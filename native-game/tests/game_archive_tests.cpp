// SPDX-License-Identifier: MIT
// Source: session_saves.gd/session_save_extensions.gd stage before commit;
// world_ui_save.gd cross-component scheduler and mine-calendar constraints.
#include "app/game_archive.h"
#include "app/game_archive_codec.h"
#include "app/economy_archive.h"
#include "app/save_archive.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <sstream>
#include <stdexcept>
using namespace transartica;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label) {++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
void require(bool value,const std::string& error) {if(!value)throw std::runtime_error(error);}
std::string read(const std::filesystem::path& path) {
    std::ifstream in(path,std::ios::binary);return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};
}
void put(const std::filesystem::path& path,const std::string& bytes) {
    std::ofstream out(path,std::ios::binary|std::ios::trunc);out<<bytes;out.close();require(!out.fail(),"Cannot write composite fixture");
}
struct Scratch {
    std::filesystem::path path;
    explicit Scratch(const std::filesystem::path& parent):path(parent/"native-game-archive-tests") {
        require(std::filesystem::create_directory(path),"Scratch already exists; preserved: "+path.string());
    }
    ~Scratch() {
        std::error_code error;
        for(const auto* name:{"good.ta","copy.ta","bad.ta","legacy.ta"})std::filesystem::remove(path/name,error);
        std::filesystem::remove(path,error);
    }
};
struct Fixture {
    Session core;GameSession game;audio::GameAudio audio;PresentationState ui;
    explicit Fixture(const std::filesystem::path& path):game(core),
        // Owner-provided allocation limit, 1GiB. Root serializes all execution.
        audio(path,{false,1073741824,0},31) {
        std::string error;require(core.load_world(path/"data/CARTE.FIC",error),error);
        require(game.load(path,error),error);reset();
    }
    void reset() {
        game.random.seed(7);game.encounter_random.seed(19);game.visual_random.seed(23);game.reset();
        audio.reset();ui={};ui.screen=1;
    }
};
SaveSections fingerprint(Fixture& f) {
    std::ostringstream core;require(f.core.write_snapshot(core),"Live test state is not a valid core save");
    const auto& g=f.game;
    archive::Encounters encounters{g.encounter_random,g.visual_random,g.difficulty,g.pending_enemy,g.city,
        g.automatic,g.manual_paused,g.workshop,g.text_accumulator,g.report};
    SaveSections result{{"core",core.str()},
        {"economy",serialize_economy({g.trade.snapshot(),g.random,g.works,f.ui.workshop})},
        {"world",world::serialize({g.enemies.snapshot(),g.world.snapshot(),g.roamers.snapshot()})},
        {"campaign",campaign::serialize_snapshot(g.campaign.snapshot())},{"encounters",archive::encode(encounters)},
        {"presentation",archive::encode(f.ui)},{"audio",archive::encode(f.audio.snapshot())},
        {"launcher",launcher::serialize_snapshot(g.launcher.snapshot())}};
    if(g.tactical)result["tactical"]=combat::serialize(g.tactical->snapshot());
    return result;
}
std::string playback(const audio::GameAudio& audio) {
    std::ostringstream out;out<<audio.resident_bytes()<<' ';
    const auto add=[&](const audio::MusicState& s){out<<s.cursor<<' '<<s.frames<<' '<<s.loop_begin<<' '<<s.loop_end<<' '<<s.gain<<' '<<s.playing<<' '<<s.loop<<' ';};
    add(audio.music_state());add(audio.finale_state());
    for(const auto& s:audio.channels())out<<s.cursor<<' '<<s.frames<<' '<<s.priority<<' '<<s.repeats<<' '<<s.gain<<' '<<s.playing<<' ';
    return out.str();
}
SaveSections roundtrip(Fixture& f,const std::filesystem::path& directory,const std::string& label) {
    std::string error;const auto expected=fingerprint(f);const auto presentation=f.ui;
    require(save_game(directory/"good.ta",f.game,f.audio,f.ui,error),label+" save: "+error);
    SaveSections saved;require(read_archive(directory/"good.ta",saved,error),error);
    f.reset();require(load_game(directory/"good.ta",f.game,f.audio,f.ui,error),label+" load: "+error);
    check(fingerprint(f)==expected&&f.ui==presentation,label+" complete typed state roundtrip");
    require(save_game(directory/"copy.ta",f.game,f.audio,f.ui,error),error);
    SaveSections copied;require(read_archive(directory/"copy.ta",copied,error),error);
    check(copied==saved,label+" canonical section payloads unchanged after restore");
    return saved;
}
SaveSections base_state(Fixture& f,const std::filesystem::path& directory) {
    f.reset();auto& g=f.game;
    g.difficulty=4;g.automatic=true;f.core.calendar.day=3;
    require(g.world.tick_mines(3),"Real mine batch could not be staged");g.world.visit_city(24);
    g.campaign.station(-2);g.campaign.process();g.campaign.process();g.take_actions();
    auto trade=g.trade.snapshot();trade.stock[0][0]=-128;trade.stock[21][15]=127;trade.spy_slots[0]=1;
    require(g.trade.restore(trade),"Trade fixture invalid");
    auto campaign=g.campaign.snapshot();campaign.state.spies[0][0]=1;
    require(g.campaign.restore(campaign),"Campaign recruit fixture invalid");
    f.ui.visual_time=3.25;f.ui.options_open=true;f.ui.options_return=2;
    f.ui.world_view={true,{47.3,52.2},.65,{},false,true,8};
    require(f.audio.play_track("bopres-0"),f.audio.last_error());f.audio.advance(1,{});
    f.audio.toggle_original_music();f.audio.set_effects_enabled(false);
    const auto saved=roundtrip(f,directory,"base/world/trade/RNG/audio");
    check(saved.contains("launcher")&&saved.size()>=8,"complete archive carries launcher continuation section");
    check(g.campaign.model().urga_key&&g.trade.snapshot().spy_slots[0]==1,"campaign flags and recruited slot survive composite commit");
    return saved;
}
void works_and_quiz(Fixture& f,const std::filesystem::path& directory) {
    f.reset();auto& g=f.game;
    f.core.wagons.push_back({17,0,1,20});f.core.wagons.push_back({5,0,0,15});g.cargo_changed();
    require(g.works.ask(f.core.network,{83,67}),"Real crevasse fixture unavailable");g.answer_works(true);
    const auto paid=f.core.wagons;const auto random=g.random;
    roundtrip(f,directory,"already-paid work report");
    g.answer_works(true);check(f.core.wagons==paid&&g.random==random,"restored report cannot charge acceptance twice");
    g.finish_works();check(f.core.network.tile({83,67})==63,"restored report commits actual source repair on dismissal");
    f.reset();g.open_city(5);
    require(g.campaign.model().pending.quiz.has_value(),"Source copy-protection quiz did not open");
    const auto quiz=*g.campaign.model().pending.quiz;roundtrip(f,directory,"pending campaign copy-protection quiz");
    g.campaign.submit_code(g.campaign.data().quizzes[int(quiz.kind)][quiz.index].answer);g.take_actions();
    check(g.city==5&&g.world.snapshot().visited_cities==std::vector<int>{5},"restored quiz resumes one city arrival");
}
void battle(Fixture& f,const std::filesystem::path& directory) {
    f.reset();auto& g=f.game;const int slot=g.enemies.spawn(0,g.encounter_random);
    require(slot>=0,"Cannot stage source enemy record");g.pending_enemy=slot;g.tactical.emplace();
    require(g.tactical->begin(f.core.wagons,g.enemies.at(slot)->strength,g.encounter_random),"Cannot stage source tactical battle");
    g.manual_paused=true;f.core.paused=true;g.tactical->set_player_velocity(1);
    roundtrip(f,directory,"active tactical encounter");
    check(g.tactical&&g.pending_enemy==slot&&g.manual_paused&&g.enemies.at(slot)->active(),"tactical modal retains live enemy association");
    auto bad=g.tactical->snapshot();bad.original[0].state=1;
    SaveSections sections;std::string error;require(read_archive(directory/"good.ta",sections,error),error);
    sections["tactical"]=combat::serialize(bad);require(write_archive(directory/"bad.ta",sections,error),error);
    const auto before=fingerprint(f);const auto sound=playback(f.audio);
    check(!load_game(directory/"bad.ta",g,f.audio,f.ui,error)&&fingerprint(f)==before&&playback(f.audio)==sound,"tactical original train mismatch refuses before model/audio commit");
}
void rejected(Fixture& f,const std::filesystem::path& directory,const SaveSections& sections,const std::string& label) {
    const auto before=fingerprint(f);const auto sound=playback(f.audio);const auto ui=f.ui;std::string error;
    require(write_archive(directory/"bad.ta",sections,error),error);
    check(!load_game(directory/"bad.ta",f.game,f.audio,f.ui,error)&&!error.empty()&&fingerprint(f)==before&&playback(f.audio)==sound&&f.ui==ui,label+" preserves models, UI, voices and playback offsets");
}
void malformed(Fixture& f,const std::filesystem::path& directory,const SaveSections& original) {
    f.reset();std::string error;require(write_archive(directory/"good.ta",original,error),error);
    require(load_game(directory/"good.ta",f.game,f.audio,f.ui,error),error);
    f.audio.set_effects_enabled(true);require(f.audio.son(1)>=0,f.audio.last_error());require(f.audio.play_finale(1),f.audio.last_error());
    for(const auto& [name,payload]:original) {
        auto missing=original;missing.erase(name);rejected(f,directory,missing,"missing "+name);
        auto truncated=original;truncated[name]=payload.substr(0,payload.size()/2);rejected(f,directory,truncated,"truncated "+name);
    }
    auto unknown=original;unknown["unexpected"]="1";rejected(f,directory,unknown,"unknown mandatory component");
    auto bad_audio=original;auto audio=f.audio.snapshot();audio.track="unregistered-score";
    bad_audio["audio"]=archive::encode(audio);rejected(f,directory,bad_audio,"unknown score key");
    auto future=original;world::Archive world_state;
    require(world::parse(future.at("world"),world_state),"Cannot parse original world");world_state.actions.last_mine_day=6;
    future["world"]=world::serialize(world_state);rejected(f,directory,future,"mine production date after saved calendar");
    auto timer=original;archive::Encounters encounters;
    require(archive::decode(timer.at("encounters"),encounters),"Cannot parse original encounters");encounters.text_accumulator=1.0/96;
    timer["encounters"]=archive::encode(encounters);rejected(f,directory,timer,"orphan text scheduler remainder");
    const auto before=fingerprint(f);const auto sound=playback(f.audio);
    put(directory/"legacy.ta",original.at("core"));
    check(!load_game(directory/"legacy.ta",f.game,f.audio,f.ui,error)&&!error.empty()&&fingerprint(f)==before&&playback(f.audio)==sound,"standalone legacy core schema explicitly refused as incomplete full game");
    put(directory/"bad.ta","{\"version\":9}");
    check(!load_game(directory/"bad.ta",f.game,f.audio,f.ui,error)&&fingerprint(f)==before&&playback(f.audio)==sound,"Godot JSON cannot masquerade as complete native archive");
    auto envelope=read(directory/"good.ta");put(directory/"bad.ta",envelope.substr(0,envelope.size()-1));
    check(!load_game(directory/"bad.ta",f.game,f.audio,f.ui,error)&&fingerprint(f)==before&&playback(f.audio)==sound,"truncated envelope rejected before any audio load");
}
void commit_boundaries(Fixture& f,const std::filesystem::path& directory,const SaveSections& original,const std::filesystem::path& game) {
    std::string error;require(write_archive(directory/"good.ta",original,error),error);
    f.reset();f.game.open_city(24);f.game.battle_events.push_back({"stale"});
    require(load_game(directory/"good.ta",f.game,f.audio,f.ui,error),error);
    check(f.game.take_actions().empty()&&f.game.battle_events.empty(),"successful commit clears old scene actions and battle events");
    const auto before=fingerprint(f);const auto ui=f.ui;
    audio::GameAudio tiny(game,{false,1,0},1);tiny.toggle_original_music();
    const auto audio=tiny.snapshot();const auto sound=playback(tiny);
    check(!load_game(directory/"good.ta",f.game,tiny,f.ui,error)&&fingerprint(f)==before&&f.ui==ui&&tiny.snapshot()==audio&&playback(tiny)==sound,
        "PCM allocation failure after model validation cannot commit models or audio preferences");
}
}
int main(int argc,char** argv) {
    if(argc!=3){std::cerr<<"usage: game_archive_tests <game-directory> <existing-scratch-parent>\n";return 2;}
    try {
        Scratch scratch(argv[2]);Fixture fixture(argv[1]);const auto original=base_state(fixture,scratch.path);
        works_and_quiz(fixture,scratch.path);battle(fixture,scratch.path);malformed(fixture,scratch.path,original);
        commit_boundaries(fixture,scratch.path,original,argv[1]);
        std::cout<<checks<<" composite archive checks, "<<failures<<" failures\n";return failures?1:0;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
