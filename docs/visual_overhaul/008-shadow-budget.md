# 008a: controlled shadow diagnosis

Status: 008a complete with desktop/film measurement limitations below. Production shadow settings and artwork are unchanged.
This is the nonvisual engineering portion of 008; any resulting authored lighting/caster
change belongs to 008b and needs matched gameplay views and user review.

## Reproduction

`python tools/vo_shadow_sweep.py desktop --renderer mobile --attempt desktop-mobile-01`
runs the existing fixed route at 720p/Mid with shadows on/off/on and 1920×1080 output.
It preserves attempts, logs the command, acquires the shared resource lock, isolates
preferences/saves, and rejects errors or focus loss. Captures are separated by pass.

`python tools/vo_shadow_sweep.py export`, followed by
`python tools/vo_shadow_sweep.py phone --serial ZY22K7BD2J`, uses a separate benchmark APK
and isolated `bench/vo/008` state. It never replaces the player's package. The runner
shares the same lock as desktop measurements and model requests.

The validator recomputes summary statistics from every raw trace, checks identical
routes/settings and effective light configurations, rejects a shadow light left on
in the off pass, and checks restoration. Godot-generated unnamed-node IDs are
normalized only for comparison; raw paths remain in the evidence. Unsupported GPU
counters produce no saving estimate. GPU differences describe the net effect of
disabling light shadows, not a timestamped isolated shadow pass. Bracket drift and
frame pacing must be reported separately.

## Existing implementation audit

- World and battle sunlight already use a 30-unit distance and two splits
  (`world.gd`, `battle.gd`). Min disables authored light shadows; Mid/Max retain them
  through the shared `render_quality.gd`. No distance increase is justified by this audit.
- The hero-house interior is a separate path: `world.gd`'s indoor sun enables shadows
  without overriding the engine defaults. Runtime evidence confirms **100 units and
  four splits**. This is a concrete coverage/budget question for 008b, not evidence
  that the unstable house timing can be credited as a saving.
- Grass, flowers, lily pads, fences, low undergrowth and outer-ring shrubs/rocks
  already request shadowless batches. Trees deep in woods are shadowless; trees
  near open ground can cast. Chunked 8×8 MultiMeshes remain intact.
- Street lamps, signs and structural rails/pier pieces use the batch helper's
  shadow-enabled default. Their visual contribution and size need inspection before
  selecting any narrower eligibility rule; a blanket removal is not implemented.
- Battle scenery is made shadowless before trainer/fighter construction. The cool
  rim and dressing practical lights are shadowless. Preserve this distinction.
- The hatchery's OculusKey is a shadow-casting spot with range 26 and angle 26°.
  FrontFill is shadowless with range 13; two shadowless LanternWarmth fills have
  range 6.5. CoreDownlight is shadowless with range 9 and angle 42°.
  `enlarge()` scales local-light ranges for the merge stage. Chamber/roundel/conduit
  geometry, beams, halos and dust are shadowless; mechanism/subject parts can cast.
  The field route does **not** measure these films, so this source audit does not
  establish their peak overlap or GPU cost. Energy alone is not a cost estimate.

## Verification

Quick checks, `vo-perf-route`, `video-settings`, `video-settings-touch`, `polish`,
`polish-touch` and `battle-stage` pass through `server.py` (raw summaries in
`build/vo-resume-*.json`). `vo-shadow-route` passes all three requested states and
checks each arriving field light against its registered authored baseline.
`python tools/test_vo_shadow_sweep.py` passes six validator checks, including
focus loss, a light left casting, changed distance, incorrect statistics and
unsupported GPU timing. Headless tests are correctness checks, not GPU evidence.
`python tools/test_vo_phone_sweep.py` passes two recovery checks: cleanup cannot
mask the original disconnect, and observer recovery cannot overwrite a changed
player-package snapshot. USB loss is distinguished from a confirmed app exit.

## Actual-phone results

`build/perf/vo/008/phone/{report.json,validated-shadows.json,shadows.md}` records
three on/off/on passes / **457.203 s**, Mobile / 720p / Mid, razr 2024 / Android 16 /
Mali-G615 MC2. Refresh 60 Hz, cap 60, VSync enabled, 2640×1080 output. All effective
light-state checks, raw statistics and restoration checks pass. Zero harness
problems/focus losses. Battery readings stayed 29.9°C, charging.

| Scene | On/off/return-on GPU median ms | Mean on minus off | On GPU drift | Frame medians ms |
|---|---|---:|---:|---|
| Coastal Path | 28.560 / 24.778 / 28.407 | 3.706 | −0.5% | 33.70 / 33.35 / 33.60 |
| Cove plaza | 26.219 / 22.758 / 25.972 | 3.337 | −0.9% | 33.38 / 33.30 / 33.36 |
| Rue Royale | 23.740 / 22.112 / 23.724 | 1.620 | −0.1% | 33.32 / 33.30 / 33.33 |
| Coast battle | 14.308 / 13.430 / 14.452 | 0.950 | +1.0% | 34.35 / 33.47 / 34.20 |
| Hero house | 6.578 / 12.741 / 13.717 | −2.594 | +108.5% | 16.71 / 33.25 / 33.30 |

The outdoor brackets support shadows as a measurable GPU contributor. Even removing
all light shadows did not resolve the near-30-fps outdoor frame pacing. A narrower
caster/distance change can save only part of this diagnostic difference; no expected
production saving is asserted. House results are inconclusive because of the large
drift/pacing change. Raw outliers remain, including an initial Path frame near 923 ms.

USB observation failed during the first pass. The same benchmark PID 10015 remained
running and unlocked; `--attach` recovered observation without reinstalling or
restarting. No new heavy job or model inference ran during the recovery gap. The
largest temperature gap is **108.084 s**; continuous thermal and host-lock coverage
cannot be claimed. Retained logcat contains the completed pass markers, allocator
format/usage warnings and startup QUEUE_BUFFER_TIMEOUT entries; no Godot SCRIPT ERROR
or Godot ERROR was found. Harness focus/error counters remain clean.

APK SHA-256: `5207efe30e5ca9a4d5536b33a522be968b9ea49162ed72ed1eef6ba5a0a5b740`.
The benchmark is an exported snapshot, not verification of concurrent font edits.
Original player-package paths match; temporary package was uninstalled. Export
presets match the preserved original bytes. Thirty captures are extracted under
`phone/extracted/`. Authored-on/off views of Path, Cove and battle are assembled in
`build/shots/vo/008/shadow-diagnostic.png`. Path views were inspected directly:
the off pass removes building/tree shade and some grounding; it is not an art proposal.

Local-model help: checkpoint summary, completed-log triage and a first-look comparison
of the diagnostic sheet, all through the shared wrappers. Its log answer called an
XR property WARNING a Godot error; the actual line is a warning, confirmed directly.
It omitted the queue-buffer timeouts noted above. Its image answer overstated the
loss of all grounding and claimed shadows under UI elements; direct inspection shows
contact/baked shading remains, and the switch changes light shadows only. These
claims were not used to justify a production edit. A separate earlier log request
timed out waiting for the busy resource lock and ran no inference.

## Desktop limit and next checkpoint

`build/perf/vo/008/desktop-mobile-01/` lost foreground focus and is marked INVALID.
It is not accepted desktop performance evidence; no automatic retry was made.
A future focused desktop run needs a fresh `--attempt`, and any adopted change
needs its own matched before/after measurements. Phone data does not establish PC,
Web, minimum-class or mid-class Snapdragon performance.

Continue with [Claude's concrete 008b visual handoff](claude-008b-handoff.md).
The whole of 008 remains open. Do not advance 006 or the art integration prerequisites.
