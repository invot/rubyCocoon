# Broadleaf tree: artwork candidate

**Status:** **rev_003 approved by the user as the broadleaf candidate on 2026-11-12.** It supersedes the earlier approved rev_001 direction, and rev_002 got change requests. All three revisions stay as published. This is still preproduction for runbook step 027 (S7 tree grammar): **not integrated, and 027 is not complete.** Integration waits for steps 011, 022 and 023 (budgets, material presets and the scale sheet), Codex's technical review, the CC-BY credit for roroer's model in `CREDITS.md`/`licenses/`, and an in-game check of the integrated trees.
**Owner:** Claude's art-candidate lane ([parallel-handoff.md](../parallel-handoff.md)). Codex reviews only published revisions, in its own review file.

## Revisions

| Revision | Published | Folder | Notes |
|---|---|---|---|
| rev_001 | 2026-11-12 | `build/art_candidates/broadleaf/rev_001/` | First candidate: 3 variants × 3 LODs. `READY.json` lists hashes, counts and provenance. **Approved by the user as the candidate on 2026-11-12** |
| rev_002 | 2026-11-12 | `build/art_candidates/broadleaf/rev_002/` | Seam fix (baked crown atlases), single-sided export, trunk base cap, open-end and back-face checks. Same shapes, scale, palette and artwork. **Changes requested**: the painted individual leaves look silly |
| rev_003 | 2026-11-12 | `build/art_candidates/broadleaf/rev_003/` | Rework of roroer's CC-BY-4.0 "Stylized tree", chosen by the user: pillowy painted domes, recoloured to the approved palettes, root flare added. **Approved by the user as the candidate on 2026-11-12** |

Published revisions never change. Corrections go in `rev_002` and later revisions.

## Rework or rebuild

**Decision: rebuild (a procedural Blender script), after a recorded rework attempt.**

- **The source.** `assets/nature/tree_oak.res` comes from `build/nature_split/tree_oak.json`. `tools/prepare_stylized_nature.py` cut it out of the supplied *Environment Pack - Stylized Nature* (model_0), and `tools/import_stylized_nature.gd` baked it. It has 3,780 triangles, 3,612 of them in the crown, and the crown is two stacked faceted domes:
  - one dome has an open hole in its front;
  - loose triangles float beside the tree;
  - the trunk is short and cut off;
  - the UVs point into flat swatches of a 4096 colour-palette sheet, so there is no leaf texture to rework.
- **The rework attempt** (in the script):
  - merge by distance;
  - drop islands under 40 faces;
  - fill holes;
  - voxel remesh;
  - smooth;
  - decimate to 2,000 triangles.

  This closes the hole and removes the scraps. The result is still the two-dome stacked-primitive silhouette that standards.md §11 rejects, with no leaf clusters and no root flare.
- **The rebuild** keeps only the source's envelope: width/height about 0.857 for the old oak, 0.82–0.98 for the variants. No source geometry or texture goes into the delivered files. The pack stays untouched.

## rev_003: rework of a supplied model

**Your direction (2026-11-12):**
- the individual leaves looked silly;
- crowns should be pillowy and simple;
- the low-poly pack's palms are rejected.

**What I reviewed.** You supplied six CC-BY-4.0 Sketchfab models. Their author, source and licence are recorded in `READY.json`. Renders are in `build/art_candidates/broadleaf/refs/`.
- The closest fit was roroer's **"Stylized tree"**: a few painted dome shells with scalloped hems, plus a trunk with arms.
- The low-poly pack's broadleaf trees are built from see-through leaf cards: the individual-leaf look, and alpha-heavy for phones.
- The other models are pines, palms, a hand-painted birch pair and a house.

**Your choice:** rework roroer's model rather than only borrow its style.

**Source.** `build/art_candidates/broadleaf/sources/stylized_tree_roroer/stylized_tree.glb`: 4,668 triangles, one 1,024-pixel texture, double-sided. A byte-identical copy (SHA-256 `69947502…98e`) travels in `rev_003/source/original/`. Your Downloads copy is untouched.

**Generator.** `tools/blender/art_candidates/broadleaf/broadleaf_rework.py`. It reuses the render and check helpers in `broadleaf_candidate.py`, which is now import-safe; that changes none of its output.

**What the rework does:**
- **Recolour.** The texture's painting is kept and recoloured to the approved A/B/C leaf palettes and the bark palette by brightness. Bark texels are found by rasterising the trunk's UVs. The source's near-black trunk base is lifted to the bark groove colour.
- **Trunk.**
  - Welds the glTF seam splits.
  - Adds rings low on the trunk and flares them into 4–6 root fins (the approved flare).
  - Caps the base with a face pointing down.
  - Slims the girth to 0.82.
- **Crown.** The four dome groups stay as modelled for A. B stretches the centre stack (1.15) and raises the side domes. C adds a copy of the right-hand group turned 150°. Each variant is fitted to its approved height × width × depth.
- **Detail levels.** Welded first (decimating without welding tore the shells open), then collapse-decimated: **2,728 / 1,114 / 553** triangles for A and B, **2,720 / 1,113 / 547** for C.
- **Materials.** Two per tree on one shared 1,024 texture: the trunk is single-sided, the crown **two-sided**. The scalloped hems are single open sheets by design. An inner-skin version that allowed single-sided rendering took LOD0 over 3,900 triangles, so I dropped it.

**Checks:**
- The back-face renders show no red on the trunk; its cap faces down. On the crown, red appears only on the skirt undersides, as expected for a two-sided material.
- LOD1 and LOD2 show a few small decimation slivers from above, and C LOD2 has slightly pointed tops.
- The positive control (open source oak) still shows red.
- The rebuild was byte-identical.

**Credit, needed at integration** (I don't own `CREDITS.md`): "Stylized tree" by roroer (https://sketchfab.com/3d-models/stylized-tree-6ba26deef34249ddb8694888b47db449), CC BY 4.0, modified (recoloured, root flare added, rearranged into three variants, decimated into LODs).

**Not done:**
- no engine import, in-game capture or performance measurement;
- no 022/023 check;
- explicit LODs are not wired into Godot.

## rev_002: what changed

Codex's review of rev_001 asked for three fixes: the leaf seam, the two-sided flag and the trunk/branch open ends.

**Leaf seam.**
- rev_001 switched each crown face between a top projection and a side wrap. That left a band where the leaves changed direction and stretched. The side wrap also sheared leaves in the valleys between lobes.
- rev_002 gives each crown its own atlas: smart-UV islands, 1024 / 512 / 256 by LOD. A numpy bake colours every texel from the **same approved leaf tile, at the same world scale**, through three planar projections (two sides, with leaves hanging down, and the top).
- The projections are height-blended on a leaf mask, so whole leaves interlock instead of meeting on a line.
- It is portable: no shader is needed. LOD switches keep the same world-space leaf placement.
- The leaf tiles and bark are byte-identical to rev_001. The leaf tiles are now bake sources in `source/art/`; the bark still ships as the tile.

**Two-sided flag.**
- The materials now export single-sided (`doubleSided` absent).
- In a back-face check, culling is off and back faces glow red. It shows no red from underneath, at the roots, at the branch junctions or from the top, at LOD0 (0° and 180°), LOD1 and LOD2.
- A control render of the open source oak does show red through its hole, so the check can catch a fault.

**Open ends.**
- The trunk base is now capped with a downward fan: +12 / +8 / +6 triangles.
- The remaining open ends are the trunk top, the branch bases and the branch tips. A nearest-surface test puts every ring vertex inside the solid that hides it, with at least about 0.05 units of clearance (`READY.json` → `counts.*.lods.*.open_ends`). Capping them would add triangles nobody can see.
- The winding is unchanged and correct.

**Counts.** 1,932 / 780 / 244 triangles per variant, 2 materials per tree.

**Texture density.** LOD0 crown texel density is about 190–210 px per unit; rev_001's tiles gave about 320. The crown textures go from three shared 512 tiles to nine per-tree atlases, which costs more texture memory. That is for 011 budgets to weigh. No engine measurement was made.

**Previews** (`rev_002/previews/`):
- `seam_compare_A/B/C.png`: rev_001 imported read-only and rendered with the same cameras, at three turns;
- `seam_crop_A.png`;
- `gameplay_compare.png`;
- `cull_check_A/B/C.png`;
- `cull_control.png`;
- the usual turntables, LODs and gameplay angle.

**Local model.** It was asked to list the differences on the seam crop pair. It answered that there were none, which direct inspection contradicts, so I overrode it.

**Still open after rev_002:**
- slight softening of the leaves at the lower texel density;
- small cross-fades where three projections meet on tight valleys;
- the regular leaf rows and banded bark (kept by design);
- explicit LODs not wired into Godot;
- no 022/023 check and no engine import.

The current generator reproduces rev_002. rev_001's own generator copy is in `rev_001/source/generator/`.

## What was made (rev_001)

Generator: `tools/blender/art_candidates/broadleaf/broadleaf_candidate.py`. It is deterministic: a rebuild of the same revision gave byte-identical meshes and textures.

| Variant | Look | Height × width (units) | LOD0 / LOD1 / LOD2 triangles |
|---|---|---|---|
| A | Round oak, mid green | 3.00 × 2.55 | 1,918 / 772 / 238 |
| B | Tall linden, fresh yellow-green, slight lean | 3.40 × 2.30 | 1,918 / 772 / 238 |
| C | Wide chestnut, deeper cool green | 2.80 × 2.75 | 1,918 / 772 / 238 |

The three variants have identical triangle counts because each LOD is decimated to the same crown target. The crown and trunk splits for each LOD are in `READY.json`.

**Trunk**
- Tapered, with 4–6 root fins flaring onto the ground.
- 2–3 short branches reach up into the crown (LOD0 and LOD1 only).
- Analytic smooth normals.
- Bark UVs run once around the trunk and tile every 2 units up it.

**Crown**
- A union of rounded leaf-cluster lobes: metaballs, then a voxel remesh, a smooth and a collapse decimation. It is solid, with no alpha cards.
- Its normals are softened toward the crown's ellipsoid (55%) so the foliage shades as one soft mass.
- The leaf UVs keep one world scale (one tile per 1.6 units, so a leaf is about 0.2 units). The sides use a wrap-around projection with a whole number of tiles around. The top and underside are projected from above, so the leaves hang toward the gameplay camera.

**Materials and textures**
- Each tree has two materials: its own leaf material and the shared bark.
- The four textures are 512 seamless tiles, painted by the script with numpy: `leaf_A`, `leaf_B`, `leaf_C` and `bark`. They use soft gradients and organized overlapping leaf shapes, with no noise or grain.
- They are **unsmoothed**. `tools/smoothed.json` was not touched; smooth them once at integration.

**Scale**
- 1 unit = 1 tile. The origin is the trunk base on the ground. The `.blend` is Z-up; the glTF is Y-up.
- The game fits each tree to a height of 2.0–3.7 by its bounding box (`world.gd`), so the authored height sets proportion only.

**Files** (in the revision folder)
- `mesh/*.gltf` and `.bin`, with `mesh/textures/*.png`;
- `source/broadleaf_candidate.blend` (textures packed);
- `source/generator/`: copies of the scripts;
- `build_report.json`;
- `renders/`: the raw renders;
- `previews/`: the labelled sheets.

## Previews (candidate renders, not in-game evidence)

All previews are in `previews/`:
- `turntable_A.png`, `turntable_B.png`, `turntable_C.png`: 8 angles beside a 1.44-unit hero stand-in on a 1-unit grid;
- `gameplay_angle.png` and `gameplay_angle_crop.png`: the game camera's FOV and offset, with trees on tile centres;
- `lods.png`;
- `rework_vs_rebuild.png`;
- `textures.png`: each tile with a 2×2 tiling check.

The lighting and ground are Blender stand-ins, not the game's outdoor light.

## Known limitations and review questions (as of rev_001; item 1 is addressed in rev_002)

1. Where the crown's slope passes about 52°, the leaf UVs switch from the top projection to the side wrap. That band shows a moderate leaf discontinuity and some stretching in close crops. The local model noticed it, and a close crop confirmed it. Possible fixes are a texture-sampling triplanar foliage shader at integration (027 already names `foliage.gdshader`) or a blended projection in rev_002.
2. The leaves are evenly shingled rows. They read as organized, but may be too regular or scale-like. Should they be grouped into larger clumps?
3. The bark plates have a regular vertical rhythm with soft horizontal checks. They could become broader and less banded.
4. The LODs are separate glTF files. How the engine uses explicit LODs, or regenerates its own, is for integration to decide.
5. The trees haven't been measured in the engine and haven't been checked against 022 or 023, which don't exist yet.

## Reproduce

```text
python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b --factory-startup -P tools/blender/art_candidates/broadleaf/broadleaf_candidate.py -- --rev rev_00N
python tools/blender/art_candidates/broadleaf/make_sheets.py rev_00N
python tools/blender/art_candidates/broadleaf/finalize.py rev_00N     # writes READY.json last, atomically
```

`inspect_source.py` renders the unmodified source derivative on its own.
