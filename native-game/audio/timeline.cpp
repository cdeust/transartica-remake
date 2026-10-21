// SPDX-License-Identifier: MIT
// Exact source ticks/cues: scripts/game_audio.gd, engine_audio.gd, scene_audio.gd.
#include "implementation.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace transartica::audio {
int GameAudio::son(int selector,int pitch,bool long_ambient) {
    if(selector==2) return effect("son",long_ambient?0x72:0x87,{{12,pitch}});
    if(selector==8) return effect("son",long_ambient?0x109:0x11e,{{12,pitch}});
    if(selector==6) {
        const int result=effect("son",0x12f);
        impl_->pending.push_back({impl_->clock+3.0/50,0x144});
        impl_->pending.push_back({impl_->clock+6.0/50,0x159});
        return result;
    }
    const std::map<int,int> offsets{{0,0x34},{1,0x48},{3,0x9b},{4,0xaf},{5,0xc3},{7,0xdf}};
    const auto found=offsets.find(selector);
    return found==offsets.end()?-1:effect("son",found->second,{{12,pitch}});
}
void GameAudio::advance(double seconds,const EngineAudioState& engine) {
    if(!std::isfinite(seconds) || seconds<0) throw std::invalid_argument("Audio delta must be finite and nonnegative");
    auto& p=*impl_;
    {DeviceLock lock(p.device);p.mixer.collect_finished();}
    p.clock+=seconds;
    // Remove due calls before dispatch: stop_effects must cancel all future stages.
    std::vector<Impl::Pending> ready;
    for(auto it=p.pending.begin();it!=p.pending.end();) {
        if(it->due<=p.clock) {ready.push_back(*it);it=p.pending.erase(it);} else ++it;
    }
    std::stable_sort(ready.begin(),ready.end(),[](const auto& a,const auto& b){return a.due<b.due;});
    for(const auto& pending:ready) effect("son",pending.offset);
    p.advance_engine(*this,seconds,engine);
    p.advance_scene(*this,seconds,engine);
    p.advance_score(seconds);
}
void GameAudio::Impl::advance_engine(GameAudio& audio,double seconds,const EngineAudioState& engine) {
    auto& p=*this;
    if(!engine.cabin_visible) {p.cabin_active=false;p.cabin_time=0;}
    else {
        if(!p.cabin_active) {
            p.cabin_active=true;p.poses={};p.waits={};audio.stop_effects();
            if(engine.speed>0) audio.son(8);
            else if(engine.pressure_reserve>=1500) audio.son(2,(engine.speed-1)/60);
        }
        p.cabin_time+=seconds;
        while(p.cabin_time>=1.0/50) {
            p.cabin_time-=1.0/50;
            for(std::size_t side=0;side<2;++side) {
                const int rate=side?engine.anthracite_rate:engine.lignite_rate;
                const int fuel=side?engine.anthracite:engine.lignite;
                if(rate==0 || fuel==0) {p.poses[side]=0;p.waits[side]=0;continue;}
                if(p.waits[side]>0 && --p.waits[side]>0) continue;
                if(p.poses[side]==0) audio.effect("train",0x10cf);
                else if(p.poses[side]==3) audio.effect("train",0x10e3);
                p.poses[side]=(p.poses[side]+1)%8;p.waits[side]=5-2*rate;
            }
        }
    }
}
void GameAudio::Impl::advance_scene(GameAudio& audio,double seconds,const EngineAudioState& engine) {
    auto& p=*this;
    if(!engine.oslo_visible) p.scene_time=0;
    else {
        p.scene_time+=seconds;
        while(p.scene_time>=1.0/50) {p.scene_time-=1.0/50;if(p.state.random.range(0,9)==0) audio.effect("scene4",0x3ed);}
    }
}
void GameAudio::Impl::advance_score(double seconds) {
    auto& p=*this;
    if(p.state.track.empty()) return;
    p.state.elapsed+=seconds;
    float level=-1;
    if(p.fade_remaining>0) {
        p.fade_remaining=std::max(0.0,p.fade_remaining-seconds);
        level=float(p.fade_gain*p.fade_remaining/p.fade_duration);
    } else {
        const auto track=p.resources.track(p.state.track);
        const double finish=(double(track.duration)+(p.state.track=="bopres-0"?21:11))/50;
        if(track.loop && p.state.elapsed>finish) {
            const double base=p.state.track.starts_with("bojeu")?50.0/127:1;
            level=float(base*std::max(0.0,1-(p.state.elapsed-finish)*50/101));
        }
    }
    if(level==0) p.stop_music();
    else if(level>0) {DeviceLock lock(p.device);p.mixer.music.gain=level;}
}
}
