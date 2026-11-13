# 007 — alpha and overdraw

13 November 2026. **Desktop checkpoint complete; required phone evidence remains open.**
No production material, geometry, particle count, film timing, fade or AA setting has changed.
Do not advance to 011 until the phone evidence/cleanup below is resolved or explicitly waived.

Claude can independently prepare the [isolated 028 shrub/flower candidate](claude-028-candidate-handoff.md).
That is preproduction, not completion or integration of 028.

## Actual transparency

The foliage shader writes colour/lighting, not ALPHA; ordinary grass is solid geometry.
The earlier 004 endpoint audit did not establish that there are no blended objects along a moving route.
The 007 moving Coastal Path inventory finds **12 blended BaseMaterial surfaces at its midpoint**.
`inventory-01.json` independently tags all twelve as members of `world.ripples`, with `TorusMesh` geometry:
they are intentional fishing ripples, not blended grass or leaves. The remaining transparent sources there
are water and contact shadows. Source/material inventories include scissor signage/characters and do not
equate those with blended foliage. Preserve water, fishing cues, shadows and building/actor fades.
No blanket alpha-scissor conversion or depth-prepass removal is justified.

Inventories are conservative visible-frustum AABB/material estimates, including occluded and zero-alpha
surfaces. They are **not renderer transparent-pass counts or pixel-overdraw measurements**. Total renderer
draws are recorded separately; the isolated candidate changes only known transparent mesh visibility.
`tools/debug/vo_cost.gd` supplies shared material/overlay totals; `vo_alpha.gd` adds paths and CPU particles.

## Merge-film experiment

The existing film uses additive, unshaded, shadowless beams; its authored Sparks/Essence emitters retain
56/40/40 particles and 1.1-second lifetimes. Peak overlap captures cover parents, falling shaft, overlap,
landing and revealed child. Mist, dust, beams, halos and particle sources are listed per capture.

The isolated candidate hides only Beam1/2, DeckGlow1/2 and CenterBeam when their controlling alpha/power
is **exactly zero**. It never removes a partially visible layer, changes particle counts or touches lights.
It is not installed in `merge_cinematic.gd`. A separate AA experiment never applies this candidate.

Accepted desktop Mobile control/candidate/control, Mid, 720p, 1920×1080 window:

| Metric | Original | Hide exact-zero draws | Original |
|---|---:|---:|---:|
| Median total draws | 48 | 44 | 48 |
| Median primitives | 105806 | 105546 | 105806 |
| Median GPU ms | 0.299 | 0.299 | 0.287 |
| Median render CPU ms | 0.143 | 0.139 | 0.152 |
| Median frame interval ms | 16.667 | 16.682 | 16.679 |
| GPU ms, overlap frames 240–299 | 0.300 | 0.2985 | 0.288 |

Evidence: `build/perf/vo/007/mobile-film-02/`; matched captures under
`build/shots/vo/007/mobile-film-02/`, including [child comparison](../../build/shots/vo/007/zero_alpha.png).
Four draws disappear without a reliable GPU benefit. Keep current film rendering pending phone results;
the data does not justify reducing visible beams/halos/particles or changing the film's readability.

The film/AnimationPlayers advance at fixed 1/60 simulation steps. CPUParticles use fixed seeds,
`speed_scale=0` and requested simulation time, so screenshot waits do not advance them. See the official
[Godot 4.7 particle playback API](https://docs.godotengine.org/en/4.7/classes/class_cpuparticles3d.html#class-cpuparticles3d-method-request-particles-process).
Shader TIME/other engine effects can still vary; fixed seeds do not establish pixel-identical frames.
Both original controls in the accepted zero-alpha run have matching median primitives. The earlier
`mobile-film-01` predates this playback control and is preliminary, not the basis of the decision.

## Separate AA trial

`mobile-aa-02`: desktop Mobile, Mid/720p, 2400×1080 touch window, 1600×720 render target.
2× MSAA / FXAA with MSAA off / 2× MSAA. Effective properties are saved for the actual measured viewport.
The camera traverses Coastal Path; the merge timeline includes moving beam and character edges.

| Median GPU ms | 2× MSAA | FXAA | 2× MSAA |
|---|---:|---:|---:|
| Moving Coastal Path | 1.131 | 1.147 | 1.317 |
| Merge film | 0.360 | 0.310 | 0.348 |

Frame medians stay ~16.666 ms under presentation pacing. Field cost does not improve consistently;
the beam difference is small in absolute desktop time. [Foliage crops](../../build/shots/vo/007/aa_foliage.png)
and [beam crops](../../build/shots/vo/007/aa_beam.png) show no clear overall quality improvement that warrants
a default change. Retain 2× MSAA at Mid; never stack it with FXAA. Still crops alone cannot certify temporal
aliasing. The local model strongly preferred the left grass edges; its generic claims about AA were not
treated as measured facts. Direct image inspection and raw timings determine the decision.

`mobile-aa-01` is qualitative/preliminary: it predates deterministic particles and overlapped smoke checks.
Do not pool its timings with accepted runs. Desktop is a shared machine, not a dedicated benchmark rig;
other game previews were open when inspected later. Control variation and raw maxima remain recorded.
All desktop Mobile results are **desktop evidence**, never actual-phone results.

## Phone blocker and exact recovery

The player package is `com.rubycocoon.x`; diagnostics use only `com.rubycocoon.vo_perf` and isolated
`user://bench/vo/007-v2/` state. No player saves were accessed. The suite repeats the standard 002
walking/house/battle route, then the film, for three passes. It installed/launched but its ADB observer
disconnected before the first report could be pulled. Subsequent transports were missing/offline; even
a reconnect plus a bounded 90-second wait did not become ready after the user reconnected/unlocked it.
**No phone performance result is accepted.** One 26.9°C initial sample is not sustained thermal evidence.

- Suite APK SHA256: `d4d0957071f47ef6e967a521e2d1dc8c013390f2e9926b30f6ba72a22e6ab283`.
- AA APK SHA256: `5c21688c28e0c41455e88870bc8d805fe13e11c17936e8004951cc0608068252`.
- Evidence/partial logs: `build/perf/vo/007-v2/phone/`; AA export: `build/perf/vo/007-v2-aa/phone/`.
- AA was **not launched**: the new runner guard prevents replacing a benchmark awaiting observer recovery.
- Phone cleanup/player-package after-snapshot are **unverified** while USB is unavailable. Do not claim the
  temporary package was removed. Normal benchmark completion restores keep-on and exits, but completion
  of this specific on-device run has not been observed.

When ADB reports an awake connected device, recover first, without reinstalling or clearing:

```text
python tools/vo_alpha.py phone --part=suite --attach
```

The shared recorder now handles an already completed checkpoint even when the app has exited. It saves
the report/archive and attempts historical PID-filtered logcat, recording any ring-buffer coverage gap.
The Python reader then validates all traces, settings, routes, AA flags, 570 film samples and elapsed time.
If the recovered report has focus loss/script errors, keep it invalid and use a new versioned attempt;
never overwrite it or count it as completed evidence. Preserve the original player-package snapshot.
After suite validation, run `python tools/vo_alpha.py phone --part=aa` using the already built AA package.
Then validate/extract screenshots, compare phone costs, verify player identity and uninstall only
`com.rubycocoon.vo_perf`. A USB gap may prevent a full log audit; retain that limit explicitly.

## Verification

### New-device follow-up, 13 November

The Galaxy A71 (`R58N22FFRCB`) is now connected and authorized for testing; this does not recover
the interrupted run on the original phone. Keep that original evidence directory intact.
`007-v2/phone-a71` hit Vulkan device loss at Mid/720p. The separate Compatibility trial
`007-a71-compat/phone` was deliberately stopped for triage: Coastal median 146.702 ms and Cove
176.0435 ms, without a complete pass. Neither is an accepted three-pass alpha comparison.
Benchmark cleanup on the A71 preserves the player package identity. A separate playable
`com.rubycocoon.compat` remains available alongside the user's `com.rubycocoon.x`.
See [011's provisional A71 diagnosis](011-budgets.md) for accepted Min-profile measurements,
terrain attribution and crash-isolation trials. Requirements have not changed; the user describes
the A71 as around the minimum specification. Step 007 remains open for its missing comparisons.

`vo-alpha`, `vo-alpha-aa` and required `nature`: **all three pass** in 15 seconds. Quick's four checks
pass in eight seconds. Verification advances the complete 9.5-second film in 24 coarse steps;
those headless reports are not performance evidence. Four Python observer-recovery regressions pass,
including completed-without-PID recovery, invalid-report preservation and unchanged player identity checks.
`py_compile` and `git diff --check` pass. Shutdown ObjectDB/resource warnings remain visible in test logs.

Adopted game-visual changes: **none**. Screenshot approval is not requested for rejected diagnostic variants.
Keep 007 open for the phone comparison/cleanup, then decide whether it closes as an evidence-backed no-op.
