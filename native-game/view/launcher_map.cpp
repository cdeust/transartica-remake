// SPDX-License-Identifier: MIT
// Source launcher_scene.gd map registration16px/cell and target12px maximum.
#include "view.h"
#include "render_check.h"
#include <algorithm>
#include <cmath>
#include <numbers>
namespace transartica {
void View::launcher_map(const Session& session,Cell camera,Point glide) {
    const auto frame=fit(320,200);const float scale=frame.w/320;
    const SDL_FRect viewport{frame.x,frame.y,frame.w,149*scale};
    auto* renderer=canvas_.renderer();SDL_SetRenderDrawColor(renderer,13,27,35,255);
    render_check(SDL_RenderFillRectF(renderer,&viewport),"Launcher map background");
    const auto project=[&](Point p){return Point{frame.x+((p.x-camera.x)*16-glide.x)*scale,frame.y+((p.y-camera.y)*16-glide.y)*scale};};
    for(const auto& region:regions_) {
        const auto p=project({region.world.x,region.world.y});
        const SDL_FRect box{float(p.x),float(p.y),region.world.w*16*scale,region.world.h*16*scale};
        if(!SDL_HasIntersectionF(&box,&viewport))continue;
        render_check(SDL_RenderCopyF(renderer,canvas_.texture(region.path),&region.crop,&box),"Launcher selected world artwork");
    }
    SDL_SetRenderDrawColor(renderer,23,54,65,255);
    // Cover one cell beyond viewport for the source16px camera scroll.
    for(int x=std::max(0,camera.x-1);x<std::min(RailNetwork::width,camera.x+22);++x)
        for(int y=std::max(0,camera.y-1);y<std::min(RailNetwork::height,camera.y+11);++y) {
            const Point center{x+.5,y+.5};const auto a=project(center);
            for(auto port:rail_ports(session.network.tile({x,y}))) {
                const auto b=project(center+port);render_check(SDL_RenderDrawLineF(renderer,a.x,a.y,b.x,b.y),"Launcher rail");
            }
        }
}
void View::launcher_target(Cell cell,int heading,Cell camera,Point glide) {
    const auto found=frames_.find("locomotive");if(found==frames_.end())return;
    const auto& art=found->second;const auto frame=fit(320,200);const float scale=frame.w/320;
    const auto direction=heading_delta(heading);
    const Point center{frame.x+((cell.x-camera.x+.5)*16-glide.x)*scale,frame.y+((cell.y-camera.y+.5)*16-glide.y)*scale};
    draw_frame_at(art,center,std::atan2(direction.y,direction.x)-std::numbers::pi/2,
        12*scale/std::max(art.bounds.w,art.bounds.h),{255,255,255,255});
}
}
