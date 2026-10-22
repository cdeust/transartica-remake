// SPDX-License-Identifier: MIT
// Sources: map_rail_drawing.gd, map_rail_geometry_cache.gd, rail_material.gd.
// Only the active integrated-ground layers; world-hd already owns scenery.
#include "world_visual.hpp"
#include "world_visual_math.hpp"
#include "world_passages.hpp"
#include "platform/hash.h"
#include "render_check.h"
#include <algorithm>
#include <numbers>
namespace transartica {
using namespace rail_visual;
void WorldVisual::mechanism(Mesh& mesh,Point center,Point incoming,Point outgoing,double zoom){
    const double minimum=screen_stroke(0,zoom);
    join(mesh,incoming,center,outgoing,4,true,selected_stroke(1.1,zoom));auto tangent=normalized(outgoing-center);
    auto base=center+transverse(normalized(center-incoming),gauge*1.25),crown=base+Point{0,-10},grip=crown+tangent*5;
    Point pad{3,2.5};std::array<Point,4> rect{base-pad,base+Point{pad.x,-pad.y},base+pad,base+Point{-pad.x,pad.y}};polygon(mesh,4,rect,contact);
    line(mesh,4,base,crown,steel_side,screen_stroke(3,zoom));line(mesh,4,crown,grip,steel,screen_stroke(3,zoom));
    // Diameter at least one screen pixel; keep source grip centre and brass.
    const double radius=std::max(1.1,minimum*.5);
    // Same one-vertex-per-pixel circumference policy as MapCanvasBatch, now in
    // final screen pixels like the stroke floor (bounded even at tiny zoom).
    int count=std::max(3,int(std::ceil(2*std::numbers::pi*radius*zoom)));std::vector<Point> circle;
    for(int i=0;i<count;++i){double a=2*std::numbers::pi*i/count;circle.push_back(grip+Point{std::cos(a),std::sin(a)}*radius);}polygon(mesh,4,circle,handle);
}
void WorldVisual::buffer(Mesh& mesh,Point center,Point direction){
    center=center-direction*12;auto side=transverse(direction,gauge*.65),depth=direction*5;Point rise{0,-10};
    for(int sign:{-1,1}){auto foot=center+side*sign;line(mesh,4,foot,foot+depth,contact,5);line(mesh,4,foot+depth,foot+rise,steel_side,3);line(mesh,4,foot,foot+rise,steel,3);}
    line(mesh,4,center-side+rise,center+side+rise,wood_side,5);line(mesh,4,center-side+rise,center+side+rise,wood,3);
    line(mesh,4,center-side+rise*1.1,center+side+rise*1.1,steel,1.1);
}
WorldVisual::Mesh WorldVisual::build_rail(int code,bool detailed,double zoom){
    // Replace intact steel/sleepers, not an overlay: the authored centre must
    // remain physically broken. Other signed glyph families retain their scope.
    if(const auto broken=broken_straight_plan(code)){
        Mesh mesh;polygon(mesh,0,broken->points,{255,255,255,255},broken->crop);return mesh;}
    Mesh mesh;auto ports=rail_ports(code);Point center{cell/2,cell/2};std::vector<Point> endpoints;for(auto p:ports)endpoints.push_back(center+p*cell);
    int absolute=std::abs(code);if((absolute>=38&&absolute<=52)||(absolute>=55&&absolute<=57)){
        for(auto end:endpoints){auto direction=normalized(end-center);double extent=length(end-center);
            for(double travel=0;travel<extent;travel+=20)line(mesh,0,center+direction*travel,center+direction*std::min(travel+10,extent),steel,4);}return mesh;}
    for(const auto& chord:tile_segments(center,endpoints))segment(mesh,chord[0],chord[1],detailed);
    if(detailed&&ports.size()==2)join(mesh,endpoints[0],center,endpoints[1]);
    if(const auto route=switch_route(code)){
        if(detailed)for(std::size_t i=0;i<ports.size();++i)if(ports[i]!=route->entry)join(mesh,center+route->entry*cell,center,endpoints[i]);
        mechanism(mesh,center,center+route->entry*(.7*cell),center+route->selected*(.7*cell),zoom);}
    if(code>=34&&code<=37&&!ports.empty())buffer(mesh,center,normalized(ports[0]));
    return mesh;
}
void WorldVisual::rails(const RailNetwork& network,const WorldProjection& p){
    if(!network.loaded()||!std::isfinite(p.pixels_per_cell)||p.pixels_per_cell<=0)return;
    if(!std::isfinite(p.origin.x)||!std::isfinite(p.origin.y)||!std::isfinite(p.viewport.x)||!std::isfinite(p.viewport.y)||!std::isfinite(p.viewport.w)||!std::isfinite(p.viewport.h)||p.viewport.w<=0||p.viewport.h<=0)return;
    const auto path=assets_/"travel/rail-track-kit.png";
    if(rail_texture_size_.x==0){
        // Pin the measured kit before using its authored strip/damage crops.
        verify_sha256(path,"6905fe2c3a7c6a4788958bf47e85b6d9f43c8352b3c8edbc5c6d1ad3d660ae26");
        auto size=canvas_.image_size(path);rail_texture_size_={double(size.x),double(size.y)};}
    const double zoom=p.pixels_per_cell/cell;if(!std::isfinite(1/zoom))return;
    bool detailed=zoom*36*gauge/source_gauge*depth_ratio>=1;
    // Only one zoom generation: switch screen-pixel floors must not accumulate
    // a cache entry for every camera animation sample.
    if(rail_mesh_zoom_!=zoom){rails_.clear();rail_mesh_zoom_=zoom;}
    // travel_world.gd::_visible_world_bounds retains one cell beyond each edge.
    // Bound in floating point first. Large finite camera positions may produce
    // infinite quotients; clamping those still gives a safe empty map range.
    int left=int(std::clamp(std::floor((p.viewport.x-p.origin.x)/p.pixels_per_cell)-1,0.,double(RailNetwork::width)));
    int top=int(std::clamp(std::floor((p.viewport.y-p.origin.y)/p.pixels_per_cell)-1,0.,double(RailNetwork::height)));
    int right=int(std::clamp(std::ceil((p.viewport.x+p.viewport.w-p.origin.x)/p.pixels_per_cell)+1,0.,double(RailNetwork::width)));
    int bottom=int(std::clamp(std::ceil((p.viewport.y+p.viewport.h-p.origin.y)/p.pixels_per_cell)+1,0.,double(RailNetwork::height)));
    auto* renderer=canvas_.renderer();SDL_BlendMode prior;SDL_GetRenderDrawBlendMode(renderer,&prior);SDL_SetRenderDrawBlendMode(renderer,SDL_BLENDMODE_BLEND);
    struct Batch{int layer;Surface surface;std::vector<SDL_Vertex> vertices;};
    for(int y=top;y<bottom;++y){std::vector<Batch> batches;
        for(int x=left;x<right;++x){int code=network.tile({x,y});
            // MapRailDrawing: authenticated mouth/obstacle art owns its embedded
            // rail stub or bridge; never add normal steel or ballast over it.
            if(WorldPassages::owns_rails({x,y},code))continue;
            auto key=std::pair{code,detailed};auto found=rails_.find(key);
            if(found==rails_.end())found=rails_.emplace(key,build_rail(code,detailed,zoom)).first;auto origin=p.screen({double(x),double(y)});
            for(const auto& group:found->second){auto batch=std::find_if(batches.begin(),batches.end(),[&](const Batch& b){return b.layer==group.layer&&b.surface==group.surface;});
                if(batch==batches.end()){batches.push_back({group.layer,group.surface,{}});batch=std::prev(batches.end());}
                for(const auto& v:group.vertices){auto q=origin+v.point*zoom;batch->vertices.push_back({{float(q.x),float(q.y)},v.color,{float(v.uv.x),float(v.uv.y)}});}}}
        std::stable_sort(batches.begin(),batches.end(),[](const Batch& a,const Batch& b){return a.layer<b.layer;});
        for(const auto& b:batches){auto* texture=b.surface==Surface::Track?canvas_.texture(path):(b.surface==Surface::Ballast?canvas_.rail_ballast_texture(path):nullptr);
            render_check(SDL_RenderGeometry(renderer,texture,b.vertices.data(),int(b.vertices.size()),nullptr,0),"Active world rails");}}
    SDL_SetRenderDrawBlendMode(renderer,prior);
}
}
