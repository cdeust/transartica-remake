// SPDX-License-Identifier: MIT
// Sources: campaign_hazards.gd TABLE0x282..39e,0x463..4b7; stoup_messages.gd.
#include "types.hpp"
#include <algorithm>
#include <cstdlib>
namespace transartica::campaign {
namespace {
constexpr std::array<Cell,7> trap_cells{{{24,4},{26,2},{27,6},{33,7},{38,4},{24,7},{33,1}}};
constexpr std::array<Cell,7> moles{{{50,44},{74,38},{92,57},{83,27},{44,59},{5,28},{66,40}}};
}
void Stoup::push(int id) {if(entries.size()>=10) entries.erase(entries.begin());entries.push_back(id);}
std::optional<int> Stoup::pop() {if(entries.empty()) return {};int id=entries.back();entries.pop_back();return id;}
bool Hazards::intercept_trap(Cell cell,RailNetwork& network) {
    auto found=std::find(trap_cells.begin(),trap_cells.end(),cell);
    if(found==trap_cells.end()) return false;auto index=std::size_t(found-trap_cells.begin());
    if(traps[index]!=-1) return false;
    traps[index]=0;network.set_campaign_tile(cell,-std::abs(network.tile(cell)));return true;
}
bool Hazards::intercept_mole(Cell cell,bool missile,const GameCalendar& calendar,Random& rng) {
    if(std::find(moles.begin(),moles.end(),cell)==moles.end()) return false;
    bool hit=rng.range(0,5)==0;mole_times[cell.x%10]=hit&&!missile?-1:calendar.day*50+calendar.hour;return hit;
}
bool Hazards::player_mole(Cell cell,const GameCalendar& calendar,Random& rng) {
    if(std::find(moles.begin(),moles.end(),cell)==moles.end()) return false;
    auto stamp=mole_times[cell.x%10];
    bool ready=calendar.day-1>stamp/50||(calendar.day>stamp/50&&calendar.hour>=stamp%50);
    int roll=rng.range(0,5); // TIME evaluates rnd6 even for the forced -1 sentinel.
    if(stamp!=-1&&(!ready||roll!=0)) return false;
    mole_times[cell.x%10]=calendar.day*50+calendar.hour;return true;
}
bool Hazards::valid() const {return std::all_of(traps.begin(),traps.end(),[](int value){return value==-1||value==0;});}
}
