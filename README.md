# claude-setup

One-run setup for a nicer Claude Code experience on Windows.

> Unofficial. Not affiliated with or endorsed by Anthropic or Microsoft. This repo contains **no** Anthropic artwork and **no** Windows Terminal binaries: the icon is extracted from your own installed `claude.exe` at setup time (or you supply your own `.ico`), and Windows Terminal is downloaded from Microsoft's official GitHub releases.

## Install

```powershell
git clone https://github.com/DanielCohen002/claude-setup
cd claude-setup
.\setup.ps1
```

Then open **Claude** from the Start Menu. Close any open Claude windows before re-running `setup.ps1`.

Requires Windows 10/11, PowerShell 5.1+, and the `claude` CLI installed (found on your PATH or at `~\.local\bin\claude.exe`).

## What you get

| Feature | What it does |
| --- | --- |
| **Its own taskbar icon** | Claude opens in a portable Windows Terminal that uses the icon from your installed `claude.exe`, so Claude windows are grouped separately from your other terminals. |
| **Start Menu launcher** | A `Claude` shortcut that opens straight into Claude, with no console window flashing first. |
| **Opens centered** | The window opens in the middle of your screen instead of the corner. |
| **Files go to Downloads** | Claude starts in your Downloads folder, and a rule in `~/.claude/CLAUDE.md` tells it to save anything it downloads or creates there, unless you or a project say otherwise. |
| **Easy tracking** | The `easy-tracking` mod makes long conversations easy to follow (details below). |
| **New tab: `Ctrl+Shift+N`** | Opens a new Claude tab. `Ctrl+Shift+T` does the same. |
| **Exit: `Ctrl+W`** | Types `/exit` and presses Enter, so Claude exits cleanly and the tab closes. |
| **Rename tab: `Ctrl+Shift+R`** | Renames the current tab. |
| **Copy and paste** | `Ctrl+C` copies when text is selected (otherwise it interrupts Claude as usual). `Ctrl+V` pastes. `Ctrl+Shift+C` and `Ctrl+Shift+V` also work. |
| **Remote Control always on** | Every session connects to Remote Control automatically (the same as `/config` → Enable Remote Control for all sessions). |
| **Session recap off** | Claude doesn't show the automatic recap when you come back to a session (`awaySummaryEnabled: false`). `/recap` still works on demand. |
| **Push notifications on** | `agentPushNotifEnabled: true`. |
| **No "Quick safety check"** | The starting folder is marked trusted, so Claude stops asking whether you trust it every time. |

Notes:

- `Ctrl+W` is handled by Windows Terminal, so it does not reach Claude's prompt (where it would delete a word). It types `/exit` into whatever has focus, so use it at Claude's prompt. If Claude is mid-response the `/exit` is queued, and in a non-Claude program it just types `/exit`.
- Trusting a folder lets Claude load that folder's project settings, hooks and MCP servers. The starting folder is your Downloads folder by default; change it with `-StartingDirectory`, or skip this with `-SkipTrust`. Claude generally treats a trusted folder's subfolders as trusted too, and Downloads is where downloaded files (including cloned or unzipped projects) end up, so only keep this on if you are comfortable with that.

## What `setup.ps1` does

1. Extracts the icon from `claude.exe` (`extract-icon.ps1`), or uses your own with `-IconPath`.
2. Downloads the latest portable Windows Terminal into `wt-portable\`, writes its settings (a `Claude` profile, centered launch, and the shortcuts above), and patches the exe's embedded icon (`patch-icon.ps1`).
3. Creates the Start Menu shortcut `Claude`, which runs `launch-claude.vbs` → `launch-claude.ps1` (sets the window's icon and AppUserModelID so the taskbar groups it separately).
4. Installs the `easy-tracking` mod from this repo, and removes the old standalone `claude-easy-tracking` one if present.
5. Sets these Claude preferences in `~/.claude/settings.json` (your other settings are kept): `remoteControlAtStartup: true` (Remote Control for all sessions), `awaySummaryEnabled: false` (session recap off) and `agentPushNotifEnabled: true` (push notifications on). It also adds a marked "Where files go" block to `~/.claude/CLAUDE.md` (rest of the file is left alone; re-running updates the block) so Claude saves downloads and files it creates in your Downloads folder.
6. Marks the starting folder as trusted in `~/.claude.json`. It changes only that one value, after saving a backup as `.claude.json.setup-backup`.

Options:

| Option | Meaning |
| --- | --- |
| `-IconPath <file.ico>` | Use your own icon instead of the one in `claude.exe`. |
| `-TerminalZip <zip>` | Use a local portable Windows Terminal zip instead of downloading. |
| `-ClaudeExe <path>` | Path to `claude.exe` if it is not found automatically. |
| `-StartingDirectory <dir>` | Folder new Claude tabs open in (default: your Downloads folder). |
| `-SkipPlugin` | Don't install the easy-tracking mod. |
| `-SkipPreferences` | Don't change the Claude preferences or the Downloads rule in step 5 (Remote Control, recap, push notifications, `CLAUDE.md`). |
| `-SkipTrust` | Don't mark the starting folder as trusted. |

After updating the portable terminal build, re-run `setup.ps1`.

## The easy-tracking mod

A Claude Code mod that makes a long conversation easier to follow:

- **▶ YOU box.** Your own prompts are drawn in a cyan box in the transcript.
- **▶ YOUR TURN box.** The next steps Claude asks you to take are highlighted in a yellow box, so you can see at a glance what is waiting on you. Both boxes share the same rounded border, with the label on its own line above the text.
- **Green finish timer.** When a turn finishes, the "✻ … for 1m 5s" line is drawn in green with the clock time it finished, such as "· done 3:42 PM", so you can tell Claude is done and not still running.
- **Ding.** When Claude finishes responding, a short ding plays (the Windows `ding.wav`, through a `Stop` hook; Python is used if installed because it starts faster, otherwise PowerShell). Remove the `hooks` block from `hooks/hooks.json` to turn it off.

Claude is told to start each line that needs your action with a `▶` marker. The mod draws those lines highlighted and leaves the marker alone inside code blocks.

To install only the mod, without the terminal:

```
claude plugin install easy-tracking --marketplace DanielCohen002/claude-setup
```

In the desktop app, where `/plugin` does not run: click + next to the prompt box, then Plugins, Add marketplace with `DanielCohen002/claude-setup`, then Add plugin.

## License

MIT (scripts only). Windows Terminal is MIT-licensed by Microsoft.
