// SPDX-License-Identifier: MIT
// TEXTEK4b13..4bd5 and scripts/combat_report.gd. Full-screen source report.
#include "combat_report.h"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>
namespace transartica::panels {
void CombatReport::draw(const combat::AutomaticResult&r){auto*renderer=canvas_.renderer();SDL_SetRenderDrawColor(renderer,8,19,26,255);render_check(SDL_RenderClear(renderer),"Combat report background");const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f),left=(canvas_.width()-320*scale)/2,top=(canvas_.height()-200*scale)/2;const SDL_Color gold{238,202,136,255};auto centered=[&](float y,const std::string&text){const int size=std::max(1,int(std::round(6*scale)));const auto extent=canvas_.measure(text,size);canvas_.text(text,left+(320*scale-extent.x)/2,top+(y-6)*scale,size,gold);};centered(17,"TRAIN COMBAT");centered(34,r.won?"VICTORY":"TRANSARCTICA HAS BEEN DEFEATED");if(r.won){centered(64,std::to_string(r.soldiers_lost)+" SOLDIER(S) KILLED");centered(79,std::to_string(r.mammoths_lost)+" MAMMOTH(S) KILLED");}centered(154,"PRESS RETURN");}
CombatReportEvent CombatReport::handle(const SDL_Event&e)const{if(e.type!=SDL_KEYDOWN||e.key.repeat)return CombatReportEvent::None;if(e.key.keysym.sym==SDLK_F6)return CombatReportEvent::Options;if(e.key.keysym.sym==SDLK_RETURN||e.key.keysym.sym==SDLK_SPACE)return CombatReportEvent::Continue;return CombatReportEvent::None;}
}
