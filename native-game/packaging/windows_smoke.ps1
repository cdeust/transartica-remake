# SPDX-License-Identifier: MIT
# Source: Inno Setup command-line documentation; native app --quit-after contract.
param([Parameter(Mandatory)][string]$Installer, [Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path $Installer).Path
if (Test-Path $Evidence) { throw "Refusing existing evidence directory: $Evidence" }
New-Item -ItemType Directory -Path $Evidence | Out-Null
$Evidence = (Resolve-Path $Evidence).Path
$installed = Join-Path $Evidence 'installed'
$installLog = Join-Path $Evidence 'install.log'
$setup = Start-Process -FilePath $Installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$installed`"", "/LOG=`"$installLog`"") -PassThru
if (!$setup.WaitForExit(120000)) { $setup.Kill(); throw 'Installer did not exit within the CI installation budget' }
if ($setup.ExitCode -ne 0) { throw "Installer failed with exit $($setup.ExitCode)" }
$receipt = Get-Content (Join-Path $installed 'package-receipt.json') -Raw | ConvertFrom-Json
foreach ($file in $receipt.files.PSObject.Properties) {
    $path = Join-Path $installed $file.Name
    if ((Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant() -ne $file.Value) { throw "Installed hash mismatch: $($file.Name)" }
}
$executable = Join-Path $installed 'Transartica.exe'
$stateLog = Join-Path $Evidence 'state.log'
$savedPath = $env:PATH
$savedAudio = $env:SDL_AUDIODRIVER
try {
    # System-only PATH proves that the installed DLL closure suffices.
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
    # Hosted Windows has no physical audio device. This tests SDL mixing, not listening.
    $env:SDL_AUDIODRIVER = 'dummy'
    # Source: StartupTimeline::title_ready / hz = 360 / 50 = 7.2 seconds.
    # Reception music begins at publisher_end / hz = 5.04 seconds.
    $arguments = @('--quit-after', '7.2', '--save-dir', "`"$(Join-Path $Evidence 'saves')`"", '--log', "`"$stateLog`"")
    $game = Start-Process -FilePath $executable -WorkingDirectory $Evidence -ArgumentList $arguments -RedirectStandardOutput (Join-Path $Evidence 'stdout.log') -RedirectStandardError (Join-Path $Evidence 'stderr.log') -PassThru
    if (!$game.WaitForExit(30000)) { $game.Kill(); throw 'Installed game did not exit within the CI launch budget' }
    if ($game.ExitCode -ne 0) { throw "Installed game failed with exit $($game.ExitCode)" }
} finally {
    $env:PATH = $savedPath
    $env:SDL_AUDIODRIVER = $savedAudio
}
& (Join-Path $PSScriptRoot 'assert_windows_logs.ps1') -Evidence $Evidence
$uninstaller = Join-Path $installed 'unins000.exe'
$uninstall = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru
if (!$uninstall.WaitForExit(120000)) { $uninstall.Kill(); throw 'Uninstaller did not exit within the CI budget' }
if ($uninstall.ExitCode -ne 0 -or (Test-Path $executable)) { throw 'Uninstall did not remove the installed executable' }
@{ format = 'transartica-windows-installer-smoke-v1'; installer_sha256 = (Get-FileHash $Installer).Hash.ToLowerInvariant(); os = [Environment]::OSVersion.VersionString; runtime_tested = $true; physical_audio_tested = $false; gameplay_input_tested = $false; uninstall_tested = $true; resources_verified = @($receipt.files.PSObject.Properties).Count } | ConvertTo-Json | Set-Content (Join-Path $Evidence 'receipt.json')
