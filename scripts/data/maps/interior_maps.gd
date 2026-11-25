extends RefCounted
## Building interiors. Every building of a type uses its template, or its set of them (SHOP_ROOMS).
## Most are stage rooms ("stage"): one compact room each, seen whole like a stage set, open towards the camera, the way
## in through a side wall (D in it, P beside it). A building of several rooms has a door in a wall for each of the
## others ("doors": symbol -> the room it leads to), and each room is loaded on its own; going through, you come out
## at the door of the room you left. Stairs (> and <) lead to the next room up the set and back down; in a house the
## stairs always come up into a landing (half a room deep), with that floor's rooms through doors off it. A wall with a
## door to another room (one that opens or a locked one) has no windows, and every room has windows in at least one
## wall (the front door's may have them too); tools/check_maps.gd checks both. The big dungeons (the temples, the
## hideout, the towers, the cathedral and its crypt) keep their bigger layouts.
## Legend:
##   #  wall          w  wall with window   .  wooden floor   :  tiled floor   r  area-rug placement seed
## Area rugs are fitted nearby as 2x3, 3x4, 4x5 or 6x5 rectangles (either orientation), not stretched to the r run.
##   x  arena ring    C  counter            s  goods shelf    B  bookshelf     t  table
##   h  stool         p  potted plant       b  bed            q  fireplace     A  merge altar
##   G  trade board   M  storage terminal   o  pillar         e  exhibit       n  organ
##   =  bench         ~  fountain           Y  crystal ball   D  door mat (exit)
##   P  where you appear when entering      1-9 people (roles in "npcs")
##   >  stairs to the next floor   <  stairs back down/up   g  eerie mist (wild encounters)
##   %  lava   *  crystal shard   $  hidden item   H  healing machine   I  egg incubator
##   K  kennel pen (a beast waiting to be adopted)   @  a red telephone (calling Dad saves the game, see phone.gd)
## Temples (and Gravenmoor's crypt) keep their singing stones on anchors stone_0 .. stone_3 (one per flute button:
## left, right, A, B) and the tablet that sings the stones' order on "tablet" (Places.song_stone / song_tablet).
## A room of several levels has "heights" (elevation.gd), "level_h" and "top_level" (the digit that is floor level), and
## "water_levels" for its water, "stone_doors" for its engraved doors ("stone_panels" for the ones drawn as a flush
## panel in the wall, outlined in blue) and "puzzle" for its levers (tide_water.gd,
## tide_puzzles.gd; see the Temple of Tides).
## Rooms within a building (drawn by room_builder.gd):
##   d  doorway between rooms      L  locked door      Z  staff-only door (locked)
##   "locked": what you find at each locked door, in reading order (else just that it's locked)
##   furniture (see FURNITURE): k kitchen counter, i kitchen sink, v stove, f fridge, j pantry, T toilet, U bathtub,
##   u washbasin, W washing machine, S sofa, a armchair, V television, c chair, y coffee table,
##   N small one-tile drawers, QQ wide two-tile dresser (along its wall), E desk, F storage (a big chest of drawers over two tiles), m mop and bucket, l floor lamp, O and X plain floor (the
##   coat stand, retired 2026-11-15 as too thin, and the open boxes, removed 2026-11-16),
##   z bin, J bunk bed, & low book display, ^ hay bales, ( low cupboard, ) pouf, [ basket of blankets,
##   + a bedroll (a makeshift bed on the floor),
##   } the hero's standing mirror (against a back wall; looking in it changes clothes). TVs (V) belong on the implied fourth wall in stage rooms.
##   A run of the same letter is one piece (two b's are a bed, a block of four a double bed).
##   "zones": the kind of room each tile is in, one letter per tile like the rows (see room_builder.gd ZONES):
##   l living room, b bedroom, k kitchen, a bathroom, h hall, s shop floor, o back room, f office, g grand hall,
##   w wood panelling, t stone, d diner; any other letter (walls) takes "zone", the template's default.
## People: keeper (runs the shop), leader (arena leader), patron (chatty visitor),
##   resident (lives in the house), mom. The bottom row is the open front: no wall is drawn there.
## Staff (keepers, the Beast Center's guide, a barn's kennel keeper, the receptionist) always stand behind a counter,
## boxed in so you can only talk to them across it. Short wooden gates (|) close staff passages; plants are decoration.
## A gate has a counter at one end of it and a wall or another counter at the other, in line with it, best behind
## the counter's end with the back wall beyond it (RoomBuilder.gate_fit; the user's 2026-11-18 direction).

const FURNITURE := {
	"|": "counter_gate", "k": "counter", "i": "kitchen_sink", "v": "stove", "f": "fridge", "j": "pantry", "T": "toilet", "U": "bathtub",
	"u": "basin", "W": "washer", "S": "sofa", "a": "armchair", "V": "tv", "c": "chair", "y": "coffee_table",
	"N": "nightstand", "Q": "dresser", "E": "desk", "F": "storage", "m": "mop", "+": "bedroll",
	"&": "book_display", "l": "floor_lamp", "z": "trash", "J": "bunk", "@": "phone", "^": "hay",
	"(": "cabinet", ")": "pouf", "[": "basket", "}": "mirror",
}

const ROOMS := {
	## The Dustwell Well (docs/dustwell-water-arc.md), traced from the user's grid drawing of 22 November 2026, one
	## square a tile. Fifteen rooms joined by doorways (A.., "doors"). Each room steps down from its back wall to its open
	## front ("heights"): ladders are one-tile ramps (^), cracks are bottomless (" " on the "abyss" level), and rope
	## bridges (-) stay broken until their "bridges" flag is set. Grey cliff walls, except the cut-stone stretches with
	## straight walls and square niches ("masonry_cols"). Five beavers guard it (beaver_0..4, Story.WELL_BEAVERS), each the
	## "third strongest"; Dale hides at the far end with his bedroom and hot spring. Earth beasts roam everywhere but there.
	## The great chamber: four floors stepping down from the back wall to the front (1 at the back, where the rope ladder comes down from the town (D), to 4 at the front). Ladders (^ in "heights") join them; the one down to floor 4 lies fallen until Beaver Crumb's ladder replaces it. Bridge 2 (-) joins floor 3's two halves once mended with rope. Doors: the nook (A), Beaver Dibble's locked room (B, Beaver Nub's key), Beaver Crumb's room (C) and the long hall towards Dale (E).
	"well_main": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "level_h": 2.0, "top_level": 4,
		"tall_back": 3.2,
		"bridges": {"-": "well_bridge_2"},
		"locked_doors": {"B": "well_door_open"},
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_nook", "B": "well_bever3", "C": "well_bever4", "E": "well_hall"},
		"anchors": {"0": "chest:spirit_drop#10", "1": "chest:mega_potion#11", "2": "chest:revival_seed#12"},
		"anchor_tiles": {"fallen_ladder": Vector2i(23, 16)}, "ladder_flag": "well_ladder_set",
		"rows": [
			"####################################D############",
			"##################################/.P.\\##########",
			"################################/........\\#######",
			"#######################/..\\###/...........#######",
			"######################/...................#######",
			"########/...\\#######......................#######",
			"########.......\\####......................#######",
			"#######A.....................................\\###",
			"########......................................###",
			"########......................................B##",
			"#####/........................................###",
			"##/...........................................\\##",
			"##......................................0......##",
			"#C.......................  ....................##",
			"##.......................--....................##",
			"#/..........................................1..\\#",
			"#...............................................#",
			"#...............................................#",
			"#.2.............................................E",
			"#...............................................#",
			"#################################################",
		],
		"heights": [
			"4444444444444444444444444444444444444444444444444",
			"4444444444444444444444444444444444444444444444444",
			"4444444444444444444444444444444444444444444444444",
			"4444444444444444444444444444444444444444444444444",
			"4444444444444444444444444444444444444444444444444",
			"4444444433333444444444444444444444444444444444444",
			"4444444433333333444444444444444444444444444444444",
			"4444444333333333333333^33\\444444444/3\\444/3333444",
			"4444444433333333333333333333\\44/33333333333333444",
			"4444444433333333333333333333333333333333333333344",
			"44444222\\3333333333333333333333333333333333333444",
			"442222222222\\333/22\\33333333333333/^2\\/22\\333/144",
			"44222222222222222222222\\3333/22\\/2222222222111144",
			"422222222222222222222222211222222222222222/111144",
			"4422222222222222222222222222222222222222/11111144",
			"41\\2222222/11\\2/\\2222222/11\\222222222222111111114",
			"411\\2222/111111111\\22/1^11111111\\2/11\\2/111111114",
			"4111111111111111111111111111111111111111111111114",
			"4111111111111111111111111111111111111111111111111",
			"4111111111111111111111111111111111111111111111114",
			"4444444444444444444444444444444444444444444444444",
		],
	},
	## Beaver Pebble's chamber, far to the west: beating Pebble earns the planks for bridge 1.
	"well_bever1": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_cellar"},
		"anchors": {"0": "beaver_0", "1": "chest:potion#0"},
		"rows": [
			"##########################",
			"#################/.\\######",
			"########/..\\###/....######",
			"########............\\##/\\#",
			"#/.1.\\#/.................#",
			"#.......0................A",
			"#........................#",
			"##########################",
		],
	},
	## A cut-stone cellar between Pebble's chamber and the nook.
	"well_cellar": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "masonry_cols": [0, 20],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_bever1", "B": "well_nook"},
		"anchors": {"0": "chest:honey_cake#0"},
		"rows": [
			"#####################",
			"##.....#..0..#.....##",
			"#...................#",
			"A...................B",
			"#...................#",
			"#####################",
		],
	},
	## A small cut-stone nook off the great chamber's floor 2: west to the cellar, up to the long gallery.
	"well_nook": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "masonry_cols": [0, 8],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_cellar", "B": "well_long", "C": "well_main"},
		"rows": [
			"#########",
			"A...\\#B##",
			"#.......#",
			"#.......#",
			"#.......C",
			"#.......#",
			"#########",
		],
	},
	## The long gallery at the back of the well.
	"well_long": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_nook", "B": "well_crack"},
		"anchors": {"0": "chest:elixir#0"},
		"rows": [
			"####################################",
			"#####/\\#/..\\###############/\\#######",
			"#/............\\##/.\\#/...0........\\#",
			"#..................................#",
			"A..................................B",
			"#..................................#",
			"#..................................#",
			"####################################",
		],
	},
	## A deep crack runs from the back of this cave to its front; bridge 1 (-) crosses it once mended with Pebble's planks.
	"well_crack": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "level_h": 2.0, "top_level": 3, "abyss": true,
		"bridges": {"-": "well_bridge_1"},
		"arches": [[8, 9, 2]],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_long", "B": "well_bever2"},
		"anchors": {"0": "chest:spirit_drop#0"},
		"rows": [
			"#########################",
			"########/  ##############",
			"########  /##############",
			"#######/ /###############",
			"#######  ################",
			"#######  \\###############",
			"#######\\  ###############",
			"########  ###############",
			"########  ###############",
			"#######/  \\######/.0.\\###",
			"#/.....   ....\\/.......\\#",
			"#.......  ..............#",
			"A.......--..............B",
			"#.......  ..............#",
			"#.......  ..............#",
			"#########################",
		],
		"heights": [
			"3333333333333333333333333",
			"3333333330033333333333333",
			"3333333300333333333333333",
			"3333333303333333333333333",
			"3333333003333333333333333",
			"3333333003333333333333333",
			"3333333300333333333333333",
			"3333333300333333333333333",
			"3333333300333333333333333",
			"3333333300333333333333333",
			"3333333000333333333333333",
			"3333333\\00333333333333333",
			"3333333333333333333333333",
			"3333333300333333333333333",
			"3333333300\\33333333333333",
			"3333333333333333333333333",
		],
	},
	## Beaver Nub's cave: Nub waits on a raised shelf at the back, up a ladder, and has the key to Dibble's door.
	"well_bever2": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "level_h": 2.0, "top_level": 2,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_crack"},
		"anchors": {"0": "beaver_1", "1": "chest:scroll_ice#0"},
		"rows": [
			"######################",
			"##############/..1.\\##",
			"############/.......##",
			"############...0....\\#",
			"############.........#",
			"####/....\\##.........#",
			"#/...................#",
			"#....................#",
			"A....................#",
			"#....................#",
			"#....................#",
			"######################",
		],
		"heights": [
			"2222222222222222222222",
			"2222222222222222222222",
			"2222222222222222222222",
			"2222222222222222222222",
			"2222222222222222222222",
			"2222111111222222222222",
			"211111111111\\22222/112",
			"211111111111111^111112",
			"1111111111111111111112",
			"2111111111111111111112",
			"2111111111111111111112",
			"2222222222222222222222",
		],
	},
	## Beaver Dibble's locked chamber, off the great chamber's floor 2: beating Dibble earns the rope for bridges 2 and 3.
	"well_bever3": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_main"},
		"anchors": {"0": "beaver_2", "1": "chest:mega_potion#0"},
		"rows": [
			"################",
			"#/\\##/..\\#######",
			"#.........\\/..\\#",
			"#..............#",
			"A........0...1.#",
			"#..............#",
			"################",
		],
	},
	## Beaver Crumb's cave, off floor 3: bridge 3 (-) crosses its crack, and beating Crumb earns the ladder down to floor 4.
	"well_bever4": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "level_h": 2.0, "top_level": 3, "abyss": true,
		"bridges": {"-": "well_bridge_3"},
		"arches": [[17, 5, 2]],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_main"},
		"anchors": {"0": "beaver_3", "1": "chest:revival_seed#0"},
		"rows": [
			"##################################",
			"#################/ ###############",
			"################/ /###############",
			"################  ################",
			"################\\ \\###############",
			"##########/..\\###  ##/..\\#########",
			"###/.1\\#/........  .......\\#/...\\#",
			"#/...............  ..............#",
			"#.......0........--..............#",
			"#................  ..............A",
			"#................   .............#",
			"##################################",
		],
		"heights": [
			"3333333333333333333333333333333333",
			"3333333333333333330333333333333333",
			"3333333333333333303333333333333333",
			"3333333333333333003333333333333333",
			"3333333333333333303333333333333333",
			"3333333333333333300333333333333333",
			"3333333333333333300333333333333333",
			"3333333333333333300333333333333333",
			"3333333333333333333333333333333333",
			"3333333333333333300\\33333333333333",
			"3333333333333333/00033333333333333",
			"3333333333333333333333333333333333",
		],
	},
	## A cut-stone hall from floor 4 towards Beaver Velvet.
	"well_hall": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "masonry_cols": [0, 23],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_main", "B": "well_bever5"},
		"anchors": {"0": "chest:potion#0", "1": "chest:honey_cake#1"},
		"rows": [
			"########################",
			"##........#..0..#..1..##",
			"#......................#",
			"A......................B",
			"#......................#",
			"########################",
		],
	},
	## Beaver Velvet's cave, the last guard: cut stone at its west end, rock beyond. Its back door leads to Dale's hideaway.
	"well_bever5": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "masonry_cols": [0, 6],
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [15, 19], "roam": true},
		"doors": {"A": "well_hall", "B": "well_hub"},
		"anchors": {"0": "beaver_4", "1": "chest:mega_potion#0"},
		"rows": [
			"#################B######",
			"##############/....\\####",
			"#######/\\##/.........\\##",
			"##....#...1...........##",
			"#.....................##",
			"A.....0...............\\#",
			"#......................#",
			"########################",
		],
	},
	## Dale's hideaway: a cut-stone hall with his workroom (west), bedroom and pink hot spring (both up the back). No wild beasts here.
	"well_hub": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "masonry_cols": [0, 14],
		"doors": {"A": "well_dale", "B": "well_bedroom", "C": "well_spa", "E": "well_bever5"},
		"rows": [
			"####B#####C####",
			"##.....#.....##",
			"#.............#",
			"A.............E",
			"#.............#",
			"###############",
		],
	},
	## Dale's workroom: Dale on the east side of a crack, a chest with his old Wellspring Pendant across bridge 4 (-), which Dale lowers for you.
	## Its front is a cliff ("front_water": its face stands over the water, not left open like a crack's) down to a channel
	## the crack runs into. Below the chest a ledge leads onto a stone stairway ("stone_stairs": its ramp is steps, not a
	## ladder) running east along the cliff's foot, two tiles for its one level, to a step at the water, where Dale's
	## rowboat (well_boat) floats once the spring runs (Story._well_boat).
	"well_dale": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true, "level_h": 2.0, "top_level": 3, "abyss": true, "masonry_cols": [0, 13],
		"stone_stairs": true, "front_water": true, "pit_depth": 1.0,
		"bridges": {"-": "well_bridge_4"},
		"doors": {"A": "well_hub"},
		"anchors": {"0": "dale", "1": "chest:wellspring_pendant#0"},
		# (the boat floats on the channel, so its tile stays a gap: anchor_tiles, not an anchor letter)
		"anchor_tiles": {"well_boat": Vector2i(5, 7)},
		"rows": [
			"##############",
			"####..  ..####",
			"###...  ...###",
			"##....  .0..##",
			"#.....  .....#",
			"#1....--.....A",
			"#.....  .....#",
			"#....        #",
			"#            #",
		],
		"heights": [
			"33333333333333",
			"33333300333333",
			"33333300333333",
			"33333300333333",
			"33333300333333",
			"33333333333333",
			"33333300333333",
			"33<<2000000003",
			"30000000000003",
		],
	},
	## Dale's hot spring: the same pink healing spring as the hotel's, its sign on the back wall.
	"well_spa": {
		"wall": "#726777", "rug": "#887b72", "zone": "stone", "dark": true, "cavern": true, "well": true,
		"doors": {"A": "well_hub"},
		"fixtures": [[2, 2, "hot_tub"], [3, 2, "hot_tub"], [2, 3, "hot_tub"], [3, 3, "hot_tub"], [4, 0, "hot_tub_sign"]],
		"rows": [
			"#######",
			"#....\\#",
			"#.....#",
			"#.....A",
			"#.....#",
			"#######",
		],
	},
	## Dale's bedroom: his bed and books, and the red telephone he keeps for emergencies (calling Dad saves the game).
	"well_bedroom": {
		"wall": "#726777", "rug": "#6a5a8a", "zone": "stone", "dark": true, "well": true, "dungeon_walls": true,
		"doors": {"A": "well_hub"},
		"rows": [
			"#########",
			"##BB.bb##",
			"#E.....@#",
			"#c......A",
			"#...r...#",
			"#########",
		],
	},

	## The old church the elemental mages kept, the Jackals' now (docs/scaraba-implementation-plan.md WP8): a whitewashed
	## nave with the air mages' emblems (nowhere a cross), benches, a bronze ring on the back wall, the strongbox by the
	## door and the church well beside the altar steps. Hoss and Clem hold it with Grubb at the door (church_chapter.gd).
	"church_nave": {
		"wall": "#e6dcc6", "rug": "#8a5a3a", "zone": "hall", "wall_tex": {"hall": "wall_plaster"},
		"rows": [
			"################",
			"#..............#",
			"#..............#",
			"#.o..==...==.o.#",
			"#....==...==...#",
			"#.o..==...==.o.#",
			"#....==...==...#",
			"#.o..==...==.o.#",
			"#....>.........#",
			"#......r.......#",
			"#..............#",
			"DP..............#",
			"################",
		],
	},
	## The cave under the church well: the town well's shapes in a harder, colder palette (well_cave.gd), the Jackals'
	## sentries on the way to the trainers' room, and the five beavers, friendly now (church_chapter.gd).
	"church_cellar": {
		"wall": "#4e4658", "rug": "#3f3632", "zone": "stone", "dark": true, "cavern": true,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [20, 24], "roam": true},
		"anchors": {"0": "chest:revival_seed#0"},
		"rows": [
			"#..................#",
			"#.P................#",
			"#..................#",
			"#..................#",
			"#..................#",
			"#.........0........#",
			"#..................#",
			"#..................#",
			"#..<.............>.#",
			"#..................#",
			"#..................#",
		],
	},
	## The flooded gallery deeper in (the plan's "flooded gallery the player can already solve"): the town well's water
	## standing in the old workings, a stone walk between two long pools, and the walk straight through it.
	"church_gallery": {
		"wall": "#4e4658", "rug": "#3f3632", "zone": "stone", "dark": true, "floor_tex": {"hall": "floor_stone"},
		"pool_tint": "#203a42", "pool_curb": false, "pool_surface": -0.03,
		"encounter": {"races": [12, 15, 18, 21, 66], "lv": [20, 24], "roam": true},
		"anchors": {"0": "chest:mega_potion#0"},
		"rows": [
			"######################",
			"#________P...________#",
			"#________....________#",
			"#_______.....________#",
			"#________....._______#",
			"#______......._______#",
			"#_______...._________#",
			"#________....________#",
			"#______......________#",
			"#.<................>.#",
			"#................0...#",
			"######################",
		],
	},
	## The room before the trainers' door, where the beavers chew through (church_chapter.gd).
	"church_barred": {
		"wall": "#4e4658", "rug": "#3f3632", "zone": "stone", "dark": true, "cavern": true,
		"doors": {"B": "church_room"}, "locked_doors": {"B": "trainers_door"},
		"rows": [
			"#............#",
			"#..P.........#",
			"#............#",
			"#............#",
			"#............#",
			"#............B",
			"#............#",
			"#............#",
			"#.<..........#",
			"#............#",
		],
	},
	## Behind the door: the room the Jackals kept the missing trainers in (Lio, Bea, Orin and Sable's three juniors).
	"church_room": {
		"wall": "#5a4a3e", "rug": "#4a3a42", "zone": "stone", "dark": true,
		"doors": {"A": "church_barred"},
		"rows": [
			"#..............#",
			"#..P...........#",
			"#..............#",
			"#..............#",
			"#..............#",
			"#..............#",
			"#..............#",
			"#..............#",
			"#..............A",
			"#..............#",
			"#..............#",
		],
	},

	"collapsed_tunnel": {
		"cavern": true, "dark": true, "zone": "stone",
		"rows": ["#####", "#...#", "#...#", "DP..#", "#####"],
	},
	## Every Beast Center is the same little temple, one room you walk into from the side (12x9): walls of the same grey
	## stone blocks as its outside (beast_temple.gd), pilasters and flame sconces, a glowing inlay in the Center's red, and magic rather than machines. Each relic
	## has its own bay along the back wall: the nurse's stone counter with her warming cradle (1, I), the healing font
	## (H), the storage reliquary (M) and the merge altar (A); the red phone stands on the nurse's counter. Guide Dottie
	## (2) walks about the room, and two waiting chairs (c) stand by the left wall. (The kennel is not here: it has its
	## own barns out on the roads, "kennel_barn" below.)
	"center": {
		"wall": "#c2beb6", "rug": "#d8283a", "ancient": true, "blocks": true, "stage": true,
		"npcs": {"1": "keeper", "2": "guide", "3": "patron"},
		"counter_phone": [3, 2],
		"rows": [
			"####w###w###",
			"#1I#:H:M:A:#",
			"#CCCrrrrrrr#",
			"#::::::::::#",
			"#::::::::::#",
			"#::2:::3:::#",
			"#c:::::::::#",
			"#c::::::::PD",
			"############",
		],
	},
	## A kennel barn out on the roads (route_maps.gd "?", barn_builder.gd): timber walls and boards, hay bales (^) and
	## lanterns ("barn"), and the four pens (K) behind Kennel Keeper Pip's counter (1) with his stores beside them.
	## Each barn keeps its own pens (GameState.kennel, keyed by its road).
	"kennel_barn": {
		"wall": "#c08a58", "rug": "#a85a3a", "zone": "wood", "stage": true, "barn": true, "npcs": {"1": "kennel"},
		"rows": [
			"###w###w###",
			"#^KKKK^.FF#",
			"#...1.....#",
			"#CCCCCCCCC#",
			"#.........w",
			"#^........#",
			"#c.......PD",
			"###########",
		],
	},
	"apothecary": {
		"wall": "#d8e8d0", "rug": "#4a8a5a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. It's occupied."],
		"counter_phone": [6, 2],
		"rows": [
			"#####Z#####",
			"#.|BB1ss|.#",
			"#.CCCCCCC.w",
			"#.........w",
			"L..rr2rr..#",
			"#..rrrrr.PD",
			"###########",
		],
	},
	"outfitter": {
		"wall": "#e8d8c0", "rug": "#4a6a9a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The fitting room. Someone in there is trying on a very large hat."],
		"rows": [
			"#####Z#####",
			"#BB.s1s.ss#",
			"#CCCCCCCCCw",
			"#.........w",
			"#e.......e#",
			"L.....2..PD",
			"###########",
		],
	},
	"library": {
		"wall": "#c8b090", "rug": "#607a88", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"rows": [
			"###w####w####",
			"#BB..1..BB.B#",
			"#p.CCCCC...pw",
			"#...........w",
			"#ct2..rrr...#",
			"#.....rrr..PD",
			"#############",
		],
	},
	"bookstore": {
		"wall": "#c8b090", "rug": "#8a4a3a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The stockroom. Boxes of books are piled to the ceiling in there."],
		"rows": [
			"#####Z#####",
			"#.|BB1BB|.#",
			"#.CCCCCCC.w",
			"#.........w",
			"L.......&&#",
			"#t2..rr..PD",
			"###########",
		],
	},
	## Every arena is one big room, like the Beast Center (21x9: the camera follows you round it). You come in on the
	## right, into the lobby: the host (1) at her desk in the back corner (she runs the arena ladder, never the master's
	## challenge), a bench and the red phone on the host's counter. On the left, on its own marble floor, is the master's hall: the ring (x)
	## with benches round it and the arena master (3) waiting on its far side, two fans (4, 5) watching. A wall runs
	## forward from the back between the two and stops short of the front, so you walk round its end to reach the
	## master. In Bellerive the arena's two coaches (6, 7: world_db.gd ARENA_LESSONS) wait in the lobby: Rory above the
	## entrance looking down at it, Ondine along the row you come in on. Only Rory approaches; Ondine waits to be spoken
	## to. Elsewhere these are plain floor.
	"arena": {
		"wall": "#c8c0b0", "rug": "#b03a3a", "stage": true, "npcs": {"1": "keeper", "3": "leader", "4": "patron", "5": "patron"},
		"anchors": {"6": "lesson_team", "7": "lesson_elements"},
		"locked": ["The changing room. Someone in there is practising a victory speech."],
		"counter_phone": [15, 2],
		"rows": [
			"###w#####w#######w###",
			"#=::::3::::=#.1|.==.#",
			"#=:xxxxxxx:=#CCC....w",
			"#::x:::::x::#......6w",
			"L::x:::::x::#.......#",
			"#=:xxxxxxx:=#.......#",
			"#=4:::::::5:........#",
			"#:::::::::::...7...PD",
			"#####################",
		],
		"zones": [
			"#####################",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#ggggggggggg#########",
			"#####################",
		],
	},
	## The café: the counter at the back, tables out front; the kitchen is through the STAFF ONLY door.
	## (2026-11-15) Widened so a large platform fills the whole left corner (no counter behind it): one step up, railed along its open edges, its step
	## at the east side; two regulars sit on cushions at low tables there. Platforms are most at home in cafes.
	"cafe": {
		"wall": "#f0d8d0", "rug": "#c07040", "stage": true, "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"locked": ["The restroom. Somebody's humming in there."],
		"counter_phone": [8, 2],
		"dais": [{"rect": [1, 1, 4, 5], "steps": [[4, 5]]}],
		# (all its wood this one colour except the floor, the user's direction: room_builder.gd _one_wood)
		"wood": "#84522f",
		# (lots of art all over the walls, the user's direction: room_builder.gd _art_walls)
		"art_walls": true,
		"rows": [
			"######Z######",
			"#BBp..1...pp#",
			"#.2..CCCCCCCw",
			"#)y)........w",
			"#.3.........#",
			"#)y.....hyh.#",
			"L..........PD",
			"#############",
		],
	},
	## Dustwell's Oasis Saloon (a cafe: the barkeep sells the same snacks, Places.shop). Barkeep Dusty (1) is boxed in
	## behind the bar, and the locked card room (Z) is behind him. Off the bar: Rosa's office (?) through the back wall,
	## and the concert hall (A) through the left wall, with the band's storeroom beyond it (the user's 2026-11-22 and
	## 2026-11-24 layouts). The stairs at the right go up to the hotel landing. Tables fill the floor.
	"saloon": {
		"wall": "#c47a4e", "rug": "#8a2a2a", "stage": true, "zone": "wood", "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"doors": {"?": "saloon_office", "A": "saloon_stage"},
		"locked": ["The back room. Somebody in there is shuffling cards, very slowly, and humming."],
		"counter_phone": [11, 2],
		"rows": [
			"###?####Z##########",
			"#.....C..1.BBC.>>>#",
			"#.....CCCCCCCC....w",
			"#.................w",
			"A..hth....hth..hth#",
			"#.......2.....3...w",
			"#..hth....hth..hth#",
			"#................PD",
			"###################",
		],
	},
	## The concert hall (the user's 2026-11-24 layout): you come in from the bar through the right wall (A), and the band's
	## storeroom is through the left (!). The stage runs along the back wall, one step up at its right end, with the
	## band's instruments left on it and a little sound and light gear, all switched off, a speaker knocked over and the
	## lights set down on the floor ("stage_gear", concert_hall.gd). Rows of little tables, each with a tiny lamp (and drinks on some)
	## between two chairs that both face the stage ("seats_face"); two regulars (1, 2) sit waiting at theirs.
	"saloon_stage": {
		"wall": "#c47a4e", "rug": "#8a2a2a", "stage": true, "zone": "wood", "npcs": {"1": "patron", "2": "patron"},
		"doors": {"A": "saloon", "!": "saloon_back"},
		"dais": [{"rect": [1, 1, 13, 2], "steps": [[12, 2]], "rails": false}],
		"furniture_kinds": {"t": "concert_table"},
		"seats_face": [0, -1],
		"stage_gear": [
			{"piece": "speaker", "at": [1, 1], "yaw": 20},
			{"piece": "stage_lights", "at": [2, 2], "off": [0.5, 0.05], "yaw": 4, "blocks": [[2, 2], [3, 2]]},
			{"piece": "cello", "at": [3, 1], "off": [0, -0.15], "yaw": 10, "tilt": [-10, 6]},
			{"piece": "violin", "at": [4, 2], "yaw": 25, "tilt": [-90, 0]},
			{"piece": "acoustic_guitar", "at": [5, 1], "off": [0, -0.25], "yaw": -10, "tilt": [-14, 0]},
			{"piece": "drums", "at": [7, 1], "yaw": -60, "blocks": [[6, 1], [7, 1], [8, 1]]},
			{"piece": "tambourine", "at": [8, 1], "off": [0.42, 0.36], "yaw": 40, "tilt": [0, 8]},
			{"piece": "trumpet", "at": [9, 1], "yaw": 30},
			{"piece": "electric_guitar", "at": [10, 1], "off": [0, -0.25], "yaw": 8, "tilt": [-14, 0]},
			{"piece": "bar_lights", "at": [11, 1], "off": [0.5, -0.1], "yaw": -6, "blocks": [[11, 1], [12, 1]]},
			{"piece": "speaker", "at": [13, 1], "off": [0, 0.5], "yaw": -10, "tilt": [90, 0], "blocks": [[13, 1], [13, 2]]},
		],
		"rows": [
			"###w###w###w###",
			"#:::::::::::::#",
			"#:::::::::::::#",
			"#.............#",
			"#.ctc.1tc.ctc.#",
			"!.............A",
			"#.ctc.ctc.ct2.#",
			"#.............#",
			"###############",
		],
	},
	## Rosa's office, through the bar's back wall: Rosa sits at her desk (anchor rosa) with her takings stacked on it
	## in gold coins (the "cash_desk", the user's 2026-11-22 exception to no coin props), books and drawers behind her.
	## You talk to her across the desk.
	"saloon_office": {
		"wall": "#a8503a", "rug": "#6a1a22", "stage": true, "zone": "office", "doors": {"?": "saloon"},
		"furniture_kinds": {"E": "cash_desk"},
		"anchors": {"1": "rosa"},
		"rows": [
			"####w####",
			"#BB.1.FF#",
			"#p.EEE.l#",
			"?.......#",
			"#.......#",
			"#########",
		],
	},
	## The saloon's hotel landing, half a room deep: the stairs come up at the right, two dancers' rooms open off the
	## back wall and the third room is locked.
	"saloon_hall": {
		"wall": "#c47a4e", "rug": "#8a2a2a", "stage": true, "zone": "hall", "doors": {"!": "saloon_room_a", "?": "saloon_room_b"},
		"locked": ["Room 3. A card on the knob says DO NOT DISTURB. Someone inside is practising high kicks, loudly."],
		"rows": [
			"###!#####?####L####",
			"w..............<<<#",
			"w...............P.#",
			"###################",
		],
	},
	## Hotel room 1: a can-can dancer (anchor dancer_0) by her dresser.
	"saloon_room_a": {
		"wall": "#d8a2a0", "rug": "#8a2a4a", "stage": true, "zone": "bedroom", "doors": {"!": "saloon_hall"},
		"anchors": {"1": "dancer_0"},
		"rows": [
			"#####w##w##",
			"#NbbN.....#",
			"#Qbb..)...#",
			"#Q....1...!",
			"#l..rrr...#",
			"###########",
		],
	},
	## Hotel room 2: another dancer (anchor dancer_1), the room mirrored.
	"saloon_room_b": {
		"wall": "#d8a2a0", "rug": "#6a2a6a", "stage": true, "zone": "bedroom", "doors": {"?": "saloon_hall"},
		"anchors": {"1": "dancer_1"},
		"rows": [
			"##w##w#####",
			"#.....NbbN#",
			"#...)..bbQ#",
			"?...1....Q#",
			"#...rrr..l#",
			"###########",
		],
	},
	## The band's storeroom, off the concert hall's left wall (the user's 2026-11-24 layout): a bank of steel lockers (F)
	## and shelves of tins and boxes ("goods": "pantry") along the back, and the four cots the Rubywave Five sleep on
	## (there are four of them; that's the joke). Until they're freed the four wander about the room (anchors
	## band_0..3, Story.extra_npcs).
	"saloon_back": {
		"wall": "#a8704a", "rug": "#5a3a2a", "stage": true, "zone": "back", "doors": {"!": "saloon_stage"},
		"anchors": {"1": "band_0", "2": "band_1", "3": "band_2", "4": "band_3"},
		"furniture_kinds": {"F": "lockers", "b": "cot"},
		"furniture_yaws": {Vector2i(1, 4): 0.0, Vector2i(3, 4): 0.0, Vector2i(5, 4): 0.0, Vector2i(7, 4): 0.0},
		"goods": "pantry",
		"rows": [
			"#####ww######",
			"#FFFF..ss.ss#",
			"#..1.....2..#",
			"#...........#",
			"#b.b.b.b.3..!",
			"#b.b.b.b....#",
			"#....4....z.#",
			"#############",
		],
	},
	## Dustwell Jail: Deputy Rusk (1) behind the front desk, the two cells' doors shut behind him (they're empty, and
	## staff only).
	"jail": {
		"wall": "#e2c48a", "rug": "#7a3a2a", "stage": true, "zone": "back", "npcs": {"1": "deputy"},
		"rows": [
			"###Z###Z###",
			"#FF..1...O#",
			"#CCCCCCCCCw",
			"#.........w",
			"#ht.......#",
			"#ht......PD",
			"###########",
		],
	},
	## The dojo: a mat floor, the sensei (1) behind his desk; the locker room is locked.
	"dojo": {
		"wall": "#e0d0b0", "rug": "#c8b070", "stage": true, "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"locked": ["The locker room. It smells of old socks and victory."],
		"rows": [
			"###w###w###",
			"#o..C1C..o#",
			"#rrrCCCrrr#",
			"#rrrrrrrrr#",
			"#rr2rrr3rr#",
			"L........PD",
			"###########",
		],
	},
	## The museum: exhibits round the hall, the curator (1) at her desk; her office is staff only.
	"museum": {
		"wall": "#d0d8e0", "rug": "#3a5a8a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. A sign reads: PLEASE DO NOT FEED THE EXHIBITS."],
		"rows": [
			"######Z######",
			"#e.eoe.eoe.e#",
			"#:::::::::::w",
			"#|C:::::::::w",
			"#1C::::2::::#",
			"#|C::e:::e:PD",
			"L:::::::::::#",
			"#############",
		],
	},
	## The music hall: the stage and organ, rows of benches; backstage is staff only.
	"music_hall": {
		"wall": "#c0c8e8", "rug": "#8a2a3a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. There's a queue of one."],
		"rows": [
			"##Z##########",
			"#rrrrnnnrrrr#",
			"#rrrrC1Crrrrw",
			"#rrrrCCCrrrrw",
			"#:===:===:::#",
			"#:::::::::2:#",
			"L:===:===::PD",
			"#############",
		],
	},
	## Dustwell's dance studio: Lucille (1) drills three students (2-4) in the can-can, all facing the back wall, which
	## is one floor-to-ceiling mirror reflecting the room ("mirror_wall", room_builder.gd). Benches along the side.
	"dance_studio": {
		"wall": "#dfbd8d", "stage": true, "mirror_wall": true,
		"anchors": {"1": "dance_instructor", "2": "dance_student_0", "3": "dance_student_1", "4": "dance_student_2"},
		"rows": [
			"#############",
			"#p.........p#",
			"#...2.3.4...w",
			"#==.........w",
			"#.....1.....#",
			"#...........#",
			"#...........#",
			"#..........PD",
			"#############",
		],
	},
	"music_shop": {
		"wall": "#d8c8a8", "rug": "#2a5a8a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The practice room. Someone in there is playing the same three notes over and over."],
		"counter_phone": [6, 2],
		"rows": [
			"#####Z#####",
			"#nB.B1B.BB#",
			"#CCCCCCCCCw",
			"#.........w",
			"#....2....#",
			"L.==.....PD",
			"###########",
		],
	},
	## A fortune teller's parlour ("parlour", room_builder.gd _parlour_decor; the user's 2026-11-16 direction): dim and
	## candlelit, the curtains drawn, cloth swagged along the walls, one rug and its floor full of poufs, baskets and books; one crystal ball on a
	## square wooden table (Y) between the seer and her visitor.
	"fortune": {
		"wall": "#4e3a5e", "rug": "#6a2a5a", "trim": "#2e1c34", "stage": true, "parlour": true, "npcs": {"1": "keeper"},
		# (its poufs' cloths in reading order: red at the far end of the left book table, indigo, green at the book table's near end, mustard)
		"pouf_cloths": [0, 1, 3, 2],
		# (its one rug, centred across the room under the crystal table: the user's 2026-11-16 direction)
		"rug_rects": [[2, 2, 5, 4]],
		"rows": [
			"###w#w###",
			"#([p1p&(#",
			"#)..Y..)#",
			"#&rrrrr.#",
			"#)rrrrr.#",
			"#[.)...PD",
			"#########",
		],
	},
	## A townsperson's studio: the bed and the living room in one room (the bed's corner carpeted), the bathroom locked.
	"studio_a": {
		"wall": "#e8d8b8", "rug": "#7a4a8a", "stage": true, "npcs": {"1": "resident", "2": "resident"},
		"locked": ["The bathroom. Someone's in there, singing."],
		"rows": [
			"#######L#####",
			"#NbbN.B.SS.@#",
			"w.bb........#",
			"#Q......yy.a#",
			"wQrrr..1....#",
			"#[.......2.PD",
			"#############",
		],
		"zones": [
			"#############",
			"#bbbblllllll#",
			"#bbbblllllll#",
			"#bbbblllllll#",
			"#bbbblllllll#",
			"#bbbblllllll#",
			"#############",
		],
	},
	## Another studio: a single bed in the corner, a table, and the kitchen locked.
	"studio_b": {
		"wall": "#d8e0c8", "rug": "#4a6a8a", "stage": true, "npcs": {"1": "resident"},
		"locked": ["The kitchen. Something's simmering on the stove in there."],
		"rows": [
			"######L####",
			"#Nb.BB...p#",
			"w.b.......#",
			"w....ctc..#",
			"#a.1......#",
			"#p.......PD",
			"###########",
		],
		"zones": [
			"###########",
			"#bblllllll#",
			"#bblllllll#",
			"#bblllllll#",
			"#bblllllll#",
			"#bblllllll#",
			"###########",
		],
	},
	## A house of two rooms: the living room, and the bedroom through the door at the back.
	"house_two": {
		"wall": "#e0d0b8", "rug": "#8a5a3a", "stage": true, "npcs": {"1": "resident", "2": "resident"},
		"fireplace_style": "limestone", "fireplace_stone": "#d7c9a6",
		"doors": {"!": "house_two_bed"}, "locked": ["The kitchen. It smells like toast."],
		"rows": [
			"######!###L##",
			"#BB.SS..qq.@#",
			"w...........#",
			"wa..yy......#",
			"#...rrrr..1.#",
			"#p......2..PD",
			"#############",
		],
	},
	"house_two_bed": {
		"wall": "#e0d0b8", "rug": "#8a5a3a", "stage": true, "zone": "bedroom", "doors": {"!": "house_two"},
		"rows": [
			"###w###w###",
			"#...NbbN..#",
			"#....bb..Q#",
			"!........Q#",
			"#...rrr..p#",
			"###########",
		],
	},
	## A house with an upstairs: the living room, and stairs up to the landing, which leads to the bedroom.
	"house_up": {
		"wall": "#e8e0d0", "rug": "#3a7a6a", "stage": true, "npcs": {"1": "resident", "2": "resident"},
		"locked": ["The kitchen. Someone's left the radio on in there."],
		"rows": [
			"#######L#####",
			"#BB.SS...>>>#",
			"w...........#",
			"wa..yy.....@#",
			"#.....rrr...#",
			"#p...1...2.PD",
			"#############",
		],
	},
	## Its landing, half a room deep: the stairs come up at the right end, the bedroom's door is in the back wall and
	## the bathroom (locked) at the left end.
	"house_up_hall": {
		"wall": "#e8e0d0", "rug": "#3a7a6a", "stage": true, "zone": "hall", "doors": {"!": "house_up_bed"},
		"locked": ["The bathroom. Someone's having a very long bath."],
		"rows": [
			"####!###L####",
			"w.p...B..<<<#",
			"w..........P#",
			"#############",
		],
	},
	"house_up_bed": {
		"wall": "#e8e0d0", "rug": "#3a7a6a", "stage": true, "zone": "bedroom", "doors": {"!": "house_up_hall"},
		"rows": [
			"#####w##w##",
			"#NbbN.....#",
			"#Qbb......#",
			"#Q........!",
			"#l..rrr...#",
			"###########",
		],
	},
	## Fisher Gil's shack on the Bellerive docks: nets, crates, and his spare fishing pole (1) leaning by the back wall.
	"fishery": {
		"wall": "#8a6a52", "rug": "#3a5a7a", "zone": "wood", "stage": true, "anchors": {"1": "rod"},
		"rows": [
			"####w####",
			"#.FF..1.#",
			"#.......#",
			"#th.....#",
			"#......PD",
			"#########",
		],
	},
	## Spare beast equipment in the shack at the eastern end of Bellerive's promenade.
	"harbour_shack": {
		"wall": "#8a6a52", "rug": "#3a5a7a", "zone": "wood", "stage": true,
		"anchors": {"1": "item:rope_collar", "2": "item:cloth_band", "3": "item:twine_anklet"},
		"rows": [
			"####w####",
			"#.FF....#",
			"#.1.2.3.#",
			"#th.....#",
			"#......PD",
			"#########",
		],
	},
	## Inspector Grubb's house in Scaraba (sundown building 6, locked until you've met him: scaraba_town.gd): one room
	## with a bed, and the stairs at the back down to the old cistern (twins_cistern; drawn as a flight up for now).
	"twins_house": {
		"wall": "#e0c8a0", "rug": "#a8503a", "stage": true, "zone": "bedroom",
		"rows": [
			"#####w###w###",
			"#bb.N(...>>>#",
			"w...........#",
			"#Q..rrr.....#",
			"#Q.........PD",
			"#############",
		],
	},
	## The old cistern under Grubb's house, where Tam (6) and Saffi (7) hide on two bedrolls with a basket of blankets.
	"twins_cistern": {
		"wall": "#b8a080", "rug": "#6a8aa0", "zone": "stone", "anchors": {"6": "tam", "7": "saffi"},
		"rows": [
			"###########",
			"#+.+..[<<<#",
			"#........P#",
			"#..6..7...#",
			"#(...rr...#",
			"###########",
		],
	},
	## Uncle Rafe's house in Bellerive, by the west gate: one room, where he waits (1) with your father's flute.
	"uncle_home": {
		"wall": "#e0d0b0", "rug": "#4a6a9a", "stage": true, "anchors": {"1": "uncle"},
		"locked": ["Rafe's kitchen. It smells of brass polish."],
		"rows": [
			"#######L#####",
			"#NbN.BB.SS.@#",
			"w.b.........#",
			"#Q.....1yy.a#",
			"wQrrr.......#",
			"#[.........PD",
			"#############",
		],
	},
	## Your home: the living room downstairs, where Mom (1) is, and the red phone; stairs up to your bedroom. The kitchen
	## is locked. The phone stands against the staircase wall; the first time you go to leave, it rings.
	## (2026-11-15) The sofa and armchair stand out in the room facing the open front (the TV is on the fourth wall),
	## the coffee table before them past an open row; a closet is built into the back wall, and only low things stand
	## where you can walk behind them.
	"home": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "npcs": {"1": "mom"}, "scheme": "apricot_sunroom",
		"furniture_offsets": {Vector2i(11, 2): Vector2(0, -0.28)}, "closets": [[1, 0, 2]],
		"locked": ["The kitchen. A faint smell of biscuits lingers by the door."],
		"rows": [
			"#######L#####",
			"#..l.BB..>>>#",
			"w..aSSS....@#",
			"w...rrr.....#",
			"#...yyy.1...#",
			"#p.(.......PD",
			"#############",
		],
	},
	## Upstairs at home: the landing, a hallway half a room deep. The stairs come up at its right end; your bedroom is
	## through the door at its left end, Mom's room and the bathroom (locked) off its back wall.
	"home_hall": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "hall", "scheme": "oat_olive",
		"doors": {"!": "home_bed", "?": "home_mom"}, "locked": ["The bathroom. The tap's dripping again."],
		"rows": [
			"##!#L##?#####",
			"wp...l...<<<#",
			"w..........P#",
			"#############",
		],
	},
	## Your bedroom, where you wake up (wake). Your bed is the one in this room.
	## (2026-11-15) The rocket print over the bed, the desk under the window with its chair beside it, a closet in the
	## back wall where the wardrobe was, and only low things at the front.
	## (2026-11-17) The standing mirror from the character creator (}) in the nook between the nightstand and the desk,
	## off the way from the bed to the door: look in it to change clothes.
	"home_bed": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "bedroom", "wake": [3, 2], "doors": {"!": "home_hall"},
		"scheme": "mint_cherry", "closets": [[8, 0, 2]],
		"rows": [
			"#####w#####",
			"#NbN}Ec...#",
			"#.b.......#",
			"#Q........!",
			"#Q..rrr)..#",
			"#p......([#",
			"###########",
		],
	},
	## Mom's room: her double bed between two nightstands.
	## (2026-11-15) A closet in the back wall where the wardrobe was; her armchair against the side wall facing in.
	"home_mom": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "bedroom", "doors": {"!": "home_hall"},
		"scheme": "rose_moss", "closets": [[8, 0, 2]],
		"rows": [
			"###w#######",
			"#pQQNbbN..#",
			"#....bb...#",
			"!........a#",
			"#..rrrr...#",
			"#[......)(#",
			"###########",
		],
	},
	"electronics": {
		"wall": "#d8dce4", "rug": "#3a6ab0", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. A note on the door: OUT OF ORDER (WE ARE FIXING IT. WE FIX THINGS)."],
		"rows": [
			"#####Z#####",
			"#ss.s1s.BB#",
			"#CCCCCCCCCw",
			"#.........w",
			"#e...r...e#",
			"L....r.2.PD",
			"###########",
		],
	},
	## The Sky Tower: Skykeeper Aria's ticket desk and the stairs in the lobby, and up top an open-air platform
	## ("open": railings instead of walls, sky all round) where the Tempestrix waits to fly you away.
	"skytower": {
		"wall": "#e4ecf4", "rug": "#3a7ac8", "stair_flights": true,
		"npcs": {"1": "keeper"},
		"rows": [
			"####Z######",
			"#.1....>>>#",
			"#CCC......#",
			"wp........w",
			"#=...r...=#",
			"#=..rrr..=#",
			"#p..rrr..PD",
			"###########",
		],
	},
	"skytower_top": {
		"wall": "#c8b088", "rug": "#3a7ac8", "open": true, "stair_flights": true,
		"npcs": {"1": "thunderhawk"},
		"rows": [
			"###########",
			"#p.....<<<#",
			"#....1...P#",
			"#.........#",
			"#.........#",
			"#.........#",
			"#......==.#",
			"###########",
		],
	},
	# The Temple of Tides (WorldDB.TEMPLES "water"), one long descent. The hall has a walkway along its back wall, stepping
	# down to the east in three levels ("heights": the entrance level is y = 0), with a flooded pit in front of it. Solving
	# the falls room (door 2) lowers the water a level, opening the middle walkway and the maze room's door (3); solving
	# the maze drains the hall and shows the stone door (4), in its east wall, to the song room. There the stones teach the temple's song,
	# which opens the door (K) to the guardian's octagon. The puzzles' rules: scripts/data/tide_puzzles.gd.
	# Down on the drained floor, back by the west wall near the front, a smooth stone panel (Q, flush in the wall: the
	# water_panel target, Story.WATER_TARGETS) opens to Water into the mages' sanctuary (5), with a chest (9) a few tiles off.
	"temple_tides_hall": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"2": "temple_tides_falls", "3": "temple_tides_maze", "4": "temple_tides_song", "5": "temple_tides_sanctuary"},
		"stone_doors": ["4", "Q"], "stone_panels": ["Q"], "level_h": 0.8, "top_level": 2,
		"water_levels": [["tides_falls_solved", -0.12], ["tides_maze_solved", -0.92]],
		"floods": {";": {"flag": "tides_falls_solved", "wet": "_", "dry": ":"}, "+": {"flag": "tides_maze_solved", "wet": "_", "dry": ":"},
			"Q": {"flag": "water_mages_found", "wet": "L", "dry": "5"}},
		"locked": ["A smooth stone panel set into the wall, carved with waves."],
		"anchor_tiles": {"water_panel": Vector2i(0, 10)},
		"anchors": {"9": "chest:tidal_tiara@tides_maze_solved"},
		"rows": [
			"######2##########3#############",
			"#:::::::::::;;;;;;;;;+++++++++#",
			"DP::::::::::;;;;;;;;;+++++++++4",
			"#:::::::::::;;;;;;;;;+++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"Q+++9+++++++++++++++++++++++++#",
			"#+++++++++++++++++++++++++++++#",
			"###############################",
		],
		"heights": [
			"0000002000000000010000000000000",
			"022222222222<<1111111<<00000000",
			"222222222222<<1111111<<00000000",
			"022222222222<<1111111<<00000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
			"0000000000000000000000000000000",
		],
	},
	# One path, along the back wall. Three waterfalls run down that wall into their sunken basins (_), open to the pool at
	# the front of the room where a stretch of the path (a .. c) has sunk under the water while its fall runs (it rises
	# again when the fall stops: tide_water.gd), with four levers against the wall between them. The treasure lies on the
	# pool's floor, and two flights of steps lead down to it once it's drained.
	"temple_tides_sanctuary": {
		"wall": "#648da3", "rug": "#247082", "zone": "stone",
		"doors": {"[": "temple_tides_hall"},
		"anchors": {"1": "water_teacher", "2": "water_acolyte"},
		"rows": [
			"#############",
			"#o::_____::o#",
			"#:::_____:::#",
			"#::2::1:::::#",
			"#:::::::::::[",
			"#o:::::::::o#",
			"#############",
		],
	},
	"temple_tides_falls": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_hall"},
		"level_h": 0.8, "top_level": 1,
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"water_levels": [["tides_falls_solved", -0.12]], "puzzle": "falls",
		"floods": {"+": {"flag": "tides_falls_solved", "wet": "_", "dry": ":"}},
		"anchors": {"5": "switch:0", "6": "switch:1", "7": "switch:2", "8": "switch:3", "9": "chest:tide_pendant@tides_falls_solved", "4": "tide_tablet"},
		"rows": [
			"#################",
			"#:8___7___6___54#",
			"#:::c:::b:::a:::[",
			"#+++++++++++++++#",
			"#+++++++++++++++#",
			"#+++++++++++++++#",
			"#+++++++++++++++#",
			"#+++++++9+++++++#",
			"#+++++++++++++++#",
			"#################",
		],
		"heights": [
			"11111111111111111",
			"11111111111111111",
			"11111111111111111",
			"100000^000^000001",
			"10000000000000001",
			"10000000000000001",
			"10000000000000001",
			"00000000000000001",
			"10000000000000001",
			"00000000000000000",
		],
	},
	# A maze of walkways over a pool, with metal lattices in them: three waterfalls drop from the pipes overhead through the
	# lattices (a .. h) and block them. Four levers move the falls; all down reveal a fifth in a back-wall cubby
	# (TidePuzzles.CUBBY_TILE), and pulling it drains the pool and opens a second cubby (CHEST_CUBBY_TILE) with the
	# treasure, the room's only one. (Its "#1" keeps the save flag it had when it lay on the pool's floor, after a chest
	# that stood at the walkway's east end.)
	"temple_tides_maze": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_hall"},
		"level_h": 0.8, "top_level": 1,
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"water_levels": [["tides_maze_solved", -0.12]], "puzzle": "maze",
		"floods": {"+": {"flag": "tides_maze_solved", "wet": "_", "dry": ":"}},
		"anchors": {"5": "switch:0", "6": "switch:1", "7": "switch:2", "8": "switch:3", "4": "switch:4", "2": "chest:tide_charm@tides_maze_solved#1"},
		"rows": [
			"#####################",
			"#+++++2+++7+++4+++++#",
			"#+::::::::::::::::::#",
			"#+:+++++++:+++++++:+#",
			"#+a+++++++d+++++++e+#",
			"#+:+++++++:+++++++:+#",
			"[::::::6+5::h::::::+#",
			"#+:+++++++:+++++++:+#",
			"#+b+++++++c+++++++:+#",
			"#+:+++++++:+++++++:+#",
			"#+::::::f:::::::g::+#",
			"#+++++8+++++++++++++#",
			"#####################",
		],
		"heights": [
			"111111111111111111111",
			"100000100010001000001",
			"101111111111111111111",
			"101000000010000000101",
			"101000000010000000101",
			"101000000010000000101",
			"111111110111111111101",
			"101000000010000000101",
			"101000000010000000101",
			"101000000010000000101",
			"101111111111111111101",
			"100000100000000000001",
			"111111111111111111111",
		],
	},
	# The song room: the singing stones and their tablet. Learning the song opens the stone door (K) to the guardian.
	"temple_tides_song": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_hall", "2": "temple_water"},
		"stone_doors": ["K"],
		"floods": {"K": {"flag": "tides_song_door", "wet": "L", "dry": "2"}},
		"locked": ["A great stone door, engraved with waves and framed in sea-blue stone. It won't budge. Something in this room must wake it."],
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"######K######",
			"#:::::::::::#",
			"#:::::::::::#",
			"#::3:4:5:6::#",
			"#:::::::::::#",
			"#::7::::::::#",
			"[:::::::::::#",
			"#:::::::::::#",
			"#############",
		],
	},
	# The guardian's chamber: a round room, its raised platform almost filling it over a dark pit, water pouring down
	# the walls all round into the pit (round_chamber.gd). A bridge crosses from the door, and a lane between the
	# hoard's heaps and lines of candles leads straight to the dragon's nest on its round dais in the middle.
	"temple_water": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"round": {"centre": Vector2i(9, 9), "platform": 7.0, "wall": 9.0, "dais": [2.35, 2.0, 1.65],
			"candles": [[Vector2(3.0, 7.92), Vector2(6.75, 7.92)], [Vector2(3.0, 11.08), Vector2(6.75, 11.08)]]},
		# the dragon's hoard round its nest (dragon_hoard.gd): gold and treasures heaped on these tiles
		"hoard": [Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(3, 11), Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(14, 9), Vector2i(12, 10), Vector2i(13, 12), Vector2i(11, 12), Vector2i(11, 14), Vector2i(10, 13), Vector2i(8, 14), Vector2i(8, 12), Vector2i(6, 13), Vector2i(6, 5), Vector2i(8, 6), Vector2i(8, 4), Vector2i(10, 5), Vector2i(11, 4), Vector2i(11, 6), Vector2i(13, 6), Vector2i(12, 8)],
		"npcs": {"1": "guardian"},
		"doors": {"[": "temple_tides_song"},
		"rows": [
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"   ....            ",
			"[......  1         ",
			"   ....            ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
			"                   ",
		],
	},
	# Valkoog (WorldDB.TEMPLES "air", docs/scaraba-implementation-plan.md WP6): four floors of air-keyed traps climb to
	# the keepers' chamber, and its wind-cut seam opens on the summit, in the old one-room temple. Every floor's star
	# stands on anchors air_1 .. air_5 round its trap (air_trap, a blocking gust), with the twins on twin_tam /
	# twin_saffi; the keepers' chamber has the singing stones and the star of them all. air_temple.gd keeps the rules.
	"valkoog_1": {
		"wall": "#e8dcc0", "rug": "#4ab8a0",
		"anchors": {"1": "air_1", "2": "air_2", "3": "air_3", "4": "air_4", "5": "air_5", "6": "air_trap",
			";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"#################",
			"#.......>.......#",
			"#......o6o......#",
			"#......o.o......#",
			"#.......1.......#",
			"#..5.........2..#",
			"#...............#",
			"#..4.........3..#",
			"#.;...........,.#",
			"DP..............#",
			"#################",
		],
	},
	"valkoog_2": {
		"wall": "#e0d4b8", "rug": "#3f9a8a",
		"anchors": {"1": "air_1", "2": "air_2", "3": "air_3", "4": "air_4", "5": "air_5", "6": "air_trap",
			";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"#################",
			"#.......>.......#",
			"#......o6o......#",
			"#......o.o......#",
			"#..o...1...o.o..#",
			"#..5.........2..#",
			"#...............#",
			"#..4.........3..#",
			"#.;...........,.#",
			"#P<.............#",
			"#################",
		],
	},
	"valkoog_3": {
		"wall": "#d8c8a8", "rug": "#4a8a8a",
		"anchors": {"1": "air_1", "2": "air_2", "3": "air_3", "4": "air_4", "5": "air_5", "6": "air_trap",
			";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"#################",
			"#.......>.......#",
			"#......o6o......#",
			"#......o.o......#",
			"#..o...1...o.o..#",
			"#..5.........2..#",
			"#......ooo......#",
			"#..4.........3..#",
			"#.;...........,.#",
			"#P<.............#",
			"#################",
		],
	},
	"valkoog_4": {
		"wall": "#e8dcc0", "rug": "#3f8f7a", "zone": "stone",
		"anchors": {"1": "air_1", "2": "air_2", "3": "air_3", "4": "air_4", "5": "air_5", "6": "air_trap",
			";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"#################",
			"#.......>.......#",
			"#......o6o......#",
			"#......o.o......#",
			"#..o...1...o.o..#",
			"#..5.........2..#",
			"#..o.........o..#",
			"#..4.........3..#",
			"#.;...........,.#",
			"#P<.............#",
			"#################",
		],
	},
	# The keepers' chamber: the five stand at the star's points round a star cut in the floor, the singing stones and
	# their tablet against the back wall, and the wind-cut seam (K) opens on the summit once the song is learned.
	"valkoog_keepers": {
		"wall": "#efe2c4", "rug": "#4ab8a0", "zone": "stone",
		"doors": {"0": "temple_air"},
		"stone_doors": ["K"],
		"floods": {"K": {"flag": "winds_song_door", "wet": "L", "dry": "0"}},
		"locked": ["A seam in the wall, cut by wind. It's shut, and the air round it is perfectly still."],
		"anchor_tiles": {"tablet": Vector2i(8, 9)},
		"anchors": {"1": "keeper_0", "2": "keeper_1", "3": "keeper_2", "4": "keeper_3", "5": "keeper_4",
			"6": "stone_0", "7": "stone_1", "8": "stone_2", "9": "stone_3", ";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"#################",
			"#.......K.......#",
			"#..6..7..8..9...#",
			"#...............#",
			"#....1.....2....#",
			"#...............#",
			"#.......5.......#",
			"#...............#",
			"#....4.....3....#",
			"#.;...........,.#",
			"#P<.............#",
			"#################",
		],
	},
	# The summit: the dragon's nest and hoard, and the wind that answers the Song of Winds. The keepers' seam comes up
	# into this room (a door), and the twins come along.
	"temple_air": {
		"wall": "#e8dcc0", "rug": "#4ab8a0",
		# the dragon's hoard round its nest (dragon_hoard.gd): gold and treasures heaped on these tiles
		"hoard": [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(10, 1), Vector2i(11, 1), Vector2i(12, 1), Vector2i(1, 7), Vector2i(1, 8), Vector2i(14, 7), Vector2i(14, 8), Vector2i(13, 10), Vector2i(4, 6), Vector2i(12, 6), Vector2i(4, 9), Vector2i(12, 9), Vector2i(3, 10), Vector2i(1, 2), Vector2i(15, 2)],
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [20, 25], "races": [33, 30, 36]},
		"doors": {"0": "valkoog_keepers"},
		"anchors": {";": "twin_tam", ",": "twin_saffi"},
		"rows": [
			"###w###w###w###w#",
			"#o.....AAA.....o#",
			"#..;.........,..#",
			"#o.ggg.....ggg.o#",
			"0..ggg.....ggg..#",
			"#o.....rrr.....o#",
			"#......r1r......#",
			"#..ggg.rrr.ggg..#",
			"#..ggg.rrr.ggg..#",
			"#o.....rrr.....o#",
			"#.*....rrr......#",
			"#.....rrr.......#",
			"#################",
		],
	},
	"temple_fire": {
		"wall": "#5a3a34", "rug": "#c83a1a",
		# the dragon's hoard round its nest (dragon_hoard.gd): gold and treasures heaped on these tiles
		"hoard": [Vector2i(7, 1), Vector2i(9, 1), Vector2i(1, 7), Vector2i(1, 8), Vector2i(15, 7), Vector2i(15, 8), Vector2i(13, 10), Vector2i(5, 2), Vector2i(11, 2), Vector2i(4, 6), Vector2i(12, 6), Vector2i(4, 9), Vector2i(12, 9), Vector2i(3, 10)],
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [30, 35], "races": [3, 9, 0, 6]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#################",
			"#o%%%o..A..o%%%o#",
			"#.%%%.......%%%.#",
			"#o.3..4...5..6.o#",
			"#..ggg.....ggg..#",
			"#..ggg..r..ggg..#",
			"#o.....r1r.....o#",
			"#.%%...rrr...%%.#",
			"#.%%...rrr...%%.#",
			"#o.....rrr.....o#",
			"#.....*rrr......#",
			"DP...7.rrr.....@#",
			"#################",
		],
	},
	"temple_earth": {
		"wall": "#6a8a5a", "rug": "#5a8a3a",
		# the dragon's hoard round its nest (dragon_hoard.gd): gold and treasures heaped on these tiles
		"hoard": [Vector2i(4, 1), Vector2i(7, 1), Vector2i(9, 1), Vector2i(12, 1), Vector2i(1, 9), Vector2i(13, 9), Vector2i(5, 2), Vector2i(11, 2), Vector2i(4, 6), Vector2i(12, 6), Vector2i(4, 8), Vector2i(12, 8), Vector2i(4, 10), Vector2i(12, 10)],
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [38, 43], "races": [18, 21, 15, 12]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#################",
			"#op..p..A..p..po#",
			"#.p...........p.#",
			"#o.3..4...5..6.o#",
			"#..ggg.....ggg..#",
			"#..ggg..r..ggg..#",
			"#o.....r1r.....o#",
			"#.pp...rrr...pp.#",
			"#o.....rrr.....o#",
			"#......rrr......#",
			"#.*....rrr....p.#",
			"DP...7.rrr.....@#",
			"#################",
		],
	},
	"hideout": {
		"wall": "#8a6a4a", "rug": "#6a3a2a",
		"npcs": {"1": "bandit_boss", "2": "bandit", "3": "bandit"},
		"rows": [
			"###############",
			"##.....1.....##",
			"#..t...CC..t..#",
			"#.............#",
			"#.2.......====#",
			"#.............#",
			"#=====.....3..#",
			"#..h.......*..#",
			"DP....rrr.....#",
			"###############",
		],
	},
	## Old Hal the builder's log cabin by the Coastal Path's washed-out footbridge: Hal (1, story.gd _builder) is too
	## tired to mend it himself; he lends you the logs stacked by his door, and gives you an egg once it's mended.
	"kit_cabin": {
		"wall": "#c89a6a", "rug": "#a85a3a", "zone": "wood", "stage": true, "anchors": {"1": "builder"},
		"fireplace_style": "fieldstone", "fireplace_stone": "#b9b1a0",
		"rows": [
			"###w###w###",
			"#Nb..qq..F#",
			"#.b......F#",
			"#....1....#",
			"#.ctc...a.#",
			"#.ctc.....#",
			"#[.......PD",
			"###########",
		],
	},
	## The wooden neighbor's shack on Cocoon Cove's pier, a lived-in fisher's cabin: weathered wood walls and a plank
	## floor, the bed and its nightstand against the back wall beside the storage rack and the hearth, crates stacked in
	## the corners and by the side wall, a small table between two stools, a rag rug, and the neighbor (1).
	"cove_dock_shack": {
		"wall": "#8a6a52", "rug": "#5a4a3c", "zone": "wood", "stage": true, "npcs": {"1": "resident"},
		"fireplace_style": "fieldstone", "fireplace_stone": "#a6b3ac",
		"rows": [
			"###w###w###",
			"#Nb..qq.FF#",
			"#.b.......#",
			"#....1r...#",
			"#.hth.r...#",
			"#........PD",
			"###########",
		],
	},
	## The Old Gear Shack at the end of Cocoon Cove's dock: nobody lives there any more, but
	## a trainer's starter gear was left behind (1-3: a cap, sneakers and a beast's collar, "found" items in item_db.gd).
	"shack": {
		"wall": "#b08a62", "rug": "#8a5a3a", "zone": "wood", "stage": true,
		"anchors": {"1": "item:worn_cap", "2": "item:old_sneakers", "3": "item:rope_collar"},
		"rows": [
			"#####w##w##",
			"#.Nb..FF..#",
			"#..b......#",
			"#...1..2..#",
			"#.ct......#",
			"#[.....3.PD",
			"###########",
		],
	},
	"ceo_1": {
		"wall": "#a8503a", "rug": "#7a2a2a",
		"npcs": {"1": "receptionist", "2": "patron", "3": "robot", "4": "robot"},
		"rows": [
			"#####w###w#####",
			"#p....#>>#...p#",
			"#.....#..#....#",
			"L..C|C.34.....#",
			"#..C1C........#",
			"#..CCC........#",
			"#.......e..e..L",
			"#.2...........#",
			"#.............#",
			"DP............#",
			"###############",
		],
	},
	"ceo_2": {
		"wall": "#8a4a3a", "rug": "#c8a040",
		"npcs": {"3": "robot", "4": "robot", "5": "robot"},
		"rows": [
			"####w#####w####",
			"#>>....o..e..e#",
			"#..3..........#",
			"L.......o.....#",
			"#..o.......4..#",
			"#.....o.......#",
			"#..e.......o..L",
			"#.........5...#",
			"#*.........P<<#",
			"###############",
		],
	},
	"ceo_3": {
		"wall": "#7a4038", "rug": "#c8a040",
		"npcs": {"3": "robot", "4": "robot", "5": "robot"},
		"rows": [
			"####w#####w####",
			"#e..e..o....>>#",
			"#..........3..#",
			"L.....o.......#",
			"#..4.......o..#",
			"#.......o.....#",
			"#..o.......e..L",
			"#...5.........#",
			"#<<P.........*#",
			"###############",
		],
	},
	"ceo_4": {
		"wall": "#c8a868", "rug": "#7a1a2a",
		"npcs": {"1": "ceo"},
		"anchors": {"2": "captive_0", "3": "captive_1", "4": "captive_2", "5": "freight_control"},
		"rows": [
			"####w#####w####",
			"#B..e.....e..B#",
			"#....CCCCC....#",
			"#......1......#",
			"#..2...3...4..#",
			"#..rrrrrrrrr..#",
			"#..rrrr5rrrr..#",
			"#.............#",
			"#<<P..........#",
			"###############",
		],
	},
	"cathedral": {
		"wall": "#6a6a74", "rug": "#5a1a3a",
		"npcs": {"1": "nyx", "2": "grunt", "3": "grunt"},
		"rows": [
			"######w###w####  ",
			"#>o...pAAAp...o\\ ",
			"#.......1.......#",
			"#o.............o#",
			"#...2..rrr..3...Z",
			"#.===..rrr..===.#",
			"#......rrr......#",
			"#.===..rrr..===.#",
			"#......rrr......#",
			"#.===..rrr..===.#",
			"#o.....rrr.....o#",
			"DP.....rrr......#",
			"#################",
		],
	},
	"crypt_1": {
		"wall": "#4a4a52", "rug": "#3a2a4a",
		"npcs": {"1": "guardian", "2": "ghost_grunt", "8": "ghost_grunt"},
		"encounter": {"lv": [42, 48], "ghost": true},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"###################",
			"#<P..ggg...t..ggg.#",
			"#..7.ggg......ggg.#",
			"#t.......2.3.4.5.6#",
			"#..ggg.......ggg..#",
			"#..ggg...o...ggg..#",
			"#.........t...1...#",
			"#ggg...8......ggg.#",
			"#ggg..........ggg.#",
			"#.....t...ggg...*.#",
			"#.........ggg...>.#",
			"###################",
		],
	},
	"crypt_2": {
		"wall": "#3a3448", "rug": "#5a2a6a",
		"npcs": {"1": "vexmora", "2": "ghost_grunt"},
		"encounter": {"lv": [46, 52], "ghost": true},
		"anchors": {"3": "reactor_0", "4": "reactor_1", "5": "reactor_2"},
		"rows": [
			"###################",
			"#o......AAA......o#",
			"#........1........#",
			"#..3..o.....o..4..#",
			"#..ggg...rrr...ggg#",
			"#..ggg...rrr...ggg#",
			"#o.......rrr.....o#",
			"#ggg..2..rrr......#",
			"#ggg.....5rr...ggg#",
			"#<P......rrr...ggg#",
			"###################",
		],
	},
}

## The room(s) each building type uses, the way in first: stage rooms joined by doors and stairs, or a dungeon's
## floors joined by stairs.
const SHOP_ROOMS := {
	"center": ["center"],
	"apothecary": ["apothecary"],
	"beast_gear": ["outfitter"],
	"trainer_gear": ["outfitter"],
	"bookstore": ["bookstore"],
	"arena": ["arena"],
	"cafe": ["cafe"],
	"dojo": ["dojo"],
	"museum": ["museum"],
	"music_hall": ["music_hall"],
	"music_shop": ["music_shop"],
	"fortune": ["fortune"],
	"home": ["home", "home_hall", "home_bed", "home_mom"],
	"electronics": ["electronics"],
	"skytower": ["skytower", "skytower_top"],
	"hideout": ["hideout"],
	"cabin": ["kit_cabin"],
	"kennel": ["kennel_barn"],
	"shack": ["shack"],
	"uncle": ["uncle_home"],
	"fishery": ["fishery"],
	"ceo_tower": ["ceo_1", "ceo_2", "ceo_3", "ceo_4"],
	"cathedral": ["cathedral", "crypt_1", "crypt_2"],
}

## The townsfolk's houses (each picks one by its seed): two studios, a house of two rooms, one with an upstairs.
const HOUSES := [["studio_a"], ["studio_b"], ["house_two", "house_two_bed"], ["house_up", "house_up_hall", "house_up_bed"]]

## Timber stage rooms on the Isle of Tides: round homes/store, rectangular arena. Entrances stay in the visible eastern side wall.
static func kelpwick_room(key: String) -> Dictionary:
	return KELPWICK_ROOMS.get(key, ROOMS[key])

const KELPWICK_ROOMS := {
	"studio_a": {"stage": true, "wall": "#dfbd8d", "zone": "wood", "home": true, "npcs": {"1": "resident"}, "rows": ["  ###w#  ", " /Nbb..\\ ", "#..bb...#", "#@......#", "#...1..PD", "#.[).yS.#", " \\...../ ", "  #####  "]},

	"outfitter": {"stage": true, "wall": "#dfbd8d", "zone": "wood", "npcs": {"1": "keeper", "2": "patron"},
		"counter_phone": [7, 2],
		"rows": [
			"   ###w###   ",
			"  /.s.1.s.\\  ",
			" /CCCCCCCCC\\ ",
			"#...........#",
			"#...........#",
			"#..........PD",
			"#.....2.....#",
			"#...........#",
			" \\........./ ",
			"  \\......./  ",
			"   #######   ",
		],
	},
	## Kelpwick shares healing and arena services: a wall separates the entrance lobby from the ring; the crystal
	## stands one tile farther back, with no furniture behind it. The host has a plain desk and counter phone.
	"arena": {"stage": true, "wall": "#dfbd8d", "zone": "wood", "npcs": {"1": "keeper", "3": "leader", "4": "patron", "5": "patron"}, "counter_phone": [15, 2], "rows": ["###w#####w#######w###", "#=::::3::::=#.1|.==.#", "#=:xxxxxxx:=#CCC...Hw", "#::x:::::x::#.......w", "#::x:::::x::#.......#", "#=:xxxxxxx:=#.......#", "#=4:::::::5:........#", "#:::::::::::.......PD", "#####################"]},}

## Hotel Mariposa: one two-storey lobby with walkable stairs and a balcony whose back wall has
## round-arched open doorways ("!") into a window box, as the guest rooms' back walls do; open hallway entrances on
## its left, guest rooms on both floors, and pool, healing spring and gym downstairs. Suite/room IDs @2/@3 stay stable.
## Paintings: [wall x, wall y, inward x/y, centre height, along-wall offset, width, height].
const HOTEL_ROOMS := {
	"hotel_lobby": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"#!#!#!#!#!#!#!#!#!#!#",
			"#...................#",
			"g...................#",
			"#...................#",
			"#.....CCCCCCCC..::..#",
			"#...............::..#",
			"#........1......::..#",
			"#.....CCCCCCCC..::..#",
			"#...............::..#",
			"#l..................w",
			"d..................PD",
			"#..aya........aya...w",
			"#.........2.........#",
			"#####################"
		],
		# (the user's 2026-11-15 direction) a runner leads straight from the front door to the hallway, with nothing on
		# it; the big plants stand behind it, the paired armchairs face each other across small tables in front of it,
		# and nothing in the lobby fades
		"runners": [[1, 10, 19, 1]],
		"furniture_yaws": {Vector2i(4, 11): PI / 2.0, Vector2i(15, 11): PI / 2.0},
		"counter_phone_plant": true,
		"no_fade": true,
		"doors": {
			"d": "hotel_hall_lower",
			"g": "hotel_hall_upper"
		},
		"npcs": {
			"1": "keeper",
			"2": "patron"
		},
		"counter_phone": [
			11,
			7
		],
		"wall_height": 5.5,
		"balcony": true,
		"level_h": 2.7,
		"heights": [
			"111111111111111111111",
			"111111111111111111111",
			"111111111111111111111",
			"111111111111111111111",
			"0000000000000000^^000",
			"0000000000000000^^000",
			"0000000000000000^^000",
			"0000000000000000^^000",
			"0000000000000000^^000",
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000",
			"000000000000000000000"
		],
		"open_doors": [
			"d",
			"g"
		],
		"fixtures": [
			[6, 5, "counter_gate"], [6, 6, "counter_gate"],
			[13, 5, "counter_gate"], [13, 6, "counter_gate"],
			[2, 6, "large_plant"],
			[2, 7, "large_plant"],
			[3, 6, "large_plant"],
			[3, 7, "large_plant"],
			[18, 5, "large_plant"],
			[18, 6, "large_plant"],
			[19, 5, "large_plant"],
			[19, 6, "large_plant"],
			# (the user's 2026-11-24 call) no giant plant in the middle of the floor behind the armchairs
			# guests' luggage, stacked against the back wall on every open tile (the user's 2026-11-15 direction)
			[1, 4, "luggage"], [2, 4, "luggage"], [3, 4, "luggage"], [4, 4, "luggage"], [5, 4, "luggage"],
			[14, 4, "luggage"], [15, 4, "luggage"], [18, 4, "luggage"], [19, 4, "luggage"],
			[
				2,
				1,
				"plant_table"
			],
			[
				6,
				1,
				"plant_table"
			],
			[
				8,
				1,
				"plant_table"
			],
			[
				12,
				1,
				"plant_table"
			],
			[
				14,
				1,
				"plant_table"
			],
			[
				18,
				1,
				"plant_table"
			]
		],
		"paintings": [
			[0, 8, 1, 0, 1.8, 0, 1.8, 1.2],
			[20, 7, -1, 0, 1.8, 0, 1.6, 1.1]
		],
		"counter_facing": [
			0,
			1
		]
	},
	"hotel_suite": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"########!#!##",
			"#.NbbN......#",
			"#..bb.......w",
			"#.....rrr...#",
			"dP....rrrSS.#",
			"#........yy.w",
			"#############"
		],
		"doors": {
			"d": "hotel_hall_upper"
		},
		"paintings": [
			[3, 0, 0, 1, 1.8, 0.5, 1.6, 1.0]
		]
	},
	"hotel_room": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"######!#!##",
			"#NbbN.....#",
			"#.bb......w",
			"dP..1..yy.#",
			"#...[..SS.w",
			"###########"
		],
		"doors": {
			"d": "hotel_hall_lower"
		},
		"npcs": {
			"1": "patron"
		},
		"paintings": [
			[2, 0, 0, 1, 1.8, 0.5, 1.6, 1.0]
		]
	},
	"hotel_hall_lower": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"##g###h###i####",
			"w.............#",
			"#............Pd",
			"#..p....==....#",
			"###############"
		],
		"doors": {
			"d": "hotel_lobby",
			"g": "hotel_room",
			"h": "hotel_pool",
			"i": "hotel_ice_lower"
		},
		"open_doors": [
			"d"
		],
		"paintings": [
			[8, 0, 0, 1, 1.8, 0, 1.6, 1.1]
		]
	},
	"hotel_hall_upper": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"##g###h###i####",
			"w.............#",
			"#............Pd",
			"#..p....==....#",
			"###############"
		],
		"doors": {
			"d": "hotel_lobby",
			"g": "hotel_suite",
			"h": "hotel_room_upper",
			"i": "hotel_ice_upper"
		},
		"open_doors": [
			"d"
		],
		"paintings": [
			[8, 0, 0, 1, 1.8, 0, 1.6, 1.1]
		]
	},
	"hotel_pool": {
		"stage": true,
		"dais": [{"rect": [1, 1, 4, 4], "steps": [[3, 4, "^"], [4, 4, "^"]]}],
		"zone": "hall",
		"full_height_windows": true,
		"swimmers": [[7, 5], [11, 3]],
		"pool_ladder": [9, 5],
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"#wwwwwwwwwwww#",
			"#...._______.#",
			"#...._______.#",
			"#...._______.#",
			"#...._______.g",
			"#...._______.#",
			"dP...........#",
			"#............#",
			"#............#",
			"##############"
		],
		"doors": {
			"d": "hotel_hall_lower",
			"g": "hotel_gym"
		},
		"fixtures": [
			[2, 1, "hot_tub"], [3, 1, "hot_tub"],
			[2, 2, "hot_tub"], [3, 2, "hot_tub"],
			[2, 4, "hot_tub_sign"],
			[1, 7, "chair"], [1, 8, "chair"]
		],
		"paintings": [
			[0, 2, 1, 0, 1.8, 0, 1.5, 1.1],
			[13, 2, -1, 0, 1.8, 0, 1.5, 1.1]
		]
	},
	"hotel_gym": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"##w###w###w##",
			"#...........w",
			"#..1....2...#",
			"#...........#",
			"dP..........w",
			"#..p.....p..#",
			"#############"
		],
		"doors": {
			"d": "hotel_pool"
		},
		"npcs": {
			"1": "runner",
			"2": "runner"
		},
		"treadmills": [
			[
				3,
				2
			],
			[
				8,
				2
			]
		],
		"paintings": [
			[4, 0, 0, 1, 1.8, 0, 1.6, 1.1],
			[8, 0, 0, 1, 1.8, 0, 1.6, 1.1]
		]
	},
	"hotel_ice_lower": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"#####w#",
			"#.mfz.#",
			"#.....#",
			"dP....#",
			"#.....#",
			"#######"
		],
		"doors": {
			"d": "hotel_hall_lower"
		},
		"fixtures": [
			[
				3,
				1,
				"ice_maker"
			]
		]
	},
	"hotel_ice_upper": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"#####w#",
			"#.mfz.#",
			"#.....#",
			"dP....#",
			"#.....#",
			"#######"
		],
		"doors": {
			"d": "hotel_hall_upper"
		},
		"fixtures": [
			[
				3,
				1,
				"ice_maker"
			]
		]
	},
	"hotel_room_upper": {
		"stage": true,
		"zone": "hall",
		"wall": "#fbf1e2",
		"trim": "#4a2c1a",
		"mission": true,
		"floor_tex": {
			"hall": "floor_terracotta"
		},
		"wall_tex": {
			"hall": "wall_plaster"
		},
		"rows": [
			"######!#!##",
			"#NbbN.....#",
			"#.bb......w",
			"dP.....yy.#",
			"#...[..SS.w",
			"###########"
		],
		"doors": {
			"d": "hotel_hall_upper"
		},
		"paintings": [
			[2, 0, 0, 1, 1.8, 0.5, 1.6, 1.0]
		]
	}
}
