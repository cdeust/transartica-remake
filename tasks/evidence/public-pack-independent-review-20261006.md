# Independent public-pack and foreground-probe review — 6 October 2026

APPROVE the audited pack contents and bounded probe changes. This is headless pack inspection on macOS, not a Windows executable launch, native foreground pixel acceptance or artistic approval.

The exact rebuilt macOS ZIP was opened and its sole Resources/Transartica.pck extracted temporarily for audit. The pre-existing builds/public-v1/macos extraction was older (740 resources, missing new music/map resources); it was not used as proof of the rebuilt ZIP. The actual ZIP PCK and current Windows PCK each pass with 782 enumerated files, public_release enabled and res://public_boot.tscn as the main scene. Both have zero forbidden paths and zero SHA256 matches against the complete original-data payload manifest. Private-data, reference-private, tests and saves are rejected. WAV/sample exceptions are restricted to the five authored orchestral names in their exact resource/import directories.

All nine authored cue keys load real stereo 44.1k AudioStreamWAV resources. Both packs contain the score JSON, world-registration JSON, eight regional textures whose imported RGBA hashes match registration, the master, three canopy textures and straight portal. Include filters package authored JSON; private payloads are absent.

The prepared foreground probe now rejects city, hidden/zero-area map and other modal screens, waits for frame_post_draw before capture, verifies the earned input file SHA after each capture, checks unchanged saves/network/rigid poses and requires positive changed pixels beneath actual train alpha at every site. Zero train-alpha changes produce exit 1 rather than an occlusion claim. Native execution and image review remain root-owned.

Audit script and per-platform JSON/inventories/logs: .cache/public-release/audit-public.gd and public-audit-{macos,windows}.*. Exact artifact hashes and PE header checks are in public-audit-artifact-hashes.json. The extracted audit PCK is removed after verification; no GUI or test process remains.

| Artifact | SHA256 |
|---|---|
| `builds/public-v1/Transartica-macOS-v1.zip` | `6d3894751b645d70c45ae6f3d45566bffdb1ddf2e612634a3f3ee7bdcb3a273b` |
| `builds/public-v1/windows/Transartica.exe` | `5bae54022c7e699b6f0f26230cf49a01c3582640623c6cf7f055c15eac9c5f29` |
| `builds/public-v1/windows/Transartica.pck` | `b7d7ebe0a000b919d962a703d7bdf5d8b59cb629955c527b960ec06f67ec498e` |
| ZIP embedded macOS PCK | `b7d7ebe0a000b919d962a703d7bdf5d8b59cb629955c527b960ec06f67ec498e` |
