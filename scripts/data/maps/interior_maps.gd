extends RefCounted
## Building interiors. Every building of a type uses its template, or its set of them (SHOP_ROOMS).
## Most are stage rooms ("stage"): one compact room each, seen whole like a stage set, open towards the camera, the way
## in through a side wall (D in it, P beside it). A building of several rooms has a door in a wall for each of the
## others ("doors": symbol -> the room it leads to), and each room is loaded on its own; going through, you come out
## at the door of the room you left. Stairs (> and <) lead to the next room up the set and back down. The big
## dungeons (the temples, the hideout, the towers, the cathedral and its crypt) keep their bigger layouts.
## Legend:
##   #  wall          w  wall with window   .  wooden floor   :  tiled floor   r  rug
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
## Rooms within a building (drawn by room_builder.gd):
##   d  doorway between rooms      L  locked door      Z  staff-only door (locked)
##   "locked": what you find at each locked door, in reading order (else just that it's locked)
##   furniture (see FURNITURE): k kitchen counter, i kitchen sink, v stove, f fridge, j pantry, T toilet, U bathtub,
##   u washbasin, W washing machine, S sofa, a armchair, V television, c chair, y coffee table, R wardrobe,
##   N nightstand, Q dresser, E desk, F storage shelves, X boxes, m mop and bucket, l floor lamp, O coat stand,
##   z bin, J bunk bed. A run of the same letter is one piece (two b's are a bed, a block of four a double bed).
##   "zones": the kind of room each tile is in, one letter per tile like the rows (see room_builder.gd ZONES):
##   l living room, b bedroom, k kitchen, a bathroom, h hall, s shop floor, o back room, f office, g grand hall,
##   w wood panelling, t stone, d diner; any other letter (walls) takes "zone", the template's default.
## People: keeper (runs the shop), leader (arena leader), patron (chatty visitor),
##   resident (lives in the house), mom. The bottom row is the open front: no wall is drawn there.
## Staff (keepers, the Beast Center's guide and kennel keeper, the receptionist) always stand behind a counter,
## boxed in so you can only talk to them across it.

const FURNITURE := {
	"k": "counter", "i": "kitchen_sink", "v": "stove", "f": "fridge", "j": "pantry", "T": "toilet", "U": "bathtub",
	"u": "basin", "W": "washer", "S": "sofa", "a": "armchair", "V": "tv", "c": "chair", "y": "coffee_table",
	"R": "wardrobe", "N": "nightstand", "Q": "dresser", "E": "desk", "F": "storage", "X": "boxes", "m": "mop",
	"l": "floor_lamp", "O": "coat_stand", "z": "trash", "J": "bunk", "@": "phone",
}

const ROOMS := {
	## Every Beast Center is the same 50s diner, one room you walk into from the side. Each machine has its own bay along
	## the back wall: the soda-can healing machine (H), the storage terminal (M), the nurse's counter with her egg
	## incubator (1, I) and the merge altar (A). Through the door in the left wall is the kennel (its own room). Guide
	## Dottie (2) walks about by the booths; the red phone (@) stands by the entrance.
	"center": {
		"wall": "#eef6f2", "rug": "#d8283a", "checker": true, "stage": true,
		"npcs": {"1": "keeper", "2": "guide", "3": "patron"}, "doors": {"!": "center_kennel"},
		"rows": [
			"####w###w####",
			"#H:M:#1I#:A:#",
			"#rrrrCCCCrrr#",
			"!:::::::::::#",
			"#::::::=t=:@#",
			"#::2:3:=t=::#",
			"#::::::::::PD",
			"#############",
		],
	},
	## The Beast Center's kennel: Pip (4) behind the counter, the pens (K) behind him.
	"center_kennel": {
		"wall": "#eef6f2", "rug": "#d8283a", "checker": true, "stage": true, "npcs": {"4": "kennel"},
		"doors": {"!": "center"},
		"rows": [
			"####w####",
			"#KpKpKpK#",
			"#...4...#",
			"#CCCCCCC#",
			"#.......!",
			"#p......#",
			"#########",
		],
	},
	"apothecary": {
		"wall": "#d8e8d0", "rug": "#4a8a5a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. It's occupied."],
		"rows": [
			"###w#Z#w###",
			"#sss.1.sss#",
			"#pCCCCCCCp#",
			"#........@#",
			"L..rr2rr..#",
			"#..rrrrr.PD",
			"###########",
		],
	},
	"outfitter": {
		"wall": "#e8d8c0", "rug": "#4a6a9a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The fitting room. Someone in there is trying on a very large hat."],
		"rows": [
			"###w#Z#w###",
			"#ss.s1s.ss#",
			"#CCCCCCCCC#",
			"#.........#",
			"#e.e...e.e#",
			"L.....2..PD",
			"###########",
		],
	},
	"bookstore": {
		"wall": "#c8b090", "rug": "#8a4a3a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The stockroom. Boxes of books are piled to the ceiling in there."],
		"rows": [
			"###w#Z#w###",
			"#BBB.1.BBB#",
			"#pCCCCCCCp#",
			"#.........#",
			"L.BB.BB.BB#",
			"#t2..rr..PD",
			"###########",
		],
	},
	## The arena's lobby: the receptionist (1) at her desk, a phone, and the door through to the ring. In Tidewater the
	## arena's two coaches (6, 7: world_db.gd ARENA_LESSONS) wait here: Rory above the entrance looking down at it, Ondine
	## along the row you come in on, looking along it. Elsewhere those tiles are plain floor.
	"arena": {
		"wall": "#c8c0b0", "rug": "#b03a3a", "stage": true, "npcs": {"1": "keeper"},
		"anchors": {"6": "lesson_team", "7": "lesson_elements"}, "doors": {"!": "arena_ring"},
		"locked": ["The restroom. The sign says OUT OF ORDER."],
		"rows": [
			"###w#!#w###",
			"#pC.....@=#",
			"#1C......6#",
			"#pC.......#",
			"#.........#",
			"L....7...PD",
			"###########",
		],
	},
	## The arena's ring (x), benches round it, the leader (3) waiting on its far side.
	"arena_ring": {
		"wall": "#c8c0b0", "rug": "#b03a3a", "stage": true, "npcs": {"3": "leader", "4": "patron", "5": "patron"},
		"doors": {"!": "arena"},
		"rows": [
			"#############",
			"#=::::3::::=#",
			"#=:xxxxxxx:=#",
			"#::x:::::x::#",
			"!::x:::::x::#",
			"#=:xxxxxxx:=#",
			"#=4:::::::5=#",
			"#############",
		],
		"zones": [
			"#############",
			"#wwwwwwwwwww#",
			"#wwgggggggww#",
			"#wwgggggggww#",
			"#wwgggggggww#",
			"#wwgggggggww#",
			"#wwwwwwwwwww#",
			"#############",
		],
	},
	## The café: the counter at the back, tables out front; the kitchen is through the STAFF ONLY door.
	"cafe": {
		"wall": "#f0d8d0", "rug": "#c07040", "stage": true, "npcs": {"1": "keeper", "2": "patron", "3": "patron"},
		"locked": ["The restroom. Somebody's humming in there."],
		"rows": [
			"###w#Z#w###",
			"#ss..1...p#",
			"#CCCCCCCCC#",
			"#........@#",
			"#ht2...ht3#",
			"L........PD",
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
			"####w#Z#w####",
			"#e.e.e.e.e.e#",
			"#:::::::::::#",
			"#pC::o:::o::#",
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
			"##Z#w###w####",
			"#rrrrnnnrrrr#",
			"#rrrrC1Crrrr#",
			"#rrrrCCCrrrr#",
			"#:===:===:::#",
			"#:::::::2:::#",
			"L:===:===::PD",
			"#############",
		],
	},
	"music_shop": {
		"wall": "#d8c8a8", "rug": "#2a5a8a", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The practice room. Someone in there is playing the same three notes over and over."],
		"rows": [
			"###w#Z#w###",
			"#BB.B1B.BB#",
			"#CCCCCCCCC#",
			"#........@#",
			"#.n..2....#",
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
			"####w##L#w###",
			"#NbbNB..V..@#",
			"#.bb...yy...#",
			"#Q.....SS..a#",
			"#.rrr..1....#",
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
			"###w##L#w##",
			"#Nb..V...p#",
			"#.b.......#",
			"#....ctc..#",
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
			"####w#!#w#L##",
			"#BB..V.....@#",
			"#....yy.....#",
			"#a...SS.....#",
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
	## A house with an upstairs: the living room, and stairs up to the bedroom.
	"house_up": {
		"wall": "#e8e0d0", "rug": "#3a7a6a", "stage": true, "npcs": {"1": "resident", "2": "resident"},
		"locked": ["The kitchen. Someone's left the radio on in there."],
		"rows": [
			"####w##L#w###",
			"#BB..V...>>>#",
			"#....yy.....#",
			"#a...SS....@#",
			"#.....rrr...#",
			"#p...1...2.PD",
			"#############",
		],
	},
	"house_up_bed": {
		"wall": "#e8e0d0", "rug": "#3a7a6a", "stage": true, "zone": "bedroom",
		"locked": ["The bathroom. Someone's having a very long bath."],
		"rows": [
			"###w#L#w###",
			"#NbbN.<<<.#",
			"#.bb....P.#",
			"#Q........#",
			"#l..rrr...#",
			"###########",
		],
	},
	## Fisher Gil's shack on the Tidewater docks: nets, crates, and his spare fishing pole (1) leaning by the back wall.
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
	## Uncle Rafe's house in Tidewater, by the west gate: one room, where he waits (1) with your father's flute.
	"uncle_home": {
		"wall": "#e0d0b0", "rug": "#4a6a9a", "stage": true, "anchors": {"1": "uncle"},
		"locked": ["Rafe's kitchen. It smells of brass polish."],
		"rows": [
			"####w##L#w###",
			"#NbNBB..V..@#",
			"#.b...yy....#",
			"#Q...SS.1..a#",
			"#.rrr.......#",
			"#l.........PD",
			"#############",
		],
	},
	## Your home: the living room downstairs, where Mom (1) is, and the red phone; stairs up to your bedroom. The kitchen
	## is locked while Mom's baking. The first time you go to leave, the phone rings (story.gd can_use_exit).
	"home": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "npcs": {"1": "mom"},
		"locked": ["The kitchen. Mom's baking something, and you're not allowed in until it's done."],
		"rows": [
			"####w##L#w###",
			"#BB...V..>>>#",
			"#....yy.....#",
			"#a...SS....@#",
			"#.......1...#",
			"#lp..rrr...PD",
			"#############",
		],
	},
	## Upstairs at home: your bedroom, where you wake up (wake). Your bed is the one to nap in.
	"home_up": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "zone": "bedroom", "wake": [3, 2],
		"locked": ["The bathroom. The tap's dripping again.", "Mom's room. Better not go snooping."],
		"rows": [
			"###L#w#w###",
			"#Nb.cE<<<.#",
			"#.b......P#",
			"#Q........#",
			"L..rrr....#",
			"#.......lp#",
			"###########",
		],
	},
	"electronics": {
		"wall": "#d8dce4", "rug": "#3a6ab0", "stage": true, "npcs": {"1": "keeper", "2": "patron"},
		"locked": ["The restroom. A note on the door: OUT OF ORDER (WE ARE FIXING IT. WE FIX THINGS)."],
		"rows": [
			"###w#Z#w###",
			"#ss.s1s.ss#",
			"#CCCCCCCCC#",
			"#.........#",
			"#e.e.r.e.e#",
			"L....r.2.PD",
			"###########",
		],
	},
	## The Sky Tower: Skykeeper Aria's ticket desk and the stairs in the lobby, and up top an open-air platform
	## ("open": railings instead of walls, sky all round) where the Tempestrix waits to fly you away.
	"skytower": {
		"wall": "#e4ecf4", "rug": "#3a7ac8",
		"npcs": {"1": "keeper"},
		"rows": [
			"###wZ##w###",
			"#pC1C.>>.p#",
			"#.CCC.....#",
			"#.........#",
			"#=...r...=#",
			"#=..rrr..=#",
			"#p..rPr..p#",
			"#####DD####",
		],
	},
	"skytower_top": {
		"wall": "#c8b088", "rug": "#3a7ac8", "open": true,
		"npcs": {"1": "thunderhawk"},
		"rows": [
			"###########",
			"#p.......p#",
			"#....1....#",
			"#.........#",
			"#.........#",
			"#.........#",
			"#<P....==.#",
			"###########",
		],
	},
	"temple_water": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"npcs": {"1": "guardian", "2": "patron"},
		"encounter": {"lv": [8, 11], "races": [21, 24, 27]},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#####w#####w#####",
			"#o~~~o..A..o~~~o#",
			"#.~~~...1...~~~.#",
			"#..3..4.:.5..6..#",
			"#o.ggg.....ggg.o#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
			"#..~~..rrr..~~..#",
			"#o.~~..rrr..~~.o#",
			"#......rrr......#",
			"#.2..7.rrr....*.#",
			"#......rPr......#",
			"#######DDD#######",
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
			"#o.ggg.rrr.ggg.o#",
			"#..ggg.rrr.ggg..#",
			"#o.....rrr.....o#",
			"#.*....rrr......#",
			"#....7.rPr.....@#",
			"#######DDD#######",
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
			"#..3..4...5..6..#",
			"#o.ggg.....ggg.o#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
			"#.%%...rrr...%%.#",
			"#o%%...rrr...%%o#",
			"#......rrr......#",
			"#.....*rrr......#",
			"#....7.rPr.....@#",
			"#######DDD#######",
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
			"#..3..4...5..6..#",
			"#o.ggg.....ggg.o#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
			"#.pp...rrr...pp.#",
			"#o.....rrr.....o#",
			"#......rrr......#",
			"#.*....rrr....p.#",
			"#....7.rPr.....@#",
			"#######DDD#######",
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
			"#.....rPr.....#",
			"######DDD######",
		],
	},
	## Old Hal the builder's log cabin by the Coastal Path's washed-out footbridge: Hal (1, story.gd _builder) is too
	## tired to mend it himself; he lends you the logs stacked by his door, and gives you an egg once it's mended.
	"kit_cabin": {
		"wall": "#c89a6a", "rug": "#a85a3a", "zone": "wood", "stage": true, "anchors": {"1": "builder"},
		"rows": [
			"###w###w###",
			"#R.bb.Nq.X#",
			"#X.......F#",
			"#....1....#",
			"#.ctc...a.#",
			"#.ctc.....#",
			"#l.......PD",
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
			"#......P......#",
			"######DDD######",
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
		"rows": [
			"####w#####w####",
			"#B..e.....e..B#",
			"#....CCCCC....#",
			"#......1......#",
			"#.............#",
			"#..rrrrrrrrr..#",
			"#..rrrrrrrrr..#",
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
			"#......rPr......#",
			"#######DDD#######",
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
	"center": ["center", "center_kennel"],
	"apothecary": ["apothecary"],
	"beast_gear": ["outfitter"],
	"trainer_gear": ["outfitter"],
	"bookstore": ["bookstore"],
	"arena": ["arena", "arena_ring"],
	"cafe": ["cafe"],
	"dojo": ["dojo"],
	"museum": ["museum"],
	"music_hall": ["music_hall"],
	"music_shop": ["music_shop"],
	"fortune": ["fortune"],
	"home": ["home", "home_up"],
	"electronics": ["electronics"],
	"skytower": ["skytower", "skytower_top"],
	"hideout": ["hideout"],
	"cabin": ["kit_cabin"],
	"uncle": ["uncle_home"],
	"fishery": ["fishery"],
	"ceo_tower": ["ceo_1", "ceo_2", "ceo_3", "ceo_4"],
	"cathedral": ["cathedral", "crypt_1", "crypt_2"],
}

## The townsfolk's houses (each picks one by its seed): two studios, a house of two rooms, one with an upstairs.
const HOUSES := [["studio_a"], ["studio_b"], ["house_two", "house_two_bed"], ["house_up", "house_up_bed"]]
