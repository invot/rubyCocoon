# Step 009a — production loading-phase attribution

Completed 12 November 2026. No production visual, warm-up, shader or asset change. The opt-in instrumentation
times the existing transition's calls/awaits. Both accepted native runs have two passes, zero problems and zero focus
losses: desktop Mobile 146.72 seconds and Compatibility 181.03 seconds, 1920×1080 / 1080p/Mid, Godot 4.7 on the
Ryzen 9700X/Radeon RX 9060 XT. These are not phone results or a controlled speedup comparison.

## Evidence and verification

- `build/perf/vo/009a/focused-01/{mobile,gl_compatibility}-cost.json/.log`.
- Generated `validated-phases.json` and `phases.md`: `python tools/vo_load_summary.py --attempt focused-01`.
  Validates the existing route statistics, two complete passes, unchanged route/sample counts, zero focus loss,
  finite nonnegative phase timings and their sum within total transition time.
- Quick (four checks), vo-perf-route and transitions passed through server.py; JSON summaries are beside the traces.
  No script/deferred-call/missing-resource errors in the accepted logs. Existing ObjectDB shutdown warnings remain.
- Each measured run held the shared resource lock. No other measured/heavy/model jobs were started during it;
  concurrent work was file reading and the small static candidate audit. Pre-existing Godot processes were not killed,
  so unknown background activity still limits claims about absolute headroom. No player state was read or changed.
- Earlier focus-lost attempts remain invalid and untouched; see 009a-loading-checkpoint.md for historical details.

## Attribution

The generated table is authoritative for all sixteen transitions. The **first process-frame await after viewport
re-enable** dominates Compatibility first visits: Path 21309.9 ms, Cove 4780.8 ms, house 3339.9 ms and Rue Royale
701.1 ms. On return those intervals are 7.5 / 8.4 / 2.0 / 4.9 ms. The second await is another 209–293 ms on first
visits and 2.4–4.1 ms on return. These are wall-clock frame-scheduling/render waits, **not isolated shader compiler
timers**. First-use rendering/driver/pipeline work is the priority lead; Compatibility's zero pipeline counters do not
quantify compilation. Source-level `_warm_shaders` work is submitted for those draws, not completed in its setup time.

Mobile's corresponding first waits are 5.8–28.5 ms. Its first Path costs are spread across world construction
(916.6 ms), dependency/world-script wait (565.6 ms), first-battle prewarm (405.6 ms) and arrival preparation
(365.3 ms). Later first-map construction is 222.6–577.4 ms, and return outdoor construction 99.8–343.7 ms.
Reuse is already significant; avoid deleting caches while pursuing a generic shader explanation.

The explicit surface-finish traversal is only 0.175–2.484 ms in Mobile; it is not the multi-second first-visit cause.
Earlier automatic finishing still occurs within construction, so this is not a complete accounting of finish work.
Field-audio prewarm is small in this fixture and does not explain the Compatibility waits. First battle/script loading
is a one-time Path cost, not a per-map shader count.

## Important black-time measurement correction

The old `black_ms` is sampled at process-frame boundaries. It can miss synchronous work or the first-draw stall before
the first fully-black sample: the accepted Compatibility house reports **234.5 ms sampled black** while its recorded
loading phases total **3628.6 ms**, all inside the fully-black loading section. Mobile's house similarly reports 25.1 ms
against 241.7 ms in loading phases. The total transition includes the work and bounds the phase sum.

Retain historical 001–003 JSON unmodified, but treat their black samples as frame-sampled intervals, not exact continuous
stopwatches. This limitation applies to the measurement method on every target; the demonstrated discrepancy is from
these native runs, not a newly measured phone/Web correction. Do not subtract the two counters or infer zero cost.

For 009b before/after and its 1.5-second criterion, add a continuous fully-black interval from the return of fade_out
through the call starting fade_in, including post-draw state/audio selection. Keep legacy samples alongside it for
traceability. Recollect the before measurement with that counter; this is justified by the concrete undercount above.

## Resulting work order

Continue automatically to **010a**: actual-phone 720p/Mid versus 540p/Mid, including frame pacing/refresh metadata.
005b remains the documented no-op from 005a. Then 009b should address Compatibility first-use draw/pipeline work
with correct continuous black timing, preserving the current visuals and Web cache caveats. Do not claim that cache
settings or shader warm-up alone solve it before controlled measurements. No new savings are claimed in 009a.
