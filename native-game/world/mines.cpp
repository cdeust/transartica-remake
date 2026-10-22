// SPDX-License-Identifier: MIT
// Sources: scripts/mines.gd, mine_extraction.gd and tasks/evidence/mines.md.
#include "mines.hpp"
#include <algorithm>
namespace transartica::world {
int Mines::free_slot()const{for(int i=0;i<36;++i)if(!records_[i].signed_day)return i;return -1;}
int Mines::slot_for_cell(Cell c)const{for(int i=0;i<36;++i)if(records_[i].signed_day&&records_[i].cell()==c)return i;return -1;}
bool Mines::restore(const MineState& s){bool free=false;for(const auto&r:s){if(r.dx< -40||r.dx>119||r.y<0||r.y>72||r.wealth< -4||r.wealth>49)return false;if(r.signed_day){if(free)return false;}else free=true;}records_=s;return true;}
MapWrites Mines::deplete(){MapWrites writes;for(auto&r:records_)if(r.signed_day&&r.wealth>0){r.wealth-=5;if(r.wealth<1)writes.push_back({r.cell(),79});}return writes;}
std::optional<Mines::Placement> Mines::placement(Cell c,const RailNetwork& n){
    const int tile=n.tile(c);if(tile!=2&&tile!=3)return {};
    struct Corner {int excluded_a,excluded_b,code;};
    constexpr Corner rows[2][2][2]={{{{18,19,20},{22,23,24}},{{20,21,18},{24,25,22}}},{{{28,29,32},{32,33,28}},{{26,27,30},{30,31,26}}}};
    for(int group=0;group<2;++group){const int dx=group==0?-1:1;
        for(int corner=0;corner<2;++corner){const int dy=corner==0?-1:1;const Cell mine=c+Cell{dx,dy};const int empty=n.tile(mine);
            if(!(empty==0||empty>85||empty< -124))continue;
            const Cell neighbor=c+(tile==2?Cell{dx,0}:Cell{0,dy});const auto& rule=rows[tile-2][group][corner];const int code=n.tile(neighbor);
            if(code==rule.excluded_a||code==rule.excluded_b)break;
            return Placement{c,mine,rule.code};
        }
    }return {};
}
MapWrites Mines::create(int day,const RailNetwork& n,Random& rng){
    const int slot=free_slot();if(day<1||day>127||slot<0)return {};
    const int cx=rng.range(0,137)+11;const int cy=rng.range(0,49)+11;
    for(int x=cx-10;x<=cx+10;++x)for(int y=cy-10;y<=cy+10;++y)if(auto p=placement({x,y},n)){
        const bool anthracite=rng.range(0,1)==0;const int wealth=rng.range(0,9)+40;
        records_[slot]={p->mine.x-40,p->mine.y,anthracite?-day:day,wealth};return {{p->track,p->code},{p->mine,78}};
    }return {};
}
MapWrites Mines::tick(int day,const RailNetwork& n,Random& rng){auto result=deplete();auto next=create(day,n,rng);for(auto write:next){auto found=std::find_if(result.begin(),result.end(),[&](const auto&v){return v.first==write.first;});if(found!=result.end())*found=write;else result.push_back(write);}return result;}
MapWrites Mines::prospect(int slot,bool accept){if(slot<0||slot>=36||!records_[slot].signed_day||!accept)return {};records_[slot].wealth=-1;return {{records_[slot].cell(),79}};}
namespace {
std::string format(std::string value,const std::vector<int>& args){for(int n:args){const auto at=value.find("%s");if(at==std::string::npos)return {};value.replace(at,2,std::to_string(n));}return value;}
}
std::vector<std::string> Mines::report(int slot,const std::map<std::string,std::string>& p)const{
    if(slot<0||slot>=36||!records_[slot].signed_day)return {};
    for(const char* key:{"title_closed","title_open","ore_anthracite","ore_lignite","coordinates","date"})if(!p.contains(key))return {};
    const auto&r=records_[slot];return {p.at(r.wealth<1?"title_closed":"title_open")+p.at(r.signed_day<0?"ore_anthracite":"ore_lignite"),format(p.at("coordinates"),{r.dx+40,r.y}),format(p.at("date"),{std::abs(r.signed_day)})};
}
int signed_word(int n){return int((unsigned(n)+32768U)&65535U)-32768;}
MineResources mine_resources(const std::vector<Wagon>& wagons){MineResources out;for(const auto&w:wagons){if(w.type==5||w.type==6)out.slaves=signed_word(out.slaves+w.quantity);else if(w.type==7)out.mammoths=signed_word(out.mammoths+w.quantity);else if(w.type==16&&w.state<3)++out.cranes;}return out;}
int mine_quantity(const std::vector<Wagon>& wagons,MineResources crew,int wealth,int lignite,int anthracite){int capacity=0;for(const auto&w:wagons)if(w.type==21&&w.state!=3)capacity=signed_word(capacity+5000);if(capacity<0)capacity=32000;const int free=signed_word(capacity-(anthracite+lignite));int work=signed_word(crew.slaves+crew.mammoths*30);if(crew.cranes)work=signed_word(work+150);int quantity=signed_word((std::max(wealth,0)+1)*(work/5+1));if(quantity<0)quantity=30000;return std::min(quantity,free);}
int credited_coal(int before,int quantity){const int total=signed_word(before+quantity);return total<0||total>31000?31000:total;}
}
