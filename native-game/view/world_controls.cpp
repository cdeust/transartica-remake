// SPDX-License-Identifier: MIT
// Sources: world_view.gd pointer gestures, travel_world.gd zoom/focus/switch
// release ordering, boudoir_session.gd::_inspect_map, train_camera_fit.gd.
#include "view.h"
#include "core/train_pose.hpp"
#include "world_visual_math.hpp"
#include <algorithm>
#include <cmath>
namespace transartica {
namespace {bool contains(SDL_FRect r,Point p){return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;}}
Point View::world_point(Point p)const{const auto r=world_rect();return camera_+(p-Point{r.x+r.w*.5,r.y+r.h*.5})*(1/cell_pixels_);}
WorldState View::snapshot_world()const{
    WorldState value;value.ready=camera_ready_;value.following=following_train_;value.inspecting=inspecting_map_;value.selected_city=selected_city_;
    if(camera_ready_||inspecting_map_)value.camera=camera_;
    if(camera_ready_)value.zoom=cell_pixels_/rail_visual::cell;
    // Offset is folded into camera_ by pan/zoom; this canonical zero-offset
    // form has the same source world_to_screen projection and future controls.
    return value;
}
bool View::restore_world(const WorldState& value,const Session& session,std::size_t city_count){
    auto staged=value;if(!normalize_world_state(staged,city_count))return false;
    double pixels=staged.zoom*rail_visual::cell;Point camera=staged.camera-staged.offset*(1/pixels);
    if(!std::isfinite(camera.x)||!std::isfinite(camera.y))return false; // Reject conversion overflow, never clip camera position.
    camera_=camera;cell_pixels_=pixels;camera_ready_=staged.ready;following_train_=staged.following;inspecting_map_=staged.inspecting;selected_city_=staged.selected_city;
    world_motion_.reset(session.journey);world_visual_.clear_effects();world_left_=world_dragging_=false;
    camera_cycle_=session.engine.cycles;camera_visual_=world_motion_.position();auto rect=world_rect();camera_extent_={rect.w,rect.h};return true;
}
void View::zoom_world(double factor,Point anchor){
    if(!camera_ready_||!std::isfinite(factor)||factor<=0)return;
    // Source travel_world.gd TRAVEL_MIN_ZOOM=.001 and TRAVEL_MAX_ZOOM=2.
    const auto before=world_point(anchor);cell_pixels_=std::clamp(cell_pixels_*factor,rail_visual::cell*.001,rail_visual::cell*2);
    camera_=camera_+(before-world_point(anchor));
}
int View::city_at(Point p,const economy::WorldData& data)const{
    // Source world_view.gd CITY_HIT_RADIUS=10, inclusive with later-index ties.
    int nearest=-1;double closest=10;for(std::size_t i=0;i<data.cities().size();++i){auto candidate=screen(point(data.cities()[i].anchor)+Point{.5,.5});double span=distance(p,candidate);
        if(span<=closest){nearest=int(i);closest=span;}}return nearest;
}
void View::focus_city(int index,const economy::WorldData& data){
    const auto* city=data.city(index);if(!city||!camera_ready_)return;selected_city_=index;camera_=point(city->anchor)+Point{.5,.5};following_train_=false;
}
void View::inspect_world(Cell cell){
    if(cell.x<0||cell.y<0||cell.x>=RailNetwork::width||cell.y>=RailNetwork::height)return;
    camera_=point(cell)+Point{.5,.5};following_train_=false;inspecting_map_=true;
}
void View::center_on_train(const Session& s){
    inspecting_map_=false;world_motion_.synchronize(s.journey,true);if(!camera_ready_){update_camera(s,poses(s));return;}
    double length=0;for(const auto& wagon:s.wagons)length+=vehicle_length(wagon.type);
    auto middle=s.journey.sample_behind(length*wagon_cell_ratio*.5+world_motion_.lag(s.journey));
    camera_=(middle.ok?middle.position:world_motion_.position())+Point{.5,.5};
    // Source center_on_train calls keep_train_in_view, not the nose-follow path.
    bool previous=following_train_;following_train_=false;update_camera(s,poses(s));following_train_=previous;
}
void View::follow_train(const Session& s){inspecting_map_=false;following_train_=true;world_motion_.synchronize(s.journey,true);update_camera(s,poses(s));}
WorldInput View::handle_world(const SDL_Event& event,const economy::WorldData& data,const RailNetwork* network){
    if(!camera_ready_)return {};
    if(event.type==SDL_WINDOWEVENT&&(event.window.event==SDL_WINDOWEVENT_FOCUS_LOST||event.window.event==SDL_WINDOWEVENT_HIDDEN)){world_left_=world_dragging_=false;return {};}
    if(event.type==SDL_MOUSEWHEEL){Point p;
#if SDL_VERSION_ATLEAST(2,26,0)
        p={double(event.wheel.mouseX),double(event.wheel.mouseY)};
#else
        int x{},y{};SDL_GetMouseState(&x,&y);p={double(x),double(y)};
#endif
        // Source world_view.gd WHEEL_ZOOM_STEP=1.2, repeated per wheel step.
        if(!contains(world_rect(),p))return {};int turns=event.wheel.y*(event.wheel.direction==SDL_MOUSEWHEEL_FLIPPED?-1:1);zoom_world(std::pow(1.2,turns),p);return {{},true};}
    if(event.type==SDL_MOUSEBUTTONDOWN&&event.button.button==SDL_BUTTON_LEFT){Point p{double(event.button.x),double(event.button.y)};
        if(!contains(world_rect(),p))return {};world_press_=world_pointer_=p;world_left_=true;world_dragging_=false;return {{},true};}
    if(event.type==SDL_MOUSEMOTION&&world_left_){Point p{double(event.motion.x),double(event.motion.y)};
        if(!world_dragging_&&distance(p,world_press_)>=4)world_dragging_=true; // Source DRAG_THRESHOLD=4.
        if(world_dragging_){following_train_=false;camera_=camera_-(p-world_pointer_)*(1/cell_pixels_);}world_pointer_=p;return {{},true};}
    if(event.type!=SDL_MOUSEBUTTONUP||event.button.button!=SDL_BUTTON_LEFT||!world_left_)return {};
    Point p{double(event.button.x),double(event.button.y)};bool click=!world_dragging_&&distance(p,world_press_)<4;world_left_=world_dragging_=false;
    if(!click)return {{},true};auto cell=world_cell(float(p.x),float(p.y));if(!cell)return {{},true};
    // Source TravelWorld first offers a released click to the live switch.
    if(network&&network->is_switch(*cell))return {cell,true};
    int city=city_at(p,data);if(city>=0)selected_city_=city;return {cell,true,city};
}
}
