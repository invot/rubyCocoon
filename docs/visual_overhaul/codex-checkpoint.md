# Codex checkpoint — 12 November 2026

## Current checkpoint (supersedes the historical text below)

**008b complete; parent 008 complete; next 006** (supersedes historical paragraphs below).
Claude's approved enclosed-room 30-unit/two-split setting is integrated in `world.gd`.
Outdoors and films retain their lighting. Full report: `008b-integration.md`; film evidence:
`claude-008b-cost-return.md`. Largest generated room reef#0, 31×13, four reachable edges inspected.
`vo-lighting` / `tools/vo_lighting.py` record indoor old/approved/old and film key-shadow on/off/on.
Desktop Mobile `008b/mobile-01`: 125.335 s, zero problems/focus loss; GPU drift/background Godot
limit attribution. Phone: 309.625 s, zero problems/focus loss/disconnect, 28.9–29.9°C.
Reported phone refresh is 24 Hz throughout (cap 60); ~41.6 ms frame medians do not prove an fps gain.
Indoor GPU differences 0.105/0.248 ms. Film key-shadow differences 0.540/0.160 ms, films unchanged.
Mobile desktop/phone coverage frames and 2400×1080 Compatibility/touch capture inspected.
Quick + six focused scenarios and 14 Python validator/recovery checks pass. Earlier harness errors/stall
were corrected; only this task's verified stalled PIDs were stopped. Source/tests/log limits in report.
Benchmark removed; player-package identity and export preset bytes match. Phone captures extracted safely.
APK SHA-256 `7a84f0604a7127aff0acd882793fcbd9ff45a3eab356592c5139b698f4f10c70`.
All Codex model/measurement/export jobs from this step have finished. No root override.cfg.
No commits, branches, resets, production art replacements or player-save changes. Preserve all existing work.

Codex continuation complete through **008a controlled shadow diagnosis**. Next: **Claude 008b visual work**,
with concrete instructions in `claude-008b-handoff.md` and evidence in `008-shadow-budget.md`.
010b missing phone evidence is complete: three clean passes / 459.855 s, 28.9–29.9°C;
see `010b-phone-resolve.md` for pacing/drift limits. 008a phone on/off/on completed in 457.203 s,
zero problems/focus losses; battery 29.9°C. USB recovery on the same PID left a 108.084 s
observation/temperature gap; no continuous host observation/lock coverage claim.
Outdoor shadow-off GPU differences: Path 3.706 ms, Cove 3.337, Rue Royale 1.620; frames still ~33 ms.
House drift +108.5% is inconclusive. Its sun uses 100 units/four splits: concrete 008b coverage question.
Desktop attempt `008/desktop-mobile-01` lost focus and is INVALID, preserved without retry.
Eight Python validator/recovery checks, quick, vo-shadow-route and focused scenarios pass.
Both benchmark packages have been removed; player identity and export preset bytes match originals.
No measured job remains, no override.cfg. Local-model triage 67037 timed out on the busy lock;
subsequent log triage completed (its 'Godot Error' was actually an XR property WARNING, confirmed directly).
Image first-look completed too; exaggerated grounding/UI-shadow claims were corrected by direct inspection.
All Codex measurement/model jobs from this continuation have ended. No further job is queued.
Production lighting unchanged; no new art candidate/approval, no Codex commits/branches/resets.
006 remains gated by parent 008. Preserve concurrent typography/UI/documentation changes;
the historical font paragraphs below may be superseded by those ongoing edits.

Font task: Fuzzy Bubbles body/dialogue is implemented; Spartan headings retained. See font-update.md for captures/checks and pending world-artwork review. All checks including 26 glyph coverage passed; no active jobs. Waiting for visual approval. Preserve existing Claude work.

Latest user steering: resume Codex code/testing/nonvisual work, stop for Claude visual authorship. Typography direction recorded in AGENTS, README and overhaul README/runbook/standards/steps; font and shared world-glyph mapping implementation pending. Read Claude’s latest state below: 009b user-closed, 010b visually approved but phone evidence missing; 008 shadow measurement tooling awaits run. Preserve Claude changes. No jobs remain from Codex’s earlier session.


**Latest (Claude, usage limit reached mid-step):** 010b approved by the user. Its phone evidence is still missing:
the 010b phone sweep (`tools/vo_phone_sweep.py --step 010b`, package already exported at
`build/android/RubyCocoon-perf-010b.apk`) lost the USB connection and produced no report (`build/perf/vo/010b/phone/INVALID.txt`).
Benchmark package uninstalled; player app unchanged. Step 008 has only its measurement tooling so far:
`--shadow_sweep=on,off,on` in vo-perf (render_quality.gd `diag_shadows`), quick and vo-perf-route pass; no measurement run yet.
No active jobs, no root override.cfg.

**009b closed by the user (Web criterion recorded as not met). Next: 010b.**

**Claude continuation (after Codex's session ended):** 009b remains in progress, waiting for the user's decision.
Capture comparison done; fixed the shared warm-up crash on PrimitiveMesh (two partial runs marked INVALID);
shared warm-up gives no measurable gain on desktop (2316 vs 2322 ms Path) and was inconclusive on Web, so it is not
adopted. `vo_cost.py --warmup-shared` and summary columns added. Quick, transitions and title-startup pass.
See the continuation section in 009b-first-visit-checkpoint.md. No active jobs; no root override.cfg.
Then the user chose **Prototype title compile**: shader_precompile.gd + assets/shaders/compat_warmup.scn
(--scene=shader-manifest), desktop Compatibility with cache off only. Results and open items in the checkpoint's
title-precompile section. Waiting for user review. Browser pane emulation reset; no override.cfg.


**Current state: 009b remains in progress. No active benchmark/model jobs.**
The user's latest “Ready for the focused run” was used; `exported-compat-focused` completed cleanly.
Read [009b-first-visit-checkpoint.md](009b-first-visit-checkpoint.md) for the accepted cache comparison,
packaged evidence, renderer scope and remaining cold/Web requirements. Latest first visits: 1272/1133/302/461 ms;
earlier packaged first launch 13811/7089/3260/1219 ms remains adverse evidence. Do not mark complete or advance.
Title-script waits were separately recorded (941 and 696 ms), not hidden as loading improvement.
Actual benchmark export is `build/windows-compat-bench/RubyCocoon.exe` with custom feature compatibility_build;
normal presets restored, no root override remains. Normal Mobile/Forward+ caching enabled. Existing warm-up unchanged.
Templates in build/tools came from official partial archive; full archive SHA explicitly unverified, ZIP CRC checked.
`vo_firstvisit_summary.py` validated six accepted experiments (including ANGLE, which was slower).
Focus-lost packaged repeat is invalid and retained; fail-fast handler worked. No save/art candidate changes.
Next: capture comparison and tool review; Web continuous-timer before measurement; safe warm-up optimization.

The text below is historical and may name jobs that have since finished:

**Newest 009b state:** continuous timer and failure-safe harness implemented; production warm-up/configuration still
unchanged. Full-route before attempt lost focus and hung waiting for drawing; stopped only its verified own Godot PID
13516. It is invalid, retains logs/captures, and has no accepted report. Focus-loss handler now saves partial failure,
restores keep-on and exits nonzero immediately. Quick passes after the change.

Loading-only fixture (`--load-only`) measures the same 4 arrivals × 2 passes, skips walking/battle samples, and cuts
focus time to about one minute. Report explicitly marks loading_only; do not compare its missing segments as perf frames.
Accepted runs: `build/perf/vo/009b/before-load/` (cache on), `cache-off/`, `cache-on-control/`, all zero problems/focus losses.
Generated comparison `first-visits.md` / `validated-first-visits.json` via
`python tools/vo_firstvisit_summary.py before-load cache-off cache-on-control`.
First continuous black Path: 23.383 s cache on → 2.483 s off → 22.976 s on control. Cove: 5.528 → 0.875 → 5.446 s;
house: 3.872 → 0.345 → 3.552 s. Return visits are small in all. This is a native AMD OpenGL/cache-path finding,
not a Web/Vulkan conclusion or an isolated compiler-time trace. No blanket cache-disable fix applied.

`tools/vo_cost.py --shader-cache off/on` creates a temporary root override.cfg under the shared lock only when none
exists, refuses an existing file, verifies effective value in report, then removes only its own unchanged override in finally.
All three experiments restored it; no existing shader cache was deleted. Cache probe shows cache/pipeline enabled,
671 runtime cache files (~125 MB), 88 project cache files. Probe is read-only: tools/debug/shader_cache_probe.gd;
evidence `009b/cache-probe.json`. Native shader-binary cache load is a strong causal lead, not proof of specific driver internals.

**Active job now: tool session 56613**, ANGLE comparison with cache left enabled:
`python tools/vo_cost.py --phases --step 009b --renderer gl_compatibility --driver opengl3_angle --attempt angle-cache-on --load-only --shots`.
It holds shared lock and requires focus. Output/captures under matching 009b/angle-cache-on folders. Runner rejects driver
fallback. No temporary override for this test. The installed Godot 4.7 is a single executable; checking if its ANGLE is linked
in rather than assuming older dynamic-DLL packaging. Do not download or install anything unless actual evidence needs it.

Next: validate ANGLE result, compare real captures/pixels with tools/img.sh after releasing shared lock. Find a
Compatibility-only production remedy; do not disable caching for Vulkan/phone. First Path cache-off is still 2.48 s
including initial script/battle prewarm, so 009b's 1.5-second goal is not yet met. Web improvement unmeasured.
Before production changes, complete evidence and check renderer/platform scope. Before any new visual change, actual
before/after shots and user review remain mandatory. No commits, branches, saves, asset replacements or new visual change.

The following earlier paragraphs remain historical:

**Latest state: 009b in progress; 010a completed and benchmark package uninstalled.** Phone results are independently
validated in `build/perf/vo/010a/phone/{validated-sweep.json,comparison.md}` and `010a-phone-resolution.md`:
429.41 s, zero problems/focus loss, 540p GPU improves 7.3–20.3% but frame medians stay ~33 ms; GPU bracket drift ±1.2%,
battery 26.9–27.9°C. Original player package path unchanged. Three captured passes extracted safely under phone/extracted/.
Local model crop notes completed; minor labels wrong and disregarded. No heavy/model job remains from 010a.

009b: continuous timer added (opt-in load_phases) from fade_out return through fade_in call, including state/audio.
Legacy black_ms retained. Quick, vo-perf-route, transitions pass under `build/perf/vo/009b/`.
Fresh Compatibility before run active: tool session **19371**, command
`python tools/vo_cost.py --phases --step 009b --renderer gl_compatibility --attempt before --shots`.
It holds the shared lock and needs window focus. Output `build/perf/vo/009b/before/gl_compatibility-cost.json/.log`,
captures `build/shots/vo/009b/before/gl_compatibility/`. Runtime warm-up/shaders/export presets remain unchanged.
Continuous phases now include a twelfth lap (arrival state/audio); the old 009a summary validates only its historical
eleven-lap evidence, so use a new/adapted validator for 009b. Do not relabel 009a's frame samples as continuous.

Read official Godot pipeline documentation for 009b: shader baker applies only Forward+/Mobile, not Compatibility/Web,
and does not replace driver pipeline compilation. No baking/cache flags enabled yet. Next: inspect actual cache defaults
and measured material/mesh warmup coverage before changing production code; keep visuals identical and gather after evidence.

The following phone-running paragraph describes the earlier state; its job is finished:

Current step: **010a, real-phone resolution/pacing measurement running**. User explicitly resumed work and reconnected
razr `ZY22K7BD2J`. The phone was awake/unlocked. Do not start heavy Godot/Blender/model jobs while this holds the lock.
`python tools/vo_phone_sweep.py run --serial ZY22K7BD2J` is tool session **83598**, temporary package
`com.rubycocoon.vo_perf`. It runs 720p/540p/720p, same route, Mid, three passes. Never touch `com.rubycocoon.x` data.
Runner stops only the temporary package on exit; uninstall that temporary package after extracting/validating results.
APK SHA256: `a9c5ed2d9d8e21c159f12d194552b86da803314ab52befa3bb4793b83525b510`.
Evidence: `build/perf/vo/010a/phone/`; report, temperatures/logcat while running, private-files tar on completion.
No native readback screenshots during samples; harness viewport captures are outside sampled intervals.

009a **complete**: focused-01 Mobile 146.72 s / Compatibility 181.03 s, two passes each, zero focus losses/problems.
`009a-loading-phases.md`, generated `build/perf/vo/009a/focused-01/{phases.md,validated-phases.json}`.
Quick + route + transitions pass. Crucial finding: legacy sampled black_ms can miss first-frame synchronous work;
Compatibility house sampled 234.5 ms but phases total 3628.6 ms. Do not trust old samples as continuous timers.
009b needs a continuous fade_out-return→fade_in-start counter and new before/after evidence. Keep baselines intact.

rev_003 **technical review complete with integration follow-ups**: `art_reviews/broadleaf-rev_003.md`.
154 hashes/counts match, source embedded metadata verifies author/CC-BY-4.0; credits/license provenance prepared.
Intentional two-sided crown, lower-LOD slivers and normal-heuristic flags retained for real game inspection.
No new Claude correction needed for continuing performance work. 011/022/023 and actual in-game approval still gate integration.

010a tooling: opt-in `--resolution_sweep=720,540,720` on vo-perf; per-pass height/size/refresh/vsync/maxfps metadata.
`vo_phone_sweep.py` configures existing exporter/recorder, locks entire run, isolates state at user://bench/vo/010a/,
preserves baseline-phone evidence and original preset (byte restoration checked). Headless three-resolution route,
quick and normal route check pass. No production video setting/renderer/art changes.
When the phone job completes, run `python tools/vo_phone_sweep_summary.py`, inspect raw errors and captures,
collect post-run display/game pacing metadata if needed, preserve original player package path and uninstall only benchmark.
Record limitations/thermal drift; complete 010a evidence before starting 009b (005b no-op already decided).

## Historical checkpoint

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
