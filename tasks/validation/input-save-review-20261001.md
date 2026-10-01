# Native integration review, 1 October 2026

Boudoir commands now receive the configured canonical shortcut while story,
book text, and tactical context commands retain their input precedence. Main
owns tactical input dispatch once; its child no longer consumes keys first.
Native keyboard coverage exercises former/new map keys, Enter during story,
A during book naming, remapped OPTIONS, and tactical movement/pause conflicts.

Legacy saves without roaming populations construct a fresh detached source
baseline using their saved encounter RNG. Pre-encounter schemas use deterministic
save identity. This cannot recover historical population state that was never
saved. Loading never copies a currently pending nomad transaction or advances
live encounter/commercial RNG. Modern saves bypass this migration entirely.

The full boudoir fixture freezes its audio clock before atomic state comparisons;
production audio is unchanged. Its actual overview navigation verifies authored
art and the measured static chart's 45 towns and 206 dotted-route points.

Native Godot 4.5 Compatibility runs, all exit 0 without warnings/errors:

- `tests/test_boudoir.gd`: `boudoir-review-native-20261001.log`.
- `tests/test_key_bindings.gd`: `keyboard-native-20261001.log`.
- `tests/test_save_extensions.gd`: `legacy-roamers-migration-20261001.log`.
- `tests/test_launcher.gd`: 65 assertions, `launcher-controls-native-20261001.log`.

Command: `.toolchain/Godot.app/Contents/MacOS/Godot --path game --script tests/<name>.gd`.
The keyboard fixture preserves its capture in `tasks/validation/keyboard-settings-native.png`
and removes its own configuration and empty directory. The boudoir fixture removes
all of its own temporary files and directory. No historical or concurrent paths
were deleted, and no publication occurred.

Read-only checks of boot, journey, reset and audio routing found no additional
proved blocker within this bounded review. These tests do not establish complete
campaign acquisition or a Windows executable running on Windows.
