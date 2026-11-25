# claude-setup

One-run setup for a nicer Claude Code experience on Windows.

On Linux, use `setup.sh` instead (see [Linux](#linux)).

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
| **Its own taskbar icon** | Claude gets its own icon on the taskbar, separate from your other terminals. |
| **Start Menu launcher** | Open Claude from the Start Menu with one click. |
| **Opens centered** | The window opens in the middle of your screen. |
| **Files for you go to Downloads** | Things Claude makes for you (images, documents) are saved in your Downloads folder. |
| **Your messages stand out** | Your own messages are shown in a colored box, so long conversations are easy to scroll through. |
| **"Your turn" box** | Anything Claude needs you to do is pulled out into a highlighted box, so you can see at a glance what's waiting on you. |
| **Green "done" timer** | When Claude finishes, a green line shows how long it took and what time it finished. |
| **Ding when done** | A short sound plays when Claude finishes, so you can look away while it works. |
| **New tab: `Ctrl+Shift+N`** | Opens a new Claude tab. `Ctrl+Shift+T` works too. |
| **Exit: `Ctrl+W`** | Closes Claude cleanly. |
| **Rename tab: `Ctrl+Shift+R`** | Gives the current tab a name. |
| **Copy and paste** | `Ctrl+C` and `Ctrl+V` work the way you expect. `Ctrl+C` still stops Claude when nothing is selected. |
| **Remote Control always on** | You can follow and control your sessions from your phone or another device. |
| **Session recap off** | No automatic summary when you come back to a session. |
| **Push notifications on** | Get a notification when Claude needs you. |
| **Sessions can message each other** | Messages from your other sessions are accepted by default instead of being held for approval (`crossSessionInbound: accept`). |
| **No Claude co-author** | Claude isn't added as a contributor on your commits or pull requests. |
| **GitHub noreply email** | Your commits use your private GitHub email, not your real one. |
| **No "Quick safety check"** | Claude stops asking whether you trust your folder every time. |

More detail on each is below.

Notes:

- `Ctrl+W` is handled by Windows Terminal, so it does not reach Claude's prompt (where it would delete a word). It types `/exit` into whatever has focus, so use it at Claude's prompt. If Claude is mid-response the `/exit` is queued, and in a non-Claude program it just types `/exit`.
- Trusting a folder lets Claude load that folder's project settings, hooks and MCP servers. The starting folder is your user profile by default; change it with `-StartingDirectory`, or skip this with `-SkipTrust`. Claude generally treats a trusted folder's subfolders as trusted too, so everything under the starting folder (including cloned or unzipped projects) is covered. Only keep this on if you are comfortable with that.

## What `setup.ps1` does

1. Extracts the icon from `claude.exe` (`extract-icon.ps1`), or uses your own with `-IconPath`.
2. Downloads the latest portable Windows Terminal into `wt-portable\`, writes its settings (a `Claude` profile, centered launch, and the shortcuts above), and patches the exe's embedded icon (`patch-icon.ps1`).
3. Creates the Start Menu shortcut `Claude`, which runs `launch-claude.vbs` → `launch-claude.ps1` (sets the window's icon and AppUserModelID so the taskbar groups it separately).
4. Installs the `easy-tracking` mod from this repo, and removes the old standalone `claude-easy-tracking` one if present.
5. Sets these Claude preferences in `~/.claude/settings.json` (your other settings are kept): `remoteControlAtStartup: true` (Remote Control for all sessions), `awaySummaryEnabled: false` (session recap off) `agentPushNotifEnabled: true` (push notifications on), `crossSessionInbound: "accept"` (sessions can message each other) and `attribution` set to empty (no Claude co-author trailer on commits, no "Generated with Claude Code" line on PRs). It also adds a marked block ("Where files go" and "Git and GitHub") to `~/.claude/CLAUDE.md` (rest of the file is left alone; re-running updates the block) so Claude saves files meant for you to look at (generated images, documents, files you asked for) in your Downloads folder, while projects stay where they normally go, and tells Claude never to add itself as a contributor or use your real email. Finally, if your global git email isn't already a GitHub noreply address, it sets it to `<id>+<login>@users.noreply.github.com` using `gh api user` (needs `gh auth login`).
6. Marks the starting folder as trusted in `~/.claude.json`. It changes only that one value, after saving a backup as `.claude.json.setup-backup`.

Options:

| Option | Meaning |
| --- | --- |
| `-IconPath <file.ico>` | Use your own icon instead of the one in `claude.exe`. |
| `-TerminalZip <zip>` | Use a local portable Windows Terminal zip instead of downloading. |
| `-ClaudeExe <path>` | Path to `claude.exe` if it is not found automatically. |
| `-StartingDirectory <dir>` | Folder new Claude tabs open in (default: your user profile). |
| `-SkipPlugin` | Don't install the easy-tracking mod. |
| `-SkipPreferences` | Don't change the Claude preferences or the `CLAUDE.md` rules in step 5 (Remote Control, recap, push notifications, session messaging, attribution, `CLAUDE.md`). |
| `-SkipGitIdentity` | Don't set the global git email to your GitHub noreply address. |
| `-SkipTrust` | Don't mark the starting folder as trusted. |

After updating the portable terminal build, re-run `setup.ps1`.

## Linux

`setup.sh` is the Linux version (tested on Linux Mint 22.3). The Windows files are unchanged.

```bash
git clone https://github.com/DanielCohen002/claude-setup
cd claude-setup
./setup.sh
```

Requires `python3` and the `claude` CLI (on your PATH or at `~/.local/bin/claude`). For the git noreply email, also install `git` and `gh` (`sudo apt install git gh`) and run `gh auth login` first.

What it does, compared with `setup.ps1`:

| `setup.ps1` (Windows) | `setup.sh` (Linux) |
| --- | --- |
| Portable Windows Terminal, centered launch, custom shortcuts | Not done. A `Claude` launcher in your app menu (`~/.local/share/applications/org.claude.Terminal.desktop`) opens Claude in GNOME Terminal, or your default terminal. GNOME Terminal already has `Ctrl+Shift+T` (new tab) and `Ctrl+Shift+C` / `Ctrl+Shift+V` (copy / paste). |
| Icon from `claude.exe`, own taskbar group | There is no `claude.exe` on Linux, so Claude's icon is downloaded from claude.ai at setup time (not stored in this repo), or use your own with `--icon <file.png>`. GNOME Terminal runs under its own app id (`org.claude.Terminal`, via a D-Bus service file in `~/.local/share/dbus-1/services/`), so Claude gets its own taskbar icon, separate from your other terminals. |
| Block cursor (Windows Terminal default) | The default GNOME Terminal profile is switched to a line (I-beam) cursor. |
| easy-tracking mod | Same. |
| Ding from the mod's Windows hook | The mod's ding only works on Windows, so a `Stop` hook in `~/.claude/settings.json` plays `complete.oga` with `paplay` instead (added once, not on every re-run). |
| Preferences in `~/.claude/settings.json` | Same five settings. |
| `CLAUDE.md` block | Same block, with your Downloads folder from `xdg-user-dir`. |
| Git noreply email | Same, via `gh api user`. |
| Trust the starting folder in `~/.claude.json` | Same. |

**Keyring popups (opt-in, `--blank-keyring`).** With autologin you never type your password, so the GNOME login keyring stays locked, and `gh` (and `git push` through it) shows an unlock popup every time it runs. If you've forgotten the password, there's nothing you can type. `--blank-keyring` moves the locked keyring to `~/.local/share/keyrings-backup-<date>/` and replaces it with one that has no password, so it never asks, the way Windows unlocks its credential store at login. Passwords saved in the old keyring are no longer available, and anything saved from now on is stored unencrypted in your home folder. It does nothing if the keyring already has no password. Forgot your login password itself? If your account has passwordless `sudo`, run `sudo passwd $USER` to set a new one.

Before changing anything it copies `~/.claude/settings.json`, `~/.claude/CLAUDE.md` and `~/.claude.json` into `~/.claude/backups/claude-setup-<date>/`. Re-running is safe.

Options: `--claude <path>`, `--starting-directory <dir>`, `--icon <file.png>`, `--skip-plugin`, `--skip-preferences`, `--skip-git-identity`, `--skip-trust`, `--skip-launcher`, `--skip-cursor`, `--blank-keyring`. Run `./setup.sh --help` for details.

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
