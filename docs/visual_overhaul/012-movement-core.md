# 012 — shared movement core

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
timing checks were subsequently added; final results are recorded below.

Current unrelated checkout failures prevent closure:

- The map checker reports two reef story-state failures. Temple of Tides F2's
  `from_temple_tides_song` spawn `(1, 9)`, exit `(0, 9)` and guardian `(9, 9)` are
  unreachable in the current chamber/map work.
- Both `vo-budget` profiles reject Rue Royale's texture inventory at all three
  sample positions: **22,334,841 bytes > 19,781,566 bytes**. See
  [reviewed budgets](ledger/budgets.md); no limit is raised. These are structural
  source-inventory checks, not phone frame-time measurements. The A71's existing
  outdoor frame-rate debt remains.

The new movement code creates no rendering resources. Budget and map failures
are retained as gates; passing the core fixture does not waive them. Continue 012
after the concurrent scene work and its inventory are reconciled, then rerun
quick and both budget guards before considering 013.

## Local-model assistance

The local model was available. Its diff review alleged missing elevation-edge
checks, unsafe occupancy recursion and incorrect sqrt(2) duration. Direct code
inspection and the focused fixtures contradict those claims: every edge is
checked, occupancy callbacks deliberately omit recursive step validation, and
sqrt(2) duration is explicitly required for equal ground speed. Those suggestions
were not adopted. Its failed-log summaries located the beast fixture and map
failures; its claim that stale terrain caused the beast failures was also
rejected after the actor-occupancy bug was reproduced and corrected.
