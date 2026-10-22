// SPDX-License-Identifier: MIT
#pragma once
#include "mines.hpp"
#include <functional>
namespace transartica::world {
struct WorldActionState {
    MineState mines{}; int last_mine_day{},pending_mine=-1;bool mine_accepted{};
    std::string mine_phase;MineResources resources{};int quantity{},countdown{};
    std::vector<int> visited_cities;
    bool operator==(const WorldActionState&)const=default;
};
class WorldActions {
public:
    // Source world_actions.gd. Map callback commits all writes or none.
    WorldActions(Session& session,Random& random,std::function<bool(const MapWrites&)> apply):session_(session),rng_(random),apply_(std::move(apply)){}
    Mines mines;
    bool tick_mines(int day,std::vector<int>* stoup=nullptr);
    bool ask_mine(Cell);
    bool answer_mine(bool);
    bool advance_mine();
    void mine_text_tick();
    bool close_mine();
    bool before_entry(Cell);
    void visit_city(int city);
    WorldActionState snapshot()const;
    bool restore(const WorldActionState&);
private:
    Session& session_;Random& rng_;std::function<bool(const MapWrites&)> apply_;
    WorldActionState state_;
};
}
