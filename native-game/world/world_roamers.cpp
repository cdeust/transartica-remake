// SPDX-License-Identifier: MIT
// TABLE4c5..5ee; TIME67e..961; YODA24c8..25ba; TEXTEK171b..1ff9.
#include "world_roamers.hpp"
#include <algorithm>
namespace transartica::world {
namespace {constexpr std::array<Cell,11> starts{{{8,0},{149,1},{43,13},{107,14},{86,24},{11,27},{144,31},{48,42},{109,40},{124,58},{90,67}}};}
void WorldRoamers::place_nomad(Cell c){state_.nomad={c.x,c.y,0,6,0};}
void WorldRoamers::initialize(Random& rng,const std::function<Cell(Random&)>& fauna){if(state_.initialized)return;for(int i=0;i<10;++i){Herd row;row.dx=rng.range(0,129)-30;row.y=rng.range(0,59)+5;row.heading=rng.range(1,9);row.timer=rng.range(0,39)+40;row.quantity=rng.range(0,44)+5;state_.herds.push_back(row);}const Cell fauna_cell=fauna(rng);int chosen=rng.range(0,10);while(starts[chosen]==fauna_cell)chosen=rng.range(0,10);place_nomad(starts[chosen]);state_.initialized=true;}
bool WorldRoamers::has_presence(Cell c,int bit)const{if(!state_.initialized)return false;if(bit==4)return state_.nomad.cell()==c;if(bit!=2)return false;for(const auto&r:state_.herds)if(r.quantity>0&&r.cell()==c)return true;return false;}
std::vector<Observation> WorldRoamers::advance(const RailNetwork& n,Random& rng,const std::array<int,7>& traps){std::vector<Observation> out;if(!state_.initialized)return out;for(std::size_t i=0;i<state_.herds.size();++i){auto&r=state_.herds[i];if(r.quantity<=0)continue;if(++r.phase==9){r.phase=0;const auto moved=motion_step(r.cell(),r.heading,2,n);r.dx=moved.cell.x-40;r.y=moved.cell.y;out.push_back({moved.cell,int(i)+40,2});}--r.timer;bool redirected=true;if(r.dx>114)r.heading=rng.range(0,2)*3+1;else if(r.dx< -35)r.heading=rng.range(0,2)*3+3;else if(r.y<5)r.heading=rng.range(1,3);else if(r.y>66)r.heading=rng.range(7,9);else if(r.timer<0)r.heading=rng.range(1,9);else redirected=false;if(redirected)r.timer=rng.range(0,39)+30;}
    auto&r=state_.nomad;if(++r.callback==4){r.callback=0;if(++r.phase==3){r.phase=0;const auto moved=motion_step(r.cell(),r.heading,4,n,traps);r.x=moved.cell.x;r.y=moved.cell.y;r.heading=moved.heading;out.push_back({moved.cell,70,4});}r.heading=motion_turn(r.cell(),r.heading,r.phase,{},n,rng);}return out;
}
std::string WorldRoamers::encounter(Cell c,const RailNetwork& n,Random& rng,int bit){if(!state_.pending.empty()||!state_.initialized)return {};const int code=n.tile(c);const bool hunt=bit!=4&&!((code>=38&&code<=49)||code==55);for(std::size_t i=0;i<state_.herds.size();++i){auto&r=state_.herds[i];if(hunt&&r.quantity>0&&r.cell()==c){state_.herd_slot=int(i);r.dx=rng.range(0,139)-30;r.y=rng.range(0,59)+5;r.heading=rng.range(1,9);r.timer=rng.range(0,39)+40;state_.pending="herd_question";return state_.pending;}}if(bit!=2&&has_presence(c,4)){state_.pending="nomad_question";return state_.pending;}return {};}
bool WorldRoamers::answer(bool yes,Random& rng,const std::vector<Wagon>& wagons){if(state_.pending=="nomad_question"){place_nomad(starts[rng.range(0,10)]);state_.pending=yes?"nomad_trade":"";return true;}if(state_.pending!="herd_question")return false;if(!yes){state_.pending.clear();return true;}state_.commissioned={};for(const auto&w:wagons){if(w.type==7)state_.commissioned[0]+=3-w.quantity;else if(w.type==5||w.type==6)state_.commissioned[1]+=w.quantity;else if(w.type==23||w.type==24)state_.commissioned[2]+=w.quantity;}state_.pending="hunt_commissioned";return true;}
bool WorldRoamers::finish_hunt(std::vector<Wagon>& wagons){if(state_.pending!="hunt_commissioned"||state_.herd_slot<0)return false;int divisor=10-(state_.commissioned[1]+state_.commissioned[2])/40;if(divisor<=1)divisor=2;auto& herd=state_.herds[state_.herd_slot];state_.hunt_quantity=herd.quantity;state_.caught=std::min(state_.hunt_quantity/divisor+1,state_.commissioned[0]);herd.quantity-=state_.caught;int remaining=state_.caught;for(auto&w:wagons)if(w.type==7&&remaining>0){w.quantity+=remaining;if(w.quantity>3){remaining=w.quantity-3;w.quantity=3;}}state_.countdown=24;state_.pending="hunt_result";return true;}
void WorldRoamers::textek_tick(){if(state_.pending=="hunt_result"&&state_.countdown>0)--state_.countdown;}
void WorldRoamers::close(){state_.pending.clear();state_.herd_slot=-1;}
bool WorldRoamers::restore(const RoamerState&s){
    if(s.herds.size()!=(s.initialized?10:0)||s.herd_slot< -1||s.herd_slot>9||s.countdown<0||s.countdown>24||s.caught<0||s.caught>49||s.hunt_quantity<0||s.hunt_quantity>49)return false;
    for(const auto&r:s.herds)if(r.dx< -32768||r.dx>32767||r.y< -32768||r.y>32767||r.phase<0||r.phase>8||r.heading<1||r.heading>9||r.timer< -32768||r.timer>32767||r.quantity<0||r.quantity>49)return false;
    const auto&r=s.nomad;if(r.x< -32768||r.x>32767||r.y< -32768||r.y>32767||r.phase<0||r.phase>2||r.heading<1||r.heading>9||r.callback<0||r.callback>3)return false;
    if(s.pending!=""&&s.pending!="nomad_question"&&s.pending!="nomad_trade"&&s.pending!="herd_question"&&s.pending!="hunt_commissioned"&&s.pending!="hunt_result")return false;
    if((s.pending.starts_with("hunt")||s.pending=="herd_question")&&s.herd_slot<0)return false;
    if(s.herd_slot>=int(s.herds.size()))return false;
    for(int n:s.commissioned)if(n<0||n>32767)return false;state_=s;return true;
}
}
