# Rigid train precision regression, 1 October 2026

The unchanged renderer draws all 25 vehicle kinds at origin zero across eight
headings. Moving the identical unlimited straight history to (80,40) leaves only
one vehicle at heading 4 and none at heading 6. The retained before log records
those failures. This is a presentation defect, independent of route availability.

Absolute map projection rounds large Vector2 coordinates before subtraction.
Projecting the local world displacement avoids that additional cancellation.
However, local projection alone still fails headings 4 and 6 in the retained
intermediate log: sampled world positions also have finite Vector2 precision.
The last bisection sample may be less accurate than an earlier valid contact.

The final search projects each local displacement and retains the closest valid
sample across the original 24 iterations. It receives the already sampled front
world point, avoiding a redundant history lookup. The original is_equal_approx
acceptance remains unchanged, as do vehicle lengths and the search bracket.
Missing-history samples never become candidates. No route extrapolation is used.

The native Apple M4 run tests all 25 vehicle kinds at all eight source headings
at ZERO, (80,40), and the source map's far corner (159,72). All 600 vehicle poses
are present; each local projected chord satisfies the original comparison, and
adjacent vehicles share exactly the same rail-contact position. At every tested
origin/heading, 0.6-cell history produces no incomplete locomotive.

The existing test_train_renderer checks exact 0.75-cell acceptance, incomplete
trailing wagons and complete consists. It passes. Existing journey, camera-scale
and both reversal fixtures also pass without ERROR or WARNING. Native diagnostics
and source/craftsmanship checks are retained beside this report; both gates have
zero errors and zero warnings. The regression is game/tests/test_renderer_precision.gd.

A fixed 128-call native CPU A/B measurement at origin zero, heading 6, with all
25 kinds measured before median 408 microseconds/p95 501 and final median 421/p95
523. The final median difference is 13 microseconds per complete 25-vehicle pose
calculation. This measurement covers pose calculation, not GPU drawing or frame
time. Both implementations returned the same 25 poses for the measured workload.
The JSON and native benchmark log retain the exact sample count and scores.
The baseline script was read from committed 79c80b2 into this worktree's owned
cache; production source was never replaced during measurement.

Final implementation changes are limited to train_renderer.gd and the precision
regression. The authored overhead silhouettes and decoded source geography remain
subject to the existing full-route and native visual acceptance checks.
