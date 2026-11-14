# Ruby Cocoon overhaul

## Typography direction — user decision, 12 November 2026

This decision supersedes earlier instructions to use League Spartan for all text.
- Headings and names: League Spartan Semibold (600).
- Body text, menu actions, values, dialogue and damage numbers: Fuzzy Bubbles.
- Lettering physically painted, engraved or displayed on objects in the 3D world: Noto Sans Old North Arabian, using a deterministic mapping from English letters (and explicitly defined ligatures where needed) to its glyphs. Do not render English lettering on world objects. This is a fictional substitution alphabet, not an Arabic translation. Preserve the underlying readable English for dialogue, interaction descriptions and accessibility.
- UI and spoken dialogue remain readable English; they are not world-object lettering. Preserve the established intro/title logo exception unless the user changes it.
- Sources: [Fuzzy Bubbles](https://fonts.google.com/specimen/Fuzzy+Bubbles), [Noto Sans Old North Arabian](https://fonts.google.com/noto/specimen/Noto+Sans+Old+North+Arabian).
- Implementation checkpoint: Fuzzy Bubbles body/dialogue and the shared world-lettering font/map are now wired in; see [font-update.md](font-update.md). Generic signpost artwork and dedicated world-lettering visual review remain. Verify glyph coverage, wrapping, touch layouts and actual before/after game screenshots. Do not shrink text to accommodate the new font.

Codex continues code, tests and nonvisual work. Stop at the next task requiring Claude's visual authorship and prepare its concrete handoff; do not silently perform that artwork.


The overhaul aims to make the game cozy, beautiful, clean and fast, and to add the exploration pillar. **Start with [runbook.md](runbook.md):** it is the single numbered chain of work (steps 001–169), with what to offload to the local model in each step.

| File | What it is |
|---|---|
| [runbook.md](runbook.md) | **The plan to follow.** Direction, current faults, local-model offloading, the step procedure, and every step in order |
| [progress.md](progress.md) | Which steps are done, waiting for approval, or split |
| [audit.md](audit.md) | Background: the audit of the original plan and the decisions of 12 Nov 2026 |
| [steps.md](steps.md), [exploration.md](exploration.md) | Background: the earlier phase plan and the exploration design (folded into the runbook; the runbook wins on order and scope) |
| [standards.md](standards.md), [checklist.md](checklist.md) | The full visual standard and enforcement checklist (steps cite their sections) |
| `ledger/` | Generated ledgers, budgets and perf notes (steps 004, 011, 016–019) |

## Next step

New **010c: Godot 4.8 migration** is scheduled immediately after 007 phone recovery/cleanup,
before 011 budget acceptance. See the [assessment and rework](010c-godot-48-plan.md).
The user approved beta3 and the comparison visuals; the main checkout now selects
4.8 beta 3. Main 19/19 checks and both Windows export paths pass under the guard;
see [results and rollback](010c-godot-48-results.md).
Broader 010c target/feature evidence and 007's original-phone recovery remain open. Existing 011
tooling remains provisional until remeasured. Unfinished 022a now covers offline texture baking
in place of LightmapGI, following the user’s direction; completed steps retain their status.
010c's offline ASTC anomaly investigation is complete: the 6×6 encoder nearest-resizes
to block-aligned dimensions, confounding the initial metric. Eighteen round trips and
four quick checks pass; no compression profile is adopted. Next is the isolated streaming
trial and remaining target validation, before 011 budget acceptance. See the results report.

**007: alpha and overdraw.** [006's batched scenery experiments](006-scenery.md) are complete:
keep 8×8 batches, preserve recentered LOD data and cover pad swell; no experimental visual change adopted.
Phone/Web results and remaining performance limits are recorded in that report.
[007's desktop checkpoint](007-alpha-overdraw.md) retains existing rendering; phone evidence and temporary-app
cleanup await a working ADB connection. Recover its report before starting another phone package.
[008b's approved indoor integration](008b-integration.md)
and film cost experiment are complete; films retain their lighting. See [Claude's returned evidence](claude-008b-cost-return.md).
[008a diagnosis](008-shadow-budget.md) retains its desktop/observation limits.
010b's missing [phone evidence](010b-phone-resolve.md) is complete;
its visual approval is retained. Steps 001–004, 005a, 009a, 009b and 010a are complete (009b closed with the
Web criterion recorded as not met); see [the diagnosis](004-cost-diagnosis.md) for the revised execution order and
[the parallel handoff](parallel-handoff.md) for Claude artwork and Codex engineering.
New Phase H (cozy homes, steps 037a–037c, added 2026-11-12) sits between 037 and 038; its
[home decor candidate](art_candidates/home_decor.md) rev_001 is approved as the candidate (integration waits for 022, 023 and 037).
rev_003's [technical review](art_reviews/broadleaf-rev_003.md) and attribution are complete; integration still awaits
011/022/023 and in-game review. Step 027 remains open.

## How to prompt

Say **"Run runbook step 001."** Work one step at a time. Tooling and measurement steps continue automatically after their checks pass; steps that affect the game's visuals stop for screenshot review. Then:
- "Approve step NNN" or "Redo step NNN: …" after the screenshots;
- "Continue runbook step NNN" to pick up a stopped step;
- "What's the next runbook step?".

After visual approval, continue to the next step unless the user chooses to pause. Always state the current step. At a review, offer **approve and continue**, **request changes**, or **approve and pause**. If a step is too large, split it and record a clean checkpoint before stopping; never start a dependency before its evidence is complete.

The full protocol is in runbook.md §4–§5. Never touch player saves, hand-edit `tools/smoothed.json`, commit or create branches unless the user asks, or change the interface style before Phase U (steps 163–165).
