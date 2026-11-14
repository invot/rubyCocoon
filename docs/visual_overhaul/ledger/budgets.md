<!-- Generated explicitly by tools/vo_budget.py; never refreshed by tests. -->
# Measured budgets (011)

The hardware requirements are unchanged. The Galaxy A71 is a near-minimum test device, not a new specification.
010c's beta3 migration and 007's measured no-op are complete. These limits use the adopted engine and regenerated ground.
Engine: 4.8-beta3 (official); hash `c51ff06e8836a70ea905701c081bf94124dcd6ce`; ground generator `d62622bf8c32a0047becafabb3018beb`.

## Frame targets and art headroom

| Hardware class | Goal | Frame interval | Work target (20% reserve) |
|---|---:|---:|---:|
| Snapdragon 660 class | 30 fps | 33.333 ms | 26.667 ms |
| Snapdragon 865 class | 60 fps | 16.667 ms | 13.333 ms |
| PC | 60 fps | 16.667 ms | 13.333 ms |

These are goals, not measured guarantees. GPU and CPU timers overlap and must not be summed.
The prior razr 2024 outdoor GPU times are already near/exceed the 30-fps work allowance; no net outdoor art-cost growth is authorized by this ledger.
A71 Mid/720p Mobile/Vulkan has recorded device loss; Min sustained controls pass but miss 30 fps outdoors. Compatibility is not a measured performance solution.
Performance debt remains open. Structural ceilings freeze today's cost; they do not certify the frame targets or authorize added art cost.

## Headless structural regression ceilings

The guard counts the entire fixture subtree, including hidden geometry, base-LOD triangles and full batch/particle capacity.
Dummy RenderingServer does not preserve usable MultiMesh transforms/bounds. These limits therefore do not claim in-view draws or GPU cost.
Ceilings use a 5% count tolerance for regression noise; this is not extra rendering headroom or permission to expand art cost.
Texture MiB means declared RGBA8-equivalent with a full mip chain, deduplicated by texture resource, not actual compression/residency.

| Profile / scene | Geometry nodes | Surface submissions | Base source triangles | Materials | Transparent-source surfaces | Texture equivalent MiB |
|---|---:|---:|---:|---:|---:|---:|
| desktop16x9 / coast_battle | 249 | 254 | 102177 | 56 | 28 | 11.99 |
| desktop16x9 / coastal_path | 677 | 696 | 1844023 | 73 | 97 | 17.86 |
| desktop16x9 / cove_plaza | 958 | 1040 | 2687887 | 143 | 121 | 21.63 |
| desktop16x9 / hero_house | 41 | 86 | 21149 | 31 | 0 | 4.58 |
| desktop16x9 / rue_royale | 996 | 1400 | 1956960 | 218 | 508 | 18.87 |
| touch20x9 / coast_battle | 249 | 254 | 102177 | 56 | 28 | 11.99 |
| touch20x9 / coastal_path | 677 | 696 | 1844023 | 73 | 97 | 17.86 |
| touch20x9 / cove_plaza | 958 | 1040 | 2687887 | 143 | 121 | 21.63 |
| touch20x9 / hero_house | 41 | 86 | 21149 | 31 | 0 | 4.58 |
| touch20x9 / rue_royale | 996 | 1400 | 1956960 | 218 | 508 | 18.87 |

## Rendered scene evidence

Static settled start/midpoint/end holds, 120 frames each, Mid/720p. Desktop Mobile remains desktop evidence.
Draws/primitives are renderer totals. Materials/transparent surfaces are conservative source/frustum estimates, not transparent-pass counters.
Texture memory is RenderingServer's process/cache counter at the snapshot, not incremental scene residency; zero means unavailable.

A zero GPU timer means unavailable, especially on Web; it does not mean zero GPU cost.

| Runtime / renderer / scene | Max median draws | Max median primitives | Max visible source materials | Max transparent-source surfaces | Max texture counter MiB | Max median GPU ms | Max p95 frame ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| editor / forward_plus / coast_battle | 223.0 | 141258 | 48 | 26 | 251.94 | 0.717 | 1.586 |
| editor / forward_plus / coastal_path | 316.0 | 340789 | 45 | 16 | 144.86 | 1.289 | 1.841 |
| editor / forward_plus / cove_plaza | 343.0 | 329671 | 57 | 5 | 154.93 | 1.275 | 1.867 |
| editor / forward_plus / hero_house | 168.0 | 40838 | 29 | 0 | 156.90 | 0.560 | 1.099 |
| editor / forward_plus / rue_royale | 335.0 | 313652 | 40 | 5 | 162.47 | 1.211 | 1.824 |
| editor / mobile / coast_battle | 342.0 | 141258 | 48 | 26 | 203.94 | 0.475 | 1.635 |
| editor / mobile / coastal_path | 316.0 | 340789 | 45 | 16 | 130.86 | 1.104 | 1.777 |
| editor / mobile / cove_plaza | 285.0 | 329671 | 57 | 5 | 139.80 | 1.134 | 1.733 |
| editor / mobile / hero_house | 84.0 | 40838 | 29 | 0 | 142.90 | 0.249 | 0.820 |
| editor / mobile / rue_royale | 290.0 | 313652 | 40 | 5 | 147.35 | 1.037 | 1.574 |
| editor / gl_compatibility / coast_battle | 347.0 | 141258 | 48 | 26 | 129.58 | 0.565 | 1.287 |
| editor / gl_compatibility / coastal_path | 338.0 | 340789 | 45 | 16 | 89.04 | 1.157 | 1.898 |
| editor / gl_compatibility / cove_plaza | 355.0 | 329671 | 57 | 5 | 95.87 | 1.118 | 1.647 |
| editor / gl_compatibility / hero_house | 170.0 | 40838 | 29 | 0 | 99.81 | 0.422 | 0.785 |
| editor / gl_compatibility / rue_royale | 431.0 | 313652 | 40 | 5 | 102.60 | 1.034 | 1.496 |
| Windows export / forward_plus / coast_battle | 223.0 | 141258 | 48 | 26 | 251.94 | 0.712 | 1.971 |
| Windows export / forward_plus / coastal_path | 316.0 | 340789 | 45 | 16 | 144.86 | 1.270 | 2.645 |
| Windows export / forward_plus / cove_plaza | 343.0 | 329671 | 57 | 5 | 154.93 | 1.274 | 2.686 |
| Windows export / forward_plus / hero_house | 168.0 | 40838 | 29 | 0 | 156.90 | 0.572 | 1.615 |
| Windows export / forward_plus / rue_royale | 335.0 | 313652 | 40 | 5 | 162.47 | 1.207 | 2.534 |
| Windows export / gl_compatibility / coast_battle | 347.0 | 141258 | 48 | 26 | 130.08 | 0.569 | 1.287 |
| Windows export / gl_compatibility / coastal_path | 338.0 | 340789 | 45 | 16 | 89.54 | 1.145 | 1.614 |
| Windows export / gl_compatibility / cove_plaza | 355.0 | 329671 | 57 | 5 | 96.37 | 1.090 | 1.536 |
| Windows export / gl_compatibility / hero_house | 170.0 | 40838 | 29 | 0 | 100.31 | 0.415 | 0.739 |
| Windows export / gl_compatibility / rue_royale | 431.0 | 313652 | 40 | 5 | 103.10 | 1.016 | 1.466 |
| Web export / gl_compatibility / coast_battle | 330.0 | 127828 | 48 | 26 | 118.50 | 0.000 | 17.000 |
| Web export / gl_compatibility / coastal_path | 333.0 | 340789 | 45 | 16 | 79.75 | 0.000 | 16.900 |
| Web export / gl_compatibility / cove_plaza | 350.0 | 329329 | 57 | 5 | 86.54 | 0.000 | 16.900 |
| Web export / gl_compatibility / hero_house | 170.0 | 40838 | 29 | 0 | 90.40 | 0.000 | 17.600 |
| Web export / gl_compatibility / rue_royale | 431.0 | 313336 | 40 | 5 | 93.19 | 0.000 | 17.000 |

## Device evidence

One settled pass establishes this fixture's counts and observed costs, not sustained thermal stability.
A71 sustained stability and Mid-profile device-loss findings remain separately recorded in 010c/011.

| Device / renderer / profile / scene | Max median draws | Max median primitives | Materials | Transparent-source surfaces | Texture counter MiB | Max median GPU ms | Max p95 frame ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| SM-A715F / mobile / min 540p / coast_battle | 321.0 | 81464 | 48 | 26 | 99.82 | 20.962 | 47.788 |
| SM-A715F / mobile / min 540p / coastal_path | 266.0 | 228963 | 46 | 16 | 67.91 | 53.843 | 64.773 |
| SM-A715F / mobile / min 540p / cove_plaza | 205.0 | 173256 | 59 | 6 | 76.22 | 57.295 | 68.647 |
| SM-A715F / mobile / min 540p / hero_house | 65.0 | 20571 | 29 | 0 | 80.35 | 11.642 | 34.834 |
| SM-A715F / mobile / min 540p / rue_royale | 221.0 | 231927 | 43 | 5 | 84.12 | 50.524 | 61.338 |

## Use in later overhaul steps

Every later step must cite this file and its scene/profile. Run vo-budget and vo-budget-touch after structural changes.
Re-measure actual GPU/frame/pacing on the target device before accepting visual growth. A passing headless guard does not certify fps, memory residency, shadow cost, loading, free-play AI or untested shots.
Never regenerate limits to make a failing test pass without reviewing the changed workload and updating its evidence.

Detailed renderer-export verification, A71 stability and unresolved evidence are recorded in ../011-budgets.md.

## Provenance

- `build/perf/vo/011/beta3-headless-desktop-01/report.json` — SHA256 `6b57f7a1200289d9741b3f7615ba765c7f4e4fe98cc8ca76cfea1b4691774104`
- `build/perf/vo/011/beta3-headless-touch-02/report.json` — SHA256 `cf737f8b05c794cebcf8b746507a0d046601b2267134976ec8ad2e99fccadd3a`
- `build/perf/vo/011/beta3-forward-01/report.json` — SHA256 `10fa889a5569f83b386714238ebec89e5a92007618e245bc7fa75888caf5db85`
- `build/perf/vo/011/beta3-mobile-01/report.json` — SHA256 `4ed17a756aae2cb274543bd2687ebab21a1b7aeece6c85187f7760df480b57bf`
- `build/perf/vo/011/beta3-compat-01/report.json` — SHA256 `fce786b259cea6f9d58602c085ded106691379132827370ac7e32a69d1d1bd09`
- `build/perf/vo/011/beta3-export-forward-01/report.json` — SHA256 `9a2fa6a1e3a3cb5457fba132b75eb9ba075a06dc413a05c63f77bdd059812cb9`
- `build/perf/vo/011/beta3-export-compat-02/report.json` — SHA256 `df4eb1334fe10bf99cadafe24cbe54c6652efab28a8101e56314fa7a007d2c2e`
- `build/perf/vo/011/beta3-web-01/report.json` — SHA256 `0b0012b56f39418dd041a7c80c27a89bf2cdad6e51f9d9c8164c4537656ed75b`
- `build/perf/vo/011/beta3-a71-min-540-01/report.json` — SHA256 `ad28ea9a39731b3e5b7e1c5f242f82507104a95268f84917331807c210cd6154`
