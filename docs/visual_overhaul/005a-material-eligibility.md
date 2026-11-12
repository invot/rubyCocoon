# Step 005a — exact-duplicate eligibility

Whole-subtree material audit, 12 November 2026, desktop Mobile 1920×1080 / 1080p/Mid.
No production material or visual change. `python tools/vo_cost.py --eligibility` writes the raw
`build/perf/vo/004/material-eligibility.json/.log`; `python tools/vo_material_summary.py` generates
`build/perf/vo/005a/{eligibility.json,table.md}`. The early raw audit shares 004's evidence directory.

The audit compares exact binary encodings of every stored BaseMaterial3D rendering property, with texture/next-pass
resource identity, only for surface-finished materials. It excludes resource names, paths, scene-local ownership and
metadata from rendering equivalence, then reports those identities separately for human ownership review.
This does not identify equivalent image bytes across different textures, all untextured/custom materials, unloaded areas,
or actual savings. Overlays and non-bound fade copies are outside this particular material audit.

Generated table: no duplicates in battle or Coastal Path; resource-redundancy ceilings are three Cove, two house and
twelve Rue Royale. These are **not safe-sharing targets**. Review of the reported paths and source establishes:

- Cove: one opaque window_frame/window_glass pair and two groups of independently alpha-faded building copies.
- Rue Royale: one opaque frame/glass pair; ten frame/glass fade materials in one group and three building copies in
  another. Independent building opacity is mutable (`world.gd::_set_building_opacity`), so copies cannot be globally shared.
- The role names differ deliberately. `house_models.gd` reads `resource_name` to dress frame/glass surfaces differently.
  Their present render properties happen to match; merging source materials can destroy that identity. Keep both.
- House: one wall-material pair and one pair across `furniture_plain.res` / `phone_rotary.res`. Wall fading changes
  GeometryInstance transparency (`room_builder.gd::fade`), not those shared materials. These two groups are plausible
  final-assembly sharing candidates, but only two resources in a scene with 34 distinct material resources. Do not edit
  baked/source packs to merge them. A future immutable final-assembly cache could include them after measuring a benefit.

**005b decision: documented no-op for this performance foundation.** There is no evidence for a global finish cache
or tint migration: battle/Path already have no exact finished duplicates; town reductions mostly risk semantic roles
or independent fades. Introducing a full-tree canonicalization/cache for at most two additional house resources has no
measured draw-call/frame-time payoff, while that phone scene's GPU is already about 15 ms at a ~33 ms interval.
This is a cost/benefit decision, not a claim that every resource is maximally deduplicated. Reopen narrowly if 010a
or later profiling demonstrates material submission as a significant bottleneck. No renderer-count reduction or pixel
diff is claimed for this no-op; runtime assets and material bindings are unchanged.

The diagnostic route completed without problems/focus loss/script errors; the existing ObjectDB shutdown warning remains.
Quick and vo-perf-route are recorded separately under `build/perf/vo/005a/`. Source audit and final decision were done
by Codex; the approximate local model was not used for correctness or ownership judgment.
