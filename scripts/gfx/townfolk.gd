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
## The pack everyone wears: the round backpack and its straps that person 43 wears (a part some of the kit's people
## have as a top, its own colour slot given it by PART_FIXES), and the hero's colour for it unless they chose one.
## (The packs the kit baked on their own, townfolk.json "packs", sat badly: straps floating off the chest.)
const PACK := 103
const PACK_COLOUR := "#7a4a2a"
## The trainers' packs' colours, one picked for each (canvas and leather).
const TRAINER_PACK_COLOURS := ["#6a7a4a", "#7a5a3a", "#4a5a6a", "#8a6a4a", "#5a4a3a"]
## The top of the head, on the kit's body.
const HEAD_TOP := 165.6
## The kit's baseball cap (a part), for a look that asks for one ("cap"), and where a badge sits on the front of its
## crown, just above the brim (metres, as baked: see fit), leaning back with it (radians).
const CAP := 13
const CAP_BADGE := Vector3(0, 1.665, 0.335)
const CAP_BADGE_TILT := -0.35
## The hero's outfits for each body (people in townfolk.json, worn with the hero's own hairdo and colours), the first
## the one they begin in.
const HERO_OUTFITS := {"male": [0, 13, 4, 10, 11, 29],
	"female": [62, 7, 8, 31, 72, 74, 77, 63, 66, 33]}
## Parts of the kit recoloured as they load (part -> how; see _fixed): "solid": its slot's colour flat, without the
## kit's shading (the first outfit's top and shorts); [slot, lightness]: all of it in that slot (trousers whose cuffs
## kept the kit's tan and clipped, and shorts in patches); a slot alone: all of it in that slot, its light and dark
## kept (the pack); "laces": shoes all one colour but for their light blue laces, which take the top's.
const PART_FIXES := {3: "solid", 7: "solid", 66: [5, 1.0], 81: [5, 1.0], 68: "laces", PACK: 9}
## A head's eyes (see _fix_eyes): the paint at least this saturated is the outline (or a brow), not the iris; the
## outline's colour; the cells the paint is laid out in to find the brows (metres).
const EYE_LINE_S := 0.66
const EYE_LINE := "#1e1618"
const EYE_CELL := 0.005
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
		var mesh: ArrayMesh = load(DIR + "parts/%s.res" % data()["parts"][id]["file"])
		var fix = PART_FIXES.get(id, "eyes" if data()["parts"][id]["kind"] == "head" else null)
		_meshes[id] = mesh if fix == null else _fixed(mesh, fix)
		return _meshes[id]
	return _meshes[id]


## A part recoloured as it loads (see PART_FIXES, and _fix_eyes for a head's eyes): a new mesh with the same
## vertices, their colour slots changed. (It goes without the kit's smaller versions for far away: these are small.)
static func _fixed(mesh: ArrayMesh, fix) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if fix is String and fix == "eyes":
			_fix_eyes(arrays)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			continue
		var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if fix is Array:
			for i in uv2.size():
				uv2[i] = Vector2(fix[0], fix[1])
		elif fix is int:
			for i in uv2.size():
				uv2[i].x = fix
		elif fix == "solid":
			for i in uv2.size():
				uv2[i].y = 1.0
		elif fix == "laces":
			# the shoes one colour (their own slot's, the kit's average of it), the light blue laces the top's
			var sum := Color(0, 0, 0, 0)
			for i in col.size():
				if int(uv2[i].x + 0.5) == 6:
					sum += col[i]
			var own := sum / maxf(sum.a, 1.0)
			own.a = 1.0
			for i in col.size():
				var c := col[i].linear_to_srgb()
				if c.s > 0.3 and c.h > 0.45 and c.h < 0.62:
					uv2[i] = Vector2(4, 1.0)
				else:
					uv2[i] = Vector2(6, 1.0)
					col[i] = own
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## The kit paints each eye in purples, and the importer gave them all the eye colour (tools/import_townfolk.gd
## _colour): the outline round the eye and the brow over it (the saturated purples) as well as the iris (the muted
## ones). As a head loads, the outline (and the lashes, the reds at its corners) turns a dark brown-black, each brow
## takes the hair colour, a shade darker, and the iris alone keeps the eye colour, its light and dark spread round the
## colour itself. A brow is found as the importer finds it: on the front of the face, the topmost patch of paint over
## an eye, when there are three or more, or two with a gap between them.
static func _fix_eyes(arrays: Array) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var was := uv2.duplicate()
	# each painted triangle: "iris", "line" (outline, lashes and brows to begin with) or "brow"
	var kinds := {}
	var cells := {}
	for t in range(0, idx.size(), 3):
		if int(was[idx[t]].x + 0.5) != 3:
			continue
		var c := col[idx[t]].linear_to_srgb()
		kinds[t] = "iris" if c.s < EYE_LINE_S and c.h > 0.6 and c.h < 0.9 else "line"
		var a := Vector2(v[idx[t]].x, v[idx[t]].y)
		var b := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].y)
		var d := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].y)
		var mid := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if nrm[idx[t]].z < 0.3 or mid.z < 0.15 or mid.y < 1.224 or absf(mid.x) < 0.015:
			continue
		# the cells it covers (and the one its middle is in, if it's too small to cover any)
		var x0 := floori(minf(a.x, minf(b.x, d.x)) / EYE_CELL)
		var x1 := floori(maxf(a.x, maxf(b.x, d.x)) / EYE_CELL)
		var y0 := floori(minf(a.y, minf(b.y, d.y)) / EYE_CELL)
		var y1 := floori(maxf(a.y, maxf(b.y, d.y)) / EYE_CELL)
		cells[Vector2i(floori(mid.x / EYE_CELL), floori(mid.y / EYE_CELL))] = true
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				if Geometry2D.point_is_inside_triangle((Vector2(cx, cy) + Vector2(0.5, 0.5)) * EYE_CELL, a, b, d):
					cells[Vector2i(cx, cy)] = true
	# the patches of paint on each side (cells touching, corners too), and each side's brow
	var brows := []
	for side in [-1, 1]:
		var patches := []
		var seen := {}
		for k in cells:
			if seen.has(k) or signi(k.x * 2 + 1) != side:
				continue
			var box := Rect2i(k, Vector2i.ZERO)
			var q: Array = [k]
			seen[k] = true
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				box = box.expand(p)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var n := p + Vector2i(dx, dy)
						if cells.has(n) and not seen.has(n):
							seen[n] = true
							q.append(n)
			patches.append(box)
		patches.sort_custom(func(p: Rect2i, r: Rect2i) -> bool: return p.end.y > r.end.y)
		if patches.size() >= 3 or (patches.size() == 2 and (patches[0].position.y - patches[1].end.y) * EYE_CELL > 0.01):
			brows.append(Rect2(Vector2(patches[0].position) * EYE_CELL, Vector2(patches[0].size + Vector2i.ONE) * EYE_CELL))
	var iris := 0.0
	var n_iris := 0
	for t in kinds:
		var mid := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if kinds[t] == "line" and brows.any(func(r: Rect2) -> bool: return r.grow(EYE_CELL).has_point(Vector2(mid.x, mid.y))):
			kinds[t] = "brow"
		elif kinds[t] == "iris":
			for k in 3:
				iris += was[idx[t + k]].y
			n_iris += 3
	var mean := iris / maxf(n_iris, 1.0)
	var dark := Color(EYE_LINE).srgb_to_linear()
	for t in kinds:
		for k in 3:
			var i := idx[t + k]
			match kinds[t]:
				"brow":
					# (dark, too, for someone with no hair colour of their own)
					uv2[i] = Vector2(2, 0.85)
					col[i] = dark
				"line":
					uv2[i] = Vector2(0, 1.0)
					col[i] = dark
				_:
					uv2[i] = Vector2(3, clampf(was[i].y / mean, 0.8, 1.35))
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV2] = uv2


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
##   with its "hairdo" (one of HAIRDOS), the pack (PACK, in its "pack_colour") and no hat, coloured as it chose
##   ("top", "trousers", "hair", "eyes", "skin");
##   anyone else: one of the everyday townsfolk (no costumes) who suits the look: a woman for hair_style 1 (long
##   hair; with no hair_style, the look decides), robes for an "outfit" "robe", long sleeves for a coat, armour or
##   uniform, a hat for a look with a "hat" colour (and no hat without one); coloured with its "shirt", "pants",
##   "hair", "skin" and "hat" (shoes and eyes picked to go with them unless it gives "shoes" or "eyes");
##   outfit "camo" (the trainers): the townsperson's face and hair over a camo jacket with a tall collar, camo
##   trousers and boots, the camo brown for a warm "shirt" colour (reds to yellows), else green, and a pack.
## A look's "cap" (true) swaps their hat for the kit's baseball cap (CAP), in the "hat" colour; "glasses" false takes
## their glasses off.
## A look's "pack" (1 on; 0 none) puts the pack on their back, in its "pack_colour"; anyone else in the pack (some of
## the kit's people wear it) has it in their top's colour.
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
		# no pack of the kit's own: the hero's is the one pack, in the colour they chose
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "back")
		_wear_pack(parts, colours, Color(look.get("pack_colour", PACK_COLOUR)))
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
			_wear_pack(parts, colours, Color(TRAINER_PACK_COLOURS[(seed / 11) % TRAINER_PACK_COLOURS.size()]))
	if int(look.get("pack", 0)) > 0 and not hero:
		_wear_pack(parts, colours, Color(look["pack_colour"]) if look.has("pack_colour") else Color(0, 0, 0, 0))
	if _wears_pack(parts) and not colours.has("pack") and colours.has("top"):
		colours["pack"] = colours["top"]
	if not m.begins_with("tf"):
		if not hero and not colours.has("shoes"):
			colours["shoes"] = Color(SHOE_COLOURS[(seed / 7) % SHOE_COLOURS.size()])
		# a hat only for a look that has one; townsfolk with hair can take theirs off
		var hats := parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] == "hat")
		var has_hair := parts.any(func(id) -> bool: return kinds[int(id)]["kind"] == "hair")
		if not look.has("hat") and has_hair:
			for h in hats:
				parts.erase(h)
		# a uniform's baseball cap instead of their own hat; and no glasses, for a look that says so
		if look.get("cap", false):
			parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "hat")
			parts.append(CAP)
		if not look.get("glasses", true):
			parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "glasses")
	return {"person": person, "parts": parts, "colours": colours}


## Puts the pack on (if they aren't wearing it already), in `colour` (alpha 0: their top's; see outfit).
static func _wear_pack(parts: Array, colours: Dictionary, colour: Color) -> void:
	if not _wears_pack(parts):
		parts.append(PACK)
	if colour.a > 0.0:
		colours["pack"] = colour


## Whether `parts` has the pack (their ids as townfolk.json has them, floats, or as ints).
static func _wears_pack(parts: Array) -> bool:
	return parts.any(func(id) -> bool: return int(id) == PACK)


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
