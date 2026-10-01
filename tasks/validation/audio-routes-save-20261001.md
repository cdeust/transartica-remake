# Source audio routes and schema9 recovery

Owned game_audio_routes, reception/boudoir plaque UI, game_reset and
world_session music hooks. Root owns main city/depart glue and save schema9.
Source: campaign-audio-source-20261001.md, ecs-audio-independent.md and primary
private YODA0xb54/d04,1031/1070,126a/165b; OPTION0xf3/0xfb/0x108; GLIEU0x33.

Music plaque writes the original preference without stopping current score;
authored ON/OFF label follows that flag. OPTIONS opening does not restart title
music: YODA0x288e is loss hardware fallback, not ordinary reception entry.
Signed visited city kind is read before world.visit_city, selecting0 on revisit;
first kind1/2 selects3/1, abs(kind)3 andcity45 retain source exclusions. Workshop
music starts on entry; mine music only after YES; close resumes journey, duplicate
close is inert. START resets runtime selection while retaining music/effects flags.
No generic SON effect semantics or undiscovered caller hooks were invented.

Clean final native mixer/renderer logs, each PASS/noERROR/noWARNING:
test_audio_routes-final-20261001.log, test_audio_session-final-20261001.log.
Existing full extension test_save_extensions-final-20261001.log also PASS.
Tests cover actual plaque input, current score retained, first/revisit selectors,
mine question/YES/close, ordinary ticks without restart, schema9 JSON playback
cursor/preference plus independent commerce RNG, missing/null/malformed audio
and missing/bad RNG atomic rejection; legacy8 retains campaign/world and resets
new audio defaults. JSON-normalized comparisons distinguish number serialization
from actual value changes.

Headless Dummy driver left stopped AudioStreamPlaybackWAV handles during rapid
fixture score changes; verbose logs identified those resources. Tests explicitly
require native renderer/mixer like test_game_audio, where cleanup is verified.
Fixture teardown waits the actual AudioServer next-mix boundary, not a fixed
invented delay. This is input/routing/save verification, not a new waveform or
physical Amiga timing measurement. Original audio files remain private.
