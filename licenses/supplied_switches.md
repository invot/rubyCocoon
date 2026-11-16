# Supplied levers and switches

Supplied by the user on 2026-11-16 as `Levers & Switches.zip`.
The earlier `Lever.zip` is superseded and is not used.

- Source geometry: `collection/model_0.obj`.
- Source reference materials: `Levers_Levers_mat_BaseColor.png`, Normal,
  Roughness and Metalness, under `collection/`.
- No author, source page or license document is included in the supplied archive.
  These fields remain unverified; no third-party license is inferred.

The original archives remain untouched. Only fitted, simplified derivatives of
the floor lever, the third/smaller wall switch and three push buttons are used.
Large wall controls and their industrial texture maps are not shipped.

Changes: discard zero-area connector triangles; separate moving parts; dissolve
coplanar subdivisions; simplify curved rings while retaining silhouette and
material boundaries; soften normals; fit sturdy proportions to existing fixtures.
Retexture the floor lever's shaft with the exact shared fence wood (`wood_material()`),
with a painted red grip and flat grey stone base and axle arches; use smooth stone and red controls on the wall switch and
buttons. The source's English lettering and scratched metallic finish are removed.

Triangle counts (source excluding zero-area faces -> runtime):

| Model | Source | Runtime |
| --- | ---: | ---: |
| Floor lever | 796 | 346 |
| Small wall switch | 960 | 214 |
| Mushroom button | 696 | 213 |
| Small mushroom button | 576 | 187 |
| Round button | 976 | 320 |

The complete source collection contains 13,896 triangles, of which 6,666 have
zero area. The selected five models use 1,280 runtime triangles in total,
compared with 4,004 nondegenerate source triangles (68% fewer).
Counts exclude each weapon fixture's support pedestal, which instances the same
84-triangle bevelled stone housing mesh without another asset.

Rebuild: extract the source unchanged into ignored `build/levers_source/`, run
Blender with `--background --factory-startup --python tools/prepare_switch_props.py`
through `tools/local_resource.py`, then run `tools/import_switch_props.gd`,
`tools/smooth_textures.gd -- --only=res://assets/props/switch_`, and `--import`
with the pinned Godot editor. The shared runtime textures are already smoothed
and are reused without another smoothing pass.
