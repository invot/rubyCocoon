extends RefCounted
## The supplied elemental creature roster. Every line has three authored forms, growing at Lv 20/40.
## The first thirteen replacement lines retain race ids 0..38; further lines start at 48, after the
## existing temple guardians and robots. Old saves retain their race, stats, progress and equipment.
## Legacy model names are translated by canonical_form() when an existing beast is loaded.
const MoveDB = preload("res://scripts/data/move_db.gd")

const LINES := [
	# Model prefix, stage names, element, second element, stage body kinds.
	# Names: each element has its own root and each species one set of stage suffixes (low, mid, high), e.g. the
	# frilled lizard Drac/Drop/Rocc/Flopp + o/one/omni: Draco, Dracone, Dracomni. Short, and a family reads as one.
	["generated_axolotl_fire", ["Sizzlo", "Sizzlotl", "Sizzlotec"], "fire", "", ["quad", "quad", "quad"]],
	["generated_fennec_fox_fire", ["Ashkit", "Ashfen", "Ashvix"], "fire", "", ["quad", "quad", "quad"]],
	["generated_elephant_shrew_fire", ["Fizzy", "Fizzeek", "Fizzeekor"], "fire", "", ["quad", "quad", "quad"]],
	["generated_peacock_mantis_shrimp_fire", ["Scrip", "Scrimp", "Scrimperor"], "fire", "", ["quad", "quad", "quad"]],
	["generated_echidna_earth", ["Quillet", "Quiller", "Quillord"], "earth", "", ["quad", "quad", "quad"]],
	["generated_jerboa_earth", ["Clodpip", "Clodhop", "Clodhopper"], "earth", "", ["biped", "biped", "biped"]],
	["generated_fennec_fox_earth", ["Dunekit", "Dunefen", "Dunevix"], "earth", "", ["quad", "quad", "quad"]],
	["generated_axolotl_earth", ["Muddlo", "Muddlotl", "Muddlotec"], "earth", "", ["quad", "quad", "quad"]],
	["generated_peacock_mantis_shrimp_water", ["Shrip", "Shrimp", "Shrimperor"], "water", "", ["quad", "quad", "quad"]],
	["generated_axolotl_water", ["Driblo", "Driblotl", "Driblotec"], "water", "", ["quad", "quad", "quad"]],
	["generated_grey_owl_air", ["Hoobit", "Hoobert", "Hoobertus"], "air", "", ["flyer", "flyer", "flyer"]],
	["generated_poodle_moth_air", ["Pooflet", "Poofwing", "Poofwingus"], "air", "", ["flyer", "flyer", "flyer"]],
	["generated_elephant_shrew_air", ["Zippy", "Zippeek", "Zippeekor"], "air", "", ["flyer", "flyer", "flyer"]],
	["generated_draco_fire", ["Draco", "Dracone", "Dracomni"], "fire", "", ["quad", "quad", "quad"]],
	["generated_draco_water", ["Dropo", "Dropone", "Dropomni"], "water", "", ["quad", "quad", "quad"]],
	["generated_draco_earth", ["Rocco", "Roccone", "Roccomni"], "earth", "", ["quad", "quad", "quad"]],
	["generated_draco_air", ["Floppo", "Floppone", "Floppomni"], "air", "", ["flyer", "flyer", "flyer"]],
	["generated_axolotl_air", ["Pufflo", "Pufflotl", "Pufflotec"], "air", "", ["quad", "quad", "quad"]],
	["generated_jerboa_fire", ["Hotpip", "Hothop", "Hothopper"], "fire", "", ["biped", "biped", "biped"]],
	["generated_elephant_shrew_water", ["Sippy", "Sippeek", "Sippeekor"], "water", "", ["quad", "quad", "quad"]],
	["generated_fennec_fox_air", ["Gustkit", "Gustfen", "Gustvix"], "air", "", ["quad", "quad", "quad"]],
	["generated_fennec_fox_water", ["Rillkit", "Rillfen", "Rillvix"], "water", "", ["quad", "quad", "quad"]],
	["generated_poodle_moth_earth", ["Fuzzlet", "Fuzzwing", "Fuzzwingus"], "earth", "", ["flyer", "flyer", "flyer"]],
	["generated_yellow_boxfish_water", ["Bloopit", "Bloopbox", "Bloopboxer"], "water", "", ["fish", "fish", "fish"]],
	["generated_stubby_squid_water", ["Stubby", "Stubink", "Stubinkus"], "water", "", ["fish", "fish", "fish"]],
]
## how many lines have the first race ids (0..38); the rest start at LATE_BASE, after the specials (39..47)
const EARLY_LINES := 13
const LATE_BASE := 48
## Every supplied creature line is available for encounters, eggs and adoption.
const UNRELEASED := []
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
	# Gearheart robots (43-46): not catchable, no eggs
	["Clockwork Sentry", "air", "biped", "flat", "antenna", "none", "none", "plain", "#8a8a96", "#c8a040", "#ff4a3a", 1.2],
	["Steam Mecha", "fire", "golem", "flat", "none", "none", "none", "plain", "#c8c8d0", "#a83a2a", "#ffcf40", 1.3],
	["Iron Golem", "earth", "golem", "flat", "horns", "none", "spikes", "plain", "#5a6070", "#9aa0b0", "#ff9040", 1.4],
	["Tank Walker", "earth", "quad", "flat", "antenna", "none", "shell", "plain", "#5a7a3a", "#4a4a52", "#ff4a3a", 1.3],
	# the ghost guardian of Gravenmoor's crypt (47), always met as a ghost
	["Nocthrax", "air", "golem", "horned", "horns", "spike", "spikes", "plain", "#1a1420", "#3a2a3a", "#ff7a2a", 1.5],
]
## Supplied modular temple dragons, sharing the creature rig and attack/rest poses.
const LEGENDARY_FORMS := {39: "generated_temple_water", 40: "generated_temple_air", 41: "generated_temple_fire", 42: "generated_temple_earth", 47: "generated_temple_ghost"}

const NORMAL_COUNT := 39
const LEGENDARY := [39, 40, 41, 42, 47]
const ROBOTS := [43, 44, 45, 46]
## Robots are drawn with the PSX robot models (assets/robots, tools/import_psx_robots.gd), facing +x like the beasts.
const ROBOT_MODELS := {43: "robot_clockwork", 44: "robot_steam", 45: "robot_golem", 46: "robot_walker"}
const LEGENDARY_PASSIVES := {39: ["Healing Tide", "Regenerate"], 40: ["Slippery", "Swift"], 41: ["Blaze", "Thick Hide"], 42: ["Sturdy", "Rock Skin"],
	47: ["Swift", "Rock Skin"]}

## the four eggs to choose from: fire, water, earth and air, one of each Draco line (Draco, Dropo, Rocco, Floppo);
## Cocoon Cove's mascot is the Fire Draco
const STARTERS := [48, 51, 54, 57]

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


## Archived form/name aliases exist only to translate existing saves and authored references.
const LEGACY_LINES := ["dino", "cactus", "marmot", "scorpion", "beetle", "boar", "tree", "worm", "crab", "frog", "owl", "bat", "berry", "draco", "dropo", "rocco", "floppo"]
const LEGACY_NAMES := [["Embit", "Cinderex", "Pyrosaur"], ["Pricklet", "Spinesear", "Saguaroar"], ["Impkin", "Scampyre", "Infernook"], ["Nipskit", "Scorchpin", "Calderak"], ["Grubbit", "Shellhorn", "Rhinoclad"], ["Tuskit", "Bristlehog", "Crystusk"], ["Saplet", "Barkbrute", "Elderoot"], ["Wrigglet", "Mudwhip", "Abyssel"], ["Clawlet", "Snapshell", "Crustacor"], ["Tadlet", "Croakus", "Toadmiral"], ["Hootlet", "Gustowl", "Tempestrix"], ["Flittle", "Duskwing", "Nocturna"], ["Berrypuff", "Bramblume", "Galeberry"], ["Draco", "Cindrake", "Blazewyrm"], ["Dropo", "Tidrake", "Torrentwyrm"], ["Rocco", "Bouldrake", "Quakewyrm"], ["Floppo", "Glidrake", "Galewyrm"]]

## The roster's first import named its forms "Young <species>", "<species>" and "Guardian <species>" (per line, in
## LINES order); saved beasts still carrying one of those default names get their line's current name.
const INTERIM_SPECIES := ["Fire Axolotl", "Fire Fennec Fox", "Fire Elephant Shrew", "Fire Mantis Shrimp", "Echidna", "Earth Jerboa", "Earth Fennec Fox", "Earth Axolotl", "Water Mantis Shrimp", "Water Axolotl", "Grey Owl", "Air Poodle Moth", "Air Elephant Shrew", "Fire Draco", "Water Draco", "Earth Draco", "Air Draco", "Air Axolotl", "Fire Jerboa", "Water Elephant Shrew", "Air Fennec Fox", "Water Fennec Fox", "Earth Poodle Moth", "Yellow Boxfish", "Aqua Squid"]

static func canonical_form(f: String) -> String:
	if f.begins_with("generated_"):
		return f
	if f.begins_with("summon_"):
		return "generated_temple_" + f.trim_prefix("summon_").trim_suffix("_rest")
	var split := f.rfind("_")
	if split >= 0:
		var i := LEGACY_LINES.find(f.left(split))
		var st := int(f.substr(split + 1))
		if i >= 0 and st >= 1 and st <= 3:
			return "%s_%d" % [LINES[i][0], st]
	return f

## Translate a default species name while preserving player-written nicknames.
static func canonical_name(n: String, id: int) -> String:
	if not in_line(id):
		return n
	var i := _line_index(id)
	var st := stage(id) - 1
	var olds := []
	if i < LEGACY_NAMES.size():
		olds.append(LEGACY_NAMES[i][st])
	if i < INTERIM_SPECIES.size():
		olds.append(["Young %s", "%s", "Guardian %s"][st] % INTERIM_SPECIES[i])
	for was in olds:
		if n == was:
			return race_name(id)
		if n == "Umbral " + was:
			return "Umbral " + race_name(id)
	return n

## Migrate appearance references and authored stage scale; preserve shade and mixed traits.
static func canonical_genes(saved: Dictionary, id: int) -> Dictionary:
	var out := saved.duplicate(true)
	if is_robot(id):
		return out
	var saved_form := String(out.get("form", form(id)))
	out["form"] = canonical_form(saved_form)
	if in_line(id) and not out.has("recipe"):
		# Each creature form fits the shared beast box (tools/import_generated_creatures.gd); a plain form is
		# always its stage's size, so beasts saved while the young forms were drawn at full size catch up.
		out["size"] = STAGE_SIZE[stage(id) - 1]
	if not String(out["form"]).begins_with("generated_"):
		out["form"] = form(id)
	if out.has("recipe"):
		var recipe: Dictionary = out["recipe"]
		for group in recipe:
			if typeof(recipe[group]) == TYPE_STRING:
				recipe[group] = canonical_form(String(recipe[group]))
		out["form"] = recipe.get("frame", out["form"])
	var frame_id := of_form(String(out["form"]))
	out["body"] = body(frame_id if frame_id >= 0 else id)
	return out

## Every released first form, including ids beyond the historic 0..38 range.
static func first_forms() -> Array:
	var out := []
	for i in LINES.size():
		if not LINES[i][0] in UNRELEASED:
			out.append(line_base(i))
	return out

## Random selection over the complete released roster, preserving a caller's deterministic RNG.
static func random_race(rng: RandomNumberGenerator = null) -> int:
	var pool := first_forms()
	var pick := rng.randi_range(0, pool.size() - 1) if rng != null else randi_range(0, pool.size() - 1)
	return int(pool[pick])

static var _ls_cache := {}
static var _ghost_ls_cache := {}

## How many line forms there are to find (every released line's three).
static func count() -> int:
	return (LINES.size() - UNRELEASED.size()) * 3


## Every line form's race id, in line order (the early lines' 0..38, then the late lines' from LATE_BASE).
static func line_races() -> Array:
	var out := []
	for i in LINES.size():
		var b := line_base(i)
		out += [b, b + 1, b + 2]
	return out


## The race id of line i's first form.
static func line_base(i: int) -> int:
	return i * 3 if i < EARLY_LINES else LATE_BASE + (i - EARLY_LINES) * 3


## The index in LINES of a line form's race, or -1.
static func _line_index(id: int) -> int:
	if id >= 0 and id < NORMAL_COUNT:
		return id / 3
	if id >= LATE_BASE and id < LATE_BASE + (LINES.size() - EARLY_LINES) * 3:
		return EARLY_LINES + (id - LATE_BASE) / 3
	return -1


static func is_legendary(id: int) -> bool:
	return id in LEGENDARY


static func is_robot(id: int) -> bool:
	return id in ROBOTS


## A form of one of the lines (not a legendary or a robot).
static func in_line(id: int) -> bool:
	return _line_index(id) >= 0


static func _special(id: int) -> Array:
	return SPECIAL[clampi(id - NORMAL_COUNT, 0, SPECIAL.size() - 1)]


static func _line(id: int) -> Array:
	return LINES[maxi(_line_index(id), 0)]


## The generated model prefix of a line, or "" for guardians and robots.
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


## The race of a generated form or an archived alias; -1 for a temple dragon or unknown form.
static func of_form(f: String) -> int:
	var canonical := canonical_form(f)
	var split := canonical.rfind("_")
	if split < 0:
		return -1
	var prefix := canonical.left(split)
	var st := int(canonical.substr(split + 1))
	if st < 1 or st > 3:
		return -1
	for i in LINES.size():
		if LINES[i][0] == prefix:
			return line_base(i) + st - 1
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


## The generated creature or temple-dragon form, or "" for robots (which use their own models).
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
