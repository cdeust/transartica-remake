// SPDX-License-Identifier: MIT
// Sources: campaign_fauna.gd TABLE0x56f..59e/TIME0x85f..8ed/YODA0x29dc..2af6.
#include "types.hpp"
#include "world/roamer_motion.hpp"
#include <algorithm>
namespace transartica::campaign {
namespace {constexpr std::array<Cell,11> starts{{{8,0},{149,1},{43,13},{107,14},{86,24},{11,27},{144,31},{48,42},{109,40},{124,58},{90,67}}};}
void Fauna::initialize(Random& rng) {if(!initialized) relocate(rng);}
void Fauna::relocate(Random& rng) {cell=starts[rng.range(0,10)];heading=6;phase=counter=0;frozen=false;initialized=true;}
void Fauna::oslo() {cell={126,15};heading=4;phase=counter=0;frozen=true;initialized=true;}
void Fauna::record_player(Cell at,const RailNetwork& network) {
    if(network.is_switch(at)&&(history.empty()||history.front()!=at)) {history.insert(history.begin(),at);if(history.size()>3) history.resize(3);}
}
bool Fauna::advance(const RailNetwork& network,Random& rng,const Hazards& hazards) {
    if(!initialized||frozen) return false;
    if(++counter!=2) return false;
    counter=0;++phase;const bool committed=phase==3;
    if(committed) {phase=0;auto next=world::motion_step(cell,heading,8,network,hazards.traps);cell=next.cell;heading=next.heading;}
    heading=world::motion_turn(cell,heading,phase,history,network,rng);return committed;
}
bool Fauna::valid() const {
    auto in_bounds=[](Cell c){return c.x>=0&&c.x<160&&c.y>=0&&c.y<72;};
    if(!in_bounds(cell)||history.size()>3||heading<1||heading>9||phase<0||phase>2||counter<0||counter>1) return false;
    if(!std::all_of(history.begin(),history.end(),in_bounds)) return false;
    return !frozen||(initialized&&cell==Cell{126,15}&&heading==4&&phase==0&&counter==0);
}
}
