# Kelpwick arena — Stylized House

**Stylized House** by [Kesenkai](https://sketchfab.com/kesenkai).
Source: [Sketchfab model](https://sketchfab.com/3d-models/stylized-house-f61cb7025926470e89fce61e38ee409b),
provided by the user as `stylized_house.glb`.
Licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
These author, title, source and licence details are embedded in the supplied GLB's `asset.extras`.

Changes: baked the mesh and base-colour texture; removed the TV antenna and mounting pieces, original door panels
and handle; fitted the model with a uniform horizontal scale and a ground storey that accommodates the game's
full-size door; replaced the door with the tropical huts' painted wood finish. Added a clear wooden stair approach,
arena sign, small ground bushes and concealed interior closure below the model's roof terrace. Texture resized,
smoothed through the shared pipeline and sampled with linear mipmapped anisotropic filtering. Metallic/roughness
and auxiliary texture maps are not used. The arena's playable interior is a separate rectangular stage room.

The original download is unchanged. Converted resource: `assets/exteriors/kelpwick_arena.res`.
Rebuild: `tools/prepare_kelpwick_arena.py`, `tools/import_kelpwick_arena.gd`, then smoothing and Godot import as
documented in the README.
