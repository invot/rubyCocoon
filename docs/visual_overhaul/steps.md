> **Folded into [runbook.md](runbook.md)**, the numbered chain to follow. This file is background; where they differ, the runbook wins on order and scope.

## Typography direction — user decision, 12 November 2026

This decision supersedes earlier instructions to use League Spartan for all text.
- Headings and names: League Spartan Semibold (600).
- Body text, menu actions, values, dialogue and damage numbers: Fuzzy Bubbles.
- Lettering physically painted, engraved or displayed on objects in the 3D world: Noto Sans Old North Arabian, using a deterministic mapping from English letters (and explicitly defined ligatures where needed) to its glyphs. Do not render English lettering on world objects. This is a fictional substitution alphabet, not an Arabic translation. Preserve the underlying readable English for dialogue, interaction descriptions and accessibility.
- UI and spoken dialogue remain readable English; they are not world-object lettering. Preserve the established intro/title logo exception unless the user changes it.
- Sources: [Fuzzy Bubbles](https://fonts.google.com/specimen/Fuzzy+Bubbles), [Noto Sans Old North Arabian](https://fonts.google.com/noto/specimen/Noto+Sans+Old+North+Arabian).
- Implementation checkpoint: Fuzzy Bubbles body/dialogue and the shared world-lettering font/map are wired in; see [font-update.md](font-update.md). Generic signpost artwork and dedicated world-lettering visual review remain. Verify glyph coverage, wrapping, touch layouts and actual before/after game screenshots. Do not shrink text to accommodate the new font.

Codex continues code, tests and nonvisual work. Stop at the next task requiring Claude's visual authorship and prepare its concrete handoff; do not silently perform that artwork.


# Visual overhaul: steps

One step is one session of about 1–2 hours. Each step has a fixed goal, the files it touches, the evidence it must produce, and a clear stopping point. The user approves each visual step from before/after screenshots before the next visual step starts. Performance and tooling steps need only their numbers and tests.

Read [README.md](README.md) for the session protocol and the current step, [audit.md](audit.md) for the decisions, and only the sections of [standards.md](standards.md) that a step names.

**Order:** P (performance foundation) → M1–M3 (eight-way movement option) → L (ledger tooling), with M4 (diagonal terrain data) before S5, and X1–X12 (exploration systems, [exploration.md](exploration.md)) after Phase S and before B → S (style targets and reference scenes) → B (biome rollout) → C (cast: people and beasts) → E (every scene) → U (interface softening) → F (final acceptance). C may start after S is approved and run alongside B, one session at a time per set of files.

**Size rule:** if a step can't reach its "Done when" inside the session, stop at a clean point and record what remains. Then split the step in this file (e.g. S7 → S7a, S7b) instead of pushing on.

**Every step ends with:** `bash tools/run_tests.sh quick` and the step's named tests, the log read for script errors, evidence saved under `build/shots/vo/<step>/` and `build/perf/vo/<step>/`, the ledger regenerated (from L1 on), `progress.md` updated, and a stop.

---

## Phase P — Performance foundation

The goal is to know where the time goes on every target, then remove the biggest structural costs before any new art lands. Targets: **30 fps on Snapdragon 660 class phones, 60 fps on Snapdragon 865 class phones and PC**, and short first visits on the web.

| Step | Goal | Do | Done when |
|---|---|---|---|
| **P1** Reproducible perf runs | One command per renderer captures comparable numbers | Extend the existing `--scene=field-perf`, `transitions` and `perf` modes into one `--scene=vo-perf` route. It walks a fixed path on Coastal Path, Cocoon Cove, a house interior, Bellerive and a warmed coast battle. It writes JSON: frame-time median/p95/p99, worst spikes, draw calls, objects, primitives, material/surface counts, video memory, black-screen ms per transition. Run each command example in standards.md §28 once and correct any that are wrong | Forward+, Mobile and Compatibility desktop runs saved as `build/perf/vo/baseline-desktop/*.json`, with screenshots from the same route |
| **P2** Phone baseline | Real numbers from the user's Android phone | Export the debug Android build (the existing `com.rubycocoon.x` setup). Run `vo-perf` on the device. Pull the JSON with `adb`, and screenshots with `adb exec-out screencap -p` (`-d` on the razr). Record the device model, temperature if available, and a 15-minute sustained run | `build/perf/vo/baseline-phone/` holds the JSON and a short summary in `ledger/perf.md`. If no phone is attached, the user is told and the step waits |
| **P3** Web baseline | First-visit and steady numbers in a real browser | Make the single-threaded web export. Serve it locally and open it in the built-in browser. Record black-screen times for the first and return visits on the same route, plus the steady fps | Numbers in `ledger/perf.md`. Shader-compile stalls are listed per map |
| **P4** Cost diagnosis (analysis only) | Rank the causes | From P1–P3, list the top offenders per scene: unique materials (the soft-finish pass's ~14,500 surfaces), draw calls by node type, shadow casters, alpha overdraw (grass, foliage cards), lights, and per-frame scripts (use Godot's profiler output, or timing from `--scene=build-profile`). Have the local model summarise the long profiler dumps | `ledger/perf.md` has a ranked table with an estimated saving per fix. P5–P10 are re-ordered or split to match it |
| **P5** Material sharing | Far fewer unique materials | `surface_finish.gd` (and the builders it touches) shares one material per (finish texture, tint) key, or moves tint into vertex colour or instance uniforms, so identical finishes reuse a single material. Keep the look pixel-identical: compare before/after shots with `tools/img.sh diff` | The material count on the route falls by the largest achievable factor, with no visual diff beyond noise. `textures` test passes |
| **P6** Batched scenery and culling | Reduce submitted geometry without visibility regressions | Preserve chunked MultiMeshes; audit AABBs, trial runtime occluders and category-specific distance ranges, and trial Static Mesh Merger on one complex static asset in separate checkpoints. Follow [runbook 006](runbook.md#006--p6-batched-scenery); preserve LOD, fading, terrain dithering, battle sightlines, edge seals and collision. Account for Mobile/Compatibility fade limits and occlusion CPU overhead | Per-experiment on/off CPU/GPU/frame evidence on target renderers, or a documented no-op. No edge popping or invisible occluders after fading. Walking, fading and `field-perf` still have no spikes over 20 ms on desktop |
| **P7** Alpha and overdraw | Cheap foliage and grass | Make alpha-blended foliage and grass alpha-scissor or opaque. Cap card layers. Measure overdraw on Mobile. (S9 replaces the grass design later; this step only fixes cost) | Fewer transparent draws, and the GPU time on the phone route improves |
| **P8** Shadows and lights | A per-preset budget | Restrict shadow casters (big scenery and actors only; grass, flowers and small props never cast). Set shadow distance and splits per preset (Min/Mid/Max). Contact shadows carry the small things | Shadow-pass cost recorded before/after. Characters stay grounded in shots |
| **P9** Shader warm-up | No multi-second first-visit stalls | Check Godot 4.7's export shader baking/pipeline cache options for each renderer. Extend `_warm_shaders` to warm the reduced material set (P5) once at boot behind the title or the first fade, not per map. Remove one-off shader variants found in P4 | Web/Compatibility first-visit black screen is at most about 1.5 s per map on desktop. Phone first visits are recorded |
| **P10** Smooth low-resolution output | Rendering at 540p/720p looks clean, not pixelated | Replace nearest enlargement (`prefs.gd:108-110`) with a smooth resolve: bilinear on Compatibility, and FSR 1 or bilinear plus sharpening on Mobile/Forward+ (verify per renderer). Set presets to the README's 540p/Min and 720p/Mid starting points. Update the README's description of the pixel effect | Side-by-side 540p crops show no stair-stepped texels. The phone's fps at 540p is recorded. **The user approves the look** |
| **P11** Measured budgets | Budgets for the art phases | From the improved numbers, set per-scene budgets: draw calls, materials, triangles, texture MB, transparent draws and frame ms per renderer and class. Add a `vo-budget` test to `tools/run_tests.sh` that runs the route headless (CPU-side counts) and fails over budget | `ledger/budgets.md` exists, and the test passes on today's scenes |

## Phase M — Diagonal terrain and optional eight-way movement

The user's decisions, 12 November 2026:

- **Diagonal terrain.** Like cliffs, building walls, paths, water edges and all other terrain boundaries may run diagonally.
- **Whole tiles.** A tile is walkable or blocked as a whole. A diagonal edge is drawn across tiles, but it is placed so that walkable tiles look walkable and blocked tiles look blocked. Diagonal *cliff* tiles stay unenterable (existing rule).
- **Four-way still works.** Every diagonal path must remain navigable with four-way movement: underneath, it is a staircase of walkable tiles.
- **Settings toggle.** Eight-way movement is a Settings option on **every platform**, not only mobile. It is **off by default**.
- **No corner cutting.** A diagonal step needs its destination and **both** side tiles free. When a side is blocked, the move is refused, or it slides along the open side if exactly one cardinal direction of the input is free.
- **Tile centres.** The hero, NPCs and beasts always stop at tile centres. A started step, diagonal or cardinal, always finishes at the next tile's centre.

| Step | Goal | Do | Done when |
|---|---|---|---|
| **M1** Movement core | Eight-way stepping with no change to four-way | In the shared movement code (find it under `scripts/core/` or `scripts/world/`; don't duplicate it in input widgets), add diagonal steps that end on tile centres. Check the destination, both side tiles, elevation, ramps and diagonal-cliff tiles. Apply the same stepping to NPC and beast walkers, so nothing ever rests between centres. Diagonal steps last about √2 times as long, so speed along the ground is unchanged. Four-way behaviour must stay byte-for-byte the same when the option is off | `quick`, the walking tests (keyboard/gamepad/touch) and `wildgrace` pass with the option off. A new `diagonal` test covers blocked corners, ramps, cliff edges, encounter grass and doors |
| **M2** Setting and input | A player-facing toggle | Add a `Prefs` setting ("Diagonal movement", off by default, saved with sensible defaults for older settings files) to the Settings page, using the existing `UIKit` rows. Keyboard: two direction keys pressed together. Gamepad: the stick and the d-pad diagonals. Touch: the d-pad accepts diagonal zones **only while the option is on**; otherwise the existing one-direction-at-a-time behaviour is unchanged, including boundary touches and the B and flute chords | The setting is captured at desktop 1920×1080 and touch 2400×1080. Real taps and keys exercised in both modes, with screenshots |
| **M3** Rules and protections | Nothing breaks | Lessons, story gates, puzzles (such as pushing or sliding), doors, stairs, signs, fishing spots and encounter steps all work with eight-way on. Interactions face the right way after a diagonal step. Update README Controls and the AGENTS.md movement rules to describe the option | The full test suite and both map checkers pass, with eight-way on and off |
| **M4** Diagonal terrain data | Maps can describe diagonal edges | Extend map data and `cliff_corners.gd`-style tooling so path, water and building-wall boundaries can be marked diagonal per tile corner, keeping each tile's walkable or blocked state whole. `check_maps.gd` and `town_check.py` learn the new marks, and verify that every diagonal path is a connected four-way staircase | The checkers pass on the existing maps. A test map with diagonal path, water and wall runs passes |

M1–M3 run straight after Phase P. M4 runs before S5. The visual side of diagonal edges is built inside S5 (cliffs), S6 (paths, banks, shoreline), S12–S13 (building walls and footprints) and each biome's B-2/B-4 steps.

## Phase L — Ledger tooling (full ledger, generated)

| Step | Goal | Do | Done when |
|---|---|---|---|
| **L1** Asset ledger generator | Know every rendered asset | Add `tools/visual_ledger.gd` (headless). It builds each map, room, battle setting, the title and the creator. It walks the rendered nodes and records the mesh or builder ID, resource path or procedural recipe, embedded materials and textures with import settings, triangle and surface counts, the scenes using each, and SHA-256 hashes of the source and output. Write `ledger/assets.csv`, sorted and stable. Mark unshipped source packs `not shipped` with the scan as evidence | Runs in under about 5 minutes. A second run with no changes produces a byte-identical file |
| **L2** Scene/state ledger | Coverage list | Generate `ledger/scenes.csv` from data: every outdoor map, room template, battle setting, film and the story states that change geometry. Each row gets three standard cameras (gameplay, hero close-up, edge/door) defined in the capture harness | `--scene=vo-shots --id=<scene>` captures the three cameras for any row |
| **L3** Approvals and invalidation | Approval survives only while its inputs are unchanged | `ledger/approvals.csv`: ID, step, standard version, input hashes, renderer/profile, evidence path, date, "approved by user". Add a `vo-ledger` test that fails when an approved entry's hashes changed (it reverts to `ready for review`) or when an active asset is missing from the ledger | The test passes on a clean tree and fails on a deliberately touched asset (revert that touch afterwards) |
| **L4** Family grouping and first triage | A worklist | Group ledger rows into families (terrain-coast, tree-broadleaf, bush, house-cove-kit, ...). Have the local model propose families from paths, then fix them by hand. Set every family's status to `unreviewed` | `ledger/families.csv` exists, with counts per status reported |

## Phase S — Style targets and reference scenes

Each S step ends with before/after shots at the three standard cameras plus a crop matched against the closest AC reference image, and **user approval**. All work stays within `ledger/budgets.md`.

| Step | Goal | Do | Done when |
|---|---|---|---|
| **S1** Palette and light, grassland | A soft but contrasty base | Tune `outdoor_light.gd` (key, sky fill, coloured shade, tone map, glow off for ordinary surfaces) and the grassland ground colours. Aim for gentle mid-greens, warm paths and clear light/shade value steps. Saturation is held back from the lawn for actors and flowers. Use the `--light_*` flags to try values without editing, then commit to one | Coastal Path at gameplay camera, with the user's approval of the palette and light |
| **S2** Material board | Calibrate materials once | `--scene=material-board`: spheres, planks and blocks showing painted timber, bark, plaster, stone, cloth, foliage, ceramic, metal, water and skin/fur beside the hero and a beast, under the outdoor, warm-indoor, night and battle profiles. Set roughness bands per standards.md §8 | Approved board shots. Material presets live in a shared script (`scripts/gfx/materials_vo.gd` or by extending `surface_finish.gd`) |
| **S2a** Baked interior lighting prototype | Assess low-cost bounce lighting | Follow [runbook 022a](runbook.md#022a--s2a-static-interior-lightmapgi-feasibility-prototype): offline LightmapGI bake for one runtime-built room, UV2/resource mapping, dynamic-object coherence and all-renderer verification. VoxelGI is runtime GI restricted to Forward+, not the shared mobile/web baking solution | Matched screenshots, memory/loading/frame measurements and a go/no-go decision; no automatic production rollout |
| **S3** Scale sheet | One reference for size | `--scene=scale-sheet`: hero, second body type, familiar beast, door, chair, bench, counter, lamp, fence, window and a one-storey house | Approved shot, kept as the reference for every later step |
| **S4** Ground motif and painted ground, coast/grassland | Replace the flat neon lawn | Paint (procedurally, in `build_soft_textures.py` or a new tool) a soft grass base with broad patches and our own sparse motif (for example tiny leaf or clover marks, never AC's triangles), plus dirt path and sand. Feed them to `terrain.gdshader`. Run through the smoothing pipeline. Keep blends soft and wandering | Coastal Path ground approved at the gameplay camera and in close crops |
| **S5** Turf lip and cliff faces, grassland | AC-quality edges | In `terrain_mesh.gd` and the shader: a thick rounded turf lip overhanging the face, fluted vertical rock slabs with broad strata, a soft shade band under the lip, and diagonal corners preserved. Grassland/coast `CLIFF_LOOKS` only. Elevation-only, no placed meshes. Re-bake the ground (`--scene=bake-ground`) and run the `ground` test | Approved crops of a straight run, a diagonal corner, a ramp end and a cliff at water. `check_maps.gd` and `town_check.py` pass |
| **S6** Path edges, banks and shoreline | Soft transitions, diagonals included | Paths, banks and water edges follow the M4 diagonal marks as smooth diagonal runs over the four-way staircase underneath. Paths with a soft shoulder and irregular edge. River banks with a lip. Sea shore with a shallow gradient and a white foam line following the coast (water shader). Waterfall rules still hold | Approved crops of a path corner, a riverbank and a beach edge with the hero. `check_water` passes |
| **S7** Tree grammar (Blender) | One broadleaf tree that sets the standard | Blender script `tools/blender/tree_broadleaf.py`: a tapered trunk with root flare and a crown of rounded leaf-cluster masses, at about 1–3k tris, with 2–3 variants and LODs. Re-texture with the foliage shader. First try reworking the existing `tree_oak` source, and rebuild only if it can't reach the silhouette. Import through the nature importer and swap it in on Coastal Path only | Approved tree beside the hero. Its budget is met. Cube trees are gone from Coastal Path |
| **S8** Bushes, hedges and flowers | Same leaf grammar at small scale | 3–4 bush shapes and a hedge, built from the S7 grammar. Flowers become clear petal masses. Drop the orange-dot spam in favour of a few curated fruit or flower variants | Approved mixed nature gallery (all species together) plus Coastal Path |
| **S9** Grass and encounter grass | No needle fields | Short soft clumps for ordinary cover, used sparingly. Tall encounter grass is redesigned as broad-bladed, readable patches with the same footprint | Approved. Encounter tiles unchanged (the `wildgrace` and map tests pass) |
| **S10** Rocks | One geology family | Rework the rock meshes in Blender: designed broad planes, softened transitions, partly buried bases, coast and grassland colours | Approved gallery |
| **S11** Coastal Path composition → **Reference 1** | The first finished scene | Density pass: grouped planting, quiet gaps, signs and fences in place, props in purposeful groups. Compare with the AC references side by side | **User approves Reference 1.** Budgets met on the phone (re-run P2 for this map) |
| **S12** Cove materials | Town building finish | Where the map marks it, building walls may run diagonally: angled corners and footprints sealed in the builder, with doors still on a straight wall section facing their door tile. Stucco, roof, timber and trim materials for Cove's kit and the pack houses, at one feature scale. Fix plastic roofs and gritty cobbles | Approved street crops. `exteriors` and `cove-exteriors` pass |
| **S13** Cove doors, windows, trim and signs | Construction quality | Frames, sills, door leaves and sign plates at consistent bevels. Sign art at a consistent density | Approved door/window crops beside the hero |
| **S14** Cove paving and props | Streets that sit together | Paving with a soft motif, and a lamp, bench, crate and planter family reworked to share the edge and material rules. Then placement | Approved |
| **S15** Cove composition → **Reference 2** | | Like S11 | **User approves Reference 2**, plus a phone check |
| **S16–S18** Home interior → **Reference 3** | Floors, walls and rugs (S16); a furniture family pass on beds, sofas, tables and shelves (S17); composition per `docs/interior_staging.md` (S18) | | **User approves Reference 3** |
| **S19–S20** Dark location → **Reference 4** | A night/dark light profile and Moor palette (S19); dead trees, graves and Gothic trim from the S7/S10 grammars, with ghosts readable (S20) | | **User approves Reference 4** |
| **S21–S22** Dry/industrial → **Reference 5** | Desert/mesa per-biome cliff shape, sand motif, cactus and palm rework (S21); Cogsworth metal, brick and machinery materials (S22) | | **User approves Reference 5** |
| **S23** Battle → **Reference 6** | Battles match the world | Re-bake the coast backdrop from the approved assets. Battle lighting matched to S1/S2. Check the rings and pads. `check_battle_visuals` and `battle-poses` pass | **User approves Reference 6** |
| **S24** Freeze the standard | Lock it | Write the exact values (light, palette per biome so far, material presets, motif scales, lip sizes, tree/bush/rock budgets) into `standard-values.md`. Bump the standard version in the ledger | Done. Every later step cites it |

## Phase C — Cast (people and beasts; remodel, same proportions)

Pilot first, then families. Every C step keeps heights and head ratios (S3 scale sheet), rig and animation entry points (`voxel_person.gd`, `beast_model.gd`), palettes (`beast_looks.gd`) and outlines.

| Step | Goal |
|---|---|
| **C1** Hero pilot: in Blender, remodel the base body and head at the current proportions (smooth silhouette, clean joints, about 4–10k tris), fit to the existing rig, and confirm the animations play. **User approves** |
| **C2** Faces: eyes, brows and mouth shapes readable at gameplay distance, plus expressions |
| **C3** Hair family: remodel every hairdo as designed locks and masses (split C3a/C3b by count) |
| **C4** Clothing family: thickness, folds, materials from S2 (split by garment group) |
| **C5** Creator sweep: every option combination class, clipping matrix, creator UI shots at desktop and touch |
| **C6** NPC families: townsfolk, beastmasters (robes), trainers, the Jackals, etc. One family per step |
| **C7** Beast pilot: one family through all evolution stages, plus its ghost, and one merge using it, via `beast_model.gd`. `--scene=newbeasts --anim=cycle` and `battle-poses`. **User approves**, which decides the method for the rest |
| **C8…** Beasts by body kind (biped, quadruped, flyer, serpent, blob), one or two families per step, then legendaries, robots and summons. Merge connectors get their own step with a generated risk matrix |
| **C-last** Re-render portraits, icons and the save placeholders from the approved models |

## Phase B — Biome rollout

Each biome repeats the S pattern at a smaller size, reusing the frozen grammars. The order follows the journey. The biome list comes from `WorldDB.BIOMES` at the time; 14 biomes exist today.

Template per biome `<b>`. Exploration comes first, so the road is laid out once and decorated once; see [exploration.md](exploration.md):

0. **B-`<b>`-X1…X3** Road blockout at 3–4× (the Coastal Path excepted), then its set pieces, caves and secrets one per step, then hints and the README journey. The user approves the layout.
1. **B-`<b>`-1** Palette, ground motif and light variant (the S1/S4 pattern).
2. **B-`<b>`-2** Cliff shape for that biome (`CLIFF_LOOKS`), banks and shoreline (the S5/S6 pattern).
3. **B-`<b>`-3** Vegetation and rock set: rework the region's species in the shared grammar.
4. **B-`<b>`-4** Building family materials and construction (regional identity kept).
5. **B-`<b>`-5** Composition of its main map, plus a battle backdrop re-bake, with a phone check. **User approves.**

Coast/grassland, Quarter (Cocoon Cove area) and parts of Desert, Steampunk and Moor are covered by S. Remaining biomes, in journey order: Quarter/Bellerive, River, Island, Reef, Western, Desert (rest), Mesa, Mountain, Steampunk (Cogsworth rebuilt as a dense, neon cyberpunk city that reads as a city; Gearhart's tower and steam gate stay), Hot spring, Jungle, Volcano, Moor (rest). Steps are skipped where a biome has no buildings.

## Phase E — Every scene

Using `ledger/scenes.csv`, take **2–3 maps or 4–6 rooms per step**. Capture the three cameras, fix composition, joins, placement and stale derivatives (murals, ground bakes), and run both map checkers and `exteriors`. Each batch gets user approval from a contact sheet. Films get their own steps (one film per step), as do the title and app icon (key art re-render).

## Phase U — Interface (later)

On 12 November 2026 the user agreed to soften the UI **later**: after Phase E and before F, never earlier. Keep the structure, layout, inputs and the AGENTS.md interface rules (dark blurred windows, white borders, faint gem tint, League Spartan headings and Fuzzy Bubbles body/dialogue). Soften only the frame weight, ornament and finish. Steps: U1 shared frame/border weight in `frame_box.gd` and `UIKit`, across four gems × desktop/touch; U2 icon family consistency; U3 battle bar finish. Each step needs user approval.

## Phase F — Final acceptance

| Step | Goal |
|---|---|
| **F1** Full test suite, both map checkers, `vo-ledger` with zero unreviewed active entries, and `vo-budget` |
| **F2** Phone sustained run on the full route, plus the web export route. Compare with the P2/P3 baselines in `ledger/perf.md` |
| **F3** Side-by-side board: home, route, desert street, industrial battle, haunted area, portrait, title/interface. **User approves** |
| **F4** Refresh `docs/screenshots/` deliberately and update README Art/Performance. Write the completion report (checklist.md "Completion report") |
