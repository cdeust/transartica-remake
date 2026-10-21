// SPDX-License-Identifier: MIT
// Source: train_journey.gd YODA 0x18e3..1970; hidden station owner26Sep.
#include "session.hpp"
#include "train_pose.hpp"
#include <algorithm>
#include <cmath>
namespace transartica {
namespace {
int incoming_for(const RailNetwork& net, Cell cell, int outgoing) {
    const auto ports=rail_ports(net.tile(cell));
    if (std::find(ports.begin(),ports.end(),point(heading_delta(outgoing))*.5)==ports.end()) return 0;
    int found=0;
    for (int h=1; h<=9; ++h) {
        if (h==5 || net.turn(cell,h)!=outgoing || std::find(ports.begin(),ports.end(),point(heading_delta(h))*-.5)==ports.end()) continue;
        if (found) return 0;
        found=h;
    }
    return found;
}
}
double Journey::distance_travelled() const {
    if (!render_path.empty()) return render_cursor-render_origin;
    double result=0;
    for (std::size_t i=1; i<path.size(); ++i) result+=distance(path[i-1],path[i]);
    const Point entry=incoming_heading==0 ? point(position) : point(position)-point(heading_delta(incoming_heading))*.5;
    if (blocked || double(phase*23+distance_ticks)/69>=.5)
        return result+distance(entry,point(position))+distance(point(position),logical_position());
    return result+distance(entry,logical_position());
}
bool Journey::reverse_direction(const RailNetwork& net) {
    if (!net.loaded() || !net.in_bounds(position)) return false;
    if (render_path.empty()) {
        render_cursor=distance_travelled();
        render_path=path;
        render_end_cell=position;
        render_end_heading=phase==0 ? net.turn(position,heading) : heading;
        if (render_path.empty() || render_path.back()!=point(position)) render_path.push_back(point(position));
        render_path.push_back(point(position)+point(heading_delta(render_end_heading))*.5);
    }
    reversing=!reversing;
    if (!reversing) reverse_switches.clear();
    heading=10-heading;
    phase=std::abs(phase-2)-1;
    distance_ticks=23;
    blocked=false; stop_reason.clear();
    physical_obstacle={-1,-1}; physical_heading=0; physical_spy_handled=false;
    incoming_heading=phase>0 ? incoming_for(net,position,heading) : heading;
    seed_path(net);
    return true;
}
Cell Journey::boundary_cell() const { return physical_obstacle!=Cell{-1,-1} ? physical_obstacle : next_cell(); }
bool Journey::at_station() const { return blocked && stop_reason=="station"; }
bool Journey::at_reversal_event(const RailNetwork& net) const {
    const int code=net.tile(boundary_cell());
    return blocked && stop_reason=="event site" && (code==-120 || code==65 || code==78);
}
int Journey::station_result(const RailNetwork& net) const { return at_station() ? net.station_lookup(boundary_cell()) : -1; }
bool Journey::depart_from_station(const RailNetwork& net) {
    if (!at_station() && !at_reversal_event(net)) return false;
    const Cell station=boundary_cell();
    const int approach=physical_heading ? physical_heading : heading;
    position=station-heading_delta(approach);
    heading=10-approach; incoming_heading=heading;
    reverse_switches.clear(); render_path.clear(); render_cursor=0; render_origin=0; reversing=false;
    render_end_cell={}; render_end_heading=6;
    distance_ticks=0; phase=0; blocked=false; stop_reason.clear();
    physical_obstacle={-1,-1}; physical_heading=0; physical_spy_handled=false;
    refused_cell={-1,-1}; refused_heading=0;
    const Point step=point(heading_delta(approach))*.5;
    path={point(station)+step,point(station),point(station)-step};
    return true;
}
bool Journey::history_starts_in_station(const RailNetwork& net) const {
    if (path.size()<2) return false;
    const Point center=path[1];
    if (center.x!=std::floor(center.x) || center.y!=std::floor(center.y)) return false;
    const int code=net.tile({int(center.x),int(center.y)});
    return (code>=34 && code<=37) || code==-120 || code==65 || code==78;
}
bool Journey::resume_after_works(const RailNetwork& net) {
    if (!blocked || stop_reason!="obstacle") return false;
    blocked=false; stop_reason.clear();
    if (physical_obstacle!=Cell{-1,-1} && net.entry_boundary(physical_obstacle).empty()) {
        physical_obstacle={-1,-1}; physical_heading=0; physical_spy_handled=false;
    }
    return true;
}
bool Session::reverse() {
    if (engine.event_pending || !journey.reverse_direction(network)) return false;
    engine.speed=0; engine.brake=false;
    prepare_train_poses(journey,network,wagons);
    return true;
}
bool Session::toggle_switch(Cell cell) {
    if (!network.is_switch(cell)) return false;
    capture_reverse_switch(journey,network,wagons,cell);
    return network.toggle_switch(cell);
}
} // namespace transartica
