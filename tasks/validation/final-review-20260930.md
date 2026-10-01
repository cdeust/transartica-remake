# Independent integrated review — 2026-09-30

Scope: read-only main, journey_session, world_session, session_saves/extensions,
world_encounters, tactical_scene/materials against FIDELITE.md and combat/world
source evidence. Updated independent review: 2026-10-01. The earned campaign route now passes;
this is not a claim of complete visual acceptance, Windows execution or Noita parity.

## Findings and verified resolution

1. RESOLVED: F6 options followed by app._open_panel("room") reopens the same
   pending manual battle. The expanded test verifies unchanged actors and ticks.
2. CORRECTION: actual main defines BOTH save_view() public bool API and
   _save_view() notice wrapper. The battle app.save_view callback is valid.
   The earlier missing-method finding was incorrect.
3. RESOLVED: encounters now serialize manual_paused. Expanded tests verify
   P-pause survives JSON save/load, prevents ticks, and P resumes the scene.
4. RESOLVED for schema8: extension staging checks finite integral calendar
   domains and mine-day consistency before mutation. Expanded tests reject
   fractional minutes, a string factor, and a future mine day, comparing the
   complete live snapshot before/after. JSON float factor membership initially
   rejected valid saves; root corrected it with validated integer conversion.
5. RESOLVED: detached network receives source city anchors and live campaign
   capability before journey restore. Expanded tests compare staged/live anchors,
   capability, and every documented story entry boundary.

These findings were sent to root for implementation. Item2 was withdrawn after
verifying the complete API. This reviewer edits only the explicitly delegated
save regression test and this report. Root implemented recovery/calendar
seams. Expanded test_save_extensions passed exit0; see
final-save-recovery-20260930.log. No implementation code edited by reviewer.

## Verified behavior and artistic evidence

- CORRECTION: PR7 deliberately validates only locomotive trailing history.
  A full-consist guard rejected the fresh source startup and was reverted.
  The original actionable missing-history warning remains; full-route rendering
  still refuses to invent absent wagon geometry. No full-consist guard claimed.
- Main blocks engine simulation for manual combat/campaign/world dialogs; world
  text countdown advances separately at seconds_per_cycle/48, following the
  documented ALIS 16 tours/minute, three minutes/cycle ratio. Mine day hooks and
  spy advancement occur from the remake calendar callback.
- Integrated save extension suite passed with campaign/world/works/manual
  recovery, atomic rejection, UI pending restoration and legacy reset; see
  final-save-test-20260930.log. The expanded follow-up suite covers findings1/3/4/5; item2 was withdrawn.
- Tactical regression passed: original weapon/actor/dynamite rules, win/loss,
  exactly-once outcomes, JSON resume, equal 30/60/144 display cadence and per-wagon
  material occupancy. See final-tactical-test-20260930.log.
- review_tactical_impacts.gd launched natively using OpenGL Compatibility on
  Apple M4 and exited0. It calls the real source cannon hit function with aligned
  train offsets, creates health2/health1 variants, displays emitted impact events
  at two visual ages, and invokes KEY_P through the scene handler. It is an art
  fixture, not an OS mouse/keyboard journey or a full combat playthrough.
- tactical-impacts-native-20260930.png shows aligned rails, visible lower wheels,
  per-instance holes and fragments, authored flash/flame/smoke keyposes and
  light. No original damage rules or simulation constants changed. Full Noita
  material physics are not implemented/proven.
- Superseded visual finding: mechanical actor/wagon crops leaked neighboring
  feet and clipped couplers. Measured authored-master regions now isolate all six
  actor silhouettes and all25 wagon kinds. Native tactical-actors-native,
  tactical-wagons-native and tactical-wagon-impacts-native-20260930.png show whole
  silhouettes without those stray fragments. All three fracture passes plus
  workshop-palette scorch make health0 visibly ruined in tactical-wreck-native.
  These are presentation adaptations; original damage/state rules remain intact.
- A different battle object clears presentation materials/effects/lights; reopening
  the same battle preserves them. test_tactical_art_cache passes.
- Authored water detail changes only measured blue-water pixels in18 source
  resource groups. Every shoreline/nonwater pixel and alpha, source texture and
  original map byte is preserved. World-cell phase is coherent; cache is bounded
  by actual visible cells. Native water-terrain-lake/city.png reviewed.

## Current integrated verification — 2026-10-01

No new blocking correctness finding in the reviewed main/journey/calendar,
encounter observation, UI recovery or atomic save seams. Current native-host
Godot4.5 runs exited0 with PASS and no ERROR/SCRIPT ERROR:

- review-save-nativehost-20261001.log: campaign/world/works/manual roundtrip,
  paused battle/options reopening, strict schema8 atomic rejection, staged map
  capability and city anchors.
- review-cadence-nativehost-20261001.log: actual host engine/journey/calendar/
  world/campaign/encounters state agrees at30/60/144Hz for equal inputs/seeds.
  Accumulator simulation remains separate from drawing; this proves tested rates,
  not universal timing equivalence for every possible input boundary.
- review-campaign-session-nativehost-20261001.log: real app story input, partial
  Oslo code recovery, interrupted finale recovery and completion/death reception.
- review-finale-nativehost-20261001.log: source choreography/timing/RNG, JSON
  cursor resume, transparent authored effects, guarded cinematic input.
- review-campaign-route-nativehost-20261001.log:10565 actual journey advance
  calls,1713 entered cells, earned original trade/works/spy/workshop inputs,
  default enemies, actual slot29 Minotaur resolver and source Sun ending to
  OPTIONS; day23 fuel1207. Reviewed driver ordering against main journey and
  encounter dispatcher: pre-entry handlers precede actual advance; encounter
  checks bracket enemy movement; changed live slots notify posted spies.
  The driver adapts UI callbacks, not the actual main process; its report sets
  pending only from the encountered live slot. No supplied route teleport/cargo/
  quest/outcome injection was found. See campaign-route.md for ledger and sources.

Earlier full-finale-integration-20260930.log contains an actual failure and is
not green evidence; current campaign-session run supersedes its finale check.
Initial sandboxed review runs reported macOS get_system_ca_certificates
ret!=noErr despite test PASS. Those runs are not clean acceptance logs; native-
host runs above are the clean evidence. Focused campaign/cache/water assertions
also passed, but retain their existing clean owner logs for final acceptance.

Remaining acceptance limits: the earned full route does not itself perform an
intermediate disk save/restore, although actual app partial-code/finale/manual
recovery tests cover those seams separately. A full-route resumed replay would
strengthen the FIDELITE campaign-with-intermediate-saves criterion. Windows
executable execution remains unverified. All-original visual-state/animation
review and configurable-command coverage require the inventory owner to close
explicitly; current artifacts prove the inspected states only. Noita-inspired
smoke/debris/light and per-wagon authored masks are integrated, not Noita's
complete material physics. Final audio and final staged root tree are outside
this bounded review; rerun root gates after those concurrent changes settle.

## Protected local state / cleanup

Protected worktree: /Users/cdeust/Developments/Transartica/.worktrees/tactical-combat.
Unstaged temporary dependency fixes remain in game/scripts/world_actions.gd
and game/scripts/campaign_session.gd under that exact path. Automatic approval
rejected git restore: "The restore would discard uncommitted changes in two
files, including a numeric-validation fix and campaign reset changes; the
transcript does not provide trusted user authorization that these edits are
disposable." No workaround performed. They are excluded delivered commits
4cdbd41 and 1b2c1bf. Earlier cleanup removed59 generated metadata files and
66,234,446 bytes of owned import cache. Required evidence and unpushed commits
remain protected. The stalled first native capture process was interrupted;
the corrected native capture exited0, without touching another native window.
