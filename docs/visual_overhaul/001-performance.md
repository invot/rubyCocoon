# Step 001 — reproducible desktop performance runs

Status: done, 12 November 2026. The game art is unchanged. User approval is required for visual changes;
tooling and measurements continue automatically after their checks pass.

## Reproduce

Run `python tools/vo_perf.py` alone. `GODOT` overrides the executable. The default is the installed Godot 4.7 at
`C:/Program Files/Godot/Godot_v4.7-stable_win64.exe`. The runner starts a fresh process for each of two consecutive
passes on Forward+, Mobile and Compatibility at 1920×1080, then Mobile at 2400×1080 with `--touch`.
Every launch uses isolated `--save_dir` and `--prefs_path` values under `build/vo_state/`. Player data is not used.

The route seed is 12026. The field traverses cardinal tile paths using the existing elevation rules, ground
interpolation, gameplay camera, scenery visibility, water and actor animation. Each tile takes 14 rendered frames
at a fixed simulation dt of 1/60 second. Input, roaming, encounters and step-triggered story events are held still.
This is a rendering workload, not a movement/AI regression test. The repaired tutorial footbridge is part of the fixture.

Segments: Coastal Path west to east; a loop around the Cove plaza then the home doorstep; the hero's house;
Rue Royale west to its eastern junction; a warmed coast battle for 240 frames. The house is a stationary sample.
Reports include the complete tile lists, so the runner rejects differences in workload even when VSync would
give the same medians. Snapshots and screenshot readbacks run outside the sampled intervals.

`--scene=vo-perf --verify=1` checks the route without collecting performance samples. The `vo-perf-route` named
test runs this mode. The normal benchmark rejects a missing isolated save/preferences override.

## Evidence and interpretation

- Accepted raw results: `build/perf/vo/baseline-desktop/{forward,mobile,compat,mobile-touch}.json`.
- Both runs: adjacent `*-run1.json` and `*-run2.json`; repeatability checks in `repeatability.json`.
- Run logs and reports: `build/perf/vo/001/{before,after}/`.
- Segment captures: `build/shots/vo/001/{before,after}/<renderer>/`, midpoint and endpoint views.
- Standards §28 command execution logs: `build/perf/vo/001/commands/`.

Here `before` and `after` name the two validation passes of the same visual implementation, not an art comparison.
The small earlier `smoke` runs are development diagnostics and are not accepted baselines.

The machine is a Windows desktop with Ryzen 7 9700X and Radeon RX 9060 XT. These are desktop results, including
the Mobile renderer and wide touch layout; they do not establish phone or browser performance. The actual driver,
engine version, window and render sizes, quality, frame cap and VSync mode are recorded in each report.

Frame intervals include presentation pacing. `process_cpu_ms` is the existing engine `Performance.TIME_PROCESS`
monitor, whose updates can lag, not a measurement of pure CPU occupancy. `tick_cpu_ms` measures the fixture's
shared world/battle tick; `render_cpu_ms` and `gpu_ms` are measured on the 3D viewport. These counters overlap and
must not be added. See the [Godot Performance reference](https://docs.godotengine.org/en/latest/classes/class_performance.html)
and [RenderingServer reference](https://docs.godotengine.org/en/latest/classes/class_renderingserver.html).

Draw calls, objects, primitives and video memory use RenderingServer's global counters. Material/surface counts
are conservative frustum/AABB snapshots at the segment start, midpoint and end. They include occluded geometry
and do not reproduce the renderer's LOD decisions. MultiMesh surfaces are counted once per batch. A zero-valued
GPU/render/memory counter is flagged as unavailable rather than treated as evidence of zero cost.

## Results

All 16 command checks passed, including the repeated windowed full texture audit, final quick checks, the named performance test and the route/callback regression. All four renderer/layout pairs passed; the largest segment median difference was **0.123%** (5% limit). The accepted wide touch runs use screen input and have the pad visible.

- forward: largest segment median difference **0.090%**.
- mobile: largest segment median difference **0.123%**.
- compat: largest segment median difference **0.093%**.
- mobile-touch: largest segment median difference **0.003%**.

| Renderer/layout | Segment | Median / p95 / p99 ms | Worst ms | Tick / render CPU / GPU ms | Draw calls | Objects / primitives | VRAM MiB | Materials / surfaces (frustum estimate) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| forward | coast_battle | 16.677 / 16.997 / 17.306 | 18.057 | 0.146 / 0.149 / 1.283 | 205 | 459 / 128760 | 488.4 | 49–50 / 230–231 |
| forward | coastal_path | 16.681 / 16.934 / 17.740 | 18.478 | 0.348 / 0.361 / 2.070 | 302 | 310 / 367250 | 261.2 | 26–45 / 207–234 |
| forward | cove_plaza | 16.675 / 16.928 / 17.435 | 18.639 | 0.391 / 0.373 / 1.943 | 283 | 296 / 266242 | 281.5 | 35–68 / 78–198 |
| forward | hero_house | 16.665 / 18.048 / 18.444 | 82.841 | 0.136 / 0.233 / 1.123 | 276 | 279 / 65291 | 284.3 | 34–34 / 85–85 |
| forward | rue_royale | 16.680 / 17.019 / 17.414 | 18.012 | 0.373 / 0.278 / 1.733 | 292 | 369 / 282641 | 306.9 | 36–41 / 195–261 |
| mobile | coast_battle | 16.687 / 17.900 / 18.345 | 18.586 | 0.190 / 0.201 / 0.873 | 325 | 454 / 128760 | 366.6 | 49–50 / 230–231 |
| mobile | coastal_path | 16.683 / 16.910 / 17.037 | 17.997 | 0.270 / 0.253 / 1.683 | 302 | 302 / 367250 | 213.0 | 26–45 / 207–234 |
| mobile | cove_plaza | 16.678 / 16.909 / 17.068 | 17.275 | 0.308 / 0.242 / 1.470 | 232 | 232 / 266236 | 232.2 | 35–68 / 78–198 |
| mobile | hero_house | 16.672 / 19.120 / 20.656 | 20.979 | 0.190 / 0.287 / 0.394 | 42 | 42 / 65291 | 236.1 | 34–34 / 85–85 |
| mobile | rue_royale | 16.677 / 16.907 / 17.853 | 18.496 | 0.440 / 0.323 / 1.464 | 232 | 232 / 282641 | 257.6 | 36–41 / 195–261 |
| compat | coast_battle | 16.669 / 17.059 / 17.274 | 17.420 | 0.144 / 0.223 / 0.719 | 330 | 459 / 128760 | 257.5 | 49–50 / 230–231 |
| compat | coastal_path | 16.659 / 17.669 / 18.191 | 19.096 | 0.397 / 0.563 / 1.274 | 310 | 310 / 367250 | 154.9 | 26–45 / 207–234 |
| compat | cove_plaza | 16.669 / 17.392 / 18.318 | 18.994 | 0.415 / 0.515 / 1.168 | 296 | 296 / 266242 | 171.8 | 35–64 / 78–198 |
| compat | hero_house | 16.665 / 17.112 / 17.407 | 18.477 | 0.124 / 0.229 / 0.560 | 279 | 279 / 65291 | 176.1 | 34–34 / 85–85 |
| compat | rue_royale | 16.669 / 17.099 / 17.357 | 18.227 | 0.384 / 0.382 / 1.032 | 372 | 372 / 282641 | 196.2 | 36–41 / 195–261 |
| mobile-touch | coast_battle | 16.665 / 16.740 / 16.836 | 17.316 | 0.141 / 0.149 / 0.812 | 347 | 506 / 129964 | 423.2 | 50–51 / 232–233 |
| mobile-touch | coastal_path | 16.665 / 16.742 / 16.816 | 17.088 | 0.261 / 0.255 / 1.871 | 356 | 386 / 418346 | 253.2 | 26–47 / 233–279 |
| mobile-touch | cove_plaza | 16.665 / 16.723 / 16.835 | 17.286 | 0.286 / 0.267 / 1.714 | 285 | 315 / 305191 | 272.4 | 35–65 / 83–225 |
| mobile-touch | hero_house | 16.666 / 16.682 / 16.728 | 16.755 | 0.106 / 0.196 / 0.481 | 62 | 92 / 68708 | 276.3 | 34–34 / 85–85 |
| mobile-touch | rue_royale | 16.665 / 16.736 / 16.792 | 17.125 | 0.349 / 0.273 / 1.581 | 295 | 325 / 327129 | 297.8 | 37–50 / 226–289 |

Black-screen milliseconds per fresh process; these are transitions within each run, not return-visit timings.

| Renderer/layout | Coastal Path | Cove | Home | Bellerive |
|---|---:|---:|---:|---:|
| forward | 2035.6 | 469.2 | 26.0 | 587.4 |
| mobile | 2181.6 | 486.2 | 22.8 | 686.0 |
| compat | 24145.3 | 5709.9 | 3661.4 | 1192.2 |
| mobile-touch | 2090.7 | 480.1 | 35.3 | 676.5 |
Both raw spikes and the five worst frames are
retained even if the median repeatability gate passes. The gate checks every segment against a 5% median limit;
it does not claim that the current game meets all performance targets.

## Local-model help and limitations

The local qwen3.6-27b server was available. It summarized movement side effects from a focused code excerpt;
the relevant exit, trainer-sight and story triggers were confirmed in source. An oversized initial source request
was rejected by the model server; the excerpt request succeeded. It found the same ObjectDB warning in all eight run logs and no script errors or missing resources; a direct log scan confirmed that reading. Its prose summary incorrectly called the smaller repeatability percentage “smoother”; that interpretation was rejected. Repeatability is not a smoothness measure. A final local-model code scan speculated that the frustum-plane test was reversed; a numeric camera probe confirmed all six plane tests are false for an inside point and one is true for an outside point, so that suggestion was rejected. The model confirmed the final pad controls were present. Its minor arrow-clipping claim is not treated as a confirmed defect; no interface change was made from that answer.

The first wide-layout runs had no visible pad because a connected controller took priority. Those captures/reports are retained under `build/perf/vo/001/diagnostics/controller-hidden/` and excluded from accepted touch evidence. The fixture now explicitly selects screen input and records/asserts pad visibility.

The windowed full texture audit exposed a pre-existing deferred callback error: freed geometry could not be converted to its typed callback argument before the validity guard ran. `render_quality.gd` now accepts the deferred argument without that conversion and checks its lifetime first. The route regression exercises immediately freed geometry, lights and environments; the test runner now rejects deferred-call errors. The original failing log is retained as `commands/09-original-freed-callback.log`.

Existing shutdown ObjectDB leak warnings appeared in the unchanged screenshot capture and the diagnostic runs.
These are recorded separately from script errors or missing assets. No asset, texture, material, balance or map
layout was changed by this step. The callback repair changes only handling of nodes that have already been freed.
