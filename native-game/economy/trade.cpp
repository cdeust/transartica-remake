// SPDX-License-Identifier: MIT
#include "trade.hpp"
#include <json-c/json.h>
#include <algorithm>
#include <charconv>
#include <cmath>
#include <limits>
#include <memory>
#include <stdexcept>

namespace transartica::economy {
namespace {
using Json=std::unique_ptr<json_object,decltype(&json_object_put)>;
json_object* member(json_object* o,const char* key) {
    json_object* value=nullptr;
    if(!o || !json_object_object_get_ex(o,key,&value)) throw std::runtime_error(std::string("Missing commerce field: ")+key);
    return value;
}
void array_size(json_object* o,std::size_t n) {
    if(!o || !json_object_is_type(o,json_type_array) || json_object_array_length(o)!=n)
        throw std::runtime_error("Invalid commerce array dimensions");
}
int number(json_object* o) {
    if(!o || !(json_object_is_type(o,json_type_int)||json_object_is_type(o,json_type_double)))
        throw std::runtime_error("Invalid commerce integer");
    double n=json_object_get_double(o);
    if(!std::isfinite(n)||std::floor(n)!=n||n<std::numeric_limits<int>::min()||n>std::numeric_limits<int>::max())
        throw std::runtime_error("Invalid commerce integer range");
    return int(n);
}
int key_number(const char* key) {
    std::string_view s(key); int value{};
    auto r=std::from_chars(s.data(),s.data()+s.size(),value);
    if(r.ec!=std::errc{}||r.ptr!=s.data()+s.size()||value<0||value>=46) throw std::runtime_error("Invalid commerce city index");
    return value;
}
Offer read_offer(json_object* o) {
    Offer result;
    result.buy=number(member(o,"buy")); result.sell=number(member(o,"sell"));
    result.wagon_a=number(member(o,"wagon_a")); result.wagon_b=number(member(o,"wagon_b"));
    result.cap_a=number(member(o,"cap_a")); result.cap_b=number(member(o,"cap_b"));
    if(result.buy<0||result.sell<0||result.cap_a<0||result.cap_b<0||result.wagon_a<1||result.wagon_a>25||result.wagon_b<1||result.wagon_b>25)
        throw std::runtime_error("Invalid commerce offer");
    return result;
}
template<class Map> void offers(json_object* root,const char* name,Map& out) {
    auto* table=member(root,name);
    if(!json_object_is_type(table,json_type_object)) throw std::runtime_error("Invalid commerce offer table");
    json_object_object_foreach(table,key,value) { out.emplace(key_number(key),read_offer(value)); }
}
bool stock_city(int city) { return city>=24 && city<46; }
template<std::size_t N> std::array<std::string,N> names(json_object* root,const char* key) {
    auto* list=member(root,key); array_size(list,N); std::array<std::string,N> result;
    for(std::size_t i=0;i<N;++i) {
        auto* value=json_object_array_get_idx(list,i);
        if(!json_object_is_type(value,json_type_string)) throw std::runtime_error("Invalid commerce name");
        result[i]=json_object_get_string(value);
    }
    return result;
}
}
bool TradeState::valid() const {
    for(const auto& row:stock) for(int value:row) if(value< -128||value>127) return false;
    for(int value:spy_slots) if(value<0||value>3) return false;
    return true;
}
bool Trade::load(const std::filesystem::path& directory,std::string& error) {
    try {
        Json root(json_object_from_file((directory/"commerce.json").string().c_str()),json_object_put);
        if(!root || !json_object_is_type(root.get(),json_type_object)) throw std::runtime_error("Cannot read commerce.json");
        Trade staged;
        staged.goods_names_=names<16>(root.get(),"goods_names");
        staged.wagon_names_=names<25>(root.get(),"wagon_names");
        auto* stock=member(root.get(),"stock_init"); array_size(stock,22);
        for(int row=0;row<22;++row) {
            auto* cells=json_object_array_get_idx(stock,row); array_size(cells,16);
            for(int col=0;col<16;++col) {
                auto* pair=json_object_array_get_idx(cells,col); array_size(pair,2);
                const int base=number(json_object_array_get_idx(pair,0)),span=number(json_object_array_get_idx(pair,1));
                // The persistent source stock is a signed byte; validate before RNG arithmetic.
                if(base< -128||base>127||span<0||(base>=0&&std::int64_t(base)+std::max(0,span-1)>127)) throw std::runtime_error("Invalid commerce stock initializer");
                staged.stock_init_[row][col]={base,span};
            }
        }
        auto* table=member(root.get(),"goods");
        if(!json_object_is_type(table,json_type_object)) throw std::runtime_error("Invalid goods table");
        json_object_object_foreach(table,key,value) {
            int city=key_number(key); array_size(value,16);
            if(!stock_city(city)) throw std::runtime_error("Invalid trading city");
            std::array<Offer,16> entries;
            for(int i=0;i<16;++i) entries[i]=read_offer(json_object_array_get_idx(value,i));
            staged.goods_.emplace(city,entries);
        }
        offers(root.get(),"mammoths",staged.mammoths_); offers(root.get(),"slaves",staged.slaves_);
        offers(root.get(),"soldiers",staged.soldiers_); offers(root.get(),"spies",staged.spies_);
        auto* workshop=member(root.get(),"workshop");
        if(!json_object_is_type(workshop,json_type_object)) throw std::runtime_error("Invalid workshop table");
        json_object_object_foreach(workshop,city_key,entries) {
            if(!json_object_is_type(entries,json_type_array)) throw std::runtime_error("Invalid workshop list");
            auto& list=staged.workshop_[key_number(city_key)];
            for(std::size_t i=0;i<json_object_array_length(entries);++i) {
                auto* entry=json_object_array_get_idx(entries,i); array_size(entry,2);
                Entry e{number(json_object_array_get_idx(entry,0)),number(json_object_array_get_idx(entry,1))};
                if(e.type<1||e.type>25||e.price<0) throw std::runtime_error("Invalid workshop entry");
                list.push_back(e);
            }
        }
        staged.loaded_=true; *this=std::move(staged); error.clear(); return true;
    } catch(const std::exception& e) { error=e.what(); return false; }
}
void Trade::reset(Random& rng) {
    for(int r=0;r<22;++r) for(int c=0;c<16;++c) {
        auto [base,span]=stock_init_[r][c]; state_.stock[r][c]=base>=0?base+rng.below(span):-1;
    }
    state_.spy_slots.fill(0);
}
void Trade::visit(int city,Random& rng) { if(city==45) state_.stock[21][3]=5+rng.below(40); }
bool Trade::restore(const TradeState& state) { if(!state.valid()) return false; state_=state; return true; }
bool Trade::set_spy_slot(int slot,int state) {
    if(slot<0||slot>=20||state<0||state>3) return false;
    state_.spy_slots[slot]=state; return true;
}
bool Trade::offers_spies(int city) const { return (city==8||city==9)&&std::find(state_.spy_slots.begin(),state_.spy_slots.end(),0)!=state_.spy_slots.end(); }
std::string Trade::goods_name(int goods) const { return goods>=1&&goods<=16?goods_names_[goods-1]:""; }
std::string Trade::wagon_name(int type) const { return type>=1&&type<=25?wagon_names_[type-1]:""; }
std::optional<Offer> Trade::offer(int city,int kind,int mode,int goods) const {
    if(mode!=Buy&&mode!=Sell) return {};
    Offer result;
    if(kind==Commercial) {
        auto it=goods_.find(city); if(goods<1||goods>16||it==goods_.end()) return {};
        result=it->second[goods-1];
    } else {
        const std::map<int,Offer>* table=nullptr;
        if(kind==MammothFair) table=&mammoths_;
        else if(kind==SlaveMarket) table=&slaves_;
        else if(kind==Garrison) table=mode==Buy?&soldiers_:&spies_;
        if(!table) return {};
        auto it=table->find(city); if(it==table->end()) return {};
        result=it->second;
    }
    result.city=city; result.kind=kind; result.mode=kind==Garrison?Buy:mode;
    result.spy=kind==Garrison&&mode==Sell; result.goods=kind==Commercial?goods:0;
    return result;
}
int Trade::price(const Offer& o) { return o.mode==Buy?o.buy:o.sell; }
int Trade::total(const Offer& o,int quantity) { return quantity*price(o); }
std::vector<GoodsRow> Trade::goods_list(int city,int mode,const std::vector<Wagon>& wagons) const {
    std::vector<GoodsRow> result;
    if(mode==Buy) {
        if(!stock_city(city)) return result;
        for(int g=0;g<16;++g) if(state_.stock[city-24][g]>-1) result.push_back({g+1,state_.stock[city-24][g]});
    } else for(const auto& w:wagons) {
        if((w.type!=14&&w.type!=15&&w.type!=17&&w.type!=18&&w.type!=19)||w.goods==0||w.quantity==0) continue;
        auto it=std::find_if(result.begin(),result.end(),[&](const GoodsRow& row){return row.goods==w.goods;});
        if(it!=result.end()) it->quantity+=w.quantity;
        else if(result.size()<16) result.push_back({w.goods,w.quantity});
    }
    return result;
}
bool Trade::accepts(const Offer& o,const Wagon& w,int type) { return w.type==type&&(o.goods==0||w.goods==0||w.goods==o.goods); }
Capacity Trade::capacity(const Offer& o,const std::vector<Wagon>& wagons) const {
    Capacity result;
    for(const auto& w:wagons) {
        if(accepts(o,w,o.wagon_a)) { result.room+=o.cap_a-w.quantity; result.loaded+=w.quantity; }
        else if(accepts(o,w,o.wagon_b)) { result.room+=o.cap_b-w.quantity; result.loaded+=w.quantity; }
    }
    if(o.spy) result.room=std::min(result.room,int(std::count(state_.spy_slots.begin(),state_.spy_slots.end(),0)));
    return result;
}
int Trade::entry_refusal(const Offer& o,const std::vector<Wagon>& wagons) const {
    if(o.goods!=0) return 0;
    auto room=capacity(o,wagons);
    if(room.room==0&&o.mode==Buy) return NoRoom;
    if(room.loaded==0&&o.mode==Sell) return NothingToSell;
    return 0;
}
int Trade::increment_refusal(const Offer& o,int quantity,const std::vector<Wagon>& wagons,const EngineState& engine) const {
    auto room=capacity(o,wagons);
    if(quantity<0) return StockLimit;
    const auto next=std::int64_t(quantity)+1;
    if(o.mode==Buy) {
        if(room.room<next) return NoRoom;
        if(o.goods!=0 && (!stock_city(o.city)||o.goods<1||o.goods>16||next>state_.stock[o.city-24][o.goods-1])) return StockLimit;
        if(engine.lignite<next*o.buy) return NoMoney;
    } else {
        if(next>room.loaded) return NotEnoughLoad;
        std::int64_t coal_room= -std::int64_t(engine.lignite)-engine.anthracite;
        for(const auto& w:wagons) if(w.type==21&&w.state!=3) coal_room+=5000;
        if(next*o.sell>coal_room) return NoCoalRoom;
    }
    return 0;
}
int Trade::commit(const Offer& o,int quantity,std::vector<Wagon>& wagons,EngineState& engine) {
    if(quantity<=0) return 0;
    const auto canonical=offer(o.city,o.kind,o.spy?Sell:o.mode,o.goods);
    if(!canonical || *canonical!=o) return StockLimit;
    int refusal=increment_refusal(o,quantity-1,wagons,engine); if(refusal) return refusal;
    if(o.mode==Buy) engine.lignite-=total(o,quantity);
    else {
        const auto balance=std::int64_t(engine.lignite)+std::int64_t(quantity)*o.sell;
        engine.lignite=balance<0||balance>31000?31000:int(balance);
    }
    if(o.mode==Buy&&o.spy) for(int i=0;i<quantity;++i) *std::find(state_.spy_slots.begin(),state_.spy_slots.end(),0)=1;
    int left=quantity;
    for(auto& w:wagons) {
        if(o.mode==Buy) {
            int limit= -1;
            if(accepts(o,w,o.wagon_a)) limit=o.cap_a;
            else if(accepts(o,w,o.wagon_b)) limit=o.cap_b;
            if(limit<0) continue;
            const int moved=std::min(left,std::max(0,limit-w.quantity)); w.quantity+=moved; left-=moved;
            if(o.goods!=0&&moved>0) { state_.stock[o.city-24][o.goods-1]-=moved; w.goods=o.goods; }
        } else {
            if((w.type!=o.wagon_a&&w.type!=o.wagon_b)||(o.goods!=0&&w.goods!=o.goods)) continue;
            const int moved=std::min(left,w.quantity); w.quantity-=moved; left-=moved;
            if(o.goods!=0) {
                auto& value=state_.stock[o.city-24][o.goods-1];
                // GLIEU signed byte: after127->-128, subsequent units are not stocked.
                for(int i=0;i<moved && value>-1;++i) value=value<127?value+1:-128;
            }
            if(w.quantity==0) w.goods=0;
        }
        if(left==0) break;
    }
    return 0;
}
std::vector<Entry> Trade::workshop_list(int city) const { auto it=workshop_.find(city); return it==workshop_.end()?std::vector<Entry>{}:it->second; }
int Trade::intact_tenders(const std::vector<Wagon>& wagons) { return int(std::count_if(wagons.begin(),wagons.end(),[](const Wagon& w){return w.type==21&&w.state!=3;})); }
int Trade::workshop_refusal(Entry entry,int quantity,const std::vector<Wagon>& wagons,const EngineState& engine) {
    // GLIEU0x2137 checks current quantity + count >99 before increment. It allows100.
    if(std::int64_t(quantity)+std::int64_t(wagons.size())>99) return WagonsFull;
    if(entry.type==21 && intact_tenders(wagons)+quantity>=6) return TenderLimit;
    if(engine.lignite<(std::int64_t(quantity)+1)*entry.price) return NoMoney;
    return 0;
}
int Trade::buy_wagons(Entry entry,int quantity,std::vector<Wagon>& wagons,EngineState& engine) {
    if(quantity<=0) return 0;
    if(entry.type<1||entry.type>25||entry.price<0) return StockLimit;
    int refusal=workshop_refusal(entry,quantity-1,wagons,engine); if(refusal) return refusal;
    // Allocate before debit so a failed allocation cannot charge an unchanged train.
    wagons.reserve(wagons.size()+std::size_t(quantity));
    engine.lignite-=quantity*entry.price;
    for(int i=0;i<quantity;++i) wagons.push_back({entry.type,0,0,0});
    return 0;
}
}
