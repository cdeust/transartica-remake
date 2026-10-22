// SPDX-License-Identifier: MIT
// Resource baseline for the actual SDL view. This is a fixed render workload,
// not a campaign, frame-rate comparison with Godot, or a gameplay acceptance test.
#include "core/session.hpp"
#include "platform/canvas.h"
#include "view/view.h"
#include <SDL.h>
#include <json-c/json.h>
#include <openssl/evp.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace ta=transartica;
namespace fs=std::filesystem;
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
using Clock=std::chrono::steady_clock;
struct Options {
    fs::path game,artwork,font,output;
    std::string renderer,label;
    int frames{};
    // Source: app/main.cpp native default, four times the original 320x200 canvas.
    int width=1280,height=800;
};
int positive(const std::string& value) {
    std::size_t consumed{};
    const int result=std::stoi(value,&consumed);
    if(consumed!=value.size() || result<=0) throw std::runtime_error("Expected a positive integer: "+value);
    return result;
}
Options options(int argc,char** argv) {
    Options result;
    for(int i=1;i<argc;++i) {
        const std::string flag=argv[i];
        if(flag=="--help") {
            std::cout<<"render_resources --game-dir PATH --font PATH --output-dir EXISTING_DIR --renderer software|accelerated --frames N --label NAME [--artwork-dir PATH] [--width N --height N]\n";
            std::exit(0);
        }
        if(++i==argc) throw std::runtime_error("Missing value for "+flag);
        const std::string value=argv[i];
        if(flag=="--game-dir") result.game=value;
        else if(flag=="--font") result.font=value;
        else if(flag=="--artwork-dir") result.artwork=value;
        else if(flag=="--output-dir") result.output=value;
        else if(flag=="--renderer") result.renderer=value;
        else if(flag=="--frames") result.frames=positive(value);
        else if(flag=="--width") result.width=positive(value);
        else if(flag=="--height") result.height=positive(value);
        else if(flag=="--label") result.label=value;
        else throw std::runtime_error("Unknown option "+flag);
    }
    if(result.game.empty() || result.font.empty() || result.label.empty() || result.frames<2 || !fs::is_directory(result.output))
        throw std::runtime_error("Require game/font/label, an existing output directory, and at least two frames for cold/warm comparison");
    if(result.label.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")!=std::string::npos)
        throw std::runtime_error("Label must contain only ASCII letters, digits, hyphens or underscores");
    if(result.renderer!="software" && result.renderer!="accelerated") throw std::runtime_error("Select software or accelerated renderer explicitly");
    if(result.artwork.empty()) result.artwork=result.game/"assets/travel/artwork/world-hd";
    return result;
}
void require_sdl(int code,const char* operation) {
    if(code<0) throw std::runtime_error(std::string(operation)+": "+SDL_GetError());
}
void field(json_object* object,const char* name,std::uint64_t value) {json_object_object_add(object,name,json_object_new_uint64(value));}
void field(json_object* object,const char* name,const std::string& value) {json_object_object_add(object,name,json_object_new_string(value.c_str()));}
json_object* counts(const ta::ResourceCounts& value) {
    auto* object=json_object_new_object();
    field(object,"created",value.created);field(object,"destroyed",value.destroyed);
    field(object,"active",value.active);field(object,"peak_active",value.peak_active);
    field(object,"bytes_active",value.bytes_active);field(object,"bytes_peak",value.bytes_peak);
    return object;
}
json_object* timings(const ta::ResourceTimings& value) {
    auto* object=json_object_new_object();
    field(object,"png_decode_calls",value.png_decode_calls);field(object,"png_decode_ns",value.png_decode_ns);
    field(object,"upload_calls",value.upload_calls);field(object,"upload_ns",value.upload_ns);
    field(object,"glyph_raster_calls",value.glyph_raster_calls);field(object,"glyph_raster_ns",value.glyph_raster_ns);
    field(object,"alpha_scan_calls",value.alpha_scan_calls);field(object,"alpha_scan_ns",value.alpha_scan_ns);
    return object;
}
json_object* stats(const ta::ResourceStats& value) {
    auto* object=json_object_new_object();
    json_object_object_add(object,"asset_textures",counts(value.asset_textures));
    json_object_object_add(object,"glyph_textures",counts(value.glyph_textures));
    json_object_object_add(object,"glyph_entries",counts(value.glyph_entries));
    json_object_object_add(object,"alpha_planes",counts(value.alpha_planes));
    json_object_object_add(object,"staging_buffers",counts(value.staging_buffers));
    field(object,"logical_bytes_active",value.logical_bytes_active);field(object,"logical_bytes_peak",value.logical_bytes_peak);
    field(object,"texture_requests",value.texture_requests);field(object,"texture_cache_hits",value.texture_cache_hits);
    field(object,"glyph_requests",value.glyph_requests);field(object,"glyph_cache_hits",value.glyph_cache_hits);
    field(object,"measure_calls",value.measure_calls);field(object,"text_calls",value.text_calls);
    field(object,"alpha_bounds_calls",value.alpha_bounds_calls);field(object,"render_size_queries",value.render_size_queries);
    field(object,"completed_frames",value.completed_frames);
    json_object_object_add(object,"timings",timings(value.timings));
    return object;
}
json_object* frame(const ta::FrameResourceStats& value) {
    auto* object=json_object_new_object();
    field(object,"number",value.number);field(object,"elapsed_ns",value.elapsed_ns);
    field(object,"asset_texture_creations",value.asset_texture_creations);field(object,"glyph_texture_creations",value.glyph_texture_creations);
    field(object,"alpha_plane_creations",value.alpha_plane_creations);
    field(object,"texture_requests",value.texture_requests);field(object,"texture_cache_hits",value.texture_cache_hits);
    field(object,"glyph_requests",value.glyph_requests);field(object,"glyph_cache_hits",value.glyph_cache_hits);
    field(object,"measure_calls",value.measure_calls);field(object,"text_calls",value.text_calls);
    field(object,"alpha_bounds_calls",value.alpha_bounds_calls);field(object,"render_size_queries",value.render_size_queries);
    field(object,"logical_bytes_active",value.logical_bytes_active);
    json_object_object_add(object,"timings",timings(value.timings));
    return object;
}
class Digest {
    std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> context_{EVP_MD_CTX_new(),EVP_MD_CTX_free};
public:
    Digest() {if(!context_ || EVP_DigestInit_ex(context_.get(),EVP_sha256(),nullptr)!=1) throw std::runtime_error("SHA-256 initialization failed");}
    void update(const void* data,std::size_t size) {
        if(EVP_DigestUpdate(context_.get(),data,size)!=1) throw std::runtime_error("SHA-256 update failed");
    }
    std::string finish() {
        std::array<unsigned char,EVP_MAX_MD_SIZE> result{};
        unsigned length{};
        if(EVP_DigestFinal_ex(context_.get(),result.data(),&length)!=1) throw std::runtime_error("SHA-256 finish failed");
        std::ostringstream text;
        for(unsigned i=0;i<length;++i) text<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(result[i]);
        return text.str();
    }
};
std::string file_hash(const fs::path& path) {
    std::ifstream input(path,std::ios::binary);
    if(!input) throw std::runtime_error("Cannot hash "+path.string());
    Digest digest;
    std::array<char,8192> buffer{}; // Streaming I/O chunk only; does not enter rendering.
    while(input) {input.read(buffer.data(),buffer.size());digest.update(buffer.data(),static_cast<std::size_t>(input.gcount()));}
    if(!input.eof()) throw std::runtime_error("Hash read failed: "+path.string());
    return digest.finish();
}
std::string pixel_hash(ta::Canvas& canvas) {
    const int width=canvas.width(),height=canvas.height();
    std::vector<std::uint8_t> pixels(static_cast<std::size_t>(width)*height*4);
    require_sdl(SDL_RenderReadPixels(canvas.renderer(),nullptr,SDL_PIXELFORMAT_RGBA32,pixels.data(),width*4),"Read benchmark pixels");
    Digest digest;digest.update(pixels.data(),pixels.size());return digest.finish();
}
void copy(ta::Canvas& canvas,const fs::path& path) {
    const SDL_FRect target{0,0,float(canvas.width()),float(canvas.height())};
    require_sdl(SDL_RenderCopyF(canvas.renderer(),canvas.texture(path),nullptr,&target),"Draw benchmark asset");
}
void stage(ta::Canvas& canvas,const Options& options,json_object* stages,const std::string& name,const std::function<void()>& draw) {
    auto* result=json_object_new_object();json_object_array_add(stages,result);
    field(result,"name",name);
    auto* frames=json_object_new_array();json_object_object_add(result,"frames",frames);
    std::string first;
    for(int i=0;i<options.frames;++i) {
        canvas.begin_frame();
        require_sdl(SDL_SetRenderDrawColor(canvas.renderer(),13,27,35,255),"Clear color");
        require_sdl(SDL_RenderClear(canvas.renderer()),"Clear benchmark frame");
        draw();
        // Record CPU submission separately from presentation/readback; no FPS claim.
        json_object_array_add(frames,frame(canvas.end_frame()));
        if(i==0 || i==options.frames-1) {
            const auto digest=pixel_hash(canvas);
            const std::string suffix=i==0?"first":"last";
            field(result,(suffix+"_rgba_sha256").c_str(),digest);
            if(i==0) {
                first=digest;
                const auto path=options.output/(options.label+"-"+name+".png");
                if(fs::exists(path)) throw std::runtime_error("Refusing to overwrite prior capture: "+path.string());
                canvas.capture(path);
                field(result,"capture",path.filename().string());
                field(result,"png_sha256",file_hash(path));
            }
            else if(digest!=first) throw std::runtime_error("Fixed workload changed pixels: "+name);
        }
        SDL_RenderPresent(canvas.renderer());
        SDL_Event event{};
        while(SDL_PollEvent(&event)) if(event.type==SDL_QUIT) throw std::runtime_error("Benchmark window was closed");
    }
    json_object_object_add(result,"resources",stats(*canvas.resource_stats()));
}
void identities(const Options& options,json_object* report) {
    auto* files=json_object_new_array();json_object_object_add(report,"inputs",files);
    std::vector<fs::path> paths{options.font,options.game/"data/CARTE.FIC",
        options.artwork/"manifest.json",options.game/"assets/travel/vehicles-overhead.json"};
    for(const auto* relative:{"interface/reception.png","engine-room/background.png","engine-room/fire.png","engine-room/stokers.png",
            "interface/original-panel-v2.png","interface/panel-icons.png","interface/panel-launcher.png",
            "travel/vehicles-overhead.png","travel/locomotive-hero.png"}) paths.push_back(options.game/"assets"/relative);
    Json artwork(json_object_from_file((options.artwork/"manifest.json").string().c_str()),json_object_put);
    json_object* scenes{};
    if(!artwork||!json_object_object_get_ex(artwork.get(),"scenes",&scenes)||!json_object_is_type(scenes,json_type_array))
        throw std::runtime_error("Cannot enumerate selected artwork manifest");
    for(std::size_t i=0;i<json_object_array_length(scenes);++i) {
        auto* variants=json_object_object_get(json_object_array_get_idx(scenes,i),"variants");
        if(!variants||json_object_array_length(variants)!=1)throw std::runtime_error("Invalid selected artwork variants");
        auto* background=json_object_object_get(json_object_array_get_idx(variants,0),"background");
        auto* image=background?json_object_object_get(background,"image"):nullptr;
        if(!image||!json_object_is_type(image,json_type_string))throw std::runtime_error("Missing selected artwork image");
        paths.push_back(options.artwork/fs::path(json_object_get_string(image)).filename());
    }
    for(const auto& path:paths) {
        auto* item=json_object_new_object();json_object_array_add(files,item);
        field(item,"path",path.string());field(item,"sha256",file_hash(path));
    }
}
bool balanced(const ta::ResourceCounts& value) {return value.active==0 && value.bytes_active==0 && value.created==value.destroyed;}
int run(const Options& options) {
    const auto report_path=options.output/(options.label+"-resources.json");
    if(fs::exists(report_path)) throw std::runtime_error("Refusing to overwrite prior resource report: "+report_path.string());
    SDL_SetMainReady();require_sdl(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_EVENTS),"Initialize SDL");
    struct SDLGuard {~SDLGuard(){SDL_Quit();}} guard;
    std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(SDL_CreateWindow("Transartica resource baseline",SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,options.width,options.height,SDL_WINDOW_SHOWN),SDL_DestroyWindow);
    if(!window) throw std::runtime_error(SDL_GetError());
    const auto flags=options.renderer=="software"?SDL_RENDERER_SOFTWARE:SDL_RENDERER_ACCELERATED;
    std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(SDL_CreateRenderer(window.get(),-1,flags),SDL_DestroyRenderer);
    if(!renderer) throw std::runtime_error(SDL_GetError()); // Never silently compare a different backend.
    require_sdl(SDL_SetRenderDrawBlendMode(renderer.get(),SDL_BLENDMODE_BLEND),"Renderer blending");
    SDL_RendererInfo info{};require_sdl(SDL_GetRendererInfo(renderer.get(),&info),"Renderer information");
    Json report(json_object_new_object(),json_object_put);
    field(report.get(),"label",options.label);field(report.get(),"renderer",std::string(info.name));
    field(report.get(),"width",std::uint64_t(options.width));field(report.get(),"height",std::uint64_t(options.height));
    field(report.get(),"frames_per_stage",std::uint64_t(options.frames));
    field(report.get(),"units","nanoseconds and logical resource payload bytes; not RSS/VRAM; no cache policy change");
    field(report.get(),"timing_scope","CPU draw submission; excludes present, readback, capture, JSON and input hashes");
    SDL_version version{};SDL_GetVersion(&version);
    field(report.get(),"sdl_version",std::to_string(version.major)+"."+std::to_string(version.minor)+"."+std::to_string(version.patch));
    auto* stages=json_object_new_array();json_object_object_add(report.get(),"stages",stages);
    std::shared_ptr<const ta::ResourceStats> resources;
    {
        ta::Canvas canvas(renderer.get(),options.font);resources=canvas.resource_stats();
        ta::Session session;std::string error;
        if(!session.load_world(options.game/"data/CARTE.FIC",error)) throw std::runtime_error(error);
        const auto start=Clock::now();
        ta::View view(canvas,options.game/"assets",options.artwork);
        field(report.get(),"view_construction_ns",std::uint64_t(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count()));
        json_object_object_add(report.get(),"after_view_construction",stats(*resources));
        stage(canvas,options,stages,"reception",[&]{view.reception();});
        stage(canvas,options,stages,"cabin",[&]{view.cabin(session,0);});
        // Explicit render fixture: fixed visual time and heat activate the real fire/stoker atlases.
        auto heated=session;heated.engine.heat=600;heated.engine.lignite_rate=1;heated.engine.anthracite_rate=2;
        stage(canvas,options,stages,"cabin-heated",[&]{view.cabin(heated,0);});
        stage(canvas,options,stages,"world",[&]{view.world(session);});
        stage(canvas,options,stages,"footer",[&]{view.footer(session,true);});
        // Explicit render-only ownership fixture exercises the currently rescanned launcher alpha plane.
        auto launcher=session;launcher.wagons.push_back({13,0,0,0});
        stage(canvas,options,stages,"footer-launcher",[&]{view.footer(launcher,true);});
        for(int i=0;i<8;++i) {
            const auto name="region-0"+std::to_string(i);
            stage(canvas,options,stages,name,[&]{copy(canvas,options.artwork/(name+".png"));});
        }
        json_object_object_add(report.get(),"before_canvas_destruction",stats(*resources));
    }
    json_object_object_add(report.get(),"after_canvas_destruction",stats(*resources));
    const bool clean=resources->logical_bytes_active==0 && balanced(resources->asset_textures) && balanced(resources->glyph_textures)
        && balanced(resources->glyph_entries) && balanced(resources->alpha_planes) && balanced(resources->staging_buffers);
    json_object_object_add(report.get(),"all_observed_resources_released",json_object_new_boolean(clean));
    identities(options,report.get()); // Hash after timed workloads to avoid warming their file reads.
    if(json_object_to_file_ext(report_path.string().c_str(),report.get(),JSON_C_TO_STRING_PRETTY)<0)
        throw std::runtime_error("Cannot write resource report: "+report_path.string());
    std::cout<<"RESOURCE_REPORT "<<report_path<<" released="<<clean<<" logical_peak_bytes="<<resources->logical_bytes_peak<<'\n';
    return clean?0:1;
}
}
int main(int argc,char** argv) {
    try {return run(options(argc,argv));}
    catch(const std::exception& error) {std::cerr<<"RESOURCE_BENCH_ERROR: "<<error.what()<<'\n';return 1;}
}
