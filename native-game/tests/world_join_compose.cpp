// SPDX-License-Identifier: MIT
// Offline authoring only. Registration: view/world.cpp + world_join_render.cpp.
// Edge alpha: game/scripts/world_artwork.gd::EDGE_SHADER (smoothstep perimeter).
// Artist supplies every edit rectangle, edge selection and feather width.
#include <png.h>
#include <json-c/json.h>
#include <openssl/evp.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs=std::filesystem;
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
struct Rect {double x{},y{},w{},h{};};
struct Crop {int x{},y{},w{},h{};};
struct Image {int width{},height{};std::vector<std::uint8_t> rgba;};
struct Region {std::string id,sha;fs::path path;Rect world;Crop crop;int width{},height{};json_object* background{};};
struct Patch {std::string id,sha,unit,sampling{"bilinear"};fs::path path;Rect world,edit;Crop crop;int width{},height{};double feather{};std::array<bool,4> edges{};std::vector<int> repaired_features;};
struct Protection {std::string id;Rect world;int feature_index{-1};};
struct Options {fs::path artwork,patches,output;};
json_object* member(json_object* object,const char* key) {
    json_object* value{};
    if(!object||!json_object_object_get_ex(object,key,&value))throw std::runtime_error(std::string("Missing field: ")+key);
    return value;
}
std::string str(json_object* value) {
    if(!value||!json_object_is_type(value,json_type_string))throw std::runtime_error("Expected string");
    return json_object_get_string(value);
}
double number(json_object* value) {
    if(!value||(!json_object_is_type(value,json_type_int)&&!json_object_is_type(value,json_type_double)))throw std::runtime_error("Expected number");
    const auto result=json_object_get_double(value);if(!std::isfinite(result))throw std::runtime_error("Nonfinite coordinate");return result;
}
void array_size(json_object* value,std::size_t count) {
    if(!value||!json_object_is_type(value,json_type_array)||json_object_array_length(value)!=count)throw std::runtime_error("Invalid array size");
}
int integer(double value) {
    if(value<0||value!=std::floor(value)||value>std::numeric_limits<int>::max())throw std::runtime_error("Invalid pixel integer");return int(value);
}
Rect rect(json_object* value) {
    array_size(value,4);Rect r{number(json_object_array_get_idx(value,0)),number(json_object_array_get_idx(value,1)),number(json_object_array_get_idx(value,2)),number(json_object_array_get_idx(value,3))};
    if(r.w<=0||r.h<=0||!std::isfinite(r.x+r.w)||!std::isfinite(r.y+r.h))throw std::runtime_error("Empty or overflowing rectangle");return r;
}
Crop crop(json_object* value) {const auto r=rect(value);return {integer(r.x),integer(r.y),integer(r.w),integer(r.h)};}
bool contains(Rect outer,Rect inner) {return inner.x>=outer.x&&inner.y>=outer.y&&inner.x+inner.w<=outer.x+outer.w&&inner.y+inner.h<=outer.y+outer.h;}
bool contains(Rect r,double x,double y) {return x>=r.x&&x<r.x+r.w&&y>=r.y&&y<r.y+r.h;}
bool intersects(Rect a,Rect b) {return a.x<b.x+b.w&&b.x<a.x+a.w&&a.y<b.y+b.h&&b.y<a.y+a.h;}
Json read_json(const fs::path& path) {Json value(json_object_from_file(path.string().c_str()),json_object_put);if(!value)throw std::runtime_error("Cannot read JSON: "+path.string());return value;}
void field(json_object* object,const char* key,const std::string& value) {json_object_object_add(object,key,json_object_new_string(value.c_str()));}
void field(json_object* object,const char* key,std::uint64_t value) {json_object_object_add(object,key,json_object_new_uint64(value));}
void boolean(json_object* object,const char* key,bool value) {json_object_object_add(object,key,json_object_new_boolean(value));}
json_object* coords(Rect r) {auto* a=json_object_new_array();for(double v:{r.x,r.y,r.w,r.h})json_object_array_add(a,json_object_new_double(v));return a;}
Json clone(json_object* value) {Json result(json_tokener_parse(json_object_to_json_string_ext(value,JSON_C_TO_STRING_PLAIN)),json_object_put);if(!result)throw std::runtime_error("Cannot clone metadata");return result;}
std::string finish(EVP_MD_CTX* state) {
    std::array<unsigned char,EVP_MAX_MD_SIZE> bytes{};unsigned count{};
    if(EVP_DigestFinal_ex(state,bytes.data(),&count)!=1)throw std::runtime_error("SHA256 finalization failed");
    std::ostringstream out;out<<std::hex<<std::setfill('0');for(unsigned i=0;i<count;++i)out<<std::setw(2)<<unsigned(bytes[i]);return out.str();
}
auto digest_state() {
    std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> state(EVP_MD_CTX_new(),EVP_MD_CTX_free);
    if(!state||EVP_DigestInit_ex(state.get(),EVP_sha256(),nullptr)!=1)throw std::runtime_error("SHA256 init failed");return state;
}
std::string digest(const fs::path& path) {
    std::ifstream input(path,std::ios::binary);if(!input)throw std::runtime_error("Cannot hash: "+path.string());auto state=digest_state();
    std::array<char,8192> bytes{}; // Same streaming buffer as platform/hash.cpp.
    while(input) {input.read(bytes.data(),bytes.size());if(EVP_DigestUpdate(state.get(),bytes.data(),std::size_t(input.gcount()))!=1)throw std::runtime_error("SHA256 update failed");}
    if(!input.eof())throw std::runtime_error("SHA256 read failed");return finish(state.get());
}
std::string digest(const std::vector<std::uint8_t>& bytes) {auto state=digest_state();if(EVP_DigestUpdate(state.get(),bytes.data(),bytes.size())!=1)throw std::runtime_error("RGBA digest failed");return finish(state.get());}
void verify(const fs::path& path,const std::string& sha) {
    if(sha.size()!=64||sha.find_first_not_of("0123456789abcdef")!=std::string::npos||digest(path)!=sha)throw std::runtime_error("SHA256 mismatch: "+path.string());
}
struct Png {
    png_image image{};
    explicit Png(const fs::path& path) {image.version=PNG_IMAGE_VERSION;if(!png_image_begin_read_from_file(&image,path.string().c_str())){const std::string error=image.message;png_image_free(&image);throw std::runtime_error("PNG header: "+path.string()+": "+error);}}
    ~Png(){png_image_free(&image);}
};
void dimensions(const fs::path& path,int width,int height,Crop c) {
    Png png(path);
    if(width<=0||height<=0||png.image.width!=unsigned(width)||png.image.height!=unsigned(height)||c.w<=0||c.h<=0||c.x>width-c.w||c.y>height-c.h)throw std::runtime_error("PNG dimensions/crop mismatch: "+path.string());
}
Image decode(const fs::path& path) {
    Png png(path);png.image.format=PNG_FORMAT_RGBA;
    // Match Canvas's existing per-image allocation policy, not a new art limit.
    if(png.image.width>std::numeric_limits<int>::max()||png.image.height>std::numeric_limits<int>::max()||PNG_IMAGE_SIZE(png.image)>64U*1024U*1024U)throw std::runtime_error("PNG exceeds Canvas allocation budget");
    Image result{int(png.image.width),int(png.image.height),std::vector<std::uint8_t>(PNG_IMAGE_SIZE(png.image))};
    if(!png_image_finish_read(&png.image,nullptr,result.rgba.data(),0,nullptr))throw std::runtime_error("PNG decode: "+std::string(png.image.message));return result;
}
void write_png(const fs::path& path,const Image& image) {
    png_image png{};png.version=PNG_IMAGE_VERSION;png.width=image.width;png.height=image.height;png.format=PNG_FORMAT_RGBA;
    const bool ok=png_image_write_to_file(&png,path.string().c_str(),0,image.rgba.data(),0,nullptr)!=0;
    const std::string error=png.message;png_image_free(&png);if(!ok)throw std::runtime_error("PNG write: "+error);
}
std::pair<int,int> size(json_object* object) {array_size(object,2);return {integer(number(json_object_array_get_idx(object,0))),integer(number(json_object_array_get_idx(object,1)))};}
fs::path relative_file(const fs::path& base,const std::string& name) {
    const fs::path path(name);if(path.empty()||path.is_absolute())throw std::runtime_error("Expected relative patch resource");
    for(const auto& part:path)if(part=="..")throw std::runtime_error("Parent traversal in patch resource");return base/path;
}
Options options(int argc,char** argv) {
    Options result;
    for(int i=1;i<argc;++i) {
        const std::string flag=argv[i];
        if(flag=="--help"){std::cout<<"world_join_compose --artwork-dir ORIGINAL_DIR --patch-manifest FILE --output-dir EMPTY_EXISTING_DIR\n";return {};}
        if(++i==argc)throw std::runtime_error("Missing value for "+flag);
        if(flag=="--artwork-dir")result.artwork=argv[i];else if(flag=="--patch-manifest")result.patches=argv[i];else if(flag=="--output-dir")result.output=argv[i];else throw std::runtime_error("Unknown option: "+flag);
    }
    if(!fs::is_directory(result.artwork)||!fs::is_regular_file(result.patches)||!fs::is_directory(result.output)||!fs::is_empty(result.output))throw std::runtime_error("Require original artwork, patch manifest and empty existing output directory");
    return result;
}
std::vector<Region> regions(json_object* manifest,const fs::path& directory,Rect& bounds) {
    if(number(member(manifest,"schema"))!=1)throw std::runtime_error("Require schema1 affine source paintings");
    auto* scenes=member(manifest,"scenes");if(!json_object_is_type(scenes,json_type_array)||!json_object_array_length(scenes))throw std::runtime_error("Empty scenes");
    std::vector<Region> result;std::set<std::string> ids,filenames;
    double left=std::numeric_limits<double>::infinity(),top=left,right=-left,bottom=-left;
    for(std::size_t i=0;i<json_object_array_length(scenes);++i) {
        auto* scene=json_object_array_get_idx(scenes,i);Region r;r.id=str(member(scene,"id"));r.world=rect(member(scene,"world"));
        if(r.id.empty()||!ids.insert(r.id).second||str(member(scene,"registration"))!="region_bounds")throw std::runtime_error("Invalid scene identity/registration");
        // Match View's SDL_FRect storage before inverse projection.
        r.world={float(r.world.x),float(r.world.y),float(r.world.w),float(r.world.h)};
        auto* variants=member(scene,"variants");array_size(variants,1);auto* variant=json_object_array_get_idx(variants,0);
        r.crop=crop(member(variant,"source_crop"));const auto declared=size(member(variant,"size"));r.width=declared.first;r.height=declared.second;
        r.background=member(variant,"background");const auto filename=fs::path(str(member(r.background,"image"))).filename();
        if(filename.empty()||filename=="manifest.json"||filename=="composition-receipt.json"||!filenames.insert(filename.string()).second)throw std::runtime_error("Invalid/duplicate painting filename");
        r.path=directory/filename;r.sha=str(member(r.background,"png_sha256"));verify(r.path,r.sha);dimensions(r.path,r.width,r.height,r.crop);
        for(const auto& previous:result)if(intersects(previous.world,r.world))throw std::runtime_error("Overlapping base paintings");
        left=std::min(left,r.world.x);top=std::min(top,r.world.y);right=std::max(right,r.world.x+r.world.w);bottom=std::max(bottom,r.world.y+r.world.h);result.push_back(r);
    }
    bounds={left,top,right-left,bottom-top};return result;
}
std::vector<Patch> patches(json_object* spec,const fs::path& directory,Rect bounds) {
    auto* items=member(spec,"patches");if(!json_object_is_type(items,json_type_array)||!json_object_array_length(items))throw std::runtime_error("No patches");
    std::vector<Patch> result;std::set<std::string> ids;
    for(std::size_t i=0;i<json_object_array_length(items);++i) {
        auto* item=json_object_array_get_idx(items,i);Patch p;p.id=str(member(item,"id"));if(p.id.empty()||!ids.insert(p.id).second)throw std::runtime_error("Duplicate/empty patch id");
        p.path=relative_file(directory,str(member(item,"image")));p.sha=str(member(item,"png_sha256"));verify(p.path,p.sha);
        p.world=rect(member(item,"world"));p.edit=rect(member(item,"edit_world"));p.crop=crop(member(item,"source_crop"));
        if(!contains(bounds,p.world)||!contains(p.world,p.edit))throw std::runtime_error("Patch/edit outside source world");
        const auto declared=size(member(item,"size"));p.width=declared.first;p.height=declared.second;dimensions(p.path,p.width,p.height,p.crop);
        json_object* sampling{};if(json_object_object_get_ex(item,"sampling",&sampling))p.sampling=str(sampling);
        if(p.sampling!="bilinear"&&p.sampling!="area-v1")throw std::runtime_error("Unknown patch sampling");
        auto* feather=member(item,"feather");p.feather=number(member(feather,"width"));p.unit=str(member(feather,"unit"));
        if(p.feather<0||(p.unit!="source_pixels"&&p.unit!="world")||str(member(feather,"exterior_world"))!="opaque")throw std::runtime_error("Invalid feather policy");
        auto* edges=member(feather,"edges");if(!json_object_is_type(edges,json_type_array))throw std::runtime_error("Expected feather edge list");
        for(std::size_t j=0;j<json_object_array_length(edges);++j) {
            const auto name=str(json_object_array_get_idx(edges,j));const std::array<std::string,4> names{"left","right","top","bottom"};
            const auto found=std::find(names.begin(),names.end(),name);if(found==names.end()||p.edges[std::size_t(found-names.begin())])throw std::runtime_error("Invalid/duplicate feather edge");p.edges[std::size_t(found-names.begin())]=true;
        }
        // An exterior world edge has no underlying neighbour to blend toward.
        if(p.edit.x==bounds.x)p.edges[0]=false;if(p.edit.x+p.edit.w==bounds.x+bounds.w)p.edges[1]=false;
        if(p.edit.y==bounds.y)p.edges[2]=false;if(p.edit.y+p.edit.h==bounds.y+bounds.h)p.edges[3]=false;
        result.push_back(p);
    }
    return result;
}
double feather(const Patch& p,double x,double y) {
    if(p.feather==0)return 1;
    const double sx=p.unit=="source_pixels"?p.crop.w/p.world.w:1,sy=p.unit=="source_pixels"?p.crop.h/p.world.h:1;
    const std::array<double,4> distances{(x-p.edit.x)*sx,(p.edit.x+p.edit.w-x)*sx,(y-p.edit.y)*sy,(p.edit.y+p.edit.h-y)*sy};
    double edge=std::numeric_limits<double>::infinity();for(std::size_t i=0;i<4;++i)if(p.edges[i])edge=std::min(edge,distances[i]);
    // GLSL smoothstep: t*t*(3-2*t), as used by world_artwork.gd::EDGE_SHADER.
    const double t=std::clamp(edge/p.feather,0.,1.);return t*t*(3-2*t);
}
std::array<double,4> sample(const Image& image,const Patch& p,double x,double y) {
    // Inverse of View's affine crop->world mapping. Integer pixel centres are
    // shifted by 0.5, then bilinear weights; clamp taps to the selected crop.
    const double u=std::clamp(p.crop.x+(x-p.world.x)*p.crop.w/p.world.w-.5,double(p.crop.x),double(p.crop.x+p.crop.w-1));
    const double v=std::clamp(p.crop.y+(y-p.world.y)*p.crop.h/p.world.h-.5,double(p.crop.y),double(p.crop.y+p.crop.h-1));
    const int x0=int(std::floor(u)),y0=int(std::floor(v)),x1=std::min(x0+1,p.crop.x+p.crop.w-1),y1=std::min(y0+1,p.crop.y+p.crop.h-1);
    const double tx=u-x0,ty=v-y0;std::array<double,4> value{};
    for(std::size_t c=0;c<4;++c) {
        const auto at=[&](int px,int py){return double(image.rgba[(std::size_t(py)*image.width+px)*4+c]);};
        value[c]=(at(x0,y0)*(1-tx)+at(x1,y0)*tx)*(1-ty)+(at(x0,y1)*(1-tx)+at(x1,y1)*tx)*ty;
    }
    return value;
}
std::array<double,4> sample_area(const Image& image,const Patch& p,Rect cell) {
    // Pixel-area overlap weights: OpenCV resize.cpp::computeResizeAreaTab
    // https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/resize.cpp
    // Each source texel is a unit square. Integrate the actual inverse-mapped
    // destination footprint, not a guessed filter radius. Preserve bilinear
    // behavior when neither axis is minified (source footprint <= one texel).
    const double sx=p.crop.w/p.world.w,sy=p.crop.h/p.world.h;
    if(cell.w*sx<=1&&cell.h*sy<=1)return sample(image,p,cell.x+cell.w*.5,cell.y+cell.h*.5);
    const double left=std::clamp(p.crop.x+(cell.x-p.world.x)*sx,double(p.crop.x),double(p.crop.x+p.crop.w));
    const double top=std::clamp(p.crop.y+(cell.y-p.world.y)*sy,double(p.crop.y),double(p.crop.y+p.crop.h));
    const double right=std::clamp(p.crop.x+(cell.x+cell.w-p.world.x)*sx,double(p.crop.x),double(p.crop.x+p.crop.w));
    const double bottom=std::clamp(p.crop.y+(cell.y+cell.h-p.world.y)*sy,double(p.crop.y),double(p.crop.y+p.crop.h));
    const double area=(right-left)*(bottom-top);
    if(area<=0)throw std::runtime_error("Empty source sampling footprint");
    std::array<double,4> value{};
    for(int y=int(std::floor(top));y<int(std::ceil(bottom));++y) {
        const double height=std::min(bottom,double(y+1))-std::max(top,double(y));
        for(int x=int(std::floor(left));x<int(std::ceil(right));++x) {
            const double weight=height*(std::min(right,double(x+1))-std::max(left,double(x)));
            const auto index=(std::size_t(y)*image.width+x)*4;
            // Premultiply before accumulation; transparent RGB contributes no
            // color. W3C Compositing1 section5.1: cs=Cs*alpha, Cs=cs/alpha.
            // https://www.w3.org/TR/compositing-1/#simplealphacompositing
            const double opacity=image.rgba[index+3]*weight;
            for(std::size_t c=0;c<3;++c)value[c]+=image.rgba[index+c]*opacity;
            value[3]+=opacity;
        }
    }
    if(value[3]>0)for(std::size_t c=0;c<3;++c)value[c]/=value[3];
    value[3]/=area;return value;
}
std::uint8_t byte(double value){return std::uint8_t(std::clamp(std::lround(value),0L,255L));}
Rect texel_world(const Region& r,int x,int y) {return {r.world.x+(x-r.crop.x)*r.world.w/r.crop.w,r.world.y+(y-r.crop.y)*r.world.h/r.crop.h,r.world.w/r.crop.w,r.world.h/r.crop.h};}
struct Counts {std::uint64_t changed{},outside{},protected_count{},repair_eligible{},repair_changed{};};
struct PixelPermissions {std::vector<std::uint8_t> allowed,protected_pixels,repair_eligible;};
struct PatchAccess {PixelPermissions& permissions;const std::vector<std::uint8_t>& blocked;};
struct Composition {
    Options options;
    fs::path manifest_path,inventory_path;
    Json manifest{nullptr,json_object_put},spec{nullptr,json_object_put},inventory{nullptr,json_object_put},report{nullptr,json_object_put};
    std::string manifest_sha,spec_sha,inventory_sha;
    Rect bounds;
    std::vector<Region> base;
    std::vector<Patch> edits;
    std::vector<Protection> protected_areas;
    json_object* outputs{};
    Counts totals;
};
Composition load_composition(const Options& options) {
    Composition c;c.options=options;c.manifest_path=options.artwork/"manifest.json";
    c.manifest=read_json(c.manifest_path);c.spec=read_json(options.patches);
    if(number(member(c.spec.get(),"schema"))!=1)throw std::runtime_error("Unsupported patch schema");
    c.manifest_sha=str(member(c.spec.get(),"source_manifest_sha256"));c.spec_sha=digest(options.patches);
    verify(c.manifest_path,c.manifest_sha);
    c.base=regions(c.manifest.get(),options.artwork,c.bounds);c.edits=patches(c.spec.get(),options.patches.parent_path(),c.bounds);
    auto* inventory_spec=member(c.spec.get(),"city_inventory");c.inventory_path=relative_file(options.patches.parent_path(),str(member(inventory_spec,"file")));
    c.inventory_sha=str(member(inventory_spec,"sha256"));verify(c.inventory_path,c.inventory_sha);c.inventory=read_json(c.inventory_path);
    if(str(member(c.inventory.get(),"source_map_sha256"))!=str(member(c.manifest.get(),"source_map_sha256")))throw std::runtime_error("Inventory/CARTE identity mismatch");
    const auto map_size=size(member(c.inventory.get(),"dimensions"));
    if(c.bounds.x!=0||c.bounds.y!=0||c.bounds.w!=map_size.first||c.bounds.h!=map_size.second)throw std::runtime_error("Artwork bounds differ from source inventory");
    return c;
}
Json load_protections(Composition& c) {
    auto* features=member(c.inventory.get(),"features");if(!json_object_is_type(features,json_type_array))throw std::runtime_error("Invalid city inventory features");
    Json protection_report(json_object_new_array(),json_object_put);
    for(std::size_t i=0;i<json_object_array_length(features);++i) {
        auto* feature=json_object_array_get_idx(features,i);json_object* cities{};
        if(!json_object_object_get_ex(feature,"city_records",&cities))continue;
        if(!json_object_is_type(cities,json_type_array))throw std::runtime_error("Invalid city records");if(!json_object_array_length(cities))continue;
        const auto world=rect(member(feature,"world"));if(!contains(c.bounds,world))throw std::runtime_error("City bounds outside world");
        c.protected_areas.push_back({"inventory-feature-"+std::to_string(i),world,int(i)});json_object_array_add(protection_report.get(),clone(feature).release());
    }
    if(c.protected_areas.empty())throw std::runtime_error("Inventory contains no city protection");
    json_object* extra{};if(json_object_object_get_ex(c.spec.get(),"protected_world",&extra)) {
        if(!json_object_is_type(extra,json_type_array))throw std::runtime_error("Invalid protected_world");
        for(std::size_t i=0;i<json_object_array_length(extra);++i) {
            auto* area=json_object_array_get_idx(extra,i);const auto world=rect(member(area,"world"));if(!contains(c.bounds,world))throw std::runtime_error("Protected silhouette outside world");c.protected_areas.push_back({str(member(area,"id")),world});
        }
    }
    return protection_report;
}
bool city_identity_matches(json_object* request,json_object* cities) {
    const int source_index=integer(number(member(request,"city_source_index")));
    const auto name=str(member(request,"city_name"));auto* anchor=member(request,"anchor");array_size(anchor,2);
    if(!json_object_is_type(cities,json_type_array))throw std::runtime_error("Invalid city repair feature");
    for(std::size_t i=0;i<json_object_array_length(cities);++i) {
        auto* city=json_object_array_get_idx(cities,i);json_object* source{};
        if(!json_object_object_get_ex(city,"source_index",&source)||number(source)!=source_index||str(member(city,"name"))!=name)continue;
        auto* recorded=member(city,"anchor");array_size(recorded,2);
        if(number(json_object_array_get_idx(anchor,0))==number(json_object_array_get_idx(recorded,0))&&
           number(json_object_array_get_idx(anchor,1))==number(json_object_array_get_idx(recorded,1)))return true;
    }
    return false;
}
Json load_city_repairs(Composition& c) {
    Json report(json_object_new_array(),json_object_put);
    auto* features=member(c.inventory.get(),"features");auto* patches=member(c.spec.get(),"patches");
    for(std::size_t i=0;i<c.edits.size();++i) {
        auto& patch=c.edits[i];json_object* repairs{};
        if(!json_object_object_get_ex(json_object_array_get_idx(patches,i),"city_repairs",&repairs))continue;
        if(!json_object_is_type(repairs,json_type_array))throw std::runtime_error("Invalid city_repairs list");
        std::set<int> unique;
        for(std::size_t j=0;j<json_object_array_length(repairs);++j) {
            auto* request=json_object_array_get_idx(repairs,j);const int index=integer(number(member(request,"feature_index")));
            if(std::size_t(index)>=json_object_array_length(features)||!unique.insert(index).second)throw std::runtime_error("Unknown/duplicate city repair feature");
            auto* feature=json_object_array_get_idx(features,index);json_object* cities{};
            if(!json_object_object_get_ex(feature,"city_records",&cities)||!city_identity_matches(request,cities))throw std::runtime_error("City repair identity mismatch");
            if(!intersects(rect(member(feature,"world")),patch.edit))throw std::runtime_error("City repair outside patch edit");
            if(str(member(request,"reason")).find_first_not_of(" \t\r\n")==std::string::npos)throw std::runtime_error("Empty city repair reason");
            patch.repaired_features.push_back(index);
            auto resolved=clone(request);field(resolved.get(),"patch_id",patch.id);
            json_object_object_add(resolved.get(),"inventory_feature",clone(feature).release());
            json_object_array_add(report.get(),resolved.release());
        }
    }
    return report;
}
void initialize_report(Composition& c,Json protection_report,Json repair_report) {
    c.report=Json(json_object_new_object(),json_object_put);auto* report=c.report.get();
    field(report,"format","transartica-world-join-composition-v1");
    field(report,"source_manifest_sha256",c.manifest_sha);field(report,"patch_manifest_sha256",c.spec_sha);field(report,"city_inventory_sha256",c.inventory_sha);
    field(report,"source_artwork",c.options.artwork.string());field(report,"patch_manifest",c.options.patches.string());field(report,"city_inventory",c.inventory_path.string());
    field(report,"source_map_sha256",str(member(c.manifest.get(),"source_map_sha256")));
    field(report,"sampling","Per-patch sampling, default bilinear at inverse-affine texel centres. Optional area-v1 integrates exact projected texel footprints with premultiplied alpha during minification; otherwise bilinear. Crop-clamped, encoded RGB, SDL source-over, nearest RGBA8 rounding. No claim of backend bit parity.");
    field(report,"preservation_scope","Exact decoded RGBA outside edit_world texel centres; source city bounds remain exact except authenticated per-patch city_repairs. Explicit protected_world always remains exact. City silhouettes outside supplied bounds require artist review.");
    json_object_object_add(report,"artist_specification",clone(c.spec.get()).release());json_object_object_add(report,"protected_city_features",protection_report.release());
    json_object_object_add(report,"authorized_city_repairs",repair_report.release());
    // These records have anchors but no decoded footprint: do not invent bounds
    // or claim their silhouettes were certified by the footprint comparison.
    json_object* unmatched{};
    if(json_object_object_get_ex(c.inventory.get(),"city_records_without_town_footprint",&unmatched))
        json_object_object_add(report,"city_records_without_source_bounds",clone(unmatched).release());
    c.outputs=json_object_new_array();json_object_object_add(report,"regions",c.outputs);
}
std::vector<std::uint8_t> protection_pixels(const Region& region,const Image& image,const std::vector<Protection>& areas,const std::vector<int>& repaired_features={}) {
        std::vector<std::uint8_t> protected_pixels(std::size_t(image.width)*image.height);
        std::vector<Protection> relevant;
        for(const auto& area:areas) {
            // Only an authenticated inventory feature can be waived. Explicit
            // protected_world entries and overlapping unlisted cities still win.
            const bool repaired=area.feature_index>=0&&std::find(repaired_features.begin(),repaired_features.end(),area.feature_index)!=repaired_features.end();
            if(!repaired&&intersects(region.world,area.world))relevant.push_back(area);
        }
        for(int y=region.crop.y;y<region.crop.y+region.crop.h;++y)for(int x=region.crop.x;x<region.crop.x+region.crop.w;++x) {
            const auto cell=texel_world(region,x,y);for(const auto& area:relevant)if(intersects(cell,area.world)){protected_pixels[std::size_t(y)*image.width+x]=1;break;}
        }
        return protected_pixels;
}
void apply_patch(const Region& region,const Patch& patch,Image& image,PatchAccess access) {
            if(!intersects(region.world,patch.edit))return;verify(patch.path,patch.sha);auto raster=decode(patch.path);
            const auto clip_x=[&](double value){return std::clamp(value,double(region.crop.x),double(region.crop.x+region.crop.w));};
            const auto clip_y=[&](double value){return std::clamp(value,double(region.crop.y),double(region.crop.y+region.crop.h));};
            const int x0=int(std::floor(clip_x(region.crop.x+(patch.edit.x-region.world.x)*region.crop.w/region.world.w)));
            const int x1=int(std::ceil(clip_x(region.crop.x+(patch.edit.x+patch.edit.w-region.world.x)*region.crop.w/region.world.w)));
            const int y0=int(std::floor(clip_y(region.crop.y+(patch.edit.y-region.world.y)*region.crop.h/region.world.h)));
            const int y1=int(std::ceil(clip_y(region.crop.y+(patch.edit.y+patch.edit.h-region.world.y)*region.crop.h/region.world.h)));
            for(int y=y0;y<y1;++y)for(int x=x0;x<x1;++x) {
                const auto cell=texel_world(region,x,y);const double wx=cell.x+cell.w*.5,wy=cell.y+cell.h*.5;if(!contains(patch.edit,wx,wy))continue;
                const auto index=std::size_t(y)*image.width+x;auto& permissions=access.permissions;
                permissions.allowed[index]=1;if(access.blocked[index])continue;
                const auto src=patch.sampling=="area-v1"?sample_area(raster,patch,cell):sample(raster,patch,wx,wy);
                // PNG_FORMAT_RGBA stores alpha in8bits;255 is full coverage.
                const double alpha=src[3]/255*feather(patch,wx,wy);if(alpha==0)continue;
                if(permissions.protected_pixels[index])permissions.repair_eligible[index]=1;
                // SDL2 SDL_blendmode.h::SDL_BLENDMODE_BLEND equations: srcRGB*srcA +
                // dstRGB*(1-srcA); dstA=srcA+dstA*(1-srcA), straight alpha.
                for(std::size_t c=0;c<3;++c)image.rgba[index*4+c]=byte(src[c]*alpha+image.rgba[index*4+c]*(1-alpha));
                image.rgba[index*4+3]=byte(255*alpha+image.rgba[index*4+3]*(1-alpha));
            }
}
Counts validate_pixels(const std::vector<std::uint8_t>& original,const Image& image,const PixelPermissions& permissions) {
        Counts counts;
        for(std::size_t i=0;i<permissions.allowed.size();++i) {
            const bool equal=std::equal(original.begin()+i*4,original.begin()+i*4+4,image.rgba.begin()+i*4);
            if(!permissions.allowed[i]){++counts.outside;if(!equal)throw std::runtime_error("Pixels changed outside patch footprint");}
            if(permissions.repair_eligible[i]){++counts.repair_eligible;if(!equal)++counts.repair_changed;}
            else if(permissions.protected_pixels[i]){++counts.protected_count;if(!equal)throw std::runtime_error("Protected city/silhouette pixel changed");}
            if(!equal)++counts.changed;
        }
        return counts;
}
void save_region(Composition& c,Region& region,const Image& image,const std::vector<std::uint8_t>& original,Counts counts) {
        // Verify the original raw-RGBA contract too, not just compressed bytes.
        const auto source_rgba=digest(original);json_object* declared_rgba{};
        if(json_object_object_get_ex(region.background,"rgba_sha256",&declared_rgba)&&source_rgba!=str(declared_rgba))throw std::runtime_error("Source RGBA hash mismatch: "+region.id);
        const auto output=c.options.output/region.path.filename();
        if(counts.changed)write_png(output,image);else fs::copy_file(region.path,output,fs::copy_options::none);
        // Re-decode the saved PNG: receipt checks the deliverable, not only RAM.
        const auto saved=decode(output);if(saved.width!=image.width||saved.height!=image.height||saved.rgba!=image.rgba)throw std::runtime_error("Written PNG differs from validated RGBA");
        const auto output_sha=digest(output),output_rgba=digest(saved.rgba);field(region.background,"png_sha256",output_sha);field(region.background,"rgba_sha256",output_rgba);
        auto* item=json_object_new_object();json_object_array_add(c.outputs,item);field(item,"scene",region.id);field(item,"file",output.filename().string());json_object_object_add(item,"world",coords(region.world));
        field(item,"source_png_sha256",region.sha);field(item,"source_rgba_sha256",source_rgba);field(item,"png_sha256",output_sha);field(item,"rgba_sha256",output_rgba);
        field(item,"width",std::uint64_t(image.width));field(item,"height",std::uint64_t(image.height));field(item,"changed_texels",counts.changed);field(item,"unchanged_outside_footprint_texels",counts.outside);field(item,"unchanged_protected_texels",counts.protected_count);
        field(item,"repair_eligible_texels",counts.repair_eligible);field(item,"repaired_city_texels",counts.repair_changed);
        c.totals.changed+=counts.changed;c.totals.outside+=counts.outside;c.totals.protected_count+=counts.protected_count;
        c.totals.repair_eligible+=counts.repair_eligible;c.totals.repair_changed+=counts.repair_changed;
}
void compose_region(Composition& c,Region& region) {
    verify(region.path,region.sha);auto image=decode(region.path);const auto original=image.rgba;
    const auto count=std::size_t(image.width)*image.height;
    PixelPermissions permissions{std::vector<std::uint8_t>(count),protection_pixels(region,image,c.protected_areas),std::vector<std::uint8_t>(count)};
    for(const auto& patch:c.edits) {
        if(!intersects(region.world,patch.edit))continue;
        if(patch.repaired_features.empty())apply_patch(region,patch,image,{permissions,permissions.protected_pixels});
        else {
            const auto blocked=protection_pixels(region,image,c.protected_areas,patch.repaired_features);
            apply_patch(region,patch,image,{permissions,blocked});
        }
    }
    save_region(c,region,image,original,validate_pixels(original,image,permissions));
}
void verify_inputs(const Composition& c) {
    // Refuse a success receipt if another author changed any input while baking.
    verify(c.manifest_path,c.manifest_sha);verify(c.options.patches,c.spec_sha);verify(c.inventory_path,c.inventory_sha);
    for(const auto& region:c.base)verify(region.path,region.sha);
    for(const auto& patch:c.edits)verify(patch.path,patch.sha);
}
void finish_composition(Composition& c) {
    const auto output_manifest=c.options.output/"manifest.json";
    if(json_object_to_file_ext(output_manifest.string().c_str(),c.manifest.get(),JSON_C_TO_STRING_PRETTY|JSON_C_TO_STRING_NOSLASHESCAPE)<0)throw std::runtime_error("Cannot write candidate manifest");
    auto* report=c.report.get();field(report,"candidate_manifest_sha256",digest(output_manifest));field(report,"changed_texels",c.totals.changed);field(report,"unchanged_outside_footprint_texels",c.totals.outside);field(report,"unchanged_protected_texels",c.totals.protected_count);
    field(report,"repair_eligible_texels",c.totals.repair_eligible);field(report,"repaired_city_texels",c.totals.repair_changed);
    boolean(report,"outside_footprints_exact",true);boolean(report,"protected_bounds_exact",c.totals.repair_changed==0);
    boolean(report,"unapproved_protected_bounds_exact",true);boolean(report,"artistic_validation",false);boolean(report,"native_render_validation",false);
    if(json_object_to_file_ext((c.options.output/"composition-receipt.json").string().c_str(),report,JSON_C_TO_STRING_PRETTY|JSON_C_TO_STRING_NOSLASHESCAPE)<0)throw std::runtime_error("Cannot write composition receipt");
    std::cout<<"Candidate paintings: "<<c.base.size()<<"; changed texels: "<<c.totals.changed<<"; "<<c.options.output<<'\n';
}
int run(const Options& options) {
    if(options.artwork.empty())return 0;
    auto composition=load_composition(options);
    auto protections=load_protections(composition);auto repairs=load_city_repairs(composition);
    initialize_report(composition,std::move(protections),std::move(repairs));
    for(auto& region:composition.base)compose_region(composition,region);
    verify_inputs(composition);finish_composition(composition);return 0;
}
}
int main(int argc,char** argv) {
    try{return run(options(argc,argv));}catch(const std::exception& error){std::cerr<<"WORLD JOIN COMPOSITION FAILED: "<<error.what()<<"\nOutput, if any, is an incomplete candidate; preserve for inspection.\n";return 1;}
}
