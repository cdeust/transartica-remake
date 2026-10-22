// SPDX-License-Identifier: MIT
// Oracles: scripts/sample_channels.gd, game_audio.gd, engine_audio.gd,
// scene_audio.gd and data/audio/manifest.json. No device or SDL callback.
#include "audio/game_audio.hpp"
#include "audio/resources.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <set>
#include <stdexcept>

using namespace transartica::audio;
namespace {
int checks{},failures{};
void check(bool value,const std::string& label) {
    ++checks;if(!value) {++failures;std::cerr<<"FAIL: "<<label<<'\n';}
}
std::shared_ptr<const Clip> fixture() {
    auto clip=std::make_shared<Clip>();
    // Two distinct exactly representable frames expose repeats and loop endpoints.
    clip->pcm={0.25f,0.25f,0.5f,0.5f};clip->rate=clip->source_rate=44100;
    clip->source_frames=2;return clip;
}
void priorities() {
    Mixer mix;const auto clip=fixture();
    check(mix.choose(10)==0,"idle channel selection");
    check(mix.play(clip,10,128,1)==0&&mix.play(clip,10,128,1)==0,"same priority replaces existing voice");
    for(int priority=20;priority<=40;priority+=10) mix.play(clip,priority,128,1);
    check(mix.choose(9)==-1&&mix.choose(15)==0,"minimum-priority replacement boundary");
    mix.stop_effects();
    for(int priority=-4;priority<=-1;++priority) mix.play(clip,priority,128,1);
    check(mix.choose(127)==-1,"negative ambient priorities protected from positive priority");
    check(mix.choose(-5)==-1&&mix.choose(-4)==0,"negative priority comparisons and equality");
    mix.stop_effects();check(mix.play(clip,255,128,1)==0&&mix.channels[0].priority==-1,"signed byte priority");
    check(mix.resident_bytes()==clip->bytes(),"shared active PCM counted once");
}
void trusted_paths(const std::filesystem::path& game) {
    Resources resources(game);
    check(resources.path("son-2.wav")==std::filesystem::weakly_canonical(game/"data/audio/son-2.wav"),"staged audio resolves inside the delivered game");
    check(resources.path("res://data/finale.wav")==std::filesystem::weakly_canonical(game/"data/finale.wav"),"staged finale resolves inside the delivered game");
    check(resources.path("res://private-data/finale.wav")==resources.path("res://data/finale.wav"),"historical manifest paths resolve to staged data");
    try {resources.path("res://../untrusted.wav");check(false,"outside trusted roots rejected");}
    catch(const std::runtime_error&) {check(true,"outside trusted roots rejected");}
    // Owner correction 2026-10-22: each of the nine historical cues keeps its score.
    const std::array keys{"bojeu-0","bojeu-1","bojeu2-0","bolieu-0","bolieu-1",
                          "bolieu-2","bolieu-3","bolost-0","bopres-0"};
    std::set<std::filesystem::path> paths;
    for(const auto* key:keys) paths.insert(resources.track(key).path);
    check(paths.size()==keys.size(),"nine historical cues resolve to nine distinct masters");
    // Original T.X execution: tools/faithful_score/amiga-extraction-validation-20261022.json.
    check(!resources.track("bopres-0").loop,"title retains original native stop");
    check(resources.track("bolost-0").loop,"loss theme repeats until original duration expires");
}
void mixing() {
    Mixer mix;const auto clip=fixture();std::array<float,12> output{};
    mix.play(clip,1,128,2);mix.render(output.data(),5);
    const std::array<float,10> expected{0.0625f,0.0625f,0.125f,0.125f,0.0625f,0.0625f,0.125f,0.125f,0,0};
    check(std::equal(expected.begin(),expected.end(),output.begin()),"finite repeat exact PCM and source gain");
    check(!mix.channels[0].playing&&mix.channels[0].priority==-128,"completed repeat restores idle priority");
    mix.collect_finished();check(mix.resident_bytes()==0,"finished effect releases PCM on main thread");
    mix.play(clip,1,128,0);mix.render(output.data(),2);
    check(!mix.channels[0].playing,"zero repeat means one play");
    mix.collect_finished();
    check(mix.play_music(clip,true,1,2,0,1),"music attack and single-frame loop accepted");
    mix.render(output.data(),3);
    check(output[0]==0.25f&&output[2]==0.5f&&output[4]==0.5f&&mix.music.cursor==1,"attack once then exclusive loop end");
    const auto old=mix.music.clip;
    check(!mix.play_music(clip,true,1,1,0,1)&&mix.music.clip==old,"invalid loop refuses transactionally");
    check(!mix.play_music(clip,true,0,3,0,1)&&!mix.play_music(clip,true,0,2,2,1),"loop PCM/cursor bounds");
    mix.stop_music();check(mix.resident_bytes()==0,"music stop releases active resource");
    check(mix.play_music(clip,false,0,2,1,1),"nonloop seek accepted");mix.render(output.data(),2);
    check(output[0]==0.5f&&output[2]==0&&!mix.music.playing,"nonloop music terminates exactly");
}
void render(GameAudio& audio,std::size_t frames) {
    // Bounded scratch independent of the caller's simulated time.
    std::array<float,1024> output{};
    while(frames) {const auto count=std::min(frames,output.size()/2);audio.render_offline(output.data(),count);frames-=count;}
}
void scores(GameAudio& audio) {
    check(audio.play_track("bojeu2-0"),"bundled orchestral WAV decodes");
    check(audio.music_state().loop&&audio.music_state().loop_end>audio.music_state().loop_begin,"source-derived orchestral loop bounds");
    const auto residency=audio.resident_bytes();
    check(audio.play_track("bojeu2-0")&&audio.resident_bytes()==residency,"replaying the same music reuses immutable PCM");
    check(audio.play_track("bojeu-0")&&audio.snapshot().track=="bojeu-0","distinct journey cue replaces the active score");
    audio.play_city(1);check(audio.snapshot().track=="bolieu-3","fresh kind1 city selector3");
    audio.play_city(-1);check(audio.snapshot().track=="bolieu-0","visited negative kind keeps signed selector");
    audio.play_city(2);check(audio.snapshot().track=="bolieu-1","kind2 city selector1");
    audio.play_worksite();check(audio.snapshot().track=="bolieu-2","worksite selector2");
    audio.play_city(-3);check(audio.snapshot().track.empty(),"negative excluded city stops score");
    audio.play_reception();audio.play_city(1,45);check(audio.snapshot().track.empty(),"city45 excludes score");
    audio.play_loss();check(audio.snapshot().track=="bolost-0","loss score selector");
    audio.play_reception();const auto before=audio.snapshot();
    check(!audio.toggle_original_music()&&audio.snapshot().track==before.track&&audio.music_state().playing,"OPTION flag leaves current score playing");
    audio.play_reception();check(audio.snapshot().track=="bopres-0","reception bypasses disabled music preference");
    audio.new_game_reset();check(!audio.snapshot().music_enabled&&audio.snapshot().track.empty(),"START preserves preference and clears playback");
    audio.toggle_original_music();audio.play_journey();check(audio.snapshot().track=="bojeu2-0","journey begins with alternate score");
    audio.play_journey();check(audio.snapshot().track.starts_with("bojeu-"),"journey alternates random2 score");
    const auto playing=audio.snapshot();audio.play_journey(false);
    check(audio.snapshot()==playing,"non-synthesized capability skips scene selection");
    audio.fade_music(3);audio.advance(3.0/50,{});
    check(audio.snapshot().track.empty()&&!audio.music_state().playing,"explicit fade completes at source tick duration");
    audio.play_reception();audio.fade_music(0);check(!audio.music_state().playing,"zero fall stops immediately");
}
void effects(GameAudio& audio,const std::filesystem::path& game) {
    audio.reset();const int first_channel=audio.son(6);
    if(first_channel<0) std::cerr<<"SON6 decode diagnostic: "<<audio.last_error()<<'\n';
    check(first_channel>=0,"SON6 first real source cue");
    const auto first=audio.channels();audio.advance(3.0/50,{});
    check(audio.channels()!=first,"SON6 second pitch after three ticks");
    audio.stop_effects();audio.advance(3.0/50,{});
    const auto stopped=audio.channels();
    check(std::none_of(stopped.begin(),stopped.end(),[](const auto& voice){return voice.playing;}),"stop cancels delayed SON6 stage");
    audio.set_effects_enabled(false);check(audio.son(1)==-1,"effects preference rejects source sample");
    audio.set_effects_enabled(true);check(audio.son(1)>=0,"actual SON cue loads without global cache");
    auto channels=audio.channels();auto active=std::find_if(channels.begin(),channels.end(),[](const auto& voice){return voice.playing;});
    check(active!=channels.end()&&active->frames>0,"decoded source sample has PCM");
    audio.stop_effects();check(audio.resident_bytes()==0,"explicit effect stop frees PCM immediately");
    EngineAudioState engine;engine.cabin_visible=true;engine.speed=1;
    audio.advance(0,engine);check(audio.resident_bytes()>0,"engine cabin entry selects running ambient");
    audio.stop_effects();engine.cabin_visible=false;audio.advance(0,engine);
    engine.cabin_visible=true;engine.speed=0;engine.pressure_reserve=1500;
    audio.advance(0,engine);check(audio.resident_bytes()>0,"engine pressure threshold selects stationary ambient");
    audio.stop_effects();audio.advance(0,{});engine={};engine.cabin_visible=true;engine.lignite=1;engine.lignite_rate=1;
    audio.advance(1.0/50,engine);check(audio.resident_bytes()>0,"shovel pickup runs on original50Hz tick");
    audio.reset();engine={};engine.oslo_visible=true;auto expected=audio.snapshot().random;
    if(expected.range(0,9)==0) {
        Resources resources(game);auto* args=field(resources.cue("scene4",0x3ed),"args");
        for(std::size_t i=0;i<json_object_array_length(args);++i) operand(json_object_array_get_idx(args,i),{},expected);
    }
    audio.advance(1.0/50,engine);check(audio.snapshot().random==expected,"Oslo samples one independent audio random draw per tick");
    audio.reset();
}
void finale(GameAudio& audio) {
    audio.reset();audio.play_reception();const auto score=audio.snapshot();
    check(audio.play_finale(1)&&audio.finale_state().cursor==std::size_t(audio.output_rate()),"bundled finale WAV resumes controller-supplied offset");
    check(audio.snapshot()==score&&audio.music_state().playing,"finale independent player preserves current scene score");
    const auto cursor=audio.finale_state().cursor;
    check(!audio.play_finale(-1)&&audio.finale_state().cursor==cursor&&audio.finale_state().playing,"invalid finale offset preserves active player");
    audio.toggle_original_music();audio.set_effects_enabled(false);
    check(audio.play_finale(0)&&audio.finale_state().playing,"finale bypasses scene music/effects preferences like source player");
    audio.stop_effects();audio.fade_music(0);
    check(audio.finale_state().playing,"scene stop and effect stop leave finale player intact");
    render(audio,1);check(audio.finale_state().cursor==1,"offline callback advances separate finale PCM");
    audio.stop_finale();check(!audio.finale_state().playing&&audio.resident_bytes()==0,"movie stop frees finale PCM independently");
    audio.reset();
}
void save_restore(GameAudio& audio,std::size_t budget,const std::filesystem::path& game) {
    audio.play_reception();audio.advance(1,{});render(audio,std::size_t(audio.output_rate()));
    const auto saved=audio.snapshot();const auto old=audio.music_state();std::string error;
    auto invalid=saved;invalid.elapsed=std::numeric_limits<double>::quiet_NaN();
    check(!audio.restore(invalid,error)&&audio.snapshot()==saved&&audio.music_state().cursor==old.cursor,"invalid elapsed restore preserves live state");
    invalid=saved;invalid.random.increment=0;check(!audio.validate_snapshot(invalid,error),"invalid PCG snapshot rejected");
    invalid=saved;invalid.track="missing";check(!audio.restore(invalid,error)&&audio.snapshot()==saved,"unknown track restore is transactional");
    GameAudio resumed(game,{false,budget,0},999);
    check(resumed.restore(saved,error)&&resumed.snapshot()==saved,"typed snapshot restores independent RNG and preferences");
    check(resumed.music_state().cursor==old.cursor,"restore seeks elapsed score offset");
    resumed.advance(0,{});check(resumed.snapshot()==saved,"zero delta after restore preserves state");
    check(GameAudio::score_position(1,10,10,true,20,60)==1,"score initial attack seek");
    check(GameAudio::score_position(7,10,10,true,20,60)==3,"score seek wraps inside loop after attack");
    check(GameAudio::score_position(100,10,10,false,0,100)==10,"nonloop seek clamps to PCM end");
    audio.reset();resumed.reset();
    GameAudio tiny(game,{false,1,0},1);
    check(!tiny.play_track("bopres-0")&&tiny.resident_bytes()==0&&!tiny.last_error().empty(),"WAV budget rejects before decoding without residency");
}
}
int main(int argc,char** argv) {
    if(argc!=3) {std::cerr<<"usage: audio_tests <game-directory> <owner-provided-budget-bytes>\n";return 2;}
    try {
        const auto budget=std::stoull(argv[2]);
        priorities();mixing();trusted_paths(argv[1]);
        GameAudio audio(argv[1],{false,budget,0},42);
        scores(audio);effects(audio,argv[1]);finale(audio);save_restore(audio,budget,argv[1]);
        std::cout<<checks<<" native audio checks, "<<failures<<" failures\n";
        return failures?1:0;
    } catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
