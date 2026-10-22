// SPDX-License-Identifier: MIT
// SDL laboratory probe. A bounded presentation/input fixture is not campaign proof.
#include "screens/tactical_screen.h"
#include "screens/combat_report.h"
#include "screens/tactical_living.hpp"
#include "core/session.hpp"
#include <SDL.h>
#include <filesystem>
#include <iostream>
#include <stdexcept>
using namespace transartica;
int main(int argc,char**argv){if(argc!=3)return 2;const std::filesystem::path root=argv[1],evidence=argv[2];int checks=0;auto check=[&](bool value,const char*label){++checks;if(!value)throw std::runtime_error(label);};SDL_Window*window=nullptr;SDL_Renderer*renderer=nullptr;
 try{check(SDL_Init(SDL_INIT_VIDEO)==0,"SDL video init");window=SDL_CreateWindow("Transartica tactical laboratory",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,1280,800,SDL_WINDOW_HIDDEN);check(window,"SDL window");renderer=SDL_CreateRenderer(window,-1,SDL_RENDERER_SOFTWARE);check(renderer,"SDL renderer");{
 Canvas canvas(renderer,root/"native-game/assets/fonts/NotoSans.ttf");panels::TacticalScreen screen(canvas,root/"game/assets");combat::Tactical battle;Random rng;rng.seed(17);auto wagons=initial_wagons();wagons.push_back({11,0,0,0});wagons.push_back({12,0,0,0});check(battle.begin(wagons,21,rng),"source battle begins");screen.open(battle);screen.draw(battle);SDL_RenderPresent(renderer);std::filesystem::create_directories(evidence);canvas.capture(evidence/"tactical-initial.png");
 // tactical_effects_geometry.gd::wagon_at selects the nearest real wagon even outside its hull.
 const auto before_click=battle.snapshot();SDL_Event click{};click.type=SDL_MOUSEBUTTONDOWN;click.button.button=SDL_BUTTON_LEFT;click.button.x=1;click.button.y=200;
 check(screen.handle(click,battle)==panels::TacticalEvent::None&&screen.selected_wagon()>=0&&screen.selected_wagon()<int(battle.snapshot().trains[0].size()),"wagon band selects nearest real wagon");
 check(battle.snapshot()==before_click,"wagon selection preserves simulation and RNG");
 SDL_Event key{};key.type=SDL_KEYDOWN;key.key.keysym.sym=SDLK_p;screen.handle(key,battle);check(screen.paused(),"P active pause");key.key.keysym.sym=SDLK_F5;check(screen.handle(key,battle)==panels::TacticalEvent::Save,"F5 save routed");key.key.keysym.sym=SDLK_F6;check(screen.handle(key,battle)==panels::TacticalEvent::Options,"F6 options routed");screen.set_paused(false);
 auto state=battle.snapshot();state.actors.clear();state.next_id=0;state.scan=0;state.sweep=0;state.ai_wait=100;state.aggressiveness=0;state.army_strength={20,20};for(auto&side:state.trains)for(auto&car:side){if(car.kind==combat::Barracks||car.kind==combat::Livestock)car.quantity=0;}state.trains[0][6]={combat::Barracks,20,3,0};state.trains[1].back()={combat::Barracks,20,3,0};state.initial_pools={20,1,2};state.survivors={20,1,0};check(battle.restore(state),"controlled source field fixture");const int infantry=battle.add_actor(0,20,6,10,false);const int mammoth=battle.add_actor(0,24,5,3,true);check(battle.command(infantry,0)&&battle.command(mammoth,0),"troop and mammoth orders");
 for(int frame=0;frame<120;++frame){const auto events=battle.advance(1./60*2);screen.advance_visual(1./60,battle,events);if(frame==50){auto damage=battle.snapshot();damage.trains[0].back().health=1;check(battle.restore(damage),"damage presentation fixture");}screen.draw(battle);SDL_RenderPresent(renderer);}canvas.capture(evidence/"tactical-orders.png");
 panels::LivingEffects effects(root/"game/assets");effects.add("destroy",{160,100},{0,-1});effects.advance(.2);SDL_SetRenderDrawBlendMode(renderer,SDL_BLENDMODE_BLEND);effects.draw(canvas);SDL_BlendMode mode;SDL_GetRenderDrawBlendMode(renderer,&mode);check(mode==SDL_BLENDMODE_BLEND,"effects restore renderer blend state");check(effects.particle_count()<=2048,"source sparse particle bound");effects.draw_world(canvas,{320,200},2);SDL_GetRenderDrawBlendMode(renderer,&mode);check(mode==SDL_BLENDMODE_BLEND,"world effects preserve blend state");SDL_RenderPresent(renderer);canvas.capture(evidence/"tactical-effects.png");effects.advance(10);check(effects.particle_count()==0,"visual transient resources expire");
 combat::AutomaticResult victory;victory.won=true;victory.soldiers_lost=3;panels::CombatReport report(canvas);report.draw(victory);SDL_RenderPresent(renderer);canvas.capture(evidence/"combat-report.png");key.key.keysym.sym=SDLK_RETURN;check(report.handle(key)==panels::CombatReportEvent::Continue,"report return routed");
 }SDL_DestroyRenderer(renderer);SDL_DestroyWindow(window);SDL_Quit();std::cout<<"tactical_render: "<<checks<<" checks, 0 failures\n";return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<'\n';if(renderer)SDL_DestroyRenderer(renderer);if(window)SDL_DestroyWindow(window);SDL_Quit();return 1;}}
