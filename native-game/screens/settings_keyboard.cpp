// SPDX-License-Identifier: MIT
// Exact rows/hit regions/content: keyboard_settings.gd, keyboard_settings_button.gd.
#include "settings_keyboard.h"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
namespace transartica::panels {
namespace {
constexpr SDL_Color gold{238,202,136,255}; // artwork_presentation.gd GOLD.
constexpr SDL_FRect badge{130,128,59,17}; // keyboard_settings_button.gd BADGE.
}
KeyboardSettings::KeyboardSettings(Canvas& canvas,std::filesystem::path assets,input::KeyBindings& bindings)
    :canvas_(canvas),assets_(std::move(assets)),bindings_(bindings) {}
void KeyboardSettings::open() {selected_.reset();notice_="SELECT A COMMAND, THEN PRESS ITS NEW KEY";active_=true;}
SDL_FRect KeyboardSettings::frame() const {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    return {(canvas_.width()-320*scale)/2,(canvas_.height()-200*scale)/2,320*scale,200*scale};
}
SDL_FPoint KeyboardSettings::logical(float x,float y) const {const auto f=frame();return {(x-f.x)*320/f.w,(y-f.y)*200/f.h};}
SDL_FRect KeyboardSettings::row(std::size_t i) {return {15+float(i/6)*155,45+float(i%6)*19,140,17};}
void KeyboardSettings::text(float x,float baseline,std::string_view value,int size) {
    const auto f=frame();const float scale=f.w/320;
    canvas_.text(value,f.x+x*scale,f.y+(baseline-size)*scale,std::max(1,int(std::round(size*scale))),gold);
}
void KeyboardSettings::centered(float baseline,std::string_view value,int size) {
    const auto f=frame();const float scale=f.w/320;const auto width=canvas_.measure(value,std::max(1,int(std::round(size*scale)))).x;
    text((320-width/scale)/2,baseline,value,size);
}
bool KeyboardSettings::badge_hit(float x,float y) const {const auto p=logical(x,y);return SDL_PointInFRect(&p,&badge);}
void KeyboardSettings::draw_badge() {
    const auto f=frame();const float scale=f.w/320;
    const SDL_FRect box{f.x+badge.x*scale,f.y+badge.y*scale,badge.w*scale,badge.h*scale};
    int mx{},my{};const auto buttons=SDL_GetMouseState(&mx,&my);const bool hovered=badge_hit(float(mx),float(my));
    auto* renderer=canvas_.renderer();SDL_SetRenderDrawColor(renderer,hovered?61:12,hovered?74:29,hovered?82:39,255);
    render_check(SDL_RenderFillRectF(renderer,&box),"Keyboard badge");SDL_SetRenderDrawColor(renderer,gold.r,gold.g,gold.b,gold.a);
    const float edge=hovered&&(buttons&SDL_BUTTON_LMASK)?2:1;
    const SDL_FRect borders[]{{box.x,box.y,box.w,edge},{box.x,box.y+box.h-edge,box.w,edge},{box.x,box.y,edge,box.h},{box.x+box.w-edge,box.y,edge,box.h}};
    for(const auto border:borders)render_check(SDL_RenderFillRectF(renderer,&border),"Keyboard badge border");
    const auto width=canvas_.measure("KEYS",std::max(1,int(std::round(7*scale)))).x;
    text(badge.x+(badge.w-width/scale)/2,badge.y+badge.h-5,"KEYS");
}
void KeyboardSettings::draw() {
    if(!active_)return;const auto f=frame();auto* renderer=canvas_.renderer();
    SDL_SetRenderDrawColor(renderer,12,29,39,255);render_check(SDL_RenderClear(renderer),"Keyboard backdrop");
    render_check(SDL_RenderCopyF(renderer,canvas_.texture(assets_/"interface/inventory-frame.png"),nullptr,&f),"Keyboard frame");
    centered(29,"KEYBOARD SHORTCUTS",9);
    for(std::size_t i=0;i<input::commands().size();++i) {
        const auto box=row(i);
        if(selected_&&std::size_t(*selected_)==i) {
            const float scale=f.w/320;const SDL_FRect selected{f.x+box.x*scale,f.y+box.y*scale,box.w*scale,box.h*scale};
            SDL_SetRenderDrawColor(renderer,66,57,43,255);render_check(SDL_RenderFillRectF(renderer,&selected),"Selected keyboard command");
        }
        text(box.x+2,box.y+7,input::commands()[i].label);text(box.x+2,box.y+15,bindings_.key_label(input::Command(i)));
    }
    centered(168,notice_,6);text(20,187,"RESTORE DEFAULTS");text(268,187,"EXIT");
}
bool KeyboardSettings::handle(const SDL_Event& event) {
    if(!active_)return false;
    if(event.type==SDL_KEYDOWN&&!event.key.repeat) {
        if(event.key.keysym.scancode==SDL_SCANCODE_ESCAPE) {if(selected_)selected_.reset();else close();}
        else if(selected_) {
            std::string error;
            if(bindings_.assign(*selected_,event.key.keysym.scancode,error)) {notice_="SAVED";selected_.reset();}
            else notice_="KEY ALREADY USED OR SETTINGS COULD NOT BE SAVED";
        }
    }
    if(event.type==SDL_MOUSEBUTTONDOWN&&event.button.button==SDL_BUTTON_LEFT) {
        const auto p=logical(float(event.button.x),float(event.button.y));
        for(std::size_t i=0;i<input::commands().size();++i) {const auto box=row(i);if(SDL_PointInFRect(&p,&box))selected_=input::Command(i);}
        constexpr SDL_FRect defaults{15,176,125,20},exit{260,176,45,20};
        if(SDL_PointInFRect(&p,&defaults)) {std::string error;notice_=bindings_.defaults(error)?"DEFAULTS RESTORED":"COULD NOT SAVE SETTINGS";selected_.reset();}
        if(SDL_PointInFRect(&p,&exit))close();
    }
    return true;
}
}
