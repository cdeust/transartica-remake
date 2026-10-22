// SPDX-License-Identifier: MIT
// Source: game/scripts/train_renderer.gd:119..186. Shared simulation/render solve.
#include "train_pose.hpp"
#include <algorithm>
#include <cmath>
#include <limits>
namespace transartica {
namespace {
int pose_heading(Point delta, int fallback) {
    const double length=distance({},delta);
    if (length<.00001) return fallback;
    double score=-std::numeric_limits<double>::infinity();
    int best=fallback;
    for (int h=1; h<=9; ++h) if (h!=5) {
        const Point d=point(heading_delta(h));
        const double alignment=(delta.x*d.x+delta.y*d.y)/(length*distance({},d));
        if (alignment>score) { score=alignment; best=h; }
    }
    return best;
}
struct Rear { bool ok{}; Point position; double arc{}; };
template<class Sample> Rear solve_rear(Sample& sample, double arc, Point front, double nominal) {
    double low=arc+nominal*.35, high=arc+nominal*2.2;
    double closest=std::numeric_limits<double>::infinity();
    Rear best;
    for (int i=0; i<chord_iterations; ++i) {
        const double mid=(low+high)*.5;
        const auto contact=sample(mid);
        if (!contact.ok) { high=mid; continue; }
        const double chord=distance(contact.position,front), error=std::abs(chord-nominal);
        if (error<closest) { closest=error; best={true,contact.position,mid}; }
        if (chord<nominal) low=mid; else high=mid;
    }
    // Source is_equal_approx scalar tolerance, in uniformly projected units.
    if (closest>=std::max(.00001,nominal*.00001)) best.ok=false;
    return best;
}
template<class Sample> std::vector<TrainPose> solve_poses(Sample sample, const std::vector<Wagon>& wagons,double lag=0) {
    std::vector<TrainPose> result;
    result.reserve(wagons.size());
    double arc=std::max(0.,lag); // train_renderer.gd poses starts at max(lag,0).
    for (const auto& wagon:wagons) {
        const auto front=sample(arc);
        if (!front.ok) break;
        const auto rear=solve_rear(sample,arc,front.position,vehicle_length(wagon.type)*wagon_cell_ratio);
        if (!rear.ok) break;
        const auto middle=sample((arc+rear.arc)*.5);
        const Point center=(front.position+rear.position)*.5;
        result.push_back({front.position,rear.position,center,middle.ok ? middle.position : center,
            pose_heading(front.position-rear.position,middle.ok ? middle.heading : front.heading),wagon.type,arc,rear.arc});
        arc=rear.arc;
    }
    return result;
}
}
std::vector<TrainPose> train_poses(const Journey& j, const std::vector<Wagon>& wagons,double lag) {
    return solve_poses([&](double d){return j.sample_behind(d);},wagons,lag);
}
std::vector<TrainPose> prepare_train_poses(Journey& j, const RailNetwork& net, const std::vector<Wagon>& wagons) {
    return solve_poses([&](double d) {
        if (j.reversing && !j.render_path.empty()) {
            while (d>j.render_cursor) if (!j.extend_backing_path(net)) break;
        }
        return j.sample_behind(d);
    },wagons);
}
} // namespace transartica
