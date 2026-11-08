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
