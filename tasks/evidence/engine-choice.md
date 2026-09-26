# Desktop engine

Decision: Godot 4.5 stable, standard GDScript edition, pinned for reproducibility.
This is an implementation choice for the new renderer, not an original game rule.

Official release: https://godotengine.org/download/archive/4.5-stable/
Official binaries: https://github.com/godotengine/godot-builds/releases/tag/4.5-stable
Timing contract: https://docs.godotengine.org/en/4.5/tutorials/scripting/idle_and_physics_processing.html

The engine documents fixed physics updates independent of render frames, and
elapsed-time delta for frame processing. Tests must still verify the application's
own state transitions; selecting an engine does not prove timing correctness.

Local executable `.toolchain/Godot.app/Contents/MacOS/Godot --headless --version`
returned `4.5.stable.official.876b29033`. The self-contained marker `._sc_`
resides beside the binary. Downloads and editor data remain inside this project.
