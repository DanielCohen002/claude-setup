<#
.SYNOPSIS
  Sets up a portable Windows Terminal with a custom icon and a "Claude Code" profile.
.PARAMETER IconPath
  Path to a .ico file YOU supply (multi-size recommended: 16/32/48/256).
.PARAMETER TerminalZip
  Optional local Windows Terminal portable zip (x64). If omitted, the latest is downloaded from GitHub.
.PARAMETER ClaudeExe
  Optional path to claude.exe. Defaults to whatever `claude` resolves to on PATH.
.PARAMETER StartingDirectory
  Directory new Claude tabs open in. Defaults to your user profile.
#>
param(
  [Parameter(Mandatory)][string]$IconPath,
  [string]$TerminalZip,
  [string]$ClaudeExe,
  [string]$StartingDirectory = $env:USERPROFILE
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $ClaudeExe) {
  $cmd = Get-Command claude -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "claude not found on PATH. Pass -ClaudeExe." }
  $ClaudeExe = $cmd.Source
}
if (-not (Test-Path $IconPath)) { throw "Icon not found: $IconPath" }
Copy-Item $IconPath (Join-Path $root 'icon.ico') -Force
$ico = Join-Path $root 'icon.ico'

if (-not $TerminalZip) {
  $rel = Invoke-RestMethod 'https://api.github.com/repos/microsoft/terminal/releases/latest' -Headers @{ 'User-Agent' = 'setup' }
  $asset = $rel.assets | Where-Object { $_.name -match '^Microsoft\.WindowsTerminal_.*_x64\.zip$' } | Select-Object -First 1
  if (-not $asset) { throw "No portable x64 zip found in latest release." }
  $TerminalZip = Join-Path $env:TEMP $asset.name
  Invoke-WebRequest $asset.browser_download_url -OutFile $TerminalZip
}

$dest = Join-Path $root 'wt-portable'
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $TerminalZip $dest
$exe = Get-ChildItem $dest -Recurse -Filter WindowsTerminal.exe | Select-Object -First 1
$wtDir = $exe.DirectoryName
New-Item (Join-Path $wtDir '.portable') -ItemType File -Force | Out-Null

# Profile with the custom icon and Ctrl+Shift+T / Ctrl+Shift+R bindings
$settingsDir = Join-Path $wtDir 'settings'
New-Item $settingsDir -ItemType Directory -Force | Out-Null
$guid = '{c1a0de00-0000-5000-8000-000000c1a0de}'
$settings = [ordered]@{
  '$schema'      = 'https://aka.ms/terminal-profiles-schema'
  defaultProfile = $guid
  actions        = @(
    @{ id = 'User.newClaudeTab'; command = @{ action = 'newTab'; profile = $guid } },
    @{ id = 'User.renameTab';    command = 'openTabRenamer' }
  )
  keybindings    = @(
    @{ id = 'User.newClaudeTab'; keys = 'ctrl+shift+t' },
    @{ id = 'User.renameTab';    keys = 'ctrl+shift+r' }
  )
  profiles       = @{ list = @(@{
    guid = $guid; name = 'Claude'; hidden = $false
    commandline = ($ClaudeExe.Replace([string][char]92, '/'))
    icon = ($ico.Replace([string][char]92, '/'))
    startingDirectory = ($StartingDirectory.Replace([string][char]92, '/'))
  }) }
}
$settings | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $settingsDir 'settings.json') -Encoding utf8

# Patch the exe's embedded icon (taskbar / alt-tab)
& (Join-Path $root 'patch-icon.ps1') -SrcDir $wtDir -Ico $ico

# Start Menu shortcut that runs the launcher
$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Claude.lnk'
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = (Get-Command powershell.exe).Source
$sh.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $root 'launch-claude.ps1')`""
$sh.IconLocation = $ico
$sh.WorkingDirectory = $root
$sh.Save()
Write-Host "Done. Launch 'Claude' from the Start Menu."
