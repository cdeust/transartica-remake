// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
namespace transartica::economy {
struct Equipment { int instruments{}; bool launcher{}; };
// Source world_ui_save.gd: live workshop confirmation and moving selection persist.
struct WorkshopState {
    bool visible{};
    std::string title;
    int selected=-1,action=51,scroll{},moving=-1;
    bool confirmation{};
    std::string notice;
    bool operator==(const WorkshopState&) const = default;
};
// Source: train_management.gd, GLIEU0x21ea..2b10. References remain owned by Session.
class Management {
public:
    Management(EngineState& engine,std::vector<Wagon>& wagons):engine_(engine),wagons_(wagons) {}
    static std::string station_name(Cell);
    int repair_price(int index) const;
    int repair_refusal(int index) const;
    bool repair(int index,bool confirm);
    int remove_refusal(int index) const;
    bool remove(int index,bool confirm);
    bool move(int from,int to);
    Equipment equipment_flags() const;
    bool valid_workshop(const WorkshopState&) const;
private:
    EngineState& engine_;
    std::vector<Wagon>& wagons_;
};
}
