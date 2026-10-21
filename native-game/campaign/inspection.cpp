// SPDX-License-Identifier: MIT
// Source inspection_car.gd TIME0xc91..1126/CARTE0x1295..159e,100 cycles.
#include "controller.hpp"
#include <algorithm>
#include <cstdlib>
#include <stdexcept>
namespace transartica::campaign {
InspectionResult inspect(Session& session,State& state,Random& rng,Host& host,int heading,bool missile) {
    InspectionResult result;result.missile=missile;
    if(heading!=2&&heading!=4&&heading!=6&&heading!=8) return result;
    Cell cell=session.journey.position;int moving=session.journey.heading,phase=session.journey.phase;
    bool reverses=(heading==2&&moving==8)||(heading==8&&moving==2)||(heading==6&&(moving==4||moving==1||moving==7))||(heading==4&&(moving==3||moving==6||moving==9));
    if(reverses) {moving=10-moving;phase=std::abs(phase-2)-1;}
    constexpr std::array<int,12> obstacles{34,35,36,37,65,67,69,78,79,114,-116,-120};
    for(int cycle=0;cycle<100;++cycle) {
        if(++phase==3) {
            phase=0;cell=cell+heading_delta(moving);result.path.push_back(cell);
            if(state.hazards.intercept_trap(cell,session.network)||cell==session.journey.position) {result.obstacle=true;break;}
            int slot=host.enemy_at(cell);
            if(slot>=0) {
                if(missile&&slot!=29) {
                    auto enemy=host.enemy_info(slot);if(!enemy) throw std::runtime_error("Encountered inspection target has no enemy record");
                    host.set_enemy_damage(slot,5*((enemy->kind>0)-(enemy->kind<0)),enemy->strength-(enemy->strength%100)/3);
                }
                result.obstacle=true;break;
            }
            int code=session.network.tile(cell);
            if(std::find(obstacles.begin(),obstacles.end(),code)!=obstacles.end()||(code<0&&code>-108)||state.hazards.intercept_mole(cell,missile,session.calendar,rng)) {result.obstacle=true;break;}
        }
        if(phase==1) moving=session.network.turn(cell,moving);
    }
    consume(session.wagons,3);if(missile) consume(session.wagons,2);
    result.cell=cell;result.message=result.obstacle?10:11;return result;
}
}
