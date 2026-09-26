#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Installs (or updates) the Kids Time Control Windows service.
.DESCRIPTION
  Run from the unpacked kids-time-control-windows.zip in an administrator PowerShell:
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>
param(
  [string]$InstallDir = (Join-Path $env:ProgramFiles 'KidsTimeControl')
)
$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $env:ProgramData 'KidsTimeControl'
$wrapper = Join-Path $InstallDir 'KidsTimeControl.exe'

New-Item -ItemType Directory -Force -Path $InstallDir, $dataDir | Out-Null

# Only SYSTEM and administrators may read or change the data: config.json holds PIN
# hashes, cloud.json the PC's cloud credentials, usage/ the played time.
icacls $dataDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null

$existing = Get-Service -Name KidsTimeControl -ErrorAction SilentlyContinue
if ($existing -and $existing.Status -ne 'Stopped') {
  & $wrapper stop | Out-Null
  $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
}

foreach ($file in 'ktc.exe', 'KidsTimeControl.exe', 'KidsTimeControl.xml') {
  Copy-Item -Path (Join-Path $PSScriptRoot $file) -Destination $InstallDir -Force
}

if (-not $existing) {
  & $wrapper install
  if ($LASTEXITCODE -ne 0) { throw "Service installation failed ($LASTEXITCODE)" }
}
& $wrapper start
if ($LASTEXITCODE -ne 0) { throw "Service start failed ($LASTEXITCODE)" }

Write-Host "Kids Time Control is installed in $InstallDir and running."
Write-Host "Data and logs: $dataDir"
Write-Host "Connect this PC to your family (in this administrator window):"
Write-Host "  & '$InstallDir\ktc.exe' pair --api-key <Web API Key> --project-id <project id> --name 'Home PC'"
