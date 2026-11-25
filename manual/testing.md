# Testing

[◀ Manual index](index.md)

## Contents

- [The test runner](#the-test-runner)
- [Diagnostics and benchmarks](#diagnostics-and-benchmarks)
- [Movement, input and settings](#movement-input-and-settings)
- [Story, maps and world](#story-maps-and-world)
- [Interface and menus](#interface-and-menus)
- [Battle and beasts](#battle-and-beasts)
- [Assets and rendering](#assets-and-rendering)
- [Captures and screenshots](#captures-and-screenshots)

## The test runner

`bash tools/run_tests.sh` runs every check and test scene headless (no windows), three at a time, and prints one line per test, `ok` or `FAIL` with what went wrong. Full logs go to `build/test_logs/`. A failing test gets a second try before it counts, and the script exits 0 when all passed.

- About three and a half minutes.
- `bash tools/run_tests.sh quick` runs only the fast checks (seconds).
- Naming tests (`bash tools/run_tests.sh flow ringedit`) runs just those.

The runner supplies isolated save and preferences paths under `build/` when a scenario has no explicit override. It runs one test at a time by default (`JOBS` can override this).

- **Memory limits (Windows):** each test is stopped at 4 GiB private memory, or when system headroom drops below 8 GiB of commit / 4 GiB of RAM. A memory cutoff is a failure and is not automatically retried; only that test's process tree is stopped.
- **Screen size:** headless scene tests explicitly size the dummy window to the 1280×720 reference (or the test's `--resolution`), so GUI clipping and injected touch input use the intended screen dimensions.
- **Failures:** it rejects script errors, missing assets and deferred callback errors even if a scenario prints its success marker.

## Diagnostics and benchmarks

**Step-007 diagnostic route and merge film.** `bash tools/run_tests.sh vo-alpha` checks the route and merge-film setup. `python tools/vo_alpha.py desktop --part=film --renderer=mobile --attempt=<new-name>` runs the isolated zero-alpha beam and halo comparison.

- `--part=aa` separately compares 2x MSAA / FXAA / 2x MSAA on moving Coastal Path foliage and the merge film.
- `--part=suite` retains the standard walking and battle route for transparency attribution and tests zero-alpha film draws.
- These are diagnostic changes only, with isolated state, three passes, raw traces and foreground validation.
- Material inventories are source and frustum estimates, not renderer transparent-pass counts.
- Phone export and record commands are `export` and `phone`; they use the separate benchmark package, never player saves. See `tools/vo_alpha.py --help`.

**Benchmark routes.** `bash tools/run_tests.sh vo-perf-route` checks the benchmark's cardinal routes and deferred rendering callbacks; windowed measurements remain separate from this headless check.

**Visual-overhaul performance.** `python tools/vo_perf.py` runs the fixed-seed route twice on Forward+, Mobile and Compatibility at 1920×1080, plus Mobile at 2400×1080 with touch controls.

- It uses isolated saves and preferences, writes raw frame traces, median/p95/p99, worst frames, CPU/render/GPU counters, video memory, frustum material and surface estimates, and transition black holds under `build/perf/vo/`, and captures each segment under `build/shots/vo/001/`.
- It checks identical routes and a 5% median repeatability limit. Run it alone, without other GPU jobs. These are desktop measurements with presentation pacing enabled, not phone results.
- `GODOT` overrides the executable; `--renderers mobile` selects one configuration.
- The underlying mode is `--scene=vo-perf --report=res://build/perf/vo/run.json --shots=res://build/shots/vo/run --save_dir=res://build/vo_state/saves/ --prefs_path=res://build/vo_state/settings.cfg`; `--verify=1` only checks route reachability and produces no performance baseline.

**Phone benchmark.** `python tools/vo_phone.py export`, then `python tools/vo_phone.py run --serial=<adb-serial> --display=<SurfaceFlinger-display-id>`.

- It installs a separate debug package, records at least 15 minutes at 720p / Mid and uses isolated `user://bench/vo/` storage. `--attach` resumes a host observer without restarting the app.
- The first real-device baseline measured approximately 29-30 fps on a razr 2024; see [the phone report](../docs/visual_overhaul/002-phone.md) for the thermal curve, loading stalls and measurement gaps.

**Map build profile.** `--scene=build-profile --maps=caccoon,tidewater` times each phase of building a map and every building on it, and counts what the finished map asks of the renderer (`--buildings=1` lists each building).

**Field frames.** `--scene=field-perf --report=res://build/field_frames.json` samples desktop frame intervals, script CPU and GPU times on a repeatable camera path behind buildings. Run with the same renderer and settings before and after.

**Transitions.** `transitions` walks a route of towns, roads and rooms through the real transition, timing how long each stays black and checking outdoor artwork, monotonic progress and overlay cleanup on arrival. `--scene=transitions --report=res://build/transitions.json` writes the timings; run it in a window for VSync-capped figures.

**Performance and stalls.** `performance` checks cold and repeated creator and beast timings, map loading frame gaps, a bounded building cache and cached animation measurements. `--scene=stalls --report=res://build/performance.json` writes the timing report; optionally pass `--baseline=res://build/performance/baseline.json` to compare collision-grid hashes.

## Movement, input and settings

**Controllers.** `bash tools/run_tests.sh controllers controllers-touch video-settings video-settings-touch walk walk-touch` checks controller layout detection, nonzero device IDs, connect/disconnect fallback, eight stick directions, deadzone, corner and stair protection, equal diagonal speed, menu input, available input choices, saved preferences and settings focus and scroll retention. These inject joypad events; physical USB/Bluetooth pairing and Android drivers require device testing.

**Diagonal movement.** `bash tools/run_tests.sh diagonal diagonal-touch` checks the step-012 movement core in both states: all four diagonals, corner/level/ramp/cliff protection, single-component slides, equal ground speed, NPC and beast arrivals, grass step accounting and a cardinal door trigger after a diagonal.

- The developer argument `--diagonal_core=1` pins core collision rules for diagnostics independently of the public input preference.
- The named `walk-diagonal-on`, `walk-touch-diagonal-on`, `wild-grace-diagonal-on`, `flow-diagonal-on` and `lessons-diagonal-on` scenarios exercise the opt-in core.
- `diagonal-input`, `diagonal-input-touch` and `diagonal-input-reference` check the public setting's default, persistence, runtime changes, raw key/joypad/touch events, finger slides, B plus movement, flute chords and the Settings row at desktop, wide-phone and 1280×720 touch layouts.
- Capture the row with `--scene=diagonal-input --shots=res://build/shots/vo/013/<profile> --shot_w=0` and isolated preferences and saves.

**Video settings.** `video-settings` / `video-settings-touch` cover all twelve resolution and quality combinations, aspect ratio and resize, world-coordinate mapping, smooth enlargement (sharpened only on Forward+/Mobile), authored effect restoration, supported renderers, isolated settings persistence and legacy defaults, actual taps, gamepad A, focus navigation and scrolling.

- Windowed captures: `--scene=video-settings --prefs_path=res://build/video_preview/settings.cfg --save_dir=res://build/video_preview/saves/ --shots=res://build/shots/video --shot_w=0` at 1920x1080, or 2400x1080 with `--touch`. Captures include all four gems and four world resolutions.
- Add `--profile=1 --frames=120 --report=res://build/video_profile.json` to record warmed 3D viewport GPU/CPU render times for all twelve combinations. A Windows run with the Mobile renderer measures desktop hardware, not phone performance.

**Controller preview.** Windowed: `godot --path . --resolution 1920x1080 -- --scene=controllers --controller="DualSense Wireless Controller" --shots=res://build/shots/controllers_desktop --shot_w=0 --prefs_path=res://build/controller_preview/settings.cfg --save_dir=res://build/controller_preview/saves/`.

- Repeat at `2400x1080` with `--touch` and separate output, settings and save directories for a 20:9 phone layout.
- `--controller="Nintendo Switch Pro Controller"` previews Nintendo, and an unknown name previews the Xbox fallback.

**Bag capacity and actions.** `bash tools/run_tests.sh bag-limit bag-limit-touch` covers capacity; `bash tools/run_tests.sh bag-actions bag-actions-touch` checks the Bag page's actions (use on the one beast it helps, blocked battle items, beast and trainer gear, drop with No then Yes, key items). Add `--shots=res://build/shots/bag/x` to `--scene=bag-actions` in a window for each state.

- Preview with `--scene=bag-limit --shots=res://build/shots/bag --shot_w=0 --save_dir=res://build/bag_preview/` at 1920x1080, or 2400x1080 with `--touch`.
- The scenario checks stack boundaries, exemptions, lossless migration, refused purchases, persistent swaps, focus, tapping, scrolling and empty lists, then captures all four gems.

## Story, maps and world

**Demo.** `bash tools/run_tests.sh demo demo-touch mechanic-lessons` checks the studio, the cave entrance, the band's release and music switch, Torrent and the demo captain's board-or-stay choice.

Capture the demo with:

```sh
godot --path . --resolution 1920x1080 -- --demo --scene=mechanic-lessons --part=dance --shots=res://build/shots/demo_desktop --shot_w=0 --save_dir=res://build/demo_preview/
```

Repeat at `2400x1080` with `--touch` and separate capture and save directories for phone layout and actual taps.

**Weapon fixtures.** `weapon-slingshot`, `weapon-boomerang`, `weapon-bat` and `weapon-touch` cover road walks, unknown and known weapon hints, facing and blocked shots, automatic use, returning boomerangs, released ladders and gates, one-time treasure and isolated save/load persistence. Run `bash tools/run_tests.sh weapon-slingshot weapon-boomerang weapon-bat`.

- Windowed desktop captures: `godot --path . --resolution 1920x1080 -- --scene=weapon-walk --shots=res://build/shots/weapon_desktop --shot_w=0 --save_dir=res://build/weapon_preview/`.
- Repeat at `--resolution 2400x1080` with `--touch` and separate capture and save directories to exercise actual taps.

**Fences.** `bash tools/run_tests.sh fences fences-touch` checks the supplied sections, wood and stone collision, two-tile yard gates and preserved Cove interior ids. For gameplay-camera captures, use `--scene=fences --preview=wood|stone|iron|graveyard|nature|cove --shot=res://build/shots/fences.png --shot_w=0`; add `--touch` and `--resolution 2400x1080` for a landscape phone view. Test saves stay under `build/`.

**Audio.** `bash tools/run_tests.sh audio` checks sound resources, ambient routing, playback past an Ogg loop boundary and rapid indoor/outdoor transitions, without reading or writing player saves.

**Specific scenes.**

- `intro` / `intro-touch`: holding Esc / B / Start to skip (the HUD saying to keep holding while its bar fills; a tap of B turns the page instead), the controls in the top-centre HUD for four seconds as a scene begins, every line a speech bubble on one page with no narration, the phone pad showing only a plain A and B, the New Game handoff to the bedroom and Mom's plan downstairs, untouched starter state, and Dustwell setting its news flag on arrival without a speech.
- `cocoon`:
  - **Layout:** compact pirate-cove layout, saved building identities, single right-hand dock access, shared door sizes, no thick hedges, one-level ramps of at most three tiles, the tall rim of cliffs, a path to every door.
  - **Buildings:** the two-storey library with its door in the middle, the pier neighbor's shack room, the path to the gear shack and its starter gear (`--preview=shack_path` or `shack`).
  - **Flow:** the home-to-library route, entering the library (real door taps on touch), receiving the world map through the real dialogue controls, repeat visits and isolated save persistence.
  - Run with `--scene=cocoon --verify=1 --save_dir=res://build/cocoon_saves/`; add `--touch` for touch input.
- `coastal-path` / `coastal-path-touch`: walking to and across the continuous beach, screen taps in the shallows, the wading limit, returning to the trail, and no beach waterfalls or beachgoers. Windowed preview: `--scene=coastal-path --shot=res://build/shots/coastal_beach.png --save_dir=res://build/coastal_preview_saves/`.
- `waterfront`: relocated library sign taps, all four dock stair flights, entering the over-water equipment shack, collecting starter beast gear and persistence on re-entry.
- `gravenmoor` / `gravenmoor-touch`: silent arrivals and retained progression flags, contextual local speech before and after the Legion, Mort's song, Clover's ghost-egg guidance, glowing lamp panes, and written notices in dark windows through all four gems, using real interaction and confirmation input.
  - Capture with `--scene=gravenmoor --shots=res://build/shots/gravenmoor --shot_w=0 --save_dir=res://build/gravenmoor_preview/`.
  - Add `--touch` at 2400x1080 for the phone layout, or `--preview=arrival|talk|notice --quit=0` to hold a state.
- `shellhaven-marina` / `shellhaven-marina-touch`: western ramp access, walking all marina fingers, an open beachfront, the straight middle pier, ferry arrival placement, the shared ferry model and scale, shallow wading and its walking/running/tap limits, wet footfall playback, and old-save position compatibility.
- `rescue`: locked freight control, three captives, rescue persistence across map reloads, repeat use, and the reunion.
- `arena-ladder`: four-trainer rank tabs, touch-control clearance, compact talk-menu rows, left/right navigation, tab and trainer taps and A/B confirmation without vertical scrolling. Add `--matrix=1` to the scene for all four gems.
- `kennel` / `kennel-ui`: level-based adoption fees, exact and insufficient funds, cancellation, free reclaiming, storage overflow, drop-off to storage or adoption (and the Beast Center's storage-only drop-off), and the real keeper and pen menus with touch and focus navigation. Preview with `--scene=kennel --shot=res://build/shots/kennel.png` (`--preview=poor` or `empty` for those states; `--verify=1` exercises inputs).
- `counter-phones`: every service phone sits on a counter; walks to each distinct layout and checks interact and handset taps. Captures go to `build/shots/counter_phones` (`--shots=...` overrides it); add `--touch` for the phone layout. Uses fresh state and cancels calls without saving.

## Interface and menus

**Ring editor and book.** `ring-start` / `ring-start-touch` cover:

- the book list of carried beasts with HP/MP lines, and focus lighting a beast on the ring
- the Info/Move/Equip actions bar and its focus, Move and B back to the actions
- the storage screen (sections, swaps, healing on storing, the Storage stop, the last carried beast)
- the Default element row, empty-side skipping, occupied corners and fainted beasts
- focus, gamepad and tap input, tentative three-slot placement and cancellation
- full-opacity selected models with continuous silhouette masks and faded other beasts, and no swap arrow
- occupied swaps from storage and within the ring, levels and membership icons
- empty and full rosters, scrolling
- 3D formation framing without the trainer or dais
- isolated save compatibility and persistence across battle completion

- `--battle=1` also opens a real battle on the chosen side.
- `--scene=ring-start --matrix=1 --shots=res://build/shots/ring_start --save_dir=res://build/ring_start_preview/` checks runtime changes through all four gems and captures each combination; add `--touch` for the phone layout.

**Title.** `title-startup` / `title-startup-touch`, plus `title-startup-gamepad`, `title-startup-mouse`, `title-startup-touch-a` and `title-startup-natural`, check the artwork crossfade, zoom and looping, one confirmation per press, the retained slideshow and title, keyboard focus, tapping New Game once and returning with B, using isolated save paths.

**Character creator.** `hero-maker` / `hero-maker-touch` cover actual name and gender navigation (Tra, Moss, the body each gender wears, legacy gender defaults and isolated save and load), Ben's 10% scale in preview and play, the hair, hat, shirt, pants and shoes arrows, the colour rows' grids opened, picked and kept by tap, and cancellation. `--scene=creator --shots=res://build/shots/creator` captures Tra, Moss, Ben, and the Hair and Legs tabs.

**Name easter eggs.** `name-easter-eggs` / `name-easter-eggs-touch` cover deterministic Moss/Tra proc and non-proc rolls, a real charged weapon through Defend/shields/Sturdy/Vanish, boss and special exclusions, real fear and betrayal turns, trainer shields and defeat, and tutorial/Codex protections. `--scene=name-easter-eggs --shots=res://build/shots/name_eggs` captures the sparkles, knockout, frightened beast and betrayal.

**Polish.** `polish` / `polish-touch` cover glyph coverage and font metrics, home/door/dock rules, coloured lamps, machine speech, reply feedback, bounded beast information, sequential level stats and immediate item notices. Windowed `--scene=polish --shots=res://build/shots/polish --shot_w=0` captures these states using isolated test data.

**Save and phone prompts.** `phone-save` / `phone-save-touch` cover Dad's save and continue Yes/No prompts, declined saves, one answer per press, and returning to the title. Preview with `--scene=phone-save --save_dir=res://build/phone_save_preview/ --shot=res://build/shots/dad.png` (captures both prompts; add `--touch` for touch inputs).

**Door voices.** `door-voices` / `door-voices-touch` cover permanent door replies, real knocking and confirmation input, and white speech bubbles pointing to outdoor and indoor doors. It checks the top, bottom and side edges for safe-area and touch-control clearance. `--scene=door-voices --verify=1 --shot=res://build/shots/door_voice.png` captures those placements.

**Speech.** `speech` / `speech-touch` cover real NPCs at the top and bottom edges and beside the d-pad, indoor counter staff, three-page speech, idle stability, real movement, off-screen, hidden and freed speakers, all four gems, direct A/B answers and tap/gamepad/keyboard advancement without world movement.

- Capture with `--scene=speech --shots=res://build/shots/speech --shot_w=0 --save_dir=res://build/speech_preview/`.
- Use `--resolution 1920x1080` for desktop, or `--resolution 2400x1080 -- --scene=speech --touch` for the phone layout.

## Battle and beasts

**Growth, hatching and merging.** `beast-growth` covers species egg names and unique shells, all three TCM tong tips against every shell shape, textured hatchery surfaces, scene geometry budget, downlight, plain unlit tongs and fog, every hatch including storage overflow, queued battle XP, full HP/MP restoration, sequential rewards, both evolution thresholds, and the merge film's timing, input and pause.

- Add `--verify_ui=1` to `--scene=growth` in a rendered window to check real taps, focus, confirmations, pause and sequential films.
- `--scene=growth --preview=hatch` (or `evolve`, `level`, `starters`) previews the scene or starter choice; `--race=0 --at=4.2 --shot=res://build/shots/hatch.png` holds a cinematic frame for inspection.
- `--preview=merge` plays the merge film (`--race`, `--other` and `--ghost=1` pick the parents): `--at` and `--shot` hold one instant, and `--shots=path` saves a frame at each beat. Add `--perf=1` to a held preview to print frame timing and draw and primitive counts on the renderer being tested.

Rebuild the hatchery art (the procedural vault and column are in `tools/hatchery_chamber.gd`):

```sh
python tools/prepare_hatchery.py "path/to/downloads"
godot --headless --path . --script res://tools/import_hatchery.gd   # add -- --roundels to bake only the merge film's chamber
godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/interiors/hatch_
godot --headless --path . --import
```

`--audit` on the importer and `tools/debug/hatchery_parts.gd -- core` (or `platform`) produce source-part inspection sheets.

**Wild beasts.** `beast-turn` checks that a wild beast met from the side turns smoothly to face you before the battle (no snap), and one you sneak up on leaps without turning. Add `--shot=res://build/shots/beast_turn.png` for before, mid-turn and facing frames.

**Wild protection.** `wild-grace` covers wild battle return protection, smooth opacity bounds, sight and hearing, existing chases, contact, expiry, map changes, and trainer battle exclusion. Add `--shot=res://build/shots/wild_grace.png` for low, middle and high pulse opacity and the fully opaque player after expiry, or `--preview=pulse` to replay the effect in a game window.

**Battle checks.**

- `check_data.gd` checks that everything the data names exists: the beasts (race ids) on routes, maps, trainers, leaders, coaches, temples, fishing pools and eggs; songs, moves, shop items and summon models; and everyone on every map.
- It also checks that the hero in every outfit and hairdo (and the pack, in the colour chosen) can be dressed.
- `check_maps.gd` (above) also checks stage furniture facing, tall scenery placement and the implied TV wall.
- `check_beasts.gd` checks the beast lines, growing up and merging.

**Test scenes:** the story flow, cardinal walking (keys and touch), eight-direction controller walking, battle commands, the ring editor, the lessons, the coaches, the mascots, the doors and stairs at home, and each temple from its stone puzzle to capturing its guardian.

## Assets and rendering

- `check_scripts.gd`: every script parses and compiles.
- `check_nature.gd` (`bash tools/run_tests.sh nature`): single-tile hedge borders on every outdoor map, unchanged planted-ground collision, and the solid-blade grass meshes' triangle budgets.
- `scenery-lods`: recentering scenery preserves existing distance-detail thresholds and indices, base geometry, UVs, normals and materials, including both renderer index widths. `vo-scenery` checks the isolated three-map LOD-comparison route.
  - Windowed measurements use `python tools/vo_scenery.py desktop --part=lod --renderer=mobile --attempt=<new-name>`.
  - `--part=chunks4` and `chunks16` compare against the existing 8x8 chunks without changing gameplay defaults. Headless runs cannot verify renderer culling bounds.
- `check_terrain.gd` (`bash tools/run_tests.sh terrain`): raised grass on both halves of all four diagonal cliff directions, lawn joins beside paths and other diagonals, and surface-appropriate lips for grass, sand, path and beds.
- `ground`: the shipped ground meshes in `assets/ground/` match what the terrain code generates for every outdoor map, as a new game finds it and with its story gates, obstacles and floods changed. After changing the terrain code or a map's tiles, rebake with `godot --headless --path . -- --scene=bake-ground`, then `godot --headless --path . --import`.
- `meshes`: the shipped generated meshes in `assets/baked_meshes/` match what `cove_buildings.gd`, `voxel_props.gd`, `house_builder.gd`, `fence_models.gd` and `townfolk.gd` make for every outdoor map. After changing those generators, the scripts or models they use (`MeshStore.GROUPS`), rebake with `godot --headless --path . -- --scene=bake-meshes`, then `godot --headless --path . --import`.
- `textures`: every 3D surface on every town, road and room, and every beast and ghost, is drawn with a texture (`scripts/gfx/surface_finish.gd`); only light, shade and glow effects may be plain. `--scene=texture-audit` lists the rest (add `--maps=caccoon,route1` or `--rooms=0` to narrow it, `--report=path.json` to save the list).
- `house-measurements` / `battle-art`: baked geometry measurements and exact generated ring and audio assets.
- `exteriors` (`--scene=exteriors`, `tools/debug/exteriors.gd`): every town building and scenery house, built as the world builds it, seen from outside (AGENTS.md "Building exteriors and scale").
  - From each point a building encloses, lines towards wherever the gameplay camera can be must meet an opaque face of the building turned towards it (no holes, open doorways, missing panes or culled faces show the inside).
  - Every front door is at least 1.7 tall (the hero is 1.44) with its leaf no more than 0.12 in front of the wall beside it.
  - `--town=` narrows it, `--verbose=1` prints every building's measurements.

## Captures and screenshots

Focused cinematic previews use the normal screenshot harness and fresh state (no player saves):

```sh
godot --path . -- --scene=intro --at=20 --shot=res://docs/screenshots/intro_tower.png
godot --path . -- --scene=intro --at=30 --shot=res://build/shots/intro_cages.png
godot --path . -- --scene=intro --at=46 --shot=res://docs/screenshots/intro_spring.png
godot --path . -- --scene=intro --at=63 --shot=res://build/shots/intro_bedroom.png
godot --path . -- --scene=intro --hold=0
godot --path . -- --scene=rescue --preview=locked --shot=res://docs/screenshots/trainer_cages.png
godot --headless --path . -- --scene=tidewater-arrival --verify=1
godot --path . -- --scene=tidewater-arrival --preview=talk --shot=res://build/shots/tidewater_nell.png
godot --path . -- --scene=tidewater-arrival --preview=house --shot=res://build/shots/tidewater_rafe.png
godot --path . -- --scene=tidewater-arrival --preview=odile --shot=res://build/shots/bellerive_odile.png
godot --path . -- --scene=saveui --touch --save_dir=res://build/save_ui_saves/ --shot=res://build/shots/save_ui.png
godot --path . -- --scene=saveui --touch --slot=9 --save_dir=res://build/save_ui_saves/ --shot=res://build/shots/save_ui_last.png
godot --path . --resolution 2400x1080 -- --scene=arena-ladder --touch --rank=10 --verify=1 --shot=res://build/shots/arena_ladder.png
```

Screenshots from a test scene (`--shot=path.png`) come out small:

- `--crop=x0,y0,x1,y1` keeps just part of the screen (fractions, or pixels if any is over 1).
- `--shot_w` caps the width (default 960; 0 keeps full size).
- A `.jpg` path saves a JPEG instead, as for the pictures in `manual/images/`.

**Checking a screenshot without looking at it:** `bash tools/img.sh` measures it.

| Command | What it reports |
|---|---|
| `diff a.png b.png` | How much changed, and where. |
| `bbox x.png` | The box round whatever isn't background, or `--like=#rrggbb`. |
| `color x.png 0.5 0.4` | The colour at a point. |
| `crop x.png out.png` | A crop. |

Each takes `--region` and `--tol`. For a question only eyes can answer ("is any door blocked by furniture?"), `python tools/look.py x.png "question"` asks a local vision model (Qwen3-VL in Bionic or LM Studio; `LOOK_URL` and `LOOK_MODEL` pick the server and model) and prints its short answer.
