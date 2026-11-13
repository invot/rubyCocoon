# 006 — batched scenery and visibility

Engineering experiments completed 13 November 2026. Keep the existing **8×8 MultiMeshes**.
No experimental occlusion, distance cutoff, rechunking or merged asset is enabled in gameplay.
The adopted corrections preserve source LOD data when recentering and cover lily-pad shader displacement.
No artwork, collision, movement, building fading, battle sightline hiding or lighting was changed by this step.

## Adopted corrections

`VoxelAssets._recentered()` preserves LOD thresholds/indices, surface names and the existing base channels
and materials. The dedicated check covers 46 meshes / 134 LOD levels, including synthetic translated
meshes with both renderer index widths. **The sampled shipped meshes are already centered**: affected
mesh count is zero on Coastal Path, Cocoon Cove and Rue Royale. The native/phone LOD controls are A/A;
this is defensive correctness, not a measured performance gain.

Lily-pad swell reaches ±(1 + 0.45) × 0.045 = **0.06525 world units** after its shader cancels instance scale.
The shared batch helper now forwards a **0.07-unit margin** to every pad chunk. Static batches keep their
existing bounds. Pad controls have matching draws/primitives on Forward+, desktop Mobile, Compatibility,
Web and actual phone. [Matched desktop views](../../build/shots/vo/006/compare_pads.png) show the same scene;
water/pad animation phase varies. Local-model descriptions of a water-level change were not supported by
the source: no water level or lighting was changed.

## Experiment decisions

All comparisons use control/candidate/control, fixed routes/settings and 240 samples per segment.
Raw reports retain per-frame traces, p95/max, setting metadata, availability and bounds inventories.
Timings below are medians; small changes within the control bracket do not establish a gain.

| Experiment | Evidence and decision |
|---|---|
| 4×4 chunks | More submissions. Desktop Mobile Cove draws 233/272.5/233; phone 284/346/284. Reject. |
| 16×16 chunks | Phone Coastal draws 382.5/271.5/382.5, GPU 30.943/31.477/30.373 ms; Cove 30.473/31.069/29.365 ms. No frame improvement; Web render CPU also increased. Keep 8×8. |
| Engine occlusion | Conservative opaque source triangles shrunk 2%, actual 3D SubViewport enabled; faded/hidden parents disable their occluders and the hero ignores them. Phone Rue draws 266/263/266, render CPU 0.887/1.622/0.928 ms, GPU 30.061/30.097/29.179 ms. Desktop Forward+/Mobile/Compatibility also show small savings with CPU overhead. Reject. |
| Decoration ranges | Only shadowless grass/flowers, nearest full-bounds hysteresis show below 22/hide above 26 units. Phone Coastal tick CPU 0.973/1.750/0.999 ms, unchanged draws; Cove GPU change lies within control drift. Reject this manual fallback. Engine-native alternatives were not exhaustively evaluated. |
| Static Mesh Merger | 13 eligible Creole-house nodes, door kept separate; 32 surfaces → 11. Phone draws 50/26/50, GPU 3.819/3.834/4.401 ms. Position/UV/colour exact, but maximum normal error **0.241678** under nonuniform scale fails the geometry contract. Reject regardless of draw savings. |

Merger source is pinned to `e0de5d302d12ec16161e43bb7afac2e79f0b5aeb`, with MIT license and
reproduction fixture under `tools/experiments/006/StaticMeshMerger/` and `tools/debug/vo_mesh_merger.gd`.
It is not an enabled editor plugin. Build cost was about 2.75 ms desktop / 22.256 ms phone; temporary
source and result coexist during the fixture, so no production memory/load saving is claimed. No generated
mesh collision was introduced; tile rules remain unchanged. Rejected candidates need no visual approval.

## Platforms and accepted evidence

Raw evidence is under `build/perf/vo/006/`, with native matched views in `build/shots/vo/006/`.
Accepted native attempts: `mobile-lod-03`, `mobile-chunks4-01`, `mobile-pads-01`, `compat-pads-01`,
`forward-pads-02`, `touch-pads-02`, `mobile-occlusion-03`, `compat-street-05`, `forward-street-05`,
`mobile-distance-02`, `compat-distance-02`, `forward-distance-02`, `touch-distance-01`,
`compat-merger-02`, `forward-merger-03`. Desktop Mobile is **desktop evidence**, not a phone proxy.
Native 16×16 attempts lost focus and are excluded; complete phone/Web comparisons supply that evidence.
Invalid/incomplete attempts remain on disk and must not be pooled with accepted traces.

**Actual phone:** `build/perf/vo/006-suite/phone/`, razr 2024, Android Mobile renderer, Mid,
1760×720, reported refresh 60 Hz, cap 60, VSync on. Three passes, **753.3 seconds**, zero reported
problems/focus losses. Field medians ~33.3–33.7 ms (~30 fps); isolated fixture ~16.7 ms.
Temperature samples peaked at 29.9°C; this does not establish sustained thermal headroom or 60 fps.
The frozen APK SHA256 is `25281ac230d6a2160b70330604a138b4bb3f2cc90fc257430a479410e7cee8b6`.
87 PNGs recovered to `build/shots/vo/006/phone-suite/`; raw private benchmark files are archived locally.
Player package paths match before/after, cleanup succeeded and only temporary `com.rubycocoon.vo_perf`
was uninstalled. Player saves/settings and lock settings were not changed.

**Web:** `build/perf/vo/006/web_01/`, three validated passes, Compatibility, render size 1099×1080,
browser viewport 890×875 CSS pixels. This is a narrow browser stress test, not landscape/1920-wide evidence.
GPU queries are unavailable (zeros are not zero GPU cost). Console explicitly reports
`Occlusion culling is disabled at build-time`: the requested true property is inert on this template.
Web occlusion is **unsupported**, not a successful optimization test. The final console could not be
re-read after the temporary browser tab closed; absence of post-report audio errors is not established.

**Desktop field gate:** focused paced `field-02` has one 20.113 ms maximum, so that attempt misses the
20 ms criterion. Frozen-pack `field-pack-01` runs VSync off, 240/240 focused samples on each of Cove,
Rue and Cogsworth; maxima **3.864 / 3.486 / 3.278 ms** (720 total samples). It satisfies the unpaced
render-headroom check, not a guarantee about presentation pacing, current concurrent artwork or phone fps.
The pack is `build/web_perf_006_01/index.pck`; commands/logs/validation are retained alongside the report.

## Bounds and verification limits

Inventories cover 485/681/378 scenery batches and 1600/2426/1718 instances in Coastal/Cove/Rue.
Their transformed-source union matches renderer AABBs; no static underbounds or >10% oversizing was found.
Pad overlays show static versus swell bounds. The native Mobile occlusion-buffer capture is
`build/shots/vo/006/occlusion-debug-02/pass_02/tidewater_occlusion_1_occluders_debug.png`;
it shows the conservative building silhouettes. This short `verify=1` run is render-only evidence,
not an accepted timing run (three samples per segment). Water already reserves 0.1 units; foliage has no vertex
displacement, terrain holes are fragment-only. Existing dust/title-animation bounds were inspected in source.
This is not an exhaustive swept animation audit of every effect. Renderer AABBs cannot be validated headless.
Chunk LOD selection changes along with group culling, so primitive differences are not pure frustum savings.
The occluder fixture covers initially built buildings on a short dense street; it is not a production dynamic
occluder lifecycle implementation. No range system reaches battle props, edge seals, landmarks or interactables.
Because ranges/merger/occlusion are rejected, production directed battle shots retain their existing behavior.

Final current-checkout tests through `server.py`: **all 10 pass** (`scenery-lods`, the five scenery/merger
smoke checks, `nature`, `walk`, `building-fade`, `maps-built`), 44 seconds. Earlier quick compilation/data
checks also pass in nine seconds (`build/vo006-final-quick-resumed.json`). The local model supplied code indexing, a diff
triage and first screenshot descriptions; all consequential claims were checked against source/numeric data.
No combined optimization candidate survives: combined verification therefore covers the two correctness fixes.
Further optimization remains measurement-driven; this step does not promise that every performance target is met.
