// SPDX-License-Identifier: MIT
#pragma once
#include "game_session.h"
#include "audio/game_audio.hpp"
#include "economy/management.hpp"
#include "screens/captain_event.h"
#include "view/world_state.hpp"
namespace transartica {
struct PresentationState {
    int screen{},overview_return=1,options_return=1;
    bool options_open{},city_suspended{};
    double visual_time{};
    panels::CaptainState captain;
    economy::WorkshopState workshop;
    WorldState world_view;
    bool valid() const;
    bool operator==(const PresentationState&) const = default;
};
// Single envelope, staged decoding and semantic validation before live mutation.
bool save_game(const std::filesystem::path&,const GameSession&,const audio::GameAudio&,
               const PresentationState&,std::string& error);
bool load_game(const std::filesystem::path&,GameSession&,audio::GameAudio&,
               PresentationState&,std::string& error);
}
