# 008b: approved indoor shadow integration

Status: **complete under the existing user visual approval** recorded in
[Claude's result](claude-008b-result.md). No new visual direction or film-light
removal was introduced. Parent 008 is complete; next numbered work is 006.

## Change and coverage

`world.gd` now gives enclosed-room suns a 30-unit shadow distance and two splits,
replacing the engine defaults of 100/four. Mid and Max retain authored shadows;
Min disables them through the existing render-quality component. Open-air roofs
retain their existing path. Outdoor and battle casters, lighting and contact
shadows are unchanged, following Claude's approved no-op recommendation.

The new `--scene=vo-lighting` fixture reuses the existing route recorder. It
enumerates generated building interiors, then tests the hero's house and the
largest by tile area: **reef#0, Temple of Tides, 31×13 / 403 tiles**. At each room
it measures an entry hold and captures the following camera at four cardinally
reachable extremes. These coverage checks are scripted camera placements, not
input, traversal or exhaustive moving-shadow stability tests. The hero's shadow
remains visible at the checked front/back/side positions; no new shadow cutoff was
observed. Approved 30-unit phone captures and the 2400×1080 Compatibility/touch
capture were also inspected directly. Existing room staging/art is outside scope.

Before/after board: `build/shots/vo/008b/integration-indoor.png`.
Full desktop frames: `build/shots/vo/008b/mobile-01/pass_01/` (100/four),
`pass_02/` (30/two), `pass_03/` (return control).
Phone frames: `build/perf/vo/008b/phone/extracted/` (63 captures).
Compatibility capture: `build/shots/vo/008b/compat_touch_large.png`.
This is verification of the already approved candidate, not a new approval request.

## Measurements and reproduction

Commands (each wrapper acquires the shared resource lock; do not nest it):

```text
python tools/vo_lighting.py desktop --attempt mobile-01
python tools/vo_lighting.py export
python tools/vo_lighting.py phone --serial ZY22K7BD2J
python tools/vo_lighting.py summary build/perf/vo/008b/phone/report.json
```

Attempts are preserved; choose a new desktop name rather than overwriting one.
The experiment runs old/approved/old indoor coverage, and OculusKey shadow
on/off/on for the films. Preferences and saves are isolated. Validation recomputes
all summary statistics from raw traces and checks settings, maps, frame counts,
actual control properties, viewport dimensions and fixed film-time progression.
Headless smoke reports have only three frames and are rejected as performance evidence.

Desktop evidence: `build/perf/vo/008b/mobile-01/{report.json,validated-lighting.json,lighting.md,run.log}`.
Windows Mobile renderer, Mid, 720p at 1920×1080; **125.335 s**, zero harness
problems/focus losses. Frame medians remain about 16.67 ms. Net GPU median
differences were 0.148 ms for the house and 0.062 ms for the large room, but
bracket drift was +6.4% / +16.7%; film drift was +41–51%. An unrelated existing
windowed Godot process was present outside the lock and was left alone. These
are desktop observations, not phone results or a robust PC saving/headroom claim.

Phone evidence: `build/perf/vo/008b/phone/{report.json,validated-lighting.json,lighting.md,logcat.log}`.
Razr 2024 / Android 16 / Mali-G615 MC2, Mobile, Mid, 1760×720 rendering at
2640×1080 output; cap 60, VSync enabled. **309.625 s**, zero harness problems,
focus losses or USB observation interruptions. Battery **28.9–29.9°C**, charging;
largest sample gap **62.94 s**. The report records **24 Hz in all three passes**,
consistent with ~41.6 ms frame intervals. This differs from the earlier 60 Hz
walking-route experiments; the cause of refresh selection was not established,
and phone display settings were not changed. GPU measurements and pacing are
separate; this run does not establish an fps improvement or target-device acceptance.

| Scene / control | GPU medians A / B / A, ms | Mean A minus B | A bracket drift | Frame medians A / B / A, ms |
|---|---|---:|---:|---|
| House, 100/four → 30/two | 7.718 / 7.615 / 7.722 | 0.105 | +0.0% | 41.66 / 41.64 / 41.65 |
| Large room, 100/four → 30/two | 17.201 / 16.944 / 17.182 | 0.248 | −0.1% | 41.62 / 41.64 / 41.62 |
| Hatch, key shadow on → off | 10.912 / 10.352 / 10.871 | 0.540 | −0.4% | 41.64 / 41.63 / 41.64 |
| Merge, key shadow on → off | 12.708 / 12.353 / 12.319 | 0.160 | −3.1% | 41.64 / 41.71 / 41.65 |

APK SHA-256: `7a84f0604a7127aff0acd882793fcbd9ff45a3eab356592c5139b698f4f10c70`.
Benchmark cleanup succeeded, its package was uninstalled, original player-package
paths match, and export presets match the saved original bytes. No player data,
phone lock settings, source packs, artwork or smoothing records were modified.

## Requested film experiment

Both real film stages are instantiated through their existing UI stack; the hidden
world viewport is disabled. Their own 3D viewports supply GPU counters. All film
AnimationPlayers advance manually at 1/60 s alongside the film's real `_process`,
preserving callbacks/reveals. Shader time and particles still follow rendered time,
so pixel-exact animation equivalence is not claimed. This is a fixed-timeline
render-cost experiment rather than real-time film-playback acceptance. The fixture
uses level-40 race-0/race-30 parents and their merged child, and a large race-0
growth look for the hatch reveal; these are measured fixtures, not every beast.

Only OculusKey's shadow is toggled, with the effective flag checked afterward.
Hatch key range is 26; merge calls `enlarge(1.6)` and runtime evidence confirms
41.6. Other fills remain shadowless. The scene's two parent spots use range 13,
angle 26°, and its center spot range 16, angle 26°. The parent spots sit at
x=±7.7/z=−9.9, separated from the child at the front. The shared hatchery fills,
scaled ranges and textured/alpha layers remain present; the measured net key
effect is not attribution of their separate overlap/overdraw costs. Energy alone
was not used as a cost metric. 007 retains its focused alpha/beam-layer investigation.

Matched captures avoid the earlier all-white merge sample:

- Hatch egg in tongs: 4.9 s; reveal: 7.9 s.
- Merge parents: 2 s; mid-sequence: 4 s; child: 7.5 s.
- Desktop boards: `build/shots/vo/008b/film-hatch-diagnostic.png` and
  `film-merge-diagnostic.png`; full phone equivalents under `phone/extracted/`.

Phone viewport GPU p95/max with key shadows on: hatch 13.720/22.953 ms,
return 13.695/21.115; merge 18.880/25.716, return 18.324/24.986. Off:
hatch 13.356/20.746; merge 18.178/24.301. Raw outliers are retained.
`validated-lighting.json` also records the five largest GPU samples per film/pass
with sample index and nominal simulation time. GPU-counter latency means those
are not frame-exact hardware traces or proof of which effect caused a peak.

The marginal key-shadow effects, especially merge's effect relative to drift,
do not justify removing its authored shadow. Films therefore remain unchanged.
[Claude's returned experiment notes](claude-008b-cost-return.md) identify the frames
and limits for any later visual judgement before a film-light change.

## Checks and limitations

Through `server.py`: **quick**, **vo-lighting**, **vo-shadow-route**, **battle-stage**,
**video-settings**, **video-settings-touch**, **beast-growth** all pass. Raw
summaries: `build/vo008b-final-quick.json`, `build/vo008b-final-focused.json`.
Fourteen Python checks pass (`test_vo_lighting.py`, `test_vo_shadow_sweep.py`,
`test_vo_phone_sweep.py`). The new checks reject old controls labeled as approved,
wrong merge range, changed film viewport and incorrect timeline progression.

Initial harness compile errors and a headless draw-wait stall were corrected.
Only this task's verified stalled PIDs were stopped. Earlier failing logs are not
accepted measurements; the final headless smoke and named test pass. Shared
`vo-perf` behavior is preserved by optional callback/viewport/capture arguments;
headless measurement completion now skips the unavailable frame-post-draw signal.

Actual logs were checked: no runtime SCRIPT ERROR or Godot ERROR in accepted
measurements; allocator/usage probes and three phone QUEUE_BUFFER_TIMEOUT entries
are retained. Existing shutdown leak/resource warnings in diagnostic/test logs
are recorded rather than treated as runtime loading failures. The validator does
not discard runtime errors to admit a report. No PC/Web/target Snapdragon sustained
performance acceptance, all-beast film sweep or exhaustive room-camera audit is claimed.

Local-model help: a focused merge-timeline function/property summary, failed-compile
log triage through the test service, and a first look at the indoor comparison
board. Direct source/log reads confirmed the useful leads. The image answer noted
sharper foot shadows but speculated about reduced shadow-map resolution/complexity;
no shadow-map resolution changed, and that causal claim was not used. Actual
coverage was judged from the full captures, including phone and Compatibility.
