// SPDX-License-Identifier: MIT
#pragma once
#include "campaign/controller.hpp"
#include "combat/tactical.hpp"
#include "core/track_works.hpp"
#include "world/archive.hpp"
#include "launcher/launcher.hpp"
#include <optional>

namespace transartica {
// Composition/order from main.gd, journey_session.gd and world_encounters.gd.
// No renderer owns or advances a second copy of the simulation.
class GameSession final : public campaign::Host {
public:
    explicit GameSession(Session&);
    bool load(const std::filesystem::path& game,std::string& error);
    void reset();
    void advance(double seconds);
    void cargo_changed();
    void open_city(int);
    bool depart();
    void answer_world(bool);
    void continue_world();
    void answer_works(bool);
    void finish_works();
    void finish_battle();
    bool blocks_simulation() const;
    std::vector<campaign::Action> take_actions();
    Session& core;
    Random random,encounter_random,visual_random;
    economy::Trade trade;
    economy::WorldData data;
    world::WorldActions world;
    world::WorldRoamers roamers;
    world::EnemyTrains enemies;
    campaign::Controller campaign;
    launcher::Controller launcher;
    TrackWorks works;
    std::optional<combat::Tactical> tactical;
    std::optional<combat::AutomaticResult> report;
    std::vector<combat::Event> battle_events;
    int city=-1,difficulty{},pending_enemy=-1;
    bool workshop{},automatic{},manual_paused{};
    double text_accumulator{};
    void clear_pending_actions() {actions_.clear();battle_events.clear();}
    bool at_station() const override;
    int enemy_at(Cell) const override;
    std::optional<campaign::EnemyInfo> enemy_info(int) const override;
    void set_enemy_damage(int,int,int) override;
    std::optional<campaign::MoverInfo> mover_info(int) const override;
    campaign::Lines mine_report(int,const std::map<std::string,std::string>&) const override;
    std::uint64_t finale_seed() override;
private:
    std::vector<campaign::Action> actions_;
    void cycle();
    void calendar_cycle();
    void boundary(bool was_blocked);
    bool encounter_roamers(Cell);
    bool encounter(Cell old_cell);
    bool entry_due() const;
    void pause();
    void collect_campaign();
    bool apply_map(const world::MapWrites&);
};
}
