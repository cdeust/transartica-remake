// SPDX-License-Identifier: MIT
#pragma once
// Source session_saves.gd::_validate_chart/restore_chart. No SDL dependency:
// archive parsing can normalize a detached presentation state before commit.
#include "core/session.hpp"
#include <algorithm>
#include <cmath>
#include <cstddef>
namespace transartica {
struct WorldState {
    bool ready{}; // Native first-map calibration, equivalent to the host's map-open state.
    Point camera{12.5,62.5}; // travel_world.gd initial camera_world.
    double zoom=1; // world_view.gd initial zoom.
    Point offset;
    bool following{},inspecting{};
    int selected_city=-1;
    bool operator==(const WorldState&)const=default;
};
inline bool normalize_world_state(WorldState& value,std::size_t city_count){
    // Source _number accepts any finite coordinate: panning is not bounded by CARTE.
    if(!std::isfinite(value.camera.x)||!std::isfinite(value.camera.y)||!std::isfinite(value.offset.x)||!std::isfinite(value.offset.y)||!std::isfinite(value.zoom))return false;
    auto next=value;
    next.zoom=std::clamp(next.zoom,.001,2.); // travel_world.gd TRAVEL_MIN_ZOOM/MAX_ZOOM.
    const double pixels=std::hypot(180.,100.)*next.zoom; // travel_world.gd CELL_PIXELS.
    // The native zero-offset representation must also remain finite. Check
    // this before archive commit; restore_world must never introduce a late failure.
    if(!std::isfinite(next.camera.x-next.offset.x/pixels)||!std::isfinite(next.camera.y-next.offset.y/pixels))return false;
    if(next.selected_city<0||std::size_t(next.selected_city)>=city_count)next.selected_city=-1;
    value=next;return true;
}
}
