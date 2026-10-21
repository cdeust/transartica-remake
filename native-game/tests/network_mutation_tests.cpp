// SPDX-License-Identifier: MIT
// Oracles: rail_network.gd apply_mine_writes, _mine_transition,
// _campaign_transition and _is_saved_change. Synthetic tiles isolate this API.
#include "core/session.hpp"
#include "world/world_actions.hpp"
#include <iostream>
#include <sstream>
#include <stdexcept>
using namespace transartica;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label) {++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
RailNetwork network(int original=2) {
    std::vector<std::uint8_t> bytes(RailNetwork::width*RailNetwork::height,2);
    bytes[10*RailNetwork::height+10]=std::uint8_t(original);
    RailNetwork result;std::string error;
    if(!result.load_bytes(bytes,error)) throw std::runtime_error(error);return result;
}
void mutation_atomicity() {
    auto net=network();const auto before=net.tiles();
    check(!net.apply_mine_writes({{{10,10},20},{{11,10},78}})&&net.tiles()==before,"mine invalid second write rolls back first switch");
    check(!net.apply_mine_writes({{{10,10},20},{{-1,10},78}})&&net.tiles()==before,"mine out-of-bounds batch is atomic");
    check(!net.apply_mine_writes({{{10,10},20},{{10,10},22}})&&net.tiles()==before,"conflicting duplicate cell refused atomically");
    check(net.apply_mine_writes({{{10,10},20},{{10,10},20}})&&net.tile({10,10})==20,"identical duplicate write is source-valid");
    check(net.apply_mine_writes({{{10,10},20}}),"idempotent mine write accepted");
    auto empty=network(0);check(empty.apply_mine_writes({{{10,10},78}})&&empty.apply_mine_writes({{{10,10},79}}),"new mine then depletion transitions");
    check(!empty.apply_mine_writes({{{10,10},78}})&&empty.tile({10,10})==79,"depleted mine cannot reopen via mine API");
    check(!empty.set_campaign_tile({10,10},77)&&empty.tile({10,10})==79,"unproven arbitrary campaign tile refused");
}
void saved_switches() {
    for(const int original:{2,3}) {
        auto net=network(original);
        // Source whitelist accepts the four created corner switches, either
        // toggle state and their sabotaged negative representations.
        const int first=original==2?18:26,last=original==2?25:33;
        for(int code=first;code<=last;++code) for(int sign:{1,-1}) {
            auto candidate=net.initial_tiles();candidate[10*RailNetwork::height+10]=sign*code;
            check(net.restore_tiles(candidate)&&net.tile({10,10})==sign*code,"saved created/toggled/dynamited mine switch");
        }
        for(const int code:{17,34,77,128,-129}) {
            auto candidate=net.initial_tiles();candidate[10*RailNetwork::height+10]=code;const auto before=net.tiles();
            check(!net.restore_tiles(candidate)&&net.tiles()==before,"unknown map mutation preserves live tiles");
        }
    }
    auto bridge=network(-120);auto opened=bridge.initial_tiles();opened[10*RailNetwork::height+10]=-121;
    check(bridge.restore_tiles(opened),"source closed-to-open bridge whitelist is independent of coordinates");
    auto mine=network(0);auto depleted=mine.initial_tiles();depleted[10*RailNetwork::height+10]=79;
    check(mine.restore_tiles(depleted),"saved created-then-depleted mine accepted from empty original");
}
void campaign_and_save(const std::filesystem::path& game) {
    Session session;std::string error;
    if(!session.load_world(game/"data/CARTE.FIC",error)) throw std::runtime_error(error);
    session.network.campaign_entry_enabled=true;
    check(session.network.set_campaign_tile({29,67},-114)&&session.network.entry_boundary({29,67}).empty(),"revealed oasis corridor enters with campaign host enabled");
    session.network.campaign_entry_enabled=false;
    check(session.network.entry_boundary({29,67})=="special site","unhosted corridor retains source interception boundary");
    session.network.campaign_entry_enabled=true;
    check(session.network.set_campaign_tile({22,67},-122)&&session.network.set_campaign_tile({34,4},80)&&session.network.set_campaign_tile({52,32},-123),"source Urga Oslo mausoleum writes accepted");
    const auto before=session.network.tiles();
    check(!session.network.set_campaign_tile({32,67},77)&&session.network.tiles()==before,"whitelist cell cannot receive arbitrary code");
    std::ostringstream saved;check(session.write_snapshot(saved),"full core snapshot accepts proven campaign map writes");
    Session restored=session;restored.reset();std::istringstream input(saved.str());
    check(restored.read_snapshot(input,saved.str().size(),error)&&restored.network.tiles()==session.network.tiles(),"core restore validates and retains campaign writes");
    check(restored.network.campaign_entry_enabled,"runtime host capability survives detached core restoration");
    Random random;random.seed(42);const auto rng_before=random;
    world::MapWrites rejected;
    world::WorldActions actions(session,random,[&](const auto& writes){rejected=writes;return false;});
    const auto state_before=actions.snapshot();const auto map_before=session.network.tiles();
    check(!actions.tick_mines(3)&&actions.snapshot()==state_before&&random==rng_before&&session.network.tiles()==map_before,"rejected mine transaction rolls back RNG, records, day and map");
    check(!rejected.empty(),"real CARTE mine proposal exercises rejected writes");
    world::WorldActions committed(session,random,[&](const auto& writes){return session.network.apply_mine_writes(writes);});
    check(committed.tick_mines(3)&&committed.snapshot().last_mine_day==3,"real mine batch commits once on day3");
    const auto stable=committed.snapshot();const auto stable_random=random;
    check(!committed.tick_mines(3)&&committed.snapshot()==stable&&random==stable_random,"same mine day consumes no second RNG/production pass");
    std::ostringstream mined;check(session.write_snapshot(mined),"full snapshot accepts source-created mine and switch writes");
}
}
int main(int argc,char** argv) {
    if(argc!=2) {std::cerr<<"usage: network_mutation_tests <game-directory>\n";return 2;}
    try {mutation_atomicity();saved_switches();campaign_and_save(argv[1]);std::cout<<checks<<" network mutation checks, "<<failures<<" failures\n";return failures?1:0;}
    catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
