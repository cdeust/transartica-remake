// SPDX-License-Identifier: MIT
// Port of tests/{test_campaign_route,campaign_route_planner,campaign_route_driver}.gd.
// Controller-level laboratory pilot. No SDL input or visible-game claim.
#include "app/game_archive.h"
#include "app/game_archive_codec.h"
#include "app/economy_archive.h"
#include "app/save_archive.h"
#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <sstream>
#include <stdexcept>
#include <tuple>

using namespace transartica;
namespace fs=std::filesystem;
namespace {
void require(bool good,const std::string& why) {if(!good)throw std::runtime_error(why);}
std::string cell_text(Cell c) {return std::to_string(c.x)+","+std::to_string(c.y);}
bool switch_code(int code) {return code>=18&&code<=33;}
struct Action {Cell cell,next;int code{},phase{};bool reverse{},station{};};
using Key=std::tuple<int,int,int>;
Key key(Cell c,int heading,int phase) {return {c.x,c.y,heading+16*(phase+1)};}
struct Parent {Key previous;Action action;};
class Planner {
    const GameSession& g;
    const std::set<Key>& attempted_reversals;
    int code(Cell c) const {
        int value=g.core.network.tile(c);const auto& s=g.campaign.model();
        if(value==-115) {
            const bool hima=c.x>38&&c.x<59&&c.y>19&&c.y<34;
            const bool trans=c.x>138&&c.x<158&&c.y>46&&c.y<69;
            const auto& rows=g.campaign.data().regions.at(hima?"hima":trans?"trans":"oasis");
            for(const auto& r:rows)if(Cell{r.cell.x+(trans?256:0),r.cell.y}==c)return r.code;
        }
        if(c.y==67&&c.x>=28&&c.x<=30&&value>=88&&value<=90)return c.x==28?54:c.x==29?-114:-113;
        if(c==Cell{39,32}&&value==34)return 2;
        if(c==Cell{157,68}&&value==36&&s.central_destroyed)return 3;
        const auto& w=g.core.wagons;
        if(c==Cell{32,67}&&value==35&&!w.empty()&&(w.front().type==8||w.back().type==8))return 2;
        return value;
    }
    bool passable(Cell c,int heading,int& value) const {
        const auto& w=g.core.wagons;
        if(c==Cell{11,10}&&g.campaign.model().whale_present
            &&std::none_of(w.begin(),w.end(),[](const Wagon& r){return r.type==9&&r.state<3;}))return false;
        const auto kind=work_kind(value);
        if(kind!=WorkKind::None) {
            const auto rule=work_rule(kind);
            if(rails_carried(w)<rule.rails||slaves_carried(w)<rule.slaves)return false;
            value=repaired_track(value);
        }
        const auto ports=rail_ports(value);const auto port=point(heading_delta(heading))*-.5;
        return value!=-120&&std::find(ports.begin(),ports.end(),port)!=ports.end();
    }
public:
    Planner(const GameSession& game,const std::set<Key>& reversals):g(game),attempted_reversals(reversals) {}
    std::vector<Action> plan(Cell target) const {
        const auto& j=g.core.journey;const Key start=key(j.position,j.heading,j.phase);
        std::map<Key,Parent> parents;std::vector<Key> queue{start};parents[start]={start,{}};
        const auto enqueue=[&](Key next,Key prior,Action a) {
            if(parents.emplace(next,Parent{prior,a}).second)queue.push_back(next);
        };
        for(std::size_t cursor=0;cursor<queue.size();++cursor) {
            const auto state=queue[cursor];const auto [x,y,z]=state;const Cell cell{x,y};
            const int incoming=z%16,phase=z/16-1,effective=code(cell);
            std::vector<int> choices{effective};
            if(switch_code(effective)&&phase<1)choices.push_back(effective^1);
            for(int choice:choices) {
                const int outgoing=phase>=1?incoming:rail_turn(choice,incoming);
                const Cell next=cell+heading_delta(outgoing);
                if(!g.core.network.in_bounds(next))continue;
                int next_code=code(next);
                // Whale exclusion also applies when it is the requested destination.
                if(next==Cell{11,10}&&g.campaign.model().whale_present
                    &&std::none_of(g.core.wagons.begin(),g.core.wagons.end(),[](const Wagon& w){return w.type==9&&w.state<3;}))continue;
                Action a{cell,next,switch_code(choice)?choice:0,phase};
                if(next==target) {
                    std::vector<Action> route{a};auto prior=state;
                    while(prior!=start){const auto& p=parents.at(prior);route.push_back(p.action);prior=p.previous;}
                    std::reverse(route.begin(),route.end());return route;
                }
                if((next_code>=34&&next_code<=37)||next_code==65||next_code==78) {
                    a.station=true;enqueue(key(cell,10-outgoing,0),state,a);continue;
                }
                if(passable(next,outgoing,next_code))enqueue(key(next,outgoing,0),state,a);
            }
            // Pilot-only routing restriction, like allow_midtrack_reverse in
            // campaign_route_planner.gd. Do not retry a manoeuvre that already
            // produced a physical deviation during this leg; rails are unchanged.
            if(!attempted_reversals.contains(state))
                enqueue(key(cell,10-incoming,std::abs(phase-2)-1),state,{cell,{},0,phase,true,false});
        }
        return {};
    }
};
class Replay {
public:
    Session core;GameSession game;audio::GameAudio audio;PresentationState ui;
    std::ofstream log;std::size_t operations{},cycles{},entered{},limit;
    std::map<int,Cell> stations;std::map<std::pair<int,int>,int> gates;
    std::string delivery_code;bool options{};int spy=-1;
    Replay(const fs::path& directory,const fs::path& log_path,std::size_t budget)
        :game(core),audio(directory,{false,1073741824,0},1),log(log_path),limit(budget) {
        require(bool(log),"Cannot open route ledger");std::string error;
        bool good=core.load_world(directory/"private-data/CARTE.FIC",error);require(good,error);
        good=game.load(directory,error);require(good,error);
        game.random.seed(1);game.encounter_random.seed(1);game.visual_random.seed(1);game.reset();
        require(core.journey.position==Cell{12,62}&&core.journey.heading==6
            &&core.wagons==initial_wagons()&&core.engine.lignite==2000&&core.engine.anthracite==500,"Original start differs");
        for(int x=0;x<RailNetwork::width;++x)for(int y=0;y<RailNetwork::height;++y) {
            Cell c{x,y};int code=core.network.tile(c);
            if(code>=34&&code<=37)stations[core.network.station_lookup(c)]=c;
        }
        // Exact STATION_SPECIALS from the source network, not invented rails.
        for(Cell c:std::vector<Cell>{{23,67},{35,4},{53,32},{148,60}})stations[core.network.station_lookup(c)]=c;
        ui.screen=1;core.engine.cycle_anthracite();core.engine.set_regulator(300);
        note("START source seed1; controller pilot; no SDL events");
    }
    void note(const std::string& value) {log<<value<<'\n';log.flush();}
    void budget() {require(++operations<=limit,"Owner-supplied operation budget exhausted at "+cell_text(core.journey.position));}
    void actions() {
        for(const auto& action:game.take_actions()) {
            require(action.kind!=campaign::ActionKind::Quit,"Campaign requested quit");
            if(action.kind==campaign::ActionKind::Options){options=true;ui.screen=0;ui.options_open=true;}
        }
        // Audio is deliberately offline/stopped. This test verifies gameplay and
        // complete archive state; native UI/audio tests own cue dispatch evidence.
    }
    void release() {require(!game.blocks_simulation(),"Cannot release an active modal");core.paused=false;if(core.engine.brake)core.engine.toggle_brake();}
    void firing() {
        auto& e=core.engine;
        if(e.anthracite==0)while(e.anthracite_rate)e.cycle_anthracite();
        if(e.lignite==0)while(e.lignite_rate)e.cycle_lignite();
        if(e.pressure_reserve>=32000) {while(e.anthracite_rate)e.cycle_anthracite();while(e.lignite_rate)e.cycle_lignite();}
        else if(e.pressure_reserve<=1500) {
            if(e.anthracite>0){while(e.anthracite_rate!=1)e.cycle_anthracite();while(e.lignite_rate)e.cycle_lignite();}
            else if(e.lignite>0){while(e.anthracite_rate)e.cycle_anthracite();while(e.lignite_rate!=1)e.cycle_lignite();}
        }
    }
    std::string combat_context() const {
        const auto pools=combat::auto_pools(core.wagons);
        std::ostringstream out;
        out<<" soldiers="<<pools.soldiers<<" mammoths="<<pools.mammoths
            <<" guns="<<pools.guns<<" potential="<<combat::potential(pools);
        for(std::size_t i=0;i<core.wagons.size();++i) {
            const auto& w=core.wagons[i];
            out<<" wagon["<<i<<"]="<<w.type<<','<<w.state<<','<<w.goods<<','<<w.quantity;
        }
        return out.str();
    }
    std::string loss_context() const {
        const auto& pending=game.campaign.model().pending;
        std::ostringstream out;
        out<<"scene="<<campaign::scene_name(pending.scene)<<" epitaph="<<pending.epitaph
            <<" engine_pending="<<core.engine.event_pending<<" engine_message="<<core.engine.event_message
            <<combat_context();
        // Automatic loss clears GameSession::report and pending_enemy. The
        // surviving enemy records preserve the actual encounter evidence.
        const auto& slots=game.enemies.snapshot().slots;
        for(std::size_t i=0;i<slots.size();++i) {
            const auto& enemy=slots[i];if(!enemy.active())continue;
            out<<" enemy["<<i<<"]="<<cell_text(enemy.cell())<<",kind="<<enemy.kind
                <<",strength="<<enemy.strength;
            if(enemy.cell()==core.journey.position)
                out<<",contact_margin="<<combat::margin(combat::potential(combat::auto_pools(core.wagons)),enemy.strength);
        }
        return out.str();
    }
    void tick() {
        budget();firing();const Cell old=core.journey.position;const auto before=core.engine.cycles;
        game.advance(core.seconds_per_cycle/core.calendar.factor);actions();
        cycles+=std::size_t(core.engine.cycles-before);
        if(game.campaign.model().ending==campaign::Ending::Death||core.engine.event_pending)
            throw std::runtime_error("Real route lost: "+loss_context());
        if(old!=core.journey.position) {
            ++entered;const auto at=core.journey.position;
            if(at==Cell{157,68}||at==Cell{152,48}||at==Cell{151,66}||at==Cell{152,66}) {
                gates[{at.x,at.y}]=at==Cell{152,48}?int(core.wagons.size()):core.network.tile(at);
                note("GATE "+cell_text(at)+" wagons="+std::to_string(core.wagons.size()));
            }
        }
    }
    static std::string document_code(const campaign::Lines& lines) {
        for(const auto& line:lines)for(std::size_t at=0;at<line.size();) {
            if(!std::isdigit(static_cast<unsigned char>(line[at]))){++at;continue;}
            const auto start=at;while(at<line.size()&&std::isdigit(static_cast<unsigned char>(line[at])))++at;
            if(at-start==5)return line.substr(start,5);
        }
        return {};
    }
    void story() {
        while(game.campaign.blocks_simulation()) {
            budget();auto& c=game.campaign;const auto presentation=c.presentation();
            const auto pending=c.model().pending;
            require(presentation.scene!=campaign::Scene::Death&&presentation.scene!=campaign::Scene::Slope,"Unexpected loss or unprepared slope");
            if(presentation.scene==campaign::Scene::Mausoleum)delivery_code=document_code(presentation.lines);
            if(pending.quiz) {
                const auto q=*pending.quiz;c.input(c.data().quizzes[int(q.kind)][q.index].answer);
                c.submit_code(c.presentation().input_code);note("MANUAL quiz answered through controller");
            } else if(presentation.entering_code) {
                require(!delivery_code.empty(),"Oslo code was not earned from Mausoleum");
                c.input(delivery_code);c.submit_code(c.presentation().input_code);
            } else if(presentation.scene==campaign::Scene::SunRestored)game.advance(1.0/50);
            else {require(!presentation.question,"Unexpected story question");c.process();}
            actions();
        }
    }
    bool settle() {
        if(game.campaign.blocks_simulation()){story();return true;}
        if(game.report) {
            require(game.report->won,"Real automatic combat lost");
            std::ostringstream report;
            report<<"BATTLE won margin="<<game.report->margin<<" potential_before="<<game.report->potential
                <<" coal_gained="<<game.report->coal_gained<<" scrapped_indices=";
            for(int index:game.report->scrapped_indices)report<<index<<',';
            note(report.str()+" at="+cell_text(core.journey.position)+" AFTER"+combat_context());
            // Same report-dismiss operation as SessionUI::handle_modal.
            game.report.reset();core.paused=false;return true;
        }
        require(!game.tactical,"Unexpected manual combat before automatic option");
        if(!game.roamers.snapshot().pending.empty()) {game.answer_world(false);actions();note("ROAMER declined");return true;}
        if(game.world.snapshot().pending_mine>=0) {
            game.answer_world(true);while(game.world.snapshot().pending_mine>=0){budget();game.continue_world();}
            actions();note("INTERMEDIATE MINE completed");return true;
        }
        if(game.works.active()) {
            if(game.works.stage==WorkStage::Question){game.answer_works(true);require(game.works.stage==WorkStage::Report,"Earned works resources insufficient");}
            require(game.works.stage!=WorkStage::Shortage,"Works shortage");
            note("WORKS dismiss at "+cell_text(game.works.cell)+" used="+std::to_string(game.works.used)
                +" rails_remaining="+std::to_string(rails_carried(core.wagons))
                +" slaves="+std::to_string(slaves_carried(core.wagons)));
            game.finish_works();actions();return true;
        }
        return false;
    }
    void travel(Cell target,int city) {
        if(game.city>=0||game.workshop){require(game.depart(),"Departure refused");actions();}
        release();note("LEG target="+cell_text(target)+" city="+std::to_string(city));
        std::set<Key> attempted_reversals;
        for(;;) {
            budget();const auto route=Planner(game,attempted_reversals).plan(target);
            require(!route.empty(),"No supplied-resource rail route from "+cell_text(core.journey.position)+" to "+cell_text(target)
                +" rails="+std::to_string(rails_carried(core.wagons))+" slaves="+std::to_string(slaves_carried(core.wagons)));
            bool replan=false;
            for(const auto& a:route) {
                if(core.journey.position!=a.cell){replan=true;break;}
                if(a.reverse) {
                    const auto& j=core.journey;
                    if(!attempted_reversals.insert(key(j.position,j.heading,j.phase)).second) {
                        note("REPLAN repeated reverse at "+cell_text(j.position));replan=true;break;
                    }
                    require(core.reverse(),"Player reverse refused");note("REVERSE "+cell_text(a.cell));continue;
                }
                if(a.code&&core.network.tile(a.cell)!=a.code)require(core.toggle_switch(a.cell),"Switch command refused");
                while(core.journey.position!=a.next) {
                    if(core.journey.blocked&&core.journey.boundary_cell()==target) {
                        require((city>=0&&core.journey.station_result(core.network)==city)||city<0,"Actual city lookup differs");
                        if(game.campaign.model().pending.quiz)story();
                        require(city<0||game.city==city,"Actual arrival owner missing");
                        note("ARRIVE "+std::to_string(city)+" day="+std::to_string(core.calendar.day));return;
                    }
                    const auto position=core.journey.position;const int heading=core.journey.heading;
                    if(settle()) {
                        if(game.city>=0||game.workshop){require(game.depart(),"Intermediate departure refused");actions();release();replan=true;break;}
                        release();if(core.journey.position!=position||core.journey.heading!=heading){replan=true;break;}
                    }
                    if(core.journey.blocked) {
                        if(game.city>=0||game.workshop){require(game.depart(),"Intermediate departure refused");actions();release();replan=true;break;}
                        require(false,"Unresolved physical boundary "+core.journey.stop_reason+" at "+cell_text(core.journey.boundary_cell()));
                    }
                    tick();
                    if(core.journey.position!=position&&core.journey.position!=a.next){replan=true;break;}
                }
                if(replan)break;
            }
            require(replan,"Planned route ended without actual arrival");
        }
    }
    void go(int city) {require(stations.contains(city),"Unknown source station");travel(stations.at(city),city);}
    void buy(int kind) {
        for(const auto entry:game.trade.workshop_list(game.city))if(entry.type==kind) {
            require(economy::Trade::workshop_refusal(entry,0,core.wagons,core.engine)==0,"Wagon purchase refused");
            require(economy::Trade::buy_wagons(entry,1,core.wagons,core.engine)==0,"Wagon transaction refused");
            game.cargo_changed();note("BUY wagon="+std::to_string(kind)+" price="+std::to_string(entry.price)
                +" lignite="+std::to_string(core.engine.lignite));return;
        }
        throw std::runtime_error("Required wagon absent from current shop");
    }
    void transaction(int kind,int mode,int quantity,int goods=0) {
        const auto offer=game.trade.offer(game.city,kind,mode,goods);require(offer.has_value(),"Missing source offer");
        require(game.trade.entry_refusal(*offer,core.wagons)==0,"Offer entry refused");
        for(int selected=0;selected<quantity;++selected) {
            const int refusal=game.trade.increment_refusal(*offer,selected,core.wagons,core.engine);
            const auto cargo=game.trade.capacity(*offer,core.wagons);
            require(refusal==0,"Actual quantity increment refused: code="+std::to_string(refusal)
                +" city="+std::to_string(game.city)+" goods="+std::to_string(offer->goods)
                +" mode="+std::to_string(offer->mode)+" next="+std::to_string(selected+1)
                +" unit="+std::to_string(economy::Trade::price(*offer))+" loaded="+std::to_string(cargo.loaded)
                +" room="+std::to_string(cargo.room));
        }
        require(game.trade.commit(*offer,quantity,core.wagons,core.engine)==0,"Trade commit refused");
        game.cargo_changed();note("TRADE city="+std::to_string(game.city)+" goods="+std::to_string(offer->goods)
            +" quantity="+std::to_string(quantity)+" mode="+std::to_string(offer->mode)
            +" unit="+std::to_string(economy::Trade::price(*offer))+" lignite="+std::to_string(core.engine.lignite));
    }
    void goods(int id,int quantity,int mode) {transaction(economy::Commercial,mode,quantity,id);}
    int buy_available(int goods_id,int maximum=0) {
        const auto offer=game.trade.offer(game.city,economy::Commercial,economy::Buy,goods_id);
        require(offer.has_value(),"Missing financing offer");
        int quantity=0;
        while((maximum==0||quantity<maximum)
            &&game.trade.increment_refusal(*offer,quantity,core.wagons,core.engine)==0){budget();++quantity;}
        require(quantity>0,"No affordable financing stock");
        goods(goods_id,quantity,economy::Buy);return quantity;
    }
    int sell_available(int goods_id,int wanted) {
        const auto offer=game.trade.offer(game.city,economy::Commercial,economy::Sell,goods_id);
        require(offer.has_value(),"Missing financing sale");
        int quantity=0;
        while(quantity<wanted&&game.trade.increment_refusal(*offer,quantity,core.wagons,core.engine)==0){budget();++quantity;}
        if(quantity>0)goods(goods_id,quantity,economy::Sell);
        return wanted-quantity;
    }
    void rearm(int weapons) {
        // Actual Gdansk offer. The observed strength102 needs potential>=2:
        // automatic_combat.gd/combat_outcome.gd lose when margin<=0.
        require(game.city==13,"Rearm requires actual Gdansk arrival");
        while(combat::auto_pools(core.wagons).guns<weapons){budget();buy(11);}
        note("ARMAMENT"+combat_context());
    }
    void send_spy() {
        game.campaign.open_spy_menu();game.campaign.menu(0);actions();
        require(game.campaign.select_map_cell({65,20}),"Spy destination refused");actions();
        const auto& records=game.campaign.model().spies;
        for(int i=0;i<int(records.size());++i)if(records[i][0]==2&&records[i][3]==25&&records[i][4]==20)spy=i;
        require(spy>=0,"Earned recruit did not leave");note("SPY sent to65,20");
    }
    SaveSections snapshot() const {
        std::ostringstream out;require(core.write_snapshot(out),"Earned route has invalid core snapshot");
        archive::Encounters e{game.encounter_random,game.visual_random,game.difficulty,game.pending_enemy,game.city,game.automatic,game.manual_paused,game.workshop,game.text_accumulator,game.report};
        SaveSections s{{"core",out.str()},{"economy",serialize_economy({game.trade.snapshot(),game.random,game.works,ui.workshop})},
            {"world",world::serialize({game.enemies.snapshot(),game.world.snapshot(),game.roamers.snapshot()})},
            {"campaign",campaign::serialize_snapshot(game.campaign.snapshot())},{"encounters",archive::encode(e)},
            {"presentation",archive::encode(ui)},{"audio",archive::encode(audio.snapshot())},{"launcher",launcher::serialize_snapshot(game.launcher.snapshot())}};
        if(game.tactical)s["tactical"]=combat::serialize(game.tactical->snapshot());return s;
    }
    void initial_route() {
        using namespace economy;
        go(38);goods(10,20,Buy);go(31);goods(10,20,Sell);goods(12,20,Buy);
        go(11);buy(18);buy(18);
        // Pay for the two reference XL wagons at the first Ruhr visit. The old
        // pilot deferred the second purchase, but its fixed38-fur sale can exceed
        // actual tender room after the native physical route. Both purchases
        // still use source offers, consume earned coal and update train mass.
        // commerce.json: Amsterdam salt5 -> Granada13; Granada fur2 ->
        // Amsterdam60. Buy useful equipment between sales if the tender fills.
        go(38);goods(12,20,Sell);const int fur=buy_available(10);
        go(31);const int remaining_fur=sell_available(10,fur);
        // Keep the reference consist until supplies and Urga are earned.
        // Buying the spy wagon and guns here extended the reversing physical
        // contact into works25,24 before the prison/slaves/rails purchases.
        go(11);
        note("SECOND RUHR waypoint; both reference XL wagons already purchased");
        go(10);buy(5);go(4);transaction(SlaveMarket,Buy,15);
        // Recorded route crosses CARTE crevasses25,24 and6,9. The reference29
        // fails if the first uses its maximum20; keep the next entry minimum10.
        // track_works.gd WORKS: consumption=base-rnd(spread), entry requires rails.
        const auto first_work=work_rule(work_kind(core.network.tile({25,24})));
        const auto next_work=work_rule(work_kind(core.network.tile({6,9})));
        const int required_rails=first_work.base+next_work.rails;
        // commerce.json: both Marrakesh41 and Turin35 sell rails for4 with stock
        //20+rnd20. The observed Turin stock29 cannot alone supply required30.
        go(41);buy_available(1,required_rails);go(35);
        const int missing_rails=required_rails-rails_carried(core.wagons);
        if(missing_rails>0)goods(1,missing_rails,Buy);
        go(15);buy(8);go(41);go(4);go(-2);story();require(game.campaign.model().urga_key,"Urga key absent");
        go(13);buy(22);rearm(2);game.automatic=true;note("OPTION automatic combat selected");
        if(remaining_fur>0) {
            const auto offer=game.trade.offer(31,Commercial,Sell,10);
            require(offer.has_value(),"Amsterdam financing offer vanished");
            while(game.trade.increment_refusal(*offer,remaining_fur-1,core.wagons,core.engine)==NoCoalRoom)
                {budget();buy(11);}
            go(31);goods(10,remaining_fur,Sell);
        }
        go(8);transaction(Garrison,Sell,1);send_spy();go(-4);story();
        require(!delivery_code.empty(),"Mausoleum did not display a delivery code");
    }
    void remaining_route() {
        using namespace economy;
        go(27);
        if(combat::auto_pools(core.wagons).guns<2){go(13);rearm(2);go(27);}
        // Pay for the reference rail load after earning the meat sale. The
        // observed433 balance cannot pay150 rails +300 meat before travelling.
        // Keep source offer guards and sell only what was actually purchased.
        const int meat=buy_available(11,30);go(32);goods(11,meat,Sell);
        go(27);goods(1,50,Buy);go(32);
        go(16);buy(9);buy(15);go(32);goods(8,20,Buy);go(35);goods(8,20,Sell);go(13);rearm(2);
        go(-3);story();require(game.campaign.model().delivery_open,"Oslo delivery gate closed");
        require(spy>=0&&game.campaign.model().spies[spy][0]==3,"Calendar did not deliver spy");
        game.campaign.open_spy_menu();game.campaign.menu(1);actions();
        require(game.campaign.select_map_cell({65,20}),"Sabotage selection failed");
        require(game.campaign.presentation().scene==campaign::Scene::SabotageConfirm,"Sabotage confirmation absent");
        game.campaign.answer(true);actions();require(game.campaign.model().central_destroyed,"Actual sabotage failed");
        travel({12,17},-1);require(game.workshop,"Leeds workshop owner not active");
        economy::Management management(core.engine,core.wagons);
        for(int i=int(core.wagons.size())-1;i>=0;--i) {
            const auto w=core.wagons[i];const std::vector<int> remove{5,8,9,15,17,18,22,23};
            const bool spare_weapon=(w.type==11||w.type==12)&&combat::auto_pools(core.wagons).guns>1;
            if(w.state==3||spare_weapon||std::find(remove.begin(),remove.end(),w.type)!=remove.end())
                require(management.remove(i,true),"Earned workshop removal refused");
        }
        game.cargo_changed();require(core.wagons.size()==5,"Slope preparation did not retain five wagons");
        go(-5);story();
        require(options&&game.campaign.model().ending==campaign::Ending::Sun&&game.campaign.model().pending.empty(),"Sun did not finish to options");
        require(gates.contains({157,68})&&gates.at({157,68})==3,"Gycode gate not actually crossed");
        require(gates.contains({152,48})&&gates.at({152,48})==5,"Slope route not actually crossed");
        require(game.enemies.at(29)&&game.enemies.at(29)->kind==2,"Actual Minotaur not defeated");
        note("FINISH cycles="+std::to_string(cycles)+" entered="+std::to_string(entered)+" day="+std::to_string(core.calendar.day));
    }
    void reload(const fs::path& file) {
        const auto before=snapshot();std::string error;
        bool okay=save_game(file,game,audio,ui,error);require(okay,error);
        game.reset();audio.reset();ui={};
        okay=load_game(file,game,audio,ui,error);require(okay,error);
        require(snapshot()==before,"Earned midpoint changed on complete disk restore");note("MIDPOINT complete archive restored");
    }
};
fs::path claim(const fs::path& parent) {
    require(fs::is_directory(parent),"Scratch parent must already exist");
    const auto stamp=std::chrono::system_clock::now().time_since_epoch().count();
    for(unsigned n=0;;++n) {
        auto path=parent/("campaign-route-"+std::to_string(stamp)+"-"+std::to_string(n));std::error_code error;
        if(fs::create_directory(path,error))return path;
        require(!error||error==std::errc::file_exists,"Cannot claim route evidence directory");
    }
}
int run(const fs::path& game,const fs::path& parent,std::size_t limit) {
    const auto directory=claim(parent);std::cout<<"Route evidence: "<<directory<<std::endl;
    SaveSections midpoint,final;std::size_t cycles{},entered{};
    for(int pass=0;pass<2;++pass) {
        Replay r(game,directory/(pass?"resumed.log":"continuous.log"),limit);
        try {
            r.initial_route();
            if(pass==0)midpoint=r.snapshot();
            else {require(r.snapshot()==midpoint,"Seeded earned midpoint diverged");r.reload(directory/"MIDPOINT.native");}
            r.remaining_route();
            if(pass==0){final=r.snapshot();cycles=r.cycles;entered=r.entered;}
            else require(r.snapshot()==final&&r.cycles==cycles&&r.entered==entered,"Disk-resumed final campaign differs");
        } catch(const std::exception& error) {
            const auto& j=r.core.journey;const auto& e=r.core.engine;
            r.note("STOP "+std::string(error.what())+" at="+cell_text(j.position)
                +" heading="+std::to_string(j.heading)+" phase="+std::to_string(j.phase)
                +" boundary="+cell_text(j.boundary_cell())+" reason="+j.stop_reason
                +" fuel="+std::to_string(e.lignite)+"/"+std::to_string(e.anthracite)
                +" cycles="+std::to_string(r.cycles));throw;
        }
    }
    std::cout<<"PASS continuous and disk-resumed controller campaign; cycles="<<cycles<<" entered="<<entered
        <<"; no SDL input/visual proof"<<std::endl;return 0;
}
} // namespace
int main(int argc,char** argv) {
    if(argc!=4){std::cerr<<"usage: campaign_route_tests <game-dir> <existing-scratch-dir> <max-operations-per-run>\n";return 2;}
    try {std::size_t used{};const auto limit=std::stoull(argv[3],&used);
        require(argv[3][0]!='-'&&used==std::string(argv[3]).size()&&limit>0,"Invalid operation budget");return run(argv[1],argv[2],limit);
    } catch(const std::exception& error){std::cerr<<"FAIL campaign route: "<<error.what()<<'\n';return 1;}
}
