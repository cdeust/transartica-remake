// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "core/random.hpp"
#include <array>
#include <optional>

namespace transartica::campaign {
using Lines=std::vector<std::string>;
enum class Scene { None,Wolf,Mole,Slope,WhaleHarpoon,WhaleQuestion,Urga,Oslo,Mausoleum,
    Sun,SunEnd,Earth,SpyPickup,SabotageConfirm,ManualQuiz,Death,Crew,Report,SunRestored };
std::string scene_name(Scene);
enum class QuizKind { Soleil,Viking };
struct Quiz {
    QuizKind kind=QuizKind::Soleil;
    int index{},attempt{},resume_city=-1;
    bool resume_oslo{};
    bool valid() const;
    bool operator==(const Quiz&) const = default;
};
struct Pending {
    Scene scene=Scene::None;
    std::vector<int> messages;
    bool code_input{},quiz_done{},reverse{},departure_chime{};
    int spy=-1,epitaph{},divisor{},applied{};
    Lines ambush_lines;
    std::optional<Quiz> quiz;
    bool empty() const { return scene==Scene::None; }
    bool valid(bool urga_key,bool delivery_open) const;
    bool operator==(const Pending&) const = default;
};
enum class Ending { None,Sun,Death };
enum class Selection { None,Send,Dynamite };
enum class CrewMenu { None,Spies,Cars,CarDirection };
enum class Room { Boudoir,Quarters,City };
struct Presentation {
    bool visible{};
    Scene scene=Scene::None;
    Lines lines;
    std::string input_code;
    bool entering_code{},question{};
    Lines menu;
    bool operator==(const Presentation&) const = default;
};
// Source main[0x5d84],15 fields. Arrays preserve exact report history without
// duplicating commerce's ownership: Controller synchronizes Trade spy_slots.
using SpyRecord=std::array<std::int64_t,15>;
struct Stoup {
    std::vector<int> entries;
    void push(int);
    std::optional<int> pop();
    bool valid() const { return entries.size()<=10; }
    bool operator==(const Stoup&) const = default;
};
struct Hazards {
    std::array<int,7> traps{-1,-1,-1,-1,-1,-1,-1};
    std::array<std::int64_t,10> mole_times{};
    bool intercept_trap(Cell,RailNetwork&);
    bool intercept_mole(Cell,bool missile,const GameCalendar&,Random&);
    bool player_mole(Cell,const GameCalendar&,Random&);
    bool valid() const;
    bool operator==(const Hazards&) const = default;
};
struct Fauna {
    bool initialized{},frozen{};
    Cell cell;
    int heading=6,phase{},counter{};
    std::vector<Cell> history;
    void initialize(Random&);
    void relocate(Random&);
    void oslo();
    void record_player(Cell,const RailNetwork&);
    bool presence(Cell at) const { return initialized&&cell==at; }
    bool advance(const RailNetwork&,Random&,const Hazards&);
    bool valid() const;
    bool operator==(const Fauna&) const = default;
};
struct Finale {
    int tick{};
    double remainder{};
    std::uint64_t seed{};
    void start(std::uint64_t);
    bool advance(double);
    bool valid() const;
    int shot() const;
    int palette() const;
    std::array<int,4> clouds() const;
    bool operator==(const Finale&) const = default;
private:
    std::array<int,241> palettes_{};
};
}
