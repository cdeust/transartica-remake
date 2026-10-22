// SPDX-License-Identifier: MIT
// Source launcher_model.gd, BERTA/CARTE sloc[-2]=3 at50Hz.
#include "launcher.hpp"
#include <algorithm>
#include <cmath>
namespace transartica::launcher {
std::string phase_name(Phase phase){constexpr const char* names[]{"aim","arming","armed","disarming","launch","ascent","flight","impact","report"};return int(phase)>=0&&int(phase)<9?names[int(phase)]:"";}
int Model::distance()const{return digits[0]*1000+digits[1]*100+digits[2]*10+digits[3];}
bool Model::action(int code,Cell origin,const world::EnemyTrains& enemies){
    if(phase==Phase::Aim){
        if(code==101||code==102)bearing=(bearing+(code==101?31:1))%32;
        else if(code>=103&&code<=106){auto& digit=digits[code-103];digit=(digit+1)%10;if(distance()<50)digits[2]=5;}
        else if(code==107){phase=Phase::Arming;cursor=0;}else return false;
    }else if(phase==Phase::Armed){
        if(code==107){phase=Phase::Disarming;cursor=0;}
        else if(code==108){auto candidate=calculate(bearing,distance(),origin,enemies);if(!candidate)return false;geometry=*candidate;camera={std::clamp(origin.x-10,0,140),std::clamp(origin.y-4,0,63)};phase=Phase::Launch;cursor=0;}
        else return false;
    }else return false;return true;
}
void Model::advance(double seconds){
    if(!std::isfinite(seconds)||seconds<0||phase==Phase::Aim||phase==Phase::Armed||phase==Phase::Report)return;
    accumulator+=seconds;while(accumulator>=3.0/50&&phase!=Phase::Report){accumulator-=3.0/50;step();}
    if(phase==Phase::Report)accumulator=std::fmod(accumulator,3.0/50);
}
void Model::step(){
    switch(phase){
    case Phase::Arming:case Phase::Disarming:if(++cursor==5){phase=phase==Phase::Arming?Phase::Armed:Phase::Aim;cursor=0;}break;
    case Phase::Launch:if(++cursor==16){phase=Phase::Ascent;cursor=0;}break;
    case Phase::Ascent:ascent+=ascent_step;if(ascent>11)++ascent_step;++cursor;if(ascent>205){phase=Phase::Flight;cursor=0;}break;
    case Phase::Flight:flight_step();break;
    case Phase::Impact:if(++cursor>=(status==1?2:4)){phase=Phase::Report;cursor=0;}break;
    default:break;
    }
}
void Model::flight_step(){
    if(scroll_left>0){camera.x=std::clamp(camera.x+scroll.x,0,140);camera.y=std::clamp(camera.y+scroll.y,0,63);if(--scroll_left==0)++cursor;return;}
    if(!geometry)return;if(cursor>geometry->count){finish_flight();return;}
    auto point=screen_point(*geometry,camera,std::max(0,cursor-1));if(cursor>0&&scroll_or_exit(point))return;++cursor;
}
bool Model::scroll_or_exit(Cell point){
    if(point.x<7||point.x>303){
        if((point.x<7&&camera.x==0)||(point.x>303&&camera.x==140)){status=0;finish_flight();}
        else {scroll={point.x<7?-1:1,0};scroll_left=18;}return true;
    }
    if(point.y<16||point.y>142){
        if((point.y<16&&camera.y==0)||(point.y>142&&camera.y==63)){status=0;finish_flight();}
        else {scroll={0,point.y<16?-1:1};scroll_left=8;}return true;
    }return false;
}
void Model::finish_flight(){if(status!=0)status=geometry&&geometry->target>=0?2:1;phase=status==0?Phase::Report:Phase::Impact;cursor=0;}
}
