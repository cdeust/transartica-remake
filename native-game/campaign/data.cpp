// SPDX-License-Identifier: MIT
// Source: campaign_state.gd load_data/message, manual_quiz.gd lines.
#include "data.hpp"
#include <json-c/json.h>
#include <charconv>
#include <cmath>
#include <limits>
#include <memory>
#include <stdexcept>
namespace transartica::campaign {
namespace {
json_object* get(json_object* o,const char* key) {
    json_object* value=nullptr;
    if(!o||!json_object_object_get_ex(o,key,&value)) throw std::runtime_error(std::string("Missing campaign field: ")+key);
    return value;
}
int integer(json_object* o) {
    if(!o||(!json_object_is_type(o,json_type_int)&&!json_object_is_type(o,json_type_double))) throw std::runtime_error("Invalid campaign integer");
    double n=json_object_get_double(o);
    if(!std::isfinite(n)||std::floor(n)!=n||n<std::numeric_limits<int>::min()||n>std::numeric_limits<int>::max()) throw std::runtime_error("Invalid campaign integer range");
    return int(n);
}
std::string string(json_object* o) {
    if(!json_object_is_type(o,json_type_string)) throw std::runtime_error("Invalid campaign text");
    return json_object_get_string(o);
}
int key_number(const char* key) {
    std::string_view s(key);int value{}; auto r=std::from_chars(s.data(),s.data()+s.size(),value);
    if(r.ec!=std::errc{}||r.ptr!=s.data()+s.size()) throw std::runtime_error("Invalid campaign text index"); return value;
}
void object(json_object* o) { if(!json_object_is_type(o,json_type_object)) throw std::runtime_error("Invalid campaign object"); }
void array(json_object* o) { if(!json_object_is_type(o,json_type_array)) throw std::runtime_error("Invalid campaign array"); }
std::map<int,Lines> text_table(json_object* root,const char* name) {
    auto* table=get(root,name);object(table); std::map<int,Lines> result;
    json_object_object_foreach(table,key,value) {
        array(value); Lines lines;
        for(std::size_t i=0;i<json_object_array_length(value);++i) lines.push_back(string(json_object_array_get_idx(value,i)));
        result.emplace(key_number(key),std::move(lines));
    }
    return result;
}
void read_regions(Data& data,json_object* root) {
    auto* regions=get(root,"regions");object(regions);
    json_object_object_foreach(regions,key,value) {
        array(value); auto& output=data.regions[key];
        for(std::size_t i=0;i<json_object_array_length(value);++i) {
            auto* r=json_object_array_get_idx(value,i);array(r);
            if(json_object_array_length(r)!=3) throw std::runtime_error("Invalid campaign region record");
            output.push_back({{integer(json_object_array_get_idx(r,0)),integer(json_object_array_get_idx(r,1))},integer(json_object_array_get_idx(r,2))});
        }
    }
}
void read_misc(Data& data,json_object* root) {
    auto* names=get(root,"wagon_names");object(names);
    json_object_object_foreach(names,key,value) {data.wagon_names[key_number(key)]=string(value);}
    auto* bulletin=get(root,"mine_bulletin");object(bulletin);
    json_object_object_foreach(bulletin,name,text) {data.mine_bulletin[name]=string(text);}
    auto* quizzes=get(root,"quizzes");
    for(int index=0;index<2;++index) {
        auto* records=get(quizzes,index==0?"soleil":"viking");array(records);
        if(json_object_array_length(records)!=8) throw std::runtime_error("Expected eight source quiz records");
        for(int i=0;i<8;++i) {
            auto* r=json_object_array_get_idx(records,i);
            data.quizzes[index].push_back({integer(get(r,"page")),integer(get(r,"line")),integer(get(r,"word")),string(get(r,"answer"))});
        }
    }
}
void replace(std::string& line,std::string_view from,const std::string& to) { auto at=line.find(from);if(at!=std::string::npos) line.replace(at,from.size(),to); }
}
bool Data::load(const std::filesystem::path& path,std::string& error) {
    try {
        std::unique_ptr<json_object,decltype(&json_object_put)> root(json_object_from_file(path.string().c_str()),json_object_put);
        if(!root||integer(get(root.get(),"version"))!=1) throw std::runtime_error("Invalid campaign.json version");
        Data staged;read_regions(staged,root.get());read_misc(staged,root.get());
        staged.messages=text_table(root.get(),"messages");staged.documents=text_table(root.get(),"documents");staged.epitaphs=text_table(root.get(),"epitaphs");
        staged.report_phrases=text_table(root.get(),"report_phrases");staged.ambush_phrases=text_table(root.get(),"ambush_phrases");
        *this=std::move(staged);error.clear();return true;
    } catch(const std::exception& e) {error=e.what();return false;}
}
Lines Data::message(int id,bool document) const {
    const auto& table=document?(id>=100&&id<=105?epitaphs:documents):messages;
    auto it=table.find(id);return it==table.end()?Lines{}:it->second;
}
std::string Data::phrase(bool ambush,int offset,std::size_t index) const {
    const auto& table=ambush?ambush_phrases:report_phrases;auto it=table.find(offset);
    return it!=table.end()&&index<it->second.size()?it->second[index]:"";
}
Lines Data::quiz_lines(const Quiz& quiz) const {
    auto result=message(54); const auto& records=quizzes[int(quiz.kind)];
    if(result.size()==4&&records.size()==8&&quiz.index>=0&&quiz.index<8) {
        const auto& r=records[quiz.index];
        replace(result[2],"WORD        OF LINE","WORD "+std::to_string(r.word)+" OF LINE "+std::to_string(r.line));
        replace(result[3],"PAGE    :","PAGE "+std::to_string(r.page)+" :");
    }
    return result;
}
}
