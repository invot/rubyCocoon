# Next Claude prompt — broadleaf rev_002 (candidate lane only)

**Superseded — do not execute.** The user approved rev_003 on 2026-11-12 as the selected broadleaf candidate.
Keep this prompt as historical context only; no further artwork revision is requested by that approval.

Work in `D:/Games/Ruby Coccon`. Continue the isolated broadleaf artwork lane with **rev_002 technical refinement**.
This is preproduction for runbook 027, not execution/completion of 027 or production integration. rev_001 remains an
approved candidate and immutable. Codex's current numbered step is 009a, checkpointed for focused loading measurements.

Read AGENTS.md, `docs/visual_overhaul/parallel-handoff.md`, your candidate index, and
`docs/visual_overhaul/art_reviews/broadleaf-rev_001.md`. Preserve all Codex and existing work. Own only
`tools/blender/art_candidates/broadleaf/`, `build/art_candidates/broadleaf/` and
`docs/visual_overhaul/art_candidates/broadleaf.md`.

Keep rev_001's approved A/B/C silhouettes, scale, proportions, root flare and palette. Fix the visible top/side leaf
projection discontinuity in the portable asset, using a continuous/blended UV mapping or a suitable atlas. Do not
depend on a runtime shader edit. Keep the approved leaf/bark artwork unless a small, documented mapping adjustment is
necessary; do not broaden this into a repaint of leaf rows or bark.

Review the exported two-sided flags. Closed crowns should render correctly with backface culling. Identify the trunk
and branch open boundaries (Codex found 64/36/12 position-welded boundary edges by LOD; tube's cap_top is unused).
Cap or document genuinely hidden boundaries as needed, fix winding rather than hiding it, and export single-sided
where valid. Check roots, underside and branch junctions from all angles. Report actual new counts, never a presumed
in-engine performance gain. Keep the provisional LOD0 target 1,000–3,000 triangles and retain two LODs per variant.

Check the local model once; use only main-checkout wrappers and neutral questions. Run heavy Blender generation and
renders through `python tools/local_resource.py -- <command>`; never nest that lock around model/server wrappers.
Do not alter runtime assets, code, shaders, imports, maps, UI, progress, runbook, ledger, player data or tools/smoothed.json.
Leave textures unsmoothed for Codex's later integration. Budgets/material/scale prerequisites 011/022/023 still apply.

Write a new immutable rev_002 folder, repeatable generator/source, portable textured glTFs, counts/scale/material manifest,
and candidate-labelled turntable/LOD/gameplay-angle previews. Show matched rev_001/rev_002 seam crops and culling checks;
these are Blender previews, never in-game screenshots. Recheck hashes, then write READY.json last, atomically. Show the
user the candidate changes and stop at delivery. Corrections must use later revisions; do not modify rev_001.
