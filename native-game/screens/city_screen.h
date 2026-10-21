// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include "economy/trade.hpp"
#include "economy/world_data.hpp"
#include "economy/management.hpp"

namespace transartica::panels {
// A transaction may both change cargo and request departure (garrisons5..7).
struct CityEvent { bool depart{}, cargo_changed{}; int town_message{}; bool consumed{}; };
class CityScreen {
public:
    CityScreen(Canvas&,std::filesystem::path assets,economy::Trade&,const economy::WorldData&,
               EngineState&,std::vector<Wagon>&);
    bool open(int city,Random&); // Call once per actual arrival, after campaign gate.
    // Source session_saves.gd reopens city's initial menu, without visit/RNG.
    // Goods selection, quantity and list scroll are not persisted by that source.
    bool restore_city(int city);
    void open_workshop(Cell);
    economy::WorkshopState workshop_snapshot() const;
    bool restore_workshop(const economy::WorkshopState&); // Validates before mutation.
    void close() { active_=false; }
    bool active() const { return active_; }
    int city() const { return city_; }
    bool in_transaction() const { return transaction_; }
    void draw(); // Logical upper149 rows. Host draws shared footer afterwards.
    CityEvent handle(const SDL_Event&);
    // Explicit actions also allow deterministic host tests without SDL injection.
    void start(int mode);
    void start_workshop();
    void select(int row);
    void increment();
    void decrement();
    CityEvent validate();
    CityEvent leave_transaction();
    int quantity() const { return quantity_; }
    std::string notice() const { return notice_; }
private:
    Canvas& canvas_;
    std::filesystem::path assets_;
    economy::Trade& trade_;
    const economy::WorldData& world_;
    EngineState& engine_;
    std::vector<Wagon>& wagons_;
    economy::Management management_;
    bool active_{},station_{},transaction_{},workshop_{},direct_{},depart_only_{},confirmation_{};
    int city_=-1,kind_{},mode_{},quantity_{},selection_=-1,list_scroll_{},station_action_=51,moving_=-1,train_scroll_{};
    std::string title_,notice_;
    std::optional<economy::Offer> offer_;
    std::optional<economy::Entry> entry_;
    std::vector<economy::GoodsRow> rows_;
    std::vector<economy::Entry> entries_;
    struct Button { SDL_FRect box; std::string label; int action; };
    struct Icon { std::filesystem::path path; SDL_Rect crop; };
    std::array<Icon,16> icons_;
    std::array<Icon,25> overhead_;
    bool icons_loaded_{};
    bool overhead_loaded_{};
    SDL_FRect frame() const;
    Point logical(float,float) const;
    SDL_FRect rect(SDL_FRect) const;
    void fill(SDL_FRect,SDL_Color);
    void panel(SDL_FRect,SDL_Color,SDL_Color);
    void text(std::string_view,SDL_FRect,int,SDL_Color);
    void picture(const std::filesystem::path&,SDL_FRect,bool cover,const SDL_Rect* crop=nullptr);
    void draw_wagon(int,SDL_FRect);
    void load_icons();
    void load_overhead();
    void draw_station();
    void draw_transaction();
    void menu();
    void fill_list();
    std::vector<Button> buttons() const;
    CityEvent activate(int);
    CityEvent finish();
    CityEvent choose_wagon(int);
    CityEvent confirm(bool);
};
}
