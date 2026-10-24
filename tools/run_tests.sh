#!/bin/bash
# Runs the game's checks and test scenes, headless (no windows), a few at a time, and prints one line per test:
# "ok" or "FAIL" with the first line that went wrong. Full logs go to build/test_logs/<test>.log. A test that fails is
# run once more before it counts (a couple of the scene tests are timing-sensitive).
#
#   bash tools/run_tests.sh              everything (about 6-8 minutes)
#   bash tools/run_tests.sh quick        the fast checks only: scripts, data, maps, beasts (under a minute)
#   bash tools/run_tests.sh flow ringedit    just the tests named
#   JOBS=4 bash tools/run_tests.sh       how many run at once (default 3)
#   GODOT=/path/to/godot.exe bash tools/run_tests.sh
#
# Exits 0 when everything passed. The tests (name | Godot arguments | what a pass prints):

TESTS=(
	"scripts|--script res://tools/check_scripts.gd|SCRIPTS CHECK DONE: 0 of"
	"data|--script res://tools/check_data.gd|DATA CHECK DONE: 0 problem"
	"maps|--script res://tools/check_maps.gd|MAPS WITH PROBLEMS: 0"
	"beasts|--script res://tools/check_beasts.gd|BEASTS CHECK DONE: 0 problem"
	"review-fixes|--script res://tools/check_review_fixes.gd|REVIEW FIXES DONE: 0 problem"
	"egg-sales|--script res://tools/check_egg_sales.gd|EGG SALES DONE: 0 problem"
	"kennel|--script res://tools/check_kennel.gd|KENNEL DONE: 0 problem"
	"kennel-ui|-- --scene=kennel --touch --verify=1 --wait=0.3|KENNEL UI DONE: 0 problem"
	"mobile-menus|-- --scene=mobile-menus --touch --verify=1 --wait=0.3|MOBILE MENUS DONE: 0 problem"
	"desktop-menus|-- --scene=mobile-menus --verify=1 --wait=0.3|MOBILE MENUS DONE: 0 problem"
	"intro|-- --scene=intro --verify=1|INTRO TEST DONE: 0 problem"
	"rescue|-- --scene=rescue|RESCUE TEST DONE: 0 problem"
	"tidewater-arrival|-- --scene=tidewater-arrival --verify=1|TIDEWATER ARRIVAL DONE: 0 problem"
	"flow|-- --scene=flow --wait=0.3|FLOW TEST DONE"
	"walk|-- --scene=walk4 --wait=0.3|WALK TEST DONE: 0 problem"
	"walk-touch|-- --scene=walk4 --touch --wait=0.3|WALK TEST DONE: 0 problem"
	"battlecmd|-- --scene=battlecmd --touch --wait=0.3|BATTLE COMMANDS DONE: 0 problem"
	"ringedit|-- --scene=ringedit --touch --wait=0.3|RING EDIT DONE: 0 problem"
	"lessons|-- --scene=lessons --wait=0.3|lessons DONE: 0 problem"
	"coaches|-- --scene=coaches --wait=0.3|coaches DONE: 0 problem"
	"wild-grace|-- --scene=wild-grace --wait=0.3|WILD GRACE DONE: 0 problem"
	"arena-entry|-- --scene=arena-entry --wait=0.3|ARENA ENTRY DONE: 0 problem"
	"arena-ladder|-- --scene=arena-ladder --touch --verify=1 --wait=0.3|ARENA LADDER DONE: 0 problem"
	"mascot|-- --scene=mascot --wait=0.3|MASCOT TEST DONE: 0 problem"
	"maps-built|-- --scene=maps --wait=0.3|MAP TOUR DONE: .*, 0 porch"
	"phone|-- --scene=phone --wait=0.3|PHONE TEST DONE: 0 problem"
	"save-ui|-- --scene=saveui --save_dir=res://build/save_ui_saves/ --wait=0.3|SAVE UI TEST DONE: 0 problem"
	"save-ui-touch|-- --scene=saveui --touch --save_dir=res://build/save_ui_touch_saves/ --wait=0.3|SAVE UI TEST DONE: 0 problem"
	"doorway|-- --scene=doorway --wait=0.3|DOORWAY TEST DONE: 0 problem"
	"temple-water|-- --scene=guardian --temple=water --wait=0.3|GUARDIAN water: captured true"
	"temple-air|-- --scene=guardian --temple=air --wait=0.3|GUARDIAN air: captured true"
	"temple-fire|-- --scene=guardian --temple=fire --wait=0.3|GUARDIAN fire: captured true"
	"temple-earth|-- --scene=guardian --temple=earth --wait=0.3|GUARDIAN earth: captured true"
	"temple-ghost|-- --scene=guardian --temple=ghost --wait=0.3|GUARDIAN ghost: captured true"
)
QUICK="scripts data maps beasts"
## what in a test's log fails it whatever else it printed: a script error, or a model, texture or sound missing
BAD="SCRIPT ERROR|Failed loading resource|Resource file not found|Cannot open file|asset missing|model missing"

cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-C:/Program Files/Godot/Godot_v4.7-stable_win64.exe}"
JOBS="${JOBS:-3}"
LOGS="build/test_logs"
mkdir -p "$LOGS"
rm -f "$LOGS"/*.log "$LOGS"/*.result

want=()
if [ "$1" = "quick" ]; then
	want=($QUICK)
elif [ $# -gt 0 ]; then
	want=("$@")
fi

# one test: run it (and once more if it fails), write "<status>|<seconds>|<detail>" to its .result
run_one() {
	local name="$1" args="$2" pass="$3" log="$LOGS/$1.log" start=$SECONDS status="FAIL" detail="" try
	for try in 1 2; do
		# shellcheck disable=SC2086
		timeout 900 "$GODOT" --headless --path . $args > "$log" 2>&1
		# (a missing model, texture or sound counts as a failure too)
		if grep -q "$pass" "$log" && ! grep -qE "$BAD" "$log"; then
			status="ok"
			[ "$try" = 2 ] && detail="(passed on the second try)"
			break
		fi
	done
	if [ "$status" = "FAIL" ]; then
		detail=$(grep -m1 -E "$BAD|FAIL|problem|captured false|Error" "$log" | grep -v "0 problem" | cut -c1-160)
		[ -z "$detail" ] && detail="didn't print \"$pass\""
	fi
	echo "$status|$((SECONDS - start))|$detail" > "$LOGS/$name.result"
}

names=()
started=$SECONDS
for t in "${TESTS[@]}"; do
	IFS='|' read -r name args pass <<< "$t"
	if [ ${#want[@]} -gt 0 ] && [[ ! " ${want[*]} " =~ " $name " ]]; then
		continue
	fi
	names+=("$name")
	while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
		wait -n
	done
	run_one "$name" "$args" "$pass" &
done
wait

failed=0
for name in "${names[@]}"; do
	IFS='|' read -r status secs detail < "$LOGS/$name.result"
	if [ "$status" = "ok" ]; then
		printf "ok    %-13s %4ss %s\n" "$name" "$secs" "$detail"
	else
		failed=$((failed + 1))
		printf "FAIL  %-13s %4ss %s  (log: %s)\n" "$name" "$secs" "$detail" "$LOGS/$name.log"
	fi
done
took=$((SECONDS - started))
if [ "$failed" = 0 ]; then
	echo "ALL ${#names[@]} PASSED in $((took / 60))m$((took % 60))s"
else
	echo "$failed OF ${#names[@]} FAILED in $((took / 60))m$((took % 60))s"
fi
[ "$failed" = 0 ]
