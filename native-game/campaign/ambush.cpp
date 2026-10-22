// SPDX-License-Identifier: MIT
// Source campaign_ambush.gd, TEXTEK0x1875..1e31. Loss/report order is intentional.
#include "state.hpp"
#include <algorithm>
namespace transartica::campaign {
Defenders defenders(const std::vector<Wagon>& wagons,const Data& data) {
    int mammals=0,guns=0,infantry=0;
    for(const auto& w:wagons) {
        if(w.type==7) mammals+=w.quantity;
        else if(w.type==12&&w.state<3) ++guns;
        else if(w.type==23||w.type==24) infantry+=w.quantity;
    }
    return {std::max(2,10-(infantry+mammals*30+guns*60)/40),{
        data.phrase(true,0x449b)+std::to_string(infantry)+data.phrase(true,0x449b,1),
        data.phrase(true,0x44c3)+std::to_string(mammals)+data.phrase(true,0x44c3,1),
        data.phrase(true,0x44ec)+std::to_string(guns)+data.phrase(true,0x44ec,1)}};
}
Lines human_losses(std::vector<Wagon>& wagons,int divisor,const Data& data) {
    int mammals=0,slaves=0,infantry=0;
    for(auto& w:wagons) {
        if(w.type==7) {w.quantity-=w.quantity/divisor;mammals+=w.quantity/divisor;}
        else if(w.type==5||w.type==6||w.type==23||w.type==24) {
            int loss=w.quantity/divisor;if(w.type==5||w.type==6) slaves+=loss;else infantry+=loss;w.quantity-=loss;
        }
    }
    Lines lines{data.phrase(true,0x1c9f)};
    if(slaves>0) lines.push_back(data.phrase(true,0x1dc3)+std::to_string(slaves));
    lines.push_back(data.phrase(true,0x1de4)+std::to_string(infantry));
    if(mammals>0) lines.push_back(data.phrase(true,0x1e13)+std::to_string(mammals));return lines;
}
namespace {
Lines wolf_materials(std::vector<Wagon>& wagons,const Data& data,Random& rng) {
    std::array<int,3> losses{};
    for(auto& w:wagons) if((w.type==17||w.type==18)&&w.goods>=11&&w.goods<=13) {
        int loss=w.quantity/2;losses[w.goods-11]+=loss;w.quantity-=loss;
    }
    Lines lines{data.phrase(true,0x18b7)};constexpr std::array<int,3> offsets{0x1a0a,0x1a34,0x1a5e};
    for(int i=0;i<3;++i) if(losses[i]>0) lines.push_back(std::to_string(losses[i])+data.phrase(true,offsets[i]));
    if(lines.size()==1) lines.push_back(data.phrase(true,0x19f2));rng.range(0,3);return lines;
}
}
Lines material_losses(bool wolf,std::vector<Wagon>& wagons,EngineState& engine,int divisor,const Data& data,Random& rng) {
    if(wolf) return wolf_materials(wagons,data,rng);
    int first=engine.anthracite/divisor,second=engine.lignite/divisor;
    engine.anthracite-=first;engine.lignite-=second;int reported=(first+second)/10,destroyed=0;
    if(wagons.size()>4) for(auto& w:wagons) if(w.type>3&&w.type!=21) {destroyed=w.type;w.state=3;w.goods=0;w.quantity=0;break;}
    Lines lines{data.phrase(true,0x1a99)};
    if(destroyed>0) {
        auto name=data.wagon_names.find(destroyed);
        lines.push_back(data.phrase(true,0x1bee)+(name==data.wagon_names.end()?"":name->second)+data.phrase(true,0x1bee,1));
    }
    if(first>0) lines.push_back(std::to_string(second)+data.phrase(true,0x1c2c));
    if(reported>0) lines.push_back(std::to_string(first)+data.phrase(true,0x1c59));
    if(destroyed==0&&second==0&&reported==0) lines.push_back(data.phrase(true,0x1ba8));
    rng.range(0,4);return lines;
}
}
