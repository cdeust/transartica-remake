// SPDX-License-Identifier: MIT
// Source campaign_state.gd; decoded offsets are retained alongside effects.
#include "state.hpp"
#include <algorithm>
namespace transartica::campaign {
namespace {Pending event(Scene scene,std::vector<int> messages) {Pending e;e.scene=scene;e.messages=std::move(messages);return e;}}
void State::reveal(Cell cell,std::string_view region,int adjust,RailNetwork& network,const Data& data) {
    if(network.tile(cell)!=-115) return;auto it=data.regions.find(std::string(region));if(it==data.regions.end()) return;
    for(const auto& r:it->second) if(Cell{r.cell.x+adjust,r.cell.y}==cell) {network.set_campaign_tile(cell,r.code);return;}
}
Pending State::prepare_entry(Cell cell,int heading,const std::vector<Wagon>& wagons,RailNetwork& network,const Data& data,bool after_spy) {
    if(!pending.empty()||ending!=Ending::None) return pending;
    int spy=posted_at(cell);
    if(spy>=0&&!after_spy) {pending=event(Scene::SpyPickup,{21});pending.spy=spy;return pending;}
    const int code=network.tile(cell);
    if(cell.x>38&&cell.x<59&&cell.y>19&&cell.y<34) {
        if(cell==Cell{39,32}&&code==34) network.set_campaign_tile(cell,2);
        reveal(cell,"hima",0,network,data);
    } else if(cell.x>138&&cell.x<158&&cell.y>46&&cell.y<69) {
        if(cell==Cell{157,68}&&code==36&&central_destroyed) network.set_campaign_tile(cell,3);
        reveal(cell,"trans",256,network,data);
        if(cell==Cell{152,48}&&heading==1&&wagons.size()>5&&std::none_of(wagons.begin(),wagons.end(),[](const Wagon& w){return w.type==25;}))
            pending=event(Scene::Slope,{18}); // TIME0x1f53 intentionally has no damage test.
    } else {
        if(cell==Cell{11,10}&&whale_present) {
            bool harpoon=std::any_of(wagons.begin(),wagons.end(),[](const Wagon& w){return w.type==9&&w.state<3;});
            if(harpoon) {whale_present=false;pending=event(Scene::WhaleHarpoon,{53});pending.reverse=true;}
            else {pending=event(Scene::WhaleQuestion,{28});pending.epitaph=104;}
            return pending;
        }
        if(cell.y==67) {
            if(cell.x==32&&code==35&&!wagons.empty()&&(wagons.front().type==8||wagons.back().type==8)) network.set_campaign_tile(cell,2);
            if(cell.x==28&&code==88) network.set_campaign_tile(cell,54);
            if(cell.x==29&&code==89) network.set_campaign_tile(cell,-114);
            if(cell.x==30&&code==90) network.set_campaign_tile(cell,-113);
            reveal(cell,"oasis",0,network,data);
        }
    }
    return pending;
}
Pending State::station(int index,RailNetwork& network) {
    switch(index) {
    case -2:
        network.set_campaign_tile({22,67},-122);pending=event(Scene::Urga,urga_key?std::vector<int>{88}:std::vector<int>{86,87});urga_key=true;break;
    case -3:
        network.set_campaign_tile({34,4},80);pending=event(Scene::Oslo,{89,90});pending.code_input=urga_key;break;
    case -4:network.set_campaign_tile({52,32},-123);pending=event(Scene::Mausoleum,{51});break;
    case -5:ending=Ending::Sun;pending=event(Scene::Sun,{19});break;
    default:return {};
    }
    return pending;
}
bool State::submit_code(std::string_view text) {
    if(!urga_key||pending.scene!=Scene::Oslo||!pending.code_input||!pending.quiz_done||text!="58947") return false;
    const bool first=!delivery_open;delivery_open=true;if(first) fauna.oslo();
    if(first&&!sos_sent) {sos_sent=true;stoup.push(126);}
    pending=event(Scene::Oslo,{91});pending.departure_chime=first;return true;
}
Pending State::dismiss() {Pending result=std::move(pending);pending={};return result;}
Pending State::choose_whale(bool proceed) {
    if(pending.scene!=Scene::WhaleQuestion) return {};
    if(proceed) return die(104);
    return dismiss();
}
Pending State::die(int reason) {
    if(reason<100||reason>105) return {};ending=Ending::Death;pending=event(Scene::Death,{});pending.epitaph=reason;return pending;
}
}
