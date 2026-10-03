#!/bin/bash
# Creates a Spotlight-findable "Claude <Name>.app" launcher that opens the normal
# Claude.app as an extra, independent copy (own login, chats, settings).
#
#   ./make-claude-profile.sh Work                # separate data folder Claude-Work
#   ./make-claude-profile.sh Personal --default  # Claude's normal data folder
#
# Use these launchers instead of the plain Claude icon: macOS sends the plain icon
# to whichever Claude is already open. Both launch /Applications/Claude.app, so a
# single Claude update covers every profile - nothing is copied or re-signed.
set -euo pipefail

NAME="${1:-Work}"
CLAUDE_APP="/Applications/Claude.app"
LAUNCHER="$HOME/Applications/Claude $NAME.app"

[ -d "$CLAUDE_APP" ] || { echo "Claude.app not found in /Applications"; exit 1; }
mkdir -p "$HOME/Applications"

# Each launcher first looks for its profile's running Claude. If found, it brings
# that window to the front instead of starting a second copy on the same data
# (which would corrupt it).
if [ "${2:-}" = "--default" ]; then
  PROFILE_DIR="$HOME/Library/Application Support/Claude"
  FIND_PID="ps -axo pid=,args= | grep '/Contents/MacOS/Claude' | grep -v -e Helper -e --user-data-dir -e grep | awk '{print \$1}' | head -1"
  OPEN_ARGS=""
else
  PROFILE_DIR="$HOME/Library/Application Support/Claude-$NAME"
  mkdir -p "$PROFILE_DIR"
  FIND_PID="pgrep -f -- 'MacOS/Claude --user-data-dir=$PROFILE_DIR' | head -1"
  OPEN_ARGS=" --args '--user-data-dir=$PROFILE_DIR'"
fi

# Escape for embedding in an AppleScript string literal.
as_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

SCRIPT=$(cat <<EOF
set pidText to do shell script "$(as_str "$FIND_PID")"
if pidText is "" then
	do shell script "$(as_str "open -n -a '$CLAUDE_APP'$OPEN_ARGS")"
else
	try
		tell application "System Events" to set frontmost of (first process whose unix id is (pidText as integer)) to true
	end try
end if
EOF
)

rm -rf "$LAUNCHER"
osacompile -o "$LAUNCHER" -e "$SCRIPT"

# Reuse Claude's icon so the launcher is easy to spot.
ICON_SRC=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$CLAUDE_APP/Contents/Info.plist" 2>/dev/null || echo "electron.icns")
case "$ICON_SRC" in *.icns) ;; *) ICON_SRC="$ICON_SRC.icns";; esac
if [ -f "$CLAUDE_APP/Contents/Resources/$ICON_SRC" ]; then
  cp "$CLAUDE_APP/Contents/Resources/$ICON_SRC" "$LAUNCHER/Contents/Resources/applet.icns"
  touch "$LAUNCHER"
fi

echo "Created: $LAUNCHER"
echo "Profile: $PROFILE_DIR"
echo
echo "Open it from Spotlight: 'Claude $NAME'. First time on a new profile: quit other"
echo "Claude windows (Cmd+Q) before signing in, so the sign-in returns to this one."
