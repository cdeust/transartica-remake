// SPDX-License-Identifier: MIT
// Source fixtures: enemy_trains.gd, mines.gd, world_roamers.gd and their tests.
#include "world/archive.hpp"
#include <iostream>
using namespace transartica;using namespace transartica::world;
int main(){int failed=0,checks=0;auto check=[&](bool v,const char*s){++checks;if(!v){++failed;std::cerr<<"FAIL "<<s<<'\n';}};
    std::vector<std::uint8_t> bytes(160*73,2);RailNetwork n;std::string error;n.load_bytes(bytes,error);Random rng;rng.seed(42);Random expected=rng;EnemyTrains enemies;
    const int choice=expected.range(0,8);const int extra=expected.range(0,1);const int pool=expected.range(0,5);check(enemies.spawn(2,rng)==0,"first free slot");check(enemies.at(0)->strength==3+extra+20*pool&&rng==expected,"spawn consumes exactly three draws");(void)choice;
    enemies.remove(0);check(enemies.at(0)->kind==2&&enemies.spawn(0,rng)==1,"removed slot never reused");
    enemies.sync_scripted_slot({152,66});check(enemies.encounter_at({154,62})==29&&enemies.at(29)->strength==19,"scripted Minotaur");enemies.remove(29);enemies.sync_scripted_slot({152,66});check(enemies.at(29)->kind==2,"scripted removed guard");enemies.sync_scripted_slot({151,66});check(enemies.at(29)->kind==0,"scripted remove cell clears slot");
    auto state=enemies.snapshot();state.slots[1]={1,-30,20,6,2,22,2,1};check(enemies.restore(state),"enemy restore");enemies.advance_cycle(n,rng,6);check(enemies.at(1)->cell()==Cell{11,20}&&enemies.at(1)->phase==0,"enemy phase commits");
    bytes[11*73+20]=std::uint8_t(-2);n.load_bytes(bytes,error);state=enemies.snapshot();state.slots[1]={1,-30,20,6,2,22,2,1};enemies.restore(state);enemies.advance_cycle(n,rng,6);check(enemies.at(1)->kind==5&&enemies.at(1)->cell()==Cell{10,20},"damaged rail waits");for(int i=0;i<4;++i)enemies.advance_cycle(n,rng,6);check(enemies.at(1)->kind==4,"wait timer sign semantics");
    MineState mine_state{};mine_state[0]={-30,20,3,3};Mines mines;check(mines.restore(mine_state),"mine fixture");check(mines.deplete()==MapWrites{{{10,20},79}}&&mines.snapshot()[0].wealth==-2,"wealth signed undershoot");check(mines.deplete().empty(),"depleted not emitted twice");
    std::vector<Wagon>w{{21,0,0,0},{5,0,0,10},{7,0,0,2},{16,0,0,0}};check(mine_resources(w)==MineResources{10,2,1},"resources exact types");check(mine_quantity(w,mine_resources(w),40,100,0)==1845,"mine extraction source formula");check(credited_coal(31000,100)==31000,"coal cap");
    WorldRoamers movers;int fauna_calls=0;movers.initialize(rng,[&](Random&){++fauna_calls;return Cell{-1,-1};});const auto movers_initial=movers.snapshot();movers.initialize(rng,[&](Random&){++fauna_calls;return Cell{};});check(fauna_calls==1&&movers.snapshot()==movers_initial,"initialize replay safe");
    auto rs=movers.snapshot();for(auto&h:rs.herds)h.quantity=0;rs.herds[0]={-30,20,0,6,40,20};rs.nomad={30,30,0,6,0};check(movers.restore(rs),"mover restore");check(movers.encounter({10,20},n,rng)=="herd_question","herd prompt and relocation");w={{7,0,0,0},{7,0,0,0},{5,0,0,80}};check(movers.answer(true,rng,w)&&movers.finish_hunt(w),"hunt lifecycle");check(w[0].quantity==3&&w[1].quantity==3,"source paid budget repeats in later livestock");check(movers.snapshot().countdown==24,"hunt countdown");
    Archive archive{enemies.snapshot(),{},movers.snapshot()},parsed;check(parse(serialize(archive),parsed)&&parsed==archive,"world archive exact roundtrip");const auto good=parsed;check(!parse(serialize(archive)+"garbage",parsed)&&parsed==good,"archive parse atomic");
    std::cout<<"world: "<<checks<<" checks, "<<failed<<" failures\n";return failed?1:0;
}
