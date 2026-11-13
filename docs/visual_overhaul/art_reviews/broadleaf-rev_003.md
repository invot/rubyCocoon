# Codex technical review — broadleaf rev_003

12 November 2026. The user approved rev_003 as the selected broadleaf candidate. This review reads the immutable
delivery and changes none of its files. rev_001's procedural-tree findings do not transfer to this reworked source.

## Integrity and provenance

`python tools/review_broadleaf.py --revision rev_003` writes
`build/perf/vo/art-review/broadleaf-rev_003.json`. All 154 manifest-listed sizes/hashes match; the original GLB hash
also matches `69947502684d492e481b218e0c53149abcbb5d49d345f15b9b6501f9ab38b98e`.
Manifest hash: `22fea32ee0054287c32e5e83862115e4ee362bd2dd9f2b2c6f1b60db0e2a7d3b`.

The source GLB's `asset.extras` identifies “Stylized tree”, roroer, its Sketchfab source and CC-BY-4.0.
The [primary model listing](https://sketchfab.com/3d-models/stylized-tree-6ba26deef34249ddb8694888b47db449)
independently identifies the same author/title and CC Attribution; direct page access returned 403, but the indexed
listing was available. Version 4.0 is supported by the embedded original metadata. Credit and modification notes
are now prepared in CREDITS.md and licenses/broadleaf_roroer.md, clearly marked as candidate provenance.
No claim of engine integration or release readiness follows from attribution.

## Static checks

- Nine glTFs, two material slots per tree. Actual triangles match every READY entry: A 2728/1114/553,
  B 2728/1113/553, C 2720/1113/547. The candidate index's prose rounding of B's LOD1 to 1114 is not the exact count;
  use READY/decoded indices. LOD0 remains within the provisional 1000–3000 range; final budgets are pending 011.
- All primitives provide position, normal and UV attributes. No invalid indices, nonfinite UVs, non-unit/nonfinite
  normals or near-zero-area triangles were found at the review script's tolerances. Counts are measured from buffer
  accessors, not merely repeated from the manifest. This is not a proof against all intersections or bad silhouette details.
- Bounds match the approved envelopes: A 3.0 high/2.55 wide/2.4 deep; B 3.4/2.3/2.2; C 2.8/2.75/2.55.
  Ground minimum is zero; nodes carry no extra scale/rotation. In-game collision clearance/fit remains untested.
- Three RGB 1024×1024 textures, one per variant shared across its LODs. Both material slots reference painted imagery;
  both are opaque. There are no alpha leaf cards. Linear magnification/trilinear minification are exported;
  anisotropy must be set by the Godot integration. Unsmoothing is explicit; no smoothing/import was run in this review.
- Trunk exports single-sided; crown exports two-sided. This is consistent with open scalloped crown shells and differs
  intentionally from the closed rev_001 crown. Do not apply rev_001's single-sided-crown recommendation blindly.
  The claimed geometry-versus-two-sided performance tradeoff has not been measured in Godot.

## Geometry and preview findings

Position-welded topology (1e-6 precision) reproduces the manifest's total boundary counts. Trunk boundaries are
32/32/21 for A and B, and 32/32/20 for C; crown boundaries account for the remainder. No nonmanifold edges were
found under that test. Open boundaries are expected at crown hems and branch interfaces, so boundary count alone
is not a visual defect. The trunk base cap appears intact in the supplied underside/roots culling sheet.

The face-normal-versus-averaged-vertex-normal heuristic flags 11 trunk faces at LOD0 in each variant, 7–9 at LOD1,
and two at LOD2. This does not establish exposed reversed faces: smooth vertex normals can disagree with geometric
normals on concave details, and the supplied culling views show no red trunk patch. Retain this as a targeted check
for the real engine's underside/branch junction views rather than silently repairing approved immutable geometry.

Direct inspection of the LOD and backface sheets confirms that LOD1/2 have small top-surface slivers; LOD2 becomes
visibly angular/pointed, especially C. These are already disclosed limitations. The fixed-size sheet enlarges each LOD
to equal screen size and cannot establish whether the defects are visible at actual switch distances. Integration must
choose switch distances from screen-space size and inspect popping/holes in real game shots. Keep LOD0 close to the camera;
do not treat the current LOD2 as an approved close-up shape.

## Integration conditions / disposition

**Technical review complete with integration follow-ups. No further Claude revision is required to continue the
performance foundation.** Candidate approval stands; this does not certify final in-game visual/performance quality.

1. Complete 011 budgets, 022 material presets and 023 scale sheet before integration. Step 027 remains open.
2. Preserve painted source materials. Existing voxel_assets foliage replacement expects a palette atlas and adds its
   own leaf treatment; applying it unchanged would risk restoring individual-leaf patterning contrary to the approved
   pillowy look. Codex must provide the appropriate textured-material path at integration, not repaint this candidate.
3. Wire explicit LODs into the existing import/LOD system; measure their visibility, culling and actual GPU cost on
   Mobile and Compatibility. Two-sided opaque is not the same as alpha blending, but hidden/back-facing work still needs measurement.
4. Apply the shared smoothing pipeline once to integration copies, set anisotropic mipmapped filtering, and import only
   when prerequisites are satisfied. Preserve source/published candidate files unchanged.
5. Inspect real game views of roots, branch junctions and LOD transitions; fix exposed holes/slivers if visible at intended
   distances through a new candidate revision or a documented importer change. Capture before/after game screenshots
   and obtain user approval. Candidate Blender previews cannot substitute for those checks.

Generator/source scenes are present and hashed. This review did not rebuild Blender output, measure phone rendering,
or claim byte-identical reproducibility independently. The user's rejected low-poly-pack palms remain excluded.
