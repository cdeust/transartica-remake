// SPDX-License-Identifier: MIT
// Source startup_intro.gd::_draw; game_boot.gd owns the exclusive transition.
#include "startup_screen.h"
#include "view/render_check.h"
#include <json-c/json.h>
#include <algorithm>
#include <cmath>
#include <memory>
#include <stdexcept>
namespace transartica::panels {
StartupIntro::StartupIntro(Canvas& canvas,const std::filesystem::path& game)
    :canvas_(canvas),artwork_(game/"assets/campaign/startup.png") {
    std::unique_ptr<json_object,decltype(&json_object_put)> root(json_object_from_file((game/"data/startup.json").string().c_str()),json_object_put);
    json_object *title{},*credits{};
    if(!root||!json_object_object_get_ex(root.get(),"title",&title)||!json_object_is_type(title,json_type_string)
       ||!json_object_object_get_ex(root.get(),"credits",&credits)||!json_object_is_type(credits,json_type_array))
        throw std::runtime_error("Missing or invalid private startup title/credits");
    title_=json_object_get_string(title);
    for(std::size_t i=0;i<json_object_array_length(credits);++i) {
        auto* value=json_object_array_get_idx(credits,i);
        if(!json_object_is_type(value,json_type_string))throw std::runtime_error("Invalid private startup credit");
        credits_.emplace_back(json_object_get_string(value));
    }
    if(!std::filesystem::is_regular_file(artwork_))throw std::runtime_error("Missing startup painting: "+artwork_.string());
}
bool StartupIntro::handle(const SDL_Event& event) {
    if(!active()||event.type==SDL_QUIT)return false;
    if(event.type==SDL_KEYDOWN&&!event.key.repeat&&
       (event.key.keysym.scancode==SDL_SCANCODE_SPACE||event.key.keysym.scancode==SDL_SCANCODE_RETURN))bypass();
    if(event.type==SDL_MOUSEBUTTONDOWN)bypass();
    return true; // Source shields releases/repeats and all host shortcuts.
}
void StartupIntro::centered(float baseline,std::string_view value,int size) {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    const int pixels=std::max(1,int(std::round(size*scale)));const auto extent=canvas_.measure(value,pixels);
    canvas_.text(value,(canvas_.width()-extent.x)/2,(canvas_.height()-200*scale)/2+(baseline-size)*scale,pixels,{238,202,136,255});
}
void StartupIntro::draw() {
    if(!active())return;auto* renderer=canvas_.renderer();const int tick=timeline_.tick();
    SDL_SetRenderDrawColor(renderer,0,0,0,255);render_check(SDL_RenderClear(renderer),"Startup backdrop");
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    const float x=(canvas_.width()-320*scale)/2,y=(canvas_.height()-200*scale)/2;
    const bool publisher=tick<StartupTimeline::publisher_end;
    const int lift=publisher?std::clamp((tick-207)*2,0,70):0;
    const int pose=publisher?std::clamp((tick-99)/9,0,8):0;
    const SDL_FRect box{x,y+(publisher?60-lift:0)*scale,320*scale,80*scale};
    const SDL_Color modulation{255,255,255,Uint8(std::lround((publisher?1.0-double(pose)/8:1)*255))};
    const float top=publisher?0.f:.5f,bottom=publisher?.5f:1.f;
    // The actual atlas has odd height887. Fractional UVs preserve its half-row
    // source split; integer SDL_Rect cropping would lose that source registration.
    const SDL_Vertex vertices[]{{{box.x,box.y},modulation,{0,top}},{{box.x+box.w,box.y},modulation,{1,top}},{{box.x+box.w,box.y+box.h},modulation,{1,bottom}},{{box.x,box.y+box.h},modulation,{0,bottom}}};
    constexpr int indices[]{0,1,2,0,2,3};render_check(SDL_RenderGeometry(renderer,canvas_.texture(artwork_),vertices,4,indices,6),"Startup painting");
    if(publisher&&tick>=99) {
        const int letters=std::clamp((tick-99)/9+1,0,8);
        centered(float(140-lift),std::string_view(title_).substr(0,(title_.size()*std::size_t(letters)+7)/8),18);
    } else if(!publisher&&tick>=StartupTimeline::title_ready-4) {
        centered(30,title_,23);float baseline=100;
        for(const auto& credit:credits_) {centered(baseline,credit,8);baseline+=13;}
    }
    if(timeline_.exit_tick()>=0) {
        const auto alpha=Uint8(std::clamp(std::lround(double(tick-timeline_.exit_tick())*255/StartupTimeline::exit_fade),0L,255L));
        SDL_SetRenderDrawBlendMode(renderer,SDL_BLENDMODE_BLEND);SDL_SetRenderDrawColor(renderer,0,0,0,alpha);
        const SDL_FRect full{0,0,float(canvas_.width()),float(canvas_.height())};render_check(SDL_RenderFillRectF(renderer,&full),"Startup exit fade");
    }
}
}
