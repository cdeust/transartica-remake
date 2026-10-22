// SPDX-License-Identifier: MIT
// Native save transaction, corruption and source-model validation probes.
#include "app/economy_archive.h"
#include "app/save_archive.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <stdexcept>

using namespace transartica;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label) {
    ++checks;if(!value) {++failures;std::cerr<<"FAIL: "<<label<<'\n';}
}
std::string bytes(const std::filesystem::path& path) {
    std::ifstream input(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()};
}
void put(const std::filesystem::path& path,const std::string& value) {
    std::ofstream output(path,std::ios::binary|std::ios::trunc);output<<value;
    output.close();if(output.fail()) throw std::runtime_error("Cannot write archive test fixture");
}
struct Scratch {
    std::filesystem::path directory;
    explicit Scratch(const std::filesystem::path& root):directory(root/"native-archive-tests") {
        if(!std::filesystem::create_directory(directory)) throw std::runtime_error("Archive test scratch already exists; preserved: "+directory.string());
    }
    ~Scratch() {
        std::error_code error;
        for(const char* name:{"save.ta","bad.ta","save.ta.pending/owner"}) std::filesystem::remove(directory/name,error);
        std::filesystem::remove(directory/"save.ta.pending",error);
        std::filesystem::remove(directory,error);
    }
};
EconomySnapshot baseline(Session& session,const std::filesystem::path& game) {
    std::string error;economy::Trade trade;
    if(!trade.load(game/"data",error)) throw std::runtime_error(error);
    EconomySnapshot state;state.random.seed(42);trade.reset(state.random);state.trade=trade.snapshot();
    state.workshop.visible=true;state.workshop.selected=4;state.workshop.action=50;state.workshop.moving=4;
    state.workshop.title="LEEDS \"STATION\"";state.workshop.notice="First line\nSecond line \\";
    for(int x=0;x<RailNetwork::width;++x) for(int y=0;y<RailNetwork::height;++y) {
        if(!state.works.ask(session.network,{x,y})) continue;
        auto labour=session.wagons;labour.push_back({5,0,0,15});labour.push_back({17,0,1,20});
        if(!state.works.accept(labour,state.random)) throw std::runtime_error("Cannot stage paid work fixture");
        state.works.accumulator=std::numeric_limits<double>::epsilon();return state;
    }
    throw std::runtime_error("Real map contains no work obstacle");
}
void economy_roundtrip(Session& session,const EconomySnapshot& state) {
    std::string error;const auto text=serialize_economy(state);EconomySnapshot output;
    check(validate_economy(state,session,error),"real stock, paid work and live moving workshop validate");
    check(parse_economy(text,output,session,error)&&output==state,"economy roundtrip retains all arrays/RNG/workshop/work fields");
    auto expected=state.random;auto restored=output.random;
    check(expected.next_u32()==restored.next_u32(),"resumed shared RNG continues exact next draw");
    const auto before=output;
    const auto end=text.rfind("END");
    for(std::size_t n=0;n<end+3;++n) {
        if(n==end+3) break;
        check(!parse_economy(text.substr(0,n),output,session,error)&&output==before,"economy prefix truncation is transactional");
    }
    for(const std::string malformed:{text+"END\n",text+"STOCK\n",std::string("TAECONOMY 2\n"),text.substr(0,text.find("RNG"))+"RNG -1 1\n"+text.substr(text.find("STOCK"))})
        check(!parse_economy(malformed,output,session,error)&&output==before,"economy duplicate/version/unsigned corruption refuses atomically");
    auto broken=state;broken.trade.stock[0][0]=128;
    check(!parse_economy(serialize_economy(broken),output,session,error)&&output==before,"signed stock overflow rejected");
    broken=state;broken.trade.spy_slots[0]=4;check(!validate_economy(broken,session,error),"spy state domain checked");
    broken=state;broken.random.increment=0;check(!validate_economy(broken,session,error),"RNG stream must be odd");
    broken=state;broken.works.cell={-1,-1};check(!validate_economy(broken,session,error),"work report tied to restored world obstacle");
    broken=state;broken.works.accumulator=std::numeric_limits<double>::infinity();check(!validate_economy(broken,session,error),"nonfinite scheduler remainder rejected");
    broken=state;broken.workshop.selected=int(session.wagons.size());check(!validate_economy(broken,session,error),"workshop index validated against restored consist");
    broken=state;broken.workshop.visible=false;check(!validate_economy(broken,session,error),"hidden moving workshop rejected");
    broken=state;broken.workshop.moving=-1;broken.workshop.action=52;broken.workshop.confirmation=true;
    check(!validate_economy(broken,session,error),"repair confirmation requires current repair eligibility");
}
void archive_roundtrip(const std::filesystem::path& directory,const std::string& economy) {
    const auto file=directory/"save.ta",bad=directory/"bad.ta";std::string error;
    SaveSections first{{"core","original core"},{"economy",economy},{"opaque",std::string("\0\nEND\nSECTION core 2\nXX",23)}};
    check(write_archive(file,first,error)&&error.empty(),"complete archive writer commits");
    SaveSections restored;check(read_archive(file,restored,error)&&restored==first,"length-prefixed binary payload roundtrip");
    const auto original=bytes(file);const SaveSections preserved{{"preserved","current live state"}};
    for(std::size_t n=0;n<original.size();++n) {
        put(bad,original.substr(0,n));restored=preserved;
        check(!read_archive(bad,restored,error)&&restored==preserved,"archive every prefix truncation preserves output");
    }
    const std::string header="TRANSARTICA_NATIVE_GAME 1\n";
    for(const auto& malformed:std::vector<std::string>{
        header+"END\n",header+"SECTION core 1\nx\nSECTION core 1\ny\nEND\n",
        header+"SECTION Core 1\nx\nEND\n",header+"SECTION core -1\nx\nEND\n",
        header+"SECTION core 18446744073709551615\nx\nEND\n",
        header+"SECTION core 2\nx\nEND\n",original+"unexpected",header+"SECTION core 1 extra\nx\nEND\n"}) {
        put(bad,malformed);restored=preserved;
        check(!read_archive(bad,restored,error)&&restored==preserved,"malformed/duplicate archive preserves output");
    }
    check(!write_archive(file,{},error)&&bytes(file)==original,"empty write preserves previous file");
    check(!write_archive(file,{{"invalid/name","bad"}},error)&&bytes(file)==original,"invalid section write preserves previous file");
    const auto pending=directory/"save.ta.pending";
    if(!std::filesystem::create_directory(pending)) throw std::runtime_error("Cannot stage owner collision");
    put(pending/"owner","other writer");
    check(!write_archive(file,{{"core","replacement"}},error)&&bytes(file)==original&&bytes(pending/"owner")=="other writer","pending owner collision preserves archive and other writer");
    std::filesystem::remove(pending/"owner");std::filesystem::remove(pending);
    SaveSections second{{"core","replacement"},{"economy",economy}};
    check(write_archive(file,second,error)&&read_archive(file,restored,error)&&restored==second,"atomic replacement loads exact new generation");
    check(!std::filesystem::exists(pending),"writer removes its staging file and directory");
    check(!write_archive(directory,second,error)&&std::filesystem::is_directory(directory),"failed replacement preserves destination directory");
    auto sibling_pending=directory;sibling_pending+=".pending";
    check(!std::filesystem::exists(sibling_pending),"failed replacement cleans owned staging path");
}
}
int main(int argc,char** argv) {
    if(argc!=3) {std::cerr<<"usage: archive_tests <game-directory> <existing-scratch-parent>\n";return 2;}
    try {
        Session session;std::string error;
        if(!session.load_world(std::filesystem::path(argv[1])/"data/CARTE.FIC",error)) throw std::runtime_error(error);
        Scratch scratch(argv[2]);const auto state=baseline(session,argv[1]);
        economy_roundtrip(session,state);archive_roundtrip(scratch.directory,serialize_economy(state));
        std::cout<<checks<<" archive checks, "<<failures<<" failures\n";return failures?1:0;
    } catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
