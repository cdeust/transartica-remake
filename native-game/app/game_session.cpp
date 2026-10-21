// SPDX-License-Identifier: MIT
// Source game/scripts/{main,journey_session,world_session,world_encounters}.gd.
#include "game_session.h"
#include "core/train_pose.hpp"
#include <algorithm>
#include <cmath>
#include <random>
#include <utility>

namespace transartica {
GameSession::GameSession(Session& session):core(session),
    world(core,random,[this](const world::MapWrites& writes){return apply_map(writes);}),
    campaign(core,trade,data,random,*this),launcher(core,enemies) {
    std::random_device source;
    const auto seed=[&]{return (std::uint64_t(source())<<32)|source();};
    random.seed(seed());encounter_random.seed(seed());visual_random.seed(seed());
}
bool GameSession::load(const std::filesystem::path& game,std::string& error) {
    if(!data.load(game/"private-data",error)||!trade.load(game/"private-data",error)
        ||!campaign.load(game/"private-data",error)) return false;
    core.network.set_city_anchors(data.city_anchors());
    core.network.campaign_entry_enabled=true;
    reset();return true;
}
void GameSession::reset() {
    core.reset();trade.reset(random);campaign.reset();enemies.reset();launcher.reset();launcher.take_actions();
    world.restore({});roamers.restore({});
    roamers.initialize(random,[this](Random&){return campaign.initialize_fauna();});
    works={};tactical.reset();report.reset();battle_events.clear();actions_.clear();
    city=-1;pending_enemy=-1;workshop=false;manual_paused=false;text_accumulator=0;
}
bool GameSession::apply_map(const world::MapWrites& writes) {
    auto staged=core.network;
    // The drill uses the campaign whitelist; mine mutations remain atomic.
    if(!staged.apply_mine_writes(writes)) {
        for(const auto& [cell,code]:writes) if(!staged.set_campaign_tile(cell,code)) return false;
    }
    core.network=std::move(staged);return true;
}
void GameSession::cargo_changed() {
    core.engine.train_mass=train_mass(core.wagons);
    prepare_train_poses(core.journey,core.network,core.wagons);
}
void GameSession::pause() {core.engine.brake=true;core.engine.speed=0;core.paused=true;}
bool GameSession::blocks_simulation() const {
    return city>=0||workshop||works.active()||world.snapshot().pending_mine>=0
        ||!roamers.snapshot().pending.empty()||campaign.blocks_simulation()||tactical.has_value()||report.has_value()||launcher.active();
}
void GameSession::calendar_cycle() {
    const int old_hour=core.calendar.hour;
    for(const auto& event:core.calendar.advance_cycle()) {
        if(event=="bridge_open"||event=="bridge_closed") core.network.set_timed_bridge(core.calendar.bridge_code());
        else if(event=="new_day") enemies.maybe_spawn_on_day(int(core.calendar.day),difficulty,encounter_random);
    }
    if(old_hour!=core.calendar.hour) enemies.maybe_spawn_on_hour(core.calendar.hour,difficulty,encounter_random);
    std::vector<int> bulletins;
    world.tick_mines(int(core.calendar.day),&bulletins);
    for(int id:bulletins) campaign.push_stoup(id);
    campaign.advance_spies();
}
bool GameSession::entry_due() const {
    if(core.journey.blocked||core.engine.speed<=0) return false;
    const int speed=std::min(450,core.network.progress_speed(core.journey.position,core.journey.heading,core.engine.speed));
    return core.journey.phase+1>=3 && core.journey.distance_ticks+speed/20>22;
}
bool GameSession::encounter_roamers(Cell cell) {
    if(roamers.encounter(cell,core.network,random).empty()) return false;
    pause();core.calendar.factor=1;
    if(roamers.snapshot().pending=="herd_question") actions_.push_back({campaign::ActionKind::EffectAudio,0x92,"scene1"});
    return true;
}
void GameSession::cycle() {
    auto& j=core.journey;
    if(j.blocked && j.physical_obstacle!=Cell{-1,-1} && (j.stop_reason=="special site"||j.physical_spy_handled)) {
        if(campaign.model().pending.empty()) boundary(false);
        return;
    }
    if(j.at_obstacle()&&!core.engine.brake&&!works.active()) j.resume_after_works(core.network);
    const bool was_blocked=j.blocked;
    calendar_cycle();
    for(const auto& observation:roamers.advance(core.network,random,campaign.model().hazards.traps))
        campaign.observe_enemy(observation.code-1,observation.cell);
    if(encounter_roamers(j.position)||campaign.advance_fauna()) return;
    const Cell old=j.position;
    if(entry_due()) {
        if(encounter_roamers(j.next_cell())) return;
        world.before_entry(j.next_cell());
        if(campaign.before_entry(j.next_cell())) return;
    }
    advance_train(j,core.network,core.wagons,core.engine.speed);
    if(encounter(old)) return;
    if(j.blocked) boundary(was_blocked);
}
void GameSession::boundary(bool was_blocked) {
    if(was_blocked) return;
    auto& j=core.journey;
    if(j.physical_obstacle!=Cell{-1,-1}) {
        const Cell cell=j.boundary_cell();world.before_entry(cell);
        if(campaign.before_entry(cell,j.physical_heading,j.physical_spy_handled)) {
            if(campaign.model().pending.scene==campaign::Scene::SpyPickup) j.physical_spy_handled=true;
            return;
        }
        j.physical_spy_handled=false;j.stop_reason=core.network.entry_boundary(cell);
        if(j.stop_reason.empty()) {j.physical_obstacle={-1,-1};j.physical_heading=0;j.blocked=false;return;}
    }
    const int code=core.network.tile(j.boundary_cell());
    if(code==78&&world.ask_mine(j.boundary_cell())) {pause();return;}
    if(code==65) {pause();workshop=true;actions_.push_back({campaign::ActionKind::SceneAudio,0,"worksite"});return;}
    if(code==79) {core.engine.brake=true;core.engine.speed=0;works.inform(17);return;}
    const int station=j.station_result(core.network);
    if(j.at_station()&&station==-1) {core.engine.brake=true;core.engine.speed=0;works.inform(16);return;}
    if(station>=0) {open_city(station);return;}
    if(j.at_station()&&campaign.station(station)) return;
    if(j.at_reversal_event(core.network)) {
        // main.gd::_reverse_at_event: source TEXTEK52 retains the brake while
        // station-style departure turns the consist away from the closed gate.
        core.engine.brake=true;core.engine.speed=0;works.inform(52);
        j.depart_from_station(core.network);cargo_changed();return;
    }
    if(j.at_obstacle()) {core.engine.brake=true;core.engine.speed=0;works.ask(core.network,j.boundary_cell());return;}
    pause();
}
void GameSession::open_city(int index) {
    if(!data.city(index)||campaign.before_city(index)) return;
    // Audio selection must read the visited flag before this arrival writes it.
    int kind=data.city(index)->kind;
    const auto visits=world.snapshot().visited_cities;
    if(std::find(visits.begin(),visits.end(),index)!=visits.end()) kind=-std::abs(kind);
    actions_.push_back({campaign::ActionKind::SceneAudio,kind,"city",double(index)});
    world.visit_city(index);trade.visit(index,random);city=index;core.paused=true;
}
bool GameSession::depart() {
    bool departed=false;
    if(workshop) {departed=core.journey.reverse_direction(core.network);workshop=false;}
    else if(roamers.snapshot().pending=="nomad_trade") {roamers.close();departed=core.journey.reverse_direction(core.network);}
    else departed=core.journey.depart_from_station(core.network);
    if(!departed) return false;
    city=-1;core.engine.speed=0;core.paused=false;cargo_changed();
    actions_.push_back({campaign::ActionKind::DepartureChime,1});return true;
}
void GameSession::collect_campaign() {
    for(auto& action:campaign.take_actions()) {
        switch(action.kind) {
        case campaign::ActionKind::Reverse:core.reverse();break;
        case campaign::ActionKind::CargoChanged:cargo_changed();break;
        case campaign::ActionKind::Depart:depart();break;
        case campaign::ActionKind::ResumeCity:if(action.value>=0) open_city(action.value);break;
        default:break;
        }
        actions_.push_back(std::move(action));
    }
}
std::vector<campaign::Action> GameSession::take_actions() {collect_campaign();return std::exchange(actions_,{});}
}
