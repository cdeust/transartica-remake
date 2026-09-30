/* MIT. Stop a task-owned ALIS preview on its original music order wrap.
 * ABI definitions come from the pinned ALIS audio.h; no original audio copied.
 * No wall-time pass/fail limit: primary music state is the completion signal. */
#include <SDL2/SDL.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>
#include "audio/audio.h"

void observe_present(SDL_Renderer *renderer) {
    static sMV2Audio *music = NULL;
    static sAudio *engine_audio = NULL;
    static unsigned short previous = 0;
    static unsigned short previous_row = 0;
    static int observed = 0;
    static int complete = 0;
    if (!music) music = dlsym(RTLD_DEFAULT, "mv2a");
    if (!engine_audio) engine_audio = dlsym(RTLD_DEFAULT, "audio");
    if (music && music->mumax && !complete) {
        unsigned short order = music->muptr;
        unsigned short row = music->mucnt;
        if (order > 0 || row > 0) observed = 1;
        if (observed && ((engine_audio && !engine_audio->muflag) ||
                        (music->mumax > 1 && order < previous) ||
                        (music->mumax == 1 && row < previous_row))) {
            fprintf(stderr, "CAPTURE_COMPLETE: original music order wrapped or score stopped (%u orders).\n", music->mumax);
            SDL_Event event = {.type = SDL_QUIT};
            SDL_PushEvent(&event);
            complete = 1;
        }
        previous = order;
        previous_row = row;
    }
    SDL_RenderPresent(renderer);
}

__attribute__((used)) static struct {uintptr_t replacement; uintptr_t original;}
interpose __attribute__((section("__DATA,__interpose"))) = {
    (uintptr_t)&observe_present, (uintptr_t)&SDL_RenderPresent
};
