// SPDX-License-Identifier: MIT
// Positions, typography and text: engine_room_controls.gd::_draw_help.
#include "help_overlay.h"
#include "view/render_check.h"
#include <algorithm>
#include <array>
#include <cmath>
namespace transartica::panels {
bool HelpOverlay::handle(const SDL_Event& event) {
    if(!active_)return false;
    if(event.type==SDL_MOUSEBUTTONDOWN) {close();return true;}
    if(event.type!=SDL_KEYDOWN||event.key.repeat)return false;
    const auto key=bindings_.canonical(event.key).keysym.sym;
    // F1 alias explicitly requested for the standalone host; source default is H.
    if(key==SDLK_ESCAPE||key==SDLK_F1||key==SDLK_h) {close();return true;}
    return false;
}
void HelpOverlay::draw() {
    if(!active_)return;
    // Same1600x1000 authored coordinate system as View::cabin and controls.
    const float scale=std::min(canvas_.width()/1600.f,canvas_.height()/1000.f);
    const float left=(canvas_.width()-1600*scale)/2,top=(canvas_.height()-1000*scale)/2;
    const SDL_FRect box{left+370*scale,top+330*scale,860*scale,348*scale};auto* renderer=canvas_.renderer();
    // Source normalized fill(.035,.055,.07,.97) quantized to RGBA8.
    SDL_SetRenderDrawBlendMode(renderer,SDL_BLENDMODE_BLEND);SDL_SetRenderDrawColor(renderer,9,14,18,247);
    render_check(SDL_RenderFillRectF(renderer,&box),"Help panel");
    constexpr SDL_Color gold{235,189,112,255};SDL_SetRenderDrawColor(renderer,gold.r,gold.g,gold.b,gold.a);
    const float edge=2*scale;const SDL_FRect borders[]{{box.x,box.y,box.w,edge},{box.x,box.y+box.h-edge,box.w,edge},{box.x,box.y,edge,box.h},{box.x+box.w-edge,box.y,edge,box.h}};
    for(auto border:borders)render_check(SDL_RenderFillRectF(renderer,&border),"Help border");
    using input::Command;const auto label=[&](Command command){return bindings_.key_label(command);};
    const std::array<std::string,8> lines{"THE ENGINE ROOM",
        "1. Click each stoker to feed the fire: OFF / NORMAL / FAST.",
        "2. Drag the wheel above the furnace to set the regulator.",
        "3. Build steam; speed rises when the reserve is sufficient.",
        "4. Apply the brake with "+label(Command::Brake)+" or the lever in the lower panel.",
        label(Command::Pause)+": pause · "+label(Command::Save)+": save · "+label(Command::Options)+": options · Esc: close",
        "Lignite is also money. Leaving the stokers on spends your reserves.",
        label(Command::Map)+": open the railway map · use the clock to accelerate time."};
    for(std::size_t i=0;i<lines.size();++i) {
        const int size=i==0?20:17;
        canvas_.text(lines[i],left+394*scale,top+(370+float(i)*38-size)*scale,std::max(1,int(std::round(size*scale))),gold);
    }
}
}
