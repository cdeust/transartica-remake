// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "core/track_works.hpp"
#include "world_event_screen.h"
#include <map>

namespace transartica::panels {
enum class WorkAction { None, Accept, Decline, Dismiss };
class WorkScreen {
public:
    WorkScreen(Canvas&,std::filesystem::path assets);
    void advance(double seconds,const TrackWorks&);
    void draw(const TrackWorks&);
    WorkAction handle(const SDL_Event&,const TrackWorks&) const;
private:
    Canvas& canvas_;
    std::filesystem::path assets_;
    WorksiteAmbience ambience_;
    std::map<int,std::vector<std::string>> messages_;
    SDL_FRect frame() const;
    SDL_FRect rect(SDL_FRect) const;
    void panel(SDL_FRect,SDL_Color);
    void centered(float baseline,std::string_view,int size=6);
    void button(SDL_FRect,std::string_view);
    std::vector<std::string> lines(const TrackWorks&) const;
};
}
