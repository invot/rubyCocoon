# Water rendering

The shared `scripts/gfx/water.gdshader` draws clear shallows over the actual terrain and assets, with depth absorption
into the biome's blue, small crossing swells, finer surface ripples, moving caustic light and contact foam. Beach wash
travels towards the sand. Rocks that break the surface get a foam edge; fully submerged rocks remain visible without
a surface foam ring. These are visual waves, not a fluid or buoyancy simulation.

The light pattern is a faint, connected honeycomb of large irregular cells, rather than separate white strokes.
Its edges gently reshape and drift with `drift` (world units per second): downstream along the north-to-south rivers,
and north towards the sand at the south-facing beach. Both deformation and travel are deliberately slow.
The cell network is analytic and antialiased, with a soft halo; it shares the existing depth lookup.

Freshwater biomes (river, jungle and moor) allow sparse clusters of rounded, notched lily pads on level grassy banks.
Coastal regions, sand and wading shelves are excluded, as are crossings, dock edges, fishing spots and nearby boats.
The leaves reuse the cached prop mesh and chunked scenery batches, cast no shadows, and ride the same shader swells
as the water. They add no collision or CPU animation and never change navigation, elevations or saves.

`scripts/world/terrain_mesh.gd` deepens open-water beds according to distance from land. Narrow streams stay shallow.
It continues the adjacent water level beneath raised bridges, docks and over-water buildings, copying the elevation
arrays so movement heights stay intact. A backdrop plane sits below the deepest bed instead of clipping through it.

`scripts/world/shoreline.gd` and the shader share the curved beach profile. The shallow shelf still stops at five
centimetres and only the authored `a` tiles are walkable. The offshore floor reaches -1.65. Beach stones reuse the
existing scenery pack and batches, stand beyond the wading row and cast no extra shadows.

## Tuning

- `tint`: the existing per-biome water colour; the shader derives its deep colour from it.
- `wave_height`: default 0.045 world units. Waves flatten on the wading shelf. The mesh's extra cull margin covers
  the displaced surface. Pool and waterfall materials can reduce this parameter for quieter water.
- `spec`: default 0.4; the temple's moving pool keeps its existing zero-specular override.
- `opacity`: maximum opacity, 0.96 outdoors; shallow-water opacity comes from actual depth.
- `absorption_strength`: default 1.35; battle scenery uses 2.7 to keep its shallow sandy stage blue from above.
- `shore` / `shore_levels`: supplied from the map's existing shoreline rectangle and shared shoreline constants.
- `drift`: the horizontal light pattern's flow direction and speed (normally 0.03 world units per second).

No new textures or third-party code are required. Horizontal water uses one depth lookup and analytic animation,
with no screen-colour/refraction copy, extra camera, compute simulation or per-frame CPU updates. Existing texture
frames still animate lava. Waterfalls use the same palette and depth-based opacity as horizontal water,
with subtle vertical stream lines pulsing downward instead of honeycomb cells. Temple falls inherit their pool's tint.
The randomly spaced stream lines undulate, break and fade as they descend at 1.2 world units per second (before
the temple's stretch adjustment). Natural falls have a narrow white crest on a joined, level lip; the river's swell
eases to zero at that lip and the falling face shares its boundary, closing the former gap. Only the cliff face behind a fall
gets a slight blue tint and lightness lift; neighbouring dry rock keeps its regional finish.
The natural fall is recessed 0.16 units from the cliff edge, with its backing rock another 0.06 units behind it.
Shared visual corner offsets shape both the bed and banks into the shallow channel; navigation heights stay intact.
The outer banks remain forward of the channel and return slightly over its corners so the crest ends tuck under
the dirt. Riverbend's left stone fence ends a tile short of the fall, with low planting keeping the cliff edge blocked.
Depth reconstruction accounts for the different Vulkan/OpenGL ranges.
Contact foam uses the opaque depth buffer: fully transparent props do not contribute an intersection.
Fishing battles use the same shader over their sandy bed, and distant battle scenery uses a fixed depth tint where
there is no modelled bed. Both battle water meshes have one-unit subdivisions for the small swells.

The visual direction is the clear sand, depth colour and shoreline foam in the supplied reference. Research examples:
[Emilje's Godot 4 water shader](https://github.com/emilje/godot-water-shader) demonstrates Gerstner waves, depth fading
and intersection foam. This implementation stays inside the game's existing terrain/material pipeline.
[Godot's depth reconstruction documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)
explains the renderer-specific projection conversion used here.

## Checks and captures

`godot` below means the local Godot 4.7 executable. All preview state stays under `build/`.

```sh
bash tools/run_tests.sh quick
godot --headless --path . --script res://tools/check_water.gd
bash tools/run_tests.sh shellhaven-marina shellhaven-marina-touch temple-water tides-walk
godot --headless --path . --script res://tools/check_maps.gd
python tools/town_check.py
```

The focused check protects unchanged walking elevations, separate river levels, submerged dock beds and the entire
beach's five-centimetre wading limit. The marina scenarios exercise real directional/tap navigation and deep-water
blocking; the temple scenarios cover waterfalls, drains and progression.

Windowed preview, with steady-frame timing and two captures at different animation times:

```sh
godot --path . --resolution 1920x1080 --script res://tools/water_preview.gd -- --scene=world:shellhaven --overview=15 --focus=43,24 --quit=0 --wait=2 --shot_w=0 --shot=res://build/shots/water/beach_desktop.png --save_dir=res://build/water_saves/
godot --path . --rendering-method mobile --resolution 2400x1080 --script res://tools/water_preview.gd -- --scene=world:shellhaven --spawn=43,23 --touch --quit=0 --wait=2 --shot_w=0 --shot=res://build/shots/water/beach_touch.png --save_dir=res://build/water_saves/
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1920x1080 --script res://tools/water_preview.gd -- --scene=world:shellhaven --overview=15 --focus=43,24 --quit=0 --wait=2 --shot_w=0 --shot=res://build/shots/water/beach_compatibility.png --save_dir=res://build/water_saves/
```

Add `--hold=1` after `--` to keep the window open. For other views, use `--scene=world:tidewater --spawn=28,31`
for the harbour, `--scene=world:reef#0` for the temple pool, or the ordinary screenshot harness's
`--scene=battle --kind=fishing` for a reeled-in encounter. A desktop run with the Mobile renderer
checks that renderer's appearance; it does not establish performance on an actual phone.

For a lily-pad view through the real gameplay camera, use the windowed preview with
`--scene=world:riverbend --lilies=1 --quit=0 --shot=res://build/shots/water/lilies.png`.
The focused water check also audits every outdoor map for deterministic placement, unchanged navigation tiles,
and the exclusion of coastal water, beaches and wading shelves.
