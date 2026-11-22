# claude-setup

One-run setup for a nicer Claude Code experience on Windows:

- **Own taskbar icon and a Start Menu launcher.** A portable Windows Terminal whose taskbar icon is the one from your installed `claude.exe`, so Claude windows group separately from other terminals. The launcher opens with no console flash.
- **Easy tracking.** The `easy-tracking` Claude Code mod: your prompts in a cyan **▶ YOU** box, the next steps Claude asks of you in a yellow **▶ YOUR TURN** box, a green finish timer with the clock time, and a ding when Claude finishes.
- **Keyboard shortcuts.** `Ctrl+Shift+N` opens a new Claude tab, `Ctrl+W` exits Claude with `/exit` and closes the tab, `Ctrl+Shift+R` renames it.

> Unofficial. Not affiliated with or endorsed by Anthropic or Microsoft. This repo contains **no** Anthropic artwork and **no** Windows Terminal binaries: the icon is extracted from your own installed `claude.exe` at setup time (or you supply your own `.ico`), and Windows Terminal is downloaded from Microsoft's official GitHub releases.

## Install

```powershell
git clone https://github.com/DanielCohen002/claude-setup
cd claude-setup
.\setup.ps1
```

Then launch **Claude** from the Start Menu.

`setup.ps1` does everything in one run:

1. Extracts the icon from `claude.exe` (`extract-icon.ps1`).
2. Downloads the latest portable Windows Terminal into `wt-portable\`, writes a settings file with a `Claude` profile and the shortcuts above, and patches the exe's embedded icon (`patch-icon.ps1`).
3. Creates the Start Menu shortcut `Claude`, which runs `launch-claude.vbs` → `launch-claude.ps1` (sets the window's icon and AppUserModelID so the taskbar groups it separately).
4. Installs the `easy-tracking` mod from this repo (and removes the old `claude-easy-tracking` one if present).

Options: `-IconPath` (use your own `.ico`), `-TerminalZip` (use a local portable zip), `-ClaudeExe`, `-StartingDirectory`, `-SkipPlugin`.

After updating the portable build, re-run `setup.ps1`.

## Shortcuts

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+N` (also `Ctrl+Shift+T`) | New Claude tab |
| `Ctrl+W` | Types `/exit` and presses Enter in the current tab, so Claude exits cleanly and the tab closes (the window closes with the last tab) |
| `Ctrl+Shift+R` | Rename the tab |

`Ctrl+W` is handled by Windows Terminal, so it does not reach Claude's prompt (where it would delete a word). It sends text to whatever has focus, so use it at Claude's prompt; if Claude is mid-response the `/exit` is queued, and in a non-Claude program it just types `/exit`.

## easy-tracking mod

Both boxes share the same rounded border, with the label on its own line above the text. When a turn finishes, the "✻ … for 1m 5s" line is drawn in green with the clock time it finished, such as "· done 3:42 PM", so you can tell Claude is done and not still running.

When Claude finishes responding, a short ding plays (the Windows `ding.wav`, through a `Stop` hook; Python is used if installed because it starts faster, otherwise PowerShell). Remove the `hooks` block from `hooks/hooks.json` to turn it off.

Claude is told to start each line that needs your action with a `▶` marker. The mod draws those lines highlighted and leaves the marker alone inside code blocks.

To install only the mod, without the terminal:

```
claude plugin install easy-tracking --marketplace DanielCohen002/claude-setup
```

In the desktop app, where `/plugin` does not run: click + next to the prompt box, then Plugins, Add marketplace with `DanielCohen002/claude-setup`, then Add plugin.

Requires Windows 10/11, PowerShell 5.1+, and the `claude` CLI installed.

## License

MIT (scripts only). Windows Terminal is MIT-licensed by Microsoft.
