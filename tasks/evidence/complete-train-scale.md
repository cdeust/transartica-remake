# Complete train on the original network

Owner instruction, 27 September: retain the original railway network and adapt
its displayed scale to show a complete train instead of the original single
locomotive symbol. This permits a presentation ratio, not new rail connections.

Native measurements of the original initial seeded path found 5.414214 cells of
known history. The previous one-wagon-per-cell ratio drew only five complete
vehicles. Ratios 0.85, 0.8 and 0.75 each drew six. At 0.75, the train consumes
4.527590 cells, leaving 0.886623 known cells behind it; maximum chord error in the
probe was 0.000522 pixels at zoom 1. The probe reported a macOS certificate warning;
production regression tests separately verify the adopted ratio.

0.75 is an authored quarter-step calibration with measured clearance, not a
historical constant. The renderer applies it to both sprite scale and rigid
chord placement. It does not change CARTE.FIC, railway connections, train masses,
journey progression, or the requirement to reject incomplete route samples.

The initial camera fit uses the actual sprite alpha bounds and complete consist.
The sum of rigid chord lengths plus two maximum sprite radii bounds the train's
extent in any orientation (triangle inequality). An authored 10% viewport margin
keeps it clear of the edges. The resulting zoom stays fixed during travel;
manual zoom remains available. Long purchased consists may require a new explicit
fit. No heading-dependent stretching or invented route history is used.
