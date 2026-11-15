# 012 — shared movement core

**15 November follow-up:** the user explicitly requested step 013. Its public
preference/input integration is tracked in [013](013-diagonal-input.md), while
012's existing Rue Royale budget gate remains open. Historical checkpoint
statements below describe 012's state before that instruction.

Implementation checkpoint, 14 November 2026. **Not complete:** required checkout
gates must pass before step 013 starts. No new public preference or input mapping.

## Scope and existing behavior

README Controls already documents eight-way controller-stick movement. The
runbook's planned option therefore extends an existing core; it is not a new
implementation from scratch. The existing stick behavior remains with the staged
core off. Keyboard, touch, physical d-pad and tap paths retain their current input.
`--diagonal_core=1` enables the core for diagnostics; 013 owns persistence and UI.

`scripts/world/walker_step.gd` shares neighbour validation between hero, NPC and
beast walkers. A diagonal needs both side tiles, its destination and all four
elevation joins; ramps, diagonal-cliff tiles and cardinal-only approaches are
excluded. Actor-specific occupancy and roaming restrictions remain with the
world. A blocked hero diagonal slides only when exactly one cardinal component
is free. Interactions retain cardinal facing, and doors/exits keep their existing
cardinal approach. Diagonal travel time scales by sqrt(2), including roaming
NPCs and wild beasts. Scripted NPC paths are checked before their reservations
are removed. The off path retains the existing movement rules.

Movement policy is separate from `elevation.gd` because that file's complete
source pins the approved baked terrain. An initial unused helper there caused a
stale-cache warning during early checks; it was moved out, restoring that source
exactly. No terrain rebake, texture change, budget increase or artwork adoption.

## Verification and remaining gates

Evidence is under `build/perf/vo/012/`, including baseline logs, subsequent
wrapper results, Android export metadata and device output. Tests use isolated
save and preferences paths. Early checkout compilation failed in concurrent
temple work: a duplicate loop variable in `map_loader.gd` and two inferred types
in `round_chamber.gd`. Only those variable/type declarations were corrected;
the authored temple geometry and maps were preserved.

The baseline movement scenarios reported passes for flow, walk, walk-touch,
lessons and wild-grace. The initial focused core run identified an actor-occupancy
mistake: a beast's own source was being treated as a cardinal-only approach.
Occupancy now belongs to the actor callback; the corrected core fixture passes
204 checks in both desktop and touch layouts. Additional door-dispatch and NPC
timing checks bring the final fixture to **212 passing checks** on desktop,
2400×1080 touch layout and the attached Samsung A71 (SM-A715F, Android 13).
The phone export uses pinned beta3 templates and an isolated
`com.rubycocoon.vo_movement` package, removed after verification. Its saves and
preferences live under `user://bench/vo/012/`; the player app is untouched.
These are automated core checks on the device, not a physical touch-input test
or a frame-rate measurement.

The 2400×1080 A71 capture is
`build/perf/vo/012/phone/diagonal.png`, with its success marker and absence of
script errors in `phone/device.json` and `phone/logcat.log`. Direct image
inspection confirms the player and all six touch controls are visible; scenery
under the pad is expected. The first screenshot attempt lacked its output
directory; the final fixture creates it, and the collector verifies PNG bytes.
The final phone run was re-exported and repeated successfully. Android package
enumeration afterward confirms the test package is absent and the existing
player packages remain installed.

The final isolated quick checks pass: scripts, data, maps and beasts. The
initial map failure described below was resolved by concurrent chamber edits;
this task did not change its layout. A first combined movement matrix had its
logs deleted by another run using the shared default directory; that result is
invalid evidence. The replacement wrapper on port 5012 uses
`build/perf/vo/012/logs/final/`, independently of the shared runner.

Current checkout failures prevent closure:

- Initially the map checker reported two reef story-state failures. Temple of Tides F2's
  `from_temple_tides_song` spawn `(1, 9)`, exit `(0, 9)` and guardian `(9, 9)` are
  unreachable in the chamber/map work. **Resolved in the final check**:
  309 interiors checked, zero map problems.
- Both `vo-budget` profiles reject Rue Royale's texture inventory at all three
  sample positions: **22,334,841 bytes > 19,781,566 bytes**. See
  [reviewed budgets](ledger/budgets.md); no limit is raised. These are structural
  source-inventory checks, not phone frame-time measurements. The A71's existing
  outdoor frame-rate debt remains.

The new movement code creates no rendering resources. Budget and map failures
are retained as gates; passing the core fixture does not waive them. Continue 012
after the scene inventory is reconciled, then rerun the affected checks and
both budget guards before considering 013.

## Final checkpoint results

The isolated wrapper finished **16/18 passing in 6m15s**. Its exact summary is
`build/perf/vo/012/after/final-tests.json`; raw logs and result files are in
`build/perf/vo/012/logs/final/`.

| Check group | Result |
|---|---|
| Quick: scripts, data, maps, beasts | 4/4 pass |
| Diagonal fixture: desktop and touch | 2/2 pass, 212 checks each |
| Walk, walk-touch, wild-grace, flow, lessons: existing core | 5/5 pass |
| Same five scenarios with `--diagonal_core=1` | 5/5 pass |
| Desktop and touch budget guards | 2 failures, Rue Royale texture bytes only |
| A71 exported core fixture | 212 checks pass, no script errors |
| Patch whitespace | `git diff --check` passes |

No full-suite or device performance claim is made. Step 012 stays **in progress**
on the budget gate; step 013 has not begun. Relevant source hashes are in
`build/perf/vo/012/source-sha256.json`.

## Local-model assistance

The local model was available. Its diff review alleged missing elevation-edge
checks, unsafe occupancy recursion and incorrect sqrt(2) duration. Direct code
inspection and the focused fixtures contradict those claims: every edge is
checked, occupancy callbacks deliberately omit recursive step validation, and
sqrt(2) duration is explicitly required for equal ground speed. Those suggestions
were not adopted. Its failed-log summaries located the beast fixture and map
failures; its claim that stale terrain caused the beast failures was also
rejected after the actor-occupancy bug was reproduced and corrected.
Its capture review correctly located the controls but misidentified the game and
called their ordinary scenery overlap clipping. Direct inspection rejects those
claims; the image is evidence of the existing game's test state, not an art
comparison or an approval request.
