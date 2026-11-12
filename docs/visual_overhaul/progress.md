# Progress

Statuses: `todo`, `in progress`, `waiting for approval`, `approved` (visual steps, by the user), `done` (tooling and performance steps), `split`.

| Step | Status | Date | Evidence | Notes |
|---|---|---|---|---|
| Setup: audit, decisions, rules updated | done | 2026-11-12 | audit.md | AGENTS.md, README Art and memory now point to the Animal Crossing-inspired direction |
| 001 (P1) | done | 2026-11-12 | [Report](001-performance.md), `build/perf/vo/baseline-desktop/`, `build/shots/vo/001/` | Eight accepted runs; largest median difference 0.123% (limit 5%); 16 command checks, final quick and performance passed. Forced screen input for the touch fixture; fixed freed deferred-node callbacks. Existing shutdown warnings remain; game visuals unchanged. |
| 002 (P2) | done | 2026-11-12 | [Report](002-phone.md), `ledger/perf.md`, `build/perf/vo/baseline-phone/` | Real razr 2024, 720p/Mid: seven loops / 993.36 s; medians ~29–30 fps; battery 30.7–31.9°C. No focus losses or benchmark errors. 339.37 s temperature gap documented. Thread-safe pad delivery; 14 cached images unchanged. |
| 003 (P3) | done | 2026-11-12 | [Report](003-web.md), `ledger/perf.md`, `build/perf/vo/baseline-web/`, `build/shots/vo/003/after/` | Two single-thread Web passes / 161.61 s; medians ~60 fps; first/return black holds recorded. Browser caches were not cleared after preflight. Audio error after final save retained. Quick + route check passed. |

Review protocol (user, 2026-11-12): always state the step; automatically continue completed nonvisual steps. Visual changes require screenshots and approval. After approval, continue unless the user asks to pause. Review choices: approve and continue, request changes, approve and pause.

Ownership (latest user direction, 2026-11-12): stop after 003 for fresh Claude and Codex chats.
Claude authors isolated artwork candidates; Codex owns code, integration, testing and technical review.
The proposed odd/even split is cancelled. Next numbered step is 004, owned by fresh Codex.
Follow [parallel-handoff.md](parallel-handoff.md) for file ownership and shared local-model/hardware locks.
