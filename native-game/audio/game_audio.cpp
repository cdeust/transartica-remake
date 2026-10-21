// SPDX-License-Identifier: MIT
// Policies: game/scripts/game_audio.gd, sample_channels.gd, audio_cue.gd.
// Device: SDL_OpenAudioDevice/SDL_LockAudioDevice, SDL2 public API.
#include "implementation.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace transartica::audio {
namespace {
float gain(const std::string& key) {return key.starts_with("bojeu")?50.0f/127.0f:1.0f;}
std::size_t converted_frame(std::size_t source,int source_rate,int output_rate) {
    return static_cast<std::size_t>(std::llround(double(source)*output_rate/source_rate));
}
}
GameAudio::Impl::~Impl() {
    if(device) SDL_CloseAudioDevice(device);
    if(owns_subsystem) SDL_QuitSubSystem(SDL_INIT_AUDIO);
}
void GameAudio::Impl::callback(void* context,Uint8* stream,int length) noexcept {
    auto& self=*static_cast<Impl*>(context);
    self.mixer.render(reinterpret_cast<float*>(stream),std::size_t(length)/(2*sizeof(float)));
}
void GameAudio::Impl::open() {
    if(!config.resident_budget_bytes) throw std::runtime_error("Audio requires an explicit resident allocation budget");
    // source: tasks/evidence/orchestral-score-20261006.md: delivered stereo PCM16 44.1kHz.
    rate=config.device_rate?config.device_rate:44100;
    if(rate<=0) throw std::runtime_error("Invalid audio output rate");
    if(!config.open_device) return;
    if(!(SDL_WasInit(SDL_INIT_AUDIO)&SDL_INIT_AUDIO)) {
        if(SDL_InitSubSystem(SDL_INIT_AUDIO)<0) throw std::runtime_error(SDL_GetError());
        owns_subsystem=true;
    }
    SDL_AudioSpec desired{},obtained{};
    desired.freq=rate;desired.format=AUDIO_F32SYS;desired.channels=2;
    desired.samples=0; // SDL chooses the device's audio buffer quantum.
    desired.callback=callback;desired.userdata=this;
    device=SDL_OpenAudioDevice(nullptr,0,&desired,&obtained,SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
    if(!device) throw std::runtime_error("Audio device: "+std::string(SDL_GetError()));
    if(obtained.format!=AUDIO_F32SYS || obtained.channels!=2 || obtained.freq<=0) throw std::runtime_error("Unsupported negotiated audio format");
    rate=obtained.freq;SDL_PauseAudioDevice(device,0);
}
std::shared_ptr<const Clip> GameAudio::Impl::load(const std::filesystem::path& path,int numerator,int denominator) {
    std::size_t used;
    {
        DeviceLock lock(device);mixer.collect_finished();
        const auto matches=[&](const std::shared_ptr<const Clip>& clip) {
            return clip && clip->source_path==path &&
                std::int64_t(clip->pitch_numerator)*denominator==std::int64_t(numerator)*clip->pitch_denominator;
        };
        // Share only immutable PCM already owned by an active voice. No WAV cache.
        if(matches(mixer.music.clip)) return mixer.music.clip;
        if(matches(mixer.finale.clip)) return mixer.finale.clip;
        for(const auto& voice:mixer.channels) if(matches(voice.clip)) return voice.clip;
        used=mixer.resident_bytes();
    }
    if(used>=config.resident_budget_bytes) throw std::runtime_error("Audio residency budget exhausted");
    return load_clip(path,rate,numerator,denominator,config.resident_budget_bytes-used);
}
bool GameAudio::Impl::install(const std::string& key,const Track& track,std::shared_ptr<const Clip> clip,double elapsed) {
    const auto source_end=track.end?track.end:clip->source_frames;
    if(track.loop && (source_end>clip->source_frames || source_end<=track.begin)) throw std::runtime_error("Music loop outside source PCM: "+key);
    const auto begin=converted_frame(track.begin,clip->source_rate,rate);
    const auto end=std::min(clip->frames(),converted_frame(source_end,clip->source_rate,rate));
    const double position=GameAudio::score_position(elapsed,double(clip->source_frames)/clip->source_rate,clip->source_rate,track.loop,track.begin,source_end);
    auto cursor=std::min(clip->frames(),static_cast<std::size_t>(position*rate));
    if(track.loop && cursor>=end) cursor=begin;
    DeviceLock lock(device);
    if(!mixer.play_music(std::move(clip),track.loop,begin,end,cursor,gain(key))) throw std::runtime_error("Invalid converted music bounds");
    state.track=key;state.elapsed=elapsed;fade_remaining=0;return true;
}
void GameAudio::Impl::stop_music() {DeviceLock lock(device);mixer.stop_music();state.track.clear();fade_remaining=0;}
GameAudio::GameAudio(const std::filesystem::path& game,AudioConfig options,std::uint64_t seed):impl_(std::make_unique<Impl>(game,options,seed)) {impl_->open();}
GameAudio::~GameAudio()=default;
int GameAudio::sample(const std::string& script,int resource,int priority,int volume,int repeat,int frequency) {
    auto& p=*impl_;if(!p.state.effects_enabled) return -1;
    try {
        auto* entry=p.resources.sample(script,resource);
        if(!entry) throw std::runtime_error("Unknown audio sample: "+script+"/"+std::to_string(resource));
        {DeviceLock lock(p.device);if(p.mixer.choose(priority)<0) return -1;}
        const int original=integer(entry,"frequency_khz");
        int requested=frequency?frequency:original;if(requested<1 || requested>20) requested=10;
        auto clip=p.load(p.resources.path(string(entry,"file")),requested,original);
        DeviceLock lock(p.device);const int result=p.mixer.play(std::move(clip),priority,volume,repeat);p.error.clear();return result;
    } catch(const std::exception& exception) {p.error=exception.what();return -1;}
}
int GameAudio::effect(const std::string& script,int offset,const std::map<int,int>& locals) {
    auto& p=*impl_;
    try {
        auto* cue=p.resources.cue(script,offset);if(!cue) throw std::runtime_error("Unknown audio cue: "+script+"/"+std::to_string(offset));
        auto* args=field(cue,"args");if(json_object_array_length(args)!=5) throw std::runtime_error("Invalid csound operand count");
        std::array<int,5> values{};for(std::size_t i=0;i<values.size();++i) values[i]=operand(json_object_array_get_idx(args,i),locals,p.state.random);
        return sample(script,values[0],values[1],values[2],values[3],values[4]);
    } catch(const std::exception& exception) {p.error=exception.what();return -1;}
}
bool GameAudio::play_track(const std::string& key,bool guard) {
    auto& p=*impl_;
    if(guard && !p.state.music_enabled) {p.stop_music();return false;}
    try {const auto track=p.resources.track(key);auto clip=p.load(track.path);p.install(key,track,std::move(clip),0);p.error.clear();return true;}
    catch(const std::exception& exception) {p.error=exception.what();return false;}
}
void GameAudio::play_reception() {play_track("bopres-0",false);}
void GameAudio::play_journey(bool synthesized) {
    auto& state=impl_->state;
    if(!state.music_enabled) {impl_->stop_music();return;}
    // The source capability branch skips scene selection and leaves audio alone.
    if(!synthesized) return;
    state.alternate=!state.alternate;
    play_track(state.alternate?"bojeu2-0":"bojeu-"+std::to_string(state.random.range(0,1)));
}
void GameAudio::play_city(int kind,int index) {
    if(kind==3 || kind==-3 || index==45) {impl_->stop_music();return;}
    play_track(kind==1?"bolieu-3":kind==2?"bolieu-1":"bolieu-0");
}
void GameAudio::play_worksite() {play_track("bolieu-2");}
void GameAudio::play_loss() {play_track("bolost-0");}
bool GameAudio::play_finale(double seconds) {
    auto& p=*impl_;
    if(!std::isfinite(seconds)||seconds<0) {p.error="Invalid finale audio offset";return false;}
    try {
        // Source campaign_screen.gd::_resume_audio: independent, unguarded player.
        auto clip=p.load(p.resources.path("res://private-data/finale.wav"));
        const auto frames=clip->frames();
        const auto cursor=static_cast<std::size_t>(std::min(double(frames),seconds*p.rate));
        DeviceLock lock(p.device);
        p.mixer.finale={std::move(clip),cursor,0,frames,1,cursor<frames,false};
        p.error.clear();return true;
    } catch(const std::exception& error) {p.error=error.what();return false;}
}
void GameAudio::stop_finale() {DeviceLock lock(impl_->device);impl_->mixer.finale=MusicVoice{};}
void GameAudio::stop_effects() {auto& p=*impl_;p.pending.clear();DeviceLock lock(p.device);p.mixer.stop_effects();}
void GameAudio::fade_music(int ticks) {
    auto& p=*impl_;if(ticks<=0) {p.stop_music();return;}
    p.fade_duration=double(ticks)/50;p.fade_remaining=p.fade_duration;
    DeviceLock lock(p.device);p.fade_gain=p.mixer.music.gain;
}
bool GameAudio::toggle_original_music() {return impl_->state.music_enabled=!impl_->state.music_enabled;}
void GameAudio::set_effects_enabled(bool enabled) {impl_->state.effects_enabled=enabled;}
void GameAudio::reset() {
    auto& p=*impl_;stop_effects();p.stop_music();stop_finale();
    const auto random=p.state.random;p.state=Snapshot{};p.state.random=random;
    p.cabin_active=false;p.cabin_time=0;p.scene_time=0;p.clock=0;p.poses={};p.waits={};
}
void GameAudio::new_game_reset() {const bool music=impl_->state.music_enabled,effects=impl_->state.effects_enabled;reset();impl_->state.music_enabled=music;impl_->state.effects_enabled=effects;}
Snapshot GameAudio::snapshot() const {return impl_->state;}
bool GameAudio::validate_snapshot(const Snapshot& state,std::string& error) const {
    try {
        if(state.version!=2 || !state.random.valid() || !std::isfinite(state.elapsed) || state.elapsed<0) throw std::runtime_error("Invalid audio snapshot");
        if(!state.track.empty()) {const auto track=impl_->resources.track(state.track);if(!std::filesystem::is_regular_file(track.path)) throw std::runtime_error("Music file unavailable: "+track.path.string());}
        error.clear();return true;
    } catch(const std::exception& exception) {error=exception.what();return false;}
}
bool GameAudio::restore(const Snapshot& state,std::string& error) {
    if(!validate_snapshot(state,error)) return false;
    auto& p=*impl_;
    try {
        // Decode and validate all bounds before changing current music/preferences.
        if(!state.track.empty()) {const auto track=p.resources.track(state.track);auto clip=p.load(track.path);p.install(state.track,track,std::move(clip),state.elapsed);}
        else p.stop_music();
        stop_effects();stop_finale();p.state=state;p.cabin_active=false;p.cabin_time=0;p.scene_time=0;p.poses={};p.waits={};
        error.clear();p.error.clear();return true;
    } catch(const std::exception& exception) {error=exception.what();p.error=error;return false;}
}
int GameAudio::output_rate() const {return impl_->rate;}
std::size_t GameAudio::resident_bytes() const {DeviceLock lock(impl_->device);return impl_->mixer.resident_bytes();}
std::array<VoiceState,4> GameAudio::channels() const {
    DeviceLock lock(impl_->device);std::array<VoiceState,4> result{};
    for(std::size_t i=0;i<result.size();++i) {const auto& v=impl_->mixer.channels[i];result[i]={v.cursor,v.clip?v.clip->frames():0,v.priority,v.repeats,v.gain,v.playing};}
    return result;
}
MusicState GameAudio::music_state() const {
    DeviceLock lock(impl_->device);const auto& v=impl_->mixer.music;
    return {v.cursor,v.clip?v.clip->frames():0,v.loop_begin,v.loop_end,v.gain,v.playing,v.loop};
}
MusicState GameAudio::finale_state() const {
    DeviceLock lock(impl_->device);const auto& v=impl_->mixer.finale;
    return {v.cursor,v.clip?v.clip->frames():0,v.loop_begin,v.loop_end,v.gain,v.playing,v.loop};
}
void GameAudio::render_offline(float* output,std::size_t frames) {
    if(impl_->device) throw std::runtime_error("Offline render cannot share an active audio device");
    impl_->mixer.render(output,frames);impl_->mixer.collect_finished();
}
const std::string& GameAudio::last_error() const {return impl_->error;}
double GameAudio::score_position(double elapsed,double length,int rate,bool loop,std::size_t begin,std::size_t end) {
    const double first=double(begin)/rate,last=double(end)/rate;
    if(loop && last>first && elapsed>=last) return first+std::fmod(elapsed-first,last-first);
    return std::min(elapsed,length);
}
}
