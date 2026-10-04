# Reverse occupied switch investigation,4Oct

Scope: detached earned saves and production geometry. Root owns native play.

- [x] Check the actual11194,11195,11300,11437,11447 saves and contiguous native observations.
- [x] Reproduce late occupied49,39 toggle from unchanged11437.
- [x] Check a prepared unoccupied-switch case with one locomotive.
- [x] Preserve existing earned7087 physical stop and release gates.
- [x] Validate persisted continuity after a genuine occupied toggle.
- [x] Obtain independent review of the final correction.
- [x] Root verifies the built native artifact through real controls11453..11473.

## Evidence and result

The actual tunnel run is consistent with the approved3Oct reverse adaptation. The last wagon leads while backing. All21contacts are identical across11194 to11195. The leading rear exits the western mouth at11403; by11437 the locomotive is arriving at the same mouth and the other vehicles have already reached surface rails. The source turnout49,39 remains21 in all five saves. Its westbound result is7. This run does not demonstrate a sampler sign defect.

The separate late-toggle gate uses the unchanged11437 fixture in `reference-private/validation/reverse-occupied-switch-earned.json`, production `toggle_switch(49,39)` and the exact renderer chord solve. Before the candidate correction, occupied contact divergence reaches26.9009552001953 map cells, and the changed train reaches48,39 while the unchanged control reaches48,38. The switch alone does not move contacts; the following logical turn destroys and rebuilds their occupied prefix.

The initial candidate retains the occupied path and trims forecast ahead of the exact leading rear. Its late-toggle divergence is0.0 with21contacts. A prepared one-locomotive composition still follows the unoccupied straight switch to48,39 after a previous draw forecast. Both are model proofs, without native input.

The candidate is **not accepted**. Earned7087 contains historical turnout branches different from the live point route. Treating every occupied historical branch as logical authority sends it toward29,14 instead of its existing crevasse6,9 stop. Narrowing authority to all switches still fails at historical switch10,1. Existing physical stop and release gates fail. No assertions were weakened.

## Compatible correction

The unsupported broad guide was removed. The actual `TravelWorld.toggle_switch_at` command measures the renderer's complete occupied footprint before changing parity. A latch requires the switch center to lie strictly between the leading rear and the locomotive front, with the retained incoming and outgoing half-cell ports matching the live source turn before the command. Repeated toggles retain the same proved occupied branch. Render-only calls never create a latch.

`Journey.reverse_switches` persists the outgoing heading for that contact. Production restore validates the canonical cell key, switch tile and corresponding retained outgoing port before committing any state. Missing legacy metadata means no latch. The latched branch guides the later locomotive turn; its unoccupied forecast is trimmed using the exact solved rear distance. The latch retires after the locomotive front clears the outgoing port. Departure/reset clear it, and reversing forward keeps all contacts while retiring reverse-only metadata.

The final detached gate passes with divergence0.0, all21contacts and matching48,38 exits after the late command. The one-locomotive early command still reaches48,39 without a latch. Command-only contacts are unchanged. Production Journey restore preserves the latch before movement and rejects a wrong outgoing heading atomically. A real Main instance restores unchanged11437, issues the actual command, saves and reloads through SessionSaves with21unchanged contacts. The full staged pipeline also rejects an invalid branch without changing live state.

The earned7087 physical stop and release regressions pass again. Hidden earned contacts, spy YES/NO and wolf modal continuation, Turin partial station contact, all75station ports,32alternative physical-stop scenarios and the recorded reverse continuity regression pass. Planner phases preserve their existing source contract. Save extensions and atomic rejection pass. These are prepared headless proofs, not native play. Main shutdown logs retain the existing ObjectDB warning and macOS reports its existing certificate warning.

Raw before and final logs are in `.cache/reverse-occupied-switch-20261004/`. Independent reviewer `/root/reverse_physical_stop` approved the final command latch after reading its code and final Main proof. The root's rebuilt native command replay remains required before delivery.


## Built artifact acceptance

Root rebuilt and launched the macOS exported app. It loaded byte-identical
earned11437 through the normal named-book menu at11453. At11454, an actual
viewport click flips49,39 from21 to20 while paused; all21contacts stay exactly
unchanged and F5 persists outgoing7. Live resume11455..11468 keeps21vehicles
and reaches48,38. Root pauses and F5-saves11470, then inspects its PNG. Across
11453..11470 the largest consecutive contact displacement is0.3157381673 map
cells; this is measured sampling, not a new physics threshold.

The normal named-book load of the unchanged11470 snapshot at11473 preserves
all21contacts with zero displacement. Full input/capture evidence resides in
tasks/validation/continuous-play-20261003; full earned saves remain private.
Native app is paused48,38,cycles9850. This proves the occupied-switch case in
the built artifact; the complete campaign remains unfinished.
