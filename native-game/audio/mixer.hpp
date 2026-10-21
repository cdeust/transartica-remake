// SPDX-License-Identifier: MIT
#pragma once
#include <array>
#include <cstddef>
#include <filesystem>
#include <memory>
#include <vector>

namespace transartica::audio {
// Interleaved stereo float PCM in the output device rate. Conversion is SDL's.
struct Clip {
    std::vector<float> pcm;
    std::filesystem::path source_path;
    int pitch_numerator=1,pitch_denominator=1;
    int rate{};
    int source_rate{};
    std::size_t source_frames{};
    std::size_t frames() const { return pcm.size()/2; }
    std::size_t bytes() const { return pcm.size()*sizeof(float); }
};
struct Voice {
    std::shared_ptr<const Clip> clip;
    std::size_t cursor{};
    int priority=-128, repeats{};
    float gain{};
    bool playing{};
};
struct MusicVoice {
    std::shared_ptr<const Clip> clip;
    std::size_t cursor{}, loop_begin{}, loop_end{};
    float gain=1;
    bool playing{}, loop{};
};
class Mixer {
public:
    // Source: sample_channels.gd / ALIS audio.c, four original effect channels.
    std::array<Voice,4> channels;
    MusicVoice music,finale; // campaign_screen.gd owns a separate finale player.
    int choose(int priority) const;
    int play(std::shared_ptr<const Clip>,int priority,int volume,int repeats);
    bool play_music(std::shared_ptr<const Clip>,bool loop,std::size_t begin,std::size_t end,std::size_t cursor,float gain);
    void stop_effects();
    void stop_music();
    void render(float* interleaved,std::size_t frames) noexcept;
    // Main thread only, under the device lock. Callback never frees a clip.
    void collect_finished();
    std::size_t resident_bytes() const;
};
}
