// SPDX-License-Identifier: MIT
// Staged visual fixtures, not a completed campaign. See gameplay-scenarios.md.
#include "app/game_archive.h"
#include "app/game_archive_codec.h"
#include "app/economy_archive.h"
#include "app/save_archive.h"
#include <json-c/json.h>
#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>

using namespace transartica;
namespace fs = std::filesystem;
namespace {
using Json = std::unique_ptr<json_object, decltype(&json_object_put)>;
void require(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
}
void string_field(json_object* object, const char* key, const std::string& value) {
    json_object_object_add(object, key, json_object_new_string(value.c_str()));
}
struct Fixture {
    Session core;
    GameSession game;
    audio::GameAudio audio;
    PresentationState ui;
    explicit Fixture(const fs::path& path)
        : game(core), audio(path, {false, 1073741824, 0}, 31) {
        // Seeds and owner-provided 1GiB allocation limit: game_archive_tests.cpp.
        std::string error;
        require(core.load_world(path / "data/CARTE.FIC", error), error);
        require(game.load(path, error), error);
        reset();
    }
    void reset() {
        game.random.seed(7);
        game.encounter_random.seed(19);
        game.visual_random.seed(23);
        game.reset();
        game.difficulty = 0;
        game.automatic = false;
        audio.reset();
        ui = {};
        ui.screen = 1; // SessionUI::Screen::Cabin; all gameplay modals overlay it.
    }
    void brake() {
        core.engine.brake = true;
        core.engine.speed = 0;
        core.paused = true;
    }
};
SaveSections fingerprint(const Fixture& f) {
    std::ostringstream core;
    require(f.core.write_snapshot(core), "Fixture has invalid core state");
    const auto& g = f.game;
    const archive::Encounters encounters{g.encounter_random, g.visual_random,
        g.difficulty, g.pending_enemy, g.city, g.automatic, g.manual_paused,
        g.workshop, g.text_accumulator, g.report};
    SaveSections result{{"core", core.str()},
        {"economy", serialize_economy({g.trade.snapshot(), g.random, g.works, f.ui.workshop})},
        {"world", world::serialize({g.enemies.snapshot(), g.world.snapshot(), g.roamers.snapshot()})},
        {"campaign", campaign::serialize_snapshot(g.campaign.snapshot())},
        {"encounters", archive::encode(encounters)}, {"presentation", archive::encode(f.ui)},
        {"audio", archive::encode(f.audio.snapshot())},
        {"launcher", launcher::serialize_snapshot(g.launcher.snapshot())}};
    if (g.tactical) result["tactical"] = combat::serialize(g.tactical->snapshot());
    return result;
}
void boundary(Fixture& f, Cell before, int incoming, int outgoing) {
    auto& j = f.core.journey;
    j = Journey{};
    j.position = before;
    j.incoming_heading = incoming;
    j.heading = outgoing;
    j.phase = 2;
    j.blocked = true;
    j.stop_reason = f.core.network.entry_boundary(j.boundary_cell());
    j.seed_path(f.core.network);
    require(j.valid(f.core.network), "Source boundary has no valid retained rail history");
    f.brake();
}
void city(Fixture& f) {
    // game_archive_tests.cpp::commit_boundaries opens city24 at the canonical
    // start. This is a shop fixture, not proof of arrival or station departure.
    // The station_departure fixture's hidden cell31,67 is not a valid initial
    // retained route; do not bypass Journey::valid to make an archive from it.
    f.game.open_city(24);
    require(f.game.city == 24, "City24 did not open");
}
void works(Fixture& f) {
    // game_session_tests.cpp::works and game_archive_tests.cpp::works_and_quiz.
    boundary(f, {82,67}, 6, 6);
    // GameSession::boundary brakes this worksite without setting manual pause.
    f.core.paused = false;
    f.core.wagons.push_back({17,0,1,20});
    f.core.wagons.push_back({5,0,0,15});
    f.game.cargo_changed();
    require(f.game.works.ask(f.core.network, {83,67}), "Real crevasse question unavailable");
}
void mine_boundary(Fixture& f, Cell mine) {
    // Use only decoded rail ports/turns and the production Journey validator.
    // This constructs a fixture arrival; it does not assert a journey reached it.
    for (int outgoing = 1; outgoing <= 9; ++outgoing) {
        if (outgoing == 5) continue;
        for (int incoming = 1; incoming <= 9; ++incoming) {
            if (incoming == 5) continue;
            Journey j;
            j.position = mine - heading_delta(outgoing);
            j.heading = outgoing;
            j.incoming_heading = incoming;
            j.phase = 2;
            j.blocked = true;
            j.stop_reason = f.core.network.entry_boundary(mine);
            j.seed_path(f.core.network);
            if (j.valid(f.core.network)) { f.core.journey = std::move(j); return; }
        }
    }
    throw std::runtime_error("Generated mine has no valid source rail approach");
}
void mine(Fixture& f) {
    // game_archive_tests.cpp::base_state: real third-day mine callback.
    f.core.calendar.day = 3;
    require(f.game.world.tick_mines(3), "Third-day mine callback failed");
    const auto state = f.game.world.snapshot();
    for (const auto& row : state.mines) {
        if (!row.signed_day || row.wealth <= 0) continue;
        mine_boundary(f, row.cell());
        f.brake();
        require(f.game.world.ask_mine(row.cell()), "Generated mine question did not open");
        return;
    }
    throw std::runtime_error("Third-day callback did not create a mine");
}
void roamer(Fixture& f, bool nomad) {
    // game_session_tests.cpp::hunt_text_cadence; WorldRoamers::encounter.
    auto state = f.game.roamers.snapshot();
    for (auto& herd : state.herds) herd.quantity = 0;
    const auto position = f.core.journey.position;
    if (nomad) state.nomad = {position.x, position.y, 0, 6, 0};
    else state.herds[0] = {position.x - 40, position.y, 0, 6, 40, 20};
    require(f.game.roamers.restore(state), "Invalid source roamer fixture");
    const auto expected = nomad ? "nomad_question" : "herd_question";
    require(f.game.roamers.encounter(position, f.core.network, f.game.random) == expected,
        "Source roamer encounter did not open");
    f.brake();
}
void herd(Fixture& f) { roamer(f, false); }
void nomad(Fixture& f) { roamer(f, true); }
void tactical(Fixture& f) {
    // Complete source-associated archive fixture: game_archive_tests.cpp::battle.
    auto& g = f.game;
    const int slot = g.enemies.spawn(0, g.encounter_random);
    require(slot >= 0, "Source enemy spawn failed");
    g.pending_enemy = slot;
    g.tactical.emplace();
    require(g.tactical->begin(f.core.wagons, g.enemies.at(slot)->strength, g.encounter_random),
        "Source tactical battle did not begin");
    g.manual_paused = true;
    f.core.paused = true;
    g.tactical->set_player_velocity(1);
}
void prepare_launcher(Fixture& f) {
    // launcher_tests.cpp::continuation cargo. Keep the canonical starting rails.
    f.core.wagons.push_back({13,0,0,0});
    f.core.wagons.push_back({14,0,2,2});
    f.game.cargo_changed();
    require(f.game.launcher.open() == launcher::OpenResult::Opened,
        "Purchased launcher with two missiles did not open");
    require(f.game.launcher.visible(), "Launcher fixture is hidden");
}
void quiz(Fixture& f) {
    // game_archive_tests.cpp::works_and_quiz; gate precedes city visit.
    f.game.open_city(5);
    require(f.game.campaign.model().pending.quiz.has_value(), "City5 quiz did not open");
    require(f.game.city == -1, "Quiz unexpectedly visited the city");
}
void finale(Fixture& f) {
    // campaign_tests.cpp::finale_rules. Intro requires a real click to start film.
    require(f.game.campaign.station(-5), "Sun station event did not open");
    require(f.game.campaign.presentation().scene == campaign::Scene::Sun,
        "Sun introduction scene missing");
}
struct Scenario {
    const char* slot;
    void (*prepare)(Fixture&);
    const char* source;
    const char* interaction;
};
const Scenario scenarios[]{
    {"CITY", city, "game_archive_tests.cpp::commit_boundaries; GameSession::open_city",
        "Inspect city shops and prices. Train remains at the canonical start: arrival and departure are not covered."},
    {"WORKS", works, "game_session_tests.cpp::works; game_archive_tests.cpp::works_and_quiz",
        "Click OK to pay once; click OK on the report to repair cell83,67."},
    {"MINE", mine, "game_archive_tests.cpp::base_state; Mines::tick; WorldActions::ask_mine",
        "Click OK through the question, plaque and resources, then dismiss the result."},
    {"HERD", herd, "game_session_tests.cpp::hunt_text_cadence; WorldRoamers::encounter",
        "Click OK to commission the hunt, continue to the result and dismiss."},
    {"NOMAD", nomad, "WorldRoamers::encounter/answer; GameSession::answer_world; game_session_tests.cpp::cities",
        "Click OK to enter city45; inspect stock and leave the nomad market."},
    {"TACTIC", tactical, "game_archive_tests.cpp::battle",
        "Press P to release the saved tactical pause; select actors and issue actual commands."},
    {"LAUNCH", prepare_launcher, "launcher_tests.cpp::continuation",
        "Click ARM, wait for arming, click FIRE; dismiss the completed report to debit one missile."},
    {"QUIZ", quiz, "game_archive_tests.cpp::works_and_quiz",
        "Enter the private manifest answer, then Return; city5 must open once."},
    {"FINALE", finale, "campaign_tests.cpp::finale_rules; Controller::station/process",
        "Click the introduction to start the film; observe its return to options."}
};
fs::path claim_directory(const fs::path& parent) {
    require(fs::is_directory(parent), "Scratch parent must be an existing directory");
    const auto stamp = std::chrono::system_clock::now().time_since_epoch().count();
    for (unsigned attempt = 0; ; ++attempt) {
        const auto path = parent / ("gameplay-scenarios-" + std::to_string(stamp) + "-" + std::to_string(attempt));
        std::error_code error;
        if (fs::create_directory(path, error)) return path;
        require(!error || error == std::errc::file_exists, "Cannot claim scenario directory: " + error.message());
    }
}
void write_manifest(const fs::path& directory, json_object* manifest) {
    const auto path = directory / "manifest.json";
    require(!fs::exists(path), "Refusing to overwrite manifest");
    std::ofstream out(path, std::ios::binary);
    out << json_object_to_json_string_ext(manifest, JSON_C_TO_STRING_PRETTY) << '\n';
    out.close();
    require(!out.fail(), "Cannot write scenario manifest");
}
void emit(Fixture& f, const Scenario& scenario, const fs::path& directory, json_object* record) {
    f.reset();
    scenario.prepare(f);
    // Load restores the camera through View::restore_world. ready=false retains
    // its source initial framing; no invented zoom/camera limit is introduced.
    f.ui.world_view = {};
    const auto path = directory / (std::string(scenario.slot) + ".native");
    const auto staged = directory / (std::string(scenario.slot) + ".staged");
    require(!fs::exists(path), "Refusing to overwrite " + path.string());
    require(!fs::exists(staged), "Refusing to overwrite " + staged.string());
    const auto expected = fingerprint(f);
    std::string error;
    const bool written = save_game(staged, f.game, f.audio, f.ui, error);
    require(written, "Save: " + error);
    SaveSections saved;
    const bool read = read_archive(staged, saved, error);
    require(read, "Read envelope: " + error);
    require(saved == expected, "Serialized sections differ from fixture state");
    f.reset();
    const bool loaded = load_game(staged, f.game, f.audio, f.ui, error);
    require(loaded, "Reload: " + error);
    require(fingerprint(f) == expected, "Complete archive changed after reload");
    fs::rename(staged, path);
    string_field(record, "status", "archive_roundtrip_verified");
    json_object_object_add(record, "sections", json_object_new_int(int(saved.size())));
    json_object_object_add(record, "train_x", json_object_new_int(f.core.journey.position.x));
    json_object_object_add(record, "train_y", json_object_new_int(f.core.journey.position.y));
    if (const auto quiz = f.game.campaign.model().pending.quiz) {
        const auto& answer = f.game.campaign.data().quizzes[int(quiz->kind)][quiz->index].answer;
        string_field(record, "private_quiz_answer", answer);
    }
}
int generate(const fs::path& game, const fs::path& parent) {
    Fixture fixture(game);
    const auto directory = claim_directory(parent);
    std::cout << "Scenario directory: " << directory << '\n';
    Json manifest(json_object_new_object(), json_object_put);
    string_field(manifest.get(), "classification", "staged_fixture_not_earned_campaign_progress");
    string_field(manifest.get(), "visual_status", "not_observed_by_generator");
    string_field(manifest.get(), "audio", "offline device; default stopped playback; owner budget 1GiB");
    string_field(manifest.get(), "privacy", "Derived private data; keep this directory outside public bundles");
    auto* records = json_object_new_array();
    json_object_object_add(manifest.get(), "scenarios", records);
    bool failed = false;
    for (const auto& scenario : scenarios) {
        auto* record = json_object_new_object();
        json_object_array_add(records, record);
        string_field(record, "slot", scenario.slot);
        string_field(record, "source", scenario.source);
        string_field(record, "interaction", scenario.interaction);
        try { emit(fixture, scenario, directory, record); }
        catch (const std::exception& error) {
            failed = true;
            string_field(record, "status", "failed_do_not_use");
            string_field(record, "error", error.what());
            std::cerr << scenario.slot << ": " << error.what() << '\n';
        }
    }
    write_manifest(directory, manifest.get());
    return failed ? 1 : 0;
}
} // namespace
int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "usage: gameplay_scenarios <game-directory> <existing-scratch-directory>\n";
        return 2;
    }
    try { return generate(argv[1], argv[2]); }
    catch (const std::exception& error) {
        std::cerr << "Scenario generation: " << error.what() << '\n';
        return 1;
    }
}
