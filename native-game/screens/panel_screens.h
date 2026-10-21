// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
#include "economy/trade.hpp"
#include "room_hover.h"
#include "platform/canvas.h"
#include <filesystem>
#include <optional>
#include <string_view>
#include <vector>

namespace transartica::panels {
enum class Screen { Boudoir, Quarters, Instruments, Overview, Inventory };
enum class Action { None, Cabin, World, Overview, Inventory, Save, Regulator, Stoup, Revolver, Spies, Cars, Unavailable };

// Visible rooms share the actual application Session. The caller owns navigation,
// simulation blocking while inventory is open, and the common footer.
class PanelScreens {
public:
    PanelScreens(Canvas&, std::filesystem::path assets,const economy::Trade* trade=nullptr);
    void set_pointer(Point point,bool active) {pointer_=point;hover_active_=active;}
    void draw(Screen, const Session&, std::string_view notice = {});
    Action action(Screen, float x, float y) const;
    int regulator_at(float x, float y) const;
    std::optional<Cell> overview_cell(float x,float y) const;
    void reset_inventory() { inventory_page_ = 0; }
    // true while another page remains; false requests return to the boudoir.
    bool next_inventory(const Session&);
private:
    Canvas& canvas_;
    std::filesystem::path assets_;
    const economy::Trade* trade_;
    RoomHover hover_;
    Point pointer_;
    bool hover_active_{};
    std::size_t inventory_page_{};
    bool overview_loaded_{};
    struct Geometry { std::vector<SDL_FRect> routes, compartments, towns, symbols, sites; std::vector<Point> dots; } geometry_;
    SDL_FRect fit(float width, float height) const;
    Point logical(float x, float y, float width, float height) const;
    void image(const std::filesystem::path&, SDL_FRect, const SDL_Rect* crop = nullptr);
    void text(SDL_FRect frame, float logical_width, Point baseline, std::string_view, int size, SDL_Color);
    void instruments(const Session&);
    void inventory(const Session&);
    void overview(const Session&);
    void load_overview();
    std::vector<std::string> inventory_lines(const Session&) const;
};
}
