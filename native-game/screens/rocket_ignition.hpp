// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "core/session.hpp"
#include <vector>
namespace transartica::panels {
// Exact authored shader equations on its half-logical-pixel lattice. The SDL
// streaming surface is retained and rebuilt only when its visual inputs change.
class RocketIgnition {
public:
    RocketIgnition()=default;~RocketIgnition();
    RocketIgnition(const RocketIgnition&)=delete;RocketIgnition&operator=(const RocketIgnition&)=delete;
    void clear();void observe(double seconds,Point nozzle,bool burning);void draw(Canvas&);
private:
    int tick_{};double remainder_{};Point nozzle_;bool active_{},dirty_=true;
    SDL_Texture* texture_{};std::vector<unsigned char> bytes_;
};
}
