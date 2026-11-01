# claude-terminal-icon

Scripts that set up a **portable Windows Terminal** with a custom taskbar icon and a dedicated profile that launches the `claude` CLI, so your Claude sessions get their own icon instead of sharing the generic terminal one.

> Unofficial. Not affiliated with or endorsed by Anthropic or Microsoft. This repo contains **no** Anthropic artwork and **no** Windows Terminal binaries: you supply your own `.ico`, and Windows Terminal is downloaded from Microsoft's official GitHub releases at setup time.

## Use

```powershell
.\setup.ps1 -IconPath C:\path\to\your-icon.ico
```

Optional: `-TerminalZip` (use a local portable zip), `-ClaudeExe`, `-StartingDirectory`.

This downloads the latest portable Windows Terminal into `wt-portable\`, writes a settings file with a `Claude` profile, patches the exe's embedded icon, and creates a Start Menu shortcut `Claude`.

- **Ctrl+Shift+T**: new Claude tab
- **Ctrl+Shift+R**: rename tab

`launch-claude.ps1` opens a window, then sets its icon and AppUserModelID so the taskbar groups it separately from other terminals.

After updating the portable build, re-run `setup.ps1`.

Requires Windows 10/11, PowerShell 5.1+, and the `claude` CLI installed.

## License

MIT (scripts only). Windows Terminal is MIT-licensed by Microsoft.
