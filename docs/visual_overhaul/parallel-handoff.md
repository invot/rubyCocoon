# Parallel art and engineering handoff

User direction, 12 November 2026: after step 003, start fresh Claude and Codex chats
at the same time. Claude authors artwork; Codex owns code, integration, audit,
testing and technical review. The user approves visual changes. The odd/even split
is cancelled. This division supports parallel work, but does not promise equal
workload or twice the speed: artwork integration depends on the performance and
style foundations in the runbook.

## Shared checkout and machine

- Both chats use `D:/Games/Ruby Coccon`. Preserve all existing uncommitted work.
  No commits, branches, worktrees or resets unless the user asks.
- Claude owns only `tools/blender/art_candidates/broadleaf/`,
  `build/art_candidates/broadleaf/`, and
  `docs/visual_overhaul/art_candidates/broadleaf.md` for the initial task.
- Codex owns shared runtime code, shaders, importers, tests and runbook/progress
  documentation. Codex reads Claude's completed candidates without editing them.
- Claude writes a new revision directory for each delivery and writes `READY.json`
  **last**, atomically. It names the revision, files, hashes, source provenance,
  scale, triangle/material/texture counts and smoothing status. A ready revision
  stays immutable; corrections go in the next revision. No production replacement.
- Both use the **main checkout's** `tools/look.py` or `server.py` for local-model
  inference. These share `build/coordination/local-model.lock`; no direct chat API
  requests. Check `/v1/models` once at chat start; if unavailable, proceed unaided.
  Ask neutral questions and verify significant answers independently.
- Run heavy Blender generation/renders and measured native Godot commands through
  `python tools/local_resource.py -- <command>`. It acquires the same resource lock,
  avoiding interference from model inference or the other agent's heavy job.
  For browser/phone measurements, Codex must hold `tools.look.model_lock` for the
  whole measurement in a keeper process, releasing it at completion. Do not wrap
  `look.py`, `server.py`, or a job that invokes either: nested locks would wait on
  themselves. Ordinary text/code work can proceed concurrently.
- Server helpers must run outside the sandbox when required by AGENTS.md. Never
  restart the local model or kill another agent's process. Ask the user only when
  genuinely blocked; a busy lock means wait rather than bypass it.
- After the 13 November host memory-exhaustion incident, tests run serially by
  default through `tools/run_guarded.py`. Keep its memory cutoffs enabled. Archived
  010c snapshots contain superseded runners/fixtures: refresh the guard and bounded
  ring fixture before rerunning them. See `010c-godot-48-results.md`.

## Claude's first assignment: broadleaf artwork candidate

This is **preproduction for 027**, not execution or completion of 027. Steps 011,
022 and 023 have not established final budgets, material presets and scale sheets.
Keep candidates provisional until those prerequisites and user review are done.

Read AGENTS.md, README Art, runbook sections 1–5 and 027, and the relevant standard
sections on foliage, scale and materials. Inspect actual baseline gameplay shots
under `build/shots/vo/001/`, not filenames alone. Inspect
`assets/nature/tree_oak.res`, its provenance in `tools/import_psx_models.gd` and
`tools/prepare_stylized_nature.py`, and the source pack without modifying it.

Produce 2–3 broadleaf variants with tapered trunks, root flare and deliberate
rounded leaf-cluster masses, plus two LODs each. Use 1,000–3,000 triangles as a
provisional full-detail target and report actual counts. Rework a derivative first;
record why a procedural rebuild was needed if rework cannot achieve the silhouette.
Retain the game's existing scale. Every solid object must have a clean painted
texture: soft gradients and organized leaf shapes, without gritty noise, pixelated
texels, cube crowns, neon lawns or copied Animal Crossing art.

Deliver a repeatable Blender script, source scene, portable mesh export with
textures, material/scale manifest, and clearly labelled candidate turntable and
gameplay-angle preview images. Render previews as candidates, never as evidence of
in-game integration. Keep textures unsmoothed and report that status; Codex will
apply the shared smoothing/import pipeline once at integration. Do not edit
`tools/smoothed.json`, run a repository-wide import, overwrite runtime assets,
change maps/UI/builders/shaders, or mark a numbered runbook step complete.
Show previews to the user, write READY.json, and stop at that delivery checkpoint.

## Fresh Codex assignment

Start with runbook **004: cost diagnosis**, using the completed 001–003 evidence.
Read AGENTS.md, the runbook procedure and 004, progress.md, reports
001-performance.md, 002-phone.md, 003-web.md and ledger/perf.md. Inspect current
changes before editing; the checkout contains the completed baseline work and
must not be reset. Do not repeat baselines unless a concrete concern requires it.

Own code audit, profiling, shared builders/shaders/importers, technical artwork
review, integration, tests and real-window verification. Rank measured causes by
scene and target, distinguish measurements from estimated savings, and use that
ranking to reorder/split 005–010 as 004 requires. Record evidence and limitations.
Do not silently solve a later visual task while performing diagnosis.

Claude is independently making the provisional broadleaf candidate described
above. Review only immutable revisions with READY.json. Check provenance, geometry,
UVs, textures, scale, LODs, counts, material compatibility and manifest hashes. Log
feedback in a separate Codex-owned review file; do not modify Claude's candidate.
Integration waits for relevant prerequisites, measured budgets and the user's
visual approval. Candidate previews alone cannot establish in-game quality.

Always state the current numbered step. Finish each step's evidence and required
tests before the next. Nonvisual steps continue automatically. Every visual step
ends with representative before/after in-game screenshots and these choices:
approve and continue, request changes, approve and pause. Continue after approval
unless the user asks to pause. Use small checkpoints and leave a durable handoff
before context becomes tight; do not abandon a half-applied change.

Godot: resolve `python tools/godot_toolchain.py` (approved 4.8 beta 3; workspace portable editor). Do not reopen the main 4.8 cache with 4.7. See `010c-godot-48-results.md` for rollback.
Git Bash: `C:/Program Files/Git/bin/bash.exe`. Tests use `server.py` `/bionic/run`;
read its `errors`, then affected logs. Always isolate saves and preferences.
The temporary phone benchmark package was removed after step 002; the player's
original app remains installed. The phone sleeps/locks normally; use the existing
benchmark keep-on setting while running, never alter the user's lock settings.

Step 003's raw Web export measures runtime performance, not the production
compressed download/startup pipeline. Phone results are around 30 fps, not proof
of the 60 fps target or absence of throttling. Desktop VSync-paced medians do not
prove rendering headroom. Consult the individual reports for all caveats.
The Web baseline also retains an audio SampleNode._pause TypeError after final
report save; the local model missed that error, so use the actual console.
