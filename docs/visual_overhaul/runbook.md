# Ruby Cocoon overhaul runbook

## Typography direction — user decision, 12 November 2026

This decision supersedes earlier instructions to use League Spartan for all text.
- Headings and names: League Spartan Semibold (600).
- Body text, menu actions, values, dialogue and damage numbers: Short Stack.
- Lettering physically painted, engraved or displayed on objects in the 3D world: Noto Sans Old North Arabian, using a deterministic mapping from English letters (and explicitly defined ligatures where needed) to its glyphs. Do not render English lettering on world objects. This is a fictional substitution alphabet, not an Arabic translation. Preserve the underlying readable English for dialogue, interaction descriptions and accessibility.
- UI and spoken dialogue remain readable English; they are not world-object lettering. Preserve the established intro/title logo exception unless the user changes it.
- Sources: [Short Stack](https://fonts.google.com/specimen/Short+Stack), [Noto Sans Old North Arabian](https://fonts.google.com/noto/specimen/Noto+Sans+Old+North+Arabian).
- Implementation checkpoint: Short Stack body/dialogue and the shared world-lettering font/map are now wired in; see [font-update.md](font-update.md). Generic signpost artwork and dedicated world-lettering visual review remain. Verify glyph coverage, wrapping, touch layouts and actual before/after game screenshots. Do not shrink text to accommodate the new font.

Codex continues code, tests and nonvisual work. Stop at the next task requiring Claude's visual authorship and prepare its concrete handoff; do not silently perform that artwork.


This is the single ordered chain of work for the visual overhaul, performance, diagonal movement and exploration. It combines [audit.md](audit.md) (decisions and diagnosis), [steps.md](steps.md) (the visual and performance steps) and [exploration.md](exploration.md) (the exploration pillar). **Where they differ, this runbook wins on order and scope.** The full visual standard stays in [standards.md](standards.md) and the enforcement list in [checklist.md](checklist.md); steps cite their sections instead of repeating them.

## How to prompt

Each step has a number and an ID. Start a fresh session and say:

> **Run runbook step 021.**

(or `Run runbook step S1`). Work one step at a time and always state the current step. The agent reads §1–§5 of this file and that step's section only. It finds the step with a search for `### 021`, not by reading the whole file.

Useful variations:

| You say | The agent does |
|---|---|
| `Run runbook step 021.` | Does the step to its "Done when" and stops for your approval if it needs one |
| `Approve step 021.` / `Redo step 021: <what's wrong>` | Records the approval, or runs the step again with your notes (it counts as a revision round, see §5) |
| `Continue runbook step 021.` | Picks up a step stopped at a clean point, using `progress.md` |
| `Split runbook step 021.` | Rewrites the step as 021a/021b when it's too big |
| `What's the next runbook step?` | Reads `progress.md` and answers |

Steps that affect the game's visuals stop with before/after screenshots. The next step waits until you approve. Offer **approve and continue**, **request changes**, or **approve and pause**; approval means continue unless you ask to pause. Tooling and measurement steps that do not affect game visuals finish on their measurements and tests and continue automatically. This review protocol follows the user's instructions of 12 November 2026, including their clarification that nonvisual steps need no approval.

---

## §1 Direction (decided 12 November 2026)

- **Look:** cozy, beautiful, clean and modern, with Animal Crossing: New Horizons as the reference for environmental cohesion:
  - rounded deliberate forms and soft tactile painted materials;
  - thick rounded turf lips and fluted cliff faces;
  - soft banks and shorelines with foam lines;
  - leaf-cluster foliage, grouped planting with quiet gaps, and soft light with coloured shade.

  Learn the principles; never copy its models, textures, triangle grass motif, characters or interface.
- **Colour:** between soft and punchy. Gentle, slightly warm colours with clear light/shade contrast. The strongest saturation goes to people, beasts, flowers, fruit and interactables. Never a neon lawn.
- **Ground:** our own subtle motif per biome (tiny leaf or clover-like marks on grass, ripples on sand, and so on).
- **World:** flat, with no curved horizon.
- **Cliffs:** built only from elevation changes, with per-biome shapes (`WorldDB.CLIFF_LOOKS`). Lip quality and edge softness are shared.
- **People and beasts:** remodelled to the new standard, keeping their current proportions, heights and identities. Ghosts stay black and purple with smoke; merges still visibly combine their parents.
- **Regions** keep their architecture. **Cogsworth becomes a dense neon cyberpunk city** that reads as a city; Gearhart's tower and steam gate stay. Dark places stay seriously dark in the same visual language.
- **Tools and assets:** Blender is installed and may be scripted headless. Rework existing assets first; bring in new packs only when rework fails. Original packs stay untouched.
- **Performance:** **30 fps on Snapdragon 660 class phones, 60 fps on Snapdragon 865 class and PC.** The performance foundation comes first. The game is slow today on phone, web, desktop and in loading.
- **Process:** the **full ledger** (generated by tools, never typed by hand) and **small steps of about 1–2 hours**. **You approve each visual step** from before/after screenshots.
- **Movement:** cliffs, building walls, paths, water and all terrain edges may run diagonally.
  - Tiles stay whole (walkable or blocked), and diagonal cliff tiles stay unenterable.
  - Every diagonal path stays walkable with four-way movement.
  - **Eight-way movement is a Settings option on every platform, off by default, with no corner cutting.**
  - The hero, NPCs and beasts always stop on tile centres.
- **Exploration:** the game has two pillars, exploration and battling.
  - Roads grow **3–4×** (the Coastal Path stays the tutorial). They become winding, with caves, secrets, hot springs, butterflies and goofy puzzles; **many puzzles are required**. Shortcuts unlock from the far end.
  - **No map edge may ever be visible.** Every map gets an edge band of filler scenery and a camera that eases to a stop.
- **Interface:** softened **later** (Phase U, after every scene is done): frame weight, ornament and finish only. Until then, AGENTS.md's interface rules are untouched.

## §2 What's wrong today (the targets)

From `docs/screenshots/coastal_path.jpg`, `cove.jpg`, `build/shots/adobe/e_plaza.png` and `docs/performance.md`:

- **Lawns:** flat neon green, with no value variation or motif. Paths differ only in hue.
- **Cliffs:** a thin brown band with a hard top line, no turf lip, and no shade under the lip.
- **Foliage:** three languages side by side: cube-ish canopies, smooth blob bushes, and spiky alpha grass blades that read as needles.
- **Planting and props:** orange-dotted bushes repeated into every gap. Props are dropped without composition: a lone crate on a lawn, a lamp mid-path.
- **Mixed pack identities:** half-timbered pack houses, flat plastic roofs, gritty cobbles and pixel signs of mixed density.
- **Low-poly facets** on palms and statues.
- **Light:** bright and even, with weak shadows and characters that seem to float.
- **Edges:** hard polygon path edges, and visible map edges near borders.
- **Performance:**
  - about 14,500 surfaces carry their own soft-finish material (draw calls and state changes);
  - first visits on Compatibility/web hold a black screen for 4–16 s while shaders compile;
  - nearest-filtered enlargement makes low-resolution renders pixelated (`prefs.gd:108-110`);
  - phones and the web build have never been measured.

## §3 Offloading to the local model (fast mode)

The model is `qwen3.6-27b` at `http://localhost:1235/v1`. It reads text and images. **Since 12 November 2026 it no longer reasons before answering:**

| Input | Measured time |
|---|---|
| Short text answer | about 3 s |
| One screenshot | about 15–17 s |
| An 8 KB diff | about 15 s |

So ask it in the foreground when the answer is needed next. Run only full test runs and inputs over about 50,000 characters in the background. Without reasoning it is **more agreeable**: in a check on 12 November it said Coastal Path has a "rounded grass lip" when it doesn't. So:

- **Ask neutral questions.** "Describe the cliff edge in this crop", never "Is there a rounded lip?". "List what differs between these two images", never "Is the new one better?".
- **One question per call.** Ask for a short list or yes/no with a reason. Keep inputs focused: a crop or one file, not everything.
- **Confirm before acting or reporting:** grep, `tools/img.sh` (`diff`, `bbox`, `color`), a 300-px crop you look at yourself, or a script for anything numeric.
- **Always read the `errors` field** from `server.py`. A scene that failed to build still gets a confident description.

Sandbox network access must be off for localhost (`dangerouslyDisableSandbox: true`). Check once per session:

```text
curl -s -m 5 http://localhost:1235/v1/models
curl -s -m 5 http://127.0.0.1:5000/bionic/health     # if no answer: python server.py (in the background)
```

If the model isn't listed, do the work yourself and mention that briefly. Don't retry.

### What to offload, by kind of task

| Task | Offload? | How |
|---|---|---|
| Running tests and reading failed logs | **Yes** | `POST /bionic/run {"tool":"tests","params":{...}}`: returns `run_tests.sh`'s summary plus the model's reading of each failed log. Then open only the lines it points to |
| Finding script errors in a log | Grep first (`grep -n "SCRIPT ERROR\|ERROR:\|Failed to load"`). Offload only to *explain* a long trace |  |
| First look at a screenshot | **Yes** | `python tools/look.py shot.png "Describe the ground, cliff edges and foliage in this image in 5 bullet points."` |
| Before/after comparison | **Yes, for change-finding** | Put the two crops side by side (`tools/img.sh` or PIL). Ask "List the visible differences between left and right." Never ask which is better |
| Comparison with an AC reference | **Yes, as notes only** | "List how the left image's cliff and grass differ from the right image's in shape, edge and colour." You judge the result |
| Contact-sheet triage (many shots) | **Yes** | Loop: `for f in build/shots/vo/E07/*.png; do python tools/look.py "$f" "Is any grey void, sky gap or flat map edge visible? Answer yes/no and where."; done`. Then check every "yes" yourself and spot-check a few "no"s |
| Summarising long files, logs or profiler dumps | **Yes, for prose.** For numbers, write a script | `python tools/look.py --ask "Which functions build foliage and where?" scripts/gfx/...`. Rank costs from JSON with a Python one-liner, not the model |
| Searching code by meaning | **Yes, as a lead** | `--ask "Which file decides where the camera stops near map edges?" <files>`. Then grep to confirm |
| Diff review for obvious slips | **Yes** | `git diff \| python tools/look.py --ask "List typos, leftover debug prints, unbalanced CRLF/indentation or obviously unused variables."` |
| Drafting goofy NPC and critter lines | **Yes, drafts only** | Give it the character, situation, tone of nearby dialogue and the established names. Ask for 5 options of at most 3 lines each. You pick and edit, and check names and controls against the README |
| Proposing ledger family groupings | **Yes** | Feed it path lists and ask for family names. You fix them |
| Writing or reviewing code; design, balance or layout decisions; approvals; licences; final wording; anything exact | **No** | Do it yourself |

### Offload wording that works (fast mode)

- "Describe X in N bullet points" works better than open "what do you see".
- "Answer yes or no, then one sentence saying where" is good for triage.
- "List the differences between the left and right halves" is good for regression checks.
- Give it the **game's names**. It once called the beasts Pokémon. Say "creatures called beasts" and "the hero (orange hair)".
- Keep images to the region in question. Full-frame shots dilute it.

## §4 Standard step procedure

Every step:

1. **Read:** §1–§5 here, the step's section, the cited `standards.md` sections, and the relevant README and AGENTS.md sections. Grep code, then read only the needed ranges.
2. **Check the local model** (§3).
3. **Before:** capture the step's shots and numbers with the exact commands you'll use for after:
   - captures go in `build/shots/vo/<num>/before/`, numbers in `build/perf/vo/<num>/before/`;
   - once step 017 exists, use `--scene=vo-shots --id=<scene>` for the three standard cameras;
   - until then, use the existing harness modes listed in the step.
4. **Change** through the existing shared builders, shaders, importers and data (AGENTS.md):
   - new or re-baked world textures go through `tools/smooth_textures.gd`, then `godot --headless --path . --import`, never smoothed twice;
   - re-bake ground (`--scene=bake-ground`), houses (`tools/bake_house_measurements.gd`) or battle art (`tools/bake_battle_art.gd`, backdrops) when their inputs change.
5. **After:** the same captures and numbers in `.../after/`.
6. **Test:** `bash tools/run_tests.sh quick` plus the step's named tests (through `server.py` `tests`), and read errors first. Map or layout changes also run `godot --headless --path . --script res://tools/check_maps.gd` and `python tools/town_check.py`. From step 011, `vo-budget`; from step 018, `vo-ledger`.
7. **Ledger:** from step 016, regenerate `ledger/assets.csv` and `scenes.csv`, and set the touched families to `ready for review`.
8. **Record:** add a row to `progress.md` with the step, status, date, evidence paths, numbers and remaining defects. Update README.md "Next step".
9. **Report:** before/after shots, numbers, tests, and the local-model help used, with any answer you overrode. Stop for review when game visuals change; otherwise continue after the checks pass. Commit nothing and create no branches unless you're asked.

`godot` means the local Godot 4.7 executable: resolve its path. Use isolated `--save_dir=res://build/...` and `--prefs_path=res://build/...` every time; never touch player saves.

## §5 Approval, revisions and rebuilds

- Visual steps end as **waiting for approval**. You answer "approve" or "redo: …". Each redo is a revision round.
- **Stopping rule** (standards.md §24): after the first adaptation plus **two** revision rounds fail on the same fundamental requirement, the next round is a **rebuild**: a Blender remodel or repaint, not more filters. Rebuild immediately if the source can't reach the needed silhouette or construction.
- Rework first. A new pack only when rework fails (record the licence in `CREDITS.md` and `licenses/`).
- Approval is recorded in `ledger/approvals.csv` (from step 018) with input hashes. A later change to those inputs puts the entry back to `ready for review`.
- A step that cannot finish stops at a clean point and is split in this file (021 → 021a, 021b).

---

## Phase P: performance foundation

### 001 · P1: reproducible perf runs
**Approval:** numbers. **Needs:** nothing.
**Read:** `docs/performance.md`; standards.md §21 and §28 (commands); README "Developer test modes".
**Files:** `scripts/main.gd` (the `field-perf`, `build-profile`, `transitions` and `perf` modes); `tools/debug/transitions.gd`; a new `tools/debug/vo_perf.gd` if cleaner.
**Do:**
- Add `--scene=vo-perf`. It walks a fixed, scripted route with a fixed seed and no input variance:
  - Coastal Path: full length;
  - Cocoon Cove: plaza loop and into the hero's house;
  - Bellerive: Rue Royale;
  - a warmed coast battle: 240 frames.
- Per segment it records frame-time median, p95 and p99, the worst 5 frames, CPU frame time, draw calls, objects, primitives, the number of distinct materials and surfaces in view, video memory (`RenderingServer.get_rendering_info`), and black-screen ms per transition. It writes `--report=res://build/perf/vo/<tag>.json`.
- Run it on Forward+, Mobile (`--rendering-method mobile`) and Compatibility (`--rendering-method gl_compatibility`) at 1920×1080. Also run Mobile at 2400×1080 `--touch`.
- Run each command example in standards.md §28 once. Fix any that are wrong in standards.md.

**Offload:** read the long run logs ("list any SCRIPT ERROR, missing resource or warning lines"), and summarise the JSON as prose for the report. Do the ranking with a Python script.
**Evidence:** `build/perf/vo/baseline-desktop/{forward,mobile,compat,mobile-touch}.json` and one screenshot per segment.
**Done when:** two consecutive runs agree within about 5% on medians. `quick` and `performance` tests pass.

### 002 · P2: phone baseline
**Approval:** numbers. **Needs:** 001.
**Read:** README Android build and Mobile sections; memory notes on the phone build (`com.rubycocoon.x`; the razr needs `screencap -d`).
**Do:**
- Export the debug Android build with the existing preset and install it.
- Launch `vo-perf` via its launch arguments (or a debug menu entry if arguments can't be passed: add one in this step).
- Pull the JSON with `adb pull`, and screenshots with `adb exec-out screencap -d <id> -p`.
- Do a 15-minute sustained loop of the route, logging battery temperature (`adb shell dumpsys battery`) every minute.
- If no phone is attached, say so and stop.

**Offload:** summarise the `adb logcat` excerpts for errors.
**Evidence:** `build/perf/vo/baseline-phone/`, plus `ledger/perf.md` § Phone (device, Android version, renderer, resolution preset, medians, p95, temperature curve).
**Done when:** the numbers are recorded. Gaps (no thermal data, for example) are written down.

### 003 · P3: web baseline
**Approval:** numbers. **Needs:** 001.
**Do:**
- Make the single-threaded web export (existing preset) and serve it locally (`python -m http.server` in the export folder).
- Open it in the built-in browser and run the route by URL argument or debug entry.
- Record the first and return black-screen times per map, and steady fps from the in-game report (downloaded through the page or printed to the console; read via `read_console_messages`).

**Offload:** summarise the console output for shader-compile and error lines.
**Evidence:** `ledger/perf.md` § Web.
**Done when:** first-visit stalls are listed per map.

### 004 · P4: cost diagnosis (analysis only)
**Approval:** numbers. **Needs:** 001–003.
**Do:**
- Rank the causes per scene and target:
  - distinct materials (the soft-finish pass);
  - draw calls by node type;
  - shadow casters;
  - transparent draws (grass, foliage cards);
  - lights;
  - per-frame scripts (Godot profiler `--profiling` output, or `build-profile` timings);
  - shader variants compiled on first sight;
  - loading phases.
- Estimate the saving of each fix.
- Re-order or split steps 005–010 to match the result, and edit this file.

**Offload:** summarise profiler text dumps. Ask "which script functions appear most often in this per-frame list?". Verify with a script.
**Evidence:** `ledger/perf.md` § Diagnosis, a ranked table.
**Done when:** steps 005–010 reflect the ranking.

**004 result (12 November 2026):** see [004-cost-diagnosis.md](004-cost-diagnosis.md) and the generated
`build/perf/vo/004/tables.md`. Existing finishes and scenery are already shared/batched; grass is opaque geometry.
Do not implement the old blanket assumptions. Execution order after 004 is:
**005a → 009a → 010a → 005b if justified → 009b → 010b → 008 → 006 → 007 → 011**.
The cheap audits/measurements precede changes. Follow the dependencies below rather than the headings' numerical order.

### 005 · P5: material sharing (split into 005a and 005b)
### 005a · P5a: exact-duplicate eligibility (analysis only)
**Approval:** numbers. **Needs:** 004.
**Do:** count exact rendering-property-equivalent finished materials in the four whole-map fixtures and battle;
inspect ownership/mutation before proposing reuse. Distinguish resource duplication, tint differences and shader features.
Use conservative resource identity for textures; do not merge materials or move tint to vertices in this substep.
**Evidence:** eligibility counts, mutation audit and go/no-go for 005b in `ledger/perf.md`.
**Done when:** the 005b scope is justified by actual duplicates, or an evidence-backed no-op is recorded.
Continue automatically to 009a.

### 005b · P5b: proven safe material sharing
**Approval:** numbers, plus a pixel diff. **Needs:** 004.
**Additional needs:** 005a, 009a, 010a. Skip implementation only with the evidence-backed no-op from 005a.
**Files:** `scripts/gfx/surface_finish.gd`, `tools/build_soft_textures.py`, the builders that create per-surface materials.
**Do:**
- Cache one `Material` per (finish texture, tint, shader, flags) key. Move per-object tint into vertex colour or an instance uniform where it's still unique.
- Builders reuse cached materials instead of `duplicate()`.
- Keep `_warm_shaders` working.
- Before/after the same route and the same shots: `bash tools/img.sh diff before.png after.png` must show only noise.

**Offload:** a diff review for slips.
**Evidence:** material and draw-call counts before/after on all three renderers.
**Done when:** only proven equivalent immutable materials are shared, counts meet the measured eligibility target,
and the `textures`, `performance` and `transitions` tests pass. Identical-looking tint/flags alone are not a complete cache key.
Pixel diffs must be noise-only; a visible change stops for screenshot approval.

### 006 · P6: batched scenery
**Approval:** numbers and screenshot review if visible. **Needs:** 008.
**Files:** the nature/scenery placement code in `scripts/world/` (find it with a grep for `MeshInstance3D.new()` in scenery code), `foliage.gdshader`.
**Do:**
- Per terrain chunk, draw repeated bushes, grass, flowers, rocks and small props as `MultiMeshInstance3D`, with per-instance colour or custom data for variation.
- Keep LODs (one MultiMesh per LOD band, or a visibility range), fading near the camera (instance alpha via custom data), collision (separate static shapes, unchanged), and building and terrain visibility rules.
- It must work on Mobile and Compatibility.
- Existing 8×8 chunked MultiMeshes stay. Target residual repetitions, excess LOD submissions or update work only
  where measurements justify it; do not perform a second wholesale batching conversion.
- Audit frustum-culling bounds for generated terrain, merged assets, MultiMeshes, animated meshes and
  shader-displaced effects. Keep AABBs tight but large enough for the complete animation/displacement;
  check camera-edge popping and oversized bounds from actual gameplay views. A MultiMesh is culled as
  a group, not per instance; measure chunk-size trade-offs before changing the existing 8×8 layout.
- Prototype engine occlusion culling in one dense street or suitable room, with simple occluders from
  the existing runtime builders. Enable `use_occlusion_culling` on the actual 3D SubViewport (not only
  the root window), and compare on/off on the same route. Automatic occluder baking excludes MultiMesh
  sources; use conservative manually generated shapes where needed. Occluders must stay within genuinely
  opaque geometry and disable/update when that geometry fades, hides, opens or changes. Never let an
  invisible occluder hide the hero, essential choices or geometry revealed by terrain dithering.
- Keep building fading and battle sightline hiding: engine occlusion culling does not replace either.
  Compare CPU overhead, GPU time and total frame intervals on Forward+, Mobile and Compatibility/web,
  with a real phone where available. Retain occlusion only where measured savings exceed its overhead;
  record a no-op where the top-down/stage-room layout offers too little hidden geometry.
- Trial distance ranges for small nonessential decoration by category and camera framing, not a blanket
  40-unit cutoff. Preserve landmarks, interactables, mandatory sightlines, map-edge bands and battle
  dressing that seals joins. Check wide touch aspects and every directed battle shot for popping.
  Built-in visibility-range smooth fading is Forward+ only; Mobile/Compatibility need tested hysteresis
  or a measured shared alternative. Avoid adding blended overdraw just to hide a distance transition.
  Apply ranges at suitable chunk/asset granularity and preserve gameplay collision and movement rules.
- Run bounds, occlusion, distance-range and mesh-merger experiments as separate small checkpoints,
  keeping other settings fixed. Record each go/no-go before combining successful changes, then verify
  the combined result. Visible checkpoints retain screenshot approval; unavailable device tests stay explicit.
- Evaluate [Static Mesh Merger](https://github.com/EverettM12/Static-Mesh-Merger) on one isolated complex
  static prop or structure. This is an editor-side asset-preparation experiment, not a replacement for
  runtime builders or existing MultiMeshes. Review and pin the tested plugin version; keep source assets
  and a repeatable rebuild path, and record its license/attribution if adopted.
- Merge only pieces that share visibility, fading, shadow and LOD behavior. Preserve collision transforms,
  materials, UVs and normals. Keep doors, interactables, independently faded buildings and battle props
  that hide for sightlines separate. Never merge whole streets or forests across the existing chunk boundaries.
- Compare the original asset with the merged result on Forward+, Mobile and Compatibility, including an
  actual phone where available: surface/draw counts, CPU/GPU frame time, memory and load cost, plus matched
  gameplay views and collision checks. A single ArrayMesh can retain multiple surface draws; fewer nodes
  alone do not prove a gain. Check culling and LODs explicitly because the plugin does not generate LODs.
- Adopt only if measured benefit survives those checks; otherwise record an evidence-backed no-op.
  Keep generated mesh collision out of the tile movement rules, and obtain screenshot approval for any
  visible change under the existing review protocol.

**Offload:** a first look at before/after shots ("list differences"), and the diff review.
**Evidence:** draw calls before/after on Coastal Path and Cocoon Cove; bounds/occlusion debug views and
camera-edge/distance-transition crops; separate on/off CPU/GPU/frame comparisons for each experiment;
a `field-perf` run with no frame over 20 ms on desktop. Identify desktop Mobile-renderer measurements as desktop.
**Done when:** the `nature`, `walk`, `building-fade` and `maps-built` tests pass.

### 007 · P7: alpha and overdraw
**Approval:** numbers and screenshot review if visible. **Needs:** 006.
**Do:**
- Switch alpha-blended foliage and grass cards to alpha-scissor (or opaque geometry), cap card layers, and turn off depth pre-pass costs where not needed.
- Measure Mobile GPU time on desktop and on the phone (repeat the 002 route).
- 004 found solid foliage and no BaseMaterial blended surfaces in field endpoint views. Attribute actual residual
  transparent draws first; preserve water, contact shadows, fades and intentional battle effects. Record a no-op
  if no harmful foliage blend remains, rather than converting an already opaque shader.
- Include a focused merge-film overdraw check (`MergeCinematic.tscn`, `merge_cinematic.gd`,
  `hatchery_stage.gd`, `hatchery_beam.gdshader`): compare peak overlapping beams, halos and particles,
  reducing layers or covered screen area only where measured GPU cost justifies it. Beams are already
  unshaded/additive and shadowless; unshaded transparency still needs transparency handling.
  Existing merge emitters already use 56/40/40 particles with 1.1-second lifetimes; treat these as the
  baseline, not a new optimization or a universal cap for other effects. Preserve the films' timing and readability.
- If edge aliasing remains, compare the existing 2x MSAA default against FXAA at the same resolution,
  including moving foliage and beam edges. Presets currently use no AA/2x/4x MSAA, screen-space AA is
  disabled and no TAA is configured. Do not stack AA methods without evidence; ordinary MSAA does not
  multiply fragment shading by its sample count or smooth alpha-scissor edges without alpha antialiasing.
  Record an evidence-backed no-op if FXAA does not improve the quality/cost trade-off.

**Offload:** triage the before/after crops for visible holes or aliasing ("describe the edges of the grass blades").
**Evidence:** transparent draws and GPU time before/after.
**Done when:** fewer transparent draws, no visible fringe regressions, and the `nature` test passes.

### 008 · P8: shadows and lights budget
Split at the engineering/visual handoff into 008a and 008b below; the requirements here apply to both.
**Approval:** numbers and actual before/after screenshots. **Needs:** 010b.
**Files:** `outdoor_light.gd`, `render_quality.gd`, `scripts/autoload/prefs.gd`, the scenery builders' `cast_shadow` settings.
**Do:**
- Only large scenery, buildings and actors cast shadows. Grass, flowers, small props and decals never do.
- Shadow distance and splits per preset (Min/Mid/Max).
- Contact shadows (`contact_shadow.gd`) keep small things grounded.
- Battles keep "only fighters cast shadows".
- First isolate shadow-pass GPU cost with controlled diagnostics; one shadow light outdoors does not establish
  excessive lights. Do not remove authored large casters without evidence and visual review.
- Start from the existing 30-unit, two-split world/battle sun. Do not extend it to the suggested 50–80 units
  by default; choose distance and splits from visible coverage, shadow stability and measured cost per preset.
- Verify existing grass/flower/small-clutter shadow suppression and audit remaining minor bushes/debris
  by actual caster contribution. Include off-camera casters that can cast visible shadows; camera-frustum
  counts alone do not describe shadow-pass work. Preserve useful silhouettes and measure each change.
- Audit hatch/merge local-light ranges, overlap and caster eligibility as well as outdoor lighting.
  Decorative beams/particles already cast no shadows; the shared hatchery has one shadow-casting key
  and shadowless fills. Light energy (including values up to 16) is not itself a rendering-cost metric.
  Reserve costly shadows for subjects that need them and verify that important silhouettes stay grounded.

**Offload:** a first look ("describe where shadows appear under characters and props").
**Evidence:** shadow-pass cost and shots before/after.
**Done when:** characters still look grounded and the `battle-stage` test passes.

### 008a · P8a: controlled shadow diagnosis (nonvisual)
**Approval:** numbers. **Needs:** 010b.
Run matched on/off/on diagnostics, validate raw traces and effective light states, audit existing caster rules
and local-light ranges, and record GPU/pacing/drift limitations. No production lighting changes.
Use `tools/vo_shadow_sweep.py`; evidence and limitations in [008-shadow-budget.md](008-shadow-budget.md).
Quick, vo-shadow-route and battle-stage must pass. Hand off the concrete visible questions to Claude.

### 008b · P8b: authored shadows and lights
**Approval:** user screenshots. **Needs:** 008a.
Claude evaluates grounded silhouettes and shadow coverage using the diagnosis before selecting visible changes.
Codex handles any resulting shared-code integration and measured validation. Preserve authored large casters unless
measurements and visual review justify changing them. Finish the parent 008 evidence before advancing 006.

### 009 · P9: shader warm-up and first-visit stalls (split)
### 009a · P9a: production loading-phase attribution (nonvisual instrumentation)
**Approval:** numbers. **Needs:** 005a.
**Do:** time production teardown, script wait, world build, finish, wild spawn, battle/audio prewarm,
arrival preparation and first draws separately in the existing route. Record available pipeline-counter deltas;
Compatibility zeros do not mean no compilation. Preserve Web cache caveats. Do not alter warm-up behavior here.
**Evidence:** phase report on desktop Mobile and Compatibility; construction versus first-draw ranking.
**Done when:** timings explain where the black hold is spent without calling every wait shader compilation;
quick and vo-perf-route pass. Continue automatically to 010a.

### 009b · P9b: shader warm-up and first-visit changes
**Approval:** numbers, plus screenshots/approval if visible. **Needs:** 009a, 010a, 005b (or its documented no-op).
**Do:**
- Check the Godot 4.7 export options for shader baking and pipeline caches per renderer (read the local Godot docs or the export preset options; don't guess). Enable what applies.
- Move `_warm_shaders` to warm the reduced shared material set once, behind the title or the first fade, instead of per map.
- Remove one-off shader variants found in 004.

**Evidence:** first-visit black screens on Compatibility on desktop and the web (repeat 003).
**Done when:** a first visit is at most about 1.5 s per map on desktop Compatibility, and the web improves measurably. The `transitions` and `title-startup` tests pass.

**009b result (12 November 2026):** see [009b-first-visit-checkpoint.md](009b-first-visit-checkpoint.md). Desktop
Compatibility uses the dedicated cache-off profile plus a title-time shader precompile (`shader_precompile.gd`,
manifest from `--scene=shader-manifest`). Packaged first visits are 0.06–0.8 s. The web criterion was not met and the
user closed the step anyway; the precompile is off on the web and whenever the shader cache is on.

### 010 · P10: low-resolution output (split)
### 010a · P10a: phone resolution and pacing experiment (measurement only)
**Approval:** numbers. **Needs:** 009a.
**Do:** on the isolated benchmark package compare 720p/Mid with 540p/Mid on the same route; retain interval,
tick/render CPU/GPU and refresh/pacing metadata. House/battle remain ~30 fps despite ~15 ms GPU in 002;
do not assume scenery alone explains the interval. Preserve player app and lock settings. Record unavailable counters.
**Evidence:** actual phone reports and a measured resolution sensitivity, not the optimistic pixel-count model from 004.
**Done when:** the results select the next GPU/pacing intervention; no production video behavior changes in this substep.

### 010b · P10b: smooth low-resolution resolve
**Approval: you.** **Needs:** 010a, 009b.
**Files:** `scripts/autoload/prefs.gd:100-115`, `render_quality.gd`, video settings; README Mobile/Art sections.
**Do:**
- Replace nearest enlargement with a smooth resolve: bilinear on Compatibility, and FSR 1 or bilinear plus mild sharpening on Mobile and Forward+. Verify each renderer supports the mode.
- Presets: 540p/Min and 720p/Mid, as the README's starting points.
- Update the README text that describes the pixel effect.

**Offload:** a first look at 540p crops ("describe whether edges look stair-stepped or smooth").
**Evidence:** side-by-side 540p and 720p crops before/after, and phone fps at 540p.
**Done when:** you approve, and the `video-settings` and `video-settings-touch` tests pass.

### 011 · P11: measured budgets and the `vo-budget` test
**Approval:** numbers. **Needs:** 005–010.
**Do:**
- From the improved numbers, write `ledger/budgets.md`: per scene and renderer, the draw calls, distinct materials, triangles in view, texture MB, transparent draws and frame ms. Give a target per hardware class (30 fps minimum class, 60 fps mid class and PC), with headroom for the art phases.
- Add a `vo-budget` line to `tools/run_tests.sh`. It runs the route headless and fails over the CPU-side budgets.
- Verify the existing renderer split in actual exports: Forward+ desktop default, Mobile phones/tablets,
  Compatibility web and the dedicated compatibility build. Preserve it unless target measurements justify
  a change. Report desktop Mobile-renderer timings as desktop measurements. Keep GPU timing and frame
  pacing separate: 010a reduced GPU time without resolving the roughly 30 fps phone frame intervals.

**Done when:** the test passes today, and the budgets are cited by every later step.

---

## Phase M: diagonal movement (option) and the edge fix

### 012 · M1: movement core
**Approval:** numbers (tests). **Needs:** 011.
**Read:** README Controls, AGENTS.md "World layout and navigation", memory on cliffs and diagonal cliff tiles.
**Files:** the shared step and movement code for the hero, NPCs and beasts (grep `step`, `tile_center` and `_try_move` in `scripts/world/`); `scripts/world/elevation.gd`.
**Do:**
- Add diagonal steps that end on tile centres. A diagonal is allowed only if the destination **and both** side tiles are free and level-compatible: no ramps entered from the side, and no diagonal-cliff tiles.
- When it's blocked and exactly one cardinal component is free, slide along it. Otherwise refuse.
- Duration is ×√2, so ground speed is unchanged.
- NPC and beast walkers use the same stepping and always rest on centres.
- Encounter rolls, door triggers and facing work after diagonals.
- **With the option off, behaviour is byte-identical.**

**Offload:** the diff review; summarise failing test logs.
**Evidence:** a new `diagonal` test in `run_tests.sh` covering blocked corners, ramps, cliffs, encounter grass, doors, NPC paths and beasts.
**Done when:** `quick`, `walk`, `walk-touch`, `wild-grace`, `flow`, `lessons` and `diagonal` pass with the option off and on.

### 013 · M2: Diagonal movement setting and input
**Approval: you** (setting shots). **Needs:** 012.
**Files:** `scripts/autoload/prefs.gd` (the new pref, default `false`, defaulted for old settings files); the settings page (`UIKit` rows); `controls_overlay.gd` (d-pad); input handling.
**Do:**
- Add a "Diagonal movement: On/Off" row with full-width values (32 UI units; 56/80 row heights).
- Keyboard: two directions held together. Gamepad: stick and d-pad diagonals.
- Touch d-pad: diagonal zones only while the option is on. Off, it's the existing one-direction-at-a-time behaviour, including boundary touches.
- Keep B plus movement and the flute chords.

**Offload:** a first look at the settings captures ("is any text clipped or overlapping?").
**Evidence:** captures at desktop 1920×1080, touch 2400×1080 and 1280×720, plus real key and tap exercises recorded in the report.
**Done when:** you approve, and `video-settings*`, `controllers*`, `mobile-menus` and `desktop-menus` pass.

### 014 · M3: rules and protections
**Approval:** numbers. **Needs:** 013.
**Do:**
- Lessons, story gates, push and slide puzzles (Mesa boulders, Summit ice), doors, stairs, signs, fishing spots and the flute must all work with eight-way on.
- Push puzzles accept cardinal pushes only. Document that in the README.
- Update README Controls and AGENTS.md movement rules to describe the shipped option (no longer "planned").

**Done when:** the full suite (`bash tools/run_tests.sh`, in the background through `server.py`) passes with the option off, and the movement-related tests pass with it on.

### 015 · X1: map edges never show
**Approval: you.** **Needs:** 011.
**Files:** the terrain/world builder and camera follow code; `tools/check_maps.gd`.
**Do:**
- Every map, towns included, gets an **edge band**: cheap unwalkable filler beyond the playable area (raised cliffs and forest for land, open sea for coasts, dunes for desert), deep enough to cover the camera frustum at its furthest offset. It's batched (MultiMesh) and casts no shadows.
- The camera **eases to a stop** so the frustum never passes the band's outer edge.
- `check_maps.gd` fails any map whose band is too thin for the gameplay camera.

**Offload:** contact-sheet triage. Capture the four corners and edge midpoints of every map, then loop: "Is any grey void, flat cut-off, sky gap or bare map edge visible? yes/no and where."
**Evidence:** an edge contact sheet per map in `build/shots/vo/015/`.
**Done when:** no visible edge from any reachable spot, budgets are held, both map checkers pass, and you approve.

---

## Phase L: ledger tooling (full ledger, generated)

### 016 · L1: asset ledger generator
**Approval:** numbers. **Needs:** 011.
**Do:**
- Add `tools/visual_ledger.gd` (headless). It builds each outdoor map (and each story state with `bake-ground`'s shapes), each room template, battle settings, the title, the creator and the film sets.
- It walks the rendered nodes and records: a stable asset ID (resource path, or builder plus recipe key), family guess, source path, licence (from `CREDITS.md` and `licenses/`), runtime users, embedded materials and textures with import settings (filter, mipmaps, compression), triangles, surfaces, the scenes using it, source and output SHA-256, and status (`unreviewed` by default).
- Output: `docs/visual_overhaul/ledger/assets.csv`, sorted and stable.
- Unused source packs are listed `not shipped`, with the scan as evidence.

**Offload:** a first family-name pass (step 019 refines it).
**Done when:** it runs in under about 5 minutes, and a second run with no changes is byte-identical.

### 017 · L2: scene/state ledger and `vo-shots`
**Approval:** numbers. **Needs:** 016.
**Do:**
- Write `ledger/scenes.csv` from data: every outdoor map, room template, battle setting, film, and the story states that change geometry.
- Add `--scene=vo-shots --id=<row>`: three standard cameras per row (gameplay at the hero's usual spot, hero close-up at 1.5 m, edge/door crop), a fixed seed and time, and output to `build/shots/vo/<step>/<id>_{play,close,edge}.png`, with a companion JSON (renderer, quality, resolution, revision).

**Done when:** any row captures cleanly.

### 018 · L3: approvals and the `vo-ledger` test
**Approval:** numbers. **Needs:** 017.
**Do:**
- `ledger/approvals.csv` has these columns: ID, step, standard version, input hashes, renderer/profile, evidence path, date, approved by.
- The `vo-ledger` test fails when an approved entry's inputs changed (and reports it as `ready for review`), or when an active asset is missing from the ledger.

**Done when:** it passes on a clean tree and fails on a deliberately touched asset (revert the touch).

### 019 · L4: families and triage
**Approval:** numbers. **Needs:** 018.
**Do:** group ledger rows into families (terrain-coast, cliff-grassland, tree-broadleaf, bush, grass-encounter, rock-coast, house-cove-kit, house-ps1-pack, furniture-wood, people-hero, beast-<line>, and so on) in `ledger/families.csv`, with counts per status.
**Offload:** propose families from path lists, in batches of 200 paths. You fix them.
**Done when:** every active row belongs to a family.

### 020 · M4: diagonal terrain data
**Approval:** numbers. **Needs:** 014.
**Files:** map data, `tools/cliff_corners.gd`, `terrain_mesh.gd` (data only here), `tools/check_maps.gd`, `tools/town_check.py`.
**Do:**
- Maps can mark path, water and building-wall boundaries as diagonal per tile corner, the way cliff diagonals already work. Each tile stays wholly walkable or blocked.
- Both checkers learn the marks and verify that every diagonal path is a connected four-way staircase.
- Add a small test map with diagonal path, water and wall runs.

**Done when:** both checkers pass on all maps plus the test map, and the `maps`, `terrain` and `ground` tests pass.

---

## Phase S: style targets and reference scenes

Every S step must keep `ledger/budgets.md`. Each captures the three `vo-shots` cameras and a crop beside the nearest supplied Animal Crossing reference.

The **reference crop pairing**:
- **Grass/cliff:** the cherry-tree and stone-bridge shot; the cliff-and-rocks digging shot.
- **Shoreline:** the beach-curve shot.
- **Waterfalls and terraces:** the crown-on-cliff shot; the construction terraces shot.
- **Trees:** the pear-tree night shot; the cherry trees.
- **Town plaza:** the orange house with the stone plaza.
- **Dock:** the pier with the seaplane.
- **Snow:** the winter portrait (shape and warmth only, never its grain).

The reference images aren't in the repo. To use them in captures, save copies in `build/refs/` (never in `docs/screenshots/`).

### 021 · S1: palette and light, grassland
**Approval: you.** **Needs:** 011, 015.
**Read:** standards.md §9 and §17; README Art (the `--light_*` flags).
**Files:** `scripts/gfx/outdoor_light.gd`; the coast/grassland entries in `WorldDB.BIOMES` (`scripts/data/world_db.gd`).
**Do:**
- Explore with `--light_exposure/_sun/_ambient/_sky/_contrast/_saturation/_white/_glow` before editing.
- Target:
  - a gentle mid-green lawn with broad darker patches;
  - a warm path clearly separated from the lawn **in value**, not only in hue;
  - blue-violet tinted shade and a soft warm key;
  - glow only on bright sources;
  - clear light, mid and dark steps.
- Produce 3 candidate gradings. Commit the chosen one in code and data.
- Filmic is already the shared baseline. If testing AgX, compare it with Filmic using coordinated exposure,
  saturation and highlight tuning, including bright roofs and hatchery beams; do not treat this as a
  Linear-to-Filmic fix. Verify the chosen result on Forward+, Mobile and Compatibility.
- Review existing horizon-tinted, per-biome distance fog for depth separation. Trial 0.005–0.01 only where
  appropriate to that scene's scale; preserve clear routes, dark regions and intentional dense story fog.
- Tune authored SSAO only on supported renderers at Max quality (currently Forward+ and Compatibility,
  not Mobile). Compare contact crops for grounding versus halos before widening the current outdoor
  0.8 radius toward 1.0–1.5. Preserve contact-shadow grounding on lower presets and Mobile.

**Offload:** pairwise difference notes ("list differences in brightness, saturation and shadow colour between left and right") for each candidate against the current grading and against the AC grass reference.
**Evidence:** Coastal Path, three cameras × three candidates.
**Done when:** you pick and approve one, and `coastal-path` and `cocoon` pass.

### 022 · S2: material board
**Approval: you.** **Needs:** 021.
**Read:** standards.md §7 and §8.
**Do:**
- Add `--scene=material-board`. Rows of spheres, planks, blocks and cloth drapes per family: painted timber, bark, plaster, stone, cloth, upholstery, foliage, ceramic, metal, water, skin/fur/scale and neon/emissive (for Cogsworth).
- Show them beside the hero and a familiar beast, under the outdoor, warm-indoor, cool-indoor, night and battle profiles.
- Shared presets go in one place (extend `surface_finish.gd` or add `scripts/gfx/material_library.gd`), using the §8 roughness bands.
- Surface relief (user's direction, 2026-11-12; standards.md §8): the brick/masonry, stone, stucco/plaster and
  wooden-plank presets get soft bump (normal) maps generated from their painted textures, so joints, courses and
  boards catch the light. Show each with and without relief on the board, and measure its cost on Mobile and
  Compatibility (Min and the web may drop it). Every later building, interior and prop step uses these relief
  presets rather than adding its own maps.

**Offload:** "List any sample that looks glossy like plastic, or grainy/noisy."
**Done when:** you approve, and the presets are in code.

### 022a · S2a: static-interior LightmapGI feasibility prototype
**Approval:** numbers and before/after screenshots for the prototype; production adoption requires your approval.
**Needs:** 011, 021, 022.
**Files:** one representative interior fixture, its existing room/material builders, and an offline bake tool.
**Do:**
- Prototype one static interior using the approved materials; keep the experiment isolated from production.
  The current runtime has no active VoxelGI or SDFGI to replace: assess added bounce-light quality and total cost,
  rather than claiming an existing runtime GI saving.
- Prefer this LightmapGI experiment over VoxelGI for the shared lighting path. VoxelGI's bake prepares voxel
  data but still requires demanding runtime GI and Forward+; it does not benefit Mobile or Compatibility/web.
  Its static bake also has custom-ShaderMaterial limitations relevant to the game's terrain and foliage.
  Any future desktop-only VoxelGI experiment needs a separate measured justification and fallback;
  adding a VoxelGI node is not an optimization of the current lighting.
- Establish a repeatable offline bake from the runtime-built room, unique non-overlapping UV2s,
  stable geometry/transforms and resource mapping, and a cache/invalidation rule for rebuilt rooms.
  Exported play must load the baked result, never attempt an editor-only bake.
- Compare indirect-only versus direct-plus-indirect baking where useful. Keep actors, moving objects,
  room changes and dynamic lights coherent; check existing wall fading and omitted camera-facing walls.
- Verify baked-light rendering on Forward+, Mobile and Compatibility, including web. Record texture memory,
  export/download size, loading cost, GPU/frame timings and bake time alongside matched gameplay crops.
- Decide go/no-go against 011 budgets. If worthwhile, document a bounded follow-up for eligible static rooms;
  assess village/overworld eligibility separately because runtime assembly, batching and changing geometry
  may make baking unsuitable. Do not roll lightmaps across the world as part of this prototype.

**Offload:** neutral comparison of contact shadows, light bounce and visible bake seams; verify findings directly.
**Evidence:** repeatable bake instructions, renderer/device results, matched crops and an adoption decision.
**Done when:** the prototype's quality/cost trade-off and limitations are recorded and reviewed; either a
bounded adoption follow-up is planned or an evidence-backed no-op is recorded. No automatic production rollout.

### 023 · S3: scale sheet
**Approval: you.** **Needs:** 022.
**Do:** add `--scene=scale-sheet`: the hero, a second body type, a familiar beast, a door (`house_models.gd` `DOOR_H`), chair, bench, counter, lamp, fence, window and a one-storey house, in front of a 1-unit grid.
**Done when:** you approve. Every later step compares against it.

### 024 · S4: ground motif and painted ground (coast/grassland)
**Approval: you.** **Needs:** 021.
**Files:** `tools/build_soft_textures.py` (or a new `tools/build_ground_motif.py`), `terrain.gdshader`, `scripts/world/ground_store.gd`.
**Do:**
- **Grass:** a base with broad soft patches and a **sparse, regular motif of our own**: tiny leaf or clover marks, about 3–5 per tile, close in tone to the base. **Never triangles.**
- **Dirt path:** warm, with soft pebble flecks. **Sand:** soft ripple marks.
- Run them through `tools/smooth_textures.gd`, then `--import`.
- In the shader: world-space UVs, so the motif scale is constant across chunks, and soft wandering layer blends.
- Re-bake the ground with `--scene=bake-ground`.

**Offload:** "Describe the ground pattern in this crop and whether it visibly repeats" on a 3×3-tile gameplay crop.
**Done when:** you approve, and `ground`, `terrain` and `textures` pass.

### 025 · S5: turf lip and cliff faces (grassland/coast look)
**Approval: you.** **Needs:** 020, 024.
**Read:** memory "Cliffs and ramps": elevation only, diagonal unwalkable corners, deep water at sea cliffs, meandering contours, no placed cliff meshes.
**Files:** `scripts/world/terrain_mesh.gd`, `terrain.gdshader`, `WorldDB.CLIFF_LOOKS`.
**Do:**
- A **thick rounded turf lip** overhanging the face by about 0.08–0.15 units, with a soft shade band under it.
- **Fluted vertical slabs** with broad strata and slight per-slab depth variation.
- Clean diagonal runs at diagonal corners.
- Sea cliffs meet deep water with a soft foam contact.
- Only the grassland/coast look changes in this step. Re-bake the ground.

**Offload:** neutral descriptions of four crops: a straight run, a diagonal corner, a ramp end and a sea cliff.
**Done when:** you approve, both map checkers pass, and `ground`, `terrain` and `walk` pass.

### 026 · S6: paths, banks, shoreline and diagonal edges
**Approval: you.** **Needs:** 025.
**Read:** `docs/water.md`; AGENTS.md waterfall rules.
**Do:**
- Paths: a soft shoulder and an irregular edge, following M4 diagonal marks as smooth diagonal runs.
- River banks: a lip.
- Sea shore: a shallow-water gradient band and a white foam line following the coastline, with gentle motion.
- Water edges follow diagonal marks. Waterfalls stay sealed.

**Offload:** "Describe where the water meets the sand in this crop, and whether any straight hard cut is visible."
**Done when:** you approve, and `waterfront`, `terrain` and `maps` pass, plus `godot --headless --path . --script res://tools/check_water.gd`.

### 027 · S7: tree grammar (Blender)
**Approval: you.** **Needs:** 022, 023.
**Approved preproduction:** broadleaf rev_003 is the selected candidate; [technical review](art_reviews/broadleaf-rev_003.md)
and attribution are recorded. Reuse its immutable source/generator through integration copies rather than restarting
the rejected individual-leaf direction. The user's look is pillowy painted domes with soft edges, no individual-leaf
pattern; see standards §11. This does not complete 027 or bypass 011/022/023 and actual in-game approval.
**Files:** a new `tools/blender/tree_broadleaf.py` (`blender -b -P tools/blender/tree_broadleaf.py -- <args>`), `tools/import_stylized_nature.gd`, `foliage.gdshader`.
**Do:**
- **Rework first:** take a derivative of the existing `tree_oak` source (the pack stays untouched).
- Target: a tapered trunk with **root flare**, and **pillowy crown masses** with quiet painted edges as in approved rev_003. 1,000–3,000 triangles, 2–3 variants, 2 LODs; final measured budgets win.
- If the source can't reach the silhouette, build it procedurally in the script.
- Bake or paint the leaf-cluster texture, import it, and swap the cube-crown trees **on Coastal Path only**.

**Offload:** "Describe this tree's silhouette, crown and base" on a turntable sheet.
**Done when:** you approve, budgets are met, and `nature` passes. Record whether it was a rework or a rebuild.

### 028 · S8: bushes, hedges and flowers
**Approval: you.** **Needs:** 027.
**Do:**
- 3–4 bush shapes and a hedge in the S7 leaf grammar.
- Flowers as clear petal masses on stems.
- Retire the orange-dot bushes in favour of a few curated fruit or flower variants.
- Add a **mixed nature gallery** (`--scene=nature-gallery`) with every species together.

**Done when:** you approve the gallery and Coastal Path, and `nature` passes.

### 029 · S9: grass and encounter grass
**Approval: you.** **Needs:** 028.
**Do:**
- Ordinary ground cover becomes short soft clumps, used sparingly.
- Encounter grass becomes broad-bladed, readable patches on **the same tiles and footprint**.
- Alpha-scissor or opaque (as in 007).

**Done when:** you approve, and `wild-grace`, `coastal-path` and `nature` pass.

### 030 · S10: rocks
**Approval: you.** **Needs:** 022.
**Do:** a Blender rework of the rock meshes: designed broad planes, softened transitions, partly buried bases, coast and grassland colours. Add them to the gallery.
**Done when:** you approve.

### 031 · S11: Coastal Path composition → Reference 1
**Approval: you.** **Needs:** 024–030.
**Do:**
- Grouped planting with quiet gaps, props in purposeful groups against edges, signs on verges, continuous fences.
- **The tutorial layout and sightlines don't change.**
- Re-run the phone route (002) for this map.

**Offload:** side-by-side difference notes against the AC references.
**Done when:** **you approve Reference 1**, the phone is within budget, and `coastal-path`, `coastal-path-touch`, `lessons`, `intro` and both map checkers pass.

### 032 · S12: Cocoon Cove building materials and diagonal walls
**Approval: you.** **Needs:** 031.
**Files:** `cove_buildings.gd`, `house_models.gd`, `cove_stucco.gdshader`, `cove_roof.gdshader`.
**Do:**
- Stucco, roof, timber and trim at one feature scale. Replace the plastic-looking roofs and gritty cobbles.
- Apply 022's relief presets: the Cove's stone blocks, brick, stucco and timber planks show soft bump-mapped joints
  and boards (standards.md §8 Surface relief); check them from the gameplay camera, beside the hero, at 540p and
  1080p.
- Where a map marks a diagonal wall, the builder makes sealed angled corners and footprints. Doors stay on straight wall sections facing their door tile.

**Done when:** you approve, and `exteriors`, `cove-exteriors`, `cocoon` and `house-measurements` pass (re-bake if needed).

### 033 · S13: Cove doors, windows, trim and signs
**Approval: you.** **Needs:** 032.
**Do:**
- Consistent bevels on frames, sills, leaves and sign plates.
- Sign art at one density (shop-sign pixel icons may stay crisp).
- Door leaves within 0.1 of the wall face.

**Evidence:** door and window crops beside the hero.
**Done when:** you approve, and `exteriors`, `cove-exteriors` and `door-voices` pass.

### 034 · S14: Cove paving and props
**Approval: you.** **Needs:** 033.
**Do:**
- Paving with a soft motif.
- A lamp, bench, crate, barrel and planter family on the shared edge and material rules.
- Placement: grouped against walls, nothing on paths, nothing tall just south of a path.

**Done when:** you approve, and `town_check.py` passes.

### 035 · S15: Cove composition → Reference 2
**Approval: you.** **Needs:** 034.
**Done when:** **you approve Reference 2**, the phone route is within budget, and `cocoon`, `cocoon-touch`, `rescue` and both map checkers pass.

### 036 · S16: interior floors, walls and rugs
**Approval: you.** **Needs:** 022.
**Read:** `docs/interior_staging.md`; AGENTS.md interior rules.
**Do:**
- Wood boards, carpet and tile at matching feature scale.
- Smooth wall colour or subtle wallpaper in the warm or cool room families.
- Rugs at the allowed footprints, muted, with simple borders.

**Done when:** you approve.

### 037 · S17: furniture family
**Approval: you.** **Needs:** 036.
**Do:**
- Beds, sofas, cushions, tables, shelves and counters with designed edges, real volume and folds, and wood matching the floors.
- Small props sit on real surfaces.
- Blender rework where needed.

**Done when:** you approve.

### 038 · S18: home interior composition → Reference 3
**Approval: you.** **Needs:** 037.
**Done when:** **you approve Reference 3** at 1920×1080, 2400×1080 touch and 1280×720 with a speech bubble on screen, and `doorway`, `speech` and `speech-touch` pass.

### 039 · S19: dark profile and Moor palette
**Approval: you.** **Needs:** 021.
**Read:** standards.md §17 "Serious dark places"; memory "Cinematic mood".
**Do:**
- A night/dark light profile: cool fill, localized warm and magical light, fog depth, readable paths and faces.
- The Moor palette.

**Done when:** you approve, and `gravenmoor` passes.

### 040 · S20: dark props and ghosts → Reference 4
**Approval: you.** **Needs:** 039, 027, 030.
**Do:**
- Dead trees, graves and Gothic trim from the S7 and S10 grammars.
- Ghosts stay readable: black and purple with smoke, with a coloured fill.

**Done when:** **you approve Reference 4**, and `gravenmoor` and `gravenmoor-touch` pass.

### 041 · S21: desert and mesa sample
**Approval: you.** **Needs:** 025, 027.
**Do:**
- The desert/mesa **cliff shape** in `CLIFF_LOOKS`: banded sandstone strata.
- A sand-ripple motif, and broad-form cactus and palm rework without facets.
- Adobe material from S2, on one Sunwall or Dustwell block.

**Done when:** you approve, and `dustwell` passes.

### 042 · S22: Cogsworth cyberpunk pilot block → Reference 5
**Approval: you.** **Needs:** 022, 041.
**Do:**
- Prove the direction on one Cogsworth street block: dense, tall blocks; layered streets; shaped and restrained neon signage; metal and painted concrete; opaque reflective glass.
- Gearhart's tower and steam gate keep their story roles.
- Pair it with the 041 desert block as **Reference 5**, which tests the rules outside green environments.

**Offload:** "List what makes this street read as a big city and what makes it read as a small town." You judge.
**Done when:** **you approve Reference 5.** The full rebuild is in steps 101–105.

### 043 · S23: battle → Reference 6
**Approval: you.** **Needs:** 031.
**Do:**
- Re-bake the coast backdrop from the approved assets (`tools/bake_battle_backdrops.gd`, then smoothing).
- Battle light matched to 021 and 022.
- Check the rings, pads, a legacy guardian or robot, effects and every named shot.
- Preserve and verify the existing camera safeguards through rapid action requests and large summons:
  exponential position/look/FOV smoothing, 24–65-degree FOV limits, at least 0.5 seconds between shot
  changes, indoor bounds and the outdoor 27-unit radius, including shake. Change smoothing speeds only
  for a reproduced jitter problem. Bounds keep shots inside scenery; they do not themselves guarantee
  less geometry or shadow work, so make performance claims only from measurements.

**Done when:** **you approve Reference 6**, and `battle-visuals`, `battle-stage`, `battle-stage-touch`, `battle-poses`, `battle-focus` and `battle-focus-touch` pass.

### 044 · S24: freeze the standard
**Approval: you.** **Needs:** 021–043.
**Do:** write `standard-values.md`: light values, biome palettes so far, material presets, motif scales, lip sizes, cliff-look parameters, and tree/bush/rock/prop budgets. Bump the standard version in the ledger.
**Done when:** you approve. Every later step cites it.

---

## Phase X: exploration systems (built once)

Design: [exploration.md](exploration.md). The README journey table and road puzzles change road by road in the region blocks.

### 045 · X2: big-map pilot (Isle Trail grey-box)
**Approval: you** (layout), plus numbers. **Needs:** 044.
**Do:**
- Grey-box the Isle Trail at **3–4×**: a winding main route that keeps its brambles gate, 2–4 branches (a cave mouth, a beach cove, a hot-spring side path, a shortcut loop), elevation, diagonal edges and the edge band.
- No final art yet.
- Measure loading, walking and memory on all three renderers and on the phone.

**Offload:** edge and void triage over the contact sheet.
**Done when:** you approve the feel of the layout, the numbers are within budget (or a written fix), and both map checkers pass.

### 046 · X3: road layout method and plan sheets
**Approval: you.** **Needs:** 045.
**Do:**
- Write `exploration-roads.md` with a sheet per road: main route, required gate(s), branches, optional secrets, shortcut, hot spring, butterflies, cave and element, the elements needed and **where an egg of each is first reachable**. Fill it in from the region blocks below.
- Flag any required element puzzle without earlier egg access, and propose a fix.

**Done when:** you approve the sheets.

### 047 · X4: caves
**Approval:** numbers, plus a quick look from you. **Needs:** 046.
**Do:**
- A cave map type, entered from a road branch: an elemental focus (wild-beast table, palette, props, light), entry and exit, and an edge band in rock.
- One test cave.

**Done when:** it's playable in a test mode, and `maps`, `wild-grace` and `flow` pass.

### 048 · X5: darkness, torches and the shared element interaction
**Approval: you.** **Needs:** 047.
**Do:**
- Dark areas, cheap on Mobile and Compatibility: only lit pools are bright, and paths stay readable.
- A **fire beast lights torches**, saved per map.
- One shared "use a beast's element on this" interaction, extending the brambles, lava and fog obstacles.

**Done when:** you approve a torch test room, the existing obstacle tests and the temple tests still pass, and touch and keys work.

### 049 · X6: GIANT beasts
**Approval: you.** **Needs:** 047.
**Do:**
- A GIANT variant via `beast_model.gd`: larger scale, a **painted mud-and-moss overlay** (clean painted splotches, never grit), and much higher stats.
- A nest object and a once-only flag per cave.
- A **GIANT egg** shown in the egg film. Its hatchling has **+50% stats** and a **visible mark** (slightly larger, special trim), saved with a default for old saves.

**Done when:** you approve the look, and `beasts`, `beast-growth`, `egg-sales`, `phone-save` and the save/load tests pass.

### 050 · X7: talking critters and snake swings
**Approval: you.** **Needs:** 046.
**Do:**
- A talking-critter type: a world character, never a beast, with speech anchored to its head.
- Critter models in the S7/S10 finish standard: snake (and later monkey and mole).
- **Snake swing:** talking to a friendly snake enables a two-tile traversal link over a gap. It plays a short swing, works in both directions, and works with touch and keys.

**Done when:** you approve, and `speech`, `walk` and `walk-touch` pass.

### 051 · X8: magic butterflies and natural hot springs
**Approval: you.** **Needs:** 046.
**Do:**
- **Butterflies:** rare, in set areas only. A touch heals all your beasts' **MP**. A spot refills after a while (a timer, or after leaving the map), saved.
- **Hot springs:** a short cozy scene, a **full HP and MP heal**, and a **buff for the next battle only**, announced in the top bar.

**Done when:** you approve, and the save tests pass.

### 052 · X9: persistent mechanisms and shortcuts
**Approval:** numbers. **Needs:** 046.
**Do:** saved state for winches, bridges, elevators, waterwheels and far-side doors, with a generic "shortcut unlocked from the far end" pattern.
**Done when:** a save/load test covers each type.

### 053 · X10: pageant hat customiser
**Approval: you.** **Needs:** 044.
**Do:**
- Hat **shape** (bow, crown, sunhat, top hat, flower crown and more), **colours** (main and trim) and **decorations** (flower, feather, ribbon, gem).
- Built with `UIKit` rows and slots, with touch and keys. Worn in the pageant only.

**Done when:** you approve at desktop, touch and 1280×720, and `mobile-menus` and `desktop-menus` pass.

### 054 · X11: pageant runway and rhythm posing
**Approval: you.** **Needs:** 053.
**Do:**
- A runway test scene. Posing is the beat chain (`beat_chain.gd`, `beat_cue.gd`): a longer on-beat chain gives a higher score and a better pose.
- **The poses are the beast's attack poses** (`pose_*`).
- Keep the cue's minimal look and one-press-one-count.

**Done when:** you approve, and `beat-attack` passes.

### 055 · X12: pageant opponents, tiers and prizes
**Approval: you.** **Needs:** 054.
**Do:**
- Repeatable ranked tiers (for example Novice → Grand), with opponents' scores rolled per tier.
- Prizes: hat parts, items and crystal shards.
- Use a test venue for now. The real venue is in Cogsworth (step 105).

**Done when:** you approve.

---

## Phase C (pilots): people and beasts

All C steps keep heights and head ratios (the 023 scale sheet), rigs and animation entry points (`voxel_person.gd`, `beast_model.gd`), palettes (`beast_looks.gd`), outlines and speech anchors.

### 056 · C1: hero body pilot (Blender remodel)
**Approval: you.** **Needs:** 044.
**Do:**
- Remodel the body and head at the current proportions: a smooth silhouette, clean joints, 4,000–10,000 triangles, using a Blender script with a derivative of the current mesh as the guide.
- Fit it to the existing rig. Check idle, walk, run, talk and attack.

**Done when:** you approve it beside the scale sheet, and `walk` and `hero-maker` pass.

### 057 · C2: faces
**Approval: you.** **Needs:** 056.
**Do:** eyes, brows and mouths readable at gameplay distance, plus expression states.
**Done when:** you approve.

### 058 · C3: hair family
**Approval: you.** **Needs:** 056.
**Do:** remodel every hairdo as designed locks and masses, about 6 per step (058a, 058b, …).
**Done when:** you approve each batch.

### 059 · C4: clothing family
**Approval: you.** **Needs:** 056.
**Do:** thickness, folds and the S2 materials, by garment group (059a, 059b, …).
**Done when:** you approve each batch.

### 060 · C5: creator sweep
**Approval: you.** **Needs:** 057–059.
**Do:** every creator option class, with a clipping matrix of the worst combinations. Creator shots at desktop and touch.
**Done when:** you approve, and `hero-maker`, `hero-maker-touch` and `maker` pass.

### 061 · C6: beast pilot
**Approval: you.** **Needs:** 044.
**Do:**
- Remodel one beast line through every evolution stage, plus its ghost and one merge using it, all through `beast_model.gd`.
- Check with `--scene=newbeasts --anim=cycle` and `battle-poses`.

**Done when:** you approve. This sets the method for steps 150–158.

---

## Region blocks (in journey order)

Each block follows the same pattern:
- **layout** for each road: 3–4× (the Coastal Path excepted), keeping the existing required gate unless the step says otherwise;
- **set pieces**, one per step;
- **visual pass** (B-1 to B-5) reusing the frozen standard (044);
- **hints, README** and temple rooms.

Every layout step:
- runs both map checkers, `maps`, `terrain`, `ground` (re-bake), `walk` and `flow`;
- keeps the edge band (015);
- respects the elevation memory (rear and sides high, the south low, nothing tall just south of a path, signs on verges);
- marks diagonal edges (020);
- **gets your approval from an overview plus gameplay shots.**

Every set-piece step:
- adds saved flags with defaults for old saves;
- adds a focused test mode or a `run_tests.sh` line;
- updates `Story.next_goal()` hints;
- drafts goofy dialogue through the local model (5 options at a time; you pick and edit for tone, established names and current controls).

Required gates must stay solvable and impossible to get stuck in. Region blocks may interleave with the C-family steps (146–159), one session at a time per set of files.

### Coast: Bellerive

### 062 · B-coast-1: Bellerive palette and materials (Quarter biome)
**Approval: you.** **Needs:** 044. Warm masonry, painted shutters, paving and greenery from the frozen standard. `tidewater-arrival` and `tidewater-layout` pass.

### 063 · B-coast-2: Bellerive Creole fronts and galleries
**Approval: you.** **Needs:** 062. `creole_builder.gd`: galleries open-air with no room behind, doors about 2.3, sealed. `exteriors` passes.

### 064 · B-coast-3: Bellerive streets, park and harbour dressing
**Approval: you.** **Needs:** 063. Vegetation from the S7/S8 grammars. The ferry stays moored broadside.

### 065 · B-coast-4: Bellerive composition, plus arena and harbour battle backdrops
**Approval: you.** **Needs:** 064. Phone route check. `arena-entry`, `arena-ladder` and `battle-visuals` pass.

### Isle of Tides: Isle Trail, Coral Reef, Shellhaven, Kelpwick, Temple of Tides

### 066 · B-isle-X1a: Isle Trail final layout
**Approval: you.** **Needs:** 045, 046. Finalize the 045 grey-box. The brambles gate stays. Branches: beach cove (Shell Collector), cave mouth (water GIANT cave), hot-spring side path, shortcut loop.

### 067 · B-isle-X1b: Coral Reef layout
**Approval: you.** **Needs:** 066. Coral Reef (the temple road) at 3–4×, with the crayon statue's spot on the main route before the temple, a butterfly glade and sealed reef falls. `tides-walk` passes.

### 068 · B-isle-X2a: the Unreasonably Large Crayon statue
**Approval: you.** **Needs:** 067.
- The statue model blocks the Coral Reef road. **The villagers who stood across the road are removed.**
- Locals say **Kelpwick's elder** put it there to keep Shellhaven's tourists away from the temple, and grumble that any other shape would be easy to move, but a crayon? Impossible.
- After you **beat Kelpwick's arena (Reef Warden Nerissa)**, the elder explains that only a machine that removes crayon-shaped statues can shift it, and that you need some sort of nerd or inventor, strongly hinting at the one in the second city.
- Story flags and hints follow each stage. `kelpwick-huts`, `island-towns` and `flow` pass.

### 069 · B-isle-X2b: Volt's crayon eraser
**Approval: you.** **Needs:** 068.
- **Phoning Mom** after the elder's hint: she says plainly that it's Volt at Sparkwire Electronics in Bellerive.
- **Volt** gives the crayon-statue eraser **for free**, after a goofy scene, as a key item.
- Using it at the statue plays a short erase sequence and opens the road for good.
- Check the phone call flow (`phone`, `phone-save` pass) and the hints.

### 070 · B-isle-X2c: the Shell Collector
**Approval: you.** **Needs:** 066. Shells on the beach, a large empty shell, and arrangement matching the rock markings (touch and keys). Completion summons a **rare merchant critter** (not a wild beast) or reveals a buried item; decide which when the step runs and record it.

### 071 · B-isle-X2d: water GIANT cave, layout
**Approval: you.** **Needs:** 047, 066. A water-focused cave with **lots of the ordinary version** of the giant's species, and the nest chamber.

### 072 · B-isle-X2e: water GIANT, placement and balance
**Approval: you.** **Needs:** 049, 071. Giant strength set against the area's level curve (much stronger, but beatable with a prepared team). Once-only. GIANT egg drop.

### 073 · B-isle-X2f: Isle hot spring and reef butterflies
**Approval: you.** **Needs:** 051, 067.

### 074 · B-isle-1: island and reef palette, ground motif and light
**Approval: you.** **Needs:** 067.

### 075 · B-isle-2: island and reef cliff shapes, shoreline and sealed falls
**Approval: you.** **Needs:** 074. Per-biome `CLIFF_LOOKS`. `tools/check_water.gd` passes.

### 076 · B-isle-3: palms, island vegetation and beach stone
**Approval: you.** **Needs:** 075. Palms without facets. Generous leaf masses in the shared grammar.

### 077 · B-isle-4: Shellhaven resort and Kelpwick huts
**Approval: you.** **Needs:** 076. `island_buildings.gd`. `shellhaven-marina`, `kelpwick-huts`, `island-towns` (each with `-touch`) and `exteriors` pass.

### 078 · B-isle-5: composition and island/reef battle backdrops
**Approval: you.** **Needs:** 077. Phone route check.

### 079 · B-isle-X3: hints, NPC lines, README journey, Temple of Tides rooms
**Approval: you.** **Needs:** 078. Update the README Isle row and the road puzzle table. The temple rooms get a visual pass. `temple-water` passes.

### Desert: Dune Road, Mesa Trail, Dune Sea, Dustwell, Sunwall, Temple of Winds

### 080 · B-desert-X1a: Dune Road layout
**Approval: you.** **Needs:** 046. The rope-ladder cliff gate stays. Branch to the Singing Cactus spot.

### 081 · B-desert-X1b: Mesa Trail layout
**Approval: you.** **Needs:** 080. The rockslide push puzzle stays (cardinal pushes). A ravine for the Fallen Bridge, and the long route round to its winch.

### 082 · B-desert-X1c: Dune Sea layout
**Approval: you.** **Needs:** 081. The Jackals' barricade stays. The Sleeping Statues site on the temple approach, and the air GIANT cave mouth.

### 083 · B-desert-X2a: Singing Cactus behaviour
**Approval: you.** **Needs:** 080. A lone cactus **sings only while you stand beside it facing away**, and stops when you turn. Audio stays inside the existing music and sfx buses.

### 084 · B-desert-X2b: the cactus song
**Approval: you.** **Needs:** 083.
- Learn it on the flute (the existing song-learning flow).
- It's a **new battle song**. Its effect is balanced against the existing songs and proposed in the step for your OK.
- Played in the field, it **makes cacti dance**.
- `beat-attack` and the flute and lesson tests pass.

### 085 · B-desert-X2c: the Fallen Bridge
**Approval: you.** **Needs:** 052, 081. The collapsed rope bridge hangs from one side. Reach the far side by the long route, repair the winch, and get a **permanent shortcut** to the entrance.

### 086 · B-desert-X2d: the Three Sleeping Statues
**Approval: you.** **Needs:** 048, 082. Three stone statues resembling three beast types. Each opens its eyes briefly to the right elemental or creature interaction. All three awake reveals a reward.

### 087 · B-desert-X2e: air GIANT cave, layout
**Approval: you.** **Needs:** 047, 082.

### 088 · B-desert-X2f: air GIANT, placement and balance
**Approval: you.** **Needs:** 049, 087.

### 089 · B-desert-1: desert, western and mesa palettes, motifs and light
**Approval: you.** **Needs:** 041.

### 090 · B-desert-2: desert, western and mesa cliff shapes, plus oasis water
**Approval: you.** **Needs:** 089.

### 091 · B-desert-3: cactus, dry brush and desert rocks
**Approval: you.** **Needs:** 090.

### 092 · B-desert-4: Dustwell's western street and Sunwall's adobe
**Approval: you.** **Needs:** 091. `frontier_builder.gd` and `adobe_town.gd`. Vigas outside only. `dustwell` and `exteriors` pass.

### 093 · B-desert-5: composition and desert/mesa battle backdrops
**Approval: you.** **Needs:** 092. Phone route check.

### 094 · B-desert-X3: hints, README, Temple of Winds rooms
**Approval: you.** **Needs:** 093. `temple-air` passes.

### Mountains: Mine Road, Copperpick, Cogsworth (cyberpunk city)

### 095 · B-mtn-X1: Mine Road layout
**Approval: you.** **Needs:** 046. The checkpoint gate stays. Branches to the mole cave and the earth GIANT cave.

### 096 · B-mtn-X2a: mole cave, layout
**Approval: you.** **Needs:** 047, 095. Earth focus, wild beasts, five mole alcoves with treasure behind each.

### 097 · B-mtn-X2b: the five "third strongest" moles
**Approval: you.** **Needs:** 050, 096.
- Five **mole trainers** (talking critters with small teams). Each insists, in its own silly way, that it is the **THIRD strongest mole**.
- Beating one reveals its treasure. No giant here.
- Draft lines with the local model.
- `battlecmd` passes.

### 098 · B-mtn-X2c: earth GIANT cave, layout
**Approval: you.** **Needs:** 047, 095.

### 099 · B-mtn-X2d: earth GIANT, placement and balance
**Approval: you.** **Needs:** 049, 098.

### 100 · B-mtn-1: mountain palette, cliff shape, conifers and rocks
**Approval: you.** **Needs:** 044. Two steps if needed (100a, 100b).

### 101 · B-mtn-X1b: Cogsworth city layout
**Approval: you.** **Needs:** 042.
- Re-lay Cogsworth as a dense city: blocks, layered streets and plazas.
- Keep Gearhart Tower, the steam gate, the arena, shops and the Beast Center functions, plus door alignment.
- `town_check.py` and `check_maps.gd` pass.

### 102 · B-mtn-4a: Cogsworth building kit, towers and facades
**Approval: you.** **Needs:** 101. Sealed, door scale kept, opaque reflective glass.

### 103 · B-mtn-4b: Cogsworth storefronts and neon signage
**Approval: you.** **Needs:** 102. Shaped emissive within budget. Shop signs readable.

### 104 · B-mtn-4c: Cogsworth street props and lighting
**Approval: you.** **Needs:** 103.

### 105 · B-mtn-X2e: pageant venue in Cogsworth
**Approval: you.** **Needs:** 055, 104. A stage that hooks up steps 053–055, with NPC hosts and a hint.

### 106 · B-mtn-4d: Copperpick mining buildings
**Approval: you.** **Needs:** 100.

### 107 · B-mtn-5: composition, plus mountain and Cogsworth battle backdrops
**Approval: you.** **Needs:** 104, 106. Phone route check (dense city: watch the budget).

### 108 · B-mtn-X3: hints, README (Cogsworth now cyberpunk), Gearhart Tower interiors
**Approval: you.** **Needs:** 107. Update the README region rows and standards.md §18's Steampunk row to cyberpunk.

### Volcano: Caldera Road, Summit Pass, Emberfall, Temple of Flame

### 109 · B-volc-X1a: Caldera Road layout
**Approval: you.** **Needs:** 046. The steam gate and lava stream stay. Branches to the fire cave and the fire GIANT cave.

### 110 · B-volc-X1b: Summit Pass layout
**Approval: you.** **Needs:** 109. The ice sliding puzzle stays (cardinal). A natural hot-spring side path.

### 111 · B-volc-X2a: dark fire cave with torches
**Approval: you.** **Needs:** 048, 109.

### 112 · B-volc-X2b: fire GIANT cave, layout
**Approval: you.** **Needs:** 047, 109.

### 113 · B-volc-X2c: fire GIANT, placement and balance
**Approval: you.** **Needs:** 049, 112.

### 114 · B-volc-X2d: Summit hot springs
**Approval: you.** **Needs:** 051, 110.

### 115 · B-volc-X2e: Temple of Flame dark torch rooms (required)
**Approval: you.** **Needs:** 048.
- Required dark rooms lit by a fire beast's torches. Confirm a fire egg is reachable before (step 046's sheet).
- Lesson-style protections: you can't get stuck without a fire beast; the hint says to bring one.
- `temple-fire` passes.

### 116 · B-volc-1: volcano and hot-spring palettes, motifs and light
**Approval: you.** **Needs:** 044.

### 117 · B-volc-2: cliff shapes, lava flows, steam and hot-spring water
**Approval: you.** **Needs:** 116.

### 118 · B-volc-3: sparse vegetation and volcanic rocks
**Approval: you.** **Needs:** 117. No placed rock-stack spam (memory).

### 119 · B-volc-4: Emberfall buildings
**Approval: you.** **Needs:** 118.

### 120 · B-volc-5: composition and volcano battle backdrops
**Approval: you.** **Needs:** 119. Phone route check.

### 121 · B-volc-X3: hints, README, Temple of Flame visual pass
**Approval: you.** **Needs:** 120.

### Jungle: Jungle Trail, Vinehollow, Temple of Roots

### 122 · B-jung-X1: Jungle Trail layout
**Approval: you.** **Needs:** 046. The Jungle Warden stays. The Monkey Exchange stretch, snake gaps, the vine cliff, a butterfly glade and a hot spring side path.

### 123 · B-jung-X2a: Monkey Exchange, monkeys and the trade chain
**Approval: you.** **Needs:** 050, 122.
- Monkeys block the path, demanding a **bent spoon, a rotten fruit, an old shoe and an empty bottle**.
- Each item comes from another monkey along the path, in a chain of trades. Key items are removed after use. Save flags per monkey.
- The trade order is proposed for your OK.

### 124 · B-jung-X2b: Monkey Exchange, dialogue and the final monkey
**Approval: you.** **Needs:** 123. Goofy lines for each monkey (drafted by the local model). The **final monkey wants nothing** and gives irrelevant relationship advice, then steps aside.

### 125 · B-jung-X2c: snake swings placed
**Approval: you.** **Needs:** 050, 122. Two or three gaps. At least one is required (with a snake you must befriend) and others reach secrets.

### 126 · B-jung-X2d: the Giant Vine
**Approval: you.** **Needs:** 048, 122. A strange vine beside a cliff. Watering it with a **water beast** makes it climb slowly; fully grown, it's a **ladder**. Saved.

### 127 · B-jung-X2e: jungle butterflies and hot spring
**Approval: you.** **Needs:** 051, 122.

### 128 · B-jung-1: jungle palette, motif and filtered light
**Approval: you.** **Needs:** 044.

### 129 · B-jung-2: jungle cliffs, rivers and vines
**Approval: you.** **Needs:** 128.

### 130 · B-jung-3: layered broad foliage
**Approval: you.** **Needs:** 129. Watch overdraw: re-run the phone route.

### 131 · B-jung-4: Vinehollow buildings
**Approval: you.** **Needs:** 130.

### 132 · B-jung-5: composition and jungle battle backdrops
**Approval: you.** **Needs:** 131.

### 133 · B-jung-X3: hints, README, Temple of Roots pass
**Approval: you.** **Needs:** 132. `temple-earth` passes.

### River and moor: Riverbend, Moor Road, Gravenmoor

### 134 · B-moor-X1a: Riverbend road layout
**Approval: you.** **Needs:** 046. A mill beside a waterfall, with two elevations.

### 135 · B-moor-X1b: Moor Road layout
**Approval: you.** **Needs:** 134. The fog bank and sentinel stay, plus the Overly Dramatic Door on the main route and a moor butterfly glade.

### 136 · B-moor-X2a: the Forgotten Waterwheel
**Approval: you.** **Needs:** 052, 134. Restarting the wheel powers a **wooden elevator** between the two elevations. Waterfall sealing rules hold.

### 137 · B-moor-X2b: waterwheel machinery secrets
**Approval: you.** **Needs:** 136. The mechanism turns other machinery that opens small secrets.

### 138 · B-moor-X2c: the Overly Dramatic Door (required)
**Approval: you.** **Needs:** 135.
- A huge stone door with an intimidating face claims only extraordinary wisdom may pass, then asks a riddle answerable only Yes or No (spoken Yes/No: A = Yes, B = No; reply bubbles on desktop; widened A/B on touch).
- It remembers answers across tries. Once you've answered **both** yes and no, it admits it doesn't know the answer and is just lonely, and opens.
- Speech bubbles anchored to the door. `speech`, `speech-touch` and `door-voices` pass.

### 139 · B-moor-X2d: moor butterflies
**Approval: you.** **Needs:** 051, 135.

### 140 · B-moor-1: river palette, banks and freshwater vegetation
**Approval: you.** **Needs:** 044.

### 141 · B-moor-2: Riverbend buildings
**Approval: you.** **Needs:** 140.

### 142 · B-moor-3: Gravenmoor, cathedral and crypt exteriors
**Approval: you.** **Needs:** 040.

### 143 · B-moor-4: composition, plus river and moor battle backdrops
**Approval: you.** **Needs:** 141, 142.

### 144 · B-moor-X3: hints, README, crypt and temple pass
**Approval: you.** **Needs:** 143. `temple-ghost` passes.

### 145 · B-final: element-access and giant-count audit
**Approval: numbers.** **Needs:** all region blocks. 3–5 GIANT caves exist (water, air, earth and fire are planned). Every required element puzzle has earlier egg access. `flow` and `lessons` pass.

---

## Phase C (families)

Use the method approved in 056–061. Split any step by count (about 6 models per session).

### 146 · C7: townsfolk family
### 147 · C8: beastmasters (robes), coaches and Beast Center staff
### 148 · C9: rivals and villains (the Jackals, the Legion, Gearhart's staff)
### 149 · C10: critters consistency pass (snakes, monkeys, moles)
### 150 · C11: biped beasts
### 151 · C12: quadruped beasts
### 152 · C13: flyer beasts
### 153 · C14: serpent beasts
### 154 · C15: blob beasts
### 155 · C16: legendaries and summons (temple guardians)
### 156 · C17: robots
### 157 · C18: ghosts sweep (black and purple with smoke; every family)
### 158 · C19: merge connectors and the generated risk matrix (body kinds × size extremes × limb counts × ghosts)

Every C family step:
- needs **Approval: you**;
- runs `newbeasts --anim=cycle`, `battle-poses`, `beasts` and `beast-growth` (beasts), or `walk`, `speech` and `hero-maker` (people);
- **Offload:** pose-sheet triage ("list any frame where a limb clips through the body or a foot floats").

### 159 · C20: re-render portraits, icons and save placeholders
**Approval: you.** **Needs:** 146–158. `beast_icons.gd`, the item and portrait bakers, then `item-icons` and `item-icons-touch`.

---

## Phase E: every scene

### 160 · E1: scene batches
**Approval:** numbers. **Needs:** 145, 159.
- From `ledger/scenes.csv`, write the remaining batches into this file as 160a, 160b, …: 2–3 maps or 4–6 rooms each, plus every story state that changes geometry.
- Each batch: three cameras, fixes to composition, joins, placement and stale derivatives (murals, ground bakes), both map checkers and `exteriors`. **You approve each batch's contact sheet.**
- **Offload:** whole-sheet triage for voids, floating props and clipping.

### 161 · E2: films
**Approval: you.** One film per step (161a, …): the opening at Gearhart Tower, the prologue, the egg films and the others. They use finished assets; check the dark and misty mood. `intro` and `intro-touch` pass.

### 162 · E3: title, key art and app icon
**Approval: you.** Re-render with `tools/make_key_art.gd`, `tools/key_art.py` and `tools/make_icon.py` in the new direction. Update the README text that describes the icon as PS2 box art. `title-startup*` pass.

---

## Phase U: interface softening (agreed for later)

Keep the structure, layout, inputs and AGENTS.md interface rules: dark blurred windows, white borders, faint gem tint, League Spartan headings and Short Stack body/dialogue. Each step is checked in all four gems × desktop and touch × 1280×720.

### 163 · U1: shared frame and border weight and ornament (`frame_box.gd`, `UIKit`)
**Approval: you.**
### 164 · U2: icon family consistency (items, actions, markers, prompts, rings, shop signs)
**Approval: you.**
### 165 · U3: battle bar finish (structure unchanged)
**Approval: you.**

Run `desktop-audit*`, `polish*`, `top-bar*`, `battle-focus*` and `speech*`.

---

## Phase F: final acceptance

### 166 · F1: full suite, both map checkers, `vo-ledger` (zero unreviewed active entries) and `vo-budget`
**Approval:** numbers. Run the full suite through `server.py` in the background.

### 167 · F2: phone sustained run and the web export route
**Approval:** numbers. Compare with the 002 and 003 baselines in `ledger/perf.md`. Write down what couldn't be tested.

### 168 · F3: side-by-side board
**Approval: you.** Home, sunny route, desert street, Cogsworth at night, industrial battle, haunted area, a cave with a GIANT, a portrait, title and interface. They should differ in mood and clearly be one game.

### 169 · F4: documentation and completion report
**Approval: you.**
- Deliberately refresh `docs/screenshots/`.
- Update README Art, Performance, Controls and the journey.
- Write the completion report (checklist.md "Completion report"): approved and remaining counts for assets, variants, scenes and states; unresolved defects; devices, renderers and presets tested; before/after performance; and any verification that wasn't possible.
