# Ledger

Tools generate these files. Don't type the generated ones by hand.

| File | Made by | Contents |
|---|---|---|
| `assets.csv` | `tools/visual_ledger.gd` (step L1) | Every rendered asset: ID, family, source/runtime path or recipe, licence, materials, textures, import settings, triangles, surfaces, the scenes using it, source/output SHA-256, and status |
| `scenes.csv` | step L2 | Every map, room, battle setting, film and geometry-changing story state, with its three standard cameras |
| `families.csv` | step L4 | Families with their member counts and status |
| `approvals.csv` | written at each user approval | ID, step, standard version, input hashes, renderer/profile, evidence path, date, approved by |
| `perf.md` | steps P2–P4 (by hand) | Baselines per device and renderer, plus the ranked cost diagnosis |
| `budgets.md` | step P11 | Measured per-scene budgets, checked by the `vo-budget` test |

Statuses: `unreviewed`, `rework`, `rebuild`, `ready for review`, `approved`, `retired`, `not shipped`. Missing data means `unreviewed`, never approved. A changed input hash puts an `approved` entry back to `ready for review` (the `vo-ledger` test).
