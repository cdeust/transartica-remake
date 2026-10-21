// SPDX-License-Identifier: MIT
#pragma once
#include "outcome.hpp"
#include <map>
#include <optional>
namespace transartica::combat {
// WDECOR0x0440 type-to-class table, distinct from wagon TYPE namespace.
enum Class {Barracks=1,Cannon=2,MachineGun=3,Livestock=4,Locomotive=5,Merchandise=6,Wreck=7,Tender=8,GQ=22,Boudoir=23,Companion=25};
struct Car {int kind{},quantity{},health{},reload{};bool operator==(const Car&)const=default;};
struct Actor {int id{},side{},x{},y{},count{};bool mammoth{};int roof=-1,direction=8,processed=-1;bool operator==(const Actor&)const=default;};
struct Charge {int side{},slot{},fuse{},owner{};bool operator==(const Charge&)const=default;};
struct Event {std::string kind;int side=-1,wagon=-1,x{},y{},source_offset{},tick{};};
struct TacticalState {
    std::array<std::vector<Car>,2> trains;std::array<int,2> offsets{},velocities{};
    std::map<int,Actor> actors;std::vector<Charge> charges;std::vector<Wagon> original;
    Random random;Pools initial_pools,survivors;std::array<int,2> army_strength{};
    int camera_offset{},aggressiveness{},columns=80,scan{},scan_side=1,sweep{},ai_wagon{},ai_wait{},ai_direction{},ticks{},next_id{},outcome{};
    bool settled{};double remainder{};
    bool operator==(const TacticalState&)const=default;
};
class Tactical {
public:
    static constexpr double step_seconds=4.0/50.0; // WDECOR0411 ctiming4, PAL50Hz.
    bool begin(const std::vector<Wagon>&,int strength,Random& source_random);
    const TacticalState& snapshot()const{return s_;}
    bool restore(const TacticalState&);
    void set_player_velocity(int value);
    void set_camera_offset(int value);
    int train_cell(int side,int wagon)const;
    int center_offset()const;
    int roof_cell(int side,int x)const;
    const Actor* actor_at(int x,int y,int roof=-1,int ignore=-1)const;
    int add_actor(int side,int x,int y,int count,bool mammoth,int roof=-1,int direction=8);
    bool deploy(int side,int wagon,int count);
    bool command(int id,int direction,int amount=0);
    bool fire(int wagon);
    bool plant(int id,int delta);
    std::vector<Event> advance(double delta);
    std::vector<Event> step();
    Pools pools(int side)const;
    std::optional<AutomaticResult> commit(std::vector<Wagon>&,EngineState&,std::array<int,20>& spies);
private:
    TacticalState s_;std::vector<Event> events_;
    int rnd(int);
    Actor* actor(int x,int y,int roof=-1,int ignore=-1);
    bool free_cells(int x,int y,bool mammoth,int ignore=-1)const;
    bool order(Actor&,int direction,int amount);
    bool roof_order(Actor&,int direction,int amount);
    void update(Actor&);void enemy_direction(Actor&);void melee(Actor&,Actor&);
    void roof_sweep(int);void roof_move(Actor&);void defuse(const Actor&);
    void damage_actor(Actor&,int before_count);void destroy_wagon(int,int);void destroy_stock(const Car&,int side);
    void move_trains();void enemy_ai();void weapons();void cannon(int,int);void machine_gun(int,int);
    void check_end();void redistribute(std::vector<Wagon>&);
    void audio(int offset){events_.push_back({"audio",-1,-1,0,0,offset});}
};
std::string serialize(const TacticalState&);
bool parse(const std::string&,TacticalState&);
}
