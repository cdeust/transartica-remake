// SPDX-License-Identifier: MIT
// Exact authored layout from map_entities.gd heading_overlay_layout/_clear_overlay_box.
#include "world_visual.hpp"
#include "world_visual_math.hpp"
#include "render_check.h"
#include <algorithm>
#include <limits>
namespace transartica {
namespace {
bool area(SDL_FRect r){return r.w>0&&r.h>0;}
SDL_FRect clear_overlay(SDL_FRect preferred,SDL_FRect occupied,SDL_FRect viewport){
    if(preferred.w>viewport.w||preferred.h>viewport.h)return {};
    std::vector<Point> candidates{{preferred.x,preferred.y}};
    if(area(occupied)){candidates.push_back({occupied.x-preferred.w-24,preferred.y});candidates.push_back({occupied.x+occupied.w+24,preferred.y});
        candidates.push_back({preferred.x,occupied.y-preferred.h-24});candidates.push_back({preferred.x,occupied.y+occupied.h+24});}
    candidates.push_back({viewport.x,viewport.y});candidates.push_back({viewport.x+viewport.w-preferred.w,viewport.y});
    candidates.push_back({viewport.x+viewport.w-preferred.w,viewport.y+viewport.h-preferred.h});candidates.push_back({viewport.x,viewport.y+viewport.h-preferred.h});
    SDL_FRect best{};double distance=std::numeric_limits<double>::infinity();
    for(auto p:candidates){SDL_FRect rect{float(std::clamp(p.x,double(viewport.x),double(viewport.x+viewport.w-preferred.w))),float(std::clamp(p.y,double(viewport.y),double(viewport.y+viewport.h-preferred.h))),preferred.w,preferred.h};
        if(area(occupied)&&SDL_HasIntersectionF(&rect,&occupied))continue;
        double dx=rect.x-preferred.x,dy=rect.y-preferred.y,travel=dx*dx+dy*dy;if(travel<distance){best=rect;distance=travel;}}
    return best;
}
void stroke(Canvas& canvas,Point a,Point b,double width,SDL_Color color){
    auto d=rail_visual::normalized(b-a),side=Point{d.y,-d.x}*(width*.5);auto points=rail_visual::strip(a,b,side);std::array<SDL_Vertex,4> vertices{};
    for(int i=0;i<4;++i)vertices[i]={{float(points[i].x),float(points[i].y)},color,{}};
    constexpr int indices[]{0,1,2,0,2,3};render_check(SDL_RenderGeometry(canvas.renderer(),nullptr,vertices.data(),4,indices,6),"World heading arrow");
}
}
WorldHeadingLayout WorldVisual::heading_layout(Point center,Point direction,Point extent,SDL_FRect occupied,SDL_FRect viewport){
    auto tip=center+direction*32,side=Point{direction.y,-direction.x};WorldHeadingLayout layout;
    layout.points={tip-direction*12+side*7,tip,tip-direction*12-side*7};Point low=layout.points[0],high=low;
    for(auto p:layout.points){low.x=std::min(low.x,p.x);low.y=std::min(low.y,p.y);high.x=std::max(high.x,p.x);high.y=std::max(high.y,p.y);}
    SDL_FRect arrow{float(low.x)-7,float(low.y)-7,float(high.x-low.x)+14,float(high.y-low.y)+14};layout.arrow=clear_overlay(arrow,occupied,viewport);
    if(area(layout.arrow)){Point shift{layout.arrow.x-arrow.x,layout.arrow.y-arrow.y};for(auto& p:layout.points)p=p+shift;}else layout.points.clear();
    auto anchor=tip-Point{extent.x*.5,extent.y+24};if(std::abs(direction.y)>std::abs(direction.x))anchor=tip+Point{24,-extent.y*.5};
    layout.label=clear_overlay({float(anchor.x),float(anchor.y),float(extent.x)+8,float(extent.y)+6},occupied,viewport);return layout;
}
void WorldVisual::heading(const Journey& journey,Point visual,SDL_FRect occupied,const WorldProjection& projection){
    auto direction=rail_visual::normalized(point(heading_delta(journey.heading)));if(direction==Point{})return;
    // train_journey.gd HEADING_NAMES and map_entities.gd authored display caption.
    constexpr const char* names[]{"","SOUTH-WEST","SOUTH","SOUTH-EAST","WEST","","EAST","NORTH-WEST","NORTH","NORTH-EAST"};
    if(journey.heading<1||journey.heading>9)return;std::string caption=(journey.reversing?"REVERSE · ":"FORWARD · ")+std::string(names[journey.heading]);
    auto size=canvas_.measure(caption,14);auto layout=heading_layout(projection.screen(visual+Point{.5,.5}),direction,{size.x,size.y},occupied,projection.viewport);
    SDL_BlendMode prior;SDL_GetRenderDrawBlendMode(canvas_.renderer(),&prior);SDL_SetRenderDrawBlendMode(canvas_.renderer(),SDL_BLENDMODE_BLEND);
    for(auto [width,color]:{std::pair{7.,SDL_Color{23,36,43,255}},std::pair{3.,SDL_Color{255,228,165,255}}})
        for(std::size_t i=1;i<layout.points.size();++i)stroke(canvas_,layout.points[i-1],layout.points[i],width,color);
    if(area(layout.label)){SDL_SetRenderDrawColor(canvas_.renderer(),23,36,43,255);render_check(SDL_RenderFillRectF(canvas_.renderer(),&layout.label),"World heading label");canvas_.text(caption,layout.label.x+4,layout.label.y+3,14,{255,228,165,255});}
    SDL_SetRenderDrawBlendMode(canvas_.renderer(),prior);
}
}
