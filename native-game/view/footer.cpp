// SPDX-License-Identifier: MIT
#include "view.h"
#include "render_check.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <numbers>

namespace transartica {
namespace {
// Source: original_panel.gd ART_SLICES, COMMON, MAP_COMMANDS and READOUT_INNERS.
constexpr SDL_Color ink{52, 35, 23, 255}, brass{255, 225, 160, 255};
struct Slice { SDL_Rect source; SDL_FRect target; };
constexpr std::array<Slice, 3> slices{{{{0,184,992,402},{0,149,160,51}},
    {{1058,184,480,402},{160,149,70,51}}, {{1538,184,445,402},{230,149,90,51}}}};
struct Slot { SDL_FRect rect; Action action; };
constexpr std::array<Slot, 9> slots{{{{5,164,38,29},Action::Clock}, {{80,161,33,15},Action::Engine},
    {{118,162,27,14},Action::Boudoir}, {{79,180,35,14},Action::Quarters}, {{118,179,29,17},Action::Launcher},
    {{162,160,32,19},Action::DetailedMap}, {{197,160,32,19},Action::Overview},
    {{162,180,32,19},Action::Reverse}, {{197,180,32,19},Action::Brake}}};
int wagon_width(int type) {
    // Source: ecs_panel_art.gd wagon_width, YODA0x1a90.
    return type == 5 || type == 10 || type == 17 || type == 21 || type == 23 || type == 25 ? 27 : 33;
}
bool contains(SDL_FRect r, Point p) { return p.x >= r.x && p.y >= r.y && p.x < r.x+r.w && p.y < r.y+r.h; }
SDL_FRect inset(SDL_FRect r, float amount) { return {r.x+amount,r.y+amount,r.w-2*amount,r.h-2*amount}; }
void fill(SDL_Renderer* renderer, SDL_FRect r, SDL_Color color) {
    SDL_SetRenderDrawColor(renderer,color.r,color.g,color.b,color.a);
    render_check(SDL_RenderFillRectF(renderer,&r),"Draw original panel readout");
}
void circle(SDL_Renderer* renderer, Point center, double radius, SDL_Color color) {
    SDL_SetRenderDrawColor(renderer,color.r,color.g,color.b,color.a);
    for (int y=int(std::ceil(center.y-radius)); y<=int(std::floor(center.y+radius)); ++y) {
        const auto dx=std::sqrt(std::max(0.0,radius*radius-(y-center.y)*(y-center.y)));
        SDL_RenderDrawLineF(renderer,float(center.x-dx),float(y),float(center.x+dx),float(y));
    }
}
void polygon(SDL_Renderer* renderer, const std::vector<Point>& points, SDL_Color color) {
    std::vector<SDL_Vertex> vertices;
    std::vector<int> indices;
    for (const auto p:points) vertices.push_back({{float(p.x),float(p.y)},color,{0,0}});
    for (int i=1; i+1<int(points.size()); ++i) { indices.push_back(0);indices.push_back(i);indices.push_back(i+1); }
    render_check(SDL_RenderGeometry(renderer,nullptr,vertices.data(),int(vertices.size()),indices.data(),int(indices.size())),"Draw clock hand");
}
void line(SDL_Renderer* renderer,Point a,Point b,double width,SDL_Color color) {
    const auto delta=b-a;
    const double span=distance(a,b);
    if (span<=0) return;
    const Point side{-delta.y/span*width*0.5,delta.x/span*width*0.5};
    polygon(renderer,{a+side,b+side,b-side,a-side},color);
}
}

Action View::footer_action(float x,float y,bool map_context) const {
    const auto p=logical(x,y,320,200);
    if (!contains({0,149,320,51},p)) return Action::None;
    if (p.y<=158 && p.x<14) return Action::NextWagon;
    if (p.y<=158 && p.x>304) return Action::PreviousWagon;
    for (const auto& slot:slots) {
        if (!map_context && (slot.action==Action::Reverse || slot.action==Action::Brake)) continue;
        if (contains(slot.rect,p)) return slot.action;
    }
    return Action::None;
}

bool View::in_footer(float x,float y) const {
    return contains({0,149,320,51},logical(x,y,320,200));
}

void View::scroll_composition(int direction,const Session& session) {
    if (direction<0) { if (first_wagon_>0) --first_wagon_; return; }
    int width=0;
    for (std::size_t i=first_wagon_;i<session.wagons.size();++i) width+=wagon_width(session.wagons[i].type);
    if (width>286) ++first_wagon_;
}

void View::footer(const Session& session,bool map_context,bool overview_context) {
    const auto frame=fit(320,200);
    const float factor=frame.w/320;
    auto* renderer=canvas_.renderer();
    const auto screen_rect=[&](SDL_FRect r) { return SDL_FRect{frame.x+r.x*factor,frame.y+r.y*factor,r.w*factor,r.h*factor}; };
    const auto mapped=[&](SDL_FRect source,int slice) {
        const auto s=slices[slice];
        return screen_rect({s.target.x+(source.x-s.source.x)*s.target.w/s.source.w,
            s.target.y+(source.y-s.source.y)*s.target.h/s.source.h,
            source.w*s.target.w/s.source.w,source.h*s.target.h/s.source.h});
    };
    auto* plate=canvas_.texture(assets_/"interface/original-panel-v2.png");
    SDL_SetTextureScaleMode(plate,SDL_ScaleModeNearest);
    for (const auto& slice:slices) {
        const auto destination=screen_rect(slice.target);
        render_check(SDL_RenderCopyF(renderer,plate,&slice.source,&destination),"Draw original panel slice");
    }
    if (!map_context) for (const auto index:{7,8}) {
        const SDL_Rect blank{758,434,207,120};
        const auto destination=screen_rect(slots[index].rect);
        render_check(SDL_RenderCopyF(renderer,plate,&blank,&destination),"Mask inactive wagon commands");
    }
    const auto fitted_text=[&](std::string_view value,SDL_FRect area,int max_size,SDL_Color color,bool right) {
        int size=max_size;
        SDL_FPoint extent{};
        while (size>0) {
            extent=canvas_.measure(value,size);
            if (extent.x+1<=area.w && extent.y+1<=area.h) break;
            --size;
        }
        if (!size) return;
        const float x=right ? std::floor(area.x+area.w-extent.x-1) : area.x+(area.w-extent.x)*0.5f;
        const float y=area.y+(area.h-extent.y-1)*0.5f;
        canvas_.text(value,x+1,y+1,size,ink);
        canvas_.text(value,x,y,size,color);
    };
    // The existing original artwork contains the black numeric wells.
    const std::array values{session.engine.lignite,session.engine.anthracite,session.journey.blocked?0:session.engine.speed};
    constexpr std::array<float,3> readout_y{299,401,505};
    for (std::size_t i=0;i<values.size();++i)
        fitted_text(std::to_string(values[i]),inset(mapped({1775,readout_y[i],167,54},2),1),
            std::max(1,int(std::round(7*factor))),brass,true);
    auto* icons=canvas_.texture(assets_/"interface/panel-icons.png");
    SDL_SetTextureScaleMode(icons,SDL_ScaleModeNearest);
    const int icon=overview_context?4:1;
    const SDL_Rect icon_source{(icon%3)*512,(icon/3)*512,512,512};
    const auto available=inset(slots[6].rect,1);
    const float side=std::min(available.w,available.h);
    const auto destination=screen_rect({available.x+(available.w-side)*0.5f,available.y+(available.h-side)*0.5f,side,side});
    render_check(SDL_RenderCopyF(renderer,icons,&icon_source,&destination),"Draw original map command");
    if (map_context) {
        constexpr const char* headings[]{"","SW","S","SE","W","","E","NW","N","NE"};
        for (const auto index:{7,8}) {
            const bool brake=index==8;
            const auto slot=screen_rect(inset(slots[index].rect,1));
            const auto color=brake && session.engine.brake?brass:ink;
            SDL_SetRenderDrawColor(renderer,color.r,color.g,color.b,color.a);
            for (int stroke=0;stroke<int(std::ceil(factor));++stroke) {
                const auto outline=inset(slot,float(stroke));
                SDL_RenderDrawRectF(renderer,&outline);
            }
            const SDL_FRect band{slot.x,slot.y+slot.h-6*factor,slot.w,6*factor};
            fill(renderer,band,ink);
            const std::string caption=brake?(session.engine.brake?"BRAKE ON":"BRAKE OFF"):
                "FWD "+std::string(headings[std::clamp(session.journey.heading,0,9)]);
            fitted_text(caption,{band.x+factor,band.y,band.w-2*factor,band.h},std::max(1,int(std::round(4*factor))),brass,false);
            if (brake) {
                const Point pivot{slot.x+slot.w*0.5,slot.y+8*factor};
                const Point handle=pivot+Point{(session.engine.brake?-6:6)*factor,-5*factor};
                line(renderer,pivot,handle,3*factor,ink);
                line(renderer,pivot,handle,factor,brass);
                circle(renderer,handle,1.5*factor,brass);
            }
        }
    }
    // Source: original_panel.gd clock_layout/_clock_numerals. Fit real font
    // rectangles inside the measured ellipse, using its quadratic bound.
    const auto face=mapped({60,320,200,180},0);
    const auto center_rect=mapped({160,410,0,0},0);
    const Point center{center_rect.x,center_rect.y};
    constexpr std::array<const char*,12> romans{"XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"};
    struct Numeral { const char* value; SDL_FRect bounds; };
    std::vector<Numeral> numerals;
    int font_size=std::max(1,int(std::round(7*factor)));
    SDL_FPoint max_extent{};
    for (;font_size>0;--font_size) {
        numerals.clear();max_extent={};
        const auto inside=inset(face,1);
        bool valid=true;
        for (std::size_t i=0;i<romans.size();++i) {
            const auto extent=canvas_.measure(romans[i],font_size);
            max_extent.x=std::max(max_extent.x,extent.x);max_extent.y=std::max(max_extent.y,extent.y);
            if (extent.x>=inside.w || extent.y>=inside.h) {valid=false;break;}
            const double angle=double(i)/romans.size()*2*std::numbers::pi;
            const Point direction{std::sin(angle),-std::cos(angle)};
            double radius=1;
            for (const auto sign:std::array<Point,4>{{{-1,-1},{1,-1},{1,1},{-1,1}}}) {
                const Point corner{sign.x*extent.x/inside.w,sign.y*extent.y/inside.h};
                const double along=direction.x*corner.x+direction.y*corner.y;
                const double discriminant=along*along+1-corner.x*corner.x-corner.y*corner.y;
                if (discriminant<0) {valid=false;break;}
                radius=std::min(radius,-along+std::sqrt(discriminant));
            }
            if (!valid) break;
            SDL_FRect rect{float(inside.x+inside.w*0.5+direction.x*inside.w*0.5*radius-extent.x*0.5),
                float(inside.y+inside.h*0.5+direction.y*inside.h*0.5*radius-extent.y*0.5),extent.x,extent.y};
            for (const auto& prior:numerals)
                if (prior.bounds.x<rect.x+rect.w && prior.bounds.x+prior.bounds.w>rect.x &&
                    prior.bounds.y<rect.y+rect.h && prior.bounds.y+prior.bounds.h>rect.y) {valid=false;break;}
            if (!valid) break;
            numerals.push_back({romans[i],rect});
        }
        if (valid && numerals.size()==romans.size()) break;
    }
    if (font_size>0) for (const auto& numeral:numerals)
        canvas_.text(numeral.value,numeral.bounds.x,numeral.bounds.y,font_size,ink);
    const Point radius{face.w*0.5-max_extent.x,face.h*0.5-max_extent.y};
    // Source: original_panel.gd reads the one persisted campaign calendar.
    const auto minutes=session.calendar.hour*60+session.calendar.minute;
    const auto hand=[&](double angle,double length,double half_width) {
        const Point tip=center+Point{std::sin(angle)*radius.x*length,-std::cos(angle)*radius.y*length};
        const double span=distance(center,tip);
        if (span<=0) return;
        const auto axis=(tip-center)*(1/span);
        const Point side{-axis.y,axis.x};
        const auto shoulder=tip-axis*half_width;
        polygon(renderer,{center-axis*half_width,center+side*half_width,shoulder+side*factor,tip,shoulder-side*factor,center-side*half_width},ink);
        polygon(renderer,{center,center+side*half_width,tip},{191,169,120,255});
        polygon(renderer,{center,tip,center-side*half_width},{128,113,80,255});
        line(renderer,center+side*factor,shoulder,1,brass);
    };
    hand(double(minutes%720)/720*2*std::numbers::pi,6.0/9.0,1.5*factor);
    hand(double(minutes%60)/60*2*std::numbers::pi,1,factor);
    circle(renderer,center,1.5*factor,ink);circle(renderer,center,factor,{179,158,112,255});
    // Source: original_panel.gd clock_counter_layout, same inscribed half-face
    // fitting, stacked glyph heights and final placement below the ivory face.
    const auto counter_extent=radius*(6.0/9.0/std::sqrt(2.0));
    const auto counter_window=inset({float(center.x-counter_extent.x),float(center.y-counter_extent.y),
        float(counter_extent.x*2),float(counter_extent.y*2)},1);
    const float label_height=counter_window.h*(1.0f-6.0f/9.0f);
    const bool single_line=canvas_.measure("CYCLES",1).y>label_height;
    const std::vector<std::string> lines=single_line?std::vector<std::string>{std::to_string(session.engine.cycles)}:
        std::vector<std::string>{"CYCLES",std::to_string(session.engine.cycles)};
    struct CounterLine { std::string text; SDL_FPoint extent; int size; };
    std::vector<CounterLine> counter_lines;
    float total_height=0,maximum_width=0;
    for (std::size_t i=0;i<lines.size();++i) {
        const float height=single_line?counter_window.h:i==0?label_height:counter_window.h-label_height;
        int size=std::max(1,std::min(int(std::round(height)),font_size));
        for (;size>0;--size) {
            const auto extent=canvas_.measure(lines[i],size);
            if (extent.x>counter_window.w || extent.y>height) continue;
            counter_lines.push_back({lines[i],extent,size});
            total_height+=extent.y;maximum_width=std::max(maximum_width,extent.x);
            break;
        }
    }
    float counter_y=face.y+face.h+factor;
    const SDL_FRect counter_plate{float(center.x)-maximum_width*0.5f-1,counter_y-1,maximum_width+2,total_height+2};
    fill(renderer,counter_plate,ink);
    SDL_SetRenderDrawColor(renderer,brass.r,brass.g,brass.b,brass.a);
    SDL_RenderDrawRectF(renderer,&counter_plate);
    for (const auto& line:counter_lines) {
        canvas_.text(line.text,float(center.x)-line.extent.x*0.5f,counter_y,line.size,brass);
        counter_y+=line.extent.y;
    }
    // Source: original_panel.gd composition_layout; no substitutes for real wagon art.
    first_wagon_=session.wagons.empty()?0:std::min(first_wagon_,session.wagons.size()-1);
    double right=300;
    for (std::size_t i=first_wagon_;i<session.wagons.size();++i) {
        const auto& wagon=session.wagons[i];
        const auto item=frames_.find(vehicle_kind(wagon.type));
        if (item==frames_.end()) continue;
        const double width=wagon_width(wagon.type);
        const auto& vehicle=item->second;
        if (vehicle.bounds.w<=0 || vehicle.bounds.h<=0) continue;
        const double scale=std::min((width-2)/vehicle.bounds.h,5.0/vehicle.bounds.w)*factor;
        const Point center_sprite{frame.x+(right-width*0.5)*factor,frame.y+153.5*factor};
        const auto window=screen_rect({14,149,286,9});
        const auto anchor=(vehicle.front+vehicle.rear)*0.5;
        // Rotation -PI/2 turns local (x,y) into (y,-x), preserving exact alpha bounds.
        const SDL_FRect drawn{float(center_sprite.x+(vehicle.bounds.y-anchor.y)*scale),
            float(center_sprite.y-(vehicle.bounds.x+vehicle.bounds.w-anchor.x)*scale),
            float(vehicle.bounds.h*scale),float(vehicle.bounds.w*scale)};
        if (drawn.x<window.x || drawn.y<window.y || drawn.x+drawn.w>window.x+window.w || drawn.y+drawn.h>window.y+window.h) break;
        draw_frame_at(vehicle,center_sprite,-std::numbers::pi*0.5,scale,wagon.state==3?SDL_Color{125,101,81,255}:SDL_Color{255,255,255,255});
        right-=width;
    }
    // Source: original_panel.gd _draw_launcher, YODA0x7a4 ownership gate.
    if (std::any_of(session.wagons.begin(),session.wagons.end(),[](const Wagon& w){return w.type==13;})) {
        const auto path=assets_/"interface/panel-launcher.png";
        const auto crop=canvas_.alpha_bounds(path);
        if (crop.w>0 && crop.h>0) {
            const auto slot=mapped({750,430,226,130},0);
            const float scale=std::min(slot.w/crop.w,slot.h/crop.h);
            const SDL_FRect target{slot.x+(slot.w-crop.w*scale)*0.5f,slot.y+(slot.h-crop.h*scale)*0.5f,crop.w*scale,crop.h*scale};
            render_check(SDL_RenderCopyF(renderer,canvas_.texture(path),&crop,&target),"Draw owned launcher icon");
        }
    }
}
}
