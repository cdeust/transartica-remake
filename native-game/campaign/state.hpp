// SPDX-License-Identifier: MIT
#pragma once
#include "data.hpp"
#include "economy/trade.hpp"
namespace transartica::campaign {
struct State {
    bool urga_key{},delivery_open{},central_destroyed{},whale_present=true,sos_sent{};
    Pending pending;
    Ending ending=Ending::None;
    std::array<SpyRecord,20> spies{};
    std::array<bool,2> protection_seen{};
    Hazards hazards;
    Fauna fauna;
    Stoup stoup;
    Pending prepare_entry(Cell,int,const std::vector<Wagon>&,RailNetwork&,const Data&,bool after_spy=false);
    Pending station(int,RailNetwork&);
    bool submit_code(std::string_view);
    Pending dismiss();
    Pending choose_whale(bool);
    Pending die(int);
    void sync_recruits(economy::Trade&);
    int send_spy(Cell destination,Cell player,std::vector<Wagon>&,economy::Trade&);
    std::vector<int> advance_spies(RailNetwork&,economy::Trade&);
    int posted_at(Cell) const;
    bool retrieve_spy(int,bool,economy::Trade&);
    void observe_enemy(int,Cell,const GameCalendar&);
    bool sabotage(int,RailNetwork&);
    bool valid() const;
    bool operator==(const State&) const = default;
private:
    void reveal(Cell,std::string_view,int,RailNetwork&,const Data&);
};
struct Defenders { int divisor{}; Lines lines; };
Defenders defenders(const std::vector<Wagon>&,const Data&);
Lines human_losses(std::vector<Wagon>&,int,const Data&);
Lines material_losses(bool wolf,std::vector<Wagon>&,EngineState&,int,const Data&,Random&);
int goods_count(const std::vector<Wagon>&,int);
bool consume(std::vector<Wagon>&,int goods,int type=0);
}
