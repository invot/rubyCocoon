# Codex checkpoint — 12 November 2026

Latest user update: **broadleaf rev_003 approved as the selected candidate**, superseding rev_001; rev_002 received
change requests. The Claude-owned candidate index already records this. Do not execute the obsolete rev_002 refinement
prompt below. rev_003 is a different source/geometry and needs its own technical review; rev_001's review is not transferable.
Integration still waits for 011/022/023, technical review, source attribution and actual in-game review. 027 remains open.
Approval-time integrity check: all 154 READY.json-listed file sizes and SHA-256 hashes match. Manifest SHA-256:
`22fea32ee0054287c32e5e83862115e4ee362bd2dd9f2b2c6f1b60db0e2a7d3b`. This is an integrity check, not a geometry/license review.

Current step: **009a**, measurement checkpoint explicitly chosen by the user after two focus losses.
Read progress.md, 009a-loading-checkpoint.md, the runbook's revised order and parallel-handoff.md before resuming.
No commits/branches/player saves or production assets changed. Preserve Claude-owned untracked artwork directories.

004 evidence complete: `build/perf/vo/004/{mobile,forward_plus,gl_compatibility}-cost.json/.log`,
`build-profile-verified.json/.log`, generated summary.json/tables.md, tests.json (quick), route-tests.json.
All pass. `build-profile.json` has no usable stdout log and is excluded. Initial sandbox native command failed;
successful measurements use elevated execution and the shared resource lock. Existing Godot processes outside the
lock were observed; do not kill them. This limits fresh timing interpretation; counts and accepted baselines are authoritative.

005a complete: `build/perf/vo/004/material-eligibility.json/.log` and generated `build/perf/vo/005a/`.
Exact stored-property comparison plus source ownership audit found town duplicates mostly roles/fades; two plausible
house resources have no measured payoff. 005b is a documented no-op decision, not a claim of maximal deduplication.
Quick and route pass. See 005a-material-eligibility.md.

009a opt-in production phase instrumentation is complete, with quick + route + transitions passing through server.py.
Both `build/perf/vo/009a/{mobile,gl_compatibility}-cost.json/.log` have one focus loss/problem and only one pass.
Both processes have exited. No active benchmark remains. Do not report those numbers as accepted, or keep retrying while
the user uses other windows. A first-frame-await stall is only a lead. No changes made to warmup/rendering behavior.
When the user is ready for ~3 minutes of window focus per run, use
`python tools/vo_cost.py --phases --renderer mobile --attempt focused-01`, then Compatibility with the same attempt.
The wrapper already acquires the shared resource lock; run outside the sandbox, never nest another wrapper lock.
Validate both passes and zero problems/focus losses before completing 009a. Step 010a has not started.

Broadleaf rev_001 review complete: user confirmed candidate-only approval from Claude's chat. All 76 manifest hashes
and both provenance hashes match. Nine meshes at 1918/772/238 triangles per variant, two opaque textured materials,
valid indices/UVs/normals. All materials export double-sided; crown topology is closed, trunk tubes have open ends.
UV projection seam confirmed in the candidate crop. See art_reviews/broadleaf-rev_001.md and the generated static audit
under build/perf/vo/art-review/. claude-next-prompt.md is a copy-ready isolated rev_002 task (UV continuity/culling),
which can proceed independently. No candidate files modified. Integration waits for 011/022/023 and in-game review;
027 stays open. READY.json's older unapproved wording is immutable; the candidate index/user message record later approval.

ADB `ZY22K7BD2J` was attached at the last check. No app installed/launched/cleared during this task; original app/player
data and phone lock settings untouched. No smoothing/imports. Preserve all Claude-owned untracked files.

Local qwen server was checked once and is available. Wrapper summarized build_profile but made unsupported claims;
those were corrected in the 004 report. All model/heavy jobs share tools/look.py's lock; do not nest wrapper locks.
