// SPDX-License-Identifier: MIT
// Source: gameplay_input.gd, boudoir_session.gd, original_panel.gd, session_saves.gd.
#include "session_ui.h"
#include "game_archive.h"
#include <utility>

namespace transartica {
SessionUI::SessionUI(Canvas& canvas, View& view, GameSession& game, audio::GameAudio& audio, const std::filesystem::path& assets,
                     const std::filesystem::path& saves, std::function<void(std::string_view)> log)
    : view_(view), canvas_(canvas), game_(game), audio_(audio), state_(game.core), panels_(canvas,assets,&game.trade), book_(canvas,assets),
      city_(canvas,assets,game.trade,game.data,state_.engine,state_.wagons), works_(canvas,assets),
      campaign_(canvas,assets,game.campaign),tactical_(canvas,assets),report_(canvas),world_events_(canvas,assets),captain_(canvas,assets),
      launcher_(canvas,assets,state_,game.launcher,*this,game.campaign.data()),
      bindings_(saves.empty()?std::filesystem::current_path():saves),keyboard_(canvas,assets,bindings_),help_(canvas,bindings_),
      startup_(canvas,assets.parent_path()),
      save_directory_(saves.empty()?std::filesystem::current_path():saves), log_(std::move(log)) {
    std::string error;if(!bindings_.load_settings(error)&&!error.empty()) announce(error);
    view_.set_bindings(&bindings_);
    startup_.start();state_.paused=true; // main.tscn/game_boot.gd production introduction.
}
bool SessionUI::halted() const { return game_.blocks_simulation() || state_.engine.event_pending; }
bool SessionUI::footer_visible() const {
    return screen_ != Screen::Reception && screen_ != Screen::Inventory && screen_ != Screen::Instruments;
}
panels::Screen SessionUI::panel_screen() const {
    switch(screen_) {
    case Screen::Boudoir: return panels::Screen::Boudoir;
    case Screen::Quarters: return panels::Screen::Quarters;
    case Screen::Instruments: return panels::Screen::Instruments;
    case Screen::Overview: return panels::Screen::Overview;
    default: return panels::Screen::Inventory;
    }
}
void SessionUI::announce(std::string value) {
    notice_ = std::move(value); notice_seconds_ = 4; // engine_room_controls.gd announce duration.
}
void SessionUI::command(Action action,float x,float y) {
    if(action==Action::Map||action==Action::DetailedMap||action==Action::Overview||action==Action::Boudoir||action==Action::Quarters||action==Action::Instruments) help_.close();
    if(halted() && (action==Action::Pause || action==Action::Brake || action==Action::Lignite ||
                   action==Action::Anthracite || action==Action::Regulator)) return;
    switch(action) {
    case Action::Start: game_.reset(); city_.close(); city_suspended_=false; audio_.new_game_reset(); audio_.play_journey(); screen_=Screen::Cabin; options_open_=false; options_return_=Screen::Cabin; view_.reset_camera(); view_.reset_cabin(); help_.close(); notice_.clear(); discard_elapsed_=true; break;
    case Action::Load: open_book(true); break;
    case Action::Music:audio_.toggle_original_music();break;
    case Action::Difficulty:game_.difficulty=(game_.difficulty+1)%5;break;
    case Action::Combat:game_.automatic=!game_.automatic;break;
    case Action::Lignite: state_.engine.cycle_lignite(); break;
    case Action::Anthracite: state_.engine.cycle_anthracite(); break;
    case Action::Regulator: dragging_=true; state_.engine.set_regulator(view_.regulator_at(x,y)); break;
    case Action::Pause: state_.paused=!state_.paused; discard_elapsed_=true; break;
    case Action::Map:
        screen_=screen_==Screen::World?Screen::Cabin:Screen::World;
        if(screen_==Screen::Cabin) game_.launcher.resume(); else game_.launcher.hide();
        break;
    case Action::DetailedMap: game_.launcher.hide(); screen_=Screen::World; view_.center_on_train(state_); break;
    case Action::Overview:
        game_.launcher.hide(); // boudoir_session.gd::leave preserves a suspended model.
        if(screen_==Screen::Overview) screen_=overview_return_;
        else { overview_return_=screen_; screen_=Screen::Overview; }
        if(screen_==Screen::Cabin) game_.launcher.resume();
        break;
    case Action::Engine: screen_=Screen::Cabin; game_.launcher.resume(); break;
    case Action::Quarters: game_.launcher.hide(); screen_=Screen::Quarters; break;
    case Action::Boudoir: game_.launcher.hide(); screen_=Screen::Boudoir; break;
    case Action::Instruments: game_.launcher.hide(); screen_=Screen::Instruments; break;
    case Action::Clock: state_.calendar.toggle_factor(); discard_elapsed_=true; break;
    case Action::Brake: state_.engine.toggle_brake(); break;
    case Action::PreviousWagon: view_.scroll_composition(-1,state_); break;
    case Action::NextWagon: view_.scroll_composition(1,state_); break;
    case Action::Launcher: {
        const auto result=game_.launcher.open();
        if(result==launcher::OpenResult::NoMissiles) game_.works.inform(15); // panel_hotspots.gd NO_MISSILES_TEXTEK.
        break;
    }
    case Action::Reverse:
        if(city_suspended_) break; // boudoir_session.gd _reverse_train.
        if(state_.journey.at_station()&&state_.journey.station_result(state_.network)==-1) {
            const bool paused=state_.paused;game_.depart();state_.paused=paused;
        } else if(state_.reverse()) game_.cargo_changed();
        break;
    case Action::Unavailable: announce("This campaign action is not yet ported."); break;
    case Action::None: return;
    }
    log_("input");
}
void SessionUI::open_book(bool loading) {
    help_.close();
    if(!loading) screen_=Screen::Boudoir;
    book_.open(loading); discard_elapsed_=true; dragging_=false;
}
PresentationState SessionUI::presentation_snapshot() const {
    PresentationState result{int(screen_),int(overview_return_),int(options_return_),options_open_,city_suspended_,visual_time_,captain_.snapshot(),city_.workshop_snapshot(),view_.snapshot_world()};
    return result;
}
void SessionUI::quick_save() {
    // gameplay_input.gd/main.gd::_save_view: F5 saves without a name dialog.
    // Native slot name fits the existing eight-character book contract.
    std::error_code ec;std::filesystem::create_directories(save_directory_,ec);
    std::string error=ec.message();
    const bool saved=!ec&&save_game(save_directory_/"SESSION.native",game_,audio_,presentation_snapshot(),error);
    announce(saved?"SESSION SAVED":error);log_(saved?"save":"file-failed");
}
void SessionUI::submit_book(const std::string& name) {
    // Names are normalized by the source eight-letter/digit slot contract.
    const auto target=save_directory_/(panels::SaveBook::normalize(name)+".native");
    std::string error;
    bool success=false;
    auto presentation=presentation_snapshot();
    if(book_.loading()) success=load_game(target,game_,audio_,presentation,error);
    else {
        std::error_code ec;
        std::filesystem::create_directories(save_directory_,ec);
        if(ec) error=ec.message(); else success=save_game(target,game_,audio_,presentation,error);
    }
    if(!success) { book_.status(error); log_("file-failed"); return; }
    if(book_.loading()) {
        screen_=Screen(presentation.screen);overview_return_=Screen(presentation.overview_return);options_return_=Screen(presentation.options_return);
        options_open_=presentation.options_open;city_suspended_=presentation.city_suspended;visual_time_=presentation.visual_time;
        captain_.restore(presentation.captain);city_.close();tactical_open_=false;
        if(game_.tactical) {
            // tactical_scene.gd resumes a saved model without restarting its entry audio.
            tactical_.open(*game_.tactical);tactical_.set_paused(game_.manual_paused);tactical_open_=true;
        }
        if(game_.workshop) city_.restore_workshop(presentation.workshop);
        sync_models();view_.restore_world(presentation.world_view,state_,game_.data.cities().size());view_.reset_cabin();
    }
    const bool loaded=book_.loading(); book_.close(); discard_elapsed_=true;
    announce(loaded?"SAVE RESTORED":"SAVED"); log_(loaded?"load":"save");
}
void SessionUI::panel_command(panels::Action action,float x,float y) {
    switch(action) {
    case panels::Action::Cabin: command(Action::Engine); break;
    case panels::Action::World: command(Action::DetailedMap); break;
    case panels::Action::Overview: command(Action::Overview); break;
    case panels::Action::Inventory:
        if(screen_==Screen::Inventory) { if(!panels_.next_inventory(state_)) screen_=Screen::Boudoir; }
        else { panels_.reset_inventory(); screen_=Screen::Inventory; }
        discard_elapsed_=true; break;
    case panels::Action::Save: open_book(false); break;
    case panels::Action::Stoup:game_.campaign.read_stoup(screen_==Screen::Boudoir?campaign::Room::Boudoir:campaign::Room::Quarters);break;
    case panels::Action::Spies:game_.campaign.open_spy_menu();break;
    case panels::Action::Cars:game_.campaign.open_car_menu();break;
    case panels::Action::Revolver:captain_.prompt_revolver();break;
    case panels::Action::Regulator:
        if(!halted()) { dragging_=true; state_.engine.set_regulator(panels_.regulator_at(x,y)); }
        break;
    case panels::Action::Unavailable: command(Action::Unavailable); break;
    case panels::Action::None: break;
    }
}
void SessionUI::click(float x,float y) {
    if(screen_==Screen::Reception&&keyboard_.badge_hit(x,y)) {keyboard_.open();discard_elapsed_=true;return;}
    if(footer_visible() && view_.in_footer(x,y)) {
        const auto action=view_.footer_action(x,y,screen_==Screen::World || screen_==Screen::Overview);
        if(action!=Action::None) audio_.son(3);
        command(action,x,y); return;
    }
    switch(screen_) {
    case Screen::Reception: command(view_.reception_action(x,y),x,y); break;
    case Screen::Cabin: command(view_.cabin_action(x,y),x,y); break;
    case Screen::World: {
        const auto cell=view_.world_cell(x,y);
        if(cell && game_.campaign.select_map_cell(*cell)) process_actions();
        else if(cell && state_.toggle_switch(*cell)) { announce("SWITCH CHANGED"); log_("switch"); }
        break;
    }
    case Screen::Overview:
        if(const auto cell=panels_.overview_cell(x,y)) {
            if(!game_.campaign.select_map_cell(*cell)) {
                screen_=Screen::World;view_.inspect_world(*cell);captain_.inform(game_.campaign.data().message(3));
            }
            process_actions();
        }
        break;
    default: panel_command(panels_.action(panel_screen(),x,y),x,y); break;
    }
}
void SessionUI::key(const SDL_KeyboardEvent& event) {
    const auto key=event.keysym.sym;
    if(key==SDLK_F9) { open_book(true); return; }
    if(key==SDLK_ESCAPE && city_suspended_) {city_suspended_=false;return;}
    if(screen_==Screen::Reception) {
        if(key==SDLK_RETURN) command(Action::Start);
        if(key==SDLK_ESCAPE) {
            if(options_open_) { screen_=options_return_; options_open_=false; discard_elapsed_=true; if(screen_==Screen::Cabin) game_.launcher.resume(); }
            // campaign_session.gd:117..120 / reception_screen.gd:64..69:
            // a terminal reception has no live scene to return to. Its self
            // return survives presentation snapshots without a separate flag.
            else if(options_return_!=Screen::Reception) running=false;
        }
        return;
    }
    if(screen_==Screen::Inventory) {
        if(key==SDLK_ESCAPE) { screen_=Screen::Boudoir; discard_elapsed_=true; }
        else if(key==SDLK_SPACE || key==SDLK_RETURN) panel_command(panels::Action::Inventory,0,0);
        return;
    }
    switch(key) {
    case SDLK_F5: if(screen_==Screen::Boudoir)open_book(false);else quick_save(); break;
    case SDLK_F6: help_.close(); options_return_=screen_; screen_=Screen::Reception; options_open_=true; discard_elapsed_=true; break;
    case SDLK_r: command(Action::Start); break;
    case SDLK_l: command(Action::Lignite); break;
    case SDLK_a: command(Action::Anthracite); break;
    case SDLK_b: command(Action::Brake); break;
    case SDLK_SPACE: command(Action::Pause); break;
    case SDLK_m: command(Action::DetailedMap); break;
    case SDLK_j: command(Action::Boudoir); break;
    case SDLK_h: help_.toggle();discard_elapsed_=true;break;
    case SDLK_i: if(screen_==Screen::Boudoir) panel_command(panels::Action::Inventory,0,0); break;
    case SDLK_s: if(screen_==Screen::Boudoir) open_book(false); break;
    case SDLK_ESCAPE:
        if(screen_==Screen::Overview) {screen_=overview_return_;if(screen_==Screen::Cabin) game_.launcher.resume();}
        else if(screen_==Screen::Cabin) command(Action::Pause);
        else command(Action::Engine);
        break;
    case SDLK_RIGHT: case SDLK_LEFT:
        if(!halted()) {
            const int step=(event.keysym.mod&KMOD_SHIFT?1:15)*(key==SDLK_RIGHT?1:-1);
            state_.engine.set_regulator(state_.engine.regulator+step); log_("regulator");
        }
        break;
    default: break;
    }
}
void SessionUI::handle(const SDL_Event& incoming) {
    SDL_Event event=incoming;
    if(event.type==SDL_QUIT) { running=false; return; }
    if(event.type==SDL_MOUSEMOTION) {pointer_={double(event.motion.x),double(event.motion.y)};pointer_inside_=true;}
    if(event.type==SDL_WINDOWEVENT&&(event.window.event==SDL_WINDOWEVENT_LEAVE||event.window.event==SDL_WINDOWEVENT_FOCUS_LOST)) pointer_inside_=false;
    if(startup_.active()) {startup_.handle(event);return;}
    if(keyboard_.active()) {keyboard_.handle(event);discard_elapsed_=true;return;}
    if(event.type==SDL_WINDOWEVENT && event.window.event==SDL_WINDOWEVENT_FOCUS_LOST) {
        state_.paused=true; dragging_=false; discard_elapsed_=true; log_("focus-lost");
    }
    if(event.type==SDL_KEYDOWN && !event.key.repeat) {
        if(event.key.keysym.sym==SDLK_q && (event.key.keysym.mod&(KMOD_CTRL|KMOD_GUI))) { running=false; return; }
        if(event.key.keysym.sym==SDLK_F12&&bindings_.canonical(event.key).keysym.sym==SDLK_F12) { capture=true; return; }
    }
    if(book_.active()) {
        if(const auto submitted=book_.handle_event(event)) submit_book(*submitted);
        if(!book_.active()) discard_elapsed_=true;
        return;
    }
    if(event.type==SDL_KEYDOWN&&event.key.repeat) return; // gameplay_input.gd rejects echoed scene commands.
    if(help_.active()&&help_.handle(event)) {discard_elapsed_=true;return;}
    // gameplay_input.gd:12: only function-key SAVE preempts a scene or quiz.
    const bool key_event=event.type==SDL_KEYDOWN||event.type==SDL_KEYUP;
    const auto mapped=key_event?bindings_.canonical(event.key):SDL_KeyboardEvent{};
    if(event.type==SDL_KEYDOWN&&!event.key.repeat&&mapped.keysym.sym==SDLK_F5
        &&event.key.keysym.scancode>=SDL_SCANCODE_F2&&event.key.keysym.scancode<=SDL_SCANCODE_F12) {
        quick_save();return;
    }
    // gameplay_input.gd:17..20 gives reception its physical keys before
    // gameplay remapping; assigning Enter must not steal the START command.
    if(event.type==SDL_KEYDOWN&&screen_==Screen::Reception) {key(incoming.key);return;}
    if(key_event&&(game_.tactical||game_.launcher.visible())) {
        // gameplay_input.gd::_tactical_key and launcher_session.gd keep each
        // scene's own controls physical, even after gameplay remapping.
        const auto physical=event.key.keysym.scancode;
        bool contextual=physical==SDL_SCANCODE_P||physical==SDL_SCANCODE_ESCAPE||physical==SDL_SCANCODE_RETURN||physical==SDL_SCANCODE_SPACE;
        if(game_.tactical) switch(physical) {
        case SDL_SCANCODE_EQUALS:case SDL_SCANCODE_KP_PLUS:case SDL_SCANCODE_MINUS:case SDL_SCANCODE_KP_MINUS:
        case SDL_SCANCODE_Q:case SDL_SCANCODE_E:case SDL_SCANCODE_LEFT:case SDL_SCANCODE_RIGHT:
        case SDL_SCANCODE_UP:case SDL_SCANCODE_DOWN:case SDL_SCANCODE_S:contextual=true;break;
        default:break;
        }
        if(contextual) switch(physical) {
        // SDL keyboard sym follows layout; source scene controls are physical.
        case SDL_SCANCODE_P:event.key.keysym.sym=SDLK_p;break;
        case SDL_SCANCODE_Q:event.key.keysym.sym=SDLK_q;break;
        case SDL_SCANCODE_E:event.key.keysym.sym=SDLK_e;break;
        case SDL_SCANCODE_S:event.key.keysym.sym=SDLK_s;break;
        case SDL_SCANCODE_EQUALS:event.key.keysym.sym=SDLK_EQUALS;break;
        case SDL_SCANCODE_MINUS:event.key.keysym.sym=SDLK_MINUS;break;
        case SDL_SCANCODE_ESCAPE:event.key.keysym.sym=SDLK_ESCAPE;break;
        case SDL_SCANCODE_RETURN:event.key.keysym.sym=SDLK_RETURN;break;
        case SDL_SCANCODE_SPACE:event.key.keysym.sym=SDLK_SPACE;break;
        default:event.key.keysym.sym=SDL_SCANCODE_TO_KEYCODE(physical);break;
        }
        if(!contextual&&(mapped.keysym.sym==SDLK_F5||mapped.keysym.sym==SDLK_F6||physical==SDL_SCANCODE_F5||physical==SDL_SCANCODE_F6)) event.key=mapped;
    }
    if(key_event&&game_.campaign.blocks_simulation()) {
        // campaign_screen.gd numbered choices and N/Y use physical keys;
        // copy-protection text itself remains SDL_TEXTINPUT.
        const auto physical=incoming.key.keysym.scancode;
        if(physical>=SDL_SCANCODE_1&&physical<=SDL_SCANCODE_9) event.key.keysym.sym=SDLK_1+(physical-SDL_SCANCODE_1);
        else if(physical==SDL_SCANCODE_N) event.key.keysym.sym=SDLK_n;
        else if(physical==SDL_SCANCODE_Y) event.key.keysym.sym=SDLK_y;
    }
    if(handle_modal(event)) {process_actions();sync_models();return;}
    if(screen_==Screen::Inventory&&(event.type==SDL_MOUSEBUTTONDOWN||event.type==SDL_MOUSEBUTTONUP)
        &&event.button.button==SDL_BUTTON_LEFT) {
        // inventory_page.gd arms on press and turns the page on release.
        if(event.type==SDL_MOUSEBUTTONDOWN) inventory_pressed_=panels_.action(panels::Screen::Inventory,event.button.x,event.button.y)==panels::Action::Inventory;
        else {const bool turn=inventory_pressed_;inventory_pressed_=false;if(turn) panel_command(panels::Action::Inventory,0,0);}
        return;
    }
    if(event.type==SDL_KEYDOWN&&screen_==Screen::Inventory) {
        const auto physical=incoming.key.keysym.scancode;
        if(physical==SDL_SCANCODE_ESCAPE||physical==SDL_SCANCODE_SPACE||physical==SDL_SCANCODE_RETURN)
            panel_command(panels::Action::Inventory,0,0);
        return;
    }
    if(event.type==SDL_KEYDOWN&&screen_==Screen::Boudoir) {
        // boudoir_session/boudoir_screen preserve physical inventory/book keys.
        if(incoming.key.keysym.scancode==SDL_SCANCODE_I) {panel_command(panels::Action::Inventory,0,0);return;}
        if(incoming.key.keysym.scancode==SDL_SCANCODE_S) {open_book(false);return;}
    }
    if(key_event) {
        event.key=mapped;
        if(incoming.key.keysym.sym==SDLK_F1&&mapped.keysym.sym==SDLK_F1) event.key.keysym.sym=SDLK_h;
    }
    if(screen_==Screen::World) {
        const auto action=view_.handle_world(event,game_.data,&state_.network);
        if(action.clicked) {
            if(game_.campaign.select_map_cell(*action.clicked)) process_actions();
            else if(state_.toggle_switch(*action.clicked)) {announce("SWITCH CHANGED");log_("switch");}
        }
        if(action.consumed) return;
    }
    if(event.type==SDL_MOUSEBUTTONUP) dragging_=false;
    if(event.type==SDL_MOUSEMOTION && dragging_ && !halted()) {
        const auto x=float(event.motion.x),y=float(event.motion.y);
        if(screen_==Screen::Cabin) state_.engine.set_regulator(view_.regulator_at(x,y));
        else if(screen_==Screen::Instruments) state_.engine.set_regulator(panels_.regulator_at(x,y));
    }
    if(event.type==SDL_MOUSEBUTTONDOWN && event.button.button==SDL_BUTTON_LEFT) click(float(event.button.x),float(event.button.y));
    if(event.type==SDL_KEYDOWN && !event.key.repeat) key(event.key);
}
void SessionUI::advance(double seconds) {
    if(startup_.active()) {
        startup_.advance(seconds);
        for(const auto& cue:startup_.take_audio()) switch(cue.kind) {
        case panels::StartupAudioKind::PublisherEffect:audio_.effect("present",cue.value);break;
        case panels::StartupAudioKind::ReceptionMusic:audio_.play_reception();break;
        case panels::StartupAudioKind::FadeMusic:audio_.fade_music(cue.value);break;
        }
        audio_.advance(seconds,{});discard_elapsed_=true;return;
    }
    if(notice_seconds_>0) { notice_seconds_-=seconds; if(notice_seconds_<=0) notice_.clear(); }
    if(!discard_elapsed_ && screen_!=Screen::Reception && screen_!=Screen::Inventory && !book_.active() && !captain_.active() && !help_.active() && !keyboard_.active()) {
        game_.advance(seconds);
        world_events_.advance(seconds,game_.world.snapshot(),game_.roamers.snapshot());
        works_.advance(seconds,game_.works);
        launcher_.advance_visual(seconds);
        if(game_.tactical) tactical_.advance_visual(seconds,*game_.tactical,game_.battle_events);
        if(!state_.paused && !halted()) visual_time_+=seconds;
    }
    process_actions();sync_models();
    const bool presentation_paused=discard_elapsed_||halted()||book_.active()||captain_.active()||help_.active()||keyboard_.active()||screen_==Screen::Reception||screen_==Screen::Inventory;
    view_.advance_cabin(seconds,state_,presentation_paused||state_.paused);
    view_.set_pointer(pointer_,pointer_inside_&&screen_==Screen::Cabin&&!presentation_paused);
    panels_.set_pointer(pointer_,pointer_inside_&&!presentation_paused);
    view_.advance_world(state_,seconds,screen_==Screen::World,
        discard_elapsed_||halted()||book_.active()||captain_.active()||help_.active()||keyboard_.active());
    const auto& e=state_.engine;
    audio_.advance(seconds,{e.lignite,e.anthracite,e.lignite_rate,e.anthracite_rate,e.speed,e.pressure_reserve,
        (screen_==Screen::Cabin||screen_==Screen::Instruments)&&!game_.blocks_simulation(),game_.campaign.presentation().scene==campaign::Scene::Oslo});
    discard_elapsed_=false;
}
void SessionUI::draw() {
    if(startup_.active()) {startup_.draw();return;}
    if(screen_==Screen::Reception) {view_.reception(notice_);draw_options();}
    else if(screen_==Screen::Cabin) view_.cabin(state_,visual_time_,notice_);
    else if(screen_==Screen::World) view_.world(state_,notice_,&game_.enemies.snapshot(),&game_.data);
    else {
        panels_.draw(panel_screen(),state_,notice_);
        if(footer_visible()) view_.footer(state_,screen_==Screen::Overview,screen_==Screen::Overview);
    }
    if(screen_!=Screen::Reception) {
        if(city_.active()&&!city_suspended_) {city_.draw();view_.footer(state_,false);}
        if(game_.works.active()) {works_.draw(game_.works);view_.footer(state_,false);}
        if(panels::WorldEventScreen::active(game_.world.snapshot(),game_.roamers.snapshot())) {
            world_events_.draw(game_.world.snapshot(),game_.roamers.snapshot(),game_.campaign.data());view_.footer(state_,false);
        }
        if(game_.tactical) tactical_.draw(*game_.tactical);
        if(game_.report) report_.draw(*game_.report);
        if(game_.campaign.blocks_simulation()) {
            if(game_.campaign.quarters_scene()) view_.footer(state_,false);
            campaign_.draw();
        }
        if(captain_.active()) captain_.draw();
        if(game_.launcher.visible()) {view_.footer(state_,false);launcher_.draw();}
    }
    if(screen_==Screen::Reception&&!book_.active()) keyboard_.draw_badge();
    if(help_.active()) help_.draw();
    if(keyboard_.active()) keyboard_.draw();
    if(book_.active()) book_.draw();
}
}
