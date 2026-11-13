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
interaction if needed. They also authorized keeping it awake via ADB. Current temporary global USB
stay-awake flag is **2**, original value **0**, recorded in
`build/perf/vo/011/a71-playable-compat/usb-stay-awake.json`. **Restore the original after testing**, then mark
that record restored. Preserve lock/PIN settings. Ordinary game foreground was not force-stopped by us;
cleanup commands target only the temporary benchmark. User-installed game has its own native crash record.

## Stability / performance evidence so far

1. `007-v2/phone-a71`: Mid/720p Mobile benchmark hit Vulkan device-loss errors and aborted. Cleanup succeeded,
   player package path unchanged. Crash buffer also shows native SIGTRAPs in VkThread for the user-installed
   game and the benchmark, with different engine build IDs; identical underlying causes are not proven.
2. `011/a71-playable-compat/startup-02`: actual OpenGL startup confirmed, **62.2 seconds stable**, screenshot
   `phone.png` shows the playable bedroom/dialogue and touch controls. User independently reported no crash.
3. `007-a71-compat/phone`: Compatibility Mid/720p standard route is far too slow. Completed Coastal Path
   segment median 146.702 ms (~6.8 fps), Cove median 176.0435 ms. Stopped our own benchmark deliberately for
   triage before its first complete pass; preserve as diagnostic only, not an accepted three-pass result.
4. `011-a71-min-mobile/phone`: testing the existing Min/540p profile (MSAA/shadows disabled), one budget route
   pass. It progressed through Coastal and Cove without the immediate Mid-profile crash; snapshot frame
   medians still ~83–116 ms outdoors. USB observation disconnected transiently at ~127 s; device is back and
   `--attach` recovery was launched. Do not replace/clear it before recovering its report/archive.

The next decision needs actual GPU versus tick/render CPU values from that recovered report. Do not infer
the whole problem from frame intervals or promise 30 fps. Existing 30/60 fps hardware goals are unchanged.
No global renderer/preset policy has been changed; all A71 variants are explicitly isolated experiments.

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
