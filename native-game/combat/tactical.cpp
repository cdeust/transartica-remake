// SPDX-License-Identifier: MIT
// Sources scripts/{tactical_combat,combat_setup}.gd and WDECOR evidence/combat.md.
#include "tactical.hpp"
#include <algorithm>
#include <cmath>
namespace transartica::combat {
namespace {constexpr int type_class[]={5,22,23,14,10,9,4,19,18,15,2,3,20,13,11,17,6,6,12,21,8,16,1,1,7};}
int Tactical::rnd(int n){if(n<=0){s_.random.next_u32();return 0;}return s_.random.range(0,n-1);}
bool Tactical::begin(const std::vector<Wagon>&w,int strength,Random& rng){if(w.empty()||w.size()>100||strength<0)return false;for(const auto&r:w)if(r.type<1||r.type>25||r.state<0||r.state>3)return false;s_={};s_.random=rng;s_.original=w;s_.initial_pools=auto_pools(w);s_.survivors={s_.initial_pools.soldiers,s_.initial_pools.mammoths,0};for(const auto&r:w){int kind=type_class[r.type-1],quantity=r.quantity,health=3-r.state;const bool engine=kind==Locomotive;if(kind==Cannon||kind==MachineGun)quantity=0;if(!health)kind=Wreck;s_.trains[0].push_back({kind,quantity,health,0});if(engine&&health>0)s_.trains[0].push_back({Companion,0,3,0});}
    const int a=(strength/20)*4,b=strength%20+1,half=(a+b)/2;s_.aggressiveness=std::min(b*5+1,99);
    // Setup._rnd does not advance when half==0; Tactical::rnd does.
    const int n=s_.random.below(half)+half+1,trading=n*a/(a+b)+1;
    std::vector<Car> enemy(n+2,{0,0,3,0});enemy[0].kind=Locomotive;enemy[1].kind=Tender;
    for(int placed=0;placed<trading;++placed){int slot=s_.random.below(n-2)+2,attempts=1;while(enemy[slot].kind&&attempts<2){slot=s_.random.below(n-2)+2;++attempts;}if(!enemy[slot].kind||!enemy[2].kind)enemy[slot].kind=Merchandise;}
    for(int i=2;i<n+2;++i)if(!enemy[i].kind){const int roll=s_.random.below(5);if(roll==0){enemy[i].kind=Barracks;enemy[i].quantity=s_.random.below(b)*4+b+1;}else if(roll==1){enemy[i].kind=Livestock;enemy[i].quantity=s_.random.below(b)*5+b+1;}else enemy[i].kind=roll==2?MachineGun:Cannon;}
    s_.trains[1]=std::move(enemy);for(int side=0;side<2;++side)s_.offsets[side]=int(s_.trains[side].size())*64/2-64;s_.columns=std::clamp(int(s_.trains[0].size()+s_.trains[1].size())*4+8,80,416);
    for(int slot=1;slot<int(s_.trains[1].size())*4;++slot)if(rnd(400)<s_.aggressiveness){const int count=rnd(b)+1;const int dir=rnd(3);constexpr int choices[]={2,6,8};add_actor(1,slot,-1,count,false,1,choices[dir]);}
    for(int side=0;side<2;++side){for(const auto&car:s_.trains[side])if(car.health>0&&(car.kind==Barracks||car.kind==Livestock))s_.army_strength[side]+=car.quantity;}for(const auto&[id,actor]:s_.actors)s_.army_strength[actor.side]+=actor.count;rng=s_.random;return true;
}
void Tactical::set_player_velocity(int v){s_.velocities[0]=std::clamp(v,-1,1);}
void Tactical::set_camera_offset(int v){s_.camera_offset=std::clamp(v,-center_offset(),center_offset());}
int Tactical::center_offset()const{return s_.columns*16/2-160;}
int Tactical::train_cell(int side,int wagon)const{return (288+s_.offsets[side]+center_offset()-wagon*64)/16;}
int Tactical::roof_cell(int side,int x)const{return (s_.offsets[side]+304-(x*16-center_offset()))/16;}
const Actor* Tactical::actor_at(int x,int y,int roof,int ignore)const{for(const auto&[id,a]:s_.actors){if(id==ignore||a.count<=0||a.roof!=roof)continue;const int span=a.mammoth&&roof<0?2:1;if(x>=a.x&&x<a.x+span&&y>=a.y&&y<a.y+span)return &a;}return nullptr;}
Actor* Tactical::actor(int x,int y,int roof,int ignore){return const_cast<Actor*>(actor_at(x,y,roof,ignore));}
int Tactical::add_actor(int side,int x,int y,int count,bool mammoth,int roof,int direction){const int id=s_.next_id++;s_.actors.emplace(id,Actor{id,side,x,y,count,mammoth,roof,direction,-1});return id;}
bool Tactical::free_cells(int x,int y,bool mammoth,int ignore)const{const int span=mammoth?2:1;if(x<0||x+span>s_.columns||y<0||y+span>7)return false;for(int dx=0;dx<span;++dx)for(int dy=0;dy<span;++dy)if(actor_at(x+dx,y+dy,-1,ignore))return false;return true;}
bool Tactical::deploy(int side,int wagon,int count){if(s_.outcome||side<0||side>1||wagon<0||wagon>=int(s_.trains[side].size()))return false;auto&car=s_.trains[side][wagon];if(car.health<=0||(car.kind!=Barracks&&car.kind!=Livestock))return false;const bool mammoth=car.kind==Livestock;const int amount=mammoth&&side==0?1:std::min(count,car.quantity);if(amount<=0||(!mammoth&&amount>30))return false;const int x=train_cell(side,wagon),y=side==0?(mammoth?5:6):0;if(!free_cells(x,y,mammoth))return false;car.quantity-=amount;const int direction=side==0?8:rnd(3)+3;add_actor(side,x,y,amount,mammoth,-1,direction);return true;}
bool Tactical::command(int id,int direction,int amount){if(s_.outcome||direction<0||direction>8)return false;auto found=s_.actors.find(id);if(found==s_.actors.end()||found->second.side!=0||found->second.count<=0)return false;const bool result=order(found->second,direction,amount);std::erase_if(s_.actors,[](const auto&pair){return pair.second.count<=0;});return result;}
bool Tactical::fire(int wagon){if(s_.outcome||wagon<0||wagon>=int(s_.trains[0].size()))return false;auto&car=s_.trains[0][wagon];if(car.health<=0||car.reload||(car.kind!=Cannon&&car.kind!=MachineGun))return false;car.reload=car.kind==Cannon?23:13;return true;}
bool Tactical::plant(int id,int delta){if(s_.outcome||(delta!=-1&&delta!=1))return false;auto found=s_.actors.find(id);if(found==s_.actors.end())return false;auto&a=found->second;if(a.side!=0||a.roof<0||a.count<=0)return false;const int slot=a.x+delta;if(slot<=0||slot>=int(s_.trains[a.roof].size())*4||actor_at(slot,-1,a.roof))return false;for(const auto&c:s_.charges)if(c.slot==slot&&c.side==a.roof)return false;s_.charges.push_back({a.roof,slot,5,0});return true;}
std::vector<Event> Tactical::advance(double delta){std::vector<Event> all;if(!std::isfinite(delta)||delta<0)return all;s_.remainder+=delta;while((s_.remainder>=step_seconds||std::abs(s_.remainder-step_seconds)<0.00001)&&!s_.outcome){s_.remainder-=step_seconds;auto next=step();all.insert(all.end(),next.begin(),next.end());}return all;}
std::vector<Event> Tactical::step(){events_.clear();if(s_.outcome)return events_;++s_.ticks;move_trains();enemy_ai();weapons();for(int cell=0;cell<std::max(s_.columns/4,40);++cell){auto*a=actor(s_.scan%s_.columns,s_.scan/s_.columns);if(a&&a->processed!=s_.sweep){a->processed=s_.sweep;update(*a);}++s_.scan;if(s_.scan==s_.columns*6)roof_sweep(1);if(s_.scan>=s_.columns*7){s_.scan=0;roof_sweep(0);s_.scan_side=1-s_.scan_side;++s_.sweep;}}
    std::erase_if(s_.actors,[](const auto&pair){return pair.second.count<=0;});check_end();for(auto&e:events_)e.tick=s_.ticks;return events_;
}
Pools Tactical::pools(int side)const{Pools p;for(const auto&c:s_.trains[side])if(c.health>0){if(c.kind==Barracks)p.soldiers+=c.quantity;else if(c.kind==Livestock)p.mammoths+=c.quantity;else if(c.kind==Cannon||c.kind==MachineGun)++p.guns;}for(const auto&[id,a]:s_.actors)if(a.side==side&&a.count>0)(a.mammoth?p.mammoths:p.soldiers)+=a.count;return p;}
void Tactical::check_end(){const auto enemy=pools(1);if(enemy.guns<=0&&s_.army_strength[1]<=0)s_.outcome=1;else if(s_.army_strength[0]<=0)s_.outcome=2;for(const auto&c:s_.trains[0])if((c.kind==Locomotive||c.kind==GQ||c.kind==Boudoir)&&c.health<=0)s_.outcome=2;}
}
