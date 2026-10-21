// SPDX-License-Identifier: MIT
// Source travel_world.gd update_train/_advance_motion/_snap_visual_position.
#include "world_motion.hpp"
#include <algorithm>
#include <cmath>
namespace transartica {
namespace {bool close(double a,double b){return a==b||std::abs(a-b)<std::max(.00001*std::abs(a),.00001);}}
void WorldMotion::reset(const Journey& journey){arc_=from_=to_=journey.distance_travelled();position_=target_=journey.fractional_position();elapsed_=0;initialized_=true;interpolating_=false;}
void WorldMotion::synchronize(const Journey& journey,bool visible){
    auto actual=journey.fractional_position();double arc=journey.distance_travelled();bool moved=!initialized_||!close(to_,arc);
    if(!visible||journey.reversing||!initialized_||arc<to_||distance(target_,actual)>1.5){reset(journey);return;}
    if(moved){target_=actual;from_=arc_;to_=arc;elapsed_=0;interpolating_=true;}
}
void WorldMotion::advance(const Session& s,double seconds,bool visible,bool visual_paused){
    if(!visible||s.paused||s.engine.event_pending||visual_paused||!interpolating_||!std::isfinite(seconds)||seconds<=0||s.seconds_per_cycle<=0)return;
    elapsed_=std::min(elapsed_+seconds,s.seconds_per_cycle);arc_=from_+(to_-from_)*(elapsed_/s.seconds_per_cycle);
    auto sample=s.journey.sample_behind(lag(s.journey));if(sample.ok)position_=sample.position;interpolating_=elapsed_<s.seconds_per_cycle;
}
double WorldMotion::lag(const Journey& j)const{return initialized_?std::max(0.,j.distance_travelled()-arc_):0;}
}
