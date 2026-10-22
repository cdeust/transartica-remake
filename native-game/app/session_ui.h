// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "view/view.h"
#include "screens/panel_screens.h"
#include "screens/save_book.h"
#include "app/game_session.h"
#include "audio/game_audio.hpp"
#include "screens/city_screen.h"
#include "screens/work_screen.h"
#include "screens/campaign_screen.h"
#include "screens/tactical_screen.h"
#include "screens/combat_report.h"
#include "screens/world_event_screen.h"
#include "screens/captain_event.h"
#include "screens/launcher_screen.h"
#include "screens/help_overlay.h"
#include "screens/settings_keyboard.h"
#include "screens/startup_screen.h"
#include <functional>

namespace transartica {
struct PresentationState;
class SessionUI : public panels::LauncherMapHost {
public:
    SessionUI(Canvas&, View&, GameSession&, audio::GameAudio&, const std::filesystem::path& assets,
              const std::filesystem::path& save_directory, std::function<void(std::string_view)> log);
    void handle(const SDL_Event&);
    void advance(double seconds);
    void draw();
    void draw_launcher_map(Canvas&,const Session&,Cell,Point) override;
    void draw_launcher_target(Canvas&,const Session&,const world::EnemyTrain&,Cell,Point) override;
    bool running = true, capture = false;
private:
    enum class Screen { Reception, Cabin, World, Boudoir, Quarters, Instruments, Overview, Inventory };
    View& view_;
    Canvas& canvas_;
    GameSession& game_;
    audio::GameAudio& audio_;
    Session& state_;
    panels::PanelScreens panels_;
    panels::SaveBook book_;
    panels::CityScreen city_;
    panels::WorkScreen works_;
    panels::CampaignScreen campaign_;
    panels::TacticalScreen tactical_;
    panels::CombatReport report_;
    panels::WorldEventScreen world_events_;
    panels::CaptainEvent captain_;
    panels::LauncherScreen launcher_;
    input::KeyBindings bindings_;
    panels::KeyboardSettings keyboard_;
    panels::HelpOverlay help_;
    panels::StartupIntro startup_;
    std::filesystem::path save_directory_;
    std::function<void(std::string_view)> log_;
    Screen screen_ = Screen::Reception, overview_return_ = Screen::Cabin;
    Screen options_return_ = Screen::Cabin;
    bool options_open_ = false;
    bool dragging_ = false, discard_elapsed_ = false;
    bool city_suspended_ = false, tactical_open_ = false;
    bool inventory_pressed_ = false;
    Point pointer_;
    bool pointer_inside_{};
    double visual_time_ = 0, notice_seconds_ = 0;
    std::string notice_;
    void command(Action, float x = 0, float y = 0);
    void panel_command(panels::Action, float x, float y);
    void click(float x, float y);
    void key(const SDL_KeyboardEvent&);
    void open_book(bool loading);
    void submit_book(const std::string& name);
    PresentationState presentation_snapshot() const;
    void quick_save();
    void announce(std::string);
    bool halted() const;
    bool footer_visible() const;
    panels::Screen panel_screen() const;
    bool handle_modal(const SDL_Event&);
    void sync_models();
    void process_actions();
    void draw_options();
};
}
