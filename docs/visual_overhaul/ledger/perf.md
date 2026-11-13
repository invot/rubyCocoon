# Performance baselines

## Desktop

Step 001: Windows, Ryzen 7 9700X / Radeon RX 9060 XT, Godot 4.7. Forward+, Mobile and Compatibility at 1920×1080, plus Mobile touch at 2400×1080, 1080p / Mid. Eight accepted fresh-process runs; largest segment median repeatability difference 0.123% (5% gate). Frame intervals are VSync paced near 16.68 ms. [Full method and measurements](../001-performance.md).

## Phone

Step 002, 12 November 2026: Motorola razr 2024, Android 16, MT6878 / Mali-G615 MC2, Vulkan Mobile, Godot 4.7 debug APK, 720p / Mid. Physical 2640×1080 landscape, 3D 1760×720. Seven loops, 993.36 s, no focus losses or benchmark errors. Battery 30.7–31.9°C, AC charging at 100%; 339.37 s temperature-sampling gap recorded. CPU/GPU clocks were not collected. No Snapdragon 660/865 reference devices were measured. Medians stay near 29–30 fps, so the 60 fps target is not achieved in this baseline.

| Segment | First median ms | Last median ms | Last p95 / p99 ms | Last median fps |
|---|---:|---:|---:|---:|
| coast_battle | 34.43 | 34.03 | 41.48 / 49.18 | 29.4 |
| coastal_path | 33.70 | 33.60 | 50.36 / 50.80 | 29.8 |
| cove_plaza | 33.35 | 33.40 | 49.91 / 50.48 | 29.9 |
| hero_house | 33.23 | 33.27 | 34.02 / 34.73 | 30.1 |
| rue_royale | 33.30 | 33.34 | 46.66 / 47.79 | 30.0 |

| Map transition | First black ms | Last black ms |
|---|---:|---:|
| route1 | 18898.9 | 539.6 |
| caccoon | 7020.1 | 707.9 |
| caccoon#1 | 2199.3 | 100.1 |
| tidewater | 4291.4 | 1052.1 |

[Full phone method, fixes, evidence and limitations](../002-phone.md).

## Web

Step 003, 12 November 2026: built-in desktop Chromium, Godot 4.7 release,
Compatibility / WebGL 2, single-threaded, 1080p/Mid. Engine window 1615×772,
3D viewport 2259×1080. Two passes / 161.61 s, zero harness errors/focus losses.

| Map | First pass black ms | Return black ms |
|---|---:|---:|
| Coastal Path | 1898.7 | 215.0 |
| Cocoon Cove | 1597.2 | 375.4 |
| Hero's house | 416.7 | 191.6 |
| Rue Royale | 2852.4 | 594.1 |

Segment medians 16.5–16.7 ms (about 60 fps); return p99s 16.8–24.0 ms. First-pass
Rue Royale maximum 292.2 ms. First means first in the accepted instance: browser
HTTP/driver caches were not cleared after a partial packaging preflight. This is
not a cold-install or compressed production download measurement. One audio
`SampleNode._pause` TypeError occurred after final report save; no GDScript or
missing-music errors in the accepted run. Quick + route checks passed.

[Full Web method, evidence and limitations](../003-web.md).

## Diagnosis

Step 004 completed 12 November 2026. [Ranked causes, estimated savings, source audit and limits](../004-cost-diagnosis.md).
Exact numerical tables are generated with `python tools/vo_cost_summary.py` into `build/perf/vo/004/tables.md`;
raw/derived JSON, logs and quick/route results live beside them. No production rendering change.

| Rank | Cause / affected target | Evidence and saving estimate | Next investigation |
|---|---|---|---|
| 1 | First-visit work, desktop Compatibility; Web/phone follow | Seconds of black hold; 50–80% reduction is a planning hypothesis, not an observed saving | 009a phase attribution |
| 2 | Outdoor phone GPU workload | Highest accepted GPU medians; model 15–30% GPU reduction, verify affected passes | 010a, 008, 006 |
| 3 | Phone pacing / unmeasured frame work | Smaller scenes remain near half-rate despite lower GPU time; no established cause or guaranteed saving | 010a |
| 4 | Loading CPU construction | Different largest phases per map; model one-quarter of the identified phase only | 009a |
| 5 | Rue Royale phone script tick | Full tick is more significant here; endpoint cached probes do not identify moving cost | 006 |
| 6 | Exact material duplicates | Sharing already substantial; no defensible nonzero millisecond prediction | 005a |
| 7 | Transparent foliage / local lights | Blanket explanation unsupported by field inventories; near-zero expected from blanket conversion | 007 targeted audit |

Ranking: (1) Compatibility first-visit/loading attribution, then Web/phone; (2) phone outdoor GPU workload;
(3) unexplained ~30 fps pacing in smaller phone scenes; (4) loading construction (scatter, buildings/street props,
backdrop, room); (5) phone Rue Royale tick; (6) only proven duplicate materials; (7) targeted transparency/light audit.
Savings are scenarios in the report, not measured speedups. Existing foliage is opaque and chunked; the finish pass
already shares many surfaces, so the old “14,500 unique materials” premise is rejected.

Execution order: 005a → 009a → 010a → 005b if justified → 009b → 010b → 008 → 006 → 007 → 011.
Phone reference-class devices, pass-level GPU captures, compiler time, and exact draw calls by node type remain unmeasured.
Compatibility pipeline zeros are non-informative. Web cache/startup/audio caveats from 003 remain in force.

### Material eligibility (005a)

[Ownership audit and 005b no-op decision](../005a-material-eligibility.md). Generated table:
`build/perf/vo/005a/table.md` (`python tools/vo_material_summary.py`). Apparent town duplicates are predominantly
independent fades or named window roles; two house resources remain plausible candidates without measured payoff.
No runtime material cache/bindings changed. Quick and route checks passed.

### Loading phases (009a, complete)

[Accepted evidence and attribution](../009a-loading-phases.md), generated `build/perf/vo/009a/focused-01/phases.md`.
Two clean passes on each native renderer; quick, route and transitions pass. First-use draw/frame waits dominate
Compatibility, not the final finish traversal. Earlier interrupted attempts remain invalid.
**Legacy black_ms caveat:** frame-boundary sampling can miss synchronous loading/first-draw work before its first sample.
It is not a continuous stopwatch; retain 001–003 raw data, use a new continuous black interval for 009b before/after.

### Phone resolution and pacing (010a, complete)

[Experiment and limits](../010a-phone-resolution.md); exact generated comparisons in
`build/perf/vo/010a/phone/comparison.md`. Three 720p/540p/720p passes, 429.41 seconds, zero problems/focus losses.
540p GPU medians improve 7.3–20.3%, but every scene remains near 30 fps. 720p GPU drift is within about ±1.2%.
Battery 26.9–27.9°C; no clocks/throttling or presentation timestamps collected. Resolution alone does not meet 60 fps.
Native refresh is 60 Hz in all passes, cap 60, VSync enabled. Preserve outliers and legacy black-time caveat.
Next phone investigation is controlled pacing/presentation, alongside outdoor non-pixel GPU workload; no production
setting changed. Temporary package removed; original player app/saves preserved. Continue ordered work with 009b.
