// SPDX-License-Identifier: MIT
// Exact original tick boundaries retained by game/scripts/startup_intro.gd.
#include "screens/startup_model.h"
#include <iostream>
using namespace transartica::panels;
int main() {
    int failures=0,checks=0;const auto check=[&](bool value,const char* label){++checks;if(!value){++failures;std::cerr<<"FAIL: "<<label<<'\n';}};
    StartupTimeline intro;check(intro.done()&&!intro.request_exit(),"fixtures opt out until explicitly started");intro.start();
    check(!intro.request_exit(),"publisher cannot be skipped before source title-ready gate");
    for(int i=0;i<98;++i)intro.step();check(intro.take_audio().empty(),"publisher effect not early");
    intro.step();auto events=intro.take_audio();check(events.size()==1&&events[0].kind==StartupAudioKind::PublisherEffect&&events[0].value==0x3c,"tick99 publisher effect source cue");
    while(intro.tick()<StartupTimeline::publisher_end)intro.step();events=intro.take_audio();
    check(events.size()==1&&events[0].kind==StartupAudioKind::ReceptionMusic,"tick252 starts reception score before title readiness");
    while(intro.tick()<StartupTimeline::title_ready)intro.step();check(intro.request_exit()&&!intro.request_exit(),"exit accepted once at tick360");events=intro.take_audio();
    check(events.size()==1&&events[0].kind==StartupAudioKind::FadeMusic&&events[0].value==50,"source requested fifty-tick music fall");
    for(int i=0;i<59;++i)intro.step();check(intro.active(),"exit input does not bypass sixty-tick fade");intro.step();check(intro.done()&&intro.tick()==420,"exclusive boot completes at source tick420");
    intro.start();intro.advance(double(StartupTimeline::title_ready+StartupTimeline::title_timeout+StartupTimeline::exit_fade)/StartupTimeline::hz);
    check(intro.done()&&intro.tick()==30420,"no-input source timeout includes final exit fade");
    intro.start();intro.advance(-1);check(intro.tick()==0,"invalid elapsed time cannot rewind intro");
    std::cout<<checks<<" startup checks, "<<failures<<" failures\n";return failures?1:0;
}
