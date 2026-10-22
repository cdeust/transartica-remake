// SPDX-License-Identifier: MIT
// Source startup_intro.gd::advance_tick/request_exit. No game state or audio RNG.
#include "startup_model.h"
#include <cmath>
#include <utility>
namespace transartica::panels {
void StartupTimeline::start() {tick_=0;remainder_=0;exit_tick_=-1;active_=true;audio_.clear();}
void StartupTimeline::advance(double seconds) {
    if(!active_||!std::isfinite(seconds)||seconds<0||!std::isfinite(remainder_+seconds*hz))return;
    remainder_+=seconds*hz;
    while(active_&&remainder_>=1) {remainder_-=1;step();}
}
void StartupTimeline::step() {
    if(!active_)return;++tick_;
    if(tick_==99)audio_.push_back({StartupAudioKind::PublisherEffect,0x3c});
    if(tick_==publisher_end)audio_.push_back({StartupAudioKind::ReceptionMusic,0});
    if(exit_tick_<0&&tick_>=title_ready+title_timeout)request_exit();
    if(exit_tick_>=0&&tick_-exit_tick_>=exit_fade)active_=false;
}
bool StartupTimeline::request_exit() {
    if(!active_||tick_<title_ready||exit_tick_>=0)return false;
    exit_tick_=tick_;audio_.push_back({StartupAudioKind::FadeMusic,50});return true;
}
std::vector<StartupAudio> StartupTimeline::take_audio() {return std::exchange(audio_,{});}
}
