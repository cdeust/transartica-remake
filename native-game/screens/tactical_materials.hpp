// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "core/session.hpp"
#include <map>
#include <memory>
#include <tuple>
#include <vector>
namespace transartica::panels {
// scripts/tactical_materials.gd; deterministic occupancy, independent of all RNG.
class TacticalMaterials {
public:
    struct Removed {Cell point;SDL_Color color;};
    struct Material {SDL_Texture*texture{},*front{};std::vector<float>tops;std::vector<Removed>removed;int width{},height{},small_width{},small_height{};};
    TacticalMaterials();~TacticalMaterials();
    const Material& get(Canvas&,const std::filesystem::path&source,SDL_Rect region,int side,int wagon,int health);
    SDL_Color iron(const std::filesystem::path&,SDL_Rect);
    void clear();
private:struct Impl;std::unique_ptr<Impl>impl_;
};
}
