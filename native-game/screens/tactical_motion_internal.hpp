// SPDX-License-Identifier: MIT
#pragma once
#include "tactical_motion.hpp"
#include "tactical_screen.h"
#include "tactical_visual_random.hpp"
namespace transartica::panels {
struct TacticalMotion::Impl {
    struct Track;
    struct Board {Point from_cell,from_offset;double t{},height{},ladder{},out=1,land{};int wagon=-1,rungs{};double rung{},run{},climb{},rise=.45,dismount{};bool hop{};std::shared_ptr<Track>source;int which{};double face{};};
    struct Task {std::pair<int,int>key;double t{};bool arrived{};};
    struct Soldier {int uid{},slot{};Point cell;double speed{},amp{},phase{},delay{},vmul=1,breath{},strike{},recoil{};Point offset,shift,shift_to;double shift_speed{},face{},crouch{};int plant=-1;double strike_len=.35,recoil_len=.35;std::optional<Board>board;std::optional<Task>task;double gait_distance{},halt{};int gait=-1;Point lag;struct Walk{Point target,base,direction;int first{},passed{},kind{};std::vector<double>bounds;};std::optional<Walk>walk;};
    struct Track {combat::Actor actor;Point target;int roof=-1,count{},alive{},shed{};double facing=1,engaged{};std::vector<Soldier>soldiers;std::vector<int>dying;};
    struct Body {int roof=-1;Point cell,offset;double facing=1;int side{};bool mammoth{},fall{},landed{};int count{},kind{};double t{},delay{},span=.9,breath{};int rider=-1;bool pair{};int uid{};};
    struct ChargeState {bool placed=true,lit=true;};
    std::map<int,std::shared_ptr<Track>>tracks;std::vector<Body>bodies;std::map<std::pair<int,int>,ChargeState>charges;std::vector<combat::Event>melees;Random random;int serial{},body_serial{};std::array<double,2>kneels{{-1,-1}};std::array<std::vector<int>,2>rig_tops;std::map<std::pair<int,double>,double>matches;
    Impl(){random.seed(7);}
    double rnd(double lo,double hi){return art::uniform(random,lo,hi);}Soldier soldier(Point,int slot);
    Point offset(const Track&,const Soldier&)const;
    Point place(TacticalScreen&,const combat::Tactical&,int roof,Point cell,Point offset={});
    Point point(TacticalScreen&,const combat::Tactical&,const Track&,const Soldier&);
    void drop_riders(Track&,int before,int after);
    int waiting(const Track&)const;
    void muster(Track&,const combat::Actor&,bool fighting);void drop(Track&,const Soldier&,bool fall,double delay);void run(Soldier&,Track&);
    void start_climb(TacticalScreen&,const combat::Tactical&,Track&,Soldier&,Point from,Point offset,double delay,std::shared_ptr<Track>ride={},int which=0);
    void board(TacticalScreen&,const combat::Tactical&,Track&,Point);void from_shedder(TacticalScreen&,const combat::Tactical&,Track&);
    struct Pose {Point at;double climb{},crouch{},amp=-1;int frame=-1,dismount=-1;};
    Pose board_pose(TacticalScreen&,const combat::Tactical&,const Track&,const Soldier&);
    void climbing(Soldier&);void task(Soldier&,int side);void plants(const combat::TacticalState&);void engage(const combat::Event&);
    struct Spot {Point offset;int size{};double anchor{};};
    struct Label {std::string key,text;Point base,point,shown,offset;int size{};double anchor{};};
    std::map<std::string,Spot>kept;std::map<std::string,Point>shown;
    std::vector<Label>labels(TacticalScreen&,const combat::Tactical&,bool ease);
    double matched(TacticalScreen&,int side,double top);
    double hull_end(TacticalScreen&,const combat::Tactical&,int roof,int wagon,double out);
    double roof_y(TacticalScreen&,const combat::Tactical&,int roof,int wagon,double x,double fallback);
};
}
