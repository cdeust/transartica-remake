// SPDX-License-Identifier: MIT
// Source key_bindings.gd: physical remapping, uniqueness, former keys inert,
// defaults, missing preferences fallback and no mutation on save failure.
#include "input/key_bindings.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
using namespace transartica::input;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label){++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
std::string read(const std::filesystem::path& path){std::ifstream in(path,std::ios::binary);return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};}
void put(const std::filesystem::path& path,const std::string& text){std::ofstream out(path,std::ios::binary|std::ios::trunc);out<<text;out.close();if(out.fail())throw std::runtime_error("Cannot write preference fixture");}
struct Scratch {
    std::filesystem::path path;
    explicit Scratch(const std::filesystem::path& parent):path(parent/"native-key-bindings-tests") {
        if(!std::filesystem::create_directory(path))throw std::runtime_error("Existing scratch preserved: "+path.string());
    }
    ~Scratch(){std::error_code ec;for(const auto* name:{"keyboard.cfg","keyboard.cfg.pending/owner"})std::filesystem::remove(path/name,ec);std::filesystem::remove(path/"keyboard.cfg.pending",ec);std::filesystem::remove(path,ec);}
};
SDL_KeyboardEvent event(SDL_Scancode physical,SDL_Keycode key) {
    SDL_KeyboardEvent event{};event.type=SDL_KEYDOWN;event.state=SDL_PRESSED;event.keysym.scancode=physical;event.keysym.sym=key;event.keysym.mod=KMOD_SHIFT;return event;
}
void mapping(const std::filesystem::path& directory) {
    KeyBindings bindings(directory);std::string error;
    check(bindings.keys()==default_keys()&&!bindings.load_settings(error)&&error.empty(),"missing config quietly preserves twelve source defaults");
    check(bindings.assign(Command::Lignite,SDL_SCANCODE_P,error),"assign persists an unused physical key");
    const auto mapped=bindings.canonical(event(SDL_SCANCODE_P,SDLK_p));
    check(mapped.keysym.scancode==SDL_SCANCODE_L&&mapped.keysym.sym==SDLK_l&&mapped.keysym.mod==KMOD_SHIFT,"canonical copy changes physical command and preserves modifiers");
    check(bindings.canonical(event(SDL_SCANCODE_L,SDLK_l)).keysym.sym==SDLK_UNKNOWN,"former unbound default cannot retain second shortcut");
    check(bindings.canonical(event(SDL_SCANCODE_Q,SDLK_q)).keysym.sym==SDLK_q,"unrelated contextual key remains unchanged");
    const auto before=bindings.keys();const auto file=read(bindings.path());
    check(!bindings.assign(Command::Anthracite,SDL_SCANCODE_P,error)&&bindings.keys()==before&&read(bindings.path())==file,"duplicate key refuses memory/file mutation");
    check(!bindings.assign(Command::Help,SDL_SCANCODE_ESCAPE,error)&&bindings.keys()==before,"Escape cannot be captured");
    check(!bindings.assign(Command::Help,SDL_SCANCODE_UNKNOWN,error)&&!bindings.assign(Command::Help,SDL_Scancode(SDL_NUM_SCANCODES),error),"unsupported physical representations refused");
    check(bindings.assign(Command::Save,SDL_SCANCODE_F1,error)&&bindings.canonical(event(SDL_SCANCODE_F1,SDLK_F1)).keysym.sym==SDLK_F5,"F1 may be explicitly remapped without owner help alias stealing it");
    KeyBindings restored(directory);check(restored.load_settings(error)&&restored.keys()==bindings.keys(),"native preference roundtrip exact");
    const auto stable=bindings.keys();const auto stable_file=read(bindings.path());const auto pending=directory/"keyboard.cfg.pending";
    if(!std::filesystem::create_directory(pending))throw std::runtime_error("Cannot stage existing writer claim");put(pending/"owner","another writer");
    check(!bindings.assign(Command::Help,SDL_SCANCODE_F2,error)&&bindings.keys()==stable&&read(bindings.path())==stable_file&&read(pending/"owner")=="another writer","atomic writer claim collision preserves mapping and other owner");
    std::filesystem::remove(pending/"owner");std::filesystem::remove(pending);
    check(bindings.defaults(error)&&bindings.keys()==default_keys()&&!std::filesystem::exists(pending),"defaults persist atomically and remove owned staging");
    check(restored.load_settings(error)&&restored.keys()==default_keys(),"restored defaults survive reload");
}
void malformed(const std::filesystem::path& directory) {
    KeyBindings bindings(directory);std::string error;
    check(bindings.assign(Command::Help,SDL_SCANCODE_F1,error),"stage persisted alternate help key");const auto before=bindings.keys();
    for(const auto& text:{std::string("TRANSARTICA_NATIVE_KEYS 2\nEND\n"),std::string("[keys]\nhelp=72\n"),
        std::string("TRANSARTICA_NATIVE_KEYS 1\nhelp 0\nEND\n"),"TRANSARTICA_NATIVE_KEYS 1\nhelp "+std::to_string(SDL_SCANCODE_ESCAPE)+"\nEND\n",
        "TRANSARTICA_NATIVE_KEYS 1\nhelp "+std::to_string(SDL_SCANCODE_F1)+"\nhelp "+std::to_string(SDL_SCANCODE_F2)+"\nEND\n","TRANSARTICA_NATIVE_KEYS 1\nhelp "+std::to_string(SDL_SCANCODE_F1)+"\n"}) {
        put(bindings.path(),text);check(!bindings.load_settings(error)&&!error.empty()&&bindings.keys()==before,"bad/versioned/duplicate/truncated preference preserves live mapping");
    }
    put(bindings.path(),"TRANSARTICA_NATIVE_KEYS 1\nhelp "+std::to_string(SDL_SCANCODE_F1)+"\nEND\n");
    check(bindings.load_settings(error)&&bindings.key(Command::Help)==SDL_SCANCODE_F1&&bindings.key(Command::Brake)==SDL_SCANCODE_B,"missing command fields inherit source defaults");
}
}
int main(int argc,char** argv) {
    if(argc!=2){std::cerr<<"usage: key_bindings_tests <existing-scratch-parent>\n";return 2;}
    try{Scratch scratch(argv[1]);mapping(scratch.path);malformed(scratch.path);std::cout<<checks<<" key binding checks, "<<failures<<" failures\n";return failures?1:0;}
    catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
