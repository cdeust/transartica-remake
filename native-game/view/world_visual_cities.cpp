// SPDX-License-Identifier: MIT
// Active sources: travel_map_entities.gd overrides map_entities.gd draw_city_tile;
// artwork_scene_renderer.gd coverage, world_view.gd city labels and fallback house.
// Historical city pixels must not cover the selected world-hd paintings.
#include "world_visual.hpp"
#include "world_visual_math.hpp"
#include "render_check.h"
#include <algorithm>
namespace transartica {
namespace {
void fill(Canvas& canvas,SDL_FRect rect,SDL_Color color){SDL_SetRenderDrawColor(canvas.renderer(),color.r,color.g,color.b,color.a);render_check(SDL_RenderFillRectF(canvas.renderer(),&rect),"City annotation");}
bool contains(SDL_FRect r,Point p){return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;}
bool covered(Cell cell,std::span<const SDL_FRect> paintings){
    // Source artwork_scene_renderer.gd::_subtract_regions: a cell can straddle
    // several neighboring resident regions. Subtract their union, not one box.
    std::vector<SDL_FRect> remaining{{float(cell.x),float(cell.y),1,1}};
    for(auto paint:paintings){std::vector<SDL_FRect> next;for(auto rect:remaining){SDL_FRect overlap{};
        if(!SDL_IntersectFRect(&rect,&paint,&overlap)){next.push_back(rect);continue;}
        auto add=[&](SDL_FRect piece){if(piece.w>0&&piece.h>0)next.push_back(piece);};
        add({rect.x,rect.y,rect.w,overlap.y-rect.y});add({rect.x,overlap.y+overlap.h,rect.w,rect.y+rect.h-overlap.y-overlap.h});
        add({rect.x,overlap.y,overlap.x-rect.x,overlap.h});add({overlap.x+overlap.w,overlap.y,rect.x+rect.w-overlap.x-overlap.w,overlap.h});}
        remaining=std::move(next);if(remaining.empty())return true;}return remaining.empty();
}
void roof(Canvas& canvas,Point a,Point b,SDL_Color color){
    auto d=rail_visual::normalized(b-a),side=Point{d.y,-d.x}*.75;auto points=rail_visual::strip(a,b,side);std::array<SDL_Vertex,4> vertices{};
    for(int i=0;i<4;++i)vertices[i]={{float(points[i].x),float(points[i].y)},color,{}};constexpr int indices[]{0,1,2,0,2,3};
    render_check(SDL_RenderGeometry(canvas.renderer(),nullptr,vertices.data(),4,indices,6),"Source city roof");
}
void house(Canvas& canvas,Point p,bool selected){
    auto base=selected?SDL_Color{255,250,240,255}:SDL_Color{238,233,215,255},mark=selected?SDL_Color{166,119,66,255}:SDL_Color{23,54,65,255};
    fill(canvas,{float(p.x)-4,float(p.y),8,4},base);roof(canvas,p+Point{-5,0},p+Point{0,-4},mark);roof(canvas,p+Point{0,-4},p+Point{5,0},mark);fill(canvas,{float(p.x)-3,float(p.y)+1,6,3},mark);
}
}
void WorldVisual::city_label(Point p,std::string_view name,bool chosen,const WorldProjection& projection,std::vector<SDL_FRect>& occupied){
    int pixels=chosen?14:11;auto extent=canvas_.measure(name,pixels);SDL_FRect box{float(p.x)+(chosen?10:8),float(p.y)+(chosen?-11:-8),extent.x+(chosen?12:5),extent.y+(chosen?5:4)};
    auto vp=projection.viewport;box.x=std::clamp(box.x,vp.x,std::max(vp.x,vp.x+vp.w-box.w));box.y=std::clamp(box.y,vp.y,std::max(vp.y,vp.y+vp.h-box.h));
    if(!chosen&&std::any_of(occupied.begin(),occupied.end(),[&](SDL_FRect prior){return SDL_HasIntersectionF(&box,&prior);}))return;
    if(!chosen)occupied.push_back(box);fill(canvas_,box,chosen?SDL_Color{255,250,240,255}:SDL_Color{238,233,215,255});
    if(chosen){SDL_SetRenderDrawColor(canvas_.renderer(),173,139,82,255);render_check(SDL_RenderDrawRectF(canvas_.renderer(),&box),"Selected city label");SDL_FRect marker{float(p.x)-6,float(p.y)-6,13,13};render_check(SDL_RenderDrawRectF(canvas_.renderer(),&marker),"Selected city marker");}
    canvas_.text(name,box.x+(chosen?6:3),box.y+(chosen?1:0),pixels,{23,54,65,255});
}
void WorldVisual::cities(const economy::WorldData& world,const RailNetwork& network,const WorldProjection& p,std::span<const SDL_FRect> paintings,int selected){
    std::vector<SDL_FRect> occupied;SDL_BlendMode prior;SDL_GetRenderDrawBlendMode(canvas_.renderer(),&prior);SDL_SetRenderDrawBlendMode(canvas_.renderer(),SDL_BLENDMODE_BLEND);
    for(std::size_t i=0;i<world.cities().size();++i){const auto& city=world.cities()[i];auto center=p.screen(point(city.anchor)+Point{.5,.5});if(!contains(p.viewport,center))continue;
        int code=network.tile(city.anchor),resource=code< -104?code+256:std::abs(code);bool chosen=int(i)==selected;
        if(!(resource>=71&&resource<=76&&covered(city.anchor,paintings)))house(canvas_,center,chosen);
        city_label(center,city.name,chosen,p,occupied);}
    SDL_SetRenderDrawBlendMode(canvas_.renderer(),prior);
}
}
