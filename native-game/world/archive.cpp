// SPDX-License-Identifier: MIT
#include "archive.hpp"
#include <iomanip>
#include <sstream>
namespace transartica::world {
std::string serialize(const Archive& a){std::ostringstream o;o<<"TAWORLD 1\n";for(const auto&r:a.enemies.slots)o<<r.kind<<' '<<r.dx<<' '<<r.y<<' '<<r.heading<<' '<<r.phase<<' '<<r.remainder<<' '<<r.speed<<' '<<r.strength<<'\n';o<<a.enemies.switch_history.size()<<'\n';for(Cell c:a.enemies.switch_history)o<<c.x<<' '<<c.y<<'\n';
    const auto&s=a.actions;for(const auto&r:s.mines)o<<r.dx<<' '<<r.y<<' '<<r.signed_day<<' '<<r.wealth<<'\n';o<<s.last_mine_day<<' '<<s.pending_mine<<' '<<s.mine_accepted<<' '<<std::quoted(s.mine_phase)<<' '<<s.resources.slaves<<' '<<s.resources.mammoths<<' '<<s.resources.cranes<<' '<<s.quantity<<' '<<s.countdown<<'\n'<<s.visited_cities.size()<<'\n';for(int city:s.visited_cities)o<<city<<' ';o<<'\n';
    const auto&r=a.roamers;o<<r.initialized<<' '<<r.herds.size()<<'\n';for(const auto&h:r.herds)o<<h.dx<<' '<<h.y<<' '<<h.phase<<' '<<h.heading<<' '<<h.timer<<' '<<h.quantity<<'\n';o<<r.nomad.x<<' '<<r.nomad.y<<' '<<r.nomad.phase<<' '<<r.nomad.heading<<' '<<r.nomad.callback<<' '<<std::quoted(r.pending)<<' '<<r.herd_slot;for(int n:r.commissioned)o<<' '<<n;o<<' '<<r.caught<<' '<<r.hunt_quantity<<' '<<r.countdown<<'\n';return o.str();
}
bool parse(const std::string& text,Archive& out){if(text.size()>65536)return false;std::istringstream in(text);std::string magic;int version;Archive a;if(!(in>>magic>>version)||magic!="TAWORLD"||version!=1)return false;for(auto&r:a.enemies.slots)if(!(in>>r.kind>>r.dx>>r.y>>r.heading>>r.phase>>r.remainder>>r.speed>>r.strength))return false;
    std::size_t count;if(!(in>>count)||count>2)return false;for(std::size_t i=0;i<count;++i){Cell c;if(!(in>>c.x>>c.y))return false;a.enemies.switch_history.push_back(c);}EnemyTrains enemies;if(!enemies.restore(a.enemies))return false;
    auto&s=a.actions;for(auto&r:s.mines)if(!(in>>r.dx>>r.y>>r.signed_day>>r.wealth))return false;Mines mines;if(!mines.restore(s.mines))return false;
    if(!(in>>s.last_mine_day>>s.pending_mine>>s.mine_accepted>>std::quoted(s.mine_phase)>>s.resources.slaves>>s.resources.mammoths>>s.resources.cranes>>s.quantity>>s.countdown>>count)||count>46||s.mine_phase.size()>16)return false;for(std::size_t i=0;i<count;++i){int city;if(!(in>>city))return false;s.visited_cities.push_back(city);}
    auto&r=a.roamers;if(!(in>>r.initialized>>count)||count>10)return false;for(std::size_t i=0;i<count;++i){Herd h;if(!(in>>h.dx>>h.y>>h.phase>>h.heading>>h.timer>>h.quantity))return false;r.herds.push_back(h);}if(!(in>>r.nomad.x>>r.nomad.y>>r.nomad.phase>>r.nomad.heading>>r.nomad.callback>>std::quoted(r.pending)>>r.herd_slot)||r.pending.size()>24)return false;for(int&n:r.commissioned)if(!(in>>n))return false;if(!(in>>r.caught>>r.hunt_quantity>>r.countdown))return false;WorldRoamers roamers;if(!roamers.restore(r))return false;in>>std::ws;if(!in.eof())return false;out=std::move(a);return true;
}
}
