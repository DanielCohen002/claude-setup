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

**A dedicated Claude window**
- Its own taskbar icon: Claude runs in a portable Windows Terminal that uses the icon from your installed `claude.exe`, so it's grouped apart from your other terminals.
- A `Claude` Start Menu launcher that opens straight into Claude with no console flash, centered on screen.

**Shortcuts**

| Key | Action |
| --- | --- |
| `Ctrl+Shift+N` / `Ctrl+Shift+T` | New Claude tab |
| `Ctrl+W` | Types `/exit` and presses Enter, so Claude exits cleanly and the tab closes |
| `Ctrl+Shift+R` | Rename the current tab |
| `Ctrl+C` / `Ctrl+V` | Copy (when text is selected; otherwise it interrupts Claude as usual) / paste. `Ctrl+Shift+C` and `Ctrl+Shift+V` also work |

**Easy tracking** (the `easy-tracking` mod, details below)
- Your prompts and the steps Claude needs from you are drawn in highlighted boxes.
- A green "done" timer and a ding tell you when Claude has finished.

**Claude preferences** (set in `~/.claude/settings.json`; your other settings are kept)
- Remote Control on for every session.
- Session recap off (`/recap` still works on demand).
- Push notifications on.
- No Claude co-author trailer on commits and no "Generated with Claude Code" line on PRs.
- No "Quick safety check": the starting folder is marked trusted.

**Rules for Claude** (a marked block in `~/.claude/CLAUDE.md`; the rest of the file is left alone)
- Files meant for you (generated images, documents, files you asked for) are saved in your Downloads folder; projects and code stay where they normally go.
- Claude never adds itself as a contributor and never uses your real email in commits.

**Git identity**
- Your global git email is set to your GitHub noreply address (`<id>+<login>@users.noreply.github.com`) so your real email stays out of public history. Needs `gh auth login`; skipped if it's already a noreply address.

Every part can be turned off with the options below.

Notes:

- `Ctrl+W` is handled by Windows Terminal, so it does not reach Claude's prompt (where it would delete a word). It types `/exit` into whatever has focus, so use it at Claude's prompt. If Claude is mid-response the `/exit` is queued, and in a non-Claude program it just types `/exit`.
- Trusting a folder lets Claude load that folder's project settings, hooks and MCP servers. The starting folder is your user profile by default; change it with `-StartingDirectory`, or skip this with `-SkipTrust`. Claude generally treats a trusted folder's subfolders as trusted too, so everything under the starting folder (including cloned or unzipped projects) is covered. Only keep this on if you are comfortable with that.

## What `setup.ps1` does

1. Extracts the icon from `claude.exe` (`extract-icon.ps1`), or uses your own with `-IconPath`.
2. Downloads the latest portable Windows Terminal into `wt-portable\`, writes its settings (a `Claude` profile, centered launch, and the shortcuts above), and patches the exe's embedded icon (`patch-icon.ps1`).
3. Creates the Start Menu shortcut `Claude`, which runs `launch-claude.vbs` → `launch-claude.ps1` (sets the window's icon and AppUserModelID so the taskbar groups it separately).
4. Installs the `easy-tracking` mod from this repo, and removes the old standalone `claude-easy-tracking` one if present.
5. Sets these Claude preferences in `~/.claude/settings.json` (your other settings are kept): `remoteControlAtStartup: true` (Remote Control for all sessions), `awaySummaryEnabled: false` (session recap off) `agentPushNotifEnabled: true` (push notifications on) and `attribution` set to empty (no Claude co-author trailer on commits, no "Generated with Claude Code" line on PRs). It also adds a marked block ("Where files go" and "Git and GitHub") to `~/.claude/CLAUDE.md` (rest of the file is left alone; re-running updates the block) so Claude saves files meant for you to look at (generated images, documents, files you asked for) in your Downloads folder, while projects stay where they normally go, and tells Claude never to add itself as a contributor or use your real email. Finally, if your global git email isn't already a GitHub noreply address, it sets it to `<id>+<login>@users.noreply.github.com` using `gh api user` (needs `gh auth login`).
6. Marks the starting folder as trusted in `~/.claude.json`. It changes only that one value, after saving a backup as `.claude.json.setup-backup`.

Options:

| Option | Meaning |
| --- | --- |
| `-IconPath <file.ico>` | Use your own icon instead of the one in `claude.exe`. |
| `-TerminalZip <zip>` | Use a local portable Windows Terminal zip instead of downloading. |
| `-ClaudeExe <path>` | Path to `claude.exe` if it is not found automatically. |
| `-StartingDirectory <dir>` | Folder new Claude tabs open in (default: your user profile). |
| `-SkipPlugin` | Don't install the easy-tracking mod. |
| `-SkipPreferences` | Don't change the Claude preferences or the `CLAUDE.md` rules in step 5 (Remote Control, recap, push notifications, attribution, `CLAUDE.md`). |
| `-SkipGitIdentity` | Don't set the global git email to your GitHub noreply address. |
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
