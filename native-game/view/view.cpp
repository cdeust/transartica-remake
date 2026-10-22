// SPDX-License-Identifier: MIT
#include "view.h"
#include "render_check.h"
#include "platform/hash.h"
#include <json-c/json.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <stdexcept>

namespace transartica {
namespace {
using Json = std::unique_ptr<json_object, decltype(&json_object_put)>;
json_object* member(json_object* obj, const char* key) {
    json_object* value{};
    if (!json_object_object_get_ex(obj, key, &value))
        throw std::runtime_error(std::string("Missing artwork field: ") + key);
    return value;
}
double number(json_object* array, std::size_t index) {
    auto* value = json_object_array_get_idx(array, index);
    if (!value || !(json_object_is_type(value, json_type_int) || json_object_is_type(value, json_type_double)))
        throw std::runtime_error("Invalid artwork coordinate");
    const double result = json_object_get_double(value);
    if (!std::isfinite(result)) throw std::runtime_error("Non-finite artwork coordinate");
    return result;
}
SDL_FRect rectangle(json_object* array) {
    if (!json_object_is_type(array, json_type_array) || json_object_array_length(array) != 4)
        throw std::runtime_error("Invalid artwork rectangle");
    SDL_FRect result{float(number(array, 0)), float(number(array, 1)), float(number(array, 2)), float(number(array, 3))};
    if (result.w <= 0 || result.h <= 0) throw std::runtime_error("Empty artwork rectangle");
    return result;
}
SDL_Rect pixels(json_object* array) {
    const auto r = rectangle(array);
    if (r.x < 0 || r.y < 0 || r.x != std::floor(r.x) || r.y != std::floor(r.y) ||
        r.w != std::floor(r.w) || r.h != std::floor(r.h) ||
        double(r.x) > std::numeric_limits<int>::max() || double(r.y) > std::numeric_limits<int>::max() ||
        double(r.w) > std::numeric_limits<int>::max() || double(r.h) > std::numeric_limits<int>::max())
        throw std::runtime_error("Invalid artwork pixel crop");
    return {int(r.x), int(r.y), int(r.w), int(r.h)};
}
void validate_crop(Canvas& canvas, const std::filesystem::path& path, SDL_Rect crop) {
    const auto size=canvas.image_size(path);
    const int width=size.x,height=size.y;
    if (crop.x < 0 || crop.y < 0 || crop.w <= 0 || crop.h <= 0 || crop.x > width || crop.y > height ||
        crop.w > width - crop.x || crop.h > height - crop.y)
        throw std::runtime_error("Artwork crop outside texture: " + path.string());
}
std::string string(json_object* obj) {
    if (!json_object_is_type(obj, json_type_string)) throw std::runtime_error("Invalid artwork string");
    return json_object_get_string(obj);
}
bool contains(SDL_FRect r, Point p) {
    return p.x >= r.x && p.y >= r.y && p.x < r.x + r.w && p.y < r.y + r.h;
}
}

View::View(Canvas& canvas, std::filesystem::path assets, std::filesystem::path artwork)
    : canvas_(canvas), assets_(std::move(assets)), artwork_(std::move(artwork)),world_visual_(canvas_,assets_),world_passages_(canvas_,assets_),cabin_effects_(assets_) {
    load_artwork();
    load_vehicles();
}

void View::load_artwork() {
    Json root(json_object_from_file((artwork_ / "manifest.json").string().c_str()), json_object_put);
    if (!root) throw std::runtime_error("Cannot read selected world-hd artwork manifest");
    auto* scenes = member(root.get(), "scenes");
    if (!json_object_is_type(scenes, json_type_array) || !json_object_array_length(scenes))
        throw std::runtime_error("Empty selected artwork manifest");
    for (std::size_t i = 0; i < json_object_array_length(scenes); ++i) {
        auto* scene = json_object_array_get_idx(scenes, i);
        if (string(member(scene, "registration")) != "region_bounds")
            throw std::runtime_error("Unsupported artwork registration");
        auto* variants = member(scene, "variants");
        if (!json_object_is_type(variants, json_type_array) || json_object_array_length(variants) != 1)
            throw std::runtime_error("Regional artwork requires its one selected variant");
        auto* variant = json_object_array_get_idx(variants, 0);
        auto filename = std::filesystem::path(string(member(member(variant, "background"), "image"))).filename();
        Region region{rectangle(member(scene, "world")), pixels(member(variant, "source_crop")), artwork_ / filename};
        if (!std::filesystem::is_regular_file(region.path))
            throw std::runtime_error("Missing selected painting: " + region.path.string());
        verify_sha256(region.path, string(member(member(variant, "background"), "png_sha256")));
        validate_crop(canvas_, region.path, region.crop);
        painted_world_.push_back(region.world);
        world_passages_.add_painting(region.world,region.crop,region.path);
        regions_.push_back(std::move(region));
    }
}

void View::load_vehicles() {
    Json root(json_object_from_file((assets_ / "travel/vehicles-overhead.json").string().c_str()), json_object_put);
    if (!root) throw std::runtime_error("Cannot read vehicle artwork manifest");
    const auto atlas = assets_ / "travel" / string(member(root.get(), "file"));
    auto* vehicles = member(root.get(), "vehicles");
    if (!json_object_is_type(vehicles, json_type_object)) throw std::runtime_error("Invalid vehicle catalogue");
    json_object_object_foreach(vehicles, key, value) {
        const auto crop = pixels(member(value, "region"));
        validate_crop(canvas_, atlas, crop);
        auto* front = member(value, "front");
        auto* rear = member(value, "rear");
        frames_[key] = {crop, {number(front, 0), number(front, 1)}, {number(rear, 0), number(rear, 1)},
            {0, 0, float(crop.w), float(crop.h)}, atlas, {}};
        const auto used = canvas_.alpha_bounds(atlas, crop);
        frames_[key].bounds = {float(used.x),float(used.y),float(used.w),float(used.h)};
    }
    auto found = frames_.find("locomotive");
    if (found == frames_.end()) throw std::runtime_error("Locomotive artwork absent");
    auto& frame = found->second;
    texels_per_cell_ = distance(frame.front, frame.rear);
    if (texels_per_cell_ <= 0) throw std::runtime_error("Invalid locomotive contact anchors");
    // Source: train_renderer.gd load_assets; accepted hero alpha crop and registration.
    frame.crop = {178, 48, 438, 1886};
    const auto center = (frame.front + frame.rear) * 0.5;
    const double width = frame.crop.w * texels_per_cell_ / frame.crop.h;
    frame.draw = {float(center.x - width * 0.5), float(center.y - texels_per_cell_ * 0.5), float(width), float(texels_per_cell_)};
    frame.bounds = frame.draw;
    frame.path = assets_ / "travel/locomotive-hero.png";
    validate_crop(canvas_, frame.path, frame.crop);
}

SDL_FRect View::fit(float w, float h) const {
    const float factor = std::min(float(canvas_.width()) / w, float(canvas_.height()) / h);
    return {(canvas_.width() - w * factor) * 0.5f, (canvas_.height() - h * factor) * 0.5f, w * factor, h * factor};
}
Point View::logical(float x, float y, float w, float h) const {
    const auto r = fit(w, h);
    return {(x - r.x) * w / r.w, (y - r.y) * h / r.h};
}
void View::panel(std::string_view text, float y) {
    auto* renderer = canvas_.renderer();
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
    SDL_SetRenderDrawColor(renderer, 9, 16, 20, 235);
    SDL_FRect bounds{0, y, float(canvas_.width()), 36};
    SDL_RenderFillRectF(renderer, &bounds);
    canvas_.text(text, 16, y + 8, 18, {235, 189, 112, 255});
}
void View::reception(std::string_view notice) {
    const auto destination = fit(320, 200); // Source: original_screen.gd logical ECS canvas.
    render_check(SDL_RenderCopyF(canvas_.renderer(), canvas_.texture(assets_ / "interface/reception.png"), nullptr, &destination), "Draw reception artwork");
    if (!notice.empty()) panel(notice, 0);
}
Action View::reception_action(float x, float y) const {
    const auto p = logical(x, y, 320, 200);
    // Source: reception_screen.gd PLAQUES; retain original artwork hit regions.
    if (contains({95, 50, 128, 68}, p)) return Action::Start;
    if (contains({191, 126, 128, 68}, p)) return Action::Load;
    if (contains({0, 0, 128, 68}, p)) return Action::Difficulty;
    if (contains({191, 0, 128, 68}, p)) return Action::Combat;
    if (contains({0, 126, 128, 68}, p)) return Action::Music;
    return Action::None;
}
void View::reset_world() { camera_ready_=false;world_motion_=WorldMotion{};world_visual_.clear_effects();following_train_=inspecting_map_=world_left_=world_dragging_=false;selected_city_=-1;camera_cycle_=-1; }
void View::reset_camera() { reset_world(); }
}
