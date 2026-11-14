# 010c remaining validation

In progress, 13 November 2026. Continuation of the approved beta3 cutover;
[parent evidence and rollback](010c-godot-48-results.md) remain authoritative.

## Evidence boundaries

Matched comparisons use preserved `import-settings-02/project-47/` and
`project-48/` sources and independent caches; the A71 beta run uses the matching
`project-48-swappy0/` intervention. Android exports use matching templates,
guarded exporters and isolated benchmark state. Player saves are untouched.

New evidence: `build/perf/vo/010c/closure-01/`. Task scripts there preserve exact
commands. `tools/vo_streaming_trial.py` prepares a separate copied-texture project.

Concurrent controller/title UI and loading-art edits arrived during the live
checkout's full suite. `concurrent-source-state.json` records this boundary. A
transient `controls_overlay.gd` parse error and changed title-guide assertions
are not accepted as engine regressions. Do not claim this moving-checkout suite
verifies one immutable source revision; preserve the other work.

## Completed checks

- Python town checker: zero problems.
- Toolchain isolation: 4/4 Python checks; small-child memory/timeout guard: 5/5.
- Earlier offline ASTC anomaly investigation: complete; no profile adopted.
- A71 4.7 Min/720p control: 4 complete walking-route passes / 1,100.848 seconds,
  zero reported problems/focus losses. Python recomputed every segment's
  statistics and trace lengths. Battery 27.6–32.7°C, USB charging. Export/template
  identity and validated summary are under `phone-47/`.

## Phone investigation

The first beta3 pass had roughly 20–25% longer outdoor frame/GPU medians than
the first 4.7 pass, with equal resolution and draw counts. This sequential
observation does not isolate the engine: beta3 started at 33.0°C battery.
Mid-run `dumpsys thermalservice` records thermal status 1, skin status 1 at
36.1°C and battery 33.8°C. GPU clock access is denied; no clock/thermal controls
were changed. A warm 4.7 bracket is queued before feature trials.

The earlier settled-view budget route and this walking route are different
workloads. The walking 4.7 control already exceeds the 30-fps target; do not
substitute the older settled-view ~30-fps result. CPU/GPU timers overlap.

## Streaming eligibility

`source-inventory.json`: 387 ordinary texture import sidecars, zero streamed
imports in `assets/` and `ui/`. Four sampled scenery resources (oak, pine, lamp,
torch) contain embedded 256×256 `ImageTexture` resources. `voxel_textures.gd`
rebuilds imported images as runtime `ImageTexture` and `Texture2DArray` resources,
including terrain. A global switch does not convert those paths to streaming.

The isolated fixture imports three separate copies of the unchanged coast
backdrop through regular and streamed importers, testing near/far/return views
and forced low/full mip residency. It records traces, residency, format support
and images; this is not an in-game memory-savings claim. Production streaming
remains off. Pinned beta3 source disables streaming on Compatibility; actual
fallback captures remain required.

The script scan found no custom sky shaders, compositors or non-UI normal/
roughness-map assignments. This does not exhaustively inspect all embedded
materials or validate future normal/mask compression.

## Remaining gates

- Finish beta sustained comparison and warm-control classification.
- Streaming/ASTC capability and actual renderer fallback trials.
- Native exported/desktop Mobile routes and dark/indoor/water/battle images.
- Production-compressed Web routes and the old SampleNode pause check.
- Actual controller/touch input observation, followed by review of results and
  outstanding legacy suite failures. The user confirmed controller availability.

Keep 010c open and 011 budgets provisional until these gates are resolved.
