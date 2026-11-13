# Claude task — isolated rock-family preproduction

Parallel art assignment proposed 13 November 2026 while Codex owns A71 stability and 011 budgets.
This is preproduction for runbook 030, not execution/completion of that numbered step.
The approved broadleaf/shrub/home candidates stay immutable; shrub rev_002 still awaits user review.

Read AGENTS.md, parallel-handoff.md, runbook 030, the art standards and approved broadleaf/shrub previews.
Inspect the actual existing field/beach/big/small rock meshes, their source packs/provenance, placement scale
and the conversion in `tools/prepare_stylized_nature.py`. Rework established sources before inventing a new pack.

Make a small coherent family of rocks for coast and grassland: designed broad planes, softened transitions,
partly buried grounded bases, quiet warm/cool painted colour variants and readable silhouettes. Match the
approved nature candidates. Keep every solid object textured, with gentle painted gradients and no grain,
speckle, harsh cracks, visible texel blocks, voxel cubes or low-poly pointiness. Preserve useful scale and
footprints; do not change collision or identify a new rock as a puzzle object.

Work only in:
- `tools/blender/art_candidates/rocks/`
- `build/art_candidates/rocks/`
- `docs/visual_overhaul/art_candidates/rocks.md`

Deliver a repeatable Blender generator, source scenes, textured portable exports, two simpler LODs where useful,
and a manifest with hashes, scale, triangle/material/texture counts, source attribution/license and smoothing status.
Keep budgets provisional until 011/022/023; report costs rather than inventing final budgets. Prefer few materials
and opaque geometry. Provide labelled turntables, LOD/backface views and candidate gameplay-angle compositions
beside the approved foliage, using a neutral scale reference. These are art previews, not in-game integration proof.
Publish a new immutable `rev_NNN`, write `READY.json` last, show previews to the user and stop for review.

Do not edit runtime files, maps, shared shaders/builders/importers, existing revisions, `tools/smoothed.json`
or production assets. Do not smooth/import/integrate the candidates or mark 030 complete. Codex owns technical
review, material/scale integration, actual-device costs and the eventual in-game gallery after prerequisites.
Use the existing model wrappers and `tools/local_resource.py` for heavy Blender work. The phone benchmark
holds the same resource lock: do source review, design and generator writing while it is busy; never bypass it.
