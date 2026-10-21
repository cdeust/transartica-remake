// SPDX-License-Identifier: MIT
// Oracles: game/tests/test_campaign.gd, test_campaign_fauna.gd and source
// manual_quiz.gd / inspection_car.gd / finale_sequence.gd. No renderer required.
#include "campaign/controller.hpp"
#include <algorithm>
#include <cctype>
#include <iostream>
#include <limits>
#include <stdexcept>
using namespace transartica;
using namespace transartica::campaign;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label){++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
struct TestHost final:Host {
    bool station{};int target=-1;Cell target_cell{-1,-1};EnemyInfo enemy{2,6,369};int damage_calls{};
    bool at_station() const override{return station;}
    int enemy_at(Cell c) const override{return c==target_cell?target:-1;}
    std::optional<EnemyInfo> enemy_info(int slot) const override{return slot==target?std::optional<EnemyInfo>{enemy}:std::nullopt;}
    void set_enemy_damage(int,int kind,int strength) override{enemy.kind=kind;enemy.strength=strength;++damage_calls;}
    std::optional<MoverInfo> mover_info(int code) const override{return code==40?std::optional<MoverInfo>{{6,29}}:std::optional<MoverInfo>{{4,0}};}
    Lines mine_report(int index,const std::map<std::string,std::string>&) const override{return {std::to_string(index)};}
    std::uint64_t finale_seed() override{return 7;}
};
struct Fixture {
    Session session;economy::Trade trade;economy::WorldData world;Random random;TestHost host;Controller controller;
    explicit Fixture(const std::filesystem::path& path):controller(session,trade,world,random,host){
        std::string error;random.seed(7);
        if(!session.load_world(path/"CARTE.FIC",error)||!trade.load(path,error)||!world.load(path,error)||!controller.load(path,error))throw std::runtime_error(error);
        trade.reset(random);session.network.campaign_entry_enabled=true;
    }
};
void state_rules(Fixture& f){
    const auto& data=f.controller.data();auto& net=f.session.network;State s;
    check(data.message(100,true).size()==10,"source epitaph100 ten lines");
    auto monster=data.message(104,true);check(std::any_of(monster.begin(),monster.end(),[](const auto& line){return line.find("MONSTER")!=std::string::npos;}),"whale epitaph from private table");
    s.station(-3,net);check(!s.submit_code("58947"),"Oslo rejects keyless code");s.dismiss();
    check(s.station(-2,net).messages==std::vector<int>({86,87})&&s.urga_key,"first Urga yields key and two pages");s.dismiss();
    check(s.station(-2,net).messages==std::vector<int>({88}),"repeat Urga page");s.dismiss();s.station(-3,net);
    check(!s.submit_code("58947"),"manual quiz cannot be bypassed with valid code");s.pending.quiz_done=true;
    check(!s.submit_code("59847")&&!s.delivery_open,"incorrect digits preserve locked delivery");
    check(s.submit_code("58947")&&s.delivery_open&&s.pending.departure_chime&&s.fauna.frozen&&s.stoup.entries==std::vector<int>{126},"correct source code freezes Oslo wolf and pushes SOS once");
    s.dismiss();s.station(-3,net);s.pending.quiz_done=true;check(s.submit_code("58947")&&!s.pending.departure_chime&&s.stoup.entries.size()==1,"repeated code neither repeats SOS nor chime");
    s.dismiss();check(s.station(-4,net).messages==std::vector<int>{51},"mausoleum document");s.dismiss();
    check(s.station(-5,net).scene==Scene::Sun&&s.ending==Ending::Sun,"Sun ending station");
    for(int reason=100;reason<=105;++reason){State dead;check(dead.die(reason).epitaph==reason&&dead.ending==Ending::Death,"source death reason "+std::to_string(reason));}
}
void entry_rules(Fixture& f){
    State s;auto wagons=initial_wagons();auto& net=f.session.network;const auto& data=f.controller.data();
    check(s.prepare_entry({11,10},6,wagons,net,data).scene==Scene::WhaleQuestion,"unarmed whale question");
    s.choose_whale(false);check(s.ending==Ending::None&&s.whale_present,"declining whale stays alive");
    wagons.push_back({9,3,0,0});check(s.prepare_entry({11,10},6,wagons,net,data).scene==Scene::WhaleQuestion,"destroyed harpoon cannot kill whale");s.dismiss();wagons.back().state=2;
    auto whale=s.prepare_entry({11,10},6,wagons,net,data);check(whale.scene==Scene::WhaleHarpoon&&whale.reverse&&!s.whale_present,"intact harpoon kills whale and requests reversal");s.dismiss();
    check(s.prepare_entry({11,10},6,wagons,net,data).empty(),"whale interception is one-shot");
    check(s.prepare_entry({152,48},1,wagons,net,data).scene==Scene::Slope,"long consist requires boiler at source slope");s.dismiss();wagons.push_back({25,3,0,0});
    check(s.prepare_entry({152,48},1,wagons,net,data).empty(),"slope source checks boiler type even destroyed");
}
void spy_rules(Fixture& f){
    State s;auto wagons=initial_wagons();wagons.push_back({22,0,0,1});f.trade.set_spy_slot(0,1);s.sync_recruits(f.trade);
    check(s.send_spy({65,20},{64,20},wagons,f.trade)==0&&wagons.back().quantity==0&&f.trade.snapshot().spy_slots[0]==2,"send spy consumes one recruit and shares travel state");
    check(s.advance_spies(f.session.network,f.trade).empty()&&s.advance_spies(f.session.network,f.trade).empty(),"spy waits two callbacks");
    check(s.advance_spies(f.session.network,f.trade)==std::vector<int>{0}&&s.spies[0][0]==3,"third callback posts spy");
    check(f.session.network.tile({65,20})==-124&&f.session.network.tile({64,20})==-124&&s.stoup.entries==std::vector<int>{127},"central discovery changes paired tiles and bulletin");
    check(s.sabotage(0,f.session.network)&&s.central_destroyed&&s.stoup.entries.back()==125&&!s.sabotage(0,f.session.network),"central sabotage is once until refusal clears marker");
    s.retrieve_spy(0,false,f.trade);check(s.spies[0][0]==3&&s.spies[0][13]<100,"decline pickup clears sabotage marker");
    check(s.retrieve_spy(0,true,f.trade)&&s.spies[0][0]==1&&f.trade.snapshot().spy_slots[0]==1&&wagons.back().quantity==0,"pickup resets record without adding cargo quantity");
    Stoup stoup;for(int i=1;i<=12;++i)stoup.push(i);check(stoup.entries.size()==10&&stoup.entries.front()==3&&stoup.pop()==12,"ten-entry LIFO drops oldest");
}
void quiz_rules(Fixture& f){
    auto& c=f.controller;c.reset();check(!c.before_city(4)&&c.before_city(5),"Soleil gate city5 only on entry");
    check(c.model().protection_seen[0]&&!c.model().protection_seen[1],"Soleil flag set before questionnaire");
    c.input("a1BcDEFGHI");check(c.presentation().input_code=="ABCDEFGH","manual input letters and eight-char limit");c.backspace();check(c.presentation().input_code=="ABCDEFG","manual backspace");
    c.submit_code("ZZZZZZZZ");check(c.model().pending.quiz->attempt==1,"wrong answer increments attempt");
    auto q=*c.model().pending.quiz;auto answer=c.data().quizzes[int(q.kind)][q.index].answer;
    std::transform(answer.begin(),answer.end(),answer.begin(),[](unsigned char x){return char(std::tolower(x));});c.submit_code(answer);
    auto actions=c.take_actions();check(!c.blocks_simulation()&&std::any_of(actions.begin(),actions.end(),[](const Action& a){return a.kind==ActionKind::ResumeCity&&a.value==5;}),"successful manual answer resumes exact city before visit");
    check(!c.before_city(6)&&c.before_city(12)&&!c.model().protection_seen[1],"Soleil shared flag and separate Viking pending flag");
    for(int i=0;i<3;++i)c.submit_code("ZZZZZZZZ");actions=c.take_actions();check(std::any_of(actions.begin(),actions.end(),[](const Action& a){return a.kind==ActionKind::Quit;}),"third wrong answer emits quit");
    c.reset();c.station(-2);c.process();c.process();c.station(-3);c.process();
    check(c.presentation().scene==Scene::ManualQuiz&&c.model().pending.quiz->resume_oslo,"Oslo manual before code");
    q=*c.model().pending.quiz;c.submit_code(c.data().quizzes[int(q.kind)][q.index].answer);
    check(c.presentation().scene==Scene::Oslo&&c.model().pending.quiz_done,"manual restores Oslo code scene");
    c.input("a58947b0");check(c.presentation().input_code=="58947","Oslo input only five digits");c.submit_code(c.presentation().input_code);
    check(c.model().delivery_open&&c.presentation().lines==c.data().message(91),"Oslo delivery after both gates");
}
void fauna_rules(Fixture& f){
    RailNetwork net;std::string error;check(net.load_bytes(std::vector<std::uint8_t>(160*73,2),error),"straight fixture map");
    Fauna fauna;fauna.initialize(f.random);fauna.cell={40,40};Hazards hazards;
    for(int i=0;i<5;++i)check(!fauna.advance(net,f.random,hazards),"wolf no commit before callback six");
    check(fauna.advance(net,f.random,hazards)&&fauna.cell==Cell{41,40},"wolf two callbacks per phase");
    fauna.oslo();for(int i=0;i<12;++i)fauna.advance(net,f.random,hazards);check(fauna.cell==Cell{126,15}&&fauna.phase==0,"Oslo wolf frozen");
    fauna.phase=1;check(!fauna.valid(),"frozen invalid phase rejected");
    hazards.mole_times[0]=-1;auto before=f.random;
    check(hazards.player_mole({50,44},f.session.calendar,f.random)&&f.random!=before,"forced mole still consumes RNG");
    check(!hazards.player_mole({50,44},f.session.calendar,f.random),"same clock mole cooldown");
}
void ambush_rules(Fixture& f){
    auto& c=f.controller;c.reset();auto s=c.snapshot();s.state.fauna.oslo();check(c.restore(s),"stage source Oslo ambush");
    f.session.wagons={{1,0,0,0},{21,0,0,0},{2,0,0,0},{3,0,0,0},{7,0,0,5},{23,0,0,40},{17,0,11,9}};
    check(c.before_entry({126,15})&&c.presentation().scene==Scene::Wolf&&f.session.wagons[5].quantity==40,"wolf first page precedes losses");
    c.process();auto human=f.session.wagons;s=c.snapshot();check(s.page==1&&s.state.pending.applied==1&&human[5].quantity<40,"second page applies human loss");
    std::string error;Snapshot parsed;auto encoded=serialize_snapshot(s);check(parse_snapshot(encoded,parsed,error)&&parsed==s,"interrupted ambush strict JSON roundtrip");
    check(c.restore(parsed)&&f.session.wagons==human,"restore does not reapply loss");c.process();
    check(f.session.wagons[6].quantity==5&&c.snapshot().page==2,"third page halves food once");
    auto good=c.snapshot(),bad=good;bad.state.pending.applied=1;check(!c.restore(bad)&&c.snapshot()==good,"mismatched applied loss rejected atomically");
    c.process();check(c.model().pending.empty()&&!c.model().fauna.frozen,"last page relocates wolf");
    s=c.snapshot();s.state.hazards.mole_times[0]=-1;check(c.restore(s)&&c.before_entry({50,44}),"forced mole enters actual controller");c.process();int anthracite=f.session.engine.anthracite;c.process();
    check(f.session.engine.anthracite<anthracite&&f.session.wagons[4].state==3,"mole burns coal and destroys first eligible wagon");
    auto wagons=std::vector<Wagon>{{7,0,0,12},{5,0,0,7},{23,0,0,9}};auto report=human_losses(wagons,2,c.data());
    check(wagons[0].quantity==6&&wagons[1].quantity==4&&wagons[2].quantity==5&&report.back().ends_with("3"),"source mammoth reduced-quantity report preserved");
}
void inspection_rules(Fixture& f){
    Session s;std::string error;s.network.load_bytes(std::vector<std::uint8_t>(160*73,2),error);s.network.campaign_entry_enabled=true;s.journey.position={23,4};
    s.wagons={{17,0,3,2},{17,0,2,1}};State state;TestHost host;
    auto result=inspect(s,state,f.random,host,6,false);
    check(result.obstacle&&result.cell==Cell{24,4}&&s.network.tile({24,4})==-2&&state.hazards.traps[0]==0&&s.wagons[0].quantity==1,"inspection reveals trap and consumes car");
    s.journey.position={40,40};s.wagons={{17,0,3,1},{17,0,2,1}};host.target=0;host.target_cell={41,40};
    result=inspect(s,state,f.random,host,6,true);check(result.obstacle&&host.damage_calls==1&&host.enemy.kind==5&&host.enemy.strength==346&&s.wagons[0].quantity==0&&s.wagons[1].quantity==0,"missile damages source remainder third and consumes cargo");
    host.target=29;host.damage_calls=0;s.wagons={{17,0,3,1},{17,0,2,1}};inspect(s,state,f.random,host,6,true);check(host.damage_calls==0,"inspection missile cannot damage Minotaur slot29");
}
void persistence_rules(Fixture& f){
    f.controller.reset();auto good=f.controller.snapshot();std::string error;auto bytes=serialize_snapshot(good);Snapshot target=good;
    check(parse_snapshot(bytes,target,error)&&target==good,"default campaign roundtrip");
    for(const auto& bad:std::vector<std::string>{"{}",bytes+"x",bytes.substr(0,bytes.size()-1)})check(!parse_snapshot(bad,target,error)&&target==good,"invalid JSON preserves destination");
    auto position=bytes.find("\"page\":0");auto malformed=bytes;malformed.replace(position,8,"\"page\":1.5");check(!parse_snapshot(malformed,target,error)&&target==good,"fractional page rejected");
    auto bad=good;bad.state.spies[0][0]=4;check(!f.controller.restore(bad)&&f.controller.snapshot()==good,"invalid spy state rejected");
    bad=good;bad.state.fauna.history.resize(4);check(!f.controller.restore(bad),"bounded fauna history");
    bad=good;bad.finale.remainder=std::numeric_limits<double>::infinity();check(!f.controller.restore(bad),"nonfinite finale rejected");
}
void finale_rules(Fixture& f){
    Finale a,b;a.start(7);b.start(7);check(a.shot()==36,"source finale starts shot36");
    for(int i=0;i<60;++i)a.advance(1.0/60);for(int i=0;i<144;++i)b.advance(1.0/144);check(a.tick==50&&b.tick==50,"finale source50Hz independent of frame rate");
    a.tick=156;check(a.clouds()==std::array<int,4>{-4,-3,-2,-1},"source cloud speeds after intro35");
    auto& c=f.controller;c.reset();auto rng=f.random;c.station(-5);c.process();check(c.presentation().scene==Scene::SunRestored&&f.random==rng,"ending film uses separate visual RNG");
    c.advance(7.22);auto actions=c.take_actions();check(!c.blocks_simulation()&&std::any_of(actions.begin(),actions.end(),[](const Action& x){return x.kind==ActionKind::Options;}),"361 finale ticks return to options");
}
}
int main(int argc,char** argv){
    if(argc!=2){std::cerr<<"usage: campaign_tests GAME_PRIVATE_DATA_DIRECTORY\n";return 2;}
    try{Fixture f(argv[1]);state_rules(f);entry_rules(f);spy_rules(f);quiz_rules(f);fauna_rules(f);ambush_rules(f);inspection_rules(f);persistence_rules(f);finale_rules(f);
        std::cout<<checks<<" campaign checks, "<<failures<<" failures\n";return failures?1:0;
    }catch(const std::exception& e){std::cerr<<"campaign fixture: "<<e.what()<<'\n';return 2;}
}
