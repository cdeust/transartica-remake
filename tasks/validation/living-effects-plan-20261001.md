# Living effects work

Ownership: reusable effects modules, tactical presentation and presentation event
signals. Root owns external scene integration and generated atlas. Base79c80b2.

External gate: actual weapon/dynamite events must produce distinct muzzle and impact
effects without altering combat snapshots or gameplay RNG. Multi-tick advances must
deliver every event. Native captures must show materially richer fragments/plumes;
the same seeded visual sequence must finish identically at30/60/144Hz. Measure
simulation/draw cost at bounded peak concurrency on the native host.

- [x] Recall earlier mistakes and verify base.
- [x] Agree shared API and atlas identifiers with root.
- [x] Implement bounded effects with independent presentation randomness.
- [x] Wire actual weapon events; preserve every tick and pause/restart behavior.
- [x] Validate model invariance and display-rate stability.
- [x] Capture native actual gun/dynamite visuals and measure frame cost.
- [x] Run source/craft checks and deliver exact evidence.

Authored visual recipes remain separate from decoded damage/clocks. Fixed visual
updates use the existing source50Hz cadence; sprite/material motion is presentation.

Review: native source gun/dynamite captures and deterministic tests pass. CPU
submission/update measurements are recorded in living-effects-20261001.md.
