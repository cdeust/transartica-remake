// SPDX-License-Identifier: MIT
// Source session_saves.gd + session_save_extensions.gd component transactions.
#include "game_archive.h"
#include "game_archive_codec.h"
#include "economy_archive.h"
#include "save_archive.h"
#include <set>
#include <sstream>
namespace transartica {
namespace {
bool section_set(const SaveSections& sections) {
    const std::set<std::string> required{"core","economy","world","campaign","encounters","presentation","audio","launcher"};
    for(const auto& name:required)if(!sections.contains(name))return false;
    for(const auto& [name,value]:sections)if(!required.contains(name)&&name!="tactical")return false;
    return true;
}
archive::Encounters encounters(const GameSession& game) {
    return {game.encounter_random,game.visual_random,game.difficulty,game.pending_enemy,game.city,
        game.automatic,game.manual_paused,game.workshop,game.text_accumulator,game.report};
}
struct Staged {
    Session core;
    EconomySnapshot economy;
    world::Archive world;
    campaign::Snapshot campaign;
    archive::Encounters encounters;
    PresentationState presentation;
    audio::Snapshot audio;
    launcher::Snapshot launcher;
    std::optional<combat::Tactical> tactical;
};
bool decode(const SaveSections& sections,const GameSession& game,const audio::GameAudio& audio,Staged& s,std::string& error) {
    if(!section_set(sections)){error="Incomplete or unknown native save sections";return false;}
    s.core=game.core;std::istringstream core(sections.at("core"));
    if(!s.core.read_snapshot(core,sections.at("core").size(),error))return false;
    if(!parse_economy(sections.at("economy"),s.economy,s.core,error))return false;
    if(!world::parse(sections.at("world"),s.world)||!campaign::parse_snapshot(sections.at("campaign"),s.campaign,error)
        ||!archive::decode(sections.at("encounters"),s.encounters)||!archive::decode(sections.at("presentation"),s.presentation)
        ||!archive::decode(sections.at("audio"),s.audio)||!launcher::parse_snapshot(sections.at("launcher"),s.launcher,error))
        {if(error.empty())error="Invalid native component payload";return false;}
    if(!audio.validate_snapshot(s.audio,error))return false;
    s.presentation.workshop=s.economy.workshop;
    if(sections.contains("tactical")) {
        combat::TacticalState tactical;
        if(!combat::parse(sections.at("tactical"),tactical)){error="Invalid tactical payload";return false;}
        s.tactical.emplace();if(!s.tactical->restore(tactical)||tactical.settled||tactical.original!=s.core.wagons){error="Tactical train does not match campaign train";return false;}
    }
    return true;
}
bool validate(Staged& s,std::string& error) {
    world::EnemyTrains enemies;world::WorldRoamers roamers;
    world::WorldActions actions(s.core,s.economy.random,[](const world::MapWrites&){return false;});
    if(!enemies.restore(s.world.enemies)||!roamers.restore(s.world.roamers)||!actions.restore(s.world.actions)) {
        error="World records do not match the saved map";return false;
    }
    if(!launcher::validate_snapshot(s.launcher,s.core.wagons,enemies,s.core.journey.position)) {error="Invalid launcher continuation";return false;}
    const auto& e=s.encounters;
    // session_save_extensions.gd and world_ui_save.gd cross-component guards.
    if(s.world.actions.last_mine_day>s.core.calendar.day || (e.text_accumulator!=0 && s.world.actions.mine_phase!="result"
        && !s.economy.works.active() && s.world.roamers.pending!="hunt_result")) {
        error="Saved world clock is inconsistent";return false;
    }
    if((e.pending>=0 && (!enemies.at(e.pending)||!enemies.at(e.pending)->active()))
        ||(s.tactical.has_value()!=(e.pending>=0))||(e.manual_paused&&!s.tactical)
        ||(e.report&&s.tactical)||(s.launcher.active&&(e.report||s.tactical))||(e.workshop&&e.city>=0)||(e.workshop!=s.presentation.workshop.visible)
        ||(s.presentation.city_suspended&&e.city<0&&!e.workshop)) {
        error="Conflicting saved modal or encounter state";return false;
    }
    return true;
}
void commit(GameSession& game,Staged& s) {
    game.core=std::move(s.core);game.random=s.economy.random;game.trade.restore(s.economy.trade);game.works=s.economy.works;
    game.enemies.restore(s.world.enemies);game.roamers.restore(s.world.roamers);game.world.restore(s.world.actions);
    game.campaign.restore(s.campaign);game.encounter_random=s.encounters.random;game.visual_random=s.encounters.visual;
    game.city=s.encounters.city;game.workshop=s.encounters.workshop;game.difficulty=s.encounters.difficulty;
    game.automatic=s.encounters.automatic;game.pending_enemy=s.encounters.pending;game.manual_paused=s.encounters.manual_paused;
    game.text_accumulator=s.encounters.text_accumulator;game.report=std::move(s.encounters.report);game.tactical=std::move(s.tactical);
    game.launcher.restore(s.launcher);game.clear_pending_actions();
}
}
bool save_game(const std::filesystem::path& path,const GameSession& game,const audio::GameAudio& audio,
               const PresentationState& presentation,std::string& error) {
    if(!presentation.valid()){error="Invalid presentation state";return false;}
    std::ostringstream core;if(!game.core.write_snapshot(core)){error="Invalid simulation state";return false;}
    EconomySnapshot economy{game.trade.snapshot(),game.random,game.works,presentation.workshop};
    if(!validate_economy(economy,game.core,error))return false;
    SaveSections sections{{"core",core.str()},{"economy",serialize_economy(economy)},
        {"world",world::serialize({game.enemies.snapshot(),game.world.snapshot(),game.roamers.snapshot()})},
        {"campaign",campaign::serialize_snapshot(game.campaign.snapshot())},{"encounters",archive::encode(encounters(game))},
        {"presentation",archive::encode(presentation)},{"audio",archive::encode(audio.snapshot())},
        {"launcher",launcher::serialize_snapshot(game.launcher.snapshot())}};
    if(game.tactical)sections["tactical"]=combat::serialize(game.tactical->snapshot());
    Staged verified;if(!decode(sections,game,audio,verified,error)||!validate(verified,error))return false;
    return write_archive(path,sections,error);
}
bool load_game(const std::filesystem::path& path,GameSession& game,audio::GameAudio& audio,
               PresentationState& presentation,std::string& error) {
    SaveSections sections;if(!read_archive(path,sections,error))return false;
    Staged staged;if(!decode(sections,game,audio,staged,error)||!validate(staged,error))return false;
    // PCM decoding/install is itself transactional. All model checks ran first.
    if(!audio.restore(staged.audio,error))return false;
    commit(game,staged);presentation=std::move(staged.presentation);error.clear();return true;
}
}
