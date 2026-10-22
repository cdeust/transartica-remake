// SPDX-License-Identifier: MIT
#pragma once
#include "platform/canvas.h"
#include <vector>
#include <string>
namespace transartica::panels {
enum class CaptainMode {Closed,Confirm,Notice,Epitaph,Earth};
enum class CaptainAction {None,Confirmed,Dismissed,Options};
struct CaptainState {CaptainMode mode=CaptainMode::Closed;std::vector<std::string> lines;bool operator==(const CaptainState&)const=default;};
class CaptainEvent {
public:
    CaptainEvent(Canvas&,std::filesystem::path assets);
    void prompt_revolver();
    void inform(std::vector<std::string>);
    void end_journey();
    void close();
    bool active()const{return state_.mode!=CaptainMode::Closed;}
    void draw();
    CaptainAction handle_event(const SDL_Event&);
    const CaptainState& snapshot()const{return state_;}
    bool restore(const CaptainState&);
private:
    Canvas& canvas_;std::filesystem::path assets_;CaptainState state_;std::vector<std::string> epitaph_;bool armed_{};
    SDL_FRect frame()const;
    CaptainAction advance();
    void centered(float,std::string_view);
};
}
