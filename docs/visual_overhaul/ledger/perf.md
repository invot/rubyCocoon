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
