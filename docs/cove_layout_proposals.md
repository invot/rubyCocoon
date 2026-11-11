# Cocoon Cove: modern pirate cove

**Option A is implemented**, with the apothecary on the eastern bluff and a much
shorter pier entered only from the right. Its only buildings are wooden shacks:
the neighbor (`hut_3`) and Old Gear Shack (`hut_1`) at the far end. The plaster
neighbor (`house_2`) has moved to the western garden on land. The apothecary keeps
the kit's plaster building (`house_3`) and green shop sign. Its small rooftop room
and upper door are removed, leaving two main storeys and a sealed clay roof. A
3.1-unit ground storey exposes the front door. The kit's wraparound canopy is cut
away and replaced by the old town's shared green-and-white striped shop awning,
over a brown wood porch with its sign above the front beam. The building stands
1.2 units farther back so the porch fits inside its plot. The street lamp stands
east of the entrance sightline. Existing interiors and saved building identities
move with their roles.

The playable map uses the existing cardinal tile movement, elevation, streamed scenery,
terrain, input and story systems. Its 54x44 footprint is smaller than the previous
66x49 map. All seven saved interior identities, room contents, starter items and story
gates are retained. Invalid old saved positions recover through the normal safe spawn.
Original art-study tools remain available for design history; the playable map in
`town_maps.gd` and `cove_buildings.gd` is authoritative.

## Common direction

- Compact, welcoming seaside settlement: brown timber cottages, pastel stucco, orange clay roofs,
  opaque blue-green windows, warm lamps, planters, and stone stairways.
- Stucco colors are fixed by building: sky-blue home, coral Beast Center, sage
  apothecary, rose garden neighbor, buttery-yellow library and lavender rear cottage.
  Crates and barrel staves share the buildings' brown board texture; barrel hoops stay metal.
- A low town in a cove ringed by tall cliffs (north, west, and east above the road out);
  the player's home and the scenery cottages stand on one gentle terrace a step above
  the square, joined to it by short three-tile ramps. The library and diner-like Beast
  Center face the square. Every house has a path to its door; the camera's blind strips
  behind tall buildings are shrub thickets, never lawn that can't be walked on.
- Only wooden shacks stand over the water. The apothecary and plaster homes stand on
  land. The single right-hand stair reaches a short pier ending at the gear shack,
  with no second shore connection, ships, boats or rafts. The shack keeps its existing
  exploration role.
- Preserve all seven enterable buildings and two scenery homes. Existing interior
  identity order remains Center, home, apothecary, house, house, library, gear shack.
  Those saved identities remain fixed even though their origins move.
- Rowan and the mascot stay in the square. Bram remains the only way onto the Coastal
  Path until the first beast; the library map gift and shack items keep their rules.

## A: Lantern Horseshoe

The most compact arrangement. The home has its own high western garden; two small
scenery cottages occupy the rear shelf. A stair descends beside the library to the
square. The apothecary occupies the eastern bluff. The plaster neighbor's home sits
in the western garden. Right-hand stairs descend to one short boardwalk past a wooden
neighbor's shack, ending at the wooden gear shack's platform. It has 77 walkable deck
tiles before cargo instead of 169. There is no loop, long southern arm or onward route beyond it.

Crates and barrels dress the dock edges, gardens and shop sides. `prop_clearance`
rectangles reserve the through-lanes, stairs, square crossings and doorway approaches.
The authored-prop path uses the shared local connectivity proof and full-flood
fallback, rejecting any decoration that disconnects a formerly reachable tile.

Doors use `HouseModels._front_door`, `DOOR_H` (1.8), `DOOR_ASPECT`, and the existing
door tiles and brass knob. Blue paint marks usable doors; crimson marks doors with a
permanent resident's knock reply. Fitted to their plots the kit houses came out with doorways as low as
1.1 units, under the hero's 1.44: `cove_buildings.gd` `warped()` fits the doorway to
`DOOR_H`, the ground storey to 2.6 units (3.1 at the apothecary) and upper storeys to at least 2.45 units.
Roofs retain their proportions. The kit's own door slab is cut away so the new leaf lies on the wall.
The library uses the kit's two-storey `whole_house` (its door in the middle with a window
either side) instead of `house_4`'s converted loading bays or the smaller `house_2` cottage
it used before, with its reading room and map gift retained. The Beast Center shares the
apothecary's 3.1-unit ground storey so the sign over its awning sits under the eaves. The
pier neighbor's shack has a lived-in fisher's cabin inside (`cove_dock_shack`).
The library's canopy is the door width plus a small margin;
the other towns keep their existing shopfront widths. Dock planks have quiet painted
seams and low rails with pilings, built once into shared meshes.

## Original alternative B: Switchback Village

The strongest vertical journey. Home overlooks an intermediate residential terrace;
two turns and separate stair flights lead past a neighbor to the square below. The
waterfront extends east into a compact dock district with the apothecary and second
enterable neighbor. The old shack sits on the lower western headland; two scenery
cottages fill the rear of the main village.

Best for a more adventurous descent and distinct neighborhoods. Longer home-to-square
travel and camera sightlines will need particular attention during tile-map work.

## Original alternative C: Tidecup Lagoon

The most sheltered waterfront. A high home and rear scenery cottages overlook the
inland square; the old shack anchors a rocky western arm. A longer connected dock
walk carries the two neighboring homes and apothecary around an open water courtyard.
Both dock ends reconnect to land.

Best for the hidden-cove feeling in the reference, with more emphasis on water and
dock wandering. Keep the inland square as the main social space.

## Exterior corrections

The WholeHouseFBX geometry is retained but its noisy orange texture is replaced by
the kit's simpler plaster, timber, and clay finishes. All kit buildings replace the
orange timber atlas swatches with brown, smoothly filtered board textures, including
the physical wood infill and frames. Clay roofs retain their terracotta finish. Its front door, original window
apertures on three sides, and attic ends have physical opaque closures.

The other eight buildings receive closed doors, opaque glazing, infill behind exposed
walls, and gable closures where needed. Huts are turned so their entrances face the
same direction as the other houses. Shopfront openings become framed, opaque display
windows. Windows have colored glass and reflection marks, without showing interiors.
Repairs are baked into each mesh; they do not depend on hiding interior geometry at
one camera angle. `check_cove_exteriors.gd` checks 42 source-aperture rays, opaque
materials, and grounding across all nine building meshes.

## Reproduce

Resolve the local Godot 4.7 executable as described in the README. Supply the folder
containing the original `towns.glb` and `wholehousefbx.glb` downloads:

```text
godot --headless --path . --script res://tools/prepare_cove_proposals.gd -- --source=C:/path/to/downloads
godot --headless --path . --script res://tools/smooth_textures.gd -- --only=res://assets/exteriors/cove_
godot --headless --path . --import
godot --headless --path . --script res://tools/bake_cove_measurements.gd
```

Run the quick checks and the exterior scenario, then render the studies:

```text
bash tools/run_tests.sh quick
bash tools/run_tests.sh cove-exteriors
bash tools/run_tests.sh cocoon cocoon-touch
bash tools/run_tests.sh door-voices door-voices-touch exteriors
python tools/town_check.py
godot --path . -- --scene=cocoon --preview=overview --shot=res://build/shots/cove_game_overview.png
godot --path . -- --scene=cocoon --preview=square --shot=res://build/shots/cove_game_square.png
godot --path . --resolution 2400x1080 -- --scene=cocoon --touch --preview=docks --shot=res://build/shots/cove_game_touch.png
```

Original isolated art studies (not used as runtime maps):

```text
godot --path . --script res://tools/cove_proposals.gd -- --layout=a --shot=res://build/shots/cove_a.png
godot --path . --script res://tools/cove_proposals.gd -- --layout=b --shot=res://build/shots/cove_b.png
godot --path . --script res://tools/cove_proposals.gd -- --layout=c --shot=res://build/shots/cove_c.png
godot --path . --script res://tools/cove_proposals.gd -- --layout=gallery --shot=res://build/shots/cove_asset_gallery.png
godot --path . --script res://tools/cove_proposals.gd -- --layout=gallery --model=whole_house --shot=res://build/shots/cove_whole_after.png
```

`--view=square`, `--view=home`, `--view=harbour`, or `--view=apothecary` gives a closer art view;
`--hold=1` keeps the study window open. These tools do not load or modify saves.

The source ZIP lacks its OBJ material libraries and a licence statement, so the
derived assets use the self-contained, attributed GLBs instead. See
[asset provenance](../licenses/pirate_cove.md). Original downloads are untouched.

`bake_cove_measurements.gd` exports the renderer's fitted plot bounds for the Python
sightline checker. Re-run it after changing plots or fitting rules. The `cocoon`
scenario checks the short shack-only dock, cargo placement, clear walking lanes,
the two-tile right-hand entrance, standard doors, old interior
ids, old-position recovery, the route to the shack, item collection, and the library
gift. Its touch mode enters the shack and library through actual world taps.
