<!-- Generated explicitly by tools/vo_budget.py; never refreshed by tests. -->
# Measured budgets (011)

The hardware requirements are unchanged. The Galaxy A71 is a near-minimum test device, not a new specification.
007's original-phone recovery remains open; its missing measurements are not treated as passes.

## Frame targets and art headroom

| Hardware class | Goal | Frame interval | Work target (20% reserve) |
|---|---:|---:|---:|
| Snapdragon 660 class | 30 fps | 33.333 ms | 26.667 ms |
| Snapdragon 865 class | 60 fps | 16.667 ms | 13.333 ms |
| PC | 60 fps | 16.667 ms | 13.333 ms |

These are goals, not measured guarantees. GPU and CPU timers overlap and must not be summed.
The prior razr 2024 outdoor GPU times are already near/exceed the 30-fps work allowance; no net outdoor art-cost growth is authorized by this ledger.
A71 Mobile/Vulkan produced a device-loss crash; its Compatibility trial is tracked separately, not passed off as a Mobile result.

## Headless structural regression ceilings

The guard counts the entire fixture subtree, including hidden geometry, base-LOD triangles and full batch/particle capacity.
Dummy RenderingServer does not preserve usable MultiMesh transforms/bounds. These limits therefore do not claim in-view draws or GPU cost.
Ceilings use a 5% count tolerance for regression noise; this is not extra rendering headroom or permission to expand art cost.
Texture MiB means declared RGBA8-equivalent with a full mip chain, deduplicated by texture resource, not actual compression/residency.

| Profile / scene | Geometry nodes | Surface submissions | Base source triangles | Materials | Transparent-source surfaces | Texture equivalent MiB |
|---|---:|---:|---:|---:|---:|---:|
| desktop16x9 / coast_battle | 249 | 254 | 102177 | 56 | 28 | 11.73 |
| desktop16x9 / coastal_path | 686 | 705 | 1851129 | 72 | 98 | 16.46 |
| desktop16x9 / cove_plaza | 955 | 1045 | 2663320 | 144 | 134 | 21.81 |
| desktop16x9 / hero_house | 44 | 90 | 21800 | 36 | 0 | 2.83 |
| desktop16x9 / rue_royale | 996 | 1403 | 1947132 | 224 | 516 | 18.08 |
| touch20x9 / coast_battle | 249 | 254 | 102177 | 56 | 28 | 11.73 |
| touch20x9 / coastal_path | 686 | 705 | 1851129 | 72 | 98 | 16.46 |
| touch20x9 / cove_plaza | 955 | 1045 | 2663320 | 144 | 134 | 21.81 |
| touch20x9 / hero_house | 44 | 90 | 21800 | 36 | 0 | 2.83 |
| touch20x9 / rue_royale | 996 | 1403 | 1947132 | 224 | 516 | 18.08 |

## Rendered scene evidence

Static settled start/midpoint/end holds, 120 frames each, Mid/720p. Desktop Mobile remains desktop evidence.
Draws/primitives are renderer totals. Materials/transparent surfaces are conservative source/frustum estimates, not transparent-pass counters.
Texture memory is RenderingServer's process/cache counter at the snapshot, not incremental scene residency; zero means unavailable.

| Renderer / scene | Max median draws | Max median primitives | Max visible source materials | Max transparent-source surfaces | Max texture counter MiB | Max median GPU ms | Max p95 frame ms |
|---|---:|---:|---:|---:|---:|---:|---:|

## Use in later overhaul steps

Every later step must cite this file and its scene/profile. Run vo-budget and vo-budget-touch after structural changes.
Re-measure actual GPU/frame/pacing on the target device before accepting visual growth. A passing headless guard does not certify fps, memory residency, shadow cost, loading, free-play AI or untested shots.
Never regenerate limits to make a failing test pass without reviewing the changed workload and updating its evidence.

Detailed renderer-export verification, A71 stability and unresolved evidence are recorded in ../011-budgets.md.

## Provenance

- `build/perf/vo/011/headless-desktop-01/report.json` — SHA256 `037718bee9f9dafdc6835236c4312a6295960bf18f9fd5ac82238cc63ee54619`
- `build/perf/vo/011/headless-touch-01/report.json` — SHA256 `846d444463eb974ac52340dfc08caf6941b36d5fa2ca7ffff6820b4bd2268c99`
