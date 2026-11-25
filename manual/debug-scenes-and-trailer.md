# Debug scenes and trailer

[◀ Manual index](index.md)

Developer preview scenes, the capture harness and the trailer pipeline. Every command runs with fresh, isolated state unless it names its own saves.

## Contents

- [Benchmarks](#benchmarks)
- [World and map previews](#world-and-map-previews)
- [Story, lessons and field previews](#story-lessons-and-field-previews)
- [Battle previews](#battle-previews)
- [Beast previews](#beast-previews)
- [Book, title, creator and phone previews](#book-title-creator-and-phone-previews)
- [Trailer](#trailer)
- [Captures and status notes](#captures-and-status-notes)

## Benchmarks

The phone and visual-overhaul benchmarks are described with the test runner in [Testing](testing.md#diagnostics-and-benchmarks): `vo_phone.py` records the isolated phone package, and `vo_perf.py` runs the fixed-seed route on each renderer. Run the performance route alone, without other GPU jobs.
**Cocoon Cove** implements the selected pirate-cove layout:

- a two-storey library, chunky timber and window frames in Kelpwick's hut wood (`tribal_hut_wood.res`, grain along each beam)
- painted stucco (`cove_stucco.gdshader`) with small darker blocks standing proud of it here and there like Kelpwick's arena (`cove_buildings.gd` `_stucco_blocks`; not on the Beast Center)
- clay tile roofs laid in courses along the eaves (`cove_roof.gdshader`)
- 2.6-unit ground storeys (3.1 at the apothecary and the Beast Center, so the sign over each awning sits on the wall under the eaves), and upper storeys at least 2.45 units high

Focused views use `--scene=cocoon --preview=overview|square|library|neighbor|home|docks|gear|apothecary|apothecary-wide` with `--shot=`; add `--touch` for the phone controls. See [the design and original layout studies](../docs/cove_layout_proposals.md) for asset preparation, fitted bounds and the opaque-exterior check.

## World and map previews

- `--scene=world:<id>` opens any map, with `#<n>` for an interior.
- `--scene=interiors` shows every distinct room.
- `--overview` looks down on a whole map, or on one spot with `--focus=x,y`.
- `--scene=gallery:nature:0` opens an asset gallery.

```sh
godot --path . -- --scene=world:cogsworth --shot=C:/tmp/a.png            # screenshot any map (or world:cogsworth#10 for an interior)
godot --path . --resolution 1920x1080 -- --scene=interiors --shots=res://build/shots/interiors  # every distinct room, fresh state
godot --path . --resolution 2400x1080 -- --scene=interiors --touch --shots=res://build/shots/interiors_touch  # phone audit
godot --path . -- --scene=world:reef --spawn=33,10 --flags=island_peace  # spawn at a tile with story flags set
godot --path . -- --scene=gallery:nature:0 --shot=C:/tmp/g.png           # asset gallery
godot --path . -- --scene=world:tidewater --overview=1 --shot=C:/tmp/o.png   # a whole map from high above
godot --path . -- --scene=world:tidewater --overview=13 --focus=34,21 --shot=C:/tmp/a.png   # one spot (a tile), 13 up
godot --headless --path . --script res://tools/check_tidewater_layout.gd  # galleries clear of paths; solid arena entrance shoulders
godot --headless --path . -- --scene=building-fade                      # buildings load when their base reaches the screen and fade in; also walks the western dock lane; --town=tidewater narrows the audit
godot --headless --path . -- --scene=exteriors --town=caccoon --verbose=1  # no building shows its inside from outside; full-size front doors set on their walls
```

## Story, lessons and field previews

- `--scene=flow` is a scripted run through the whole story; `--scene=sim --n=10` runs simulated auto battles.
- `--scene=tutorial --lesson=attack|defend|potions|sling` plays one Coastal Path teacher's guided battle.
- `--scene=puzzles` solves every road puzzle; `--scene=wilds` covers roaming wild beasts, sneak attacks, chases, ambushes and fleeing.
- `--scene=skytower` rides the Hoobertus; `--scene=knock` knocks on locked doors.

```sh
godot --headless --path . -- --scene=sim --n=10                          # simulated auto battles
godot --headless --path . -- --scene=flow                                # scripted run through the whole story
godot --path . -- --scene=knock                                         # knock on locked doors (a Bellerive house, the cathedral)
godot --path . -- --scene=door-voices --preview=1 --shot=res://build/shots/cove_red_door.png # permanent voices and red/blue paint; add --touch for a phone preview
godot --path . -- --scene=skytower                                      # into a Sky Tower, up to the roof and away on the Hoobertus
godot --headless --path . -- --scene=tutorial --lesson=sling --auto=1   # one Coastal Path teacher's guided battle (attack, defend, potions, sling)
godot --headless --path . -- --scene=tutorial --lesson=elements --auto=1  # a Bellerive arena coach's lesson (team, elements; --egg=24 starts with an earth beast)
godot --path . -- --scene=fishing --taps=4.6 --snap=10 --shot=C:/tmp/f.png  # Gil's lesson (--lesson=0: a cast at a ripple, --bait=worm_bait)
godot --path . -- --scene=battle --kind=fishing --shot=C:/tmp/d.png        # a reeled-in beast's battle: the dock and the water
godot --path . -- --scene=codex --mood=worried --shot=C:/tmp/c.png       # the Codex talking (--topic=id, --mood=happy|excited|proud|curious|worried|surprised|determined|neutral); --book=1: the Start book's Codex page
godot --path . -- --scene=battle --codex=team --shot=C:/tmp/b.png --wait=9  # a battle where the Codex chimes in about one topic
godot --headless --path . -- --scene=lessons                            # every guided battle played by a button masher, with one beast and with two: one thing to pick on every bar and menu, nobody down, all won ("lessons DONE: 0 problem(s)")
godot --headless --path . -- --scene=coaches                            # Coastal Path teachers, Rory's arena approach, a clear lobby route, then speaking to Ondine ("coaches DONE: 0 problem(s)")
godot --headless --path . -- --scene=flutelesson                        # the guided first wild beast after the flute: Weaken, then beating it for its egg
godot --headless --path . -- --scene=mascot                             # mascots' signature moves: the rules, teaching at Lv 39 / 40, another line, a merge
godot --path . -- --scene=mascot --plaque=1 --pages=2 --shot=C:/tmp/q.png   # read Cocoon Cove's statue plaque
godot --headless --path . -- --scene=capture                            # eggs-only rules: Uncle Rafe's lesson, the arena's flute rule, no capture songs, egg chance with gear
godot --headless --path . -- --scene=puzzles                            # solves every road puzzle (bridge, cliff, rockslide, ice, checkpoint, warden, sentinel)
godot --headless --path . -- --scene=wilds                              # roaming wild beasts: sneak attack, chase, ambush, flee
godot --path . -- --scene=marks --shot=C:/tmp/k.png                     # the !, blue ! and ? marks
godot --path . -- --scene=spiral --kind=ambush --wait=0.6 --shot=C:/tmp/s.png   # the battle spiral (sneak / wild / ambush)
godot --path . -- --scene=tap                                           # tap to walk, double-tap to run, tap to talk / enter
godot --path . -- --scene=tapzone                                       # taps near the touch controls don't walk you anywhere
godot --path . -- --scene=walk4 --touch                                 # cardinal keys/d-pad, a near-cardinal stick push, B to run, touch walking and a porch; every stop on a tile's centre ("WALK TEST DONE: 0 problem(s)"); controllers covers eight stick directions
godot --path . -- --scene=heal --shot=C:/tmp/h.png                      # the Beast Center healing machine (--what=hatch for the incubator)
godot --path . -- --scene=defeat --at=0.2 --shot=C:/tmp/d.png           # a beaten foe's puff of smoke and a damage number
godot --path . -- --scene=defeat --trainer=foe --at=1.6 --shot=C:/tmp/k.png   # a beaten trainer dropping to one knee (ally: you; robot: powering down)
godot --path . -- --scene=flute --song=weaken --mode=learn --lesson=1    # the flute game as a lesson (the teacher plays first); without --mode it's your turn straight away
```

## Battle previews

- `--scene=battle --kind=robots` and `--kind=fishing` stage battles; `--keys=r,r,r,a,a` aims a move.
- `--scene=battlecmd` checks the command panel; `--scene=battle-redirect` checks what happens when two beasts aim at one foe.
- `--scene=battle-focus` previews 3D selection and targeting; `--scene=battle-stage` previews every stage.
- `--scene=ring` drives a ring battle by keys; `--scene=ringedit` opens the ring editor.

```sh
godot --path . -- --scene=battle --kind=robots --wait=5 --shot=C:/tmp/b.png
godot --path . --resolution 2400x1080 -- --touch --scene=battle --keys=r,r,r,a,a --shot=C:/tmp/t.png   # aiming a move: target arrows, with move info closed
godot --path . -- --scene=battle --kind=fishing --shot=C:/tmp/d.png        # a reeled-in beast's battle: the dock and the water
godot --path . -- --scene=battlecmd --touch                             # the battle's command panel: one A is one confirm, every move's target picked (arrows, all-foe moves), ▲ turns the ring, Move (yours and a foe trainer's), the ring turning by itself ("BATTLE COMMANDS DONE: 0 problem(s)"); --stop=trainer|target|all|move --shot=C:/tmp/b.png
godot --path . -- --scene=battlecmd --stop=message --shot=C:/tmp/b.png   # compact message with beast avatar; also trainer-message, effective, resistant, long-message
godot --path . -- --scene=battle-redirect --shots=res://build/shots/battle_redirect --save_dir=res://build/battle_redirect_saves/ # two beasts aim at one foe and the first knocks it out: the second goes to the next foe, then the trainer, then is dropped; heals, revives and items too ("BATTLE REDIRECT DONE: 0 problem(s)")
godot --path . --resolution 2400x1080 -- --scene=top-bar --touch --gem=sapphire --shots=res://build/shots/top_bar --save_dir=res://build/top_bar_test_saves/ # the top bar's notices: quick pickups merging, gold adding up, a place name queued behind them, a long line wrapping, then hidden ("TOP BAR DONE: 0 problem(s)")
godot --path . --resolution 1920x1080 -- --scene=battle-focus --shots=res://build/shots/cinematic_desktop --shot_w=0 --save_dir=res://build/cinematic_test_saves/ # 3D selection/targeting, gamepad A, HP tags, shields, long labels, four gems
godot --path . --resolution 2400x1080 -- --scene=battle-focus --touch --shots=res://build/shots/cinematic_touch --shot_w=0 --save_dir=res://build/cinematic_test_saves/ # actual touch menu/3D taps and cluster exclusion; --preview=trainer|beast|cost|target|hit|shield|action
godot --path . -- --scene=battle-focus --wild=1 --save_dir=res://build/cinematic_wild_saves/ # wild pack and a resolved action; --stage_map=route3 (desert), --arena=1, or --stage_map=reef#temple_water for enclosed scenery previews
godot --path . -- --scene=ring --keys=a,a,d,d,d --shot=C:/tmp/r.png      # a ring battle driven by keys (a b l r u d); --kind=wild, --foe_level, --foe_shield
godot --path . -- --scene=ringedit --touch                              # the ring editor: who may go where on the ring and in and out of storage, lit cells, taps ("RING EDIT DONE: 0 problem(s)")
godot --path . -- --scene=mobile-menus --touch --verify=1 --shots=res://build/shots/mobile_menu  # direct A/B answers, centered lists, scrolling, the Start book's retained controls and scroll buttons, and its Map page: tapping towns and flying (Yes / No)
godot --rendering-method mobile --path . --resolution 1920x1080 -- --scene=battle-stage --shots=res://build/shots/battle_stage_desktop --shot_w=0 --save_dir=res://build/battle_stage_saves/ # every biome, dock, arena, five temples/crypt, four Gearheart floors and both Sky Tower rooms; four angles and victory per setting
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=battle-stage --touch --shots=res://build/shots/battle_stage_touch --shot_w=0 --save_dir=res://build/battle_stage_saves/ # camera dwell, real action dispatch, enclosure, scenery shadows and menu/cluster clearance
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=battle-stage --touch --setting=coast --profile=1 --frames=240 --report=res://build/battle_frames.json --save_dir=res://build/battle_stage_saves/ # warmed frame intervals (median/p95), CPU frame time and draw calls; repeat before/after on the same hardware, renderer and layout. A Windows Mobile-renderer run does not establish phone performance.
godot --headless --path . --script res://tools/check_battle_visuals.gd # closed arrow geometry, complete mural surfaces and mipmapped artwork for every biome
```

**Rebuilding the battle murals:**

```sh
godot --path . --rendering-method gl_compatibility --script res://tools/bake_battle_backdrops.gd # offline mural rebuild; -- --biome=coast rebuilds one region
godot --headless --path . --import
godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/battle/backdrops/
godot --headless --path . --import # reimport the smoothed, mipmapped murals; the smoothing record prevents double passes
```

## Beast previews

- `--scene=beasts:0` shows the beast gallery as the game draws it (pages 0-3: the forms, then the legendaries; 4 = merges).
- `--scene=newbeasts` lines beasts up side by side; `--anim=cycle` runs every pose.
- `--scene=battle-poses` shows the poses through the battle camera.
- `check_beasts.gd` checks every form's name, elements and model, growing up at Lv 20 and 40, and merging only final forms.

```sh
godot --path . -- --scene=beasts:0 --shot=C:/tmp/v.png                   # beast gallery as the game draws them (pages 0-3: the forms, then the legendaries; 4 = merges)
godot --path . -- --scene=newbeasts --lines=dino,owl --shot=C:/tmp/n.png  # the beasts side by side, a column per line (--stages=1,3, --anim=idle|walk|lie|attack|cast|defend|block|hit|heavy|faint (--wait=0 --at=s: the shot that far into it), --ghost=1, --view=three|side|front, --zoom, --merge=dino_3+owl_3 --seeds=1,2,3)
godot --path . --resolution 1920x1080 -- --scene=newbeasts --anim=cycle --page=all --shots=res://build/shots/poses --shot_w=0  # every line's three forms (--page=0..2, five lines a page), then ghosts of every body and merges, through every battle pose, named over them; saves <page>_<pose>.png at each pose's telling moment (--quit=0 loops one page)
godot --path . --resolution 1920x1080 -- --scene=battle-poses --shots=res://build/shots/battle_poses --shot_w=0 --save_dir=res://build/battle_poses_saves/ # the poses in a real battle through its camera: a cast's two cuts and its extra-effective hit, Defend and a block, a hit, a heal, a faint ("BATTLE POSES DONE: 0 problem(s)"); --old=1 the legendaries' and robots' models; add --resolution 2400x1080 --touch for the phone layout
godot --headless --path . --script res://tools/check_beasts.gd           # every form's name, elements and model; growing up at Lv 20 and 40; merging only final forms ("BEASTS CHECK DONE: 0 problem(s)")
```

## Book, title, creator and phone previews

- `--scene=book:<tab>` opens the Start book on a tab.
- `--scene=title` previews the title menu; `--fixture=1` gives it a fresh test save.
- `--scene=maker` exercises the character creator; `--scene=hero` shows the hero from four sides.
- The save, call and phone scenes preview the corresponding screens.

```sh
godot --path . -- --scene=book:settings --gem=sapphire --shot=C:/tmp/s.png  # try a gem for one run
godot --path . -- --scene=book:map --flip=cozy --wait=1 --shot=C:/tmp/f.png   # Settings > Style changed with the book open
godot --path . -- --scene=book:beasts --shot=C:/tmp/m.png               # the Start book on a tab (trainer, beasts, flute, bag, codex, map, settings); --flyer=1 adds an air beast that can fly, --visited=caccoon,tidewater sets the towns you've been to, --no_map=1 is before the library's map, --next=N taps a scroll bar's down arrow N times
godot --path . -- --touch --scene=battle --shot=C:/tmp/t.png            # touch layout
godot --path . -- --scene=title --fixture=1 --keys=d,a --save_dir=res://build/title_saves/ --shot=C:/tmp/t.png   # title with a fresh test save; d,a opens Load Game (--saves=0: first-launch menu)
godot --path . -- --scene=title --hold=1 --quit=0 --save_dir=res://build/title_skip_preview/   # hold the rising dragon; press A or tap to check skipping
godot --path . --resolution 2400x1080 -- --touch --scene=maker --verify=1  # the character creator's five tabs: rows, keys, taps, color grids and Start ("MAKER TEST DONE: 0 problem(s)"); --picks=body:1,tab:1,hat:2,dye:hat:#3a6ab8,row:hat_color,open:hat_color
godot --path . -- --scene=hero --shot=C:/tmp/h.png                      # the hero from four sides
godot --path . -- --scene=saves --card=1 --shot=C:/tmp/c.png            # save slots and the "Game saved!" card
godot --path . -- --scene=call --shot=C:/tmp/c.png                       # calling Dad from the phone at home, up to his first line (--where=payphone|center, --town, --presses)
godot --path . -- --scene=call --where=center --town=tidewater --who=mom --tip=0 --level=8 --presses=5 --shot=C:/tmp/m.png   # calling Mom: her tip, then her level advice
```

**World-map artwork previews:**

```sh
godot --path . -- --scene=mobile-menus --preview=map --explored=1 --wait=1 --shot=res://build/shots/map.png --shot_w=0 --prefs_path=res://build/map_preview/settings.cfg --save_dir=res://build/map_preview/saves/
```

Use 1920x1080 on desktop, or 2400x1080 with `--touch` for the phone layout. Omit `--explored=1` to retain question marks for unreached towns. The supplied map artwork is rebuilt with `python tools/prepare_world_map.py` (Pillow), then `godot --headless --path . --import`; these are 2D UI assets, not world textures.

## Trailer

`tools/trailer/` records and cuts the trailer from real play. It needs ffmpeg, and Python with Pillow and NumPy.

```sh
bash tools/trailer/record_all.sh               # every clip, 1920x1080 at 60 fps, into build/trailer/raw/ (name clips to record just those)
python tools/trailer/make_trailer.py           # the cut -> build/trailer/ruby_cocoon_trailer.mp4
python tools/trailer/make_trailer.py --sheet   # a still of every shot and card, for checking the cut
python tools/trailer/make_trailer.py --audio   # mix the sound again and lay it on the finished picture
```

- Clips are recorded with Godot's movie writer from fresh state (their own settings and saves under `build/trailer/`), with the game's sound effects and no music.
- `--scene=trailer` (`tools/debug/trailer.gd`) stages them:
  - `--shot=film` plays the opening film without the controls' hints.
  - `--shot=world` runs the hero through a map behind a camera that cranes down onto them.
  - `--shot=battle` plays a battle by itself on a chosen map with a chosen party and foes.
  - `--shot=play` plays from real key presses for plain gameplay footage: `--input=` lists them (`r@1.5` holds →, `a` taps A, `m` Start, `w1` waits, `song` plays the flute sheet that's up, `fish` strikes and reels, `cell:p2` clicks a ring editor cell). Add `--battle=1 --auto=0` to choose a battle's moves by hand (`tools/debug/trailer.gd` lists them all).
- The cut, its title cards and its sound are listed in `make_trailer.py` `build_cut()`; its shots land on the bar lines of the coast theme and, for the finale, the boss theme. Every frame carries a pre-release footage notice along the bottom.
- The music is the game's own: "Adventures in Adventureland", "Ether Vox" and "Rising Tide (faster)", listed in `CREDITS.md` as Kevin MacLeod's under CC BY 4.0 (each still to be confirmed there). Credit him wherever the trailer is posted.

## Captures and status notes

**Island-update captures** (isolated saves): `--scene=island-updates --shots=res://build/shots/island_updates/desktop --shot_w=0` at 1920x1080, or 2400x1080 with `--touch`.

- The arena ladder has twelve ranks with four trainers each; old saves retain completed-rank credit when migrating to the expanded roster.
- Beach guests can be spoken to while reclining and complain about their resort holiday.

**Pending-request update, 17 November 2026:**

- New Game covers character-creator loading with a multicolour spiral until the bedroom and mirror are ready. Its progress bar reports completed phases.
- A fresh A/B press can dismiss an egg-drop film immediately; hatching and level-up retain their reveal and continue flow.
- Aquatic egg shells no longer carry fins.
- See [revised development plan](../docs/development-plan.md) for the remaining story and exploration work.
