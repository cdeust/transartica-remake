# Resumed music and installer checkpoint, 22 October 2026

The nine historical cues now have distinct source-derived orchestral masters in
`game/assets/audio/orchestral/`. The five invented compositions have been removed.
Original T.X execution and measured PCM supply the musical events and pitches.
Original resonant/percussive textures remain; internal phrase onsets carry
measurement uncertainty. No published-score recovery is claimed.

The original-player audit covers 3981 rows, 3611 triggers and 288 sample hashes.
All nine masters rebuild identically. Native C++ passes 21 CTest suites, and
packaging passes 40 tests. The score tool suite passes 91 tests.

The macOS26+ arm64 DMG is created and installation-tested with CoreAudio.
Actual app interaction also verified map opening and SESSION save/restoration.
The final Windows build is next; its preliminary old-score installer passed
installation, advancing playback and uninstall on the hosted Windows runner.

The owner additionally requests cleanup of obsolete resources and data.
Preserve the final installers and compact source evidence before deleting owned
build copies. Do not remove other sessions' worktrees or unresolved local work.

Current worktree: `.claude/worktrees/faithful-orchestral-20261022`.
Owned scratch: `disk-hygiene-9t1vpqpm` in the main repository.
Final deliverables: `output/faithful-native-20261022/` in the main repository.
Detailed evidence: [faithful-orchestral-delivery-20261022.md](faithful-orchestral-delivery-20261022.md).
