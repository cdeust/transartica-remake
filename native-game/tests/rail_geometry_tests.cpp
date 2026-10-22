// SPDX-License-Identifier: MIT
// Source oracles: RailArt, RailNetwork SWITCH_RULES and actual CARTE repair pairs.
#include "view/world_visual_math.hpp"
#include <cmath>
#include <iostream>
using namespace transartica;
using namespace transartica::rail_visual;
namespace {
int checks{},failures{};
void check(bool ok,const char* label){++checks;if(!ok){++failures;std::cerr<<"FAIL "<<label<<'\n';}}
bool near(double a,double b){return std::abs(a-b)<.00001;} // Godot CMP_EPSILON.
bool near(Point a,Point b){return near(a.x,b.x)&&near(a.y,b.y);}
void switch_cases(){
    for(int code=18;code<=33;++code){
        const auto state=switch_route(code);check(bool(state),"all16 source switch states have presentation");
        if(!state)continue;
        const auto incoming=heading_delta(facing(code)),outgoing=heading_delta(rail_turn(code,facing(code)));
        check(near(state->entry,point(incoming)*-.5),"switch mechanism entry matches decoded incoming heading");
        check(near(state->selected,point(outgoing)*.5),"selected polish reaches decoded active branch");
        const auto alternate=switch_route(code%2?code-1:code+1);
        check(alternate&&state->entry==alternate->entry&&state->selected!=alternate->selected,"toggle changes only selected branch");
        const auto ports=rail_ports(code);std::vector<Point> ends;for(auto p:ports)ends.push_back(p*cell);
        const auto segments=tile_segments({},ends);check(segments.size()==2,"switch retains straight chord and one branch");
        for(auto endpoint:ends){int occurrences{};for(const auto& segment:segments)for(auto p:segment)if(near(p,endpoint))++occurrences;
            check(occurrences==1,"every switch source port occurs exactly once");}
    }
    check(!switch_route(17)&&!switch_route(34)&&!switch_route(-18),"crossing/station/destroyed glyph do not invent live mechanism");
}
void ground_cases(){
    check(near(transverse({1,0},1),{0,-depth_ratio}),"horizontal normal retains screen-up ground compression");
    check(near(transverse({0,1},1),{1,0}),"vertical normal retains source orthogonal sign");
    for(Point d:std::array<Point,4>{{{1,0},{0,1},{1,1},{1,-1}}}){
        const auto n=normalized(d);
        const double expected=gauge*std::sqrt(depth_ratio*depth_ratio*n.x*n.x+n.y*n.y);
        check(near(projected_gauge(d),expected),"far envelope uses the detailed ground gauge, not isotropic width");
        const auto pieces=ballast_plan({},d*cell);check(!pieces.empty(),"source ballast has finite authored repeats");
        for(std::size_t i=1;i<pieces.size();++i)
            check(near(pieces[i-1].points[2],pieces[i].points[1])&&near(pieces[i-1].points[3],pieces[i].points[0]),"ballast repeat endpoints meet without gaps");
        for(const auto& piece:pieces)check(piece.uv[2].y>0&&(piece.uv[2].y<=1||near(piece.uv[2].y,1)),"partial last repeat crops UV instead of stretching the whole texture");
        if(!pieces.empty()){const auto center=(pieces.back().points[2]+pieces.back().points[3])*.5;check(near(center,d*cell),"ballast terminates at exact original endpoint");}
    }
    check(ballast_plan({2,3},{2,3}).empty(),"zero source chord produces no repeated geometry");
}
void zoom_cases(){
    for(double zoom:{.001,.03,.1,.5,1.,2.})for(double width:{1.1,3.}){
        const auto actual=screen_stroke(width,zoom)*zoom;
        check((actual>=1||near(actual,1))&&near(actual,std::max(width*zoom,1.)),"selected rail and lever retain one real screen pixel floor");
    }
    // Regression: at .1 the former active polish was only one raster pixel;
    // source MapRailDrawing's active route uses a two-pixel minimum instead.
    for(double zoom:{.001,.03,.1,.5,1.,2.}){
        const auto selected=selected_stroke(1.1,zoom)*zoom;
        check((selected>=2||near(selected,2))&&near(selected,std::max(1.1*zoom,2.)),"active branch retains source two-screen-pixel floor");
        check(near(screen_stroke(3,.1)*.1,1),"active-branch floor does not enlarge the physical lever floor");
    }
}
void obstacle_cases(){
    check(rail_ports(67).empty()&&rail_ports(69).empty(),"unrepaired crevasse never gains a continuous invented rail");
    check(rail_ports(63)==rail_ports(2)&&rail_ports(64)==rail_ports(3),"source repairs reveal only the original E-W/N-S bridge axis");
    for(int code:{2,3,4,6,18})check(rail_ports(-code)==rail_ports(code),"destroyed track preserves decoded orientation without mutating state");
}
void broken_cases(){
    for(int code:{-2,-3,-4,-5}){
        const auto p=broken_straight_plan(code);check(bool(p),"four destroyed ordinary straights reuse measured authored frame");if(!p)continue;
        const auto map=[&](Point q){return p->points[0]+(p->points[1]-p->points[0])*(q.x/p->crop.w)+(p->points[3]-p->points[0])*(q.y/p->crop.h);};
        const auto ports=rail_ports(code);const Point center{cell/2,cell/2};auto a=center+ports[0]*cell,b=center+ports[1]*cell;
        if(a.x>b.x||(a.x==b.x&&a.y>b.y))std::swap(a,b);
        check(near(map(broken_first),a)&&near(map(broken_last),b),"measured complete broken ends land on original CARTE ports");
        const auto axis=normalized(broken_last-broken_first);const Point normal{axis.y,-axis.x};const auto middle=(broken_first+broken_last)*.5;
        const auto cross_section=map(middle+normal*(broken_gauge*.5))-map(middle-normal*(broken_gauge*.5));
        check(near(cross_section,transverse(normalized(b-a),gauge)),"measured50.5 calibration retains original projected track gauge");
        check(p->crop.x==724&&p->crop.y==774&&p->crop.w==321&&p->crop.h==218,"whole measured alpha component retained, not synthetic gap");
        check(near(map(middle),(a+b)*.5),"source central fracture retains source chord midpoint");
    }
    for(int code:{0,2,3,4,5,-6,-13,-14,-17,-18,-33,-38,-52,-53,-54,-55,-57,-58,63,64,-116,-117,-120,-121})
        check(!broken_straight_plan(code),"positive/complex/tunnel/mouth/special glyph does not enter straight-damage recipe");
}
}
int main(){switch_cases();ground_cases();zoom_cases();obstacle_cases();broken_cases();std::cout<<"rail geometry: "<<checks<<" checks, "<<failures<<" failures\n";return failures?1:0;}
