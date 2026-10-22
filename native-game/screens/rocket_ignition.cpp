// SPDX-License-Identifier: MIT
// Equations, colors and constants: game/shaders/rocket_ignition.gdshader and
// rocket_ignition.gd/canvas.gd; native calibration rocket-ignition-20261001.md.
#include "rocket_ignition.hpp"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
namespace transartica::panels {
namespace {
struct V{float x{},y{};V operator+(V b)const{return{x+b.x,y+b.y};}V operator*(float f)const{return{x*f,y*f};}};
struct RGB{float r{},g{},b{};};
float clamp(float x,float a=0,float b=1){return std::clamp(x,a,b);}
float mix(float a,float b,float t){return a+(b-a)*t;}
RGB mix(RGB a,RGB b,float t){return {mix(a.r,b.r,t),mix(a.g,b.g,t),mix(a.b,b.b,t)};}
float fract(float x){return x-std::floor(x);}
float smooth(float a,float b,float x){float t=clamp((x-a)/(b-a));return t*t*(3-2*t);}
float step(float edge,float x){return x<edge?0:1;}
float grain(V p){return fract(std::sin(std::floor(p.x)*19+std::floor(p.y)*47)*3151);}
float pigment(V p){V cell{std::floor(p.x),std::floor(p.y)};float x=fract(p.x),y=fract(p.y);x=x*x*(3-2*x);y=y*y*(3-2*y);return mix(mix(grain(cell),grain(cell+V{1,0}),x),mix(grain(cell+V{0,1}),grain(cell+V{1,1}),x),y);}
float bayer(V p){constexpr float m[]{0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};int x=(int(std::floor(p.x))%4+4)%4,y=(int(std::floor(p.y))%4+4)%4;return (m[y*4+x]+.5f)/16;}
struct Params{V nozzle;float t{},ground{},contact{},lift{};};
float cloud_body(V p,const Params& a){
    float dx=std::abs(p.x-a.nozzle.x),side=float((p.x>a.nozzle.x)-(p.x<a.nozzle.x));
    float front=8+62*(1-std::exp(-a.t*.8f)),pile=std::min(30.f,6+a.t*15)*(.5f+.5f*a.contact),profile=pile*std::pow(std::max(0.f,1-dx/front),.7f);
    V roll{(dx-a.t*20)*.075f,(105-p.y)*.09f-a.t*.5f};float billow=pigment(roll)*.62f+pigment(roll*2.1f+V{side*3,a.t*.7f})*.28f+pigment(roll*4.7f)*.1f;
    float above=105-p.y-a.lift*16;return profile-above+(billow-.5f)*22;
}
struct Fire{RGB color;float alpha{},silhouette{},heat{};};
Fire jet(V p,const Params& a,float dither){
    V q{p.x-a.nozzle.x,p.y-a.nozzle.y};float core=16+10*(1-a.contact);
    float coarse=pigment({q.x*.45f,q.y*.23f-a.t*13}),fine=grain(p*2+V{0,std::floor(a.t*50)*3});
    float bend=std::sin(q.y*.37f-a.t*16)*smooth(0,30,q.y)*.7f,width=2+q.y*.09f+(coarse-.5f)*2.2f;
    width+=a.contact*smooth(a.ground-10,a.ground,q.y)*9;float edge=std::abs(q.x-bend)/std::max(width,.1f);
    float density=(1-smooth(.55f,1.1f,edge))*step(0,q.y)*step(q.y,a.ground+1);density*=std::exp(-std::max(0.f,q.y-core)/(22+coarse*14));
    float run=6+34*a.contact*std::min(1.f,a.t*1.6f),splash_dx=std::abs(q.x)/std::max(run,1.f);
    float tongue=5*(1-splash_dx)+(pigment({std::abs(q.x)*.3f-a.t*18,p.y*.4f})-.5f)*4;
    float splash=a.contact*step(splash_dx,1)*step(105-p.y,tongue)*step(p.y,105.5f)*(1-splash_dx*.7f);density=std::max(density,splash);
    float heat=clamp(1.15f-edge*.7f-q.y/(core*3)+(coarse-.5f)*.4f+fine*.12f);heat=std::max(heat*density,splash*(.75f-splash_dx*.55f));
    float diamond=std::pow(std::max(0.f,std::sin(q.y*.7f-a.t*15)),4)*(1-edge)*.25f*step(q.y,core);heat=clamp(heat+diamond);
    RGB color=mix(RGB{.5f,.52f,.58f},RGB{.8f,.25f,.06f},smooth(.08f,.3f,heat));color=mix(color,{1,.55f,.08f},smooth(.25f,.5f,heat));color=mix(color,{1,.94f,.72f},smooth(.5f,.8f,heat));color=mix(color,{1,1,1},smooth(.82f,.99f,heat));
    color={std::floor(color.r*8+dither)/8,std::floor(color.g*8+dither)/8,std::floor(color.b*8+dither)/8};
    float glow=std::exp(-edge*edge*.6f)*step(0,q.y)*std::exp(-q.y/40)*.22f;glow=std::max(glow,std::exp(-std::abs(p.y-105)/2.5f)*std::exp(-std::abs(q.x)/18)*a.contact*.5f);
    float alpha=smooth(.04f,.55f,density)*mix(.55f,1,smooth(.1f,.35f,heat));return {color,std::max(alpha,glow),alpha,heat};
}
std::array<unsigned char,4> pixel(V p,const Params& a){
    float dither=bayer(p*2);auto fire=jet(p,a,dither);float body=cloud_body(p,a)-a.lift*12;
    float relief=clamp((body-cloud_body(p+V{-1.5f,-1.5f},a)+a.lift*12)*.35f,-1,1);
    float coverage=clamp(body/4)*smooth(0,.08f,a.t);coverage*=1-smooth(106,109,p.y);float smoke=step(dither*.9f+.05f,coverage);
    float shade=clamp(.55f+relief*.6f-clamp(body/30)*.2f);shade=std::floor(shade*5+dither)/5;
    RGB cloud=mix(RGB{.17f,.21f,.28f},RGB{.84f,.88f,.93f},shade);float warmth=std::exp(-std::abs(p.x-a.nozzle.x)/18)*std::exp(-std::abs(p.y-105)/10)*a.contact;cloud=mix(cloud,{1,.6f,.22f},warmth*.7f);
    float cloud_alpha=smoke*smooth(20,30,p.x)*(1-smooth(199,209,p.x));cloud_alpha*=1-fire.silhouette*step(.6f,fire.heat);
    RGB color=mix(cloud,fire.color,fire.alpha);float alpha=cloud_alpha+fire.alpha*(1-cloud_alpha);
    return {static_cast<unsigned char>(std::round(clamp(color.r)*255)),static_cast<unsigned char>(std::round(clamp(color.g)*255)),static_cast<unsigned char>(std::round(clamp(color.b)*255)),static_cast<unsigned char>(std::round(clamp(alpha)*255))};
}
}
RocketIgnition::~RocketIgnition(){if(texture_)SDL_DestroyTexture(texture_);}
void RocketIgnition::clear(){tick_=0;remainder_=0;nozzle_={};active_=false;dirty_=true;}
void RocketIgnition::observe(double seconds,Point nozzle,bool burning){
    if(nozzle_!=nozzle)dirty_=true;nozzle_=nozzle;active_=burning;if(!burning||!std::isfinite(seconds)||seconds<=0)return;
    remainder_+=seconds;while(remainder_>=1.0/50||std::abs(remainder_-1.0/50)<.00001){remainder_=std::max(0.0,remainder_-1.0/50);++tick_;dirty_=true;}
}
void RocketIgnition::draw(Canvas& canvas){
    if(!active_)return;constexpr int width=378,height=282; // REGION189x141 at half-logical lattice.
    if(!texture_){texture_=SDL_CreateTexture(canvas.renderer(),SDL_PIXELFORMAT_RGBA32,SDL_TEXTUREACCESS_STREAMING,width,height);if(!texture_)throw std::runtime_error(SDL_GetError());render_check(SDL_SetTextureBlendMode(texture_,SDL_BLENDMODE_BLEND),"Ignition blend");render_check(SDL_SetTextureScaleMode(texture_,SDL_ScaleModeNearest),"Ignition sampling");bytes_.resize(width*height*4);dirty_=true;}
    if(dirty_){Params a;a.nozzle={float(nozzle_.x),float(nozzle_.y)};a.t=tick_/50.f;a.ground=std::max(2.f,105-a.nozzle.y);a.contact=1-smooth(25,70,a.ground);a.lift=smooth(20,90,a.ground);
        for(int y=0;y<height;++y)for(int x=0;x<width;++x){auto c=pixel({20+x*.5f,y*.5f},a);std::copy(c.begin(),c.end(),bytes_.begin()+(y*width+x)*4);}render_check(SDL_UpdateTexture(texture_,nullptr,bytes_.data(),width*4),"Ignition texture upload");dirty_=false;}
    float scale=std::min(canvas.width()/320.f,canvas.height()/200.f);SDL_FRect box{(canvas.width()-320*scale)/2+20*scale,(canvas.height()-200*scale)/2,189*scale,141*scale};render_check(SDL_RenderCopyF(canvas.renderer(),texture_,nullptr,&box),"Ignition surface");
}
}
