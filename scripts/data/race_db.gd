extends RefCounted
## The 48 beast races: 12 each of fire, water, earth and air.
## Each entry: name, element, body, head, ears, tail, back, pattern, c1, c2, c3, size
## The appearance fields are "genes" that merging mixes between parents.

const MoveDB = preload("res://scripts/data/move_db.gd")

const RACES := [
	# ---------------- FIRE ----------------
	["Redcoon", "fire", "quad", "round", "round", "fluffy", "none", "mask", "#c43a3a", "#2e2230", "#ffcf6b", 1.0],
	["Emberkit", "fire", "quad", "pointy", "pointed", "flame", "none", "belly", "#f07a2a", "#ffe2b0", "#ffd23f", 0.85],
	["Cindermole", "fire", "quad", "snout", "none", "spike", "none", "belly", "#6b3b2e", "#f0a060", "#ff5a1f", 0.85],
	["Blazehound", "fire", "quad", "pointy", "pointed", "flame", "flames", "stripes", "#d9482b", "#3b1f1a", "#ffb43f", 1.1],
	["Magmaw", "fire", "blob", "flat", "horns", "none", "spikes", "spots", "#3d2b2b", "#ff6a1f", "#ffd23f", 1.15],
	["Pyrowing", "fire", "bird", "beak", "crest", "feather", "wings", "belly", "#e8452c", "#ffb347", "#ffe680", 0.95],
	["Scorchscale", "fire", "serpent", "flat", "fins", "spike", "spikes", "stripes", "#b8321e", "#ff9a3c", "#ffe066", 1.1],
	["Infernox", "fire", "golem", "horned", "horns", "spike", "flames", "plain", "#7a2a1e", "#e0603a", "#ffcf4a", 1.3],
	["Flarefly", "fire", "insect", "round", "antenna", "flame", "wings", "spots", "#ffb02e", "#c8401e", "#fff27a", 0.75],
	["Ashwyrm", "fire", "serpent", "horned", "horns", "long", "wings", "belly", "#4a4040", "#ff7b2e", "#ffcf6b", 1.25],
	["Kilnback", "fire", "golem", "flat", "none", "spike", "shell", "spots", "#8a5a3a", "#c2452a", "#ffa43f", 1.2],
	["Solarion", "fire", "quad", "round", "crest", "flame", "flames", "belly", "#f2a23a", "#c8401e", "#fff1a0", 1.2],
	# ---------------- WATER ----------------
	["Puddlepup", "water", "quad", "round", "long", "fin", "none", "belly", "#3f8fe0", "#cfe9ff", "#7fe0ff", 0.85],
	["Tidalotl", "water", "blob", "round", "fins", "fin", "none", "spots", "#ff9fc8", "#ffd0e4", "#5fd0ff", 0.9],
	["Bubblefin", "water", "fish", "round", "fins", "fin", "fin", "stripes", "#4fc0e8", "#ffffff", "#ffd23f", 0.85],
	["Coralynx", "water", "quad", "pointy", "pointed", "long", "crystals", "spots", "#2f7fb8", "#ff8fa0", "#9ff0ff", 1.05],
	["Mistcrab", "water", "insect", "flat", "antenna", "none", "shell", "plain", "#3f6fa0", "#a0d8ff", "#ff7f6a", 0.9],
	["Rippleray", "water", "fish", "flat", "none", "long", "wings", "belly", "#2a4f8a", "#8fd0ff", "#e0f8ff", 1.1],
	["Lagoonaga", "water", "serpent", "pointy", "fins", "fin", "fin", "belly", "#1f8f9f", "#a0f0e0", "#ffd86b", 1.15],
	["Dewdrake", "water", "biped", "horned", "fins", "long", "wings", "belly", "#3a7fd0", "#bfe8ff", "#5ff0ff", 1.1],
	["Seashelly", "water", "blob", "round", "antenna", "none", "shell", "rings", "#7fc8d8", "#f0d0a0", "#ff8fa0", 0.85],
	["Brookotter", "water", "quad", "round", "round", "long", "none", "belly", "#7a5a3f", "#d8c0a0", "#4fb0ff", 0.95],
	["Aquapon", "water", "quad", "snout", "round", "fin", "shell", "spots", "#5f7fc8", "#c0d0ff", "#3fe0d0", 1.25],
	["Leviathorn", "water", "serpent", "horned", "crest", "fin", "spikes", "stripes", "#1f3f8f", "#4fb0e0", "#e0ffff", 1.35],
	# ---------------- EARTH ----------------
	["Pebblit", "earth", "blob", "round", "none", "none", "crystals", "spots", "#8a8a7a", "#c0b8a0", "#7fd06f", 0.75],
	["Burrowbun", "earth", "quad", "round", "long", "fluffy", "none", "belly", "#a07a50", "#e8d8b8", "#6fa040", 0.85],
	["Mossback", "earth", "golem", "flat", "none", "spike", "leaves", "plain", "#5a7a3a", "#8a6a40", "#b0e060", 1.2],
	["Quarrion", "earth", "biped", "horned", "horns", "spike", "spikes", "belly", "#8a6a50", "#c8b090", "#e0c060", 1.1],
	["Thornhog", "earth", "quad", "snout", "round", "none", "spikes", "belly", "#6a5038", "#c8a878", "#8fc050", 0.9],
	["Clayvern", "earth", "biped", "pointy", "horns", "long", "wings", "belly", "#b0683a", "#e8b080", "#7f5030", 1.15],
	["Geodillo", "earth", "quad", "snout", "pointed", "spike", "shell", "stripes", "#7a7060", "#a8a090", "#c080ff", 0.95],
	["Rootling", "earth", "biped", "round", "leaf", "leaf", "leaves", "plain", "#6a8a3a", "#a0703a", "#ffd060", 0.8],
	["Boulderox", "earth", "golem", "horned", "horns", "fluffy", "none", "plain", "#6a6a70", "#a09080", "#e0d0b0", 1.35],
	["Mudmander", "earth", "quad", "flat", "none", "long", "none", "spots", "#6a4a30", "#a07850", "#f0c040", 1.0],
	["Ironhide", "earth", "golem", "flat", "crest", "spike", "spikes", "stripes", "#5a6070", "#9aa0b0", "#ff9040", 1.3],
	["Terragon", "earth", "quad", "horned", "horns", "spike", "crystals", "belly", "#4a6a3a", "#c0a070", "#60e0c0", 1.3],
	# ---------------- AIR ----------------
	["Zephyrling", "air", "bird", "beak", "crest", "feather", "wings", "belly", "#8fd0e8", "#ffffff", "#ffd23f", 0.8],
	["Galeferret", "air", "quad", "pointy", "round", "long", "none", "stripes", "#d8d0b0", "#8a7a5a", "#70e0c0", 0.9],
	["Wisplet", "air", "blob", "round", "antenna", "none", "wings", "plain", "#e0f0ff", "#a0c8ff", "#ffe06b", 0.7],
	["Stormowl", "air", "bird", "beak", "pointed", "feather", "wings", "spots", "#6a6a8a", "#c8c8e0", "#ffe040", 1.05],
	["Cloudsquid", "air", "fish", "round", "none", "long", "none", "plain", "#f0f0ff", "#c0d0f0", "#ff9fd0", 1.0],
	["Mothmyst", "air", "insect", "round", "antenna", "none", "wings", "spots", "#b8a0e0", "#f0e0ff", "#70f0e0", 0.9],
	["Breezebat", "air", "biped", "pointy", "long", "none", "wings", "belly", "#6a5a9a", "#c0b0e0", "#ffd060", 0.9],
	["Thunderhawk", "air", "bird", "beak", "crest", "feather", "wings", "stripes", "#3f4f8a", "#ffe040", "#ffffff", 1.2],
	["Nimbuskit", "air", "quad", "round", "pointed", "fluffy", "wings", "belly", "#e8eef8", "#a8b8d8", "#8fe0ff", 0.95],
	["Dustdevil", "air", "serpent", "pointy", "none", "long", "fin", "rings", "#d8c090", "#a08860", "#ffffff", 1.0],
	["Featherfox", "air", "quad", "pointy", "pointed", "feather", "none", "belly", "#70c0a0", "#f0f0e0", "#ffb040", 1.0],
	["Aurorasprite", "air", "biped", "round", "antenna", "none", "wings", "plain", "#a0f0d0", "#f0a0f0", "#ffffa0", 0.85],
	# ---------------- LEGENDARY temple guardians (48-51) ----------------
	["Abyssion", "water", "serpent", "horned", "crest", "fin", "fin", "stripes", "#1a4a9a", "#5ad0f0", "#e8ffff", 1.45],
	["Zephyrax", "air", "bird", "beak", "crest", "feather", "wings", "stripes", "#e8f8ff", "#5ad8c8", "#ffd040", 1.4],
	["Pyroclast", "fire", "quad", "horned", "horns", "flame", "flames", "belly", "#c8281a", "#2a1a1a", "#ffb030", 1.45],
	["Terranox", "earth", "golem", "horned", "crest", "spike", "crystals", "stripes", "#4a6a3a", "#8a7a5a", "#7affb0", 1.5],
	# ---------------- Gearhart robots (52-55): not catchable, no eggs ----------------
	["Clockwork Sentry", "air", "biped", "flat", "antenna", "none", "none", "plain", "#8a8a96", "#c8a040", "#ff4a3a", 1.2],
	["Steam Mecha", "fire", "golem", "flat", "none", "none", "none", "plain", "#c8c8d0", "#a83a2a", "#ffcf40", 1.3],
	["Iron Golem", "earth", "golem", "flat", "horns", "none", "spikes", "plain", "#5a6070", "#9aa0b0", "#ff9040", 1.4],
	["Tank Walker", "earth", "quad", "flat", "antenna", "none", "shell", "plain", "#5a7a3a", "#4a4a52", "#ff4a3a", 1.3],
]

## The PSX model each race is drawn with (assets/psx/beasts/<form>.res, baked by tools/import_psx_beasts.gd from the
## creature packs in psx/Creatures), recoloured with the race's c1 / c2 colours. Merged beasts inherit one parent's.
const FORMS := [
	# fire
	"raccoon", "red_fox", "aardvark", "dobermann", "toad", "falcon", "rattlesnake", "bison", "firefly", "dragon",
	"tortoise", "lion",
	# water
	"puppy", "frog", "clownfish", "bobcat", "scorpion", "catfish", "crocodile", "dragon", "snail", "otter", "capybara",
	"alligator",
	# earth
	"hedgehog", "rabbit", "gorilla", "bighorn", "boar", "komodo", "armadillo", "sloth", "muskox", "iguana", "rhino", "elk",
	# air
	"ptarmigan", "red_panda", "slime", "snowy_owl", "perch", "moth", "bat", "eagle", "alpaca", "coral_snake",
	"kit_fox", "butterfly",
	# legendary guardians
	"shark", "condor", "tiger", "mammoth",
]

const NORMAL_COUNT := 48
const LEGENDARY := [48, 49, 50, 51]
const ROBOTS := [52, 53, 54, 55]
## Robots are drawn with the PSX robot models (assets/psx/robots, tools/import_psx_robots.gd), facing +x like the beasts.
const ROBOT_MODELS := {52: "robot_clockwork", 53: "robot_steam", 54: "robot_golem", 55: "robot_walker"}
const LEGENDARY_PASSIVES := {48: ["Healing Tide", "Regenerate"], 49: ["Slippery", "Swift"], 50: ["Blaze", "Thick Hide"], 51: ["Sturdy", "Rock Skin"]}

const STARTERS := [1, 12, 24, 36]

## base stats per element role: hp, atk, def, spr, spd
const ROLE_STATS := {
	"fire": [80, 92, 72, 55, 62],
	"water": [78, 62, 64, 92, 66],
	"earth": [88, 68, 96, 66, 42],
	"air": [62, 72, 56, 70, 96],
}
const BODY_MOD := {
	"quad": [0, 4, 0, 0, 4], "biped": [0, 2, 2, 2, 0], "bird": [-6, 2, -4, 0, 10],
	"serpent": [2, 8, 0, -2, 0], "blob": [12, -4, 2, 4, -6], "insect": [-6, 0, 0, 2, 8],
	"fish": [0, 0, -2, 6, 4], "golem": [10, 4, 10, -4, -14],
}
const STAT_KEYS := ["hp", "atk", "def", "spr", "spd"]

const PASSIVES := {
	"fire": ["Blaze", "Thick Hide", "Fury"],
	"water": ["Healing Tide", "Regenerate", "Purity"],
	"earth": ["Sturdy", "Rock Skin", "Rooted"],
	"air": ["Slippery", "Trickster", "Swift"],
}
const PASSIVE_DESC := {
	"Blaze": "Deals 30% more damage below 1/3 HP.",
	"Thick Hide": "Takes 15% less damage.",
	"Fury": "Attack may rise when hit.",
	"Healing Tide": "Healing it gives is 25% stronger.",
	"Regenerate": "Recovers 1/16 HP every turn.",
	"Purity": "Cannot be burned or poisoned.",
	"Sturdy": "Survives one lethal hit at full HP.",
	"Rock Skin": "Takes 25% less from powerful moves.",
	"Rooted": "Starts battles with raised Defense.",
	"Slippery": "Harder to hit.",
	"Trickster": "Its status effects land more often.",
	"Swift": "Starts battles with raised Speed.",
	"Phantom": "Immune to status ailments except Haunt.",
}

static var _ls_cache := {}
static var _ghost_ls_cache := {}


static func count() -> int:
	return NORMAL_COUNT


static func is_legendary(id: int) -> bool:
	return id in LEGENDARY


static func is_robot(id: int) -> bool:
	return id in ROBOTS


static func get_race(id: int) -> Dictionary:
	var r: Array = RACES[clampi(id, 0, RACES.size() - 1)]
	var el: String = r[1]
	return {
		"id": id, "name": r[0], "el": el, "passive": PASSIVES[el][id % 3],
	}


static func race_name(id: int) -> String:
	return RACES[clampi(id, 0, RACES.size() - 1)][0]


static func element(id: int) -> String:
	return RACES[clampi(id, 0, RACES.size() - 1)][1]


static func genes(id: int) -> Dictionary:
	var r: Array = RACES[clampi(id, 0, RACES.size() - 1)]
	var g := {
		"body": r[2], "head": r[3], "ears": r[4], "tail": r[5], "back": r[6], "pattern": r[7],
		"c1": r[8], "c2": r[9], "c3": r[10], "size": r[11], "shade": 0.0,
	}
	if ROBOT_MODELS.has(id):
		g["model"] = ROBOT_MODELS[id]
	else:
		g["form"] = form(id)
	return g


## The PSX model a race is drawn with ("" for the robots, which use their own models).
static func form(id: int) -> String:
	return FORMS[id] if id >= 0 and id < FORMS.size() else ""


static func base_stats(id: int) -> Array:
	var r: Array = RACES[id]
	var role: Array = ROLE_STATS[r[1]]
	var bm: Array = BODY_MOD[r[2]]
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 4513 + 77
	var size: float = r[11]
	var bonus := 34.0 if is_legendary(id) else (10.0 if is_robot(id) else 0.0)
	var out := []
	for i in 5:
		var v: float = role[i] + bm[i] + rng.randi_range(-8, 8) + bonus
		if i == 0 or i == 1:
			v += (size - 1.0) * 24.0
		if i == 4:
			v -= (size - 1.0) * 18.0
		out.append(maxf(25.0, v))
	return out


static func xp_yield(id: int) -> int:
	var total := 0.0
	for v in base_stats(id):
		total += v
	return int(total / 6.0)


## [[level, move_id], ...]
static func learnset(id: int) -> Array:
	if _ls_cache.has(id):
		return _ls_cache[id]
	var r: Array = RACES[id]
	var el: String = r[1]
	var body: String = r[2]
	var pool: Array = MoveDB.POOLS[el].duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 13
	for i in range(1, pool.size() - 1):
		if rng.randf() < 0.35:
			var tmp = pool[i]
			pool[i] = pool[i + 1]
			pool[i + 1] = tmp
	# each race skips a couple of its element's moves, so races feel distinct
	if not is_legendary(id):
		for _k in 2:
			pool.remove_at(rng.randi_range(2, pool.size() - 2))
	var levels := [1, 5, 9, 13, 17, 21, 26, 31, 37, 43, 50, 57, 64]
	if is_legendary(id):
		levels = [1, 3, 6, 9, 12, 15, 19, 23, 27, 32, 37, 43, 50]
	var first := "scratch"
	if body in ["golem", "blob", "fish", "serpent"]:
		first = "tackle"
	var out := [[1, first]]
	for i in pool.size():
		out.append([levels[mini(i, levels.size() - 1)], pool[i]])
	var extra := "bite"
	if body in ["golem", "biped"]:
		extra = "headbutt"
	elif el == "air" or body in ["bird", "insect"]:
		extra = "quick_strike"
	out.append([11, extra])
	out.append([19, "brace" if el == "earth" or el == "water" else "howl"])
	out.sort_custom(func(a, b): return a[0] < b[0])
	_ls_cache[id] = out
	return out


## Learnset for the Legion's ghost version of a race.
static func ghost_learnset(id: int) -> Array:
	if _ghost_ls_cache.has(id):
		return _ghost_ls_cache[id]
	var out := [[1, "tackle"]]
	var levels := [1, 6, 12, 18, 25, 32, 40, 48, 56, 64]
	var gp: Array = MoveDB.POOLS["ghost"]
	for i in gp.size():
		out.append([levels[i], gp[i]])
	# keep two of the original element's strongest moves
	var own := learnset(id)
	var picked := 0
	for i in range(own.size() - 1, -1, -1):
		var e: Array = own[i]
		if MoveDB.get_move(e[1])["el"] != "neutral" and MoveDB.is_damaging(e[1]):
			out.append([e[0], e[1]])
			picked += 1
			if picked >= 2:
				break
	out.sort_custom(func(a, b): return a[0] < b[0])
	_ghost_ls_cache[id] = out
	return out
