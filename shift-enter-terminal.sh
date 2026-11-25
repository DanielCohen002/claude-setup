#!/usr/bin/env bash
# Makes Shift+Enter insert a new line in Claude (it sends Ctrl+J) while GNOME Terminal is focused.
# GNOME Terminal sends the same code for Shift+Enter as for Enter, so Claude can't tell them apart.
# The key is only grabbed while the terminal has focus, so other apps are not affected. X11 only.
RC="${XDG_CONFIG_HOME:-$HOME/.config}/claude-setup/shift-enter.xbindkeysrc"
export DISPLAY="${DISPLAY:-:0}"
mkdir -p "$(dirname "$RC")"
# Fires on key release and lets go of Shift without restoring it (restoring it leaves Shift stuck).
cat > "$RC" <<'RULE'
"xdotool keyup Shift_L Shift_R key ctrl+j"
  release + shift + Return
RULE
pkill -f "xbindkeys -f $RC" 2>/dev/null
trap 'pkill -f "xbindkeys -f $RC" 2>/dev/null; exit 0' INT TERM
update() {
  local id
  id=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
  if xprop -id "$id" WM_CLASS 2>/dev/null | grep -qi gnome-terminal; then
    pgrep -f "xbindkeys -f $RC" >/dev/null || xbindkeys -f "$RC" &
  else
    pkill -f "xbindkeys -f $RC" 2>/dev/null
  fi
}
update
xprop -root -spy _NET_ACTIVE_WINDOW | while read -r _; do update; done
