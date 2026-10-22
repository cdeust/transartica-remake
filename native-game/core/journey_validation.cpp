// SPDX-License-Identifier: MIT
// Source: train_journey.gd restore v6, train_path.gd, source rail glyph ports.
#include "session.hpp"
#include <algorithm>
#include <cmath>
namespace transartica {
namespace {
bool heading_valid(int h) { return h>=1 && h<=9 && h!=5; }
bool has_port(const std::vector<Point>& ports, Point p) { return std::find(ports.begin(),ports.end(),p)!=ports.end(); }
bool is_center(Point p) { return p.x==std::floor(p.x) && p.y==std::floor(p.y); }
int heading_for(Point d) {
    for (int h=1; h<=9; ++h) if (h!=5 && point(heading_delta(h))==d) return h;
    return 0;
}
bool valid_turn(int code, int incoming, int outgoing) {
    if (rail_turn(code,incoming)==outgoing) return true;
    // Toggling a switch never rewrites its already occupied physical branch.
    return code>=18 && code<=33 && rail_turn(code^1,incoming)==outgoing;
}
bool hidden_interior(const RailNetwork& net, const std::vector<Point>& path, std::size_t center) {
    if (center!=1 || path.size()<3 || !is_center(path[1]) || (path[0]+path[2])*.5!=path[1]) return false;
    const int code=net.tile({int(path[1].x),int(path[1].y)});
    return (code>=34 && code<=37) || code==-120 || code==65 || code==78;
}
bool valid_vertex(Point p) {
    return std::isfinite(p.x) && std::isfinite(p.y) && p.x>=-.5 && p.x<=RailNetwork::width-.5
        && p.y>=-.5 && p.y<=RailNetwork::height-.5 && p.x*2==std::floor(p.x*2) && p.y*2==std::floor(p.y*2);
}
bool valid_path(const RailNetwork& net, const std::vector<Point>& path) {
    if (path.empty()) return false;
    for (std::size_t i=0; i<path.size(); ++i) {
        const Point p=path[i];
        if (!valid_vertex(p)) return false;
        if (i==0) continue;
        const Point prior=path[i-1], delta=p-prior;
        const double dx=std::abs(delta.x),dy=std::abs(delta.y);
        if ((dx==0 && dy==0) || (dx!=0 && dx!=.5) || (dy!=0 && dy!=.5) || is_center(p)==is_center(prior)) return false;
        const Point center=is_center(p) ? p : prior, port=is_center(p) ? prior : p;
        const Cell cell{int(center.x),int(center.y)};
        const auto center_index=is_center(p) ? i : i-1;
        const bool hidden=hidden_interior(net,path,center_index);
        if (!net.in_bounds(cell) || (!hidden && !has_port(rail_ports(net.tile(cell)),port-center))) return false;
        if (i<2) continue;
        const Point before=path[i-2];
        if (!is_center(prior)) {
            if ((before+p)*.5!=prior || before==p) return false;
        } else if (!hidden) {
            const int incoming=heading_for((prior-before)*2),outgoing=heading_for((p-prior)*2);
            if (!heading_valid(incoming) || !heading_valid(outgoing) || !valid_turn(net.tile(cell),incoming,outgoing)) return false;
        }
    }
    return true;
}
bool valid_render(const Journey& j, const RailNetwork& net) {
    if (!std::isfinite(j.render_cursor) || !std::isfinite(j.render_origin)) return false;
    if (j.render_path.empty()) return !j.reversing && j.render_cursor==0 && j.render_origin==0 && j.reverse_switches.empty();
    if (!valid_path(net,j.render_path) || !heading_valid(j.render_end_heading) || !net.in_bounds(j.render_end_cell)
        || j.render_path.back()!=point(j.render_end_cell)+point(heading_delta(j.render_end_heading))*.5
        || j.render_cursor<0 || j.render_cursor>j.render_length()+.00001) return false;
    if (!j.reversing && !j.reverse_switches.empty()) return false;
    for (std::size_t n=0; n<j.reverse_switches.size(); ++n) {
        const auto latch=j.reverse_switches[n];
        if (!net.is_switch(latch.cell) || !heading_valid(latch.heading)) return false;
        for (std::size_t before=0; before<n; ++before) if (j.reverse_switches[before].cell==latch.cell) return false;
        const auto it=std::find(j.render_path.begin(),j.render_path.end(),point(latch.cell));
        if (it==j.render_path.begin() || it==j.render_path.end() || *(it-1)!=point(latch.cell)+point(heading_delta(latch.heading))*.5) return false;
    }
    return true;
}
bool valid_physical(const Journey& j, const RailNetwork& net) {
    if (j.physical_obstacle==Cell{-1,-1}) return j.physical_heading==0 && !j.physical_spy_handled;
    // Map-edge refusal has no handler: retain its exact outside coordinate.
    const bool edge=net.entry_boundary(j.physical_obstacle)=="world edge wrap not verified"
        && j.physical_obstacle.x>=-1 && j.physical_obstacle.x<=RailNetwork::width
        && j.physical_obstacle.y>=-1 && j.physical_obstacle.y<=RailNetwork::height;
    if (!j.reversing || !heading_valid(j.physical_heading) || (!net.in_bounds(j.physical_obstacle) && !edge)) return false;
    if (j.blocked && (j.stop_reason.empty() || net.entry_boundary(j.physical_obstacle)!=j.stop_reason)) return false;
    return !j.render_path.empty();
}
}
bool Journey::valid(const RailNetwork& net) const {
    const bool occupied_bridge=position==Cell{110,33} && net.tile(position)==-120;
    if (!net.loaded() || !net.in_bounds(position) || (!net.entry_boundary(position).empty() && !occupied_bridge)
        || !heading_valid(heading) || (incoming_heading!=0 && !heading_valid(incoming_heading))
        || phase< -1 || phase>2 || distance_ticks<0 || distance_ticks>23 || path.empty()) return false;
    if (phase==-1 && distance_ticks!=23) return false;
    if (incoming_heading==0 && phase<=0) return false;
    if (blocked) {
        if (stop_reason.empty() || net.entry_boundary(boundary_cell())!=stop_reason) return false;
        if (physical_obstacle==Cell{-1,-1} && (phase!=2 || distance_ticks!=0)) return false;
    } else if (!stop_reason.empty()) return false;
    if (phase<=0 && heading!=incoming_heading) return false;
    const auto ports=rail_ports(net.tile(position));
    if (incoming_heading && !has_port(ports,point(heading_delta(incoming_heading))*-.5)) return false;
    if (phase>0 && ((!has_port(ports,point(heading_delta(heading))*.5))
        || (incoming_heading && !valid_turn(net.tile(position),incoming_heading,heading)))) return false;
    const Point entry=incoming_heading==0 ? point(position) : point(position)-point(heading_delta(incoming_heading))*.5;
    return path.back()==entry && valid_path(net,path) && valid_render(*this,net) && valid_physical(*this,net);
}
} // namespace transartica
