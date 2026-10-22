// SPDX-License-Identifier: MIT
// Tests port source test_reverser, reverse_physical_stop, reverse_occupied_switch.
// JSON is used ONLY to read earned fixtures, never as a runtime importer.
#include "core/train_pose.hpp"
#include <json-c/json.h>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <sstream>
#include <stdexcept>
using namespace transartica;
namespace {
int checks=0, failures=0;
void check(bool ok,const std::string& label) { ++checks; if (!ok) { ++failures; std::cerr<<"FAIL: "<<label<<'\n'; } }
json_object* field(json_object* p,const char* name) { return json_object_object_get(p,name); }
int integer(json_object* p,const char* name) { return json_object_get_int(field(p,name)); }
double real(json_object* p,const char* name) { return json_object_get_double(field(p,name)); }
Cell cell(json_object* p) { return {json_object_get_int(json_object_array_get_idx(p,0)),json_object_get_int(json_object_array_get_idx(p,1))}; }
std::vector<Point> points(json_object* array) {
    std::vector<Point> result;
    for (std::size_t i=0;i<json_object_array_length(array);++i) {
        auto* p=json_object_array_get_idx(array,i);
        result.push_back({json_object_get_double(json_object_array_get_idx(p,0)),json_object_get_double(json_object_array_get_idx(p,1))});
    }
    return result;
}
Journey read_journey(json_object* p) {
    Journey j;
    j.position=cell(field(p,"position")); j.heading=integer(p,"heading"); j.incoming_heading=integer(p,"incoming_heading");
    j.phase=integer(p,"phase"); j.distance_ticks=integer(p,"distance_ticks"); j.blocked=integer(p,"blocked");
    j.stop_reason=json_object_get_string(field(p,"stop_reason")); j.path=points(field(p,"path"));
    j.reversing=integer(p,"reverse"); j.render_path=points(field(p,"render_path"));
    j.render_cursor=real(p,"render_cursor"); j.render_origin=real(p,"render_origin");
    j.render_end_cell=cell(field(p,"render_end_cell")); j.render_end_heading=integer(p,"render_end_heading");
    if (field(p,"physical_obstacle")) j.physical_obstacle=cell(field(p,"physical_obstacle"));
    j.physical_heading=integer(p,"physical_heading"); j.physical_spy_handled=integer(p,"physical_spy_handled");
    return j;
}
Session earned(const std::filesystem::path& root,const std::string& name) {
    auto* doc=json_object_from_file((root/"fixtures"/(name+".json")).string().c_str());
    if (!doc) throw std::runtime_error("Missing earned fixture "+name);
    std::ifstream map(root/"game/data/CARTE.FIC",std::ios::binary);
    std::vector<std::uint8_t> bytes{std::istreambuf_iterator<char>(map),std::istreambuf_iterator<char>()};
    if (bytes.size()!=RailNetwork::width*RailNetwork::height) throw std::runtime_error("Missing CARTE");
    // Prepared map is the recorded earned map, including campaign writes that
    // this isolated contact test does not execute or claim to port.
    auto* switches=field(field(doc,"network"),"switches");
    json_object_object_foreach(switches,key,value) {
        std::istringstream coordinates(key); int x,y; char comma;
        coordinates>>x>>comma>>y; bytes.at(x*RailNetwork::height+y)=std::uint8_t(json_object_get_int(value));
    }
    Session s; std::string error;
    if (!s.network.load_bytes(bytes,error)) throw std::runtime_error(error);
    s.journey=read_journey(field(doc,"journey")); s.wagons.clear();
    auto* wagons=field(doc,"wagons");
    for (std::size_t i=0;i<json_object_array_length(wagons);++i) {
        auto* w=json_object_array_get_idx(wagons,i);
        s.wagons.push_back({json_object_get_int(json_object_array_get_idx(w,0)),json_object_get_int(json_object_array_get_idx(w,1)),
            json_object_get_int(json_object_array_get_idx(w,2)),json_object_get_int(json_object_array_get_idx(w,3))});
    }
    s.engine.train_mass=train_mass(s.wagons);
    s.calendar.hour=s.network.tile({110,33})==-121 ? 12 : 0;
    json_object_put(doc); return s;
}
bool contacts_equal(const std::vector<TrainPose>& a,const std::vector<TrainPose>& b,double tolerance=1e-8) {
    if (a.size()!=b.size()) return false;
    for (std::size_t i=0;i<a.size();++i)
        if (distance(a[i].front,b[i].front)>tolerance || distance(a[i].rear,b[i].rear)>tolerance || a[i].wagon_type!=b[i].wagon_type) return false;
    return true;
}
bool roundtrip(Session& s) {
    std::ostringstream out; if (!s.write_snapshot(out)) return false;
    Session restored=s; std::string error; std::istringstream in(out.str());
    if (!restored.read_snapshot(in,out.str().size(),error)) { std::cerr<<error<<'\n'; return false; }
    return contacts_equal(train_poses(s.journey,s.wagons),train_poses(restored.journey,restored.wagons),0)
        && s.journey.reverse_switches==restored.journey.reverse_switches && s.journey.physical_obstacle==restored.journey.physical_obstacle;
}
void initial_reversals(const std::filesystem::path& root) {
    Session original; std::string error;
    if (!original.load_world(root/"game/data/CARTE.FIC",error)) throw std::runtime_error(error);
    for (int steps=0;steps<12;++steps) {
        Session s=original;
        for (int i=0;i<steps;++i) s.journey.advance(s.network,300);
        const auto before=train_poses(s.journey,s.wagons);
        check(before.size()==s.wagons.size(),"six complete initial contacts");
        const auto position=s.journey.position; const auto phase=s.journey.phase;
        s.engine.speed=100; s.engine.brake=true; s.paused=true;
        check(s.reverse(),"reverse command accepted");
        check(s.engine.speed==0 && !s.engine.brake && s.paused,"reverser stops engine and preserves pause");
        check(s.journey.position==position && s.journey.phase==std::abs(phase-2)-1 && s.journey.distance_ticks==23,"decoded YODA phase transform");
        check(contacts_equal(before,train_poses(s.journey,s.wagons)),"reverse preserves every rigid contact");
        check(s.journey.valid(s.network) && roundtrip(s),"reversal in every phase saves and restores");
        check(s.reverse() && contacts_equal(before,train_poses(s.journey,s.wagons)),"round-trip reverser preserves contacts");
        check(s.journey.valid(s.network),"round-trip source logical state valid");
    }
}
void physical_obstacle(const std::filesystem::path& root) {
    auto s=earned(root,"reverse-obstacle-approach-earned");
    check(s.journey.valid(s.network),"earned obstacle source state validates");
    bool full=true;
    for (int i=0;i<1000 && !s.journey.blocked;++i) {
        advance_train(s.journey,s.network,s.wagons,300);
        full=full && train_poses(s.journey,s.wagons).size()==s.wagons.size();
    }
    check(full,"backing preserves all 13 contacts through actual turns");
    check(s.journey.at_obstacle() && s.journey.obstacle_cell()==Cell{6,9},"rear contact stops at actual Rum crevasse");
    check(s.journey.next_cell()!=s.journey.obstacle_cell(),"physical stop occurs before locomotive TIME boundary");
    s.paused=true; s.engine.brake=true; s.engine.speed=0;
    check(s.journey.valid(s.network) && roundtrip(s),"physical refusal roundtrip preserves contacts");
    check(s.journey.resume_after_works(s.network),"declined works releases logical stop");
    advance_train(s.journey,s.network,s.wagons,300);
    check(s.journey.at_obstacle() && s.journey.obstacle_cell()==Cell{6,9},"refused works retries same physical obstacle");
    const auto stopped=train_poses(s.journey,s.wagons);
    check(s.reverse() && contacts_equal(stopped,train_poses(s.journey,s.wagons)),"reversing away from obstacle preserves contacts");
}
void occupied_switch(const std::filesystem::path& root) {
    auto control=earned(root,"reverse-occupied-switch-earned"), switched=control;
    const auto before=prepare_train_poses(switched.journey,switched.network,switched.wagons);
    check(before.size()==21,"earned occupied switch has 21 contacts");
    check(switched.toggle_switch({49,39}),"actual occupied switch command");
    check(switched.journey.reverse_switches==std::vector<Journey::SwitchLatch>{{{49,39},7}},"command captures measured occupied northwest branch");
    check(contacts_equal(before,train_poses(switched.journey,switched.wagons)) && roundtrip(switched),"occupied command preserves geometry and persists");
    auto invalid=switched.journey; invalid.reverse_switches.front().heading=6;
    check(!invalid.valid(switched.network),"forged occupied branch rejected");
    bool same=true,full=true;
    for (int i=0;i<1000 && control.journey.position!=Cell{48,38} && !control.journey.blocked;++i) {
        advance_train(control.journey,control.network,control.wagons,300);
        advance_train(switched.journey,switched.network,switched.wagons,300);
        const auto a=train_poses(control.journey,control.wagons),b=train_poses(switched.journey,switched.wagons);
        same=same && contacts_equal(a,b); full=full && a.size()==21 && b.size()==21;
    }
    check(same && full && switched.journey.position==Cell{48,38},"late switch preserves all contacts until occupied branch clears");
    advance_train(switched.journey,switched.network,switched.wagons,300);
    check(switched.journey.reverse_switches.empty(),"latch retires after last body contact clears outgoing port");
    auto early=earned(root,"reverse-occupied-switch-earned"); early.wagons.resize(1); early.engine.train_mass=train_mass(early.wagons);
    prepare_train_poses(early.journey,early.network,early.wagons);
    check(early.toggle_switch({49,39}) && early.journey.reverse_switches.empty(),"unoccupied forecast never latches a switch");
    for (int i=0;i<1000 && early.journey.position.x>48 && !early.journey.blocked;++i) advance_train(early.journey,early.network,early.wagons,300);
    check(early.journey.position==Cell{48,39},"leading rear follows changed unoccupied straight branch");
}
void partial_switch(const std::filesystem::path& root) {
    auto s=earned(root,"reverse-refusal11686-earned");
    const auto before=prepare_train_poses(s.journey,s.network,s.wagons);
    check(before.size()==15,"earned partial emergence has 15 proven contacts");
    check(s.toggle_switch({42,32}),"partial occupied switch command");
    check(s.journey.reverse_switches==std::vector<Journey::SwitchLatch>{{{42,32},9}},"partial footprint latches only proven southeast branch");
    check(contacts_equal(before,train_poses(s.journey,s.wagons)) && roundtrip(s),"partial contacts and latch survive save reload");
}
void save_versions(const std::filesystem::path& root) {
    Session s;std::string error;
    if (!s.load_world(root/"game/data/CARTE.FIC",error)) throw std::runtime_error(error);
    std::ostringstream out; check(s.write_snapshot(out),"write native schema 3");
    auto v2=out.str(); v2.replace(0,v2.find('\n'),"TRANSARTICA_NATIVE_FORWARD 2");
    v2.erase(v2.find("RENDER ")); v2+="END\n";
    check(s.reverse(),"destination contains reverse state before legacy load");
    std::istringstream old(v2);
    check(s.read_snapshot(old,v2.size(),error) && !s.journey.reversing && s.journey.render_path.empty(),"schema 2 resets reverse state to exact forward representation");
    s.reverse(); std::ostringstream reverse;check(s.write_snapshot(reverse),"write reversed source snapshot");
    auto bad=reverse.str(); const auto cursor=bad.find("RENDER "),end=bad.find('\n',cursor);
    bad.replace(cursor,end-cursor,"RENDER 1 1e300 0 12 62 6");
    const auto before=train_poses(s.journey,s.wagons); std::istringstream damaged(bad);
    check(!s.read_snapshot(damaged,bad.size(),error) && contacts_equal(before,train_poses(s.journey,s.wagons)),"invalid canonical cursor is rejected transactionally");
}
}
int main(int argc,char** argv) {
    try {
        if (argc!=2) throw std::runtime_error("usage: reverse_tests runtime-resource-root");
        initial_reversals(argv[1]); physical_obstacle(argv[1]); occupied_switch(argv[1]); partial_switch(argv[1]); save_versions(argv[1]);
    } catch(const std::exception& e) { ++failures; std::cerr<<e.what()<<'\n'; }
    std::cout<<checks<<" reverse checks, "<<failures<<" failures\n"; return failures ? 1 : 0;
}
