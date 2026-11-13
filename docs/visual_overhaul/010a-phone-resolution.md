# Step 010a — phone resolution and pacing experiment

Completed, 12 November 2026. Production video/rendering behavior is unchanged. The separate benchmark ran
720p/Mid → 540p/Mid → 720p/Mid in one process, with identical fixed-seed route/frames and isolated state under
`user://bench/vo/010a/`. Bracketed 720p samples help expose drift/order effects; this is not a reference-class
hardware certification or a guarantee against throttling.

## Reproduce / evidence

```text
python tools/vo_phone_sweep.py export
python tools/vo_phone_sweep.py run --serial ZY22K7BD2J
python tools/vo_phone_sweep_summary.py
```

The wrapper already holds the shared resource lock for export and the entire phone observation; do not nest
local_resource around it. Run outside the sandbox. It reuses the existing temporary-preset exporter and isolated
benchmark package `com.rubycocoon.vo_perf`, never the player package `com.rubycocoon.x`. Original preset bytes were
verified restored after export. The temporary APK hash is
`a9c5ed2d9d8e21c159f12d194552b86da803314ab52befa3bb4793b83525b510`.

Evidence goes to `build/perf/vo/010a/phone/`: device/display metadata, package path before/after, logs, temperatures,
report with per-pass render dimensions/refresh/vsync/cap, and private benchmark files/screenshots in phone-files.tar.
Native ADB screenshot readbacks are disabled during this sweep; harness captures occur outside sampled intervals.
Player saves/settings and phone lock settings are untouched. The benchmark requests keep-screen-on for its run only.

Preflight checks passed: quick, vo-perf-route and a headless three-resolution route. The latter verifies transitions,
pass settings and no benchmark problems; it does not measure real GPU/presentation performance. The actual phone
is Motorola razr 2024, Android 16, MT6878/Mali-G615 MC2, Vulkan Mobile, 2640×1080 landscape with a 1760×720 or
1320×540 3D viewport. Engine cap is 60 and the first pass reports 60 Hz. Battery temperature started at 26.9°C,
AC charging. All three passes completed in 429.41 seconds with zero benchmark problems/focus losses. Every segment's
median, p95, p99 and maximum was independently recomputed from raw traces; route/sample counts and render sizes match.
The temporary benchmark was stopped and uninstalled afterward; the player package remains at the identical path.

## Results

Exact generated comparison: `build/perf/vo/010a/phone/comparison.md`; machine-readable checks and per-pass settings:
`validated-sweep.json`. Re-run `python tools/vo_phone_sweep_summary.py` from the retained report.

540p reduces viewport pixels by 43.75%, but measured GPU medians fall by only **7.3–20.3%** against the bracketed 720p
average. Coastal Path GPU is 28.43 → 23.05 → 28.25 ms; house is 15.34 → 12.24 → 15.35 ms. All five scenes still have
33.23–33.83 ms frame medians at 540p (about 30 fps). The 60 fps goal is not met. GPU and tick/render CPU counters
overlap and must not be added. Lowering resolution alone does not fix the phone target in these fixtures.

720p GPU drift across the bracket is -1.2% to +1.1%. Battery samples cover 26.9–27.9°C, AC charging;
largest gap 62.49 seconds, with no observer interruption. No CPU/GPU frequency or thermal throttling counters were
collected, so small drift/temperature changes do not prove absence of throttling or explain the GPU scaling.

Path's 540p p95 improves to 34.24 ms versus about 50.4–50.6 ms at 720p. Other tails still show dropped intervals.
All outliers remain: first 720p Path has an **816.69 ms** maximum at frame 613, absent from the return Path run
(51.89 ms maximum). Its cause is not established; do not discard it or call it shader compilation from timing alone.

All passes report 60 Hz, VSync enabled and Engine.max_fps=60. Android's post-run game service reports no game-mode
intervention for the benchmark package; this does not instrument every driver/compositor scheduling decision.
The half-rate interval remains even in the house with ~12 ms GPU at 540p. Select a controlled pacing/presentation
test as the next phone diagnostic, retaining workload measurements separately; no blind mode/power/refresh change.
Outdoor GPU medians still exceed 16.67 ms at 540p, so presentation alone also cannot be promised to give 60 fps outdoors.

No GDScript, deferred-call or missing-resource errors occurred. The existing missing `xr/shaders/enabled` warning,
Mali format-probe errors and one startup GPU-buffer timeout remain in the raw log, as in the earlier baseline family.
No claim is made that these messages are harmless or that they caused a particular sampled frame. The benchmark's
keep-on request ended with the app; no persistent screen/lock/power setting was changed.

Actual captures are extracted under `phone/extracted/files/bench/vo/010a/shots/pass_01..03/`. The 720p/540p Path
captures were inspected directly: same fixture/artwork and visible touch clusters, with the expected coarser 540p
image under the existing nearest resolve. This measures existing settings, not new-artwork approval or integration.
Candidate rev_003 remains outside runtime assets.

The local model described the visible d-pad, A/B and Start/Pause controls, confirmed by direct inspection.
Its generic description called the orange-haired hero white-haired and treated bush markings as flowers;
these labels were not used as factual findings or grounds for a change. Numeric conclusions come from Python.

## Pacing investigation notes (not a diagnosis)

The complete bracket reproduces the ~30 fps baseline. GPU/CPU clocks and presentation timestamps were not collected,
so DVFS and scheduling remain possible confounders; no root cause is established by the interval/GPU relationship alone.

The [exact engine commit's Vulkan source](https://github.com/godotengine/godot/blob/5b4e0cb0f/drivers/vulkan/rendering_device_driver_vulkan.cpp#L3497)
configures Swappy differently from the mode labels in documentation: mode 0 enables auto-swap/auto-pipeline,
mode 1 enables auto-swap only, and mode 2 disables both. The
[Android API reference](https://developer.android.com/games/sdk/reference/frame-pacing/group/swappy-vk)
defines these Boolean switches. Therefore do not select a pacing experiment from enum names alone, or assume
automatic downshifting explains this particular run without checking its effective configuration. No Swappy,
VSync, refresh, FPS-cap or device power setting was changed for this resolution-only experiment.
