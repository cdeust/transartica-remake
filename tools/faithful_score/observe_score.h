/* MIT. Passive instrumentation included only in an isolated ALIS source copy. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <SDL2/SDL.h>

static FILE *score_out;
static uint64_t score_frame, score_serial[4], score_ended[4];
static int score_slot[4] = {-1,-1,-1,-1};
static unsigned score_previous_order, score_previous_row, score_observed, score_cycles;
static unsigned score_wanted_cycles;
static int score_done, score_finish;

static void score_error(const char *what) {
    fprintf(stderr, "SCORE_TRACE_ERROR: %s\n", what);
    exit(120);
}
static void score_quit(const char *reason) {
    if (!score_out || score_done) return;
    fprintf(score_out,"{\"event\":\"complete\",\"frame\":%llu,\"reason\":\"%s\"}\n",
            (unsigned long long)score_frame,reason);
    if (fflush(score_out) || ferror(score_out)) score_error("trace write failed");
    score_done=1;
    SDL_Event event={.type=SDL_QUIT};
    if (SDL_PushEvent(&event)<0) score_error("SDL quit failed");
}
static unsigned score_rate(sAudioVoice *v) {
    s16 p=v->freqsam;
    return p<0 ? mv2a.tabfrq[(-p)>>2]>>2 : mv2a.tabfrq[p];
}
static void score_start(void) {
    const char *path=getenv("ALIS_SCORE_TRACE");
    if (!path) return;
    /* Offline mode changes scheduling only: wait for any callback to finish
       while muflag is still zero, then leave the device paused for this preview. */
    if (getenv("ALIS_SCORE_OFFLINE")) {
        extern int audio_id; /* source: sys/sys.c audio device owned by SDL2. */
        SDL_PauseAudioDevice((SDL_AudioDeviceID)audio_id,1);
    }
    if (score_out) score_error("unexpected second music start");
    const char *header=getenv("ALIS_SCORE_HEADER");
    const char *samples=getenv("ALIS_SCORE_SAMPLES");
    if (!header || !samples || audio.host_freq!=44100) score_error("missing metadata or wrong rate");
    /* source: mv2_gomusic selects the PCM engine when both chip flags are zero. */
    if (mv2a.muchip || mv2a.muopl2) score_error("unsupported non-PCM music engine");
    score_out=fopen(path,"wb");
    if (!score_out) score_error("cannot open trace");
    fprintf(score_out,"%s\n",header);
    score_wanted_cycles=(unsigned)strtoul(getenv("ALIS_SCORE_CYCLES") ? getenv("ALIS_SCORE_CYCLES") : "0",NULL,10);
    fprintf(score_out,"{\"event\":\"start\",\"frame\":0,\"frames\":%u,\"tempo\":%u,\"speed\":%u,\"attack\":%u,\"duration\":%d,\"release\":%u,\"orders\":%u}\n",
            audio.mutaloop,audio.mutempo,audio.mutemp,audio.muattac,audio.muduree,audio.muchute,mv2a.mumax);
    for (unsigned slot=0;slot<32;slot++) {
        u32 address=audio.tabinst[slot].address;
        if (!address) continue;
        u32 base=address-16;
        unsigned type=xread8(base);
        if (type!=2) score_error("unexpected instrument type");
        u32 length=xread32(base+2);
        if (length<32) score_error("invalid instrument length");
        char filename[4096];
        if (snprintf(filename,sizeof(filename),"%s/slot-%u.bin",samples,slot)>=(int)sizeof(filename)) score_error("sample path too long");
        FILE *out=fopen(filename,"wb");
        if (!out) score_error("cannot open sample dump");
        for (u32 i=0;i<length;i++) if (fputc(xread8(base+i),out)==EOF) score_error("sample dump failed");
        if (fclose(out)) score_error("sample close failed");
        fprintf(score_out,"{\"event\":\"instrument\",\"slot\":%u,\"address\":%u,\"type\":%u,\"transpose\":%u,\"resource_file\":\"slot-%u.bin\",\"resource_bytes\":%u,\"payload_offset\":16,\"header_hex\":\"",
                slot,base,type,audio.tabinst[slot].unknown,slot,length);
        for (unsigned i=0;i<16;i++) fprintf(score_out,"%02x",xread8(base+i));
        fprintf(score_out,"\",\"source_loop_start_field\":%u,\"source_loop_end_field\":%u}\n",xread32(base+8),xread32(base+12));
    }
    if (fflush(score_out)) score_error("header flush failed");
}
static void score_row(u32 at) {
    if (!score_out || score_done) return;
    fprintf(score_out,"{\"event\":\"row\",\"frame\":%llu,\"order\":%u,\"pattern\":%u,\"row\":%u,\"raw\":[",(unsigned long long)score_frame,mv2a.muptr,xread8(audio.mupnote+mv2a.muptr),mv2a.mucnt);
    for(unsigned i=0;i<4;i++) {
        fprintf(score_out,"%s\"",i?",":"");
        for(unsigned byte=0;byte<4;byte++) fprintf(score_out,"%02x",xread8(at+i*4+byte));
        fprintf(score_out,"\"");
    }
    fprintf(score_out,"]}\n");
}
static void score_trigger(sAudioVoice *v,unsigned slot) {
    if (!score_out || score_done) return;
    unsigned voice=(unsigned)(v-mv2a.voices);
    if (voice>=4) score_error("voice index");
    score_slot[voice]=(int)slot; score_serial[voice]++;
    fprintf(score_out,"{\"event\":\"trigger\",\"frame\":%llu,\"voice\":%u,\"serial\":%llu,\"slot\":%u,\"period\":%u,\"rate_q16\":%u,\"sample_address\":%u,\"startsam1\":%u,\"longsam1\":%u,\"startsam2\":%u,\"longsam2\":%u}\n",(unsigned long long)score_frame,voice,(unsigned long long)score_serial[voice],slot,v->freqsam,score_rate(v),v->sample,v->startsam1,v->longsam1,v->startsam2,v->longsam2);
}
static void score_tick(int mixed) {
    if (!score_out || score_done) return;
    fprintf(score_out,"{\"event\":\"tick\",\"frame\":%llu,\"frames\":%u,\"mixed\":%s,\"global_volume\":%u,\"speed\":%u,\"voices\":[",(unsigned long long)score_frame,audio.mutaloop,mixed?"true":"false",mv2a.muvolgen,mv2a.muspeed);
    for(unsigned i=0;i<4;i++) {
        sAudioVoice *v=&mv2a.voices[i];
        fprintf(score_out,"%s{\"voice\":%u,\"serial\":%llu,\"slot\":%d,\"period\":%u,\"rate_q16\":%u,\"volume\":%u,\"effect\":%u,\"delta\":%u,\"startsam1\":%u,\"longsam1\":%u,\"startsam2\":%u,\"longsam2\":%u}",i?",":"",i,(unsigned long long)score_serial[i],score_slot[i],v->freqsam,score_rate(v),v->volsam,v->type,v->delta,v->startsam1,v->longsam1,v->startsam2,v->longsam2);
    }
    fprintf(score_out,"]}\n");
}
static void score_endvoice(sAudioVoice *v,unsigned offset) {
    if (!score_out || score_done) return;
    unsigned voice=(unsigned)(v-mv2a.voices);
    if (!score_serial[voice] || score_ended[voice]==score_serial[voice]) return;
    score_ended[voice]=score_serial[voice];
    fprintf(score_out,"{\"event\":\"endvoice\",\"frame\":%llu,\"voice\":%u,\"serial\":%llu}\n",(unsigned long long)(score_frame+offset),voice,(unsigned long long)score_serial[voice]);
}
static void score_advance(void) {
    if (!score_out || score_done) return;
    /* Source: capture_alis_music_loop.c observes state AFTER original_fill.
       BOJEU2 B01 sets order=0,row=65 before advancing to order1 next tick;
       testing only a decoded order0,row0 would miss this original loop. */
    if (score_observed && ((mv2a.mumax>1 && mv2a.muptr==0 && score_previous_order>0) ||
                          (mv2a.mumax==1 && mv2a.mucnt<score_previous_row))) {
        score_cycles++;
        fprintf(score_out,"{\"event\":\"loop\",\"frame\":%llu,\"cycle\":%u}\n",(unsigned long long)score_frame,score_cycles);
        if (score_wanted_cycles && score_cycles>=score_wanted_cycles) score_finish=1;
    }
    score_previous_order=mv2a.muptr; score_previous_row=mv2a.mucnt; score_observed=1;
    if (score_finish) {score_quit("cycles");return;}
    score_frame+=audio.mutaloop;
}
static void score_stop(void) {
    if (!score_out || score_done) return;
    fprintf(score_out,"{\"event\":\"stop\",\"frame\":%llu}\n",(unsigned long long)score_frame);
    score_quit("native-stop");
}
static void score_run_offline(void) {
    if (!score_out || !getenv("ALIS_SCORE_OFFLINE")) return;
    /* Original preview has no subsequent music controls: it yields forever.
       Call the unchanged score/mixer until the same semantic completion event. */
    while (!score_done) audio.soundrout();
}
