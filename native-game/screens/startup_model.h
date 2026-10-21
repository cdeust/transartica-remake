// SPDX-License-Identifier: MIT
#pragma once
#include <vector>
namespace transartica::panels {
enum class StartupAudioKind {PublisherEffect,ReceptionMusic,FadeMusic};
struct StartupAudio {StartupAudioKind kind;int value{};};
// Source startup_intro.gd: MAIN573..645, PRESENT and PRESENT2 original waits.
class StartupTimeline {
public:
    static constexpr int hz=50,publisher_end=252,title_ready=360,title_timeout=30000,exit_fade=60;
    void start();
    void advance(double seconds);
    void step();
    bool request_exit();
    bool active() const {return active_;}
    bool done() const {return !active_;}
    int tick() const {return tick_;}
    int exit_tick() const {return exit_tick_;}
    std::vector<StartupAudio> take_audio();
private:
    int tick_{},exit_tick_=-1;double remainder_{};bool active_{};
    std::vector<StartupAudio> audio_;
};
}
