// SPDX-License-Identifier: MIT
// Composition: world_event_screen.gd and artwork_presentation.gd.
#include "work_screen.h"
#include "view/render_check.h"
#include <json-c/json.h>
#include <algorithm>
#include <cmath>
#include <memory>
#include <stdexcept>

namespace transartica::panels {
namespace {constexpr SDL_Color gold{238,202,136,255};}
WorkScreen::WorkScreen(Canvas& canvas,std::filesystem::path assets):canvas_(canvas),assets_(std::move(assets)),ambience_(assets_) {
    using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
    const auto file=assets_.parent_path()/"data/textek.json";
    Json data(json_object_from_file(file.string().c_str()),json_object_put);
    json_object* messages{};
    if(!data || !json_object_object_get_ex(data.get(),"messages",&messages) || !json_object_is_type(messages,json_type_object))
        throw std::runtime_error("Missing or invalid TEXTEK messages: "+file.string());
    json_object_object_foreach(messages,key,value) {
        if(!json_object_is_type(value,json_type_array)) throw std::runtime_error("Invalid TEXTEK message lines");
        auto& lines=messages_[std::stoi(key)];
        for(std::size_t i=0;i<json_object_array_length(value);++i) {
            auto* line=json_object_array_get_idx(value,i);
            if(!json_object_is_type(line,json_type_string)) throw std::runtime_error("Invalid TEXTEK line");
            lines.emplace_back(json_object_get_string(line));
        }
    }
}
SDL_FRect WorkScreen::frame() const {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    return {(canvas_.width()-320*scale)/2,(canvas_.height()-200*scale)/2,320*scale,200*scale};
}
SDL_FRect WorkScreen::rect(SDL_FRect r) const {
    const auto f=frame();const float s=f.w/320;
    return {f.x+r.x*s,f.y+r.y*s,r.w*s,r.h*s};
}
void WorkScreen::panel(SDL_FRect box,SDL_Color color) {
    const auto r=rect(box);auto* renderer=canvas_.renderer();
    SDL_SetRenderDrawColor(renderer,color.r,color.g,color.b,color.a);
    render_check(SDL_RenderFillRectF(renderer,&r),"Work panel");
    SDL_SetRenderDrawColor(renderer,gold.r,gold.g,gold.b,gold.a);
    render_check(SDL_RenderDrawRectF(renderer,&r),"Work panel border");
}
void WorkScreen::centered(float baseline,std::string_view value,int size) {
    const auto f=frame();const float scale=f.w/320;
    const int pixels=std::max(1,int(std::round(size*scale)));
    const auto extent=canvas_.measure(value,pixels);
    canvas_.text(value,f.x+(f.w-extent.x)/2,f.y+(baseline-size)*scale,pixels,gold);
}
void WorkScreen::button(SDL_FRect box,std::string_view value) {
    panel(box,{60,52,41,255});
    const auto f=frame();const float s=f.w/320;
    canvas_.text(value,f.x+(box.x+7)*s,f.y+(box.y+4)*s,std::max(1,int(std::round(6*s))),gold);
}
std::vector<std::string> WorkScreen::lines(const TrackWorks& work) const {
    if(work.stage==WorkStage::Report) return {std::to_string(work.used)+" RAILS",std::to_string(work.labour.slaves)+" SLAVE(S)",
        std::to_string(work.labour.mammoths)+" MAMMOTH(S)",std::to_string(work.labour.cranes)+" CRANE(S)"};
    const int id=work.stage==WorkStage::Information?work.information:
        work.stage==WorkStage::Shortage?work_rule(work.kind).lack:work_rule(work.kind).question;
    const auto found=messages_.find(id);
    if(found==messages_.end()) throw std::runtime_error("Missing TEXTEK message "+std::to_string(id));
    auto result=found->second;
    if(work.stage==WorkStage::Shortage) {
        result.push_back(work.lacks_rails?"BUT YOU DON'T HAVE":"BUT YOU DON'T HAVE ENOUGH");
        result.push_back(work.lacks_rails?"ENOUGH RAILS TO REPAIR":"SLAVES TO WORK ON IT");
    }
    return result;
}
void WorkScreen::advance(double seconds,const TrackWorks& work) {
    if(!work.active()) {ambience_.clear();return;}
    ambience_.advance(seconds,"works",work.stage==WorkStage::Report&&work.countdown>0);
}
void WorkScreen::draw(const TrackWorks& work) {
    if(!work.active()) return;
    const auto backdrop=rect({0,0,320,149});
    SDL_SetRenderDrawColor(canvas_.renderer(),12,29,39,255);
    render_check(SDL_RenderFillRectF(canvas_.renderer(),&backdrop),"Work scene backdrop");
    const auto destination=rect({0,39,320,110});
    auto* texture=canvas_.texture(assets_/"world-events/track-works.png");
    int width{},height{};render_check(SDL_QueryTexture(texture,nullptr,nullptr,&width,&height),"Work art dimensions");
    const float scale=std::max(destination.w/width,destination.h/height);
    SDL_Rect crop{int((width-destination.w/scale)/2),int((height-destination.h/scale)/2),int(destination.w/scale),int(destination.h/scale)};
    render_check(SDL_RenderCopyF(canvas_.renderer(),texture,&crop,&destination),"Work scene");
    ambience_.draw(canvas_,"works");
    panel({1,1,318,37},{20,45,57,255});
    const auto text=lines(work);const float first=text.size()>2?11:15;
    for(std::size_t i=0;i<text.size();++i) centered(first+float(i)*8,text[i]);
    if(work.stage==WorkStage::Question) button({120,124,32,14},"NO");
    button({170,124,32,14},"OK");
}
WorkAction WorkScreen::handle(const SDL_Event& event,const TrackWorks& work) const {
    if(!work.active()) return WorkAction::None;
    const bool question=work.stage==WorkStage::Question;
    if(event.type==SDL_KEYDOWN && !event.key.repeat) {
        if(event.key.keysym.sym==SDLK_RETURN) return question?WorkAction::Accept:WorkAction::Dismiss;
        if(event.key.keysym.sym==SDLK_ESCAPE) return question?WorkAction::Decline:WorkAction::Dismiss;
    }
    if(event.type!=SDL_MOUSEBUTTONDOWN || event.button.button!=SDL_BUTTON_LEFT) return WorkAction::None;
    const auto f=frame();const SDL_FPoint p{(event.button.x-f.x)*320/f.w,(event.button.y-f.y)*200/f.h};
    const SDL_FRect no{120,124,32,14},yes{170,124,32,14};
    if(SDL_PointInFRect(&p,&yes)) return question?WorkAction::Accept:WorkAction::Dismiss;
    if(question && SDL_PointInFRect(&p,&no)) return WorkAction::Decline;
    return WorkAction::None;
}
}
