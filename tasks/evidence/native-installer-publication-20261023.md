# Native installer publication,23October2026

PR12 is merged at07e4b23cae7c321913c1b317f321fad0b29bfead.
The public release native-v0.1.0 points to that commit and contains both tested
installers, SHA256SUMS and validation.json. Release metadata and every asset
SHA256 were checked against the local Mac artifact or hosted Windows proof.

Mac DMG:296177633bytes; SHA256
e113c20561e20a61263d93866657d93f5d24c652dfc7bac83225709c22d407f4.
Windows installer:263712245bytes; SHA256
9fcd6d74386b73758f02b38604f8fc6c859a0dc74bf6ba54b4050c002ef998db.
Windows install/start/uninstall passed in run39862770188; publisher39866245837
verified the artifact, all nine music hashes and the remote installer digest.
Final-head regression39864919669 passed21 CTest suites and22 packaging tests.

Durable source captures, prior native-review evidence and current installation
receipts are under output/faithful-native-20261022/evidence in the main checkout.
All archive members were hash-verified before source scratch removal. The owner
explicitly authorized deletion of disk-hygiene-ltx2pwm6,disk-hygiene-54i1ct98 and
disk-hygiene-9t1vpqpm. All three folders are removed. The registered scratch disposal returned
"removed disposable temporary directory". The Windows installer is retained
on GitHub; its verification receipts and the Mac DMG remain in the main checkout.

Release: https://github.com/cdeust/transartica-remake/releases/tag/native-v0.1.0

The release is a preview. Full campaign completion and artistic listening
acceptance remain unverified. The Mac package requires macOS26 on Apple Silicon
and has an ad-hoc signature without notarization. Windows playback was tested
with SDL dummy audio, without physical audio or player input verification.
