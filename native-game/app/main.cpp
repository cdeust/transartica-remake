// SPDX-License-Identifier: MIT
#include "core/session.hpp"
#include "app/session_ui.h"
#include "platform/canvas.h"
#include "platform/hash.h"
#include "view/view.h"
#include <SDL.h>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

namespace ta = transartica;
namespace fs = std::filesystem;
namespace {
struct Options {
    fs::path game;
    fs::path artwork;
    fs::path font;
    fs::path save_directory;
    fs::path captures;
    fs::path log;
    double quit_after{};
};
Options options(int argc, char** argv) {
    Options result;
    // SDL uses Contents/Resources for .app and the executable directory otherwise.
    std::unique_ptr<char,decltype(&SDL_free)> base(SDL_GetBasePath(),SDL_free);
    if(!base) throw std::runtime_error(std::string("Cannot locate runtime resources: ")+SDL_GetError());
    fs::path resources(base.get());
    if(resources.filename().empty()) resources=resources.parent_path();
    const bool app_bundle=resources.filename()=="Resources" && resources.parent_path().filename()=="Contents"
        && resources.parent_path().parent_path().extension()==".app";
    if(!app_bundle) resources/="resources";
    result.game=resources/"game";
    result.font=resources/"fonts/NotoSans.ttf";
    for (int i = 1; i < argc; ++i) {
        const std::string flag = argv[i];
        if (flag == "--help") {
            std::cout << "Transartica C++ standalone\n--game-dir PATH --artwork-dir PATH --font PATH --save-dir PATH --capture-dir PATH --log PATH --quit-after SECONDS\n"
                         "Enter: start, L/A: fuel, arrows: regulator, B: brake, Space: pause, M: map, Esc: cabin, F5: save, F9: load, F12: capture, Ctrl+Q: quit\n";
            std::exit(0);
        }
        if (++i == argc) throw std::runtime_error("Missing value for " + flag);
        if (flag == "--game-dir") result.game = argv[i];
        else if (flag == "--artwork-dir") result.artwork = argv[i];
        else if (flag == "--font") result.font = argv[i];
        else if (flag == "--save-dir") result.save_directory = argv[i];
        else if (flag == "--capture-dir") result.captures = argv[i];
        else if (flag == "--log") result.log = argv[i];
        else if (flag == "--quit-after") {
            std::size_t consumed{};
            result.quit_after = std::stod(argv[i], &consumed);
            if (consumed != std::string(argv[i]).size() || !std::isfinite(result.quit_after) || result.quit_after <= 0)
                throw std::runtime_error("--quit-after requires a positive finite number");
        } else throw std::runtime_error("Unknown option " + flag);
    }
    if(result.save_directory.empty()) {
        // Durable saves use SDL's platform preference path.
        // Explicit --save-dir is resolved first, including bounded workspace checks.
        std::unique_ptr<char,decltype(&SDL_free)> preferences(SDL_GetPrefPath("Transartica","Transartica"),SDL_free);
        if(!preferences) throw std::runtime_error(std::string("Cannot locate save directory: ")+SDL_GetError());
        result.save_directory=preferences.get();
    }
    if (result.artwork.empty()) result.artwork = result.game / "assets/travel/artwork/world-hd";
    if (result.captures.empty()) result.captures = result.save_directory.parent_path();
    return result;
}
void state_log(std::string_view event, const ta::Session& state, std::ostream* file) {
    std::ostringstream message;
    const auto pos = state.journey.fractional_position();
    message << std::setprecision(17) << "STATE event=" << event << " cycle=" << state.engine.cycles
              << " speed=" << state.engine.speed << " regulator=" << state.engine.regulator
              << " fuel=" << state.engine.lignite << ',' << state.engine.anthracite
              << " rates=" << state.engine.lignite_rate << ',' << state.engine.anthracite_rate
              << " heat=" << state.engine.heat << " reserve=" << state.engine.pressure_reserve
              << " position=" << pos.x << ',' << pos.y << " heading=" << state.journey.heading
              << " phase=" << state.journey.phase << " ticks=" << state.journey.distance_ticks
              << " brake=" << state.engine.brake << " paused=" << state.paused
              << " blocked=" << state.journey.blocked << " stop=" << std::quoted(state.journey.stop_reason)
              << " calendar=" << state.calendar.day << "," << state.calendar.hour << "," << state.calendar.minute << " factor=" << state.calendar.factor << '\n';
    std::cout << message.str() << std::flush;
    if(file) *file << message.str() << std::flush;
}
int run(const Options& config) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS | SDL_INIT_TIMER) < 0) throw std::runtime_error(SDL_GetError());
    struct SDLGuard { ~SDLGuard() { SDL_Quit(); } } guard;
    // Four times the source reception's 320x200 canvas; presentation choice only.
    std::unique_ptr<SDL_Window, decltype(&SDL_DestroyWindow)> window(
        SDL_CreateWindow("Transartica — C++ natif", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                         1280, 800, SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE), SDL_DestroyWindow);
    if (!window) throw std::runtime_error(SDL_GetError());
    std::unique_ptr<SDL_Renderer, decltype(&SDL_DestroyRenderer)> renderer(
        SDL_CreateRenderer(window.get(), -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC), SDL_DestroyRenderer);
    if (!renderer) renderer.reset(SDL_CreateRenderer(window.get(), -1, SDL_RENDERER_SOFTWARE));
    if (!renderer) throw std::runtime_error(SDL_GetError());
    SDL_SetRenderDrawBlendMode(renderer.get(), SDL_BLENDMODE_BLEND);
    SDL_RendererInfo info{}; SDL_GetRendererInfo(renderer.get(), &info);
    std::cout << "NATIVE runtime=SDL2 renderer=" << info.name << " game=" << config.game << " artwork=" << config.artwork << std::endl;
    ta::Canvas canvas(renderer.get(), config.font);
    ta::Session state;
    std::string error;
    const auto carte = config.game / "data/CARTE.FIC";
    // Source: FORMAT-CARTE.md:17, private ECS world identity.
    ta::verify_sha256(carte, "8e1067619b254d57717348fefedc1b5013eb1d7ba23200a815e36f9b856d811a");
    if (!state.load_world(carte, error)) throw std::runtime_error(error);
    ta::GameSession game(state);
    if(!game.load(config.game,error)) throw std::runtime_error(error);
    // Same owner resource ceiling as the supervised native validation process.
    ta::audio::GameAudio audio(config.game,{true,1024ULL*1024*1024,0},game.visual_random.next_u32());
    ta::View view(canvas, config.game / "assets", config.artwork);
    std::ofstream state_file;
    if(!config.log.empty()) {
        state_file.open(config.log);
        if(!state_file) throw std::runtime_error("Cannot create requested state log: "+config.log.string());
    }
    const auto log=[&](std::string_view event){
        state_log(event,state,state_file.is_open()?&state_file:nullptr);
        if(event!="cycle") {
            // Device-backed cursors distinguish playback from a successful file load.
            const auto music=audio.music_state(),finale=audio.finale_state();
            std::ostringstream line;
            line<<"AUDIO event="<<event<<" driver="<<SDL_GetCurrentAudioDriver()
                <<" rate="<<audio.output_rate()<<" music_cursor="<<music.cursor
                <<" music_frames="<<music.frames<<" music_playing="<<music.playing
                <<" finale_cursor="<<finale.cursor<<" resident_bytes="<<audio.resident_bytes()
                <<" error="<<std::quoted(audio.last_error())<<'\n';
            std::cout<<line.str()<<std::flush;
            if(state_file) state_file<<line.str()<<std::flush;
        }
    };
    ta::SessionUI ui(canvas,view,game,audio,config.game/"assets",config.save_directory,log);
    unsigned capture_index=0;
    auto previous=std::chrono::steady_clock::now();
    const auto started=previous;
    auto last_cycle=state.engine.cycles;
    log("boot");
    while(ui.running) {
        const auto now=std::chrono::steady_clock::now();
        const double elapsed=std::chrono::duration<double>(now-previous).count(); previous=now;
        SDL_Event event{};
        while(SDL_PollEvent(&event)) ui.handle(event);
        ui.advance(elapsed);
        if(last_cycle!=state.engine.cycles) {log("cycle");last_cycle=state.engine.cycles;}
        canvas.begin_frame();
        SDL_SetRenderDrawColor(renderer.get(),8,12,16,255); SDL_RenderClear(renderer.get());
        ui.draw();
        if(ui.capture) {
            fs::create_directories(config.captures);
            fs::path path;
            do { path=config.captures/("native-"+std::to_string(++capture_index)+".png"); } while(fs::exists(path));
            canvas.capture(path); std::cout<<"CAPTURE "<<path<<std::endl; ui.capture=false;
        }
        canvas.end_frame();
        SDL_RenderPresent(renderer.get());
        // Software fallback has no presentation synchronization; avoid busy spinning.
        if(!(info.flags&SDL_RENDERER_PRESENTVSYNC)) SDL_Delay(16);
        if(config.quit_after>0 && std::chrono::duration<double>(now-started).count()>=config.quit_after) ui.running=false;
    }
    log("quit");
    return 0;
}
}
int main(int argc, char** argv) {
    try { return run(options(argc, argv)); }
    catch (const std::exception& error) {
        std::cerr << "NATIVE FAILURE: " << error.what() << std::endl;
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Transartica — startup/render failure", error.what(), nullptr);
        return 1;
    }
}
