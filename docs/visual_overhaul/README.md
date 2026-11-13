# Ruby Cocoon overhaul

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

**009b: shader warm-up and first-visit changes.** Steps 001–004, 005a, 009a and 010a are complete; see
[the diagnosis](004-cost-diagnosis.md) for the revised execution order and
[the parallel handoff](parallel-handoff.md) for Claude artwork and Codex engineering.
The [accepted loading-phase report](009a-loading-phases.md) replaces the earlier measurement checkpoint.
rev_003's [technical review](art_reviews/broadleaf-rev_003.md) and attribution are complete; integration still awaits
011/022/023 and in-game review. The old rev_002 prompt is superseded. Step 027 remains open.

## How to prompt

Say **"Run runbook step 001."** Work one step at a time. Tooling and measurement steps continue automatically after their checks pass; steps that affect the game's visuals stop for screenshot review. Then:
- "Approve step NNN" or "Redo step NNN: …" after the screenshots;
- "Continue runbook step NNN" to pick up a stopped step;
- "What's the next runbook step?".

After visual approval, continue to the next step unless the user chooses to pause. Always state the current step. At a review, offer **approve and continue**, **request changes**, or **approve and pause**. If a step is too large, split it and record a clean checkpoint before stopping; never start a dependency before its evidence is complete.

The full protocol is in runbook.md §4–§5. Never touch player saves, hand-edit `tools/smoothed.json`, commit or create branches unless the user asks, or change the interface style before Phase U (steps 163–165).
