// SPDX-License-Identifier: MIT
// Exact sources scripts/{combat_setup,combat_outcome,automatic_combat}.gd;
// WDECOR0x5963..6053 and TEXTEK0x49fc..5a56, evidence/combat.md.
#include "outcome.hpp"
#include <algorithm>
namespace transartica::combat {
bool vital_intact(const std::vector<Wagon>& w){for(const auto&r:w)if((r.type==1||r.type==2||r.type==3)&&r.state>=3)return false;return true;}
Pools auto_pools(const std::vector<Wagon>& w){Pools p;for(const auto&r:w)if(r.state<3){if(r.type==7)p.mammoths+=r.quantity;else if(r.type==11||r.type==12)++p.guns;else if(r.type==23||r.type==24)p.soldiers+=r.quantity;}return p;}
int potential(Pools p){return(p.soldiers+p.mammoths*20+p.guns*50)/50;}
int margin(int p,int strength){return p-strength/100;}
namespace {
void coal(const std::vector<Wagon>& w,EngineState&e,int raw){int room=0;for(const auto&r:w)if(r.type==21&&r.state!=3)room+=5000;room=std::max(0,room-e.lignite-e.anthracite);e.lignite+=std::min(raw,room);if(e.lignite<0||e.lignite>31000)e.lignite=31000;}
int slaves(std::vector<Wagon>&w,int total,int gate){int remaining=total;for(auto&r:w){if(remaining<=0)break;if(r.state==3)continue;int cap=0;if(r.type==5&&r.quantity<gate)cap=60;else if(r.type==6&&r.quantity<100)cap=100;else continue;const int take=std::min(cap-r.quantity,remaining);r.quantity+=take;remaining-=take;}return total-remaining;}
void scrap_one(std::vector<Wagon>&w,Random&rng){for(int i=0;i<2;++i){auto&r=w[rng.below(int(w.size()))];if(r.type<=3||r.type==21||r.type>=22)return;if(r.state!=3){r.state=3;r.goods=r.quantity=0;return;}}}
int auto_rnd(Random&rng,int n){if(n==0){rng.next_u32();return 0;}return rng.range(0,n-1);}
EnemyReport enemy_report(int strength,Random&rng){const int a=strength/100,b=strength%100,half=(a+b)/2;EnemyReport r;r.wagons=auto_rnd(rng,half)+half+1;r.trading=r.wagons*b/(b+a+1);const int guns=(r.wagons-r.trading-1)/2;r.gun_groups[0]=auto_rnd(rng,guns);r.gun_groups[1]=guns-r.gun_groups[0];r.soldiers=r.wagons*6+auto_rnd(rng,r.wagons*6);r.mammoths=r.soldiers/(15+auto_rnd(rng,15))+1;return r;}
}
void apply_destruction(std::vector<Wagon>&w,EngineState&e,std::array<int,20>&spies,Random&rng){for(auto&r:w){if(r.state!=3)continue;if(r.type==21){if(rng.below(3)==0)e.anthracite-=5000;else e.lignite-=5000;if(e.lignite<0){e.anthracite+=e.lignite;e.lignite=0;}if(e.anthracite<0){e.lignite+=e.anthracite;e.anthracite=0;}e.lignite=std::max(0,e.lignite);}else if(r.type==22){int quantity=r.quantity;for(int&spy:spies){if(spy==1)spy=0;quantity=int((unsigned(quantity-1)+128U)&255U)-128;if(!quantity)break;}}r.goods=r.quantity=0;}}
void win_coal(const std::vector<Wagon>&w,EngineState&e,int n,Random&rng){coal(w,e,(n*2+rng.below(50))*10);}
int win_slaves(std::vector<Wagon>&w,int n,Random&rng){return slaves(w,n*3+rng.below(n*3),60);}
int win_survivors(std::vector<Wagon>&w,int total){int remaining=total;for(auto&r:w){if(remaining<=0)break;if(r.state==3)continue;const int cap=r.type==23&&r.quantity<50?50:r.type==24&&r.quantity<100?100:0;if(!cap)continue;const int take=std::min(cap-r.quantity,remaining);r.quantity+=take;remaining-=take;}return total-remaining;}
int win_mammoths(std::vector<Wagon>&w,int total){int remaining=total;for(auto&r:w){if(remaining<=0)break;if(r.state==3||r.type!=7)continue;const int take=std::min(5-r.quantity,remaining);if(take>0){r.quantity+=take;remaining-=take;}}return total-remaining;}
void capture_trading_wagons(std::vector<Wagon>&w,int count,Random&rng){for(int i=0;i<count&&w.size()<100;++i){const int type=17+rng.below(2),roll=rng.below(16)+1;const int goods=roll==3?roll:10+rng.below(7);const int quantity=rng.below(type==17?20:40)+1;w.push_back({type,0,goods,quantity});}}
AutomaticResult automatic_resolve(std::vector<Wagon>& w,EngineState&e,int strength,Random&rng){
    AutomaticResult result;if(strength<0||w.empty())return result;const auto p=auto_pools(w);result.potential=potential(p);result.margin=margin(result.potential,strength);result.enemy=enemy_report(strength,rng);result.won=result.margin>0;if(!result.won){result.epitaph_id=105;return result;}
    int soldiers=result.soldiers_lost=p.soldiers-p.soldiers/(result.margin+1);int mammoths=result.mammoths_lost=p.mammoths-p.mammoths/(result.margin+1);
    for(auto&r:w){if(r.type==7){r.quantity-=mammoths;if(r.quantity<0){mammoths=-r.quantity;r.quantity=0;}}else if(r.type==23||r.quantity==24){r.quantity-=soldiers;if(r.quantity<0){soldiers=-r.quantity;r.quantity=0;}}}
    const int target=std::max(0,9-result.margin);for(int attempt=0;attempt<8&&int(result.scrapped_indices.size())<target;++attempt){const auto before=w;scrap_one(w,rng);for(std::size_t i=0;i<w.size();++i)if(before[i].state!=3&&w[i].state==3)result.scrapped_indices.push_back(int(i));}
    const int before=e.lignite;coal(w,e,(result.enemy.wagons*2+rng.below(50)+1)*10);result.coal_gained=e.lignite-before;result.slaves_gained=slaves(w,result.enemy.wagons*3+rng.below(result.enemy.wagons*3),30);
    const auto count=w.size();for(int i=0;i<std::min(result.margin,8)&&w.size()<100;++i){const int type=17+auto_rnd(rng,2);int goods=auto_rnd(rng,16)+1,cap=40;if(goods==2||goods==3)cap=10;else if(goods==5||goods==6||goods==8||goods==9)goods=10+auto_rnd(rng,7);const int quantity=auto_rnd(rng,type==17?cap/2:cap)+1;w.push_back({type,0,goods,quantity});}
    result.wagons_captured=int(w.size()-count);result.captured.assign(w.begin()+count,w.end());e.train_mass=train_mass(w);return result;
}
}
