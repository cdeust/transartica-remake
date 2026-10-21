// SPDX-License-Identifier: MIT
// Source layouts: scripts/{boudoir_screen,general_quarters,original_screen,
// engine_instruments,instrument_art,inventory_page,inventory_report,
// ecs_overview,overview_chart_art}.gd. No game state is simulated by these views.
#include "panel_screens.h"
#include <json-c/json.h>
#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <iomanip>
#include <memory>
#include <numbers>
#include <sstream>
#include <stdexcept>
#include <utility>

namespace transartica::panels {
namespace {
constexpr SDL_Color gold{238,202,136,255}, instrument_gold{226,185,117,255}, dark{24,32,42,255};
bool contains(SDL_FRect r, Point p) { return p.x>=r.x && p.y>=r.y && p.x<r.x+r.w && p.y<r.y+r.h; }
void color(SDL_Renderer* r, SDL_Color c) { SDL_SetRenderDrawColor(r,c.r,c.g,c.b,c.a); }
void checked(int result) { if(result<0) throw std::runtime_error(std::string("Panel draw: ")+SDL_GetError()); }
std::string digits(int number) { std::ostringstream out; out<<std::setw(3)<<std::setfill('0')<<number; return out.str(); }
std::string uppercase(std::string text) { for(char& c:text) c= c=='-'?' ':char(std::toupper(static_cast<unsigned char>(c))); return text; }
}
PanelScreens::PanelScreens(Canvas& canvas,std::filesystem::path assets,const economy::Trade* trade):canvas_(canvas),assets_(std::move(assets)),trade_(trade),hover_(assets_) {}
SDL_FRect PanelScreens::fit(float width,float height) const {
    const float scale=std::min(canvas_.width()/width,canvas_.height()/height);
    return {(canvas_.width()-width*scale)*.5f,(canvas_.height()-height*scale)*.5f,width*scale,height*scale};
}
Point PanelScreens::logical(float x,float y,float width,float height) const {
    const auto r=fit(width,height);
    if(r.w<=0 || r.h<=0) return {-1,-1};
    return {(x-r.x)*width/r.w,(y-r.y)*height/r.h};
}
void PanelScreens::image(const std::filesystem::path& path,SDL_FRect r,const SDL_Rect* crop) {
    checked(SDL_RenderCopyF(canvas_.renderer(),canvas_.texture(path),crop,&r));
}
void PanelScreens::text(SDL_FRect frame,float logical_width,Point baseline,std::string_view value,int size,SDL_Color ink) {
    const float scale=frame.w/logical_width;
    canvas_.text(value,frame.x+float(baseline.x)*scale,frame.y+float(baseline.y-size)*scale,
        std::max(1,int(std::round(size*scale))),ink);
}
void PanelScreens::draw(Screen screen,const Session& session,std::string_view notice) {
    auto room=fit(320,200); room.h*=149.f/200.f;
    switch(screen) {
    case Screen::Boudoir: image(assets_/"boudoir/captain-boudoir.png",room); break;
    case Screen::Quarters: image(assets_/"boudoir/general-quarters.png",room); break;
    case Screen::Instruments: instruments(session); break;
    case Screen::Overview: overview(session); break;
    case Screen::Inventory: inventory(session); break;
    }
    if(screen==Screen::Boudoir||screen==Screen::Quarters)
        hover_.draw(canvas_,screen==Screen::Boudoir?RoomHover::Room::Boudoir:RoomHover::Room::Quarters,room,pointer_,hover_active_);
    // Explicit host notices use the existing navy/brass presentation palette.
    if(!notice.empty()) {
        auto frame=fit(320,200);
        SDL_FRect box{frame.x+frame.w*.1f,frame.y+frame.h*.60f,frame.w*.8f,frame.h*.12f};
        color(canvas_.renderer(),{12,29,39,245}); checked(SDL_RenderFillRectF(canvas_.renderer(),&box));
        const float scale=frame.w/320;
        const int pixels=std::max(1,int(std::round(6*scale)));
        std::istringstream words{std::string(notice)}; std::string word,line;
        float y=frame.y+frame.h*.61f;
        while(words>>word) {
            auto candidate=line.empty()?word:line+" "+word;
            if(!line.empty() && canvas_.measure(candidate,pixels).x>box.w-10*scale) {
                canvas_.text(line,box.x+5*scale,y,pixels,gold); y+=8*scale; line=word;
            } else line=std::move(candidate);
        }
        if(!line.empty()) canvas_.text(line,box.x+5*scale,y,pixels,gold);
    }
}
Action PanelScreens::action(Screen screen,float x,float y) const {
    if(screen==Screen::Instruments) {
        const auto p=logical(x,y,1600,1000);
        if(contains({1190,690,345,255},p)) return Action::Cabin;
        if(contains({475,42,650,225},p)) return Action::Regulator;
        return Action::None;
    }
    const auto p=logical(x,y,320,200);
    if(screen==Screen::Inventory) return contains({0,0,320,200},p)?Action::Inventory:Action::None;
    if(screen==Screen::Overview) return contains({0,0,320,149},p)?Action::Unavailable:Action::None;
    if(!contains({0,0,320,149},p)) return Action::None;
    const Point n{p.x/320,p.y/149};
    if(screen==Screen::Boudoir) {
        if(contains({.03f,.77f,.075f,.17f},n)) return Action::Stoup;
        if(contains({.10f,.32f,.28f,.66f},n)) return Action::Inventory;
        if(contains({.455f,.79f,.10f,.15f},n)) return Action::Revolver;
        if(contains({.57f,.74f,.30f,.24f},n)) return Action::Save;
    } else if(screen==Screen::Quarters) {
        if(contains({0,.74f,.085f,.24f},n)) return Action::Stoup;
        if(contains({.08f,.44f,.13f,.49f},n)) return Action::Spies;
        if(contains({.80f,.20f,.20f,.80f},n)) return Action::Cars;
        if(contains({.36f,.4f,.44f,.6f},n)) return Action::Overview;
    }
    return Action::None;
}
std::optional<Cell> PanelScreens::overview_cell(float x,float y) const {
    const auto p=logical(x,y,320,200);
    if(!contains({0,0,320,149},p))return {};
    // ecs_overview.gd CARTE0x235b..244a: lens clamp and inspected coordinates.
    return Cell{int(std::clamp(p.x,19.0,300.0)/2),int((std::clamp(p.y,12.0,140.0)-6)/2)};
}
int PanelScreens::regulator_at(float x,float y) const {
    return int(std::clamp((logical(x,y,1600,1000).x-500)/600,0.0,1.0)*300);
}
void PanelScreens::instruments(const Session& session) {
    const auto frame=fit(1600,1000); const float scale=frame.w/1600;
    image(assets_/"engine-room/instruments.png",frame);
    auto* r=canvas_.renderer(); const auto& e=session.engine;
    const auto at=[&](Point p) { return SDL_FPoint{frame.x+float(p.x)*scale,frame.y+float(p.y)*scale}; };
    const auto rect=[&](SDL_FRect box,SDL_Color ink) { color(r,ink); box={frame.x+box.x*scale,frame.y+box.y*scale,box.w*scale,box.h*scale}; checked(SDL_RenderFillRectF(r,&box)); };
    const auto line=[&](Point a,Point b,float width,SDL_Color ink) {
        const auto from=at(a),to=at(b); const double length=std::hypot(to.x-from.x,to.y-from.y);
        if(length==0) return;
        const float nx=float(-(to.y-from.y)/length)*width*scale*.5f,ny=float((to.x-from.x)/length)*width*scale*.5f;
        const SDL_Vertex v[]{{{from.x+nx,from.y+ny},ink,{}},{{to.x+nx,to.y+ny},ink,{}},{{to.x-nx,to.y-ny},ink,{}},{{from.x-nx,from.y-ny},ink,{}}};
        constexpr int indices[]{0,1,2,0,2,3}; checked(SDL_RenderGeometry(r,nullptr,v,4,indices,6));
    };
    const auto needle=[&](Point center,double radius,double ratio) {
        const double angle=std::numbers::pi*.75+std::clamp(ratio,0.0,1.0)*std::numbers::pi*1.5;
        const Point tip=center+Point{std::cos(angle),std::sin(angle)}*radius;
        line(center+Point{3,3},tip+Point{3,3},6,{0,0,0,64}); line(center,tip,5,{120,55,42,255});
        // Exact circle fill in output pixels, radius8 from instrument_art.gd.
        color(r,instrument_gold); const auto c=at(center); const int radius_px=std::max(1,int(std::round(8*scale)));
        for(int y=-radius_px;y<=radius_px;++y) { const float dx=std::sqrt(float(radius_px*radius_px-y*y)); checked(SDL_RenderDrawLineF(r,c.x-dx,c.y+y,c.x+dx,c.y+y)); }
    };
    needle({338,527},146,double(e.heat)/5000); needle({823,462},112,double(e.speed)/300);
    const auto label=[&](Point p,std::string_view v,int size,SDL_Color ink=instrument_gold){text(frame,1600,p,v,size,ink);};
    label({224,760},"BOILER PRESSURE",20); label({726,660},"SPEED · km/h",22);
    label({751,529},digits(e.speed),32,dark); label({262,599},std::to_string(e.heat),30,dark); label({235,632},"LIMIT 5000",17,dark);
    const float height=356*std::clamp(float(e.temperature)/600,0.f,1.f); rect({1230,705-height,7,height},{174,65,49,255});
    label({1187,281},std::to_string(e.temperature)+" °C",23);
    const float x=500+600*float(e.regulator)/300; rect({x-12,132,24,71},{58,37,32,255}); rect({x-9,132,18,63},instrument_gold);
    label({675,87},"REGULATOR  "+digits(e.regulator),22); label({662,858},"PISTON PRESSURE",15);
    label({745,793},digits(e.pressure_reserve/200),38); label({1307,968},"ENGINE ROOM",20);
    if(e.event_pending) label({380,956},e.event_message,24);
}
std::vector<std::string> PanelScreens::inventory_lines(const Session& session) const {
    // Source inventory_report TYPE_ORDER, intact counts and contents suffixes.
    constexpr int order[]{1,2,3,21,8,9,10,11,12,13,4,16,20,22,23,24,5,6,7,14,15,17,18,19};
    std::vector<std::string> lines;
    for(int type:order) {
        int count=0,quantity=0;
        for(auto w:session.wagons) if(w.type==type && w.state!=3) { ++count; quantity+=w.quantity; }
        if(!count) continue;
        lines.push_back(uppercase(trade_?trade_->wagon_name(type):vehicle_kind(type))+": "+std::to_string(count));
        const char* suffix=type==5||type==6?"SLAVE(S)":type==7?"MAMMOTH(S)":type==15?"TON(S) OF OIL":type==19?"TON(S) OF PLANTS":type==22?"SPY (SPIES)":type==23||type==24?"SOLDIER(S)":"";
        if(*suffix) lines.push_back("CONTAINING "+std::to_string(quantity)+" "+suffix);
    }
    return lines;
}
bool PanelScreens::next_inventory(const Session& session) {
    const auto count=inventory_lines(session).size();
    // inventory_page.gd first page90..180 (11 lines), later30..174 (17).
    const std::size_t pages=1+(count>11?(count-11+16)/17:0);
    if(inventory_page_+1>=pages) { inventory_page_=0; return false; }
    ++inventory_page_; return true;
}
void PanelScreens::inventory(const Session& session) {
    const auto frame=fit(320,200); image(assets_/"interface/inventory-frame.png",frame);
    const auto label=[&](Point p,std::string_view value){text(frame,320,p,value,7,gold);};
    label({125,13},"INVENTORY"); label({254,13},"PAGE "+std::to_string(inventory_page_+1));
    if(inventory_page_==0) {
        int destroyed=0,tare=0,load=0,tenders=0;
        for(auto w:session.wagons) {
            if(w.state==3) { ++destroyed; tare+=10; continue; }
            const int empty=train_mass({Wagon{w.type,0,0,0}}); tare+=empty;
            load+=w.type==21?session.engine.lignite+session.engine.anthracite:train_mass({w})-empty;
            if(w.type==21) ++tenders;
        }
        label({38,31},"NUMBER OF WAGONS: "+std::to_string(session.wagons.size()));
        label({38,40},destroyed?"DESTROYED WAGONS: "+std::to_string(destroyed):"NO WAGONS DESTROYED");
        label({38,50},"PTAV: "+std::to_string(tare)); label({38,59},"PTAC: "+std::to_string(tare+load));
        label({38,69},"TENDER CAPACITY: "+std::to_string(tenders*5000));
        label({38,79},"PRESENT CONTENTS: "+std::to_string(session.engine.lignite+session.engine.anthracite));
    }
    label({38,13},"DAY "+std::to_string(session.calendar.day));
    const auto lines=inventory_lines(session);
    const std::size_t first=inventory_page_?11+(inventory_page_-1)*17:0,limit=inventory_page_?17:11;
    for(std::size_t i=first;i<lines.size() && i<first+limit;++i) label({38,double((inventory_page_?30:90)+(i-first)*9)},lines[i]);
}
void PanelScreens::load_overview() {
    if(overview_loaded_) return;
    const auto path=assets_.parent_path()/"data/overview-geometry.json";
    using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
    Json root(json_object_from_file(path.string().c_str()),json_object_put);
    if(!root) throw std::runtime_error("Cannot read original overview geometry: "+path.string());
    const auto field=[&](const char* key){json_object* result{}; if(!json_object_object_get_ex(root.get(),key,&result)) throw std::runtime_error(std::string("Missing overview field: ")+key); return result;};
    if(json_object_get_int(field("version"))!=1 || json_object_get_int(field("width"))!=320 || json_object_get_int(field("height"))!=149) throw std::runtime_error("Unsupported overview geometry");
    Geometry candidate;
    const auto read=[&](const char* name,std::vector<SDL_FRect>& out,int size) {
        auto* rows=field(name); if(!json_object_is_type(rows,json_type_array)) throw std::runtime_error("Invalid overview rows");
        for(std::size_t i=0;i<json_object_array_length(rows);++i) {
            auto* row=json_object_array_get_idx(rows,i);
            if(!json_object_is_type(row,json_type_array) || json_object_array_length(row)!=std::size_t(size)) throw std::runtime_error("Invalid overview row");
            std::array<float,4> values{};
            for(int j=0;j<size;++j) {
                auto* value=json_object_array_get_idx(row,std::size_t(j));
                if(!json_object_is_type(value,json_type_int) && !json_object_is_type(value,json_type_double)) throw std::runtime_error("Invalid overview coordinate");
                const double n=json_object_get_double(value);
                if(!std::isfinite(n) || n!=std::floor(n) || std::abs(n)>320) throw std::runtime_error("Invalid overview coordinate");
                values[std::size_t(j)]=float(n);
            }
            out.push_back({values[0],values[1],values[2],values[3]});
        }
    };
    read("routes",candidate.routes,4); read("compartments",candidate.compartments,4); read("towns",candidate.towns,4);
    read("symbols",candidate.symbols,4); read("sites",candidate.sites,4);
    std::vector<SDL_FRect> dots; read("dots",dots,2); for(auto dot:dots) candidate.dots.push_back({dot.x,dot.y});
    geometry_=std::move(candidate); overview_loaded_=true;
}
void PanelScreens::overview(const Session& session) {
    load_overview(); auto frame=fit(320,200); frame.h*=149.f/200.f; auto* r=canvas_.renderer(); const float scale=frame.w/320;
    // ecs_overview.gd clip_contents: artwork's (2,3,320,146) registration extends
    // beyond the320-wide plan. Restore the caller's clip before footer drawing.
    struct ClipGuard {
        SDL_Renderer* renderer; SDL_Rect prior{}; bool enabled;
        explicit ClipGuard(SDL_Renderer* value):renderer(value),enabled(SDL_RenderIsClipEnabled(value)==SDL_TRUE){SDL_RenderGetClipRect(value,&prior);}
        ~ClipGuard(){SDL_RenderSetClipRect(renderer,enabled?&prior:nullptr);}
    } clipping(r);
    const SDL_Rect clip{int(std::floor(frame.x)),int(std::floor(frame.y)),int(std::ceil(frame.w)),int(std::ceil(frame.h))};
    checked(SDL_RenderSetClipRect(r,&clip));
    const auto box=[&](SDL_FRect b){return SDL_FRect{frame.x+b.x*scale,frame.y+b.y*scale,b.w*scale,b.h*scale};};
    const auto line=[&](Point a,Point b,SDL_Color ink){color(r,ink); checked(SDL_RenderDrawLineF(r,frame.x+float(a.x)*scale,frame.y+float(a.y)*scale,frame.x+float(b.x)*scale,frame.y+float(b.y)*scale));};
    color(r,{238,233,215,255}); checked(SDL_RenderFillRectF(r,&frame));
    // world_artwork.gd overview_rect preserves CARTE's exact (2*x+2,2*y+3).
    const auto master=assets_/"travel/terrain/world-artwork.png";
    if(std::filesystem::is_regular_file(master)) image(master,box({2,3,320,146}));
    else {
        // overview_chart_art.paper_region: ellipse-inscribed measured paper crop.
        const SDL_Rect paper{90,347,140,126}; image(assets_/"interface/original-panel-v2.png",frame,&paper);
    }
    constexpr SDL_Color ink{52,35,23,255},brass{173,139,82,255};
    for(auto l:geometry_.compartments) line({l.x,l.y},{l.w,l.h},{173,139,82,41});
    for(auto l:geometry_.routes) line({l.x,l.y},{l.w,l.h},ink);
    const auto circle=[&](Point center,double radius,SDL_Color shade) {
        color(r,shade); const float cx=frame.x+float(center.x)*scale,cy=frame.y+float(center.y)*scale;
        const int px=std::max(1,int(std::round(radius*scale)));
        for(int y=-px;y<=px;++y){const float dx=std::sqrt(float(px*px-y*y)); checked(SDL_RenderDrawLineF(r,cx-dx,cy+y,cx+dx,cy+y));}
    };
    for(auto p:geometry_.dots) circle(p,.4,brass);
    const SDL_Rect town_crop{11,75,360,325};
    for(auto town:geometry_.towns) {
        // overview_chart_art.town_markers fits terrain_landmarks.REGIONS[0].
        const float factor=std::min(town.w/360,town.h/325); const float w=360*factor,h=325*factor;
        image(assets_/"travel/terrain/landmarks-master.png",box({town.x+(town.w-w)*.5f,town.y+(town.h-h)*.5f,w,h}),&town_crop);
    }
    for(const auto* list:{&geometry_.symbols,&geometry_.sites}) for(auto b:*list) {
        const Point center{b.x+b.w*.5,b.y+b.h*.5}; const double radius=std::min(b.w,b.h)*.5;
        circle(center,radius,ink); circle(center,radius*.5,brass);
    }
    const auto border=[&](SDL_FRect dst,SDL_Rect source){image(assets_/"interface/world-chart-frame.png",box(dst),&source);};
    border({0,0,320,3},{240,28,1320,49}); border({0,146,320,3},{240,796,1320,66});
    border({0,3,3,143},{10,206,45,402}); border({317,3,3,143},{1715,206,49,402}); border({291,104,29,27},{1558,631,216,256});
    line({42,145},{66,145},ink); text(frame,320,{43,142},"700 Km",5,ink);
    const Point p{2.0*session.journey.position.x+2,2.0*session.journey.position.y+3}; constexpr SDL_Color marker{198,40,35,255};
    if(session.engine.speed==0 || session.journey.blocked) {line(p-Point{3,3},p+Point{3,3},marker);line(p+Point{-3,3},p+Point{3,-3},marker);}
    else {auto d=point(heading_delta(session.journey.heading));d=d*(1/std::hypot(d.x,d.y));const Point side{-d.y,d.x};line(p-d*3,p+d*3,marker);line(p+side*2,p+d*3,marker);line(p+d*3,p-side*2,marker);}
}
}
