// SPDX-License-Identifier: MIT
#pragma once
#include "session.hpp"
namespace transartica {
// train_renderer.gd authored scale and bounded chord solve. World projection is
// uniform in the native overhead view, so Euclidean world chords are sufficient.
inline constexpr double wagon_cell_ratio = .75;
inline constexpr int chord_iterations = 24;
struct TrainPose {
    Point front, rear, center, rail_midpoint;
    int heading{}, wagon_type{};
    double front_distance{}, rear_distance{};
    bool operator==(const TrainPose&) const = default;
};
// Read-only drawing uses already prepared connected history. Missing wagons are
// explicit: the result contains only the physically solved prefix.
std::vector<TrainPose> train_poses(const Journey&, const std::vector<Wagon>&, double lag=0);
// Simulation preparation may extend backing history on actual source rail ports.
std::vector<TrainPose> prepare_train_poses(Journey&, const RailNetwork&, const std::vector<Wagon>&);
void advance_train(Journey&, const RailNetwork&, const std::vector<Wagon>&, int speed);
void capture_reverse_switch(Journey&, const RailNetwork&, const std::vector<Wagon>&, Cell);
} // namespace transartica
