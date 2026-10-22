// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "platform/canvas.h"
#include "world_motion.hpp"
#include "world_visual.hpp"
#include "world_passages.hpp"
#include "world_state.hpp"
#include "cabin_effects.h"
#include "screens/room_hover.h"
#include "input/key_bindings.h"
#include <SDL.h>
#include <filesystem>
#include <map>
#include <optional>
#include <string_view>

namespace transartica {
enum class Action { None, Start, Load, Lignite, Anthracite, Regulator, Pause, Map, Brake, Unavailable,
    Engine, Instruments, Overview, DetailedMap, Quarters, Boudoir, Launcher, Reverse, Clock, PreviousWagon, NextWagon,
    Music, Difficulty, Combat };
struct WorldInput {std::optional<Cell> clicked;bool consumed{};int picked_city=-1;};

class View {
public:
    View(Canvas&, std::filesystem::path assets, std::filesystem::path artwork);
    void reception(std::string_view notice = {});
    void cabin(const Session&, double visual_seconds, std::string_view notice = {});
    void set_bindings(const input::KeyBindings* bindings) { bindings_=bindings; }
    void set_pointer(Point,bool active);
    void advance_cabin(double seconds,const Session&,bool paused);
    void reset_cabin();
    void world(const Session&, std::string_view notice = {},const world::EnemyState* enemies=nullptr,const economy::WorldData* cities=nullptr);
    void advance_world(const Session&,double seconds,bool visible,bool paused=false);
    void reset_world();
    WorldState snapshot_world()const;
    bool restore_world(const WorldState&,const Session&,std::size_t city_count);
    WorldInput handle_world(const SDL_Event&,const economy::WorldData&,const RailNetwork* network=nullptr);
    void focus_city(int,const economy::WorldData&);
    void inspect_world(Cell); // Overview message3: fixed inspected cell, no train-follow.
    void center_on_train(const Session&); // Return from inspection, fixed scale/convoy framing.
    void follow_train(const Session&); // Explicit source Follow control: nose at72%/65%.
    int selected_city()const{return selected_city_;}
    void footer(const Session&, bool map_context, bool overview_context = false);
    Action reception_action(float x, float y) const;
    Action cabin_action(float x, float y) const;
    Action footer_action(float x, float y, bool map_context) const;
    bool in_footer(float x, float y) const;
    void scroll_composition(int direction, const Session&);
    int regulator_at(float x, float y) const;
    std::optional<Cell> world_cell(float x, float y) const;
    void reset_camera();
    void launcher_map(const Session&,Cell camera,Point glide);
    void launcher_target(Cell cell,int heading,Cell camera,Point glide);
private:
    struct Region { SDL_FRect world; SDL_Rect crop; std::filesystem::path path; };
    struct Frame { SDL_Rect crop; Point front, rear; SDL_FRect draw; std::filesystem::path path; SDL_FRect bounds; };
    struct Pose { const Frame* frame; Point front,rear,rail_midpoint;SDL_Color tint{255,255,255,255};int heading{}; };
    Canvas& canvas_;
    std::filesystem::path assets_, artwork_;
    WorldVisual world_visual_;
    WorldPassages world_passages_;
    WorldMotion world_motion_;
    CabinEffects cabin_effects_;
    panels::ObjectHighlight cabin_stoker_,cabin_engineer_,cabin_interface_;
    const input::KeyBindings* bindings_{};
    Point cabin_pointer_{};
    bool cabin_pointer_active_{};
    std::vector<Region> regions_;
    std::vector<SDL_FRect> painted_world_;
    std::map<std::string, Frame> frames_;
    double texels_per_cell_{};
    bool camera_ready_{};
    Point camera_{};
    double cell_pixels_{};
    bool following_train_{},inspecting_map_{},world_left_{},world_dragging_{};
    Point world_press_,world_pointer_,camera_visual_;
    std::int64_t camera_cycle_=-1;
    SDL_FPoint camera_extent_{};
    int selected_city_=-1;
    std::size_t first_wagon_{};
    SDL_FRect fit(float w, float h) const;
    SDL_FRect world_rect() const;
    Point logical(float x, float y, float w, float h) const;
    Point screen(Point) const;
    Point world_point(Point)const;
    void zoom_world(double,Point);
    int city_at(Point,const economy::WorldData&)const;
    void load_artwork();
    void load_vehicles();
    std::vector<Pose> poses(const Session&) const;
    SDL_FRect train_bounds(const std::vector<Pose>&) const;
    void update_camera(const Session&, const std::vector<Pose>&);
    void draw_vehicle(const Pose&,const RailNetwork&);
    void draw_frame_at(const Frame&, Point center, double angle, double scale, SDL_Color tint);
    void panel(std::string_view, float y);
    std::string key_label(input::Command) const;
    void cabin_background(const Session&,double,SDL_FRect);
    void cabin_stokers(const Session&,double,SDL_FRect);
    void cabin_controls(const Session&,SDL_FRect);
    void cabin_needles(const Session&,SDL_FRect);
    void cabin_status(const Session&,std::string_view,SDL_FRect);
};
}
