// SPDX-License-Identifier: MIT
// Source fixtures: game/tests/test_automatic_combat.gd and combat_outcome.gd.
#include "combat/outcome.hpp"
#include "combat/tactical.hpp"
#include <iostream>
using namespace transartica;using namespace transartica::combat;
int main(){int checks=0,fail=0;auto c=[&](bool x,const char*s){++checks;if(!x){++fail;std::cerr<<"FAIL "<<s<<'\n';}};Random rng;rng.seed(4);EngineState e;auto w=initial_wagons();
 c(auto_pools(w).soldiers==10,"initial troop pool");c(potential({50,2,1})==2&&margin(4,201)==2,"potential and strength namespace");
 std::vector<Wagon> weak{{1,0,0,0},{21,0,0,0}};const auto before=weak;const auto engine=e;auto result=automatic_resolve(weak,e,100,rng);c(!result.won&&result.epitaph_id==105&&weak==before&&e==engine,"loss reports before mutation");
 w={{1,0,0,0},{21,0,0,0},{23,0,0,200},{7,0,0,2},{5,0,0,0}};result=automatic_resolve(w,e,0,rng);c(result.won&&result.margin==4&&result.soldiers_lost==160&&result.mammoths_lost==2,"source casualty formula");c(result.wagons_captured<=8&&w.size()<=100,"capture cap");
 w={{5,0,0,29},{5,0,0,30},{6,0,0,99}};c(win_slaves(w,1,rng)>0&&w[0].quantity>29,"win prison distribution");
 w={{23,0,0,45},{24,0,0,90},{7,0,0,3}};c(win_survivors(w,20)==15&&w[1].quantity==100,"XL source cap100");c(win_mammoths(w,4)==2&&w[2].quantity==5,"win mammoth cap5");
 w={{22,3,0,0}};std::array<int,20> spies;spies.fill(1);apply_destruction(w,e,spies,rng);int remaining=0;for(int s:spies)remaining+=s;c(remaining==0,"zero spy quantity signed byte underflow scans all20");

 Tactical battle;w=initial_wagons();rng.seed(17);c(battle.begin(w,21,rng),"tactical begin");const auto start=battle.snapshot();c(start.trains[0].size()==w.size()+1&&start.trains[0][1].kind==Companion,"intact engine companion");c(start.random==rng,"begin returns RNG draws to encounters");
 TacticalState parsed;c(parse(serialize(start),parsed)&&parsed==start,"tactical exact typed archive");const auto saved=parsed;c(!parse(serialize(start)+"junk",parsed)&&parsed==saved,"tactical parse atomic");
 Tactical first,second;c(first.restore(start)&&second.restore(start),"independent tactical resumes");for(int i=0;i<100;++i)first.advance(.04);for(int i=0;i<50;++i)second.step();auto f=first.snapshot(),g=second.snapshot();f.remainder=g.remainder=0;c(f==g,"fixed-step time partition invariant");
 auto fixture=start;fixture.actors.clear();fixture.next_id=0;fixture.scan=0;fixture.sweep=0;fixture.ai_wait=100;fixture.aggressiveness=0;fixture.army_strength={20,20};for(auto&side:fixture.trains)for(auto&car:side){car.quantity=0;car.reload=0;if(car.kind==Cannon||car.kind==MachineGun)car.kind=Merchandise;}fixture.trains[0][5]={Barracks,20,3,0};fixture.trains[1].back()={Barracks,20,3,0};fixture.survivors={20,0,0};fixture.initial_pools={20,0,0};c(battle.restore(fixture),"controlled field fixture");const int id=battle.add_actor(0,20,6,10,false);c(battle.command(id,0),"infantry move order");for(int i=0;i<14;++i)battle.step();const auto moved=battle.snapshot();c(moved.actors.at(id).y<6,"player infantry receives field sweeps");
 fixture=battle.snapshot();fixture.actors.clear();fixture.next_id=0;fixture.scan=0;fixture.sweep=0;fixture.trains[0][0].health=fixture.trains[0][1].health=3;fixture.outcome=0;fixture.settled=false;c(battle.restore(fixture),"roof fixture restore");const int roof=battle.add_actor(0,4,-1,10,false,1,8);c(battle.plant(roof,1),"plant adjacent dynamite");for(int i=0;i<5*14;++i)battle.step();c(battle.snapshot().trains[1][1].health==0,"fuse five complete roof sweeps");
 auto ending=start;ending.outcome=1;ending.actors.clear();ending.charges.clear();ending.survivors={ending.initial_pools.soldiers,ending.initial_pools.mammoths,0};c(battle.restore(ending),"win fixture restore");w=ending.original;std::array<int,20> no_spies{};auto report=battle.commit(w,e,no_spies);c(report&&report->won&&!battle.commit(w,e,no_spies),"tactical commit exactly once");
 std::cout<<"combat: "<<checks<<" checks, "<<fail<<" failures\n";return fail?1:0;}
