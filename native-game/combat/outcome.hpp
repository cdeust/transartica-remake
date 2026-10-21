// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
namespace transartica::combat {
struct Pools {int soldiers{},mammoths{},guns{};bool operator==(const Pools&)const=default;};
bool vital_intact(const std::vector<Wagon>&);
Pools auto_pools(const std::vector<Wagon>&);
int potential(Pools);
int margin(int potential,int strength);
void apply_destruction(std::vector<Wagon>&,EngineState&,std::array<int,20>& spies,Random&);
void win_coal(const std::vector<Wagon>&,EngineState&,int enemy_wagons,Random&);
int win_slaves(std::vector<Wagon>&,int enemy_wagons,Random&);
int win_survivors(std::vector<Wagon>&,int soldiers);
int win_mammoths(std::vector<Wagon>&,int mammoths);
void capture_trading_wagons(std::vector<Wagon>&,int count,Random&);
struct EnemyReport {int wagons{},trading{};std::array<int,2> gun_groups{};int soldiers{},mammoths{};};
struct AutomaticResult {
    bool won{};int margin{},potential{};EnemyReport enemy;
    int soldiers_lost{},mammoths_lost{},coal_gained{},slaves_gained{},wagons_captured{},epitaph_id{};
    std::vector<int> scrapped_indices;std::vector<Wagon> captured;
};
AutomaticResult automatic_resolve(std::vector<Wagon>&,EngineState&,int strength,Random&);
}
