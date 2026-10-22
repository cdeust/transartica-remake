// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "world/enemy_trains.hpp"
#include <optional>
#include <string_view>
namespace transartica::launcher {
enum class Phase {Aim,Arming,Armed,Disarming,Launch,Ascent,Flight,Impact,Report};
std::string phase_name(Phase);
struct Geometry {
    Cell origin,delta,step;int count{},target=-1,group{};std::optional<world::EnemyTrain> record;
    bool operator==(const Geometry&)const=default;
};
int angle(int bearing);
std::optional<Geometry> calculate(int bearing,int distance,Cell origin,const world::EnemyTrains&);
Cell screen_point(const Geometry&,Cell camera,int tick,bool final=false);
struct Model {
    int bearing{};std::array<int,4> digits{0,0,5,0};Phase phase=Phase::Aim;
    int cursor{},ascent{},ascent_step=4;std::optional<Geometry> geometry;
    Cell camera,scroll;int scroll_left{},status=1;bool removed{};double accumulator{};
    int distance()const;
    bool action(int code,Cell origin,const world::EnemyTrains&);
    void advance(double seconds);
    void step();
    bool operator==(const Model&)const=default;
private:
    void flight_step();bool scroll_or_exit(Cell);void finish_flight();
};
struct Snapshot {
    bool active{},visible{},paused{};std::optional<Model> state;
    bool operator==(const Snapshot&)const=default;
};
bool validate_snapshot(const Snapshot&,const std::vector<Wagon>&,const world::EnemyTrains&,Cell origin);
std::string serialize_snapshot(const Snapshot&);
bool parse_snapshot(std::string_view,Snapshot&,std::string& error);
enum class OpenResult {Opened,NoLauncher,NoMissiles};
enum class ActionKind {Cabin,Options,Save,CargoChanged,EnemyRemoved,EffectAudio,ImpactAudio};
struct Action {ActionKind kind;int value{};};
class Controller {
public:
    Controller(Session&,world::EnemyTrains&);
    OpenResult open();
    bool action(int code);
    void advance(double seconds);
    bool dismiss();
    void reset();void resume();void hide();void toggle_pause();void options();void save();
    bool active()const{return state_.active;}
    bool visible()const{return state_.visible;}
    bool paused()const{return state_.paused;}
    const Model* model()const{return state_.state?&*state_.state:nullptr;}
    const Snapshot& snapshot()const{return state_;}
    bool restore(const Snapshot&);
    std::vector<Action> take_actions();
    bool pace_enabled=true; // Owner1Oct dynamic-scenes pace, source launcher_session.
private:
    Session& session_;world::EnemyTrains& enemies_;Snapshot state_;std::vector<Action> actions_;
};
}
