#!/usr/bin/env bash
# Linux version of setup.ps1. Sets up the easy-tracking mod, Claude preferences,
# CLAUDE.md rules, git noreply email, folder trust and an app-menu launcher.
# The Windows Terminal parts of setup.ps1 (portable terminal, patched icon,
# taskbar grouping) have no Linux equivalent here; a GNOME Terminal launcher is used instead.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]
  --claude <path>            Path to the claude binary (default: found on PATH or ~/.local/bin/claude)
  --starting-directory <dir> Folder the launcher opens Claude in (default: $HOME)
  --skip-plugin              Don't install the easy-tracking mod
  --skip-preferences         Don't change Claude preferences, the ding hook or the CLAUDE.md rules
  --skip-git-identity        Don't set the global git email to your GitHub noreply address
  --skip-trust               Don't mark the starting folder as trusted
  --skip-launcher            Don't create the "Claude" app-menu launcher
  --skip-cursor              Don't change the GNOME Terminal cursor to a line
EOF
}

CLAUDE_BIN=""; START_DIR="$HOME"
SKIP_PLUGIN=0; SKIP_PREFS=0; SKIP_GIT=0; SKIP_TRUST=0; SKIP_LAUNCHER=0; SKIP_CURSOR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) CLAUDE_BIN="$2"; shift 2 ;;
    --starting-directory) START_DIR="$2"; shift 2 ;;
    --skip-plugin) SKIP_PLUGIN=1; shift ;;
    --skip-preferences) SKIP_PREFS=1; shift ;;
    --skip-git-identity) SKIP_GIT=1; shift ;;
    --skip-trust) SKIP_TRUST=1; shift ;;
    --skip-launcher) SKIP_LAUNCHER=1; shift ;;
    --skip-cursor) SKIP_CURSOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

warn() { echo "WARNING: $*" >&2; }

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
if [ -z "$CLAUDE_BIN" ]; then
  CLAUDE_BIN="$(command -v claude || true)"
  [ -z "$CLAUDE_BIN" ] && [ -x "$HOME/.local/bin/claude" ] && CLAUDE_BIN="$HOME/.local/bin/claude"
  [ -z "$CLAUDE_BIN" ] && { echo "claude not found on PATH or at ~/.local/bin/claude. Pass --claude." >&2; exit 1; }
fi
START_DIR="$(cd "$START_DIR" && pwd)"
DOWNLOADS="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
[ -z "$DOWNLOADS" ] || [ "$DOWNLOADS" = "$HOME" ] && DOWNLOADS="$HOME/Downloads"

# Back up the files this script edits
BACKUP="$HOME/.claude/backups/claude-setup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" "$HOME/.claude.json"; do
  [ -f "$f" ] && cp -p "$f" "$BACKUP/"
done
echo "Backups saved in $BACKUP"

# easy-tracking mod (YOU / YOUR TURN boxes, green finish timer)
if [ "$SKIP_PLUGIN" = 0 ]; then
  REPO="DanielCohen002/claude-setup"
  "$CLAUDE_BIN" plugin uninstall easy-tracking@claude-setup >/dev/null 2>&1 || true
  "$CLAUDE_BIN" plugin marketplace remove claude-setup >/dev/null 2>&1 || true
  "$CLAUDE_BIN" plugin install easy-tracking --marketplace "$REPO" -y \
    || warn "Plugin install failed. Run: claude plugin install easy-tracking --marketplace $REPO"
fi

# Claude preferences plus a Linux "ding" Stop hook (the mod's own ding uses Windows sounds)
if [ "$SKIP_PREFS" = 0 ]; then
  python3 -I - "$HOME/.claude/settings.json" <<'EOF' || warn "Could not write Claude preferences."
import json, os, sys
p = sys.argv[1]
s = {}
if os.path.exists(p):
    with open(p) as f:
        s = json.load(f) or {}
s.update({"remoteControlAtStartup": True, "awaySummaryEnabled": False, "agentPushNotifEnabled": True,
          "crossSessionInbound": "accept", "attribution": {"commit": "", "pr": ""}})
ding = "paplay /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 || true"
stop = s.setdefault("hooks", {}).setdefault("Stop", [])
if not any(h.get("command") == ding for g in stop for h in g.get("hooks", [])):
    stop.append({"hooks": [{"type": "command", "command": ding, "async": True}]})
os.makedirs(os.path.dirname(p), exist_ok=True)
with open(p, "w") as f:
    json.dump(s, f, indent=2)
EOF

  python3 -I - "$HOME/.claude/CLAUDE.md" "$DOWNLOADS" <<'EOF' || warn "Could not write ~/.claude/CLAUDE.md."
import os, re, sys
p, downloads = sys.argv[1], sys.argv[2]
b, e = "<!-- claude-setup:begin -->", "<!-- claude-setup:end -->"
rule = f"""{b}
## Where files go
Save files that are meant for the user to look at or keep - generated images, documents, exports, and files they asked you to make or download - in their Downloads folder: {downloads}
Projects, code, and anything that belongs to a repo or working project go where they normally would (the current working directory or project), not in Downloads.

## Git and GitHub
Never add Claude as a contributor: no Co-Authored-By trailers on commits and no Generated-with-Claude-Code line on pull requests. Only use the GitHub noreply email already in git config (user.email) for commits; never use the user's real email in commits, configs or anything pushed to GitHub.
{e}"""
md = open(p).read() if os.path.exists(p) else ""
pat = re.escape(b) + ".*?" + re.escape(e)
if re.search(pat, md, re.S):
    md = re.sub(pat, lambda m: rule, md, flags=re.S)
else:
    md = md.rstrip() + ("\n\n" if md.strip() else "") + rule + "\n"
os.makedirs(os.path.dirname(p), exist_ok=True)
open(p, "w").write(md)
EOF
fi

# GitHub noreply email for commits (needs git and a signed-in gh)
if [ "$SKIP_GIT" = 0 ]; then
  if ! command -v git >/dev/null; then
    warn "Skipped git noreply email: git is not installed (sudo apt install git gh)."
  else
    current="$(git config --global user.email || true)"
    if [[ "$current" != *@users.noreply.github.com ]]; then
      u="$(command -v gh >/dev/null && gh api user --jq '"\(.id) \(.login)"' 2>/dev/null || true)"
      if [ -n "$u" ]; then
        id="${u% *}"; login="${u#* }"
        git config --global user.email "$id+$login@users.noreply.github.com"
        [ -z "$(git config --global user.name || true)" ] && git config --global user.name "$login"
        echo "Git email set to $id+$login@users.noreply.github.com"
      else
        warn "Skipped git noreply email: install gh, run 'gh auth login' and re-run, or set it yourself."
      fi
    fi
  fi
fi

# Mark the starting folder as trusted so Claude skips the "Quick safety check"
if [ "$SKIP_TRUST" = 0 ] && [ -f "$HOME/.claude.json" ]; then
  python3 -I - "$HOME/.claude.json" "$START_DIR" <<'EOF' || warn "Could not pre-trust $START_DIR."
import json, os, sys
p, d = sys.argv[1], sys.argv[2]
with open(p) as f:
    c = json.load(f)
proj = c.setdefault("projects", {}).setdefault(d, {})
if proj.get("hasTrustDialogAccepted") is not True:
    proj["hasTrustDialogAccepted"] = True
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(c, f, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, p)
EOF
fi

# "Claude" app-menu launcher (GNOME Terminal if present, else the system default terminal)
if [ "$SKIP_LAUNCHER" = 0 ]; then
  apps="$HOME/.local/share/applications"; mkdir -p "$apps"
  if command -v gnome-terminal >/dev/null; then
    exec_line="gnome-terminal --title=Claude --working-directory=\"$START_DIR\" -- \"$CLAUDE_BIN\""
  else
    exec_line="x-terminal-emulator -e sh -c 'cd \"$START_DIR\" && exec \"$CLAUDE_BIN\"'"
  fi
  cat > "$apps/claude.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Claude
Comment=Claude Code in a terminal
Exec=$exec_line
Icon=utilities-terminal
Terminal=false
Categories=Development;
EOF
  chmod +x "$apps/claude.desktop"
  command -v update-desktop-database >/dev/null && update-desktop-database "$apps" 2>/dev/null || true
fi

# Line (I-beam) cursor instead of a block in the default GNOME Terminal profile
if [ "$SKIP_CURSOR" = 0 ]; then
  if command -v gsettings >/dev/null && gsettings list-schemas 2>/dev/null | grep -qx org.gnome.Terminal.ProfilesList; then
    profile="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
    gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/" cursor-shape 'ibeam' \
      || warn "Could not set the terminal cursor shape."
  else
    warn "Skipped cursor shape: GNOME Terminal settings not found."
  fi
fi

echo "Done. Open 'Claude' from your app menu (start a new Claude session for the settings to apply)."
