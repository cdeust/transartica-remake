// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "combat/outcome.hpp"
namespace transartica::panels {
enum class CombatReportEvent {None,Continue,Options};
class CombatReport {
public:
    explicit CombatReport(Canvas& canvas):canvas_(canvas){}
    void draw(const combat::AutomaticResult&);
    CombatReportEvent handle(const SDL_Event&)const;
private:Canvas&canvas_;
};
}
