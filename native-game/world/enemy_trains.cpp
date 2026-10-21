// SPDX-License-Identifier: MIT
// Exact source: scripts/enemy_trains.gd; tasks/evidence/enemy-trains.md.
#include "enemy_trains.hpp"
#include "roamer_motion.hpp"
#include <algorithm>
#include <cstdlib>
namespace transartica::world {
void EnemyTrains::reset() { state_={}; presence_.fill(0); }
void EnemyTrains::mark(Cell c,bool value) { if(c.x>=0&&c.x<160&&c.y>=0&&c.y<73) presence_[c.x*73+c.y]=value; }
bool EnemyTrains::has_presence(Cell c) const { return c.x>=0&&c.x<160&&c.y>=0&&c.y<73&&presence_[c.x*73+c.y]; }
const EnemyTrain* EnemyTrains::at(int slot) const { return slot>=0&&slot<30?&state_.slots[slot]:nullptr; }
bool EnemyTrains::set_damage(int slot,int kind,int strength) { if(slot<0||slot>=30||strength<0) return false; state_.slots[slot].kind=kind; state_.slots[slot].strength=strength; return true; }
int EnemyTrains::spawn(int difficulty,Random& rng) {
    int slot=0; while(slot<=28&&state_.slots[slot].kind!=0) ++slot; if(slot>28) return -1;
    constexpr int points[][3]={{-31,40,4},{-28,40,6},{-29,41,2},{75,25,6},{72,25,8},{73,26,4},{38,61,8},{35,61,4},{37,62,2}};
    const auto& p=points[rng.range(0,8)]; auto& r=state_.slots[slot];
    r.dx=p[0];r.y=p[1];r.heading=p[2];r.kind=1;r.phase=2;r.speed=20+slot/2+difficulty;
    const int extra=rng.range(0,1); const int pool=rng.range(0,5);
    r.strength=slot/2+difficulty+1+extra+20*pool; mark(r.cell(),true); return slot;
}
int EnemyTrains::maybe_spawn_on_hour(int hour,int difficulty,Random& rng) { return difficulty==4&&hour%12==0?spawn(difficulty,rng):-1; }
int EnemyTrains::maybe_spawn_on_day(int day,int difficulty,Random& rng) { return difficulty>=0&&difficulty<4&&day%(4-difficulty)==0?spawn(difficulty,rng):-1; }
void EnemyTrains::sync_scripted_slot(Cell c) {
    if(c==Cell{152,66}&&state_.slots[29].kind!=2) { state_.slots[29]={-1,114,62,2,0,0,0,19}; mark({154,62},true); }
    else if(c==Cell{151,66}) { mark({154,62},false); state_.slots[29]={}; }
}
void EnemyTrains::remove(int slot) { if(slot<0||slot>=30) return; mark(state_.slots[slot].cell(),false);state_.slots[slot]={2,0,0,0,0,0,0,0}; }
void EnemyTrains::record_player_position(Cell c,const RailNetwork& n) { if(n.is_switch(c)) { state_.switch_history.insert(state_.switch_history.begin(),c); if(state_.switch_history.size()>2) state_.switch_history.resize(2); } }
void EnemyTrains::advance(EnemyTrain& r,const RailNetwork& n,Random& rng,int player_heading) {
    if(!r.active()) return;
    if(std::abs(r.kind)>49) { r.kind=r.kind>0?1:-1; return; }
    if(std::abs(r.kind)>=5) { r.kind+=r.kind>0?-1:1; return; }
    const Cell here=r.cell(); const int code=std::abs(n.tile(here));
    int speed=n.progress_speed(here,r.heading,r.speed);
    if(code==15||code==16) speed=r.speed*((code==15&&(player_heading==4||player_heading==6))||(code==16&&(player_heading==2||player_heading==8))?2:1);
    r.remainder+=std::min(speed,45)/2; if(r.remainder<=22) return;
    r.remainder-=23; if(++r.phase<3) return; r.phase=0;
    const std::vector<Cell> empty;
    const int heading=motion_turn(here,r.heading,1,r.strength>=0?state_.switch_history:empty,n,rng);
    const Cell candidate=here+heading_delta(heading); const int target=n.tile(candidate);
    if(target<0&&target>-105) {r.kind=5*(r.kind>0?1:-1);return;}
    constexpr int obstacles[]={13,113,34,35,36,37,65,67,69,78,79,107,114,116,120};
    if(std::find(std::begin(obstacles),std::end(obstacles),std::abs(target))!=std::end(obstacles)) { r.heading=10-r.heading;r.kind=-r.kind;r.phase=std::abs(r.phase-2)-1;r.remainder=23;return; }
    mark(here,false);mark(candidate,true);r.dx=candidate.x-40;r.y=candidate.y;r.heading=heading;
}
void EnemyTrains::advance_cycle(const RailNetwork& n,Random& rng,int player_heading) { for(auto& r:state_.slots) advance(r,n,rng,player_heading); }
int EnemyTrains::encounter_at(Cell c) const { if(!has_presence(c)) return -1;for(int i=0;i<30;++i) if(state_.slots[i].kind!=0&&state_.slots[i].cell()==c) return i;return -1; }
bool EnemyTrains::restore(const EnemyState& s) {
    if(s.switch_history.size()>2) return false;
    for(Cell c:s.switch_history) if(c.x<0||c.x>=160||c.y<0||c.y>=73) return false;
    for(const auto& r:s.slots) if(r.active()&&(r.strength<0||r.heading<1||r.heading>9||r.heading==5||r.cell().x<0||r.cell().x>=160||r.y<0||r.y>=73)) return false;
    state_=s;presence_.fill(0);for(const auto& r:s.slots) if(r.active()) mark(r.cell(),true);return true;
}
}
