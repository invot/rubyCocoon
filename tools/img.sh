#!/bin/bash
# Measures screenshots (tools/img.gd): bash tools/img.sh diff a.png b.png | bbox x.png | color x.png 0.5 0.5 | crop x.png out.png | size x.png
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-C:/Program Files/Godot/Godot_v4.7-stable_win64.exe}"
"$GODOT" --headless --path . --script res://tools/img.gd -- "$@" 2>&1 | grep -v "^Godot Engine\|^$\|leaked\|still in use\|PagedAllocator\|^ *at: "
