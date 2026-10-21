// SPDX-License-Identifier: MIT
#include "canvas.h"
#include <ft2build.h>
#include FT_FREETYPE_H
#include <png.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <map>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace transartica {
namespace {
using Clock = std::chrono::steady_clock;
using Counter = ResourceCounts ResourceStats::*;
std::uint64_t elapsed_ns(Clock::time_point start) {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());
}
void acquired(ResourceStats& stats, Counter counter, std::uint64_t bytes) {
    auto& item=stats.*counter;
    ++item.created; ++item.active; item.bytes_active+=bytes;
    item.peak_active=std::max(item.peak_active,item.active);
    item.bytes_peak=std::max(item.bytes_peak,item.bytes_active);
    stats.logical_bytes_active+=bytes;
    stats.logical_bytes_peak=std::max(stats.logical_bytes_peak,stats.logical_bytes_active);
}
void released(ResourceStats& stats, Counter counter, std::uint64_t bytes) {
    auto& item=stats.*counter;
    ++item.destroyed; --item.active; item.bytes_active-=bytes;
    stats.logical_bytes_active-=bytes;
}
class Lease {
    std::shared_ptr<ResourceStats> stats_;
    Counter counter_{};
    std::uint64_t bytes_{};
public:
    Lease() = default;
    Lease(std::shared_ptr<ResourceStats> stats, Counter counter, std::uint64_t bytes)
        :stats_(std::move(stats)),counter_(counter),bytes_(bytes) { acquired(*stats_,counter_,bytes_); }
    Lease(const Lease&)=delete;
    Lease& operator=(const Lease&)=delete;
    Lease(Lease&& other) noexcept=default;
    Lease& operator=(Lease&& other) noexcept {
        if(this==&other) return *this;
        if(stats_) released(*stats_,counter_,bytes_);
        stats_=std::move(other.stats_);counter_=other.counter_;bytes_=other.bytes_;
        return *this;
    }
    ~Lease() { if(stats_) released(*stats_,counter_,bytes_); }
};
struct TextureDeleter {
    std::shared_ptr<ResourceStats> stats;
    Counter counter{};
    std::uint64_t bytes{};
    void operator()(SDL_Texture* texture) const {
        SDL_DestroyTexture(texture);
        released(*stats,counter,bytes);
    }
};
using Texture=std::unique_ptr<SDL_Texture,TextureDeleter>;
Texture create_texture(SDL_Renderer* renderer,int width,int height,std::shared_ptr<ResourceStats> stats,Counter counter) {
    const auto bytes=std::uint64_t(width)*std::uint64_t(height)*4; // SDL_PIXELFORMAT_RGBA32 payload.
    auto* raw=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGBA32,SDL_TEXTUREACCESS_STATIC,width,height);
    if(raw) acquired(*stats,counter,bytes);
    return Texture(raw,TextureDeleter{std::move(stats),counter,bytes});
}
class Timer {
    std::uint64_t& duration_;
    Clock::time_point started_=Clock::now();
public:
    Timer(std::uint64_t& calls,std::uint64_t& duration):duration_(duration) {++calls;}
    ~Timer() {duration_+=elapsed_ns(started_);}
};
std::runtime_error sdl_error(const std::string& operation) {
    return std::runtime_error(operation + ": " + SDL_GetError());
}
struct Glyph {
    Texture texture{nullptr, TextureDeleter{}};
    Lease record;
    int width{}, height{}, left{}, top{}, advance{};
    std::uint64_t used_frame{};
};
struct Png {
    png_image image{};
    explicit Png(const std::filesystem::path& path) {
        image.version=PNG_IMAGE_VERSION;
        if(!png_image_begin_read_from_file(&image,path.string().c_str())) {
            const std::string error=image.message;png_image_free(&image);
            throw std::runtime_error("Cannot read image "+path.string()+": "+error);
        }
    }
    ~Png() {png_image_free(&image);}
};
struct Pixels {
    int width{},height{};
    std::vector<std::uint8_t> values;
    Lease allocation;
};
// UTF-8 decoding for the bundled font; invalid sequences become replacement glyphs.
std::vector<std::uint32_t> codepoints(std::string_view value) {
    std::vector<std::uint32_t> result;
    for (std::size_t i = 0; i < value.size();) {
        const auto lead = static_cast<unsigned char>(value[i++]);
        if (lead < 0x80) { result.push_back(lead); continue; }
        int remaining = lead >= 0xf0 ? 3 : lead >= 0xe0 ? 2 : lead >= 0xc0 ? 1 : 0;
        std::uint32_t point = remaining ? lead & ((1U << (6 - remaining)) - 1U) : 0xfffd;
        const int length = remaining;
        bool valid = remaining > 0;
        while (remaining-- > 0) {
            if (i == value.size() || (static_cast<unsigned char>(value[i]) & 0xc0) != 0x80) {
                valid = false; break;
            }
            point = (point << 6) | (static_cast<unsigned char>(value[i++]) & 0x3f);
        }
        const std::uint32_t minimum[] = {0, 0x80, 0x800, 0x10000};
        if (!valid || point < minimum[length] || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff)) point = 0xfffd;
        result.push_back(point);
    }
    return result;
}
}
struct Canvas::Impl {
    SDL_Renderer* renderer;
    std::shared_ptr<ResourceStats> stats=std::make_shared<ResourceStats>();
    ResourceStats frame_start;
    Clock::time_point frame_started{};
    bool frame_open{};
    std::optional<SDL_Point> frame_size;
    FT_Library library{};
    FT_Face face{};
    struct Asset {Texture texture;std::uint64_t used_frame{};};
    std::map<std::filesystem::path, Asset> textures;
    std::map<std::filesystem::path, Asset> rail_ballasts;
    std::map<std::filesystem::path, SDL_Point> dimensions;
    struct Alpha { int width{}, height{}; std::vector<std::uint8_t> pixels; Lease allocation; };
    std::map<std::filesystem::path, Alpha> alpha;
    using BoundsKey=std::pair<std::filesystem::path,std::array<int,4>>;
    std::map<BoundsKey,SDL_Rect> bounds;
    std::map<std::pair<int, std::uint32_t>, Glyph> glyphs;
    explicit Impl(SDL_Renderer* value) : renderer(value) {}
    ~Impl() {
        glyphs.clear(); textures.clear(); rail_ballasts.clear(); alpha.clear();
        if (face) FT_Done_Face(face);
        if (library) FT_Done_FreeType(library);
    }
    std::uint64_t usage_stamp() const {return stats->completed_frames+(frame_open?1:0);}
    void release_unused() {
        for(auto it=textures.begin();it!=textures.end();)
            if(it->second.used_frame!=stats->completed_frames) it=textures.erase(it);else ++it;
        for(auto it=rail_ballasts.begin();it!=rail_ballasts.end();)
            if(it->second.used_frame!=stats->completed_frames) it=rail_ballasts.erase(it);else ++it;
        for(auto it=glyphs.begin();it!=glyphs.end();)
            if(it->second.used_frame!=stats->completed_frames) it=glyphs.erase(it);else ++it;
        alpha.clear();
    }
    SDL_Point output_size() {
        if(frame_open&&frame_size) return *frame_size;
        ++stats->render_size_queries;SDL_Point size{};
        if(SDL_GetRendererOutputSize(renderer,&size.x,&size.y)<0) throw sdl_error("Renderer size");
        if(frame_open) frame_size=size;
        return size;
    }
    SDL_Point image_size(const std::filesystem::path& path) {
        if(const auto found=dimensions.find(path);found!=dimensions.end()) return found->second;
        Png png(path);
        if(png.image.width>std::numeric_limits<int>::max()||png.image.height>std::numeric_limits<int>::max())
            throw std::runtime_error("Image dimensions outside SDL range: "+path.string());
        const SDL_Point size{int(png.image.width),int(png.image.height)};
        dimensions.emplace(path,size);return size;
    }
    Pixels decode(const std::filesystem::path& path) {
        Timer timer(stats->timings.png_decode_calls,stats->timings.png_decode_ns);
        Png png(path);auto& image=png.image;image.format=PNG_FORMAT_RGBA;
        // Existing allocation policy: 64MiB per decoded asset under the 1GiB cap.
        if(PNG_IMAGE_SIZE(image)>64U*1024U*1024U) throw std::runtime_error("Image exceeds allocation budget: "+path.string());
        Pixels pixels;pixels.width=int(image.width);pixels.height=int(image.height);
        pixels.values.resize(PNG_IMAGE_SIZE(image));
        pixels.allocation=Lease(stats,&ResourceStats::staging_buffers,pixels.values.size());
        if(!png_image_finish_read(&image,nullptr,pixels.values.data(),0,nullptr))
            throw std::runtime_error(path.string()+": "+image.message);
        dimensions[path]={pixels.width,pixels.height};return pixels;
    }
    const Alpha& alpha_plane(const std::filesystem::path& path) {
        if(const auto found=alpha.find(path);found!=alpha.end()) return found->second;
        auto rgba=decode(path);Alpha plane;plane.width=rgba.width;plane.height=rgba.height;
        plane.pixels.resize(std::size_t(plane.width)*plane.height);
        plane.allocation=Lease(stats,&ResourceStats::alpha_planes,plane.pixels.size());
        for(std::size_t i=0;i<plane.pixels.size();++i) plane.pixels[i]=rgba.values[i*4+3];
        return alpha.emplace(path,std::move(plane)).first->second;
    }
    Glyph& glyph(int size, std::uint32_t point) {
        ++stats->glyph_requests;
        const auto key = std::make_pair(size, point);
        if (const auto it = glyphs.find(key); it != glyphs.end()) {++stats->glyph_cache_hits;it->second.used_frame=usage_stamp();return it->second;}
        {
            Timer raster(stats->timings.glyph_raster_calls,stats->timings.glyph_raster_ns);
            if (FT_Set_Pixel_Sizes(face, 0, static_cast<FT_UInt>(size)) || FT_Load_Char(face, point, FT_LOAD_RENDER))
                throw std::runtime_error("Cannot rasterize bundled font");
        }
        const auto slot = face->glyph;
        Glyph item;
        item.used_frame=usage_stamp();
        item.width = static_cast<int>(slot->bitmap.width);
        item.height = static_cast<int>(slot->bitmap.rows);
        item.left = slot->bitmap_left; item.top = slot->bitmap_top;
        item.advance = static_cast<int>(slot->advance.x / 64); // FreeType 26.6 pixel units.
        if (item.width && item.height) {
            std::vector<std::uint8_t> pixels(static_cast<std::size_t>(item.width * item.height * 4), 255);
            Lease staging(stats,&ResourceStats::staging_buffers,pixels.size());
            for (int y = 0; y < item.height; ++y)
                for (int x = 0; x < item.width; ++x)
                    pixels[static_cast<std::size_t>((y * item.width + x) * 4 + 3)] = slot->bitmap.buffer[y * slot->bitmap.pitch + x];
            {
                Timer upload(stats->timings.upload_calls,stats->timings.upload_ns);
                item.texture=create_texture(renderer,item.width,item.height,stats,&ResourceStats::glyph_textures);
                if (!item.texture || SDL_UpdateTexture(item.texture.get(), nullptr, pixels.data(), item.width * 4) < 0)
                    throw sdl_error("Font texture");
            }
            SDL_SetTextureBlendMode(item.texture.get(), SDL_BLENDMODE_BLEND);
        }
        item.record=Lease(stats,&ResourceStats::glyph_entries,0);
        return glyphs.emplace(key, std::move(item)).first->second;
    }
};
Canvas::Canvas(SDL_Renderer* renderer, const std::filesystem::path& font) : impl_(std::make_unique<Impl>(renderer)) {
    if (FT_Init_FreeType(&impl_->library) || FT_New_Face(impl_->library, font.string().c_str(), 0, &impl_->face))
        throw std::runtime_error("Cannot load font: " + font.string());
}
Canvas::~Canvas() = default;
SDL_Renderer* Canvas::renderer() const { return impl_->renderer; }
std::shared_ptr<const ResourceStats> Canvas::resource_stats() const { return impl_->stats; }
void Canvas::begin_frame() {
    if(impl_->frame_open) throw std::logic_error("Canvas frame measurement already open");
    impl_->frame_start=*impl_->stats;
    impl_->frame_started=Clock::now();
    impl_->frame_open=true;
    impl_->frame_size.reset();
    impl_->release_unused();
}
FrameResourceStats Canvas::end_frame() {
    if(!impl_->frame_open) throw std::logic_error("Canvas frame measurement was not started");
    const auto& before=impl_->frame_start;
    auto& now=*impl_->stats;
    FrameResourceStats frame;
    frame.number=++now.completed_frames;
    frame.elapsed_ns=elapsed_ns(impl_->frame_started);
    frame.asset_texture_creations=now.asset_textures.created-before.asset_textures.created;
    frame.glyph_texture_creations=now.glyph_textures.created-before.glyph_textures.created;
    frame.alpha_plane_creations=now.alpha_planes.created-before.alpha_planes.created;
    frame.texture_requests=now.texture_requests-before.texture_requests;
    frame.texture_cache_hits=now.texture_cache_hits-before.texture_cache_hits;
    frame.glyph_requests=now.glyph_requests-before.glyph_requests;
    frame.glyph_cache_hits=now.glyph_cache_hits-before.glyph_cache_hits;
    frame.measure_calls=now.measure_calls-before.measure_calls;
    frame.text_calls=now.text_calls-before.text_calls;
    frame.alpha_bounds_calls=now.alpha_bounds_calls-before.alpha_bounds_calls;
    frame.render_size_queries=now.render_size_queries-before.render_size_queries;
    frame.logical_bytes_active=now.logical_bytes_active;
    frame.timings={now.timings.png_decode_calls-before.timings.png_decode_calls,now.timings.png_decode_ns-before.timings.png_decode_ns,
        now.timings.upload_calls-before.timings.upload_calls,now.timings.upload_ns-before.timings.upload_ns,
        now.timings.glyph_raster_calls-before.timings.glyph_raster_calls,now.timings.glyph_raster_ns-before.timings.glyph_raster_ns,
        now.timings.alpha_scan_calls-before.timings.alpha_scan_calls,now.timings.alpha_scan_ns-before.timings.alpha_scan_ns};
    now.last_frame=frame;
    impl_->frame_open=false;
    return frame;
}
int Canvas::width() const {return impl_->output_size().x;}
int Canvas::height() const {return impl_->output_size().y;}
SDL_Point Canvas::image_size(const std::filesystem::path& path) {return impl_->image_size(path);}
SDL_Texture* Canvas::texture(const std::filesystem::path& path) {
    auto& stats=*impl_->stats;
    ++stats.texture_requests;
    if (const auto it = impl_->textures.find(path); it != impl_->textures.end()) {
        ++stats.texture_cache_hits;it->second.used_frame=impl_->usage_stamp();return it->second.texture.get();
    }
    auto pixels=impl_->decode(path);
    Texture texture{nullptr,TextureDeleter{}};
    {
        Timer upload(stats.timings.upload_calls,stats.timings.upload_ns);
        texture=create_texture(renderer(),pixels.width,pixels.height,impl_->stats,&ResourceStats::asset_textures);
        if (!texture || SDL_UpdateTexture(texture.get(),nullptr,pixels.values.data(),pixels.width*4)<0) throw sdl_error("Image upload " + path.string());
    }
    SDL_SetTextureBlendMode(texture.get(), SDL_BLENDMODE_BLEND);
    SDL_SetTextureScaleMode(texture.get(), SDL_ScaleModeLinear);
    Impl::Asset asset{std::move(texture),impl_->usage_stamp()};
    return impl_->textures.emplace(path,std::move(asset)).first->second.texture.get();
}
SDL_Texture* Canvas::rail_ballast_texture(const std::filesystem::path& path) {
    auto& stats=*impl_->stats;++stats.texture_requests;
    if(const auto found=impl_->rail_ballasts.find(path);found!=impl_->rail_ballasts.end()) {
        ++stats.texture_cache_hits;found->second.used_frame=impl_->usage_stamp();return found->second.texture.get();
    }
    auto source=impl_->decode(path);
    // Exact RailArt STRIP/SOURCE_CENTER/WOOD_WIDTH/SOURCE_DEPTH/GRAVEL recipe.
    constexpr SDL_Rect strip{85,100,195,200},gravel{168,130,40,14};
    constexpr int left=189-112/2-5-strip.x,right=189+112/2+5-strip.x;
    if(source.width<strip.x+strip.w||source.height<strip.y+strip.h)throw std::runtime_error("Rail strip outside authored kit");
    Pixels pixels;pixels.width=strip.w;pixels.height=strip.h;pixels.values.resize(std::size_t(strip.w)*strip.h*4);
    pixels.allocation=Lease(impl_->stats,&ResourceStats::staging_buffers,pixels.values.size());
    for(int y=0;y<strip.h;++y)for(int x=0;x<strip.w;++x) {
        const bool neutral=x>=left&&x<right;
        const int sx=neutral?gravel.x+(x-left)%gravel.w:strip.x+x,sy=neutral?gravel.y+y%gravel.h:strip.y+y;
        std::copy_n(source.values.begin()+(std::size_t(sy)*source.width+sx)*4,4,pixels.values.begin()+(std::size_t(y)*strip.w+x)*4);
    }
    Texture texture{nullptr,TextureDeleter{}};
    {Timer upload(stats.timings.upload_calls,stats.timings.upload_ns);
        texture=create_texture(renderer(),pixels.width,pixels.height,impl_->stats,&ResourceStats::asset_textures);
        if(!texture||SDL_UpdateTexture(texture.get(),nullptr,pixels.values.data(),pixels.width*4)<0)throw sdl_error("Neutral rail ballast upload");}
    SDL_SetTextureBlendMode(texture.get(),SDL_BLENDMODE_BLEND);SDL_SetTextureScaleMode(texture.get(),SDL_ScaleModeLinear);
    return impl_->rail_ballasts.emplace(path,Impl::Asset{std::move(texture),impl_->usage_stamp()}).first->second.texture.get();
}
void Canvas::text(std::string_view value, float x, float y, int size, SDL_Color color) {
    ++impl_->stats->text_calls;
    if (size <= 0) return;
    if (FT_Set_Pixel_Sizes(impl_->face, 0, static_cast<FT_UInt>(size))) throw std::runtime_error("Invalid font size");
    const float baseline = y + static_cast<float>(impl_->face->size->metrics.ascender / 64);
    for (const auto point : codepoints(value)) {
        auto& glyph = impl_->glyph(size, point);
        if (glyph.texture) {
            SDL_SetTextureColorMod(glyph.texture.get(), color.r, color.g, color.b);
            SDL_SetTextureAlphaMod(glyph.texture.get(), color.a);
            const SDL_FRect dst{x + glyph.left, baseline - glyph.top, static_cast<float>(glyph.width), static_cast<float>(glyph.height)};
            if (SDL_RenderCopyF(renderer(), glyph.texture.get(), nullptr, &dst) < 0) throw sdl_error("Text draw");
        }
        x += static_cast<float>(glyph.advance);
    }
}
SDL_FPoint Canvas::measure(std::string_view value, int size) {
    ++impl_->stats->measure_calls;
    if (size <= 0) return {0, 0};
    if (FT_Set_Pixel_Sizes(impl_->face, 0, static_cast<FT_UInt>(size))) throw std::runtime_error("Invalid font size");
    const float height = static_cast<float>((impl_->face->size->metrics.ascender - impl_->face->size->metrics.descender) / 64);
    float width = 0;
    for (const auto point : codepoints(value)) width += static_cast<float>(impl_->glyph(size, point).advance);
    return {width, height};
}
SDL_Rect Canvas::alpha_bounds(const std::filesystem::path& path, SDL_Rect crop) {
    ++impl_->stats->alpha_bounds_calls;
    const auto size=impl_->image_size(path);
    if (crop.w == 0 && crop.h == 0) crop = {0, 0,size.x,size.y};
    if (crop.x < 0 || crop.y < 0 || crop.w <= 0 || crop.h <= 0 || crop.x > size.x - crop.w || crop.y > size.y - crop.h)
        throw std::runtime_error("Invalid alpha crop: " + path.string());
    const Impl::BoundsKey key{path,{crop.x,crop.y,crop.w,crop.h}};
    if(const auto found=impl_->bounds.find(key);found!=impl_->bounds.end()) return found->second;
    const auto& alpha=impl_->alpha_plane(path);
    Timer scan(impl_->stats->timings.alpha_scan_calls,impl_->stats->timings.alpha_scan_ns);
    int left = crop.w, top = crop.h, right = -1, bottom = -1;
    for (int y = 0; y < crop.h; ++y) for (int x = 0; x < crop.w; ++x) {
        if (!alpha.pixels[static_cast<std::size_t>((crop.y + y) * alpha.width + crop.x + x)]) continue;
        left = std::min(left, x); top = std::min(top, y); right = std::max(right, x); bottom = std::max(bottom, y);
    }
    const SDL_Rect result=right < left ? SDL_Rect{} : SDL_Rect{left, top, right - left + 1, bottom - top + 1};
    impl_->bounds.emplace(key,result);return result;
}
std::vector<int> Canvas::alpha_tops(const std::filesystem::path& path,SDL_Rect crop,unsigned char threshold) {
    const auto size=impl_->image_size(path);
    if(crop.x<0||crop.y<0||crop.w<=0||crop.h<=0||crop.x>size.x-crop.w||crop.y>size.y-crop.h)
        throw std::runtime_error("Invalid alpha profile crop: "+path.string());
    const auto& alpha=impl_->alpha_plane(path);
    Timer scan(impl_->stats->timings.alpha_scan_calls,impl_->stats->timings.alpha_scan_ns);
    std::vector<int> tops(std::size_t(crop.w),crop.y+crop.h);
    for(int x=0;x<crop.w;++x) for(int y=crop.y;y<crop.y+crop.h;++y) {
        if(alpha.pixels[std::size_t(y)*alpha.width+crop.x+x]<threshold) continue;
        tops[std::size_t(x)]=y;break;
    }
    return tops;
}
void Canvas::capture(const std::filesystem::path& path) const {
    const int w = width(), h = height();
    std::vector<std::uint8_t> pixels(static_cast<std::size_t>(w * h * 4));
    Lease staging(impl_->stats,&ResourceStats::staging_buffers,pixels.size());
    if (SDL_RenderReadPixels(renderer(), nullptr, SDL_PIXELFORMAT_RGBA32, pixels.data(), w * 4) < 0) throw sdl_error("Capture frame");
    png_image image{}; image.version = PNG_IMAGE_VERSION; image.width = static_cast<png_uint_32>(w);
    image.height = static_cast<png_uint_32>(h); image.format = PNG_FORMAT_RGBA;
    if (!png_image_write_to_file(&image, path.string().c_str(), 0, pixels.data(), 0, nullptr)) {
        const std::string error = image.message; png_image_free(&image); throw std::runtime_error("Capture: " + error);
    }
    png_image_free(&image);
}
}
