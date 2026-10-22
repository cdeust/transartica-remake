// SPDX-License-Identifier: MIT
// Sources: campaign_state.restore, campaign_snapshot.gd, manual_quiz.valid,
// campaign_ambush_snapshot.gd. Validation is pure before host state changes.
#include "controller.hpp"
#include <algorithm>
namespace transartica::campaign {
std::string scene_name(Scene scene) {
    static const std::array<const char*,19> names{"","wolf","mole","slope","whale_harpoon","whale_question","urga","oslo","mausoleum","sun","sun_end","earth","spy_pickup","sabotage_confirm","manual_quiz","death","crew","report","sun-restored"};
    int index=int(scene);return index>=0&&index<19?names[index]:"";
}
bool Quiz::valid() const {
    if(kind!=QuizKind::Soleil&&kind!=QuizKind::Viking) return false;
    bool resume=resume_oslo?resume_city==-1:(resume_city>=5&&resume_city<=9)||resume_city==12;
    return resume&&index>=0&&index<8&&attempt>=0&&attempt<3;
}
bool Pending::valid(bool urga,bool delivery) const {
    if(scene==Scene::None) return messages.empty()&&!quiz;
    if(int(scene)<int(Scene::Wolf)||int(scene)>int(Scene::Death)) return false;
    if(messages.size()>3) return false;
    for(int id:messages) if(id<1||id>100) return false;
    if(scene==Scene::Wolf||scene==Scene::Mole) {
        if(divisor<2||divisor>10||applied<0||applied>2||ambush_lines.size()>10) return false;
        if(messages!=(scene==Scene::Wolf?std::vector<int>{77,81,79}:std::vector<int>{78,81,80})) return false;
    }
    if(scene==Scene::ManualQuiz&&(!quiz||!quiz->valid())) return false;
    if(scene!=Scene::ManualQuiz&&quiz) return false;
    if((scene==Scene::SpyPickup||scene==Scene::SabotageConfirm)&&(spy<0||spy>=20)) return false;
    if(code_input&&(scene!=Scene::Oslo||!urga)) return false;
    if(departure_chime&&(scene!=Scene::Oslo||!delivery||messages!=std::vector<int>{91})) return false;
    return epitaph==0||(epitaph>=100&&epitaph<=105);
}
bool State::valid() const {
    if(ending!=Ending::None&&ending!=Ending::Sun&&ending!=Ending::Death) return false;
    if(!hazards.valid()||!fauna.valid()||!stoup.valid()||!pending.valid(urga_key,delivery_open)) return false;
    for(const auto& r:spies) {
        if(r[0]<0||r[0]>3||r[5]<0||r[5]>2||r[13]<0||r[13]>199) return false;
        if(r[0]>1&&(r[1]<-40||r[1]>=120||r[2]<0||r[2]>=73||r[3]<-40||r[3]>=120||r[4]<0||r[4]>=73)) return false;
    }
    return true;
}
bool Snapshot::valid() const {
    if(!state.valid()||!finale.valid()||page>state.pending.messages.size()) return false;
    if(int(selection)<0||int(selection)>2||int(crew_menu)<0||int(crew_menu)>3||int(return_room)<0||int(return_room)>2) return false;
    const auto& p=presentation;const auto& e=state.pending;
    if(int(p.scene)<0||int(p.scene)>int(Scene::SunRestored)||p.scene==Scene::SunEnd||p.lines.size()>10||p.menu.size()>3) return false;
    if(p.input_code.size()>(p.scene==Scene::ManualQuiz?8U:5U)) return false;
    for(char c:p.input_code) if(p.scene==Scene::ManualQuiz?(c<'A'||c>'Z'):(c<'0'||c>'9')) return false;
    if(!e.empty()) {
        Scene expected=e.scene==Scene::SunEnd?Scene::SunRestored:e.scene;
        if(!p.visible||p.scene!=expected||notice) return false;
        if((expected==Scene::Wolf||expected==Scene::Mole)&&page!=std::size_t(e.applied)) return false;
    }
    if(!p.input_code.empty()&&!p.entering_code) return false;
    if(p.entering_code&&e.scene!=Scene::ManualQuiz&&(e.scene!=Scene::Oslo||!e.code_input)) return false;
    return p.question==(e.scene==Scene::WhaleQuestion||e.scene==Scene::SpyPickup||e.scene==Scene::SabotageConfirm);
}
}
