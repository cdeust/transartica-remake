// SPDX-License-Identifier: MIT
#pragma once
#include "combat/tactical.hpp"
#include <memory>
#include <optional>
#include <set>
namespace transartica::panels {
class TacticalScreen;
class TacticalMotion {
public:
    TacticalMotion();~TacticalMotion();
    void clear();void melee(const combat::Event&);
    void step(TacticalScreen&,const combat::Tactical&);
    void ease_labels(TacticalScreen&,const combat::Tactical&);
    void draw(TacticalScreen&,const combat::Tactical&);
    Point point(TacticalScreen&,const combat::Tactical&,const combat::Actor&);
private:struct Impl;std::unique_ptr<Impl>impl_;
};
}
