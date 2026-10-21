// SPDX-License-Identifier: MIT
// Source: reverse_contact_stop.gd and reverse_switch_contact.gd. Physical rear
// contact owns backing refusal; no unknown boundary may authorize extrapolation.
#include "train_pose.hpp"
#include <algorithm>
namespace transartica {
namespace {
bool refused_boundary(const Journey& j, const RailNetwork& net) {
    // Source handles works/stations/specials. Standalone also suspends at other
    // still-unported boundaries, rather than passing an unsupported handler.
    return j.refused_cell!=Cell{-1,-1} && !net.entry_boundary(j.refused_cell).empty();
}
void physical_stop(Journey& j, const RailNetwork& net, Cell cell, int heading) {
    j.physical_obstacle=cell; j.physical_heading=heading;
    j.blocked=true; j.stop_reason=net.entry_boundary(cell);
}
void seek_last_contact(Journey& j, const Journey& before, const RailNetwork& net,
                       const std::vector<Wagon>& wagons, int speed, Cell cell, int approach) {
    const int progress=std::min(net.progress_speed(before.position,before.heading,speed),450);
    double low=0, high=double(progress/20)/69;
    Journey accepted=before;
    for (int i=0; i<chord_iterations; ++i) {
        j=before;
        const double middle=(low+high)*.5;
        j.advance_render(net,middle);
        if (prepare_train_poses(j,net,wagons).size()==wagons.size()) { low=middle; accepted=j; }
        else high=middle;
    }
    j=std::move(accepted);
    physical_stop(j,net,cell,approach);
}
}
void advance_train(Journey& j, const RailNetwork& net, const std::vector<Wagon>& wagons, int speed) {
    if (!j.reversing || j.blocked || speed<=0) { j.advance(net,speed); return; }
    if (j.physical_obstacle!=Cell{-1,-1} && !net.entry_boundary(j.physical_obstacle).empty()) {
        physical_stop(j,net,j.physical_obstacle,j.physical_heading); return;
    }
    j.refused_cell={-1,-1};
    const auto occupied=prepare_train_poses(j,net,wagons);
    if (occupied.size()!=wagons.size()) {
        if (refused_boundary(j,net)) physical_stop(j,net,j.refused_cell,j.refused_heading);
        else j.advance(net,speed);
        return;
    }
    j.retire_switches();
    if (!occupied.empty()) j.retain_occupied_path(occupied.back().rear_distance);
    const Journey before=j;
    j.refused_cell={-1,-1};
    j.advance(net,speed);
    if (prepare_train_poses(j,net,wagons).size()==wagons.size() || !refused_boundary(j,net)) return;
    const Cell refused=j.refused_cell;
    const int approach=j.refused_heading;
    seek_last_contact(j,before,net,wagons,speed,refused,approach);
}
void capture_reverse_switch(Journey& j, const RailNetwork& net, const std::vector<Wagon>& wagons, Cell cell) {
    if (!j.reversing) return;
    const auto poses=prepare_train_poses(j,net,wagons);
    if (poses.empty()) return;
    const auto it=std::find(j.render_path.begin(),j.render_path.end(),point(cell));
    const auto index=std::size_t(it-j.render_path.begin());
    if (index<1 || index+1>=j.render_path.size()) return;
    double arc=0;
    for (std::size_t i=1; i<=index; ++i) arc+=distance(j.render_path[i-1],j.render_path[i]);
    if (arc>=j.render_cursor || arc<=j.render_cursor-poses.back().rear_distance) return;
    int incoming=0,outgoing=0;
    for (int h=1; h<=9; ++h) if (h!=5) {
        const Point half=point(heading_delta(h))*.5;
        if (half==point(cell)-j.render_path[index+1]) incoming=h;
        if (half==j.render_path[index-1]-point(cell)) outgoing=h;
    }
    const auto latch=std::find_if(j.reverse_switches.begin(),j.reverse_switches.end(),[&](const auto& l){return l.cell==cell;});
    if (incoming && outgoing && (net.turn(cell,incoming)==outgoing || (latch!=j.reverse_switches.end() && latch->heading==outgoing))) {
        if (latch==j.reverse_switches.end()) j.reverse_switches.push_back({cell,outgoing});
        else latch->heading=outgoing;
    }
}
} // namespace transartica
