// SPDX-License-Identifier: MIT
// Source launcher_snapshot.gd: validate actual finite continuation by replay.
#include "launcher.hpp"
#include <algorithm>
#include <cmath>
namespace transartica::launcher {
namespace {
bool basic(const Model& m){
    if(m.bearing<0||m.bearing>31||int(m.phase)<0||int(m.phase)>int(Phase::Report))return false;
    for(int digit:m.digits)if(digit<0||digit>9)return false;
    return m.distance()>=50&&std::isfinite(m.accumulator)&&m.accumulator>=0&&m.accumulator<3.0/50;
}
bool aim(const Model& m){
    if(m.phase!=Phase::Aim&&m.phase!=Phase::Armed&&m.phase!=Phase::Arming&&m.phase!=Phase::Disarming)return false;
    if(m.cursor<0||m.cursor>=5||((m.phase==Phase::Aim||m.phase==Phase::Armed)&&m.cursor!=0))return false;
    Model expected;expected.bearing=m.bearing;expected.digits=m.digits;expected.phase=m.phase;expected.cursor=m.cursor;expected.accumulator=m.accumulator;
    return m==expected;
}
bool flight(const Model& m,const world::EnemyTrains& enemies,Cell origin){
    const auto& g=*m.geometry;if(g.target<-1||g.target>=30||bool(g.record)!=(g.target>=0))return false;
    world::EnemyTrains staged;auto state=enemies.snapshot();
    if(g.target>=0){
        if(m.removed){if(state.slots[g.target]!=world::EnemyTrain{2,0,0,0,0,0,0,0})return false;}
        else if(state.slots[g.target]!=*g.record)return false;
        state.slots[g.target]=*g.record;
    }
    if(!staged.restore(state))return false;auto expected=calculate(m.bearing,m.distance(),origin,staged);if(!expected||*expected!=g)return false;
    Model replay;replay.bearing=m.bearing;replay.digits=m.digits;replay.phase=Phase::Armed;if(!replay.action(108,origin,staged))return false;
    while(true){
        replay.removed=(replay.phase==Phase::Impact||replay.phase==Phase::Report)&&g.target>=0;
        auto candidate=replay;candidate.accumulator=m.accumulator;if(candidate==m)return true;
        if(replay.phase==Phase::Report)return false;replay.step();
    }
}
}
bool validate_snapshot(const Snapshot& s,const std::vector<Wagon>& wagons,const world::EnemyTrains& enemies,Cell origin){
    if(!s.active)return !s.state&&!s.visible&&!s.paused;
    if(!s.state||!basic(*s.state))return false;
    if(!std::any_of(wagons.begin(),wagons.end(),[](const Wagon& w){return w.type==13;})||!std::any_of(wagons.begin(),wagons.end(),[](const Wagon& w){return w.goods==2&&w.quantity>0;}))return false;
    return s.state->geometry?flight(*s.state,enemies,origin):aim(*s.state);
}
}
