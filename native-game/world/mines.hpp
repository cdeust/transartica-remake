// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
#include <array>
#include <map>
#include <optional>
namespace transartica::world {
using MapWrites=std::vector<std::pair<Cell,int>>;
struct Mine { int dx{},y{},signed_day{},wealth{}; Cell cell() const {return {dx+40,y};} bool operator==(const Mine&)const=default; };
using MineState=std::array<Mine,36>;
// YODA0x1e2a..0x2317; scripts/mines.gd. Caller atomically applies map writes.
class Mines {
public:
    const MineState& snapshot()const{return records_;}
    bool restore(const MineState&);
    int slot_for_cell(Cell)const;
    int free_slot()const;
    MapWrites deplete();
    MapWrites create(int day,const RailNetwork&,Random&);
    MapWrites tick(int day,const RailNetwork&,Random&);
    MapWrites prospect(int slot,bool accept);
    std::vector<std::string> report(int slot,const std::map<std::string,std::string>& phrases)const;
private:
    MineState records_{};
    struct Placement {Cell track,mine;int code{};};
    static std::optional<Placement> placement(Cell,const RailNetwork&);
};
struct MineResources {int slaves{},mammoths{},cranes{};bool operator==(const MineResources&)const=default;};
int signed_word(int);
MineResources mine_resources(const std::vector<Wagon>&);
int mine_quantity(const std::vector<Wagon>&,MineResources,int wealth,int lignite,int anthracite);
int credited_coal(int before,int quantity);
}
