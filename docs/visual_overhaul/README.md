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

**001: P1, reproducible perf runs.** Update this line when a step finishes.

## How to prompt

Start a fresh session and say **"Run runbook step 001."** One step per session. Then:
- "Approve step NNN" or "Redo step NNN: …" after the screenshots;
- "Continue runbook step NNN" to pick up a stopped step;
- "What's the next runbook step?".

The full protocol is in runbook.md §4–§5. Never: start a second step in the same session, touch player saves, hand-edit `tools/smoothed.json`, commit or create branches unless the user asks, or change the interface style before Phase U (steps 163–165).
