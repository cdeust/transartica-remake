// SPDX-License-Identifier: MIT
// Typed archive section. Structural parse is detached; Controller restore also
// replays source continuation against staged wagons/enemies/origin before commit.
#include "launcher.hpp"
#include <json-c/json.h>
#include <charconv>
#include <cmath>
#include <limits>
#include <memory>
#include <stdexcept>
#include <cctype>
namespace transartica::launcher {
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
void shape(json_object* o,int n){if(!o||!json_object_is_type(o,json_type_object)||json_object_object_length(o)!=n)throw std::runtime_error("Invalid launcher object shape");}
json_object* get(json_object* o,const char* key){json_object* v{};if(!json_object_object_get_ex(o,key,&v))throw std::runtime_error(std::string("Missing launcher field ")+key);return v;}
int number(json_object* o){
    if(!o||!json_object_is_type(o,json_type_int))throw std::runtime_error("Launcher integer required");
    std::string_view text=json_object_get_string(o);int value{};auto r=std::from_chars(text.data(),text.data()+text.size(),value);
    if(r.ec!=std::errc{}||r.ptr!=text.data()+text.size())throw std::runtime_error("Launcher integer out of range");return value;
}
bool boolean(json_object* o){if(!o||!json_object_is_type(o,json_type_boolean))throw std::runtime_error("Launcher boolean required");return json_object_get_boolean(o);}
template<std::size_t N>std::array<int,N> read_array(json_object* o){
    if(!o||!json_object_is_type(o,json_type_array)||json_object_array_length(o)!=N)throw std::runtime_error("Invalid launcher array");
    std::array<int,N> a{};for(std::size_t i=0;i<N;++i)a[i]=number(json_object_array_get_idx(o,i));return a;
}
Cell read_cell(json_object* o){auto a=read_array<2>(o);return {a[0],a[1]};}
template<class T>json_object* array(const T& values){auto* a=json_object_new_array();for(auto v:values)json_object_array_add(a,json_object_new_int(v));return a;}
json_object* cell(Cell c){return array(std::array<int,2>{c.x,c.y});}
void add(json_object* o,const char* key,json_object* v){json_object_object_add(o,key,v);}
void add(json_object* o,const char* key,int n){add(o,key,json_object_new_int(n));}
void add(json_object* o,const char* key,bool b){add(o,key,json_object_new_boolean(b));}
Geometry read_geometry(json_object* o){
    shape(o,7);Geometry g;g.origin=read_cell(get(o,"origin"));g.delta=read_cell(get(o,"delta"));g.step=read_cell(get(o,"step"));g.count=number(get(o,"count"));g.target=number(get(o,"target"));g.group=number(get(o,"group"));
    auto* r=get(o,"record");if(r){auto a=read_array<8>(r);g.record=world::EnemyTrain{a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]};}return g;
}
json_object* encode_geometry(const Geometry& g){
    auto* o=json_object_new_object();add(o,"origin",cell(g.origin));add(o,"delta",cell(g.delta));add(o,"step",cell(g.step));add(o,"count",g.count);add(o,"target",g.target);add(o,"group",g.group);
    auto r=g.record;add(o,"record",r?array(std::array<int,8>{r->kind,r->dx,r->y,r->heading,r->phase,r->remainder,r->speed,r->strength}):nullptr);return o;
}
Model read_model(json_object* o){
    shape(o,14);Model m;m.bearing=number(get(o,"bearing"));m.digits=read_array<4>(get(o,"digits"));int phase=number(get(o,"phase"));if(phase<0||phase>8)throw std::runtime_error("Invalid launcher phase");m.phase=Phase(phase);
    m.cursor=number(get(o,"cursor"));m.ascent=number(get(o,"ascent"));m.ascent_step=number(get(o,"ascent_step"));if(auto* g=get(o,"geometry"))m.geometry=read_geometry(g);
    m.camera=read_cell(get(o,"camera"));m.scroll=read_cell(get(o,"scroll"));m.scroll_left=number(get(o,"scroll_left"));m.status=number(get(o,"status"));m.removed=boolean(get(o,"removed"));
    auto* a=get(o,"accumulator");if(!a||(!json_object_is_type(a,json_type_double)&&!json_object_is_type(a,json_type_int)))throw std::runtime_error("Invalid launcher accumulator");m.accumulator=json_object_get_double(a);
    if(number(get(o,"version"))!=1)throw std::runtime_error("Unsupported launcher model schema");
    if(m.bearing<0||m.bearing>31||!std::isfinite(m.accumulator)||m.accumulator<0||m.accumulator>=3.0/50)throw std::runtime_error("Invalid launcher scalar");
    for(auto d:m.digits)if(d<0||d>9)throw std::runtime_error("Invalid launcher digit");if(m.distance()<50)throw std::runtime_error("Invalid launcher distance");return m;
}
json_object* encode_model(const Model& m){
    auto* o=json_object_new_object();add(o,"version",1);add(o,"bearing",m.bearing);add(o,"digits",array(m.digits));add(o,"phase",int(m.phase));add(o,"cursor",m.cursor);add(o,"ascent",m.ascent);add(o,"ascent_step",m.ascent_step);
    add(o,"geometry",m.geometry?encode_geometry(*m.geometry):nullptr);add(o,"camera",cell(m.camera));add(o,"scroll",cell(m.scroll));add(o,"scroll_left",m.scroll_left);add(o,"status",m.status);add(o,"removed",m.removed);add(o,"accumulator",json_object_new_double(m.accumulator));return o;
}
}
std::string serialize_snapshot(const Snapshot& s){
    Json root(json_object_new_object(),json_object_put);add(root.get(),"version",1);add(root.get(),"active",s.active);add(root.get(),"visible",s.visible);add(root.get(),"paused",s.paused);add(root.get(),"state",s.state?encode_model(*s.state):nullptr);
    return json_object_to_json_string_ext(root.get(),JSON_C_TO_STRING_PLAIN);
}
bool parse_snapshot(std::string_view input,Snapshot& destination,std::string& error){
    try{
        if(input.size()>std::size_t(std::numeric_limits<int>::max()))throw std::runtime_error("Launcher section exceeds parser size");
        std::unique_ptr<json_tokener,decltype(&json_tokener_free)> tok(json_tokener_new(),json_tokener_free);json_tokener_set_flags(tok.get(),JSON_TOKENER_STRICT);
        Json root(json_tokener_parse_ex(tok.get(),input.data(),int(input.size())),json_object_put);
        if(!root||json_tokener_get_error(tok.get())!=json_tokener_success)throw std::runtime_error("Invalid launcher JSON");
        for(auto i=json_tokener_get_parse_end(tok.get());i<input.size();++i)if(!std::isspace(static_cast<unsigned char>(input[i])))throw std::runtime_error("Trailing launcher JSON");
        auto* o=root.get();shape(o,5);if(number(get(o,"version"))!=1)throw std::runtime_error("Unsupported launcher schema");
        Snapshot staged;staged.active=boolean(get(o,"active"));staged.visible=boolean(get(o,"visible"));staged.paused=boolean(get(o,"paused"));if(auto* m=get(o,"state"))staged.state=read_model(m);
        if(staged.active!=bool(staged.state)||(!staged.active&&(staged.visible||staged.paused)))throw std::runtime_error("Invalid launcher activity");
        destination=std::move(staged);error.clear();return true;
    }catch(const std::exception& e){error=e.what();return false;}
}
}
