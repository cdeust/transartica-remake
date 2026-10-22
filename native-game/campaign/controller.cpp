// SPDX-License-Identifier: MIT
// Source campaign_session.gd, campaign_protection.gd, campaign_fauna_session.gd.
#include "controller.hpp"
#include <algorithm>
#include <cctype>
#include <utility>
namespace transartica::campaign {
Controller::Controller(Session& session,economy::Trade& trade,const economy::WorldData& world,Random& random,Host& host)
    :session_(session),trade_(trade),world_(world),random_(random),host_(host) {reset();}
bool Controller::load(const std::filesystem::path& path,std::string& error) {return data_.load(path/"campaign.json",error);}
void Controller::reset() {state_={};state_.finale.start(0);actions_.clear();}
void Controller::emit(ActionKind kind,int value,std::string source,double seconds) {actions_.push_back({kind,value,std::move(source),seconds});}
std::vector<Action> Controller::take_actions() {return std::exchange(actions_,{});}
bool Controller::before_entry(Cell cell,int heading,bool after_spy) {
    if(blocks_simulation()) return true;
    auto event=state_.state.prepare_entry(cell,heading==0?session_.journey.heading:heading,session_.wagons,session_.network,data_,after_spy);
    if(event.empty()) return state_.state.ending==Ending::None&&before_fauna(cell);
    if(event.reverse) emit(ActionKind::Reverse);
    present(std::move(event));return true;
}
bool Controller::station(int index) {
    auto event=state_.state.station(index,session_.network);if(event.empty()) return false;present(std::move(event));return true;
}
void Controller::set_presentation(Scene scene,Lines lines,bool code,bool question) {
    if(state_.presentation.scene==Scene::SunRestored) emit(ActionKind::FinaleAudioStop);
    state_.presentation={true,scene,std::move(lines),"",code,question,{}};
}
void Controller::present(Pending event) {
    state_.state.pending=std::move(event);const auto& e=state_.state.pending;
    if(e.scene==Scene::SabotageConfirm) {
        const auto& spy=state_.state.spies[e.spy];
        if(spy[0]==2||spy[13]>99) {state_.state.dismiss();emit(ActionKind::Quarters);return;}
    }
    session_.engine.brake=true;session_.engine.speed=0;session_.calendar.factor=1;session_.paused=true;
    state_.page=0;state_.notice=false;
    switch(e.scene) {
    case Scene::Urga:emit(ActionKind::SceneAudio,0xea,"scene3");break;
    case Scene::Mausoleum:emit(ActionKind::SceneAudio,0x16b,"scene3");break;
    case Scene::WhaleQuestion:emit(ActionKind::SceneAudio,0x17a,"scene3");break;
    case Scene::WhaleHarpoon:emit(ActionKind::SceneAudio,0x189,"scene3");break;
    case Scene::Wolf:emit(ActionKind::SceneAudio,0xa1,"scene1");break;
    case Scene::Slope:emit(ActionKind::SceneAudio,0xb0,"scene1");break;
    case Scene::Death:emit(ActionKind::SceneAudio,0,"loss");break;
    default:break;
    }
    show_page();
}
void Controller::show_page() {
    auto& e=state_.state.pending;
    if(e.scene==Scene::Oslo&&e.code_input&&state_.page+1==e.messages.size()&&!e.quiz_done) {begin_quiz(QuizKind::Viking,-1,true);return;}
    if(e.scene==Scene::ManualQuiz) {set_presentation(Scene::ManualQuiz,data_.quiz_lines(*e.quiz),true);return;}
    Lines lines;
    if(e.scene==Scene::SabotageConfirm) lines={"ORDER THIS SPY TO USE DYNAMITE HERE?"};
    else if(e.scene==Scene::Wolf||e.scene==Scene::Mole) {
        if(state_.page>std::size_t(e.applied)) {
            e.ambush_lines=state_.page==1?human_losses(session_.wagons,e.divisor,data_):material_losses(e.scene==Scene::Wolf,session_.wagons,session_.engine,e.divisor,data_,random_);
            e.applied=int(state_.page);emit(ActionKind::CargoChanged);
        }
        lines=e.ambush_lines;
    } else if(e.epitaph&&e.scene==Scene::Death) lines=data_.message(e.epitaph,true);
    else if(state_.page<e.messages.size()) lines=data_.message(e.messages[state_.page]);
    set_presentation(e.scene,std::move(lines),e.code_input&&state_.page+1==e.messages.size(),e.scene==Scene::WhaleQuestion||e.scene==Scene::SpyPickup||e.scene==Scene::SabotageConfirm);
}
void Controller::process() {
    if(!blocks_simulation()||(state_.presentation.scene==Scene::SunRestored&&state_.finale.tick<361)) return;
    if(state_.notice) {state_.presentation={};state_.notice=false;return_to_room();return;}
    if(++state_.page<state_.state.pending.messages.size()) {show_page();return;}
    auto event=state_.state.dismiss();state_.page=0;
    if(event.scene==Scene::Wolf) state_.state.fauna.relocate(random_);
    if(event.departure_chime) emit(ActionKind::DepartureChime,3);
    if(event.scene==Scene::Sun) {
        set_presentation(Scene::SunRestored,{});state_.finale.start(host_.finale_seed());
        state_.state.pending.scene=Scene::SunEnd;emit(ActionKind::FinaleAudioStart);return;
    }
    if(event.scene==Scene::Death) {set_presentation(Scene::Earth,{});state_.state.pending.scene=Scene::Earth;return;}
    if(event.scene==Scene::Earth||event.scene==Scene::SunEnd) {
        if(event.scene==Scene::SunEnd) emit(ActionKind::FinaleAudioStop);
        state_.presentation={};emit(ActionKind::Options);return;
    }
    state_.presentation={};if(host_.at_station()) emit(ActionKind::Depart);session_.paused=false;emit(ActionKind::Cabin);
}
void Controller::answer(bool proceed) {
    auto& model=state_.state;Scene scene=model.pending.scene;
    if(scene==Scene::SabotageConfirm) {
        if(proceed) model.sabotage(model.pending.spy,session_.network);
        model.dismiss();state_.page=0;state_.presentation={};session_.paused=false;emit(ActionKind::Quarters);return;
    }
    if(scene==Scene::SpyPickup) {
        model.retrieve_spy(model.pending.spy,proceed,trade_);model.dismiss();state_.page=0;
        state_.presentation={};session_.paused=false;emit(ActionKind::Cabin);return;
    }
    if(scene!=Scene::WhaleQuestion) return;
    auto event=model.choose_whale(proceed);
    if(proceed) present(std::move(event));else {state_.presentation={};session_.paused=false;emit(ActionKind::Cabin);}
}
bool Controller::before_city(int city) {
    if(blocks_simulation()) return true;
    if(!((city>=5&&city<=9)||city==12)) return false;
    const auto name=city==12?QuizKind::Viking:QuizKind::Soleil;
    if(state_.state.protection_seen[int(name)]) return false;
    if(name==QuizKind::Soleil) state_.state.protection_seen[int(name)]=true;
    begin_quiz(name,city);return true;
}
void Controller::begin_quiz(QuizKind kind,int city,bool oslo) {
    Pending event;event.scene=Scene::ManualQuiz;event.messages={54};event.quiz=Quiz{kind,random_.range(0,7),0,city,oslo};present(std::move(event));
}
void Controller::submit_quiz(std::string_view text) {
    auto& q=*state_.state.pending.quiz;const auto& records=data_.quizzes[int(q.kind)];
    if(records.size()!=8) return;std::string upper(text);
    for(char& c:upper) c=char(std::toupper(static_cast<unsigned char>(c)));
    if(upper.starts_with(records[q.index].answer)) {
        const auto resume=q;state_.state.dismiss();state_.page=0;
        if(resume.resume_city>=0) {state_.state.protection_seen[int(resume.kind)]=true;state_.presentation={};emit(ActionKind::ResumeCity,resume.resume_city);}
        else {Pending next;next.scene=Scene::Oslo;next.messages={90};next.code_input=true;next.quiz_done=true;present(std::move(next));}
    } else {
        if(++q.attempt>=3) {emit(ActionKind::Quit);return;}
        q.index=random_.range(0,7);set_presentation(Scene::ManualQuiz,data_.quiz_lines(q),true);
    }
}
void Controller::submit_code(std::string_view text) {
    if(state_.state.pending.scene==Scene::ManualQuiz) {submit_quiz(text);return;}
    if(state_.state.submit_code(text)) {emit(ActionKind::EffectAudio,0x13e,"scene4");state_.page=0;show_page();}
    else {state_.presentation.lines=data_.message(63);state_.presentation.input_code.clear();}
}
void Controller::input(std::string_view value) {
    auto& p=state_.presentation;if(!p.entering_code) return;
    for(unsigned char c:value) {
        if(p.scene==Scene::ManualQuiz) {c=static_cast<unsigned char>(std::toupper(c));if(c>='A'&&c<='Z'&&p.input_code.size()<8) p.input_code+=char(c);}
        else if(c>='0'&&c<='9'&&p.input_code.size()<5) p.input_code+=char(c);
    }
}
void Controller::backspace() {auto& p=state_.presentation;if(p.entering_code&&!p.input_code.empty()) p.input_code.pop_back();}
void Controller::die(int reason) {auto event=state_.state.die(reason);if(!event.empty()) present(std::move(event));}
bool Controller::present_engine_event() {
    if(!session_.engine.event_pending||!state_.state.pending.empty()||state_.state.ending!=Ending::None) return false;
    if(session_.engine.event_message=="Boiler overload") {die(102);return true;}
    if(session_.engine.event_message=="No coal remaining") {die(101);return true;}
    return false;
}
bool Controller::before_fauna(Cell cell) {
    auto& s=state_.state;s.fauna.initialize(random_);
    if(s.fauna.presence(cell)) {ambush(true);return true;}
    if(s.hazards.player_mole(cell,session_.calendar,random_)) {ambush(false);return true;}
    return false;
}
void Controller::ambush(bool wolf) {
    auto defense=defenders(session_.wagons,data_);Pending event;event.scene=wolf?Scene::Wolf:Scene::Mole;
    event.messages=wolf?std::vector<int>{77,81,79}:std::vector<int>{78,81,80};event.divisor=defense.divisor;
    event.ambush_lines=data_.message(wolf?77:78);event.ambush_lines.insert(event.ambush_lines.end(),defense.lines.begin(),defense.lines.end());present(std::move(event));
}
Cell Controller::initialize_fauna() {state_.state.fauna.initialize(random_);return state_.state.fauna.cell;}
void Controller::advance_spies() {
    auto& s=state_.state;if(!s.pending.empty()||s.ending!=Ending::None||blocks_simulation()) return;
    s.sync_recruits(trade_);s.advance_spies(session_.network,trade_);
}
bool Controller::advance_cycle() {advance_spies();return advance_fauna();}
bool Controller::advance_fauna() {
    auto& s=state_.state;if(!s.pending.empty()||s.ending!=Ending::None||blocks_simulation()) return false;
    s.fauna.initialize(random_);s.fauna.record_player(session_.journey.position,session_.network);
    if(s.fauna.advance(session_.network,random_,s.hazards)) {
        s.observe_enemy(59,s.fauna.cell,session_.calendar);
        if(s.fauna.presence(session_.journey.position)) {ambush(true);return true;}
    }
    return false;
}
void Controller::advance(double seconds) {if(state_.presentation.visible&&state_.presentation.scene==Scene::SunRestored&&state_.finale.tick<361&&state_.finale.advance(seconds)) process();}
bool Controller::quarters_scene() const {auto s=state_.presentation.scene;return s==Scene::Crew||s==Scene::None||s==Scene::SpyPickup||s==Scene::SabotageConfirm;}
bool Controller::restore(const Snapshot& snapshot) {
    if(!snapshot.valid()) return false;
    state_=snapshot;const auto tick=state_.finale.tick;const auto remainder=state_.finale.remainder;
    state_.finale.start(snapshot.finale.seed);state_.finale.tick=tick;state_.finale.remainder=remainder;actions_.clear();
    if(state_.presentation.visible&&state_.presentation.scene==Scene::SunRestored&&state_.finale.tick<361)
        emit(ActionKind::FinaleAudioStart,0,{},(state_.finale.tick+state_.finale.remainder)/50);
    return true;
}
}
