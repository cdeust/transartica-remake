// SPDX-License-Identifier: MIT
#include "view.h"
#include "world_painting_join.hpp"
#include "core/train_pose.hpp"
#include "render_check.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <numbers>

namespace transartica {
namespace {
std::array<Point, 4> corners(SDL_FRect r) {
    return {{{r.x, r.y}, {r.x + r.w, r.y}, {r.x + r.w, r.y + r.h}, {r.x, r.y + r.h}}};
}
Point rotated(Point p, double radians) {
    return {p.x * std::cos(radians) - p.y * std::sin(radians), p.x * std::sin(radians) + p.y * std::cos(radians)};
}
}

std::vector<View::Pose> View::poses(const Session& session) const {
    std::vector<Pose> result;
    for (const auto& pose:train_poses(session.journey,session.wagons,world_motion_.lag(session.journey))) {
        const auto frame = frames_.find(vehicle_kind(pose.wagon_type));
        if (frame == frames_.end()) break;
        Cell cell{int(std::round(pose.rail_midpoint.x)),int(std::round(pose.rail_midpoint.y))};
        result.push_back({&frame->second,pose.front,pose.rear,pose.rail_midpoint,WorldVisual::train_tint(session.network.tile(cell)),pose.heading});
    }
    return result;
}

Point View::screen(Point p) const {
    const auto viewport = world_rect();
    return {viewport.x + viewport.w * 0.5 + (p.x - camera_.x) * cell_pixels_,
            viewport.y + viewport.h * 0.5 + (p.y - camera_.y) * cell_pixels_};
}

SDL_FRect View::world_rect() const {
    // Source: boudoir_session.gd _layout; ultrawide exterior above ECS y149 footer.
    const auto frame = fit(320, 200);
    return {0, frame.y, float(canvas_.width()), frame.h * 149 / 200};
}

std::optional<Cell> View::world_cell(float x, float y) const {
    if (!camera_ready_ || !std::isfinite(cell_pixels_) || cell_pixels_ <= 0 || !std::isfinite(x) || !std::isfinite(y)) return {};
    const auto viewport = world_rect();
    if (x < viewport.x || y < viewport.y || x >= viewport.x + viewport.w || y >= viewport.y + viewport.h) return {};
    const double wx=camera_.x+(x-viewport.x-viewport.w*.5)/cell_pixels_;
    const double wy=camera_.y+(y-viewport.y-viewport.h*.5)/cell_pixels_;
    // Pan remains unbounded, but only a finite point inside CARTE can be hit.
    // Reject before floating-to-int conversion, whose out-of-range result is undefined.
    if(!std::isfinite(wx)||!std::isfinite(wy)||wx<0||wy<0||wx>=RailNetwork::width||wy>=RailNetwork::height)return {};
    return Cell{int(std::floor(wx)),int(std::floor(wy))};
}

void View::update_camera(const Session& session, const std::vector<Pose>& train) {
    const auto viewport = world_rect();
    if (!camera_ready_) {
        double length{}, radius{};
        for (const auto& wagon : session.wagons) {
            length += vehicle_length(wagon.type);
            const auto frame = frames_.find(vehicle_kind(wagon.type));
            if (frame == frames_.end()) continue;
            const auto anchor = (frame->second.front + frame->second.rear) * 0.5;
            for (const auto p : corners(frame->second.bounds))
                radius = std::max(radius, distance(p, anchor) * wagon_cell_ratio / texels_per_cell_);
        }
        // Source: train_camera_fit.gd initial_zoom, 90% initial framing only.
        cell_pixels_ = std::min(viewport.w, viewport.h) * 0.9 / (length * wagon_cell_ratio + 2 * radius);
        // Source: travel_world.gd _initial_artwork_zoom_limit: no initial image enlargement.
        for (const auto& r : regions_)
            cell_pixels_ = std::min(cell_pixels_, double(std::min(r.crop.w / r.world.w, r.crop.h / r.world.h)));
        cell_pixels_=std::clamp(cell_pixels_,std::hypot(180.,100.)*.001,std::hypot(180.,100.)*2); // travel_world TRAVEL_MIN/MAX_ZOOM.
        const auto middle = session.journey.sample_behind(world_motion_.lag(session.journey)+length * wagon_cell_ratio * 0.5);
        if(!inspecting_map_)camera_ = (middle.ok ? middle.position : session.journey.fractional_position()) + Point{0.5, 0.5};
        camera_ready_ = true;
    }
    if(following_train_){camera_=world_motion_.position()+Point{.5,.5}-Point{viewport.w*(.72-.5)/cell_pixels_,viewport.h*(.65-.5)/cell_pixels_};return;} // travel_world TRAIN_NOSE_SCREEN.
    if(train.empty()||inspecting_map_)return;
    const auto with_decision=[&](SDL_FRect rect){auto p=screen(point(session.journey.next_cell())+Point{.5,.5});double left=std::min(double(rect.x),p.x),top=std::min(double(rect.y),p.y);
        return SDL_FRect{float(left),float(top),float(std::max(double(rect.x+rect.w),p.x)-left),float(std::max(double(rect.y+rect.h),p.y)-top)};};
    auto bounds=with_decision(train_bounds(train));
    if(bounds.w>viewport.w||bounds.h>viewport.h){auto hero=train_bounds({train.front()}),decision=with_decision(hero);bounds=decision.w<=viewport.w&&decision.h<=viewport.h?decision:hero;}
    // Source train_camera_fit::keep_train_in_view. The two source recenter
    // translations combine to this displacement; zoom is never reduced.
    if(bounds.x<viewport.x||bounds.y<viewport.y||bounds.x+bounds.w>viewport.x+viewport.w||bounds.y+bounds.h>viewport.y+viewport.h)
        camera_=camera_+Point{(bounds.x+bounds.w*.5-viewport.x-viewport.w*.5)/cell_pixels_,(bounds.y+bounds.h*.5-viewport.y-viewport.h*.5)/cell_pixels_};
}

void View::draw_vehicle(const Pose& pose,const RailNetwork& network) {
    const auto& frame = *pose.frame;
    const auto front = screen(pose.front + Point{0.5, 0.5});
    const auto rear = screen(pose.rear + Point{0.5, 0.5});
    const auto axis = front - rear;
    const double angle = std::atan2(axis.y, axis.x) - std::numbers::pi * 0.5;
    const auto center = (front + rear) * 0.5;
    const auto world_center=(pose.front+pose.rear)*.5+Point{.5,.5};
    const auto anchor=(frame.front+frame.rear)*.5;
    auto world_quad=corners(frame.bounds);
    for(auto& p:world_quad)p=world_center+rotated((p-anchor)*(wagon_cell_ratio/texels_per_cell_),angle);
    if(world_passages_.fully_covered(network,pose.front,pose.rear,pose.rail_midpoint,pose.heading,world_quad))return;
    draw_frame_at(frame, center, angle, cell_pixels_ * wagon_cell_ratio / texels_per_cell_,pose.tint);
}

SDL_FRect View::train_bounds(const std::vector<Pose>& train)const {
    if(train.empty())return {};
    Point low{std::numeric_limits<double>::infinity(),std::numeric_limits<double>::infinity()},high{-low.x,-low.y};
    for(const auto& pose:train){auto center=(pose.front+pose.rear)*.5+Point{.5,.5},axis=pose.front-pose.rear;
        double angle=std::atan2(axis.y,axis.x)-std::numbers::pi*.5;auto anchor=(pose.frame->front+pose.frame->rear)*.5;
        for(auto p:corners(pose.frame->bounds)){auto q=screen(center+rotated((p-anchor)*(wagon_cell_ratio/texels_per_cell_),angle));
            low.x=std::min(low.x,q.x);low.y=std::min(low.y,q.y);high.x=std::max(high.x,q.x);high.y=std::max(high.y,q.y);}}
    return {float(low.x),float(low.y),float(high.x-low.x),float(high.y-low.y)};
}

void View::advance_world(const Session& session,double seconds,bool visible,bool paused){
    if(!visible)world_left_=world_dragging_=false;
    world_motion_.synchronize(session.journey,visible);
    world_motion_.advance(session,seconds,visible,paused);
    if(!visible||paused||session.paused||session.engine.event_pending)return;
    auto train=poses(session);
    if(train.empty()){world_visual_.advance_effects(seconds,session.engine.heat,{});return;}
    auto stacks=WorldVisual::smoke_stacks(train.front().front,train.front().rear);
    world_visual_.advance_effects(seconds,session.engine.heat,stacks);
}

void View::draw_frame_at(const Frame& frame, Point center, double angle, double scale, SDL_Color tint) {
    auto* texture = canvas_.texture(frame.path);
    int width{}, height{};
    SDL_QueryTexture(texture, nullptr, nullptr, &width, &height);
    const auto anchor = (frame.front + frame.rear) * 0.5;
    const auto draw_corners = corners(frame.draw);
    const auto uv_corners = corners({float(frame.crop.x) / width, float(frame.crop.y) / height,
        float(frame.crop.w) / width, float(frame.crop.h) / height});
    std::array<SDL_Vertex, 4> vertices{};
    for (std::size_t i = 0; i < vertices.size(); ++i) {
        const auto p = center + rotated((draw_corners[i] - anchor) * scale, angle);
        vertices[i] = {{float(p.x), float(p.y)}, tint, {float(uv_corners[i].x), float(uv_corners[i].y)}};
    }
    constexpr int triangles[] = {0, 1, 2, 0, 2, 3};
    render_check(SDL_RenderGeometry(canvas_.renderer(), texture, vertices.data(), int(vertices.size()), triangles, 6), "Draw rigid train vehicle");
}

void View::world(const Session& session,std::string_view notice,const world::EnemyState* enemies,const economy::WorldData* cities) {
    world_motion_.synchronize(session.journey,true);
    auto train = poses(session);
    const auto size=world_rect();
    if(!camera_ready_||camera_cycle_!=session.engine.cycles||camera_visual_!=world_motion_.position()||camera_extent_.x!=size.w||camera_extent_.y!=size.h){
        update_camera(session,train);camera_cycle_=session.engine.cycles;camera_visual_=world_motion_.position();camera_extent_={size.w,size.h};}
    auto* renderer = canvas_.renderer();
    const auto viewport = world_rect();
    SDL_SetRenderDrawColor(renderer, 13, 27, 35, 255);
    SDL_RenderClear(renderer);
    const SDL_Rect clip{int(viewport.x), int(viewport.y), int(viewport.w), int(viewport.h)};
    SDL_RenderSetClipRect(renderer, &clip);
    for (const auto& region : regions_) {
        const auto p = screen({region.world.x, region.world.y});
        SDL_FRect dest{float(p.x), float(p.y), float(region.world.w * cell_pixels_), float(region.world.h * cell_pixels_)};
        if (dest.x + dest.w < viewport.x || dest.y + dest.h < viewport.y || dest.x > viewport.x + viewport.w || dest.y > viewport.y + viewport.h) continue;
        render_check(SDL_RenderCopyF(renderer, canvas_.texture(region.path), &region.crop, &dest), "Draw selected world painting");
    }
    const WorldProjection projection{screen({}),cell_pixels_,viewport};
    reconstruct_horizontal_painting_joins(canvas_,regions_,projection);
    world_passages_.floor(session.network,projection);
    world_visual_.rails(session.network,projection);
    const auto occupied=train_bounds(train);
    const auto locomotive=frames_.find("locomotive");
    if(enemies&&locomotive!=frames_.end())for(const auto& e:WorldVisual::visible_enemies(*enemies,session.journey,session.wagons,session.network))
        train.push_back({&locomotive->second,e.front,e.rear,e.center,e.tint,enemies->slots[e.slot].heading});
    // Active map_vehicle_object.gd places the y-sorted Node2D at pose.center.
    // rail_midpoint determines underground tint, not the actual sort position.
    std::stable_sort(train.begin(), train.end(), [](const Pose& a, const Pose& b) { return a.front.y+a.rear.y < b.front.y+b.rear.y; });
    // Owner18Oct visibility adaptation: real terrain pixels mask underground
    // spans below. The portions still outside remain fully opaque.
    for (auto pose : train) {pose.tint.a=255;draw_vehicle(pose,session.network);}
    world_visual_.draw_effects(projection);
    world_passages_.cover(session.network,projection);
    world_passages_.foreground(session.network,projection);
    if(cities)world_visual_.cities(*cities,session.network,projection,painted_world_,selected_city_);
    world_visual_.heading(session.journey,world_motion_.position(),occupied,projection);
    SDL_RenderSetClipRect(renderer, nullptr);
    footer(session, true);
    std::string status;
    if (session.paused) status = "PAUSED · "+key_label(input::Command::Pause)+" to resume";
    if (session.journey.blocked) status = "JOURNEY STOPPED: " + session.journey.stop_reason;
    if (session.engine.event_pending) status = "ENGINE STOPPED: " + session.engine.event_message;
    if (!notice.empty()) { if (!status.empty()) status += " | "; status += notice; }
    if (!status.empty()) panel(status, viewport.y);
}
}
