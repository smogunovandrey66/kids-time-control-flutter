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
$agent = Join-Path $InstallDir 'agent\ktc_agent.exe'
$runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'

New-Item -ItemType Directory -Force -Path $InstallDir, $dataDir | Out-Null

# Only SYSTEM and administrators may read or change the data: config.json holds PIN
# hashes, cloud.json the PC's cloud credentials, usage/ the played time.
icacls $dataDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null

$existing = Get-Service -Name KidsTimeControl -ErrorAction SilentlyContinue
if ($existing -and $existing.Status -ne 'Stopped') {
  & $wrapper stop | Out-Null
  $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
}

# Running agents lock their files; they are started again below and at the next logon.
Get-Process ktc_agent -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

foreach ($file in 'ktc.exe', 'KidsTimeControl.exe', 'KidsTimeControl.xml') {
  Copy-Item -Path (Join-Path $PSScriptRoot $file) -Destination $InstallDir -Force
}
$agentSource = Join-Path $PSScriptRoot 'agent'
if (Test-Path $agentSource) {
  $agentDir = Join-Path $InstallDir 'agent'
  if (Test-Path $agentDir) { Remove-Item -Recurse -Force $agentDir }
  Copy-Item -Recurse -Path $agentSource -Destination $agentDir
  # The tray agent starts at logon for every Windows user. HKLM: a child with a
  # standard account cannot remove it.
  Set-ItemProperty -Path $runKey -Name KidsTimeControlAgent -Value "`"$agent`""
}

if (-not $existing) {
  & $wrapper install
  if ($LASTEXITCODE -ne 0) { throw "Service installation failed ($LASTEXITCODE)" }
}
& $wrapper start
if ($LASTEXITCODE -ne 0) { throw "Service start failed ($LASTEXITCODE)" }

if (Test-Path $agent) {
  # Start the agent for the current user now. Through explorer.exe it runs
  # without administrator rights, like at logon.
  if (Get-Process explorer -ErrorAction SilentlyContinue) {
    Start-Process explorer.exe -ArgumentList "`"$agent`""
  } else {
    Start-Process $agent
  }
}

Write-Host "Kids Time Control is installed in $InstallDir and running."

# Children must use a standard account: an administrator can stop the service.
try {
  $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop |
    ForEach-Object { ($_.Name -split '\\')[-1] })
  $users = @(Get-LocalUser | Where-Object {
    $_.Enabled -and $_.SID.Value -notmatch '-(500|501|503|504)$'
  })
  $standard = @($users | Where-Object { $admins -notcontains $_.Name })
  Write-Host ''
  Write-Host "Administrators: $($admins -join ', ')"
  if ($standard.Count -eq 0) {
    Write-Warning ('Every account on this PC is an administrator. Children using such an ' +
      'account can turn Kids Time Control off. Create a standard account for the children ' +
      '(Settings > Accounts > Other users) and keep the administrator password to yourself.')
  } else {
    Write-Host "Standard accounts (for the children): $(($standard | ForEach-Object Name) -join ', ')"
  }
} catch {
  Write-Warning "Could not check the accounts: $_"
}
Write-Host "Data and logs: $dataDir"
Write-Host "Connect this PC to your family (in this administrator window):"
Write-Host "  & '$InstallDir\ktc.exe' pair --api-key <Web API Key> --project-id <project id> --name 'Home PC'"
