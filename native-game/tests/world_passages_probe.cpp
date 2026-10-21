// SPDX-License-Identifier: MIT
// Prepared layer-order/occlusion captures, not continuous gameplay acceptance.
// Six locations: underground-rendering.md. Hero: train_renderer.gd registration.
#include "view/world_passages.hpp"
#include "view/world_visual_math.hpp"
#include "view/render_check.h"
#include "platform/hash.h"
#include <SDL.h>
#include <json-c/json.h>
#include <png.h>
#include <openssl/evp.h>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <initializer_list>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>

namespace ta=transartica;
namespace fs=std::filesystem;
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
struct Options {fs::path game,artwork,font,output;std::string renderer,placement;double density{},background_context{};};
struct Painting {fs::path path;SDL_FRect world;SDL_Rect crop;std::string id,sha;};
struct Mouth {ta::Cell cell;int code;ta::Point direction;};
// travel_cover.gd exact MOUTHS. Opening faces surface, opposite neighbor is covered.
constexpr std::array<Mouth,6> mouths{{{{61,51},53,{0,1}},{{30,58},54,{-1,0}},{{51,39},54,{-1,0}},
    {{12,21},58,{1,0}},{{105,23},58,{1,0}},{{113,58},58,{1,0}}}};
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
json_object* field(json_object* object,const char* name){json_object* value{};require(json_object_object_get_ex(object,name,&value),"Missing painting field");return value;}
double number(json_object* array,int i){return json_object_get_double(json_object_array_get_idx(array,i));}
void text(json_object* object,const char* key,const std::string& value){json_object_object_add(object,key,json_object_new_string(value.c_str()));}
json_object* coords(std::initializer_list<double> values){auto* result=json_object_new_array();for(auto value:values)json_object_array_add(result,json_object_new_double(value));return result;}
void rectangle(json_object* object,const char* key,SDL_FRect r){json_object_object_add(object,key,coords({r.x,r.y,r.w,r.h}));}
std::string digest(const fs::path& path){
    // Same bounded streaming EVP digest as platform/hash.cpp.
    std::ifstream input(path,std::ios::binary);require(bool(input),"Cannot read capture digest input");
    std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> state(EVP_MD_CTX_new(),EVP_MD_CTX_free);
    require(bool(state)&&EVP_DigestInit_ex(state.get(),EVP_sha256(),nullptr)==1,"Cannot initialize capture digest");
    std::array<char,8192> buffer{};while(input){input.read(buffer.data(),buffer.size());require(EVP_DigestUpdate(state.get(),buffer.data(),std::size_t(input.gcount()))==1,"Cannot update capture digest");}
    require(input.eof(),"Cannot finish capture input");std::array<unsigned char,EVP_MAX_MD_SIZE> bytes{};unsigned count{};
    require(EVP_DigestFinal_ex(state.get(),bytes.data(),&count)==1,"Cannot finish capture digest");
    const char hex[]="0123456789abcdef";std::string result;for(unsigned i=0;i<count;++i){result+=hex[bytes[i]>>4];result+=hex[bytes[i]&15];}return result;
}
Options options(int argc,char** argv){
    Options result;for(int i=1;i<argc;++i){std::string key=argv[i];require(++i<argc,"Missing option value");std::string value=argv[i];
        if(key=="--game-dir")result.game=value;else if(key=="--artwork-dir")result.artwork=value;
        else if(key=="--font")result.font=value;else if(key=="--output-dir")result.output=value;
        else if(key=="--renderer")result.renderer=value;else if(key=="--placement")result.placement=value;
        else if(key=="--density"){std::size_t used{};result.density=std::stod(value,&used);require(used==value.size(),"Invalid density");}
        else if(key=="--background-context"){std::size_t used{};result.background_context=std::stod(value,&used);require(used==value.size()&&std::isfinite(result.background_context)&&result.background_context>0,"Invalid background context");}
        else throw std::runtime_error("Unknown option: "+key);}
    require(fs::is_directory(result.game)&&fs::is_regular_file(result.font)&&fs::is_directory(result.output),"Require game/font/existing output directory");
    require(result.renderer=="software"||result.renderer=="accelerated","Explicit renderer required; no fallback");
    require(result.placement=="mouth"||result.placement=="inner","Explicit placement mouth|inner required");
    require(std::isfinite(result.density)&&result.density>0&&result.density<=ta::rail_visual::cell*2,"Density must fit source maximum zoom2");
    if(result.artwork.empty())result.artwork=result.game/"assets/travel/artwork/world-hd";
    require(!fs::exists(result.output/"world-passages.json"),"Output receipt already exists");return result;
}
std::vector<Painting> paintings(ta::WorldPassages& passages,ta::Canvas& canvas,const fs::path& directory){
    Json doc(json_object_from_file((directory/"manifest.json").string().c_str()),json_object_put);require(bool(doc),"Missing painting manifest");
    auto* scenes=field(doc.get(),"scenes");std::vector<Painting> result;
    for(std::size_t i=0;i<json_object_array_length(scenes);++i){auto* scene=json_object_array_get_idx(scenes,i);
        auto* variant=json_object_array_get_idx(field(scene,"variants"),0);auto* world=field(scene,"world");auto* crop=field(variant,"source_crop");auto* background=field(variant,"background");
        fs::path path=directory/fs::path(json_object_get_string(field(background,"image"))).filename();
        ta::verify_sha256(path,json_object_get_string(field(background,"png_sha256")));
        Painting item{path,{float(number(world,0)),float(number(world,1)),float(number(world,2)),float(number(world,3))},
            {int(number(crop,0)),int(number(crop,1)),int(number(crop,2)),int(number(crop,3))},json_object_get_string(field(scene,"id")),json_object_get_string(field(background,"png_sha256"))};
        canvas.image_size(path);passages.add_painting(item.world,item.crop,item.path);result.push_back(item);
    }require(result.size()==8,"Probe requires selected eight paintings");return result;
}
void background(ta::Canvas& canvas,const std::vector<Painting>& paintings,const ta::WorldProjection& p){
    auto* renderer=canvas.renderer();SDL_SetRenderDrawColor(renderer,13,27,35,255);ta::render_check(SDL_RenderClear(renderer),"Probe clear");
    for(const auto& item:paintings){auto a=p.screen({item.world.x,item.world.y});SDL_FRect dest{float(a.x),float(a.y),float(item.world.w*p.pixels_per_cell),float(item.world.h*p.pixels_per_cell)};
        if(SDL_HasIntersectionF(&dest,&p.viewport))ta::render_check(SDL_RenderCopyF(renderer,canvas.texture(item.path),&item.crop,&dest),"Probe painting");}
}
void background_inputs(json_object* record,const std::vector<Painting>& art,SDL_FRect window,const ta::WorldProjection& p,SDL_Rect crop){
    auto* inputs=json_object_new_array();json_object_object_add(record,"inputs",inputs);
    for(const auto& item:art){SDL_FRect part{};if(!SDL_IntersectFRect(&window,&item.world,&part))continue;
        auto* input=json_object_new_object();json_object_array_add(inputs,input);text(input,"scene",item.id);text(input,"file",item.path.filename().string());text(input,"png_sha256",item.sha);
        rectangle(input,"world",item.world);rectangle(input,"source_crop",{float(item.crop.x),float(item.crop.y),float(item.crop.w),float(item.crop.h)});rectangle(input,"visible_world",part);
        rectangle(input,"visible_source_pixels",{item.crop.x+(part.x-item.world.x)/item.world.w*item.crop.w,item.crop.y+(part.y-item.world.y)/item.world.h*item.crop.h,part.w/item.world.w*item.crop.w,part.h/item.world.h*item.crop.h});
        const auto at=p.screen({item.world.x,item.world.y});rectangle(input,"submitted_destination",{float(at.x-crop.x),float(at.y-crop.y),float(item.world.w*p.pixels_per_cell),float(item.world.h*p.pixels_per_cell)});
    }
}
void background_geometry(json_object* record,ta::WorldPassages& passages,const ta::RailNetwork& network,const Mouth& mouth,const ta::WorldProjection& p){
    auto* outline=json_object_new_array();json_object_object_add(record,"portal_quads_world",outline);
    const ta::Point inner=ta::point(mouth.cell)-mouth.direction;
    double left=inner.x,top=inner.y,right=inner.x+1,bottom=inner.y+1;
    for(bool front:{false,true})for(const auto& piece:passages.portal_plan(network,p,front))if(piece.cell==mouth.cell){
        auto* item=json_object_new_object();text(item,"layer",front?"crown":"floor");auto* points=json_object_new_array();json_object_object_add(item,"points",points);json_object_array_add(outline,item);
        for(auto screen:piece.points){auto world=(screen-p.origin)*(1/p.pixels_per_cell);json_object_array_add(points,coords({world.x,world.y}));
            left=std::min(left,world.x);top=std::min(top,world.y);right=std::max(right,world.x);bottom=std::max(bottom,world.y);}
    }
    rectangle(record,"edit_envelope_world",{float(left),float(top),float(right-left),float(bottom-top)});
    text(record,"edit_envelope_provenance","Union of registered portal bounds and the immediately adjacent authoritative underground cell; proposed local terrain extent, not an applied mask");
    rectangle(record,"underground_neighbor_world",{float(inner.x),float(inner.y),1,1});
    const auto port=ta::point(mouth.cell)+ta::Point{.5,.5}+mouth.direction*.5;json_object_object_add(record,"surface_port_world",coords({port.x,port.y}));
    json_object_object_add(record,"cell",coords({double(mouth.cell.x),double(mouth.cell.y)}));json_object_object_add(record,"opening_direction",coords({mouth.direction.x,mouth.direction.y}));
}
void export_background(ta::Canvas& canvas,ta::WorldPassages& passages,const std::vector<Painting>& art,const ta::RailNetwork& network,const Mouth& mouth,const ta::WorldProjection& p,const Options& o,json_object* record,const std::string& prefix){
    if(o.background_context==0)return;
    // Owner19Oct2026 requests a tighter context, with camera/density unchanged.
    const double requested=o.background_context*o.density;
    require(std::isfinite(requested)&&requested>=1&&requested<=std::min(canvas.width(),canvas.height()),"Background context must fit existing viewport at requested density");
    const int side=int(std::lround(requested));SDL_Rect crop{(canvas.width()-side)/2,(canvas.height()-side)/2,side,side};
    const auto origin=(ta::Point{double(crop.x),double(crop.y)}-p.origin)*(1/p.pixels_per_cell);
    SDL_FRect world{float(origin.x),float(origin.y),float(crop.w/p.pixels_per_cell),float(crop.h/p.pixels_per_cell)};
    const auto output=o.output/(prefix+"-background.png");require(!fs::exists(output),"Background capture already exists");
    std::vector<Uint8> bytes(std::size_t(crop.w)*crop.h*4);ta::render_check(SDL_RenderReadPixels(canvas.renderer(),&crop,SDL_PIXELFORMAT_RGBA32,bytes.data(),crop.w*4),"Background crop pixels");
    png_image png{};png.version=PNG_IMAGE_VERSION;png.width=crop.w;png.height=crop.h;png.format=PNG_FORMAT_RGBA;
    const bool written=png_image_write_to_file(&png,output.string().c_str(),0,bytes.data(),0,nullptr)!=0;const std::string error=png.message;png_image_free(&png);if(!written)throw std::runtime_error("Background PNG: "+error);
    auto* item=json_object_new_object();json_object_object_add(record,"background",item);text(item,"id",prefix);text(item,"kind","mouth_background");text(item,"capture",output.filename().string());text(item,"capture_sha256",digest(output));
    rectangle(item,"world",world);json_object_object_add(item,"pixels",coords({double(crop.w),double(crop.h)}));json_object_object_add(item,"source_crop",coords({0,0,double(crop.w),double(crop.h)}));
    json_object_object_add(item,"crop_in_viewport",coords({double(crop.x),double(crop.y),double(crop.w),double(crop.h)}));
    text(item,"scope","Selected terrain pixels only; no rails, vehicle, arch or labels; original viewport camera and density");
    background_inputs(item,art,world,p,crop);background_geometry(item,passages,network,mouth,p);
}
void obstacle_checks(ta::WorldPassages& passages,const ta::RailNetwork& network,double density){
    // Bound the prepared plan to the named source fixtures at every density;
    // these coordinates are not the live application's viewport.
    const auto projection=[&](ta::Point center){return ta::WorldProjection{{-center.x*density,-center.y*density},density,{float(-2*density),float(-2*density),float(4*density),float(4*density)}};};
    auto plan=passages.obstacle_plan(network,projection({25.5,25.5}));const auto has=[&](ta::Cell cell){return std::any_of(plan.begin(),plan.end(),[&](const ta::PassagePiece& piece){return piece.cell==cell;});};
    require(network.tile({25,24})==67&&network.tile({25,25})==67&&network.tile({26,26})==67,"Amsterdam CARTE fixture changed");
    require(has({25,24})&&!has({25,25})&&!has({26,26}),"Broken obstacle rail layer must distinguish railway from geological continuation");
    require(network.tile({110,33})==-120&&ta::WorldPassages::owns_rails({110,33},-120)&&!ta::WorldPassages::owns_rails({110,32},-120),"Closed timed bridge rail exclusion must remain source-local");
    const auto bridge_projection=projection({110.5,33.5});plan=passages.obstacle_plan(network,bridge_projection);require(!has({110,33}),"Closed timed bridge must not draw bridge atlas");
    auto open=network;require(open.set_timed_bridge(-121),"Cannot stage source timed bridge open state");plan=passages.obstacle_plan(open,bridge_projection);require(has({110,33}),"Open timed bridge lost authored bridge rails");
}
SDL_FRect hero(ta::Canvas& canvas,const fs::path& assets,ta::Point center,ta::Point direction,const ta::WorldProjection& p){
    // View::load_vehicles accepted hero crop, fixed0.75-cell contact length.
    constexpr SDL_Rect source{178,48,438,1886};double height=.75*p.pixels_per_cell,width=height*438/1886;
    auto at=p.screen(center);SDL_FRect dest{float(at.x-width/2),float(at.y-height/2),float(width),float(height)};
    const double angle=std::atan2(direction.y,direction.x)*180/std::acos(-1.)-90;
    ta::render_check(SDL_RenderCopyExF(canvas.renderer(),canvas.texture(assets/"travel/locomotive-hero.png"),&source,&dest,angle,nullptr,SDL_FLIP_NONE),"Probe registered hero");
    if(direction.x!=0)return {float(at.x-height/2),float(at.y-width/2),float(height),float(width)};return dest;
}
std::vector<Uint8> pixels(ta::Canvas& canvas){
    std::vector<Uint8> bytes(std::size_t(canvas.width())*canvas.height()*4);
    ta::render_check(SDL_RenderReadPixels(canvas.renderer(),nullptr,SDL_PIXELFORMAT_RGBA32,bytes.data(),canvas.width()*4),"Probe pixels");return bytes;
}
std::size_t changed(const std::vector<Uint8>& a,const std::vector<Uint8>& b,int width,int height,SDL_FRect box){
    std::size_t count{};int left=std::clamp(int(std::floor(box.x)),0,width),right=std::clamp(int(std::ceil(box.x+box.w)),0,width);
    int top=std::clamp(int(std::floor(box.y)),0,height),bottom=std::clamp(int(std::ceil(box.y+box.h)),0,height);
    for(int y=top;y<bottom;++y)for(int x=left;x<right;++x){auto at=(std::size_t(y)*width+x)*4;
        if(!std::equal(a.begin()+at,a.begin()+at+4,b.begin()+at))++count;}return count;
}
std::size_t residual(const std::vector<Uint8>& floor,const std::vector<Uint8>& train,const std::vector<Uint8>& covered,const std::vector<Uint8>& reference){
    std::size_t count{};for(std::size_t at=0;at<floor.size();at+=4){
        const bool hero=!std::equal(floor.begin()+at,floor.begin()+at+4,train.begin()+at);
        if(hero&&!std::equal(reference.begin()+at,reference.begin()+at+4,covered.begin()+at))++count;
    }return count;
}
void registration(ta::WorldPassages& passages,const ta::RailNetwork& network,const Mouth& mouth,const ta::WorldProjection& p,const Options& o){
    auto floors=passages.portal_plan(network,p,false),crowns=passages.portal_plan(network,p,true);
    const auto match=[&](const ta::PassagePiece& piece){return piece.cell==mouth.cell&&piece.code==mouth.code;};
    const auto first=std::find_if(floors.begin(),floors.end(),match),last=std::find_if(crowns.begin(),crowns.end(),match);
    require(first!=floors.end()&&last!=crowns.end(),"Fixture portal floor or crown absent");
    const auto& floor=*first;const auto& crown=*last;
    require(floor.points[0]==crown.points[3]&&floor.points[1]==crown.points[2],"Portal split changed registered crown/floor boundary");
    Json doc(json_object_from_file((o.game/"assets/travel/terrain/underground-mouths.json").string().c_str()),json_object_put);require(bool(doc),"Missing source portal metadata");
    auto* frames=field(doc.get(),"frames");json_object* frame{};
    for(std::size_t i=0;i<json_object_array_length(frames);++i){auto* item=json_object_array_get_idx(frames,i);if(json_object_get_int(field(item,"code"))==mouth.code)frame=item;}
    require(frame!=nullptr,"Source frame absent");auto* endpoint=field(frame,"rail_endpoint");auto* crop=field(frame,"region");auto* anchor=field(frame,"mouth_anchor");ta::Point section;
    if(mouth.code==53)section=floor.points[3]+(floor.points[2]-floor.points[3])*(number(endpoint,0)/number(crop,2));
    else {double t=(number(endpoint,1)-number(anchor,1))/(number(crop,3)-number(anchor,1));section=mouth.code==54?floor.points[0]+(floor.points[3]-floor.points[0])*t:floor.points[1]+(floor.points[2]-floor.points[1])*t;}
    const auto expected=p.screen(ta::point(mouth.cell)+ta::Point{.5,.5}+mouth.direction*.5);
    // SDL vertices use float coordinates; source section must agree within that
    // representation's epsilon, before any native raster comparison.
    require(ta::distance(section,expected)<=std::numeric_limits<float>::epsilon(),"Measured external rail section missed original surface port");
}
void fixture(ta::Canvas& canvas,ta::WorldPassages& passages,ta::WorldVisual& rails,const std::vector<Painting>& art,const ta::RailNetwork& network,const Mouth& mouth,const Options& o,json_object* records){
    require(network.tile(mouth.cell)==mouth.code,"Mouth location does not match immutable CARTE");
    ta::Cell neighbor{mouth.cell.x-int(mouth.direction.x),mouth.cell.y-int(mouth.direction.y)};
    require(ta::WorldPassages::underground(network.tile(neighbor)),"Mouth underground neighbor mismatch");
    const auto center=ta::point(mouth.cell)+ta::Point{.5,.5};
    ta::WorldProjection p{{canvas.width()*.5-center.x*o.density,canvas.height()*.5-center.y*o.density},o.density,{0,0,float(canvas.width()),float(canvas.height())}};
    registration(passages,network,mouth,p,o);
    // Mouth midpoint intersects the arch. Inner boundary intersects one covered
    // neighbor, exercising clipped body visibility rather than midpoint alpha.
    auto train_center=center-mouth.direction*(o.placement=="inner"?.5:0);
    const std::string prefix="mouth-"+std::to_string(mouth.cell.x)+"-"+std::to_string(mouth.cell.y);
    const char* suffixes[]{"floor","train","cover","crown"};for(auto suffix:suffixes)require(!fs::exists(o.output/(prefix+"-"+suffix+".png")),"Capture already exists");
    auto* record=json_object_new_object();json_object_array_add(records,record);text(record,"prefix",prefix);json_object_object_add(record,"source_code",json_object_new_int(mouth.code));
    canvas.begin_frame();background(canvas,art,p);export_background(canvas,passages,art,network,mouth,p,o,record,prefix);
    passages.floor(network,p);rails.rails(network,p);canvas.capture(o.output/(prefix+"-floor.png"));auto before=pixels(canvas);
    // Repaint the same cover without a hero for an exact render-order oracle.
    // This avoids treating resampling differences from a second texture draw
    // as leaked vehicle pixels.
    passages.cover(network,p);auto reference_cover=pixels(canvas);
    background(canvas,art,p);passages.floor(network,p);rails.rails(network,p);
    auto train_box=hero(canvas,o.game/"assets",train_center,mouth.direction,p);canvas.capture(o.output/(prefix+"-train.png"));auto with_train=pixels(canvas);
    passages.cover(network,p);canvas.capture(o.output/(prefix+"-cover.png"));auto covered=pixels(canvas);
    passages.foreground(network,p);canvas.capture(o.output/(prefix+"-crown.png"));auto crowned=pixels(canvas);canvas.end_frame();SDL_RenderPresent(canvas.renderer());
    const auto train_pixels=changed(before,with_train,canvas.width(),canvas.height(),train_box),cover_pixels=changed(with_train,covered,canvas.width(),canvas.height(),train_box),crown_pixels=changed(covered,crowned,canvas.width(),canvas.height(),train_box);
    require(train_pixels>0,"Prepared hero drew no pixels");if(o.placement=="inner")require(cover_pixels>0,"Underground cover changed no pixels beneath train bounds");
    const auto remaining=residual(before,with_train,covered,reference_cover);json_object_object_add(record,"hero_changed_pixels_unrestored_after_cover",json_object_new_uint64(remaining));
    // At the inner border the entire0.75-cell hero is behind the registered
    // mouth plane. Compare only pixels actually changed by the hero, not its box.
    if(o.placement=="inner")require(remaining==0,"Hero reappears between underground cell and registered mouth plane");
    json_object_object_add(record,"train_bbox_changed",json_object_new_uint64(train_pixels));json_object_object_add(record,"cover_bbox_changed",json_object_new_uint64(cover_pixels));
    json_object_object_add(record,"crown_bbox_changed",json_object_new_uint64(crown_pixels));
}
int run(const Options& o){
    SDL_SetMainReady();require(SDL_Init(SDL_INIT_VIDEO)==0,SDL_GetError());struct Quit{~Quit(){SDL_Quit();}} quit;
    // Same1280x800 default as the actual native application.
    std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(SDL_CreateWindow("Passage prepared probe",0,0,1280,800,SDL_WINDOW_HIDDEN),SDL_DestroyWindow);require(bool(window),SDL_GetError());
    std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(SDL_CreateRenderer(window.get(),-1,o.renderer=="software"?SDL_RENDERER_SOFTWARE:SDL_RENDERER_ACCELERATED),SDL_DestroyRenderer);require(bool(renderer),SDL_GetError());
    ta::render_check(SDL_SetRenderDrawBlendMode(renderer.get(),SDL_BLENDMODE_BLEND),"Probe blend");ta::Canvas canvas(renderer.get(),o.font);
    ta::WorldPassages passages(canvas,o.game/"assets");ta::WorldVisual rails(canvas,o.game/"assets");auto art=paintings(passages,canvas,o.artwork);
    ta::RailNetwork network;std::string error;if(!network.load(o.game/"private-data/CARTE.FIC",error))throw std::runtime_error(error);const auto before=network.tiles();
    obstacle_checks(passages,network,o.density);
    Json report(json_object_new_object(),json_object_put);text(report.get(),"scope","Prepared floor/train/cover/crown sequence, not live traversal or artistic acceptance");
    text(report.get(),"placement",o.placement);text(report.get(),"artwork_directory",o.artwork.string());text(report.get(),"counter_scope","Changed pixels inside train bounding box, not an alpha-mask occlusion proof");
    text(report.get(),"format","transartica-world-passages-reference-v2");text(report.get(),"manifest_sha256",digest(o.artwork/"manifest.json"));text(report.get(),"source_map_sha256",digest(o.game/"private-data/CARTE.FIC"));
    json_object_object_add(report.get(),"background_context_cells_requested",json_object_new_double(o.background_context));
    text(report.get(),"obstacle_checks","Amsterdam25,24 rails present; geological25,25 and26,26 absent; timed110,33 closed has no rails, open has authored bridge");
    SDL_RendererInfo info{};ta::render_check(SDL_GetRendererInfo(renderer.get(),&info),"Probe renderer");text(report.get(),"renderer",info.name);
    auto* records=json_object_new_array();json_object_object_add(report.get(),"captures",records);json_object_object_add(report.get(),"pixels_per_cell",json_object_new_double(o.density));
    for(const auto& mouth:mouths)fixture(canvas,passages,rails,art,network,mouth,o,records);
    require(network.tiles()==before,"Passage drawing changed CARTE");require(json_object_to_file_ext((o.output/"world-passages.json").string().c_str(),report.get(),JSON_C_TO_STRING_PRETTY)>=0,"Cannot write passage receipt");
    std::cout<<"Six prepared passage captures; source network unchanged. "<<o.output<<'\n';return 0;
}
}
int main(int argc,char** argv){try{return run(options(argc,argv));}catch(const std::exception& error){std::cerr<<"PASSAGE PROBE FAILED: "<<error.what()<<'\n';return 1;}}
