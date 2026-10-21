// SPDX-License-Identifier: MIT
// Native schema 3 (reads forward schema 2): all fields are explicit and validated on a detached Session.
// Source staging contract: game/scripts/session_saves.gd:62-105. Bounds for
// engine/wagons/path follow their existing restore methods; this is NOT a legacy
// save importer. POSIX rename / Windows MoveFileEx commit within one filesystem.
#include "session.hpp"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <limits>
#include <locale>
#include <sstream>
#include <system_error>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#endif

namespace transartica {
namespace {
bool valid_wagons(const std::vector<Wagon>& wagons) {
    if (wagons.empty() || wagons.size() > 100) return false;
    for (const auto& w : wagons) {
        const int minimum = w.type == 23 || w.type == 24 ? -128 : 0;
        if (w.type < 1 || w.type > 25 || w.state < 0 || w.state > 3 || w.goods < 0 || w.goods > 16 || w.quantity < minimum || w.quantity > 127) return false;
    }
    return true;
}
bool valid_session(const Session& s) {
    return s.network.loaded() && s.engine.valid() && s.calendar.valid() && valid_wagons(s.wagons)
        && transartica::train_mass(s.wagons) == s.engine.train_mass && s.journey.valid(s.network)
        && (s.network.initial_tiles()[110*RailNetwork::height+33] != -120
            || s.network.tile({110,33}) == s.calendar.bridge_code())
        && s.seconds_per_cycle == 1.0
        && std::isfinite(s.accumulator) && s.accumulator >= 0 && s.accumulator < s.seconds_per_cycle
        // world_session.gd suspends work through the modal, independently of
        // paused; journey_session retries a refused entry after brake release.
        && (s.network.campaign_entry_enabled || !s.journey.blocked || (s.paused && s.engine.brake && s.engine.speed == 0));
}
bool token(std::istream& in, const char* expected) { std::string t; return bool(in >> t) && t == expected; }
bool boolean(std::istream& in, bool& out) {
    int value = -1;
    if (!(in >> value) || (value != 0 && value != 1)) return false;
    out = value == 1; return true;
}
void write_session(std::ostream& out, const Session& s) {
    out.imbue(std::locale::classic());
    out << std::setprecision(std::numeric_limits<double>::max_digits10);
    out << "TRANSARTICA_NATIVE_FORWARD 3\nORIGINAL " << s.network.initial_tiles().size() << '\n';
    for (int v : s.network.initial_tiles()) out << v << ' ';
    out << "\nTILES " << s.network.tiles().size() << '\n';
    for (int v : s.network.tiles()) out << v << ' ';
    const auto& e = s.engine;
    out << "\nENGINE " << e.lignite << ' ' << e.anthracite << ' ' << e.lignite_rate << ' ' << e.anthracite_rate
        << ' ' << e.regulator << ' ' << e.speed << ' ' << e.heat << ' ' << e.temperature << ' ' << e.pressure_reserve
        << ' ' << e.cycles << ' ' << e.train_mass << ' ' << int(e.brake) << ' ' << int(e.event_pending) << ' ' << std::quoted(e.event_message);
    out << "\nCLOCK " << int(s.paused) << ' ' << s.seconds_per_cycle << ' ' << s.accumulator;
    out << "\nCALENDAR " << s.calendar.minute << ' ' << s.calendar.hour << ' ' << s.calendar.day << ' ' << s.calendar.factor;
    out << "\nWAGONS " << s.wagons.size() << '\n';
    for (auto w : s.wagons) out << w.type << ' ' << w.state << ' ' << w.goods << ' ' << w.quantity << '\n';
    const auto& j = s.journey;
    out << "JOURNEY " << j.position.x << ' ' << j.position.y << ' ' << j.heading << ' ' << j.incoming_heading
        << ' ' << j.distance_ticks << ' ' << j.phase << ' ' << int(j.blocked) << ' ' << std::quoted(j.stop_reason);
    out << "\nPATH " << j.path.size() << '\n';
    for (Point p : j.path) out << p.x << ' ' << p.y << '\n';
    out << "RENDER " << int(j.reversing) << ' ' << j.render_cursor << ' ' << j.render_origin
        << ' ' << j.render_end_cell.x << ' ' << j.render_end_cell.y << ' ' << j.render_end_heading;
    out << "\nRENDER_PATH " << j.render_path.size() << '\n';
    for (Point p : j.render_path) out << p.x << ' ' << p.y << '\n';
    out << "PHYSICAL " << j.physical_obstacle.x << ' ' << j.physical_obstacle.y << ' ' << j.physical_heading << ' ' << int(j.physical_spy_handled);
    out << "\nSWITCH_LATCHES " << j.reverse_switches.size() << '\n';
    for (const auto& latch : j.reverse_switches) out << latch.cell.x << ' ' << latch.cell.y << ' ' << latch.heading << '\n';
    out << "END\n";
}
bool read_reverse(std::istream& in, Journey& j, std::uintmax_t bytes) {
    std::size_t count=0;
    if (!token(in,"RENDER") || !boolean(in,j.reversing)
        || !(in >> j.render_cursor >> j.render_origin >> j.render_end_cell.x >> j.render_end_cell.y >> j.render_end_heading)) return false;
    if (!token(in,"RENDER_PATH") || !(in >> count) || count>bytes/4) return false;
    j.render_path.resize(count);
    for (auto& p:j.render_path) if (!(in >> p.x >> p.y)) return false;
    if (!token(in,"PHYSICAL") || !(in >> j.physical_obstacle.x >> j.physical_obstacle.y >> j.physical_heading)
        || !boolean(in,j.physical_spy_handled)) return false;
    if (!token(in,"SWITCH_LATCHES") || !(in >> count) || count>RailNetwork::width*RailNetwork::height || count>bytes/6) return false;
    j.reverse_switches.resize(count);
    for (auto& latch:j.reverse_switches) if (!(in >> latch.cell.x >> latch.cell.y >> latch.heading)) return false;
    return true;
}
bool read_session(std::istream& in, Session& staged, std::uintmax_t file_bytes) {
    in.imbue(std::locale::classic());
    int version = 0;
    if (!token(in,"TRANSARTICA_NATIVE_FORWARD") || !(in >> version) || (version != 2 && version != 3)) return false;
    std::size_t count = 0;
    if (!token(in,"ORIGINAL") || !(in >> count) || count != staged.network.initial_tiles().size()) return false;
    for (int original : staged.network.initial_tiles()) { int code; if (!(in >> code) || code != original) return false; }
    if (!token(in,"TILES") || !(in >> count) || count != staged.network.tiles().size()) return false;
    std::vector<int> tiles(count);
    for (int& t : tiles) if (!(in >> t)) return false;
    if (!staged.network.restore_tiles(tiles)) return false;
    auto& e = staged.engine;
    if (!token(in,"ENGINE") || !(in >> e.lignite >> e.anthracite >> e.lignite_rate >> e.anthracite_rate >> e.regulator >> e.speed
        >> e.heat >> e.temperature >> e.pressure_reserve >> e.cycles >> e.train_mass)
        || !boolean(in,e.brake) || !boolean(in,e.event_pending) || !(in >> std::quoted(e.event_message))) return false;
    if (!token(in,"CLOCK") || !boolean(in,staged.paused) || !(in >> staged.seconds_per_cycle >> staged.accumulator)) return false;
    if (!token(in,"CALENDAR") || !(in >> staged.calendar.minute >> staged.calendar.hour >> staged.calendar.day >> staged.calendar.factor)) return false;
    if (!token(in,"WAGONS") || !(in >> count) || count == 0 || count > 100) return false;
    staged.wagons.resize(count);
    for (auto& w : staged.wagons) if (!(in >> w.type >> w.state >> w.goods >> w.quantity)) return false;
    staged.journey = Journey{}; // Forward v2 has no retained reverse state.
    auto& j = staged.journey;
    if (!token(in,"JOURNEY") || !(in >> j.position.x >> j.position.y >> j.heading >> j.incoming_heading >> j.distance_ticks >> j.phase)
        || !boolean(in,j.blocked) || !(in >> std::quoted(j.stop_reason))) return false;
    // Each text point needs at least "0 0\n" (four bytes). Validate before allocation.
    if (!token(in,"PATH") || !(in >> count) || count == 0 || count > file_bytes / 4) return false;
    j.path.resize(count);
    for (auto& p : j.path) if (!(in >> p.x >> p.y)) return false;
    if (version==3 && !read_reverse(in,j,file_bytes)) return false;
    if (!token(in,"END")) return false;
    in >> std::ws;
    if (!in.eof() || !valid_session(staged)) return false;
    if (!j.render_path.empty()) j.render_cursor=std::min(j.render_cursor,j.render_length());
    return true;
}
bool replace_file(const std::filesystem::path& source, const std::filesystem::path& target, std::string& error) {
#ifdef _WIN32
    if (!MoveFileExW(source.c_str(),target.c_str(),MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        error = "Save replacement failed with Windows error " + std::to_string(GetLastError()); return false;
    }
#else
    std::error_code ec;
    std::filesystem::rename(source,target,ec);
    if (ec) { error = "Save replacement failed: " + ec.message(); return false; }
#endif
    return true;
}
}
bool Session::write_snapshot(std::ostream& out) const {
    if (!valid_session(*this)) return false;
    write_session(out,*this);
    return bool(out);
}
bool Session::read_snapshot(std::istream& in, std::uintmax_t bytes, std::string& error) {
    if (!network.loaded()) { error="Load CARTE.FIC before loading a native save"; return false; }
    Session staged=*this;
    if (!read_session(in,staged,bytes)) { error="Invalid native snapshot (schema 2 or 3 required); current session preserved"; return false; }
    *this=std::move(staged); error.clear(); return true;
}
bool Session::save(const std::filesystem::path& file, std::string& error) const {
    if (!valid_session(*this)) { error = "Current native session is invalid; previous save preserved"; return false; }
    // Atomically claim a sibling directory so another writer's temporary data
    // is never overwritten. The save file and its replacement share a volume.
    auto pending = file;
    pending += ".pending";
    std::error_code ec;
    if (!std::filesystem::create_directory(pending,ec)) {
        error = "Cannot claim save staging directory: " + pending.string() + (ec ? ": " + ec.message() : " already exists"); return false;
    }
    const auto staged = pending / "session.tmp";
    bool committed = false;
    {
        std::ofstream out(staged,std::ios::binary | std::ios::trunc);
        const bool written=write_snapshot(out);
        out.flush();
        if (!written || !out) error = "Cannot write complete native save; previous save preserved";
        else {
            out.close();
            if (out.fail()) error = "Cannot close native save; previous save preserved";
            else committed = replace_file(staged,file,error);
        }
    }
    std::filesystem::remove(staged,ec);
    std::filesystem::remove(pending,ec);
    if (committed) error.clear();
    return committed;
}
bool Session::load_save(const std::filesystem::path& file, std::string& error) {
    if (!network.loaded()) { error = "Load CARTE.FIC before loading a native save"; return false; }
    std::error_code ec;
    const auto bytes = std::filesystem::file_size(file,ec);
    if (ec) { error = "Cannot read native save: " + ec.message(); return false; }
    // Resource policy: bound serialized input to 1/64 of the host's 1-GiB task
    // cap, leaving space for decoded paths and currently resident artwork.
    constexpr std::uintmax_t max_save_bytes = (1024ULL * 1024 * 1024) / 64;
    if (bytes > max_save_bytes) { error = "Native save exceeds the bounded input budget"; return false; }
    std::ifstream in(file,std::ios::binary);
    if (!in) { error="Cannot open native save"; return false; }
    return read_snapshot(in,bytes,error);
}
} // namespace transartica
