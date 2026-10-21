// SPDX-License-Identifier: MIT
// Source: map_canvas_batch.gd and rail_art.gd segment_plan; integrated bed only.
#include "world_visual.hpp"
#include "world_visual_math.hpp"
#include <algorithm>
namespace transartica {
using namespace rail_visual;
void WorldVisual::polygon(Mesh& mesh,int layer,std::span<const Point> points,SDL_Color color,std::optional<SDL_FRect> crop){
    if(points.size()<3)return;
    for(std::size_t i=1;i+1<points.size();++i)
        if(std::abs(cross(points[i]-points[0],points[i+1]-points[0]))<.00001)return;
    const auto surface=crop?Surface::Track:Surface::Color;
    auto group=std::find_if(mesh.begin(),mesh.end(),[&](const Group& g){return g.layer==layer&&g.surface==surface;});
    if(group==mesh.end()){mesh.push_back({layer,surface,{}});group=std::prev(mesh.end());}
    std::array<Point,4> uv{};
    if(crop){const auto c=*crop;uv={Point{c.x,c.y},Point{c.x+c.w,c.y},Point{c.x+c.w,c.y+c.h},Point{c.x,c.y+c.h}};
        for(auto& p:uv){if(c.h==1)p.y=c.y+.5;p={p.x/rail_texture_size_.x,p.y/rail_texture_size_.y};}}
    for(std::size_t i=1;i+1<points.size();++i)for(auto index:{std::size_t(0),i,i+1})
        group->vertices.push_back({points[index],crop?uv[index]:Point{},color});
}
void WorldVisual::line(Mesh& mesh,int layer,Point a,Point b,SDL_Color color,double width,bool texture){
    auto d=b-a,side=normalized({d.y,-d.x})*(std::max(1.,width)*.5);auto quad=strip(a,b,side);
    polygon(mesh,layer,quad,color,texture?std::optional<SDL_FRect>(steel_crop):std::nullopt);
}
void WorldVisual::segment(Mesh& mesh,Point start,Point finish,bool detailed){
    if(start.x>finish.x||(start.x==finish.x&&start.y>finish.y))std::swap(start,finish);
    ballast(mesh,start,finish);
    if(!detailed){polygon(mesh,0,strip(start,finish,transverse(normalized(finish-start),gauge/2)),steel_side);line(mesh,0,start,finish,steel,3);return;}
    auto direction=normalized(finish-start),side=transverse(direction,1);double extent=length(finish-start),scale=gauge/source_gauge;
    if(extent==0)return;Point rise{0,-5*scale};
    struct Volume{Point start,finish;std::array<Point,4> ground,top;};std::vector<Volume> sleepers,rails;
    auto volume=[&](Point a,Point b,Point across){auto ground=strip(a,b,across),top=ground;for(auto& p:top)p=p+rise;return Volume{a,b,ground,top};};
    double stretch=longitudinal(direction),pitch=36*scale*stretch,half=14*scale*stretch/2;
    for(double travel=0;travel<extent;travel+=pitch)sleepers.push_back(volume(start+direction*std::max(0.,travel-half),start+direction*std::min(extent,travel+half),side*(112*scale/2)));
    for(int sign:{-1,1}){auto offset=side*(gauge/2*sign);rails.push_back(volume(start+offset,finish+offset,side*1.5));}
    Point shadow{length(rise)*.75,length(rise)*.75};
    for(const auto* collection:{&sleepers,&rails})for(const auto& v:*collection){auto shape=v.ground;for(auto& p:shape)p=p+shadow;polygon(mesh,1,shape,contact);}
    auto sides=[&](const Volume& v,int layer,SDL_Color c){for(int i=0;i<4;++i){int n=(i+1)%4;std::array<Point,4> face{v.ground[i],v.ground[n],v.top[n],v.top[i]};polygon(mesh,layer,face,c);}};
    for(const auto& v:sleepers){sides(v,2,wood_side);polygon(mesh,2,v.top,{255,255,255,255},wood_crop);}
    for(const auto& v:rails){sides(v,3,steel_side);polygon(mesh,3,v.top,steel,steel_crop);line(mesh,3,v.start+rise,v.finish+rise,frost,1.1,true);}
}
void WorldVisual::ballast(Mesh& mesh,Point start,Point finish){
    const auto plan=ballast_plan(start,finish);if(plan.empty())return;
    auto found=std::find_if(mesh.begin(),mesh.end(),[](const Group& g){return g.layer==-1&&g.surface==Surface::Ballast;});
    if(found==mesh.end()){mesh.push_back({-1,Surface::Ballast,{}});found=std::prev(mesh.end());}
    for(const auto& piece:plan)for(std::size_t i=1;i+1<piece.points.size();++i)for(auto index:{std::size_t(0),i,i+1})
        found->vertices.push_back({piece.points[index],piece.uv[index],{255,255,255,255}});
}
void WorldVisual::join(Mesh& mesh,Point start,Point center,Point finish,int layer,bool selected,double minimum_width){
    auto incoming=normalized(center-start),outgoing=normalized(finish-center);double divisor=cross(incoming,outgoing);Point rise{0,-5*gauge/source_gauge};
    if(std::abs(divisor)<.00001){if(selected){auto side=transverse(normalized(finish-start),gauge/2);for(int sign:{-1,1})line(mesh,layer,start+side*sign+rise,finish+side*sign+rise,handle,std::max(1.1,minimum_width));}return;}
    for(int sign:{-1,1}){auto before=center+transverse(incoming,gauge/2)*sign,after=center+transverse(outgoing,gauge/2)*sign;
        auto intersection=before+incoming*(cross(after-before,outgoing)/divisor);
        std::array<Point,3> points{start+transverse(incoming,gauge/2)*sign+rise,intersection+rise,finish+transverse(outgoing,gauge/2)*sign+rise};
        if(selected){for(int i=0;i<2;++i)line(mesh,layer,points[i],points[i+1],handle,std::max(1.1,minimum_width));}
        else{for(int i=0;i<2;++i)line(mesh,layer,points[i],points[i+1],steel_side,3,true);for(int i=0;i<2;++i)line(mesh,layer,points[i],points[i+1],frost,1.1,true);}}
}
}
