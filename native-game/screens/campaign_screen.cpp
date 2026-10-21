// SPDX-License-Identifier: MIT
// Sources: campaign_screen.gd, brass_choice.gd, finale_art.gd. Logical320x200.
#include "campaign_screen.h"
#include <algorithm>
#include <cmath>
#include <stdexcept>
namespace transartica::panels {
namespace {
constexpr SDL_Color gold{238,202,136,255};
void checked(int r){if(r<0)throw std::runtime_error(std::string("Campaign draw: ")+SDL_GetError());}
}
CampaignScreen::CampaignScreen(Canvas& c,std::filesystem::path a,campaign::Controller& ctl):canvas_(c),assets_(std::move(a)),controller_(ctl){}
CampaignScreen::~CampaignScreen(){if(text_input_)SDL_StopTextInput();}
SDL_FRect CampaignScreen::frame() const {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    return {(canvas_.width()-320*scale)/2,(canvas_.height()-200*scale)/2,320*scale,200*scale};
}
SDL_FRect CampaignScreen::rectangle(float x,float y,float w,float h) const {
    auto f=frame();float s=f.w/320;return {f.x+x*s,f.y+y*s,w*s,h*s};
}
void CampaignScreen::sync_input(){
    bool active=controller_.presentation().visible&&controller_.presentation().entering_code;
    // A modal book can stop SDL's process-wide text input while this scene
    // remains logically active; resume its native input when the book closes.
    if(active==text_input_&&(!active||SDL_IsTextInputActive()))return;
    text_input_=active;if(active)SDL_StartTextInput();else SDL_StopTextInput();
}
void CampaignScreen::plate(const std::filesystem::path& path,bool contain){
    auto* texture=canvas_.texture(assets_/path);auto box=frame();
    if(contain){int w,h;checked(SDL_QueryTexture(texture,nullptr,nullptr,&w,&h));float s=std::min(box.w/w,box.h/h);box={box.x+(box.w-w*s)/2,box.y+(box.h-h*s)/2,w*s,h*s};}
    checked(SDL_RenderCopyF(canvas_.renderer(),texture,nullptr,&box));
}
void CampaignScreen::centered(float baseline,std::string_view text){
    auto f=frame();float s=f.w/320;int pixels=std::max(1,int(std::round(7*s)));
    canvas_.text(text,f.x+(f.w-canvas_.measure(text,pixels).x)/2,f.y+(baseline-7)*s,pixels,gold);
}
void CampaignScreen::choice(SDL_FRect logical,SDL_FRect hit,std::string_view text,bool focused){
    int mx,my;auto buttons=SDL_GetMouseState(&mx,&my);auto bounds=frame();float s=bounds.w/320;
    SDL_FPoint p{(mx-bounds.x)/s,(my-bounds.y)/s};bool hovered=SDL_PointInFRect(&p,&hit);
    auto box=rectangle(logical.x,logical.y,logical.w,logical.h);auto* r=canvas_.renderer();
    SDL_SetRenderDrawColor(r,hovered?61:12,hovered?74:29,hovered?82:39,255);checked(SDL_RenderFillRectF(r,&box));
    // artwork_presentation.border_width uses one physical pixel, two when focused.
    float edge=(focused||(hovered&&(buttons&SDL_BUTTON_LMASK)))?2.f:1.f;
    SDL_SetRenderDrawColor(r,gold.r,gold.g,gold.b,255);
    const SDL_FRect borders[]{{box.x,box.y,box.w,edge},{box.x,box.y+box.h-edge,box.w,edge},{box.x,box.y,edge,box.h},{box.x+box.w-edge,box.y,edge,box.h}};
    for(auto border:borders)checked(SDL_RenderFillRectF(r,&border));
    int pixels=std::max(1,int(std::round(7*s)));auto size=canvas_.measure(text,pixels);
    canvas_.text(text,box.x+(box.w-size.x)/2,box.y+box.h-12*s,pixels,gold);
}
void CampaignScreen::draw(){
    sync_input();if(!controller_.presentation().visible)return;
    if(controller_.presentation().scene==campaign::Scene::SunRestored){draw_finale();return;}
    auto* r=canvas_.renderer();const auto& p=controller_.presentation();using campaign::Scene;
    if(!controller_.quarters_scene()){SDL_SetRenderDrawColor(r,12,29,39,255);checked(SDL_RenderClear(r));}
    auto name=campaign::scene_name(p.scene);
    if(p.scene==Scene::WhaleQuestion||p.scene==Scene::WhaleHarpoon)name="whale";
    if(p.scene==Scene::Sun)name="sun-overcast";
    if(p.scene==Scene::Wolf||p.scene==Scene::Mole)name+="-ambush";
    if(p.scene==Scene::Urga||p.scene==Scene::Oslo||p.scene==Scene::Mausoleum||p.scene==Scene::Sun||p.scene==Scene::Slope||name=="whale"||p.scene==Scene::Wolf||p.scene==Scene::Mole)plate("campaign/"+name+".png",true);
    else if(controller_.quarters_scene()){auto box=rectangle(0,0,320,149);checked(SDL_RenderCopyF(r,canvas_.texture(assets_/"boudoir/general-quarters.png"),nullptr,&box));}
    if(p.scene==Scene::Earth){plate("interface/mort-earth.png");return;}
    draw_page();
}
void CampaignScreen::draw_page(){
    const auto& p=controller_.presentation();using campaign::Scene;
    if(p.scene==Scene::Death||p.scene==Scene::Report||p.scene==Scene::ManualQuiz){
        plate("interface/inventory-frame.png");const int anchors[]{17,34,49,64,79,94,109,124,139,154};
        for(std::size_t i=0;i<p.lines.size()&&i<10;++i)centered(anchors[i],p.lines[i]);
        if(p.entering_code)centered(137,p.input_code+"_");return;
    }
    if(!p.menu.empty())for(std::size_t i=0;i<p.menu.size();++i)choice({64,44+float(i)*25,192,20},{0,44+float(i)*25,320,25},std::to_string(i+1)+"  "+p.menu[i],i==0);
    else {auto box=rectangle(0,159,320,41);SDL_SetRenderDrawColor(canvas_.renderer(),0,0,0,255);checked(SDL_RenderFillRectF(canvas_.renderer(),&box));for(std::size_t i=0;i<p.lines.size();++i)centered(169+i*9,p.lines[i]);}
    if(p.entering_code)centered(137,p.input_code+"_");
    if(p.question){choice({24,130,112,19},{0,0,160,200},"NO");choice({184,130,112,19},{160,0,160,200},"OK",true);}
}
void CampaignScreen::draw_finale(){
    const auto& f=controller_.finale();auto* r=canvas_.renderer();auto box=frame();
    SDL_SetRenderDrawColor(r,12,29,39,255);checked(SDL_RenderClear(r));plate("campaign/sun-overcast.png");
    int counter=f.tick-120;
    if(counter>=200)plate("campaign/sun-restored.png");
    else if(counter>=0){
        const SDL_Color grades[]{{255,255,255,255},{166,184,255,255},{255,204,140,255},{179,153,230,255}};
        auto c=grades[f.palette()];auto* t=canvas_.texture(assets_/"campaign/sun-overcast.png");
        checked(SDL_SetTextureColorMod(t,c.r,c.g,c.b));int result=SDL_RenderCopyF(r,t,nullptr,&box);SDL_SetTextureColorMod(t,255,255,255);checked(result);
    }
    if(counter<0){int shot=f.shot();if(shot>=37&&shot<=40){float w=shot==37?26:39,h=shot==37?22:32;effect({123-w/2,116-h/2,w,h},shot==37?2:3);}}
    else {auto shifts=f.clouds();for(int i=0;i<4;++i){effect({float(shifts[i]),float(i*6),175,56},i%2);effect({175.f-shifts[i],float(i*6),-175,56},i%2);}}
}
void CampaignScreen::effect(SDL_FRect dest,int cell){
    // finale_art._effect keeps origin for a negative width, then clips the mirror.
    float w=std::abs(dest.w),h=std::abs(dest.h),x=std::max(0.f,dest.x),y=std::max(0.f,dest.y);
    float right=std::min(320.f,dest.x+w),bottom=std::min(200.f,dest.y+h);if(right<=x||bottom<=y)return;
    auto* texture=canvas_.texture(assets_/"campaign/finale-effects.png");
    float offset=dest.w<0?dest.x+w-right:x-dest.x;
    float u=(cell%2+offset/w)/2,v=(cell/2+(y-dest.y)/h)/2;
    float end_u=u+(right-x)/w/2,end_v=v+(bottom-y)/h/2;
    if(dest.w<0)std::swap(u,end_u);auto box=rectangle(x,y,right-x,bottom-y);
    // Floating UVs preserve source fractional clipping at the mirrored cloud edge.
    constexpr SDL_Color white{255,255,255,255};
    const SDL_Vertex vertices[]{{{box.x,box.y},white,{u,v}},{{box.x+box.w,box.y},white,{end_u,v}},{{box.x+box.w,box.y+box.h},white,{end_u,end_v}},{{box.x,box.y+box.h},white,{u,end_v}}};
    constexpr int indices[]{0,1,2,0,2,3};checked(SDL_RenderGeometry(canvas_.renderer(),texture,vertices,4,indices,6));
}
void CampaignScreen::key(SDL_Keycode key){
    const auto& p=controller_.presentation();
    if(!p.menu.empty()){
        int choice=int(key-SDLK_1);if(choice>=0&&choice<int(p.menu.size()))controller_.menu(choice);
        else if(key==SDLK_ESCAPE||key==SDLK_F1)controller_.menu(int(p.menu.size())-1);return;
    }
    if(p.entering_code){if(key==SDLK_BACKSPACE)controller_.backspace();else if(key==SDLK_RETURN||key==SDLK_KP_ENTER)controller_.submit_code(p.input_code);return;}
    if(p.question){if(key==SDLK_ESCAPE||key==SDLK_n)controller_.answer(false);else if(key==SDLK_RETURN||key==SDLK_KP_ENTER||key==SDLK_y)controller_.answer(true);return;}
    if(key==SDLK_SPACE||key==SDLK_RETURN||key==SDLK_KP_ENTER||key==SDLK_ESCAPE)controller_.process();
}
bool CampaignScreen::handle_event(const SDL_Event& event){
    sync_input();const auto& p=controller_.presentation();if(!p.visible)return false;
    if(p.scene==campaign::Scene::SunRestored&&controller_.finale().tick<361)return true;
    if(event.type==SDL_TEXTINPUT)controller_.input(event.text.text);
    else if(event.type==SDL_KEYDOWN)key(event.key.keysym.sym);
    else if(event.type==SDL_MOUSEBUTTONDOWN){
        auto f=frame();float s=f.w/320;if(s<=0)return true;float x=(event.button.x-f.x)/s,y=(event.button.y-f.y)/s;
        if(x<0||x>=320||y<0||y>=200)return true;
        bool left=event.button.button==SDL_BUTTON_LEFT;
        if(!p.menu.empty()){int row=int(std::floor((y-44)/25));if(left&&row>=0&&row<int(p.menu.size()))controller_.menu(row);}
        else if(p.question){if(left)controller_.answer(x>=160);else if(event.button.button==SDL_BUTTON_RIGHT)controller_.answer(false);}
        else if(left&&!p.entering_code)controller_.process();
    }
    sync_input();return true;
}
}
