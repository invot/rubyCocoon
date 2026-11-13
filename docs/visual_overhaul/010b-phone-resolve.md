# 010b: completed phone evidence

The user had already approved Claude's smooth-resolve screenshots. The missing
phone measurement is now recorded; no production rendering change was made here.

The existing `RubyCocoon-perf-010b.apk` was run on the razr 2024 (Android 16,
MT6878, Mali-G615 MC2), Mobile renderer, Mid, 720p/540p/720p. APK SHA-256:
`4772a1783de9b496dfb7349d97c0fc6edb4036b451ae35416561f48e6e9095d3`.
Output was 2640×1080, refresh 60 Hz, VSync enabled and cap 60 in every pass.
Raw evidence: `build/perf/vo/010b/phone/`; the validator is
`python tools/vo_phone_sweep_summary.py 010b`. It recomputed statistics from raw
traces and checked route, settings and player-package identity.

Three passes completed in **459.855 seconds**, with zero harness problems and
focus losses. Battery was **28.9–29.9°C**, charging; largest temperature gap was
62.20 seconds. The earlier USB-failed attempt is retained under `attempt-before-*`,
including its INVALID marker. Thirty captures are extracted under `phone/extracted/`.

| Scene | 540p frame median / GPU ms | 720p GPU bracket drift |
|---|---:|---:|
| Coastal Path | 33.46 / 28.05 | +6.2% |
| Cove plaza | 33.47 / 27.10 | +11.2% |
| Hero house | 16.72 / 5.24 | −52.4% |
| Rue Royale | 32.83 / 16.53 | +0.3% |
| Coast battle | 16.86 / 6.83 | +1.4% |

Use the generated `comparison.md` and `validated-sweep.json` for all three passes.
The house returned at 16.69 ms even at 720p, after a first 720p median of 33.22 ms:
pacing is variable, and this run does not isolate a sharpening regression or gain.
Outdoor samples remain near 30 fps. This is the requested observed 540p result,
not proof of a sustained 60 fps target or comparison on the target Snapdragon classes.
The earlier 010a run was cooler and had much smaller bracket drift, so do not
attribute differences between runs solely to the resolve shader.

Actual log inspection found no Godot SCRIPT ERROR or Godot ERROR. Mali allocator
format/usage errors and Android QUEUE_BUFFER_TIMEOUT lines are retained; the same
allocator probes also occur in 010a. They were not silently counted as game-script
failures or discarded. A 540p Coastal Path capture was inspected: scene, hero and
touch controls render; the legacy scenery remains pending the later art overhaul.

Quick, video-settings, video-settings-touch, polish, polish-touch, vo-perf-route
and battle-stage passed through `server.py` in this continuation. The temporary
benchmark package was removed after extraction; original player-package paths
match before/after. Player saves and phone lock settings were untouched.

010b's existing visual approval remains in force. Continue with 008a diagnostics;
the separate font update still has its own visual review checkpoint.
