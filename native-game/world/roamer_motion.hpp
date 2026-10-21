// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
#include <array>
namespace transartica::world {
// TIME0x1444/0x1a25/0x21d5, scripts/roamer_motion.gd.
int motion_turn(Cell,int heading,int phase,const std::vector<Cell>& history,const RailNetwork&,Random&);
struct MotionStep { Cell cell; int heading{}; };
MotionStep motion_step(Cell,int heading,int bit,const RailNetwork&,const std::array<int,7>& traps = {});
}
