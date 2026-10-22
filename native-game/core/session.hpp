// SPDX-License-Identifier: MIT
#pragma once
#include <array>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <iosfwd>
#include <string>
#include <vector>

namespace transartica {
struct Cell { int x{}, y{}; bool operator==(const Cell&) const = default; };
struct Point { double x{}, y{}; bool operator==(const Point&) const = default; };
Point operator+(Point, Point);
Point operator-(Point, Point);
Point operator*(Point, double);
Cell operator+(Cell, Cell);
Cell operator-(Cell, Cell);
Point point(Cell);
Cell heading_delta(int heading);
double distance(Point, Point);
std::vector<Point> rail_ports(int signed_code);
int rail_turn(int signed_code, int incoming_heading);

// Source: FORMAT-CARTE.md; signed, column-major x * 73 + y CARTE.FIC.
class RailNetwork {
public:
    static constexpr int width = 160, height = 73;
    bool load(const std::filesystem::path&, std::string& error);
    bool load_bytes(const std::vector<std::uint8_t>&, std::string& error);
    bool loaded() const;
    bool in_bounds(Cell) const;
    int tile(Cell) const;
    int turn(Cell, int incoming_heading) const;
    int progress_speed(Cell, int heading, int speed) const;
    std::string entry_boundary(Cell) const;
    bool toggle_switch(Cell);
    bool is_switch(Cell) const;
    bool set_timed_bridge(int signed_code);
    bool repair(Cell);
    bool apply_mine_writes(const std::vector<std::pair<Cell,int>>&);
    bool set_campaign_tile(Cell,int);
    bool campaign_entry_enabled = false; // Runtime host capability, never saved.
    void set_city_anchors(const std::vector<Cell>&);
    int station_lookup(Cell) const;
    const std::vector<int>& tiles() const { return tiles_; }
    const std::vector<int>& initial_tiles() const { return initial_; }
    bool restore_tiles(const std::vector<int>&);
private:
    std::vector<int> initial_, tiles_;
    std::vector<Cell> city_anchors_;
};

// Source: train_wagons.gd TABLE 0x699..0x6f4, TIME 0x2a77/0x2b4a.
struct Wagon { int type{}, state{}, goods{}, quantity{}; bool operator==(const Wagon&) const = default; };
std::vector<Wagon> initial_wagons();
int train_mass(const std::vector<Wagon>&);
std::string vehicle_kind(int type);
double vehicle_length(int type);

struct EngineState {
    int lignite = 2000, anthracite = 500;
    int lignite_rate{}, anthracite_rate{}, regulator{}, speed{};
    int heat{}, temperature{}, pressure_reserve{};
    bool brake{}, event_pending{};
    std::string event_message;
    std::int64_t cycles{};
    int train_mass = 1266;
    void cycle_lignite();
    void cycle_anthracite();
    void set_regulator(int);
    void toggle_brake();
    void step_cycle();
    bool valid() const;
    bool operator==(const EngineState&) const = default;
};

// Source: game/scripts/game_calendar.gd, TABLE 0x0130..0x013c and YODA
// 0x3394. Each completed remake cycle is THREE game minutes at either factor.
// App applies real delta * factor once (main.gd:108); Session never scales again.
struct GameCalendar {
    int minute{}, hour{};
    std::int64_t day = 1;
    int factor = 1;
    void toggle_factor();
    std::vector<std::string> advance_cycle();
    int bridge_code() const;
    std::string display_text() const;
    bool valid() const;
    bool operator==(const GameCalendar&) const = default;
};

struct RouteSample {
    bool ok{};
    Point position;
    int heading{};
    std::string reason;
};

// Logical TIME position and canonical physical consist path are distinct.
// Source: train_journey.gd and train_path.gd; TIME 0x0486..0x067d.
struct Journey {
    Cell position{12, 62};
    int heading = 6, incoming_heading = 6, distance_ticks{}, phase{};
    bool blocked{};
    std::string stop_reason;
    std::vector<Point> path; // Oldest half-cell port/center first, ends at current entry.
    bool reversing{};
    std::vector<Point> render_path;
    double render_cursor{}, render_origin{};
    Cell render_end_cell{};
    int render_end_heading = 6;
    struct SwitchLatch { Cell cell; int heading{}; bool operator==(const SwitchLatch&) const = default; };
    std::vector<SwitchLatch> reverse_switches;
    Cell physical_obstacle{-1,-1};
    int physical_heading{};
    bool physical_spy_handled{};
    // Transient contact-search refusal, deliberately absent from saves.
    Cell refused_cell{-1,-1};
    int refused_heading{};
    void reset(const RailNetwork&);
    void seed_path(const RailNetwork&);
    void advance(const RailNetwork&, int speed);
    bool reverse_direction(const RailNetwork&);
    void advance_render(const RailNetwork&, double fraction);
    bool extend_backing_path(const RailNetwork&);
    void prepend_render(const std::vector<Point>&);
    void reroute_turn();
    void retain_occupied_path(double rear_distance);
    void retire_switches();
    void finish_render_boundary();
    double render_length() const;
    double distance_travelled() const;
    Point logical_position() const;
    Cell boundary_cell() const;
    bool at_station() const;
    bool at_obstacle() const { return blocked && stop_reason == "obstacle"; }
    Cell obstacle_cell() const { return boundary_cell(); }
    bool at_reversal_event(const RailNetwork&) const;
    int station_result(const RailNetwork&) const;
    bool depart_from_station(const RailNetwork&);
    bool history_starts_in_station(const RailNetwork&) const;
    bool resume_after_works(const RailNetwork&);
    Point fractional_position() const;
    RouteSample sample_behind(double world_distance) const;
    Cell next_cell() const;
    bool valid(const RailNetwork&) const;
};

// One real simulation state used by UI, movement and saves. The 1-second cadence
// is the remake's documented provisional cadence, not decoded original timing.
struct Session {
    RailNetwork network;
    EngineState engine;
    Journey journey;
    GameCalendar calendar;
    std::vector<Wagon> wagons = initial_wagons();
    bool paused{};
    double seconds_per_cycle = 1.0, accumulator{};
    bool load_world(const std::filesystem::path& carte, std::string& error);
    void reset();
    void advance(double seconds,const std::function<void()>& journey_cycle = {});
    bool reverse();
    bool toggle_switch(Cell);
    bool write_snapshot(std::ostream&) const;
    bool read_snapshot(std::istream&, std::uintmax_t bytes, std::string& error);
    bool save(const std::filesystem::path&, std::string& error) const;
    bool load_save(const std::filesystem::path&, std::string& error);
};
} // namespace transartica
