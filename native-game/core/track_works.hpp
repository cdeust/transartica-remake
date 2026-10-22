// SPDX-License-Identifier: MIT
#pragma once
#include "session.hpp"
#include "random.hpp"

namespace transartica {
enum class WorkKind { None, Crevasse, Lake, Destroyed };
enum class WorkStage { Closed, Question, Shortage, Report, Information };
struct WorkRule { int question, lack, rails, slaves, work, base, spread; };
struct WorkLabour { int slaves{}, mammoths{}, cranes{}, ticks{}; bool operator==(const WorkLabour&) const = default; };
WorkKind work_kind(int signed_code);
int repaired_track(int signed_code);
WorkRule work_rule(WorkKind);
int rails_carried(const std::vector<Wagon>&);
int slaves_carried(const std::vector<Wagon>&);
int consume_rails(std::vector<Wagon>&,int amount);
WorkLabour work_labour(WorkKind,const std::vector<Wagon>&);

// Source works_dialog.gd: charge on acceptance, write the map only on dismissal.
// This state also represents an interrupted, already-paid work report in saves.
struct TrackWorks {
    WorkKind kind = WorkKind::None;
    WorkStage stage = WorkStage::Closed;
    Cell cell{-1,-1};
    int code{}, used{}, information{}, countdown{};
    bool lacks_rails{};
    double accumulator{};
    WorkLabour labour;
    bool active() const { return stage != WorkStage::Closed; }
    bool ask(const RailNetwork&,Cell);
    void inform(int message);
    bool accept(std::vector<Wagon>&,Random&);
    bool dismiss(RailNetwork&,Journey&);
    bool advance(double seconds,double seconds_per_cycle);
    bool valid(const RailNetwork&) const;
    bool operator==(const TrackWorks&) const = default;
};
}
