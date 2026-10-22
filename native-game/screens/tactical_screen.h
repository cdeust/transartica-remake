// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "combat/tactical.hpp"
#include "tactical_living.hpp"
#include "tactical_materials.hpp"
#include "tactical_weapons.hpp"
#include "tactical_motion.hpp"
#include <array>
#include <map>
namespace transartica::panels {
enum class TacticalEvent {None,Save,Options,Completed};
class TacticalScreen {
public:
    TacticalScreen(Canvas&,std::filesystem::path assets);
    void open(const combat::Tactical&);
    void draw(const combat::Tactical&);
    TacticalEvent handle(const SDL_Event&,combat::Tactical&);
    // Host routes returned source audio events and calls completion when outcome!=0.
    void advance_visual(double,combat::Tactical&,const std::vector<combat::Event>&);
    bool paused()const{return paused_;}
    void set_paused(bool value){paused_=value;}
    int selected_actor()const{return selected_actor_;}
    int selected_wagon()const{return selected_wagon_;}
private:
    friend class TacticalMotion;
    Canvas&canvas_;std::filesystem::path assets_;LivingEffects living_;TacticalMaterials materials_;TacticalWeapons weapons_;TacticalMotion motion_;
    struct Sprite {std::filesystem::path path;SDL_Rect region,crop;std::vector<int> tops;};
    struct Geometry {Sprite*sprite{};SDL_FRect box;float factor{};const TacticalMaterials::Material*material{};SDL_Rect source{};};
    struct Flash {combat::Event event;int born{};};
    std::array<Sprite,25> sprites_;std::vector<Flash> effects_;
    bool loaded_{},paused_{},world_drawing_{};Point world_jolt_;int selected_actor_=-1,selected_wagon_=-1,group_size_=1,edge_scroll_{};
    double camera_{};
    SDL_FRect frame()const;SDL_FRect rect(SDL_FRect)const;Point logical(float,float)const;
    void text(std::string_view,float x,float y,int size,SDL_Color={238,202,136,255});
    void label(Point,std::string_view,int size=4,double anchor=0);
    void fill(SDL_FRect,SDL_Color);void picture(const std::filesystem::path&,SDL_Rect,SDL_FRect,SDL_Color={255,255,255,255},bool flip=false,double angle=0,Point pivot={});
    void load();float shown_offset(const combat::Tactical&,int)const;
    Geometry wagon(const combat::Tactical&,int,int);
    int wagon_at(const combat::Tactical&,int,float);
    float surface_y(const Geometry&,float)const;
    float drawn_y(const Geometry&,float)const;
    Point actor_point(const combat::Tactical&,const combat::Actor&);
    void train(const combat::Tactical&,int);
    void soldier(Point,int side,float facing,double phase,float amount,double crouch=0,double strike=0,double recoil=0,double climb=0,double breath=0,SDL_Color tint={255,255,255,255});
    void actors(const combat::Tactical&);
    WeaponGeometry weapon_geometry(const combat::Tactical&,int side,int index);
    void visual_step(const combat::Tactical&);
    void direction(SDL_Keycode,bool shift,combat::Tactical&);
    void activate(combat::Tactical&);
};
}
