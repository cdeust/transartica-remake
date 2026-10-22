// SPDX-License-Identifier: MIT
#pragma once
#include "core/session.hpp"
namespace transartica {
// Presentation-only source travel_world interpolation; never mutates Journey.
class WorldMotion {
public:
    void reset(const Journey&);
    void synchronize(const Journey&,bool visible); // On source train update/cycle.
    void advance(const Session&,double seconds,bool visible,bool visual_paused=false);
    double lag(const Journey&)const;
    Point position()const{return position_;}
    bool initialized()const{return initialized_;}
private:
    double arc_{},from_{},to_{},elapsed_{};
    Point position_,target_;bool initialized_{},interpolating_{};
};
}
