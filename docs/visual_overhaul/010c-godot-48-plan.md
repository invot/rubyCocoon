# Godot 4.8 migration assessment

Planning only, 13 November 2026. Step **010c is todo**; no engine, templates,
imports, game code or completed evidence were changed by this assessment.

## Timing and release gate

Insert 010c after recovery/cleanup of 007's interrupted phone experiment and before
011's budget acceptance. The revised tail is **007 → 010c → 011 → 012**.
This is the earliest clean migration boundary: it preserves the 4.7 experiments,
avoids replacing a temporary app before its evidence is recovered, and establishes
4.8 costs before material boards, final artwork, room bakes and larger maps.
There are already uncommitted 011 tooling experiments; preserve that work and use
its 4.7 results as provisional evidence, then remeasure before accepting budgets.
Do not repeat or reopen completed numbered steps merely to change their engine label.

The [official archive](https://godotengine.org/download/archive/) and
[beta 3 announcement](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-3/)
list **4.8 beta 3 (9 November 2026)**, not a stable release. Recheck at execution.
Start isolated migration testing immediately after 007; use matching editor and
export templates pinned to one exact build. Recommend stable 4.8 for the main
checkout cutover. If still beta, record test results and keep the adoption
checkpoint open for stable, or an explicit user decision to adopt the tested beta.
Independent asset candidates can continue while that gate is open. Do not claim
the migration complete or finalize engine-dependent 011 budgets on an unadopted build.

## Lighting direction

The user's new direction is **offline lighting/contact shading baked into textures**.
Do not introduce multi-bounce AO approximation, SSIL, SDFGI, VoxelGI or a LightmapGI
bounce-light rollout. Multi-bounce AO is an approximation rather than full GI, but
is still excluded by this direction. Directional lightmap specular improvements
are not a reason to adopt LightmapGI. The previous, unfinished 022a experiment is
replaced with a texture-baking workflow checkpoint; it was never completed.

Keep existing direct lighting, actor shadows, glow and material response coherent.
Check new engine defaults for unwanted bounce effects without stripping unrelated
approved lighting. Shared/recoloured textures and movable actors must not acquire
scene-specific directional shadows; reserve those for stable, uniquely mapped
static surfaces. Avoid double-darkening from baked AO plus runtime AO/shadows.

## Features worth testing

These are project recommendations, not measured savings or claims of identical
renderer support. For each trial record actual support on Forward+, Mobile and
Compatibility/Web; unsupported paths retain their existing implementation.

| Candidate | Where it could help | Required rework / decision |
|---|---|---|
| Mip-level texture streaming | Memory headroom for painted scenery and later enlarged roads | Trial one imported texture family first. Inventory embedded images in `.res` resources and shader textures; verify eligibility rather than assuming all stream. Measure memory, camera-turn mip popping, I/O stalls and first visits. Keep filtering; do not turn this into a mass texture reauthoring task. |
| ASTC 6×6 / compression profiles | Phone texture memory versus painted-detail quality | Reimport a representative diffuse, normal and mask set; compare compressed output and download size. Check target ASTC capability and retain ETC2/Web fallbacks. Do not apply lossy profiles indiscriminately to UI, fonts or data textures. |
| Alpha-coverage-preserving mipmaps | Distant leaf/flower cards retaining their shape | Apply only to genuine cutouts. Existing opaque foliage needs no conversion. Check halos, silhouettes and cost; retain deliberate blended water/effects. Schedule art-family application in 027–029. |
| Compatibility decals / animated decals | Shared grounding marks and localized surface detail across desktop and web | Prototype against current contact-shadow quads and material paths in 022; do not assume Mobile cost parity. Check depth, fading and batching. Keep the existing path until replacement is demonstrably useful. |
| Screen-space contact shadows | Small grounding details on supported targets | Optional 022/043 trial, with existing actor contact shadows as fallback. Check screen-edge/off-screen failures, duplicate shadows, low-resolution artifacts and GPU cost. This is a shadow option, not bounced lighting. |
| Engine CPU/render fixes | Scene teardown, property access, shader setup and orthographic shadows | First measure the unchanged game on 4.8. Do not rewrite scripts speculatively or translate engine microbenchmarks into game fps promises. |
| Trail3D | Later spell/weapon trails | Optional 043 prototype using the existing effects entry points and bounded lifetime/overdraw. Keep texture-bearing physical objects and battle readability rules. No wholesale effects rewrite during migration. |

Feature sources: [4.8 feature overview](https://godotengine.org/article/dev-snapshot-godot-4-8-beta-1/),
[ASTC profiles implementation](https://github.com/godotengine/godot/pull/115003),
[contact shadows](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-6/),
[Trail3D](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-4/).
Availability must be checked against the exact adopted build, not just these previews.

## Migration work inventory

1. Preserve a manifest of the dirty checkout and source/assets before opening it
   with a newer editor. Use an isolated, ignored project copy for beta/import
   trials, excluding player data; do not make branches/worktrees or reset edits.
   Keep 4.7 installed and a reproducible 4.7 export for rollback. Never reopen
   upgraded import caches with 4.7 as the rollback strategy.
2. Parameterize actual version pins, not a blanket search/replace: `project.godot`,
   `server.py`, `tools/run_tests.sh`, `tools/img.sh`, `tools/key_art.py`,
   `tools/make_web.py`, the `tools/vo_*.py` launchers, especially `vo_phone.py`
   (template directory and editor-settings filename), `prepare_windows_templates.py`,
   `vo_windows_compat.py` and `vo_export_probe.py`. Respect `GODOT`/CLI overrides
   consistently and record engine version in every measurement. Update active setup
   docs only at cutover; historical 4.7 reports must stay accurate.
3. Reimport in isolation; inspect resource/UID/serialization diffs and shader
   compile errors before copying necessary fixes back. Preserve source packs and
   smoothing history. An engine reimport is not a reason to smooth assets again.
   Keep desktop Forward+, phone Mobile, single-thread WebGL 2 web and the dedicated
   Compatibility export. Check all preset/template associations, including custom
   Compatibility probe templates. Preserve signing, package IDs and player installs.
4. Review the current release's breaking changes and regression list. In particular,
   audit custom sky shaders (`SCREEN_UV`), texture compression API calls, GDScript
   parsing, Control focus and touch button handling. Verify one confirmation per
   tap, held B plus movement, film A/B and target aim/confirm. Do not enable automatic
   font shrinking. Only adapt APIs actually used; this is GDScript, no C# migration.
5. Review `render_quality.gd`, `prefs.gd`, terrain/water/fading shaders and battle
   silhouette SubViewports. Capture the same cameras at 540p/720p, Min/Mid/Max,
   desktop and wide-touch layouts. Check normal maps, alpha, soft shadows, AA,
   smooth output scaling, depth-dependent effects and dark scenes. If any compositor
   is found, check resolved-depth access against the adopted release's rules.
6. Rebuild native, Android and production Web exports; test real exported first
   visits with cold/warm caches. Keep 009b's warm-up conditional until measured;
   explicitly retest the baseline Web SampleNode pause error against beta 3's
   announced Sample-driver fixes. A release note alone does not close that bug.

## Evidence and acceptance

Use checkpoints of about 1–2 hours: toolchain/import compatibility; unchanged-game
exports and measurements; small feature trials; adoption and documentation. Split
010c into lettered children if needed, preserving an open parent until adoption.
This is several checkpoints plus device/beta availability, not a promised one-hour port.

Run the full existing suite through `server.py` (read `errors` and actual failed
logs), both map checkers, and the relevant rendered input/graphics fixtures.
Use isolated saves/preferences. Run measured native commands via
`tools/local_resource.py`; never nest it around wrappers that acquire the same lock.
Compare matched 4.7/4.8 builds on the same hardware, route and settings: medians,
p95/p99, CPU/GPU, draw calls, memory, loading/stalls, export size and sustained phone
temperature/pacing. Desktop Mobile timings remain desktop evidence. Missing phone
or browser evidence stays an explicit open criterion, not a pass.

Write `010c-godot-48-results.md` with engine/template hashes, fixes, feature support
matrix, accepted/rejected trials, raw artifact paths and rollback instructions.
Adopt only after regressions are fixed or explicitly reviewed and representative
before/after gameplay screenshots are approved. Then refresh 011's measurements
on the adopted engine; preserve the old baselines and their limitations.
