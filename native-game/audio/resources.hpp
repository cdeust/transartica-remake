// SPDX-License-Identifier: MIT
#pragma once
#include "mixer.hpp"
#include "core/random.hpp"
#include <filesystem>
#include <map>
#include <string>
#include <json-c/json.h>

namespace transartica::audio {
using Json = std::unique_ptr<json_object,decltype(&json_object_put)>;
json_object* field(json_object*,const char*);
int integer(json_object*,const char*);
std::string string(json_object*,const char*);
struct Track {std::filesystem::path path; bool loop{}; int duration{}; std::size_t begin{},end{};};
class Resources {
public:
    explicit Resources(std::filesystem::path game);
    json_object* sample(const std::string& script,int resource) const;
    json_object* cue(const std::string& script,int offset) const;
    Track track(const std::string& key) const;
    std::filesystem::path path(const std::string& filename) const;
private:
    std::filesystem::path game_;
    std::filesystem::path private_; // Project-owned private data may be symlinked.
    Json samples_{nullptr,json_object_put}, music_{nullptr,json_object_put};
};
int operand(json_object*,const std::map<int,int>&,Random&);
std::shared_ptr<const Clip> load_clip(const std::filesystem::path&,int output_rate,int pitch_numerator,int pitch_denominator,std::size_t available_bytes);
}
