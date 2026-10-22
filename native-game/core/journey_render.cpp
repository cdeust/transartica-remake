// SPDX-License-Identifier: MIT
// Source: game/scripts/train_journey_render.gd, owner-approved occupied path.
#include "session.hpp"
#include <algorithm>
#include <cmath>
namespace transartica {
namespace {
Point sign(Point p) { return {double((p.x>0)-(p.x<0)),double((p.y>0)-(p.y<0))}; }
int heading_for(Point p) {
    for (int h=1; h<=9; ++h) if (h!=5 && point(heading_delta(h))==p) return h;
    return 0;
}
std::size_t center_index(const Journey& j, Cell cell) {
    return std::find(j.render_path.begin(),j.render_path.end(),point(cell))-j.render_path.begin();
}
double prefix_length(const std::vector<Point>& path, std::size_t end) {
    double result=0;
    for (std::size_t i=1; i<=end && i<path.size(); ++i) result+=distance(path[i-1],path[i]);
    return result;
}
void append_tile(std::vector<Point>& path, Cell cell, int heading) {
    if (path.empty() || path.back()!=point(cell)) path.push_back(point(cell));
    path.push_back(point(cell)+point(heading_delta(heading))*.5);
}
}
double Journey::render_length() const { return prefix_length(render_path,render_path.size()); }
void Journey::prepend_render(const std::vector<Point>& points) {
    double added=0;
    Point end=render_path.front();
    for (auto it=points.rbegin(); it!=points.rend(); ++it) { added+=distance(*it,end); end=*it; }
    render_path.insert(render_path.begin(),points.begin(),points.end());
    render_cursor+=added; render_origin+=added;
}
bool Journey::extend_backing_path(const RailNetwork& net) {
    if (render_path.size()<2) return false;
    const Point start=render_path.front(), delta=sign(render_path[1]-start);
    Cell cell{int(std::round(start.x-delta.x*.5)),int(std::round(start.y-delta.y*.5))};
    const int travel_heading=heading_for(delta*-1);
    const bool center=start.x==std::round(start.x) && start.y==std::round(start.y);
    if (center) cell={int(start.x),int(start.y)};
    const int code=net.tile(cell);
    const bool interior=cell==next_cell() && code>=34 && code<=37;
    if (!travel_heading || (!net.entry_boundary(cell).empty() && !interior)) {
        refused_cell=cell; refused_heading=travel_heading; return false;
    }
    const int outgoing=net.turn(cell,travel_heading);
    if (center) { prepend_render({start+point(heading_delta(outgoing))*.5}); return true; }
    if (interior) { prepend_render({point(cell)+point(heading_delta(travel_heading))*.5,point(cell)}); return true; }
    const Point offset=point(heading_delta(outgoing))*.5;
    const auto ports=rail_ports(code);
    if (std::find(ports.begin(),ports.end(),offset)==ports.end()) return false;
    prepend_render({point(cell)+offset,point(cell)}); return true;
}
void Journey::advance_render(const RailNetwork& net, double fraction) {
    if (render_path.empty()) return;
    const double incoming=incoming_heading==0 ? 0 : distance({},point(heading_delta(incoming_heading)));
    const double tile_length=(incoming+distance({},point(heading_delta(heading))))*.5;
    render_cursor+=fraction*tile_length*(reversing ? -1 : 1);
    while (render_cursor>render_length()) {
        const Cell next=render_end_cell+heading_delta(render_end_heading);
        if (!net.loaded() || !net.entry_boundary(next).empty()) { render_cursor=render_length(); break; }
        render_end_heading=net.turn(next,render_end_heading);
        render_end_cell=next;
        append_tile(render_path,next,render_end_heading);
    }
    while (render_cursor<0) if (!extend_backing_path(net)) { render_cursor=0; break; }
}
void Journey::reroute_turn() {
    if (render_path.empty()) return;
    const auto index=center_index(*this,position);
    if (index==render_path.size()) return;
    if (!reversing) {
        render_path.resize(index+1);
        append_tile(render_path,position,heading);
        render_end_cell=position; render_end_heading=heading; return;
    }
    if (index>0) {
        const int candidate=heading_for(sign(render_path[index-1]-point(position)));
        const auto latch=std::find_if(reverse_switches.begin(),reverse_switches.end(),[&](const auto& l){return l.cell==position && l.heading==candidate;});
        if (candidate==heading || latch!=reverse_switches.end()) { heading=candidate; return; }
    }
    const double removed=prefix_length(render_path,index);
    render_path.erase(render_path.begin(),render_path.begin()+index);
    render_cursor-=removed; render_origin-=removed;
    prepend_render({point(position)+point(heading_delta(heading))*.5});
    render_cursor=std::max(0.0,render_cursor);
}
void Journey::retain_occupied_path(double rear_distance) {
    const double target=render_cursor-rear_distance;
    double arc=0;
    for (std::size_t i=1; i<render_path.size(); ++i) {
        const double length=distance(render_path[i-1],render_path[i]);
        if (arc+length>=target) {
            render_path.erase(render_path.begin(),render_path.begin()+i-1);
            render_cursor-=arc; render_origin-=arc; return;
        }
        arc+=length;
    }
}
void Journey::retire_switches() {
    if (!reversing) { reverse_switches.clear(); return; }
    std::erase_if(reverse_switches,[&](const auto& latch) {
        const auto index=center_index(*this,latch.cell);
        return index<1 || index==render_path.size() || render_cursor<prefix_length(render_path,index-1);
    });
}
void Journey::finish_render_boundary() {
    if (render_path.empty()) return;
    const Point target=logical_position();
    double arc=0;
    for (std::size_t i=1; i<render_path.size(); ++i) {
        const Point start=render_path[i-1], delta=render_path[i]-start, offset=target-start;
        const double norm=delta.x*delta.x+delta.y*delta.y;
        const double t=std::clamp((offset.x*delta.x+offset.y*delta.y)/norm,0.0,1.0);
        // Godot CMP_EPSILON used by source is_equal_approx(Vector2).
        if (distance(start+delta*t,target)<.00001) { render_cursor=arc+distance(start,target); return; }
        arc+=std::sqrt(norm);
    }
    if (reversing && render_path.front()==point(position)) { prepend_render({target}); render_cursor=0; }
}
} // namespace transartica
