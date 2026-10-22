// SPDX-License-Identifier: MIT
#pragma once
#include "core/track_works.hpp"
#include "economy/management.hpp"
#include "economy/trade.hpp"

namespace transartica {
// Source: session_saves.gd/world_ui_save.gd extension state. The shared game RNG
// and already-paid work report must commit together with the restored Session.
struct EconomySnapshot {
    economy::TradeState trade;
    Random random;
    TrackWorks works;
    economy::WorkshopState workshop;
    bool operator==(const EconomySnapshot&) const = default;
};
std::string serialize_economy(const EconomySnapshot&);
bool validate_economy(const EconomySnapshot&,const Session&,std::string& error);
// Output is assigned only after complete syntax and model validation succeed.
bool parse_economy(const std::string&,EconomySnapshot&,const Session&,std::string& error);
}
