# Claude handoff: 008b shadows and light coverage

> **Returned 2026-11-12, user-approved:** see [claude-008b-result.md](claude-008b-result.md) for the settings to integrate.
> **Integrated and verified:** [008b-integration.md](008b-integration.md). Requested film experiment returned in [claude-008b-cost-return.md](claude-008b-cost-return.md); film lighting retained.

Codex has completed the nonvisual 008a diagnosis and 010b's missing phone evidence.
**Next work requires visual judgement/authorship.** Production lighting is unchanged.
Read AGENTS.md, runbook §1–§5 and 008/008a/008b, parallel-handoff.md, and
[the measured diagnosis](008-shadow-budget.md). Preserve concurrent font/UI work.
No commits, branches, resets, production art replacement or broadleaf integration.

## Evidence to inspect

- `build/shots/vo/008/shadow-diagnostic.png`: authored shadows on (left), diagnostic
  all-light-shadows off (right), from the actual phone run. This is a diagnostic
  comparison, **not** an approved replacement look.
- Full-resolution captures in `build/perf/vo/008/phone/extracted/pass_01/`,
  `pass_02/` and `pass_03/`, including endpoints. Match them by filename.
- `build/perf/vo/008/phone/shadows.md` and raw report. Outdoor shadow-off GPU
  differences are 3.706 ms Path, 3.337 ms Cove, 1.620 ms Rue Royale; battle 0.950 ms.
  Outdoor frames still sit near 33 ms. House results are inconclusive (+108.5% drift).
  USB recovery left a 108-second observation/temperature gap. Desktop attempt is INVALID.

## Concrete visual work

1. Identify which shadow silhouettes keep people, trees, buildings and small props
   grounded in Path/Cove/Rue Royale. Inspect hero/door/tree bases at gameplay scale,
   especially where existing contact shadows survive. Keep useful large-tree/building
   shadows. Inspect existing shadow-enabled lamp/sign/structural batches before
   proposing any category-specific exclusion; do not turn all shadows off.
2. Inspect indoor coverage in the hero's house, including camera motion and wide touch
   layout. The indoor sun currently retains **100 units / four splits**, whereas
   world and battle use **30 / two**. Propose the smallest justified coverage/split
   change from actual views, checking shadow stability and room edges. The house
   timing does not establish a performance gain. Code changes remain Codex-owned:
   leave concrete scene/settings recommendations for integration.
3. Inspect the hatch/merge stage's important silhouettes and local-light overlap.
   OculusKey is the one shadow-casting spot; fills/core light are shadowless.
   `HatcheryStage.enlarge()` scales ranges. Existing field-route timings say nothing
   about the films' peak cost. Preserve film timing, readability and stage enclosure;
   request a focused cost experiment before removing/reworking visible light layers.

Keep this checkpoint scoped to lighting/caster coverage. If the existing look is
already the best measured trade-off, document an evidence-backed no-op rather than
changing artwork to satisfy the step. The separate font review remains separate;
do not overwrite current font decisions based on this older exported snapshot.

## Return checkpoint

Return concrete settings/caster recommendations and representative gameplay
before/after shots for any authored visual candidate, with unchanged-camera and
touch comparisons. Codex integrates shared code and measures the actual candidate,
including a fresh focused desktop attempt and phone on/off/control where useful.
Run quick, vo-shadow-route and battle-stage (plus affected named tests).
User visual approval is required before closing 008b/008 and advancing 006.
No new visual candidate was authored in the Codex diagnosis, so no visual approval
is being requested for the all-shadows-off diagnostic board.

All heavy Blender/measured native commands and local-model requests must use the
project's shared lock wrappers. The earlier benchmark and model jobs have finished;
verify current checkpoint before starting in case another chat has begun work.
