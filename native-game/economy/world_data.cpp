// SPDX-License-Identifier: MIT
#include "world_data.hpp"
#include <algorithm>
#include <charconv>
#include <fstream>
#include <iterator>
#include <sstream>
#include <stdexcept>
namespace transartica::economy {
namespace {
std::vector<std::string> fields(const std::string& line) {
    std::vector<std::string> out; std::stringstream stream(line); std::string field;
    while(std::getline(stream,field,',')) { if(!field.empty()&&field.back()=='\r') field.pop_back(); out.push_back(field); }
    return out;
}
int integer(const std::string& text) {
    int n{}; const auto r=std::from_chars(text.data(),text.data()+text.size(),n);
    if(r.ec!=std::errc{}||r.ptr!=text.data()+text.size()) throw std::runtime_error("Invalid city integer");
    return n;
}
}
bool WorldData::load(const std::filesystem::path& path,std::string& error) {
    try {
        std::ifstream map_file(path/"CARTE.FIC",std::ios::binary);
        if(!map_file) throw std::runtime_error("Cannot read CARTE.FIC");
        std::vector<unsigned char> map((std::istreambuf_iterator<char>(map_file)),{});
        if(map.size()!=160*73) throw std::runtime_error("Invalid CARTE dimensions");
        std::ifstream city_file(path/"villes-decoded.data");
        if(!city_file) throw std::runtime_error("Cannot read villes-decoded.data");
        std::string line; std::getline(city_file,line); const auto columns=fields(line);
        auto column=[&](const std::string& name) {
            auto it=std::find(columns.begin(),columns.end(),name);
            if(it==columns.end()) throw std::runtime_error("Missing city column: "+name);
            return std::size_t(it-columns.begin());
        };
        const auto name=column("game_name"),x=column("anchor_x"),y=column("anchor_y"),type=column("type_label_by_abs_value"),kind=column("field2_abs");
        const auto required=std::max({name,x,y,type,kind}); std::vector<City> cities;
        while(std::getline(city_file,line)) {
            if(line.empty()||line=="\r") continue;
            auto row=fields(line); if(row.size()<=required) throw std::runtime_error("Incomplete city row");
            City city{row[name],{integer(row[x]),integer(row[y])},row[type],integer(row[kind])};
            if(city.anchor.x<0||city.anchor.x>=160||city.anchor.y<0||city.anchor.y>=73||city.kind<1||city.kind>6) throw std::runtime_error("Invalid city anchor or kind");
            cities.push_back(std::move(city));
        }
        if(cities.size()!=46) throw std::runtime_error("Expected46 city records");
        map_=std::move(map); cities_=std::move(cities); error.clear(); return true;
    } catch(const std::exception& e) { error=e.what(); return false; }
}
const City* WorldData::city(int index) const { return index>=0&&index<int(cities_.size())?&cities_[index]:nullptr; }
std::optional<int> WorldData::city_at(Cell at) const {
    for(std::size_t i=0;i<cities_.size();++i) if(cities_[i].anchor==at) return int(i);
    return {};
}
int WorldData::map_code(Cell at) const {
    if(at.x<0||at.x>=160||at.y<0||at.y>=73||map_.size()!=160*73) return -1;
    return map_[at.x*73+at.y];
}
std::vector<Cell> WorldData::city_anchors() const { std::vector<Cell> result; for(const auto& c:cities_) result.push_back(c.anchor); return result; }
}
