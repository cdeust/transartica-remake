// SPDX-License-Identifier: MIT
// Oracles: tasks/evidence/locomotive-rules.md; game/tests/test_train_journey.gd;
// game/tests/tests_engine_session.gd. Synthetic maps only isolate decoded rules;
// the production-file tests below traverse the actual private CARTE.FIC.
#include "core/session.hpp"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <stdexcept>
#include <string>

using namespace transartica;
namespace {
int checks = 0, failures = 0;
void check(bool value, const std::string& label) {
    ++checks;
    if (!value) { ++failures; std::cerr << "FAIL: " << label << '\n'; }
}
void near(double a, double b, const std::string& label) {
    // Test precision: eight double ulps at unit scale allows std::hypot/lerp
    // rounding; source half-cell coordinates themselves compare exactly.
    check(std::abs(a-b) <= 8*std::numeric_limits<double>::epsilon()*std::max(1.0,std::abs(b)),label);
}
std::string read_file(const std::filesystem::path& path) {
    std::ifstream in(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};
}
void write_file(const std::filesystem::path& path, const std::string& text) {
    std::ofstream out(path,std::ios::binary | std::ios::trunc); out << text;
    if (!out) throw std::runtime_error("Cannot write test fixture");
}
bool same(const Session& a, const Session& b) {
    return a.engine == b.engine && a.calendar == b.calendar && a.paused == b.paused && a.seconds_per_cycle == b.seconds_per_cycle
        && a.accumulator == b.accumulator && a.wagons == b.wagons && a.network.tiles() == b.network.tiles()
        && a.journey.position == b.journey.position && a.journey.heading == b.journey.heading
        && a.journey.incoming_heading == b.journey.incoming_heading && a.journey.phase == b.journey.phase
        && a.journey.distance_ticks == b.journey.distance_ticks && a.journey.blocked == b.journey.blocked
        && a.journey.stop_reason == b.journey.stop_reason && a.journey.path == b.journey.path;
}
void engine_rules() {
    EngineState e;
    check(train_mass(initial_wagons()) == 1266,"TABLE initial six wagon mass is 1266");
    check(e.lignite == 2000 && e.anthracite == 500 && e.speed == 0,"TABLE initial stocks and stopped engine");
    e.cycle_lignite(); e.step_cycle();
    check(e.lignite == 1999 && e.anthracite == 500 && e.heat == 9 && e.temperature == 9 && e.pressure_reserve == 0 && e.speed == 0,"decoded one-cycle golden vector");
    for (int i = 1; i < 12; ++i) e.step_cycle();
    check(e.lignite == 1988 && e.heat == 106 && e.temperature == 106 && e.pressure_reserve == 200 && e.speed == 0,"decoded twelve-cycle golden vector");
    e.cycle_lignite(); check(e.lignite_rate == 2,"fuel rate advances to two");
    e.cycle_lignite(); check(e.lignite_rate == 0,"fuel rate wraps to zero");
    e.set_regulator(-1); check(e.regulator == 0,"regulator lower bound");
    e.set_regulator(301); check(e.regulator == 300,"regulator upper bound");
    e = EngineState{}; e.pressure_reserve = 1600; e.set_regulator(100); e.step_cycle();
    check(e.speed == 5,"reserve above 1500 starts acceleration by five");
    e.brake = true; e.speed = 10; e.step_cycle();
    check(e.speed == 5 && e.regulator == 100,"approved service brake slows progressively and retains target");
    e = EngineState{}; e.heat = 5000; e.lignite_rate = 2; e.step_cycle();
    check(e.event_pending && e.event_message == "Boiler overload" && e.lignite == 2000,"overload suspends before fuel consumption");
    const auto stopped = e; e.step_cycle(); check(e == stopped,"pending event suspends all later cycles");
    e = EngineState{}; e.lignite = 1; e.anthracite = 0; e.lignite_rate = 1; e.step_cycle();
    check(e.event_pending && e.event_message == "No coal remaining" && e.lignite == 0,"coal exhaustion is a suspension, not an invented ending");
}
void rail_rules() {
    std::vector<std::uint8_t> bytes(RailNetwork::width*RailNetwork::height);
    const auto put = [&](Cell c,int value) { bytes[c.x*RailNetwork::height+c.y] = static_cast<std::uint8_t>(value); };
    put({5,5},6); put({6,5},22); put({7,5},23); put({8,5},15); put({9,5},40);
    put({10,5},-50); put({11,5},-120); put({12,5},-121); put({13,5},34); put({14,5},114);
    RailNetwork net; std::string error;
    check(net.load_bytes(bytes,error),"load synthetic source-rule map");
    check(net.tile({10,5}) == -50 && net.tile({5,10}) == 0,"signed column-major CARTE indexing");
    check(net.turn({5,5},6) == 3 && net.turn({5,5},7) == 4 && net.turn({5,5},2) == 2,"TIME curve six incoming rules");
    check(net.turn({6,5},6) == 6 && net.turn({7,5},6) == 3 && net.turn({6,5},7) == 4,"facing and trailing switch rules");
    check(net.progress_speed({8,5},6,100) == 200 && net.progress_speed({8,5},2,100) == 100,"crossing axis speed rule");
    check(net.progress_speed({9,5},8,100) == 200,"second rail set doubles progression");
    check(net.toggle_switch({6,5}) && net.tile({6,5}) == 23 && net.toggle_switch({6,5}) && net.tile({6,5}) == 22,"switch toggles even/odd reversibly");
    check(!net.toggle_switch({5,5}),"ordinary curve cannot be mutated as switch");
    check(net.entry_boundary({10,5}) == "obstacle" && net.entry_boundary({14,5}) == "obstacle","destroyed rail and lake block entry");
    check(net.entry_boundary({11,5}) == "event site" && net.entry_boundary({12,5}).empty(),"closed bridge blocks and decoded intact bridge passes");
    check(net.entry_boundary({13,5}) == "station" && net.entry_boundary({160,5}) == "world edge wrap not verified","station and unknown world wrap are explicit boundaries");
    const auto original = net.tiles(); bytes.pop_back();
    check(!net.load_bytes(bytes,error) && net.tiles() == original,"invalid map size preserves existing network");
    auto bad = original; bad[5*RailNetwork::height+5] = 2;
    check(!net.restore_tiles(bad) && net.tiles() == original,"save cannot rewrite ordinary map geometry");
    check(rail_ports(6) == std::vector<Point>{{-.5,0},{.5,.5}} && rail_ports(-50) == rail_ports(2),"curve and destroyed glyph ports follow source geometry");
    check(rail_ports(34) == std::vector<Point>{{-.5,0}} && rail_ports(71).empty(),"station terminal has one port and city is not fabricated rail");
}
Session session_for(const std::filesystem::path& carte) {
    Session s; std::string error;
    if (!s.load_world(carte,error)) throw std::runtime_error(error);
    return s;
}
void route_rules(const std::filesystem::path& carte) {
    auto s = session_for(carte);
    check(s.journey.position == Cell{12,62} && s.journey.heading == 6,"TABLE start cell and heading on actual CARTE");
    check(s.journey.fractional_position() == Point{11.5,62},"initial train head lies on actual entry port");
    check(s.journey.sample_behind(0).ok && s.journey.sample_behind(0).position == Point{11.5,62},"zero-distance sample is head");
    const auto tail = s.journey.sample_behind(5);
    // CARTE cells (10,62)=7 and (9,63)=11 bend the connected initial
    // history southwest, then south through (9,64)=32 and (9,65)=3.
    // Head to (10,62): 1.5; diagonal to (9,63): sqrt(2); remainder
    // of the requested five units follows the vertical rail. The former
    // straight expectation belongs to the synthetic source fixture only.
    check(tail.ok && tail.heading == 8,"initial convoy tail follows actual northbound rail history");
    near(tail.position.x,9,"actual initial tail x on CARTE rail");
    near(tail.position.y,66.5-std::sqrt(2.0),"actual initial tail y after source diagonal");
    check(!s.journey.sample_behind(6).ok,"initial history stops before station interior; never extrapolates");
    check(!s.journey.sample_behind(-1).ok && !s.journey.sample_behind(std::numeric_limits<double>::infinity()).ok,"invalid sample distances rejected");
    s.journey.advance(s.network,450);
    check(s.journey.distance_ticks == 22 && s.journey.phase == 0,"TIME strict threshold retains remainder 22");
    s.journey.advance(s.network,450);
    check(s.journey.distance_ticks == 21 && s.journey.phase == 1,"TIME threshold subtracts 23 exactly once");
    near(s.journey.fractional_position().x,12.0+44.0/69.0-.5,"forward interpolation follows three source phases");
    s.reset(); bool all_track = true, diagonal = false;
    // Existing real-route regression uses 20000 as a termination ceiling.
    for (int i = 0; i < 20000 && !s.journey.blocked; ++i) {
        s.journey.advance(s.network,450);
        all_track = all_track && s.network.tile(s.journey.position) != 0;
        if (s.journey.position == Cell{41,64}) {
            diagonal = true;
            const auto sample = s.journey.sample_behind(.25);
            check(sample.ok && std::isfinite(sample.position.x) && std::isfinite(sample.position.y),"diagonal route sample remains finite at precision-regression cell");
        }
    }
    check(all_track && diagonal,"real route follows populated rails through 41,64 diagonal");
    check(s.journey.blocked && s.journey.position == Cell{82,67} && s.journey.next_cell() == Cell{83,67} && s.journey.stop_reason == "obstacle","actual default route stops before unported crevasse 83,67");
    check(s.journey.fractional_position() == Point{82.5,67},"refused entry snaps to exact stopping port");
    const auto before = s.journey.path; s.journey.advance(s.network,450);
    check(s.journey.path == before && s.journey.position == Cell{82,67},"blocked advance cannot cross unported boundary");
    s.reset(); check(s.network.toggle_switch({54,67}),"real branch switch exists at 54,67");
    bool south = false;
    for (int i = 0; i < 20000 && !s.journey.blocked; ++i) { s.journey.advance(s.network,450); south |= s.journey.position == Cell{55,68}; }
    check(south && s.journey.blocked && s.journey.next_cell() == Cell{138,71} && s.journey.stop_reason == "station","real switch selects authentic alternate station route");
}
void cadence_rules(const std::filesystem::path& carte) {
    auto sixty = session_for(carte), fifteen = session_for(carte), one44 = session_for(carte);
    for (auto* s : {&sixty,&fifteen,&one44}) { s->engine.cycle_lignite(); s->engine.set_regulator(175); }
    for (int i = 0; i < 600; ++i) sixty.advance(1.0/60);
    for (int i = 0; i < 150; ++i) fifteen.advance(1.0/15);
    for (int i = 0; i < 1440; ++i) one44.advance(1.0/144);
    check(sixty.engine == fifteen.engine && sixty.engine == one44.engine && sixty.engine.cycles == 10,"15/60/144 Hz yield exactly ten identical engine cycles");
    auto s = session_for(carte);
    s.advance(.375); s.paused = true; s.advance(4);
    check(s.engine.cycles == 0 && s.accumulator == .375,"pause preserves fractional accumulator without backlog");
    s.paused = false; s.advance(.625);
    check(s.engine.cycles == 1 && s.accumulator == 0,"resume completes exactly one residual cycle");
    s.engine.heat = 5000; s.engine.lignite_rate = 2; s.advance(5);
    check(s.engine.event_pending && s.engine.cycles == 2 && s.accumulator == 0,"event interrupts accumulated cycles immediately");
    auto driven = session_for(carte); driven.engine.cycle_lignite(); driven.engine.cycle_lignite(); driven.engine.set_regulator(300);
    int first_motion = 0;
    while (driven.engine.cycles < 20000 && !driven.journey.blocked && !driven.engine.event_pending) {
        driven.advance(1);
        if (first_motion == 0 && driven.engine.speed > 0) first_motion = int(driven.engine.cycles);
    }
    check(first_motion > 0 && driven.journey.blocked && driven.journey.position == Cell{82,67},"real boiler controls drive integrated session to authentic first boundary");
    check(driven.paused && driven.engine.brake && driven.engine.speed == 0 && driven.accumulator == 0,"unported boundary stops engine and clears time backlog");
    std::cout << "MEASURED: first motion cycle=" << first_motion << "; first boundary cycle=" << driven.engine.cycles << '\n';
}
void calendar_rules(const std::filesystem::path& carte, const std::filesystem::path& dir) {
    GameCalendar clock;
    check(clock.display_text() == "DAY 1 00:00" && clock.factor == 1 && clock.bridge_code() == -120,"TABLE initial calendar day one midnight and closed bridge");
    clock.advance_cycle();
    check(clock.minute == 3,"normal factor adds three game minutes per remake cycle");
    clock = GameCalendar{}; clock.toggle_factor(); clock.advance_cycle();
    check(clock.factor == 3 && clock.minute == 3,"fast factor still adds only three game minutes per cycle");
    clock.toggle_factor(); check(clock.factor == 1,"calendar factor toggles between one and three");
    clock = GameCalendar{};
    std::vector<std::string> events;
    for (int i = 0; i < 240; ++i) {
        const auto hooks = clock.advance_cycle(); events.insert(events.end(),hooks.begin(),hooks.end());
    }
    check(clock.hour == 12 && clock.minute == 0 && events == std::vector<std::string>{"bridge_open"} && clock.bridge_code() == -121,"240 cycles reach noon and emit exact opening hook");
    for (int i = 0; i < 40; ++i) {
        const auto hooks = clock.advance_cycle(); events.insert(events.end(),hooks.begin(),hooks.end());
    }
    check(clock.hour == 14 && events.back() == "bridge_closed" && clock.bridge_code() == -120,"forty more cycles close bridge at 14:00");
    clock.factor = 3;
    for (int i = 0; i < 200; ++i) clock.advance_cycle();
    check(clock.day == 2 && clock.hour == 0 && clock.minute == 0,"fast factor cycle arithmetic rolls day without double multiplication");
    clock.day = 2; clock.hour = 23; clock.minute = 59;
    check(clock.advance_cycle() == std::vector<std::string>{"new_day","mines"}
        && clock.day == 3 && clock.hour == 0 && clock.minute == 2,"midnight rollover preserves minutes and ordered third-day hook");
    clock.minute = 60; check(!clock.valid(),"calendar rejects minute sixty");
    clock = GameCalendar{}; clock.factor = 2; check(!clock.valid(),"calendar rejects unsupported factor two");
    auto normal = session_for(carte), fast = session_for(carte);
    fast.calendar.toggle_factor();
    normal.advance(1*normal.calendar.factor); fast.advance(1*fast.calendar.factor);
    check(normal.engine.cycles == 1 && normal.calendar.minute == 3 && fast.engine.cycles == 3 && fast.calendar.minute == 9,"app-applied factor once gives three-times cycle count, not nine-times calendar");
    fast.paused = true; const auto stopped = fast.calendar; fast.advance(3);
    check(fast.calendar == stopped,"pause suspends native calendar");
    fast.paused = false; fast.engine.heat = 5000; fast.engine.lignite_rate = 2; fast.advance(3);
    check(fast.engine.event_pending && fast.calendar == stopped,"engine event suspends before advancing calendar");
    auto bridge = session_for(carte);
    for (int i = 0; i < 4; ++i) bridge.advance(60);
    check(bridge.calendar.hour == 12 && bridge.network.tile({110,33}) == -121,"native session applies timed bridge write on noon hook");
    bridge.calendar.toggle_factor();
    const auto save = dir/"calendar.native"; std::string error;
    check(bridge.save(save,error),"calendar and open bridge save together: "+error);
    auto resumed = session_for(carte);
    check(resumed.load_save(save,error) && same(bridge,resumed),"calendar date factor and open bridge roundtrip in schema two");
    resumed.advance(40);
    check(resumed.calendar.hour == 14 && resumed.network.tile({110,33}) == -120,"resumed calendar closes persisted bridge at 14:00");
    // Isolated source map-write case: closure after entry must not invalidate
    // a legitimate occupied rail path or teleport the locomotive off the tile.
    auto occupied = session_for(carte);
    occupied.network.set_timed_bridge(-121);
    occupied.calendar.hour = 13; occupied.calendar.minute = 57;
    occupied.journey.position = {110,33}; occupied.journey.heading = 6;
    occupied.journey.incoming_heading = 6; occupied.journey.phase = 1;
    occupied.journey.path = {{109.5,33}};
    occupied.advance(1);
    check(occupied.calendar.hour == 14 && occupied.network.tile({110,33}) == -120
        && occupied.journey.valid(occupied.network) && occupied.journey.position == Cell{110,33},
        "bridge closure preserves an already occupied legitimate rail path");
    resumed.reset();
    check(resumed.calendar == GameCalendar{} && resumed.network.tile({110,33}) == -120,"new session resets calendar factor and bridge");
    std::filesystem::remove(save);
}
void save_rules(const std::filesystem::path& carte, const std::filesystem::path& dir) {
    const auto save = dir/"roundtrip.native", corrupt = dir/"corrupt.native";
    auto s = session_for(carte); s.engine.cycle_lignite(); s.engine.cycle_lignite(); s.engine.set_regulator(175); s.advance(35.375);
    check(s.network.toggle_switch({54,67}),"save fixture uses a real switched map state");
    s.calendar.toggle_factor();
    s.paused = true; std::string error;
    check(s.save(save,error),"native save written: "+error);
    const auto persisted = s;
    auto restored = session_for(carte);
    check(restored.load_save(save,error) && same(restored,persisted),"roundtrip preserves every simulation field and complete history");
    const auto bytes = read_file(save);
    check(restored.save(save,error) && read_file(save) == bytes,"atomic replacement is deterministic and repeatable");
    auto resumed = persisted; resumed.paused = false; restored.paused = false;
    resumed.advance(30.625); for (int i = 0; i < 245; ++i) restored.advance(.125);
    check(same(resumed,restored),"save resume preserves next cycles and route under different frame batching");
    const auto before = restored;
    auto tamper = bytes;
    const auto journey_start = tamper.find("\nJOURNEY ");
    const auto journey_end = tamper.find('\n',journey_start+1);
    const auto& j = persisted.journey;
    tamper.replace(journey_start,journey_end-journey_start,"\nJOURNEY "+std::to_string(j.position.x)+" "+std::to_string(j.position.y)+" 8 "+std::to_string(j.incoming_heading)+" 0 1 0 \"\"");
    write_file(corrupt,tamper);
    check(!restored.load_save(corrupt,error) && same(before,restored),"off-rail heading in phase one rejected transactionally");
    write_file(corrupt,bytes.substr(0,bytes.size()/2));
    check(!restored.load_save(corrupt,error) && same(before,restored),"truncated save rejected without mutation");
    write_file(corrupt,bytes+"TRAILING");
    check(!restored.load_save(corrupt,error) && same(before,restored),"trailing data rejected without mutation");
    auto bad = bytes; const auto clock = bad.find("\nCLOCK "); const auto end = bad.find('\n',clock+1);
    bad.replace(clock,end-clock,"\nCLOCK 0 0 0"); write_file(corrupt,bad);
    check(!restored.load_save(corrupt,error) && same(before,restored),"zero cadence rejected before session commit");
    for (const std::string cadence : {"1e-300","1e300","nan"}) {
        bad = bytes;
        const auto clock_start = bad.find("\nCLOCK ");
        bad.replace(clock_start,bad.find('\n',clock_start+1)-clock_start,"\nCLOCK 0 "+cadence+" 0");
        write_file(corrupt,bad);
        check(!restored.load_save(corrupt,error) && same(before,restored),"unsupported cadence rejected transactionally: "+cadence);
    }
    auto invalid_clock = before; invalid_clock.seconds_per_cycle = 1e-300;
    invalid_clock.advance(1);
    check(invalid_clock.engine == before.engine,"public advance rejects tiny cadence without looping");
    bad = bytes; const auto path = bad.find("\nPATH "); const auto points = bad.find('\n',path+1);
    bad.replace(path,points-path,"\nPATH 18446744073709551615"); write_file(corrupt,bad);
    check(!restored.load_save(corrupt,error) && same(before,restored),"malicious path count rejected before allocation");
    bad = bytes; const auto original = bad.find('\n',bad.find("ORIGINAL "))+1;
    bad.replace(original,bad.find(' ',original)-original,"127"); write_file(corrupt,bad);
    check(!restored.load_save(corrupt,error) && same(before,restored),"mismatched source map rejected transactionally");
    bad = bytes;
    const auto calendar_start = bad.find("\nCALENDAR ");
    bad.replace(calendar_start,bad.find('\n',calendar_start+1)-calendar_start,"\nCALENDAR 60 0 1 1");
    write_file(corrupt,bad);
    check(!restored.load_save(corrupt,error) && same(before,restored),"invalid calendar minute rejected transactionally");
    bad = bytes;
    bad.replace(0,bad.find('\n'),"TRANSARTICA_NATIVE_FORWARD 1");
    write_file(corrupt,bad);
    check(!restored.load_save(corrupt,error) && same(before,restored),"schema one rejected rather than inventing absent calendar state");
    auto invalid = persisted; invalid.engine.regulator = 301;
    check(!invalid.save(save,error) && read_file(save) == bytes,"invalid runtime state cannot overwrite good save");
    const auto pending = std::filesystem::path(save.string()+".pending");
    std::filesystem::create_directory(pending); write_file(pending/"owned-by-other","keep");
    check(!persisted.save(save,error) && read_file(save) == bytes && read_file(pending/"owned-by-other") == "keep","existing staging owner and previous save preserved");
    std::filesystem::remove(pending/"owned-by-other"); std::filesystem::remove(pending);
    std::filesystem::remove(save); std::filesystem::remove(corrupt);
}
}
int main(int argc, char** argv) {
    if (argc != 3) { std::cerr << "Usage: transartica_core_tests CARTE.FIC EXISTING_SCRATCH_DIRECTORY\n"; return 2; }
    const auto dir = std::filesystem::path(argv[2])/"core-tests";
    try {
        if (!std::filesystem::create_directory(dir)) throw std::runtime_error("Refusing to reuse test directory: "+dir.string());
        engine_rules(); rail_rules(); route_rules(argv[1]); cadence_rules(argv[1]); calendar_rules(argv[1],dir); save_rules(argv[1],dir);
        std::filesystem::remove(dir);
    } catch (const std::exception& e) { ++failures; std::cerr << "ERROR: " << e.what() << '\n'; }
    std::cout << "Standalone core: " << checks << " checks, " << failures << " failures\n";
    return failures == 0 ? 0 : 1;
}
