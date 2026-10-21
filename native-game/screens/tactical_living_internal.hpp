// SPDX-License-Identifier: MIT
#pragma once
#include "tactical_living.hpp"
#include "tactical_visual_random.hpp"
#include <map>
#include <limits>
#include <optional>
namespace transartica::panels {
namespace visual {
struct Color{double r{},g{},b{},a=1;};
struct Projection{float x{},y{},scale=1;};
Projection projection(Canvas&);
extern thread_local std::optional<Projection> world_projection;
Color color(unsigned rgb,double a=1);Color lerp(Color,Color,double);SDL_Color sdl(Color);
Point norm(Point);Point from_angle(double);Point rotated(Point,double);Point snap(Point);
struct Particle {std::string kind;Point point,velocity,extent,origin;Color color;int age{},life{};double scale=1,angle{},floor=std::numeric_limits<double>::infinity();bool trail{},radial{};};
struct Emitter {std::string kind;Point point,direction;int age{},duration{};bool explosive{},gun{};double scale{};};
struct Pending {int clock{};Point point;std::string material;};
struct Mote {Point point,velocity;double phase{},heat{},cool{};int shade{},life{};bool pale{};std::vector<Cell>mask;std::vector<double>rim;};
struct TextureDeleter{void operator()(SDL_Texture*p)const{if(p)SDL_DestroyTexture(p);}};
using Texture=std::unique_ptr<SDL_Texture,TextureDeleter>;
struct Blast {std::string kind;Point point,direction,anchor;double scale{};bool blast{},gun{},dirty=true;int age{},life{},width{},height{};std::vector<Mote>motes;std::vector<unsigned char>bytes;Texture texture;};
void polygon(Canvas&,const std::vector<Point>&,Color,SDL_BlendMode=SDL_BLENDMODE_BLEND);
void line(Canvas&,Point,Point,double,Color,SDL_BlendMode=SDL_BLENDMODE_BLEND);
void box(Canvas&,Point,Point,Color,SDL_BlendMode=SDL_BLENDMODE_BLEND);
void circle(Canvas&,Point,double,Color,SDL_BlendMode=SDL_BLENDMODE_BLEND);
}
struct LivingEffects::Impl {
    std::filesystem::path assets,atlas_path;std::map<std::string,SDL_Rect>regions;bool loaded{};
    std::vector<visual::Particle>particles;std::vector<visual::Emitter>emitters;std::vector<visual::Pending>pending;std::vector<visual::Blast>fields;visual::Texture halo;
    Random random,volume_random;double remainder{},shake{};int serial{},volume_serial{},clock{};
    explicit Impl(std::filesystem::path path):assets(std::move(path)){}
    double rnd(double lo,double hi){return art::uniform(random,lo,hi);}int randi(int lo,int hi){return random.range(lo,hi);}
    void launch(std::string,Point,Point,int,Point,visual::Color,double=1,double=0,double=std::numeric_limits<double>::infinity());
    void plume(const visual::Emitter&);void burst(const visual::Emitter&,int);void ricochet(Point,const std::string&);
    void step();void draw_particles(Canvas&,Point,bool light);
    void atlas(Canvas&,const std::string&,Point,Point,visual::Color,double);
    void load(Canvas&);
    void add_volume(std::string,Point,Point,double);visual::Mote mote(const visual::Blast&,int);void step_volume();void draw_volume(Canvas&,Point);void raster(visual::Blast&,Canvas&);
};
}
