// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "core/session.hpp"
#include "world/enemy_trains.hpp"
#include "economy/world_data.hpp"
#include "screens/tactical_living.hpp"
#include <functional>
#include <map>
#include <optional>
#include <span>
namespace transartica {
struct WorldProjection {
    Point origin;double pixels_per_cell{};SDL_FRect viewport;
    Point screen(Point p)const{return origin+p*pixels_per_cell;}
};
struct WorldMobile {int slot{};Point center,front,rear;SDL_Color tint{255,255,255,255};};
struct WorldHeadingLayout {std::vector<Point> points;SDL_FRect arrow{},label{};};
class WorldVisual {
public:
    WorldVisual(Canvas&,std::filesystem::path game_assets);
    void rails(const RailNetwork&,const WorldProjection&);
    static int observation_radius(const std::vector<Wagon>&);
    static std::vector<WorldMobile> visible_enemies(const world::EnemyState&,const Journey&,const std::vector<Wagon>&,const RailNetwork&);
    static SDL_Color train_tint(int code);
    void city_labels(const economy::WorldData&,const WorldProjection&,int selected=-1);
    void cities(const economy::WorldData&,const RailNetwork&,const WorldProjection&,std::span<const SDL_FRect> paintings,int selected=-1);
    void heading(const Journey&,Point visual_position,SDL_FRect occupied,const WorldProjection&);
    static WorldHeadingLayout heading_layout(Point center,Point direction,Point text_extent,SDL_FRect occupied,SDL_FRect viewport);
    static std::array<Point,2> smoke_stacks(Point front,Point rear);
    void advance_effects(double seconds,int heat,std::span<const Point> projected_stacks);
    void draw_effects(const WorldProjection&);
    void clear_effects();
    std::size_t rail_cache_entries()const{return rails_.size();}
private:
    struct Vertex {Point point,uv;SDL_Color color;};
    enum class Surface { Color,Track,Ballast };
    struct Group {int layer{};Surface surface{};std::vector<Vertex> vertices;};
    using Mesh=std::vector<Group>;
    Canvas& canvas_;std::filesystem::path assets_;std::map<std::pair<int,bool>,Mesh> rails_;
    panels::LivingEffects effects_;double remainder_{};int tick_{};
    Point rail_texture_size_{};
    double rail_mesh_zoom_{};
    void city_label(Point,std::string_view,bool,const WorldProjection&,std::vector<SDL_FRect>&);
    Mesh build_rail(int,bool,double);
    void polygon(Mesh&,int,std::span<const Point>,SDL_Color,std::optional<SDL_FRect> crop={});
    void line(Mesh&,int,Point,Point,SDL_Color,double,bool texture=false);
    void segment(Mesh&,Point,Point,bool);
    void ballast(Mesh&,Point,Point);
    void join(Mesh&,Point,Point,Point,int layer=3,bool selected=false,double minimum_width=0);
    void mechanism(Mesh&,Point,Point,Point,double);
    void buffer(Mesh&,Point,Point);
};
}
