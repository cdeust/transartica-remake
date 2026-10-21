// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "world/world_actions.hpp"
#include "world/world_roamers.hpp"
#include "campaign/data.hpp"
#include "tactical_living.hpp"
namespace transartica::panels {
class WorksiteAmbience {
public:
    explicit WorksiteAmbience(std::filesystem::path assets):effects_(std::move(assets)){}
    void clear();
    void advance(double seconds,std::string_view mode,bool working);
    void draw(Canvas&,std::string_view mode);
private:
    LivingEffects effects_;
    double time_{};
    int emitted_phase_=-1;
    std::string scene_key_;
};
enum class WorldEventAction {None,Accept,Decline,Dismiss};
class WorldEventScreen {
public:
    WorldEventScreen(Canvas&,std::filesystem::path assets);
    void advance(double seconds,const world::WorldActionState&,const world::RoamerState&);
    void draw(const world::WorldActionState&,const world::RoamerState&,const campaign::Data&);
    WorldEventAction handle_event(const SDL_Event&,const world::WorldActionState&,const world::RoamerState&) const;
    static bool active(const world::WorldActionState&,const world::RoamerState&);
private:
    Canvas& canvas_;std::filesystem::path assets_;WorksiteAmbience ambience_;
    SDL_FRect frame() const;
    SDL_FRect rect(SDL_FRect) const;
    void panel(SDL_FRect,SDL_Color);
    void button(SDL_FRect,std::string_view);
    void centered(float,std::string_view);
    void scene(std::string_view,bool contain);
    static bool question(const world::WorldActionState&,const world::RoamerState&);
    static campaign::Lines lines(const world::WorldActionState&,const world::RoamerState&,const campaign::Data&);
};
}
