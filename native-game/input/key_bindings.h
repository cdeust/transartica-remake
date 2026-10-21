// SPDX-License-Identifier: MIT
#pragma once
#include <SDL.h>
#include <array>
#include <filesystem>
#include <string>
#include <string_view>
#include <utility>
namespace transartica::input {
// Exact insertion order/defaults from game/scripts/key_bindings.gd DEFAULTS.
enum class Command {Lignite,Anthracite,Brake,Pause,Help,Map,Journal,RegulatorDown,RegulatorUp,Save,Options,Restart,Count};
struct CommandInfo {std::string_view name,label;SDL_Scancode physical;SDL_Keycode canonical;};
using Keys=std::array<SDL_Scancode,static_cast<std::size_t>(Command::Count)>;
const std::array<CommandInfo,static_cast<std::size_t>(Command::Count)>& commands();
Keys default_keys();
class KeyBindings {
public:
    explicit KeyBindings(std::filesystem::path save_directory):directory_(std::move(save_directory)),keys_(default_keys()){}
    bool load_settings(std::string& error); // Missing file leaves defaults quietly.
    bool assign(Command,SDL_Scancode,std::string& error);
    bool defaults(std::string& error);
    static bool valid(const Keys&);
    SDL_KeyboardEvent canonical(const SDL_KeyboardEvent&) const;
    SDL_Scancode key(Command) const;
    std::string key_label(Command) const;
    const Keys& keys() const {return keys_;}
    std::filesystem::path path() const {return directory_/"keyboard.cfg";}
private:
    std::filesystem::path directory_;
    Keys keys_;
    bool save(const Keys&,std::string& error);
};
}
