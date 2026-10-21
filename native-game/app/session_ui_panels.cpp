// SPDX-License-Identifier: MIT
// Source boudoir_session.gd, world_session.gd, game_audio_routes.gd.
#include "session_ui.h"
#include "view/render_check.h"
#include <algorithm>
#include <cmath>

namespace transartica {
void SessionUI::sync_models() {
    if(game_.workshop) {
        if(!city_.active()) city_.open_workshop(state_.journey.position);
    } else if(game_.city>=0) {
        if(!city_.active()||city_.city()!=game_.city) {
            city_.restore_city(game_.city);
            // main_interface.gd::show_city selects the arrival without recentering.
            auto chart=view_.snapshot_world();chart.selected_city=game_.city;
            view_.restore_world(chart,state_,game_.data.cities().size());
        }
    } else {city_.close();city_suspended_=false;}
    if(game_.tactical && !tactical_open_) {
        // tactical_scene.gd::open_battle, WDECOR127 -> 6114 ambient.
        audio_.stop_effects();audio_.effect("wdecor",0x6121);
        tactical_.open(*game_.tactical);tactical_.set_paused(game_.manual_paused);tactical_open_=true;
    }
    if(!game_.tactical) tactical_open_=false;
}
void SessionUI::process_actions() {
    using Kind=campaign::ActionKind;
    for(const auto& action:game_.take_actions()) switch(action.kind) {
    case Kind::Quit:running=false;break;
    case Kind::Cabin:screen_=Screen::Cabin;break;
    case Kind::Quarters:screen_=Screen::Quarters;break;
    case Kind::Boudoir:screen_=Screen::Boudoir;break;
    case Kind::Overview:overview_return_=screen_;screen_=Screen::Overview;break;
    // Controller emits Options only after Earth or SunEnd, never a temporary
    // F6 menu (campaign_session.gd:117..120). Reception owns further input.
    case Kind::Options:options_return_=Screen::Reception;screen_=Screen::Reception;options_open_=false;break;
    case Kind::ResumeCity:city_suspended_=false;break;
    case Kind::SceneAudio:
        if(action.source=="loss") audio_.play_loss();
        else if(action.source=="city") {if(audio_.snapshot().music_enabled) audio_.play_city(action.value,int(action.seconds));}
        else if(action.source=="journey") {if(audio_.snapshot().music_enabled) audio_.play_journey();}
        else if(action.source=="worksite") {if(audio_.snapshot().music_enabled) audio_.play_worksite();}
        else audio_.effect(action.source,action.value);
        break;
    case Kind::EffectAudio:audio_.effect(action.source,action.value);break;
    case Kind::DepartureChime:audio_.son(action.value);if(action.value==1&&audio_.snapshot().music_enabled) audio_.play_journey();break;
    case Kind::FinaleAudioStart:audio_.play_finale(action.seconds);break;
    case Kind::FinaleAudioStop:audio_.stop_finale();break;
    default:break; // Model actions already applied once by GameSession.
    }
    for(const auto& action:game_.launcher.take_actions()) switch(action.kind) {
    case launcher::ActionKind::Cabin:screen_=Screen::Cabin;break;
    case launcher::ActionKind::Options:options_return_=screen_;screen_=Screen::Reception;options_open_=true;break;
    case launcher::ActionKind::Save:quick_save();break;
    case launcher::ActionKind::CargoChanged:game_.cargo_changed();break;
    case launcher::ActionKind::EffectAudio:audio_.effect("berta",action.value);break;
    case launcher::ActionKind::ImpactAudio:audio_.son(action.value);break;
    case launcher::ActionKind::EnemyRemoved:break;
    }
    for(const auto& event:game_.battle_events) if(event.kind=="audio") audio_.effect("wdecor",event.source_offset);
    game_.battle_events.clear();
}
bool SessionUI::handle_modal(const SDL_Event& event) {
    if(screen_==Screen::Reception) return false;
    if(captain_.active()) {
        const auto action=captain_.handle_event(event);
        if(action==panels::CaptainAction::Confirmed) {state_.paused=true;captain_.end_journey();audio_.play_loss();}
        // captain_event.gd:80..82 ends the game on the reception screen.
        if(action==panels::CaptainAction::Options) {options_return_=Screen::Reception;screen_=Screen::Reception;options_open_=false;}
        return true;
    }
    if(game_.campaign.blocks_simulation()) {campaign_.handle_event(event);return true;}
    if(game_.launcher.visible()) {
        if(event.type==SDL_MOUSEBUTTONDOWN && event.button.button==SDL_BUTTON_LEFT && view_.in_footer(event.button.x,event.button.y)) {
            command(view_.footer_action(event.button.x,event.button.y,false),event.button.x,event.button.y);audio_.son(3);
        } else launcher_.handle_event(event);
        return true;
    }
    if(game_.tactical) {
        const auto action=tactical_.handle(event,*game_.tactical);
        game_.manual_paused=tactical_.paused();
        if(action==panels::TacticalEvent::Save) quick_save();
        if(action==panels::TacticalEvent::Options) {options_return_=screen_;screen_=Screen::Reception;options_open_=true;}
        if(action==panels::TacticalEvent::Completed) game_.finish_battle();
        return true;
    }
    if(game_.report) {
        const auto action=report_.handle(event);
        if(action==panels::CombatReportEvent::Continue) {game_.report.reset();state_.paused=false;}
        if(action==panels::CombatReportEvent::Options) {options_return_=screen_;screen_=Screen::Reception;options_open_=true;}
        return true;
    }
    if(game_.works.active()) {
        const auto action=works_.handle(event,game_.works);
        if(action==panels::WorkAction::Accept) game_.answer_works(true);
        else if(action==panels::WorkAction::Decline) game_.answer_works(false);
        else if(action==panels::WorkAction::Dismiss) game_.finish_works();
        return true;
    }
    if(panels::WorldEventScreen::active(game_.world.snapshot(),game_.roamers.snapshot())) {
        // world_event_screen.gd::_has_point excludes the shared strip. Only
        // works_dialog blocks its commands (original_panel.gd:135..140).
        if(event.type==SDL_MOUSEBUTTONDOWN && event.button.button==SDL_BUTTON_LEFT && view_.in_footer(event.button.x,event.button.y)) {
            const auto action=view_.footer_action(event.button.x,event.button.y,false);
            if(action!=Action::None) {audio_.son(3);command(action,event.button.x,event.button.y);}
            return true;
        }
        const auto action=world_events_.handle_event(event,game_.world.snapshot(),game_.roamers.snapshot());
        if(action==panels::WorldEventAction::Accept) game_.answer_world(true);
        else if(action==panels::WorldEventAction::Decline) game_.answer_world(false);
        else if(action==panels::WorldEventAction::Dismiss) game_.continue_world();
        return true;
    }
    if(city_.active()&&!city_suspended_) {
        if(event.type==SDL_MOUSEBUTTONDOWN && event.button.button==SDL_BUTTON_LEFT && view_.in_footer(event.button.x,event.button.y)) {
            const auto action=view_.footer_action(event.button.x,event.button.y,false);
            city_suspended_=action==Action::Map||action==Action::Overview||action==Action::DetailedMap||action==Action::Engine||action==Action::Quarters||action==Action::Boudoir;
            command(action,event.button.x,event.button.y);audio_.son(3);return true;
        }
        const auto action=city_.handle(event);
        if(action.cargo_changed) game_.cargo_changed();
        if(action.town_message) game_.campaign.show_town(action.town_message);
        if(action.depart) game_.depart();
        return true;
    }
    return false;
}
void SessionUI::draw_options() {
    // reception_screen.gd / brass_choice.gd cards fit the authored plaques.
    const float scale=std::min(canvas_.width()/320.f,canvas_.height()/200.f);
    const float left=(canvas_.width()-320*scale)/2,top=(canvas_.height()-200*scale)/2;
    const auto card=[&](SDL_FRect box,const std::string& text) {
        SDL_FRect rectangle{left+box.x*scale,top+box.y*scale,box.w*scale,box.h*scale};
        auto* renderer=canvas_.renderer();SDL_SetRenderDrawColor(renderer,8,19,26,255);
        render_check(SDL_RenderFillRectF(renderer,&rectangle),"Option card");
        SDL_SetRenderDrawColor(renderer,238,202,136,255);render_check(SDL_RenderDrawRectF(renderer,&rectangle),"Option border");
        const int size=std::max(1,int(std::round(7*scale)));const auto extent=canvas_.measure(text,size);
        canvas_.text(text,rectangle.x+(rectangle.w-extent.x)/2,top+(box.y+box.h-12)*scale,size,{238,202,136,255});
    };
    card({199,48,112,18},game_.automatic?"AUTO":"MANUAL");
    card({8,48,112,18},"LEVEL "+std::to_string(game_.difficulty));
    card({8,171,112,18},audio_.snapshot().music_enabled?"ON":"OFF");
}
}
