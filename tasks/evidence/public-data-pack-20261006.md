# Public binaries and separate original data

Owner authorization: public macOS/Windows v1 binaries after actual campaign
victory; original data stays separate. Native campaign victory is documented in
`campaign-victory-20261006.md`. This change prepares the public installation path.

Godot4.5 documents loading ZIPs into the resource filesystem with
[ProjectSettings.load_resource_pack](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-method-load-resource-pack).
The loader validates every entry using
[ZIPReader](https://docs.godotengine.org/en/4.5/classes/class_zipreader.html) and
[HashingContext](https://docs.godotengine.org/en/4.5/classes/class_hashingcontext.html)
before mounting. Feature-specific project settings select the public bootstrap;
see [feature tags](https://docs.godotengine.org/en/4.5/tutorials/export/feature_tags.html).
No ZIP entries are extracted onto the filesystem.

The manifest contains exact paths, byte sizes and SHA256 values only. It does
not contain original payloads. Entries must match this manifest exactly; extra
paths, missing data, duplicates, traversal and changed bytes are refused.
Validated installation copies to a candidate, validates that copy, then renames
the previous ZIP to a backup and moves the candidate to the now vacant path.
Failures restore the backup; an interrupted replacement is recovered on launch.
Invalid source data never replaces the installed ZIP.
Mount uses `replace_files=false`, and main is dynamically loaded afterwards.
The private development main-scene setting remains unchanged. Scene changes from
`_ready` are deferred. Replacement uses a backup because the
[Godot4.5 Windows implementation](https://github.com/godotengine/godot/blob/4.5-stable/drivers/windows/dir_access_windows.cpp#L254-L291)
removes an existing destination before moving the source; direct overwrite is
therefore not a failure-atomic operation.

## Measured pack

The local builder inventoried100raw private files,68,915,873payload bytes. It
excluded91Godot `.import` sidecars. The deterministic ZIP is35,256,027bytes;
SHA256 `7e3353109628da48cd492c31d85ff00b7a015a8795417e3e5e46b00adc1b0e1f`.
The ignored local file is `.cache/public-release/original-data.zip`.
All100entries begin `private-data/`; none is an import sidecar. No source file
was moved or deleted. This ZIP must not be uploaded as a public release asset.

## Verification and remaining proof

`test_public_data_pack.gd` passes missing-data gating, valid/corrupt/empty/extra/
traversal/duplicate ZIPs, preservation of prior installed bytes on invalid input,
copy validation, successful resource mounting and both main-scene settings.
The base suite uses only synthetic bytes and needs no original data. The
additional invocation validates the actual100-file local data ZIP:

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script tests/test_public_data_pack.gd -- /Users/cdeust/Developments/Transartica/.cache/public-release/original-data.zip
```

Two local builder invocations produced byte-identical ZIPs. Test fixtures are removed
at the end. Log: `.cache/public-release/test-public-pack.log`.

Actual public export inventory, native installation and startup, macOS
save/resume and Windows execution remain to be verified by the publication owner.
Public preset exclusions are a configuration, not proof of exported contents.

## Interrupted replacement follow-up

Independent review found two uncovered crash states: a valid installed ZIP with
its remaining `.previous` backup blocked future installation; a corrupt installed
ZIP with a valid backup was not restored. Recovery now validates both files.
When both match this edition, it keeps the installed ZIP and removes the redundant
recognized backup. A missing or corrupt destination is restored from a recognized
valid backup. An unrecognized backup remains untouched; valid installed data can
still start, but replacement reports its retained path. Invalid incoming data is
rejected before any recovery or installation mutation.

An active installation keeps its backup until mount succeeds; it does not invoke
startup backup cleanup before a possible rollback. Focused synthetic regressions
cover both crash states, a subsequent successful replacement, invalid incoming
preserving both existing files, and retention of an unrecognized backup. The
actual100-file data pack still validates. Log:
`.cache/public-release/test-public-pack-recovery.log`.

## Actual candidate export checks by root

Both release exports completed successfully using the exact public presets. The macOS binary and Windows PCK each expose940 resource paths. Recursive inventory found no private-data, WAV/sample, test or save paths. SHA256 comparison of all exported resource payloads against the100-entry original-data manifest found no matches. Logs: `.cache/public-release/audit-public-macos.log` and `audit-public-windows-pck.log`. This is Windows PCK inspection on macOS, not Windows execution.

The actual public macOS executable instantiated its public bootstrap without a data pack and displayed the expected installation screen. The same executable then exercised the installer against the actual100-file ZIP, using an explicit project-contained destination for test isolation. Installation succeeded, native main launched, and ordinary title/input/save-book controls loaded earned PANELQA at47204. F5 save and normal F6 reload47205 yielded identical full JSON state.47206 showed the complete workshop list. The default OS user-data destination and native file-picker selection were not exercised by this isolated run.

The candidates remain unreleased. Actual Windows startup, save and resume still require a Windows environment. Public release assets will exclude the original-data ZIP.
