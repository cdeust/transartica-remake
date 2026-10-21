// SPDX-License-Identifier: MIT
// Source captain_event.gd, ROOM0x121/YODA0x27d8. Confirmation does not delete saves.
#include "captain_event.h"
#include "campaign/data.hpp"
#include <stdexcept>
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
namespace transartica::panels {
namespace {constexpr SDL_Color gold{238,202,136,255};}
CaptainEvent::CaptainEvent(Canvas& c,std::filesystem::path a):canvas_(c),assets_(std::move(a)){
    campaign::Data data;std::string error;if(!data.load(assets_.parent_path()/"data/campaign.json",error))throw std::runtime_error(error);epitaph_=data.message(100,true);
    if(epitaph_.size()!=10)throw std::runtime_error("Missing private captain epitaph100");
}
void CaptainEvent::prompt_revolver(){state_={CaptainMode::Confirm,{"IN ORDER TO COMMIT SUICIDE","PRESS THE LEFT BUTTON","OR THE RIGHT BUTTON TO CANCEL"}};armed_=false;}
void CaptainEvent::inform(std::vector<std::string> lines){state_={CaptainMode::Notice,std::move(lines)};armed_=false;}
void CaptainEvent::end_journey(){state_.mode=CaptainMode::Epitaph;armed_=false;}
void CaptainEvent::close(){state_={};armed_=false;}
bool CaptainEvent::restore(const CaptainState& value){if(int(value.mode)<0||int(value.mode)>int(CaptainMode::Earth))return false;state_=value;armed_=false;return true;}
SDL_FRect CaptainEvent::frame()const{float s=std::min(canvas_.width()/320.f,canvas_.height()/200.f);return {(canvas_.width()-320*s)/2,(canvas_.height()-200*s)/2,320*s,200*s};}
void CaptainEvent::centered(float baseline,std::string_view text){auto f=frame();float s=f.w/320;int pixels=std::max(1,int(std::round(7*s)));canvas_.text(text,f.x+(f.w-canvas_.measure(text,pixels).x)/2,f.y+(baseline-7)*s,pixels,gold);}
void CaptainEvent::draw(){
    if(!active())return;auto f=frame();auto* r=canvas_.renderer();float s=f.w/320;
    if(state_.mode==CaptainMode::Epitaph||state_.mode==CaptainMode::Earth){
        render_check(SDL_RenderCopyF(r,canvas_.texture(assets_/"interface/inventory-frame.png"),nullptr,&f),"Captain epitaph frame");
        if(state_.mode==CaptainMode::Earth){render_check(SDL_RenderCopyF(r,canvas_.texture(assets_/"interface/mort-earth.png"),nullptr,&f),"Captain Earth");return;}

        const int anchors[]{17,34,49,64,79,94,109,124,139,154};for(int i=0;i<10;++i)centered(anchors[i],epitaph_[i]);return;
    }
    SDL_FRect strip{f.x,f.y+159*s,f.w,41*s};SDL_SetRenderDrawColor(r,0,0,0,255);render_check(SDL_RenderFillRectF(r,&strip),"Captain notice");
    float e=.6f*s;const SDL_FRect borders[]{{strip.x,strip.y,strip.w,e},{strip.x,strip.y+strip.h-e,strip.w,e},{strip.x,strip.y,e,strip.h},{strip.x+strip.w-e,strip.y,e,strip.h}};
    SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,255);for(auto box:borders)render_check(SDL_RenderFillRectF(r,&box),"Captain notice border");
    for(std::size_t i=0;i<state_.lines.size();++i)centered(169+float(i)*9,state_.lines[i]);
}
CaptainAction CaptainEvent::advance(){
    if(state_.mode==CaptainMode::Epitaph){state_.mode=CaptainMode::Earth;return CaptainAction::None;}
    auto result=state_.mode==CaptainMode::Earth?CaptainAction::Options:CaptainAction::Dismissed;close();return result;
}
CaptainAction CaptainEvent::handle_event(const SDL_Event& event){
    if(!active())return CaptainAction::None;
    if(event.type==SDL_KEYDOWN){auto key=event.key.keysym.sym;
        if(state_.mode==CaptainMode::Confirm){if(key==SDLK_ESCAPE||key==SDLK_F1){close();return CaptainAction::Dismissed;}}
        else if(key==SDLK_SPACE||key==SDLK_RETURN||key==SDLK_ESCAPE)return advance();
    }
    if(event.type!=SDL_MOUSEBUTTONDOWN&&event.type!=SDL_MOUSEBUTTONUP)return CaptainAction::None;
    if(state_.mode==CaptainMode::Confirm&&event.type==SDL_MOUSEBUTTONDOWN){
        if(event.button.button==SDL_BUTTON_LEFT)return CaptainAction::Confirmed;
        if(event.button.button==SDL_BUTTON_RIGHT){close();return CaptainAction::Dismissed;}
    }else if(event.button.button==SDL_BUTTON_LEFT){if(event.type==SDL_MOUSEBUTTONDOWN)armed_=true;else if(armed_){armed_=false;return advance();}}
    return CaptainAction::None;
}
}
