// SPDX-License-Identifier: MIT
// Sources: game/scripts/engine_room_art.gd and engine_room_controls.gd.
#include "view.h"
#include "render_check.h"
#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <iomanip>
#include <numbers>
#include <sstream>
#include <string>

namespace transartica {
namespace {
struct Hotspot {SDL_FRect bounds;Action action;const char* name;};
// Source engine_room_controls.gd HOTSPOTS, including its priority order.
constexpr std::array hotspots{
    Hotspot{{825,116,180,66},Action::Instruments,"INSTRUMENTS"},
    Hotspot{{405,400,310,326},Action::Lignite,"LIGNITE"},
    Hotspot{{996,408,234,318},Action::Anthracite,"ANTHRACITE"},
    Hotspot{{1270,783,305,71},Action::Lignite,"LIGNITE"},
    Hotspot{{1270,860,305,61},Action::Anthracite,"ANTHRACITE"},
    Hotspot{{550,72,140,215},Action::Regulator,"REGULATOR"},
    Hotspot{{32,790,199,205},Action::Pause,"CLOCK"},
    Hotspot{{803,785,338,86},Action::Map,"ROUTE CHART"},
    Hotspot{{416,885,178,105},Action::Boudoir,"BOUDOIR"},
    Hotspot{{610,885,182,105},Action::Brake,"BRAKE"}
};
bool contains(SDL_FRect r,Point p) {return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;}
SDL_FRect scaled(SDL_FRect bounds,SDL_FRect r) {
    const float s=bounds.w/1600;
    return {bounds.x+r.x*s,bounds.y+r.y*s,r.w*s,r.h*s};
}
void text(Canvas& canvas,SDL_FRect bounds,float x,float baseline,std::string_view value,int size) {
    const float s=bounds.w/1600;const int pixels=std::max(1,int(std::round(size*s)));
    canvas.text(value,bounds.x+(x+2)*s,bounds.y+(baseline-size+2)*s,pixels,{9,13,16,255});
    canvas.text(value,bounds.x+x*s,bounds.y+(baseline-size)*s,pixels,{235,189,112,255});
}
std::string digits(int number,int width) {std::ostringstream out;out<<std::setw(width)<<std::setfill('0')<<number;return out.str();}
void stroke(Canvas& canvas,Point a,Point b,float width,SDL_Color color) {
    const double length=distance(a,b);if(length==0)return;
    const Point side{-(b.y-a.y)/length*width/2,(b.x-a.x)/length*width/2};
    const std::array<Point,4> p{a+side,b+side,b-side,a-side};std::array<SDL_Vertex,4> v{};
    for(int i=0;i<4;++i)v[i]={{float(p[i].x),float(p[i].y)},color,{}};
    constexpr int indices[]{0,1,2,0,2,3};
    render_check(SDL_RenderGeometry(canvas.renderer(),nullptr,v.data(),4,indices,6),"Cabin stroke");
}
void ring(Canvas& canvas,SDL_FRect bounds,Point center,double radius) {
    constexpr int points=72; // engine_room_controls.gd::_draw_round_highlights.
    const double s=bounds.w/1600;const Point offset{bounds.x,bounds.y};
    for(int i=1;i<points;++i) {
        const double a=2*std::numbers::pi*(i-1)/(points-1),b=2*std::numbers::pi*i/(points-1);
        stroke(canvas,offset+(center+Point{std::cos(a),std::sin(a)}*radius)*s,
            offset+(center+Point{std::cos(b),std::sin(b)}*radius)*s,float(s),{255,207,125,166});
    }
}
}
std::string View::key_label(input::Command command) const {
    return bindings_?bindings_->key_label(command):SDL_GetScancodeName(input::commands()[std::size_t(command)].physical);
}
void View::set_pointer(Point pointer,bool active) {
    cabin_pointer_=pointer;
    if(cabin_pointer_active_&&!active) {cabin_stoker_.clear();cabin_engineer_.clear();cabin_interface_.clear();}
    cabin_pointer_active_=active;
}
void View::advance_cabin(double seconds,const Session& session,bool paused) {
    cabin_effects_.advance(seconds,session.engine,paused||session.paused||session.engine.event_pending);
}
void View::reset_cabin() {cabin_effects_.clear();set_pointer({},false);}
Action View::cabin_action(float x,float y) const {
    const auto p=logical(x,y,1600,1000);
    for(const auto& h:hotspots) if(contains(h.bounds,p)) {
        if(h.action==Action::Regulator&&!cabin_engineer_.red_pixel(assets_/"engine-room/engineer-mask.png",{p.x/1600,p.y/1000}))return Action::None;
        return h.action;
    }
    return Action::None;
}
int View::regulator_at(float x,float y) const {
    return std::clamp(int((logical(x,y,1600,1000).x-535)/185*300),0,300);
}
void View::cabin(const Session& session,double seconds,std::string_view notice) {
    const auto bounds=fit(1600,1000);
    cabin_background(session,seconds,bounds);
    cabin_stokers(session,seconds,bounds);
    cabin_controls(session,bounds);
    cabin_needles(session,bounds);
    cabin_status(session,notice,bounds);
    footer(session,false);
}
void View::cabin_background(const Session& session,double seconds,SDL_FRect bounds) {
    auto* renderer=canvas_.renderer();
    render_check(SDL_RenderCopyF(renderer,canvas_.texture(assets_/"engine-room/background.png"),nullptr,&bounds),"Cabin background");
    if(session.engine.heat>0) {
        auto* fire=canvas_.texture(assets_/"engine-room/fire.png");int w{},h{};
        render_check(SDL_QueryTexture(fire,nullptr,nullptr,&w,&h),"Fire sheet size");
        const int frame=int(seconds*8)%4;const SDL_Rect crop{(frame%2)*w/2,(frame/2)*h/2,w/2,h/2};
        const float strength=std::clamp(float(session.engine.heat)/600,.08f,1.f);
        const float height=180*(.25f+.75f*strength);auto dest=scaled(bounds,{665,675-height,270,height});
        render_check(SDL_SetTextureAlphaMod(fire,Uint8(std::round(strength*255))),"Furnace glow");
        const int result=SDL_RenderCopyF(renderer,fire,&crop,&dest);SDL_SetTextureAlphaMod(fire,255);
        render_check(result,"Draw furnace fire");
    }
    cabin_effects_.draw(canvas_,bounds); // engine_room_art.gd: before actors.
}
void View::cabin_stokers(const Session& session,double seconds,SDL_FRect bounds) {
    constexpr std::array<SDL_Rect,8> crops{{{0,0,384,512},{384,0,396,512},{780,0,360,512},{1140,0,396,512},
        {0,512,340,512},{340,512,400,512},{740,512,380,512},{1120,512,416,512}}};
    constexpr std::array<Point,8> pivots{{{177,481},{560,481},{905,481},{1262,481},{197,953},{606,953},{948,953},{1360,953}}};
    const auto hover=cabin_pointer_active_?cabin_action(float(cabin_pointer_.x),float(cabin_pointer_.y)):Action::None;
    const auto pointer=logical(float(cabin_pointer_.x),float(cabin_pointer_.y),1600,1000);
    const auto path=assets_/"engine-room/stokers.png";auto* stokers=canvas_.texture(path);
    for(int side=0;side<2;++side) {
        const int rate=side?session.engine.anthracite_rate:session.engine.lignite_rate;
        const int pose=side*4+(rate?int(std::floor(seconds*rate*4))%4:0);const auto crop=crops[pose];
        const auto pivot=pivots[pose]-Point{double(crop.x),double(crop.y)};
        auto dest=scaled(bounds,{float((side?1080:550)-pivot.x*.7),float(724-pivot.y*.7),crop.w*.7f,crop.h*.7f});
        if(pointer.y<760&&hover==(side?Action::Anthracite:Action::Lignite))
            cabin_stoker_.draw(canvas_,path,dest,panels::HighlightKind::StokerOutline,crop);
        render_check(SDL_RenderCopyF(canvas_.renderer(),stokers,&crop,&dest),"Cabin actor");
    }
    if(hover==Action::Regulator)
        cabin_engineer_.draw(canvas_,assets_/"engine-room/engineer-mask.png",bounds,panels::HighlightKind::MatteRed);
    if(hover==Action::Brake||hover==Action::Boudoir) for(const auto& h:hotspots) if(h.action==hover)
        cabin_interface_.draw(canvas_,assets_/"engine-room/interface-mask.png",bounds,panels::HighlightKind::MatteRed,{},
            {h.bounds.x/1600,h.bounds.y/1000,h.bounds.w/1600,h.bounds.h/1000});
}
void View::cabin_controls(const Session& session,SDL_FRect bounds) {
    const auto& e=session.engine;constexpr const char* rates[]{"OFF","NORMAL","FAST"};
    text(canvas_,bounds,1408,847,std::to_string(e.lignite),36);
    text(canvas_,bounds,1408,917,std::to_string(e.anthracite),36);
    text(canvas_,bounds,1500,979,std::to_string(e.speed),36);
    text(canvas_,bounds,462,723,rates[e.lignite_rate],17);
    text(canvas_,bounds,1031,723,rates[e.anthracite_rate],17);
    text(canvas_,bounds,636,985,e.brake?"BRAKE ON":"BRAKE OFF",17);
    text(canvas_,bounds,546,316,"REGULATOR "+digits(e.regulator,3),17);
    const auto minutes=e.cycles*3;
    text(canvas_,bounds,50,783,digits(int(minutes/60),2)+":"+digits(int(minutes%60),2),17);
}
void View::cabin_needles(const Session& session,SDL_FRect bounds) {
    const auto& e=session.engine;const double s=bounds.w/1600;const Point offset{bounds.x,bounds.y};
    const auto needle=[&](Point center,double ratio) {
        const double angle=(-1.25+1.5*std::clamp(ratio,0.,1.))*std::numbers::pi;
        stroke(canvas_,offset+center*s,offset+(center+Point{std::cos(angle),std::sin(angle)}*12)*s,float(3*s),{173,74,50,255});
        auto hub=scaled(bounds,{float(center.x)-2,float(center.y)-2,4,4});
        SDL_SetRenderDrawColor(canvas_.renderer(),233,226,207,255);
        render_check(SDL_RenderFillRectF(canvas_.renderer(),&hub),"Instrument hub");
    };
    needle({854,141},double(e.temperature)/600);needle({907,145},double(e.pressure_reserve)/32000);needle({961,143},double(e.speed)/300);
}
void View::cabin_status(const Session& session,std::string_view notice,SDL_FRect bounds) {
    using input::Command;const auto& e=session.engine;
    std::string status=key_label(Command::Lignite)+" / "+key_label(Command::Anthracite)+": STOKERS   "+key_label(Command::Brake)
        +": BRAKE   "+key_label(Command::Pause)+": PAUSE   "+key_label(Command::Save)+": SAVE   "+key_label(Command::Options)
        +": OPTIONS   "+key_label(Command::Help)+": HELP";
    const auto hover=cabin_pointer_active_?cabin_action(float(cabin_pointer_.x),float(cabin_pointer_.y)):Action::None;
    for(const auto& h:hotspots) if(h.action==hover) {
        if(hover==Action::Instruments)status="BOILER "+std::to_string(e.temperature)+"   STEAM RESERVE "+std::to_string(e.pressure_reserve)+"   SPEED "+std::to_string(e.speed);
        else if(hover==Action::Regulator)status="REGULATOR · drag the engineer · "+key_label(Command::RegulatorDown)+" / "+key_label(Command::RegulatorUp);
        else {auto command=hover==Action::Lignite?Command::Lignite:hover==Action::Anthracite?Command::Anthracite:hover==Action::Pause?Command::Pause:hover==Action::Map?Command::Map:hover==Action::Boudoir?Command::Journal:Command::Brake;status=std::string(h.name)+" · "+key_label(command);}
        break;
    }
    if(!notice.empty())status=notice;
    if(session.paused)status="PAUSED · "+key_label(Command::Pause)+" to resume";
    auto panel=scaled(bounds,{260,12,1080,34});SDL_SetRenderDrawColor(canvas_.renderer(),6,10,14,230);
    render_check(SDL_RenderFillRectF(canvas_.renderer(),&panel),"Cabin status background");
    text(canvas_,bounds,280,36,status,18);text(canvas_,bounds,585,760,"ENGINE ROOM",15);
    if(hover==Action::Instruments)for(Point center:std::array<Point,3>{{{854,141},{907,145},{961,143}}})ring(canvas_,bounds,center,15);
    if(hover==Action::Pause)ring(canvas_,bounds,{127,890},87);
    if(e.event_pending) {
        auto box=scaled(bounds,{400,375,800,190});SDL_SetRenderDrawColor(canvas_.renderer(),10,14,17,247);
        render_check(SDL_RenderFillRectF(canvas_.renderer(),&box),"Engine stop message");
        SDL_SetRenderDrawColor(canvas_.renderer(),200,117,77,255);render_check(SDL_RenderDrawRectF(canvas_.renderer(),&box),"Engine stop border");
        std::string message=e.event_message;std::transform(message.begin(),message.end(),message.begin(),[](unsigned char c){return char(std::toupper(c));});
        text(canvas_,bounds,430,425,message,26);text(canvas_,bounds,430,468,"The journey has stopped.",18);
        text(canvas_,bounds,430,510,key_label(Command::Options)+": open options to load a save or start a new journey.",18);
    }
}
}
