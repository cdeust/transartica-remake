// SPDX-License-Identifier: MIT
#pragma once
#include <SDL.h>
#include <stdexcept>
#include <string>

namespace transartica {
// SDL rendering calls return -1 on error; do not silently present an empty frame.
// Source: SDL2 SDL_RenderCopyF / SDL_RenderGeometry API return-value contracts.
inline void render_check(int result, const char* operation) {
    if (result < 0) throw std::runtime_error(std::string(operation) + ": " + SDL_GetError());
}
}
