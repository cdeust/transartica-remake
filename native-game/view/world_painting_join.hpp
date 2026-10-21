// SPDX-License-Identifier: MIT
#pragma once
#include "world_visual.hpp"
#include "render_check.h"
#include <algorithm>
#include <cmath>
#include <optional>

namespace transartica {
// Opaque regional paintings have independently sampled grids. Reconstruct the
// interval between boundary texel centres instead of clamping both textures.
// Linear interpolation: Khronos OpenGL 4.6 core, section 8.14.2 (GL_LINEAR).
// https://registry.khronos.org/OpenGL/specs/gl/glspec46.core.pdf
// 0.5 locates texel centres; 255 is the SDL_Color RGBA8 maximum.
// SDL per-vertex alpha: https://wiki.libsdl.org/SDL2/SDL_RenderGeometry
// Measured Turin regression: native row jump13.576RGB at y250, neighbouring
// row jumps0.102/0.307. No source pixels, registration or blend width invented:
// the interval endpoints are exactly the neighbouring texel centres.
template<class Regions>
void reconstruct_horizontal_painting_joins(Canvas& canvas, const Regions& regions,
    const WorldProjection& projection, std::optional<SDL_FRect> world_clip = {}) {
    for (const auto& north : regions) for (const auto& south : regions) {
        if (double(north.world.y) + north.world.h != south.world.y) continue;
        double left = std::max(north.world.x, south.world.x);
        double right = std::min(double(north.world.x) + north.world.w,
                                double(south.world.x) + south.world.w);
        const double first = double(south.world.y) - double(north.world.h) / north.crop.h * .5;
        const double last = double(south.world.y) + double(south.world.h) / south.crop.h * .5;
        double top = first, bottom = last;
        if (world_clip) {
            left = std::max(left, double(world_clip->x));
            right = std::min(right, double(world_clip->x) + world_clip->w);
            top = std::max(top, double(world_clip->y));
            bottom = std::min(bottom, double(world_clip->y) + world_clip->h);
        }
        if (right <= left || bottom <= top) continue;
        const auto a = projection.screen({left, top}), b = projection.screen({right, bottom});
        const auto v = projection.viewport;
        if (b.x <= v.x || b.y <= v.y || a.x >= double(v.x) + v.w || a.y >= double(v.y) + v.h) continue;
        const auto row = [&](const auto& region, double source_y, Uint8 upper, Uint8 lower) {
            const auto size = canvas.image_size(region.path);
            const auto u = [&](double x) {
                return float((region.crop.x + (x - region.world.x) * region.crop.w / region.world.w) / size.x);
            };
            const float source_v = float(source_y / size.y);
            const float u0 = u(left), u1 = u(right);
            const SDL_Vertex vertices[] = {
                {{float(a.x), float(a.y)}, {255,255,255,upper}, {u0,source_v}},
                {{float(b.x), float(a.y)}, {255,255,255,upper}, {u1,source_v}},
                {{float(b.x), float(b.y)}, {255,255,255,lower}, {u1,source_v}},
                {{float(a.x), float(b.y)}, {255,255,255,lower}, {u0,source_v}}
            };
            constexpr int triangles[] = {0,1,2,0,2,3};
            // SDL2 software collapses uniform quads into RenderCopyF; a
            // constant-v source then becomes a solid rectangle (zero height).
            // Submit triangles separately so both backends sample the row.
            // Source: SDL release-2.32.10/src/render/SDL_render.c:3711-3760.
            auto* texture = canvas.texture(region.path);
            for (int triangle : {0,3})
                render_check(SDL_RenderGeometry(canvas.renderer(), texture,
                    vertices, 4, triangles + triangle, 3), "Reconstruct regional painting boundary");
        };
        row(north, north.crop.y + north.crop.h - .5, 255, 255);
        const auto alpha = [&](double y) { return Uint8(std::lround(255 * (y - first) / (last - first))); };
        row(south, south.crop.y + .5, alpha(top), alpha(bottom));
    }
}
}
