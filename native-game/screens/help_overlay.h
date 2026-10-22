// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "input/key_bindings.h"
namespace transartica::panels {
// Source engine_room_controls.gd owns help, not a separate story/help session.
// Host blocks simulation while active and draws this over the cabin last.
class HelpOverlay {
public:
    HelpOverlay(Canvas& canvas,const input::KeyBindings& bindings):canvas_(canvas),bindings_(bindings){}
    bool active() const {return active_;}
    void toggle() {active_=!active_;}
    void open() {active_=true;}
    void close() {active_=false;}
    bool handle(const SDL_Event&); // Any pointer press/Esc/help closes; other keys pass.
    void draw();
private:
    Canvas& canvas_;const input::KeyBindings& bindings_;bool active_{};
};
}
