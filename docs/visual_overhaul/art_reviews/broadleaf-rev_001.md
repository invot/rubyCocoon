# Codex technical review — broadleaf rev_001

12 November 2026. Read-only review of the immutable delivery. The user confirmed candidate approval in this chat;
Claude's candidate index records it. READY.json retains its original provisional/unapproved wording by design: do not
rewrite the immutable manifest to reflect later approval. Approval is for the candidate, not production integration.

Reproduce the static audit: `python tools/review_broadleaf.py`; results go to
`build/perf/vo/art-review/broadleaf-rev_001.json`, outside Claude's ownership.

## Verified

- All 76 manifest-listed sizes and SHA-256 hashes match. The source derivative and source texture hashes also match
  their provenance entries. The delivery records a failed rework and a procedural rebuild; generator/source copies are included.
  This audit did not rebuild Blender output or independently certify byte-identical reproducibility.
- Nine glTFs: three variants, each 1,918 / 772 / 238 triangles. Two material slots and two textured opaque primitives
  per tree; four shared/dedicated RGB 512×512 texture images in the delivery. No alpha cards.
- No invalid indices, near-zero-area triangles, nonfinite UVs or invalid/non-unit normals found at the stated tolerances.
  Positions and normals are present alongside UVs for every primitive. glTF uses +Y up without additional node transforms.
- Bounds agree with the manifest at its stated precision: heights around 3.0005, 3.4009, 2.8004 and widths 2.55, 2.30,
  2.75 at LOD0. Roots dip slightly below zero (largest across LODs ~0.0024 unit), consistent with grounding rather than a
  floating origin. Final game fit/placement, collision envelope and matching 023 are untested.
- Samplers use linear magnification and trilinear minification. Anisotropy is an engine integration setting, not proven
  by this glTF sampler. Unsmoothing status is explicit; no smoothing/import was performed during review.
- Position-welded crown topology has zero boundary/nonmanifold edges in all nine meshes, at 1e-6 position precision.
  Face winding agrees with average vertex normals. This is a static consistency check, not a self-intersection proof.

## Follow-up for rev_002

1. **UV projection seam:** the candidate gameplay-angle crop visibly changes leaf direction and stretches near the
   top-to-side projection band. This is a portable-asset issue, not something to silently fix by editing a shared runtime
   shader during diagnosis. Produce a continuous/blended mapping or a portable atlas solution while preserving the
   approved silhouettes, proportions and palette. Show the same crop before/after, honestly labelled Blender candidates.
2. **Two-sided materials:** all 18 material entries (two per glTF) set `doubleSided: true`. Solid closed crowns have no
   demonstrated need for this. Test backface culling, export single-sided where valid, and show all views. Do not claim
   a GPU gain before engine measurement. The trunk primitive has 64 / 36 / 12 position-welded boundary edges by LOD;
   `tube()` does not cap its ends (its `cap_top` argument is currently unused). These may be hidden by crown/ground,
   so they are not automatically a visible-hole defect. Identify the boundaries and cap or justify them before relying
   on one-sided rendering; verify root, underside and branch junction views rather than masking bad winding with two-sidedness.
3. **Material integration:** current `voxel_assets.gd` foliage replacement samples a palette atlas then adds its own
   procedural leaf treatment. Applying it unchanged to these already-painted leaf images risks double-patterning/color
   treatment. Integration needs an explicit textured-asset path after step 022, with shared bark/leaf materials and LOD
   handling. Claude must not change that runtime system. Separate glTF LODs are not yet wired into Godot's existing LOD pipeline.

The regular leaf rows and banded bark are acknowledged aesthetic limitations in the approved candidate; this review
does not revoke that approval or authorize unrelated repainting. Keep them unless the user asks or a narrowly required
seam fix makes a small documented adjustment unavoidable.

Local-model neutral crop notes are retained separately; the crop was inspected directly. Numeric checks and technical
judgment were performed by Codex. Candidate images are **not in-game integration evidence**.

**Result:** provenance/manifest/geometry basics pass; eligible to continue isolated candidate refinement, with the
above follow-up. No production integration: steps 011, 022, 023, explicit LOD/material integration decisions and actual
before/after game screenshots with user review are still outstanding. Step 027 stays open. No candidate files modified.
