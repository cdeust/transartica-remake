// SPDX-License-Identifier: MIT
// Source finale_sequence.gd: IFEBO0x24d..346 waits,50Hz ALIS screen cadence.
#include "types.hpp"
#include <algorithm>
#include <cmath>
namespace transartica::campaign {
void Finale::start(std::uint64_t value) {
    tick=0;remainder=0;seed=value;Random rng;rng.seed(value);int previous=0;
    for(int& palette:palettes_) {palette=rng.range(0,3);if(palette==previous) palette=(palette+1)%4;previous=palette;}
}
bool Finale::advance(double seconds) {
    if(!std::isfinite(seconds)||seconds<0) return false;
    remainder+=seconds*50;
    // Preserve source is_equal_approx rounding (Math::CMP_EPSILON=0.00001).
    const double nearest=std::round(remainder),tolerance=std::max(0.00001*std::abs(remainder),0.00001);
    const double steps=std::abs(remainder-nearest)<tolerance?nearest:std::floor(remainder);
    remainder=std::max(0.0,remainder-steps);tick=int(std::min(361.0,tick+steps));return tick==361;
}
bool Finale::valid() const {return tick>=0&&tick<=361&&std::isfinite(remainder)&&remainder>=0&&remainder<1;}
int Finale::shot() const {
    constexpr std::array<std::array<int,2>,11> shots{{{36,30},{37,5},{38,5},{39,5},{38,5},{37,3},{38,2},{39,20},{39,5},{39,20},{40,20}}};
    int total=0;for(auto shot:shots) {total+=shot[1];if(tick<total) return shot[0];}return 2;
}
int Finale::palette() const {int counter=tick-120;return counter<0||counter>=200?0:palettes_[counter];}
std::array<int,4> Finale::clouds() const {int moved=std::max(0,tick-120-35);return {-moved*4,-moved*3,-moved*2,-moved};}
}
