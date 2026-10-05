# Occupied prefix and actual contact refusal,4Oct

- [x] Inspect earned11707 and distinguish its rollback poses from the rejected trial.
- [x] Replay unmodified genuine11686 with actual11687 switch command in Main.
- [x] Preserve matching occupied geometry without changing source point heading rules.
- [x] Protect a switch inside a measured partial contact interval before its command.
- [x] Verify physical early-switch obedience and partial save/reload.
- [x] Run existing physical stop and station compatibility gates.
- [x] Independent final review5October: APPROVE; six targeted regressions pass.
- [x] Root replayed the rebuilt artifact through native controls11716..11735.

## Cause

Native11707 stores21 rollback contacts ending at44.5,25.5, while its physical boundary says49,33. The rejected source step had rebuilt the complete reverse prefix from the locomotive's34,32 center. Its trial had only19 contacts, ending at47.89204,33, and refused49,33. Rear relocation reached7.319104 map cells in one step. This is not a harmless failed far-ahead chord probe. The old body was replaced by another route before the guard restored the earlier frame.

The retained outgoing port at34,32 already agrees with the source TIME turn to heading6. Rebuilding that matching branch is unnecessary and loses the actual occupied route. Retain it when its port agrees with the selected source heading. Only an explicit measured switch-command latch may select a different logical turn; arbitrary legacy history keeps its existing point contract.

The actual11687 command also matters. Earned11686 has42,32=19 and15 solved contacts. Native11687 changes it to18 while42 lies inside those known contacts. The previous capture helper required all21vehicles and missed that proof. A switch inside the interval from the first solved front to the last solved rear is occupied, regardless of unknown later vehicles. Capture that branch before the successful command, without inferring geometry beyond the last known rear. Save/restore preserves this partial proof and all15known contacts.

Retaining matching geometry must not retain unoccupied forecasts as route authority. Trim forecast ahead of the exact solved rear before every complete physical movement. The strengthened free49 test checks the leading rear on every step before the locomotive reaches the turnout. Matching-prefix retention alone failed that check; exact trimming passes. A switch command alone still moves no known contact.

## Measured gate

`game/tests/test_reverse_refusal11707.gd` loads byte-identical11686 through actual Main and SessionSaves, executes the actual11687 switch command and dispatches hidden source entries normally at the earned speed130. It does not clear stop fields or alter the saved rail path. The before mode uses the pre-fix copied Journey/Render and command capture helper; its script class name and Render preload are the only fixture plumbing changes. Production visibility is checked before the baseline parity mutation.

Before: exit1, source dispatch prepares the reconstructed43,32 through49,33 branch, then reports physical49,33 while logical34,32 remains phase0 and its rollback frame still has21contacts. After: exit0, source dispatch prepares44,30 through44,26 and then45,25, reaches34,32 phase1 without blockage, and retains21contacts with rear44.61261,25.3874. Partial command save/reload runs through the production staging pipeline before movement.

Raw evidence is `.cache/reverse-refusal-11707-20261004/earned-before.log` and `earned-after.log`. The earlier isolated11707 trial logs are retained separately as diagnostic evidence; the acceptance gate uses genuine11686 without releasing fields.

The earned7087 crevasse stop and release gates pass. The75station-port matrix passes, as do Turin partial contacts, hidden saved histories and spy YES/NO or wolf modal continuation. The32alternative physical stop scenarios pass. The late11437 and strengthened early49 switch tests pass, including partial11686 command contacts. Planner phase compatibility and save-extension atomic rejection pass. Main shutdown retains its existing ObjectDB warning; the host certificate warning also remains.

The incorrect already-blocked11707 save is not automatically migrated. Root loaded genuine11686 through normal controls11716. The actual latched42branch defers its newly selected straight track until a future visit; native itinerary continuation must follow the actual occupied route and be inspected by root.

## Native rebuilt artifact replay

On4October root exported DEBUG macOS and launched the resulting Transartica.app with the existing viewport-input console. Normal book load11716 restores byte-identical earned11686 at33,31 with15known contacts. Actual click11717 changes42,32 from19 to18. Native11729..11735 passes34,32 without blockage and with21contacts. New stop11767/11768 is physical51,23: last known rear50.5,23, all21contacts retained. This terminal is the previously occupiedNEbranch, not the removed reconstructed49,33 refusal. Screenshot11769 inspected. Root reversed through the actual control11775 and retreated by live input. The geometric fix has native confirmation; itinerary aid remains unaware of occupied-switch constraints.
