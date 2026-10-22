// SPDX-License-Identifier: MIT
// Source launcher_scene.gd BERTA form8 and authored launcher plates.
#include "launcher_screen.h"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
#include <numbers>
#include <cstdio>
#include <cctype>
namespace transartica::panels {
namespace {
constexpr SDL_Color gold{238,202,136,255};
constexpr SDL_FRect hotspots[]{{245,15,7,7},{245,31,7,7},{261,17,6,14},{269,17,6,14},{277,17,6,14},{285,17,6,14},{261,40,15,15},{285,40,15,14}};
class Clip {
public:
    Clip(SDL_Renderer* r,SDL_Rect next):r_(r),enabled_(SDL_RenderIsClipEnabled(r)){SDL_RenderGetClipRect(r,&old_);render_check(SDL_RenderSetClipRect(r,&next),"Launcher clip");}
    ~Clip(){SDL_RenderSetClipRect(r_,enabled_?&old_:nullptr);}
private:SDL_Renderer* r_;SDL_bool enabled_;SDL_Rect old_{};
};
}
LauncherScreen::LauncherScreen(Canvas& c,std::filesystem::path a,const Session& s,launcher::Controller& controller,LauncherMapHost& map,const campaign::Data& data)
    :canvas_(c),assets_(std::move(a)),session_(s),controller_(controller),map_(map),data_(data),effects_(assets_){}
SDL_FRect LauncherScreen::frame()const{float s=std::min(canvas_.width()/320.f,canvas_.height()/200.f);return {(canvas_.width()-320*s)/2,(canvas_.height()-200*s)/2,320*s,200*s};}
SDL_FRect LauncherScreen::rect(SDL_FRect r)const{auto f=frame();float s=f.w/320;return {f.x+r.x*s,f.y+r.y*s,r.w*s,r.h*s};}
void LauncherScreen::text(float x,float y,std::string_view value,int size){auto f=frame();float s=f.w/320;canvas_.text(value,f.x+x*s,f.y+(y-size)*s,std::max(1,int(std::round(size*s))),gold);}
void LauncherScreen::centered(float y,std::string_view value,int size){auto f=frame();float s=f.w/320;int pixels=std::max(1,int(std::round(size*s)));canvas_.text(value,f.x+(f.w-canvas_.measure(value,pixels).x)/2,f.y+(y-size)*s,pixels,gold);}
void LauncherScreen::plate(std::string_view path,SDL_FRect box,const SDL_Rect* crop,double angle){auto dest=rect(box);render_check(SDL_RenderCopyExF(canvas_.renderer(),canvas_.texture(assets_/path),crop,&dest,angle,nullptr,SDL_FLIP_NONE),"Launcher artwork");}
void LauncherScreen::controls(const launcher::Model& m){
    auto* r=canvas_.renderer();auto box=rect({211,7,100,64});SDL_SetRenderDrawColor(r,23,43,52,255);render_check(SDL_RenderFillRectF(r,&box),"Launcher controls");plate("interface/inventory-frame.png",{211,7,100,64});
    char bearing[16];std::snprintf(bearing,sizeof(bearing),"%03d°",launcher::angle(m.bearing));text(216,28,bearing);
    for(int i=0;i<8;++i){auto logical=hotspots[i];box=rect(logical);SDL_SetRenderDrawColor(r,52,71,83,255);render_check(SDL_RenderFillRectF(r,&box),"Launcher hotspot");SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,255);render_check(SDL_RenderDrawRectF(r,&box),"Launcher hotspot edge");
        if(i<2){float direction=i==0?-1:1;auto f=frame();float s=f.w/320,x=box.x+box.w/2,y=box.y+box.h/2;const SDL_Vertex vertices[]{{{x-2*s,y-direction*s},gold,{}},{{x+2*s,y-direction*s},gold,{}},{{x,y+2*direction*s},gold,{}}};render_check(SDL_RenderGeometry(r,nullptr,vertices,3,nullptr,0),"Launcher bearing arrow");}
        else if(i<6)text(logical.x+1,logical.y+9,std::to_string(m.digits[i-2]),5);
        else text(logical.x+1,logical.y+9,i==6?"ARM":"FIRE",4);
    }
    if(m.phase==launcher::Phase::Armed||m.phase==launcher::Phase::Arming){box=rect(hotspots[6]);SDL_SetRenderDrawColor(r,255,225,160,255);render_check(SDL_RenderDrawRectF(r,&box),"Launcher armed edge");}
    auto phase=launcher::phase_name(m.phase);for(char& c:phase)c=char(std::toupper(static_cast<unsigned char>(c)));text(216,65,phase,5);
}
void LauncherScreen::rocket(const launcher::Model& m){
    constexpr SDL_Rect body{398,29,228,1402};float width=96.f*228/1402;plate("interface/launcher-rocket.png",{141-width/2,7-float(rocket_offset(m)),width,96},&body);
    if(m.phase==launcher::Phase::Arming||m.phase==launcher::Phase::Armed||m.phase==launcher::Phase::Disarming){
        float pose=m.phase==launcher::Phase::Armed?1:m.cursor/4.f;if(m.phase==launcher::Phase::Disarming)pose=1-pose;float length=10+37*pose;
        constexpr SDL_Rect beam{751,72,340,35};for(int y:{55,91})plate("interface/launcher.png",{188-length,float(y),length,3},&beam);
    }
}
void LauncherScreen::flight(const launcher::Model& m){
    Point glide=m.phase==launcher::Phase::Flight&&m.scroll_left>0?point(m.scroll)*(std::clamp(m.accumulator/(3.0/50),0.0,1.0)*16):Point{};
    map_.draw_launcher_map(canvas_,session_,m.camera,glide);
    if(m.geometry&&m.geometry->record&&m.phase==launcher::Phase::Flight)map_.draw_launcher_target(canvas_,session_,*m.geometry->record,m.camera,glide);
    if(m.phase==launcher::Phase::Flight){auto p=flight_point(m)-glide;constexpr SDL_Rect body{398,29,228,1402};float width=12.f*228/1402;plate("interface/launcher-rocket.png",{float(p.x)-width/2,float(p.y)-6,width,12},&body,-launcher::angle(m.bearing)+90);}
    effects_.draw(canvas_,point(m.camera)*-16-glide);
    if(m.phase==launcher::Phase::Report){auto box=rect({0,102,320,47});SDL_SetRenderDrawColor(canvas_.renderer(),23,43,52,255);render_check(SDL_RenderFillRectF(canvas_.renderer(),&box),"Launcher result");auto lines=data_.message(60+m.status);for(std::size_t i=0;i<lines.size();++i)centered(111+float(i)*9,lines[i],6);}
}
void LauncherScreen::draw(){
    const auto* m=controller_.model();if(!m||!controller_.visible())return;auto top=rect({0,0,320,149});Clip clip(canvas_.renderer(),{int(top.x),int(top.y),int(top.w),int(top.h)});
    if(m->phase==launcher::Phase::Flight||m->phase==launcher::Phase::Impact||m->phase==launcher::Phase::Report)flight(*m);
    else {plate("interface/launcher.png",{0,0,320,149});rocket(*m);effects_.draw(canvas_);controls(*m);ignition_.draw(canvas_);}
    text(5,146,"P: PAUSE   F5: SAVE   F6: OPTIONS   ESC: EXIT",5);if(controller_.paused())centered(76,"PAUSED");
}
bool LauncherScreen::handle_event(const SDL_Event& event){
    if(!controller_.visible()||!controller_.model())return false;
    if(event.type==SDL_KEYDOWN){switch(event.key.keysym.sym){case SDLK_p:controller_.toggle_pause();break;case SDLK_F6:controller_.options();break;case SDLK_F5:controller_.save();break;case SDLK_ESCAPE:case SDLK_RETURN:case SDLK_SPACE:controller_.dismiss();break;default:return false;}return true;}
    if(event.type!=SDL_MOUSEBUTTONDOWN)return false;auto f=frame();if(f.w<=0)return false;SDL_FPoint p{(event.button.x-f.x)*320/f.w,(event.button.y-f.y)*200/f.h};if(p.y<0||p.y>=149||p.x<0||p.x>=320)return false;
    if(controller_.model()->phase==launcher::Phase::Report)controller_.dismiss();else for(int i=0;i<8;++i)if(SDL_PointInFRect(&p,&hotspots[i])){controller_.action(101+i);break;}return true;
}
void LauncherScreen::clear_visual(){effects_.clear();ignition_.clear();trail_.reset();phase_=launcher::Phase::Aim;cursor_=ascent_=-1;map_space_=false;}
void LauncherScreen::advance_visual(double seconds){
    auto* m=controller_.model();if(!m){clear_visual();return;}if(controller_.paused()||!controller_.visible())return;
    bool map=m->phase==launcher::Phase::Flight||m->phase==launcher::Phase::Impact||m->phase==launcher::Phase::Report;
    if(map!=map_space_){clear_visual();map_space_=map;}effects_.advance(seconds);
    ignition_.observe(seconds,{141,103-rocket_offset(*m)},m->phase==launcher::Phase::Launch||m->phase==launcher::Phase::Ascent);
    if(m->phase==launcher::Phase::Flight){
        auto world=flight_point(*m)+point(m->camera)*16;double a=-launcher::angle(m->bearing)*std::numbers::pi/180;Point direction{std::cos(a),std::sin(a)};
        if(!trail_)trail_=world;while(distance(*trail_,world)>=2){auto delta=world-*trail_;*trail_=*trail_+delta*(2/distance(*trail_,world));effects_.add("rocket-exhaust",*trail_-direction*6,direction*-1,.3);}
    }
    if(m->phase!=phase_&&m->phase==launcher::Phase::Impact&&m->geometry)effects_.add(m->status==2?"rocket-impact":"impact",point(launcher::screen_point(*m->geometry,{},0,true)),{0,-1},1.15);
    phase_=m->phase;cursor_=m->cursor;ascent_=m->ascent;
}
}
