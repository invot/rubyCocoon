# Performance audit — November 1, 2026

The main stalls were synchronous map construction, repeated visibility/construction work while walking, first-use
battle artwork/audio generation, and rebuilding the character creator's styles on every change. The old start menu
also waited for a 4.2-second entrance and rendered a 3D scene behind its menus.

## Changes

- Start directly on New Game / Continue / Load Game. Disable the boot image and the unused world viewport while
  browsing the start menu, saves, or character creator. Background script requests finish without a blocking get.
- Divide map loading into terrain chunks, scenery rows, house plans and NPC construction. Checkpoints yield after a
  CPU work budget (see [Scene transitions](#scene-transitions--november-8-2026) for the current one) and the arrival
  view is prepared behind the fade.
- Retain at most eight hidden buildings on each map, disable their processing, and reuse visibility when the camera
  stops. Walking back reuses the same nodes rather than constructing them again. Preserve footprint-based visibility
  and arrival fades on every renderer.
- Replace most street-prop flood fills with a local connectivity proof, retaining the original full-map check for
  possible chokepoints. Bake house bounds, door positions, steps and porch measurements instead of analyzing unused
  candidate models during loading. The sampled maps' collision grids match the pre-change baseline exactly.
- Cache beast animation measurements by recipe, including merged beasts and ghosts, with independent per-instance
  animation state. Limit the recipe cache to 96 entries.
- Reuse creator swatch styles and update only changed states. Keep its preview rig for name/color changes. Use 2x
  MSAA for previews, matching the main view, and remove the background 3D scene from creator rendering.
- Bake the unchanged ring graphics and three encounter sweeps. Warm footstep/encounter sounds during loading.
  Bound the music cache to three recent tracks; active players retain their streams during crossfades.
- Match battle shadow splits/range to the world's two splits and 30-unit distance. Avoid unsupported SSAO calls on
  Mobile. Remove duplicate vertices from Classic rounded shapes to stop repeated triangulation errors.

The world still renders at the window's full resolution. No movement speeds, encounter rules, progression gates,
save formats, world textures or source-pack assets were changed by this performance work.

## Measurements

These are local CPU measurements from separate fresh Godot 4.7 processes on Windows, using an AMD Ryzen 7 9700X.
The windowed renderer checks used an AMD Radeon RX 9060 XT. These results are not measurements from a phone.

Median time per operation, in milliseconds:

| Operation | Before | After |
|---|---:|---:|
| Creator: name | 6.43 | 0.19 |
| Creator: top color | 6.63 | 0.45 |
| Creator: outfit | 6.55 | 0.44 |
| Creator: hairdo | 6.58 | 0.31 |
| Creator: body | 6.37 | 0.81 |
| Repeated dino model | 0.43 | 0.09 |
| Repeated owl model | 0.66 | 0.08 |
| Repeated beetle model | 1.45 | 0.09 |

The first creator opening stayed approximately 25–27 ms; this optimization primarily improves subsequent choices.
Cold beast construction still performs its first geometry analysis. The first battle script plus ring preparation
fell from approximately 594 ms to 276 ms. In the latter result, script loading/compilation accounts for 272 ms and
the ring's preparation for 3.8 ms. The baseline's combined counter did not separate those two costs.

| Map | Before: synchronous load call | After: total load | After: largest observed loading frame gap |
|---|---:|---:|---:|
| Cocoon Cove | 894 ms | 756 ms | 38 ms |
| Bellerive | 618 ms | 503 ms | 32 ms |
| Cogsworth | 373 ms | 281 ms | 24 ms |
| Coastal Path | 205 ms | 206 ms | 22 ms |

Yielding favors responsiveness over the shortest wall time. A checkpoint is a soft budget: a single model, asset
read or shader compilation can take longer. The frame-gap measurements above are headless CPU checks, not GPU or
physical-device frame rates. The normal windowed performance preview is VSync/frame-cap limited on this PC.

Temporary baseline, final JSON and logs are in `build/performance/`. Reproduce the audit with:

```text
godot --headless --path . -- --scene=stalls --save_dir=res://build/perf_saves/ --report=res://build/perf.json
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=perf --touch --save_dir=res://build/perf_saves/
bash tools/run_tests.sh
```

Use a fresh process for comparable cold/repeated results. An optional `--baseline=res://build/performance/baseline.json`
compares the audit's collision-grid hashes with an earlier report.

## Scene transitions — November 8, 2026

Transitions no longer show a loading message, and the wait behind the fade is shorter:

- While the screen is black nothing needs to stay smooth, so construction works for 50 ms between frames instead of
  6 ms (12 ms on the web, where music is mixed on the main thread). The 3D view is disabled during construction.
- The finished map gets its first draw while still black, and one further frame absorbs that draw's long delta, so a
  first-draw hitch can't jump the fade-in.
- Flat tiles at height 0 skip the neighbour search in `_vertex_y` (it always answers their own level), and ground
  meshes are built from packed arrays rather than `SurfaceTool`. All 23 outdoor maps, 883 meshes and 3.7 million
  vertices were compared against the old generator: positions, normals, colors, formats and bounds are identical.
- The ground meshes of the last three outdoor maps are kept, keyed by everything their shape depends on. A map whose
  ground has changed is generated afresh.
- Arrival buildings are built within the same work budget instead of one per frame, and a room's music and ambience
  reuse its loaded map instead of parsing its town twice more.

Milliseconds the screen stayed fully black, second walk of the route, same assets, Ryzen 7 9700X / RX 9060 XT:

| Transition | Forward+ 1920x1080: before | after | Mobile 2400x1080 touch: before | after |
|---|---:|---:|---:|---:|
| Into Cocoon Cove, ground not remembered | 795 | 335 | 834 | 325 |
| Back out of a house to Cocoon Cove | 790 | 175 | 799 | 196 |
| Into a house | 51 | 3 | 68 | 55 |
| Coastal Path | 402 | 158 | 403 | 68 |
| Into Bellerive, ground not remembered | 901 | 453 | 949 | 413 |
| Back out of a center to Bellerive | 898 | 248 | 981 | 343 |
| Cogsworth | 645 | 248 | 725 | 325 |

The fades add 550 ms around each of these, unchanged. A room's whole transition grew by about 30–50 ms: the two frames
that hide its first draw. On the Compatibility renderer (Windows OpenGL here) outdoor maps still hold black for 2–5 s
before and after this change, spent in the first draw; the web build was not profiled and its 12 ms budget is untested.
Phones were not profiled. Reproduce with `--scene=transitions` in a window, and see `tools/debug/transitions.gd`.

## Verification and limits

- All 57 regression checks passed in the final full suite, including quick checks, story flow, lessons, wild grace,
  battle commands, keyboard/gamepad/touch walking, building visibility/cache reuse, save/load, and all temples.
- Both map checkers passed. Generated house metadata matches fresh source measurements; baked ring images and
  encounter audio match the generators' data exactly.
- Windowed title/creator interaction checks passed at 1920x1080, 2400x1080 with touch, and 1280x720 with touch.
  Pixel and Classic, and Ruby, Sapphire, Emerald and Hematite, were captured and inspected. The live touch B button,
  New Game and color controls were also exercised through the actual Windows game window.
- Battle targeting was exercised and captured with Mobile and Compatibility renderers. Godot imported the new
  resources. Temporary captures are under `build/shots/performance/`; the README title image was deliberately updated.
- Player saves were not used. Save-related tests used isolated `res://build/.../` directories.
- Android/iPhone hardware and a browser export were not profiled. Driver shader compilation and individual cold
  construction operations can still cause shorter hitches. Some Godot ObjectDB/resources-in-use warnings remain at
  test shutdown; such warnings also appeared in the baseline. Android export tooling was not configured on this host.

After changing imported houses, run `tools/bake_house_measurements.gd` and its `-- --verify` mode. After changing
ring/sweep generators, run `tools/bake_battle_art.gd` and its `-- --verify` mode. These bake geometry metadata, UI
glyphs and synthesized audio; no new world texture was introduced or smoothed.

## Ground on disk, prebuilt buildings, lighter scenery and textured surfaces — November 12, 2026

The user reported slow scene loads, a near-freeze walking up to a building, and untextured, unappealing 3D. Changes:

- **Ground on disk** (`scripts/world/ground_store.gd`): every outdoor map's ground meshes are baked into
  `assets/ground/` by `--scene=bake-ground` (32 shapes: each map fresh and with its story gates, obstacles and floods
  changed; about 32 MB) and read back instead of generated. Other ground is generated once and kept in
  `user://ground/` (24 maps at most). The `ground` test checks the shipped set against the terrain code.
- **No building is built during play**: `prepare_arrival_view` builds every building behind the fade and keeps it
  (hidden while its base is off-screen); `HIDDEN_BUILDING_CACHE` is 64.
- **Lighter scenery**: `tools/import_stylized_nature.gd` simplifies bushes and shrubs to about 700 triangles and trees
  to 1,400 (`bush_2` and `shrub_3` 4,341 -> 1,083, `tree_oak` 3,780 -> 1,890) before their LODs are generated.
- **Every object textured** (`scripts/gfx/surface_finish.gd`): 14,500 plain-colour surfaces now carry soft finishes
  painted by `tools/build_soft_textures.py`. The pass runs synchronously before a map's first draw: on Compatibility a
  material drawn before it is finished compiles a shader that is thrown away again (3.5 s on every Beast Center visit
  until this was fixed). The `textures` test fails on any untextured object.

Map construction, CPU only (`--scene=build-profile`, Forward+ window, all buildings built):

| Map | Ground before | after | Whole map before | after |
|---|---:|---:|---:|---:|
| Cocoon Cove | 664 ms | 170 ms | 1,837 ms | 1,532 ms |
| Bellerive | 560 ms | 78 ms | 1,333 ms | 762 ms |
| Cogsworth | 287 ms | 40 ms | 1,254 ms | 870 ms |
| Dustwell | 239 ms | 36 ms | 559 ms | 304 ms |

Milliseconds of black screen (`--scene=transitions --passes=2 --battles=1`), Mobile renderer at 1920x1080 on this
desktop (Ryzen 7 9700X / RX 9060 XT) — a desktop measurement, not a phone's:

| Transition | before | after |
|---|---:|---:|
| Into Cocoon Cove, first | 3,292 | 2,488 |
| Into Bellerive, first | 1,514 | 723 |
| Coastal Path, first | 665 | 300 |
| Into Cocoon Cove, again | 749 | 167 |
| Into Bellerive, again | 1,349 | 406 |
| First battle, largest frame | 1,398 | 150 |

Walking past houses (`--scene=field-perf`, Mobile renderer, same desktop): no frame over 20 ms; the earlier report
had 225 ms (Cocoon Cove) and 608 ms (Bellerive) spikes. GPU time per frame is 1.4-2.1 ms with or without the finishes
(`--finish=0` measures without them); the triangles drawn on Coastal Path fell with the lighter bushes.

On Compatibility (the web renderer) return visits are as fast as before or faster, but a first visit still holds black
for seconds while the driver compiles shaders on first draw (Cocoon Cove 20.3 -> 16.3 s, its Beast Center 9.8 -> 4.3 s).
Phones and a browser export were not measured.

### Lighting pass and the web renderer's walking stalls — November 12, 2026

- The outdoor light now fills shade from the sky (`OutdoorLight.ambient`, a 64-pixel radiance map built once) and is
  graded for more contrast (+7%) and richer colour (+3-10%) at the same brightness (within 2%), measured over
  screenshots of Cocoon Cove and Bellerive on all three renderers. GPU time while walking on the Mobile renderer rose
  from about 1.9 to 2.2 ms per frame on this desktop. Battles keep their own stage lighting unchanged.
- On Compatibility, buildings no longer fade in (`world.gd NO_ARRIVAL_FADE`): each see-through copy compiled a shader
  on first sight. Behind the black screen the map's meshes and materials are each drawn once as a speck in front of the
  camera (`_warm_shaders`), so nothing compiles mid-walk: the largest render time while walking past Bellerive's
  houses fell from about 960 ms to 1 ms (`--scene=field-perf`, `--fade=1` forces the fade back for comparison).
  Medians in these runs were inflated by two busy Godot editors on the same machine.
