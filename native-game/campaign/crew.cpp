// SPDX-License-Identifier: MIT
// Source campaign_crew.gd; ROOM/CARTE/TIME menu and stoup dispatch.
#include "controller.hpp"
#include <algorithm>
namespace transartica::campaign {
void Controller::return_to_room() {
    emit(state_.return_room==Room::City?ActionKind::ResumeCity:state_.return_room==Room::Boudoir?ActionKind::Boudoir:ActionKind::Quarters,-1);
}
void Controller::read_stoup(Room room) {
    state_.return_room=room;auto message=state_.state.stoup.pop();if(!message) return;state_.notice=true;
    if(*message<51) set_presentation(Scene::Report,host_.mine_report(*message-1,data_.mine_bulletin));
    else if(*message>=101&&*message<=120) set_presentation(Scene::Report,spy_report(*message-101,state_.state,data_,host_));
    else set_presentation(Scene::None,data_.message(*message));
}
void Controller::show_town(int id) {state_.return_room=Room::City;state_.notice=true;set_presentation(Scene::None,data_.message(id,true));}
void Controller::open_menu(Lines labels) {set_presentation(Scene::Crew,{});state_.presentation.menu=std::move(labels);}
void Controller::open_spy_menu() {
    state_.return_room=Room::Quarters;state_.state.sync_recruits(trade_);
    bool available=std::any_of(state_.state.spies.begin(),state_.state.spies.end(),[](const SpyRecord& r){return r[0]>=1&&r[0]<=3;});
    if(!available) {state_.notice=true;set_presentation(Scene::None,data_.message(9));return;}
    state_.crew_menu=CrewMenu::Spies;open_menu({"SEND SPY","DYNAMITE","EXIT"});
}
void Controller::open_car_menu() {
    state_.return_room=Room::Quarters;
    if(goods_count(session_.wagons,3)==0) {state_.notice=true;set_presentation(Scene::None,data_.message(8));return;}
    state_.crew_menu=CrewMenu::Cars;open_menu({"LINE INSPECTION CAR","MISSILE CAR","EXIT"});
}
void Controller::menu(int index) {
    if(index<0||index>2) return;
    if(index==2) {state_.presentation={};state_.selection=Selection::None;state_.crew_menu=CrewMenu::None;return;}
    if(state_.crew_menu==CrewMenu::Cars) {
        state_.car_missile=index==1;
        if(state_.car_missile&&goods_count(session_.wagons,2)==0) {state_.notice=true;set_presentation(Scene::None,data_.message(15));return;}
        state_.crew_menu=CrewMenu::CarDirection;bool vertical=session_.journey.heading==2||session_.journey.heading==8;
        open_menu({vertical?"SOUTH":"WEST",vertical?"NORTH":"EAST","EXIT"});
    } else if(state_.crew_menu==CrewMenu::CarDirection) {
        bool vertical=session_.journey.heading==2||session_.journey.heading==8;int heading=vertical?(index==0?2:8):(index==0?4:6);
        session_.engine.speed=0;session_.engine.brake=true;auto result=inspect(session_,state_.state,random_,host_,heading,state_.car_missile);
        emit(ActionKind::CargoChanged);state_.notice=true;state_.crew_menu=CrewMenu::None;set_presentation(Scene::None,data_.message(result.message));
    } else if(state_.crew_menu==CrewMenu::Spies) {
        state_.selection=index==0?Selection::Send:Selection::Dynamite;state_.presentation={};emit(ActionKind::Overview);
    }
}
bool Controller::select_map_cell(Cell cell) {
    if(state_.selection==Selection::None) return false;
    if(state_.selection==Selection::Send) {state_.state.send_spy(cell,session_.journey.position,session_.wagons,trade_);emit(ActionKind::CargoChanged);}
    else for(int i=0;i<20;++i) {
        const auto& record=state_.state.spies[i];
        if(record[1]+40==cell.x&&record[2]==cell.y) {
            state_.selection=Selection::None;Pending event;event.scene=Scene::SabotageConfirm;event.spy=i;present(std::move(event));return true;
        }
    }
    state_.selection=Selection::None;emit(ActionKind::Quarters);return true;
}
}
