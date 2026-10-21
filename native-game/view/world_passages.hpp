// SPDX-License-Identifier: MIT
#pragma once
#include "world_visual.hpp"
#include <array>
#include <map>
#include <optional>

namespace transartica {
// Texture coordinates retain double precision until normalized SDL vertices.
// V4/H2 regression: float pixel origin + width exceeded a 1322px painting.
struct PassageSource { double x,y,w,h; };
struct PassagePiece {
    std::filesystem::path texture;
    PassageSource source;
    std::array<Point,4> points;
    Cell cell;
    int code{};
};
struct MouthOpening { Point position,direction; };
// Source terrain_portals.gd / travel_cover.gd / terrain_obstacles.gd.
// Painting cover is the owner's18Oct visibility adaptation, not legacy masks.
class WorldPassages {
public:
    WorldPassages(Canvas&,std::filesystem::path assets);
    static bool owns_rails(Cell,int code);
    static bool underground(int code);
    std::optional<MouthOpening> mouth_opening(Cell) const;
    bool fully_covered(const RailNetwork&,Point front,Point rear,Point rail_midpoint,
                       int heading,const std::array<Point,4>& world_quad) const;
    void add_painting(SDL_FRect world,SDL_Rect crop,std::filesystem::path);
    std::vector<PassagePiece> portal_plan(const RailNetwork&,const WorldProjection&,bool foreground) const;
    std::vector<PassagePiece> obstacle_plan(const RailNetwork&,const WorldProjection&) const;
    void floor(const RailNetwork&,const WorldProjection&);
    void cover(const RailNetwork&,const WorldProjection&);
    void foreground(const RailNetwork&,const WorldProjection&);
    void draw(const PassagePiece&);
private:
    struct Portal {SDL_Rect crop;Point anchor,endpoint;double gauge;};
    struct Obstacle {SDL_Rect crop;Point first,last;double gauge;};
    struct Painting {SDL_FRect world;SDL_Rect crop;std::filesystem::path path;};
    Canvas& canvas_;
    std::filesystem::path root_;
    std::map<int,Portal> portals_;
    std::map<int,Obstacle> obstacles_;
    std::vector<Painting> paintings_;
    void load_portals();
    void load_obstacles();
    void cover_painting(SDL_FRect,const WorldProjection&);
    void stipple(Cell,int,const WorldProjection&);
};
}
