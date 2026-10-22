// SPDX-License-Identifier: MIT
// Cue semantics: scripts/audio_cue.gd. Conversion: SDL_audio.h AudioCVT contract.
#include "resources.hpp"
#include <SDL.h>
#include <algorithm>
#include <climits>
#include <cstring>
#include <stdexcept>

namespace transartica::audio {
namespace {
Json read(const std::filesystem::path& path) {
    Json result(json_object_from_file(path.string().c_str()),json_object_put);
    if(!result || !json_object_is_type(result.get(),json_type_object)) throw std::runtime_error("Invalid audio manifest: "+path.string());
    return result;
}
int pop(std::vector<int>& values) {
    if(values.empty()) throw std::runtime_error("Invalid audio operand stack");
    const int value=values.back();values.pop_back();return value;
}
}
json_object* field(json_object* object,const char* key) {
    json_object* result=nullptr;
    if(object) json_object_object_get_ex(object,key,&result);
    return result;
}
int integer(json_object* object,const char* key) {return json_object_get_int(field(object,key));}
std::string string(json_object* object,const char* key) {
    auto* value=field(object,key);return value?json_object_get_string(value):"";
}
Resources::Resources(std::filesystem::path game):game_(std::filesystem::weakly_canonical(game)),
    data_(std::filesystem::weakly_canonical(game_/"data")) {
    samples_=read(game_/"data/audio/manifest.json");
    const auto score=game_/"assets/audio/orchestral/music.json";
    music_=read(std::filesystem::exists(score)?score:game_/"data/audio/music.json");
    if(!field(samples_.get(),"scripts") || !field(music_.get(),"tracks")) throw std::runtime_error("Audio manifest lacks scripts/tracks");
}
std::filesystem::path Resources::path(const std::string& filename) const {
    auto relative=filename.starts_with("res://")?std::filesystem::path(filename.substr(6)):std::filesystem::path("data/audio")/filename;
    if(relative.generic_string().starts_with("private-data/"))
        relative=std::filesystem::path("data")/relative.lexically_relative("private-data");
    const auto resolved=std::filesystem::weakly_canonical(game_/relative);
    const auto within=[&](const std::filesystem::path& root) {
        const auto relative=resolved.lexically_relative(root);
        return !relative.empty()&&!relative.is_absolute()&&*relative.begin()!="..";
    };
    // Historical manifests retain their source paths; the native layout uses data/.
    if(filename.empty() || (!within(game_)&&!within(data_))) throw std::runtime_error("Audio path outside trusted game/data roots");
    return resolved;
}
json_object* Resources::sample(const std::string& script,int resource) const {
    return field(field(field(field(samples_.get(),"scripts"),script.c_str()),"samples"),std::to_string(resource).c_str());
}
json_object* Resources::cue(const std::string& script,int offset) const {
    auto* cues=field(field(field(samples_.get(),"scripts"),script.c_str()),"cues");
    if(!cues) return nullptr;
    for(std::size_t i=0;i<json_object_array_length(cues);++i) {
        auto* item=json_object_array_get_idx(cues,i);
        if(integer(item,"offset")==offset && string(item,"name")=="csound") return item;
    }
    return nullptr;
}
Track Resources::track(const std::string& key) const {
    auto* entry=field(field(music_.get(),"tracks"),key.c_str());
    if(!entry) throw std::runtime_error("Unknown music cue: "+key);
    const auto begin=json_object_get_int64(field(entry,"loop_begin")),end=json_object_get_int64(field(entry,"loop_end"));
    if(begin<0 || end<0) throw std::runtime_error("Negative music loop bounds");
    return {path(string(entry,"file")),bool(json_object_get_boolean(field(entry,"cycle"))),integer(entry,"duration_ticks"),std::size_t(begin),std::size_t(end)};
}
int operand(json_object* item,const std::map<int,int>& locals,Random& random) {
    const auto name=string(item,"name");auto* args=field(item,"args");
    const auto first=[&]{return json_object_array_get_idx(args,0);};
    if(name=="oimmb" || name=="oimmw") return json_object_get_int(first());
    if(name=="odirb") {const auto it=locals.find(json_object_get_int(first()));return it==locals.end()?0:it->second;}
    if(name!="oeval") throw std::runtime_error("Unsupported audio operand: "+name);
    int accumulator=0;std::vector<int> stack;
    for(std::size_t i=0;i<json_object_array_length(args);++i) {
        auto* child=json_object_array_get_idx(args,i);const auto op=string(child,"name");
        if(op=="opushacc") stack.push_back(accumulator);
        else if(op=="opile") accumulator=pop(stack);
        else if(op=="ornd") accumulator=random.range(0,std::max(0,accumulator-1));
        else if(op=="oadd") {
            auto* value=json_object_array_get_idx(field(child,"args"),0);
            accumulator+=string(value,"name")=="opile"?pop(stack):operand(value,locals,random);
        } else if(op!="ofin") accumulator=operand(child,locals,random);
    }
    return accumulator;
}
std::shared_ptr<const Clip> load_clip(const std::filesystem::path& path,int rate,int numerator,int denominator,std::size_t budget) {
    if(rate<=0 || numerator<=0 || denominator<=0) throw std::runtime_error("Invalid audio rate");
    // Authored resources are PCM WAVs; preflight their file payload before SDL allocates.
    if(std::filesystem::file_size(path)>budget) throw std::runtime_error("Audio decode exceeds available budget: "+path.string());
    SDL_AudioSpec source{};Uint8* data=nullptr;Uint32 length=0;
    if(!SDL_LoadWAV(path.string().c_str(),&source,&data,&length)) throw std::runtime_error("Audio WAV: "+std::string(SDL_GetError()));
    std::unique_ptr<Uint8,decltype(&SDL_FreeWAV)> wave(data,SDL_FreeWAV);
    const auto source_frame=std::size_t(SDL_AUDIO_BITSIZE(source.format)/8)*source.channels;
    const auto pitched=std::int64_t(source.freq)*numerator/denominator;
    if(!source_frame || length%source_frame || !length || length>INT_MAX || pitched<=0 || pitched>INT_MAX || length>budget) throw std::runtime_error("Invalid audio PCM size/rate");
    SDL_AudioCVT conversion{};
    if(SDL_BuildAudioCVT(&conversion,source.format,source.channels,int(pitched),AUDIO_F32SYS,2,rate)<0) throw std::runtime_error(SDL_GetError());
    const auto multiplier=std::size_t(std::max(1,conversion.len_mult));
    if(multiplier>(budget-length)/length) throw std::runtime_error("Audio conversion exceeds available budget");
    const auto capacity=std::size_t(length)*multiplier;
    std::unique_ptr<Uint8,decltype(&SDL_free)> buffer(static_cast<Uint8*>(SDL_malloc(capacity)),SDL_free);
    if(!buffer) throw std::bad_alloc();
    std::memcpy(buffer.get(),data,length);conversion.buf=buffer.get();conversion.len=int(length);
    if(SDL_ConvertAudio(&conversion)<0) throw std::runtime_error(SDL_GetError());
    const auto bytes=std::size_t(conversion.len_cvt);
    if(conversion.len_cvt<=0 || bytes%(2*sizeof(float)) || bytes>budget-length-capacity) throw std::runtime_error("Audio converted PCM exceeds available budget");
    auto result=std::make_shared<Clip>();result->rate=rate;result->source_rate=source.freq;result->source_frames=length/source_frame;
    result->source_path=path;result->pitch_numerator=numerator;result->pitch_denominator=denominator;
    result->pcm.resize(bytes/sizeof(float));std::memcpy(result->pcm.data(),buffer.get(),bytes);
    return result;
}
}
