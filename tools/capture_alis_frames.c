/* MIT. SDL framebuffer capture for the private original finale verification.
 * SDL2 API: SDL_RenderReadPixels and SDL_GetRendererOutputSize, public headers.
 * Inject only into the task-owned original ALIS preview process. */
#include <SDL2/SDL.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

static Uint32 audio_origin = 0;

void capture_present(SDL_Renderer *renderer) {
    static void (*present)(SDL_Renderer *) = NULL;
    static FILE *capture = NULL;
    if (!present) {
        present = SDL_RenderPresent;
        const char *path = getenv("TRANSARTICA_CAPTURE_FRAMES");
        if (path) capture = fopen(path, "wb");
    }
    static Uint32 previous = 0;
    Uint32 now = SDL_GetTicks();
    /* ALIS sys_sdl2 k_frame_ticks=20000us: capture its target50Hz. */
    if (capture && now - previous >= 20) {
        previous = now;
        if (!audio_origin) audio_origin = now;
        int width = 0, height = 0;
        SDL_GetRendererOutputSize(renderer, &width, &height);
        unsigned char *pixels = malloc((size_t)width * height * 4);
        if (pixels && SDL_RenderReadPixels(renderer, NULL, SDL_PIXELFORMAT_RGBA32, pixels, width * 4) == 0) {
            unsigned int dimensions[3] = {(unsigned int)width, (unsigned int)height, now - audio_origin};
            fwrite(dimensions, sizeof(dimensions), 1, capture);
            fwrite(pixels, (size_t)width * height * 4, 1, capture);
            fflush(capture);
        }
        free(pixels);
    }
    present(renderer);
}

/* macOS two-level namespace interposition, confined to this preview process. */
__attribute__((used)) static struct {uintptr_t replacement; uintptr_t original;}
interpose __attribute__((section("__DATA,__interpose"))) = {
    (uintptr_t)&capture_present, (uintptr_t)&SDL_RenderPresent
};
