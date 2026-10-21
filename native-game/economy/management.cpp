// SPDX-License-Identifier: MIT
#include "management.hpp"
#include <algorithm>
#include <array>
namespace transartica::economy {
namespace { constexpr std::array<int,25> prices{100,80,50,80,10,15,20,60,30,50,50,40,80,30,30,60,10,15,40,30,10,60,15,20,80}; }
std::string Management::station_name(Cell cell) {
    if(cell.x<30) return "LEEDS STATION";
    if(cell.x<70) return "AOUDJILA STATION";
    if(cell.x<100) return "NOVOMOSKOVSK STATION";
    return cell.y<50?"BALKHACH STATION":"OMAN STATION";
}
int Management::repair_price(int index) const {
    if(index<0||index>=int(wagons_.size())) return 0;
    const auto& w=wagons_[index]; if(w.type<1||w.type>25) return 0;
    return prices[w.type-1]*w.state;
}
int Management::repair_refusal(int index) const {
    if(index<0||index>=int(wagons_.size())) return 88;
    const int state=wagons_[index].state;
    if(state==3) return 87;
    if(state==0) return 35;
    return engine_.lignite<repair_price(index)?50:0;
}
bool Management::repair(int index,bool confirm) {
    if(!confirm||repair_refusal(index)) return false;
    engine_.lignite-=repair_price(index); wagons_[index].state=0; return true;
}
int Management::remove_refusal(int index) const {
    if(index<0||index>=int(wagons_.size())) return 88;
    const auto& w=wagons_[index];
    // Exact source compares tender QUANTITY to3, not its damage STATE.
    return w.type<4||(w.type==21&&w.quantity!=3)?88:0;
}
bool Management::remove(int index,bool confirm) {
    if(!confirm||remove_refusal(index)) return false;
    wagons_.erase(wagons_.begin()+index); return true;
}
bool Management::move(int from,int to) {
    if(from<0||to<0||from>=int(wagons_.size())||to>=int(wagons_.size())) return false;
    const auto saved=wagons_[from]; wagons_.erase(wagons_.begin()+from); wagons_.insert(wagons_.begin()+to,saved); return true;
}
Equipment Management::equipment_flags() const {
    Equipment result;
    for(const auto& w:wagons_) if(w.state<3) {
        if(w.type==4) result.instruments=2;
        else if(w.type==10) result.instruments=std::max(result.instruments,1);
        else if(w.type==13) result.launcher=true;
    }
    return result;
}
bool Management::valid_workshop(const WorkshopState& value) const {
    const int count=int(wagons_.size());
    if(value.selected< -1||value.selected>=count||value.moving< -1||value.moving>=count) return false;
    if(value.action<50||value.action>53||value.scroll<0||value.scroll>std::max(0,count-10)) return false;
    if(value.moving>=0&&(!value.visible||value.action!=50||value.selected!=value.moving)) return false;
    if(!value.confirmation) return true;
    if(!value.visible||value.selected<0||(value.action!=52&&value.action!=53)) return false;
    return value.action==52?repair_refusal(value.selected)==0:remove_refusal(value.selected)==0;
}
}
