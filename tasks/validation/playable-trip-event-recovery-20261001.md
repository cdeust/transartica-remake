# Playable trip fixture modal responses, 1 October 2026

The old test directly called main._advance_journey even while a source campaign
or world encounter owned the UI. That bypassed the production main._process
modal guard and could reach a city with an earlier ambush still pending.
SaveExtensions.blocks correctly preserved that encounter after restore, so the
city-reopens assertion failed. No runtime game or save rule changed.

The fixture now supplies actual Escape/NO world question responses and Enter
campaign report responses before another direct travel callback. Its first-city
routes use reproducible authored commerce seed1. Station departure and city-save
checks explicitly require no older world/campaign modal. The city restore
assertion and cargo/mass assertions remain intact.

A source-valid wolf fixture exercises all three actual report pages through the
same responder, then the isolated city routes restart using original TABLE
state. This is a modal input regression, not earned campaign evidence.

Native `playable-trip-event-recovery-20261001.log` records wolf continuation
three times and PASS with no errors or warnings. Source and craftsmanship gates
are retained alongside this file. No disposable fixture or test process remains.
