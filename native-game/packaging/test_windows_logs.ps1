# SPDX-License-Identifier: MIT
param([Parameter(Mandatory)][string]$Scratch)
$ErrorActionPreference = 'Stop'
if (Test-Path $Scratch) { throw "Refusing existing test directory: $Scratch" }
New-Item -ItemType Directory -Path $Scratch | Out-Null
$Scratch = (Resolve-Path $Scratch).Path
$verification = Join-Path $PSScriptRoot 'assert_windows_logs.ps1'
$validState = "STATE event=boot cycle=0`nSTATE event=quit cycle=0`nAUDIO event=quit driver=dummy rate=44100 music_cursor=220500 music_frames=500000 music_playing=1 finale_cursor=0 resident_bytes=2000000 error=`"`"`n"
$validOutput = "NATIVE runtime=SDL2 renderer=direct3d game=fixture`n"
function Write-Fixture([string]$State, [string]$Output, [string]$ErrorText) {
    [IO.File]::WriteAllText((Join-Path $Scratch 'state.log'), $State)
    [IO.File]::WriteAllText((Join-Path $Scratch 'stdout.log'), $Output)
    [IO.File]::WriteAllText((Join-Path $Scratch 'stderr.log'), $ErrorText)
}
function Assert-Rejected([string]$Expected) {
    try {
        & $verification -Evidence $Scratch
        throw 'Expected verification failure was absent'
    } catch {
        if (!$_.Exception.Message.Contains($Expected)) { throw }
    }
}
try {
    Write-Fixture $validState $validOutput ''
    & $verification -Evidence $Scratch
    Write-Fixture $validState $validOutput 'audio device failed'
    Assert-Rejected 'Installed game emitted stderr: audio device failed'
    Write-Fixture '' $validOutput ''
    Assert-Rejected 'Native boot/quit markers missing'
    Write-Fixture $validState '' ''
    Assert-Rejected 'Native SDL renderer marker missing'
    Write-Fixture ($validState.Replace('music_cursor=220500', 'music_cursor=0')) $validOutput ''
    Assert-Rejected 'Music did not advance successfully'
    Write-Output 'Five Windows log-verification regressions passed'
} finally {
    Remove-Item -LiteralPath $Scratch -Recurse -Force
}
