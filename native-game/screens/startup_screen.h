// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "startup_model.h"
namespace transartica::panels {
// Start only for game_boot's play_startup_intro=true (production main.tscn).
// Host shields its shortcuts, pauses the game, dispatches take_audio events and
// resumes OPTIONS after done(). Audio itself continues advancing during boot.
class StartupIntro {
public:
    StartupIntro(Canvas&,const std::filesystem::path& game_directory);
    void start() {timeline_.start();}
    bool bypass() {return timeline_.request_exit();} // Source title-ready guard.
    bool active() const {return timeline_.active();}
    bool done() const {return timeline_.done();}
    int tick() const {return timeline_.tick();}
    void advance(double seconds) {timeline_.advance(seconds);}
    bool handle(const SDL_Event&);
    void draw();
    std::vector<StartupAudio> take_audio() {return timeline_.take_audio();}
private:
    Canvas& canvas_;std::filesystem::path artwork_;StartupTimeline timeline_;
    std::string title_;std::vector<std::string> credits_;
    void centered(float baseline,std::string_view,int size);
};
}
