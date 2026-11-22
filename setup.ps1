<#
.SYNOPSIS
  Sets up a portable Windows Terminal with a custom icon and a "Claude Code" profile.
.PARAMETER IconPath
  Optional path to a .ico file YOU supply (multi-size recommended: 16/32/48/256).
  If omitted, the icon embedded in claude.exe is extracted and used.
.PARAMETER TerminalZip
  Optional local Windows Terminal portable zip (x64). If omitted, the latest is downloaded from GitHub.
.PARAMETER ClaudeExe
  Optional path to claude.exe. Defaults to whatever `claude` resolves to on PATH.
.PARAMETER StartingDirectory
  Directory new Claude tabs open in. Defaults to your user profile.
#>
param(
  [string]$IconPath,
  [string]$TerminalZip,
  [string]$ClaudeExe,
  [string]$StartingDirectory = $env:USERPROFILE,
  [switch]$SkipPlugin
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# Refuse to reinstall over a running portable terminal (would leave a half-deleted install)
$running = Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -and $_.Path -like "$(Join-Path $root 'wt-portable')*" }
if ($running) { throw "The portable Claude terminal is open. Close all Claude windows, then run setup.ps1 again." }

if (-not $ClaudeExe) {
  $cmd = Get-Command claude -ErrorAction SilentlyContinue
  if ($cmd) { $ClaudeExe = $cmd.Source }
  else {
    $default = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $default) { $ClaudeExe = $default }
    else { throw "claude not found on PATH or at $default. Pass -ClaudeExe." }
  }
}
$ico = Join-Path $root 'icon.ico'
if ($IconPath) {
  if (-not (Test-Path $IconPath)) { throw "Icon not found: $IconPath" }
  Copy-Item $IconPath $ico -Force
} else {
  & (Join-Path $root 'extract-icon.ps1') -Exe $ClaudeExe -Out $ico
}

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
    @{ id = 'User.renameTab';    command = 'openTabRenamer' },
    @{ id = 'User.exitClaude'; command = @{ action = 'sendInput'; input = "/exit`r" } },
    @{ id = 'User.copy';       command = @{ action = 'copy'; singleLine = $false } },
    @{ id = 'User.paste';      command = 'paste' }
  )
  keybindings    = @(
    @{ id = 'User.newClaudeTab';   keys = 'ctrl+shift+n' },
    @{ id = 'User.newClaudeTab';   keys = 'ctrl+shift+t' },
    @{ id = 'User.exitClaude';     keys = 'ctrl+w' },
    @{ id = 'User.renameTab';      keys = 'ctrl+shift+r' },
    # Copy / paste (Ctrl+C only copies when text is selected; otherwise it interrupts Claude as usual)
    @{ id = 'User.copy';           keys = 'ctrl+c' },
    @{ id = 'User.copy';           keys = 'ctrl+shift+c' },
    @{ id = 'User.paste';          keys = 'ctrl+v' },
    @{ id = 'User.paste';          keys = 'ctrl+shift+v' }
  )
  profiles       = @{ list = @(@{
    guid = $guid; name = 'Claude'; hidden = $false; closeOnExit = 'graceful'
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
# wscript + .vbs starts the launcher with no console window (no flash)
$sh.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$sh.Arguments = "`"$(Join-Path $root 'launch-claude.vbs')`""
$sh.IconLocation = $ico
$sh.WorkingDirectory = $root
$sh.Save()
# easy-tracking mod (YOU / YOUR TURN boxes, green finish timer, ding)
if (-not $SkipPlugin) {
  $ErrorActionPreference = 'Continue'  # cleanup calls below may report "not found"
  $repo = 'DanielCohen002/claude-setup'
  # Migrate off the old standalone marketplace if it is still installed
  & $ClaudeExe plugin uninstall easy-tracking@claude-easy-tracking 2>&1 | Out-Null
  & $ClaudeExe plugin marketplace remove claude-easy-tracking 2>&1 | Out-Null
  # Refresh if already installed, otherwise install
  & $ClaudeExe plugin uninstall easy-tracking@claude-setup 2>&1 | Out-Null
  & $ClaudeExe plugin marketplace remove claude-setup 2>&1 | Out-Null
  & $ClaudeExe plugin install easy-tracking --marketplace $repo -y
  if ($LASTEXITCODE -ne 0) { Write-Warning "Plugin install failed. Run: claude plugin install easy-tracking --marketplace $repo" }
}

Write-Host "Done. Launch 'Claude' from the Start Menu."
