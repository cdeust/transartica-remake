// SPDX-License-Identifier: MIT
// Exact registrations: terrain_portals.gd:66..87, travel_cover.gd:59..65,
// terrain_obstacles.gd:149..190. No old foreground silhouettes are activated.
#include "world_passages.hpp"
#include "world_painting_join.hpp"
#include "world_visual_math.hpp"
#include "platform/hash.h"
#include "render_check.h"
#include <json-c/json.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <stdexcept>

namespace transartica {
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
// travel_cover.gd MOUTHS, confirmed by the immutable CARTE atlas.
struct Mouth {Cell cell;int code;Point direction;};
constexpr std::array<Mouth,6> mouths{{{{61,51},53,{0,1}},{{30,58},54,{-1,0}},
    {{51,39},54,{-1,0}},{{12,21},58,{1,0}},{{105,23},58,{1,0}},{{113,58},58,{1,0}}}};
json_object* field(json_object* object,const char* name) {
    json_object* value{};
    if(!json_object_object_get_ex(object,name,&value))throw std::runtime_error(std::string("Passage metadata missing ")+name);
    return value;
}
double number(json_object* value) {
    if(!value||(!json_object_is_type(value,json_type_int)&&!json_object_is_type(value,json_type_double)))throw std::runtime_error("Invalid passage number");
    const double result=json_object_get_double(value);
    if(!std::isfinite(result))throw std::runtime_error("Nonfinite passage number");return result;
}
void array(json_object* value,std::size_t count) {
    if(!json_object_is_type(value,json_type_array)||json_object_array_length(value)!=count)throw std::runtime_error("Invalid passage coordinate array");
}
Point point_value(json_object* value) {array(value,2);return {number(json_object_array_get_idx(value,0)),number(json_object_array_get_idx(value,1))};}
SDL_Rect crop_value(json_object* value) {
    array(value,4);std::array<int,4> values{};
    for(int i=0;i<4;++i){const double n=number(json_object_array_get_idx(value,i));if(n<0||n!=std::floor(n)||n>std::numeric_limits<int>::max())throw std::runtime_error("Invalid passage crop");values[i]=int(n);}
    if(values[2]<=0||values[3]<=0)throw std::runtime_error("Empty passage crop");return {values[0],values[1],values[2],values[3]};
}
Json document(const std::filesystem::path& path) {
    Json result(json_object_from_file(path.string().c_str()),json_object_put);
    if(!result)throw std::runtime_error("Cannot read passage metadata: "+path.string());return result;
}
void validate_crop(Canvas& canvas,const std::filesystem::path& path,SDL_Rect crop) {
    const auto size=canvas.image_size(path);
    if(crop.x>size.x||crop.y>size.y||crop.w>size.x-crop.x||crop.h>size.y-crop.y)throw std::runtime_error("Passage crop outside atlas");
}
struct Transform {
    Point x,y,origin;
    Point apply(Point p)const{return origin+x*p.x+y*p.y;}
};
std::array<Point,4> quad(SDL_FRect rectangle,const Transform& t) {
    return {t.apply({rectangle.x,rectangle.y}),t.apply({rectangle.x+rectangle.w,rectangle.y}),
        t.apply({rectangle.x+rectangle.w,rectangle.y+rectangle.h}),t.apply({rectangle.x,rectangle.y+rectangle.h})};
}
struct Bounds {int left,top,right,bottom;};
Bounds bounds(const WorldProjection& p) {
    if(!std::isfinite(p.origin.x)||!std::isfinite(p.origin.y)||!std::isfinite(p.pixels_per_cell)||p.pixels_per_cell<=0
       ||!std::isfinite(p.viewport.x)||!std::isfinite(p.viewport.y)||!std::isfinite(p.viewport.w)||!std::isfinite(p.viewport.h))return {};
    const auto limit=[](double n,int high){return int(std::clamp(n,0.,double(high)));};
    // travel_world.gd visible-world bounds retain one neighboring source cell.
    return {limit(std::floor((p.viewport.x-p.origin.x)/p.pixels_per_cell)-1,RailNetwork::width),
        limit(std::floor((p.viewport.y-p.origin.y)/p.pixels_per_cell)-1,RailNetwork::height),
        limit(std::ceil((p.viewport.x+p.viewport.w-p.origin.x)/p.pixels_per_cell)+1,RailNetwork::width),
        limit(std::ceil((p.viewport.y+p.viewport.h-p.origin.y)/p.pixels_per_cell)+1,RailNetwork::height)};
}
bool visible(const std::array<Point,4>& points,SDL_FRect viewport) {
    double left=points[0].x,right=left,top=points[0].y,bottom=top;
    for(auto p:points){left=std::min(left,p.x);right=std::max(right,p.x);top=std::min(top,p.y);bottom=std::max(bottom,p.y);}
    return right>=viewport.x&&bottom>=viewport.y&&left<=viewport.x+viewport.w&&top<=viewport.y+viewport.h;
}
int obstacle_source(int code) {return code==114?69:code==-117?64:code;}
bool obstacle_code(int code) {return code==67||code==63||code==69||code==64||code==114||code==-116||code==-117||code==-121;}
bool connected_approach(const RailNetwork& network,Cell cell,Point direction) {
    // rail_network.gd/rail_glyphs.gd port reciprocity identifies a railway.
    // CARTE also uses broken-obstacle codes for geological continuation tiles.
    for(double side:{-.5,.5}){
        const Cell neighbor{cell.x+int(direction.x*side*2),cell.y+int(direction.y*side*2)};
        for(auto port:rail_ports(network.tile(neighbor)))if(port==direction*(-side))return true;
    }return false;
}
}
WorldPassages::WorldPassages(Canvas& canvas,std::filesystem::path assets):canvas_(canvas),root_(std::move(assets)/"travel/terrain") {load_portals();load_obstacles();}
bool WorldPassages::underground(int code) {code=std::abs(code);return (code>=38&&code<=52)||(code>=55&&code<=57);}
std::optional<MouthOpening> WorldPassages::mouth_opening(Cell cell) const {
    const auto mouth=std::find_if(mouths.begin(),mouths.end(),[&](const Mouth& m){return m.cell==cell;});
    if(mouth==mouths.end())return {};
    const auto& f=portals_.at(mouth->code);
    // Same authenticated registration as portal_plan, in world units.
    const double scale=rail_visual::projected_gauge(mouth->direction)/rail_visual::cell/f.gauge;
    Point basis_x{scale,0};const auto delta=f.endpoint-f.anchor;
    if(mouth->code!=53)basis_x.y=-scale*delta.y/delta.x;
    const Transform transform{basis_x,{0,scale},{}};
    return MouthOpening{point(cell)+Point{.5,.5}+mouth->direction*.5
        +transform.apply(f.anchor)-transform.apply(f.endpoint),mouth->direction};
}
bool WorldPassages::fully_covered(const RailNetwork& network,Point front,Point rear,
    Point midpoint,int heading,const std::array<Point,4>& quad) const {
    // TIME0x0496 / RailNetwork::progress_speed: crossings15/16 are covered
    // only on their underground axis. A midpoint alone cannot hide a wagon
    // that straddles a surface boundary. Check both physical rail contacts.
    for(const auto p:{front,rear,midpoint}){
        const Cell cell{int(std::round(p.x)),int(std::round(p.y))};
        if(network.progress_speed(cell,heading,1)!=2)return false;
    }
    double left=quad[0].x,right=left,top=quad[0].y,bottom=top;
    for(auto p:quad){left=std::min(left,p.x);right=std::max(right,p.x);top=std::min(top,p.y);bottom=std::max(bottom,p.y);}
    for(const auto& mouth:mouths){
        if(network.tile(mouth.cell)!=mouth.code||right<mouth.cell.x||left>mouth.cell.x+1
            ||bottom<mouth.cell.y||top>mouth.cell.y+1)continue;
        const auto opening=*mouth_opening(mouth.cell);
        for(auto p:quad){const auto offset=p-opening.position;
            if(offset.x*opening.direction.x+offset.y*opening.direction.y>0)return false;}
    }
    // Cell-sized painting masks miss rigid sprite overhang on diagonal joins.
    // Suppress the complete proven-covered body, preserving the surface rails
    // above directional crossings. Mouth-straddling bodies still use cover().
    return true;
}
bool WorldPassages::owns_rails(Cell cell,int code) {
    // game_calendar.gd: the timed bridge closes at (110,33). Its resource136
    // is water without rails (travel_terrain.gd::resource_code), not a bridge.
    if(cell==Cell{110,33}&&code==-120)return true;
    if(obstacle_code(code))return true;
    return std::any_of(mouths.begin(),mouths.end(),[&](const Mouth& mouth){return mouth.cell==cell&&mouth.code==code;});
}
void WorldPassages::load_portals() {
    // travel_terrain.gd PORTAL_DESCRIPTOR_SHA256 authenticates these anchors.
    verify_sha256(root_/"underground-mouths.json","dc0782286f681f124a955e76c7facf4646dfaec8e0412264493e7ee234039e12");
    auto data=document(root_/"underground-mouths.json");auto* frames=field(data.get(),"frames");array(frames,3);
    const auto path=root_/"underground-mouths.png";
    verify_sha256(path,json_object_get_string(field(data.get(),"sha256")));
    for(std::size_t i=0;i<json_object_array_length(frames);++i){auto* frame=json_object_array_get_idx(frames,i);int code=int(number(field(frame,"code")));
        Portal item{crop_value(field(frame,"region")),point_value(field(frame,"mouth_anchor")),point_value(field(frame,"rail_endpoint")),number(field(frame,"rail_gauge"))};
        auto* measurement=field(frame,"measurement");auto* centroids=field(measurement,"centroids");array(centroids,2);
        auto delta=point_value(json_object_array_get_idx(centroids,1))-point_value(json_object_array_get_idx(centroids,0));
        const std::string axis=json_object_get_string(field(measurement,"axis"));item.gauge=axis=="y"?std::abs(delta.x):std::abs(delta.y);
        if((code!=53&&code!=54&&code!=58)||item.gauge<=0||item.anchor.y<=0||item.anchor.y>=item.crop.h||!portals_.emplace(code,item).second)throw std::runtime_error("Invalid registered portal");
        validate_crop(canvas_,path,item.crop);
    }
}
void WorldPassages::load_obstacles() {
    // Eight-frame metadata from terrain_obstacles.gd:6, isolated from the legacy
    // shared descriptor so native packaging preserves its authenticated schema.
    const auto metadata=root_/"scenes/obstacles-native.json";
    verify_sha256(metadata,"703ddd339ea3735809bee7672b78cd846cdbc662d76f129c95256ee673ea35e7");
    auto data=document(metadata);auto* frames=field(data.get(),"frames");array(frames,8);
    const auto path=root_/"scenes/bridges-only-v1.png";
    // Existing authored rail-only sheet, byte identity inspected18Oct2026.
    verify_sha256(path,"19fc7e79c5da692cca2813fdcd1480051f7f059bf4d26545e08bc047e1c3c4a5");
    for(std::size_t i=0;i<json_object_array_length(frames);++i){auto* frame=json_object_array_get_idx(frames,i);auto* ports=field(frame,"rail_ports");array(ports,2);
        Obstacle item{crop_value(field(frame,"region")),point_value(json_object_array_get_idx(ports,0)),point_value(json_object_array_get_idx(ports,1)),number(field(frame,"rail_gauge"))};
        auto* codes=field(frame,"codes");array(codes,1);int code=int(number(json_object_array_get_idx(codes,0)));
        if(!obstacle_code(code)||item.gauge<=0||item.first==item.last||!obstacles_.emplace(code,item).second)throw std::runtime_error("Invalid registered obstacle");
    }
    for(const auto& [code,item]:obstacles_)validate_crop(canvas_,path,obstacles_.at(obstacle_source(code)).crop);
}
void WorldPassages::add_painting(SDL_FRect world,SDL_Rect crop,std::filesystem::path path) {paintings_.push_back({world,crop,std::move(path)});}
std::vector<PassagePiece> WorldPassages::portal_plan(const RailNetwork& network,const WorldProjection& p,bool front)const {
    std::vector<PassagePiece> result;if(bounds(p).right==0)return result;
    for(const auto& mouth:mouths){if(network.tile(mouth.cell)!=mouth.code)continue;const auto& f=portals_.at(mouth.code);
        const double scale=rail_visual::projected_gauge(mouth.direction)*p.pixels_per_cell/rail_visual::cell/f.gauge;
        Point basis_x{scale,0};auto delta=f.endpoint-f.anchor;if(mouth.code!=53)basis_x.y=-scale*delta.y/delta.x;
        Transform t{basis_x,{0,scale},{}};t.origin=p.screen(point(mouth.cell)+Point{.5,.5}+mouth.direction*.5)-t.apply(f.endpoint);
        SDL_FRect local{0,front?0.f:float(f.anchor.y),float(f.crop.w),float(front?f.anchor.y:f.crop.h-f.anchor.y)};
        auto points=quad(local,t);if(!visible(points,p.viewport))continue;
        result.push_back({root_/"underground-mouths.png",{f.crop.x+local.x,f.crop.y+local.y,local.w,local.h},points,mouth.cell,mouth.code});
    }return result;
}
std::vector<PassagePiece> WorldPassages::obstacle_plan(const RailNetwork& network,const WorldProjection& p)const {
    std::vector<PassagePiece> result;auto area=bounds(p);
    for(int y=area.top;y<area.bottom;++y)for(int x=area.left;x<area.right;++x){int code=network.tile({x,y});if(!obstacle_code(code))continue;
        const auto& f=obstacles_.at(obstacle_source(code));Point direction=(code==64||code==69||code==114||code==-117)?Point{0,1}:Point{1,0};
        if((code==67||code==69||code==114||code==-116)&&!connected_approach(network,{x,y},direction))continue;
        auto source_axis=rail_visual::normalized(f.last-f.first);Point source_normal{source_axis.y,-source_axis.x},normal{direction.y,-direction.x};
        const double along=p.pixels_per_cell/rail_visual::length(f.last-f.first),across=rail_visual::projected_gauge(direction)*p.pixels_per_cell/rail_visual::cell/f.gauge;
        Transform t{direction*(along*source_axis.x)+normal*(across*source_normal.x),direction*(along*source_axis.y)+normal*(across*source_normal.y),{}};
        t.origin=p.screen(Point{double(x)+.5,double(y)+.5}-direction*.5)-t.apply(f.first);
        SDL_FRect local{0,0,float(f.crop.w),float(f.crop.h)};auto points=quad(local,t);
        if(visible(points,p.viewport))result.push_back({root_/"scenes/bridges-only-v1.png",{float(f.crop.x),float(f.crop.y),local.w,local.h},points,{x,y},code});
    }return result;
}
void WorldPassages::draw(const PassagePiece& piece) {
    auto* texture=canvas_.texture(piece.texture);auto size=canvas_.image_size(piece.texture);const auto r=piece.source;
    const std::array<Point,4> uv{{{r.x/size.x,r.y/size.y},{(r.x+r.w)/size.x,r.y/size.y},{(r.x+r.w)/size.x,(r.y+r.h)/size.y},{r.x/size.x,(r.y+r.h)/size.y}}};
    std::array<SDL_Vertex,4> vertices{};for(int i=0;i<4;++i)vertices[i]={{float(piece.points[i].x),float(piece.points[i].y)},{255,255,255,255},{float(uv[i].x),float(uv[i].y)}};
    constexpr int indices[]{0,1,2,0,2,3};render_check(SDL_RenderGeometry(canvas_.renderer(),texture,vertices.data(),4,indices,6),"Registered world passage");
}
void WorldPassages::floor(const RailNetwork& network,const WorldProjection& p) {for(const auto& item:portal_plan(network,p,false))draw(item);for(const auto& item:obstacle_plan(network,p))draw(item);}
void WorldPassages::foreground(const RailNetwork& network,const WorldProjection& p) {for(const auto& item:portal_plan(network,p,true))draw(item);}
void WorldPassages::cover(const RailNetwork& network,const WorldProjection& p) {
    // Owner18Oct: actual selected-painting pixels cover authoritative underground
    // cells. This replaces the former alpha-only visibility, not terrain geometry.
    auto area=bounds(p);std::vector<std::pair<Cell,int>> cells;
    for(int y=area.top;y<area.bottom;++y)for(int x=area.left;x<area.right;++x){int code=network.tile({x,y});if(!underground(code))continue;cells.push_back({{x,y},code});
        cover_painting({float(x),float(y),1,1},p);}
    // The measured opening lies inside the mouth cell, beyond its underground
    // boundary. Extend the authorized painting cover to that exact plane;
    // otherwise a vehicle reappears between the cell border and the arch.
    for(const auto& floor:portal_plan(network,p,false)){
        const auto opening=mouth_opening(floor.cell)->position;
        SDL_FRect part{float(floor.cell.x),float(floor.cell.y),1,1};
        if(floor.code==53)part.h=float(std::clamp(opening.y-floor.cell.y,0.,1.));
        else if(floor.code==54){const double edge=std::clamp(opening.x,double(floor.cell.x),double(floor.cell.x+1));part.x=float(edge);part.w=float(floor.cell.x+1-edge);}
        else part.w=float(std::clamp(opening.x-floor.cell.x,0.,1.));
        if(part.w>0&&part.h>0)cover_painting(part,p);
    }
    for(const auto& [cell,code]:cells)stipple(cell,code,p);
}
void WorldPassages::cover_painting(SDL_FRect world,const WorldProjection& p) {
    for(const auto& painting:paintings_){SDL_FRect part{};if(!SDL_IntersectFRect(&world,&painting.world,&part))continue;
        const auto& w=painting.world;const auto& c=painting.crop;const auto a=p.screen({part.x,part.y}),b=p.screen({part.x+part.w,part.y+part.h});
        // Preserve affine source coordinates in double precision. Storing pixel
        // origin and extent as float made their sum exceed the texture edge
        // (1322.0001220703125 at V4), rejected by SDL_RenderGeometry.
        draw({painting.path,{c.x+(double(part.x)-w.x)/w.w*c.w,c.y+(double(part.y)-w.y)/w.h*c.h,double(part.w)/w.w*c.w,double(part.h)/w.h*c.h},
            {a,Point{b.x,a.y},b,Point{a.x,b.y}}});}
    reconstruct_horizontal_painting_joins(canvas_,paintings_,p,world);
}
void WorldPassages::stipple(Cell cell,int code,const WorldProjection& p) {
    // terrain_portals.gd:89..98:20px pitch, half-pitch marks, gauge*0.2 width.
    const double zoom=p.pixels_per_cell/rail_visual::cell,pitch=20*zoom;if(pitch<=0)return;
    const auto start=p.screen(point(cell)+Point{.5,.5});std::vector<SDL_Vertex> vertices;
    for(auto port:rail_ports(code)){auto finish=p.screen(point(cell)+Point{.5,.5}+port),direction=rail_visual::normalized(finish-start),side=Point{direction.y,-direction.x}*(2*zoom);
        for(double cursor=0;cursor<rail_visual::length(finish-start);cursor+=pitch){auto q=rail_visual::strip(start+direction*cursor,start+direction*std::min(cursor+pitch*.5,rail_visual::length(finish-start)),side);
            for(int index:{0,1,2,0,2,3})vertices.push_back({{float(q[index].x),float(q[index].y)},rail_visual::steel,{}});}}
    if(!vertices.empty())render_check(SDL_RenderGeometry(canvas_.renderer(),nullptr,vertices.data(),int(vertices.size()),nullptr,0),"Underground navigation stipple");
}
}
