// SPDX-License-Identifier: MIT
// Independent opaque-color fixture: interpolation between neighbouring texel
// centres, with nonzero source crops and unequal source sampling densities.
#include "view/world_painting_join.hpp"
#include <png.h>
#include <array>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <vector>

namespace fs=std::filesystem;
namespace ta=transartica;
namespace {
constexpr int width=128,height=128;
using Pixels=std::vector<unsigned char>;
struct Region {SDL_FRect world;SDL_Rect crop;fs::path path;};
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
void fixture(const Region& region,std::array<unsigned char,3> color){
    const int w=region.crop.w+4,h=region.crop.h+4;Pixels data(w*h*4);
    for(int y=0;y<h;++y)for(int x=0;x<w;++x){
        bool inside=x>=region.crop.x&&x<region.crop.x+region.crop.w&&y>=region.crop.y&&y<region.crop.y+region.crop.h;
        auto c=inside?color:std::array<unsigned char,3>{255,0,255};
        for(int k=0;k<3;++k)data[(y*w+x)*4+k]=c[k];data[(y*w+x)*4+3]=255;
    }
    png_image image{};image.version=PNG_IMAGE_VERSION;image.width=w;image.height=h;image.format=PNG_FORMAT_RGBA;
    require(png_image_write_to_file(&image,region.path.string().c_str(),0,data.data(),0,nullptr)!=0,"fixture PNG write");
}
Pixels frame(ta::Canvas& canvas,const std::vector<Region>& regions,bool repair,std::optional<SDL_FRect> clip={}){
    auto* renderer=canvas.renderer();canvas.begin_frame();
    SDL_SetRenderDrawColor(renderer,7,11,13,255);ta::render_check(SDL_RenderClear(renderer),"fixture clear");
    const ta::WorldProjection projection{{16,16},24,{0,0,width,height}};
    for(const auto& r:regions){auto p=projection.screen({r.world.x,r.world.y});SDL_FRect dst{float(p.x),float(p.y),r.world.w*24,r.world.h*24};
        ta::render_check(SDL_RenderCopyF(renderer,canvas.texture(r.path),&r.crop,&dst),"fixture painting");}
    if(repair)ta::reconstruct_horizontal_painting_joins(canvas,regions,projection,clip);
    Pixels pixels(width*height*4);ta::render_check(SDL_RenderReadPixels(renderer,nullptr,SDL_PIXELFORMAT_RGBA32,pixels.data(),width*4),"fixture read");
    canvas.end_frame();SDL_RenderPresent(renderer);return pixels;
}
void outside_exact(const Pixels& baseline,const Pixels& repaired,int left,int top,int right,int bottom){
    for(int y=0;y<height;++y)for(int x=0;x<width;++x){
        if(x>=left&&x<right&&y>=top&&y<bottom)continue;
        for(int c=0;c<4;++c)require(baseline[(y*width+x)*4+c]==repaired[(y*width+x)*4+c],"pixel outside repair footprint changed");
    }
}
void ramp(const Pixels& pixels,int left,int top,int right,int bottom){
    // Region N last row centre: 16+24*(2-2/(2*4))=58.
    // Region S first row centre:16+24*(2+2/(2*6))=68.
    constexpr std::array<int,3> north{30,60,90},south{210,180,150};
    for(int y=top;y<bottom;++y)for(int x=left;x<right;++x)for(int c=0;c<3;++c){
        const double t=(y+.5-58)/10;const double expected=north[c]*(1-t)+south[c]*t;
        // RGBA8 vertex-alpha quantization and final blend rounding each cost
        // at most one channel unit; no geometric or image-error allowance.
        if(std::abs(pixels[(y*width+x)*4+c]-expected)>2){
            std::cerr<<"ramp mismatch x="<<x<<" y="<<y<<" c="<<c<<" actual="<<int(pixels[(y*width+x)*4+c])<<" expected="<<expected<<'\n';
            throw std::runtime_error("boundary centre interpolation differs");
        }
    }
}
int run(int argc,char** argv){
    require(argc==4,"usage: world_painting_join_tests FONT EXISTING_SCRATCH software|accelerated");
    fs::path scratch=argv[2];require(fs::is_directory(scratch),"scratch directory must exist");
    const std::string backend=argv[3];require(backend=="software"||backend=="accelerated","explicit renderer required");
    SDL_SetMainReady();require(SDL_Init(SDL_INIT_VIDEO)==0,SDL_GetError());struct Quit{~Quit(){SDL_Quit();}} quit;
    std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(SDL_CreateWindow("Join regression",0,0,width,height,SDL_WINDOW_HIDDEN),SDL_DestroyWindow);
    require(bool(window),SDL_GetError());
    std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(SDL_CreateRenderer(window.get(),-1,backend=="software"?SDL_RENDERER_SOFTWARE:SDL_RENDERER_ACCELERATED),SDL_DestroyRenderer);
    require(bool(renderer),SDL_GetError());ta::Canvas canvas(renderer.get(),argv[1]);
    std::vector<Region> regions{{{0,0,4,2},{2,2,4,4},scratch/"join-north.png"},{{0,2,4,2},{2,2,6,6},scratch/"join-south.png"}};
    for(const auto& r:regions)require(!fs::exists(r.path),"preserve existing fixture file");
    // Only these newly created fixture files belong to this test invocation.
    struct Cleanup {std::vector<fs::path> paths;~Cleanup(){for(const auto& p:paths){std::error_code ec;fs::remove(p,ec);}}};
    Cleanup cleanup{{regions[0].path,regions[1].path}};
    fixture(regions[0],{30,60,90});fixture(regions[1],{210,180,150});
    const auto baseline=frame(canvas,regions,false),repaired=frame(canvas,regions,true);
    outside_exact(baseline,repaired,16,58,112,68);ramp(repaired,32,58,96,68);
    require(baseline!=repaired,"regression fixture must exercise repair");
    // Integer screen rectangle [40,61,88,66] truncates the band while retaining
    // its original ramp endpoints, as an underground cover cell must do.
    const SDL_FRect clip{1,45.0f/24,2,5.0f/24};const auto clipped=frame(canvas,regions,true,clip);
    outside_exact(baseline,clipped,40,61,88,66);ramp(clipped,42,62,86,65);
    regions[1].world.y=3;require(frame(canvas,regions,false)==frame(canvas,regions,true),"nonadjacent regions must remain unchanged");
    std::cout<<"PASS: boundary ramp, nonzero crops, unequal grids, outside exact, cover clipping, nonadjacent regions ("<<backend<<")\n";return 0;
}
}
int main(int argc,char** argv){try{return run(argc,argv);}catch(const std::exception& e){std::cerr<<"PAINTING JOIN FAILED: "<<e.what()<<'\n';return 1;}}
