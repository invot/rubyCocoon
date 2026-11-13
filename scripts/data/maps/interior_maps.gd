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
## "water_levels" for its water, "stone_doors" for its engraved doors and "puzzle" for its levers (tide_water.gd,
## tide_puzzles.gd; see the Temple of Tides).
## Rooms within a building (drawn by room_builder.gd):
##   d  doorway between rooms      L  locked door      Z  staff-only door (locked)
##   "locked": what you find at each locked door, in reading order (else just that it's locked)
##   furniture (see FURNITURE): k kitchen counter, i kitchen sink, v stove, f fridge, j pantry, T toilet, U bathtub,
##   u washbasin, W washing machine, S sofa, a armchair, V television, c chair, y coffee table, R wardrobe,
##   N nightstand, Q dresser, E desk, F storage shelves, X boxes, m mop and bucket, l floor lamp, O coat stand,
##   z bin, J bunk bed, & low book display, ^ hay bales. TVs (V) belong on the implied fourth wall in stage rooms.
##   A run of the same letter is one piece (two b's are a bed, a block of four a double bed).
##   "zones": the kind of room each tile is in, one letter per tile like the rows (see room_builder.gd ZONES):
##   l living room, b bedroom, k kitchen, a bathroom, h hall, s shop floor, o back room, f office, g grand hall,
##   w wood panelling, t stone, d diner; any other letter (walls) takes "zone", the template's default.
## People: keeper (runs the shop), leader (arena leader), patron (chatty visitor),
##   resident (lives in the house), mom. The bottom row is the open front: no wall is drawn there.
## Staff (keepers, the Beast Center's guide, a barn's kennel keeper, the receptionist) always stand behind a counter,
## boxed in so you can only talk to them across it.

const FURNITURE := {
	"k": "counter", "i": "kitchen_sink", "v": "stove", "f": "fridge", "j": "pantry", "T": "toilet", "U": "bathtub",
	"u": "basin", "W": "washer", "S": "sofa", "a": "armchair", "V": "tv", "c": "chair", "y": "coffee_table",
	"R": "wardrobe", "N": "nightstand", "Q": "dresser", "E": "desk", "F": "storage", "X": "boxes", "m": "mop",
	"&": "book_display", "l": "floor_lamp", "O": "coat_stand", "z": "trash", "J": "bunk", "@": "phone", "^": "hay",
}

const ROOMS := {
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
			"#^KKKK^.FX#",
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
			"#sss.1.sss#",
			"#pCCCCCCCpw",
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
			"#ss.s1s.ss#",
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
			"#BBB.1..BBBB#",
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
			"#BBB.1.BBB#",
			"#pCCCCCCCpw",
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
			"#=::::3::::=#p1p.==.#",
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
	"cafe": {
		"wall": "#f0d8d0", "rug": "#c07040", "stage": true, "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"locked": ["The restroom. Somebody's humming in there."],
		"counter_phone": [6, 2],
		"rows": [
			"#####Z#####",
			"#ss..1...p#",
			"#CCCCCCCCCw",
			"#.........w",
			"#ht2...ht3#",
			"L........PD",
			"###########",
		],
	},
	## Dustwell's Oasis Saloon (a cafe: the barkeep sells the same snacks, Places.shop): the bar along the back with
	## kegs and bottles behind it, tables and stools for the regulars, a locked back room where the card game goes on.
	"saloon": {
		"wall": "#c47a4e", "rug": "#8a2a2a", "stage": true, "zone": "wood", "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"locked": ["The back room. Somebody in there is shuffling cards, very slowly, and humming."],
		"counter_phone": [8, 2],
		"rows": [
			"######Z######",
			"#XX..1...sss#",
			"#CCCCCCCCCCCw",
			"#...........w",
			"#ht2....ht3.#",
			"#...........#",
			"L..........PD",
			"#############",
		],
	},
	## Dustwell Jail: Deputy Rusk (1) behind the front desk, the two cells' doors shut behind him (they're empty, and
	## staff only).
	"jail": {
		"wall": "#e2c48a", "rug": "#7a3a2a", "stage": true, "zone": "back", "npcs": {"1": "deputy"},
		"rows": [
			"###Z###Z###",
			"#F...1...O#",
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
			"#pC:::::::::w",
			"#1C::::2::::#",
			"#pC::e:::e:PD",
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
	"dance_studio": {
		"wall": "#dfbd8d", "stage": true, "anchors": {"1": "dance_instructor"},
		"rows": [
			"###w###w#####",
			"#p.nn.....Op#",
			"#.....1.....w",
			"#==.........w",
			"#...........#",
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
	"fortune": {
		"wall": "#6a4a7a", "rug": "#5a2a6a", "stage": true, "npcs": {"1": "keeper"},
		"rows": [
			"###w#w###",
			"#..p1p..#",
			"#..YYY..#",
			"#rrrrrrr#",
			"#rrrrrrr#",
			"#t.....PD",
			"#########",
		],
	},
	## A townsperson's studio: the bed and the living room in one room (the bed's corner carpeted), the bathroom locked.
	"studio_a": {
		"wall": "#e8d8b8", "rug": "#7a4a8a", "stage": true, "npcs": {"1": "resident", "2": "resident"},
		"locked": ["The bathroom. Someone's in there, singing."],
		"rows": [
			"#######L#####",
			"#NbbNB..SS.@#",
			"w.bb........#",
			"#Q......yy.a#",
			"w.rrr..1....#",
			"#l.......2.PD",
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
			"#Nb......p#",
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
		"doors": {"!": "house_two_bed"}, "locked": ["The kitchen. It smells like toast."],
		"rows": [
			"######!###L##",
			"#BB.SS.....@#",
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
			"#R..NbbN..#",
			"#....bb...#",
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
			"###w###w###",
			"#NbbN....R#",
			"#.bb......#",
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
			"#X.F..1X#",
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
			"#X.F...X#",
			"#.1.2.3.#",
			"#th.....#",
			"#......PD",
			"#########",
		],
	},
	## Uncle Rafe's house in Bellerive, by the west gate: one room, where he waits (1) with your father's flute.
	"uncle_home": {
		"wall": "#e0d0b0", "rug": "#4a6a9a", "stage": true, "anchors": {"1": "uncle"},
		"locked": ["Rafe's kitchen. It smells of brass polish."],
		"rows": [
			"#######L#####",
			"#NbNBB..SS.@#",
			"w.b.........#",
			"#Q.....1yy.a#",
			"w.rrr.......#",
			"#l.........PD",
			"#############",
		],
	},
	## Your home: the living room downstairs, where Mom (1) is, and the red phone; stairs up to your bedroom. The kitchen
	## is locked. The phone stands against the staircase wall; the first time you go to leave, it rings.
	"home": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "npcs": {"1": "mom"},
		"furniture_offsets": {Vector2i(11, 2): Vector2(0, -0.28)},
		"locked": ["The kitchen. A faint smell of biscuits lingers by the door."],
		"rows": [
			"#######L#####",
			"#BB.SS...>>>#",
			"w..........@#",
			"wa..yy......#",
			"#.......1...#",
			"#lp..rrr...PD",
			"#############",
		],
	},
	## Upstairs at home: the landing, a hallway half a room deep. The stairs come up at its right end; your bedroom is
	## through the door at its left end, Mom's room and the bathroom (locked) off its back wall.
	"home_hall": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "hall",
		"doors": {"!": "home_bed", "?": "home_mom"}, "locked": ["The bathroom. The tap's dripping again."],
		"rows": [
			"##!#L##?#####",
			"wp...l...<<<#",
			"w..........P#",
			"#############",
		],
	},
	## Your bedroom, where you wake up (wake). Your bed is the one to nap in.
	"home_bed": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "bedroom", "wake": [3, 2], "doors": {"!": "home_hall"},
		"rows": [
			"###w###w###",
			"#Nb.cE..RR#",
			"#.b.......#",
			"#Q........!",
			"#..rrr....#",
			"#p......l.#",
			"###########",
		],
	},
	## Mom's room: her double bed between two nightstands.
	"home_mom": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "bedroom", "doors": {"!": "home_hall"},
		"rows": [
			"###w###w###",
			"#RR.NbbN.Q#",
			"#a...bb...#",
			"!.........#",
			"#..rrrr..p#",
			"#l........#",
			"###########",
		],
	},
	"electronics": {
		"wall": "#d8dce4", "rug": "#3a6ab0", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. A note on the door: OUT OF ORDER (WE ARE FIXING IT. WE FIX THINGS)."],
		"rows": [
			"#####Z#####",
			"#ss.s1s.ss#",
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
	"temple_tides_hall": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"2": "temple_tides_falls", "3": "temple_tides_maze", "4": "temple_tides_song"},
		"stone_doors": ["4"], "level_h": 0.8, "top_level": 2,
		"water_levels": [["tides_falls_solved", -0.12], ["tides_maze_solved", -0.92]],
		"floods": {";": {"flag": "tides_falls_solved", "wet": "_", "dry": ":"}, "+": {"flag": "tides_maze_solved", "wet": "_", "dry": ":"}},
		"anchors": {"6": "chest:spirit_tonic@tides_maze_solved"},
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
			"#++++++++++++++++++++++++++6++#",
			"#+++++++++++++++++++++++++++++#",
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
	# One path, along the back wall. Three waterfalls run down that wall into their basins (_) and across the path (a .. c)
	# into the pool at the front of the room, with four levers against the wall between them. The treasure lies on the
	# pool's floor, and two flights of steps lead down to it once it's drained.
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
			"10000000000000001",
			"10000000000000001",
			"00000000000000000",
		],
	},
	# A maze of walkways over a pool, with metal lattices in them: three waterfalls drop from the pipes overhead through the
	# lattices (a .. h) and block them, and each lever moves one from a lattice to another.
	"temple_tides_maze": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_hall"},
		"level_h": 0.8, "top_level": 1,
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"water_levels": [["tides_maze_solved", -0.12]], "puzzle": "maze",
		"floods": {"+": {"flag": "tides_maze_solved", "wet": "_", "dry": ":"}},
		"anchors": {"5": "switch:0", "6": "switch:1", "7": "switch:2", "8": "switch:3", "9": "chest:tide_charm@tides_maze_solved", "3": "chest:revival_seed"},
		"rows": [
			"#####################",
			"#+++++++++7+++++++++#",
			"#+:::::::::::::::::3#",
			"#+:+++++++:+++++++:+#",
			"#+a+++++++d+++++++e+#",
			"#+:+++++++:+++++++:+#",
			"[::::::6+5::h::::::+#",
			"#+:+++++++:+++++++:+#",
			"#+b+++++9+c+++++++:+#",
			"#+:+++++++:+++++++:+#",
			"#+::::::f:::::::g::+#",
			"#+++++8+++++++++++++#",
			"#####################",
		],
		"heights": [
			"111111111111111111111",
			"100000000010000000001",
			"101111111111111111111",
			"101000000010000000101",
			"101000000010000000101",
			"101000000010000000101",
			"111111110111111111101",
			"101000000010000000101",
			"101000000010000000101",
			"1010000v00100v0000101",
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
	# The guardian's octagon: a path over the water from the door to the island in the middle.
	"temple_water": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"npcs": {"1": "guardian"},
		"doors": {"[": "temple_tides_song"},
		"level_h": 0.8, "top_level": 1,
		"water_levels": [["", -0.12]],
		"floods": {"+": {"flag": "", "wet": "_", "dry": ":"}},
		"rows": [
			"    /#########\\    ",
			"   /+++++++++++\\   ",
			"  /+++++++++++++\\  ",
			" /+++++++++++++++\\ ",
			"/+++++++++++++++++\\",
			"#+++++++++++++++++#",
			"#+++++++:A:+++++++#",
			"#++++++::1::++++++#",
			"[:::::::::::++++++#",
			"#++++++:::::++++++#",
			"#+++++++:::+++++++#",
			"#+++++++++++++++++#",
			"#+++++++++++++++++#",
			"\\+++++++++++++++++/",
			" \\+++++++++++++++/ ",
			"  \\+++++++++++++/  ",
			"   \\+++++++++++/   ",
			"    ###########    ",
		],
		"heights": [
			"1111111111111111111",
			"1111000000000001111",
			"1110000000000000111",
			"1100000000000000011",
			"1000000000000000001",
			"1000000000000000001",
			"1000000011100000001",
			"1000000111110000001",
			"1111111111110000001",
			"1000000111110000001",
			"1000000011100000001",
			"1000000000000000001",
			"1000000000000000001",
			"1000000000000000001",
			"1100000000000000011",
			"1110000000000000111",
			"1111000000000001111",
			"1111000000000001111",
		],
	},
	"temple_air": {
		"wall": "#e8dcc0", "rug": "#4ab8a0",
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [20, 25], "races": [33, 30, 36]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"###w###w###w###w#",
			"#o.....AAA.....o#",
			"#..3..4.1.5..6..#",
			"#o.ggg.....ggg.o#",
			"#..ggg.....ggg..#",
			"#o.....rrr.....o#",
			"#......rrr......#",
			"#..ggg.rrr.ggg..#",
			"#..ggg.rrr.ggg..#",
			"#o.....rrr.....o#",
			"#.*....rrr......#",
			"DP...7.rrr.....@#",
			"#################",
		],
	},
	"temple_fire": {
		"wall": "#5a3a34", "rug": "#c83a1a",
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [30, 35], "races": [3, 9, 0, 6]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#################",
			"#o%%%o..A..o%%%o#",
			"#.%%%...1...%%%.#",
			"#o.3..4...5..6.o#",
			"#..ggg.....ggg..#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
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
		"npcs": {"1": "guardian"},
		"encounter": {"lv": [38, 43], "races": [18, 21, 15, 12]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#################",
			"#op..p..A..p..po#",
			"#.p.....1.....p.#",
			"#o.3..4...5..6.o#",
			"#..ggg.....ggg..#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
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
		"rows": [
			"###w###w###",
			"#R.Nb..q.X#",
			"#X..b....F#",
			"#....1....#",
			"#.ctc...a.#",
			"#.ctc.....#",
			"#l.......PD",
			"###########",
		],
	},
	## The wooden neighbor's shack on Cocoon Cove's pier, a lived-in fisher's cabin: weathered wood walls and a plank
	## floor, the bed and its nightstand against the back wall beside the storage rack and the hearth, crates stacked in
	## the corners and by the side wall, a small table between two stools, a rag rug, and the neighbor (1).
	"cove_dock_shack": {
		"wall": "#8a6a52", "rug": "#5a4a3c", "zone": "wood", "stage": true, "npcs": {"1": "resident"},
		"rows": [
			"###w###w###",
			"#NbF..q.XO#",
			"#.b......X#",
			"#....1r...#",
			"#.hth.r...#",
			"#X.......PD",
			"###########",
		],
	},
	## The Old Gear Shack at the end of Cocoon Cove's dock: nobody lives there any more, but
	## a trainer's starter gear was left behind (1-3: a cap, sneakers and a beast's collar, "found" items in item_db.gd).
	"shack": {
		"wall": "#b08a62", "rug": "#8a5a3a", "zone": "wood", "stage": true,
		"anchors": {"1": "item:worn_cap", "2": "item:old_sneakers", "3": "item:rope_collar"},
		"rows": [
			"###w###w###",
			"#RNb...F.X#",
			"#X.b......#",
			"#...1..2..#",
			"#.ct......#",
			"#l.....3.PD",
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
			"L...p..34.....#",
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
		"rows": [
			"###################",
			"#o......AAA......o#",
			"#........1........#",
			"#.....o.....o.....#",
			"#..ggg...rrr...ggg#",
			"#..ggg...rrr...ggg#",
			"#o.......rrr.....o#",
			"#ggg..2..rrr......#",
			"#ggg.....rrr...ggg#",
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
	"studio_a": {"stage": true, "wall": "#dfbd8d", "zone": "wood", "npcs": {"1": "resident"},
		"rows": [
			"   ###w###   ",
			"  /Nbb..SR\\  ",
			" /..bb.....\\ ",
			"#...........#",
			"#......yy...#",
			"#..@.......PD",
			"#.....1.....#",
			"#...........#",
			" \\........./ ",
			"  \\......./  ",
			"   #######   ",
		],
	},
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
	## Kelpwick has no Beast Center: its great hut keeps the village's healing machine (H) in the back corner, with the red
	## telephone on the host's counter beside it ("counter_phone": its counter tile) so nothing stands in the machine's way.
	"arena": {"stage": true, "wall": "#dfbd8d", "zone": "wood", "npcs": {"1": "keeper", "3": "leader", "4": "patron", "5": "patron"}, "anchors": {"6": "lesson_team", "7": "lesson_elements"},
		"counter_phone": [17, 2],
		"rows": [
			"##########w##########",
			"#..............1....#",
			"#CCCCCCCCCCCCCCCCCCC#",
			"#.....3............H#",
			"#..xxxxxxxx.........#",
			"#..x......x.........#",
			"#..x......x........PD",
			"#..x......x......6..#",
			"#..xxxxxxxx.........#",
			"#..4......5......7..#",
			"#...................#",
			"#...................#",
			"#####################",
		],
	},
}

## Hotel Mariposa, finished like a Spanish mission (room_builder.gd _mission_decor): terracotta tiles, white plaster over
## an azulejo dado, dark carved wood, iron sconces and arched doorways. Its lobby has doors through to two guest rooms, each with a pair of open doorways onto the
## balconies seen on the front of the hotel ("!": drawn open, but you can't walk out of them). All share the normal
## room-door system.
const HOTEL_ROOMS := {
	"hotel_lobby": {
		"stage": true, "zone": "hall", "wall": "#fbf1e2", "rug": "#5e1a22", "trim": "#4a2c1a", "mission": true,
		"npcs": {"1": "keeper", "2": "patron"},
		"doors": {"d": "hotel_suite", "g": "hotel_room"}, "locked": ["The hotel kitchen. Staff only."],
		"counter_phone": [9, 2],
		"rows": [
			"#######Z#######",
			"#p.....1.....p#",
			"#CCCCCCCCCCCCCw",
			"#....rrrr.....w",
			"d....r2rr.....#",
			"#....rrrr.....w",
			"g..SS..yy....PD",
			"###############",
		],
		"floor_tex": {"hall": "floor_terracotta"}, "wall_tex": {"hall": "wall_plaster"},
	},
	"hotel_suite": {
		"stage": true, "zone": "bedroom", "wall": "#fbf1e2", "rug": "#4e2140", "trim": "#4a2c1a", "mission": true,
		"floor_tex": {"bedroom": "floor_terracotta"}, "wall_tex": {"bedroom": "wall_plaster"},
		"doors": {"d": "hotel_lobby"}, "locked": ["Your suite's private bathroom."],
		"rows": [
			"##!#########!##",
			"#.....NbbN...@#",
			"#......bb.....#",
			"#....rrrr.....L",
			"dP...rrrrSS...#",
			"#....rrrryy...#",
			"#.............#",
			"###############",
		],
	},
	"hotel_room": {
		"stage": true, "zone": "bedroom", "wall": "#fbf1e2", "rug": "#1f3a66", "trim": "#4a2c1a", "mission": true,
		"floor_tex": {"bedroom": "floor_terracotta"}, "wall_tex": {"bedroom": "wall_plaster"},
		"doors": {"d": "hotel_lobby"},
		"rows": [
			"###!#####!###",
			"#Ec..NbbN...#",
			"#.....bb....w",
			"#...rrrr....#",
			"dP..rrrr.SS.w",
			"#...rrrr.yy.#",
			"#...........#",
			"#############",
		],
	},
}
