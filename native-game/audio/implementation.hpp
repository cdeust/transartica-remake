// SPDX-License-Identifier: MIT
#pragma once
#include "game_audio.hpp"
#include "resources.hpp"
#include <SDL.h>

namespace transartica::audio {
struct DeviceLock {
    SDL_AudioDeviceID device;
    explicit DeviceLock(SDL_AudioDeviceID id):device(id) {if(device) SDL_LockAudioDevice(device);}
    ~DeviceLock() {if(device) SDL_UnlockAudioDevice(device);}
};
struct GameAudio::Impl {
    Resources resources;
    AudioConfig config;
    Mixer mixer;
    Snapshot state;
    SDL_AudioDeviceID device{};
    bool owns_subsystem{};
    int rate{};
    std::string error;
    double fade_remaining{},fade_duration{},fade_gain{};
    bool cabin_active{};
    double cabin_time{},scene_time{},clock{};
    std::array<int,2> poses{},waits{};
    struct Pending {double due;int offset;};
    std::vector<Pending> pending;
    Impl(const std::filesystem::path& game,AudioConfig options,std::uint64_t seed):resources(game),config(options) {state.random.seed(seed);}
    ~Impl();
    void open();
    std::shared_ptr<const Clip> load(const std::filesystem::path&,int numerator=1,int denominator=1);
    bool install(const std::string&,const Track&,std::shared_ptr<const Clip>,double elapsed);
    void stop_music();
    void advance_engine(GameAudio&,double,const EngineAudioState&);
    void advance_scene(GameAudio&,double,const EngineAudioState&);
    void advance_score(double);
    static void callback(void*,Uint8*,int) noexcept;
};
}
