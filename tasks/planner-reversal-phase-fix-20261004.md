# Planner reversal phase correction

- [x] Diagnose native9875/9876 against YODA reverse and TIME turn phase.
- [x] Carry the true phase through the planner state and reverse edges.
- [x] Preserve observed9875 and earned9876 privately and test all source phases.
- [x] Run the dedicated regression before/after and freeze the lot.

Gate: the planner's post-reverse switch and exit must agree with detached
TrainJourney replay from the exact earned snapshots. This is a model regression,
not native earned acceptance. Root owns the pilot and all native inputs.

Cause: native9875 reverses from phase1 to phase0. The old planner encoded every
reverse as phase0 to phase1, skipping a turn that the next native cycle executes.
The pilot then matched route23/current23 and issued no switch command.

Source: `reference-private/yoda-listing.json` at 0x1962 stores
`abs(main[0x2fba] - 2) - 1`; `reference-private/time-listing.json` at 0x14bd
compares the phase with 1 before the heading switch. TIME 0x05a6..063f commits
the next cell at phase3 and resets to phase0. The production equivalents are
`TrainJourney.reverse_direction` and `advance`. Station emergence remains
phase0, matching `depart_from_station`; no rail or gameplay rule was changed.

Planner API: `plan(position, heading, target, phase=0)`. Every movement carries
its starting `phase`; reversal carries `phase_before` and `phase_after`.
Search states distinguish phases -1,0,1,2; all reversal edges use the source
formula. A turn is pending only for phases below `Journey.TURN_PHASE`.
Three-argument callers retain their phase0 behavior. The parent owns passing
the saved phase and preparing switches before native resume.

Private fixtures: `planner-reversal-observed9875.json` is the exact diagnostic
snapshot, not a full save. `planner-reversal-earned9876.json` is the exact earned
full save. Other phases are explicitly labeled model variants.

Verification (Godot 4.5, Dummy audio, detached models):

- Baseline copied from fc4e91dd1e2ef5d8f6bc260a6e13a15e8d482dc7:
  `test_planner_reversal_phase.gd -- --before-planner`, exit1, raw failure
  `ERROR: 9875 reverse must prepare22 before east departure`.
- Current `test_planner_reversal_phase.gd`, exit0, raw result
  `PASS: earned9875/9876 planner reverse phases, switch preparation and detached journey agreement`.
  Tests all four source phases against actual Journey cell exit, exact9876
  wrong-switch turn and prepared-switch exit, default API and map preservation.
- `test_train_journey.gd`, exit0, raw result
  `PASS: decoded rail network, curves, switches, double-speed tiles, boundaries, stations, persistence`.
- `git diff --check` for the owned files: exit0.

Commands used `.toolchain/Godot.app/Contents/MacOS/Godot --headless --audio-driver
Dummy --path game --script res://tests/<test>.gd`. Logs and baseline remain in
`.cache/planner-reversal-phase-fix-20261004/`. Both test processes returned their
exit codes directly; none remain active from this task. The host certificate
lookup reports `get_system_ca_certificates` in both before and after logs.
No native gameplay acceptance is claimed. Owned files are frozen for review.

## Native follow-through

The root pilot loaded the byte-identical earned9876 save through OPTIONS at
9900, selected switch22 while paused at9902, resumed, and reached30,24 at9921.
9922 paused travel and9923 recorded a real F5 save. The rendered9923 capture
was inspected: the convoy follows the selected straight rail and all21 poses
remain in the recorded state. No live model state was assigned.

The corrected pilot then reached Bayreuth at9958, opened its information and
rumours at9959/9961, departed through EXIT at9963 and entered Berlin at10019.
Berlin's actual SPY transaction10020/10021 recruited one aboard the earned
spy wagon. This is a partial native campaign, not proof of its ending.

Independent planner/pilot review: APPROVE, no blocking findings. The reviewer
checked9902 and9923 snapshots and ran the phase regression and isolated pilot
ordering check without native inputs. Source checker:0errors/0warnings.
Craftsmanship:0errors,1 advisory for the53-line pilot loop.

The full detached campaign test initially failed because its Chart test double
missed the production restore callback. campaign_route_checkpoint.gd now
implements that callback and checks both disk restores synchronize to the
restored fractional position. Both complete modeled campaigns pass with10657
advance calls and1713 entered cells; disk resume preserves the same finale.
These model tests supplement the native run. Dummy-audio shutdown still
reports ObjectDB instances; macOS sandbox certificate lookup also reports an
error. Neither is called native rendering or clean platform acceptance.
