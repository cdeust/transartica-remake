// SPDX-License-Identifier: MIT
#include "roamer_motion.hpp"
#include <algorithm>
#include <cstdlib>
namespace transartica::world {
int motion_turn(Cell c,int h,int phase,const std::vector<Cell>& history,const RailNetwork& n,Random& rng) {
    if(phase!=1) return h;
    const int code=std::abs(n.tile(c)),base=code-code%2;
    constexpr int rules[][3]={{18,6,9},{20,4,7},{22,6,3},{24,4,1},{26,2,3},{28,2,1},{30,8,9},{32,8,7}};
    for(const auto& r:rules) if(base==r[0]&&h==r[1]) {
        const bool known=std::find(history.begin(),history.end(),c)!=history.end();
        const bool diverge=known ? n.is_switch(c)&&n.tile(c)%2==1 : rng.range(0,1)==1;
        return diverge?r[2]:h;
    }
    return n.turn(c,h);
}
MotionStep motion_step(Cell c,int h,int bit,const RailNetwork& n,const std::array<int,7>& traps) {
    const Cell candidate=c+heading_delta(h);
    if(bit!=2) {
        // campaign_hazards.gd TRAPS, TIME0x2117.
        constexpr std::array<Cell,7> cells{{{24,4},{26,2},{27,6},{33,7},{38,4},{24,7},{33,1}}};
        bool blocked=false;
        for(std::size_t i=0;i<cells.size();++i) if(cells[i]==candidate&&bit==16&&n.tile(candidate)<0&&traps[i]==-1) blocked=true;
        constexpr int obstacles[]={34,35,36,37,65,67,69,78,79,107,114,116,120};
        if(blocked||std::find(std::begin(obstacles),std::end(obstacles),std::abs(n.tile(candidate)))!=std::end(obstacles)) return {c,10-h};
    }
    return {candidate,h};
}
}
