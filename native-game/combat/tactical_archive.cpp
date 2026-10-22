// SPDX-License-Identifier: MIT
// scripts/tactical_restore.gd constraints, WDECOR arrays and save boundary.
#include "tactical.hpp"
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
namespace transartica::combat {
namespace {bool range(int n,int lo,int hi){return n>=lo&&n<=hi;}bool valid(const TacticalState&s){
    if(!s.random.valid())return false;
    for(int side=0;side<2;++side){if(s.trains[side].empty()||s.trains[side].size()>101||!range(s.offsets[side],-100000,100000)||!range(s.velocities[side],-1,1))return false;for(const auto&c:s.trains[side])if(!range(c.kind,1,25)||!range(c.health,0,3)||!range(c.quantity,c.kind==Barracks?-128:0,100000)||!range(c.reload,0,23))return false;}
    const int limit=s.columns*16/2-160;if(!range(s.columns,80,416)||!range(s.camera_offset,-limit,limit)||!range(s.scan,0,s.columns*7-1)||!range(s.scan_side,0,1)||s.sweep<0||!range(s.ai_wagon,0,int(s.trains[1].size())-1)||!range(s.ai_wait,0,119)||!range(s.ai_direction,-1,1)||s.ticks<0||s.next_id<0||!range(s.outcome,0,2)||!range(s.aggressiveness,0,99)||!std::isfinite(s.remainder)||std::abs(s.remainder)>1)return false;
    if(!range(s.initial_pools.soldiers,-12800,100000)||!range(s.initial_pools.mammoths,0,100000)||!range(s.initial_pools.guns,0,100000)||!range(s.survivors.soldiers,-32768,s.initial_pools.soldiers)||!range(s.survivors.mammoths,0,s.initial_pools.mammoths)||!range(s.army_strength[0],-32768,32767)||!range(s.army_strength[1],-32768,32767))return false;
    for(const auto&[id,a]:s.actors){if(id!=a.id||!range(id,0,s.next_id-1)||!range(a.count,1,31)||!range(a.side,0,1)||!range(a.roof,-1,1)||!range(a.direction,0,8)||a.processed< -1)return false;if(a.roof>=0){if(a.y!=-1||!range(a.x,0,int(s.trains[a.roof].size())*4-1))return false;}else{const int span=a.mammoth?2:1;if(a.x<0||a.x+span>s.columns||a.y<0||a.y+span>7)return false;}}
    for(const auto&c:s.charges)if(!range(c.side,0,1)||!range(c.owner,0,1)||!range(c.fuse,1,5)||!range(c.slot,1,int(s.trains[c.side].size())*4-1))return false;
    if(s.original.empty()||s.original.size()>100)return false;for(const auto&w:s.original)if(!range(w.type,1,25)||!range(w.state,0,3)||!range(w.goods,0,25)||!range(w.quantity,w.type==23||w.type==24?-128:0,100000))return false;
    // Strengthen the original parser: result write-back must have exactly one
    // corresponding roster entry plus each intact engine's companion.
    std::size_t roster=0;for(const auto&w:s.original){if(roster>=s.trains[0].size())return false;if(w.type==1&&w.state<3){if(roster+1>=s.trains[0].size()||s.trains[0][roster].kind!=Locomotive||s.trains[0][roster+1].kind!=Companion)return false;++roster;}++roster;}return roster==s.trains[0].size();
}}
bool Tactical::restore(const TacticalState&s){if(!valid(s))return false;s_=s;events_.clear();return true;}
std::string serialize(const TacticalState&s){std::ostringstream o;o<<std::setprecision(17)<<"TACOMBAT 1\n"<<s.random.state<<' '<<s.random.increment<<'\n';for(int side=0;side<2;++side){o<<s.trains[side].size()<<' '<<s.offsets[side]<<' '<<s.velocities[side]<<'\n';for(const auto&c:s.trains[side])o<<c.kind<<' '<<c.quantity<<' '<<c.health<<' '<<c.reload<<'\n';}o<<s.camera_offset<<' '<<s.aggressiveness<<' '<<s.columns<<' '<<s.scan<<' '<<s.scan_side<<' '<<s.sweep<<' '<<s.ai_wagon<<' '<<s.ai_wait<<' '<<s.ai_direction<<' '<<s.ticks<<' '<<s.next_id<<' '<<s.outcome<<' '<<s.settled<<' '<<s.remainder<<'\n';o<<s.initial_pools.soldiers<<' '<<s.initial_pools.mammoths<<' '<<s.initial_pools.guns<<' '<<s.survivors.soldiers<<' '<<s.survivors.mammoths<<' '<<s.survivors.guns<<' '<<s.army_strength[0]<<' '<<s.army_strength[1]<<'\n';o<<s.actors.size()<<'\n';for(const auto&[id,a]:s.actors)o<<id<<' '<<a.side<<' '<<a.x<<' '<<a.y<<' '<<a.count<<' '<<a.mammoth<<' '<<a.roof<<' '<<a.direction<<' '<<a.processed<<'\n';o<<s.charges.size()<<'\n';for(const auto&c:s.charges)o<<c.side<<' '<<c.slot<<' '<<c.fuse<<' '<<c.owner<<'\n';o<<s.original.size()<<'\n';for(const auto&w:s.original)o<<w.type<<' '<<w.state<<' '<<w.goods<<' '<<w.quantity<<'\n';return o.str();}
bool parse(const std::string&text,TacticalState&out){
    // Bounds derive from 2*101 cars, columns*7 field cells plus 2*404 roof
    // cells, at most one charge per roof cell, and 100 original wagons.
    constexpr std::size_t actor_limit=416*7+2*101*4,charge_limit=2*101*4;
    if(text.size()>actor_limit*128+charge_limit*64+2*101*64+100*64)return false;
    std::istringstream in(text);std::string magic;int version;TacticalState s;std::size_t count;if(!(in>>magic>>version)||magic!="TACOMBAT"||version!=1||!(in>>s.random.state>>s.random.increment))return false;
    for(int side=0;side<2;++side){if(!(in>>count>>s.offsets[side]>>s.velocities[side])||count<1||count>101)return false;for(std::size_t i=0;i<count;++i){Car c;if(!(in>>c.kind>>c.quantity>>c.health>>c.reload))return false;s.trains[side].push_back(c);}}
    if(!(in>>s.camera_offset>>s.aggressiveness>>s.columns>>s.scan>>s.scan_side>>s.sweep>>s.ai_wagon>>s.ai_wait>>s.ai_direction>>s.ticks>>s.next_id>>s.outcome>>s.settled>>s.remainder>>s.initial_pools.soldiers>>s.initial_pools.mammoths>>s.initial_pools.guns>>s.survivors.soldiers>>s.survivors.mammoths>>s.survivors.guns>>s.army_strength[0]>>s.army_strength[1]>>count)||count>actor_limit)return false;
    for(std::size_t i=0;i<count;++i){Actor a;if(!(in>>a.id>>a.side>>a.x>>a.y>>a.count>>a.mammoth>>a.roof>>a.direction>>a.processed)||s.actors.contains(a.id))return false;s.actors.emplace(a.id,a);}if(!(in>>count)||count>charge_limit)return false;for(std::size_t i=0;i<count;++i){Charge c;if(!(in>>c.side>>c.slot>>c.fuse>>c.owner))return false;s.charges.push_back(c);}if(!(in>>count)||count<1||count>100)return false;for(std::size_t i=0;i<count;++i){Wagon w;if(!(in>>w.type>>w.state>>w.goods>>w.quantity))return false;s.original.push_back(w);}in>>std::ws;if(!in.eof()||!valid(s))return false;out=std::move(s);return true;
}
}
