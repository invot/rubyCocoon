# 011 — measured budgets on adopted beta3

**Done, 14 November 2026.** The user approved the ground-cache comparison and measured limits; they are promoted and main-checkout verification passes. 010c and
007 are complete. The earlier 4.7 experiments below remain historical evidence;
they are not relabelled as beta3 measurements. Hardware requirements are unchanged.

## Current measurement boundary

`build/perf/vo/011/beta3-20261114-01/` preserves an independent archive of committed
source `2e7dd36421e6a2ed54acbbd2898349b76d0adc44`, 609 source import sidecars and an
independently revalidated beta3 import cache. Initial editor import had user-directory/
headless-editor warnings; the isolated-APPDATA recheck is clean (797 MiB sampled
peak). A source recheck finds 148 line-ending-only differences against the checkout,
with no actual differences in world, graphics, data or map source. Concurrent title
and phone-save edits remain untouched. All measured jobs share the OS resource lock
and exporters/native tests retain the memory guard.

The existing shipped ground was stale, so source and compiled exports could use
different geometry. The isolated bake regenerates 32 shapes, generator
`d62622bf8c32a0047becafabb3018beb`, replacing the old `d1d404b2c75ff02756e1451aae47a63d`
epoch. Two shape keys are added and two retired; 18 matching libraries differ in
index/topology data. Equal-length paired vertex/normal arrays compare identically;
that does not establish equivalence for changed-size arrays or new shapes.
No textures are regenerated or smoothed. Original files are preserved in
`original-ground.tar`. The validated 32-shape cache is now promoted. The two retired cache files and previous ledger are backed up in `main-before-promotion.tar`; `promotion.json` records the accepted file hashes.

Before/after real-camera views are under `build/shots/vo/011/beta3-ground-01/`.
Direct review finds the sampled Cove ground/cliffs, Coastal Path and Rue street
closely matched; the moving pink beast is not a ground addition. The local model
invented an added lamppost; direct inspection confirms it in both views. A first
array-diff helper used a nonexistent API and timed out; only the corrected
`ground-diff-02` result is accepted. Selected captures do not prove every map/state
visually identical.

## Accepted beta3 records

- `beta3-headless-desktop-01` and `beta3-headless-touch-02`: complete whole-subtree
  structural baselines, reference 16:9 and explicit 2400x1080 20:9 respectively.
  `beta3-headless-touch-01` was actually 16:9 despite its requested CLI resolution;
  it is superseded. The diagnostic now explicitly sizes the dummy window.
- `beta3-forward-01`, `beta3-mobile-01`, `beta3-compat-01`: complete unpaced desktop
  settled routes, Mid/720p. Desktop Mobile is desktop evidence.
- `beta3-export-forward-01`, `beta3-export-compat-02`: actual Windows debug exports,
  with diagnostic scripts included and no renderer command override. They confirm
  Forward+/Vulkan default and Compatibility/OpenGL dedicated build; preset bytes
  are restored. Compatibility disables its shader cache. The first Compatibility
  route lost focus and is excluded. The retry includes title shader precompile.
- `beta3-web-01`: production compressor, loader and streamed music with diagnostic
  scripts, default Web Compatibility, fixed 1280x720 canvas, Mid/720p. The complete
  report and every trace statistic validate with no focus loss/problems. The local
  collector raced its own report write after saving the result; the retained report
  was independently validated and browser console read directly before closure.
  Exit-time PagedAllocator/ObjectDB warnings remain. No script error was observed.
  Browser GPU timing is unavailable (zero), not a zero-cost measurement.
- `beta3-a71-min-540-01`: actual default Android Mobile/Vulkan export, no renderer
  override, matched beta3 templates. A71 completes one settled pass / 153 seconds,
  zero problems/focus losses; battery 28.6–29.0 C, USB charging. Private benchmark
  files/report are archived, benchmark uninstalled, player package path unchanged.
  This is one-pass fixture evidence, not a new sustained stability certification.

The accepted ledger is [ledger/budgets.md](ledger/budgets.md), with schema-2 limits in
`ledger/budgets.json`; the isolated candidate remains preserved. It records per-scene
renderer draws/primitives, conservative source material/transparency counts,
process/cache texture counters, frame/GPU costs and hashed provenance. Actual
transparent-pass draw counts are unavailable through the exposed Godot counters;
the source estimate is explicitly labelled rather than presented as that counter.
Source texture capacity and renderer texture memory remain separate quantities.

A71 Min/540p outdoor snapshot medians are about 50–66 ms, with worst scene GPU
medians around 54–57 ms. These exceed the 33.333 ms minimum-class frame target and
26.667 ms work allowance. The goals remain 30 fps minimum class, 60 fps middle
class/PC, with 20% work reserve; no added outdoor art cost is accepted. A passing
structural guard freezes cost and does not certify frame rate. The older A71 Mid
Vulkan device-loss findings and beta3 sustained controls remain separate evidence.

## Guard and verification

The schema-2 guard pins the engine hash and ground generator as well as the two
scene/profile ceilings. It rejects stale ground and missing metrics; tests never
regenerate reviewed limits. Raw render summaries are validated against every trace.
The recorder now uses the memory guard and isolated APPDATA, and can measure an
independent project. Export probes can include diagnostics in an isolated project.

Five Python evidence-boundary tests pass. In isolated Godot integration probes,
normal limits pass; zero geometry allowance, wrong engine and wrong ground each
return exit code 1 with the expected budget failure. Probe limits are restored
byte-for-byte. The first probe checker incorrectly expected exit zero on a
negative case; its raw rejection is retained and the corrected four-case check
passes (`guard-probes-02/results.json`). All eight isolated quick/budget/inventory/ground checks pass (48 seconds); the
Python town checker reports zero problems. Do not describe this as a full-suite pass.

## Acceptance and current-checkout verification

The user approved the concrete comparison and budgets on 14 November 2026.
Promotion first verified that the terrain generator and original production cache
still matched the reviewed source; it backed up the old cache/ledger and copied
only the accepted 32 ground shapes, index and derived budget files. No textures,
smoothing records, player data, renderer/preset policy or unrelated edits changed.

The main import is clean. Through `server.py`'s test wrapper, all **8/8** focused
checks pass in **53 seconds**: scripts, data, maps, beasts, vo-budget,
vo-budget-touch, budget-inventory and ground. Five Python evidence-boundary tests
pass, the Python town checker reports zero problems, and diff whitespace checks
pass. These are focused results, not a rerun of the known failing full suite.
Main evidence: `main-import.json`, `main-checks.json`, `main-test-logs/` and
`promotion.json` under `beta3-20261114-01/`. A real-window main capture is retained
as `build/shots/vo/011/beta3-ground-01/main-approved-cove.png`.

**011 is complete. Next is 012, movement core.** Every later step must cite the
ledger and affected scene/profile, run both structural budget profiles, and
remeasure the target before accepting visual cost. The A71 frame-rate debt and
historical Mid-profile device loss remain limitations; no added outdoor art cost
is authorized by passing the guard.

---

# Earlier provisional work and A71 stability investigation

**In progress, 13 November 2026.** The user asked to advance after the 007 desktop checkpoint;
007's original-phone evidence remains explicitly open. Do not pretend it passed or silently close it.
The user subsequently supplied a Galaxy A71 and asked for the game to run on it. Their correction is
explicit: **do not change the hardware requirements; this phone is around the minimum requirements.**

## Current work

- New `vo-budget` route and `budget_inventory.gd`, reusing the standard field path builder and battle fixture.
- Source complexity covers geometry, surface submissions, base-LOD instanced triangle capacity, distinct
  materials, conservative transparent-source surfaces and deduplicated RGBA8/full-mip texture equivalent.
- Headless dummy rendering does not retain usable MultiMesh transforms/AABBs. Headless budgets therefore
  count the entire subtree including hidden geometry, not visible draws. Rendered source inventories use
  actual transforms and frustum AABBs. Actual renderer draw/primitive/time/texture counters stay separate.
- Generated **provisional** `ledger/budgets.json` and `budgets.md` use explicit recordings
  `build/perf/vo/011/headless-desktop-01/` and `headless-touch-01/`. Tests never regenerate limits.
- `vo-budget`, `vo-budget-touch`, `budget-inventory` added to the runner. Final checks still required.
- The first raw record failed on a PrimitiveMesh API call and is invalid; record-02 used unusable dummy
  MultiMesh transforms for frustum counts and is superseded. Do not promote those raw records.
- Native `forward-01` lost foreground focus and is invalid. The queued renderer chain stopped there.
- `tools/vo_export_probe.py` verifies actual default Windows export renderers without a command override.
  First forward export confirmed Forward+/Vulkan, cache enabled, but its collector expected a separate PCK
  although the preset embeds it. That collector is fixed; repeat under a new --attempt. Compatibility probe
  and rendered scene tables remain pending. Web/phone actual-export evidence from earlier steps is retained.

## A71 facts and preserved data

ADB serial `R58N22FFRCB`, model SM-A715F, Android 13, SoC SM7150; runtime Vulkan header reports Adreno 618.
The user installed `com.rubycocoon.x`. It remains in place; no saves were read/cleared/copied. Benchmark
package is `com.rubycocoon.vo_perf`. A separate playable **Ruby Cocoon Compatibility** was installed as
`com.rubycocoon.compat`; it preserves the user's existing installation. All benchmark state is isolated.

The user said the phone will not be touched and authorized all needed testing; ask only for physical
interaction if needed. They also authorized keeping it awake via ADB. Temporary charging
stay-awake flag **3 (AC and USB)** has now been restored to its original value **0**, confirmed by ADB and
recorded as restored in `build/perf/vo/011/a71-playable-compat/usb-stay-awake.json`.
Preserve lock/PIN settings. Ordinary game foreground was not force-stopped by us;
cleanup commands target only the temporary benchmark. User-installed game has its own native crash record.
Android reports `mStayOn=false` despite that flag: device administration enforces a maximum screen-off
timeout of 300000 ms. Do not change that policy or the PIN/lock settings. Keep the stable playable game
foreground between tests; the benchmark requests screen keep-on during its runs. The user has opened a
game to keep the phone awake and confirmed it will otherwise remain untouched.

## Stability / performance evidence so far

1. `007-v2/phone-a71`: Mid/720p Mobile benchmark hit Vulkan device-loss errors and aborted. Cleanup succeeded,
   player package path unchanged. Crash buffer also shows native SIGTRAPs in VkThread for the user-installed
   game and the benchmark, with different engine build IDs; identical underlying causes are not proven.
2. `011/a71-playable-compat/startup-02`: actual OpenGL startup confirmed, **62.2 seconds stable**, screenshot
   `phone.png` shows the playable bedroom/dialogue and touch controls. User independently reported no crash.
3. `007-a71-compat/phone`: Compatibility Mid/720p standard route is far too slow. Completed Coastal Path
   segment median 146.702 ms (~6.8 fps), Cove median 176.0435 ms. Stopped our own benchmark deliberately for
   triage before its first complete pass; preserve as diagnostic only, not an accepted three-pass result.
4. `011-a71-min-mobile/phone`: existing Min/540p Mobile profile completed all five fixtures. Completed report
   and private benchmark archive recovered with `--attach` after a transient USB disconnect at ~127 s.
   `observer-recovery.json` records the historical-logcat coverage gap. No reported focus/runtime problems;
   outdoor snapshot frame medians remain ~83–116 ms, so stability does not establish acceptable performance.
5. `011-a71-gpu-trial-03/phone`: valid six-pass attribution, 299.7 s. Coastal baseline GPU medians
   71.62/91.31/85.95 ms; terrain hidden 26.79/26.47/28.53 ms; final control 71.82/91.05/86.55 ms.
   Hiding foliage or increasing LOD threshold helped much less. Earlier trial-02 leaked cached visibility
   and is explicitly invalid; trial-01 used an incomplete material selector. Do not cite either for savings.
6. `011-a71-terrain-ab/phone`: original/branch-cleanup/original, 170.0 s, same 252/266/275 draws.
   Original GPU 72.0525/91.525/87.758 ms, cleanup 53.825/66.3525/64.4085 ms, final original
   70.8925/89.5565/87.3645 ms. This removes unused calculations and preserves analytical noise/formulas.
   Desktop matched crops (`011/terrain-pixel-comparison.json`) have zero changed path/grass pixels;
   cliff crop differs in five of 6000 pixels by at most one channel value. It still misses 30 fps outdoors.
7. `011-a71-noise-ab/phone`: rejected diagnostic lookup-noise variant, 120.9 s. Only ~1–3 ms GPU gain,
   with different noise placement. Prototype remains in `tools/experiments/011/terrain_lookup.gdshader`;
   production terrain retains analytical noise. Do not compare its separate baseline epoch as a controlled
   improvement over the prior terrain test.
8. `011-a71-mid-no-msaa/phone`: disabling MSAA alone still hit device loss. The subsequent
   `011-a71-mid-no-shadows/phone` launch also hit Vulkan device loss with SIGTRAP in VkThread;
   its earlier lock-blocked attempt supplies no performance evidence. Neither switch alone prevents it.
9. `011-a71-lighting-ab/phone`: isolated pixel/vertex/pixel diagnostic, 157.7 s, three completed passes
   with no reported focus/runtime problems. Baseline GPU 53.9265/66.337/63.901 ms, vertex lighting
   51.0195/59.383/50.3725 ms, final baseline 53.775/66.232/63.817 ms. Draws remain 252/266/275;
   candidate changes 62 standard materials and two shaders, restored in the final control. This still
   misses 30 fps and is **not adopted** as a preset change. Headless three-pass smoke also passed.
   `phone-startup-focus-invalid/` preserves the first launch interrupted by foreground loss; excluded.
10. `011-a71-mid-no-glow/phone`: current-source Mid/720p diagnostic with glow disabled also hit Vulkan
    device loss/SIGTRAP after entering Coastal. This is not an accepted timing result. It does not prove
    the independent effects are unrelated or exclude interactions/resolution/driver faults; no production
    workaround follows from it. All three failed diagnostic packages were force-stopped, with unchanged
    player-package paths verified. The stable playable Compatibility app was brought back to foreground.

Do not infer the whole problem from frame intervals or promise 30 fps. Existing 30/60 fps hardware goals are unchanged.
No global renderer/preset policy has been changed; all A71 variants are explicitly isolated experiments.

Latest focused checks: `build/vo011-final-focused-02.json` has six passes (script compilation,
both budget profiles, synthetic inventory, terrain and video settings). The earlier quick run's
data/maps/beasts passed but scripts caught a concurrent `beasts_page.gd` type-inference error;
that file was independently corrected in the shared checkout before the successful compilation rerun.
Do not describe the original quick result as an uninterrupted pass. Final glow-hook focused checks
are recorded separately in `build/vo011-glow-focused.json`.

## Evidence boundaries

Current 4.7 measurements and budget ceilings remain provisional. The newly scheduled
[010c migration assessment](010c-godot-48-plan.md) places engine adoption before 011 budget acceptance;
preserve these results and remeasure on the adopted engine rather than relabelling them.
Native terrain also warns that the baked ground source hash is stale. Shader edits do not cause that
warning: the bake hashes terrain mesh/elevation/shoreline sources. Native regeneration and exports that
trust the baked set may therefore use different geometry epochs. No ground rebake has been performed
here; this discrepancy must be resolved before claiming source/export budget equivalence.

## Reproduction / continuation

```text
python tools/vo_device_profile.py run --tag=011-a71-min-mobile --serial R58N22FFRCB --renderer=mobile --attach
python tools/vo_budget.py record --headless --attempt=<new-name>
python tools/vo_budget.py record --headless --touch --attempt=<new-name>
python tools/vo_budget.py record --renderer=forward_plus --attempt=<new-name>
python tools/vo_export_probe.py --attempt=<new-name>
```

`vo_device_profile.py export/run` supports explicit --quality/--height/--renderer and fresh --tag folders.
It reuses the shared Android exporter/recorder and resource lock. Do not overwrite prior attempts.
`vo_budget.py generate` explicitly creates candidate limits from headless reports and rendered tables from
native reports; review them, test a regression failure, run quick and focused checks, and cite their limits.
Hold the shared resource lock for phone/native/export work. Do not run Blender or model inference around it.

Claude can independently prepare the [isolated 030 rock candidate](claude-030-candidate-handoff.md).
Heavy Blender jobs wait for the same lock; no runtime integration or published-art edits are authorized there.

At this 13 November checkpoint, rendered tables, export coverage, guard validation and A71 disposition
were still open. The 14 November acceptance above supersedes this continuation note. Budget guard
success still does not certify the frame targets.
