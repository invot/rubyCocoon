# Supplied fence models

Supplied by the user on 2026-11-10. The original downloads remain untouched.
Only extracted, fitted fence sections are redistributed in `assets/props/`.

## Low Poly wood fence on grass

- Source file: `low_poly_wood_fence_on_grass.glb`.
- Author, as recorded in the GLB: cattleya, https://sketchfab.com/cattleya.
- Source: https://sketchfab.com/3d-models/low-poly-wood-fence-on-grass-d35a038f74ea47819459cabae8c28c62.
- Embedded license: CC BY 4.0, http://creativecommons.org/licenses/by/4.0/.
- Changes: one straight picket section extracted; grass display base removed;
  section centred, fitted to a tile and made 0.78 units high; texture resized and
  smoothed with the project's texture pipeline. Corners use joined half sections.

## Iron Fence

- Source file: `iron_fence.glb`.
- Author, as recorded in the GLB: BaseCubeRo, https://sketchfab.com/BaseCubeRo.
- Source: https://sketchfab.com/3d-models/iron-fence-ef5bdd2f8125412784d1992ba2f5c83b.
- Embedded license: **CC BY-NC-SA 4.0**,
  http://creativecommons.org/licenses/by-nc-sa/4.0/.
- Changes: one ornamental panel, its plinth and two capped piers extracted from
  the display kit and combined, fitted to a tile and made 1.0 unit high; roughness
  adapted to the existing scenery materials. Corners use joined half sections.
  The supplied license includes noncommercial and share-alike conditions.

## Low Poly stone fence on grass

- Source archive: `Low Poly stone fence on grass.zip`.
- Source members: `collection/model_1.obj` and `collection/fence1.png`.
- No author, source page or license document was included in the archive; these
  attribution and license fields remain unverified. No license is inferred from
  the similarly named wooden model.
- Changes: a straight masonry section extracted; display grass and degenerate
  connectors removed; section centred, fitted to a tile and made 0.72 units high;
  texture resized and smoothed. Corners use joined half sections.

## Rebuild

`tools/prepare_fences.py` reads the supplied downloads into ignored
`build/fences_source/`. `tools/import_fences.gd` uses the shared scenery material
and LOD helpers to bake the three meshes. Run `tools/smooth_textures.gd` afterward,
then Godot's `--import`. See the README for commands.
