// SPDX-License-Identifier: MIT
// Sources: game/scripts/game_calendar.gd; TABLE 0x0130..0x013c (initial date),
// YODA 0x3394 (minute factor), 0x33ba..0x33f8 (timed bridge),
// tasks/evidence/engine-cadence.md (three phases per remake cycle).
#include "session.hpp"
#include <iomanip>
#include <limits>
#include <sstream>

namespace transartica {
void GameCalendar::toggle_factor() { factor = factor == 1 ? 3 : 1; }
std::vector<std::string> GameCalendar::advance_cycle() {
    std::vector<std::string> events;
    if (!valid()) return events;
    // Factor changes the number of cycles per real second in the application.
    // A cycle itself always contains three source phases / game minutes.
    for (int trigger = 0; trigger < 3/factor; ++trigger) {
        minute += factor;
        if (minute <= 59) continue;
        minute %= 60;
        ++hour;
        if (hour == 12) events.emplace_back("bridge_open");
        else if (hour == 14) events.emplace_back("bridge_closed");
        if (hour <= 23) continue;
        ++day;
        hour = 0;
        events.emplace_back("new_day");
        if (day % 3 == 0) events.emplace_back("mines");
    }
    return events;
}
int GameCalendar::bridge_code() const { return hour >= 12 && hour < 14 ? -121 : -120; }
std::string GameCalendar::display_text() const {
    std::ostringstream text;
    text << "DAY " << day << ' ' << std::setfill('0') << std::setw(2) << hour << ':' << std::setw(2) << minute;
    return text.str();
}
bool GameCalendar::valid() const {
    // Native EngineState's persisted cycle count is bounded to INT32_MAX.
    // Three game minutes per cycle bound the date reachable by this schema;
    // this is a representation limit, not an invented campaign duration.
    constexpr std::int64_t last_day = (std::int64_t{2147483647}*3)/(24*60)+1;
    return minute >= 0 && minute <= 59 && hour >= 0 && hour <= 23
        && day >= 1 && day <= last_day && (factor == 1 || factor == 3);
}
} // namespace transartica
