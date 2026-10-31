extends RefCounted
## The world: twelve towns across the regions, the routes between them, arenas, temples and biomes.
## Journey: Coast -> Isle of Tides -> Desert -> Mountains & Cogsworth -> Volcano -> Jungle -> River -> Gravenmoor.

const RaceDB = preload("res://scripts/data/race_db.gd")

## Town progression order (also each town's shop tier).
const TOWN_ORDER := ["caccoon", "tidewater", "shellhaven", "kelpwick", "dustwell", "sundown",
	"copperpick", "cogsworth", "emberfall", "vinehollow", "riverbend", "gravenmoor"]

const TOWNS := {
	"caccoon": {"name": "Cocoon Cove", "size": "hamlet", "mascot": 2, "signature": "bandit_blaze", "biome": "coast",
		"shops": ["center", "apothecary", "home", "house", "house", "bookstore"],
		"blurb": "A spacious hamlet above a rocky cove, home of the Pyrosaur. Its library welcomes new travelers."},
	"tidewater": {"name": "Bellerive", "size": "town", "mascot": 29, "signature": "tidewater_torrent", "biome": "quarter",
		"shops": ["center", "apothecary", "electronics", "beast_gear", "bookstore", "cafe", "arena", "skytower", "house", "house", "house"],
		"blurb": "A French Quarter harbour town of iron balconies and stone quays. Ferries sail from here to the Isle of Tides."},
	"shellhaven": {"name": "Shellhaven", "size": "village", "mascot": 26, "signature": "pearl_cannon", "biome": "island",
		"shops": ["center", "apothecary", "cafe", "house", "house", "house"],
		"blurb": "A fishing village on the west shore of the Isle of Tides."},
	"kelpwick": {"name": "Kelpwick", "size": "village", "mascot": 23, "signature": "kelp_maelstrom", "biome": "island",
		"shops": ["center", "beast_gear", "arena", "house", "house", "house"],
		"blurb": "A village of reef-divers on the east shore of the Isle of Tides."},
	"dustwell": {"name": "Dustwell Oasis", "size": "hamlet", "mascot": 32, "signature": "sirocco", "biome": "desert",
		"shops": ["center", "apothecary", "fortune", "house", "house"],
		"blurb": "The last cool water before the open desert."},
	"sundown": {"name": "Sundown Gulch", "size": "town", "mascot": 38, "signature": "tumbleweed_twister", "biome": "western",
		"shops": ["center", "apothecary", "trainer_gear", "cafe", "bookstore", "arena", "skytower", "house", "house", "house"],
		"blurb": "A frontier town of saloons and dust, plagued by bandits."},
	"copperpick": {"name": "Copperpick", "size": "village", "mascot": 17, "signature": "motherlode", "biome": "mountain",
		"shops": ["center", "apothecary", "dojo", "arena", "house", "house"],
		"blurb": "A mining camp clinging to the mountainside."},
	"cogsworth": {"name": "Cogsworth", "size": "city", "mascot": 14, "signature": "clockwork_crusher", "biome": "steampunk",
		"shops": ["center", "apothecary", "beast_gear", "trainer_gear", "bookstore", "arena", "museum", "music_shop", "cafe", "skytower", "ceo_tower", "house", "house", "house"],
		"blurb": "A city of brass and steam, ruled from the Gearhart Tower."},
	"emberfall": {"name": "Emberfall", "size": "village", "mascot": 11, "signature": "caldera_burst", "biome": "hotspring",
		"shops": ["center", "apothecary", "bookstore", "arena", "dojo", "house", "house"],
		"blurb": "A hot-spring village in the shadow of Mount Cinder."},
	"vinehollow": {"name": "Vinehollow", "size": "village", "mascot": 20, "signature": "elder_grove", "biome": "jungle",
		"shops": ["center", "apothecary", "beast_gear", "trainer_gear", "arena", "house", "house", "house"],
		"blurb": "An ancient jungle village. Its traders sell the finest gear in the land."},
	"riverbend": {"name": "Riverbend", "size": "town", "mascot": 29, "signature": "riverbend_rapids", "biome": "river",
		"shops": ["center", "apothecary", "beast_gear", "bookstore", "cafe", "music_hall", "fortune", "museum", "arena", "skytower", "house", "house", "house"],
		"blurb": "A peaceful river town at the edge of the moors."},
	"gravenmoor": {"name": "Gravenmoor", "size": "town", "mascot": 35, "signature": "moonlit_gale", "biome": "moor",
		"shops": ["center", "apothecary", "trainer_gear", "cathedral", "house", "house", "house"],
		"blurb": "A fog-bound town beside the old graveyard. The Umbral Legion rules here now."},
}

## Each route connects `from` to `to` (to = "" for a dead end); `dir` is the edge of `from` it leaves by.
## races: the first forms of the lines that live there; a wild beast is the form its level gives (RaceDB.for_level).
const ROUTES := {
	"route1": {"name": "Coastal Path", "from": "caccoon", "to": "tidewater", "dir": "east", "biome": "coast", "lv": [2, 4], "races": [0, 27, 36, 24, 15, 30],
		"after_flute": true, "pack": 1},
	"route2": {"name": "Isle Trail", "from": "shellhaven", "to": "kelpwick", "dir": "east", "biome": "island", "lv": [4, 7], "races": [24, 27, 12, 36, 9]},
	"reef": {"name": "Coral Reef", "from": "kelpwick", "to": "", "dir": "east", "biome": "island", "lv": [7, 10], "races": [21, 24, 27]},
	"route3": {"name": "Dune Road", "from": "tidewater", "to": "dustwell", "dir": "north", "biome": "desert", "lv": [10, 13], "races": [30, 15, 3, 33, 9]},
	"route4": {"name": "Mesa Trail", "from": "dustwell", "to": "sundown", "dir": "north", "biome": "mesa", "lv": [12, 16], "races": [36, 6, 12, 3]},
	"route5": {"name": "Dune Sea", "from": "sundown", "to": "copperpick", "dir": "north", "biome": "desert", "lv": [16, 22], "races": [33, 0, 15, 30, 21], "temple": "air"},
	"route6": {"name": "Mine Road", "from": "copperpick", "to": "cogsworth", "dir": "east", "biome": "mountain", "lv": [20, 25], "races": [15, 12, 6, 18], "legion": true},
	"route7": {"name": "Caldera Road", "from": "cogsworth", "to": "emberfall", "dir": "north", "biome": "volcano", "lv": [26, 31], "races": [9, 0, 6, 3], "temple": "fire"},
	"route8": {"name": "Summit Pass", "from": "emberfall", "to": "vinehollow", "dir": "west", "biome": "mountain", "lv": [30, 36], "races": [30, 36, 33, 18, 27], "legion": true},
	"route9": {"name": "Jungle Trail", "from": "vinehollow", "to": "riverbend", "dir": "south", "biome": "jungle", "lv": [34, 40], "races": [18, 27, 36, 24, 0], "temple": "earth"},
	"route10": {"name": "Moor Road", "from": "riverbend", "to": "gravenmoor", "dir": "east", "biome": "moor", "lv": [40, 46], "races": [33, 21, 6, 36], "legion": true, "ghosts": 0.2},
}

## The four elemental temples, and Gravenmoor's crypt. Each holds a guardian beast that can't be beaten, only
## captured: wear it down and play the temple's song (song; the singing stones in its room teach it, Places.song_stone).
## A captured guardian becomes a summon (GameState.summons, the battle's Summon command). helpers: the beasts that
## fight beside it (the first temple's guardian brings one).
const TEMPLES := {
	"water": {"name": "Temple of Tides", "route": "reef", "room": "temple_water", "guardian": 39, "level": 12, "glow": "#5ac8ff",
		"element": "water", "song": "song_tides", "helpers": [21]},
	"air": {"name": "Temple of Winds", "route": "route5", "room": "temple_air", "guardian": 40, "level": 30, "glow": "#c8fff0",
		"element": "air", "song": "song_winds", "helpers": [33, 36]},
	"fire": {"name": "Temple of Flame", "route": "route7", "room": "temple_fire", "guardian": 41, "level": 40, "glow": "#ff7a3a",
		"element": "fire", "song": "song_flame", "helpers": [3, 6]},
	"earth": {"name": "Temple of Roots", "route": "route9", "room": "temple_earth", "guardian": 42, "level": 48, "glow": "#7ae05a",
		"element": "earth", "song": "song_roots", "helpers": [18, 12]},
	"ghost": {"name": "Gravenmoor Crypt", "route": "gravenmoor", "room": "crypt_1", "guardian": 47, "level": 48, "glow": "#a56bff",
		"element": "ghost", "song": "song_dusk", "helpers": [33, 21], "ghost": true},
}


## The temple whose guardian and singing stones a room holds ("water", ..., "ghost"), or "".
static func temple_for_room(room: String) -> String:
	for tk in TEMPLES:
		if String(TEMPLES[tk]["room"]) == room:
			return tk
	return ""

## Field obstacles drawn into the maps. A beast in your party of a listed element clears them.
const OBSTACLES := {
	"w": {"name": "pile of driftwood", "kind": "driftwood", "elements": ["fire", "water", "earth", "air"], "clear": "path"},
	"j": {"name": "thicket of thorny brambles", "kind": "vines", "elements": ["air", "fire"], "clear": "grass"},
	"d": {"name": "sand drift", "kind": "sand", "elements": ["water", "air"], "clear": "sand"},
	"o": {"name": "huge boulder", "kind": "boulder", "elements": ["earth"], "clear": "path"},
	"y": {"name": "swirling dust storm", "kind": "dust", "elements": ["air"], "clear": "path"},
	"l": {"name": "stream of lava", "kind": "lava", "elements": ["water"], "clear": "path"},
	"i": {"name": "wall of ice", "kind": "ice", "elements": ["fire"], "clear": "path"},
	"|": {"name": "deep ravine", "kind": "chasm", "elements": ["earth"], "clear": "bridge"},
	"x": {"name": "wooden barricade", "kind": "barricade", "elements": ["fire"], "clear": "path"},
	"m": {"name": "bank of cold fog", "kind": "fog", "elements": ["air"], "clear": "grass"},
	# route puzzles: "item" = fixed with a key item, "flyer" = needs a beast with wings
	"n": {"name": "washed-out footbridge", "kind": "broken_bridge", "elements": [], "item": "bridge_log", "need": 5, "clear": "bridge"},
	"k": {"name": "sheer cliff", "kind": "rope_cliff", "elements": [], "flyer": true, "clear": "rope"},
}
const FIELD_VERBS := {
	"fire": "burned it away", "water": "washed it away", "air": "blew it away", "earth": "smashed it apart",
}

## The Coastal Path's teachers (see battle.gd LESSONS, and story.gd for how they're placed and talk). Each looks
## across the trail where you can't slip past them (tools/check_maps.gd checks it), so they spot you and walk you
## through one part of battling, before you have a flute; the last one sets "tutorial_done". Youngster Kit lives in
## the log cabin by the washed-out footbridge, looking at his door, and his gift is the logs to mend it (story.gd
## logs_missing).
## lines: before the battle; after: once you've won; defeat: when you talk to them again; gift: items they give you.
const LESSON_TRAINERS := [
	{"anchor": "lesson_screen", "lesson": "screen", "name": "Tilly", "cls": "Camper", "team": [[27, 2]], "facing": Vector2i(0, 1),
		"look": {"skin": "#f0c8a0", "hair": "#a06030", "hair_style": 1, "shirt": "#6aa84f", "pants": "#5a4a3a", "hat": "#d8b060"},
		"lines": ["Hey hey, a new trainer! Everyone who walks the Coastal Path gets a lesson from us. It's tradition. We started it last Tuesday."],
		"after": ["That's the battle screen! Keep heading along the trail. Fisher Dale will teach you about turns. He's very patient. He's a fisher."],
		"defeat": "Your own bar comes first, then one for each beast. Left and right to choose, A to confirm, B to go back!"},
	{"anchor": "lesson_turns", "lesson": "turns", "name": "Dale", "cls": "Fisher", "team": [[36, 2]], "facing": Vector2i(0, -1),
		"look": {"skin": "#c08a60", "hair": "#303040", "shirt": "#3a6a9a", "pants": "#4a4a52", "hat": "#e8c040"},
		"lines": ["Shh, the fish are bit... oh, a trainer! Never mind the fish. They never bite anyway. Let's talk about turns."],
		"after": ["Patience wins battles, and Defend buys you time. Youngster Kit hangs about on the trail by the creek. He'll show you your own turn. He's VERY excited about it."],
		"defeat": "Everyone picks first, then the faster side goes. Defend always goes first and halves the hurt."},
	{"anchor": "lesson_slingshot", "lesson": "slingshot", "name": "Kit", "cls": "Youngster", "team": [[24, 3]], "facing": Vector2i(0, 1),
		"look": {"skin": "#e0b088", "hair": "#5a3a20", "hair_style": 0, "shirt": "#e07a5a", "pants": "#3a4a6a"},
		"lines": ["Hey! You! You've got a slingshot, right? EVERY trainer has a slingshot! I'll show you what yours is for!"],
		"after": ["The footbridge is out, did you see? Old Hal the builder lives in the cabin by the creek. Ask him about it!",
			"Picnicker Mae is over on the far side. Bring an appetite."],
		"defeat": "Your own bar: Slingshot, Items, Watch... and Run from wild beasts, or Forfeit against trainers."},
	{"anchor": "lesson_items", "lesson": "items", "name": "Mae", "cls": "Picnicker", "team": [[15, 3]], "facing": Vector2i(0, 1),
		"gift": {"minor_potion": 3},
		"look": {"skin": "#f8d8c0", "hair": "#e0c070", "hair_style": 1, "shirt": "#e8a0c0", "pants": "#6a5a8a"},
		"lines": ["Is that a beast? Is it hungry? Never mind. Let's talk about the most important thing in a battle: snacks. I mean items."],
		"after": ["Take these for the road: three Minor Potions! Ranger Holt waits just before Bellerive with the last lesson."],
		"defeat": "Potions heal HP and Spirit Drops bring back MP. Apothecaries sell them. Picnic baskets don't. I checked."},
	{"anchor": "lesson_ring", "lesson": "ring", "name": "Holt", "cls": "Ranger", "team": [[30, 3]], "facing": Vector2i(0, -1),
		"look": {"skin": "#8a5a3a", "hair": "#2a1a10", "shirt": "#5a7a3a", "pants": "#4a3a2a", "hat": "#4a6a2a"},
		"lines": ["Halt! Rangers check every new trainer before Bellerive. Relax, it's a lesson, not a test. Well. A little bit a test."],
		"after": ["You're ready. Shields recharge after every battle, and Volt at Sparkwire Electronics can add shield points and beast slots for crystal shards.",
			"Now go and see your uncle! Bellerive's just along the trail."],
		"defeat": "Knock out the foe's middle beast, then hit the trainer. No shield left? That trainer loses."},
]

## Bellerive's arena coaches (battle.gd LESSONS "team" and "elements"): before you may challenge Tide Captain Marina,
## and so before Captain Gull sails you to the Isle of Tides, Coach Rory teaches battling with a whole side of your
## ring and Coach Ondine elemental weaknesses (her beast is weak to your side's element, see story.gd
## _elements_lesson). They wait in the lobby of Bellerive's arena (interior_maps.gd "arena" anchors): Rory above the
## side entrance looking down at it. Only Rory approaches on entry; Ondine waits to be spoken to, keeping the
## entrance's other escape tile free after Rory's lesson.
## needs: a lesson to have had first (until then, that coach doesn't notice you).
const ARENA_LESSONS := [
	{"anchor": "lesson_team", "lesson": "team", "town": "tidewater", "name": "Rory", "cls": "Coach", "team": [[27, 4], [33, 4]],
		"facing": Vector2i(0, 1), "look": {"skin": "#c8946a", "hair": "#3a2a1a", "hair_style": 0, "shirt": "#2f6fb0", "pants": "#2a2a3a", "hat": "#f0f0f0"},
		"lines": ["Ahoy! I'm Coach Rory. Nobody faces Tide Captain Marina without a lesson from me and one from Coach Ondine. Arena rules!",
			"Today: fighting as a team. One beast is a pet. Three beasts is a crew!"],
		"after": ["That's teamwork! Every beast on the side facing the foe gets a move each round, so a full side hits three times as hard.",
			"Fill your ring's sides with beasts and you'll never fight alone. Now go and see Coach Ondine about elements."],
		"defeat": "Up and down move between your beasts' bars. Every beast on the side facing the foe gets a move!"},
	{"anchor": "lesson_elements", "lesson": "elements", "town": "tidewater", "needs": "lesson_team", "name": "Ondine", "cls": "Coach",
		"team": [[36, 4]], "facing": Vector2i(1, 0), "manual_only": true,
		"look": {"skin": "#f0c8a0", "hair": "#30a0b0", "hair_style": 1, "shirt": "#e8e0c0", "pants": "#3a5a7a"},
		"first": "Coach Rory's lesson comes first, sweetie. Teamwork, then elements. I don't make the rules. Rory does. Loudly.",
		"lines": ["I'm Coach Ondine. Let's talk elements: the secret to beating beasts bigger than yours."],
		"after": ["Remember the wheel: fire is weak to air, earth to water, water to air, and air to fire.",
			"Tide Captain Marina's beasts are all water... and water is weak to air. Just saying! She's waiting for you in the ring."],
		"defeat": "Look for the ★ beside a move and ★ WEAK on a target's card: that's double damage!"},
]

## Arena leaders. element: eggs the master buys for twice the Beast Center offer.
## team: [race, level] (a line's first form: the level picks the form). Each teaches a flute song.
const ARENAS := {
	"tidewater": {"element": "water", "leader": "Marina", "title": "Tide Captain", "team": [[24, 9], [27, 9], [21, 10]], "song": "shanty", "crest": "Wave Crest", "gold": 900, "look": {"shirt": "#2f6fb0", "hair": "#203048", "hat": "#f0f0f0"}},
	"kelpwick": {"element": "water", "leader": "Nerissa", "title": "Reef Warden", "team": [[21, 15], [27, 15], [24, 16]], "song": "coral", "flute": "lullaby", "crest": "Coral Crest", "gold": 1300, "look": {"shirt": "#e07a8a", "hair": "#30a0b0"}},
	"sundown": {"element": "air", "leader": "Rosa", "title": "Gunslinger", "team": [[36, 21], [3, 21], [12, 22]], "song": "reel", "crest": "Spur Crest", "gold": 1800, "look": {"shirt": "#8a4a2a", "hair": "#2a1a10", "hat": "#6a4a2a"}},
	"copperpick": {"element": "earth", "leader": "Gorran", "title": "Mine Foreman", "team": [[15, 27], [9, 27], [6, 28]], "song": "dirge", "crest": "Ore Crest", "gold": 2400, "look": {"shirt": "#5a6070", "hair": "#806040", "hat": "#e8c040", "outfit": "coat"}},
	"cogsworth": {"element": "earth", "leader": "Volta", "title": "Chief Engineer", "team": [[30, 33], [0, 33], [12, 34]], "song": "anvil", "flute": "static", "crest": "Cog Crest", "gold": 3000, "look": {"shirt": "#6a4a3a", "hair": "#f0f0f0", "hat": "#c8a040", "outfit": "apron"}},
	"emberfall": {"element": "fire", "leader": "Brann", "title": "Forgemaster", "team": [[9, 39], [3, 39], [0, 40]], "song": "waltz", "crest": "Flame Crest", "gold": 3800, "look": {"shirt": "#8a2a1e", "hair": "#2a1a10", "outfit": "apron"}},
	"vinehollow": {"element": "earth", "leader": "Aeris", "title": "Jungle Huntress", "team": [[18, 45], [24, 45], [15, 46]], "song": "fanfare", "flute": "minuet", "crest": "Vine Crest", "gold": 4600, "look": {"shirt": "#4a7a3a", "hair": "#e8e0c0", "outfit": "robe"}},
	"riverbend": {"element": "water", "leader": "Skye", "title": "River Ranger", "team": [[36, 51], [27, 51], [30, 52]], "song": "anthem", "crest": "River Crest", "gold": 5500, "look": {"shirt": "#3a6ab0", "hair": "#f0d070", "hat": "#3a5a3a"}},
}

const BIOMES := {
	"coast": {"ground": "#7cc05a", "side": "#9a7a50", "sand": "#ecd8a0", "path": "#c8a878", "plaza": "#c8c0b0", "tuft": "#5aa040",
		"trees": [["palm", 2], ["palm_bent", 1], ["tree_dome", 2], ["tree_oak", 2], ["tree_birch", 1], ["tree_round_2", 1], ["tree_cypress", 1]], "rocks": ["beach_rock", "rock_small"],
		"shrubs": ["shrub_1", "shrub_3", "shrub_4", "bush_1", "bush_2"], "mixed": 0.35,
		"sky_top": "#4aa8f0", "sky_hz": "#d8f0f8", "sun": "#fff8e8", "sun_e": 1.3, "amb": 0.6, "style": "coastal", "water": "#3a90e0", "music": "coast"},
	# Bellerive's French Quarter: the coast's sky and sea, but a town of stone: cobbled streets ("paving", stone_streets:
	# world.gd draws its paths as setts), warm flagstone sidewalks and squares, live oaks and palms, Creole buildings.
	"quarter": {"ground": "#78b858", "side": "#9a8a70", "sand": "#e6d6a8", "path": "#8e8a84", "plaza": "#d4bfa4", "tuft": "#5aa040",
		"paving": "#9a948c", "stone_streets": true,
		"trees": [["tree_oak", 3], ["palm", 2], ["tree_round_1", 1]], "rocks": ["rock_small"],
		"shrubs": ["shrub_1", "shrub_3", "bush_1", "bush_2"], "mixed": 0.3,
		"sky_top": "#4aa8f0", "sky_hz": "#e0eef4", "sun": "#fff4e0", "sun_e": 1.3, "amb": 0.62, "style": "creole", "water": "#3a8ad0", "music": "coast"},
	"island": {"ground": "#6ac050", "side": "#9a7a50", "sand": "#f0e0a8", "path": "#d8b880", "plaza": "#d8ccb0", "tuft": "#4ab040",
		"trees": [["palm", 3], ["palm_bent", 2], ["tree_dome", 1]], "rocks": ["beach_rock", "rock_small"], "shrubs": ["shrub_2", "shrub_1"],
		"sky_top": "#3ab0f0", "sky_hz": "#e0f8f8", "sun": "#fffae8", "sun_e": 1.4, "amb": 0.62, "style": "island", "water": "#2aa8d8", "music": "island"},
	"desert": {"ground": "#e2c890", "side": "#b8945a", "sand": "#ecd8a0", "path": "#c8a070", "plaza": "#d8c098", "tuft": "#b8a050",
		"trees": [["cactus_1", 2], ["cactus_2", 2], ["cactus_3", 1]], "rocks": ["field_rock", "bones_1", "bones_2", "stone_2"], "shrubs": ["bush_1", "bush_2"],
		"sky_top": "#5aa8e8", "sky_hz": "#f8e8c8", "sun": "#fff0d0", "sun_e": 1.5, "amb": 0.62, "style": "adobe", "water": "#3a9ad8", "music": "desert"},
	"western": {"ground": "#d8b880", "side": "#a8804a", "sand": "#e2c890", "path": "#b89060", "plaza": "#c8a878", "tuft": "#a89848",
		"trees": [["cactus_2", 2], ["cactus_1", 1], ["dead_tree", 1]], "rocks": ["field_rock", "bones_3", "stone_4"], "shrubs": ["bush_3", "bush_1"],
		"sky_top": "#5aa0e0", "sky_hz": "#f8dcb0", "sun": "#ffe8c0", "sun_e": 1.45, "amb": 0.6, "style": "western", "water": "#3a9ad8", "music": "western"},
	"mesa": {"ground": "#d8946a", "side": "#a85a3a", "sand": "#e2b080", "path": "#c8906a", "plaza": "#c8a080", "tuft": "#a8984a",
		"trees": [["cactus_1", 2], ["dead_tree", 1]], "rocks": ["mountain_3", "mountain_6", "field_rock"], "shrubs": ["bush_2"],
		"sky_top": "#5aa0e0", "sky_hz": "#f8d0a8", "sun": "#ffe0b8", "sun_e": 1.45, "amb": 0.58, "style": "western", "water": "#3a9ad8", "music": "western"},
	"mountain": {"ground": "#8a9a6a", "side": "#6a6058", "sand": "#b8b0a0", "path": "#9a8a70", "plaza": "#a8a49a", "tuft": "#6a8a4a",
		"trees": [["tree_pine", 3], ["tree_birch", 1], ["tree_cypress", 1], ["tree_cypress_slim", 1]], "rocks": ["mountain_0", "mountain_2", "mountain_5", "rock_big"], "shrubs": ["shrub_3", "bush_3"],
		"sky_top": "#6ab0f0", "sky_hz": "#e8f4f8", "sun": "#ffffff", "sun_e": 1.3, "amb": 0.6, "style": "mining", "water": "#3a8ad0", "music": "mountain"},
	"steampunk": {"ground": "#7a7a72", "side": "#5a5a58", "sand": "#a89a80", "path": "#6a6a68", "plaza": "#8a847a", "tuft": "#5a7a40",
		"trees": [["tree_round_2", 1]], "rocks": ["crates", "barrel"], "shrubs": ["shrub_1"],
		"sky_top": "#8a9ab0", "sky_hz": "#e0d0b8", "sun": "#ffe8c8", "sun_e": 1.2, "amb": 0.55, "style": "steampunk", "water": "#4a7a9a", "music": "steampunk"},
	"volcano": {"ground": "#5a4a44", "side": "#3a2e2a", "sand": "#7a6a5a", "path": "#6a5a50", "plaza": "#6a5e58", "tuft": "#6a6a3a",
		"trees": [["dead_tree", 2], ["stump", 1]], "rocks": ["mountain_1", "mountain_8", "stone_5"], "shrubs": ["stone_5", "stone_3"],
		"sky_top": "#a05a48", "sky_hz": "#f0b080", "sun": "#ffc090", "sun_e": 1.2, "amb": 0.5, "style": "hotspring", "water": "#ff6a20", "lava": true, "music": "volcano"},
	"hotspring": {"ground": "#6a8a5a", "side": "#5a4a40", "sand": "#a89a80", "path": "#8a7a68", "plaza": "#9a948a", "tuft": "#5a8a4a",
		"trees": [["tree_pine", 2], ["dead_tree", 1]], "rocks": ["mountain_7", "rock_big"], "shrubs": ["shrub_3"],
		"sky_top": "#8a8aa8", "sky_hz": "#f0c8a8", "sun": "#ffd8b0", "sun_e": 1.25, "amb": 0.55, "style": "hotspring", "water": "#6ac8d8", "music": "hotspring"},
	"jungle": {"ground": "#3f8a3a", "side": "#5a4028", "sand": "#a89060", "path": "#8a7048", "plaza": "#8a8a70", "tuft": "#3aa03a",
		"trees": [["tree_big", 3], ["tree_oak", 2], ["palm", 1]], "rocks": ["mossy_statue", "rock_big"], "shrubs": ["shrub_2", "shrub_4", "shrub_1"],
		"sky_top": "#5aa0c8", "sky_hz": "#d8f0d0", "sun": "#fff4d0", "sun_e": 1.2, "amb": 0.55, "style": "jungle", "water": "#3a9a9a", "music": "jungle"},
	"river": {"ground": "#6ab050", "side": "#8a6a48", "sand": "#d8c890", "path": "#b89a6a", "plaza": "#b8b0a0", "tuft": "#5aa040",
		"trees": [["tree_oak", 2], ["tree_birch", 1], ["tree_round_1", 1]], "rocks": ["rock_small", "field_rock"], "shrubs": ["shrub_1", "shrub_3"],
		"sky_top": "#5aa0e8", "sky_hz": "#e0f0f0", "sun": "#fff0d0", "sun_e": 1.3, "amb": 0.6, "style": "town", "water": "#3a8ad8", "music": "river"},
	"moor": {"ground": "#4a5a48", "side": "#3a3430", "sand": "#7a7468", "path": "#6a6258", "plaza": "#6a6a70", "tuft": "#5a6a48",
		"trees": [["dead_tree", 3], ["stump", 1]], "rocks": ["grave_1w", "grave_2w", "tomb_2", "stone_1"], "shrubs": ["bush_3"],
		"sky_top": "#3a3a58", "sky_hz": "#9a8aa0", "sun": "#c8b8ff", "sun_e": 0.9, "amb": 0.5, "style": "gothic", "water": "#3a4a6a", "fog": 0.016, "music": "moor"},
}

const TRAINER_NAMES := ["Pip", "Rosa", "Tomas", "Ivy", "Bram", "Lena", "Otto", "Mira", "Kai", "Juno", "Felix", "Nell",
	"Hugo", "Wren", "Ada", "Cyrus", "Dot", "Ezra", "Faye", "Gus", "Hana", "Ian", "Jade", "Knox", "Lux", "Moss",
	"Nia", "Orin", "Pell", "Quinn", "Remy", "Sage", "Tula", "Uri", "Vera", "Wes", "Bizcuit"]
const TRAINER_CLASSES := ["Hiker", "Beast Tamer", "Wanderer", "Fisher", "Bird Keeper", "Ace Trainer", "Scout", "Picnicker"]

## Route trainers who carry a flute and play a song in battle (index = trainer in reading order).
## Beat them and play the song back without a mistake to learn it; they'll battle again for an encore.
const BARDS := {
	"route2": {"index": 0, "name": "Tamsin", "song": "jig", "skill": 0.75},
	"route3": {"index": 0, "name": "Wren", "song": "dazzle", "skill": 0.8},
	"route4": {"index": 1, "name": "Silas", "song": "venom", "skill": 0.8},
	"route8": {"index": 0, "name": "Oriel", "song": "mending", "skill": 0.85},
}

const TIPS := [
	"Fire beasts hit hard and can take a beating. Air beasts make them sweat, though.",
	"Water beasts are the best healers around. Earth beasts hate getting splashed.",
	"Earth beasts can shield their friends. Put one up front!",
	"Air beasts are slippery tricksters. Fire burns right through their tricks.",
	"Beat wild beasts and sometimes they leave an egg behind. A Beast Center can hatch it!",
	"Once two beasts in their final form hit their level limit, a Beast Center can merge them into one stronger beast.",
	"A beast grows up as it levels: into a new form at Lv 20, and into its last at Lv 40. Even a tiny hatchling has a lot ahead of it!",
	"Your beasts' elemental moves work outside battle too. Vines burn, sand washes away, boulders shatter!",
	"Crystal shards are hidden all over. Five of them buy a shield upgrade at the Bellerive electronics shop.",
	"If all your beasts faint, enemies go after you. Your shield is all that stands between you and defeat!",
	"You can throw items in battle too: bombs, powders, tonics. Don't forget your own turn!",
	"The bird at the top of a Sky Tower can fly you to any town you've visited.",
	"Raise an air beast to Lv 40, its final form, and it can carry you anywhere!",
	"The better you play Capture, the more likely a wild beast is to join you. Play it flawlessly to win over a beast stronger than yours!",
	"Once one of your beasts reaches your Capture level, practise the next level from the Flute page of your book.",
	"Flute songs aren't just for charming. Some lift your team's spirits, others sap the foe's strength!",
	"A few trainers carry flutes. Listen closely: play their song back perfectly and it's yours.",
	"The music shop in Cogsworth sells sheet music. The Maestro there will even play you one song for free.",
	"You can't charm another trainer's beasts. That would be stealing!",
	"Wild beasts wander in the open. Creep up behind one and you'll catch it off guard. Hide in tall grass and they'll have a harder time spotting you!",
	"Wild beasts stronger than yours come running when they see you. The weaker ones bolt!",
	"You can send three beasts into battle at once. Pick a good mix!",
	"Bookstores sell tomes that teach beasts brand new moves.",
	"People say each of the four elemental temples hides a guardian beast of incredible power.",
]

## Positions on the world map screen.
const MAP_POS := {
	"caccoon": Vector2(40, 430), "tidewater": Vector2(200, 430), "shellhaven": Vector2(330, 470), "kelpwick": Vector2(470, 470),
	"dustwell": Vector2(200, 330), "sundown": Vector2(200, 230), "copperpick": Vector2(200, 110), "cogsworth": Vector2(380, 110),
	"emberfall": Vector2(380, 0), "vinehollow": Vector2(580, 0), "riverbend": Vector2(580, 160), "gravenmoor": Vector2(760, 160),
}
const ROUTE_PATHS := {
	"reef": [Vector2(470, 470), Vector2(600, 470)],
}
## The ferry between Bellerive and Shellhaven (drawn on the map, travelled by boat).
const FERRY := ["tidewater", "shellhaven"]


## Shop tier per town (progression order). Vinehollow is special: tier 12 unlocks premium jungle goods.
static func town_tier(id: String) -> int:
	if id == "vinehollow":
		return 12
	return maxi(0, TOWN_ORDER.find(id))


## What a town's mascot statue is cast in: bronze along the coast and the isles, silver from the desert to the
## mountains, gold in the far towns.
static func statue_metal(id: String) -> String:
	var tier := town_tier(id)
	return "bronze" if tier < 4 else ("silver" if tier < 8 else "gold")


static func is_town(id: String) -> bool:
	return TOWNS.has(id)


static func map_name(id: String) -> String:
	if TOWNS.has(id):
		return TOWNS[id]["name"]
	if ROUTES.has(id):
		return ROUTES[id]["name"]
	return id


static func opposite(dir: String) -> String:
	return {"north": "south", "south": "north", "east": "west", "west": "east"}.get(dir, "south")


## Edges of a town: dir -> route id
static func town_edges(town: String) -> Dictionary:
	var out := {}
	for rid in ROUTES:
		var r: Dictionary = ROUTES[rid]
		if r["from"] == town:
			out[r["dir"]] = rid
		elif r["to"] == town:
			out[opposite(r["dir"])] = rid
	return out


## Edges of a route: dir -> town id
static func route_edges(rid: String) -> Dictionary:
	var r: Dictionary = ROUTES[rid]
	var out := {opposite(r["dir"]): r["from"]}
	if r["to"] != "":
		out[r["dir"]] = r["to"]
	return out


static func biome_of(map_id: String) -> Dictionary:
	var b := "coast"
	var base := map_id.get_slice("#", 0)
	if TOWNS.has(base):
		b = TOWNS[base]["biome"]
	elif ROUTES.has(base):
		b = ROUTES[base]["biome"]
	var d: Dictionary = BIOMES[b].duplicate()
	d["id"] = b
	return d


## Neighbouring maps (towns <-> routes, plus the ferry).
static func neighbours(id: String) -> Array:
	var out: Array = (town_edges(id) if TOWNS.has(id) else (route_edges(id) if ROUTES.has(id) else {})).values()
	if id == FERRY[0]:
		out.append(FERRY[1])
	elif id == FERRY[1]:
		out.append(FERRY[0])
	return out


## The closest visited town (by number of maps travelled) - every town has a Beast Center.
static func nearest_center(from_id: String, visited: Array) -> String:
	var start := from_id.get_slice("#", 0)
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if TOWNS.has(cur) and visited.has(cur):
			return cur
		for n in neighbours(cur):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return "caccoon"


## Map-specific music (otherwise the biome's), and the music for each kind of room.
const MAP_MUSIC := {"caccoon": "home", "route8": "summit", "tidewater": "andreas"}
const ROOM_MUSIC := {
	"temple": "temple", "cathedral": "crypt", "hideout": "hideout", "ceo_tower": "krampus", "arena": "arena",
	"center": "center", "house": "house", "home": "house", "uncle": "house", "museum": "house", "music_hall": "house",
	"cafe": "silly", "music_shop": "silly", "fortune": "silly",
}
## Ambient loops layered under the music.
const BIOME_AMBIENCE := {"desert": "wind", "mesa": "wind", "mountain": "wind", "moor": "ghostly"}
const ROOM_AMBIENCE := {"cathedral": "ghostly", "ceo_tower": "machines"}


## The wild level range around a town (for trade boards etc.)
static func level_near(town: String) -> Array:
	var best := [2, 5]
	for rid in ROUTES:
		var r: Dictionary = ROUTES[rid]
		if r["from"] == town:
			return r["lv"]
		if r["to"] == town:
			best = r["lv"]
	return best


## The forms a route's wild beasts can be at its levels: a line's first form on the early roads, its second and third
## further on (Lv 20 and Lv 40, RaceDB.EVOLVE).
static func route_forms(rid: String) -> Array:
	var r: Dictionary = ROUTES[rid]
	var out := []
	for x in r["races"]:
		for f in range(RaceDB.for_level(int(x), int(r["lv"][0])), RaceDB.for_level(int(x), int(r["lv"][1])) + 1):
			out.append(f)
	return out


## Wild beasts of the region near a town (used for trade boards).
static func races_near(town: String) -> Array:
	var out := []
	for rid in ROUTES:
		var r: Dictionary = ROUTES[rid]
		if r["from"] == town or r["to"] == town:
			out += r["races"]
	return out if not out.is_empty() else [0, 15, 36, 27]
