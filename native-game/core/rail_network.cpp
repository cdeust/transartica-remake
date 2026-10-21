// SPDX-License-Identifier: MIT
// Sources: FORMAT-CARTE.md; game/scripts/{rail_network,rail_glyphs,track_works}.gd;
// tasks/evidence/rail-network.md (TIME 0x1444..0x1918, 0x2392..0x257e).
#include "session.hpp"
#include "track_works.hpp"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iterator>

namespace transartica {
Point operator+(Point a, Point b) { return {a.x + b.x, a.y + b.y}; }
Point operator-(Point a, Point b) { return {a.x - b.x, a.y - b.y}; }
Point operator*(Point a, double n) { return {a.x * n, a.y * n}; }
Cell operator+(Cell a, Cell b) { return {a.x + b.x, a.y + b.y}; }
Cell operator-(Cell a, Cell b) { return {a.x - b.x, a.y - b.y}; }
Point point(Cell a) { return {double(a.x), double(a.y)}; }
Cell heading_delta(int h) {
    // TIME 0x1a34: numeric keypad, south-positive y.
    constexpr std::array<Cell, 10> deltas{{{0,0},{-1,1},{0,1},{1,1},{-1,0},{0,0},{1,0},{-1,-1},{0,-1},{1,-1}}};
    return h >= 0 && h < int(deltas.size()) ? deltas[h] : Cell{};
}
double distance(Point a, Point b) { return std::hypot(a.x-b.x, a.y-b.y); }
std::vector<Point> rail_ports(int code) {
    if (code > 127) code -= 256;
    if (code < 0) {
        if (code == -114 || code == -113 || code == -121 || code == -120) return rail_ports(2);
        if (code == -117) return rail_ports(3);
        return code > -105 ? rail_ports(-code) : std::vector<Point>{};
    }
    switch (code) {
    case 2: return {{-.5,0},{.5,0}};
    case 3: return {{0,-.5},{0,.5}};
    case 4: return {{.5,-.5},{-.5,.5}};
    case 5: return {{-.5,-.5},{.5,.5}};
    case 6: return {{-.5,0},{.5,.5}};
    case 7: return {{.5,0},{-.5,.5}};
    case 8: return {{.5,0},{-.5,-.5}};
    case 9: return {{-.5,0},{.5,-.5}};
    case 10: return {{0,.5},{-.5,-.5}};
    case 11: return {{0,.5},{.5,-.5}};
    case 12: return {{0,-.5},{-.5,.5}};
    case 13: return {{0,-.5},{.5,.5}};
    case 14: case 15: case 16: return {{0,-.5},{.5,0},{0,.5},{-.5,0}};
    case 17: case 49: return {{.5,-.5},{.5,.5},{-.5,.5},{-.5,-.5}};
    case 18: case 19: return {{-.5,0},{.5,0},{.5,-.5}};
    case 20: case 21: return {{-.5,0},{.5,0},{-.5,-.5}};
    case 22: case 23: return {{-.5,0},{.5,0},{.5,.5}};
    case 24: case 25: return {{-.5,0},{.5,0},{-.5,.5}};
    case 26: case 27: return {{0,-.5},{0,.5},{.5,.5}};
    case 28: case 29: return {{0,-.5},{0,.5},{-.5,.5}};
    case 30: case 31: return {{0,-.5},{0,.5},{.5,-.5}};
    case 32: case 33: return {{0,-.5},{0,.5},{-.5,-.5}};
    case 34: return {{-.5,0}};
    case 35: return {{.5,0}};
    case 36: return {{0,.5}};
    case 37: return {{0,-.5}};
    case 42: case 51: return rail_ports(6);
    case 43: case 57: return rail_ports(7);
    case 45: return rail_ports(8);
    case 44: return rail_ports(9);
    case 47: return rail_ports(10);
    case 46: return rail_ports(11);
    case 55: return rail_ports(12);
    case 48: return rail_ports(13);
    case 38: case 52: case 53: case 64: return rail_ports(3);
    case 39: case 50: case 54: case 56: case 58: case 63: return rail_ports(2);
    case 40: return rail_ports(5);
    case 41: return rail_ports(4);
    default: return {};
    }
}
bool RailNetwork::load(const std::filesystem::path& file, std::string& error) {
    std::ifstream in(file, std::ios::binary);
    if (!in) { error = "Cannot open CARTE.FIC: " + file.string(); return false; }
    // Bounded read; a malformed oversized input never allocates its declared size.
    std::vector<std::uint8_t> bytes(width * height);
    in.read(reinterpret_cast<char*>(bytes.data()), std::streamsize(bytes.size()));
    if (in.gcount() != std::streamsize(bytes.size()) || in.peek() != std::char_traits<char>::eof()) {
        error = "CARTE.FIC must contain exactly 11680 bytes"; return false;
    }
    return load_bytes(bytes, error);
}
bool RailNetwork::load_bytes(const std::vector<std::uint8_t>& bytes, std::string& error) {
    if (bytes.size() != width * height) { error = "CARTE.FIC must contain exactly 11680 bytes"; return false; }
    std::vector<int> staged;
    staged.reserve(bytes.size());
    for (auto b : bytes) staged.push_back(b > 127 ? int(b)-256 : int(b));
    initial_ = staged;
    tiles_ = std::move(staged);
    error.clear(); return true;
}
bool RailNetwork::loaded() const { return tiles_.size() == width * height; }
bool RailNetwork::in_bounds(Cell c) const { return c.x >= 0 && c.x < width && c.y >= 0 && c.y < height; }
int RailNetwork::tile(Cell c) const { return loaded() && in_bounds(c) ? tiles_[c.x * height + c.y] : 0; }
bool RailNetwork::is_switch(Cell c) const { const int t = tile(c); return t > 17 && t < 34; }
bool RailNetwork::toggle_switch(Cell c) {
    if (!is_switch(c)) return false;
    int& t = tiles_[c.x * height + c.y]; t += t % 2 == 0 ? 1 : -1; return true;
}
bool RailNetwork::repair(Cell c) {
    if(!loaded() || !in_bounds(c) || work_kind(tile(c))==WorkKind::None) return false;
    tiles_[c.x*height+c.y]=repaired_track(tile(c));
    return true;
}
bool RailNetwork::set_timed_bridge(int code) {
    // YODA 0x33ba..0x33f8 writes only the bridge at (110,33).
    constexpr Cell bridge{110,33};
    if (!loaded() || (code != -120 && code != -121)
        || initial_[bridge.x*height+bridge.y] != -120) return false;
    tiles_[bridge.x*height+bridge.y] = code;
    return true;
}
int RailNetwork::turn(Cell c, int h) const { return rail_turn(tile(c),h); }
int rail_turn(int signed_code, int h) {
    const int code = std::abs(signed_code);
    // Each row: curve code and its two incoming/outgoing TIME cases.
    constexpr int rules[][5] = {
        {6,6,3,7,4},{42,6,3,7,4},{51,6,3,7,4},
        {7,9,6,4,1},{43,9,6,4,1},{57,9,6,4,1},
        {8,3,6,4,7},{45,3,6,4,7},{9,6,9,1,4},{44,6,9,1,4},
        {10,8,7,3,2},{47,8,7,3,2},{11,8,9,1,2},{46,8,9,1,2},
        {12,2,1,9,8},{55,2,1,9,8},{13,2,3,7,8},{48,2,3,7,8}};
    for (const auto& r : rules) if (r[0] == code) return h == r[1] ? r[2] : h == r[3] ? r[4] : h;
    constexpr int switches[][5] = {
        {18,6,9,1,4},{20,4,7,3,6},{22,6,3,7,4},{24,4,1,9,6},
        {26,2,3,7,8},{28,2,1,9,8},{30,8,9,1,2},{32,8,7,3,2}};
    for (const auto& r : switches) if (code - code % 2 == r[0]) {
        if (h == r[1]) return code % 2 ? r[2] : h;
        if (h == r[3]) return r[4];
    }
    return h;
}
int RailNetwork::progress_speed(Cell c, int h, int speed) const {
    const int code = std::abs(tile(c));
    const bool doubled = (code == 15 && (h == 4 || h == 6)) || (code == 16 && (h == 2 || h == 8))
        || (code >= 38 && code <= 52) || (code >= 55 && code <= 57);
    return doubled ? speed * 2 : speed;
}
std::string RailNetwork::entry_boundary(Cell c) const {
    if (!in_bounds(c)) return "world edge wrap not verified";
    const int code = tile(c);
    if (code == 67 || code == 69 || code == -116 || code == 114 || (code < 0 && code > -105)) return "obstacle";
    if (code >= 34 && code <= 37) return "station";
    if (code == -120 || code == 65 || code == 78 || code == 79) return "event site";
    const bool corridor=campaign_entry_enabled && ((c==Cell{29,67} && code==-114) || (c==Cell{30,67} && code==-113));
    if (code <= -105 && code != -121 && code != -117 && !corridor) return "special site";
    constexpr Cell story[]{{11,10},{28,67},{29,67},{30,67},{151,66},{152,66},{152,48}};
    for (Cell s : story) if (s == c && !campaign_entry_enabled) return "story trigger";
    if (code == 0) return "no track";
    return {};
}
namespace {
// Exact mutation whitelist: rail_network.gd _mine_transition/_campaign_transition.
bool mine_transition(int before,int after) {
    if(before==2) return after>=18 && after<=24 && after%2==0;
    if(before==3) return after>=26 && after<=32 && after%2==0;
    if(before==78) return after==79;
    return (before==0 || before>85 || before<-124) && after==78;
}
bool campaign_transition(Cell c,int before,int after) {
    constexpr std::pair<Cell,int> writes[]={{{32,67},2},{{28,67},54},{{29,67},-114},
        {{30,67},-113},{{39,32},2},{{157,68},3},{{22,67},-122},{{34,4},80},{{52,32},-123}};
    for(const auto& [cell,value]:writes) if(c==cell && after==value) return true;
    if(c.x>=63 && c.x<=66 && c.y>=19 && c.y<=21 && after==-124) return true;
    if(before==-115 && after>=-128 && after<=127) return true;
    if(before>=1 && before<=58 && !(before>=34 && before<=37)) return after==-before;
    return (before==63 && after==67) || (before==64 && after==69)
        || (before==-117 && after==114) || (before==-121 && after==-116);
}
}
bool RailNetwork::apply_mine_writes(const std::vector<std::pair<Cell,int>>& writes) {
    if(!loaded()) return false;
    for(std::size_t i=0;i<writes.size();++i) {
        const auto& [cell,value]=writes[i];
        if(!in_bounds(cell) || (tile(cell)!=value && !mine_transition(tile(cell),value))) return false;
        for(std::size_t j=0;j<i;++j) if(writes[j].first==cell && writes[j].second!=value) return false;
    }
    for(const auto& [cell,value]:writes) tiles_[cell.x*height+cell.y]=value;
    return true;
}
bool RailNetwork::set_campaign_tile(Cell cell,int value) {
    if(!loaded() || !in_bounds(cell) || !campaign_transition(cell,tile(cell),value)) return false;
    tiles_[cell.x*height+cell.y]=value;
    return true;
}
bool RailNetwork::restore_tiles(const std::vector<int>& candidate) {
    if (!loaded() || candidate.size() != initial_.size()) return false;
    for (std::size_t i = 0; i < candidate.size(); ++i) {
        const int original = initial_[i], code = candidate[i];
        if (code == original) continue;
        const Cell cell{int(i)/height,int(i)%height};
        if(campaign_transition(cell,original,code) || mine_transition(original,code)) continue;
        if((original==0 || original>85 || original<-124) && code==79) continue;
        const int base=std::abs(code)-std::abs(code)%2;
        if((original==2 && base>=18 && base<=24) || (original==3 && base>=26 && base<=32)) continue;
        if (original == -120 && code == -121) continue;
        if(work_kind(original)!=WorkKind::None && code==repaired_track(original)) continue;
        if (original <= 17 || original >= 34 || code != original + (original % 2 ? -1 : 1)) return false;
    }
    tiles_ = candidate; return true;
}
// TIME 0x26fb..0x2868: offsets modify the loop counters, not only probes.
void RailNetwork::set_city_anchors(const std::vector<Cell>& anchors) { city_anchors_=anchors; }
int RailNetwork::station_lookup(Cell cell) const {
    if (cell==Cell{23,67}) return -2;
    if (cell==Cell{35,4}) return -3;
    if (cell==Cell{53,32}) return -4;
    if (cell==Cell{148,60}) return -5;
    if (cell==Cell{51,47}) return 40;
    constexpr std::array<Cell,6> offsets{{{2,1},{1,1},{0,1},{2,0},{1,0},{0,0}}};
    int dx=-1;
    do {
        int dy=-1;
        do {
            const Cell probe=cell+Cell{dx,dy};
            if (probe.y>=0 && probe.y<72 && probe.x>=0 && probe.x<width) {
                const int code=tile(probe);
                if (code>70 && code<77) {
                    dx+=offsets[code-71].x; dy+=offsets[code-71].y;
                    const Cell anchor=cell+Cell{dx,dy};
                    for (std::size_t i=0; i<std::min<std::size_t>(46,city_anchors_.size()); ++i)
                        if (city_anchors_[i]==anchor) return int(i);
                }
            }
        } while (++dy<=1);
    } while (++dx<=1);
    return -1;
}
} // namespace transartica
