# Visual overhaul

This folder holds the plan for making Ruby Cocoon cozy, beautiful, clean and fast, with Animal Crossing: New Horizons as the reference for environmental cohesion.

| File | What it is |
|---|---|
| [audit.md](audit.md) | **Read first.** Gaps in the plan, current faults and the user's decisions (12 Nov 2026). These win over the other files |
| [steps.md](steps.md) | The work, in steps of about 1–2 hours |
| [exploration.md](exploration.md) | Exploration pillar: 3–4× roads, caves, GIANT beasts, puzzles, shortcuts, map-edge fix, pageant |
| [progress.md](progress.md) | Which steps are done, waiting for approval, or split |
| [standards.md](standards.md) | The full visual standard (reference: read only the sections a step names) |
| [checklist.md](checklist.md) | The enforcement checklist (reference) |
| `ledger/` | Generated asset/scene/approval ledgers, budgets and perf notes (from steps L1–L4, P4, P11) |

## Next step

**P1: reproducible perf runs.** Update this line when a step finishes.

## Session protocol (keeps each session inside usage limits)

Start a session with: *"Do step P1 from docs/visual_overhaul/steps.md."*

1. Read this file, the step's row in `steps.md`, and `audit.md` § Decisions. Open `standards.md` only at the sections the step names. Don't read whole large scripts: grep, then read the needed ranges.
2. Check the local model (`curl -s -m 5 http://localhost:1235/v1/models`, sandbox off). Give it test runs (`server.py` `tests`), log reading, first looks at shots, and summaries of long profiler or diff output.
3. Take **before** shots and numbers first, with the same commands you will use for **after**. Captures go in `build/shots/vo/<step>/`, numbers in `build/perf/vo/<step>/`. Measure with `tools/img.sh` and crops before reading full images.
4. Make the change through the existing shared builders, shaders and importers (AGENTS.md). Keep original packs untouched. New or re-baked world textures go through `tools/smooth_textures.gd`, then `--import`.
5. Run `bash tools/run_tests.sh quick` plus the step's named tests, and read the errors first.
6. From step L1 on, regenerate the ledger and run the `vo-ledger` test. From P11 on, run `vo-budget`.
7. Update `progress.md` and the "Next step" line above. Show the user the before/after shots and numbers. **Visual steps stop here until the user approves.** Mark the step `approved` only after the user says so, and record it in `ledger/approvals.csv`.
8. If the step won't fit, stop at a clean point, split it in `steps.md` (P5 → P5a/P5b), and note what remains.

Never: start a second step in the same session, touch player saves, hand-edit `tools/smoothed.json`, commit or create branches unless the user asks, or touch the interface style before Phase U.
