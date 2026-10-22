# Historical music and native installers, 22 October 2026

Nine source-derived orchestral masters replace the five invented compositions.
Each historical cue has a distinct file. The underlying events come from the
original Amiga T.X player and decoder, executed through machine68k 0.4.0.
Instrument changes use the existing VSCO2 CE recordings and their author SFZ
pitch roots. Original resonant/percussive textures remain in the arrangement.
The content notice distinguishes historical music rights from the MIT code.

## Fidelity and verification

The final calibration has 59 static orchestral routes, four internal phrases
and 20 retained texture routes. Phrase notes are measured musical inference;
their onset bounds and frequency resolution remain explicit. BOJEU2 slot12 has
five supported notes. A weak drifting band does not establish a sixth note and
is not promoted to one. This is not a recovered published partition.

All nine renders pass event identity and source-hash checks. Independent reruns
produce identical WAV hashes. For each cyclic cue, the final 882 PCM frames
match the frames preceding its first repeat exactly, so wrapping reproduces an
existing transition. BOPRES ends at the original native stop. Numeric details
and hashes are in `faithful-orchestral-delivery-20261022.json`.

The score tooling passed 91 tests. Native C++ passed all 21 CTest suites with
the new resources; packaging passed 40 tests. The extraction refactor preserves
52128 event records and 288 sample blobs across nine fresh captures, with only
provenance header hashes changed. These tests do not establish artistic listening
acceptance or completion of an entire campaign.

## macOS

The sealed app contains 146 verified files. Real interface checks exercised
startup, the world map, and a SESSION save followed by restoration. CoreAudio
played the new journey master and advanced after restoration without errors.
The process quit normally within the 1 GiB guard.

The DMG was mounted, its app copied out, then the image ejected. The installed
copy passed file/signature verification and launched with CoreAudio playing the
new title master. The package requires macOS26 or newer on Apple Silicon. It is
signed ad-hoc and is not notarized.

Deliverables and installation receipts are under
`output/faithful-native-20261022/` in the main checkout.

## Windows

The final installer passed actual installation, launch with advancing music
and uninstall on Windows Server2025.
[Run39862770188](https://github.com/cdeust/transartica-remake/actions/runs/39862770188)
used music commit3953e35. It passed all21 native CTest suites,14 installer Python
tests and5 PowerShell regression checks. The runtime test uses SDL dummy audio;
it does not establish playback through physical Windows audio hardware or
gameplay input. Installed file hashes are verified before launch.

The installer is being transferred into the combined release. Its final
publication receipt will bind the hosted file to the successful installation.

## Cleanup

The source captures and verification evidence are retained in
`output/faithful-native-20261022/evidence/music-source-evidence.tar.gz`.
Its 904 members were read back and SHA256-verified before cleanup. The archive
is 20615476 bytes; its SHA256 is
`2be904d9ec3f294253e5d25f9b6b5a07078b7f969ef11b1f5a6269d25ceb09d6`.

Removed owned build directories, duplicate renders and the loose app copy total
1100104249 logical bytes. The verified DMG remains. The cleanup receipt records
per-path sizes and filesystem measurements; concurrent disk activity and APFS
sharing mean deleted file sizes are not a claim about net free-space gain.
Other worktrees, reference sources and unrelated project evidence were preserved.
