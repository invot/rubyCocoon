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
## Rooms within a building (drawn by room_builder.gd):
##   d  doorway between rooms      L  locked door      Z  staff-only door (locked)
##   "locked": what you find at each locked door, in reading order (else just that it's locked)
##   furniture (see FURNITURE): k kitchen counter, i kitchen sink, v stove, f fridge, j pantry, T toilet, U bathtub,
##   u washbasin, W washing machine, S sofa, a armchair, V television, c chair, y coffee table, R wardrobe,
##   N nightstand, Q dresser, E desk, F storage shelves, X boxes, m mop and bucket, l floor lamp, O coat stand,
##   z bin, J bunk bed, & low book display. TVs (V) belong on the implied fourth wall in stage rooms.
##   A run of the same letter is one piece (two b's are a bed, a block of four a double bed).
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
	"&": "book_display", "l": "floor_lamp", "O": "coat_stand", "z": "trash", "J": "bunk", "@": "phone",
}

const ROOMS := {
	## Every Beast Center is the same 50s diner, one room you walk into from the side; bigger than the other rooms
	## (17x9), so the camera follows you round it. On the left, on its own wood floor, is the kennel: its four pens (K)
	## behind Kennel Keeper Pip's counter (4), and two chairs (c) in the front corner. A wall runs forward from the back
	## between it and the diner and stops short of the front, so you walk round its end. Each machine has its own bay
	## along the diner's back wall: the nurse's counter with her egg incubator (1, I), the soda-can healing machine (H),
	## the storage terminal (M) and the merge altar (A); the red phone stands on the nurse's counter. Guide Dottie (2)
	## walks about the room.
	"center": {
		"wall": "#eef6f2", "rug": "#d8283a", "checker": true, "stage": true,
		"npcs": {"1": "keeper", "2": "guide", "3": "patron", "4": "kennel"},
		"counter_phone": [8, 2],
		"rows": [
			"##w######w###w###",
			"#KKKK#1I#:H:M:A:#",
			"#.4..#CCCrrrrrrr#",
			"#CCCC#::::::::::#",
			"#....#::::::::::#",
			"#....#::2:::3:::#",
			"#c...:::::::::::#",
			"#c...::::::::::PD",
			"#################",
		],
		"zones": [
			"#################",
			"#wwww############",
			"#wwww############",
			"#wwww############",
			"#wwww############",
			"#wwww############",
			"#wwww############",
			"#wwww############",
			"#################",
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
			"#e.e...e.e#",
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
			"L.&&.&&.&&#",
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
	## is locked while Mom's baking. The first time you go to leave, the phone rings (story.gd can_use_exit).
	"home": {
		"wall": "#f0e0c0", "rug": "#c05050", "stage": true, "npcs": {"1": "mom"},
		"locked": ["The kitchen. Mom's baking something, and you're not allowed in until it's done."],
		"rows": [
			"#######L#####",
			"#BB.SS...>>>#",
			"w...........#",
			"wa..yy.....@#",
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
			"#e.e.r.e.e#",
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
	# The Temple of Tides (WorldDB.TEMPLES "water"): a hall, three wings and the guardian's chamber below. The hall's
	# east channel (;) drains with the west wing's lever, the basin before the gallery's door (+) with the east wing's,
	# and the great pool (?) with the gallery's, showing the stairs down (!) to the chamber. In the wings, walkways run
	# between water channels (_), strong water beasts prowl them in plain sight ("roam"), and chests hold treasure.
	"temple_tides_hall": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_west", "]": "temple_tides_east", "^": "temple_tides_gallery", "<": "temple_water"},
		"floods": {";": {"flag": "tides_lever_1", "wet": "_", "dry": ":"}, "+": {"flag": "tides_lever_2", "wet": "_", "dry": ":"},
			"?": {"flag": "tides_lever_3", "wet": "_", "dry": ":"}, "!": {"flag": "tides_lever_3", "wet": "_", "dry": "<"}},
		"rows": [
			"##########^##########",
			"#:::::::+++++:::;;::#",
			"#___::::+++++:::;;::#",
			"#___::o:::::o:::;;::#",
			"#___::::::::::::;;::#",
			"#::::?????????::;;::#",
			"#::::?????????::;;::#",
			"[::::????!????::;;::]",
			"#::::?????????::;;::#",
			"#::::?????????::;;::#",
			"#___::::::::::::;;::#",
			"#___::o:::::o:::;;::#",
			"#___::::::::::::;;::#",
			"DP::::::::::::::;;::#",
			"#####################",
		],
	},
	"temple_tides_west": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"]": "temple_tides_hall"},
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"anchors": {"5": "lever:tides_lever_1", "6": "chest:tide_pendant", "7": "chest:potion"},
		"levers": {"tides_lever_1": {"ask": "A heavy bronze lever, cold and wet. Pull it?",
			"lines": ["Deep in the walls, a gate grinds open. Far off, water roars away down a drain.",
				"Something has drained, back in the entrance hall."],
			"done": "The lever is locked down. Water still gurgles somewhere below."}},
		"rows": [
			"#######################",
			"#5_:::::::::_:_:::::::#",
			"#:_:_:_____:_:_:_____:#",
			"#:_:::_:::::_:::_:::_:#",
			"#:_:___:___:_____:_:_:#",
			"#:_:::_:::::::::::_:::#",
			"#:___:_________:___:_:#",
			"#:::::_:::::::::::::_:]",
			"#______:_:___:_:_____:#",
			"#:::::_:_:::::_:::::::#",
			"#:___:_:_______:_____:#",
			"#:_:::_:_:::::_:::_:::#",
			"#:_:___:_:___:_____:_:#",
			"#6_:::::::_7::::::::_:#",
			"#######################",
		],
	},
	"temple_tides_east": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"[": "temple_tides_hall"},
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"anchors": {"5": "lever:tides_lever_2", "6": "chest:tide_charm", "7": "chest:revival_seed"},
		"levers": {"tides_lever_2": {"ask": "Another bronze lever, carved with waves. Pull it?",
			"lines": ["A deep rumble shakes the floor, and water drains away somewhere close by.",
				"The basin before the hall's north door must be empty now."],
			"done": "The lever is locked down."}},
		"rows": [
			"#######################",
			"#5_:::::_6::::::::::::#",
			"#:___:_:_________:___:#",
			"#:::::_:_:::_:::::::::#",
			"#______:_:_:_:_____:__#",
			"#:::::_:::_:_:::_7_:::#",
			"#____:_____:___:_:_:_:#",
			"[:::_:::::_:::::_:_:::#",
			"#:_:_:_:_____:___:___:#",
			"#:_:::_:::::::::::::_:#",
			"#:___:_:_______:_____:#",
			"#:::_:_:::::::_:_:::_:#",
			"#:_:_____:_:_:_:_:_:_:#",
			"#:_:::::::::_:_:::::::#",
			"#######################",
		],
	},
	"temple_tides_gallery": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"doors": {"]": "temple_tides_hall"},
		"encounter": {"lv": [10, 12], "races": [24, 27, 21], "roam": true},
		"anchors": {"5": "lever:tides_lever_3", "6": "chest:spirit_tonic"},
		"levers": {"tides_lever_3": {"ask": "The last bronze lever, crowned with a coral wave. Pull it?",
			"lines": ["The whole temple shudders. Back in the entrance hall, the great pool drains away with a roar.",
				"Where the water was, a stair must lead down into the dark."],
			"done": "The lever is locked down. The way to the inner chamber is open."}},
		"rows": [
			"#####################",
			"#5::::_:::::_:::::::#",
			"#____:_:_:_:_:_____:#",
			"#:::::_:_:_:_:_:::::#",
			"#:_____:_:_:___:_:_:#",
			"#:_6_:::_:_:::::_:::#",
			"#:_:_:_:_:_______:__#",
			"#:_:_:::_:::_:::_:::]",
			"#:_:___:___:_:___:_:#",
			"#:_:::::::::_:::::_:#",
			"#:_______:___:_:_:_:#",
			"#:::::::::::::::_:::#",
			"#####################",
		],
	},
	# the guardian's inner chamber, down the stairs out of the hall's drained pool, the way back up through the door in
	# its west wall (no one else is down here)
	"temple_water": {
		"wall": "#8ab8d8", "rug": "#2a6aa8",
		"npcs": {"1": "guardian"},
		"doors": {"[": "temple_tides_hall"},
		"anchors": {"3": "stone_0", "4": "stone_1", "5": "stone_2", "6": "stone_3", "7": "tablet"},
		"rows": [
			"#################",
			"#o___o..A..o___o#",
			"#.___...1...___.#",
			"#..3..4.:.5..6..#",
			"#o.___.....___.o#",
			"#..___..r..___..#",
			"#o.....rrr.....o#",
			"#..__..rrr..__..#",
			"#o.__..rrr..__.o#",
			"#......rrr......#",
			"#....7.rPr....*.#",
			"[...............#",
			"#################",
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
			"#..3..4...5..6..#",
			"#o.ggg.....ggg.o#",
			"#..ggg..r..ggg..#",
			"#o.....rrr.....o#",
			"#.%%...rrr...%%.#",
			"#o%%...rrr...%%o#",
			"#......rrr......#",
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
			"#..3..4...5..6..#",
			"#o.ggg.....ggg.o#",
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
	## The old log shack on Cocoon Cove's clifftop, at the end of the woodland path: nobody lives there any more, but
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
	"shack": ["shack"],
	"uncle": ["uncle_home"],
	"fishery": ["fishery"],
	"ceo_tower": ["ceo_1", "ceo_2", "ceo_3", "ceo_4"],
	"cathedral": ["cathedral", "crypt_1", "crypt_2"],
}

## The townsfolk's houses (each picks one by its seed): two studios, a house of two rooms, one with an upstairs.
const HOUSES := [["studio_a"], ["studio_b"], ["house_two", "house_two_bed"], ["house_up", "house_up_hall", "house_up_bed"]]

## Rounded timber stage rooms on the Isle of Tides. The entrance stays in the visible eastern side wall.
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
			"   #######w#######   ",
			"  /............1..\\  ",
			" /CCCCCCCCCCCCCCCCC\\ ",
			"#.....3............H#",
			"#..xxxxxxxx.........#",
			"#..x......x.........#",
			"#..x......x........PD",
			"#..x......x......6..#",
			"#..xxxxxxxx.........#",
			"#..4......5......7..#",
			" \\................./ ",
			"  \\.............../  ",
			"   ###############   ",
		],
	},
}

## A hotel lobby and guest suite share the normal room-door system.
const HOTEL_ROOMS := {
	"hotel_lobby": {
		"stage": true, "zone": "hall", "wall": "#f4d5bd", "rug": "#7aa9a0",
		"npcs": {"1": "keeper", "2": "patron"},
		"doors": {"d": "hotel_suite"}, "locked": ["The hotel kitchen. Staff only."],
		"counter_phone": [6, 2],
		"rows": [
			"#####Z#####",
			"#p...1...p#",
			"#CCCCCCCCCw",
			"#.........w",
			"d..2......#",
			"#SS..yy..PD",
			"###########",
		],
		"floor_tex": {"hall": "floor_marble"},
	},
	"hotel_suite": {
		"stage": true, "zone": "bedroom", "wall": "#b8d9d3", "rug": "#d4b38b",
		"doors": {"d": "hotel_lobby"}, "locked": ["Your suite's private bathroom."],
		"rows": [
			"######L######",
			"#NbbN..SS..@w",
			"#.bb........w",
			"#...........#",
			"dP....yy....#",
			"#...........#",
			"#############",
		],
	},
}
