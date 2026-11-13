# Progress

Statuses: `todo`, `in progress`, `waiting for approval`, `approved` (visual steps, by the user), `done` (tooling and performance steps), `split`.

| Step | Status | Date | Evidence | Notes |
|---|---|---|---|---|
| Setup: audit, decisions, rules updated | done | 2026-11-12 | audit.md | AGENTS.md, README Art and memory now point to the Animal Crossing-inspired direction |
| 001 (P1) | done | 2026-11-12 | [Report](001-performance.md), `build/perf/vo/baseline-desktop/`, `build/shots/vo/001/` | Eight accepted runs; largest median difference 0.123% (limit 5%); 16 command checks, final quick and performance passed. Forced screen input for the touch fixture; fixed freed deferred-node callbacks. Existing shutdown warnings remain; game visuals unchanged. |
| 002 (P2) | done | 2026-11-12 | [Report](002-phone.md), `ledger/perf.md`, `build/perf/vo/baseline-phone/` | Real razr 2024, 720p/Mid: seven loops / 993.36 s; medians ~29–30 fps; battery 30.7–31.9°C. No focus losses or benchmark errors. 339.37 s temperature gap documented. Thread-safe pad delivery; 14 cached images unchanged. |
| 003 (P3) | done | 2026-11-12 | [Report](003-web.md), `ledger/perf.md`, `build/perf/vo/baseline-web/`, `build/shots/vo/003/after/` | Two single-thread Web passes / 161.61 s; medians ~60 fps; first/return black holds recorded. Browser caches were not cleared after preflight. Audio error after final save retained. Quick + route check passed. |
| 004 (P4) | done | 2026-11-12 | [Diagnosis](004-cost-diagnosis.md), `ledger/perf.md`, `build/perf/vo/004/` | Three renderer inventories, headless build phases, pipeline counters and script probes; quick + route pass. Reordered/split 005–010. Existing sharing/batching and opaque grass invalidate blanket conversions. No production visual changes. |
| 005a (P5a) | done | 2026-11-12 | [Eligibility](005a-material-eligibility.md), `build/perf/vo/005a/`, `build/perf/vo/004/material-eligibility.*` | Exact property comparison plus mutation/semantic-role audit. Quick + route pass. 005b scoped to documented no-op: only two plausible house resources, no measured payoff. |
| 009a (P9a) | done | 2026-11-12 | [Phase report](009a-loading-phases.md), `build/perf/vo/009a/focused-01/` | Two clean passes per native renderer; quick + route + transitions pass. Compatibility first-frame waits dominate. Legacy sampled black time can undercount; continuous timer required for 009b. Earlier interrupted traces remain invalid. |
| 010a (P10a) | done | 2026-11-12 | [Phone experiment](010a-phone-resolution.md), `build/perf/vo/010a/phone/` | Three passes / 429.41 s, no problems/focus losses. 540p lowers GPU medians 7.3–20.3% but stays ~30 fps. 26.9–27.9°C; benchmark removed, player app preserved. No production video change. |
| 009b (P9b) | done | 2026-11-12 | [Report](009b-first-visit-checkpoint.md), `build/perf/vo/009b/` | Dedicated Compatibility profile (cache off) plus title-time shader precompile (approved): packaged first visits 508/798/55/442 ms, against 1272/1133/302/461. Cold first launch: about 28 s on the title. Shared warm-up no gain. **Web criterion not met** (user closed the step; precompile off on the web). Quick, transitions, title-startup, vo-perf-route pass. |
| 010b (P10b) | approved | 2026-11-12 | `build/shots/vo/010b/compare_{forward,compat,mobile-touch}.png` | Nearest enlargement replaced by bilinear on all renderers, plus a clamped mild sharpen (`resolve_sharpen.gdshader`) on Forward+/Mobile when enlarging. 540p and 720p before/after crops at 1920x1080 and 2400x1080 touch; video-settings, video-settings-touch and quick pass. Phone fps at 540p with the sharpen pass not yet measured. |
| Broadleaf rev_001 technical review (pre-027) | done | 2026-11-12 | [Review](art_reviews/broadleaf-rev_001.md), `build/perf/vo/art-review/` | User confirmed candidate-only approval. All 76 hashes match; geometry basics pass. UV seam / two-sided export follow-up prepared for rev_002. Integration still waits for 011/022/023 and in-game review. 027 remains open. |

Review protocol (user, 2026-11-12): always state the step; automatically continue completed nonvisual steps. Visual changes require screenshots and approval. After approval, continue unless the user asks to pause. Review choices: approve and continue, request changes, approve and pause.

Broadleaf candidate approval update (user, 2026-11-12): **rev_003 approved**, superseding rev_001 as the selected
candidate; rev_002 received change requests. Published revisions remain immutable. [rev_003 technical review](art_reviews/broadleaf-rev_003.md) is complete with integration follow-ups;
the rev_001 review above does not cover the replacement source/geometry. Integration still waits for 011/022/023
and actual in-game review. Technical review/attribution are now recorded. Step 027 remains open.

rev_003 review follow-up (2026-11-12): 154 hashes and all nine mesh counts match; index/UV/normal basics pass.
Two-sided crown shells and lower-LOD slivers remain explicit integration checks. Candidate provenance/credit is recorded
in CREDITS.md and licenses/broadleaf_roroer.md. No engine import or production replacement; 011/022/023 remain prerequisites.

Ownership (latest user direction, 2026-11-12): stop after 003 for fresh Claude and Codex chats.
Claude authors isolated artwork candidates; Codex owns code, integration, testing and technical review.
The proposed odd/even split is cancelled. Step 004 is complete; follow its revised execution order, starting with 005a.
Follow [parallel-handoff.md](parallel-handoff.md) for file ownership and shared local-model/hardware locks.
