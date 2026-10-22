// SPDX-License-Identifier: MIT
// Source launcher_scene.curve/_present: pooled source velocities, five-tap mean,
// then cubic Hermite. Presentation only, no alteration to BERTA source cursors.
#include "launcher_screen.h"
#include <algorithm>
#include <cmath>
namespace transartica::panels {
namespace {
const std::vector<double>& curve(){
    static const auto value=[](){
        std::vector<double> poses{0,1,2,4,6,8,10,13,16,19,22,25,28,32,36,40};int ascent=0,increment=4;poses.push_back(42);
        while(ascent<=205){ascent+=increment;if(ascent>11)++increment;poses.push_back(42+ascent);}
        std::vector<std::pair<double,int>> pooled;
        for(std::size_t i=0;i+1<poses.size();++i){pooled.push_back({poses[i+1]-poses[i],1});while(pooled.size()>1){auto last=pooled.back(),prior=pooled[pooled.size()-2];if(prior.first/prior.second<=last.first/last.second)break;pooled.pop_back();pooled.back()={prior.first+last.first,prior.second+last.second};}}
        std::vector<double> speed,smooth;for(auto [total,count]:pooled)for(int i=0;i<count;++i)speed.push_back(total/count);
        double sum=0;for(int i=0;i<int(speed.size());++i){double total=0;for(int tap=-2;tap<=2;++tap)total+=speed[std::clamp(i+tap,0,int(speed.size())-1)];smooth.push_back(total/5);sum+=smooth.back();}
        double scale=(poses.back()-poses.front())/sum;std::vector<double> result{poses.front()};for(auto v:smooth)result.push_back(result.back()+v*scale);return result;
    }();return value;
}
}
double LauncherScreen::rocket_offset(const launcher::Model& m){
    if(m.phase!=launcher::Phase::Launch&&m.phase!=launcher::Phase::Ascent)return 0;
    const auto& points=curve();int index=std::clamp(m.phase==launcher::Phase::Launch?m.cursor:16+m.cursor,0,int(points.size())-2);
    double f=std::clamp(m.accumulator/(3.0/50),0.0,1.0),start=points[index],span=points[index+1]-start;
    double before=index>0?points[index]-points[index-1]:0,after=points[std::min(int(points.size())-1,index+2)]-points[index+1];
    return start+(f*f*f-2*f*f+f)*(before+span)/2+(-2*f*f*f+3*f*f)*span+(f*f*f-f*f)*(span+after)/2;
}
Point LauncherScreen::flight_point(const launcher::Model& m){
    if(!m.geometry)return {};bool final=m.phase==launcher::Phase::Impact||m.phase==launcher::Phase::Report;
    Point point=transartica::point(launcher::screen_point(*m.geometry,m.camera,std::max(0,m.cursor-1),final));
    if(m.phase==launcher::Phase::Flight&&m.scroll_left==0&&m.cursor>0&&m.cursor<=m.geometry->count){
        auto next=launcher::screen_point(*m.geometry,m.camera,m.cursor);
        if(next.x>=7&&next.x<=303&&next.y>=16&&next.y<=142)point=point+(transartica::point(next)-point)*std::clamp(m.accumulator/(3.0/50),0.0,1.0);
    }return point;
}
}
