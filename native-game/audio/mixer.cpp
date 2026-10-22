// SPDX-License-Identifier: MIT
// Source: game/scripts/sample_channels.gd and game_audio.gd; original priority,
// repeat and loop semantics. Float output uses SDL's normalized audio range.
#include "mixer.hpp"
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace transartica::audio {
namespace {
int signed_priority(int priority) {
    const int byte=static_cast<std::uint8_t>(priority);
    return byte>=128?byte-256:byte;
}
}
int Mixer::choose(int priority) const {
    priority=signed_priority(priority);
    int chosen=0;
    bool equal=false;
    for(std::size_t i=0;i<channels.size();++i) if(channels[i].priority==priority) {chosen=int(i);equal=true;break;}
    if(!equal) for(std::size_t i=0;i<channels.size();++i)
        if(channels[i].priority<channels[chosen].priority) chosen=int(i);
    const int current=channels[chosen].priority;
    if((priority>=0 && current<0 && current!=-128) || priority<current) return -1;
    return chosen;
}
int Mixer::play(std::shared_ptr<const Clip> clip,int priority,int volume,int repeats) {
    if(!clip || !clip->frames()) return -1;
    const int index=choose(priority);
    if(index<0) return -1;
    channels[index]={std::move(clip),0,signed_priority(priority),std::max(1,repeats),float(volume>>1)/256,true};
    return index;
}
bool Mixer::play_music(std::shared_ptr<const Clip> clip,bool loop,std::size_t begin,std::size_t end,std::size_t cursor,float gain) {
    if(!clip || !clip->frames() || !std::isfinite(gain) || gain<0 || cursor>clip->frames()) return false;
    if(loop && (end<=begin || end>clip->frames() || cursor>=end)) return false;
    music={std::move(clip),cursor,begin,end,gain,true,loop};
    if(!loop && cursor==music.clip->frames()) music.playing=false;
    return true;
}
void Mixer::stop_effects() {for(auto& channel:channels) channel=Voice{};}
void Mixer::stop_music() {music=MusicVoice{};}
void Mixer::collect_finished() {
    for(auto& channel:channels) if(!channel.playing) channel.clip.reset();
    if(!music.playing) music.clip.reset();
    if(!finale.playing) finale.clip.reset();
}
void Mixer::render(float* output,std::size_t frames) noexcept {
    std::fill_n(output,frames*2,0.0f);
    for(std::size_t frame=0;frame<frames;++frame) {
        for(auto& voice:channels) {
            if(!voice.playing || !voice.clip) continue;
            output[frame*2]+=voice.clip->pcm[voice.cursor*2]*voice.gain;
            output[frame*2+1]+=voice.clip->pcm[voice.cursor*2+1]*voice.gain;
            if(++voice.cursor==voice.clip->frames()) {
                if(--voice.repeats>0) voice.cursor=0;
                else {voice.playing=false;voice.priority=-128;}
            }
        }
        for(auto* score:{&music,&finale}) if(score->playing && score->clip) {
            output[frame*2]+=score->clip->pcm[score->cursor*2]*score->gain;
            output[frame*2+1]+=score->clip->pcm[score->cursor*2+1]*score->gain;
            ++score->cursor;
            if(score->loop && score->cursor==score->loop_end) score->cursor=score->loop_begin;
            else if(score->cursor==score->clip->frames()) score->playing=false;
        }
        output[frame*2]=std::clamp(output[frame*2],-1.0f,1.0f);
        output[frame*2+1]=std::clamp(output[frame*2+1],-1.0f,1.0f);
    }
}
std::size_t Mixer::resident_bytes() const {
    std::array<const Clip*,6> seen{}; // Four source effects, scene score, finale.
    std::size_t count=0,total=0;
    const auto add=[&](const std::shared_ptr<const Clip>& clip) {
        if(!clip || std::find(seen.begin(),seen.begin()+count,clip.get())!=seen.begin()+count) return;
        seen[count++]=clip.get();total+=clip->bytes();
    };
    for(const auto& channel:channels) add(channel.clip);
    add(music.clip);
    add(finale.clip);
    return total;
}
}
