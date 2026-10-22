// SPDX-License-Identifier: MIT
// Source tactical_trooper_rig.gd pose/draw and tactical_actor_motion_constants.gd.
#include "tactical_screen.h"
#include "tactical_frames.hpp"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
#include <numbers>
namespace transartica::panels {
namespace {
Point rotate(Point p,double angle){return{p.x*std::cos(angle)-p.y*std::sin(angle),p.x*std::sin(angle)+p.y*std::cos(angle)};}
Point knee(Point hip,Point target){const Point reach=target-hip;const double dist=std::clamp(std::hypot(reach.x,reach.y),.5,19*.999);const double bend=std::acos(std::clamp(dist/19.,-1.,1.));const double angle=std::atan2(reach.y,reach.x)-bend;return hip+Point{std::cos(angle)*9.5,std::sin(angle)*9.5};}
}
void TacticalScreen::soldier(Point foot,int side,float facing,double phase,float amount,double crouch,double strike,double recoil,double climb,double breath,SDL_Color tint){
    // Rig texels, PER=4 logical; all dimensions and gait constants from source.
    constexpr double pi=std::numbers::pi;std::array<Point,2> feet;std::array<bool,2>swing;
    for(int leg=0;leg<2;++leg){const double local=std::fmod(phase+pi*leg,2*pi);const bool swinging=local>=pi;double x,y=0;if(!swinging)x=11-22*local/pi;else{const double u=(local-pi)/pi;x=-11+22*(u*u*(3-2*u)*1.08-.04*std::sin(pi*u));y=-11*(1+.6*climb)*std::sin(pi*std::pow(u,.8));}x*=1-.75*climb;const double rest=leg==0?2:-2;feet[leg]={rest+(x-rest)*amount,y*amount};swing[leg]=swinging&&amount>.05;}
    const double shape=std::sin(pi*strike);feet[0].x+=shape*5;const double bob=-1.4*std::cos(2*phase)*amount+2.5*amount+std::sin(breath)*.35*(1-amount);const Point hip{-2*crouch+shape*3-recoil*2,-25.5+9*crouch+bob+1.5*shape},waist=hip+Point{0,25.5-27.7};const double lean=.32*amount*(1-climb)+.5*std::min(crouch,1.)+.35*shape-.3*recoil+.1*climb,thrust=shape*4-recoil*1.5;std::array<Point,2>knees,shafts;std::array<double,2>thighs;
    for(int leg=0;leg<2;++leg){const Point target=feet[leg]+Point{0,-9.1},joint=hip+Point{leg==0?1.:-1.,0};knees[leg]=knee(joint,target);const auto reach=target-knees[leg];const double len=std::hypot(reach.x,reach.y);shafts[leg]=knees[leg]+reach*(len>0?9.5/len:0);thighs[leg]=std::atan2(knees[leg].x-joint.x,knees[leg].y-joint.y);}
    auto piece=[&](SDL_Rect crop,Point pivot,Point at,double angle,SDL_Color color){color={Uint8(int(color.r)*tint.r/255),Uint8(int(color.g)*tint.g/255),Uint8(int(color.b)*tint.b/255),tint.a};auto*t=canvas_.texture(assets_/"combat/trooper-rig.png");SDL_SetTextureScaleMode(t,SDL_ScaleModeNearest);int tw{},th{};render_check(SDL_QueryTexture(t,nullptr,nullptr,&tw,&th),"Rig texture extent");const auto f=frame();const float scale=f.w/320;auto vertex=[&](double x,double y,float u,float v){const auto local=rotate(Point{x-pivot.x,y-pivot.y},angle)+at;const Point p=foot+Point{local.x*facing/4,local.y/4};return SDL_Vertex{{f.x+float(p.x)*scale,f.y+float(p.y)*scale},color,{u,v}};};const float u0=float(crop.x)/tw,v0=float(crop.y)/th,u1=float(crop.x+crop.w)/tw,v1=float(crop.y+crop.h)/th;const std::array<SDL_Vertex,4>v{{vertex(0,0,u0,v0),vertex(crop.w,0,u1,v0),vertex(crop.w,crop.h,u1,v1),vertex(0,crop.h,u0,v1)}};const int indices[]={0,1,2,0,2,3};render_check(SDL_RenderGeometry(canvas_.renderer(),t,v.data(),4,indices,6),"Trooper rig piece");};
    auto line=[&](Point a,Point b,double width,SDL_Color c){a=foot+Point{a.x*facing/4,a.y/4};b=foot+Point{b.x*facing/4,b.y/4};const double len=distance(a,b);if(len==0)return;const Point normal{-(b.y-a.y)/len*width/8,(b.x-a.x)/len*width/8};const auto f=frame();const float scale=f.w/320;auto vertex=[&](Point p){return SDL_Vertex{{f.x+float(p.x)*scale,f.y+float(p.y)*scale},c,{0,0}};};const std::array<SDL_Vertex,4>v{{vertex(a+normal),vertex(a-normal),vertex(b-normal),vertex(b+normal)}};const int indices[]={0,1,2,0,2,3};render_check(SDL_RenderGeometry(canvas_.renderer(),nullptr,v.data(),4,indices,6),"Trooper leg");};
    auto leg=[&](int i,bool dim,bool partial=false){SDL_Color outline{11,13,18,tint.a};SDL_Color cloth=side==0?SDL_Color{29,38,59,255}:SDL_Color{73,67,43,255};SDL_Color color{255,255,255,255};if(dim){cloth.r=Uint8(cloth.r*.62);cloth.g=Uint8(cloth.g*.62);cloth.b=Uint8(cloth.b*.66);color={158,158,168,255};}cloth={Uint8(int(cloth.r)*tint.r/255),Uint8(int(cloth.g)*tint.g/255),Uint8(int(cloth.b)*tint.b/255),tint.a};const Point start=partial?knees[i]:hip+Point{i==0?1.:-1.,0};line(start,knees[i],6,outline);line(knees[i],shafts[i],5,outline);line(start,knees[i],4.5,cloth);line(knees[i],shafts[i],3.5,cloth);const double toe=swing[i]?.45*std::clamp(-feet[i].y/11,0.,1.):0;piece({193,side==0?1:28,9,9},{3.4,.2},shafts[i],toe,color);};
    const double front=-std::clamp(std::max(thighs[0],thighs[1])*.35,0.,.45)+.12*amount,back=std::clamp(-std::min(thighs[0],thighs[1])*.35,0.,.45)+.12*amount;leg(1,true);piece({65,side==0?1:28,14,19},{13.3,.5},waist,back,{255,255,255,255});leg(0,false);piece({129,side==0?1:28,side==0?11:12,19},{.3,.5},waist,front,{255,255,255,255});if(thighs[0]>.35)leg(0,false,true);piece({1,side==0?1:28,36,25},{14.9,24.6},waist+Point{thrust,0},lean,{255,255,255,255});
}
void TacticalScreen::actors(const combat::Tactical&battle){motion_.draw(*this,battle);}
}
