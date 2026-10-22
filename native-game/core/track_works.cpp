// SPDX-License-Identifier: MIT
// Source: game/scripts/track_works.gd and works_dialog.gd;
// tasks/evidence/obstacles.md, YODA0x2390 and TEXTEK0x41d6..462d.
#include "track_works.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace transartica {
WorkKind work_kind(int code) {
    if(code==67 || code==69) return WorkKind::Crevasse;
    if(code==-116 || code==114) return WorkKind::Lake;
    if(code<0 && code>-105) return WorkKind::Destroyed;
    return WorkKind::None;
}
int repaired_track(int code) {
    switch(code) {
    case 67:return 63; case 69:return 64; case -116:return -121; case 114:return -117;
    default:return std::abs(code);
    }
}
WorkRule work_rule(WorkKind kind) {
    switch(kind) {
    case WorkKind::Crevasse:return {24,92,10,15,74,20,5};
    case WorkKind::Lake:return {25,93,8,15,75,25,5};
    case WorkKind::Destroyed:return {26,94,2,5,76,2,0};
    default:throw std::invalid_argument("No work rule for empty work kind");
    }
}
int rails_carried(const std::vector<Wagon>& wagons) {
    int total=0;
    for(const auto& w:wagons) if((w.type==17 || w.type==18) && w.goods==1) total+=w.quantity;
    return total;
}
int slaves_carried(const std::vector<Wagon>& wagons) {
    int total=0;
    for(const auto& w:wagons) if(w.type==5 || w.type==6) total+=w.quantity;
    return total;
}
int consume_rails(std::vector<Wagon>& wagons,int amount) {
    int left=amount;
    for(auto& w:wagons) {
        if(left<=0) break;
        if((w.type!=17 && w.type!=18) || w.goods!=1) continue;
        const int taken=std::min(left,w.quantity);
        w.quantity-=taken; left-=taken;
        // TEXTEK0x42bd preserves the goods id on an exact empty, clears on undershoot.
        if(w.quantity==0 && left>0) w.goods=0;
    }
    return amount-left;
}
WorkLabour work_labour(WorkKind kind,const std::vector<Wagon>& wagons) {
    WorkLabour result;
    result.slaves=slaves_carried(wagons);
    for(const auto& w:wagons) {
        if(w.type==7) result.mammoths+=w.quantity;
        if(w.type==16) ++result.cranes;
    }
    const int labour=result.slaves+result.mammoths*30+(result.cranes>0?150:0);
    const bool destroyed=kind==WorkKind::Destroyed;
    const int remaining=std::max(0,(destroyed?175:420)-labour);
    // Source local byte is signed; retain the wrap rather than clamping it.
    const int ticks=(remaining/3+(destroyed?12:144))&255;
    result.ticks=ticks>127?ticks-256:ticks;
    return result;
}
bool TrackWorks::ask(const RailNetwork& network,Cell at) {
    if(!network.in_bounds(at) || work_kind(network.tile(at))==WorkKind::None) return false;
    *this={}; cell=at; code=network.tile(at); kind=work_kind(code); stage=WorkStage::Question;
    return true;
}
void TrackWorks::inform(int message) { *this={};information=message;stage=WorkStage::Information; }
bool TrackWorks::accept(std::vector<Wagon>& wagons,Random& rng) {
    if(stage!=WorkStage::Question) return false;
    const auto rule=work_rule(kind);
    lacks_rails=rails_carried(wagons)<rule.rails;
    if(lacks_rails || slaves_carried(wagons)<rule.slaves) {stage=WorkStage::Shortage;return false;}
    used=consume_rails(wagons,rule.base-(rule.spread?rng.below(rule.spread):0));
    labour=work_labour(kind,wagons);countdown=labour.ticks;stage=WorkStage::Report;
    return true;
}
bool TrackWorks::dismiss(RailNetwork& network,Journey& journey) {
    const bool repaired=stage==WorkStage::Report && network.tile(cell)==code && network.repair(cell);
    if(repaired) journey.resume_after_works(network);
    stage=WorkStage::Closed;accumulator=0;
    return repaired;
}
bool TrackWorks::advance(double seconds,double seconds_per_cycle) {
    if(!active()) {accumulator=0;return false;}
    if(!std::isfinite(seconds) || seconds<0 || seconds_per_cycle<=0) return false;
    // world_session.gd TEXT_TICKS_PER_CYCLE; source scheduler time, not frame count.
    const double interval=seconds_per_cycle/48.0;
    accumulator+=seconds;
    bool expired=false;
    while(accumulator>=interval) {
        accumulator-=interval;
        if(stage==WorkStage::Report && countdown>0) expired=(--countdown==0)||expired;
    }
    return expired;
}
bool TrackWorks::valid(const RailNetwork& network) const {
    if(stage<WorkStage::Closed || stage>WorkStage::Information || kind<WorkKind::None || kind>WorkKind::Destroyed) return false;
    if(!std::isfinite(accumulator) || accumulator<0 || accumulator>=1.0/48.0 || countdown<-128 || countdown>127) return false;
    if(stage==WorkStage::Closed) return true;
    if(stage==WorkStage::Information) return kind==WorkKind::None && information>0;
    if(kind==WorkKind::None || !network.in_bounds(cell) || network.tile(cell)!=code || work_kind(code)!=kind) return false;
    return stage!=WorkStage::Report || (used>=0 && used<=work_rule(kind).base && labour.slaves>=0 && labour.mammoths>=0 && labour.cranes>=0);
}
}
