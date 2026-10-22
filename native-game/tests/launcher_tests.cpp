// SPDX-License-Identifier: MIT
// Source fixtures: game/tests/test_launcher_model.gd and test_launcher.gd.
#include "launcher/launcher.hpp"
#include <iostream>
#include <limits>
#include <stdexcept>
using namespace transartica;
using namespace transartica::launcher;
namespace {
int checks{},failures{};
void check(bool value,const char* label){++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
void geometry_rules(){
    world::EnemyTrains enemies;enemies.reset();Cell origin{80,40};Model model;
    check(model.distance()==50,"initial fifty units");check(model.action(101,origin,enemies)&&model.bearing==31,"bearing wraps left");check(model.action(102,origin,enemies)&&model.bearing==0,"bearing wraps right");check(!model.action(108,origin,enemies),"unarmed fire denied");
    for(int index=0;index<4;++index)for(int tick=0;tick<10;++tick)model.action(103+index,origin,enemies);check(model.distance()==50,"source digit floor and wraps");
    check(angle(0)==90&&angle(8)==0&&angle(16)==270&&angle(24)==180,"source cardinal bearings");
    for(int i=0;i<32;++i)check(calculate(i,50,origin,enemies).has_value(),"all source coefficient table entries");
    auto state=enemies.snapshot();state.slots[0]={1,40,33,2,0,0,0,10};state.slots[1]={1,40,33,2,0,0,0,20};check(enemies.restore(state),"source duplicate-cell target fixture");
    auto hit=calculate(0,50,origin,enemies);check(hit&&hit->target==0&&hit->delta==Cell{0,112}&&hit->count==14,"strict-square first match and integer trajectory");
    state.slots[0].kind=2;enemies.restore(state);check(calculate(0,50,origin,enemies)->target==1,"removed slot2 ignored");
    state.slots[0]={0,40,33,0,0,0,0,0};enemies.restore(state);check(calculate(0,50,origin,enemies)->target==0,"source includes state0 in target search");
    check(!calculate(-1,50,origin,enemies)&&!calculate(32,50,origin,enemies)&&!calculate(0,49,origin,enemies),"invalid scalar geometry rejected before division");
}
void continuation(){
    Session s;s.journey.position={80,40};world::EnemyTrains enemies;enemies.reset();Controller c(s,enemies);c.pace_enabled=false;
    check(c.open()==OpenResult::NoLauncher,"source unpurchased gate");s.wagons.push_back({13,0,0,0});check(c.open()==OpenResult::NoMissiles,"source purchased no-missile refusal");s.wagons.push_back({14,0,2,2});
    auto es=enemies.snapshot();es.slots[0]={1,40,33,2,0,0,0,10};check(enemies.restore(es),"source target for full continuation");
    check(c.open()==OpenResult::Opened&&c.active()&&c.visible(),"open actual controller");check(c.action(107),"arm command");
    for(int i=0;i<5;++i)c.advance(3.0/50);check(c.model()->phase==Phase::Armed&&!c.action(103),"five callbacks arm and lock digits");
    check(c.action(107),"disarm command");for(int i=0;i<5;++i)c.advance(3.0/50);check(c.model()->phase==Phase::Aim,"five callbacks disarm");
    c.action(107);for(int i=0;i<5;++i)c.advance(3.0/50);s.engine.speed=20;check(c.action(108)&&s.engine.speed==0&&s.wagons.back().quantity==2,"launch stops train with delayed ammo debit");
    check(!c.dismiss()&&c.active(),"launch cannot dismiss before source continuation");
    c.options();auto paused=c.snapshot();c.advance(1);check(c.snapshot()==paused&&!c.visible()&&c.paused(),"options suspends continuation");c.resume();c.toggle_pause();
    while(true){
        auto value=c.snapshot();check(validate_snapshot(value,s.wagons,enemies,s.journey.position),"every source continuation passes replay validator");
        auto bytes=serialize_snapshot(value);Snapshot parsed;std::string error;check(parse_snapshot(bytes,parsed,error)&&parsed==value,"every continuation detached JSON roundtrip");
        auto cargo=s.wagons;auto enemy=enemies.snapshot();check(c.restore(parsed)&&s.wagons==cargo&&enemies.snapshot()==enemy,"restoration changes no cargo or enemy");
        if(c.model()->phase==Phase::Report)break;c.advance(3.0/50);
    }
    check(c.model()->status==2&&enemies.at(0)->kind==2&&s.wagons.back().quantity==2,"homing enemy removed once with ammo still reserved");
    auto good=c.snapshot(),bad=good;bad.state->geometry->record->dx+=1;check(!c.restore(bad)&&c.snapshot()==good,"historical target tampering rejected atomically");
    bad=good;bad.state->removed=false;check(!c.restore(bad)&&c.snapshot()==good,"removed enemy flag mismatch rejected");
    check(c.dismiss()&&!c.active()&&s.wagons.back().quantity==1&&s.wagons.back().goods==2,"report debit exactly once and retains source goods code");check(!c.dismiss()&&s.wagons.back().quantity==1,"repeated dismissal no second debit");
}
void malformed(){
    Session s;s.wagons.push_back({13,0,0,0});s.wagons.push_back({14,0,2,1});world::EnemyTrains enemies;enemies.reset();Controller c(s,enemies);c.open();auto good=c.snapshot(),bad=good;
    bad.state->cursor=1;check(!c.restore(bad)&&c.snapshot()==good,"aim cursor forged state rejected");bad=good;bad.state->camera={1,0};check(!c.restore(bad),"aim camera must remain canonical");
    bad=good;bad.state->accumulator=std::numeric_limits<double>::infinity();check(!c.restore(bad),"nonfinite accumulator rejected");bad=good;bad.state->digits[0]=10;check(!c.restore(bad),"digit bounds");
    std::string error;Snapshot target=good;for(auto bytes:{std::string("{}"),serialize_snapshot(good)+" trailing"})check(!parse_snapshot(bytes,target,error)&&target==good,"malformed parse leaves destination unchanged");
    auto bytes=serialize_snapshot(good),fractional=bytes;auto at=fractional.find("\"bearing\":0");fractional.replace(at,11,"\"bearing\":0.5");check(!parse_snapshot(fractional,target,error)&&target==good,"integer-only schema rejects fractional bearing");
    s.wagons.back().quantity=0;check(!c.restore(good),"active continuation requires reserved missile");
}
void cadence(){
    world::EnemyTrains enemies;enemies.reset();std::optional<Model> expected;
    for(int rate:{30,60,144}){Model m;m.phase=Phase::Armed;check(m.action(108,{80,40},enemies),"source flight cadence setup");for(int frame=0;frame<rate*30;++frame)m.advance(1.0/rate);m.accumulator=0;
        check(m.phase==Phase::Report,"finite flight completes");if(expected)check(*expected==m,"same source state at30/60/144Hz");else expected=m;}
}
}
int main(){try{geometry_rules();continuation();malformed();cadence();std::cout<<checks<<" launcher checks, "<<failures<<" failures\n";return failures?1:0;}catch(const std::exception& e){std::cerr<<"launcher fixture: "<<e.what()<<'\n';return 2;}}
