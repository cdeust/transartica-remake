// SPDX-License-Identifier: MIT
// Sources: game/scripts/{engine_state,train_wagons,train_consist}.gd;
// tasks/evidence/locomotive-rules.md. Integer divisions preserve decoded TIME.
#include "session.hpp"
#include <algorithm>
#include <limits>

namespace transartica {
std::vector<Wagon> initial_wagons() { return {{1,0,0,0},{21,0,0,0},{2,0,0,0},{3,0,0,0},{17,0,0,0},{23,0,0,10}}; }
int train_mass(const std::vector<Wagon>& wagons) {
    constexpr int weights[]{1000,50,40,110,65,85,60,105,20,100,100,40,120,40,45,55,45,55,40,90,50,50,80,100,200};
    int result = 0;
    for (auto w : wagons) {
        if (w.type < 1 || w.type > 25) return 0;
        int load = 0;
        switch (w.type) {
        case 5: case 6: case 23: case 24: load = w.quantity / 10; break;
        case 7: case 21: load = w.quantity * 10; break;
        case 14: case 15: case 17: case 18: case 19: load = w.quantity; break;
        default: break;
        }
        result += weights[w.type-1] + load;
    }
    return result;
}
std::string vehicle_kind(int type) {
    constexpr const char* names[]{"locomotive","general-quarters","boudoir","observatory","prison","alcatraz","livestock","drill","harpoon","observation-box","cannon","machine-gun","missile-launcher","tank","oil","crane","merchandise","xl-merchandise","bio-greenhouse","refrigerator","tender","spy","barracks","xl-barracks","boiler"};
    return type >= 1 && type <= 25 ? names[type-1] : "";
}
double vehicle_length(int type) {
    // Authored atlas alpha spans; not historical wagon dimensions.
    constexpr double lengths[]{1.0,1.01,.99,.99,1,1,1,1,1,1,1,1,1,1,.99,1,.99,.99,1,1,1.01,1,.99,1,.99};
    return type >= 1 && type <= 25 ? lengths[type-1] : 0;
}
void EngineState::cycle_lignite() { lignite_rate = (lignite_rate + 1) % 3; }
void EngineState::cycle_anthracite() { anthracite_rate = (anthracite_rate + 1) % 3; }
void EngineState::set_regulator(int value) { regulator = std::clamp(value,0,300); }
void EngineState::toggle_brake() { brake = !brake; }
void EngineState::step_cycle() {
    if (event_pending || train_mass <= 0) return;
    ++cycles;
    heat += 10*lignite_rate + 30*anthracite_rate;
    if (heat > 5000) { event_pending = true; event_message = "Boiler overload"; return; }
    lignite = std::max(0, lignite-lignite_rate);
    anthracite = std::max(0, anthracite-anthracite_rate);
    if (lignite == 0 && anthracite == 0 && (lignite_rate != 0 || anthracite_rate != 0)) {
        event_pending = true; event_message = "No coal remaining"; return;
    }
    int transfer = 0;
    if (heat != 0) { transfer = heat / 100 + 1; heat = std::max(0, heat-transfer); }
    temperature = std::min(heat,600);
    if (temperature > 100) pressure_reserve = std::min(32000,pressure_reserve+100*transfer);
    const int mass_factor = train_mass / 100;
    const int resistance = (train_mass + mass_factor*mass_factor) / 2;
    // The old runtime reports a division error for these invalid configurations.
    // Standalone must stop visibly rather than invoke undefined integer division.
    if (resistance == 0 || 32000 / resistance == 0) {
        event_pending = true; event_message = "Unsupported train mass: zero engine divisor"; return;
    }
    const int divisor = 32000 / resistance;
    pressure_reserve -= (speed + speed*(speed/10)) / divisor;
    if (brake) { pressure_reserve = std::max(pressure_reserve,0); speed = std::max(speed-5,0); return; }
    if (pressure_reserve <= 0) { pressure_reserve = 0; speed -= 5; }
    else if (pressure_reserve > 1500 || speed > 0) {
        speed = speed < regulator ? std::min(speed+5,regulator) : std::max(speed-5,regulator);
    }
    speed = std::max(speed,0);
}
bool EngineState::valid() const {
    const auto between = [](auto v, auto lo, auto hi) { return v >= lo && v <= hi; };
    return between(lignite,0,32767) && between(anthracite,0,32767)
        && between(lignite_rate,0,2) && between(anthracite_rate,0,2)
        && between(regulator,0,300) && between(speed,0,300) && between(heat,0,32767)
        && between(temperature,0,600) && between(pressure_reserve,0,32000)
        && between(cycles,std::int64_t{0},std::int64_t{2147483647}) && between(train_mass,1,32767)
        && (event_pending ? !event_message.empty() : event_message.empty());
}
} // namespace transartica
