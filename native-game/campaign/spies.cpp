// SPDX-License-Identifier: MIT
// Source campaign_spies.gd: MAIN0x3b, CARTE0x1dc9/0x27a4, TIME0x976.
#include "state.hpp"
#include <cstdlib>
namespace transartica::campaign {
namespace {int sign(std::int64_t value) {return (value>0)-(value<0);} bool bounds(Cell c) {return c.x>=0&&c.x<160&&c.y>=0&&c.y<73;}}
bool consume(std::vector<Wagon>& wagons,int goods,int type) {
    for(auto& w:wagons) if((type!=0?w.type==type:w.goods==goods)&&w.quantity>0) {
        --w.quantity;if(type==0&&w.quantity==0) w.goods=0;return true;
    }
    return false;
}
int goods_count(const std::vector<Wagon>& wagons,int goods) {int total=0;for(const auto& w:wagons) if(w.goods==goods) total+=w.quantity;return total;}
void State::sync_recruits(economy::Trade& trade) {
    const auto slots=trade.snapshot().spy_slots;
    for(int i=0;i<20;++i) {
        int value=slots[i];
        if(value==1&&spies[i][0]==0) spies[i][0]=1;
        else if(value==0&&spies[i][0]==1) spies[i].fill(0);
        trade.set_spy_slot(i,int(spies[i][0]));
    }
}
int State::send_spy(Cell destination,Cell player,std::vector<Wagon>& wagons,economy::Trade& trade) {
    sync_recruits(trade);if(!bounds(destination)) return -1;
    for(int i=0;i<20;++i) if(spies[i][0]==1) {
        auto& r=spies[i];r[0]=2;r[1]=player.x-40;r[2]=player.y;r[3]=destination.x-40;r[4]=destination.y;
        consume(wagons,0,22);trade.set_spy_slot(i,2);return i;
    }
    return -1;
}
std::vector<int> State::advance_spies(RailNetwork& network,economy::Trade& trade) {
    std::vector<int> arrived;
    for(int i=0;i<20;++i) {
        auto& r=spies[i];if(r[0]!=2) continue;
        if(++r[5]!=3) continue;r[5]=0;r[1]+=sign(r[3]-r[1]);r[2]+=sign(r[4]-r[2]);
        if(r[1]!=r[3]||r[2]!=r[4]) continue;
        r[0]=3;r[6]=5;trade.set_spy_slot(i,3);Cell cell{int(r[1]+40),int(r[2])};arrived.push_back(i);
        if(std::abs(r[1]-25)<2&&std::abs(r[2]-20)<2) {
            network.set_campaign_tile(cell,-124);network.set_campaign_tile({cell.x-1,cell.y},-124);stoup.push(127);
        }
    }
    return arrived;
}
int State::posted_at(Cell cell) const {
    for(int i=0;i<20;++i) if(spies[i][0]==3&&spies[i][1]+40==cell.x&&spies[i][2]==cell.y) return i;
    return -1;
}
bool State::retrieve_spy(int index,bool accept,economy::Trade& trade) {
    if(index<0||index>=20||spies[index][0]!=3) return false;
    if(accept) {spies[index].fill(0);spies[index][0]=1;trade.set_spy_slot(index,1);}
    else spies[index][13]%=100;
    return true;
}
void State::observe_enemy(int slot,Cell cell,const GameCalendar& calendar) {
    int index=posted_at(cell);if(index<0) return;
    auto& r=spies[index];stoup.push(index+101);
    r[8]=r[7];r[7]=slot+1;r[12]=r[9];r[9]=calendar.day;r[13]=r[10];r[10]=calendar.hour;r[14]=r[11];r[11]=calendar.minute;
}
bool State::sabotage(int index,RailNetwork& network) {
    if(index<0||index>=20) return false;auto& r=spies[index];
    if(r[0]!=3||r[13]>99) return false;r[13]+=100;Cell cell{int(r[1]+40),int(r[2])};int code=network.tile(cell);
    if(code==-124) {central_destroyed=true;stoup.push(125);}
    else if(code==63) network.set_campaign_tile(cell,67);
    else if(code==64) network.set_campaign_tile(cell,69);
    else if(code==-117) network.set_campaign_tile(cell,114);
    else if(code==-121) network.set_campaign_tile(cell,-116);
    else if(code>1&&code<59&&(code<34||code>37)) network.set_campaign_tile(cell,-code);
    return true;
}
}
