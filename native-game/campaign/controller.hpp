// SPDX-License-Identifier: MIT
#pragma once
#include "state.hpp"
#include "economy/world_data.hpp"

namespace transartica::campaign {
struct EnemyInfo { int kind{},heading{},strength{}; };
struct MoverInfo { int heading{},quantity{}; };
// Concrete adapter provided by GameSession against its sole world/combat owners.
// No default no-op implementations: missing dependencies cannot silently succeed.
class Host {
public:
    virtual ~Host()=default;
    virtual bool at_station() const=0;
    virtual int enemy_at(Cell) const=0;
    virtual std::optional<EnemyInfo> enemy_info(int slot) const=0;
    virtual void set_enemy_damage(int slot,int kind,int strength)=0;
    virtual std::optional<MoverInfo> mover_info(int code) const=0;
    virtual Lines mine_report(int index,const std::map<std::string,std::string>& phrases) const=0;
    // Source finale uses global randi(), never the commerce/campaign RNG stream.
    virtual std::uint64_t finale_seed()=0;
};
enum class ActionKind { ResumeCity,Depart,Reverse,Quit,Cabin,Quarters,Boudoir,Overview,Options,
    CargoChanged,SceneAudio,EffectAudio,DepartureChime,FinaleAudioStart,FinaleAudioStop };
struct Action { ActionKind kind; int value{}; std::string source; double seconds{}; };
struct InspectionResult { int message{}; Cell cell; std::vector<Cell> path; bool obstacle{},missile{}; };
InspectionResult inspect(Session&,State&,Random&,Host&,int heading,bool missile);
Lines spy_report(int,const State&,const Data&,const Host&);
struct Snapshot {
    State state;
    std::size_t page{};
    Selection selection=Selection::None;
    CrewMenu crew_menu=CrewMenu::None;
    bool notice{},car_missile{};
    Room return_room=Room::Quarters;
    Presentation presentation;
    Finale finale;
    bool valid() const;
    bool operator==(const Snapshot&) const = default;
};
std::string serialize_snapshot(const Snapshot&);
bool parse_snapshot(std::string_view,Snapshot&,std::string& error);
class Controller {
public:
    Controller(Session&,economy::Trade&,const economy::WorldData&,Random&,Host&);
    bool load(const std::filesystem::path& private_data,std::string& error);
    void reset();
    bool before_entry(Cell,int heading=0,bool after_spy=false);
    bool before_city(int);
    bool station(int);
    void advance(double seconds); // Presentation time only, finale50Hz.
    Cell initialize_fauna();
    void advance_spies();
    bool advance_fauna();
    bool advance_cycle(); // Convenience only; GameSession preserves world ordering.
    void process(); // Continue current page.
    void answer(bool);
    void submit_code(std::string_view);
    void input(std::string_view ascii); // Filters quiz letters or Oslo digits.
    void backspace();
    void menu(int index);
    void read_stoup(Room return_room);
    void open_spy_menu();
    void open_car_menu();
    bool select_map_cell(Cell);
    void show_town(int);
    void die(int);
    bool present_engine_event();
    bool blocks_simulation() const { return state_.presentation.visible; }
    bool quarters_scene() const;
    const Presentation& presentation() const { return state_.presentation; }
    const Finale& finale() const { return state_.finale; }
    const State& model() const { return state_.state; }
    const Data& data() const { return data_; }
    void push_stoup(int id) { state_.state.stoup.push(id); }
    void observe_enemy(int slot,Cell cell) { state_.state.observe_enemy(slot,cell,session_.calendar); }
    Snapshot snapshot() const { return state_; }
    bool restore(const Snapshot&); // No model effects, RNG draws or repeated losses.
    std::vector<Action> take_actions();
private:
    Session& session_;
    economy::Trade& trade_;
    const economy::WorldData& world_;
    Random& random_;
    Host& host_;
    Data data_;
    Snapshot state_;
    std::vector<Action> actions_;
    void emit(ActionKind,int value=0,std::string source={},double seconds=0);
    void present(Pending);
    void show_page();
    void set_presentation(Scene,Lines,bool code=false,bool question=false);
    void begin_quiz(QuizKind,int city=-1,bool oslo=false);
    void submit_quiz(std::string_view);
    bool before_fauna(Cell);
    void ambush(bool wolf);
    void open_menu(Lines);
    void return_to_room();
};
}
