// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
#include <array>
namespace transartica::world {
// TABLE30 records; YODA0x2af7/0xa56, TIME0x11a6..0x1961/0x261c.
struct EnemyTrain {
    int kind{},dx{},y{},heading{},phase{},remainder{},speed{},strength{};
    Cell cell() const { return {dx+40,y}; }
    bool active() const { return kind!=0&&kind!=2; }
    bool operator==(const EnemyTrain&) const = default;
};
struct EnemyState {
    std::array<EnemyTrain,30> slots{};
    std::vector<Cell> switch_history;
    bool operator==(const EnemyState&) const = default;
};
class EnemyTrains {
public:
    void reset();
    int spawn(int difficulty,Random&);
    int maybe_spawn_on_hour(int hour,int difficulty,Random&);
    int maybe_spawn_on_day(int day,int difficulty,Random&);
    void sync_scripted_slot(Cell);
    void remove(int slot);
    void record_player_position(Cell,const RailNetwork&);
    void advance_cycle(const RailNetwork&,Random&,int player_heading);
    int encounter_at(Cell) const;
    bool has_presence(Cell) const;
    const EnemyTrain* at(int slot) const;
    bool set_damage(int slot,int kind,int strength);
    const EnemyState& snapshot() const { return state_; }
    bool restore(const EnemyState&);
private:
    EnemyState state_;
    std::array<unsigned char,RailNetwork::width*RailNetwork::height> presence_{};
    void mark(Cell,bool);
    void advance(EnemyTrain&,const RailNetwork&,Random&,int);
};
}
