// SPDX-License-Identifier: MIT
// Validation delegates to the source-backed model contracts; this envelope adds
// no trade, repair or UI rules. Floating state uses round-trip decimal precision.
#include "economy_archive.h"
#include <charconv>
#include <iomanip>
#include <limits>
#include <locale>
#include <sstream>

namespace transartica {
namespace {
// Same native input resource policy as core/save.cpp and app/save_archive.cpp.
constexpr std::size_t maximum_bytes=(1024ULL*1024*1024)/64;
bool marker(std::istream& in,const char* expected) {
    std::string text;return bool(in>>text)&&text==expected;
}
bool flag(std::istream& in,bool& value) {
    std::string token;if(!(in>>token)||(token!="0"&&token!="1")) return false;
    value=token=="1";return true;
}
template<class Number> bool number(std::istream& in,Number& value) {
    std::string token;if(!(in>>token)) return false;
    const auto [end,error]=std::from_chars(token.data(),token.data()+token.size(),value);
    return error==std::errc{}&&end==token.data()+token.size();
}
template<class... Numbers> bool numbers(std::istream& in,Numbers&... values) {
    return (number(in,values)&&...);
}
bool text(std::istream& in,std::string& value) {
    in>>std::ws;return in.peek()=='"'&&bool(in>>std::quoted(value));
}
bool read_works(std::istream& in,TrackWorks& work) {
    int kind{},stage{};
    if(!marker(in,"WORK")||!numbers(in,kind,stage,work.cell.x,work.cell.y,work.code,work.used,work.information,work.countdown)) return false;
    work.kind=static_cast<WorkKind>(kind);work.stage=static_cast<WorkStage>(stage);
    return flag(in,work.lacks_rails)&&numbers(in,work.accumulator,work.labour.slaves,work.labour.mammoths,work.labour.cranes,work.labour.ticks);
}
bool read_workshop(std::istream& in,economy::WorkshopState& shop) {
    return marker(in,"SHOP")&&flag(in,shop.visible)&&text(in,shop.title)&&
        numbers(in,shop.selected,shop.action,shop.scroll,shop.moving)&&
        flag(in,shop.confirmation)&&text(in,shop.notice);
}
bool decode(std::istream& in,EconomySnapshot& state) {
    int version{};
    if(!marker(in,"TAECONOMY")||!number(in,version)||version!=1||!marker(in,"RNG")) return false;
    if(!numbers(in,state.random.state,state.random.increment)||!marker(in,"STOCK")) return false;
    for(auto& row:state.trade.stock) for(int& value:row) if(!number(in,value)) return false;
    if(!marker(in,"SPIES")) return false;
    for(int& value:state.trade.spy_slots) if(!number(in,value)) return false;
    if(!read_works(in,state.works)||!read_workshop(in,state.workshop)||!marker(in,"END")) return false;
    in>>std::ws;return in.eof();
}
}
std::string serialize_economy(const EconomySnapshot& state) {
    std::ostringstream out;out.imbue(std::locale::classic());
    out<<std::setprecision(std::numeric_limits<double>::max_digits10);
    out<<"TAECONOMY 1\nRNG "<<state.random.state<<' '<<state.random.increment<<"\nSTOCK\n";
    for(const auto& row:state.trade.stock) {for(int value:row) out<<value<<' ';out<<'\n';}
    out<<"SPIES\n";for(int value:state.trade.spy_slots) out<<value<<' ';out<<'\n';
    const auto& work=state.works;
    out<<"WORK "<<int(work.kind)<<' '<<int(work.stage)<<' '<<work.cell.x<<' '<<work.cell.y<<' '<<work.code<<' '
        <<work.used<<' '<<work.information<<' '<<work.countdown<<' '<<work.lacks_rails<<' '<<work.accumulator<<' '
        <<work.labour.slaves<<' '<<work.labour.mammoths<<' '<<work.labour.cranes<<' '<<work.labour.ticks<<'\n';
    const auto& shop=state.workshop;
    out<<"SHOP "<<shop.visible<<' '<<std::quoted(shop.title)<<' '<<shop.selected<<' '<<shop.action<<' '
        <<shop.scroll<<' '<<shop.moving<<' '<<shop.confirmation<<' '<<std::quoted(shop.notice)<<"\nEND\n";
    return out.str();
}
bool validate_economy(const EconomySnapshot& state,const Session& session,std::string& error) {
    if(!state.trade.valid()) {error="Invalid persisted trade stock or spy slot";return false;}
    if(!state.random.valid()) {error="Invalid persisted game RNG";return false;}
    if(!state.works.valid(session.network)) {error="Invalid persisted track work";return false;}
    auto engine=session.engine;auto wagons=session.wagons;
    economy::Management management(engine,wagons);
    if(!management.valid_workshop(state.workshop)) {error="Invalid persisted workshop selection";return false;}
    error.clear();return true;
}
bool parse_economy(const std::string& source,EconomySnapshot& output,const Session& session,std::string& error) {
    if(source.size()>maximum_bytes) {error="Economy save exceeds native input budget";return false;}
    std::istringstream input(source);input.imbue(std::locale::classic());EconomySnapshot staged;
    if(!decode(input,staged)) {error="Invalid or truncated economy save; current state preserved";return false;}
    if(!validate_economy(staged,session,error)) return false;
    output=std::move(staged);error.clear();return true;
}
}
