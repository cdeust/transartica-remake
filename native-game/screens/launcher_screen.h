// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "launcher/launcher.hpp"
#include "campaign/data.hpp"
#include "tactical_living.hpp"
#include "rocket_ignition.hpp"
namespace transartica::panels {
class LauncherMapHost {
public:
    virtual ~LauncherMapHost()=default;
    virtual void draw_launcher_map(Canvas&,const Session&,Cell camera,Point glide)=0;
    virtual void draw_launcher_target(Canvas&,const Session&,const world::EnemyTrain&,Cell camera,Point glide)=0;
};
class LauncherScreen {
public:
    LauncherScreen(Canvas&,std::filesystem::path assets,const Session&,launcher::Controller&,LauncherMapHost&,const campaign::Data&);
    void draw();
    bool handle_event(const SDL_Event&);
    void advance_visual(double seconds); // Host advances launcher controller first.
    void clear_visual();
    static Point flight_point(const launcher::Model&);
    static double rocket_offset(const launcher::Model&);
private:
    Canvas& canvas_;std::filesystem::path assets_;const Session& session_;launcher::Controller& controller_;LauncherMapHost& map_;const campaign::Data& data_;
    LivingEffects effects_;RocketIgnition ignition_;std::optional<Point> trail_;launcher::Phase phase_=launcher::Phase::Aim;int cursor_=-1,ascent_=-1;bool map_space_{};
    SDL_FRect frame()const;SDL_FRect rect(SDL_FRect)const;
    void text(float,float,std::string_view,int=7);
    void centered(float,std::string_view,int=7);
    void plate(std::string_view,SDL_FRect,const SDL_Rect* crop=nullptr,double angle=0);
    void controls(const launcher::Model&);
    void rocket(const launcher::Model&);
    void flight(const launcher::Model&);
};
}
