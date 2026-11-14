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

Acceptance testing was therefore moved to an independent archive of committed
baseline `c083ee43228a42b1cdc85905984e5ff420ad66af`, in `closure-01/suite-project/`.
All 519 source import sidecars were preserved and the copied import cache was
revalidated by the pinned editor (938 MiB sampled peak). A post-import content
check finds no tracked source changes after accounting for Git's CRLF conversion.
The moving-checkout attempts remain separate interrupted records.

## Completed checks

- Python town checker: zero problems.
- Toolchain isolation: 4/4 Python checks; small-child memory/timeout guard: 5/5.
- Earlier offline ASTC anomaly investigation: complete; no profile adopted.
- A71 4.7 Min/720p control: 4 complete walking-route passes / 1,100.848 seconds,
  zero reported problems/focus losses. Python recomputed every segment's
  statistics and trace lengths. Battery 27.6–32.7°C, USB charging. Export/template
  identity and validated summary are under `phone-47/`.
- A71 beta3 Min/720p: 3 complete passes / 989.410 seconds, zero reported problems/
  focus losses. A warm 4.7 follow-up completes one full pass / 376.134 seconds.

## Phone investigation

The first beta3 pass had roughly 20–25% longer outdoor frame/GPU medians than
the first 4.7 pass, with equal resolution and draw counts. This sequential
observation does not isolate the engine: beta3 started at 33.0°C battery.
Mid-run `dumpsys thermalservice` records thermal status 1, skin status 1 at
36.1°C and battery 33.8°C. GPU clock access is denied; no clock/thermal controls
were changed. A completed warm 4.7 bracket follows those runs below.

The completed warm bracket does not reproduce an engine-only 25% slowdown:

| Scene | Warm 4.7 frame median, ms | Final beta3 frame median, ms |
|---|---:|---:|
| Coastal Path | 100.090 | 100.176 |
| Cove plaza | 121.882 | 113.313 |
| Hero's house | 33.423 | 33.413 |
| Rue Royale | 104.392 | 104.131 |
| Coast battle | 55.213 | 54.638 |

Draw medians agree. Four scenes agree within about 1%; the separate Cove result
is not an engine speedup claim. These sequential runs cannot isolate thermal/
DVFS state, and raw long tails remain in `phone-warm-comparison.json`. The warm
4.7 bracket battery range is 33.7–33.9°C.

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

## Full suite and failure classification

The frozen beta3 suite completes **128/141 passing, 13 failing, in 61m54s**.
`frozen-suite.json` and `frozen-suite/` retain all results. This is not a green
suite. The separate live-checkout attempts are superseded, not pooled.

Same-commit 4.7 controls reproduce the failures in `hero-maker`,
`hero-maker-touch`, `sky-courier-touch`, `bag-limit`, `performance`, `ground`,
`beast-growth`, `battlecmd`, `ring-start-touch` and `phone-save-touch`.
`door-voices-touch` passes on both. The two mechanic-lessons failures were also
reproduced in the earlier 4.7 snapshot documented by the parent report; that
older source boundary is distinct from the current committed control.

`temple-air` fails in the beta suite and passes in the original 4.7 control.
The fixture randomizes starting stats, IDs and AI. A diagnostic with canonical
stats/IDs and an explicit battle seed loses on 4.7 and wins on beta3
(`controlled-air-comparison.json`). This does not establish deterministic engine
parity: battle AI also uses global random calls, including timing-dependent
consumption, beyond the seeded battle RNG. Preserve both outcomes. A flaky
win-dependent fixture remains an acceptance limitation, not a proven beta-only
regression and not a passing original test.

## Native renderers and visual checks

`native-matrix-02/` contains six validated two-pass route reports and 36 matched
captures: Forward+ Windows export, Compatibility Windows export, and desktop
Mobile renderer, each on 4.7 and beta3. Templates match their editors; export
presets were restored byte-for-byte. These are desktop measurements, not phone
numbers. First-pass shader/driver state is not globally reset. The interrupted
initial matrix is retained separately and superseded.

Warm Forward+ route medians are roughly 16.7�17.1 ms on both engines; desktop
Mobile roughly 16.7 ms. Compatibility is roughly 30.3�30.5 ms on both despite
GPU medians below 2 ms: do not claim 60 fps from GPU headroom. Draw medians agree
per matched scene. `validated-summary.json` recomputes every trace statistic.

Direct review of the three comparison sheets covers Cove Min/540p, house
Mid/720p, Gravenmoor Max/720p, water Mid/540p, battle Max/540p and fishing Min/720p.
Town, dark-area, water, combat models and silhouettes remain recognizable and
closely matched. NPC/foliage animation and stochastic scenery differ between
captures. A Compatibility house background is purple on 4.7 and black on beta3;
this visible difference is recorded for review, not silently approved. Contact
sheets are under `build/shots/vo/010c/closure-01/native-matrix-02/`.

## Actual texture feature trials

All nine desktop renderer/importer combinations render. The Mobile streamed
attempt lost foreground focus; only `mobile-streamed-retry1` is accepted for
functionality. Desktop feature traces overlapped the headless suite and are
not accepted performance measurements. AMD desktop ASTC/ETC2 support reports
false; fallback textures render. Compatibility warns that streaming is
unsupported and retains complete textures with zero streaming residency count.

On A71/Adreno 618, ASTC 4x4, 6x6, 8x8 and ETC2 sampling report supported.
The actual imported ASTC6 texture renders (format 47), with a physical image of
1026x516 and logical resource size 1024x512. This does not overturn the earlier
nearest-resize quality finding. No production compression profile is adopted.

The final phone streaming fixture uses Swappy 0 and a 60 fps cap. Regular and
streamed runs have no reported focus losses/problems. Streamed residency falls
from 1,048,632 to 16,440 bytes while inactive/forced low, and returns to full
by the seventh rendered return frame. Maximum return frame is 64.991 ms;
initial maximum is 295.868 ms. Visible distant textures retain high mips in
this fixture. These are small-fixture results, not whole-game savings or a
pop-free guarantee. Production streaming stays off and source imports unchanged.

## Loading and input

The matched A71 app-data-cold loading diagnostic records first Coastal Path
transition at 19,932.8 ms on 4.7 and 12,984.8 ms on beta3; return at 1,127.7 and
862.3 ms respectively. Other first/return transitions and script/title phases
are retained in `phone-loading-comparison.json`. Driver caches and thermal
state were not globally controlled; no general engine speedup is claimed.

The user reports the requested A71 touch exercise worked. The first native
journal independently confirms title/creator A/B transitions only. The follow-up
session has no journal available and the phone is locked at collection; retain
the user's observation separately from instrumented verification. The physical
controller is available but has not yet been exercised in this validation.

## Remaining gates

- Production-compressed Web route and old SampleNode pause check: underway.
- Physical controller/keyboard input observation and review of the Compatibility
  background difference.
- Full-suite acceptance: retain the 13 failures and their source/control boundaries.
- Original 007 phone recovery remains separate and open.

Keep 010c open and 011 budgets provisional until required acceptance is resolved.
