// SPDX-License-Identifier: MIT
#pragma once
#include "tactical_living_internal.hpp"
#include "combat/tactical.hpp"
#include <functional>
namespace transartica::panels {
struct WeaponGeometry {SDL_FRect box;std::function<double(double)> surface;};
struct WeaponMount {Point base,body,muzzle,breech,pivot,direction;double angle{};};
class TacticalWeapons {
public:
    struct Round {int side{},wagon{},number{};double heat{};};
    void fire(int side,int wagon,const std::string&kind);
    std::vector<Round> step();
    void settle(const combat::TacticalState&,const std::function<WeaponGeometry(int,int)>&,LivingEffects&,Point world_offset={});
    WeaponMount mount(const WeaponGeometry&,int side,int wagon,bool machine_gun)const;
    void draw(Canvas&,const std::filesystem::path&assets,const WeaponGeometry&,int side,int wagon,bool machine_gun,int health)const;
    void clear(){rigs_.clear();resting_.clear();}
private:
    struct Rig {int side{},wagon{},window{},age{},rounds{};std::string kind;double phase{},speed{},recoil{},heat{};};
    struct Rest {double x{},y{},vx{},vy{},angle{},spin{};int health{};double rest{};};
    std::map<std::pair<int,int>,Rig>rigs_;std::map<std::pair<int,int>,Rest>resting_;
    Rig rig(int side,int wagon)const;
    static Point extent(int side,bool machine_gun);static double reach(int side,bool machine_gun);
};
}
