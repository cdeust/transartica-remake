// SPDX-License-Identifier: MIT
// Prepared rendering/resource probe, not live campaign or artistic acceptance.
#include "view/view.h"
#include "view/world_visual_math.hpp"
#include <SDL.h>
#include <json-c/json.h>
#include <cmath>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
namespace ta=transartica;
namespace fs=std::filesystem;
namespace {
struct Options{fs::path game,artwork,font,output;std::string renderer;double zoom{};};
void require(bool ok,const char* error){if(!ok)throw std::runtime_error(error);}
Options options(int argc,char** argv){
    Options o;for(int i=1;i<argc;++i){const std::string key=argv[i];require(++i<argc,"Missing option value");const std::string value=argv[i];
        if(key=="--game-dir")o.game=value;else if(key=="--artwork-dir")o.artwork=value;else if(key=="--font")o.font=value;
        else if(key=="--output-dir")o.output=value;else if(key=="--renderer")o.renderer=value;
        else if(key=="--zoom"){std::size_t used{};o.zoom=std::stod(value,&used);require(used==value.size(),"Invalid zoom");}
        else throw std::runtime_error("Unknown option: "+key);}
    require(fs::is_directory(o.game)&&fs::is_regular_file(o.font)&&fs::is_directory(o.output),"Require game/font/existing output");
    require(std::isfinite(o.zoom)&&o.zoom>=.001&&o.zoom<=2,"Explicit source zoom range .001..2 required");
    require(o.renderer=="software"||o.renderer=="accelerated","Explicit renderer required; no fallback");
    if(o.artwork.empty())o.artwork=o.game/"assets/travel/artwork/world-hd";
    for(const auto* file:{"SEROV.png","AMSTERDAM.png","rail-render.json"})require(!fs::exists(o.output/file),"Probe output already exists");return o;
}
void field(json_object* o,const char* name,std::string value){json_object_object_add(o,name,json_object_new_string(value.c_str()));}
void ballast_resources(ta::Canvas& canvas,const fs::path& kit){
    canvas.begin_frame();auto* texture=canvas.rail_ballast_texture(kit);int w{},h{};
    require(SDL_QueryTexture(texture,nullptr,nullptr,&w,&h)==0&&w==195&&h==200,"Neutral texture must retain exact source STRIP size");
    const auto created=canvas.resource_stats()->asset_textures.created,decodes=canvas.resource_stats()->timings.png_decode_calls;
    require(canvas.rail_ballast_texture(kit)==texture,"Warm derived texture must reuse the live cached object");
    require(canvas.resource_stats()->asset_textures.created==created&&canvas.resource_stats()->timings.png_decode_calls==decodes,"Warm derived texture allocated/decoded again");
    canvas.end_frame();SDL_RenderPresent(canvas.renderer());
    canvas.begin_frame();canvas.end_frame();SDL_RenderPresent(canvas.renderer());
    canvas.begin_frame();require(canvas.resource_stats()->asset_textures.active==0,"Unused derived asset must leave the frame cache");
    require(canvas.resource_stats()->staging_buffers.bytes_active==0,"Derived texture retained CPU staging bytes");
    canvas.end_frame();SDL_RenderPresent(canvas.renderer());
}
void fixture(ta::View& view,ta::Canvas& canvas,ta::Session& session,const ta::economy::WorldData& cities,const Options& o,const char* name,json_object* captures){
    const ta::economy::City* selected{};for(const auto& city:cities.cities())if(city.name==name)selected=&city;
    require(selected!=nullptr,"Named fixture city absent from decoded source");
    ta::WorldState state;state.ready=true;state.inspecting=true;state.camera=ta::point(selected->anchor)+ta::Point{.5,.5};state.zoom=o.zoom;
    require(view.restore_world(state,session,cities.cities().size()),"Prepared world camera rejected");
    const auto before=session.network.tiles();
    for(int frame=0;frame<2;++frame){canvas.begin_frame();view.world(session,{},nullptr,&cities);canvas.end_frame();
        if(frame==1)canvas.capture(o.output/(std::string(name)+".png"));SDL_RenderPresent(canvas.renderer());}
    require(session.network.tiles()==before,"Drawing changed CARTE network");
    auto* item=json_object_new_object();field(item,"city",name);field(item,"capture",std::string(name)+".png");
    auto* anchor=json_object_new_array();json_object_array_add(anchor,json_object_new_int(selected->anchor.x));json_object_array_add(anchor,json_object_new_int(selected->anchor.y));
    json_object_object_add(item,"source_city_anchor",anchor);json_object_array_add(captures,item);
}
int run(const Options& o){
    SDL_SetMainReady();require(SDL_Init(SDL_INIT_VIDEO)==0,SDL_GetError());struct Quit{~Quit(){SDL_Quit();}} quit;
    // Same1280x800 application default; four times source320x200.
    std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(SDL_CreateWindow("Rail prepared probe",SDL_WINDOWPOS_UNDEFINED,SDL_WINDOWPOS_UNDEFINED,1280,800,SDL_WINDOW_HIDDEN),SDL_DestroyWindow);
    require(bool(window),SDL_GetError());
    std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(SDL_CreateRenderer(window.get(),-1,o.renderer=="software"?SDL_RENDERER_SOFTWARE:SDL_RENDERER_ACCELERATED),SDL_DestroyRenderer);
    require(bool(renderer),SDL_GetError());require(SDL_SetRenderDrawBlendMode(renderer.get(),SDL_BLENDMODE_BLEND)==0,SDL_GetError());
    ta::Canvas canvas(renderer.get(),o.font);ballast_resources(canvas,o.game/"assets/travel/rail-track-kit.png");
    ta::Session session;ta::economy::WorldData cities;std::string error;
    if(!session.load_world(o.game/"private-data/CARTE.FIC",error)||!cities.load(o.game/"private-data",error))throw std::runtime_error(error);
    ta::View view(canvas,o.game/"assets",o.artwork);
    std::unique_ptr<json_object,decltype(&json_object_put)> report(json_object_new_object(),json_object_put);
    field(report.get(),"scope","Prepared source-city cameras and neutral-ballast resource lifecycle; not live input/campaign or artistic acceptance");
    SDL_RendererInfo info{};require(SDL_GetRendererInfo(renderer.get(),&info)==0,SDL_GetError());field(report.get(),"renderer",info.name);
    field(report.get(),"artwork_directory",o.artwork.string());json_object_object_add(report.get(),"zoom",json_object_new_double(o.zoom));
    auto* captures=json_object_new_array();json_object_object_add(report.get(),"captures",captures);
    fixture(view,canvas,session,cities,o,"SEROV",captures);fixture(view,canvas,session,cities,o,"AMSTERDAM",captures);
    json_object_object_add(report.get(),"amsterdam_25_24_source_code",json_object_new_int(session.network.tile({25,24})));
    require(json_object_to_file_ext((o.output/"rail-render.json").string().c_str(),report.get(),JSON_C_TO_STRING_PRETTY)>=0,"Cannot write probe receipt");
    std::cout<<"rail render: source network unchanged; derived cache released; two prepared captures in "<<o.output<<'\n';return 0;
}
}
int main(int argc,char** argv){try{return run(options(argc,argv));}catch(const std::exception& e){std::cerr<<"RAIL RENDER FAILED: "<<e.what()<<'\n';return 1;}}
