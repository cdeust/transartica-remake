// SPDX-License-Identifier: MIT
// Regressions: native-3/4 tunnel captures in verification-cpp-20261020;
// directional crossings: TIME0x0496 and core/rail_network.cpp::progress_speed.
#include "view/world_passages.hpp"
#include <SDL.h>
#include <json-c/json.h>
#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>

namespace ta=transartica;
namespace {
void require(bool value,const char* message){if(!value)throw std::runtime_error(message);}
std::array<ta::Point,4> box(double x,double y,double w,double h){
    return {{{x,y},{x+w,y},{x+w,y+h},{x,y+h}}};
}
json_object* field(json_object* object,const char* name){
    json_object* result{};require(json_object_object_get_ex(object,name,&result),"Missing portal field");return result;
}
double at(json_object* array,int index){return json_object_get_double(json_object_array_get_idx(array,index));}
}
int main(int argc,char** argv){
    try{
        require(argc==3,"Usage: world_train_cover_tests GAME FONT");
        const std::filesystem::path game=argv[1];
        SDL_SetMainReady();require(SDL_Init(SDL_INIT_VIDEO)==0,SDL_GetError());
        struct Quit{~Quit(){SDL_Quit();}} quit;
        std::unique_ptr<SDL_Window,decltype(&SDL_DestroyWindow)> window(
            SDL_CreateWindow("Train cover regression",0,0,640,480,SDL_WINDOW_HIDDEN),SDL_DestroyWindow);
        require(bool(window),SDL_GetError());
        std::unique_ptr<SDL_Renderer,decltype(&SDL_DestroyRenderer)> renderer(
            SDL_CreateRenderer(window.get(),-1,SDL_RENDERER_SOFTWARE),SDL_DestroyRenderer);
        require(bool(renderer),SDL_GetError());
        ta::Canvas canvas(renderer.get(),argv[2]);ta::WorldPassages passages(canvas,game/"assets");
        ta::RailNetwork network;std::string error;
        require(network.load(game/"data/CARTE.FIC",error),error.c_str());
        const auto original=network.tiles();
        // The diagonal joins cells(9,22)/(10,21). Its rigid body can extend
        // into unpainted neighboring cells even though every contact is buried.
        require(passages.fully_covered(network,{9.8,21.2},{9.3,21.7},{9.55,21.45},9,
            box(9.5,21.5,.8,.8)),"Diagonal underground body leaked");
        require(network.tile({8,22})==15,"Live crossing fixture changed");
        for(int heading:{4,6})require(passages.fully_covered(network,{8.3,22},{7.6,22},{7.95,22},heading,
            box(8,22.3,.8,.4)),"Horizontal train leaked at crossing15");
        for(int heading:{2,8})require(!passages.fully_covered(network,{8,22.3},{8,21.6},{8,21.95},heading,
            box(8.3,22,.4,.8)),"Surface train hidden at crossing15");
        bool crossing16=false;
        for(int x=0;x<ta::RailNetwork::width&&!crossing16;++x)for(int y=0;y<ta::RailNetwork::height&&!crossing16;++y){
            if(network.tile({x,y})!=16)continue;crossing16=true;
            const auto center=ta::point({x,y});const auto quad=box(x+.3,y+.1,.4,.8);
            for(int heading:{2,8})require(passages.fully_covered(network,center+ta::Point{0,.3},center-ta::Point{0,.3},center,heading,quad),"Vertical train leaked at crossing16");
            for(int heading:{4,6})require(!passages.fully_covered(network,center+ta::Point{.3,0},center-ta::Point{.3,0},center,heading,quad),"Surface train hidden at crossing16");
        }
        require(crossing16,"Original crossing16 absent");
        require(!passages.fully_covered(network,{14,21},{13,21},{11,21},6,box(11,21,4,1)),"Midpoint alone hid surface contacts");
        require(!passages.fully_covered(network,{12.1,21},{11.4,21},{11.75,21},6,box(11.7,21.3,.9,.4)),"Mouth-straddling body hidden as a whole");
        const ta::WorldProjection projection{{0,0},1,{0,0,160,73}};
        const auto floors=passages.portal_plan(network,projection,false);
        std::unique_ptr<json_object,decltype(&json_object_put)> doc(
            json_object_from_file((game/"assets/travel/terrain/underground-mouths.json").c_str()),json_object_put);
        require(bool(doc),"Missing authenticated portal metadata");
        require(floors.size()==6,"Expected six original mouths");
        for(const auto& floor:floors){
            json_object* frame{};auto* frames=field(doc.get(),"frames");
            for(std::size_t i=0;i<json_object_array_length(frames);++i){auto* candidate=json_object_array_get_idx(frames,i);
                if(json_object_get_int(field(candidate,"code"))==floor.code)frame=candidate;}
            require(frame!=nullptr,"Portal code absent");
            const auto opening=*passages.mouth_opening(floor.cell);
            const auto expected=floor.points[0]+(floor.points[1]-floor.points[0])*
                (at(field(frame,"mouth_anchor"),0)/at(field(frame,"region"),2));
            require(ta::distance(opening.position,expected)<=std::numeric_limits<float>::epsilon(),"Mouth plane differs from rendered arch");
            const auto inner=ta::point(floor.cell)-opening.direction;
            const int heading=floor.code==53?2:floor.code==54?4:6;
            const auto side=ta::Point{opening.direction.y,-opening.direction.x}*.1;
            auto quad=std::array<ta::Point,4>{opening.position-side,opening.position+side,
                opening.position+side-opening.direction,opening.position-side-opening.direction};
            require(passages.fully_covered(network,inner+opening.direction*.3,inner-opening.direction*.3,inner,heading,quad),"Covered body rejected at exact mouth plane");
            for(auto& p:quad)p=p+opening.direction*.1;
            require(!passages.fully_covered(network,inner+opening.direction*.3,inner-opening.direction*.3,inner,heading,quad),"Visible tip beyond measured mouth plane hidden");
        }
        require(!passages.mouth_opening({0,0}),"Invented mouth");
        require(network.tiles()==original,"Occlusion altered CARTE");
        std::cout<<"Diagonal body, directional crossings and six measured mouth planes passed\n";
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
