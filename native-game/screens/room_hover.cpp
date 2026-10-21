// SPDX-License-Identifier: MIT
// Sources: object_hover.gdshader, stoker_hover.gdshader, wagon_hover.gd,
// boudoir_screen.gd and general_quarters.gd. No silhouette approximation.
#include "room_hover.h"
#include "view/render_check.h"
#include <png.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <utility>
#include <vector>

namespace transartica::panels {
namespace {
struct TextureDeleter { void operator()(SDL_Texture* p) const { if(p) SDL_DestroyTexture(p); } };
using Texture=std::unique_ptr<SDL_Texture,TextureDeleter>;
struct Coverage { int width{},height{};std::vector<unsigned char> bytes; };
Coverage read_coverage(const std::filesystem::path& path,bool alpha) {
    png_image image{};image.version=PNG_IMAGE_VERSION;
    struct Guard {png_image& image;~Guard(){png_image_free(&image);}} guard{image};
    if(!png_image_begin_read_from_file(&image,path.string().c_str()))
        throw std::runtime_error("Cannot read selection matte: "+path.string()+": "+image.message);
    image.format=PNG_FORMAT_RGBA;
    // Same existing per-asset allocation policy as platform/canvas.cpp.
    if(!image.width||!image.height||image.width>unsigned(std::numeric_limits<int>::max()/4)
       ||image.height>unsigned(std::numeric_limits<int>::max())||PNG_IMAGE_SIZE(image)>64U*1024U*1024U)
        throw std::runtime_error("Selection matte exceeds image budget: "+path.string());
    std::vector<unsigned char> rgba(PNG_IMAGE_SIZE(image));
    if(!png_image_finish_read(&image,nullptr,rgba.data(),0,nullptr))
        throw std::runtime_error("Cannot decode selection matte: "+path.string()+": "+image.message);
    Coverage result{int(image.width),int(image.height),{}};
    result.bytes.resize(std::size_t(result.width)*result.height);
    const std::size_t channel=alpha?3:0;
    for(std::size_t i=0;i<result.bytes.size();++i) result.bytes[i]=rgba[i*4+channel];
    return result;
}
bool contains(SDL_FRect r,Point p) {
    return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;
}
// RGBA8 conversion of the exact shader's normalized color/coverage output.
unsigned char byte(double value) { return static_cast<unsigned char>(std::lround(std::clamp(value,0.,255.))); }
SDL_Rect normalized_crop(SDL_Rect crop,const Coverage& image) {
    if(crop.w==0&&crop.h==0) return {0,0,image.width,image.height};
    if(crop.x<0||crop.y<0||crop.w<=0||crop.h<=0||crop.x>image.width-crop.w||crop.y>image.height-crop.h)
        throw std::runtime_error("Selection crop outside matte");
    return crop;
}
unsigned char surround(const Coverage& image,SDL_Rect crop,int x,int y,HighlightKind kind) {
    unsigned char result=0;
    const int stride=kind==HighlightKind::StokerOutline?2:1;
    for(int dy=-1;dy<=1;++dy) for(int dx=-1;dx<=1;++dx) {
        int sx=x+dx*stride,sy=y+dy*stride;
        if(kind==HighlightKind::StokerOutline) {
            if(sx<crop.x||sy<crop.y||sx>=crop.x+crop.w||sy>=crop.y+crop.h) continue;
        } else {
            sx=std::clamp(sx,0,image.width-1);sy=std::clamp(sy,0,image.height-1);
        }
        result=std::max(result,image.bytes[std::size_t(sy)*image.width+sx]);
    }
    return result;
}
std::vector<unsigned char> contour(const Coverage& image,SDL_Rect crop,HighlightKind kind) {
    std::vector<unsigned char> result(std::size_t(crop.w)*crop.h*4);
    for(int y=0;y<crop.h;++y) for(int x=0;x<crop.w;++x) {
        const int sx=crop.x+x,sy=crop.y+y;
        const auto center=image.bytes[std::size_t(sy)*image.width+sx];
        const int edge=std::max(0,int(surround(image,crop,sx,sy,kind))-center);
        const std::size_t at=(std::size_t(y)*crop.w+x)*4;
        result[at]=255;
        // Source: game/shaders/stoker_hover.gdshader highlight_color and
        // game/shaders/object_hover.gdshader COLOR, not a replacement palette.
        result[at+1]=byte(255*(kind==HighlightKind::StokerOutline?.76:.81));
        result[at+2]=byte(255*(kind==HighlightKind::StokerOutline?.34:.49));
        // Stoker outline is drawn BEFORE the unchanged base sprite. Source-over
        // then gives the shader's alpha = base.a + edge*(1-base.a) exactly.
        result[at+3]=byte(kind==HighlightKind::StokerOutline?edge*.82:edge*.72+center*.07);
    }
    return result;
}
void draw_clip(Canvas& canvas,SDL_Texture* texture,SDL_FRect destination,SDL_FRect uv) {
    const SDL_FRect box{destination.x+uv.x*destination.w,destination.y+uv.y*destination.h,
        uv.w*destination.w,uv.h*destination.h};
    constexpr SDL_Color white{255,255,255,255};
    const SDL_Vertex vertices[]{{{box.x,box.y},white,{uv.x,uv.y}},
        {{box.x+box.w,box.y},white,{uv.x+uv.w,uv.y}},
        {{box.x+box.w,box.y+box.h},white,{uv.x+uv.w,uv.y+uv.h}},
        {{box.x,box.y+box.h},white,{uv.x,uv.y+uv.h}}};
    constexpr int indices[]{0,1,2,0,2,3};
    render_check(SDL_RenderGeometry(canvas.renderer(),texture,vertices,4,indices,6),"Selection contour");
}
}
struct ObjectHighlight::Impl {
    std::filesystem::path path;
    Coverage source;
    HighlightKind kind=HighlightKind::MatteRed;
    SDL_Rect crop{};
    Texture texture;
    void load(const std::filesystem::path& next,HighlightKind mode) {
        if(path==next&&kind==mode&&!source.bytes.empty()) return;
        auto staged=read_coverage(next,mode!=HighlightKind::MatteRed);
        // Only called before this helper submits its new frame's draw. The
        // previous frame's texture has already passed SDL_RenderPresent.
        texture.reset();source=std::move(staged);path=next;kind=mode;crop={};
    }
    void prepare(Canvas& canvas,SDL_Rect next) {
        if(texture&&crop.x==next.x&&crop.y==next.y&&crop.w==next.w&&crop.h==next.h) return;
        auto rgba=contour(source,next,kind);
        Texture staged(SDL_CreateTexture(canvas.renderer(),SDL_PIXELFORMAT_RGBA32,SDL_TEXTUREACCESS_STATIC,next.w,next.h));
        if(!staged) throw std::runtime_error(SDL_GetError());
        render_check(SDL_UpdateTexture(staged.get(),nullptr,rgba.data(),next.w*4),"Upload selection contour");
        render_check(SDL_SetTextureBlendMode(staged.get(),SDL_BLENDMODE_BLEND),"Selection blending");
        render_check(SDL_SetTextureScaleMode(staged.get(),SDL_ScaleModeNearest),"Selection sampling");
        texture=std::move(staged);crop=next;
    }
};
ObjectHighlight::ObjectHighlight():impl_(std::make_unique<Impl>()){}
ObjectHighlight::~ObjectHighlight()=default;
void ObjectHighlight::draw(Canvas& canvas,const std::filesystem::path& path,SDL_FRect destination,
                           HighlightKind kind,SDL_Rect crop,SDL_FRect clip) {
    impl_->load(path,kind);impl_->prepare(canvas,normalized_crop(crop,impl_->source));
    draw_clip(canvas,impl_->texture.get(),destination,clip);
}
bool ObjectHighlight::red_pixel(const std::filesystem::path& path,Point uv) const {
    if(!std::isfinite(uv.x)||!std::isfinite(uv.y)||uv.x<0||uv.y<0||uv.x>=1||uv.y>=1) return false;
    impl_->load(path,HighlightKind::MatteRed);
    const auto& s=impl_->source;const int x=int(uv.x*s.width),y=int(uv.y*s.height);
    return s.bytes[std::size_t(y)*s.width+x]>127; // engine_room_art.gd r>0.5.
}
void ObjectHighlight::clear() { impl_=std::make_unique<Impl>(); }
std::size_t ObjectHighlight::resident_bytes() const {
    return impl_->source.bytes.size()+(impl_->texture?std::size_t(impl_->crop.w)*impl_->crop.h*4:0);
}
RoomHover::RoomHover(std::filesystem::path assets):assets_(std::move(assets)){}
void RoomHover::clear() {highlight_.clear();}
void RoomHover::draw(Canvas& canvas,Room room,SDL_FRect bounds,Point pointer,bool active) {
    if(!active||bounds.w<=0||bounds.h<=0||!contains(bounds,pointer)) {highlight_.clear();return;}
    const Point p{(pointer.x-bounds.x)/bounds.w,(pointer.y-bounds.y)/bounds.h};
    struct Hotspot {SDL_FRect box;const char* name;};
    constexpr std::array<Hotspot,4> boudoir{{{{.03f,.77f,.075f,.17f},"boudoir-stoup.png"},
        {{.10f,.32f,.28f,.66f},"boudoir-kolotov.png"},{{.455f,.79f,.10f,.15f},"boudoir-revolver.png"},
        {{.57f,.74f,.30f,.24f},"boudoir-book.png"}}};
    constexpr std::array<Hotspot,4> quarters{{{{0,.74f,.085f,.24f},"quarters-stoup.png"},
        {{.08f,.44f,.13f,.49f},"quarters-operator.png"},{{.80f,.20f,.20f,.80f},"quarters-officer.png"},
        {{.36f,.4f,.44f,.6f},"quarters-map.png"}}};
    const auto& spots=room==Room::Boudoir?boudoir:quarters;
    for(const auto& spot:spots) if(contains(spot.box,p)) {
        highlight_.draw(canvas,assets_/"boudoir/cutouts"/spot.name,bounds,HighlightKind::CutoutAlpha);
        return;
    }
    highlight_.clear();
}
}
