// SPDX-License-Identifier: MIT
#pragma once
#include "enemy_trains.hpp"
#include "world_actions.hpp"
#include "world_roamers.hpp"
namespace transartica::world {
struct Archive {EnemyState enemies;WorldActionState actions;RoamerState roamers;bool operator==(const Archive&)const=default;};
// Text protocol is independent of JSON/engine. Parse is bounded and atomic;
// models perform semantic validation against the restored live network.
std::string serialize(const Archive&);
bool parse(const std::string&,Archive&);
}
