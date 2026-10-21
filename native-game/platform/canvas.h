// SPDX-License-Identifier: MIT
#pragma once
#include <SDL.h>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <string_view>
#include <vector>

namespace transartica {
struct ResourceCounts {
    std::uint64_t created{}, destroyed{}, active{}, peak_active{};
    std::uint64_t bytes_active{}, bytes_peak{};
};
struct ResourceTimings {
    std::uint64_t png_decode_calls{}, png_decode_ns{};
    std::uint64_t upload_calls{}, upload_ns{};
    std::uint64_t glyph_raster_calls{}, glyph_raster_ns{};
    std::uint64_t alpha_scan_calls{}, alpha_scan_ns{};
};
struct FrameResourceStats {
    std::uint64_t number{}, elapsed_ns{};
    std::uint64_t asset_texture_creations{}, glyph_texture_creations{}, alpha_plane_creations{};
    std::uint64_t texture_requests{}, texture_cache_hits{}, glyph_requests{}, glyph_cache_hits{};
    std::uint64_t measure_calls{}, text_calls{}, alpha_bounds_calls{}, render_size_queries{};
    std::uint64_t logical_bytes_active{};
    ResourceTimings timings;
};
// Single renderer thread only. GPU bytes are requested RGBA storage, not driver
// allocation or process RSS. CPU bytes count payloads, not allocator overhead.
// Counters include failed operations whose resources were created then released.
struct ResourceStats {
    ResourceCounts asset_textures, glyph_textures, glyph_entries, alpha_planes, staging_buffers;
    std::uint64_t logical_bytes_active{}, logical_bytes_peak{};
    std::uint64_t texture_requests{}, texture_cache_hits{}, glyph_requests{}, glyph_cache_hits{};
    std::uint64_t measure_calls{}, text_calls{}, alpha_bounds_calls{}, render_size_queries{};
    ResourceTimings timings;
    std::uint64_t completed_frames{};
    FrameResourceStats last_frame;
};
// Owns decoded texture/font caches; the SDL renderer outlives this object.
class Canvas {
public:
    Canvas(SDL_Renderer*, const std::filesystem::path& font);
    ~Canvas();
    Canvas(const Canvas&) = delete;
    Canvas& operator=(const Canvas&) = delete;
    SDL_Renderer* renderer() const;
    SDL_Texture* texture(const std::filesystem::path&);
    // rail_art.gd::neutral_ballast: one195x200 derived crop, same frame cache
    // lifetime/resource accounting as an ordinary asset; source PNG unchanged.
    SDL_Texture* rail_ballast_texture(const std::filesystem::path&);
    // PNG header inspection only; does not decode or upload a texture.
    SDL_Point image_size(const std::filesystem::path&);
    void text(std::string_view, float x, float y, int size, SDL_Color);
    SDL_FPoint measure(std::string_view, int size);
    SDL_Rect alpha_bounds(const std::filesystem::path&, SDL_Rect crop = {});
    // tactical_effects_geometry.gd::_profile alpha>=0.5: RGBA8 alpha>=128.
    // Absolute top y per crop column, or crop.y+crop.h for transparent columns.
    std::vector<int> alpha_tops(const std::filesystem::path&,SDL_Rect crop,unsigned char threshold=128);
    // This read-only handle survives Canvas destruction, exposing final releases.
    std::shared_ptr<const ResourceStats> resource_stats() const;
    // Call begin_frame after the preceding SDL_RenderPresent. It releases assets
    // and glyphs unused in that preceding frame, and transient CPU alpha planes.
    // Returned texture pointers remain valid through end_frame and presentation.
    // Calls must pair; drawing without frame boundaries retains its caches.
    void begin_frame();
    FrameResourceStats end_frame();
    int width() const;
    int height() const;
    void capture(const std::filesystem::path&) const;
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
}
