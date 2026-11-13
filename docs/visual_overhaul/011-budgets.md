# 011 — measured budgets / A71 stability checkpoint

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

Do not mark 011 complete yet. Actual rendered tables, renderer-export coverage, guard validation and A71
stability/performance disposition are still required. Budget guard success will not certify the frame targets.
