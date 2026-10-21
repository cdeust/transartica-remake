// SPDX-License-Identifier: MIT
// Oracles: game/tests/test_city_trade.gd; train_management.gd GLIEU references;
// tasks/evidence/city-scripts.md. Real private tables, no generated price fixtures.
#include "economy/trade.hpp"
#include "economy/management.hpp"
#include "economy/world_data.hpp"
#include <algorithm>
#include <iostream>
#include <stdexcept>
using namespace transartica;
using namespace transartica::economy;
namespace {
int checks=0,failures=0;
void check(bool value,const std::string& label) { ++checks; if(!value) { ++failures; std::cerr<<"FAIL: "<<label<<'\n'; } }
Offer required(const Trade& trade,int city,int kind,int mode,int goods=0) {
    auto result=trade.offer(city,kind,mode,goods); if(!result) throw std::runtime_error("Missing source offer"); return *result;
}
void data_rules(Trade& trade,const WorldData& world) {
    check(world.cities().size()==46,"46 VILLE records");
    check(world.city(0)&&world.city(0)->name=="CASABLANCA"&&world.city(0)->anchor==Cell{6,53},"source first city decoded anchor");
    check(world.city(24)&&world.city(24)->name=="KUWAIT"&&world.city(24)->kind==Commercial,"source city index24 is Kuwait commercial");
    check(!world.city(-1)&&!world.city(46)&&world.map_code({-1,0})==-1&&world.map_code({160,0})==-1,"city and map bounds");
    for(int i=0;i<46;++i) {
        const auto& c=world.cities()[i]; check(world.city_at(c.anchor)==i,"city anchor lookup "+std::to_string(i));
        if(c.kind==Commercial) for(int goods=1;goods<=16;++goods) check(trade.offer(i,c.kind,Buy,goods).has_value(),"commercial price coverage");
        if(c.kind==MammothFair||c.kind==SlaveMarket||c.kind==Garrison) check(trade.offer(i,c.kind,Buy).has_value(),"market price coverage");
    }
    check(world.map_code({6,53})==76,"CARTE unsigned source accessor");
    check(trade.goods_name(1)=="RAILS"&&trade.wagon_name(21)=="TENDER"&&trade.wagon_name(25)=="BOILER","source names");
    check(!trade.offer(1,SlaveMarket,Buy)&&!trade.offer(24,Commercial,Buy,0)&&!trade.offer(24,Commercial,Buy,17),"missing/inapplicable offers");
    int sold=0; for(const auto& row:trade.snapshot().stock) for(int stock:row) if(stock>=0) ++sold;
    check(sold==94,"TABLE94 traded goods");
}
void transaction_rules(Trade& trade) {
    auto wagons=initial_wagons(); EngineState engine;
    auto state=trade.snapshot(); state.stock[0][0]=30; check(trade.restore(state),"stage stock fixture");
    const auto rails=required(trade,24,Commercial,Buy,1);
    check(Trade::price(rails)==4&&trade.capacity(rails,wagons).room==20,"Kuwait rails unit4 and capacity20");
    check(trade.increment_refusal(rails,20,wagons,engine)==NoRoom,"21st rail capacity refusal");
    engine.lignite=10;
    check(trade.increment_refusal(rails,1,wagons,engine)==0&&trade.increment_refusal(rails,2,wagons,engine)==NoMoney,"exact affordability boundary");
    engine.lignite=2000; state.stock[0][0]=2; trade.restore(state);
    check(trade.increment_refusal(rails,2,wagons,engine)==StockLimit,"silent stock refusal");
    state.stock[0][0]=30; trade.restore(state);
    check(trade.commit(rails,5,wagons,engine)==0&&engine.lignite==1980&&wagons[4]==Wagon{17,0,1,5}&&trade.snapshot().stock[0][0]==25,"purchase debit/load/stock oracle");
    const auto wood=required(trade,24,Commercial,Buy,7);
    check(trade.capacity(wood,wagons).room==0,"different goods cannot share wagon");
    check(trade.goods_list(24,Sell,wagons)==std::vector<GoodsRow>{{1,5}},"sale list from actual load");
    const auto sale=required(trade,24,Commercial,Sell,1);
    engine.lignite=4500;
    check(trade.increment_refusal(sale,0,wagons,engine)==NoCoalRoom,"coal capacity includes anthracite");
    auto before=wagons; const auto old_engine=engine; const auto old_stock=trade.snapshot();
    check(trade.commit(sale,1,wagons,engine)==NoCoalRoom&&wagons==before&&engine==old_engine&&trade.snapshot()==old_stock,"stale transaction refuses atomically");
    engine.lignite=1000;
    check(trade.increment_refusal(sale,5,wagons,engine)==NotEnoughLoad,"sixth rail sale refused");
    check(trade.commit(sale,5,wagons,engine)==0&&engine.lignite==1010&&wagons[4]==Wagon{17,0,0,0}&&trade.snapshot().stock[0][0]==30,"sale credit and empty wagon clearing");
    wagons[4]={17,0,1,5}; state=trade.snapshot(); state.stock[0][0]=127; trade.restore(state);
    check(trade.commit(sale,2,wagons,engine)==0&&trade.snapshot().stock[0][0]==-128,"signed stock wrap stops later stocking");
    state=trade.snapshot(); state.stock[0][0]=-1; trade.restore(state);
    check(trade.commit(sale,1,wagons,engine)==0&&trade.snapshot().stock[0][0]==-1,"unsold goods stay unstocked");
    // Source money clamp fixture with enough real tender room to reach the credit path.
    wagons=initial_wagons(); for(int i=0;i<6;++i) wagons.push_back({21,0,0,0}); wagons[4]={17,0,1,5}; engine.lignite=30999;
    check(trade.commit(sale,5,wagons,engine)==0&&engine.lignite==31000,"sale clamp31000");
    state=trade.snapshot(); state.stock[0][0]=30; trade.restore(state); engine.lignite=31500;
    check(trade.commit(rails,1,wagons,engine)==0&&engine.lignite==31496,"debit is never clamped");
    wagons={{17,0,0,0},{18,0,0,0},{21,0,0,0}}; engine.lignite=1000;
    check(trade.commit(rails,25,wagons,engine)==0&&wagons[0].quantity==20&&wagons[1].quantity==5,"loading follows wagon order and capacities");
    check(trade.commit(sale,23,wagons,engine)==0&&wagons[0].goods==0&&wagons[1].quantity==2,"unloading follows wagon order");
}
void recruitment_rules(Trade& trade) {
    auto wagons=initial_wagons(); EngineState engine;
    auto soldiers=required(trade,5,Garrison,Buy);
    auto cap=trade.capacity(soldiers,wagons);
    check(Trade::price(soldiers)==6&&cap.room==40&&cap.loaded==10,"Abu Dhabi soldiers oracle");
    check(trade.commit(soldiers,3,wagons,engine)==0&&wagons[5].quantity==13&&engine.lignite==1982,"soldiers purchase");
    auto spies=required(trade,8,Garrison,Sell);
    check(spies.spy&&spies.mode==Buy&&trade.offers_spies(8)&&!trade.offers_spies(5),"spy menu is a purchase path");
    check(trade.entry_refusal(spies,wagons)==NoRoom,"spy wagon required");
    wagons.push_back({22,0,0,0}); auto state=trade.snapshot(); state.spy_slots.fill(3); state.spy_slots[19]=0; trade.restore(state);
    check(trade.capacity(spies,wagons).room==1&&trade.increment_refusal(spies,1,wagons,engine)==NoRoom,"spy files cap physical wagon room");
    check(trade.commit(spies,1,wagons,engine)==0&&trade.snapshot().spy_slots[19]==1&&!trade.offers_spies(8),"one spy allocates last file");
    check(!trade.set_spy_slot(20,0)&&!trade.set_spy_slot(0,4)&&trade.set_spy_slot(19,2),"shared campaign slot transitions bounds");
    auto mammoths=required(trade,1,MammothFair,Sell);
    check(trade.entry_refusal(mammoths,wagons)==NothingToSell,"mammoth sale entry refusal");
}
void workshop_rules(Trade& trade) {
    const int expected[]={8,8,5,7,6,1,8};
    for(int i=0;i<7;++i) check(trade.workshop_list(i+10).size()==std::size_t(expected[i]),"workshop source catalogue size");
    check(trade.workshop_list(9).empty()&&trade.workshop_list(10).front()==Entry{21,100}&&trade.workshop_list(15)==std::vector<Entry>{{8,800}},"named workshop catalogue oracles");
    auto wagons=initial_wagons(); EngineState engine; engine.lignite=10000;
    check(Trade::workshop_refusal({21,100},4,wagons,engine)==0&&Trade::workshop_refusal({21,100},5,wagons,engine)==TenderLimit,"six intact tenders maximum");
    wagons[1].state=3; check(Trade::workshop_refusal({21,100},5,wagons,engine)==0,"scrap tender excluded");
    engine.lignite=1600;
    check(Trade::buy_wagons({8,800},2,wagons,engine)==0&&engine.lignite==0&&wagons.size()==8&&wagons[6]==Wagon{8,0,0,0},"two drills debit and append");
    engine.lignite=100000; wagons.assign(99,{17,0,0,0});
    check(Trade::workshop_refusal({7,1},0,wagons,engine)==0,"source checks99 before increment");
    check(Trade::buy_wagons({7,1},1,wagons,engine)==0&&wagons.size()==100&&Trade::workshop_refusal({7,1},0,wagons,engine)==WagonsFull,"100th allowed101st refused");
    wagons={{1,0,0,0},{4,2,0,0},{21,3,0,0},{21,0,0,3},{10,0,0,0},{13,3,0,0}};
    Management management(engine,wagons);
    check(management.repair_price(1)==160&&management.repair_refusal(2)==87&&management.repair_refusal(0)==35,"repair price and refusal ordering");
    engine.lignite=159; check(management.repair_refusal(1)==NoMoney&&!management.repair(1,true),"repair affordability");
    engine.lignite=160; check(!management.repair(1,false)&&engine.lignite==160&&management.repair(1,true)&&engine.lignite==0&&wagons[1].state==0,"repair confirmation charges once");
    check(management.remove_refusal(0)==88&&management.remove_refusal(2)==88&&management.remove_refusal(3)==0,"tender protection checks quantity not state");
    check(!management.remove(3,false)&&management.remove(3,true)&&wagons.size()==5,"remove confirmation");
    auto first=wagons[0]; check(management.move(0,4)&&wagons[4]==first&&wagons[0].type==4,"move inserts at unchanged destination index");
    auto flags=management.equipment_flags(); check(flags.instruments==2&&!flags.launcher,"equipment ignores scrap");
    check(!management.move(-1,0)&&!management.remove(99,true)&&management.repair_price(-1)==0,"management invalid indices");
    check(Management::station_name({29,60})=="LEEDS STATION"&&Management::station_name({30,60})=="AOUDJILA STATION"&&Management::station_name({70,60})=="NOVOMOSKOVSK STATION","station x thresholds");
    check(Management::station_name({100,49})=="BALKHACH STATION"&&Management::station_name({100,50})=="OMAN STATION","station y threshold");
    WorkshopState state; state.visible=true; state.action=50; state.selected=0; state.moving=0;
    check(management.valid_workshop(state),"moving workshop selection can resume");
    state.moving=1; check(!management.valid_workshop(state),"moving source and selected must agree");
    state.moving=-1; state.action=52; state.confirmation=true;
    check(!management.valid_workshop(state),"cannot restore stale repair confirmation on undamaged wagon");
    state.confirmation=false; state.scroll=1;
    check(!management.valid_workshop(state),"workshop scroll validated against current train");
}
void state_rules(Trade& trade) {
    auto good=trade.snapshot(),bad=good; bad.stock[0][0]=128;
    check(!trade.restore(bad)&&trade.snapshot()==good,"invalid stock restore preserves state");
    bad=good; bad.spy_slots[0]=4; check(!trade.restore(bad)&&trade.snapshot()==good,"invalid spy restore preserves state");
    Random random; random.seed(7); const auto before=random; trade.visit(24,random);
    check(random==before,"ordinary visit consumes no RNG");
    auto expected=random; int amount=5+expected.below(40); trade.visit(45,random);
    check(random==expected&&trade.snapshot().stock[21][3]==amount,"nomad visit exact RNG/stock");
    auto saved=trade.snapshot(); Trade restored; check(restored.restore(saved)&&restored.snapshot()==saved,"typed economy state roundtrip");
}
}
int main(int argc,char** argv) {
    if(argc!=2) { std::cerr<<"usage: economy_tests GAME_PRIVATE_DATA_DIRECTORY\n"; return 2; }
    try {
        Trade trade; WorldData world; std::string error;
        if(!trade.load(argv[1],error)||!world.load(argv[1],error)) throw std::runtime_error(error);
        Random random; random.seed(7); trade.reset(random);
        data_rules(trade,world); transaction_rules(trade); recruitment_rules(trade); workshop_rules(trade); state_rules(trade);
        std::cout<<checks<<" economy checks, "<<failures<<" failures\n"; return failures?1:0;
    } catch(const std::exception& e) { std::cerr<<"economy fixture: "<<e.what()<<'\n'; return 2; }
}
