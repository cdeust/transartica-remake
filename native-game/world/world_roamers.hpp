// SPDX-License-Identifier: MIT
#pragma once
#include "roamer_motion.hpp"
#include <functional>
namespace transartica::world {
struct Herd {int dx{},y{},phase{},heading{},timer{},quantity{};Cell cell()const{return {dx+40,y};}bool operator==(const Herd&)const=default;};
struct Nomad {int x{},y{},phase{},heading=6,callback{};Cell cell()const{return {x,y};}bool operator==(const Nomad&)const=default;};
struct RoamerState {
    bool initialized{};std::vector<Herd> herds;Nomad nomad;
    std::string pending;int herd_slot=-1;std::array<int,3> commissioned{};int caught{},hunt_quantity{},countdown{};
    bool operator==(const RoamerState&)const=default;
};
struct Observation {Cell cell;int code{},bit{};};
class WorldRoamers {
public:
    // Source world_roamers.gd: ten herds, THEN fauna initialize, THEN nomad draw.
    void initialize(Random&,const std::function<Cell(Random&)>& initialize_fauna);
    const RoamerState& snapshot()const{return state_;}
    bool restore(const RoamerState&);
    bool has_presence(Cell,int bit)const;
    std::vector<Observation> advance(const RailNetwork&,Random&,const std::array<int,7>& traps={});
    std::string encounter(Cell,const RailNetwork&,Random&,int bit=0);
    bool answer(bool,Random&,const std::vector<Wagon>&);
    bool finish_hunt(std::vector<Wagon>&);
    void textek_tick();
    void close();
private:
    RoamerState state_;
    void place_nomad(Cell);
};
}
