// SPDX-License-Identifier: MIT
#pragma once
// Source: rail_art.gd / rail_material.gd. Local presentation units only.
#include "core/session.hpp"
#include <SDL.h>
#include <algorithm>
#include <cmath>
#include <optional>
#include <vector>
namespace transartica::rail_visual {
inline const double cell=std::sqrt(180.*180.+100.*100.);
constexpr double depth_ratio=100./180.,gauge=20.,source_gauge=60.;
constexpr SDL_Color steel{101,123,135,255},steel_side{32,42,44,255},frost{158,175,184,179};
constexpr SDL_Color wood{89,83,74,255},wood_side{55,59,61,255},contact{36,56,72,56},handle{164,149,117,255};
constexpr SDL_FRect steel_crop{158,100,3,200},wood_crop{168,116,40,1};
inline double length(Point p){return std::hypot(p.x,p.y);}
inline Point normalized(Point p){double n=length(p);return n>0?p*(1/n):Point{};}
inline double cross(Point a,Point b){return a.x*b.y-a.y*b.x;}
// Source: https://github.com/godotengine/godot/blob/4.5/core/math/vector2.h#L158
// Vector2::orthogonal is (y,-x); keep this sign for the authored atlas UVs.
inline Point transverse(Point d,double width){auto axis=normalized({d.x,d.y/depth_ratio});return Point{axis.y,-axis.x*depth_ratio}*width;}
inline double longitudinal(Point d){auto axis=normalized({d.x,d.y/depth_ratio});return length({axis.x,axis.y*depth_ratio});}
inline double projected_gauge(Point direction){return std::abs(cross(transverse(direction,gauge),normalized(direction)));}
// MapCanvasBatch.draw_line's one-pixel floor, applied in the final raster space.
inline double screen_stroke(double authored_width,double zoom){return std::max(authored_width,1/zoom);}
// map_rail_drawing.gd::_draw_switch_state: maxf(2.0,7.0*scale) already
// establishes a two-pixel active-route floor; keep the physical HANDLE palette.
inline double selected_stroke(double authored_width,double zoom){return std::max(authored_width,2/zoom);}
inline std::array<Point,4> strip(Point a,Point b,Point side){return {a-side,a+side,b+side,b-side};}
inline int facing(int code){constexpr int values[]{6,4,6,4,2,2,8,8};return values[(code-18)/2];}
struct SwitchRoute {Point entry,selected;};
inline std::optional<SwitchRoute> switch_route(int code){
    if(code<18||code>33)return std::nullopt;
    const auto ports=rail_ports(code);const auto delta=heading_delta(facing(code));Point entry{delta.x*-.5,delta.y*-.5};
    return SwitchRoute{entry,code%2?ports[2]:(ports[0]==entry?ports[1]:ports[0])};
}
// rail_art.gd::tile_segments: centre/port chords and opposing pairs stay exact.
inline std::vector<std::array<Point,2>> tile_segments(Point center,const std::vector<Point>& endpoints){
    std::vector<std::array<Point,2>> segments;std::vector<bool> paired(endpoints.size());
    for(std::size_t i=0;i<endpoints.size();++i){if(paired[i])continue;for(std::size_t j=i+1;j<endpoints.size();++j){if(paired[j])continue;
        if(length(normalized(endpoints[i]-center)+normalized(endpoints[j]-center))<.00001){segments.push_back({endpoints[i],endpoints[j]});paired[i]=paired[j]=true;break;}}}
    for(std::size_t i=0;i<endpoints.size();++i)if(!paired[i])segments.push_back({center,endpoints[i]});return segments;
}
// rail_art.gd::_draw_ballast repeats the195x200 STRIP at its authored scale.
struct BallastStrip {std::array<Point,4> points,uv;};
inline std::vector<BallastStrip> ballast_plan(Point start,Point finish){
    std::vector<BallastStrip> strips;auto direction=normalized(finish-start);const double extent=length(finish-start),scale=gauge/source_gauge;
    if(extent==0)return strips;
    const double repeat=200*scale*longitudinal(direction);auto side=transverse(direction,195*scale/2);
    for(double cursor=0;cursor<extent;){double end=std::min(cursor+repeat,extent),fraction=(end-cursor)/repeat;
        strips.push_back({strip(start+direction*cursor,start+direction*end,side),{Point{},Point{1,0},Point{1,fraction},Point{0,fraction}}});cursor=end;}
    return strips;
}
// Measured existing PNG6905fe2c... (no new art). Full alpha component and
// external glint sections: tasks/standalone-cpp-20261018/rail-broken-strip-measurements.md.
constexpr SDL_FRect broken_crop{724,774,321,218};
constexpr Point broken_first{12,104.5},broken_last{316,104};
// Owner-approved symmetric calibration of measured endpoint gauges51 and50.
constexpr double broken_gauge=(51.+50.)/2;
struct BrokenRailPlan {SDL_FRect crop;std::array<Point,4> points;};
inline std::optional<BrokenRailPlan> broken_straight_plan(int code){
    if(code!=-2&&code!=-3&&code!=-4&&code!=-5)return std::nullopt;
    const auto ports=rail_ports(code);const Point center{cell/2,cell/2};
    Point first=center+ports[0]*cell,last=center+ports[1]*cell;
    if(first.x>last.x||(first.x==last.x&&first.y>last.y))std::swap(first,last);
    // Same source-basis inverse as TerrainObstacles.registration, with the
    // existing ground transverse vector so the normal gauge is not isotropic.
    const auto axis=normalized(broken_last-broken_first),direction=normalized(last-first);
    const Point normal{axis.y,-axis.x};const double along=length(last-first)/length(broken_last-broken_first);
    const auto across=transverse(direction,gauge)*(1/broken_gauge);
    const auto x=direction*(along*axis.x)+across*normal.x,y=direction*(along*axis.y)+across*normal.y;
    const auto origin=first-x*broken_first.x-y*broken_first.y;
    const auto project=[&](Point p){return origin+x*p.x+y*p.y;};
    return BrokenRailPlan{broken_crop,{project({}),project({broken_crop.w,0}),project({broken_crop.w,broken_crop.h}),project({0,broken_crop.h})}};
}
}
