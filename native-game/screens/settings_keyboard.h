// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "input/key_bindings.h"
#include <optional>
namespace transartica::panels {
class KeyboardSettings {
public:
    KeyboardSettings(Canvas&,std::filesystem::path assets,input::KeyBindings&);
    void open();void close() {active_=false;selected_.reset();}
    bool active() const {return active_;}
    bool handle(const SDL_Event&);
    void draw();
    void draw_badge(); // Host only on OPTIONS, while the load book is hidden.
    bool badge_hit(float x,float y) const;
    std::optional<input::Command> selected() const {return selected_;}
    const std::string& notice() const {return notice_;}
private:
    Canvas& canvas_;std::filesystem::path assets_;input::KeyBindings& bindings_;
    bool active_{};std::optional<input::Command> selected_;std::string notice_;
    SDL_FRect frame() const;
    SDL_FPoint logical(float,float) const;
    static SDL_FRect row(std::size_t);
    void text(float,float,std::string_view,int size=7);
    void centered(float,std::string_view,int size=7);
};
}
