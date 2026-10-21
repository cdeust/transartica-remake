// SPDX-License-Identifier: MIT
#pragma once
#include "game_archive.h"
#include <sstream>
namespace transartica::archive {
struct Encounters {
    Random random,visual;
    int difficulty{},pending=-1,city=-1;
    bool automatic{},manual_paused{},workshop{};
    double text_accumulator{};
    std::optional<combat::AutomaticResult> report;
};
std::string encode(const Encounters&);
bool decode(const std::string&,Encounters&);
std::string encode(const audio::Snapshot&);
bool decode(const std::string&,audio::Snapshot&);
std::string encode(const PresentationState&);
bool decode(const std::string&,PresentationState&);
}
