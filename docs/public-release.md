# Public v1 edition

The public macOS and Windows packages contain the remake code and authored
artwork. Original game data is a separate local ZIP and is not a release asset.
Without that data, the application opens an installation screen.

Open the application, choose **Choose data ZIP**, then select your local
`original-data.zip`. The application checks that its contents match this edition,
installs a copy in its user-data directory, and starts the game. Subsequent
launches use that installed copy. An invalid ZIP leaves existing data unchanged.
The game does not download original data.

## Local maintainer packaging

From the project root, build the separate private data ZIP:

```sh
python3 tools/build_private_data_pack.py --output .cache/public-release/original-data.zip
```

This also updates `game/assets/interface/original-data-manifest.json`, which
contains filenames, sizes and hashes only. The ZIP preserves `private-data/`
paths and excludes Godot import sidecars. Keep this ZIP private.

The public export presets are **macOS Public** and **Windows Public**. They add
`public_release`, exclude `private-data/*`, and start at `public_boot.tscn`.
The existing private preview presets still start at `main.tscn` and include data.
Authored asset JSON manifests are explicitly included in public exports.

Before uploading binaries, inspect the actual PCK inventory and payload hashes:
there must be no private-data members, original payloads or imported original WAV
resources. Verify the exact executable's missing-data screen, data installation,
ordinary start, save and load on each announced platform. A successful export or
a headless loader test does not establish Windows execution.
