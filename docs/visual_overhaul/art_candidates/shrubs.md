# Bushes, hedges, flowers and fruit: artwork candidate

**Status:** **rev_001 approved by the user as the shrub, hedge and flower candidate on 2026-11-13.** **rev_002**, published the same day, adds the straight hedge middle piece and the fruit bush you asked for. **It was approved by the user as the candidate on 2026-11-13 and supersedes rev_001.** This is preproduction for runbook step 028 (S8: bushes, hedges and flowers). **It is not integrated, and 028 is not complete.** Integration waits for:
- Codex's technical review;
- steps 011, 022 and 023 (budgets, material presets and the scale sheet);
- 027's tree integration;
- an in-game check.

**Owner:** Claude's art-candidate lane ([parallel-handoff.md](../parallel-handoff.md)). Codex reviews only published revisions, in its own review file.

## Revisions

| Revision | Published | Folder | Notes |
|---|---|---|---|
| rev_001 | 2026-11-13 | `build/art_candidates/shrubs/rev_001/` | First candidate. 4 bushes, 1 hedge and 4 flower clumps, 2 LODs each. `READY.json` lists hashes, counts, scale and provenance. **Approved by the user as the candidate on 2026-11-13** |
| rev_002 | 2026-11-13 | `build/art_candidates/shrubs/rev_002/` | Adds `hedge_middle`, `bush_E` (fruit bush), `bush_E_picked` and `fruit`. rev_001's nine models are byte-identical; the atlas gains a fruit cell. **Approved by the user as the candidate on 2026-11-13** |

Published revisions never change. Corrections go in `rev_002` and later revisions.

## rev_002: what's new

You asked for a straight hedge middle piece and a fruit bush with large fruit that the player can pick and feed to beasts (restoring HP like a Minor Potion).

| Model | Look | W × D × H (units) | LOD0 / LOD1 triangles |
|---|---|---|---|
| `hedge_middle` | Straight clipped hedge, one tile, with two top domes. Laid end to end, or against the rounded `hedge`, it joins without a notch; the last piece of a run ends squared off | 1.40 × 0.81 × 0.95 (covers 1 tile; the ends overlap the neighbours by about 0.2) | 1,152 / 576 |
| `bush_E` | Fruit bush (leaf C) with four large orange-red fruit on its south side, toward the camera | 0.94 × 0.82 × 0.89 | 1,632 / 584 |
| `bush_E_picked` | The same bush with the fruit gone, to swap in after picking | 0.94 × 0.80 × 0.80 | 816 / 344 |
| `fruit` | The fruit alone (about 0.2 across), with a stalk and leaf, for holding, dropping or an item view | 0.22 × 0.21 × 0.23 | 276 / 156 |

**How the middle piece joins.**
- Its body uses a squared footprint: a superellipse resampled by arc length, so the scallops stay evenly spaced.
- That keeps nearly full width out to its ends, so overlapping pieces show no waist.
- Its two top domes repeat every half tile, so a run's rhythm doesn't change at the joins.

**Pick points.** The fruit centres and radii on `bush_E` are in `READY.json` (`models.bush_E.fruit_anchors`), for interaction points at integration.

**Checks.**
- Every model is closed and within the provisional ranges (bushes and hedges 300–1,800; fruit, a small prop, 100–800).
- The magenta back-face check shows none, and the open control does.
- rev_001's models rebuild byte-identically.

**Gameplay is not part of this revision.** The fruit as an item (picking, regrowth, feeding a beast to restore HP like `minor_potion`: heal 40, target ally) is runtime code for integration, so it belongs to Codex's lane and waits for the bushes to be integrated (028).

**Handoff to Codex (the user's decision, 2026-11-13).** Codex builds the fruit gameplay at integration. The request:
- the player picks the fruit from a fruit bush (`bush_E`, using its pick points), and the bush then shows as `bush_E_picked`;
- the fruit becomes an item that can be fed to a beast, restoring HP like a Minor Potion;
- every action works with touch as well as keyboard and gamepad (AGENTS.md).

**Further user decisions (2026-11-13):**
- Fruit regrows whenever the player re-enters the area/map. Picked state does not persist across map visits or saves.
- Fruit-bearing bushes must be very rare; an exact placement count has not been set.
- Never place fruit near a map entry point. Place it in the map's interior or off the main path, while keeping it clear of entry points.

Ask the user what the fruit is called before building. Regrowth and picked-state persistence are already decided.

New previews in `rev_002/previews/`:
- `new_pieces.png`;
- `gameplay_angle.png` and `gameplay_close.png`, which now show a hedge run and fruit bushes;
- the updated turntables, LODs and back-face check.

## Style source

It uses the approved [broadleaf rev_003](broadleaf.md) grammar:
- pillowy painted domes;
- scalloped hems whose rounded tongues hang over a slight lip;
- faint painted scallop marks;
- no pattern of individual leaves.

Leaf palettes A, B and C are the approved broadleaf palettes, so bushes sit with the trees. The previews import the rev_003 glTFs **read-only** to show the kit beside them. No rev_003 geometry or texture is in this revision, so roroer's CC-BY credit doesn't extend to it.

## Rework or rebuild

**Decision: procedural build.**

The current `bush_*` and `shrub_*` assets are cut from the same Stylized Nature pack as `tree_oak` (`tools/prepare_stylized_nature.py`). Broadleaf already showed that reworking that pack doesn't reach the dome grammar. Building the kit directly in the approved grammar was more direct.

There is **no third-party content**: all geometry and the atlas are generated by the script.

## What was made (rev_001)

| Model | Look | W × D × H (units) | LOD0 / LOD1 triangles |
|---|---|---|---|
| `bush_A` | Round puff: a big dome with three small ones at its foot (leaf A) | 0.94 × 0.83 × 0.78 | 1,056 / 444 |
| `bush_B` | Low wide mound (leaf B) | 1.01 × 0.77 × 0.56 | 864 / 364 |
| `bush_C` | Tall upright: an egg with puffs at mid-height (leaf C) | 0.72 × 0.70 × 1.06 | 1,008 / 420 |
| `bush_D` | Flowering bush with six pink five-petal blossoms. It replaces the orange-dot bushes | 0.91 × 0.74 × 0.79 | 1,644 / 704 |
| `hedge` | Clipped hedge: a long body with three soft top domes and a scalloped skirt; rounded ends; 2 tiles long | 2.06 × 0.81 × 0.96 | 1,624 / 696 |
| `flower_daisy` | Three white daisies tilted toward the camera, on a leaf mound | 0.43 × 0.36 × 0.47 | 780 / 512 |
| `flower_tulip_coral` | Three coral tulip cups | 0.32 × 0.31 × 0.58 | 570 / 296 |
| `flower_tulip_butter` | Three butter-yellow tulip cups | 0.32 × 0.32 × 0.56 | 570 / 296 |
| `flower_pom_lilac` | Three lilac bellflowers (round heads with scalloped skirts) | 0.39 × 0.36 × 0.54 | 750 / 404 |

**Budgets.** Every LOD0 is inside the provisional ranges in standards.md §5.3:
- bushes and the hedge: 300–1,800 ("rock or substantial shrub");
- flowers: 100–800 ("small repeated prop").

These ranges are provisional until step 011, and nothing was measured in the engine.

**Construction.**
- Every mass is a closed lathe: a dome over a belly, a scalloped skirt and a tucked underside.
- Flowers are petal masses on tapered stems:
  - daisies and blossoms are lens-shaped heads cut into rounded petals around the rim;
  - tulips are three-pointed cups;
  - bellflowers are small domes.
- Every model and LOD has 0 open and 0 non-manifold edges.

**Materials.**
- One opaque, single-sided material, `shrubs_kit`, is shared by the whole kit.
- It uses one **1024 atlas**, `mesh/textures/shrubs_atlas.png`. The atlas is 4 × 4 cells of 256 with 14-texel gutters:
  - four foliage cells (leaf A, B and C, and a hedge green);
  - six petal cells;
  - a flower-centre cell and a stem cell.
- The atlas is painted with numpy: soft gradients and a few faint scallop marks, with no noise. It is **unsmoothed**, and `tools/smoothed.json` is untouched. Smooth it once at integration and set anisotropic filtering there.
- There are no alpha cards.

**Scale.**
- 1 unit = 1 tile. The origin is the footprint centre on the ground. The `.blend` is Z-up and the glTF is Y-up. The hero stand-in is 1.44 tall.
- Bushes fit about one tile. `world.gd` fits a bush to 0.9 of its blocking tile, so `bush_B` (1.0 wide) would be scaled slightly.
- Flowers are knee-high on the hero, for walk-through flower tiles.

**Checks.**
- Back-face check: culling off, back faces glow magenta, rendered from the side, below and above. The kit shows **0** flagged pixels. A positive control, the same puff with its underside removed, shows about 25,000.
  - The first check used red. Coral tulips also count as red, so it moved to magenta, which no kit colour uses.
  - The local model's "no red" reading of the drafts agreed, but the pixel count is the evidence.
- A rebuild was **byte-identical** (all glTF, bin and atlas files).

## Previews (candidate renders, not in-game evidence)

In `rev_001/previews/`:
- `gameplay_angle.png` and `gameplay_close.png`: the game camera (fov 36, offset 0,7,11). Broadleaf rev_003 trees stand behind, with bushes, two hedge pieces and flower clumps.
- `beside_broadleaf.png`: front and gameplay-pitch lineup beside rev_003 A and the hero.
- `turntable_bushes.png` and `turntable_flowers.png`.
- `lods.png`, `cull_check.png` and `atlas.png`.

The lighting and ground are Blender stand-ins, not the game's outdoor light.

## Limitations and review questions

1. At LOD1, blossoms and daisy heads become five- or eight-point stars, which is fine at distance only. `bush_C`'s top is slightly pointed at both LODs.
2. (rev_001) Two rounded-end hedges laid end to end show a small notch. **rev_002 adds `hedge_middle` for runs.** There is still no corner piece, and where middles overlap the skirt shows a faint crease.
3. `bush_D`'s blossoms are separate small solids, about 140 triangles each at LOD0. If 011's budgets are tight, a texture-only blossom variant is cheaper.
4. The bellflower is a bell rather than a pom. Should it be a rounder pom or stay a bell?
5. (rev_001) There was no fruit variant. **rev_002 adds the fruit bush `bush_E`.**

## Reproduce

```text
python tools/local_resource.py -- "C:/Program Files/Blender Foundation/Blender 4.2/blender.exe" -b --factory-startup -P tools/blender/art_candidates/shrubs/shrubs_candidate.py -- --rev rev_00N
python tools/blender/art_candidates/shrubs/make_sheets.py rev_00N
python tools/blender/art_candidates/shrubs/finalize.py rev_00N    # checks, hashes, READY.json last (atomic)
```

`finalize.py` refuses in four cases:
- the revision is already published;
- a back-face render shows magenta;
- the control doesn't;
- any mesh is open.
