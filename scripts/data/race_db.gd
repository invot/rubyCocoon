extends RefCounted
## The beast races. Most belong to the 13 lines of three forms: a beast hatches as its line's first form, grows into
## the second at Lv 20 and the third at Lv 40 (EVOLVE, beast.gd gain_xp), and only a line's third form can merge
## (beasts.gd). A line has one element, or two neighbouring ones on the ring: the scorpion is fire and earth, and the
## worm, an eel in the sea, earth and water. Race id = line × 3 + stage - 1. Each form is drawn with its own model
## (assets/beasts/<line>_<stage>.res, beast_rig.gd), the earlier stages smaller.
## After the lines come the four legendary temple guardians and the Gearhart robots, then the crypt's ghost guardian,
## in the old shape (name, element, body, head, ears, tail, back, pattern, c1, c2, c3, size). The guardians are drawn
## with the summon models (assets/summons, voxel_beast.gd): captured with their temple's song, they become summons.

const MoveDB = preload("res://scripts/data/move_db.gd")

const LINES := [
	# line (its models' name), its forms' names, element, second element, each form's body
	["dino", ["Embit", "Cinderex", "Pyrosaur"], "fire", "", ["quad", "quad", "biped"]],
	["cactus", ["Pricklet", "Spinesear", "Saguaroar"], "fire", "", ["biped", "biped", "biped"]],
	["marmot", ["Impkin", "Scampyre", "Infernook"], "fire", "", ["biped", "biped", "biped"]],
	["scorpion", ["Nipskit", "Scorchpin", "Calderak"], "fire", "earth", ["quad", "quad", "quad"]],
	["beetle", ["Grubbit", "Shellhorn", "Rhinoclad"], "earth", "", ["quad", "quad", "biped"]],
	["boar", ["Tuskit", "Bristlehog", "Crystusk"], "earth", "", ["quad", "quad", "quad"]],
	["tree", ["Saplet", "Barkbrute", "Elderoot"], "earth", "", ["biped", "biped", "biped"]],
	["worm", ["Wrigglet", "Mudwhip", "Abyssel"], "earth", "water", ["serpent", "serpent", "serpent"]],
	["crab", ["Clawlet", "Snapshell", "Crustacor"], "water", "", ["quad", "quad", "quad"]],
	["frog", ["Tadlet", "Croakus", "Toadmiral"], "water", "", ["biped", "biped", "biped"]],
	["owl", ["Hootlet", "Gustowl", "Tempestrix"], "air", "", ["flyer", "flyer", "flyer"]],
	["bat", ["Flittle", "Duskwing", "Nocturna"], "air", "", ["flyer", "flyer", "flyer"]],
	["berry", ["Berrypuff", "Bramblume", "Galeberry"], "air", "", ["blob", "blob", "blob"]],
]
## the levels a beast grows into its line's second and third forms
const EVOLVE := [20, 40]
## each stage's size (the "size" gene), and its share of the line's full stats
const STAGE_SIZE := [0.72, 0.86, 1.0]
const STAGE_STATS := [0.8, 0.9, 1.0]

const SPECIAL := [
	# legendary temple guardians (39-42)
	["Abyssion", "water", "serpent", "horned", "crest", "fin", "fin", "stripes", "#1a4a9a", "#5ad0f0", "#e8ffff", 1.45],
	["Zephyrax", "air", "bird", "beak", "crest", "feather", "wings", "stripes", "#e8f8ff", "#5ad8c8", "#ffd040", 1.4],
	["Pyroclast", "fire", "quad", "horned", "horns", "flame", "flames", "belly", "#c8281a", "#2a1a1a", "#ffb030", 1.45],
	["Terranox", "earth", "golem", "horned", "crest", "spike", "crystals", "stripes", "#4a6a3a", "#8a7a5a", "#7affb0", 1.5],
	# Gearhart robots (43-46): not catchable, no eggs
	["Clockwork Sentry", "air", "biped", "flat", "antenna", "none", "none", "plain", "#8a8a96", "#c8a040", "#ff4a3a", 1.2],
	["Steam Mecha", "fire", "golem", "flat", "none", "none", "none", "plain", "#c8c8d0", "#a83a2a", "#ffcf40", 1.3],
	["Iron Golem", "earth", "golem", "flat", "horns", "none", "spikes", "plain", "#5a6070", "#9aa0b0", "#ff9040", 1.4],
	["Tank Walker", "earth", "quad", "flat", "antenna", "none", "shell", "plain", "#5a7a3a", "#4a4a52", "#ff4a3a", 1.3],
	# the ghost guardian of Gravenmoor's crypt (47), always met as a ghost
	["Nocthrax", "air", "golem", "horned", "horns", "spike", "spikes", "plain", "#1a1420", "#3a2a3a", "#ff7a2a", 1.5],
]
## the summon models the guardians are drawn with (assets/summons/<element>.res, tools/import_summons.gd)
const LEGENDARY_FORMS := {39: "summon_water", 40: "summon_air", 41: "summon_fire", 42: "summon_earth", 47: "summon_ghost"}

const NORMAL_COUNT := 39
const LEGENDARY := [39, 40, 41, 42, 47]
const ROBOTS := [43, 44, 45, 46]
## Robots are drawn with the PSX robot models (assets/robots, tools/import_psx_robots.gd), facing +x like the beasts.
const ROBOT_MODELS := {43: "robot_clockwork", 44: "robot_steam", 45: "robot_golem", 46: "robot_walker"}
const LEGENDARY_PASSIVES := {39: ["Healing Tide", "Regenerate"], 40: ["Slippery", "Swift"], 41: ["Blaze", "Thick Hide"], 42: ["Sturdy", "Rock Skin"],
	47: ["Swift", "Rock Skin"]}

## the four eggs to choose from: fire, water, earth and air
const STARTERS := [0, 24, 12, 30]

## base stats per element role: hp, atk, def, spr, spd
const ROLE_STATS := {
	"fire": [80, 92, 72, 55, 62],
	"water": [78, 62, 64, 92, 66],
	"earth": [88, 68, 96, 66, 42],
	"air": [62, 72, 56, 70, 96],
}
const BODY_MOD := {
	"quad": [0, 4, 0, 0, 4], "biped": [0, 2, 2, 2, 0], "bird": [-6, 2, -4, 0, 10], "flyer": [-6, 2, -4, 0, 10],
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


## A form of one of the lines (not a legendary or a robot).
static func in_line(id: int) -> bool:
	return id >= 0 and id < NORMAL_COUNT


static func _special(id: int) -> Array:
	return SPECIAL[clampi(id - NORMAL_COUNT, 0, SPECIAL.size() - 1)]


static func _line(id: int) -> Array:
	return LINES[clampi(id, 0, NORMAL_COUNT - 1) / 3]


## The line a race belongs to ("dino"), "" for the legendaries and robots.
static func line(id: int) -> String:
	return _line(id)[0] if in_line(id) else ""


## Its stage in its line, 1..3 (the legendaries and robots count as final forms).
static func stage(id: int) -> int:
	return id % 3 + 1 if in_line(id) else 3


## Its line's first form (what its eggs hatch as).
static func first_form(id: int) -> int:
	return id - id % 3 if in_line(id) else id


## The form of its line a beast of this level has grown into.
static func for_level(id: int, level: int) -> int:
	if not in_line(id):
		return id
	var s := 0
	for l in EVOLVE:
		if level >= l:
			s += 1
	return first_form(id) + s


## The race of one of the lines' forms ("dino_2"), or -1 (a legendary's model, or not a form).
static func of_form(f: String) -> int:
	var st := int(f.get_slice("_", 1)) if f.get_slice_count("_") == 2 else 0
	for i in LINES.size():
		if LINES[i][0] == f.get_slice("_", 0) and st >= 1 and st <= 3:
			return i * 3 + st - 1
	return -1


## How it moves and fights: quad, biped, flyer, serpent or blob (the legendaries' and robots' old bodies).
static func body(id: int) -> String:
	return _line(id)[4][stage(id) - 1] if in_line(id) else _special(id)[2]


static func get_race(id: int) -> Dictionary:
	var el := element(id)
	var k := id / 3 if in_line(id) else id
	return {
		"id": id, "name": race_name(id), "el": el, "el2": element2(id), "passive": PASSIVES[el][k % 3],
	}


static func race_name(id: int) -> String:
	return _line(id)[1][stage(id) - 1] if in_line(id) else _special(id)[0]


static func element(id: int) -> String:
	return _line(id)[2] if in_line(id) else _special(id)[1]


## Its line's second element ("" for most).
static func element2(id: int) -> String:
	return _line(id)[3] if in_line(id) else ""


static func genes(id: int) -> Dictionary:
	if in_line(id):
		return {"form": form(id), "body": body(id), "size": STAGE_SIZE[stage(id) - 1], "shade": 0.0}
	var r := _special(id)
	var g := {
		"body": r[2], "head": r[3], "ears": r[4], "tail": r[5], "back": r[6], "pattern": r[7],
		"c1": r[8], "c2": r[9], "c3": r[10], "size": r[11], "shade": 0.0,
	}
	if ROBOT_MODELS.has(id):
		g["model"] = ROBOT_MODELS[id]
	else:
		g["form"] = form(id)
	return g


## The model a race is drawn with: its form's ("dino_2"), a guardian's summon model ("summon_fire"), or "" for the
## robots (their own models).
static func form(id: int) -> String:
	if in_line(id):
		return "%s_%d" % [line(id), stage(id)]
	return String(LEGENDARY_FORMS.get(id, ""))


static func base_stats(id: int) -> Array:
	var role: Array = ROLE_STATS[element(id)]
	var bm: Array = BODY_MOD[body(id)]
	var rng := RandomNumberGenerator.new()
	var out := []
	if in_line(id):
		# a line's forms share its build, each stage a share of the last; a dual line is half of each element
		var el2 := element2(id)
		rng.seed = first_form(id) * 4513 + 77
		for i in 5:
			var v: float = role[i] if el2 == "" else (role[i] + ROLE_STATS[el2][i]) / 2.0
			v = (v + bm[i] + rng.randi_range(-8, 8)) * STAGE_STATS[stage(id) - 1]
			out.append(maxf(25.0, v))
		return out
	rng.seed = id * 4513 + 77
	var size: float = _special(id)[11]
	var bonus := 34.0 if is_legendary(id) else 10.0
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


## [[level, move_id], ...]: the same for every form of a line, so growing into the next keeps what it would learn.
## A dual line learns every third move from its second element.
static func learnset(id: int) -> Array:
	var key := first_form(id)
	if _ls_cache.has(key):
		return _ls_cache[key]
	var el := element(key)
	var el2 := element2(key)
	var bd := body(key)
	var pool: Array = MoveDB.POOLS[el].duplicate()
	if el2 != "":
		var other: Array = MoveDB.POOLS[el2]
		for i in range(2, mini(pool.size(), other.size()), 3):
			pool[i] = other[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = key * 7919 + 13
	for i in range(1, pool.size() - 1):
		if rng.randf() < 0.35:
			var tmp = pool[i]
			pool[i] = pool[i + 1]
			pool[i + 1] = tmp
	# each line skips a couple of its element's moves, so lines feel distinct
	if not is_legendary(key):
		for _k in 2:
			pool.remove_at(rng.randi_range(2, pool.size() - 2))
	var levels := [1, 5, 9, 13, 17, 21, 26, 31, 37, 43, 50, 57, 64]
	if is_legendary(key):
		levels = [1, 3, 6, 9, 12, 15, 19, 23, 27, 32, 37, 43, 50]
	var first := "scratch"
	if bd in ["golem", "blob", "fish", "serpent"]:
		first = "tackle"
	var out := [[1, first]]
	for i in pool.size():
		out.append([levels[mini(i, levels.size() - 1)], pool[i]])
	var extra := "bite"
	if bd in ["golem", "biped"]:
		extra = "headbutt"
	elif el == "air" or bd in ["bird", "insect", "flyer"]:
		extra = "quick_strike"
	out.append([11, extra])
	out.append([19, "brace" if el == "earth" or el == "water" else "howl"])
	out.sort_custom(func(a, b): return a[0] < b[0])
	_ls_cache[key] = out
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
