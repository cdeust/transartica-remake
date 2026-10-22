# SPDX-License-Identifier: MIT
# Validate the actual installed game's receipt without requiring nonempty stderr.
param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
# File.ReadAllText returns an empty string for a zero-byte file; Get-Content -Raw
# returns null for that case in PowerShell, so calling Trim on it fails.
$state = [IO.File]::ReadAllText((Join-Path $Evidence 'state.log'))
$stdout = [IO.File]::ReadAllText((Join-Path $Evidence 'stdout.log'))
$stderr = [IO.File]::ReadAllText((Join-Path $Evidence 'stderr.log'))
if ($state -notmatch 'STATE event=boot ' -or $state -notmatch 'STATE event=quit ') { throw 'Native boot/quit markers missing' }
if ($stdout -notmatch 'NATIVE runtime=SDL2 renderer=') { throw 'Native SDL renderer marker missing' }
if ($stderr.Trim()) { throw "Installed game emitted stderr: $stderr" }
if ($state -notmatch 'AUDIO event=quit .* music_cursor=[1-9][0-9]* .* music_playing=1 .* error=""') { throw 'Music did not advance successfully' }
