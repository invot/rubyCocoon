# Step 002 — phone baseline

Completed, 12 November 2026. The user attached a Motorola razr 2024 after the initial ADB device list was empty.
ADB reports Android 16, SoC MT6878 and a 1080×2640 physical display. The inner SurfaceFlinger display is
`4627039422300187648`; the second/cover display is `4627039422300187651`.

The configured Android SDK directory was missing. Google platform-tools 37.0.1, command-line tools, build-tools
35.0.1 and platform android-35 were prepared in `build/tools/android/`. The command-line ZIP SHA-256 matches
Google's [official download page](https://developer.android.com/studio/):
`90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`.

`python tools/vo_phone.py export` uses a workspace-local self-contained copy of the installed Godot 4.7 executable,
the existing Android debug template and keystore, and a temporary clone of the Android preset. Global Godot SDK
settings remain unchanged; the original export presets are restored after export. Temporary SDK and screenshot
directories have `.gdignore` files so the editor does not import them.

The checked-in preset targets `com.rubycocoon.game`, while the installed player copy is `com.rubycocoon.x`.
The benchmark uses a separate package, `com.rubycocoon.vo_perf`, titled **Ruby Cocoon Perf**, to preserve player data.
Only that package's private benchmark files are read for results. The debug-only preset includes the benchmark
scripts and bakes its launch arguments; the production resource filters are unchanged.

The planned sustained run is 15 minutes at **720p / Mid**, Mobile renderer, on the real landscape phone display.
`vo-perf --duration=900` repeats the same route in one process, writes a checkpoint after each pass, and records
focus losses. Android test saves/preferences/reports live under `user://bench/vo/002/`, because exported `res://`
is read-only. Normal save and preferences defaults remain unchanged.

The user warned that the phone sleeps/locks automatically. The benchmark requests keep-screen-on only for its
run and restores the prior app flag afterward. This does not unlock an already locked phone. Recording starts
only when ADB reports an awake, unlocked display. A focus loss invalidates the pass; interrupted time must not be
reported as valid sustained performance. The Python recorder logs battery temperature once per minute, captures
the inner display and reads logcat only for the benchmark process.

Evidence and results will be recorded in `build/perf/vo/baseline-phone/` and `ledger/perf.md` after validation.

## First device attempt

The app launched successfully and held the screen awake. Initial battery temperature was 29.9°C; Android reported AC charging at 100% battery (not USB charging). The first Coastal Path median was about 33.35 ms, but this is **diagnostic only**, because the cold touch-pad painter logged a thread-safety error at `controls_overlay.gd:474`. The attempt was stopped and archived under `build/perf/vo/baseline-phone/attempt1-thread-error/`.

The worker previously called `get_script()` on a live overlay Node while delivering its finished images. It now receives a script callback and weak reference captured on the main thread, and runs as a static worker. The face-painting algorithms and cache style version are unchanged. A fresh-cache phone run is required to verify delivery, rather than hiding the issue behind cached faces.

## Corrected run in progress

The rebuilt APK SHA-256 is `ebd57c3fdbfd5ffc9e6984c2399625c2d1850384e437900fb0fd21551eec8e04`. Controller, controller-touch and route regression checks all passed. A cold test-app cache was cleared with `pm clear com.rubycocoon.vo_perf`; no player package was cleared. The corrected app started at 30.7°C and its first route completed without the touch-painter thread error. The native inner-display capture shows the normal pad. Sustained-run validation is still pending.

## Recorder recovery

The host observer encountered an empty/partial JSON checkpoint while the app was replacing its report. The phone process continued uninterrupted. `tools/vo_phone.py --attach` now reconnects without reinstalling, clearing data or restarting the app; partial checkpoint reads are retried. The observer reattached around 880 seconds, with six valid completed loops already recorded by the app. Battery samples have a gap from about 541 to 880 seconds; this must be retained as a limitation. The raw app traces and focus-loss tracking continued through that gap.

Early host temperature records labeled charging from the USB flag only, while raw battery-service logs correctly report AC charging. Final power-source metadata must be derived from those raw logs; measured temperatures/timestamps are unchanged. Native ADB screenshots can add readback overhead, so their timestamps are retained and raw worst-frame outliers must not automatically be attributed to the game.

## Accepted results

Seven complete loops ran for **993.36 seconds (16 min 33 s)** at 720p / Mid on the Mobile renderer, Vulkan 1.3.247, **Mali-G615 MC2**. The physical/window capture is 2640×1080 and the 3D viewport is 1760×720. All seven loops have identical tile paths and sample counts. Independent Python checks reproduced every median, p95, p99 and worst-five ranking. There were **zero benchmark problems and zero focus losses**; keep-screen-on was true. These are real-phone measurements, not desktop Mobile-renderer figures.

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

| Segment | Tick CPU / render CPU / 3D GPU median ms | Draw calls | VRAM MiB |
|---|---:|---:|---:|
| coast_battle | 1.85 / 2.04 / 15.21 | 349 | 246.9 |
| coastal_path | 3.16 / 2.99 / 28.73 | 377 | 207.7 |
| cove_plaza | 3.50 / 2.78 / 26.33 | 306 | 202.9 |
| hero_house | 1.67 / 2.33 / 15.41 | 62 | 201.7 |
| rue_royale | 5.50 / 3.78 / 23.86 | 318 | 209.2 |

The final segment medians are approximately **29–30 fps**, below the 60 fps target. No material median slowdown appeared between the first and last loop. This does not prove that CPU/GPU clocks never throttled: clock/throttling counters were not collected. No Snapdragon 660- or 865-class reference phone was measured in this step.

Battery temperature samples ranged from **30.7°C to 31.9°C**, with AC charging reported at 100% battery. `temperature-curve.csv` retains the measured curve. The largest sample gap is **339.37 seconds**, from the host-recorder checkpoint race; the app's frame traces continued uninterrupted. Earlier charging metadata was normalized from each raw `battery-XX.txt`; the original observer JSON is preserved. Native screenshot readback can affect isolated raw worst frames, so those maxima are not presented as proof of shader or game-code stalls.

There were no Godot script errors or missing resources in the accepted run. One startup warning reports the missing `xr/shaders/enabled` setting; Android/Mali graphics-probe and buffer-timeout messages remain in logcat and were not silently discarded. Their causes were not diagnosed in this measurement step.

The **14 touch-pad cache images are byte-for-byte identical** before and after the callback repair (`pad-cache-comparison.json`). The repair changes delivery thread safety, not the control artwork. The actual inner-display screenshot and all five per-segment viewport captures were inspected. Controller, controller-touch, route, quick and phone-save / phone-save-touch checks passed. Player saves and the installed `com.rubycocoon.x` game were preserved.

Accepted evidence: `build/perf/vo/baseline-phone/report.json`, `device.json`, `logcat.log`, `temperatures.json`, `temperature-curve.csv`, raw battery files, native display captures, `phone-files.tar` and `extracted/files/bench/vo/002/shots/`. The failed first attempt is retained separately.

After extraction and validation, the temporary `com.rubycocoon.vo_perf` package was removed. ADB confirmed that
the original `com.rubycocoon.x` game remains installed at the same APK path. The app's keep-screen-on request
ended with the benchmark; no persistent screen-lock setting was changed.

The local model identified the expected touch controls in the native capture and read the final log as normal
completion. The full log was independently scanned for Godot errors and missing resources. The accepted phone
captures are collected in `build/perf/vo/baseline-phone/phone-board.jpg`.
