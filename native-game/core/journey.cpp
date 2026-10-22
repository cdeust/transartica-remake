// SPDX-License-Identifier: MIT
// Sources: game/scripts/{train_journey,train_path}.gd; tasks/evidence/rail-network.md.
#include "session.hpp"
#include "train_pose.hpp"
#include <algorithm>
#include <cmath>
#include <set>
#include <tuple>

namespace transartica {
namespace {
bool has_port(const std::vector<Point>& ports, Point p) { return std::find(ports.begin(),ports.end(),p) != ports.end(); }
std::vector<int> incoming_choices(const RailNetwork& net, Cell cell, int outgoing) {
    const auto ports = rail_ports(net.tile(cell));
    std::vector<int> choices;
    if (!has_port(ports,point(heading_delta(outgoing))*.5)) return choices;
    for (int h = 1; h <= 9; ++h) if (h != 5 && has_port(ports,point(heading_delta(h))*-.5) && net.turn(cell,h) == outgoing) choices.push_back(h);
    return choices;
}
Point entry(const Journey& j) { return j.incoming_heading == 0 ? point(j.position) : point(j.position)-point(heading_delta(j.incoming_heading))*.5; }
RouteSample segment(Point start, Point end, double remaining, int fallback) {
    const double length = distance(start,end);
    if (remaining > length) return {};
    const Point d = end-start;
    const auto sign = [](double v) { return v > 0 ? 1 : v < 0 ? -1 : 0; };
    int heading = fallback;
    for (int h = 1; h <= 9; ++h) if (h != 5 && heading_delta(h) == Cell{sign(d.x),sign(d.y)}) heading = h;
    return {true, length == 0 ? end : end+(start-end)*(remaining/length), heading, {}};
}
}
void Journey::reset(const RailNetwork& net) {
    *this = Journey{};
    seed_path(net);
}
void Journey::seed_path(const RailNetwork& net) {
    path.clear();
    path.push_back(entry(*this));
    if (incoming_heading == 0) return;
    Cell cursor = position;
    int direction = incoming_heading;
    std::set<std::tuple<int,int,int>> visited;
    while (net.loaded()) {
        cursor = cursor-heading_delta(direction);
        if (!visited.emplace(cursor.x,cursor.y,direction).second) break;
        const auto choices = incoming_choices(net,cursor,direction);
        if (choices.size() != 1) break;
        direction = choices.front();
        path.push_back(point(cursor));
        path.push_back(point(cursor)-point(heading_delta(direction))*.5);
    }
    std::reverse(path.begin(),path.end());
}
void Journey::advance(const RailNetwork& net, int speed) {
    if (blocked || speed <= 0 || !net.loaded()) return;
    // TIME 0x0567 clamps progress at 450; 0x0588 advances only above 22.
    const int progress = std::min(net.progress_speed(position,heading,speed),450);
    advance_render(net,double(progress/20)/69.0);
    distance_ticks += progress/20;
    if (distance_ticks <= 22) return;
    distance_ticks -= 23;
    ++phase;
    if (phase < 3) {
        if (phase == 1) { heading = net.turn(position,heading); reroute_turn(); }
        return;
    }
    const Cell candidate = next_cell();
    const auto reason = net.entry_boundary(candidate);
    if (reason.empty()) {
        if (path.empty()) path.push_back(entry(*this));
        if (path.back() != point(position)) path.push_back(point(position));
        path.push_back(point(position)+point(heading_delta(heading))*.5);
        position = candidate;
        incoming_heading = heading;
        phase = 0;
        return;
    }
    phase = 2;
    distance_ticks = 0;
    blocked = true;
    stop_reason = reason;
    finish_render_boundary();
}
Point Journey::fractional_position() const {
    if (!render_path.empty()) { const auto sample = sample_behind(0); if (sample.ok) return sample.position; }
    return logical_position();
}
Point Journey::logical_position() const {
    if (blocked) return point(position)+point(heading_delta(heading))*.5;
    // Approved presentation adaptation from train_journey.gd: traverse center /
    // half-cell ports uniformly over the decoded three phases.
    const double elapsed = double(phase*23+distance_ticks)/double(3*23);
    if (elapsed < .5) return incoming_heading == 0 ? point(position) : point(position)-point(heading_delta(incoming_heading))*(.5-elapsed);
    return point(position)+point(heading_delta(heading))*(elapsed-.5);
}
RouteSample Journey::sample_behind(double remaining) const {
    if (!std::isfinite(remaining) || remaining < 0) return {false,{},0,"invalid distance"};
    if (!render_path.empty()) {
        remaining += render_length()-render_cursor;
        for (std::size_t i = render_path.size(); i > 1; --i) {
            const auto sample = segment(render_path[i-2],render_path[i-1],remaining,heading);
            if (sample.ok) return sample;
            remaining -= distance(render_path[i-2],render_path[i-1]);
        }
        return {false,{},0,"insufficient canonical route history"};
    }
    const bool past_center = blocked || double(phase*23+distance_ticks)/double(3*23) >= .5;
    std::array<Point,3> current{entry(*this),point(position),logical_position()};
    const std::size_t count = past_center ? 3 : 2;
    if (!past_center) current[1] = current[2];
    Point endpoint = current[count-1];
    const int fallback = past_center ? heading : incoming_heading;
    for (std::size_t i = count-1; i > 0; --i) {
        const auto result = segment(current[i-1],endpoint,remaining,fallback);
        if (result.ok) return result;
        remaining -= distance(current[i-1],endpoint);
        endpoint = current[i-1];
    }
    for (std::size_t i = path.size(); i > 1; --i) {
        const auto result = segment(path[i-2],endpoint,remaining,fallback);
        if (result.ok) return result;
        remaining -= distance(path[i-2],endpoint);
        endpoint = path[i-2];
    }
    return {false,{},0,"insufficient route history"};
}
Cell Journey::next_cell() const { return position+heading_delta(heading); }
bool Session::load_world(const std::filesystem::path& file, std::string& error) {
    RailNetwork candidate;
    if (!candidate.load(file,error)) return false;
    Session staged;
    staged.network = std::move(candidate);
    staged.reset();
    if (!staged.journey.valid(staged.network)) { error = "CARTE.FIC has no valid original starting rail"; return false; }
    *this = std::move(staged);
    error.clear(); return true;
}
void Session::reset() {
    if (network.loaded()) network.restore_tiles(network.initial_tiles());
    wagons = initial_wagons();
    engine = EngineState{};
    engine.train_mass = transartica::train_mass(wagons);
    journey.reset(network);
    calendar = GameCalendar{};
    paused = false; accumulator = 0;
}
void Session::advance(double seconds,const std::function<void()>& journey_cycle) {
    if (!network.loaded() || paused || (journey.blocked && !journey_cycle) || engine.event_pending || !std::isfinite(seconds) || seconds <= 0
        || seconds_per_cycle != 1.0 || !calendar.valid() || !std::isfinite(accumulator+seconds)) return;
    accumulator += seconds;
    // Existing engine_session.gd uses approximate equality to avoid dropping a
    // cycle at 30/60/144 Hz. Preserve its documented 1e-5 scaled tolerance
    // (math_defs.hpp CMP_EPSILON / math.hpp is_equal_approx), without runtime SDK.
    constexpr double cadence_tolerance = .00001;
    while (accumulator >= seconds_per_cycle || (accumulator > 0 && std::abs(accumulator-seconds_per_cycle) < cadence_tolerance*std::max(1.0,std::abs(accumulator)))) {
        accumulator = std::max(0.0,accumulator-seconds_per_cycle);
        engine.step_cycle();
        if (!engine.event_pending && journey_cycle) journey_cycle();
        else if (!engine.event_pending) {
            // journey_session.gd advances calendar before movement, and skips
            // it entirely on the engine cycle that suspends for an event.
            for (const auto& event : calendar.advance_cycle()) {
                if (event == "bridge_open" || event == "bridge_closed") network.set_timed_bridge(calendar.bridge_code());
                // Enemy/day/mines campaign handlers remain explicitly unported.
            }
            advance_train(journey,network,wagons,engine.speed);
        }
        if (journey.blocked && !journey_cycle) { engine.brake = true; engine.speed = 0; paused = true; }
        if (paused || engine.event_pending) { accumulator = 0; return; }
    }
}
} // namespace transartica
