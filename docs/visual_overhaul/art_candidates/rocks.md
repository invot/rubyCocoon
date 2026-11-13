# Rock family: artwork candidate

**Status:** **rev_001 approved by the user as the rock family candidate on 2026-11-13.** This is preproduction for runbook step 030 (S10: rocks). **It is not integrated, and 030 is not complete.** Integration waits for:
- Codex's technical review;
- steps 011, 022 and 023 (budgets, material presets and the scale sheet);
- the mixed nature gallery (028).

**Owner:** Claude's art-candidate lane ([parallel-handoff.md](../parallel-handoff.md)). Codex reviews only published revisions, in its own review file.

## Revisions

| Revision | Published | Folder | Notes |
|---|---|---|---|
| rev_001 | 2026-11-13 | `build/art_candidates/rocks/rev_001/` | First candidate. 4 shapes × 2 palettes (grassland, coast), 2 LODs each. `READY.json` lists hashes, counts, scale and provenance. **Approved by the user as the candidate on 2026-11-13** |

Published revisions never change. Corrections go in `rev_002` and later revisions.

## What 030 and the standards ask

- **Runbook 030:** "a Blender rework of the rock meshes: designed broad planes, softened transitions, partly buried bases, coast and grassland colours".
- **Standards §11:** related rocks share grain scale and crevice contrast. No floating bases, balancing boulders, accidental pyramids, or a mix of very angular and inflated rocks.

## Rework or rebuild

**Decision: per shape.** Every shape went through the same pipeline from two point sets, and the better one was kept. `previews/rework_vs_rebuild.png` shows the pack's cut, the rework and the procedural build side by side.

**The source.** The game's 18 rock names come from the supplied *Environment Pack - Stylized Rock*, cut by `tools/prepare_stylized_nature.py`.
- The script reuses six boxes, so there are only 7 distinct cuts.
- Rendered in `build/art_candidates/rocks/inspect/`, they are faceted, crystal-like pieces with a marbled texture.
- Several are peaks or spikes.

**The pipeline:**
1. Convex hull.
2. Limited dissolve (16°) into a few broad planes.
3. A two-segment bevel on the ridges only (edges sharper than 22°), for softened transitions.
4. The base cut 0.07 below the ground line and capped, so the rock is partly buried.
5. Weighted normals, so the planes shade flat and the bevels round.

**What each shape uses:**

| Shape | Built from | Why |
|---|---|---|
| `rock_A` field boulder | procedural | The `field_rock` cut's hull rises to a peak (an accidental pyramid) |
| `rock_B` tall boulder (cliff foot, shallow water) | **rework** of `mountain_1` | The squat column keeps broad, designed planes |
| `rock_C` low outcrop (knee high) | **rework** of `mountain_0` | The broad layered slab keeps its planes. Its narrow underside is sunk below the ground line so it rests rather than balances |
| `rock_D` stone cluster (ankle high) | procedural | The `rock_small` cut is a thin spike, so it's three rebuilt stones instead |

The reworks use only the pack cuts' vertex positions; no pack texture, UV or face is used. The pack's provenance is already recorded in `CREDITS.md` and `licenses/supplied_environment_packs.md`. It came with no licence, so your rule treats it as Creative Commons.

## What was made (rev_001)

| Shape | W × D × H above ground | LOD0 / LOD1 triangles |
|---|---|---|
| `rock_A` | 0.81 × 0.76 × 0.59 | 234 / 98 |
| `rock_B` | 0.81 × 0.76 × 0.91 | 586 / 246 |
| `rock_C` | 1.35 × 0.92 × 0.40 | 594 / 248 |
| `rock_D` | 0.60 × 0.42 × 0.23 | 482 / 202 |

**Exports.** Each shape exports twice: `rock_X_grass_lodN` and `rock_X_coast_lodN`, with the same geometry and a different material.

**Budgets.** All are within the provisional "rock or substantial shrub" range (300–1,800) or under it; `rock_A` is below the 300 planning floor. These ranges are provisional until step 011, and nothing was measured in the engine.

**Textures.** There are two 1024 atlases, `rocks_grass.png` and `rocks_coast.png`, each with a 512 cell per shape. They're baked with numpy from each texel's position and the plane it belongs to:
- a steady tone per broad plane;
- lighter top planes;
- a soft pale edge on the bevels;
- a darker contact shade at the ground;
- broad smooth colour patches, with no grain.

On the grassland atlas, moss settles on the tops. On the coast atlas there's a darker wet band low down and salt-pale tops.

The atlases are **unsmoothed**, and `tools/smoothed.json` is untouched. Smooth them once at integration and set anisotropic filtering there.

**Materials.** One opaque, single-sided material per model, with no alpha.

**Scale.**
- 1 unit = 1 tile, and the origin is the footprint centre on the ground line.
- Bases continue 0.07 below the ground. The game currently re-anchors rocks by the bottom of their bounding box (`world.gd`), which would lift them 0.07. Integration should anchor them at the origin.
- The game fits rocks with `VA.fit_scale`, so the authored size sets proportion only.

**Checks.**
- Every model and LOD has 0 open and 0 non-manifold edges.
- Back-face check: magenta, from the side, below and above, at LOD0 and LOD1. It shows none, and an open control does.
- A rebuild was byte-identical: meshes and both atlases.

## Previews (candidate renders, not in-game evidence)

In `rev_001/previews/`:
- `beside_nature.png`: a mixed lineup with the approved broadleaf rev_003 and shrubs rev_002, imported read-only.
- `gameplay_angle.png` and `gameplay_close.png`: the game camera, with grassland rocks among the trees and shrubs and coast rocks in front.
- `rework_vs_rebuild.png`.
- `turntable_grass.png` and `turntable_coast.png`.
- `lods.png`, `cull_check.png` and `atlases.png`.

The lighting and ground are Blender stand-ins.

## Limitations and review questions

1. `rock_A` (procedural) has a few thin planes converging on its shoulder.
2. The coast wet band is subtle at gameplay distance. It may need darkening against real water at integration.
3. Coast and grassland share geometry. Should coast rocks get their own detail, such as a tide line or barnacles?
4. Horizon hills (`mountain_*`) and cliff faces are outside this family.
5. Is the grey-beige stone right for both biomes, or should grassland lean cooler and coast warmer than this?

## Reproduce

```text
python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b --factory-startup -P tools/blender/art_candidates/rocks/rocks_candidate.py -- --rev rev_00N
python tools/blender/art_candidates/rocks/make_sheets.py rev_00N
python tools/blender/art_candidates/rocks/finalize.py rev_00N    # checks, hashes, READY.json last (atomic)
```

`inspect_source.py` renders the pack's distinct cuts on their own.
