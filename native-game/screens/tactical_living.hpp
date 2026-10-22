// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "core/session.hpp"
#include "core/random.hpp"
#include <memory>
#include <vector>
#include <limits>
#include <functional>
namespace transartica::panels {
// Presentation only: source living_effects.gd and living_particles.gd.
// Fixed50Hz; owns sparse particles and at most four small blast fields.
class LivingEffects {
public:
    explicit LivingEffects(std::filesystem::path assets);
    ~LivingEffects();
    LivingEffects(const LivingEffects&)=delete;LivingEffects&operator=(const LivingEffects&)=delete;
    void add(std::string kind,Point point,Point direction={1,0},double scale=1);
    void fire_round(Point point,Point direction,int number,double heat,double floor_y,double reach,bool armour,Point breech={std::numeric_limits<double>::infinity(),std::numeric_limits<double>::infinity()});
    void fragments(Point,const std::vector<SDL_Color>&);
    // engine_living_effects.gd explicit particles.launch("ember",...) recipe.
    void ember(Point point,Point velocity,int lifetime,Point extent,SDL_Color,double scale=1);
    void advance(double seconds,const std::function<void()>& before_step={});
    void draw(Canvas&,Point offset={});
    void draw_world(Canvas&,Point screen_origin,double zoom);
    void draw_light(Canvas&,Point offset={});
    void draw_atlas(Canvas&,const std::string& name,Point,Point extent,SDL_Color,double angle=0);
    void clear();Point shake_offset()const;
    std::size_t particle_count()const;
private:struct Impl;std::unique_ptr<Impl> impl_;
};
}
