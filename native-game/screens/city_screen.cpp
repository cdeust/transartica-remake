// SPDX-License-Identifier: MIT
// Source: city_screen.gd, city_backdrop.gd, city_list_icons.gd, station_workshop.gd.
#include "city_screen.h"
#include <json-c/json.h>
#include <algorithm>
#include <cmath>
#include <memory>
#include <stdexcept>

namespace transartica::panels {
using namespace economy;
namespace {
constexpr SDL_Color ink{12,29,39,255},gold{238,202,136,255},steel{77,132,147,255},paper{240,227,203,255};
bool inside(SDL_FRect r,Point p) { return p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h; }
void checked(int value) { if(value<0) throw std::runtime_error(std::string("City drawing: ")+SDL_GetError()); }
std::string refusal_text(int code) {
    switch(code) {
    case NoRoom:return "No room left in suitable wagons.";
    case NothingToSell:return "Nothing of this kind aboard.";
    case NoMoney:return "Not enough lignite to pay.";
    case NotEnoughLoad:return "You do not carry that many.";
    case NoCoalRoom:return "The tenders cannot hold that much more coal.";
    case WagonsFull:return "The train cannot take more wagons.";
    case 35:return "THIS WAGON IS UNDAMAGED";
    case 87:return "THIS WAGON IS DESTROYED";
    case 88:return "YOU CANNOT REMOVE THIS WAGON";
    default:return {}; // GLIEU stock/tender limits are silent refusals.
    }
}
constexpr std::array<int,25> tare{1000,50,40,110,65,85,60,105,20,100,100,40,120,40,45,55,45,55,40,90,50,50,80,100,200};
}
CityScreen::CityScreen(Canvas& canvas,std::filesystem::path assets,Trade& trade,const WorldData& world,EngineState& engine,std::vector<Wagon>& wagons)
    :canvas_(canvas),assets_(std::move(assets)),trade_(trade),world_(world),engine_(engine),wagons_(wagons),management_(engine,wagons) {}
SDL_FRect CityScreen::frame() const {
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    return {(canvas_.width()-320*scale)*.5f,(canvas_.height()-200*scale)*.5f,320*scale,200*scale};
}
Point CityScreen::logical(float x,float y) const { auto f=frame(); return f.w>0?Point{(x-f.x)*320/f.w,(y-f.y)*200/f.h}:Point{-1,-1}; }
SDL_FRect CityScreen::rect(SDL_FRect r) const { auto f=frame(); float s=f.w/320; return {f.x+r.x*s,f.y+r.y*s,r.w*s,r.h*s}; }
void CityScreen::fill(SDL_FRect box,SDL_Color c) {
    checked(SDL_SetRenderDrawBlendMode(canvas_.renderer(),SDL_BLENDMODE_BLEND));
    checked(SDL_SetRenderDrawColor(canvas_.renderer(),c.r,c.g,c.b,c.a)); auto r=rect(box);
    checked(SDL_RenderFillRectF(canvas_.renderer(),&r));
}
void CityScreen::panel(SDL_FRect box,SDL_Color c,SDL_Color edge) {
    fill(box,c); checked(SDL_SetRenderDrawColor(canvas_.renderer(),edge.r,edge.g,edge.b,edge.a)); auto r=rect(box);
    checked(SDL_RenderDrawRectF(canvas_.renderer(),&r));
}
void CityScreen::text(std::string_view value,SDL_FRect box,int size,SDL_Color c) {
    auto r=rect(box); int pixels=std::max(1,int(std::round(size*frame().w/320)));
    SDL_FPoint measured=canvas_.measure(value,pixels);
    while(pixels>1&&(measured.x>r.w||measured.y>r.h)) measured=canvas_.measure(value,--pixels);
    canvas_.text(value,r.x+(r.w-measured.x)*.5f,r.y+(r.h-measured.y)*.5f,pixels,c);
}
void CityScreen::picture(const std::filesystem::path& path,SDL_FRect box,bool cover,const SDL_Rect* crop) {
    auto* texture=canvas_.texture(path); int w=0,h=0; checked(SDL_QueryTexture(texture,nullptr,nullptr,&w,&h));
    SDL_Rect source=crop?*crop:SDL_Rect{0,0,w,h}; auto destination=rect(box);
    if(source.w<=0||source.h<=0||destination.w<=0||destination.h<=0) return;
    if(cover) {
        float scale=std::max(destination.w/source.w,destination.h/source.h);
        int cw=std::max(1,int(std::round(destination.w/scale))),ch=std::max(1,int(std::round(destination.h/scale)));
        source.x+=(source.w-cw)/2; source.y+=(source.h-ch)/2; source.w=cw; source.h=ch;
    } else {
        float scale=std::min(destination.w/source.w,destination.h/source.h);
        float width=source.w*scale,height=source.h*scale;
        destination.x+=(destination.w-width)/2; destination.y+=(destination.h-height)/2; destination.w=width; destination.h=height;
    }
    checked(SDL_RenderCopyF(canvas_.renderer(),texture,&source,&destination));
}
void CityScreen::load_icons() {
    if(icons_loaded_) return;
    using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
    Json root(json_object_from_file((assets_/"cities/goods-icons.json").string().c_str()),json_object_put);
    json_object *frames=nullptr,*file=nullptr;
    if(!root||!json_object_object_get_ex(root.get(),"frames",&frames)||!json_object_is_type(frames,json_type_array)||json_object_array_length(frames)!=16||
       !json_object_object_get_ex(root.get(),"file",&file)||!json_object_is_type(file,json_type_string)) throw std::runtime_error("Invalid goods icon manifest");
    std::array<Icon,16> staged; std::array<bool,16> seen{};
    const auto path=assets_/"cities"/json_object_get_string(file);
    int width=0,height=0; checked(SDL_QueryTexture(canvas_.texture(path),nullptr,nullptr,&width,&height));
    for(int i=0;i<16;++i) {
        auto* item=json_object_array_get_idx(frames,i); json_object *id=nullptr,*region=nullptr;
        if(!json_object_object_get_ex(item,"id",&id)||!json_object_object_get_ex(item,"region",&region)||!json_object_is_type(region,json_type_array)||json_object_array_length(region)!=4)
            throw std::runtime_error("Invalid goods icon");
        int index=json_object_get_int(id)-1;
        if(index<0||index>=16||seen[index]) throw std::runtime_error("Invalid goods icon ID");
        SDL_Rect r{json_object_get_int(json_object_array_get_idx(region,0)),json_object_get_int(json_object_array_get_idx(region,1)),json_object_get_int(json_object_array_get_idx(region,2)),json_object_get_int(json_object_array_get_idx(region,3))};
        if(r.x<0||r.y<0||r.w<=0||r.h<=0||r.x+r.w>width||r.y+r.h>height) throw std::runtime_error("Invalid goods icon region");
        seen[index]=true; staged[index]={path,r};
    }
    icons_=std::move(staged); icons_loaded_=true;
}
void CityScreen::draw_wagon(int type,SDL_FRect box) {
    if(type<1||type>25) return;
    if(station_) {
        // station_workshop.gd rotates train_renderer.gd's actual overhead frame.
        load_overhead(); const auto& icon=overhead_[type-1];
        auto destination=rect(box); const float scale=std::min(destination.w/icon.crop.h,destination.h/icon.crop.w);
        const float w=icon.crop.w*scale,h=icon.crop.h*scale;
        destination={destination.x+(destination.w-w)*.5f,destination.y+(destination.h-h)*.5f,w,h};
        checked(SDL_RenderCopyExF(canvas_.renderer(),canvas_.texture(icon.path),&icon.crop,&destination,-90,nullptr,SDL_FLIP_NONE)); return;
    }
    // city_list_icons.gd uses these measured authored tactical silhouettes.
    // One pixel fringe is retained, as in tactical_wagon_art.gd texture_for().
    static constexpr int master[25]={0,0,0,1,1,1,1,1,1,2,0,2,2,2,2,2,3,3,3,3,0,3,0,3,3};
    static constexpr SDL_Rect bounds[25]={{34,120,796,245},{1392,124,749,241},{26,420,688,236},{35,42,711,334},{787,136,716,240},{21,437,745,250},{787,437,729,250},{21,741,744,231},{781,759,734,213},{31,66,731,269},{1449,481,692,175},{783,129,725,206},{28,455,735,200},{783,403,725,252},{31,720,731,237},{783,731,725,231},{38,53,635,202},{717,59,804,196},{23,309,690,194},{737,305,782,198},{847,156,524,211},{27,510,631,241},{737,426,692,230},{675,556,843,195},{38,771,665,218}};
    static const char* files[]={"train-master.png","wagons-master-04-10.png","wagons-master-10-17.png","wagons-master-17-25.png"};
    if(type==1) { SDL_Rect hero{16,35,2002,673}; picture(assets_/"combat/wagon-01.png",box,false,&hero); return; }
    auto r=bounds[type-1]; --r.x; --r.y; r.w+=2; r.h+=2;
    picture(assets_/"combat"/files[master[type-1]],box,false,&r);
}
void CityScreen::load_overhead() {
    if(overhead_loaded_) return;
    using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
    Json root(json_object_from_file((assets_/"travel/vehicles-overhead.json").string().c_str()),json_object_put);
    json_object *vehicles=nullptr,*file=nullptr;
    if(!root||!json_object_object_get_ex(root.get(),"vehicles",&vehicles)||!json_object_is_type(vehicles,json_type_object)||
        !json_object_object_get_ex(root.get(),"file",&file)||!json_object_is_type(file,json_type_string)) throw std::runtime_error("Invalid station vehicle manifest");
    std::array<Icon,25> staged; std::array<bool,25> seen{};
    const auto path=assets_/"travel"/json_object_get_string(file);
    int width{},height{}; checked(SDL_QueryTexture(canvas_.texture(path),nullptr,nullptr,&width,&height));
    json_object_object_foreach(vehicles,key,value) {
        (void)key; json_object *id=nullptr,*region=nullptr;
        if(!json_object_object_get_ex(value,"type_id",&id)||!json_object_object_get_ex(value,"region",&region)||
            !json_object_is_type(region,json_type_array)||json_object_array_length(region)!=4) throw std::runtime_error("Invalid station vehicle");
        int index=json_object_get_int(id)-1;
        if(index<0||index>=25||seen[index]) throw std::runtime_error("Invalid station vehicle type");
        SDL_Rect r{json_object_get_int(json_object_array_get_idx(region,0)),json_object_get_int(json_object_array_get_idx(region,1)),json_object_get_int(json_object_array_get_idx(region,2)),json_object_get_int(json_object_array_get_idx(region,3))};
        if(r.x<0||r.y<0||r.w<=0||r.h<=0||r.x+r.w>width||r.y+r.h>height) throw std::runtime_error("Invalid station vehicle region");
        staged[index]={path,r}; seen[index]=true;
    }
    if(std::find(seen.begin(),seen.end(),false)!=seen.end()) throw std::runtime_error("Incomplete station vehicle manifest");
    staged[0]={assets_/"travel/locomotive-hero.png",{178,48,438,1886}};
    overhead_=std::move(staged); overhead_loaded_=true;
}
bool CityScreen::open(int index,Random& random) {
    if(!restore_city(index)) return false;
    trade_.visit(index,random); return true;
}
bool CityScreen::restore_city(int index) {
    const auto* city=world_.city(index); if(!city||!trade_.loaded()) return false;
    city_=index; kind_=city->kind; title_=city->name; station_=false; active_=true; direct_=false;
    notice_.clear(); menu();
    if(kind_==Garrison&&!trade_.offers_spies(city_)) { direct_=true; start(Buy); }
    return true;
}
void CityScreen::open_workshop(Cell cell) {
    station_=true; active_=true; city_=-1; kind_=3; title_=Management::station_name(cell);
    transaction_=false; workshop_=false; selection_=-1; train_scroll_=0; moving_=-1; confirmation_=false; notice_.clear();
}
WorkshopState CityScreen::workshop_snapshot() const {
    if(!station_) return {};
    return {active_,title_,selection_,station_action_,train_scroll_,active_?moving_:-1,active_&&confirmation_,notice_};
}
bool CityScreen::restore_workshop(const WorkshopState& value) {
    if(!management_.valid_workshop(value)) return false;
    station_=true; active_=value.visible; city_=-1; kind_=3; transaction_=false; workshop_=false;
    title_=value.title; selection_=value.selected; station_action_=value.action; train_scroll_=value.scroll;
    moving_=value.moving; confirmation_=value.confirmation; notice_=value.notice; return true;
}
void CityScreen::menu() {
    transaction_=false; offer_.reset(); entry_.reset(); workshop_=false; depart_only_=false; quantity_=0; selection_=-1; list_scroll_=0;
}
void CityScreen::fill_list() {
    rows_=trade_.goods_list(city_,mode_,wagons_);
    selection_=-1;
    if(offer_) for(std::size_t i=0;i<rows_.size();++i) if(rows_[i].goods==offer_->goods) selection_=int(i);
    list_scroll_=std::clamp(list_scroll_,0,std::max(0,(int(rows_.size())+4)/5-2));
}
void CityScreen::start(int mode) {
    if(!active_||station_||(mode!=Buy&&mode!=Sell)) return;
    mode_=mode; quantity_=0; notice_.clear(); workshop_=false;
    if(kind_==Commercial) { offer_.reset(); fill_list(); }
    else {
        offer_=trade_.offer(city_,kind_,mode);
        if(!offer_) { notice_="No price is recorded for this city."; return; }
        int refusal=trade_.entry_refusal(*offer_,wagons_);
        if(refusal) { notice_=refusal_text(refusal); if(direct_) depart_only_=true; return; }
    }
    transaction_=true;
}
void CityScreen::start_workshop() {
    if(!active_||station_||city_<10||city_>16) return;
    workshop_=true; entry_.reset(); offer_.reset(); quantity_=0; selection_=-1; list_scroll_=0;
    notice_.clear(); entries_=trade_.workshop_list(city_); transaction_=true;
}
void CityScreen::select(int row) {
    if(!transaction_) return;
    if(workshop_) { if(row<0||row>=int(entries_.size())) return; entry_=entries_[row]; }
    else { if(row<0||row>=int(rows_.size())) return; offer_=trade_.offer(city_,kind_,mode_,rows_[row].goods); }
    selection_=row; quantity_=0; notice_.clear();
}
void CityScreen::increment() {
    int refusal=0;
    if(workshop_) { if(!entry_) return; refusal=Trade::workshop_refusal(*entry_,quantity_,wagons_,engine_); }
    else { if(!offer_) return; refusal=trade_.increment_refusal(*offer_,quantity_,wagons_,engine_); }
    if(!refusal) { ++quantity_; notice_.clear(); }
    else if(auto message=refusal_text(refusal);!message.empty()) notice_=std::move(message);
}
void CityScreen::decrement() { if(quantity_>0) --quantity_; }
CityEvent CityScreen::finish() {
    direct_=false;
    if(city_>=5&&city_<=7) return {true,false,0,true};
    menu(); return {false,false,0,true};
}
CityEvent CityScreen::validate() {
    CityEvent event{false,false,0,true}; if(!transaction_) return event;
    if(workshop_) {
        if(quantity_>0&&entry_) {
            int refusal=Trade::buy_wagons(*entry_,quantity_,wagons_,engine_);
            if(refusal) { notice_=refusal_text(refusal); return event; }
            event.cargo_changed=true;
        }
        quantity_=0; entry_.reset(); selection_=-1; return event;
    }
    if(!offer_) return event;
    if(quantity_>0) {
        int refusal=trade_.commit(*offer_,quantity_,wagons_,engine_);
        if(refusal) { notice_=refusal_text(refusal); return event; }
        event.cargo_changed=true;
    }
    quantity_=0;
    if(kind_==Commercial) fill_list();
    else { auto end=finish(); event.depart=end.depart; }
    return event;
}
CityEvent CityScreen::leave_transaction() { if(workshop_) { menu(); return {false,false,0,true}; } return finish(); }
std::vector<CityScreen::Button> CityScreen::buttons() const {
    std::vector<Button> result;
    if(station_) {
        const char* labels[]={"MOVE","WAGON","REPAIR","REMOVE","EXIT"};
        for(int i=0;i<5;++i) result.push_back({{20.f+56*i,22,55,15},labels[i],50+i});
        return result;
    }
    if(transaction_) return {{{20,23,34,13},"OK",100},{{58,23,34,13},"-",101},{{118,23,34,13},"+",102},{{156,23,34,13},"EXIT",103}};
    std::vector<std::pair<std::string,int>> choices;
    if(!depart_only_) {
        if(city_>=10&&city_<=16) choices.push_back({"BUY",104});
        else if(kind_==Town) { choices.push_back({"INFORMATION",105}); choices.push_back({"RUMOURS",106}); }
        else if(kind_==Garrison) { choices.push_back({"ENLIST",Buy}); if(trade_.offers_spies(city_)) choices.push_back({"SPY",Sell}); }
        else { choices.push_back({"BUY",Buy}); choices.push_back({"SELL",Sell}); }
    }
    choices.push_back({"EXIT",107});
    // Source menu band20..300 with centered buttons. Town labels require wider cells.
    const float width=kind_==Town?80.f:54.f,spacing=4.f;
    float x=(320-(width+spacing)*float(choices.size())+spacing)*.5f;
    for(const auto& choice:choices) { result.push_back({{x,23,width,13},choice.first,choice.second}); x+=width+spacing; }
    return result;
}
CityEvent CityScreen::activate(int action) {
    if(station_) {
        if(action==54) return {true,false,0,true};
        station_action_=action; moving_=-1; confirmation_=false; return {false,false,0,true};
    }
    switch(action) {
    case Buy: case Sell:start(action);break;
    case 100:return validate(); case 101:decrement();break; case 102:increment();break;
    case 103:return leave_transaction(); case 104:start_workshop();break;
    case 105:case 106:
        if(kind_==Town&&city_>=17&&city_<=23) return {false,false,(city_-17)*2+action-104,true};
        break;
    case 107:return {true,false,0,true}; default:break;
    }
    return {false,false,0,true};
}
CityEvent CityScreen::choose_wagon(int index) {
    CityEvent event{false,false,0,true}; if(index<0||index>=int(wagons_.size())) return event;
    if(moving_>=0) { event.cargo_changed=management_.move(moving_,index); moving_=-1; station_action_=51; }
    selection_=index; confirmation_=false; notice_.clear();
    if(station_action_==50) { moving_=index; notice_="SELECT THE DESTINATION WAGON"; }
    else if(station_action_==52||station_action_==53) {
        int refusal=station_action_==52?management_.repair_refusal(index):management_.remove_refusal(index);
        confirmation_=refusal==0; notice_=refusal_text(refusal);
    }
    return event;
}
CityEvent CityScreen::confirm(bool accepted) {
    CityEvent event{false,false,0,true}; if(!confirmation_) return event;
    event.cargo_changed=station_action_==52?management_.repair(selection_,accepted):management_.remove(selection_,accepted);
    confirmation_=false; if(event.cargo_changed) selection_=-1;
    train_scroll_=std::clamp(train_scroll_,0,std::max(0,int(wagons_.size())-10)); return event;
}
CityEvent CityScreen::handle(const SDL_Event& event) {
    if(!active_) return {};
    if(event.type==SDL_KEYDOWN&&!event.key.repeat) {
        const auto key=event.key.keysym.sym;
        if(station_) {
            if(confirmation_&&(key==SDLK_RETURN||key==SDLK_KP_ENTER||key==SDLK_ESCAPE)) return confirm(key!=SDLK_ESCAPE);
            if(key==SDLK_RETURN||key==SDLK_KP_ENTER) return {true,false,0,true};
        } else {
            if(key==SDLK_RETURN||key==SDLK_KP_ENTER) return transaction_?validate():CityEvent{true,false,0,true};
            if(transaction_) {
                if(key==SDLK_ESCAPE) return leave_transaction();
                if(key==SDLK_EQUALS||key==SDLK_PLUS||key==SDLK_KP_PLUS) { increment(); return {false,false,0,true}; }
                if(key==SDLK_MINUS||key==SDLK_KP_MINUS) { decrement(); return {false,false,0,true}; }
                if((workshop_||kind_==Commercial)&&(key==SDLK_LEFT||key==SDLK_RIGHT||key==SDLK_UP||key==SDLK_DOWN)) {
                    int count=workshop_?int(entries_.size()):int(rows_.size());
                    if(count>0) { int delta=key==SDLK_LEFT?-1:key==SDLK_RIGHT?1:key==SDLK_UP?-5:5; select(std::clamp(selection_<0?0:selection_+delta,0,count-1)); if(!workshop_) list_scroll_=std::clamp(selection_/5-1,0,std::max(0,(count+4)/5-2)); }
                    return {false,false,0,true};
                }
            }
        }
    }
    if(event.type==SDL_MOUSEWHEEL&&transaction_&&!workshop_&&kind_==Commercial) {
        list_scroll_=std::clamp(list_scroll_-event.wheel.y,0,std::max(0,(int(rows_.size())+4)/5-2)); return {false,false,0,true};
    }
    if(event.type!=SDL_MOUSEBUTTONDOWN||event.button.button!=SDL_BUTTON_LEFT) return {};
    Point p=logical(float(event.button.x),float(event.button.y));
    if(!inside({0,0,320,149},p)) return {};
    if(station_&&confirmation_&&p.y>=124&&p.y<141) return confirm(p.x>=170&&p.x<=202);
    for(const auto& button:buttons()) if(inside(button.box,p)) return activate(button.action);
    if(station_) {
        if(inside({20,40,280,24},p)) return choose_wagon(train_scroll_+int((p.x-20)/28));
        if(p.y>=40&&p.y<=64) train_scroll_=std::clamp(train_scroll_+(p.x>300?1:-1),0,std::max(0,int(wagons_.size())-10));
    } else if(transaction_&&(workshop_||kind_==Commercial)&&inside({4,42,312,62},p)) {
        int rows=workshop_?std::max(1,(int(entries_.size())+4)/5):2;
        select((int((p.y-42)/(62.f/rows))+(workshop_?0:list_scroll_))*5+std::min(4,int((p.x-4)/(312.f/5))));
    }
    return {false,false,0,true};
}
void CityScreen::draw() {
    if(!active_) return;
    static const char* names[]={"","city-information","city-trading-station","city-industrial-workshop","city-garrison","city-mammoth-fair","city-slave-market"};
    int scene=(station_||(city_>=10&&city_<=16))?3:kind_;
    fill({0,0,320,149},ink);
    if(scene>=1&&scene<=6) picture(assets_/"cities"/(std::string(names[scene])+".png"),{0,39,320,110},true);
    if(transaction_||station_) fill({0,39,320,110},station_?SDL_Color{5,15,23,173}:SDL_Color{6,17,22,235});
    panel({1,1,318,19},ink,steel); text(title_,{7,2,306,17},8,paper);
    for(const auto& button:buttons()) {
        const bool selected=station_&&button.action==station_action_;
        panel(button.box,selected?SDL_Color{87,70,50,255}:SDL_Color{58,48,37,255},gold);
        text(button.label,button.box,6,paper);
    }
    if(station_) draw_station();
    else if(transaction_) draw_transaction();
    text(notice_,{7,139,306,8},5,paper);
}
void CityScreen::draw_station() {
        text("<",{2,40,15,24},9,gold); text(">",{303,40,15,24},9,gold);
        for(int i=train_scroll_;i<std::min(train_scroll_+10,int(wagons_.size()));++i) {
            SDL_FRect box{20.f+(i-train_scroll_)*28,40,27,24};
            panel(box,i==selection_?SDL_Color{59,72,80,255}:SDL_Color{21,43,52,255},i==selection_?gold:steel);
            draw_wagon(wagons_[i].type,{box.x+1.5f,box.y+3.5f,24,17});
        }
        if(selection_<0||selection_>=int(wagons_.size())) text("SELECT A WAGON IN THE TRAIN",{10,87,300,20},7,gold);
        else {
            const auto& w=wagons_[selection_]; draw_wagon(w.type,{24.5f,67,115,58});
            text(trade_.wagon_name(w.type),{145,70,170,13},7,paper);
            const int weight=w.type>=1&&w.type<=25?tare[w.type-1]:0;
            text("TARE: "+std::to_string(weight)+"  STATE: "+std::to_string(w.state),{145,84,170,12},6,paper);
            text("TRANSPORT: "+std::to_string(w.quantity)+" "+trade_.goods_name(w.goods),{145,98,170,12},6,paper);
            if(confirmation_) {
                text(station_action_==52?"REPAIR: "+std::to_string(management_.repair_price(selection_))+" LIGNITE":"REMOVE THIS WAGON?",{10,114,300,13},6,gold);
                text("NO",{112,128,30,13},6,gold); text("OK",{170,128,32,13},6,gold);
            }
        }
}
void CityScreen::draw_transaction() {
        text(std::to_string(quantity_),{96,23,18,13},5,paper);
        if(workshop_||kind_==Commercial) {
            if(!workshop_) load_icons();
            int count=workshop_?int(entries_.size()):int(rows_.size());
            const int visible_rows=workshop_?std::max(1,(count+4)/5):2;
            const float row_height=62.f/visible_rows;
            const int first=workshop_?0:list_scroll_*5;
            for(int i=first;i<std::min(count,first+visible_rows*5);++i) {
                SDL_FRect box{4.f+((i-first)%5)*(312.f/5),42.f+((i-first)/5)*row_height,312.f/5,row_height};
                if(i==selection_) panel(box,{74,69,55,255},gold);
                const float icon_height=std::min(16.f,row_height-10.f);
                if(workshop_) draw_wagon(entries_[i].type,{box.x+7,box.y,48,icon_height});
                else { const auto& icon=icons_[rows_[i].goods-1]; picture(icon.path,{box.x+7,box.y,48,icon_height},false,&icon.crop); }
                const std::string name=workshop_?trade_.wagon_name(entries_[i].type):trade_.goods_name(rows_[i].goods);
                text(name,{box.x+1,box.y+icon_height,box.w-2,5},5,paper);
                text(std::to_string(workshop_?entries_[i].price:rows_[i].quantity),{box.x+1,box.y+icon_height+5,box.w-2,5},5,paper);
            }
        }
        std::array<std::string,3> lines;
        if(workshop_) {
            lines[0]=entry_?"Buy "+trade_.wagon_name(entry_->type)+" / "+std::to_string(entry_->price)+" each":"Choose a wagon in the list.";
            if(entry_) lines[1]="Quantity "+std::to_string(quantity_)+" / total "+std::to_string(quantity_*entry_->price)+" lignite";
            lines[2]="Wagons "+std::to_string(wagons_.size());
        } else if(!offer_) lines[0]="Choose goods in the list.";
        else {
            auto cap=trade_.capacity(*offer_,wagons_);
            const auto what=offer_->goods?trade_.goods_name(offer_->goods):kind_==MammothFair?"mammoths":kind_==SlaveMarket?"slaves":offer_->spy?"spies":"soldiers";
            lines[0]=std::string(offer_->mode==Buy?"Buy ":"Sell ")+what+" / "+std::to_string(Trade::price(*offer_))+" each";
            lines[1]="Quantity "+std::to_string(quantity_)+" / total "+std::to_string(Trade::total(*offer_,quantity_))+" lignite";
            lines[2]="Room "+std::to_string(cap.room)+" / aboard "+std::to_string(cap.loaded);
        }
        for(int i=0;i<3;++i) text(lines[i],{4,106.f+i*9,312,9},5,paper);
}
}
