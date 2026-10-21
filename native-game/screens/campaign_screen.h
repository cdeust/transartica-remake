// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "campaign/controller.hpp"
namespace transartica::panels {
// Host draws the shared footer before this overlay for quarters scenes only.
class CampaignScreen {
public:
    CampaignScreen(Canvas&,std::filesystem::path,campaign::Controller&);
    ~CampaignScreen();
    void draw();
    bool handle_event(const SDL_Event&);
private:
    Canvas& canvas_;
    std::filesystem::path assets_;
    campaign::Controller& controller_;
    bool text_input_{};
    SDL_FRect frame() const;
    SDL_FRect rectangle(float,float,float,float) const;
    void sync_input();
    void plate(const std::filesystem::path&,bool contain=false);
    void centered(float,std::string_view);
    void choice(SDL_FRect,SDL_FRect,std::string_view,bool focused=false);
    void draw_page();
    void draw_finale();
    void effect(SDL_FRect,int);
    void key(SDL_Keycode);
};
}
