# Step 004 — cost diagnosis

Completed 12 November 2026. Analysis and opt-in diagnostic tooling only; production rendering and artwork are unchanged.
The accepted 001–003 baselines remain authoritative. Generated numbers are in
`build/perf/vo/004/tables.md` and `summary.json` (regenerate with `python tools/vo_cost_summary.py`).

## Method and evidence

- Read AGENTS, the parallel handoff, progress, all three baseline reports, performance ledger, README Art/Mobile/test modes,
  runbook procedure and existing performance audit before changing the harnesses.
- `python tools/vo_cost.py --renderer mobile`, then `--renderer gl_compatibility` and `--renderer forward_plus`:
  real desktop windows, 1920×1080, 1080p/Mid, identical fixed-seed route, isolated state under `build/vo_state/004/`.
  Each job acquires the shared model/artwork lock. These are additional diagnostic runs, not repeated baselines or phone results.
- `python tools/vo_cost.py --build`: verified headless phase-by-phase construction of route1, caccoon, caccoon#1 and tidewater.
  The earlier `build-profile.json` is retained but excluded: PowerShell redirection produced an empty stdout log.
  `build-profile-verified.json/.log` use Python subprocess capture and contain the completion marker and no script errors.
- Opt-in `--diagnose=1` inventories happen outside frame sampling, at each segment's end. Whole-tree and end-frustum counts
  are separate. Existing start/mid/end inventories remain unchanged. Script probes are isolated repeated method calls after
  sampling, following the existing field-perf method; **not an inclusive per-frame profiler**, and not additive costs.
- Final quick checks (scripts/data/maps/beasts) and separate vo-perf-route check passed via server.py. The quick alias ignores
  additional named selections, so the route was explicitly run separately. Python compilation and summary invariants passed.
  All three windowed runs completed with zero benchmark problems/focus losses; existing shutdown ObjectDB warnings remain.

Two pre-existing Godot processes outside the coordination protocol were observed (a retained Kelpwick preview and a headless
lesson inspector). Neither was terminated. Their activity was not quantified. Fresh desktop timings are descriptive, not clean
comparative speedup evidence. Resource counts and the accepted target baselines drive the decisions below.

## Findings

**Phone steady state:** accepted outdoor GPU medians are 28.73 ms Coastal Path, 26.33 ms Cove and 23.86 ms Rue Royale,
against shared-tick medians 3.16, 3.50 and 5.50 ms. Prioritize GPU workload and then Rue Royale CPU work. These counters overlap;
do not sum them. House/battle GPU medians are only 15.41/15.21 ms while frame intervals remain about 33 ms. Frame pacing,
presentation or other unmeasured work therefore needs investigation; reducing scenery alone cannot be promised to restore 60 fps.
The fixture freezes roaming/input/story work, so it does not establish the CPU cost of ordinary free play.

**Material premise corrected:** the finish pass edits existing materials in place; it does not allocate a material per surface.
End-view finished surfaces/distinct finished materials on desktop Mobile are 8/6 Coastal Path, 5/4 Cove, 54/23 house,
26/4 Rue Royale and 114/1 battle. Whole-tree distinct materials are respectively 65, 106, 34, 158 and 53, including hidden
buildings and actor materials. The historical “14,500 surfaces” figure is not a count of unique material resources.
Existing caches in house_models, cove_buildings, room_builder and voxel_props already reuse materials/meshes. Exact duplicate
eligibility must precede further caching; fading copies and independently animated materials cannot be indiscriminately merged.
Tint uniqueness is not shader-variant uniqueness.

**Draw workload by node type:** generated tables report surface submissions, not renderer pass-level draws. In the end views,
Coastal Path has 59 MeshInstance/175 MultiMesh surfaces, Cove 35/43, house 85/0, Rue Royale 105/90 and battle 212/19.
The global draw-call baselines are recorded separately. Visibility, LOD, instancing and shadow/depth passes prevent converting
those submissions into exact draw calls by node type. A GPU capture would be needed for that attribution; it was not collected.
`world.gd` already batches repeated scenery in 8×8 chunks. Step 006 must target residual repetitions/LOD visibility, not replace it.

**Transparency:** no BaseMaterial alpha-blended surfaces occur in those four field end views. They have 2, 13, 3 and 1 scissor
surfaces; custom ALPHA sources contribute 4, 1, 0 and 2 (principally water/contact shadows). Foliage's shader writes no ALPHA;
grass is solid geometry, not the blended card forest assumed by the old plan. Hidden arrival-fade copies inflate whole-tree
blend counts and must not be counted as visible overdraw. Battle has 25 blended surfaces plus one custom ALPHA source;
these include intentional effects. Source classification is conservative and does not measure covered pixels or draw-pass duration.
Overlay passes can make material-mode counts exceed mesh surface counts. Keep intentional water, contact shadows and effects.

**Shadows/lights:** frustum-eligible shadow-node counts are 70 Path, 28 Cove, 39 house, 47 Rue Royale and 41 battle.
This counts nodes, not triangles/instances or off-frustum casters affecting the image. Field outdoors has two visible light nodes,
one shadow-enabled; house and battle have four, one shadow-enabled. A “many local lights” explanation is unsupported for these
fixtures. Existing grass/flowers/interior-woodland suppression and two-split sun remain in place. Quantify shadow GPU contribution
with a controlled toggle before changing budgets. Battle casters need actor/scenery attribution before claiming a policy violation.

**Scripts:** endpoint desktop Mobile microprobe medians peak at 0.0505 ms `_animate_npcs` (Rue Royale), followed by
0.007 ms `_fade_buildings` there. `_place_camera` is 0.001–0.002 ms; unchanged-position `_update_hole` and frozen `_update_wilds`
are near timer resolution. These latter probes exercise cached/frozen paths, not moving or roaming cost. They are leads only.
The accepted full-route tick medians, especially the phone's Rue Royale 5.50 ms, are the stronger evidence. No script rewrite in 004.

**First sight:** new Forward+ arrival deltas (canvas/draw/mesh/specialization/surface) are 2/16/53/24/39 Path,
0/10/2/11/7 Cove, 0/10/6/12/11 house and 0/0/15/0/2 Rue Royale. These are pipeline events, **not compile milliseconds or
distinct shader source counts**, and categories are not summed. Compatibility exposes these counters as all zero despite
23.26 s Path and 5.54 s Cove black holds in this diagnostic run: zero is unavailable/non-informative here, not zero compilation.
The first Mobile diagnostic began before pipeline instrumentation was added and has no pipeline deltas; do not infer any.
Feature keys use existing VT._kind_of plus custom shader paths; anonymous custom shaders share an empty path, so the feature
inventory is a coarse grouping, not an exact shader-variant ledger. No GPU capture or compiler-time trace was collected.

`_warm_shaders` deduplicates **mesh RID plus overrides**, stops at 400 entries and schedules three draws before removal.
That is not a deduplicated shader-feature set. `_load_world` separately waits for script loading, map construction, surface
finishing, wilds, first-battle/audio prewarm and arrival preparation; `_do_goto` then draws twice behind black. Transition totals
alone cannot isolate compilation from those phases. Desktop Compatibility is the highest first-visit priority; Web's cache-warm
1.90/1.60/0.42/2.85 s first-pass numbers cannot be equated with those native cold-process numbers or production downloads.
Retain Web's post-report SampleNode._pause TypeError as unresolved audio shutdown work.

**Loading construction:** verified CPU-only totals are 307.9 ms Path, 426.8 ms Cove, 61.7 ms house and 529.7 ms Rue Royale.
Largest phases: Path scatter 141.5 ms; Cove all buildings 111.9 ms/street props 89.6 ms; house room 40.2 ms;
Rue Royale backdrop 175.8 ms/buildings 103.5 ms. Final explicit finish traversals cost 0.208–4.084 ms, but earlier automatic
finish work is included inside construction. These manual headless builds omit normal cooperative budgets, first draw, warm-up,
audio and battle prewarm, and cannot be subtracted from a different run's black-screen time. Ground is already baked/cached.

## Ranked causes, targets and estimated savings

Savings below are **planning scenarios**, not measured improvements, confidence intervals or additive claims. Zero remains a
possible outcome until a controlled before/after run establishes the effect. No promise of 60 fps follows from a scenario.

| Priority | Target / scene | Evidence-backed concern | Estimate / ceiling for a candidate fix | Follow-up |
|---|---|---|---|---|
| 1 | Desktop Compatibility first visits, then Web/phone loading | Seconds of black hold; warm-up keyed by mesh; headless construction much shorter on desktop | Aim to remove 50–80% of native first-visit holds (Path ~12–19 s of 24.15 s baseline), a hypothesis requiring phase traces; no Web/phone multiplier inferred | 009a phase attribution, 009b warm-up/cache changes |
| 2 | Phone Coastal Path, Cove, Rue Royale GPU | 28.73 / 26.33 / 23.86 ms GPU; solid foliage and existing batches | A 15–30% workload reduction would be ~4.3–8.6 / 3.9–7.9 / 3.6–7.2 ms GPU. Which passes deliver it is unmeasured | 010 resolution/pacing experiment, 008 shadows, 006 residual geometry |
| 3 | Phone all scenes, especially house and battle | ~33 ms frame with ~15 ms GPU even in smaller scenes | Up to ~16.6 ms interval improvement if a genuine half-rate pacing cause is fixed; presently **unproven**, no guaranteed gain | 010a pacing/resolution measurement before selecting a fix |
| 4 | CPU loading: Path / Cove / Rue Royale / house | Scatter / buildings+street props / backdrop / room construction dominate manual build | A 25% reduction of those largest phases models ~35 / 50 / 44 / 10 ms desktop CPU respectively; does not explain seconds of first draw | 009a separate construction and first-draw work; retain responsiveness/caches |
| 5 | Phone Rue Royale shared tick; desktop all scripts lower priority | 5.50 ms phone tick versus <=0.44 ms accepted desktop tick | A 25% improvement models ~1.38 ms phone tick, capped by actual function share; cached endpoint probes do not identify that share | 006 audit visibility/update workload before rewriting scripts |
| 6 | Materials across all scenes | Already shared, only 34–68 distinct materials in many baseline views | No defensible nonzero ms estimate; ceiling is the measured render CPU, not total frame time. Exact duplicate counts set any resource target | 005a eligibility audit; 005b only proven safe duplicates |
| 7 | Transparent field scenery/local lights | No blended BaseMaterial surfaces in field endpoint views; one shadow light | Near-zero gain expected from blanket alpha-scissor conversion or light-count pruning in these fixtures. Battle overlay/hidden-copy exceptions need attribution | 007 targeted audit; preserve intentional effects |

For a pixel-bound upper-bound model, 720p→540p reduces pixel count by 43.75%; applying that fraction to *all* phone GPU time
would give ~12.57/11.52/10.44 ms outdoors. This is deliberately optimistic: geometry, CPU, shadow maps, fixed work and pacing
do not scale with viewport pixels. Step 010a must measure the real effect rather than adopting this as a prediction.

## Order, ownership and limitations

Runbook now splits 005 into cheap exact-duplicate eligibility (005a) and conditional implementation (005b), 009 into loading
attribution (009a) and changes (009b), and 010 into resolution/pacing measurement (010a) and visual resolve (010b).
Execution: **005a → 009a → 010a → 005b if justified → 009b → 010b → 008 → 006 → 007 → 011**.
All prerequisite arrows are explicit in the runbook. Visual changes still stop for actual before/after game screenshots and user
approval; diagnostic candidates never authorize production changes. No numbered art step or candidate integration is advanced.

The local model summarized build-profile. Its claim that per-building timing required `--buildings=1` was wrong (that flag only
prints detail), and it invented absent streaming/multiplayer concerns. Source inspection overrode these. It correctly identified
construction phases; exact timings/rankings come from Python, not its prose. No immutable READY.json broadleaf delivery was present
at the review check; inspected source previews are not a candidate delivery and were not reviewed or modified.

No commits, branches, resets, player-save writes, smoothing/import changes or production asset replacements were made.
