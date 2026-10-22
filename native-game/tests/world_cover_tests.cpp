// SPDX-License-Identifier: MIT
// Regression: live V4/H2 views, tasks/evidence/cpp-interface-map-review-20261020.md.
// A southern painting's final cell produced UV 1.0000001192092896 after
// float origin + extent rounding. Exercise actual SDL geometry submission.
#include "view/world_passages.hpp"
#include <SDL.h>
#include <json-c/json.h>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>

namespace ta = transartica;
namespace fs = std::filesystem;
namespace {
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
json_object* field(json_object* object, const char* key) {
    json_object* value{};
    require(json_object_object_get_ex(object, key, &value), "Missing artwork field");
    return value;
}
double number(json_object* values, int i) {
    return json_object_get_double(json_object_array_get_idx(values, i));
}
void load_paintings(ta::WorldPassages& passages, const fs::path& artwork) {
    std::unique_ptr<json_object, decltype(&json_object_put)> doc(
        json_object_from_file((artwork / "manifest.json").c_str()), json_object_put);
    require(bool(doc), "Missing artwork manifest");
    auto* scenes = field(doc.get(), "scenes");
    require(json_object_array_length(scenes) == 8, "Expected eight map regions");
    for (std::size_t i = 0; i < json_object_array_length(scenes); ++i) {
        auto* scene = json_object_array_get_idx(scenes, i);
        auto* world = field(scene, "world");
        auto* variant = json_object_array_get_idx(field(scene, "variants"), 0);
        auto* crop = field(variant, "source_crop");
        const fs::path image = json_object_get_string(field(field(variant, "background"), "image"));
        passages.add_painting(
            {float(number(world, 0)), float(number(world, 1)), float(number(world, 2)), float(number(world, 3))},
            {int(number(crop, 0)), int(number(crop, 1)), int(number(crop, 2)), int(number(crop, 3))},
            artwork / image.filename());
    }
}
}
int main(int argc, char** argv) {
    try {
        require(argc == 5, "Usage: world_cover_tests GAME FONT ARTWORK software|accelerated");
        const fs::path game = argv[1];
        SDL_SetMainReady();
        require(SDL_Init(SDL_INIT_VIDEO) == 0, SDL_GetError());
        struct Quit { ~Quit() { SDL_Quit(); } } quit;
        std::unique_ptr<SDL_Window, decltype(&SDL_DestroyWindow)> window(
            SDL_CreateWindow("Map cover regression", 0, 0, 1280, 800, SDL_WINDOW_HIDDEN), SDL_DestroyWindow);
        require(bool(window), SDL_GetError());
        const std::string mode = argv[4];
        require(mode == "software" || mode == "accelerated", "Unknown renderer");
        std::unique_ptr<SDL_Renderer, decltype(&SDL_DestroyRenderer)> renderer(
            SDL_CreateRenderer(window.get(), -1, mode == "software" ? SDL_RENDERER_SOFTWARE : SDL_RENDERER_ACCELERATED), SDL_DestroyRenderer);
        require(bool(renderer), SDL_GetError());
        ta::Canvas canvas(renderer.get(), argv[2]);
        ta::WorldPassages passages(canvas, game / "assets");
        load_paintings(passages, argv[3]);
        ta::RailNetwork network;
        std::string error;
        require(network.load(game / "data/CARTE.FIC", error), error.c_str());
        const auto original = network.tiles();
        struct Camera { const char* name; ta::Point center; double density; };
        // Reproduction saves retain these exact cameras. Other densities cover
        // zoom around the same visible underground cells without moving CARTE.
        for (const auto& c : {Camera{"V4", {40, 55}, 16}, Camera{"H2", {60, 37}, 30}}) {
            for (const double density : {c.density, 96., 180.}) {
                const ta::WorldProjection p{{640 - c.center.x * density, 298 - c.center.y * density},
                    density, {0, 0, 1280, 596}};
                passages.floor(network, p);
                passages.cover(network, p);
                passages.foreground(network, p);
                std::cout << c.name << " density=" << density << " rendered\n";
            }
        }
        require(network.tiles() == original, "Rendering changed CARTE");
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
