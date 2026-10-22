// SPDX-License-Identifier: MIT
// Source: game/scripts/save_book.gd ROOM0x055e bottom strip and OPTION full frame;
// save_slots.gd / boudoir_actions.gd ROOM0x06a6 first-letter and eight-char rules.
#include "save_book.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace transartica::panels {
namespace {
constexpr SDL_Color gold{238,202,136,255}; // artwork_presentation.gd GOLD.
void checked(int result){if(result<0) throw std::runtime_error(std::string("Save book draw: ")+SDL_GetError());}
}
SaveBook::SaveBook(Canvas& canvas,std::filesystem::path assets):canvas_(canvas),assets_(std::move(assets)){}
SaveBook::~SaveBook(){if(active_)close();}
SDL_FRect SaveBook::frame() const {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    return {(canvas_.width()-320*scale)*.5f,(canvas_.height()-200*scale)*.5f,320*scale,200*scale};
}
void SaveBook::open(bool loading) {
    loading_=loading;active_=true;selected_=false;name_.clear();status_.clear();caret_=0;
    SDL_StartTextInput();
}
void SaveBook::close(){active_=false;selected_=false;SDL_StopTextInput();}
std::string SaveBook::normalize(std::string_view raw) {
    std::string result;
    // Accepted characters are ASCII; every byte of a non-ASCII UTF-8 scalar is
    // rejected, matching the source Unicode predicate without truncating UTF-8.
    for(unsigned char c:raw) {
        if(c==8){if(!result.empty())result.pop_back();continue;}
        if(c>='a' && c<='z')c=static_cast<unsigned char>(c-'a'+'A');
        const bool letter=c>='A' && c<='Z',digit=c>='0' && c<='9';
        if(result.size()<8 && (letter || (digit && !result.empty())))result.push_back(char(c));
    }
    return result;
}
void SaveBook::insert(std::string_view raw) {
    if(selected_){name_.clear();caret_=0;selected_=false;}
    // Source LineEdit inserts first, then text_changed normalizes the entire
    // candidate and clamps its caret to the resulting ASCII length.
    const auto inserted=std::count_if(raw.begin(),raw.end(),[](unsigned char c){return (c&0xc0)!=0x80;});
    name_.insert(caret_,raw);caret_+=std::size_t(inserted);name_=normalize(name_);caret_=std::min(caret_,name_.size());status_.clear();
}
std::optional<std::string> SaveBook::handle_event(const SDL_Event& event) {
    if(!active_)return {};
    if(event.type==SDL_TEXTINPUT){insert(event.text.text);return {};}
    if(event.type==SDL_MOUSEBUTTONDOWN && event.button.button==SDL_BUTTON_LEFT) {
        const auto bounds=frame();const float scale=bounds.w/320;
        const float baseline=bounds.y+(loading_?109:183)*scale;
        if(scale<=0 || event.button.y<baseline-11*scale || event.button.y>baseline+3*scale)return {};
        const float x=event.button.x-(bounds.x+135*scale);
        const int pixels=std::max(1,int(std::round(7*scale)));
        if(x<0 || x>64*scale)return {};
        caret_=name_.size();selected_=false;
        float prior=0;
        for(std::size_t i=1;i<=name_.size();++i){const float next=canvas_.measure(std::string_view(name_).substr(0,i),pixels).x;if(x<(prior+next)*.5f){caret_=i-1;break;}prior=next;}
        return {};
    }
    if(event.type!=SDL_KEYDOWN)return {};
    const auto key=event.key.keysym.sym;
    if(key==SDLK_F1 || key==SDLK_ESCAPE){close();return {};}
    if(key==SDLK_RETURN || key==SDLK_KP_ENTER){if(!event.key.repeat && !name_.empty())return name_;return {};}
    if(key==SDLK_a && (event.key.keysym.mod&(KMOD_CTRL|KMOD_GUI))){selected_=true;caret_=name_.size();return {};}
    if(key==SDLK_BACKSPACE || key==SDLK_DELETE) {
        if(selected_){name_.clear();caret_=0;selected_=false;}
        else if(key==SDLK_BACKSPACE && caret_){name_.erase(--caret_,1);}
        else if(key==SDLK_DELETE && caret_<name_.size()){name_.erase(caret_,1);}
        name_=normalize(name_);caret_=std::min(caret_,name_.size());status_.clear();return {};
    }
    if(key==SDLK_HOME){caret_=0;selected_=false;}
    if(key==SDLK_END){caret_=name_.size();selected_=false;}
    if(key==SDLK_LEFT){caret_=selected_?0:caret_?caret_-1:0;selected_=false;}
    if(key==SDLK_RIGHT){caret_=selected_?name_.size():std::min(caret_+1,name_.size());selected_=false;}
    return {};
}
void SaveBook::draw() {
    if(!active_)return;
    const auto bounds=frame();const float scale=bounds.w/320;
    auto* r=canvas_.renderer();const int pixels=std::max(1,int(std::round(7*scale)));
    if(loading_) {
        SDL_SetRenderDrawColor(r,12,29,39,255);checked(SDL_RenderClear(r));
        checked(SDL_RenderCopyF(r,canvas_.texture(assets_/"interface/inventory-frame.png"),nullptr,&bounds));
    } else {
        SDL_FRect strip{bounds.x,bounds.y+159*scale,bounds.w,41*scale};
        SDL_SetRenderDrawColor(r,0,0,0,255);checked(SDL_RenderFillRectF(r,&strip));
        SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,gold.a);
        const float edge=.6f*scale; // save_book.gd outline width.
        const SDL_FRect borders[]{{strip.x,strip.y,strip.w,edge},{strip.x,strip.y+strip.h-edge,strip.w,edge},{strip.x,strip.y,edge,strip.h},{strip.x+strip.w-edge,strip.y,edge,strip.h}};
        for(auto box:borders)checked(SDL_RenderFillRectF(r,&box));
    }
    const auto at=[&](float x,float baseline,std::string_view text){canvas_.text(text,bounds.x+x*scale,bounds.y+(baseline-7)*scale,pixels,gold);};
    const auto centered=[&](float baseline,std::string_view text){const auto width=canvas_.measure(text,pixels).x;canvas_.text(text,bounds.x+(bounds.w-width)*.5f,bounds.y+(baseline-7)*scale,pixels,gold);};
    const float top=loading_?69:167,baseline=loading_?109:183;
    centered(top,"ENTER THE NAME OF YOUR BACKUP");centered(top+(loading_?20:8),"THEN PRESS RETURN:");
    centered(loading_?129:191,status_.empty()?std::string_view("TO CANCEL TYPE F1"):std::string_view(status_));
    at(121,baseline,"(");
    const float width=canvas_.measure(name_,pixels).x;
    if(selected_ && !name_.empty()){
        SDL_SetRenderDrawColor(r,77,132,147,160);const SDL_FRect selection{bounds.x+135*scale,bounds.y+(baseline-7)*scale,width,canvas_.measure(name_,pixels).y};checked(SDL_RenderFillRectF(r,&selection));
    }
    at(135,baseline,name_);
    // New standalone schema uses .native; never label it as a legacy .SAV file.
    canvas_.text(".native )",bounds.x+135*scale+width,bounds.y+(baseline-7)*scale,pixels,gold);
    const float x=bounds.x+135*scale+canvas_.measure(std::string_view(name_).substr(0,caret_),pixels).x;
    SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,gold.a);
    checked(SDL_RenderDrawLineF(r,x,bounds.y+(baseline-7)*scale,x,bounds.y+(baseline+1)*scale));
    const SDL_Rect input{int(bounds.x+135*scale),int(bounds.y+(baseline-7)*scale),int(64*scale),int(11*scale)};
    SDL_SetTextInputRect(&input);
}
}
