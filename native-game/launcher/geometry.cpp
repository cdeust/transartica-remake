// SPDX-License-Identifier: MIT
// Source launcher_geometry.gd BERTA0x460..4c3/CARTE0x15b0..1a69 integer tables.
#include "launcher.hpp"
#include <algorithm>
#include <cstdlib>
namespace transartica::launcher {
int angle(int bearing){int base=bearing*113/10;if(bearing>=17)--base;return ((90-base)%360+360)%360;}
std::optional<Geometry> calculate(int bearing,int distance,Cell origin,const world::EnemyTrains& enemies){
    if(bearing<0||bearing>=32||distance<50||distance>9999)return {};
    constexpr std::array<int,32> angles{0,11,23,34,45,57,68,79,90,101,112,124,135,146,158,169,180,192,203,214,225,237,248,259,270,281,292,304,315,326,337,349};
    constexpr std::array<Cell,32> vectors{{{100,0},{98,19},{92,39},{83,56},{71,71},{54,84},{37,93},{19,98},{0,100},{-19,98},{-37,93},{-56,83},{-71,71},{-83,56},{-93,38},{-98,19},{-100,0},{-98,-21},{-92,-39},{-83,-56},{-71,-71},{-54,-84},{-37,-93},{-19,-98},{0,-100},{19,-98},{37,-93},{56,-83},{71,-71},{83,-56},{92,-39},{98,-19}}};
    constexpr std::array<int,32> groups{0,0,0,1,1,1,2,2,2,2,2,3,3,3,4,4,4,4,4,5,5,5,6,6,6,6,6,7,7,7,0,0};
    auto found=std::find(angles.begin(),angles.end(),angle(bearing));if(found==angles.end())return {};
    auto index=std::size_t(found-angles.begin());int length=distance<2000?distance*16/7:distance/7*16;
    auto vector=vectors[index];int dx=length<300?vector.x*length/100:length/100*vector.x,dy=length<300?vector.y*length/100:length/100*vector.y;
    Cell nominal=origin+Cell{dx/16,-dy/16};int radius=std::abs(length)/96;Geometry g;g.origin=origin;g.group=groups[index];
    for(int slot=0;slot<30;++slot){const auto* enemy=enemies.at(slot);if(!enemy)continue;auto cell=enemy->cell();
        if(cell.x<nominal.x+radius&&cell.x>nominal.x-radius&&cell.y<nominal.y+radius&&cell.y>nominal.y-radius&&enemy->kind!=2){g.target=slot;g.record=*enemy;dx=(cell.x-origin.x)*16;dy=-(cell.y-origin.y)*16;break;}}
    int divisor=length/8;int sx=dx/divisor,sy=dy/divisor;if(sx==0&&sy==0)return {};
    g.delta={dx,dy};g.step={sx,sy};g.count=std::abs(sx)>std::abs(sy)?std::abs(dx/sx):std::abs(dy/sy);return g;
}
Cell screen_point(const Geometry& g,Cell camera,int tick,bool final){auto offset=final?g.delta:Cell{g.step.x*tick,g.step.y*tick};return {offset.x+(g.origin.x-camera.x)*16+7,7+(g.origin.y-camera.y)*16-offset.y};}
}
