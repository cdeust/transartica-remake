// SPDX-License-Identifier: MIT
// Source launcher_session.gd. Missile debit is delayed until report dismissal.
#include "launcher.hpp"
#include <algorithm>
#include <cmath>
#include <utility>
namespace transartica::launcher {
Controller::Controller(Session& session,world::EnemyTrains& enemies):session_(session),enemies_(enemies){}
OpenResult Controller::open(){
    if(active()){resume();return OpenResult::Opened;}
    bool bought=std::any_of(session_.wagons.begin(),session_.wagons.end(),[](const Wagon& w){return w.type==13;});
    if(!bought)return OpenResult::NoLauncher;int missiles=0;for(const auto& w:session_.wagons)if(w.goods==2)missiles+=w.quantity;if(missiles<=0)return OpenResult::NoMissiles;
    state_={true,true,false,Model{}};actions_.push_back({ActionKind::Cabin});return OpenResult::Opened;
}
bool Controller::action(int code){
    if(!state_.state||state_.paused||!state_.state->action(code,session_.journey.position,enemies_))return false;
    if(code==108)session_.engine.speed=0;
    actions_.push_back({ActionKind::EffectAudio,code==108?0x574:code==107?0x596:0x568});return true;
}
void Controller::advance(double seconds){
    if(!state_.state||state_.paused||!state_.visible||!std::isfinite(seconds)||seconds<0)return;auto& m=*state_.state;auto before=m.phase;
    double pace=pace_enabled?(m.phase==Phase::Launch||m.phase==Phase::Ascent?1.5:m.phase==Phase::Flight||m.phase==Phase::Impact?2:1):1;
    if(!std::isfinite(seconds*pace))return;m.advance(seconds*pace);
    if((m.phase==Phase::Impact||m.phase==Phase::Report)&&!m.removed&&m.geometry&&m.geometry->target>=0){enemies_.remove(m.geometry->target);m.removed=true;actions_.push_back({ActionKind::EnemyRemoved,m.geometry->target});}
    if(before!=Phase::Impact&&before!=Phase::Report&&(m.phase==Phase::Impact||m.phase==Phase::Report)&&m.status!=0)actions_.push_back({ActionKind::ImpactAudio,5});
}
bool Controller::dismiss(){
    if(!state_.state)return false;auto phase=state_.state->phase;
    if(phase==Phase::Report){for(auto& w:session_.wagons)if(w.goods==2&&w.quantity>0){--w.quantity;break;}actions_.push_back({ActionKind::CargoChanged});}
    else if(phase!=Phase::Aim&&phase!=Phase::Armed&&phase!=Phase::Arming&&phase!=Phase::Disarming)return false;
    reset();actions_.push_back({ActionKind::Cabin});return true;
}
void Controller::reset(){state_={};}
void Controller::resume(){if(active())state_.visible=true;}
void Controller::hide(){state_.visible=false;}
void Controller::toggle_pause(){if(active())state_.paused=!state_.paused;}
void Controller::options(){if(active()){state_.paused=true;state_.visible=false;actions_.push_back({ActionKind::Options});}}
void Controller::save(){if(active())actions_.push_back({ActionKind::Save});}
bool Controller::restore(const Snapshot& value){if(!validate_snapshot(value,session_.wagons,enemies_,session_.journey.position))return false;state_=value;actions_.clear();return true;}
std::vector<Action> Controller::take_actions(){return std::exchange(actions_,{});}
}
