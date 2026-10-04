# Mine extraction correction

- [x] Verify original economy writers and dynamic TEXTEK72 ->41 ->42 flow.
- [x] Implement source word16 extraction and phase-owned single credit.
- [x] Preserve pending phases and legacy saves; reject inconsistent state.
- [x] Exercise arithmetic boundaries and actual Main save/restore flow in prepared tests.
- [x] Correct mines evidence and obtain independent source review.

Gate: prepared production mine flow must grant coal at text42 once, retain tile78
until result dismissal, and survive JSON restore at each phase. These tests are
models and do not constitute native earned play. Root owns that campaign.

The existing TEXTEK host scheduler uses one wait cycle per text tick. Original
result42 starts countdown60, fast clock3, and click dismissal; host wall duration
is provisional, not measured on Amiga. No automatic completion is introduced.

## Verification

Baseline fc4e91dd1e2ef5d8f6bc260a6e13a15e8d482dc7 world_actions source copied
verbatim to .cache/mining-extraction-fix-20261004/world_actions_before.gd.
Prepared Main before command:
`.toolchain/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path game --script res://tests/test_mine_extraction_session.gd -- --before-mining`
returned exit1 with `ERROR: before: source mining must credit coal`.
Same command without the baseline argument returned exit0 with
`PASS: prepared Main mining phases, JSON restore, single credit and deferred close`.

Arithmetic and WorldActions suites returned exit0. Existing world_session and
save_extensions tests compile with --check-only; their native execution remains
root-owned. Raw logs retained in .cache/mining-extraction-fix-20261004/.
Godot printed its existing macOS certificate error in headless runs. Tests above
use Dummy audio with explicit empty audio manifests in the prepared Main model;
no native earned gameplay or audio acceptance is claimed.

The original counter's <0 normalization branch is unreachable under its >0 call
guard. Counter0 retains fast factor until click; tests cover that source behavior.
No native process, input, commit or publication performed. Independent review
requested from reverse_physical_stop on the frozen source lot.

Independent review: reverse_physical_stop APPROVE, source handlers and ALIS
word arithmetic checked; arithmetic suite run exit0. No blocking finding.
Native earned campaign and host cadence acceptance remain root-owned.

Native earned-flow validation in the actual macOS release: route NOMADS→TUNIS→mine19,47 using viewport inputs, no injected state.8994 question;8995 plaque;8996 resources24 workers/no mammoths/no cranes;8997 result credits165 anthracite (wealth32, source arithmetic33×5).9001 opens OPTIONS; named MINE reload9002 restores result with165, no duplicate credit.9003 closes once, preserves165, clears pending mine and consumes its wealth. Native captures inspected. Earlier F6 on modal8998 did not open OPTIONS;8999 was a dismissal, not a reload proof. Only9002 is the actual reload evidence.
