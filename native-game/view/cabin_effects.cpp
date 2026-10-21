// SPDX-License-Identifier: MIT
// Source: game/scripts/engine_living_effects.gd, exact valve/ember recipe.
#include "cabin_effects.h"
#include <algorithm>
#include <cmath>
namespace transartica {
void CabinEffects::advance(double seconds,const EngineState& engine,bool paused) {
    if(paused||!std::isfinite(seconds)||seconds<=0) return;
    remainder_+=seconds;
    constexpr double step=1./50; // living_effects.gd STEP.
    while(remainder_>=step||std::abs(remainder_-step)<.00001) {
        remainder_=std::max(0.,remainder_-step);
        effects_.advance(step);
        tick_=(tick_+1)%15; // engine_living_effects.gd PULSE=15, phase only.
        if(tick_==0) pulse(engine);
    }
}
void CabinEffects::pulse(const EngineState& engine) {
    if(engine.pressure_reserve>0) {
        effects_.add("steam",{416,270},{0,-1},3);
        effects_.add("steam",{1119,270},{0,-1},3);
    }
    if(engine.heat>0&&engine.lignite_rate+engine.anthracite_rate>0) {
        effects_.ember({800,650},{-35,-100},40,{3,3},{255,198,117,255},3);
        effects_.ember({850,650},{45,-130},35,{3,3},{255,181,78,255},3);
    }
}
void CabinEffects::draw(Canvas& canvas,SDL_FRect bounds) {
    // LivingEffects accepts arbitrary scene projection; these particles use
    // the source1600x1000 coordinates rather than tactical320x200 coordinates.
    effects_.draw_world(canvas,{bounds.x,bounds.y},bounds.w/1600);
}
void CabinEffects::clear() {effects_.clear();remainder_=0;tick_=0;}
}
