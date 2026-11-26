# Editing the maps

[◀ Manual index](index.md)

The maps are plain text in `scripts/data/maps/`. Each string is one row of tiles, and the legend is at the top of each file.

## Contents

- [Tiles](#tiles)
- [Weapon fixtures](#weapon-fixtures)
- [Signs](#signs)
- [Push puzzles and anchors](#push-puzzles-and-anchors)
- [Valkoog's wind puzzles](#valkoogs-wind-puzzles)
- [Heights, cliffs and ramps](#heights-cliffs-and-ramps)
- [Floods and levers](#floods-and-levers)
- [Bridges and trees](#bridges-and-trees)
- [Rooms and levels](#rooms-and-levels)
- [Towns](#towns)
- [The Scaraba Desert's sections](#the-scaraba-deserts-sections)
- [Checking maps](#checking-maps)

## Tiles

### Buildings

Buildings are solid rectangles of one letter, for example:

- `C` Beast Center, `X` electronics, `V` Sky Tower
- `I` Gearheart Tower, `B` cathedral, `J` hideout, `Q` temple

### Ground and obstacles

| Tile | Meaning |
|---|---|
| `a` | Walkable shallow water. |
| `~` | Ordinary water, blocked. |
| `w j d o y l i \| x m` | Obstacles. |
| `n` | A washed-out footbridge, mended with the logs stacked by Old Hal's door. |
| `k` | A cliff that needs a winged beast. |
| `u` | A boulder (push puzzle: moves one tile). |
| `e` | An ice block (slides). |
| `c` | An icy floor. |
| `*` | A crystal shard. |
| `&` | A story gate. |

`s` is Cocoon Cove's Old Gear Shack, at the end of the dock (room `shack` in `interior_maps.gd`). `b` is Youngster Kit's log cabin on the Coastal Path (room `kit_cabin` in `interior_maps.gd`, where an `anchors` entry puts Kit by the fire).

A map's `shoreline: [west_x, slope_start_z, east_x, offshore_end_z]` supplies the smooth sandy profile shared by terrain, character grounding and touch picking; only the authored shallow row is walkable.

### Room templates

In `interior_maps.gd`:

- `>` and `<` are stairs to the next and previous floor.
- `w` in a wall is a window, and a furniture letter is furniture: `room_builder.gd` `KINDS` builds it from `interior_maps.gd` `FURNITURE` and `map_loader.gd` `ROOM_CHARS` (`c` chair, `t` table, `b` bed, `E` desk, `B` bookshelf, `s` shelf, `l` floor lamp, `p` plant, `k` counter, `N` nightstand, `Q` dresser, `)` pouf, `[` basket …). A kind no letter names is a **fixture**, `"fixtures": [[x, y, kind], …]`: `"barrel"`, `"crate"` and `"boulder"` (a large stone) are the workshop props DunGen places, beside `"lockers"`, `"booth"`, `"diner_table"`, `"cash_desk"`, `"computer"`, `"large_plant"`, `"side_coffee_table"`, `"concert_table"` and `"cot"`. Area rugs are `"rug_rects": [[x, y, w, h], …]` in the room's `"rug"` colour, and long runners `"runners"`. DunGen's **Props** layer paints the furniture and fixtures (its Objects layer's **Area rug** drags a rug), so a room's props can be laid out and seen in its Game look.
- `K` is a kennel pen and `@` a red phone.
- `_` is a pool of water, sunk in stone. A door symbol of `<` or `>` in `doors` is drawn as stairs.
- An `encounter` with `"roam": true` lets its wild beasts walk the room's floor (a temple's maze) instead of only its mist.
- An `encounter`'s optional `"beasts": [{"race": 30, "lv": [21, 24]}, ...]` gives each race its own level range. Keep
  `"races"` (the same races, the first the most common) and `"lv"` (lowest to highest of them) beside it: phone hints
  and pack sizes read those. DunGen, the dungeon editor (`tools/dungeon_builder`, hosted at
  https://dungen.rubycoccon.pages.dev), writes all three.

## Weapon fixtures

Weapon fixtures use each road's `weapon_obstacles` list, rather than a tile letter. Every entry has:

- a stable `id`
- a `type` (`bullseye`, `bell`, `switches`, `cracked_rock`, `stump`)
- cardinal ordered `targets`
- a reachable default tap approach (`use_from`)

A also works from another clear cardinal approach within seven tiles (one tile for the bat).

- Optional `blocks` retain their original floors when cleared.
- `effect` is `ladder` (an authored ramp becomes a rope ladder), `gate`, or `chest` (a suspended chest falls).
- `reward` gives a chest's `pos` and `item`.

Keep firing lanes clear of trees, rocks, buildings and intervening terrain. Ranged weapons can cross water and shoot up to a visible ledge; a bat still needs an adjacent target on joined ground.

Never rename an existing fixture's `id`: saves use `weapon_<map>_<id>` and a separate `_chest` flag. Keep rewards off the story route. Leave at least **12 tiles** between different fixtures' interaction areas (targets, barriers, rewards and firing tiles); the map checker enforces this spacing in both locked and solved layouts.

## Signs

Signs (`+`) belong on verges beside paths, never on paths, paved walking lanes, bridges or door approaches. Keep them readable and reachable from adjacent level ground. The map checker checks their inferred ground and interaction approach.

## Push puzzles and anchors

- An anchor named `puzzle_exit` marks the tile that counts as solved; `puzzle_area` draws the maze walls plain.
- **Anchors** named `item:<id>` place a fixed item (one anchor letter can be used on several tiles, each with its own flag).
- `inspector`, `warden` and `sentinel` place the road blockers.
- Room templates can have `anchors` too, `item:<id>` ones included.
- A room anchor's character must mean nothing else in a room's `rows`: not a room tile (`ROOM_CHARS` in `map_loader.gd`, which keeps retired letters such as `O`, `R` and `X` as plain floor), not furniture (`InteriorMaps.FURNITURE`), not `P`, and not `*` (a shard) or `$` (a random item). The ones left are the digits and `-`, `'`, `` ` ``, `]`, `{`, `?`, `;` and `,` (plus any character a room's own `doors` claims first). Or name the tile in `anchor_tiles` instead.

## Valkoog's wind puzzles

A room's `"wind"` (`scripts/world/wind_puzzle.gd`, the rules and the solver; `air_temple.gd`, the play; `wind_pieces.gd`, the models) is a set of pieces, each placed on the room anchor `wind_<id>`:

- `"kind": "breath"`: a keepers' hall. Vents (`"dir"`) breathe wind one way until something stops it; fans turn a quarter clockwise when pushed and send it on their way; sand jars (only with the twins along) slide the way you push until something stops them, and stop wind; pinwheels spin when wind reaches them. Its `"gate"` (`{"at": anchor, "needs": [pinwheel ids], "fed": true}`) is a sand curtain across the flight up, which falls once every pinwheel it needs spins and no wind feeds it.
- `"kind": "gale"`: the dragon's path. Wind-stones (`"flag"`) sleep until the hero casts Gust into them (`Story.field_cast`); vanes (`"tilt"` `/` or `\`) flip when pushed and turn the wind through them; a gale carries the hero along it to its end, and one that ends over a chasm (a space in `rows`, `IVOID`) sets you back where you stepped in. `"reach": anchor` is solved once you can stand there; `"goal": id` once the gale powers that updraft (`"to": anchor`), which lifts you to its ledge.
- Each solved room sets `valkoog_wind_<room>` and keeps its layout (`valkoog_wind` in the save). The twins hint, notice when a hall is stuck (`Wind.solve`) and offer to blow it back as it started.
- Design a room with the solver: `Wind.solve` gives the least moves from a layout, and `--scene=valkoog` plays every room's solution through the pieces' own talk. `check_maps.gd` counts what a gale room's winds reach as reachable.

## Heights, cliffs and ramps

A map's `heights` rows (one character per tile, lined up with `rows`) give each tile a level, `0`-`9`, one unit apiece.

- `^ v < >` is a ramp rising that way, and a run of them climbs evenly between the levels at its two ends (give it two tiles a level; runs side by side make a wide ramp).
- Neighbours on different levels meet at a cliff.
- `/` and a backslash (written `\\` in the GDScript strings) are diagonal cliffs across their tile: each half takes the level of the neighbours along its two sides, which must agree, and one half must be higher.
- A tile with a diagonal is out of bounds to everyone; walkable ground there becomes `MapGen.LEDGE` (its first type kept in `m["ledges"]` for the ground's look), and scenery on it moves onto the high half.
- Keep the back and sides high and the south low (the camera looks north), put every building, its doorstep and everyone standing about on level ground, and keep tall things off high ground just south of a road.
- `"cliffs": "walls"` draws a town's cliffs as stone retaining walls.

**Cutting corners:** `godot --headless --path . --script res://tools/cliff_corners.gd [-- --write] [map ids]` cuts the square corners of the maps' cliffs into diagonals (outer corners first, then inner ones).

- It reports each corner it leaves square and why (a doorstep, someone standing there, a shore, bridge or ramp beside it, or the only way through) and never cuts a corner that would shut anywhere off. Without `--write` it only reports.
- Run it after drawing new high ground, then both checkers.

**Cliff rock** per biome is `WorldDB.CLIFF_LOOKS`: `tex` (`rock`, `sandstone` or `slate`, the greyed textures `tools/import_cliffs.gd` bakes from the cliff packs), `tint`, `scale` (repeats per unit along and down the face), `flutes` (how deep the ribs are), and optionally `band` (strata in a second colour). Cliff faces have no moss overlay. A biome's `"woods"` is the share of its wood tiles that grow a tree (the volcano's thin dead wood).

## Floods and levers

A map's (or a room's) `floods` give a character for each stretch of water that a lever drains (`{"flag", "wet", "dry"}`; with `"rises": true`, a dry channel that fills instead).

- The character stands for its `wet` tile until the flag is set, then for its `dry` one: ground, floor, or a way on, such as stairs that are also in the room's `doors`.
- An anchor `lever:<flag>` places the lever that sets the flag, and the map's `levers[flag]` gives its words (`ask`, `lines`, `done`).
- An anchor `chest:<item>` places a treasure chest.
- `tools/check_maps.gd` checks every map both flooded and drained, and checks that no lever stands behind the water it drains.

### Rooms of several levels

The Temple of Tides shows how a room's `heights` rows work outdoors (`elevation.gd`), with `level_h` the height of a level and `top_level` the digit that is floor level, so the rest sink below it.

- Ramps are drawn as flights of steps and the drops between levels as stone faces (`room_builder.gd` `_levels`), and walls and doors reach down to the floor beside them.
- `water_levels` (`[[flag, y], ...]`) sets the water: it stands at the first `y` whose flag isn't set, drawn by `tide_water.gd`; `floods` decides which tiles are under it.
- `stone_doors` lists door characters drawn as engraved stone doors in an aqua frame, which sink into the floor to open. `open_doors` lists door characters left open (an archway with a recessed tunnel behind it), `staff_doors` puts the STAFF ONLY plate on a door's leaf, and `locked_doors` holds a door shut until its flag is set (`""` for one that never opens).
- `puzzle` names a water puzzle in `scripts/data/tide_puzzles.gd`, whose letters in `rows` are its falls' spots and whose levers are anchors `switch:<n>` (0-3 route the falls; the maze's hidden `switch:4` drains it after all four are down). Its back-wall cubby uses `TidePuzzles.CUBBY_TILE`, with the interaction anchor on the raised tile directly in front.
- An anchor `chest:<item>@<flag>` lies hidden until the flag is set. A chest's save flag counts the map's chests in reading order; a `#<n>` on the end of its anchor gives it number n instead, so a moved chest keeps its flag.

## Bridges and trees

- `"bridge_rails": true` puts rails along a map's plank bridges.
- `"ornate_bridges": [[x, y, w, d]]` builds a stone bridge with balustrades over those tiles (`temple_props.gd`).
- `"tall_trees": [[x, y, w, d]]` makes the trees in those areas an old wood, half as tall again with wider crowns.
- `"low_trees"` areas grow only thickets of shrubs on their tree tiles (undergrowth south of a path, where trees would hide you).

## Rooms and levels

Most rooms are `stage` rooms: one compact room seen whole like a stage set (no front wall, the camera still), the front door (`D`, blue, with a window over it) in a side wall.

- A building of several rooms (`SHOP_ROOMS`, `HOUSES`) joins them with doors in their walls (`doors`: a symbol for each, and the room it leads to), each room loaded on its own; locked doors (`L`, red) can say what's behind them (`locked`).
- A door that opens is its own leaf on a hinge (`room_builder.gd` `_hinged_leaf`; `world.gd` `_through_door` swings it open, `spawn_at` shuts the one you came in by).
- Stairs (`>`) lead to the next room in the set, which is always a landing (`home_hall`, `house_up_hall`: two tiles deep, the stairwell `<<<` at one end and the doors to that floor's rooms off it).
- Sky Tower lobbies have a visible side-wall entrance like home; lobbies and open-air decks use the same three-tile stair flights and recessed stairwells as home (`stair_flights` in their room templates).
- `RoomBuilder.stair_ways_in` says where each flight can be stepped onto from (its open end only), and coming back down you step off the foot of the flight.
- A room's walls take their finish per zone from `room_builder.gd` `ZONES`, and `"wall_tex": {"stone": "wall_brick"}` names one for a zone instead (brick, `wall_wood` boards, `wall_plaster` with its skirting, the house papers, tiles, marble, `ashlar` or `blocks`). `"wall"` is the colour those walls are tinted with (`"trim"` the plastered ones' skirting and boards), and `"wall_height"` how high they stand (2.8 by default; a cave's rock stands `well_cave.gd` `WALL_H` over the floor beside it, `"tall_back"` higher at its back). DunGen's Room tab picks the material and the colour apart.
- Floors are laid in a material and a colour: `"floor_tex": {"wood": "floor_wood"}` names the floor per zone (`floor_wood`, `floor_wood_2`, `floor_carpet`, `floor_carpet_2`, `floor_tiles`, `floor_stone`, `floor_marble`, `floor_terracotta`, `floor_ancient`, `floor_ring`, `checker` or `floor_cave`), and a `"*"` key lays one floor in every zone at once; `"floor_colour"` lays it in that colour (`room_builder.gd` `floor_surface`): the planks' gaps, the carpet's weave and the tiles' grout stay, in a darker shade. DunGen's Room tab picks the material and the colour apart, with swatches for each.
- Walls can be capped and blacked out: `"black_caps": true` lays a black ceiling tile over every wall and four tiles out behind the back and side walls (`room_builder.gd` `_wall_caps`), so the wall tops end in black rather than the backdrop; `"black_walls": [[x, y], …]` draws those wall tiles flat, unlit black (`_black_walls`), to block the backs of details in front of them; and `"false_walls": [[x, y], …]` are invisible walls (a stage set's false wall) that still block walking. DunGen's Room tab has the caps, and its Objects layer the two wall brushes (on a `#` or a window `w`).
- Fog is a room's own, not painted a tile at a time: `"fog": 7` (1-10; none when absent) hazes the whole room in its own pale wall colour (`world.gd` `_build_room`, `FOG_STEP`), 10 being a very thick fog that hides the far wall. `g` is where wild beasts hide, not a mist tile.
- Raised platforms are `"dais": [{"rect": [x, y, w, h], "steps": [[x, y]] or [[x, y, ">"…]], "rails": false}]`: their tiles stand `room_builder.gd` `DAIS_H` (0.3) over the floor, a step cut into a platform's edge (or on the floor beside it) becomes a ramp up, and a wooden railing runs round the edges that open onto the floor (`"rails": false` leaves a stage open towards its audience). A room with a `heights` grid builds the heights and ignores the platform (`map_loader.gd` prefers `heights`). `"rails": [[x, y, "n"|"e"|"s"|"w"]]` is a railing along that tile's edge on its own, for a stairwell's side, a high walk or a pool's edge; runs that meet join into one balustrade. A cave with a `heights` grid (or a platform, whose tiles become levels) is built by `well_cave.gd` (`room_builder.gd` `_cavern`), so its ramps get their leaning ladders and its platforms their rock cliffs rather than one flat slab. DunGen's Objects layer paints the platforms, their steps and the railings.
- A building whose floors go **down** (`"descends": true` in each of its rooms: the Dustwell church's undercroft, the cistern under Grubb's house in Scaraba, Gravenmoor's cathedral and crypt) reads its stairs the other way: a room's stairwell (`<<<`) leads on to the next room in the set, below, and arrives at the foot of that room's flight (`from_above`); the flight (`>>>`) climbs back up and arrives beside the stairwell it came down (`from_below`). Each stair needs a wall at one end, which is where it climbs to.
- Temple and vault rooms (`"ancient": true`, with `"blocks": true` for the template's own stone as dressed blocks) give their flights a solid stone parapet and their stairwells a low stone kerb instead of wooden rails; `"stone_stairs": true` does the same in any room (the whitewashed church nave). `"temple": true` lights a room as a temple's, dark and lit by its torches, without a `temple_` key (Valkoog's halls).
- `world.gd` `_take_stairs` walks you on up or down the treads (`_on_flight`) while the screen goes dark (`goto_map`'s `fade`, `STAIR_FADE`), and `_arrive_by_stairs` walks the last of them on the other floor.
- `tools/check_maps.gd` also checks the windows: none in a wall with a door to another room, and at least one wall with them in every stage room; and every flight's open end can be reached.
- Every dungeon of several floors (temples, the crypt, the undercroft, Gearheart Tower) uses the same three-tile flights and stairwells (`stair_flights`), never single stair tiles; the old one-tile stubs are only drawn for a room without it.
- `--scene=doorway` walks round the house at home: through its doors, at its stairs from every side, and past Mom. `--scene=dungeon-stairs` walks every dungeon's stairs both ways.

## Towns

Towns follow one plan: a main row of buildings with their backs to the tree line, a boulevard along their doors that the town's entrances lead straight onto, and a plaza with the statue in the middle. Shops sit around the plaza and houses at the ends. Big towns have a second row well to the south, behind deep back gardens (six rows behind two-storey shops).

**A town's own look:** `"style"` builds a town's buildings in a style of its own, whatever its biome's (Dustwell's `"frontier"`, `frontier_builder.gd`; Scaraba's `"adobe"`, `adobe_town.gd`).

- `building_looks` can set a building's `"paint"` (red, orange, yellow, pink, coral, gold, rose) and `"frontier"` (`"saloon"`, `"jail"`).
- Authored `street_props` may be the two-tile `wagon`, `water_trough` or `bench` (a two-seat bench in the shared wood, `voxel_props.gd` `bench()`; procedural benches also take the next front tile east, or become a planter where it isn't free), or Scaraba's `adobe_stall`, `adobe_jars` and `adobe_well`.
- `"town_wall": {"low_from": row}` builds a town wall on the map's `W` tiles (`adobe_town.gd`; low from that row south).
- `"palm_groves": [[x, y, w, d]]` grows palms on a desert town's tree tiles and low shrubs on its bush tiles there instead of boulders.
- `prop_clearance: [[x, y, width, depth], ...]` reserves walking lanes and door approaches from both authored and procedural street furniture; authored cargo is also checked for route connectivity.

The camera looks down from the south, so a roof, a tower or a tree hides whatever is just north of it. `python tools/town_check.py` traces the camera's line of sight to every walkable tile (with each building's real roof shape) and reports any tile where the path or the player would be hidden, plus any door, exit or person you can't reach.

### Bellerive

Bellerive keeps the plan in a French Quarter's form:

- Creole townhouses along Rue Royale.
- The Place d'Armes (an open flower garden round the statue) before the bell tower.
- A riverfront row of cottages and shops with walled courtyard gardens behind them (the camera has to see over them), and the promenade on the quay.
- Its catching ground is a fenced park between the town and the arena (`"meadow": {"rect": [...]}`: wild beasts live only in it, in its long grass), where Miss Odile feeds them candy corn; the arena's forecourt is fenced off from the river, so the way there is through the park.
- The waterfront has a continuous boardwalk at least two tiles deep, flush against the stone retaining wall, with stone stairs and matching side parapets starting south of the quay balustrade.
- Lamps sit within continuous wall sections, garden fences end in capped posts, and the eastern shoreline is fenced below the arena.
- Beside the arena the quay's wall drops to a narrow rocky beach at sea level that nothing leads down to (the map's `"rocky_beach": [[x, y, w, d]]`: sand strewn with beach rocks, scenery only, `world.gd` `_rocky_beaches`).
- Crates and open boxes sit against the retaining wall, leaving two clear dock rows and the stairs accessible.
- The steamboat pier runs straight south, two tiles wide, without a crosswise landing.
- Boat berths leave clearance from docks and one another, including paddle wheels and sail booms. The eastern dock ends at a second fishing shack standing over the water, with a Rope Collar, Cloth Band and Twine Anklet (starter beast gear, each giving a 5% stat bonus) to collect inside. Gil's original shack and fishing lesson sit at the west end, with his berth extended south to keep the boardwalk clear.

### Cocoon Cove

Cocoon Cove uses the supplied, repaired pirate-cove kit (`cove_buildings.gd`).

- Its levels are gentle: the sea and dock 0, the town 1, one terrace 2, and every ramp three tiles long; a rim of tall cliffs (level 6) closes the north, the west and the east above the road out.
- Home and the two scenery homes stand on the terrace, the library (the kit's two-storey `whole_house`, door in the middle) and Beast Center at the land square, and the apothecary to the east. The plaster neighbour's home stands in the western garden.
- Only the right-hand stairs reach the short dock, whose only buildings are wooden shacks: one neighbour (room `cove_dock_shack`) and the gear shack (`s`, room `shack`) at the far end. A path leads to every door, the scenery homes' included.
- Where the camera can't see anyone (the strips behind tall buildings), the ground is a `low_trees` thicket, never hedge-filled lawn: a hedge (`t`) is drawn only along its edges, so a thick one would look like lawn you can't walk on.
- Crates and barrels occupy spare edge tiles; `prop_clearance` rectangles reserve walking lanes, stairs and door approaches for both authored and procedural furniture. Its starter gear remains as `item:<id>` anchors.
- Standard full-size doors come from `HouseModels`; the library's awning covers only its door. Each kit house's ground storey is stretched until its doorway takes that 1.8-unit door (clearly taller than the hero), and the kit's own door slab is cut away so the door lies on the wall. All source exterior openings are sealed.
- Its `building_order` lists building origins in saved interior order; `building_looks` selects preferred house models and skins (or `cove_model` for the pirate kit), and `scenery_houses` places noninteractive buildings on solid woodland footprints. After changing its plots, run `tools/bake_cove_measurements.gd` before the Python checker.

## The Scaraba Desert's sections

The Scaraba Desert (`route5`) is not a single map. A layout director (`scripts/world/desert_layout.gd`) assembles it from short sections in `scripts/data/maps/desert_sections.gd`, which use the `route_maps.gd` format. One section stands at a time, still under the map id `route5`.

- **Seams.** Each section runs from a seam in its rear cliff (north) to its open front (south). Crossing a seam loads the next or the previous section behind a short fade (`desert_crossing.gd`). The world keeps the section just left, so stepping back one seam is quick.
- **The order.** The opening (from the Mesa Trail), two optional sections, the first join, Valkoog's approach, the second join, one or two more optional sections, and the oasis gate (into Scaraba). The save's seed picks the optional sections (`SKELETON`) and each join's lock face.
- **Tags.** Each section is tagged `fixed`, `optional`, `required` (a join) or `edge`.
- **Joins and the edge.** A join's `"ring": {"id", "center"}` puts a star lock round its centre (`star_locks.gd`): five points at `STAR_POINTS` and a tablet at `TABLET`, answered by touching the points in the order 1, 3, 5, 2, 4, 1 (flag `star_ring_<id>`). The face (stones, pillars, a duck pond that turns the centre's 3 × 3 tiles to water, or bells) is the seed's, saved in the layout's `locks`. Until then, walking on past the join in the direction you came leads into the **edge** section. At its far side the camera holds, the hero walks off alone, and after a fade they're back on the map they entered the desert from, with everything kept. A half-touched lock holds the walk-off.
- **Set pieces.** `"sights": [{"kind", "at"}]` places a section's set pieces (`desert_sights.gd`): the springs, the reed pool, the Singing Cactus (`singing_cactus.gd`), the shrine, the sleeping statues, the band's waystation, the conduit and Valkoog's landing stars. Keep their tiles open, off the road and reachable.
- **Valkoog's pyramid.** `"pyramid": {"rect": [x, y, w, h], "anchor": [x, y]}` dresses the terraces inside `rect` (`valkoog_pyramid.gd`), worked out from `heights`: sandstone blocks over every riser facing west, south or east, a pale coping along each landing, a stone stair with cheek walls over each north-climbing ramp, paved landings and forecourt, braziers at the stair's foot, banners and scarab carvings. It adds nothing walkable or blocking except its silent story object on `anchor`, a tile inside the temple's footprint that nobody can stand beside. Change the heights and the dressing follows. The summit building (`Q`, temple `air`) is the sanctuary from the same script, its doorway two tiles wide and centred on the stair.
- **Variants.** `"variants": [{"id", "flag", "tiles": {"x,y": char}, "sights"}]` swap tiles (and add set pieces) once a flag is set. A section takes its variant only when it is walked into, never while it is loaded. A variant must keep both seams and the way between them.
- **Flags.** Items, trainers and obstacles keep their flags per section (`route5_<section>`, the source's `"flag_id"`).
- **The save.** The layout (seed, list, variants, current section, direction and entry map) is in `flags.desert_layout`. A reload rebuilds the same section.

`check_maps.gd` checks every section in each of its variants. `--scene=desert-layout` (`tools/debug/desert_layout.gd`) checks the critical path over 50 seeds, every section in every variant and lock face, each face solved, the walk-off from each side, a flag set while a section is loaded, a save and reload mid-crossing, Valkoog's doors, and the set pieces. With `--desert_shots=res://build/...` (not headless) it takes a screenshot of each face and set piece instead.

## Riposo Valley

`route5b` is a single 30×54 route map, not a desert-style director. Its south mouth lines up with Scaraba's north gate (x14-15) and its north mouth with Copperpick's south road (x20-21), and its biome is `prairie` (green ground and prairie trees, with the desert's sand still used at the south mouth). A rock ridge (y25-31, level 2) crosses the valley with a two-tile pass; the crayon statues stand in it, with more on side branches. They are `weapon_obstacles` entries of `type: "crayon"` with their own `flag_name` (`crayon_statue_<n>`), `blocks` on their own tile, and a `use_from` tile in front; `tools/check_maps.gd` leaves them out of the 12-tile fixture spacing rule and the exit-blocking test, because they are a story lock (Volt's `crayon_eater`), not a weapon lock. The old drovers' cut (x16, y14-22) is a one-tile shortcut gully blocked by an earth boulder (`o`). `tools/cliff_corners.gd --write` has cut the ridge's square corners.

## Checking maps

**Nothing tall between a road and the camera:** `check_maps.gd` flags any tree or building up to three tiles south of a road, a bridge, the plaza or anyone standing about, further when it stands on higher ground (trees in a map's last three rows are drawn as shrubs, or low rocks in the desert, so they don't count). Use bushes, rocks, fences, water or tall grass there instead. On the Coastal Path everything south of the trail is low.

**No slipping past a teacher:** `check_maps.gd` also walks every way from each of a map's exits to the others and flags a teacher (`world_db.gd` LESSON_TRAINERS, ARENA_LESSONS) whose line of sight (straight ahead, 4 tiles, up to the first wall or person) it can get past without crossing, and indoors one who doesn't see the tile you come in on. Teachers notice you as you arrive on a map and after another teacher's lesson, not only when you step into their sight (`world.gd` `spot_you`).

After editing, run the map checkers (the Godot one also flags anyone indoors who faces a wall):

```sh
godot --headless --path . --script res://tools/check_maps.gd
python tools/town_check.py
```
