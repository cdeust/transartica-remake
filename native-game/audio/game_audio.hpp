// SPDX-License-Identifier: MIT
#pragma once
#include "core/random.hpp"
#include "mixer.hpp"
#include <filesystem>
#include <map>
#include <memory>
#include <string>

namespace transartica::audio {
struct AudioConfig {
    bool open_device=true;
    std::size_t resident_budget_bytes{}; // Required allocation budget from owner.
    int device_rate{}; // Zero uses the delivered orchestral masters' 44100 Hz.
};
struct EngineAudioState {
    int lignite{},anthracite{},lignite_rate{},anthracite_rate{},speed{},pressure_reserve{};
    bool cabin_visible{},oslo_visible{};
};
struct Snapshot {
    int version=2; // Native state adds an independent persisted audio RNG.
    bool music_enabled=true,effects_enabled=true,alternate{};
    std::string track;
    double elapsed{};
    Random random;
    bool operator==(const Snapshot&) const = default;
};
// Non-owning diagnostics: querying playback cannot prolong PCM residency.
struct VoiceState {
    std::size_t cursor{},frames{};int priority{},repeats{};float gain{};bool playing{};
    bool operator==(const VoiceState&) const = default;
};
struct MusicState {std::size_t cursor{},frames{},loop_begin{},loop_end{};float gain{};bool playing{},loop{};};
class GameAudio {
public:
    GameAudio(const std::filesystem::path& game_directory,AudioConfig,std::uint64_t seed);
    ~GameAudio();
    GameAudio(const GameAudio&)=delete;
    GameAudio& operator=(const GameAudio&)=delete;
    int sample(const std::string& script,int resource,int priority,int volume,int repeat,int frequency);
    int effect(const std::string& script,int offset,const std::map<int,int>& locals={});
    int son(int selector,int pitch=0,bool long_ambient=true);
    bool play_track(const std::string& key,bool guard_preference=true);
    void play_reception();
    void play_journey(bool synthesized_music=true);
    void play_city(int signed_kind,int city_index=-1);
    void play_worksite();
    void play_loss();
    bool play_finale(double seconds=0);
    void stop_finale();
    void stop_effects();
    void fade_music(int ticks);
    void advance(double seconds,const EngineAudioState&);
    bool toggle_original_music();
    void set_effects_enabled(bool);
    void new_game_reset();
    void reset();
    Snapshot snapshot() const;
    bool validate_snapshot(const Snapshot&,std::string& error) const;
    bool restore(const Snapshot&,std::string& error);
    int output_rate() const;
    std::size_t resident_bytes() const;
    std::array<VoiceState,4> channels() const;
    MusicState music_state() const;
    MusicState finale_state() const;
    // Offline tests only; refuses while a real audio callback owns the mixer.
    void render_offline(float* stereo,std::size_t frames);
    const std::string& last_error() const;
    static double score_position(double elapsed,double length,int source_rate,bool loop,std::size_t begin,std::size_t end);
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
}
