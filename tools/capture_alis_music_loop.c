/* MIT. Observe two original score cycles at the native music-buffer boundary.
 * sys.c:sys_audio_callback consumes smpidx, then calls audio.soundrout and
 * copies mutaloop generated frames. Observer calls the original unchanged. */
#include <SDL2/SDL.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "audio/audio.h"

static sAudio *engine;
static sMV2Audio *score;
static void (*original_callback)(void *, Uint8 *, int);
static void (*original_fill)(void);
static FILE *pcm;
static FILE *metadata;
static uint64_t frames;
static uint64_t fill_position;
static uint64_t callback_end;
static uint64_t boundaries[2];
static unsigned previous_order;
static unsigned previous_row;
static unsigned wraps;
static int observed;
static int complete;

static void observe_fill(void) {
    original_fill();
    unsigned order = score->muptr;
    unsigned row = score->mucnt;
    if (order || row) observed = 1;
    int wrapped = (score->mumax > 1 && order == 0 && previous_order > 0) ||
                  (score->mumax == 1 && row < previous_row);
    if (observed && wrapped && wraps < 2) {
        boundaries[wraps++] = fill_position;
        fprintf(stderr, "SOURCE_WRAP: cycle=%u pcm_frame=%llu attack_remaining=%u orders=%u\n",
                wraps, (unsigned long long)fill_position, engine->muattac, score->mumax);
        if (engine->muattac != 0) {
            fprintf(stderr, "CAPTURE_REJECTED: attack still active at source loop.\n");
            exit(2);
        }
    }
    previous_order = order;
    previous_row = row;
    uint64_t copied = engine->mutaloop;
    if (copied > callback_end - fill_position) copied = callback_end - fill_position;
    fill_position += copied;
}

static void observe_callback(void *userdata, Uint8 *stream, int length) {
    if (!engine) engine = dlsym(RTLD_DEFAULT, "audio");
    if (!score) score = dlsym(RTLD_DEFAULT, "mv2a");
    if (!pcm) {
        const char *raw_path = getenv("ALIS_CAPTURE_PCM");
        const char *meta_path = getenv("ALIS_CAPTURE_LOOP_METADATA");
        if (!raw_path || !meta_path) exit(2);
        pcm = fopen(raw_path, "wb");
        metadata = fopen(meta_path, "w");
        if (!pcm || !metadata) exit(2);
    }
    callback_end = frames + (unsigned)length / 2;
    fill_position = frames;
    if (engine && score && engine->muflag && engine->soundrout) {
        uint64_t leftover = engine->smpidx;
        if (leftover > (unsigned)length / 2) leftover = (unsigned)length / 2;
        fill_position += leftover;
        if (engine->soundrout != observe_fill) {
            original_fill = engine->soundrout;
            engine->soundrout = observe_fill;
        }
    }
    original_callback(userdata, stream, length);
    if (fwrite(stream, 1, length, pcm) != (size_t)length) exit(2);
    frames = callback_end;
    if (wraps == 2 && !complete) {
        fprintf(metadata, "{\"version\":1,\"hz\":44100,\"channels\":1,\"loop_begin\":%llu,\"loop_end\":%llu,\"orders\":%u,\"attack_remaining\":%u}\n",
                (unsigned long long)boundaries[0], (unsigned long long)boundaries[1], score->mumax, engine->muattac);
        fflush(metadata);
        fflush(pcm);
        fprintf(stderr, "CAPTURE_COMPLETE: two original cycles, native sample boundaries and attack completed.\n");
        SDL_Event event = {.type = SDL_QUIT};
        SDL_PushEvent(&event);
        complete = 1;
    }
}

SDL_AudioDeviceID observe_open(const char *device, int capture,
    const SDL_AudioSpec *desired, SDL_AudioSpec *obtained, int changes) {
    if (capture || desired->format != AUDIO_S16 || desired->channels != 1 || desired->freq != 44100) {
        fprintf(stderr, "CAPTURE_REJECTED: unexpected native mixer format.\n");
        exit(2);
    }
    SDL_AudioSpec wrapped = *desired;
    original_callback = desired->callback;
    wrapped.callback = observe_callback;
    return SDL_OpenAudioDevice(device, capture, &wrapped, obtained, changes);
}

__attribute__((used)) static struct {uintptr_t replacement; uintptr_t original;}
interpose __attribute__((section("__DATA,__interpose"))) = {
    (uintptr_t)&observe_open, (uintptr_t)&SDL_OpenAudioDevice
};
