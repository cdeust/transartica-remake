// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "screens/tactical_living.hpp"
namespace transartica {
// engine_living_effects.gd: independent presentation50Hz, no gameplay RNG.
class CabinEffects {
public:
    explicit CabinEffects(const std::filesystem::path& assets):effects_(assets){}
    void advance(double seconds,const EngineState&,bool paused);
    void draw(Canvas&,SDL_FRect canvas1600x1000);
    void clear();
    std::size_t particle_count()const{return effects_.particle_count();}
private:
    panels::LivingEffects effects_;
    double remainder_{};
    int tick_{};
    void pulse(const EngineState&);
};
}
