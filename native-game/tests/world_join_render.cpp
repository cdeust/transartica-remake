#include "view/world_painting_join.hpp"
// SPDX-License-Identifier: MIT
// Diagnostic only. Sources: view/view.cpp::load_artwork, view/world.cpp::world;
// capture windows: tasks/standalone-cpp-20261018/world-joins-art-brief.md and
// owner mandate: eight cells across a join (four each side), 8x8 at intersections.
#include "core/session.hpp"
#include "platform/canvas.h"
#include "platform/hash.h"
#include "view/render_check.h"
#include <SDL.h>
#include <json-c/json.h>
#include <openssl/evp.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace fs=std::filesystem;
namespace ta=transartica;
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
// Owner-authorized image-edit context: no more than 2:1 for an 8-cell band,
// with a declared 3-cell overlap. This is capture layout, not terrain synthesis.
constexpr int segment_max_cells=16,segment_overlap_cells=3;
struct Options {
    fs::path game,artwork,font,output;
    double density{};
    std::string renderer="software"; // Same explicit backend choices as render_resources.
    bool segments{};
};
struct Region {
    std::string id,sha;
    fs::path path;
    SDL_FRect world;
    SDL_Rect crop;
    SDL_Point declared_size;
};
struct Rect {double x{},y{},w{},h{};};
struct Capture {
    std::string id,kind;
    Rect window;
    ta::Point begin,end;
    std::vector<std::size_t> regions;
    std::string parent;
    ta::Point parent_begin,parent_end;
    int piece_index{},piece_count{},overlap_cells{};
};
json_object* member(json_object* object,const char* key) {
    json_object* value{};
    if(!object||!json_object_object_get_ex(object,key,&value)) throw std::runtime_error(std::string("Missing manifest field: ")+key);
    return value;
}
std::string string(json_object* object) {
    if(!object||!json_object_is_type(object,json_type_string)) throw std::runtime_error("Expected manifest string");
    return json_object_get_string(object);
}
double number(json_object* array,std::size_t index) {
    auto* value=json_object_array_get_idx(array,index);
    if(!value||(!json_object_is_type(value,json_type_int)&&!json_object_is_type(value,json_type_double))) throw std::runtime_error("Expected manifest coordinate");
    const auto result=json_object_get_double(value);
    if(!std::isfinite(result)) throw std::runtime_error("Nonfinite manifest coordinate");
    return result;
}
void array_size(json_object* value,std::size_t count) {
    if(!value||!json_object_is_type(value,json_type_array)||json_object_array_length(value)!=count) throw std::runtime_error("Invalid manifest array size");
}
int integer(double value) {
    if(value<0||value>std::numeric_limits<int>::max()||value!=std::floor(value)) throw std::runtime_error("Expected nonnegative integral pixel coordinate");
    return int(value);
}
Options options(int argc,char** argv) {
    Options result;
    for(int i=1;i<argc;++i) {
        const std::string flag=argv[i];
        if(flag=="--help") {
            std::cout<<"world_join_render --game-dir PATH --font PATH --output-dir EXISTING_DIR --density PIXELS_PER_CELL [--artwork-dir PATH] [--renderer software|accelerated] [--segments]\n";
            std::exit(0);
        }
        if(flag=="--segments") {result.segments=true;continue;}
        if(++i==argc) throw std::runtime_error("Missing value for "+flag);
        const std::string value=argv[i];
        if(flag=="--game-dir") result.game=value;
        else if(flag=="--artwork-dir") result.artwork=value;
        else if(flag=="--font") result.font=value;
        else if(flag=="--output-dir") result.output=value;
        else if(flag=="--renderer") result.renderer=value;
        else if(flag=="--density") {
            std::size_t used{};result.density=std::stod(value,&used);
            if(used!=value.size()||!std::isfinite(result.density)||result.density<=0) throw std::runtime_error("Density must be a positive finite number");
        } else throw std::runtime_error("Unknown option "+flag);
    }
    if(result.game.empty()||!fs::is_regular_file(result.font)||!fs::is_directory(result.output)||result.density<=0)
        throw std::runtime_error("Require game-dir, existing font/output directory and explicit density");
    if(result.renderer!="software"&&result.renderer!="accelerated") throw std::runtime_error("Renderer must be software or accelerated; no fallback");
    if(result.artwork.empty())result.artwork=result.game/"assets/travel/artwork/world-hd";
    return result;
}
std::string digest(const fs::path& path) {
    // Bounded streaming SHA256, same EVP operations/buffer as platform/hash.cpp.
    std::ifstream in(path,std::ios::binary);if(!in) throw std::runtime_error("Cannot hash "+path.string());
    std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> state(EVP_MD_CTX_new(),EVP_MD_CTX_free);
    if(!state||EVP_DigestInit_ex(state.get(),EVP_sha256(),nullptr)!=1) throw std::runtime_error("Digest init failed");
    std::array<char,8192> buffer{};
    while(in) {in.read(buffer.data(),buffer.size());if(EVP_DigestUpdate(state.get(),buffer.data(),std::size_t(in.gcount()))!=1) throw std::runtime_error("Digest update failed");}
    if(!in.eof()) throw std::runtime_error("Digest read failed");
    std::array<unsigned char,EVP_MAX_MD_SIZE> bytes{};unsigned count{};
    if(EVP_DigestFinal_ex(state.get(),bytes.data(),&count)!=1) throw std::runtime_error("Digest final failed");
    std::ostringstream out;out<<std::hex<<std::setfill('0');for(unsigned i=0;i<count;++i) out<<std::setw(2)<<unsigned(bytes[i]);return out.str();
}
Rect rectangle(const Region& region) {return {region.world.x,region.world.y,region.world.w,region.world.h};}
Rect intersection(Rect a,Rect b) {
    const auto x=std::max(a.x,b.x),y=std::max(a.y,b.y);
    return {x,y,std::max(0.,std::min(a.x+a.w,b.x+b.w)-x),std::max(0.,std::min(a.y+a.h,b.y+b.h)-y)};
}
std::vector<Region> load(const Options& options,Json& manifest,const fs::path& manifest_path) {
    manifest.reset(json_object_from_file(manifest_path.string().c_str()));
    if(!manifest) throw std::runtime_error("Cannot read world-hd manifest");
    if(json_object_get_int(member(manifest.get(),"schema"))!=1) throw std::runtime_error("This diagnostic requires the active schema1 affine paintings");
    ta::verify_sha256(options.game/"private-data/CARTE.FIC",string(member(manifest.get(),"source_map_sha256")));
    auto* scenes=member(manifest.get(),"scenes");
    if(!json_object_is_type(scenes,json_type_array)||!json_object_array_length(scenes)) throw std::runtime_error("Empty scenes");
    std::vector<Region> regions;std::set<std::string> ids;
    for(std::size_t i=0;i<json_object_array_length(scenes);++i) {
        auto* scene=json_object_array_get_idx(scenes,i);Region r;
        r.id=string(member(scene,"id"));
        if(r.id.empty()||!ids.insert(r.id).second) throw std::runtime_error("Empty or duplicate scene id");
        if(string(member(scene,"registration"))!="region_bounds") throw std::runtime_error("Unsupported registration");
        auto* world=member(scene,"world");array_size(world,4);
        // Match View::load_artwork: world coordinates are stored as SDL_FRect.
        r.world={float(number(world,0)),float(number(world,1)),float(number(world,2)),float(number(world,3))};
        if(r.world.x<0||r.world.y<0||r.world.w<=0||r.world.h<=0||r.world.x+r.world.w>ta::RailNetwork::width||r.world.y+r.world.h>ta::RailNetwork::height) throw std::runtime_error("World rectangle outside CARTE");
        auto* variants=member(scene,"variants");array_size(variants,1);auto* variant=json_object_array_get_idx(variants,0);
        auto* crop=member(variant,"source_crop");array_size(crop,4);
        r.crop={integer(number(crop,0)),integer(number(crop,1)),integer(number(crop,2)),integer(number(crop,3))};
        auto* size=member(variant,"size");array_size(size,2);r.declared_size={integer(number(size,0)),integer(number(size,1))};
        if(r.crop.w<=0||r.crop.h<=0||r.crop.x>r.declared_size.x-r.crop.w||r.crop.y>r.declared_size.y-r.crop.h) throw std::runtime_error("Crop outside declared image");
        auto* background=member(variant,"background");
        r.path=manifest_path.parent_path()/fs::path(string(member(background,"image"))).filename();
        r.sha=string(member(background,"png_sha256"));ta::verify_sha256(r.path,r.sha);
        for(const auto& previous:regions) {const auto overlap=intersection(rectangle(previous),rectangle(r));if(overlap.w>0&&overlap.h>0) throw std::runtime_error("Overlapping scene worlds");}
        regions.push_back(std::move(r));
    }
    return regions;
}
std::vector<Capture> captures(const std::vector<Region>& regions) {
    // Four cells per side is the operator's diagnostic context, not a seam fix.
    constexpr double half_band=4;
    std::vector<Capture> vertical,horizontal,corners;
    std::map<std::pair<double,double>,std::vector<std::size_t>> vertices;
    for(std::size_t i=0;i<regions.size();++i) {
        const auto a=rectangle(regions[i]);
        for(const auto& p:std::array<ta::Point,4>{{{a.x,a.y},{a.x+a.w,a.y},{a.x,a.y+a.h},{a.x+a.w,a.y+a.h}}}) vertices[{p.x,p.y}].push_back(i);
        for(std::size_t j=i+1;j<regions.size();++j) {
            const auto b=rectangle(regions[j]);
            if(a.x+a.w==b.x||b.x+b.w==a.x) {
                const auto x=a.x+a.w==b.x?b.x:a.x,low=std::max(a.y,b.y),high=std::min(a.y+a.h,b.y+b.h);
                if(high>low) vertical.push_back({"","vertical",{x-half_band,low,2*half_band,high-low},{x,low},{x,high},{i,j}});
            }
            if(a.y+a.h==b.y||b.y+b.h==a.y) {
                const auto y=a.y+a.h==b.y?b.y:a.y,low=std::max(a.x,b.x),high=std::min(a.x+a.w,b.x+b.w);
                if(high>low) horizontal.push_back({"","horizontal",{low,y-half_band,high-low,2*half_band},{low,y},{high,y},{i,j}});
            }
        }
    }
    const auto order=[](const Capture& a,const Capture& b){return std::pair{a.begin.y,a.begin.x}<std::pair{b.begin.y,b.begin.x};};
    std::sort(vertical.begin(),vertical.end(),order);std::sort(horizontal.begin(),horizontal.end(),order);
    for(std::size_t i=0;i<vertical.size();++i) vertical[i].id="V"+std::to_string(i+1);
    for(std::size_t i=0;i<horizontal.size();++i) horizontal[i].id="H"+std::to_string(i+1);
    for(const auto& [point,meeting]:vertices) if(meeting.size()==4) {
        const auto [x,y]=point;
        corners.push_back({"corner-"+std::to_string(corners.size()+1),"intersection",{x-half_band,y-half_band,2*half_band,2*half_band},{x,y},{x,y},meeting});
    }
    std::vector<Capture> result;
    result.insert(result.end(),vertical.begin(),vertical.end());result.insert(result.end(),horizontal.begin(),horizontal.end());result.insert(result.end(),corners.begin(),corners.end());
    // First deliver the owner-observed 04/05 join; geometry still comes only from adjacency.
    std::stable_partition(result.begin(),result.end(),[&](const Capture& capture){
        if(capture.kind!="vertical"||capture.regions.size()!=2)return false;
        std::set<std::string> names;for(auto i:capture.regions)names.insert(regions[i].path.filename().string());
        return names==std::set<std::string>{"region-04.png","region-05.png"};
    });
    return result;
}
std::vector<Capture> segmented(const std::vector<Capture>& full) {
    std::vector<Capture> result;
    for(const auto& capture:full) {
        if(capture.kind=="intersection") {result.push_back(capture);continue;}
        const bool vertical=capture.kind=="vertical";
        const double extent=vertical?capture.end.y-capture.begin.y:capture.end.x-capture.begin.x;
        if(extent<=0||extent!=std::floor(extent)||extent>std::numeric_limits<int>::max())
            throw std::runtime_error("Segment mode requires a positive integral source-world length");
        const int length=int(extent);
        // n windows cover L exactly when their lengths sum to L+overlap*(n-1).
        // Minimal n ensures each window is <=16; distribute surplus cells last.
        const int count=std::max(1,int(std::ceil(double(length-segment_overlap_cells)/(segment_max_cells-segment_overlap_cells))));
        const int total=length+segment_overlap_cells*(count-1),base=total/count,surplus=total%count;
        double cursor=vertical?capture.begin.y:capture.begin.x;
        for(int index=0;index<count;++index) {
            const int cells=base+(index>=count-surplus?1:0);
            if(cells>segment_max_cells)throw std::runtime_error("Segment layout exceeded its authorized maximum");
            auto piece=capture;
            piece.id=capture.id+"-"+std::to_string(index+1);
            piece.parent=capture.id;piece.parent_begin=capture.begin;piece.parent_end=capture.end;
            piece.piece_index=index+1;piece.piece_count=count;piece.overlap_cells=count>1?segment_overlap_cells:0;
            if(vertical) {piece.begin.y=cursor;piece.end.y=cursor+cells;piece.window.y=cursor;piece.window.h=cells;}
            else {piece.begin.x=cursor;piece.end.x=cursor+cells;piece.window.x=cursor;piece.window.w=cells;}
            result.push_back(std::move(piece));cursor+=cells-segment_overlap_cells;
        }
        const auto& last=result.back();
        if(last.end!=capture.end)throw std::runtime_error("Segment layout failed to preserve the source endpoint");
    }
    return result;
}
json_object* coordinates(std::initializer_list<double> values) {
    auto* result=json_object_new_array();for(auto value:values)json_object_array_add(result,json_object_new_double(value));return result;
}
void field(json_object* object,const char* name,const std::string& value) {json_object_object_add(object,name,json_object_new_string(value.c_str()));}
void field(json_object* object,const char* name,double value) {json_object_object_add(object,name,json_object_new_double(value));}
int dimension(double cells,double density) {
    const double value=cells*density;
    if(value<=0||value>std::numeric_limits<int>::max()||value!=std::floor(value))
        throw std::runtime_error("Density must produce integral image dimensions for every exact world window; no implicit rounding or stretching");
    return int(value);
}
Json render(const Options& options,const Capture& capture,const std::vector<Region>& regions) {
    const int width=dimension(capture.window.w,options.density),height=dimension(capture.window.h,options.density);
    std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(SDL_CreateWindow("Transartica world join reference",SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,width,height,SDL_WINDOW_HIDDEN),SDL_DestroyWindow);
    if(!window) throw std::runtime_error(SDL_GetError());
    const auto flags=options.renderer=="software"?SDL_RENDERER_SOFTWARE:SDL_RENDERER_ACCELERATED;
    std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(SDL_CreateRenderer(window.get(),-1,flags),SDL_DestroyRenderer);
    if(!renderer) throw std::runtime_error(SDL_GetError());
    ta::render_check(SDL_SetRenderDrawBlendMode(renderer.get(),SDL_BLENDMODE_BLEND),"World join blending");
    SDL_RendererInfo info{};ta::render_check(SDL_GetRendererInfo(renderer.get(),&info),"World join renderer");
    ta::Canvas canvas(renderer.get(),options.font);
    if(canvas.width()!=width||canvas.height()!=height) throw std::runtime_error("Native drawable size differs from requested reference size");
    Json report(json_object_new_object(),json_object_put);field(report.get(),"id",capture.id);field(report.get(),"kind",capture.kind);field(report.get(),"renderer",std::string(info.name));
    json_object_object_add(report.get(),"world",coordinates({capture.window.x,capture.window.y,capture.window.w,capture.window.h}));
    json_object_object_add(report.get(),"segment",coordinates({capture.begin.x,capture.begin.y,capture.end.x,capture.end.y}));
    json_object_object_add(report.get(),"pixels",coordinates({double(width),double(height)}));
    if(!capture.parent.empty()) {
        field(report.get(),"parent_join",capture.parent);
        json_object_object_add(report.get(),"parent_segment",coordinates({capture.parent_begin.x,capture.parent_begin.y,capture.parent_end.x,capture.parent_end.y}));
        field(report.get(),"piece_index",double(capture.piece_index));field(report.get(),"piece_count",double(capture.piece_count));
        field(report.get(),"overlap_cells",double(capture.overlap_cells));
    }
    auto* inputs=json_object_new_array();json_object_object_add(report.get(),"inputs",inputs);
    // Exact View::screen arithmetic: viewport centre + (world-camera)*cell_pixels,
    // then float conversion. Full source crop is submitted; SDL clips the viewport.
    const ta::Point camera{capture.window.x+capture.window.w*.5,capture.window.y+capture.window.h*.5};
    canvas.begin_frame();SDL_SetRenderDrawColor(renderer.get(),13,27,35,255);
    ta::render_check(SDL_RenderClear(renderer.get()),"World join clear");
    const SDL_Rect clip{0,0,width,height};ta::render_check(SDL_RenderSetClipRect(renderer.get(),&clip),"World join clip");
    for(const auto& region:regions) {
        const ta::Point p{width*.5+(region.world.x-camera.x)*options.density,height*.5+(region.world.y-camera.y)*options.density};
        const SDL_FRect dest{float(p.x),float(p.y),float(region.world.w*options.density),float(region.world.h*options.density)};
        if(dest.x+dest.w<0||dest.y+dest.h<0||dest.x>width||dest.y>height)continue;
        const auto size=canvas.image_size(region.path);
        if(size.x!=region.declared_size.x||size.y!=region.declared_size.y) throw std::runtime_error("PNG header differs from manifest: "+region.path.string());
        ta::render_check(SDL_RenderCopyF(renderer.get(),canvas.texture(region.path),&region.crop,&dest),"World join selected painting");
        const auto visible=intersection(rectangle(region),capture.window);if(visible.w<=0||visible.h<=0)continue;
        auto* item=json_object_new_object();json_object_array_add(inputs,item);field(item,"scene",region.id);field(item,"file",region.path.filename().string());field(item,"png_sha256",region.sha);
        json_object_object_add(item,"world",coordinates({region.world.x,region.world.y,region.world.w,region.world.h}));
        json_object_object_add(item,"source_crop",coordinates({double(region.crop.x),double(region.crop.y),double(region.crop.w),double(region.crop.h)}));
        json_object_object_add(item,"visible_world",coordinates({visible.x,visible.y,visible.w,visible.h}));
        json_object_object_add(item,"visible_source_pixels",coordinates({region.crop.x+(visible.x-region.world.x)*region.crop.w/region.world.w,region.crop.y+(visible.y-region.world.y)*region.crop.h/region.world.h,visible.w*region.crop.w/region.world.w,visible.h*region.crop.h/region.world.h}));
        json_object_object_add(item,"submitted_destination",coordinates({dest.x,dest.y,dest.w,dest.h}));
    }
    const ta::WorldProjection projection{{width*.5-camera.x*options.density,height*.5-camera.y*options.density}, options.density, {0,0,float(width),float(height)}};
    ta::reconstruct_horizontal_painting_joins(canvas,regions,projection);
    ta::render_check(SDL_RenderSetClipRect(renderer.get(),nullptr),"World join clear clip");canvas.end_frame();
    const auto output=options.output/(capture.id+".png");canvas.capture(output);SDL_RenderPresent(renderer.get());
    field(report.get(),"capture",output.filename().string());field(report.get(),"capture_sha256",digest(output));
    return report;
}
int run(const Options& options) {
    const auto manifest_path=options.artwork/"manifest.json";
    Json manifest(nullptr,json_object_put);const auto regions=load(options,manifest,manifest_path);auto plan=captures(regions);
    if(options.segments)plan=segmented(plan);
    if(plan.empty())throw std::runtime_error("Manifest has no internal join");
    const auto receipt=options.output/"world-joins.json";
    if(fs::exists(receipt))throw std::runtime_error("Receipt already exists; preserve the earlier reference");
    for(const auto& capture:plan) {
        dimension(capture.window.w,options.density);dimension(capture.window.h,options.density);
        if(fs::exists(options.output/(capture.id+".png")))throw std::runtime_error("Reference capture already exists: "+capture.id);
    }
    SDL_SetMainReady();if(SDL_Init(SDL_INIT_VIDEO)<0)throw std::runtime_error(SDL_GetError());
    struct Guard {~Guard(){SDL_Quit();}} guard;
    Json report(json_object_new_object(),json_object_put);
    field(report.get(),"format","transartica-world-join-reference-v1");field(report.get(),"manifest_sha256",digest(manifest_path));
    field(report.get(),"artwork_directory",options.artwork.string());
    field(report.get(),"source_map_sha256",string(member(manifest.get(),"source_map_sha256")));field(report.get(),"pixels_per_cell",options.density);
    field(report.get(),"scope","Registered terrain projection with texel-centre boundary reconstruction; no footer, rails or labels");
    field(report.get(),"mode",options.segments?"overlapping_segments":"full_joins");
    if(options.segments) {
        field(report.get(),"segment_max_cells",double(segment_max_cells));field(report.get(),"segment_overlap_cells",double(segment_overlap_cells));
        field(report.get(),"layout_provenance","Owner-authorized capture layout: maximum16 cells and overlap3; not an inferred artwork overlap");
    }
    double low=std::numeric_limits<double>::infinity(),high=0;
    for(const auto& r:regions)for(double density:{r.crop.w/double(r.world.w),r.crop.h/double(r.world.h)}){low=std::min(low,density);high=std::max(high,density);}
    json_object_object_add(report.get(),"source_pixels_per_cell_range",coordinates({low,high}));
    auto* outputs=json_object_new_array();json_object_object_add(report.get(),"captures",outputs);
    for(const auto& capture:plan) {auto result=render(options,capture,regions);json_object_array_add(outputs,result.release());std::cout<<capture.id<<" "<<options.output/(capture.id+".png")<<std::endl;}
    if(json_object_to_file_ext(receipt.string().c_str(),report.get(),JSON_C_TO_STRING_PRETTY|JSON_C_TO_STRING_NOSLASHESCAPE)<0)throw std::runtime_error("Cannot write reference receipt");
    std::cout<<"World join references: "<<plan.size()<<" captures; "<<receipt<<'\n';return 0;
}
}
int main(int argc,char** argv) {
    try{return run(options(argc,argv));}
    catch(const std::exception& error){std::cerr<<"WORLD JOIN REFERENCE FAILED: "<<error.what()<<'\n';return 1;}
}
