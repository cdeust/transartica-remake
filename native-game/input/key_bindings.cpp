// SPDX-License-Identifier: MIT
// Source game/scripts/key_bindings.gd: positive unique physical keys, Escape
// forbidden, failed persistence leaves the live mapping unchanged.
#include "key_bindings.h"
#include "settings_io.h"
#include <algorithm>
#include <fstream>
#include <limits>
#include <locale>
#include <set>
#include <sstream>
namespace transartica::input {
const std::array<CommandInfo,static_cast<std::size_t>(Command::Count)>& commands() {
    static const std::array<CommandInfo,static_cast<std::size_t>(Command::Count)> values{{
        {"lignite","LIGNITE",SDL_SCANCODE_L,SDLK_l},{"anthracite","ANTHRACITE",SDL_SCANCODE_A,SDLK_a},
        {"brake","BRAKE",SDL_SCANCODE_B,SDLK_b},{"pause","PAUSE",SDL_SCANCODE_SPACE,SDLK_SPACE},
        {"help","HELP",SDL_SCANCODE_H,SDLK_h},{"map","MAP",SDL_SCANCODE_M,SDLK_m},
        {"journal","JOURNAL",SDL_SCANCODE_J,SDLK_j},{"regulator_down","REGULATOR -",SDL_SCANCODE_LEFT,SDLK_LEFT},
        {"regulator_up","REGULATOR +",SDL_SCANCODE_RIGHT,SDLK_RIGHT},{"save","SAVE",SDL_SCANCODE_F5,SDLK_F5},
        {"options","OPTIONS",SDL_SCANCODE_F6,SDLK_F6},{"restart","NEW GAME",SDL_SCANCODE_R,SDLK_r}}};
    return values;
}
Keys default_keys() {Keys keys{};for(std::size_t i=0;i<keys.size();++i)keys[i]=commands()[i].physical;return keys;}
bool KeyBindings::valid(const Keys& keys) {
    std::set<SDL_Scancode> seen;
    for(const auto key:keys) if(key<=SDL_SCANCODE_UNKNOWN||key>=SDL_NUM_SCANCODES||key==SDL_SCANCODE_ESCAPE||!seen.insert(key).second)return false;
    return true;
}
namespace {
constexpr std::string_view header="TRANSARTICA_NATIVE_KEYS 1";
std::uintmax_t maximum_bytes() {
    // Bound from this fixed native schema and the maximum decimal int width;
    // no configurable path, unbounded table or guessed resource threshold.
    std::uintmax_t bytes=header.size()+1+std::string_view("END\n").size();
    for(const auto& info:commands())bytes+=info.name.size()+1+std::numeric_limits<int>::digits10+2+1;
    return bytes;
}
bool parse(std::istream& in,Keys& keys) {
    std::string line;if(!std::getline(in,line)||line!=header)return false;
    keys=default_keys();std::set<std::string> seen;std::string name;
    while(in>>name) {
        if(name=="END") {in>>std::ws;return in.eof()&&KeyBindings::valid(keys);}
        const auto found=std::find_if(commands().begin(),commands().end(),[&](const auto& info){return info.name==name;});
        int code{};if(found==commands().end()||!seen.insert(name).second||!(in>>code))return false;
        keys[std::size_t(found-commands().begin())]=static_cast<SDL_Scancode>(code);
    }
    return false;
}
}
bool KeyBindings::load_settings(std::string& error) {
    std::error_code ec;
    if(!std::filesystem::exists(path(),ec)&&!ec) {error.clear();return false;}
    const auto bytes=std::filesystem::file_size(path(),ec);
    if(ec||bytes>maximum_bytes()) {error="Invalid keyboard preferences size";return false;}
    std::ifstream in(path(),std::ios::binary);in.imbue(std::locale::classic());Keys candidate;
    if(!in||!parse(in,candidate)) {error="Invalid native keyboard preferences; current shortcuts preserved";return false;}
    keys_=candidate;error.clear();return true;
}
bool KeyBindings::save(const Keys& candidate,std::string& error) {
    if(directory_.empty()||!valid(candidate)) {error="Invalid keyboard preferences";return false;}
    std::ostringstream out;out.imbue(std::locale::classic());out<<header<<'\n';
    for(std::size_t i=0;i<candidate.size();++i)out<<commands()[i].name<<' '<<int(candidate[i])<<'\n';out<<"END\n";
    if(!replace_preferences(path(),out.str(),error)) return false;
    keys_=candidate;error.clear();return true;
}
bool KeyBindings::assign(Command command,SDL_Scancode code,std::string& error) {
    auto candidate=keys_;const auto index=static_cast<std::size_t>(command);
    if(index>=candidate.size()) {error="Unknown keyboard command";return false;}
    candidate[index]=code;return save(candidate,error);
}
bool KeyBindings::defaults(std::string& error) {return save(default_keys(),error);}
SDL_KeyboardEvent KeyBindings::canonical(const SDL_KeyboardEvent& event) const {
    auto result=event;const auto physical=event.keysym.scancode;
    if(std::find_if(commands().begin(),commands().end(),[&](const auto& info){return info.physical==physical;})!=commands().end()) {
        result.keysym.scancode=SDL_SCANCODE_UNKNOWN;result.keysym.sym=SDLK_UNKNOWN;
    }
    for(std::size_t i=0;i<keys_.size();++i)if(physical==keys_[i]) {
        result.keysym.scancode=commands()[i].physical;result.keysym.sym=commands()[i].canonical;break;
    }
    return result;
}
SDL_Scancode KeyBindings::key(Command command) const {return keys_.at(static_cast<std::size_t>(command));}
std::string KeyBindings::key_label(Command command) const {return SDL_GetScancodeName(key(command));}
}
