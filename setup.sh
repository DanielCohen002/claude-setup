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
  --icon <file.png>          Use your own icon instead of downloading Claude's from claude.ai
  --skip-plugin              Don't install the easy-tracking mod
  --skip-preferences         Don't change Claude preferences, the ding hook or the CLAUDE.md rules
  --skip-git-identity        Don't set the global git email to your GitHub noreply address
  --skip-trust               Don't mark the starting folder as trusted
  --skip-launcher            Don't create the "Claude" app-menu launcher
  --skip-cursor              Don't change the GNOME Terminal cursor to a line
  --blank-keyring            Opt-in: replace a locked login keyring with one that has no password,
                             so gh/git (and other apps) stop showing unlock popups. Useful with
                             autologin. The old keyring is moved to a backup, not deleted, but
                             passwords saved in it are no longer available, and new ones are
                             stored unencrypted.
EOF
}

CLAUDE_BIN=""; START_DIR="$HOME"; ICON_PATH=""
SKIP_PLUGIN=0; SKIP_PREFS=0; SKIP_GIT=0; SKIP_TRUST=0; SKIP_LAUNCHER=0; SKIP_CURSOR=0; BLANK_KEYRING=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claude) CLAUDE_BIN="$2"; shift 2 ;;
    --starting-directory) START_DIR="$2"; shift 2 ;;
    --icon) ICON_PATH="$2"; shift 2 ;;
    --skip-plugin) SKIP_PLUGIN=1; shift ;;
    --skip-preferences) SKIP_PREFS=1; shift ;;
    --skip-git-identity) SKIP_GIT=1; shift ;;
    --skip-trust) SKIP_TRUST=1; shift ;;
    --skip-launcher) SKIP_LAUNCHER=1; shift ;;
    --skip-cursor) SKIP_CURSOR=1; shift ;;
    --blank-keyring) BLANK_KEYRING=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

warn() { echo "WARNING: $*" >&2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# 65% volume (65536 = 100%)
ding = "paplay --volume=42598 /usr/share/sounds/freedesktop/stereo/complete.oga >/dev/null 2>&1 || true"
stop = s.setdefault("hooks", {}).setdefault("Stop", [])
found = False
for g in stop:
    for h in g.get("hooks", []):
        if "freedesktop/stereo/complete.oga" in h.get("command", ""):
            h["command"] = ding  # update a ding added by an earlier run instead of adding a second one
            found = True
if not found:
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

# "Claude" app-menu launcher with Claude's icon and its own taskbar entry.
# The icon is not shipped in this repo: it is downloaded from claude.ai at setup time (or use --icon).
# GNOME Terminal runs under its own app id (org.claude.Terminal) so the taskbar shows Claude separately.
if [ "$SKIP_LAUNCHER" = 0 ]; then
  APP_ID="org.claude.Terminal"
  apps="$HOME/.local/share/applications"; icons="$HOME/.local/share/icons"
  mkdir -p "$apps" "$icons"
  icon="$icons/claude-code.png"
  if [ -n "$ICON_PATH" ]; then
    [ -f "$ICON_PATH" ] || { echo "Icon not found: $ICON_PATH" >&2; exit 1; }
    cp "$ICON_PATH" "$icon"
  elif ! curl -fsSL -A "Mozilla/5.0" -o "$icon.tmp" https://claude.ai/apple-touch-icon.png \
       || ! head -c 8 "$icon.tmp" | grep -q PNG; then
    rm -f "$icon.tmp"
    [ -f "$icon" ] || { warn "Could not download Claude's icon; using the terminal icon. Pass --icon to use your own."; icon="utilities-terminal"; }
  else
    mv "$icon.tmp" "$icon"
  fi
  rm -f "$apps/claude.desktop"   # launcher name used by older versions of this script
  if command -v gnome-terminal >/dev/null && [ -x /usr/libexec/gnome-terminal-server ]; then
    mkdir -p "$HOME/.local/share/dbus-1/services"
    printf '[D-BUS Service]\nName=%s\nExec=/usr/libexec/gnome-terminal-server --app-id %s\n' "$APP_ID" "$APP_ID" \
      > "$HOME/.local/share/dbus-1/services/$APP_ID.service"
    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
    # launch-claude.sh opens the window and centers it (needs wmctrl)
    chmod +x "$ROOT/launch-claude.sh"
    exec_line="\"$ROOT/launch-claude.sh\" \"$START_DIR\" \"$CLAUDE_BIN\""
    command -v wmctrl >/dev/null || warn "wmctrl not installed, so Claude won't open centered (sudo apt install wmctrl)."
  else
    exec_line="x-terminal-emulator -e sh -c 'cd \"$START_DIR\" && exec \"$CLAUDE_BIN\"'"
  fi
  cat > "$apps/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Claude
Comment=Claude Code in a terminal
Exec=$exec_line
Icon=$icon
Terminal=false
Categories=Development;
EOF
  chmod +x "$apps/$APP_ID.desktop"
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

# Opt-in: password-less login keyring (no unlock popups, like Windows' credential store after login)
if [ "$BLANK_KEYRING" = 1 ]; then
  K="$HOME/.local/share/keyrings"
  if [ -f "$K/login.keyring" ] && ! head -c 12 "$K/login.keyring" | grep -q GnomeKeyring; then
    echo "Login keyring already has no password; leaving it alone."
  elif ! systemctl --user cat gnome-keyring-daemon.service >/dev/null 2>&1; then
    warn "Skipped blank keyring: gnome-keyring-daemon is not a systemd user service here."
  else
    KB="$HOME/.local/share/keyrings-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p -m 700 "$KB" "$K"
    systemctl --user stop gnome-keyring-daemon.service gnome-keyring-daemon.socket 2>/dev/null || true
    [ -f "$K/login.keyring" ] && mv "$K/login.keyring" "$KB/"
    [ -f "$K/default" ] && cp -p "$K/default" "$KB/"
    printf '[keyring]\ndisplay-name=Login\nctime=0\nmtime=0\nlock-on-idle=false\nlock-after=false\n' > "$K/login.keyring"
    printf 'login' > "$K/default"
    chmod 600 "$K/login.keyring" "$K/default"
    systemctl --user start gnome-keyring-daemon.service || warn "Could not restart the keyring; log out and back in."
    sleep 1
    busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service \
      Unlock ao 1 /org/freedesktop/secrets/collection/login >/dev/null 2>&1 || true
    echo "Login keyring now has no password. Old keyring saved in $KB"
  fi
fi

echo "Done. Open 'Claude' from your app menu (start a new Claude session for the settings to apply)."
