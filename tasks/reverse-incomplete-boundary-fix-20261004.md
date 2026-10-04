# Reverse incomplete station footprint

Owner owns native player inputs. This is a prepared source regression.

- [x] Read earned10646/10738 saves and native10667..10738 metadata.
- [x] Reproduce old guard with exact10646 and source toggle observed10647.
- [x] Share accepted physical boundary classes between full/partial footprints.
- [x] Test actual Main boundary callback, save/restore and city departure.
- [x] Independent reviewer /root/reverse_physical_stop returned APPROVE after
 fresh-marker correction and final gates.
- [ ] Native owner-run reload of earned10738 after rebuilding.

Cause: Bayreuth departure10586 legitimately emerges with hidden wagons. Native
10646 reverses at28,24 with 9 rendered vehicles; after10647 switches29,24,
reverse reroute creates 20 contacts on the branch ending at Turin31,37.
ReverseContactStop treated only hidden -115 in its incomplete-footprint branch,
then allowed TIME to continue toward the refused station. Contacts 20 became 1
before normal locomotive arrival10736. The pause was a real Turin city visit,
not evidence of native focus loss. Saved10738 has physical_obstacle[-1,-1],
position32,37, heading4, phase2, station stop and 1 pose.

Fix: both full and incomplete footprint branches now classify the solver's
actual refused contact with the same helper: works, station or special site.
Original emergence is retained: it has no newly refused station contact to
prepare. Exact10646 replay now stops at position29,24 with physical_obstacle
31,37 and 20 poses. It does not manufacture a twenty-first pose through a city.
JourneySession's existing physical boundary callback opens Turin at that
contact. Real Main SAV round-trip retains it; real departure returns to normal
hidden-interior station emergence.

Source: original CARTE31,37=35, accepted rear-contact timing in
reverse-obstacle-adaptation-20261003.md, TrainJourneyRender's actual refused
contact, JourneySession/WorldSession station dispatch. No source travel phases,
rail turn, city stock rule or vehicle dimensions changed.

Tests and exact fixtures:

- test_reverse_incomplete_boundary.gd with private exact10646/10738 fixtures.
- Old-guard baseline cache before-partial-stop.gd; final before/after logs in
 .cache/reverse-hidden-contact-fix-20261004/incomplete-{before,after}.log.
- The prepared Main test disables effects/music for Dummy only. Host certificate
 warning and ObjectDB shutdown warning remain; no clean-log claim.

Lesson: a valid incomplete station-emergence footprint is not permission to
continue through a newly refused physical contact. Check the same boundary
classes as the full-footprint guard, then preserve the legitimate hidden city
interior during arrival/departure. Native10736 pause must be classified from its
actual city screen and blocked station save before attributing it to focus.

Final gates: baseline incomplete replay including Main returns exit1; corrected
 replay returns exit0. Existing reverse_physical_stop, reverse_earned_history,
 reverse_continuity, reverse_special_modal, reverse_stop_release and
 station_matrix regressions return exit0 after this change.

The solver refusal marker is transient and may stay stale after a ports-only
 failure. Clear it immediately before the initial pose solve; classify only a
 refusal produced by that solve. A prepared stale31,37 marker on the earned
 nine-pose emergence continues, then the exact earned phase is restored before
 source switch replay. All six final-partial regression logs return exit0 after
 this last source change. The baseline with the same expanded test returns1.

Expanded final test also loads already-arrived earned10738 via actual Main:
 restore succeeds, position32,37 and Turin visit stay unchanged, and the single
 existing contact stays single. The fix prevents loss before arrival; it does
 not relocate this earned checkpoint or invent missing rail contacts.

Root native replay from earned10646 in the rebuilt application passes:
10768 has20 poses;10769/10770 stops at29,24 with physical31,37 and opens TURIN,
retaining20 poses. Viewport inspection10771 shows the convoi still on rails;
10772 returns to the preserved visit. Actual EXIT10773 departs to32,37 with
the legitimate one-vehicle emergence. The subsequent real journey reaches
the underground mouth51,39 with all21 poses (10897..10898) and52,39 (10904).
No save relocation or reconstructed player state was used.
