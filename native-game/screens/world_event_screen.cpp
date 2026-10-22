// SPDX-License-Identifier: MIT
// Sources: world_event_screen.gd, roamer_screen.gd, world_session.restore_roamers,
// world_actions.ask_mine, worksite_ambience.gd. No simulation state lives here.
#include "world_event_screen.h"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>
namespace transartica::panels {
namespace {constexpr SDL_Color gold{238,202,136,255};}
void WorksiteAmbience::clear(){effects_.clear();time_=0;emitted_phase_=-1;scene_key_.clear();}
void WorksiteAmbience::advance(double seconds,std::string_view mode,bool working){
    if(!std::isfinite(seconds)||seconds<=0)return;
    auto key=std::string(mode)+(working?"/true":"/false");if(key!=scene_key_){clear();scene_key_=std::move(key);}
    time_+=seconds;effects_.advance(seconds);int phase=int(time_/.75);
    if(working&&phase!=emitted_phase_){emitted_phase_=phase;Point point=mode=="mine"?Point{104,116}:Point{158,105};effects_.add("dust",point,{0,-1},.55);if(mode!="mine")effects_.add("sparks",point,{0,-1},.35);}
}
void WorksiteAmbience::draw(Canvas& canvas,std::string_view mode){
    // Measured lamps and source8Hz fire poses: worksite_ambience.gd.
    const Point mine[]{{61,82},{170,96},{264,96}},work[]{{46,84},{209,81}};
    auto name="flame-"+std::to_string(int(time_*8)%4);
    if(mode=="mine")for(auto p:mine)effects_.draw_atlas(canvas,name,p,{4,6},{255,166,64,115});
    else for(auto p:work)effects_.draw_atlas(canvas,name,p,{4,6},{255,166,64,115});
    effects_.draw(canvas);
}
WorldEventScreen::WorldEventScreen(Canvas& canvas,std::filesystem::path assets):canvas_(canvas),assets_(std::move(assets)),ambience_(assets_){}
SDL_FRect WorldEventScreen::frame()const{float s=std::min(canvas_.width()/320.f,canvas_.height()/200.f);return {(canvas_.width()-320*s)/2,(canvas_.height()-200*s)/2,320*s,200*s};}
SDL_FRect WorldEventScreen::rect(SDL_FRect r)const{auto f=frame();float s=f.w/320;return {f.x+r.x*s,f.y+r.y*s,r.w*s,r.h*s};}
bool WorldEventScreen::active(const world::WorldActionState& mine,const world::RoamerState& r){return mine.pending_mine>=0||(!r.pending.empty()&&r.pending!="nomad_trade");}
bool WorldEventScreen::question(const world::WorldActionState& mine,const world::RoamerState& r){return mine.pending_mine>=0?mine.mine_phase=="question":r.pending=="nomad_question"||r.pending=="herd_question";}
void WorldEventScreen::advance(double seconds,const world::WorldActionState& mine,const world::RoamerState& roamer){
    if(!active(mine,roamer)){ambience_.clear();return;}
    if(mine.pending_mine>=0)ambience_.advance(seconds,"mine",mine.mine_phase=="result");else ambience_.clear();
}
campaign::Lines WorldEventScreen::lines(const world::WorldActionState& mine,const world::RoamerState& roamer,const campaign::Data& data){
    if(mine.pending_mine>=0){
        if(mine.pending_mine>=int(mine.mines.size()))throw std::runtime_error("Mine presentation slot out of range");
        const auto& record=mine.mines[mine.pending_mine];std::string ore=record.signed_day<0?"ANTHRACITE":"LIGNITE";
        if(mine.mine_phase=="question")return {"YOU COME ACROSS A MINE","PROSPECT?"};
        if(mine.mine_phase=="resources")return {"AVAILABLE RESOURCES:",std::to_string(mine.resources.slaves)+" SLAVE(S)",std::to_string(mine.resources.mammoths)+" MAMMOTH(S)  "+std::to_string(mine.resources.cranes)+" CRANE(S)"};
        if(mine.mine_phase=="result")return {"RESULT OF WORKINGS",std::to_string(mine.quantity)+" BAKS OF "+ore};
        return {ore+" MINE OF THE YEAR 2714","WEALTH INDEX: "+std::to_string(record.wealth)};
    }
    if(roamer.pending=="nomad_question")return data.message(27);
    if(roamer.pending=="herd_question")return data.message(23);
    if(roamer.pending=="hunt_commissioned"){auto text=data.message(73);text.push_back(std::to_string(roamer.commissioned[1])+" SLAVES");text.push_back(std::to_string(roamer.commissioned[2])+" SOLDIERS");return text;}
    if(roamer.pending=="hunt_result"){
        auto text=data.message(83);if(text.size()!=5)throw std::runtime_error("Missing source hunt plaque83");
        return {text[0],text[1]+std::to_string(roamer.hunt_quantity),text[2]+std::to_string(roamer.commissioned[0]),text[3]+std::to_string(roamer.caught)+text[4]};
    }
    return {};
}
void WorldEventScreen::panel(SDL_FRect logical,SDL_Color fill){
    auto box=rect(logical);auto* r=canvas_.renderer();SDL_SetRenderDrawColor(r,fill.r,fill.g,fill.b,fill.a);render_check(SDL_RenderFillRectF(r,&box),"World event panel");
    SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,255);render_check(SDL_RenderDrawRectF(r,&box),"World event border");
}
void WorldEventScreen::centered(float baseline,std::string_view text){
    auto f=frame();float s=f.w/320;int pixels=std::max(1,int(std::round(6*s)));auto size=canvas_.measure(text,pixels);
    canvas_.text(text,f.x+(f.w-size.x)/2,f.y+(baseline-6)*s,pixels,gold);
}
void WorldEventScreen::button(SDL_FRect box,std::string_view label){
    panel(box,{60,52,41,255});auto f=frame();float s=f.w/320;
    canvas_.text(label,f.x+(box.x+7)*s,f.y+(box.y+4)*s,std::max(1,int(std::round(6*s))),gold);
}
void WorldEventScreen::scene(std::string_view name,bool contain){
    auto* texture=canvas_.texture(assets_/"world-events"/(std::string(name)+".png"));int w,h;render_check(SDL_QueryTexture(texture,nullptr,nullptr,&w,&h),"World event art dimensions");
    auto box=rect({0,39,320,110});float scale=contain?std::min(box.w/w,box.h/h):std::max(box.w/w,box.h/h);
    if(contain){box={box.x+(box.w-w*scale)/2,box.y+(box.h-h*scale)/2,w*scale,h*scale};render_check(SDL_RenderCopyF(canvas_.renderer(),texture,nullptr,&box),"Roamer art");return;}
    float u=(w-box.w/scale)/2/w,v=(h-box.h/scale)/2/h;constexpr SDL_Color white{255,255,255,255};
    const SDL_Vertex vertices[]{{{box.x,box.y},white,{u,v}},{{box.x+box.w,box.y},white,{1-u,v}},{{box.x+box.w,box.y+box.h},white,{1-u,1-v}},{{box.x,box.y+box.h},white,{u,1-v}}};
    constexpr int indices[]{0,1,2,0,2,3};render_check(SDL_RenderGeometry(canvas_.renderer(),texture,vertices,4,indices,6),"Mine cover art");
}
void WorldEventScreen::draw(const world::WorldActionState& mine,const world::RoamerState& roamer,const campaign::Data& data){
    if(!active(mine,roamer))return;auto box=rect({0,0,320,149});auto* r=canvas_.renderer();SDL_SetRenderDrawColor(r,12,29,39,255);render_check(SDL_RenderFillRectF(r,&box),"World event backdrop");
    bool is_mine=mine.pending_mine>=0;scene(is_mine?"mine":roamer.pending=="nomad_question"?"nomads":"mammoth-hunt",!is_mine);
    if(is_mine)ambience_.draw(canvas_,"mine");panel({1,1,318,37},{20,45,57,255});auto text=lines(mine,roamer,data);
    float first=text.size()>2?11:15;for(std::size_t i=0;i<text.size();++i)centered(first+float(i)*8,text[i]);
    if(question(mine,roamer))button({120,124,32,14},"NO");button({170,124,32,14},"OK");
}
WorldEventAction WorldEventScreen::handle_event(const SDL_Event& event,const world::WorldActionState& mine,const world::RoamerState& roamer)const{
    if(!active(mine,roamer))return WorldEventAction::None;bool ask=question(mine,roamer);
    if(event.type==SDL_KEYDOWN&&!event.key.repeat){
        if(event.key.keysym.sym==SDLK_RETURN||event.key.keysym.sym==SDLK_KP_ENTER)return ask?WorldEventAction::Accept:WorldEventAction::Dismiss;
        if(event.key.keysym.sym==SDLK_ESCAPE)return ask?WorldEventAction::Decline:WorldEventAction::None;
    }
    if(event.type!=SDL_MOUSEBUTTONDOWN||event.button.button!=SDL_BUTTON_LEFT)return WorldEventAction::None;
    auto f=frame();if(f.w<=0)return WorldEventAction::None;SDL_FPoint p{(event.button.x-f.x)*320/f.w,(event.button.y-f.y)*200/f.h};
    constexpr SDL_FRect yes{170,124,32,14},no{120,124,32,14};
    if(SDL_PointInFRect(&p,&yes))return ask?WorldEventAction::Accept:WorldEventAction::Dismiss;
    return ask&&SDL_PointInFRect(&p,&no)?WorldEventAction::Decline:WorldEventAction::None;
}
}
