// SPDX-License-Identifier: MIT
// Source world_session.gd/world_encounters.gd; lifecycle is shared by UI and saves.
#include "game_session.h"
#include <algorithm>
#include <cmath>
namespace transartica {
void GameSession::advance(double seconds) {
    if(!std::isfinite(seconds)||seconds<0) return;
    campaign.advance(seconds);
    launcher.advance(seconds);
    if(works.advance(seconds,core.seconds_per_cycle)) core.calendar.factor=1;
    const auto phase=world.snapshot().mine_phase;
    if(phase=="result"||roamers.snapshot().pending=="hunt_result") {
        text_accumulator+=seconds; // main.gd advance_text(delta): only engine cadence receives factor.
        const double interval=core.seconds_per_cycle/48; // ALIS c905, YODA16 tours/minute.
        while(text_accumulator>=interval) {
            text_accumulator-=interval;
            if(phase=="result") world.mine_text_tick();else roamers.textek_tick();
        }
    } else text_accumulator=0;
    if(tactical&&!manual_paused) {
        auto events=tactical->advance(seconds*2); // tactical_scene.gd PACE=2, presentation pacing.
        battle_events.insert(battle_events.end(),events.begin(),events.end());
        if(tactical->snapshot().outcome) finish_battle();
    }
    if(!blocks_simulation()) core.advance(seconds*core.calendar.factor,[this]{cycle();});
    campaign.present_engine_event();collect_campaign();
}
void GameSession::answer_world(bool accept) {
    if(world.snapshot().pending_mine>=0) {
        if(!world.answer_mine(accept)) return;
        if(accept) actions_.push_back({campaign::ActionKind::SceneAudio,0,"worksite"});
        else core.paused=false;
        return;
    }
    if(!roamers.answer(accept,random,core.wagons)) return;
    if(roamers.snapshot().pending=="nomad_trade") open_city(45);
    else if(roamers.snapshot().pending.empty()) core.paused=false;
}
void GameSession::continue_world() {
    if(world.snapshot().pending_mine>=0) {
        if(world.advance_mine()) {
            if(world.snapshot().mine_phase=="result") {text_accumulator=0;core.calendar.factor=3;}
        } else if(world.close_mine()) {
            core.calendar.factor=1;text_accumulator=0;core.paused=false;cargo_changed();
            actions_.push_back({campaign::ActionKind::SceneAudio,0,"journey"});
        }
        return;
    }
    if(roamers.snapshot().pending=="hunt_commissioned") {
        roamers.finish_hunt(core.wagons);core.calendar.factor=3;cargo_changed();
    } else if(roamers.snapshot().pending=="hunt_result") {roamers.close();core.paused=false;}
}
void GameSession::answer_works(bool accept) {
    if(accept) {if(works.accept(core.wagons,random)) core.calendar.factor=3;cargo_changed();}
    else finish_works();
}
void GameSession::finish_works() {
    const auto kind=works.kind;
    works.dismiss(core.network,core.journey);cargo_changed();
    if(kind==WorkKind::None && core.journey.at_station() && core.journey.station_result(core.network)==-1) depart();
}
bool GameSession::encounter(Cell old) {
    if(pending_enemy>=0) return true;
    if(old!=core.journey.position) {
        enemies.record_player_position(core.journey.position,core.network);
        enemies.sync_scripted_slot(core.journey.position);
    }
    int slot=enemies.encounter_at(core.journey.position);
    if(slot<0) {
        const auto before=enemies.snapshot();
        enemies.advance_cycle(core.network,encounter_random,core.journey.heading);
        for(int i=0;i<int(before.slots.size());++i) {
            const auto* after=enemies.at(i);
            if(after&&after->active()&&after->cell()!=before.slots[i].cell()) campaign.observe_enemy(i,after->cell());
        }
        slot=enemies.encounter_at(core.journey.position);
    }
    if(slot<0) return false;
    pending_enemy=slot;core.paused=true;
    if(automatic) {
        report=combat::automatic_resolve(core.wagons,core.engine,enemies.at(slot)->strength,encounter_random);
        if(report->won) enemies.remove(slot);else {report.reset();campaign.die(105);}
        pending_enemy=-1;cargo_changed();
    } else {
        tactical.emplace();tactical->begin(core.wagons,enemies.at(slot)->strength,encounter_random);manual_paused=false;
    }
    return true;
}
void GameSession::finish_battle() {
    if(!tactical||pending_enemy<0) return;
    auto stock=trade.snapshot();
    auto result=tactical->commit(core.wagons,core.engine,stock.spy_slots);
    if(!result) return;
    trade.restore(stock);encounter_random=tactical->snapshot().random;
    if(result->won) enemies.remove(pending_enemy);
    pending_enemy=-1;tactical.reset();manual_paused=false;cargo_changed();core.paused=true;
    if(result->won) report=std::move(result);else campaign.die(105);
}
bool GameSession::at_station() const {return core.journey.at_station();}
int GameSession::enemy_at(Cell cell) const {return enemies.encounter_at(cell);}
std::optional<campaign::EnemyInfo> GameSession::enemy_info(int slot) const {
    const auto* enemy=enemies.at(slot);
    if(!enemy) return {};
    return campaign::EnemyInfo{enemy->kind,enemy->heading,enemy->strength};
}
void GameSession::set_enemy_damage(int slot,int kind,int strength) {enemies.set_damage(slot,kind,strength);}
std::optional<campaign::MoverInfo> GameSession::mover_info(int code) const {
    // Source spy_report.gd: herds40..49, fauna60, nomads70.
    const auto& moving=roamers.snapshot();
    if(code>=40&&code<=49 && std::size_t(code-40)<moving.herds.size()) {
        const auto& herd=moving.herds[code-40];return campaign::MoverInfo{herd.heading,herd.quantity};
    }
    if(code==60) return campaign::MoverInfo{campaign.model().fauna.heading,0};
    if(code==70) return campaign::MoverInfo{moving.nomad.heading,0};
    return {};
}
campaign::Lines GameSession::mine_report(int index,const std::map<std::string,std::string>& phrases) const {return world.mines.report(index,phrases);}
std::uint64_t GameSession::finale_seed() {return (std::uint64_t(visual_random.next_u32())<<32)|visual_random.next_u32();}
}
