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
  [string]$StartingDirectory,
  [switch]$SkipPlugin,
  [switch]$SkipPreferences,
  [switch]$SkipTrust
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
# Your real Downloads folder (follows OneDrive/redirected locations)
$downloads = $null
try { $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch {}
if (-not $downloads) { $downloads = Join-Path $env:USERPROFILE 'Downloads' }
if (-not $StartingDirectory) { $StartingDirectory = $env:USERPROFILE }

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
  centerOnLaunch = $true
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

# Claude preferences (same as setting them in /config). Written to ~/.claude/settings.json; other settings are kept.
if (-not $SkipPreferences) {
  $prefs = [ordered]@{
    remoteControlAtStartup = $true    # Enable Remote Control for all sessions
    awaySummaryEnabled     = $false   # Session recap off
    agentPushNotifEnabled  = $true    # Push notifications on
  }
  $settingsFile = Join-Path $env:USERPROFILE '.claude\settings.json'
  try {
    $us = if (Test-Path $settingsFile) { Get-Content $settingsFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    if ($null -eq $us) { $us = [pscustomobject]@{} }
    foreach ($k in $prefs.Keys) { $us | Add-Member -NotePropertyName $k -NotePropertyValue $prefs[$k] -Force }
    New-Item (Split-Path $settingsFile) -ItemType Directory -Force | Out-Null
    $us | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding utf8
  } catch { Write-Warning "Could not write Claude preferences: $($_.Exception.Message)" }

  # Tell Claude to put files meant for you to look at in Downloads (projects stay where they normally go).
  # Lives in its own marked block in ~/.claude/CLAUDE.md so re-running updates it and anything else you
  # wrote there is left alone.
  $mdFile = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
  $begin = '<!-- claude-setup:begin -->'; $endMark = '<!-- claude-setup:end -->'
  $rule = @"
$begin
## Where files go
Save files that are meant for the user to look at or keep - generated images, documents, exports, and files they asked you to make or download - in their Downloads folder: $downloads
Projects, code, and anything that belongs to a repo or working project go where they normally would (the current working directory or project), not in Downloads.
$endMark
"@
  try {
    $md = if (Test-Path $mdFile) { [IO.File]::ReadAllText($mdFile) } else { '' }
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($endMark)
    if ($md -match $pattern) { $md = [regex]::Replace($md, $pattern, { param($m) $rule }) }
    else { $md = $md.TrimEnd() + $(if ($md.Trim()) { "`r`n`r`n" } else { '' }) + $rule + "`r`n" }
    New-Item (Split-Path $mdFile) -ItemType Directory -Force | Out-Null
    [IO.File]::WriteAllText($mdFile, $md, (New-Object Text.UTF8Encoding($false)))
  } catch { Write-Warning "Could not write ~/.claude/CLAUDE.md: $($_.Exception.Message)" }
}

# Mark the starting directory as trusted so Claude does not ask the "Quick safety check" every time.
# Edits only that one value in ~/.claude.json as text (no JSON re-serialization), after saving a backup.
if (-not $SkipTrust) {
  $cfgFile = Join-Path $env:USERPROFILE '.claude.json'
  try {
    if (Test-Path $cfgFile) {
      $text = [IO.File]::ReadAllText($cfgFile)
      $key  = ([IO.Path]::GetFullPath($StartingDirectory)).TrimEnd('\').Replace('\', '/')
      $needle = '"' + $key + '"'
      $at = $text.IndexOf($needle)
      $out = $null
      if ($at -ge 0) {
        $open = $text.IndexOf('{', $at + $needle.Length)
        # find the matching close brace, skipping over strings
        $depth = 0; $inStr = $false; $close = -1
        for ($i = $open; $i -lt $text.Length; $i++) {
          $c = $text[$i]
          if ($inStr) { if ($c -eq '\') { $i++ } elseif ($c -eq '"') { $inStr = $false } }
          elseif ($c -eq '"') { $inStr = $true }
          elseif ($c -eq '{') { $depth++ }
          elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { $close = $i; break } }
        }
        if ($open -ge 0 -and $close -gt $open) {
          $block = $text.Substring($open, $close - $open + 1)
          $re = '("hasTrustDialogAccepted"\s*:\s*)(true|false)'
          if ($block -match $re) { $newBlock = [regex]::Replace($block, $re, '${1}true') }
          else { $newBlock = '{ "hasTrustDialogAccepted": true,' + $block.Substring(1) }
          if ($newBlock -ne $block) { $out = $text.Substring(0, $open) + $newBlock + $text.Substring($close + 1) }
        }
      } else {
        $m = [regex]::Match($text, '"projects"\s*:\s*\{')
        if ($m.Success) { $out = $text.Insert($m.Index + $m.Length, "`n    `"$key`": { `"hasTrustDialogAccepted`": true },") }
      }
      if ($out) {
        Copy-Item $cfgFile "$cfgFile.setup-backup" -Force
        [IO.File]::WriteAllText($cfgFile, $out, (New-Object Text.UTF8Encoding($false)))
        $null = Get-Content $cfgFile -Raw | ConvertFrom-Json   # make sure it is still valid JSON
      }
    }
  } catch {
    Write-Warning "Could not pre-trust $StartingDirectory : $($_.Exception.Message)"
    if (Test-Path "$cfgFile.setup-backup") { Copy-Item "$cfgFile.setup-backup" $cfgFile -Force }
  }
}
Write-Host "Done. Launch 'Claude' from the Start Menu."
