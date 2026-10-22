// SPDX-License-Identifier: MIT
// Source oracles: travel_world.gd update_train/_advance_motion/_can_animate,
// train_renderer.gd poses(lag). Synthetic paths isolate visual interpolation.
#include "core/train_pose.hpp"
#include "view/world_motion.hpp"
#include "view/world_state.hpp"
#include <cmath>
#include <iostream>
#include <limits>
using namespace transartica;
namespace {
int checks{},failures{};
void check(bool ok,const char* label){++checks;if(!ok){++failures;std::cerr<<"FAIL "<<label<<'\n';}}
bool near(double a,double b){return std::abs(a-b)<.00001;} // Source CMP_EPSILON.
Session fixture(){Session s;s.journey.render_path={{0,0},{10,0}};s.journey.render_cursor=5;s.journey.render_origin=0;s.journey.position={5,0};s.wagons={{1,0,0,0}};return s;}
void lag_cases(){
    auto s=fixture();auto direct=train_poses(s.journey,s.wagons),lagged=train_poses(s.journey,s.wagons,.25);
    check(direct.size()==1&&lagged.size()==1,"shared solve draws known prefix");
    if(!lagged.empty()){check(near(lagged[0].front.x,4.75)&&near(lagged[0].rear.x,4),"lag moves both contacts on canonical route");check(near(lagged[0].front_distance,.25),"distance metadata includes lag");}
    check(train_poses(s.journey,s.wagons,-1)==direct,"negative lag source clamp");
    check(train_poses(s.journey,s.wagons,5).empty(),"lag cannot invent history behind route");
    auto path=s.journey.render_path;s.journey.render_path={{0,0},{5,0},{5,5}};s.journey.render_cursor=5.5;
    auto curve=train_poses(s.journey,s.wagons);check(curve.size()==1,"shared curve solve succeeds");
    if(!curve.empty()){check(near(distance(curve[0].front,curve[0].rear),.75),"curve retains rigid length");check(distance(curve[0].center,curve[0].rail_midpoint)>.1,"curved rail midpoint differs from chord center");}
    (void)path;
}
void motion_cases(){
    auto s=fixture();WorldMotion motion;motion.synchronize(s.journey,true);check(near(motion.position().x,5)&&motion.lag(s.journey)==0,"first view snaps");
    s.journey.render_cursor=5.5;motion.synchronize(s.journey,true);motion.advance(s,.5,true);check(near(motion.position().x,5.25)&&near(motion.lag(s.journey),.25),"half cycle interpolates known route");
    const auto path=s.journey.render_path;const auto cursor=s.journey.render_cursor;
    s.paused=true;motion.advance(s,.5,true);check(near(motion.position().x,5.25),"game pause freezes motion");s.paused=false;
    s.engine.event_pending=true;motion.advance(s,.5,true);check(near(motion.position().x,5.25),"engine event freezes motion");s.engine.event_pending=false;
    motion.advance(s,.5,true,true);check(near(motion.position().x,5.25),"visual pause freezes motion");
    motion.advance(s,.5,true);check(near(motion.position().x,5.5)&&near(motion.lag(s.journey),0),"cycle reaches destination");
    check(s.journey.render_path==path&&s.journey.render_cursor==cursor,"motion never mutates authoritative route");
    s.journey.render_cursor=6;motion.synchronize(s.journey,false);check(motion.lag(s.journey)==0&&near(motion.position().x,6),"hidden view resets backlog");
    s.journey.render_cursor=5;motion.synchronize(s.journey,true);check(motion.lag(s.journey)==0&&near(motion.position().x,5),"backwards arc resets");
    s.journey.render_cursor=7;motion.synchronize(s.journey,true);check(motion.lag(s.journey)==0&&near(motion.position().x,7),"source jump threshold resets");
    s.journey.render_cursor=7.5;s.journey.reversing=true;motion.synchronize(s.journey,true);check(motion.lag(s.journey)==0,"reverse uses source snap");
}
void rate_cases(){
    for(int rate:{30,60,144}){auto s=fixture();WorldMotion m;m.reset(s.journey);s.journey.render_cursor=5.5;m.synchronize(s.journey,true);
        for(int i=0;i<rate/2;++i)m.advance(s,1./rate,true);
        check(near(m.position().x,5.25)&&near(m.lag(s.journey),.25),"display rate independent half-cycle pose");}
}
void state_cases(){
    WorldState s;s.ready=true;s.camera={-1000,1000};s.offset={230,-60};s.zoom=.5;s.following=true;s.inspecting=true;s.selected_city=45;
    auto copy=s;check(normalize_world_state(copy,46)&&copy==s,"source finite off-map camera preserved");
    s.zoom=-5;s.selected_city=46;check(normalize_world_state(s,46)&&s.zoom==.001&&s.selected_city==-1,"source restore clamps zoom and drops invalid selection");
    s.zoom=10;s.selected_city=-2;check(normalize_world_state(s,46)&&s.zoom==2&&s.selected_city==-1,"upper zoom and negative city normalization");
    s.camera.x=std::numeric_limits<double>::infinity();check(!normalize_world_state(s,46),"non-finite camera rejected");
    s=WorldState{};s.offset.y=std::numeric_limits<double>::quiet_NaN();check(!normalize_world_state(s,46),"non-finite pan rejected");
    s=WorldState{};s.zoom=std::numeric_limits<double>::infinity();check(!normalize_world_state(s,46),"non-finite zoom rejected before clamp");
}
}
int main(){lag_cases();motion_cases();rate_cases();state_cases();std::cout<<"world motion: "<<checks<<" checks, "<<failures<<" failures\n";return failures?1:0;}
