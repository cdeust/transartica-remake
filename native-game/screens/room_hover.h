// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "platform/canvas.h"
#include <filesystem>
#include <memory>

namespace transartica::panels {
enum class HighlightKind { MatteRed, CutoutAlpha, StokerOutline };
// CPU translation of object_hover.gdshader / stoker_hover.gdshader. Keeps one
// source coverage plane and the currently displayed contour, never all masks.
class ObjectHighlight {
public:
    ObjectHighlight();
    ~ObjectHighlight();
    ObjectHighlight(const ObjectHighlight&)=delete;
    ObjectHighlight& operator=(const ObjectHighlight&)=delete;
    void draw(Canvas&,const std::filesystem::path&,SDL_FRect destination,HighlightKind,
              SDL_Rect crop={},SDL_FRect normalized_clip={0,0,1,1});
    bool red_pixel(const std::filesystem::path&,Point normalized) const;
    void clear();
    std::size_t resident_bytes() const;
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

class RoomHover {
public:
    enum class Room { Boudoir, Quarters };
    explicit RoomHover(std::filesystem::path assets);
    void draw(Canvas&,Room,SDL_FRect room,Point pointer,bool active=true);
    void clear();
    std::size_t resident_bytes() const { return highlight_.resident_bytes(); }
private:
    std::filesystem::path assets_;
    ObjectHighlight highlight_;
};
}
