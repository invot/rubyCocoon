#!/usr/bin/env bash
# Records every clip the trailer is cut from (tools/trailer/make_trailer.py), one after another, into
# build/trailer/raw/. Name clips to record just those: bash tools/trailer/record_all.sh b_first merge_b
cd "$(dirname "$0")/../.."
T="--scene=trailer"
GEAR="--trainer=Gearhart,CEO,coat,#1a1a22,#1a1a22,#d8d8e0,#2a2a2a"
clips=(
	"intro|84|$T --shot=film"
	"title|22|--scene=title --saves=0 --quit=0"
	"hatch_embit|10|--scene=growth --preview=hatch --race=0"
	"hatch_frog|10|--scene=growth --preview=hatch --race=27"
	"hatch_owl|10|--scene=growth --preview=hatch --race=30"
	"evolve_dino|13|--scene=growth --preview=evolve --race=0"
	"merge_a|16|--scene=growth --preview=merge --race=0 --other=30"
	"merge_b|16|--scene=growth --preview=merge --race=27 --other=12"
	"merge_c|16|--scene=growth --preview=merge --race=33 --other=24"
	"w_cove|16|$T --shot=world --map=caccoon --from=start --to=center --crane=4"
	"w_bellerive|15|$T --shot=world --map=tidewater --from=start --to=center --crane=3.5"
	"w_sundown|13|$T --shot=world --map=sundown --from=start --to=center --crane=3"
	"w_cogsworth|13|$T --shot=world --map=cogsworth --from=start --to=center --crane=3"
	"w_gravenmoor|13|$T --shot=world --map=gravenmoor --from=start --to=center --crane=3"
	"b_first|34|$T --shot=battle --map=route1 --party=0:6 --foes=27:4 --intro=wild"
	"b_trio|50|$T --shot=battle --map=route4 --party=1:24,31:24,13:24 --foes=36:20,6:21,12:20 --intro=sneak"
	"b_arena|50|$T --shot=battle --map=arena:tidewater --party=1:26,31:26,13:26 --foes=28:25,25:25,22:25 --trainer=Marina,Tide_Captain,,#2a7a9a,#22232e,#3a2a20"
	"b_robots|50|$T --shot=battle --map=tower:3 --party=2:40,32:40,14:40 --foes=44:38,45:38,46:38 $GEAR"
	"b_ghost|50|$T --shot=battle --map=route10 --party=2:44,32:44,14:44 --foes=35:42:g,23:42:g,8:42:g --intro=ambush"
	"b_summon_fire|40|$T --shot=battle --map=route8 --party=2:40,32:40,14:40 --foes=32:38,35:38,38:38 --summon=fire"
	"b_summon_water|40|$T --shot=battle --map=route9 --party=29:40,26:40,23:40 --foes=20:38,14:38,17:38 --summon=water"
)
for c in "${clips[@]}"; do
	IFS='|' read -r name secs args <<< "$c"
	if [ $# -gt 0 ] && [[ ! " $* " =~ " $name " ]]; then continue; fi
	# shellcheck disable=SC2086
	bash tools/trailer/record.sh "$name" "$secs" -- $args
	grep -h "TRAILER\|SCRIPT ERROR\|Parse Error" "build/trailer/logs/$name.log" | cut -c1-200 | sed "s/^/  $name: /"
done
echo "RECORD ALL DONE"
