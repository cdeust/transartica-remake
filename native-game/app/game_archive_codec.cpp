// SPDX-License-Identifier: MIT
// Native envelope fields preserve source session_save_extensions/session_saves state.
#include "game_archive_codec.h"
#include <cmath>
#include <iomanip>
#include <limits>
namespace transartica {
bool PresentationState::valid() const {
    auto chart=world_view;
    return screen>=0&&screen<=7&&overview_return>=0&&overview_return<=7&&options_return>=0&&options_return<=7
        &&std::isfinite(visual_time)&&visual_time>=0&&int(captain.mode)>=0&&int(captain.mode)<=int(panels::CaptainMode::Earth)
        &&normalize_world_state(chart,46); // world_data.gd's 46 decoded city anchors.
}
namespace archive {
namespace {
bool end(std::istream& in) {if(in.fail())return false;in>>std::ws;return in.eof()&&!in.bad();}
bool boolean(std::istream& in,bool& value) {int n=-1;if(!(in>>n)||n<0||n>1)return false;value=n;return true;}
bool random(std::istream& in,Random& value) {
    std::string state,increment;if(!(in>>state>>increment))return false;
    const auto read=[](const std::string& text,std::uint64_t& out) {
        if(text.empty()||text.find_first_not_of("0123456789")!=std::string::npos)return false;
        try {std::size_t count{};out=std::stoull(text,&count);return count==text.size();}catch(...){return false;}
    };
    return read(state,value.state)&&read(increment,value.increment)&&value.valid();
}
std::ostringstream stream() {std::ostringstream out;out.imbue(std::locale::classic());out<<std::setprecision(std::numeric_limits<double>::max_digits10);return out;}
void report(std::ostream& out,const combat::AutomaticResult& r) {
    out<<r.won<<' '<<r.margin<<' '<<r.potential<<' '<<r.enemy.wagons<<' '<<r.enemy.trading<<' '
       <<r.enemy.gun_groups[0]<<' '<<r.enemy.gun_groups[1]<<' '<<r.enemy.soldiers<<' '<<r.enemy.mammoths<<' '
       <<r.soldiers_lost<<' '<<r.mammoths_lost<<' '<<r.coal_gained<<' '<<r.slaves_gained<<' '<<r.wagons_captured<<' '<<r.epitaph_id<<'\n';
    out<<r.scrapped_indices.size();for(int index:r.scrapped_indices)out<<' '<<index;
    out<<'\n'<<r.captured.size();for(const auto& w:r.captured)out<<' '<<w.type<<' '<<w.state<<' '<<w.goods<<' '<<w.quantity;
}
bool report(std::istream& in,combat::AutomaticResult& r) {
    if(!boolean(in,r.won)||!(in>>r.margin>>r.potential>>r.enemy.wagons>>r.enemy.trading>>r.enemy.gun_groups[0]
       >>r.enemy.gun_groups[1]>>r.enemy.soldiers>>r.enemy.mammoths>>r.soldiers_lost>>r.mammoths_lost
       >>r.coal_gained>>r.slaves_gained>>r.wagons_captured>>r.epitaph_id))return false;
    std::size_t count{};if(!(in>>count)||count>100)return false; // Core persisted composition bound.
    r.scrapped_indices.resize(count);for(auto& index:r.scrapped_indices)if(!(in>>index)||index<0||index>=100)return false;
    if(!(in>>count)||count>100)return false;r.captured.resize(count);
    for(auto& w:r.captured)if(!(in>>w.type>>w.state>>w.goods>>w.quantity)||w.type<1||w.type>25||w.state<0||w.state>3||w.goods<0||w.goods>16||w.quantity<0||w.quantity>127)return false;
    return r.won&&r.potential>=0&&r.enemy.wagons>=0&&r.soldiers_lost>=0&&r.mammoths_lost>=0;
}
}
std::string encode(const Encounters& s) {
    auto out=stream();out<<s.random.state<<' '<<s.random.increment<<' '<<s.visual.state<<' '<<s.visual.increment<<'\n'
        <<s.difficulty<<' '<<s.pending<<' '<<s.city<<' '<<s.automatic<<' '<<s.manual_paused<<' '<<s.workshop<<' '<<s.text_accumulator<<' '<<bool(s.report)<<'\n';
    if(s.report)report(out,*s.report);return out.str();
}
bool decode(const std::string& payload,Encounters& out) {
    std::istringstream in(payload);in.imbue(std::locale::classic());Encounters s;bool has_report{};
    if(!random(in,s.random)||!random(in,s.visual)||!(in>>s.difficulty>>s.pending>>s.city)
       ||!boolean(in,s.automatic)||!boolean(in,s.manual_paused)||!boolean(in,s.workshop)||!(in>>s.text_accumulator)||!boolean(in,has_report))return false;
    if(s.difficulty<0||s.difficulty>4||s.pending< -1||s.pending>=30||s.city< -1||s.city>=46
       ||!std::isfinite(s.text_accumulator)||s.text_accumulator<0||s.text_accumulator>=1.0/48)return false;
    if(has_report){s.report.emplace();if(!report(in,*s.report))return false;}
    if(!end(in))return false;out=std::move(s);return true;
}
std::string encode(const audio::Snapshot& s) {
    auto out=stream();out<<s.version<<' '<<s.music_enabled<<' '<<s.effects_enabled<<' '<<s.alternate<<' '<<std::quoted(s.track)<<' '
        <<s.elapsed<<' '<<s.random.state<<' '<<s.random.increment<<'\n';return out.str();
}
bool decode(const std::string& payload,audio::Snapshot& out) {
    std::istringstream in(payload);in.imbue(std::locale::classic());audio::Snapshot s;
    if(!(in>>s.version)||!boolean(in,s.music_enabled)||!boolean(in,s.effects_enabled)||!boolean(in,s.alternate)
       ||!(in>>std::quoted(s.track)>>s.elapsed)||!random(in,s.random)||!end(in))return false;
    out=std::move(s);return true;
}
std::string encode(const PresentationState& s) {
    auto out=stream();out<<s.screen<<' '<<s.overview_return<<' '<<s.options_return<<' '<<s.options_open<<' '<<s.city_suspended<<' '
        <<s.visual_time<<' '<<int(s.captain.mode)<<' '<<s.captain.lines.size()<<'\n';
    for(const auto& line:s.captain.lines)out<<std::quoted(line)<<'\n';
    const auto& chart=s.world_view;
    out<<"WORLD_VIEW 1 "<<chart.ready<<' '<<chart.camera.x<<' '<<chart.camera.y<<' '<<chart.zoom<<' '
        <<chart.offset.x<<' '<<chart.offset.y<<' '<<chart.following<<' '<<chart.inspecting<<' '<<chart.selected_city<<'\n';
    return out.str();
}
bool decode(const std::string& payload,PresentationState& out) {
    std::istringstream in(payload);in.imbue(std::locale::classic());PresentationState s;int mode{};std::size_t count{};
    if(!(in>>s.screen>>s.overview_return>>s.options_return)||!boolean(in,s.options_open)||!boolean(in,s.city_suspended)
       ||!(in>>s.visual_time>>mode>>count)||count>payload.size()/2)return false;
    s.captain.mode=panels::CaptainMode(mode);s.captain.lines.resize(count);
    for(auto& line:s.captain.lines)if(!(in>>std::quoted(line)))return false;
    // Initial native full archives had no chart tail. They retain default
    // first-map calibration; any present tail must be complete and versioned.
    in>>std::ws;
    if(!in.eof()) {
        std::string tag;int version{};auto& chart=s.world_view;
        if(!(in>>tag>>version)||tag!="WORLD_VIEW"||version!=1||!boolean(in,chart.ready)
            ||!(in>>chart.camera.x>>chart.camera.y>>chart.zoom>>chart.offset.x>>chart.offset.y)
            ||!boolean(in,chart.following)||!boolean(in,chart.inspecting)||!(in>>chart.selected_city)
            ||!normalize_world_state(chart,46))return false;
    }
    if(!s.valid()||!end(in))return false;out=std::move(s);return true;
}
}
}
