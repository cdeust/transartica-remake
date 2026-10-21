// SPDX-License-Identifier: MIT
// Integration oracles: main.gd:_open_city/_advance_calendar, journey_session.gd,
// world_session.gd, world_encounters.gd, spy_report.gd. No UI or device required.
#include "app/game_session.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <iostream>
#include <sstream>
#include <stdexcept>
using namespace transartica;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label) {++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}}
struct Fixture {
    Session core;GameSession game;
    explicit Fixture(const std::filesystem::path& path):game(core) {
        std::string error;
        if(!core.load_world(path/"data/CARTE.FIC",error)||!game.load(path,error)) throw std::runtime_error(error);
        reset();
    }
    void reset() {game.random.seed(7);game.encounter_random.seed(19);game.visual_random.seed(23);game.reset();}
    void isolate() {
        if(!game.roamers.restore({})) throw std::runtime_error("Cannot isolate roamers");
        auto state=game.campaign.snapshot();state.state.fauna.oslo();
        if(!game.campaign.restore(state)) throw std::runtime_error("Cannot isolate fauna");
    }
};
void reset_order(Fixture& fixture) {
    fixture.reset();auto& game=fixture.game;
    Random expected;expected.seed(7);auto trade=game.trade;trade.reset(expected);
    world::WorldRoamers movers;campaign::Fauna fauna;
    movers.initialize(expected,[&](Random& random){fauna.initialize(random);return fauna.cell;});
    check(game.random==expected&&game.trade.snapshot()==trade.snapshot(),"START trade draws precede shared world initialization");
    check(game.roamers.snapshot()==movers.snapshot()&&game.campaign.model().fauna==fauna,"START initializes ten herds then fauna then distinct nomads");
    Random encounter,visual;encounter.seed(19);visual.seed(23);
    check(game.encounter_random==encounter&&game.visual_random==visual,"START shared initialization leaves encounter/visual RNG independent");
    game.open_city(45);game.workshop=true;game.works.inform(16);game.report=combat::AutomaticResult{};game.pending_enemy=0;
    game.reset();
    check(game.city==-1&&!game.workshop&&!game.works.active()&&!game.report&&!game.tactical&&game.pending_enemy==-1,"restart clears all blocking runtime owners");
    check(game.world.snapshot().visited_cities.empty()&&game.campaign.model().ending==campaign::Ending::None&&!game.core.paused,"restart clears visits, ending and pause");
    check(game.core.wagons==initial_wagons()&&game.core.network.tiles()==game.core.network.initial_tiles(),"restart restores original train and map");
    check(game.take_actions().empty(),"restart discards stale transition actions");
}
void cities(Fixture& fixture) {
    fixture.reset();auto& game=fixture.game;auto expected=game.random;
    const int stock=5+expected.below(40);game.open_city(45);
    check(game.city==45&&game.core.paused&&game.blocks_simulation(),"nomad city uses sole trade/session owner");
    check(game.random==expected&&game.trade.snapshot().stock[21][3]==stock,"nomad arrival rerolls source stock once");
    const auto trade=game.trade.snapshot();const auto random=game.random;
    for(int i=0;i<3;++i) {game.advance(1.0/60);game.take_actions();}
    check(game.trade.snapshot()==trade&&game.random==random,"city display and action polling cannot reroll stock");
    check(game.world.snapshot().visited_cities==std::vector<int>{45},"visit ledger contains each city once");
    fixture.reset();game.open_city(5);
    check(game.city==-1&&game.campaign.presentation().scene==campaign::Scene::ManualQuiz&&game.world.snapshot().visited_cities.empty(),"copy protection gates arrival before city visit");
    const auto quiz=*game.campaign.model().pending.quiz;
    game.campaign.submit_code(game.campaign.data().quizzes[int(quiz.kind)][quiz.index].answer);
    game.take_actions();
    check(game.city==5&&game.world.snapshot().visited_cities==std::vector<int>{5},"correct manual answer resumes city exactly once");
}
void station_departure(Fixture& fixture) {
    fixture.reset();fixture.isolate();auto& game=fixture.game;auto& core=fixture.core;
    // Source TIME station35 at32,67; owner-approved hidden city emergence.
    core.journey.position={31,67};core.journey.heading=6;core.journey.incoming_heading=6;
    core.journey.blocked=true;core.journey.stop_reason="station";core.journey.phase=2;core.journey.seed_path(core.network);
    core.paused=true;game.city=24;const auto count=core.wagons.size();
    check(game.depart()&&core.journey.heading==4&&core.journey.position==Cell{31,67},"station departure reverses through source hidden emergence");
    check(!core.journey.blocked&&!core.paused&&core.engine.speed==0&&game.city==-1&&core.wagons.size()==count,"departure shares train, clears modal and leaves speed zero");
    auto actions=game.take_actions();
    check(std::count_if(actions.begin(),actions.end(),[](const auto& action){return action.kind==campaign::ActionKind::DepartureChime;})==1,"departure emits one source chime");
}
void closed_bridge(Fixture& fixture) {
    fixture.reset();fixture.isolate();auto& game=fixture.game;auto& core=fixture.core;
    // main.gd::_reverse_at_event: TEXTEK52, brake, hidden emergence; no user reverse.
    check(core.network.tile({110,33})==-120,"real timed bridge begins closed");
    core.journey.position={109,33};core.journey.heading=6;core.journey.incoming_heading=6;
    core.journey.phase=2;core.journey.distance_ticks=22;core.journey.seed_path(core.network);
    core.engine.speed=300;core.engine.regulator=300;core.engine.pressure_reserve=32000;
    game.advance(1);
    check(game.works.stage==WorkStage::Information&&game.works.information==52,"closed bridge opens source TEXTEK52");
    check(core.engine.brake&&core.engine.speed==0&&game.blocks_simulation(),"closed bridge brakes shared train and suspends simulation");
    check(core.journey.position==Cell{109,33}&&core.journey.heading==4&&!core.journey.blocked
        &&!core.journey.reversing&&core.journey.render_path.empty()&&core.journey.history_starts_in_station(core.network),
        "closed bridge uses hidden station emergence without a reverse convoy path");
    const auto cycles=core.engine.cycles;game.advance(1);
    check(core.engine.cycles==cycles,"bridge message blocks subsequent engine cycles");
    game.finish_works();
    check(!game.works.active()&&core.engine.brake&&core.engine.speed==0&&core.journey.heading==4,
        "bridge message dismissal preserves brake and completed emergence");
}
void works(Fixture& fixture) {
    fixture.reset();fixture.isolate();auto& game=fixture.game;auto& core=fixture.core;
    check(core.network.tile({83,67})==67,"real default route crevasse fixture");
    core.journey.position={82,67};core.journey.heading=6;core.journey.incoming_heading=6;
    core.journey.blocked=true;core.journey.stop_reason="obstacle";core.journey.phase=2;core.journey.seed_path(core.network);
    core.wagons.push_back({17,0,1,20});core.wagons.push_back({5,0,0,15});game.cargo_changed();
    check(game.works.ask(core.network,{83,67}),"source work question opens at refused cell");
    const int before=rails_carried(core.wagons);auto expected=game.random;const int cost=20-expected.below(5);
    game.answer_works(true);
    check(game.works.stage==WorkStage::Report&&rails_carried(core.wagons)==before-cost&&game.random==expected,"accept charges source rail cost once using shared RNG");
    check(core.network.tile({83,67})==67,"paid report leaves obstacle intact until dismissal");
    const int countdown=game.works.countdown;game.advance(1.0/48);
    check(game.works.countdown==countdown-1,"work text uses one raw scheduler tick despite factor3");
    const auto wagons=core.wagons;const auto random=game.random;game.answer_works(true);
    check(core.wagons==wagons&&game.random==random,"repeated accept cannot double-charge work report");
    game.finish_works();
    check(core.network.tile({83,67})==63&&!game.works.active()&&!core.journey.blocked,"dismiss repairs exact source track and releases refused entry");
    game.finish_works();check(core.network.tile({83,67})==63&&core.wagons==wagons,"repeated dismissal cannot spend or change completed repair");
}
void campaign_entry(Fixture& fixture) {
    fixture.reset();fixture.isolate();auto& game=fixture.game;auto& core=fixture.core;
    core.journey.position={10,10};core.journey.heading=6;core.journey.incoming_heading=6;core.journey.seed_path(core.network);
    core.engine.speed=300;core.engine.regulator=300;core.engine.pressure_reserve=32000;
    game.advance(1);
    check(game.campaign.model().pending.empty(),"standing beside whale does not trigger before strict entry phase");
    core.journey.phase=2;core.journey.distance_ticks=22;game.advance(1);
    check(game.campaign.presentation().scene==campaign::Scene::WhaleQuestion&&core.journey.position==Cell{10,10},"due entry invokes campaign whale gate before advancing train");
    const auto cycles=core.engine.cycles;game.advance(1);
    check(core.engine.cycles==cycles&&game.blocks_simulation(),"campaign modal suspends shared engine callbacks");
}
void mover_codes_and_order(Fixture& fixture) {
    fixture.reset();auto& game=fixture.game;auto& core=fixture.core;
    const auto moving=game.roamers.snapshot();
    for(int i=0;i<10;++i) {const auto info=game.mover_info(40+i);check(info&&info->heading==moving.herds[i].heading&&info->quantity==moving.herds[i].quantity,"spy report herd code40..49");}
    const auto wolf=game.mover_info(60),nomad=game.mover_info(70);
    check(wolf&&wolf->heading==game.campaign.model().fauna.heading&&nomad&&nomad->heading==moving.nomad.heading,"spy report wolf60 and nomad70");
    for(int invalid:{39,50,51,61,62,71}) check(!game.mover_info(invalid),"unassigned mover report code refused");
    auto roamers=moving;for(auto& herd:roamers.herds) herd.quantity=0;
    roamers.herds[0]={core.journey.position.x-40,core.journey.position.y,0,6,40,20};roamers.nomad={149,1,0,6,0};
    check(game.roamers.restore(roamers),"stage source herd at stationary player");
    auto campaign=game.campaign.snapshot();campaign.state.fauna.counter=0;campaign.state.fauna.phase=0;
    auto& spy=campaign.state.spies[0];spy[0]=2;spy[1]=-30;spy[2]=10;spy[3]=-29;spy[4]=10;spy[5]=0;
    check(game.campaign.restore(campaign),"stage travelling spy and fauna callback");
    const auto fauna=game.campaign.model().fauna;game.advance(1);
    check(game.campaign.model().spies[0][5]==1,"calendar spy callback precedes same-cell roamer encounter");
    check(game.roamers.snapshot().pending=="herd_question"&&game.campaign.model().fauna==fauna,"roamer encounter returns before fauna movement");
    check(core.calendar.minute==3&&core.paused&&core.engine.brake,"roamer modal retains already-advanced calendar and brakes shared engine");
}
void hunt_text_cadence(Fixture& fixture) {
    fixture.reset();auto& game=fixture.game;
    auto state=game.roamers.snapshot();for(auto& herd:state.herds) herd.quantity=0;
    state.herds[0]={fixture.core.journey.position.x-40,fixture.core.journey.position.y,0,6,40,20};
    check(game.roamers.restore(state),"stage actual same-cell hunt source state");
    check(game.roamers.encounter(fixture.core.journey.position,fixture.core.network,game.random)=="herd_question","source hunt encounter opens question");
    game.answer_world(true);game.continue_world();
    check(game.roamers.snapshot().pending=="hunt_result"&&fixture.core.calendar.factor==3,"hunt result enters source accelerated calendar mode");
    game.advance(1.0/48);
    check(game.roamers.snapshot().countdown==23,"hunt text scheduler consumes one raw tick, independent of calendar factor");
}
void callback_cadence(const std::filesystem::path& path) {
    std::string reference;world::RoamerState reference_roamers;campaign::Snapshot reference_campaign;Random reference_random,reference_encounter;
    for(int rate:{30,60,144}) {
        Fixture fixture(path);fixture.core.engine.lignite_rate=1;
        for(int frame=0;frame<12*rate;++frame) fixture.game.advance(1.0/rate);
        check(fixture.core.engine.cycles==12&&fixture.core.calendar.minute==36,"shared callback cadence at "+std::to_string(rate)+"Hz");
        // IEEE754 binary64: each addition/subtraction here has magnitude below
        // two, so its absolute rounding error is at most epsilon. Bound by the
        // number of additions plus cycle subtractions, not a gameplay epsilon.
        const double roundoff=(12*rate+12)*std::numeric_limits<double>::epsilon();
        check(std::abs(fixture.core.accumulator)<=roundoff,"continuous clock remains within arithmetic roundoff at "+std::to_string(rate)+"Hz");
        auto discrete=fixture.core;discrete.accumulator=0;
        std::ostringstream out;check(discrete.write_snapshot(out),"cadence result is a valid core save");
        if(reference.empty()) {reference=out.str();reference_roamers=fixture.game.roamers.snapshot();reference_campaign=fixture.game.campaign.snapshot();reference_random=fixture.game.random;reference_encounter=fixture.game.encounter_random;}
        else {
            const bool core_equal=out.str()==reference,roamers_equal=fixture.game.roamers.snapshot()==reference_roamers,
                campaign_equal=fixture.game.campaign.snapshot()==reference_campaign,random_equal=fixture.game.random==reference_random,
                encounter_equal=fixture.game.encounter_random==reference_encounter;
            if(!(core_equal&&roamers_equal&&campaign_equal&&random_equal&&encounter_equal)) {
                std::cerr<<"cadence diagnostic "<<rate<<"Hz: core="<<core_equal<<" roamers="<<roamers_equal
                    <<" campaign="<<campaign_equal<<" shared_rng="<<random_equal<<" encounter_rng="<<encounter_equal
                    <<" accumulator="<<std::hexfloat<<fixture.core.accumulator<<std::defaultfloat<<'\n';
                if(!core_equal) {
                    std::istringstream expected(reference),actual(out.str());std::string a,b;int line=0;
                    while(std::getline(expected,a)&&std::getline(actual,b)) {++line;if(a!=b) {
                        std::cerr<<"core snapshot first difference line "<<line<<"\nexpected: "<<a.substr(0,300)
                            <<"\nactual: "<<b.substr(0,300)<<'\n';break;
                    }}
                }
                if(!roamers_equal) std::cerr<<"roamer source states differ\n";
                if(!campaign_equal) std::cerr<<"campaign source states differ\n";
                if(!random_equal) std::cerr<<"shared RNG expected "<<reference_random.state<<", actual "<<fixture.game.random.state<<'\n';
                if(!encounter_equal) std::cerr<<"encounter RNG expected "<<reference_encounter.state<<", actual "<<fixture.game.encounter_random.state<<'\n';
            }
            check(core_equal&&roamers_equal&&campaign_equal&&random_equal&&encounter_equal,"identical complete model and RNG across display rates");
        }
    }
}
}
int main(int argc,char** argv) {
    if(argc!=2) {std::cerr<<"usage: game_session_tests <game-directory>\n";return 2;}
    try {Fixture fixture(argv[1]);reset_order(fixture);cities(fixture);station_departure(fixture);closed_bridge(fixture);works(fixture);campaign_entry(fixture);mover_codes_and_order(fixture);hunt_text_cadence(fixture);callback_cadence(argv[1]);std::cout<<checks<<" GameSession integration checks, "<<failures<<" failures\n";return failures?1:0;}
    catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
