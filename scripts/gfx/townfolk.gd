extends RefCounted
## The townsfolk: the "townfolk collection" kit's people (baked by tools/import_townfolk.gd into assets/townfolk/),
## every one put together from the kit's parts on the one skeleton they all share, and coloured by a shader from the
## look: skin, hair, eyes, top, bottoms, shoes and hat each have a colour slot (see townfolk.gdshader); the kit's
## own colours stay on the details (trims, soles, glasses, buttons).

const DIR := "res://assets/townfolk/"
const SHADER := preload("res://scripts/gfx/townfolk.gdshader")
## The skeleton they share, where its joints are on the kit's body (centimetres, y up, facing +z, standing on y = 0;
## "l" is the person's left, +x): [bone, parent, joint]. Every bone's rest is unturned.
const BONES := [
	["hips", "", Vector3(0, 50, 0)],
	["spine", "hips", Vector3(0, 62, 0)],
	["chest", "spine", Vector3(0, 76, 0)],
	["neck", "chest", Vector3(0, 92, 0)],
	["head", "neck", Vector3(0, 101, 0)],
	["l_arm", "chest", Vector3(17, 88.5, 0)],
	["l_forearm", "l_arm", Vector3(37, 88.5, 0)],
	["l_hand", "l_forearm", Vector3(50.5, 88, 0)],
	["r_arm", "chest", Vector3(-17, 88.5, 0)],
	["r_forearm", "r_arm", Vector3(-37, 88.5, 0)],
	["r_hand", "r_forearm", Vector3(-50.5, 88, 0)],
	["l_thigh", "hips", Vector3(10, 47, 0)],
	["l_shin", "l_thigh", Vector3(10, 28, 0)],
	["l_foot", "l_shin", Vector3(10, 9, 0)],
	["l_toe", "l_foot", Vector3(10, 2, 15)],
	["r_thigh", "hips", Vector3(-10, 47, 0)],
	["r_shin", "r_thigh", Vector3(-10, 28, 0)],
	["r_foot", "r_shin", Vector3(-10, 9, 0)],
	["r_toe", "r_foot", Vector3(-10, 2, 15)],
]
## The kit's legs are short (a toddler's); between the ankle and the hip they're drawn this much longer, the body
## above raised to suit (see fit).
const LEG_STRETCH := 1.3
const ANKLE_Y := 9.0
const HIP_Y := 47.0
## The bones by role, as voxel_person.gd asks for them (a foot is its toe, under the ankle).
const ROLES := {"hips": "hips", "head": "head", "l_arm": "l_arm", "r_arm": "r_arm", "l_forearm": "l_forearm",
	"r_forearm": "r_forearm", "l_thigh": "l_thigh", "r_thigh": "r_thigh", "l_shin": "l_shin", "r_shin": "r_shin",
	"l_foot": "l_toe", "r_foot": "r_toe"}
## The colour slots a part's triangles can take (UV2.x in its mesh); "keep" is the kit's own colour, "top_plain" the
## top's where it's never camo, "pack" a worn pack's (see townfolk.gdshader).
const SLOTS := ["keep", "skin", "hair", "eyes", "top", "bottom", "shoes", "hat", "top_plain", "pack"]
## The slots with a colour of their own to set (a look's colours by slot name).
const COLOURED := ["skin", "hair", "eyes", "top", "bottom", "shoes", "hat", "pack"]
## The trainers' camo (outfit "camo"): its light, mid and dark tones, green or brown.
const CAMO := {"green": ["#9aa060", "#5c7a48", "#3b4f33"], "brown": ["#b49a68", "#7a5c3c", "#4a3828"]}
## The camo outfit's parts (townfolk.json "extras"): the jacket (with its collar and belt), trousers and boots; and
## the boots' colour.
const CAMO_PARTS := ["camo_jacket", "camo_collar", "camo_belt", "camo_trousers", "camo_boots"]
const BOOTS := "#2e2e32"
## The hero's pack to begin with (see packs(); 0 is none).
const HERO_PACK := 1
## The trainers' packs' colours, one picked for each (canvas and leather).
const TRAINER_PACK_COLOURS := ["#6a7a4a", "#7a5a3a", "#4a5a6a", "#8a6a4a", "#5a4a3a"]
## The top of the head, on the kit's body.
const HEAD_TOP := 165.6
## The hero's outfits for each body (people in townfolk.json, worn with the hero's own hairdo and colours), the first
## the one they begin in.
const HERO_OUTFITS := {"male": [0, 13, 2, 4, 10, 11, 29, 30, 35, 36, 37, 43],
	"female": [62, 7, 8, 31, 46, 72, 73, 74, 77, 63, 66, 33]}
## The hairdos: [whose hair it is (a person in townfolk.json), what the character creator calls it].
const HAIRDOS := [[0, "Short"], [2, "Parted"], [4, "Spiky"], [5, "Fluffy"], [6, "Long"], [7, "Bob"]]
## Each body's hairdo to begin with.
const HERO_HAIRDO := {"male": 0, "female": 4}
## Whose face the hero has, whatever they wear: a friendly smile (some outfits' people frown or pout).
const HERO_FACE := 0
## Shoes and eyes for townsfolk whose look doesn't say (one picked by the look).
const SHOE_COLOURS := ["#5a3a24", "#2a2a2a", "#e8e4dc", "#3a3a4a", "#7a4a2a", "#8a2a2a", "#4a5a7a"]
const EYE_COLOURS := ["#4a2e1c", "#5a3a22", "#3e2a1c", "#4a6680", "#56704e", "#6a5a3a", "#4a3a2e"]
const SKIN := "#f0c8a0"

static var _list := {}
static var _skin: Skin
static var _meshes := {}
static var _mats := {}


static func data() -> Dictionary:
	if _list.is_empty():
		_list = JSON.parse_string(FileAccess.get_file_as_string(DIR + "townfolk.json"))
	return _list


## A point on the kit's body (centimetres) where it ends up on a baked person: in metres, the legs drawn longer.
static func fit(p: Vector3) -> Vector3:
	var y := p.y
	if y > ANKLE_Y:
		y = ANKLE_Y + (minf(y, HIP_Y) - ANKLE_Y) * LEG_STRETCH + maxf(y - HIP_Y, 0.0)
	return Vector3(p.x, y, p.z) / 100.0


## How tall a baked person stands (metres), to the top of the head.
static func height() -> float:
	return fit(Vector3(0, HEAD_TOP, 0)).y


static func bone_index(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1


## A fresh skeleton in the rest pose.
static func skeleton() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton"
	for b in BONES:
		sk.add_bone(b[0])
	for i in BONES.size():
		var parent := bone_index(BONES[i][1])
		sk.set_bone_parent(i, parent)
		var at := fit(BONES[i][2])
		var rest := Transform3D(Basis.IDENTITY, at - (fit(BONES[parent][2]) if parent >= 0 else Vector3.ZERO))
		sk.set_bone_rest(i, rest)
		sk.set_bone_pose(i, rest)
	return sk


## The skin every part is bound with: each bone's bind pose is the inverse of where it rests.
static func skin() -> Skin:
	if _skin == null:
		_skin = Skin.new()
		for i in BONES.size():
			_skin.add_named_bind(BONES[i][0], Transform3D(Basis.IDENTITY, -fit(BONES[i][2])))
	return _skin


static func part_mesh(id: int) -> Mesh:
	if not _meshes.has(id):
		_meshes[id] = load(DIR + "parts/%s.res" % data()["parts"][id]["file"])
	return _meshes[id]


## A person: a Node3D (meta "skeleton", "bones", "height") holding the skeleton with each of the parts on it, all
## coloured as `colours` says (slot name -> Color; see material()).
static func assemble(parts: Array, colours: Dictionary) -> Node3D:
	var model := Node3D.new()
	model.name = "Townfolk"
	var sk := skeleton()
	model.add_child(sk)
	var mat := material(colours)
	for id in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part_mesh(int(id))
		mi.skin = skin()
		mi.material_override = mat
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
	model.set_meta("skeleton", NodePath("Skeleton"))
	model.set_meta("bones", ROLES)
	model.set_meta("height", height())
	return model


## Who a look is drawn as and in what colours: {"person": an index in townfolk.json's people, "parts": the parts to
## put on them, "colours": slot -> Color (see material)}. The same look always gives the same.
##   look "model" "tf<n>": that person outright;
##   face "hero": the hero in the outfit the character creator chose ("person", one of their body's HERO_OUTFITS),
##   with its "hairdo" (one of HAIRDOS), its "pack" (HERO_PACK if it says none) and no hat, coloured as it chose
##   ("top", "trousers", "hair", "eyes", "skin");
##   anyone else: one of the everyday townsfolk (no costumes) who suits the look: a woman for hair_style 1 (long
##   hair; with no hair_style, the look decides), robes for an "outfit" "robe", long sleeves for a coat, armour or
##   uniform, a hat for a look with a "hat" colour (and no hat without one); coloured with its "shirt", "pants",
##   "hair", "skin" and "hat" (shoes and eyes picked to go with them unless it gives "shoes" or "eyes");
##   outfit "camo" (the trainers): the townsperson's face and hair over a camo jacket with a tall collar, camo
##   trousers and boots, the camo brown for a warm "shirt" colour (reds to yellows), else green, and a pack.
## A look's "pack" (1 on, one of packs(); 0 none) puts that pack on their back, in its "pack_colour" (else its own).
static func outfit(look: Dictionary) -> Dictionary:
	var people: Array = data()["people"]
	var seed := absi(str(look).hash())
	var person := -1
	var colours := {}
	var hero: bool = look.get("face", "") == "hero" or look.is_empty()
	var m := String(look.get("model", ""))
	if m.begins_with("tf") and m.substr(2).is_valid_int():
		person = clampi(int(m.substr(2)), 0, people.size() - 1)
	elif hero:
		var outfits: Array = HERO_OUTFITS.get(String(look.get("body", "male")), HERO_OUTFITS["male"])
		person = clampi(int(look.get("person", outfits[0])), 0, people.size() - 1)
	else:
		person = _choose(look, seed)
	var parts: Array = (people[person]["parts"] as Array).duplicate()
	var kinds: Array = data()["parts"]
	if hero and not m.begins_with("tf"):
		# the hero's own face and hairdo, and no hat
		var hd := clampi(int(look.get("hairdo", HERO_HAIRDO.get(String(look.get("body", "male")), 0))), 0, HAIRDOS.size() - 1)
		parts = parts.filter(func(id) -> bool: return not kinds[int(id)]["kind"] in ["hair", "hat", "head"])
		for id in people[HAIRDOS[hd][0]]["parts"]:
			if kinds[int(id)]["kind"] == "hair":
				parts.append(id)
		for id in people[HERO_FACE]["parts"]:
			if kinds[int(id)]["kind"] == "head":
				parts.append(id)
		# no pack of the kit's own (their pack is the hero's choice)
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "back")
		if not look.has("pack"):
			_wear_pack(parts, colours, HERO_PACK, Color(0, 0, 0, 0))
	var names := {"skin": "skin", "hair": "hair", "eyes": "eyes", "top": "shirt", "bottom": "pants", "shoes": "shoes", "hat": "hat"}
	if hero:
		names["top"] = "top"
		names["bottom"] = "trousers"
	for slot in names:
		if look.has(names[slot]):
			colours[slot] = Color(look[names[slot]])
	colours["skin"] = colours.get("skin", Color(SKIN))
	colours["eyes"] = colours.get("eyes", Color(EYE_COLOURS[seed % EYE_COLOURS.size()]))
	if String(look.get("outfit", "")) == "camo" and not hero and not m.begins_with("tf"):
		var extras: Dictionary = data()["extras"]
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] in ["neck", "head", "hair"])
		for k in CAMO_PARTS:
			parts.append(int(extras[k]))
		var tones: Array = CAMO["brown" if _warm(Color(look.get("shirt", "#40a060"))) else "green"]
		colours["camo"] = tones.map(func(h: String) -> Color: return Color(h))
		colours["top"] = Color(tones[0])
		colours["bottom"] = Color(tones[0])
		colours["shoes"] = Color(BOOTS)
		colours.erase("hat")
		if not look.has("pack"):
			_wear_pack(parts, colours, 1 + (seed / 3) % packs().size(), Color(TRAINER_PACK_COLOURS[(seed / 11) % TRAINER_PACK_COLOURS.size()]))
	if look.has("pack"):
		_wear_pack(parts, colours, int(look["pack"]), Color(look["pack_colour"]) if look.has("pack_colour") else Color(0, 0, 0, 0))
	if not m.begins_with("tf"):
		if not hero and not colours.has("shoes"):
			colours["shoes"] = Color(SHOE_COLOURS[(seed / 7) % SHOE_COLOURS.size()])
		# a hat only for a look that has one; townsfolk with hair can take theirs off
		var hats := parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] == "hat")
		var has_hair := parts.any(func(id) -> bool: return kinds[int(id)]["kind"] == "hair")
		if not look.has("hat") and has_hair:
			for h in hats:
				parts.erase(h)
	return {"person": person, "parts": parts, "colours": colours}


## The packs to wear (townfolk.json "packs"): [{"name", "parts", "colour"}]; a look's "pack" counts from 1.
static func packs() -> Array:
	return data().get("packs", [])


## Puts pack `n` (from 1; 0 or out of range: none) on, in `colour` (alpha 0: its own).
static func _wear_pack(parts: Array, colours: Dictionary, n: int, colour: Color) -> void:
	if n < 1 or n > packs().size():
		return
	var pk: Dictionary = packs()[n - 1]
	for id in pk["parts"]:
		parts.append(int(id))
	colours["pack"] = colour if colour.a > 0.0 else Color(pk["colour"])


## Whether a colour is warm: the reds, oranges, yellows and pinks (a brown camo suits them).
static func _warm(c: Color) -> bool:
	return c.s > 0.15 and (c.h < 0.17 or c.h > 0.88)


## Whether a person in townfolk.json has a tag (the kinds of their parts, and "long_hair", "skirt", "dress",
## "sleeves", "novelty").
static func _has(person: int, tag: String) -> bool:
	return tag in data()["people"][person]["tags"]


## One of the everyday townsfolk for a look (see outfit), the closest fit there is.
static func _choose(look: Dictionary, seed: int) -> int:
	var people: Array = data()["people"]
	var female: bool = int(look["hair_style"]) == 1 if look.has("hair_style") else seed % 2 == 0
	var outfit_kind: String = look.get("outfit", "")
	var tests := []
	# what matters most comes last: it is the last given up when nobody fits everything
	tests.append(func(i: int) -> bool: return _has(i, "hat") == look.has("hat") or not look.has("hat"))
	match outfit_kind:
		"robe":
			tests.append(func(i: int) -> bool: return _has(i, "dress"))
		"coat", "armor", "uniform":
			tests.append(func(i: int) -> bool: return _has(i, "sleeves"))
	tests.append(func(i: int) -> bool: return _feminine(i) == female)
	tests.append(func(i: int) -> bool: return not _has(i, "novelty") or (outfit_kind == "robe" and _has(i, "dress") and _has(i, "hair")))
	var pool := []
	while pool.is_empty() and not tests.is_empty():
		for i in people.size():
			if tests.all(func(t: Callable) -> bool: return t.call(i)):
				pool.append(i)
		tests.pop_front()
	return pool[seed % pool.size()] if not pool.is_empty() else 0


## Whether a person reads as a woman or girl: longer hair, or a skirt or dress.
static func _feminine(person: int) -> bool:
	return _has(person, "long_hair") or _has(person, "skirt") or _has(person, "dress")


## The shader material for a set of colours (made once per set): slot name -> Color, any slot left out keeping the
## kit's own colour (a hat without a colour stays as the kit made it); "camo": the camo's three tones, for the top
## and bottoms.
static func material(colours: Dictionary) -> ShaderMaterial:
	var key := ""
	for s in COLOURED:
		key += (colours[s] as Color).to_html(false) if colours.has(s) else "-"
		key += "/"
	for c in colours.get("camo", []):
		key += (c as Color).to_html(false)
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for s in COLOURED:
		var c: Color = colours.get(s, Color(0, 0, 0, 0))
		mat.set_shader_parameter(s, Color(c.r, c.g, c.b, 1.0 if colours.has(s) else 0.0))
	if colours.has("camo"):
		var tones: Array = colours["camo"]
		mat.set_shader_parameter("camo", 1.0)
		mat.set_shader_parameter("camo_light", tones[0])
		mat.set_shader_parameter("camo_mid", tones[1])
		mat.set_shader_parameter("camo_dark", tones[2])
	if _mats.size() > 96:
		_mats.clear()
	_mats[key] = mat
	return mat
