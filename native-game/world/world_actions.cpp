// SPDX-License-Identifier: MIT
#include "world_actions.hpp"
#include <algorithm>
namespace transartica::world {
bool WorldActions::tick_mines(int day,std::vector<int>* stoup){
    if(day<1||day%3||day<=state_.last_mine_day)return false;
    const auto before=mines.snapshot();const auto random=rng_;const auto writes=mines.tick(day,session_.network,rng_);
    if(!apply_(writes)){mines.restore(before);rng_=random;return false;}
    state_.last_mine_day=day;if(stoup){for(int i=0;i<36;++i)if(before[i].wealth>0&&mines.snapshot()[i].wealth<1)stoup->push_back(i+1);for(int i=0;i<36;++i)if(!before[i].signed_day&&mines.snapshot()[i].signed_day)stoup->push_back(i+1);}return true;
}
bool WorldActions::ask_mine(Cell c){if(session_.network.tile(c)!=78)return false;const int slot=mines.slot_for_cell(c);if(slot<0)return false;state_.pending_mine=slot;state_.mine_accepted=false;state_.mine_phase="question";state_.resources={};state_.quantity=state_.countdown=0;session_.engine.brake=true;session_.engine.speed=0;return true;}
bool WorldActions::answer_mine(bool accept){if(state_.pending_mine<0||state_.mine_accepted)return false;if(!accept){state_.pending_mine=-1;state_.mine_phase.clear();return true;}state_.mine_accepted=true;state_.mine_phase="plaque";return true;}
bool WorldActions::advance_mine(){if(state_.pending_mine<0||!state_.mine_accepted)return false;if(state_.mine_phase=="plaque"){state_.resources=mine_resources(session_.wagons);state_.mine_phase="resources";return true;}if(state_.mine_phase=="resources"){const auto&r=mines.snapshot()[state_.pending_mine];auto&e=session_.engine;state_.quantity=mine_quantity(session_.wagons,state_.resources,r.wealth,e.lignite,e.anthracite);int& coal=r.signed_day<0?e.anthracite:e.lignite;coal=credited_coal(coal,state_.quantity);state_.countdown=60;state_.mine_phase="result";return true;}return false;}
void WorldActions::mine_text_tick(){if(state_.mine_phase=="result"&&state_.countdown>0)--state_.countdown;}
bool WorldActions::close_mine(){if(state_.pending_mine<0||!state_.mine_accepted||state_.mine_phase!="result")return false;const auto before=mines.snapshot();const auto writes=mines.prospect(state_.pending_mine,true);if(!apply_(writes)){mines.restore(before);return false;}state_.pending_mine=-1;state_.mine_accepted=false;state_.mine_phase.clear();state_.resources={};state_.quantity=state_.countdown=0;session_.journey.reverse_direction(session_.network);session_.engine.speed=0;return true;}
bool WorldActions::before_entry(Cell c){if(c!=Cell{32,67}||session_.network.tile(c)!=35||session_.wagons.empty())return false;if(session_.wagons.front().type!=8&&session_.wagons.back().type!=8)return false;return apply_({{c,2}});}
void WorldActions::visit_city(int city){if(std::find(state_.visited_cities.begin(),state_.visited_cities.end(),city)==state_.visited_cities.end())state_.visited_cities.push_back(city);}
WorldActionState WorldActions::snapshot()const{auto result=state_;result.mines=mines.snapshot();return result;}
bool WorldActions::restore(const WorldActionState&s){
    if(s.last_mine_day<0||s.last_mine_day%3||s.pending_mine< -1||s.pending_mine>=36||s.countdown<0||s.countdown>60||s.quantity< -32768||s.quantity>32767)return false;
    if((s.mine_phase.empty())!=(s.pending_mine<0))return false;
    if(s.mine_phase!=""&&s.mine_phase!="question"&&s.mine_phase!="plaque"&&s.mine_phase!="resources"&&s.mine_phase!="result")return false;
    if(s.pending_mine>=0&&s.mine_accepted!=(s.mine_phase!="question"))return false;
    if(s.pending_mine<0&&s.mine_accepted)return false;
    if(s.mine_phase!="result"&&(s.quantity||s.countdown))return false;
    if(s.mine_phase=="resources"||s.mine_phase=="result"){if(s.resources.slaves< -32768||s.resources.slaves>32767||s.resources.mammoths< -32768||s.resources.mammoths>32767||s.resources.cranes<0||s.resources.cranes>32767)return false;}else if(s.resources!=MineResources{})return false;
    Mines candidate;if(!candidate.restore(s.mines))return false;if(s.pending_mine>=0&&!s.mines[s.pending_mine].signed_day)return false;
    for(const auto&r:s.mines)if(r.signed_day&&session_.network.tile(r.cell())!=(r.wealth>0?78:79))return false;
    std::vector<int> cities;for(int city:s.visited_cities){if(city<0||city>=46||std::find(cities.begin(),cities.end(),city)!=cities.end())return false;cities.push_back(city);}
    mines=candidate;state_=s;return true;
}
}
