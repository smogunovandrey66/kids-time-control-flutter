#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Removes the Kids Time Control service. Data in %ProgramData%\KidsTimeControl is kept
  unless -RemoveData is given.
#>
param(
  [string]$InstallDir = (Join-Path $env:ProgramFiles 'KidsTimeControl'),
  [switch]$RemoveData
)
$ErrorActionPreference = 'Stop'
$wrapper = Join-Path $InstallDir 'KidsTimeControl.exe'

Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name KidsTimeControlAgent -ErrorAction SilentlyContinue
Get-Process ktc_agent -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$service = Get-Service -Name KidsTimeControl -ErrorAction SilentlyContinue
if ($service) {
  if ($service.Status -ne 'Stopped') {
    & $wrapper stop | Out-Null
    $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
  }
  & $wrapper uninstall | Out-Null
}
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
if ($RemoveData) { Remove-Item -Recurse -Force (Join-Path $env:ProgramData 'KidsTimeControl') }
Write-Host 'Kids Time Control has been removed.'
