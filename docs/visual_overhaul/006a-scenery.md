# 006a — scenery bounds, chunk sizing and retained LODs

Engineering checkpoint, 12 November 2026. **In progress**; parent 006 remains open.
No chunks, distance cutoffs, engine occlusion setting or merged production assets have been adopted.

## Scope and corrections

The world already groups repeated meshes into 8×8-tile MultiMeshes. The experiments preserve transforms,
material identities, shadow flags, layers, LOD bias and cull margins; they do not alter map collision.
Chunk trials measure the combined effects of group culling and Godot's mesh-LOD selection, not just node counts.

The recentering helper copied base arrays but omitted source LOD indices/thresholds. It now preserves them,
including the renderer's 16- and 32-bit index formats. The focused check covers 46 meshes / 134 LOD levels,
base attributes and material identity, with synthetic offset meshes exercising both index widths.
**Correction to the initial diagnosis:** finding LODs in the oak source did not establish that its runtime
copy loses them. The sampled source origins are already centered; all three scene inventories report zero
affected cached meshes. The valid original/restored/original runs are consequently A/A controls, not gains.

The shader audit found an actual culling-bound gap: `lily_pad.gdshader` applies
`water_swell * 0.045 / instance_y_scale`; the shared swell is the sum of sine terms weighted 1 and 0.45.
Its displacement is bounded by ±0.06525 world units regardless of leaf scale. Pad batches formerly had no
margin. The shared batch helper now propagates a 0.07-unit `extra_cull_margin` to every pad chunk.
Other categories retain zero additional margin. Water terrain already has a 0.1-unit margin for the same
maximum swell. The foliage shader does not displace vertices. Terrain dithering remains fragment-only.

## Evidence collected so far

- `build/perf/vo/006/mobile-lod-03/`: accepted desktop Mobile A/A control, three maps and three passes.
- `build/perf/vo/006a/phone/`: accepted razr 2024 Mobile control, 195.2 seconds, 720p/Mid;
  no problems/focus losses, 30.9°C at each temperature sample. The player's package identity is preserved;
  temporary `com.rubycocoon.vo_perf` was uninstalled after recording.
- `build/perf/vo/006/mobile-chunks4-01/`: accepted 8/4/8 comparison. The candidate increases draw and
  render-CPU submissions, without consistent GPU benefit; keep 8×8 pending the other experiments.
- `build/perf/vo/006/mobile-pads-01/`, `compat-pads-01/`, `forward-pads-02/`: accepted pad-margin controls.
  Draws and primitives match; no material or geometry change. Desktop Mobile is desktop evidence.
- Interrupted/superseded attempts retain their raw reports/logs and invalid markers. They are excluded from
  accepted comparisons. The first LOD attempt also stripped more meshes than the actual recenter branch;
  it cannot establish a gain. Later controls restrict stripping to affected mesh identities.

The current bounds inventory compares each batch's rendered AABB with the union of its transformed mesh
bounds: Coastal Path 485 batches / 1,600 instances; Cove 681 / 2,426; Rue Royale 378 / 1,718.
No static underbounds or >10% oversized volumes were found. This is not an exhaustive animation/effect audit.
Renderer bounds are unavailable headless; headless tests do not claim to check them.

## Reproduction and verification

`python tools/vo_scenery.py desktop --part=chunks4 --renderer=mobile --attempt=<new-name>` runs the comparison
under the shared resource lock. Parts `chunks16`, `lod`, `pads`, `occlusion`, `distance` and `merger` keep the
experiments separate. Reports contain raw traces, effective settings and per-experiment inventories;
the Python reader validates traces/summaries, route and settings consistency, three controls and focus.
Use isolated saves/preferences exactly as the runner supplies. See its command JSONs for accepted runs.

Early checks through `server.py`: quick, nature, scenery-lods, vo-scenery, walk, building-fade and maps-built pass.
Pad/occlusion/distance and isolated-merger headless smoke checks pass. Final checks and outstanding evidence
are still required before closing this checkpoint or parent 006.

Local-model help: a focused code index and a first-pass typo/unused-variable diff triage. Source inspection
confirmed the useful index; correctness, LOD buffers and bounds calculations were reviewed directly.
