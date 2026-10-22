// SPDX-License-Identifier: MIT
// Sources: active map_entities.gd/map_vehicle_object.gd/underground_visual.gd,
// world_view city labels and travel_living_effects measured hero chimney anchors.
#include "world_visual.hpp"
#include "render_check.h"
#include <algorithm>
#include <cmath>
#include <numbers>
namespace transartica {
namespace {const double cell_pixels=std::sqrt(180.*180.+100.*100.); // travel_world.gd CELL_PIXELS.
bool contains(SDL_FRect r,Point p){return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;}}
WorldVisual::WorldVisual(Canvas& c,std::filesystem::path assets):canvas_(c),assets_(std::move(assets)),effects_(assets_){}
int WorldVisual::observation_radius(const std::vector<Wagon>& wagons){int radius=1;for(const auto& w:wagons){if(w.state>=3)continue;if(w.type==4)return 4;if(w.type==10)radius=2;}return radius;}
SDL_Color WorldVisual::train_tint(int code){code=std::abs(code);return {255,255,255,static_cast<Uint8>((code>=38&&code<=52)||(code>=55&&code<=57)?191:255)};}
std::vector<WorldMobile> WorldVisual::visible_enemies(const world::EnemyState& enemies,const Journey& journey,const std::vector<Wagon>& wagons,const RailNetwork& network){
    int radius=observation_radius(wagons);std::vector<WorldMobile> result;
    for(int slot=0;slot<30;++slot){const auto& e=enemies.slots[slot];if(!e.active())continue;auto cell=e.cell(),delta=cell-journey.position;if(std::abs(delta.x)>radius||std::abs(delta.y)>radius)continue;
        Point center=point(cell),direction=point(heading_delta(e.heading));result.push_back({slot,center,center+direction*.5,center-direction*.5,train_tint(network.tile(cell))});}
    return result; // Host sorts these with player poses by drawn center, as Node2D does.
}
void WorldVisual::city_labels(const economy::WorldData& world,const WorldProjection& projection,int selected){
    std::vector<SDL_FRect> occupied;
    for(std::size_t i=0;i<world.cities().size();++i){const auto& city=world.cities()[i];auto p=projection.screen(point(city.anchor)+Point{.5,.5});
        if(contains(projection.viewport,p))city_label(p,city.name,int(i)==selected,projection,occupied);}
}
std::array<Point,2> WorldVisual::smoke_stacks(Point front,Point rear){
    // Actual rigid hero draw rect is438x1886, scaled to0.75 source cells.
    auto center=(front+rear)*.5+Point{.5,.5};double a=std::atan2(front.y-rear.y,front.x-rear.x)-std::numbers::pi/2;
    std::array<Point,2> result;constexpr double x[]{149./438,287./438};for(int i=0;i<2;++i){Point offset{(x[i]-.5)*cell_pixels*.75*438/1886,(1296./1886-.5)*cell_pixels*.75};result[i]=center*cell_pixels+Point{offset.x*std::cos(a)-offset.y*std::sin(a),offset.x*std::sin(a)+offset.y*std::cos(a)};}return result;
}
void WorldVisual::advance_effects(double seconds,int heat,std::span<const Point> stacks){
    if(!std::isfinite(seconds)||seconds<=0)return;remainder_+=seconds;while(remainder_>=.02||std::abs(remainder_-.02)<.00001){remainder_=std::max(0.,remainder_-.02);effects_.advance(.02);if(++tick_%15==0&&heat>0)for(auto point:stacks)effects_.add("smoke",point,{0,-1},1.2);}
}
void WorldVisual::draw_effects(const WorldProjection& projection){effects_.draw_world(canvas_,projection.origin,projection.pixels_per_cell/cell_pixels);}
void WorldVisual::clear_effects(){effects_.clear();remainder_=0;tick_=0;}
}
