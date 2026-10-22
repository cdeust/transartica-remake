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

The preliminary installer passed actual installation, launch with advancing
music and uninstall on Windows Server2025. That run used the old score.
The final installer must be rebuilt from the commit containing these nine
masters; its result will be appended here before delivery is declared complete.

## Cleanup

Temporary comparison renders were deleted after their hashes matched. Canonical
source evidence and current deliverables remain protected until archived.
The owner has requested removal of obsolete project resources and build copies;
cleanup measurements will be recorded after the final Windows artifact arrives.
