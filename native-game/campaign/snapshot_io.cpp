// SPDX-License-Identifier: MIT
// Typed standalone schema for campaign_snapshot.gd domains. All parsing stages
// into detached objects; State/Snapshot validation occurs before assignment.
#include "controller.hpp"
#include <json-c/json.h>
#include <charconv>
#include <cctype>
#include <limits>
#include <memory>
#include <stdexcept>
namespace transartica::campaign {
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
json_object* object() {return json_object_new_object();}
void add(json_object* o,const char* key,json_object* value) {json_object_object_add(o,key,value);}
void add(json_object* o,const char* key,bool value) {add(o,key,json_object_new_boolean(value));}
void add(json_object* o,const char* key,int value) {add(o,key,json_object_new_int(value));}
void add(json_object* o,const char* key,const std::string& value) {add(o,key,json_object_new_string_len(value.data(),int(value.size())));}
template<class Collection> json_object* integers(const Collection& values) {
    auto* result=json_object_new_array();for(auto value:values) json_object_array_add(result,json_object_new_int64(value));return result;
}
json_object* strings(const Lines& values) {
    auto* result=json_object_new_array();for(const auto& value:values) json_object_array_add(result,json_object_new_string_len(value.data(),int(value.size())));return result;
}
json_object* cell(Cell value) {return integers(std::array<int,2>{value.x,value.y});}
json_object* encode_pending(const Pending& p) {
    auto* o=object();add(o,"scene",int(p.scene));add(o,"messages",integers(p.messages));add(o,"code_input",p.code_input);add(o,"quiz_done",p.quiz_done);
    add(o,"reverse",p.reverse);add(o,"departure_chime",p.departure_chime);add(o,"spy",p.spy);add(o,"epitaph",p.epitaph);add(o,"divisor",p.divisor);add(o,"applied",p.applied);
    add(o,"ambush_lines",strings(p.ambush_lines));json_object* q=nullptr;
    if(p.quiz) {q=object();add(q,"kind",int(p.quiz->kind));add(q,"index",p.quiz->index);add(q,"attempt",p.quiz->attempt);add(q,"resume_city",p.quiz->resume_city);add(q,"resume_oslo",p.quiz->resume_oslo);}
    add(o,"quiz",q);return o;
}
json_object* encode_fauna(const Fauna& f) {
    auto* o=object();add(o,"initialized",f.initialized);add(o,"frozen",f.frozen);add(o,"cell",cell(f.cell));add(o,"heading",f.heading);add(o,"phase",f.phase);add(o,"counter",f.counter);
    auto* history=json_object_new_array();for(auto c:f.history) json_object_array_add(history,cell(c));add(o,"history",history);return o;
}
json_object* encode_state(const State& s) {
    auto* o=object();add(o,"urga_key",s.urga_key);add(o,"delivery_open",s.delivery_open);add(o,"central_destroyed",s.central_destroyed);add(o,"whale_present",s.whale_present);add(o,"sos_sent",s.sos_sent);
    add(o,"pending",encode_pending(s.pending));add(o,"ending",int(s.ending));
    auto* spies=json_object_new_array();for(const auto& record:s.spies) json_object_array_add(spies,integers(record));add(o,"spies",spies);
    auto* protection=json_object_new_array();for(bool value:s.protection_seen) json_object_array_add(protection,json_object_new_boolean(value));add(o,"protection_seen",protection);
    auto* hazards=object();add(hazards,"traps",integers(s.hazards.traps));add(hazards,"mole_times",integers(s.hazards.mole_times));add(o,"hazards",hazards);
    add(o,"fauna",encode_fauna(s.fauna));add(o,"stoup",integers(s.stoup.entries));return o;
}
json_object* encode_presentation(const Presentation& p) {
    auto* o=object();add(o,"visible",p.visible);add(o,"scene",int(p.scene));add(o,"lines",strings(p.lines));add(o,"input_code",p.input_code);
    add(o,"entering_code",p.entering_code);add(o,"question",p.question);add(o,"menu",strings(p.menu));return o;
}
void shape(json_object* o,std::size_t count) {
    if(!o||!json_object_is_type(o,json_type_object)||std::size_t(json_object_object_length(o))!=count) throw std::runtime_error("Invalid campaign object shape");
}
json_object* get(json_object* o,const char* key) {
    json_object* value=nullptr;if(!json_object_object_get_ex(o,key,&value)) throw std::runtime_error(std::string("Missing campaign snapshot field: ")+key);return value;
}
std::int64_t number(json_object* o) {
    if(!o||!json_object_is_type(o,json_type_int)) throw std::runtime_error("Campaign snapshot requires an integer");
    std::string_view text=json_object_get_string(o);std::int64_t value{};auto r=std::from_chars(text.data(),text.data()+text.size(),value);
    if(r.ec!=std::errc{}||r.ptr!=text.data()+text.size()) throw std::runtime_error("Campaign integer overflow");return value;
}
int integer(json_object* o) {
    auto value=number(o);if(value<std::numeric_limits<int>::min()||value>std::numeric_limits<int>::max()) throw std::runtime_error("Campaign integer out of range");return int(value);
}
bool boolean(json_object* o) {if(!o||!json_object_is_type(o,json_type_boolean)) throw std::runtime_error("Campaign snapshot requires a boolean");return json_object_get_boolean(o);}
std::string text(json_object* o) {if(!o||!json_object_is_type(o,json_type_string)) throw std::runtime_error("Campaign snapshot requires text");return {json_object_get_string(o),std::size_t(json_object_get_string_len(o))};}
std::size_t array(json_object* o,std::size_t maximum) {
    if(!o||!json_object_is_type(o,json_type_array)||json_object_array_length(o)>maximum) throw std::runtime_error("Campaign array limit exceeded");return json_object_array_length(o);
}
template<class Enum> Enum enumeration(json_object* o,int last) {int value=integer(o);if(value<0||value>last) throw std::runtime_error("Invalid campaign enum");return Enum(value);}
template<class T,std::size_t N> std::array<T,N> fixed_numbers(json_object* o) {
    if(array(o,N)!=N) throw std::runtime_error("Invalid fixed campaign array");std::array<T,N> result;
    for(std::size_t i=0;i<N;++i) {
        auto value=number(json_object_array_get_idx(o,i));
        if(value<std::numeric_limits<T>::min()||value>std::numeric_limits<T>::max()) throw std::runtime_error("Campaign array integer overflow");result[i]=T(value);
    }
    return result;
}
Lines read_lines(json_object* o,std::size_t maximum) {Lines result;auto n=array(o,maximum);for(std::size_t i=0;i<n;++i) result.push_back(text(json_object_array_get_idx(o,i)));return result;}
Cell read_cell(json_object* o) {auto values=fixed_numbers<int,2>(o);return {values[0],values[1]};}
Pending read_pending(json_object* o) {
    shape(o,12);Pending p;p.scene=enumeration<Scene>(get(o,"scene"),int(Scene::Death));
    auto* messages=get(o,"messages");auto n=array(messages,3);for(std::size_t i=0;i<n;++i) p.messages.push_back(integer(json_object_array_get_idx(messages,i)));
    p.code_input=boolean(get(o,"code_input"));p.quiz_done=boolean(get(o,"quiz_done"));p.reverse=boolean(get(o,"reverse"));p.departure_chime=boolean(get(o,"departure_chime"));
    p.spy=integer(get(o,"spy"));p.epitaph=integer(get(o,"epitaph"));p.divisor=integer(get(o,"divisor"));p.applied=integer(get(o,"applied"));p.ambush_lines=read_lines(get(o,"ambush_lines"),10);
    auto* q=get(o,"quiz");if(q) {
        shape(q,5);p.quiz=Quiz{enumeration<QuizKind>(get(q,"kind"),1),integer(get(q,"index")),integer(get(q,"attempt")),integer(get(q,"resume_city")),boolean(get(q,"resume_oslo"))};
    }
    return p;
}
Fauna read_fauna(json_object* o) {
    shape(o,7);Fauna f;f.initialized=boolean(get(o,"initialized"));f.frozen=boolean(get(o,"frozen"));f.cell=read_cell(get(o,"cell"));
    f.heading=integer(get(o,"heading"));f.phase=integer(get(o,"phase"));f.counter=integer(get(o,"counter"));
    auto* history=get(o,"history");auto n=array(history,3);for(std::size_t i=0;i<n;++i) f.history.push_back(read_cell(json_object_array_get_idx(history,i)));return f;
}
State read_state(json_object* o) {
    shape(o,12);State s;s.urga_key=boolean(get(o,"urga_key"));s.delivery_open=boolean(get(o,"delivery_open"));s.central_destroyed=boolean(get(o,"central_destroyed"));
    s.whale_present=boolean(get(o,"whale_present"));s.sos_sent=boolean(get(o,"sos_sent"));s.pending=read_pending(get(o,"pending"));s.ending=enumeration<Ending>(get(o,"ending"),2);
    auto* spies=get(o,"spies");if(array(spies,20)!=20) throw std::runtime_error("Expected20 spy records");
    for(int i=0;i<20;++i) s.spies[i]=fixed_numbers<std::int64_t,15>(json_object_array_get_idx(spies,i));
    auto* protection=get(o,"protection_seen");if(array(protection,2)!=2) throw std::runtime_error("Expected both protection flags");
    for(int i=0;i<2;++i) s.protection_seen[i]=boolean(json_object_array_get_idx(protection,i));
    auto* hazards=get(o,"hazards");shape(hazards,2);s.hazards.traps=fixed_numbers<int,7>(get(hazards,"traps"));s.hazards.mole_times=fixed_numbers<std::int64_t,10>(get(hazards,"mole_times"));
    s.fauna=read_fauna(get(o,"fauna"));auto* stoup=get(o,"stoup");auto n=array(stoup,10);for(std::size_t i=0;i<n;++i) s.stoup.entries.push_back(integer(json_object_array_get_idx(stoup,i)));return s;
}
Presentation read_presentation(json_object* o) {
    shape(o,7);Presentation p;p.visible=boolean(get(o,"visible"));p.scene=enumeration<Scene>(get(o,"scene"),int(Scene::SunRestored));
    p.lines=read_lines(get(o,"lines"),10);p.input_code=text(get(o,"input_code"));p.entering_code=boolean(get(o,"entering_code"));p.question=boolean(get(o,"question"));p.menu=read_lines(get(o,"menu"),3);return p;
}
Finale read_finale(json_object* o) {
    shape(o,3);Finale f;auto seed=text(get(o,"seed"));std::uint64_t parsed{};auto r=std::from_chars(seed.data(),seed.data()+seed.size(),parsed);
    if(r.ec!=std::errc{}||r.ptr!=seed.data()+seed.size()||std::to_string(parsed)!=seed) throw std::runtime_error("Invalid finale seed");
    f.start(parsed);f.tick=integer(get(o,"tick"));auto* remainder=get(o,"remainder");
    if(!remainder||(!json_object_is_type(remainder,json_type_double)&&!json_object_is_type(remainder,json_type_int))) throw std::runtime_error("Invalid finale remainder");
    f.remainder=json_object_get_double(remainder);return f;
}
}
std::string serialize_snapshot(const Snapshot& value) {
    if(!value.valid()) throw std::runtime_error("Refusing invalid campaign snapshot");
    Json root(object(),json_object_put);auto* o=root.get();add(o,"version",1);add(o,"state",encode_state(value.state));
    add(o,"page",int(value.page));add(o,"selection",int(value.selection));add(o,"crew_menu",int(value.crew_menu));add(o,"notice",value.notice);add(o,"return_room",int(value.return_room));add(o,"car_missile",value.car_missile);
    add(o,"presentation",encode_presentation(value.presentation));auto* f=object();add(f,"tick",value.finale.tick);add(f,"seed",std::to_string(value.finale.seed));add(f,"remainder",json_object_new_double(value.finale.remainder));add(o,"finale",f);
    return json_object_to_json_string_ext(o,JSON_C_TO_STRING_PLAIN);
}
bool parse_snapshot(std::string_view input,Snapshot& destination,std::string& error) {
    try {
        if(input.size()>std::size_t(std::numeric_limits<int>::max())) throw std::runtime_error("Campaign section exceeds parser size");
        std::unique_ptr<json_tokener,decltype(&json_tokener_free)> parser(json_tokener_new(),json_tokener_free);json_tokener_set_flags(parser.get(),JSON_TOKENER_STRICT);
        Json root(json_tokener_parse_ex(parser.get(),input.data(),int(input.size())),json_object_put);
        if(!root||json_tokener_get_error(parser.get())!=json_tokener_success) throw std::runtime_error("Invalid campaign JSON");
        for(auto i=json_tokener_get_parse_end(parser.get());i<input.size();++i) if(!std::isspace(static_cast<unsigned char>(input[i]))) throw std::runtime_error("Trailing campaign JSON content");
        auto* o=root.get();shape(o,10);if(integer(get(o,"version"))!=1) throw std::runtime_error("Unsupported campaign schema");
        Snapshot staged;staged.state=read_state(get(o,"state"));int page=integer(get(o,"page"));if(page<0) throw std::runtime_error("Invalid campaign page");staged.page=std::size_t(page);
        staged.selection=enumeration<Selection>(get(o,"selection"),2);staged.crew_menu=enumeration<CrewMenu>(get(o,"crew_menu"),3);
        staged.notice=boolean(get(o,"notice"));staged.return_room=enumeration<Room>(get(o,"return_room"),2);staged.car_missile=boolean(get(o,"car_missile"));
        staged.presentation=read_presentation(get(o,"presentation"));staged.finale=read_finale(get(o,"finale"));
        if(!staged.valid()) throw std::runtime_error("Invalid campaign state/presentation relationship");
        destination=std::move(staged);error.clear();return true;
    } catch(const std::exception& e) {error=e.what();return false;}
}
}
