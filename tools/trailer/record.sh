#!/usr/bin/env bash
# Records one clip of real gameplay with Godot's movie writer: 1920x1080 at 60 fps, the game's own sound effects and
# no music (the trailer's music is laid over the cut). Fresh state only: isolated settings and saves under build/.
#   bash tools/trailer/record.sh <name> <seconds> -- --scene=... [more game arguments]
# The clip lands in build/trailer/raw/<name>.avi, its log in build/trailer/logs/<name>.log.
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-C:/Program Files/Godot/Godot_v4.7-stable_win64.exe}"
name="$1"; seconds="$2"; shift 2
[ "${1:-}" = "--" ] && shift
out="build/trailer/raw"; mkdir -p "$out" build/trailer/logs build/trailer/prefs build/trailer/saves
if [ ! -f build/trailer/prefs/settings.cfg ]; then
	cp tools/trailer/settings.cfg build/trailer/prefs/settings.cfg
fi
frames=$(python -c "print(int(round(float('$seconds') * 60)))")
"$GODOT" --path . --resolution 1920x1080 --position 40,20 \
	--write-movie "$(pwd -W 2>/dev/null || pwd)/$out/$name.avi" --fixed-fps 60 --quit-after "$frames" \
	-- "$@" --prefs_path=res://build/trailer/prefs/settings.cfg --save_dir=res://build/trailer/saves/ \
	> "build/trailer/logs/$name.log" 2>&1
code=$?
grep -c "SCRIPT ERROR\|ERROR:" "build/trailer/logs/$name.log" | sed "s/^/$name: errors in log: /"
exit $code
