#!/usr/bin/env bash
# Linux launcher (used by the "Claude" app-menu entry that setup.sh creates).
# Opens Claude in its own GNOME Terminal window (app id org.claude.Terminal, so it gets
# its own taskbar icon) and centers that window on the monitor the mouse is on.
# Usage: launch-claude.sh [starting-directory] [claude-binary]
APP_ID="org.claude.Terminal"
START_DIR="${1:-$HOME}"
CLAUDE_BIN="${2:-claude}"

list_windows() { wmctrl -l 2>/dev/null | awk '{print $1}'; }
before="$(list_windows)"

# On Ubuntu/Mint /usr/bin/gnome-terminal is a wrapper that starts a new terminal server for every
# --app-id call, which fails once a Claude window is open. The real client reuses the running server
# (or starts it through the D-Bus service file setup.sh installs).
GT=gnome-terminal
[ -x /usr/bin/gnome-terminal.real ] && GT=/usr/bin/gnome-terminal.real
"$GT" --app-id "$APP_ID" --title=Claude --working-directory="$START_DIR" -- "$CLAUDE_BIN" || exit 1

# Centering needs wmctrl (sudo apt install wmctrl); without it the window just opens where the desktop puts it
command -v wmctrl >/dev/null || exit 0

# Work area (screen minus panels) of the monitor under the mouse: x y width height
area="$(python3 -I -c "
import gi; gi.require_version('Gdk', '3.0'); from gi.repository import Gdk
d = Gdk.Display.get_default(); _, x, y = d.get_default_seat().get_pointer().get_position()
r = d.get_monitor_at_point(x, y).get_workarea(); print(r.x, r.y, r.width, r.height)" 2>/dev/null)"
[ -n "$area" ] || exit 0
read -r ax ay aw ah <<<"$area"

# Wait up to 5 seconds for the new Claude window, then move it to the middle
for _ in $(seq 50); do
  sleep 0.1
  for w in $(list_windows); do
    grep -qxF "$w" <<<"$before" && continue
    xprop -id "$w" _GTK_APPLICATION_ID 2>/dev/null | grep -qF "\"$APP_ID\"" || continue
    read -r ww wh < <(xwininfo -id "$w" | awk '/Width:/ {w=$2} /Height:/ {h=$2} END {print w, h}')
    [ -n "$ww" ] || continue
    # Count the title bar and borders too (left, right, top, bottom), so the whole window is centered
    read -r fl fr ft fb < <(xprop -id "$w" _NET_FRAME_EXTENTS | grep -o '[0-9]\+' | tr '\n' ' '; echo)
    ww=$(( ww + ${fl:-0} + ${fr:-0} )); wh=$(( wh + ${ft:-0} + ${fb:-0} ))
    wmctrl -i -r "$w" -e "0,$(( ax + (aw - ww) / 2 )),$(( ay + (ah - wh) / 2 )),-1,-1"
    exit 0
  done
done
