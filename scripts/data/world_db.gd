extends RefCounted
## The world: twelve towns across the regions, the routes between them, arenas, temples and biomes.
## Journey: Coast -> Isle of Tides -> Desert -> Mountains & Cogsworth -> Volcano -> Jungle -> River -> Gravenmoor.

## Town progression order (also each town's shop tier).
const TOWN_ORDER := ["caccoon", "tidewater", "shellhaven", "kelpwick", "dustwell", "sundown",
	"copperpick", "cogsworth", "emberfall", "vinehollow", "riverbend", "gravenmoor"]

const TOWNS := {
	"caccoon": {"name": "Cocoon Cove", "size": "hamlet", "mascot": 0, "biome": "coast",
		"shops": ["center", "apothecary", "home", "house", "house"],
		"blurb": "A sleepy seaside hamlet, home of the Redcoon."},
	"tidewater": {"name": "Tidewater", "size": "town", "mascot": 13, "biome": "coast",
		"shops": ["center", "apothecary", "electronics", "beast_gear", "bookstore", "cafe", "arena", "skytower", "house", "house", "house"],
		"blurb": "A busy harbour town. Ferries sail from here to the Isle of Tides."},
	"shellhaven": {"name": "Shellhaven", "size": "village", "mascot": 20, "biome": "island",
		"shops": ["center", "apothecary", "cafe", "house", "house", "house"],
		"blurb": "A fishing village on the west shore of the Isle of Tides."},
	"kelpwick": {"name": "Kelpwick", "size": "village", "mascot": 14, "biome": "island",
		"shops": ["center", "beast_gear", "arena", "house", "house", "house"],
		"blurb": "A village of reef-divers on the east shore of the Isle of Tides."},
	"dustwell": {"name": "Dustwell Oasis", "size": "hamlet", "mascot": 45, "biome": "desert",
		"shops": ["center", "apothecary", "fortune", "house", "house"],
		"blurb": "The last cool water before the open desert."},
	"sundown": {"name": "Sundown Gulch", "size": "town", "mascot": 37, "biome": "western",
		"shops": ["center", "apothecary", "trainer_gear", "cafe", "bookstore", "arena", "skytower", "house", "house", "house"],
		"blurb": "A frontier town of saloons and dust, plagued by bandits."},
	"copperpick": {"name": "Copperpick", "size": "village", "mascot": 32, "biome": "mountain",
		"shops": ["center", "apothecary", "dojo", "arena", "house", "house"],
		"blurb": "A mining camp clinging to the mountainside."},
	"cogsworth": {"name": "Cogsworth", "size": "city", "mascot": 34, "biome": "steampunk",
		"shops": ["center", "apothecary", "beast_gear", "trainer_gear", "bookstore", "arena", "museum", "music_shop", "cafe", "skytower", "ceo_tower", "house", "house", "house"],
		"blurb": "A city of brass and steam, ruled from the Gearhart Tower."},
	"emberfall": {"name": "Emberfall", "size": "village", "mascot": 7, "biome": "hotspring",
		"shops": ["center", "apothecary", "bookstore", "arena", "dojo", "house", "house"],
		"blurb": "A hot-spring village in the shadow of Mount Cinder."},
	"vinehollow": {"name": "Vinehollow", "size": "village", "mascot": 31, "biome": "jungle",
		"shops": ["center", "apothecary", "beast_gear", "trainer_gear", "arena", "house", "house", "house"],
		"blurb": "An ancient jungle village. Its traders sell the finest gear in the land."},
	"riverbend": {"name": "Riverbend", "size": "town", "mascot": 21, "biome": "river",
		"shops": ["center", "apothecary", "beast_gear", "bookstore", "cafe", "music_hall", "fortune", "museum", "arena", "skytower", "house", "house", "house"],
		"blurb": "A peaceful river town at the edge of the moors."},
	"gravenmoor": {"name": "Gravenmoor", "size": "town", "mascot": 41, "biome": "moor",
		"shops": ["center", "apothecary", "trainer_gear", "cathedral", "house", "house", "house"],
		"blurb": "A fog-bound town beside the old graveyard. The Umbral Legion rules here now."},
}

## Each route connects `from` to `to` (to = "" for a dead end); `dir` is the edge of `from` it leaves by.
const ROUTES := {
	"route1": {"name": "Coastal Path", "from": "caccoon", "to": "tidewater", "dir": "east", "biome": "coast", "lv": [1, 2], "races": [0, 21, 38, 12, 25, 36]},
	"route2": {"name": "Isle Trail", "from": "shellhaven", "to": "kelpwick", "dir": "east", "biome": "island", "lv": [6, 10], "races": [13, 20, 24, 46, 2]},
	"reef": {"name": "Coral Reef", "from": "kelpwick", "to": "", "dir": "east", "biome": "island", "lv": [10, 14], "races": [14, 16, 17, 18]},
	"route3": {"name": "Dune Road", "from": "tidewater", "to": "dustwell", "dir": "north", "biome": "desert", "lv": [9, 13], "races": [45, 28, 1, 41, 33]},
	"route4": {"name": "Mesa Trail", "from": "dustwell", "to": "sundown", "dir": "north", "biome": "mesa", "lv": [12, 16], "races": [37, 8, 30, 5]},
	"route5": {"name": "Dune Sea", "from": "sundown", "to": "copperpick", "dir": "north", "biome": "desert", "lv": [16, 22], "races": [42, 3, 27, 40, 29], "temple": "air"},
	"route6": {"name": "Mine Road", "from": "copperpick", "to": "cogsworth", "dir": "east", "biome": "mountain", "lv": [20, 25], "races": [32, 34, 10, 26], "legion": true},
	"route7": {"name": "Caldera Road", "from": "cogsworth", "to": "emberfall", "dir": "north", "biome": "volcano", "lv": [26, 31], "races": [4, 9, 6, 7], "temple": "fire"},
	"route8": {"name": "Summit Pass", "from": "emberfall", "to": "vinehollow", "dir": "west", "biome": "mountain", "lv": [30, 36], "races": [39, 44, 43, 35, 19], "legion": true},
	"route9": {"name": "Jungle Trail", "from": "vinehollow", "to": "riverbend", "dir": "south", "biome": "jungle", "lv": [34, 40], "races": [31, 15, 47, 22, 11], "temple": "earth"},
	"route10": {"name": "Moor Road", "from": "riverbend", "to": "gravenmoor", "dir": "east", "biome": "moor", "lv": [40, 46], "races": [23, 41, 9, 38], "legion": true, "ghosts": 0.2},
}

## The four elemental temples. Each holds a guardian beast whose defeat leaves a legendary egg.
const TEMPLES := {
	"water": {"name": "Temple of Tides", "route": "reef", "room": "temple_water", "guardian": 48, "level": 22, "glow": "#5ac8ff", "element": "water"},
	"air": {"name": "Temple of Winds", "route": "route5", "room": "temple_air", "guardian": 49, "level": 30, "glow": "#c8fff0", "element": "air"},
	"fire": {"name": "Temple of Flame", "route": "route7", "room": "temple_fire", "guardian": 50, "level": 40, "glow": "#ff7a3a", "element": "fire"},
	"earth": {"name": "Temple of Roots", "route": "route9", "room": "temple_earth", "guardian": 51, "level": 48, "glow": "#7ae05a", "element": "earth"},
}

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

## Arena leaders. team: [race, level]. Each teaches a flute song.
const ARENAS := {
	"tidewater": {"leader": "Marina", "title": "Tide Captain", "team": [[12, 9], [13, 9], [21, 10]], "song": "shanty", "crest": "Wave Crest", "gold": 900, "look": {"shirt": "#2f6fb0", "hair": "#203048", "hat": "#f0f0f0"}},
	"kelpwick": {"leader": "Nerissa", "title": "Reef Warden", "team": [[14, 15], [18, 15], [16, 16]], "song": "coral", "flute": "lullaby", "crest": "Coral Crest", "gold": 1300, "look": {"shirt": "#e07a8a", "hair": "#30a0b0"}},
	"sundown": {"leader": "Rosa", "title": "Gunslinger", "team": [[37, 21], [8, 21], [30, 22]], "song": "reel", "crest": "Spur Crest", "gold": 1800, "look": {"shirt": "#8a4a2a", "hair": "#2a1a10", "hat": "#6a4a2a"}},
	"copperpick": {"leader": "Gorran", "title": "Mine Foreman", "team": [[32, 27], [34, 27], [10, 28]], "song": "dirge", "crest": "Ore Crest", "gold": 2400, "look": {"shirt": "#5a6070", "hair": "#806040", "hat": "#e8c040", "outfit": "coat"}},
	"cogsworth": {"leader": "Volta", "title": "Chief Engineer", "team": [[43, 33], [3, 33], [27, 34]], "song": "anvil", "flute": "static", "crest": "Cog Crest", "gold": 3000, "look": {"shirt": "#6a4a3a", "hair": "#f0f0f0", "hat": "#c8a040", "outfit": "apron"}},
	"emberfall": {"leader": "Brann", "title": "Forgemaster", "team": [[7, 39], [4, 39], [9, 40]], "song": "waltz", "crest": "Flame Crest", "gold": 3800, "look": {"shirt": "#8a2a1e", "hair": "#2a1a10", "outfit": "apron"}},
	"vinehollow": {"leader": "Aeris", "title": "Jungle Huntress", "team": [[31, 45], [15, 45], [35, 46]], "song": "fanfare", "flute": "minuet", "crest": "Vine Crest", "gold": 4600, "look": {"shirt": "#4a7a3a", "hair": "#e8e0c0", "outfit": "robe"}},
	"riverbend": {"leader": "Skye", "title": "River Ranger", "team": [[44, 51], [22, 51], [47, 52]], "song": "anthem", "crest": "River Crest", "gold": 5500, "look": {"shirt": "#3a6ab0", "hair": "#f0d070", "hat": "#3a5a3a"}},
}

const BIOMES := {
	"coast": {"ground": "#7cc05a", "side": "#9a7a50", "sand": "#ecd8a0", "path": "#c8a878", "plaza": "#c8c0b0", "tuft": "#5aa040",
		"trees": [["palm", 3], ["tree_round_1", 1]], "rocks": ["beach_rock", "rock_small"], "shrubs": ["shrub_1", "shrub_3"],
		"sky_top": "#4aa8f0", "sky_hz": "#d8f0f8", "sun": "#fff8e8", "sun_e": 1.3, "amb": 0.6, "style": "coastal", "water": "#3a90e0", "music": "coast"},
	"island": {"ground": "#6ac050", "side": "#9a7a50", "sand": "#f0e0a8", "path": "#d8b880", "plaza": "#d8ccb0", "tuft": "#4ab040",
		"trees": [["palm", 4], ["tree_round_1", 1]], "rocks": ["beach_rock", "rock_small"], "shrubs": ["shrub_2", "shrub_1"],
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
		"trees": [["tree_pine", 3], ["tree_birch", 1]], "rocks": ["mountain_0", "mountain_2", "mountain_5", "rock_big"], "shrubs": ["shrub_3", "bush_3"],
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
	"route1": {"index": 1, "name": "Tamsin", "song": "jig", "skill": 0.75},
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
	"Once two beasts hit their level limit, a Beast Center can merge them into one stronger beast.",
	"Your beasts' elemental moves work outside battle too. Vines burn, sand washes away, boulders shatter!",
	"Crystal shards are hidden all over. Five of them buy a shield upgrade at the Tidewater electronics shop.",
	"If all your beasts faint, enemies go after you. Your shield is all that stands between you and defeat!",
	"You can throw items in battle too: bombs, powders, tonics. Don't forget your own turn!",
	"The bird at the top of a Sky Tower can fly you to any town you've visited.",
	"Raise an air beast to level 40 and it can carry you anywhere!",
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
## The ferry between Tidewater and Shellhaven (drawn on the map, travelled by boat).
const FERRY := ["tidewater", "shellhaven"]


## Shop tier per town (progression order). Vinehollow is special: tier 12 unlocks premium jungle goods.
static func town_tier(id: String) -> int:
	if id == "vinehollow":
		return 12
	return maxi(0, TOWN_ORDER.find(id))


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
	"center": "center", "house": "house", "home": "house", "museum": "house", "music_hall": "house",
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


## Wild beasts of the region near a town (used for trade boards).
static func races_near(town: String) -> Array:
	var out := []
	for rid in ROUTES:
		var r: Dictionary = ROUTES[rid]
		if r["from"] == town or r["to"] == town:
			out += r["races"]
	return out if not out.is_empty() else [0, 25, 38, 21]
