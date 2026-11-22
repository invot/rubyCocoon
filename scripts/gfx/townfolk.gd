extends RefCounted
## The townsfolk: the "townfolk collection" kit's people (baked by tools/import_townfolk.gd into assets/townfolk/),
## every one put together from the kit's parts on the one skeleton they all share, and coloured by a shader from the
## look: skin, hair, eyes, top, bottoms, shoes and hat each have a colour slot (see townfolk.gdshader); the kit's
## own colours stay on the details (trims, soles, glasses, buttons).

const DIR := "res://assets/townfolk/"
const SHADER := preload("res://scripts/gfx/townfolk.gdshader")
const SurfaceFinish = preload("res://scripts/gfx/surface_finish.gd")
const Wardrobe = preload("res://scripts/data/wardrobe_db.gd")
const MeshStore = preload("res://scripts/gfx/mesh_store.gd")
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
const SLOTS := ["keep", "skin", "hair", "eyes", "top", "bottom", "shoes", "hat", "top_plain", "pack", "glasses",
	"sleeve", "trim", "bottom_trim", "shoe_trim", "hat_trim", "stripe", "stripe_sleeve"]
## The slots with a colour of their own to set (a look's colours by slot name).
const COLOURED := ["skin", "hair", "eyes", "top", "bottom", "shoes", "hat", "pack", "glasses", "sleeve", "trim",
	"bottom_trim", "shoe_trim", "hat_trim"]
## The glasses' slot: the kit paints them in its own colours, so they're moved into it as they load (see _fixed,
## "frame"), each vertex as light or dark against the part's main colour as the kit drew it.
const GLASSES_SLOT := 10
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
## kept (the pack). The wardrobe's parts are dyed all over besides (see _worn, _dye_part).
const PART_FIXES := {3: "solid", 7: "solid", 66: [5, 1.0], 81: [5, 1.0], PACK: 9}
## Parts made from the kit's as they load (named by a word, see part_id): name -> [the kit part it's made from, how].
## "let_down": a skirt let down to the shin (the kit has none so long; see _let_down); "cargo": shorts made baggy, with
## a pocket and flap on each thigh (see _cargo). Their ids follow the kit's own parts.
const DERIVED := {"long_skirt": [174, "let_down"], "cargo_shorts": [33, "cargo"]}
## Below LET_DOWN_FROM (metres, as baked) a let-down skirt is drawn out to reach LET_DOWN_HEM, flaring a little.
const LET_DOWN_FROM := 0.62
const LET_DOWN_HEM := 0.21
const LET_DOWN_FLARE := 0.22
## how much of the hem follows the thigh on its side (the rest the hips)
const LET_DOWN_SWING := 0.45
## Cargo shorts: below CARGO_FROM each leg widens round its middle (CARGO_LEG_X out from the body's), up to
## CARGO_BAGGY times at the hem, which drops CARGO_DROP; each thigh's pocket is a box CARGO_POCKET big (across, high,
## deep), its middle CARGO_POCKET_Y high, in a darker shade of the shorts, with a flap over it.
const CARGO_FROM := 0.6
const CARGO_LEG_X := 0.1
const CARGO_BAGGY := 1.5
const CARGO_DROP := 0.06
const CARGO_POCKET := Vector3(0.026, 0.085, 0.1)
const CARGO_POCKET_Y := 0.4
## The kit's satchels and packs some of its tops come with (on the hero's back over their own pack): never worn as clothes.
const NOT_CLOTHES := [138, 187]
## The second colours of the wardrobe (wardrobe_db.gd): every part the hero can wear is dyed all over as it loads (see
## _dye_part), nothing left in the kit's own colours but what FIXED keeps. Their slots (after SLOTS' first eleven): a
## plain shirt's sleeves ("sleeve": the hero's "top2", anyone else's top), what the kit painted on a shirt in a second
## colour ("trim": the hero's "top2", anyone else keeping the kit's), on pants, shoes and hats in shades of their own
## colour ("bottom_trim", "shoe_trim", "hat_trim": the hero's pants, shoes and hat, anyone else keeping the kit's), and
## a striped shirt's body and sleeves (STRIPES: the top's colour, or in a look with "stripes" bands of it and the trim's).
const SLEEVE_SLOT := 11
const TRIM_SLOT := 12
const BOTTOM_TRIM_SLOT := 13
const SHOE_TRIM_SLOT := 14
const HAT_TRIM_SLOT := 15
const STRIPE_SLOT := 16
const STRIPE_SLEEVE_SLOT := 17
## The striped shirt's parts (wardrobe_db.gd: the Striped Jumper's body and long sleeves; the Smock shares the
## sleeves, plain unless the look asks for stripes).
const STRIPES := [144, 322]
## Shirts whose trim is all one colour (no lighter and darker shades): the Bow Blouse's collar and the skirt below it.
const FLAT_TRIM := [116]
## The laces' colour, whatever the shoes'.
const LACE_WHITE := "#f2f0ea"
## Parts of the wardrobe that keep a colour of their own, whatever they're dyed (the user's 2026-11-17 directions):
## part -> [[where, colour]...], the first that fits a triangle winning. Where: the kit's colour there ("h" hue from,
## to, wrapping past 1; "s" saturation; "v" value) and its middle (metres, as baked: "x" across from the middle, "y"
## height, "z" forward, "r" out from the middle, "dx" across signed); "core": the middle of the white flower above that
## height (a share of its width). Shoes' laces are white; the Runners have a white tip over the toes; the Garden Hat's
## ribbon and bow are red, the Sun Hat's pink; the Duckie Hat's bill is yellow, its eyes sky blue, cheeks pink, the
## flower's stem green and middle yellow; the Wizard Hat's band is black with a gold buckle.
const FIXED := {
	6: [[{"s": [0.0, 0.2], "v": [0.85, 1.0], "y": [0.06, 9.0], "z": [0.08, 9.0]}, LACE_WHITE]],
	21: [[{"s": [0.0, 0.2], "v": [0.85, 1.0], "y": [0.06, 9.0], "z": [0.08, 9.0]}, LACE_WHITE]],
	58: [[{"s": [0.0, 0.2], "v": [0.85, 1.0], "y": [0.08, 9.0], "z": [0.04, 9.0]}, LACE_WHITE],
		[{"y": [0.03, 0.105], "z": [0.19, 9.0]}, "#f6f4ee"]],
	74: [[{"s": [0.0, 0.2], "v": [0.85, 1.0], "y": [0.10, 9.0], "z": [0.08, 9.0]}, LACE_WHITE]],
	79: [[{"h": [0.12, 0.26], "s": [0.4, 1.0], "v": [0.5, 1.0]}, LACE_WHITE]],
	68: [[{"h": [0.45, 0.62], "s": [0.3, 1.0]}, LACE_WHITE]],
	52: [[{"h": [0.62, 0.82], "s": [0.3, 1.0]}, LACE_WHITE]],
	47: [[{"h": [0.48, 0.66], "s": [0.5, 1.0], "y": [0.04, 9.0], "z": [0.03, 9.0]}, LACE_WHITE]],
	115: [[{"h": [0.4, 0.6], "s": [0.15, 1.0]}, "#c8303a"]],
	117: [[{"h": [0.5, 0.7], "s": [0.3, 1.0]}, "#f29ab8"]],
	122: [[{"core": [1.88, 0.3]}, "#f2c530"],
		[{"h": [0.25, 0.45], "s": [0.15, 1.0], "y": [1.76, 9.0]}, "#5aa84a"],
		[{"h": [0.38, 0.5], "s": [0.15, 1.0], "y": [0.0, 1.78]}, "#7cc8f0"],
		[{"h": [0.95, 0.09], "s": [0.25, 1.0], "y": [0.0, 1.75], "x": [0.0, 0.12], "z": [0.3, 9.0]}, "#f2c530"],
		[{"h": [0.95, 0.09], "s": [0.25, 1.0], "y": [0.0, 1.75], "x": [0.12, 9.0]}, "#f29ab0"]],
	WIZARD_HAT: [[{"h": [0.08, 0.18], "s": [0.6, 1.0]}, "#26242a"]],
}
## The Wizard Hat, and its band's buckle (added as it loads, see _buckled): a square gold frame on the front of the
## band, as tall as this share of it.
const WIZARD_HAT := 275
const BUCKLE_GOLD := "#e0b040"
const BUCKLE_SIZE := 0.8
## Glasses have no lenses (the user's 2026-11-15 direction): parts that are only lenses are dropped ("all"), and the
## goggles lose their lens triangles as they load, picked by the colour the kit painted them: "pale" white fill,
## "swim" the swim goggles' lavender, white and red shine inside their pink rims, "dark" the near-black fill and its
## glints between the ski goggles' rims.
const LENSES := {175: "all", 183: "all", 188: "swim", 195: "pale", 196: "dark"}
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
## The bathing suit (outfit "swim"): the first outfit's bare arms and legs, shorts (trunks), shoes (worn in the skin's
## colour: bare feet) and tank top (in the skin's colour for a man, the suit's for a woman); and the suits' colours,
## one picked by the look unless it says ("swimsuit").
const SWIM_PARTS := [0, 1, 3, 6, 7]
const SWIM_COLOURS := ["#e0566a", "#2f8fd0", "#f0a030", "#2aa58a", "#8a5ad0", "#f07aa8", "#1f5f9a"]
## The hero's hair colour when the look has none: the character creator's first (hero_maker.gd SWATCHES "hair").
const HERO_HAIR := "#1a1410"

static var _list := {}
static var _skin: Skin
static var _meshes := {}
static var _mats := {}


static func data() -> Dictionary:
	if _list.is_empty():
		_list = JSON.parse_string(FileAccess.get_file_as_string(DIR + "townfolk.json"))
		# the parts made as they load (DERIVED), after the kit's own
		var parts: Array = _list["parts"]
		for name in DERIVED:
			var from: Dictionary = parts[int(DERIVED[name][0])]
			parts.append({"file": from["file"], "kind": from["kind"], "derived": name})
	return _list


## A part's id: a number as townfolk.json numbers them, or a word naming one made as it loads (DERIVED).
static func part_id(id) -> int:
	if id is String and not (id as String).is_valid_int():
		var parts: Array = data()["parts"]
		return parts.size() - DERIVED.size() + DERIVED.keys().find(id)
	return int(id)


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
		if id == WIZARD_HAT:
			mesh = _buckled(mesh)
		if data()["parts"][id].has("derived"):
			var how: Array = DERIVED[data()["parts"][id]["derived"]]
			mesh = _let_down(mesh) if how[1] == "let_down" else _cargo(mesh)
		if LENSES.has(id):
			mesh = _without_lenses(mesh, LENSES[id])
		var kind: String = data()["parts"][id]["kind"]
		var fix = PART_FIXES.get(id, "eyes" if kind == "head" else ("frame" if kind == "glasses" else null))
		if fix == null and _worn().has(id):
			fix = _worn()[id]
		if fix == null:
			_meshes[id] = mesh
		else:
			_meshes[id] = MeshStore.fetch("folk", str(id), func() -> Mesh: return _fixed(mesh, fix))
		return _meshes[id]
	return _meshes[id]


## A pair of glasses with its lenses cut out (see LENSES): the same mesh without the triangles the rule picks.
static func _without_lenses(mesh: ArrayMesh, rule: String) -> ArrayMesh:
	var out := ArrayMesh.new()
	if rule == "all":
		return out
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			var c := (col[idx[t * 3]] + col[idx[t * 3 + 1]] + col[idx[t * 3 + 2]]) / 3.0
			var x := (pos[idx[t * 3]].x + pos[idx[t * 3 + 1]].x + pos[idx[t * 3 + 2]].x) / 3.0
			var lens := false
			match rule:
				"pale":
					lens = c.get_luminance() > 0.72 and c.s < 0.19
				"swim":
					# (their cups are solid: everything inside each rim goes too)
					var y := (pos[idx[t * 3]].y + pos[idx[t * 3 + 1]].y + pos[idx[t * 3 + 2]].y) / 3.0
					var inside := pow((absf(x) - 0.17) / 0.125, 2.0) + pow((y - 1.377) / 0.1, 2.0) < 1.0
					lens = inside or c.s < 0.3 or c.h > 0.978 or c.h < 0.1
				"dark":
					lens = absf(x) < 0.3 and (c.get_luminance() < 0.1 or (c.get_luminance() > 0.7 and c.s < 0.12))
			if not lens:
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


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
		elif fix is Dictionary:
			_unshared(arrays)
			_dye_part(arrays, fix)
			col = arrays[Mesh.ARRAY_COLOR]
			uv2 = arrays[Mesh.ARRAY_TEX_UV2]
		elif fix == "solid":
			for i in uv2.size():
				uv2[i].y = 1.0
		elif fix == "frame":
			# glasses: all in their own slot, each vertex as much lighter or darker than the part's middle tone as
			# the kit painted it (glints and pale lenses mixed toward white)
			var lums := []
			for c in col:
				lums.append(c.get_luminance())
			lums.sort()
			var mid := maxf(float(lums[lums.size() / 2]) if not lums.is_empty() else 1.0, 0.01)
			for i in uv2.size():
				var r := col[i].get_luminance() / mid
				uv2[i] = Vector2(GLASSES_SLOT, clampf(r, 0.45, 1.0) if r <= 1.0 else 1.0 + clampf((r - 1.0) * 0.35, 0.0, 0.9))
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## A skirt let down (see DERIVED "let_down"): everything below LET_DOWN_FROM drawn downward so its hem reaches LET_DOWN_HEM,
## widening as it goes; it keeps the skirt's weights (mostly the hips, a little each thigh).
static func _let_down(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	var lo := INF
	for s in mesh.get_surface_count():
		for p in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			lo = minf(lo, p.y)
	var k := (LET_DOWN_FROM - LET_DOWN_HEM) / maxf(LET_DOWN_FROM - lo, 0.01)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(pos.size(), 1)
		for i in pos.size():
			var p := pos[i]
			if p.y < LET_DOWN_FROM:
				var t := (LET_DOWN_FROM - p.y) / maxf(LET_DOWN_FROM - lo, 0.01)
				var wide := 1.0 + LET_DOWN_FLARE * t
				pos[i] = Vector3(p.x * wide, LET_DOWN_FROM - (LET_DOWN_FROM - p.y) * k, p.z * wide)
				# it swings with the thigh on its side more and more towards the hem (the middle stays with the hips),
				# so a stride doesn't push the knee through it
				var leg := LET_DOWN_SWING * t * smoothstep(0.015, 0.07, absf(p.x))
				for j in per:
					bones[i * per + j] = 0
					weights[i * per + j] = 0.0
				bones[i * per] = bone_index("hips")
				weights[i * per] = 1.0 - leg
				bones[i * per + 1] = bone_index("l_thigh" if p.x >= 0.0 else "r_thigh")
				weights[i * per + 1] = leg
		arrays[Mesh.ARRAY_VERTEX] = pos
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## Cargo shorts (see DERIVED "cargo"): the shorts' legs widened round their middles below CARGO_FROM, more towards the
## hem (which drops a little), and a box pocket with a flap over it on the outside of each thigh, moving with the
## shorts around it. (One surface, every triangle its own corners.)
static func _cargo(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		_unshared(arrays)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n := pos.size()
		var lo := INF
		for p in pos:
			lo = minf(lo, p.y)
		for i in n:
			var p := pos[i]
			if p.y < CARGO_FROM:
				var t := smoothstep(0.0, 1.0, (CARGO_FROM - p.y) / maxf(CARGO_FROM - lo, 0.01))
				var cx := signf(p.x) * CARGO_LEG_X
				var wide := 1.0 + (CARGO_BAGGY - 1.0) * t
				pos[i] = Vector3(cx + (p.x - cx) * wide, p.y - CARGO_DROP * t, p.z * wide)
		arrays[Mesh.ARRAY_VERTEX] = pos
		for side in [-1.0, 1.0]:
			# the outside of the leg at the pocket's height
			var xo := 0.0
			for p in pos:
				if signf(p.x) == side and absf(p.y - CARGO_POCKET_Y) < 0.015 and absf(p.z) < 0.06:
					xo = maxf(xo, absf(p.x))
			var c := Vector3(side * (xo + CARGO_POCKET.x * 0.5 - 0.012), CARGO_POCKET_Y, 0.0)
			_add_box(arrays, c, CARGO_POCKET, 0.84)
			var flap := Vector3(CARGO_POCKET.x + 0.012, 0.028, CARGO_POCKET.z + 0.012)
			_add_box(arrays, c + Vector3(side * 0.006, CARGO_POCKET.y * 0.5, 0.0), flap, 0.94)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## The Wizard Hat with a buckle on its band (see WIZARD_HAT): a square gold frame of four bars on the band's front.
static func _buckled(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		_unshared(arrays)
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		# the band's front: its triangles in the middle facing forward
		var front := -INF
		var lo := INF
		var hi := -INF
		for t in pos.size() / 3:
			var c := col[t * 3].linear_to_srgb()
			var m := (pos[t * 3] + pos[t * 3 + 1] + pos[t * 3 + 2]) / 3.0
			if _fits(FIXED[WIZARD_HAT][0][0], c, m) and absf(m.x) < 0.08 and m.z > 0.0:
				for k in 3:
					front = maxf(front, pos[t * 3 + k].z)
					lo = minf(lo, pos[t * 3 + k].y)
					hi = maxf(hi, pos[t * 3 + k].y)
		if front > -INF:
			var h := (hi - lo) * BUCKLE_SIZE
			var bar := h * 0.2
			var c := Vector3(0.0, (lo + hi) * 0.5, front + 0.01)
			var gold := Color(BUCKLE_GOLD)
			_add_box(arrays, c + Vector3(0, (h - bar) * 0.5, 0), Vector3(h, bar, 0.03), 1.0, gold)
			_add_box(arrays, c - Vector3(0, (h - bar) * 0.5, 0), Vector3(h, bar, 0.03), 1.0, gold)
			_add_box(arrays, c + Vector3((h - bar) * 0.5, 0, 0), Vector3(bar, h - bar * 2.0, 0.03), 1.0, gold)
			_add_box(arrays, c - Vector3((h - bar) * 0.5, 0, 0), Vector3(bar, h - bar * 2.0, 0.03), 1.0, gold)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_HALF << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return out


## Adds a box (middle, size) to an unshared surface, in the shorts' slot at `light` (see townfolk.gdshader), every
## other attribute (its colour as painted, bones and weights, where it is at rest) the nearest vertex's.
static func _add_box(arrays: Array, c: Vector3, size: Vector3, light: float, colour = null) -> void:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := pos.size()
	var near := 0
	for i in n:
		if pos[i].distance_squared_to(c) < pos[near].distance_squared_to(c):
			near = i
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	# (wound as the shorts' own triangles are: the first's turn against its normal)
	var base_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := signf((pos[1] - pos[0]).cross(pos[2] - pos[0]).dot(base_n[0]))
	var corners := PackedVector3Array()
	var normals := PackedVector3Array()
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o: Vector3 = c + nrm * h
		var du := u * h
		var dv := v * h
		var q := [o - du - dv, o + du - dv, o + du + dv, o - du + dv]
		var order := [0, 1, 2, 0, 2, 3]
		if signf((q[1] - q[0]).cross(q[2] - q[0]).dot(nrm)) != turn:
			order = [0, 2, 1, 0, 3, 2]
		for k in order:
			corners.append(q[k])
			normals.append(nrm)
	var rest_at = arrays[Mesh.ARRAY_CUSTOM0]
	for a in Mesh.ARRAY_MAX:
		if a == Mesh.ARRAY_INDEX or arrays[a] == null:
			continue
		var src = arrays[a]
		var stride: int = src.size() / n
		var dst = src.duplicate()
		for k in corners.size():
			for j in stride:
				dst.append(src[near * stride + j])
		arrays[a] = dst
	var p2: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n2: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var u2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var r2 = arrays[Mesh.ARRAY_CUSTOM0]
	var c2: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var rs: int = (rest_at.size() / n) if rest_at != null else 0
	for k in corners.size():
		p2[n + k] = corners[k]
		n2[n + k] = normals[k]
		# (a colour of its own: kept as painted, the lightness below 0 telling _dye_part to leave it be)
		u2[n + k] = Vector2(5, light) if colour == null else Vector2(0, -1.0)
		if colour != null:
			c2[n + k] = (colour as Color).srgb_to_linear()
		# where it is at rest: the nearest vertex's, moved as far as this corner is from it
		if rs == 8:
			var d := corners[k] - pos[near]
			for j in 3:
				var b := (n + k) * 8 + j * 2
				r2.encode_half(b, rest_at.decode_half(near * 8 + j * 2) + d[j])
	arrays[Mesh.ARRAY_VERTEX] = p2
	arrays[Mesh.ARRAY_NORMAL] = n2
	arrays[Mesh.ARRAY_TEX_UV2] = u2
	arrays[Mesh.ARRAY_COLOR] = c2
	if r2 != null:
		arrays[Mesh.ARRAY_CUSTOM0] = r2


## The parts the wardrobe dresses the hero in (wardrobe_db.gd), each with how _dye_part dyes it: {"as": "shirt",
## "pants", "shoes" or "hat", "id": the part}. (Made once.)
static var _worn_parts := {}


static func _worn() -> Dictionary:
	if not _worn_parts.is_empty():
		return _worn_parts
	var people: Array = data()["people"]
	var kinds: Array = data()["parts"]
	var as_kind := {"shirt": "shirt", "pants": "pants", "shoes": "shoes"}
	for k in as_kind:
		for body in ["male", "female"]:
			for piece in Wardrobe.pieces(k, body, "female"):
				var ids: Array = piece[2] if piece.size() > 2 and piece[2] is Array else people[int(piece[1])]["parts"]
				for raw in ids:
					var id := part_id(raw)
					if kinds[id]["kind"] in Wardrobe.KINDS[k] and not id in NOT_CLOTHES and id != PACK:
						_worn_parts[id] = {"as": as_kind[k], "id": id}
	for hat in Wardrobe.HATS:
		for id in hat[1]:
			_worn_parts[int(id)] = {"as": "hat", "id": int(id)}
	return _worn_parts


## A wardrobe part dyed all over (see _worn): its main colour stays in its piece's slot (the importer's pick, or for
## shoes and anything the importer left alone the colour covering most of it, a saturated one if it covers a third);
## everything else the kit painted is moved to the piece's trim slot, as much lighter or darker than the main colour
## as it was (pants, shoes and hats: one colour), or than the rest of the trim (a shirt's second colour; FLAT_TRIM all
## one). A plain shirt (next to no trim) has its sleeves in the sleeve slot, a striped one (STRIPES) its body and
## sleeves in the stripe slots; what FIXED says keeps its own colour. Skin, the pack and anything else in a slot of its
## own is left as it is. Every triangle has its own corners (see _unshared), each taken as a whole.
static func _dye_part(arrays: Array, how: Dictionary) -> void:
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var as_kind: String = how["as"]
	var id := int(how["id"])
	var slot: int = {"shirt": 4, "pants": 5, "shoes": 6, "hat": 7}[as_kind]
	var trim: int = {"shirt": TRIM_SLOT, "pants": BOTTOM_TRIM_SLOT, "shoes": SHOE_TRIM_SLOT, "hat": HAT_TRIM_SLOT}[as_kind]
	var n := col.size()
	var nt := n / 3
	# each triangle's size, colour as painted (its first corner's) and middle
	var area := PackedFloat32Array()
	area.resize(nt)
	var srgb := []
	var mid := PackedVector3Array()
	mid.resize(nt)
	for t in nt:
		area[t] = (pos[t * 3 + 1] - pos[t * 3]).cross(pos[t * 3 + 2] - pos[t * 3]).length() / 2.0
		srgb.append(col[t * 3].linear_to_srgb())
		mid[t] = (pos[t * 3] + pos[t * 3 + 1] + pos[t * 3 + 2]) / 3.0
	# what's free to dye: the kit's own colours and the piece's slot (not skin, the pack and the like)
	var free := PackedByteArray()
	free.resize(nt)
	for t in nt:
		var sl := int(uv2[t * 3].x + 0.5)
		free[t] = 1 if (sl == 0 or sl == slot) and uv2[t * 3].y >= 0.0 else 0
		if uv2[t * 3].y < 0.0:
			for k in 3:
				uv2[t * 3 + k].y = 1.0
	# what keeps a colour of its own (FIXED): the index of its rule, else -1
	var fixed := PackedInt32Array()
	fixed.resize(nt)
	fixed.fill(-1)
	var rules: Array = FIXED.get(id, [])
	for k in rules.size():
		var r: Dictionary = rules[k][0]
		var core := {}
		if r.has("core"):
			core = _flower_core(srgb, mid, float(r["core"][0]), float(r["core"][1]))
		for t in nt:
			if free[t] == 1 and fixed[t] < 0 and (core.has(t) if r.has("core") else _fits(r, srgb[t], mid[t])):
				fixed[t] = k
	# the main colour: the importer's pick where it made one (not shoes: it often took the sole and laces)
	var main := PackedByteArray()
	main.resize(nt)
	var picked := false
	if as_kind != "shoes":
		for t in nt:
			if free[t] == 1 and fixed[t] < 0 and int(uv2[t * 3].x + 0.5) == slot:
				main[t] = 1
				picked = true
	if not picked:
		var fam := {}
		var total := 0.0
		for t in nt:
			if free[t] == 1 and fixed[t] < 0:
				var f := _family(srgb[t])
				fam[f] = float(fam.get(f, 0.0)) + area[t]
				total += area[t]
		var best := -1
		for f in fam:
			if f >= 0 and (best < 0 or fam[f] > fam[best]):
				best = f
		var main_f := best if best >= 0 and fam[best] >= total / 3.0 else -1
		for t in nt:
			if free[t] == 1 and fixed[t] < 0 and _same(_family(srgb[t]), main_f):
				main[t] = 1
	# how light the main colour is, the trim, and each fixed colour's part
	var lm := 0.0
	var am := 0.0
	var lt := 0.0
	var at := 0.0
	var lf := {}
	for t in nt:
		if free[t] == 0:
			continue
		var l: float = (srgb[t] as Color).get_luminance()
		if fixed[t] >= 0:
			var acc: Vector2 = lf.get(fixed[t], Vector2.ZERO)
			lf[fixed[t]] = acc + Vector2(l * area[t], area[t])
		elif main[t] == 1:
			lm += l * area[t]
			am += area[t]
		else:
			lt += l * area[t]
			at += area[t]
	lm = maxf(lm / am, 0.02) if am > 0.0 else 0.5
	lt = maxf(lt / at, 0.02) if at > 0.0 else lm
	# a shirt with next to no trim is plain: its sleeves take the second colour; a striped shirt's are striped
	var plain := as_kind == "shirt" and at < (am + at) * 0.06
	var striped := id in STRIPES
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var per := 4 if bones == null or (bones as PackedInt32Array).size() <= n * 4 else 8
	var arm := [bone_index("l_arm"), bone_index("l_forearm"), bone_index("l_hand"), bone_index("r_arm"),
		bone_index("r_forearm"), bone_index("r_hand")]
	for t in nt:
		if free[t] == 0:
			continue
		var l: float = (srgb[t] as Color).get_luminance()
		if fixed[t] >= 0:
			# its own colour, keeping the kit's light and shade across it (slot 0: as painted)
			var m: Vector2 = lf[fixed[t]]
			var shade := clampf(1.0 + 0.5 * (l / maxf(m.x / maxf(m.y, 0.0001), 0.02) - 1.0), 0.8, 1.15)
			var c := Color(rules[fixed[t]][1]).srgb_to_linear() * shade
			for k in 3:
				uv2[t * 3 + k] = Vector2(0, 1.0)
				col[t * 3 + k] = Color(c.r, c.g, c.b, 1.0)
			continue
		var y: float
		var to := slot
		if striped and main[t] == 0:
			# (a striped shirt's own trim is striped with the rest: no band of the second colour left over)
			main[t] = 1
			uv2[t * 3].y = 1.0
		if main[t] == 1:
			y = uv2[t * 3].y if int(uv2[t * 3].x + 0.5) == slot else clampf(1.0 + 0.5 * (l / lm - 1.0), 0.7, 1.2)
			if (plain or striped) and bones != null:
				var w := 0.0
				for k in 3:
					for j in per:
						if int(bones[(t * 3 + k) * per + j]) in arm:
							w += float(weights[(t * 3 + k) * per + j])
				if striped:
					to = STRIPE_SLEEVE_SLOT if w > 1.5 else STRIPE_SLOT
				elif w > 1.5:
					to = SLEEVE_SLOT
		else:
			# the shirt's second colour against the rest of the trim; anything else in shades of the piece's own
			var r := 1.0 if id in FLAT_TRIM else l / (lt if as_kind == "shirt" else lm)
			y = maxf(1.0 - 0.65 * (1.0 - r), 0.5) if r < 1.0 else minf(1.0 + 0.5 * (r - 1.0), 1.6)
			to = trim
		for k in 3:
			uv2[t * 3 + k] = Vector2(to, y)
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV2] = uv2


## Whether a triangle fits a FIXED rule: its colour as painted (sRGB) and its middle.
static func _fits(r: Dictionary, c: Color, m: Vector3) -> bool:
	if r.has("h"):
		var lo := float(r["h"][0])
		var hi := float(r["h"][1])
		if not ((c.h >= lo and c.h <= hi) if lo <= hi else (c.h >= lo or c.h <= hi)):
			return false
	var have := {"s": c.s, "v": c.v, "x": absf(m.x), "y": m.y, "z": m.z, "r": Vector2(m.x, m.z).length()}
	for k in have:
		if r.has(k) and (float(have[k]) < float(r[k][0]) or float(have[k]) > float(r[k][1])):
			return false
	return true


## The middle of a white flower (FIXED "core"): of the pale triangles above `above`, those nearer their middle than
## `share` of the farthest (triangle -> true).
static func _flower_core(srgb: Array, mid: PackedVector3Array, above: float, share: float) -> Dictionary:
	var petals := []
	var centre := Vector3.ZERO
	for t in mid.size():
		var c: Color = srgb[t]
		if mid[t].y > above and c.s < 0.15 and c.v > 0.8:
			petals.append(t)
			centre += mid[t]
	var out := {}
	if petals.is_empty():
		return out
	centre /= petals.size()
	var far := 0.0
	for t in petals:
		far = maxf(far, mid[t].distance_to(centre))
	for t in petals:
		if mid[t].distance_to(centre) < far * share:
			out[t] = true
	return out


## A surface with no corners shared between triangles (each triangle its own three vertices), so they can take
## different colour slots without the colour fading across them.
static func _unshared(arrays: Array) -> void:
	var idx = arrays[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		return
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for a in Mesh.ARRAY_MAX:
		if a == Mesh.ARRAY_INDEX or arrays[a] == null:
			continue
		var src = arrays[a]
		var stride: int = src.size() / n
		var dst = src.duplicate()
		dst.resize(idx.size() * stride)
		for t in idx.size():
			for k in stride:
				dst[t * stride + k] = src[idx[t] * stride + k]
		arrays[a] = dst
	arrays[Mesh.ARRAY_INDEX] = null


## Which family of colours (as the importer sorts them, tools/import_townfolk.gd): -1 the greys, else one of 12 hues.
static func _family(c: Color) -> int:
	return -1 if c.s < 0.18 or c.v < 0.12 else int(roundf(c.h * 12.0)) % 12


static func _same(f: int, main: int) -> bool:
	if f == main:
		return true
	return f >= 0 and main >= 0 and (absi(f - main) == 1 or absi(f - main) == 11)


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
	# each painted triangle: "iris", "line", "brow", or stray eye paint restored to "skin"
	var kinds := {}
	var cells := {}
	for t in range(0, idx.size(), 3):
		if int(was[idx[t]].x + 0.5) != 3:
			continue
		var c := col[idx[t]].linear_to_srgb()
		var a := Vector2(v[idx[t]].x, v[idx[t]].y)
		var b := Vector2(v[idx[t + 1]].x, v[idx[t + 1]].y)
		var d := Vector2(v[idx[t + 2]].x, v[idx[t + 2]].y)
		var mid := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if nrm[idx[t]].z < 0.3 or mid.z < 0.15 or mid.y < 1.224 or absf(mid.x) < 0.015:
			# The baked palette also tagged small cheek, jaw and scalp faces as eyes.
			# Apply the face bounds to recolouring itself, not just brow detection.
			kinds[t] = "skin"
			continue
		kinds[t] = "iris" if c.s < EYE_LINE_S and c.h > 0.6 and c.h < 0.9 else "line"
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
				"skin":
					uv2[i] = Vector2(1, 1.0)
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
##   face "hero": the hero as the character creator dressed them: the shirt, pants and shoes its "shirt_style",
##   "pants_style" and "shoes_style" pick from their body's wardrobe (wardrobe_db.gd; an older look's "person", one of
##   HERO_OUTFITS, wears all three from that person), its "hairdo" (one of HAIRDOS), the pack (PACK, in its
##   "pack_colour"), the hat and glasses its "hat_style" and "glasses_style" pick (Wardrobe.HATS, GLASSES; none
##   without), coloured as it chose ("top", "trousers", "shoes", "hat", "glasses_colour", "hair", "eyes", "skin");
##   "face_person" optionally takes just another kit person's head, preserving the chosen hair and clothes.
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
## Temple robes a look can wear (its "robe"), as townfolk.json part ids: "plain" the long robe with a gold collar and
## hem (the kit's wizard's, without the hat), "cape" the long coat with a cape and fur collar (the kit's king's).
const ROBES := {"plain": [278, 268, 54], "hooded": [278, 268, 54, 281], "cape": [273, 272, 268, 266]}


static func outfit(look: Dictionary) -> Dictionary:
	var people: Array = data()["people"]
	# Choosing an expression must not also change the person's hair or clothes.
	var identity := look.duplicate()
	identity.erase("face_person")
	var seed := absi(str(identity).hash())
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
	if look.has("face_person"):
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "head")
		for id in people[clampi(int(look["face_person"]), 0, people.size() - 1)]["parts"]:
			if kinds[int(id)]["kind"] == "head":
				parts.append(id)
	if hero and not m.begins_with("tf"):
		parts = _hero_clothes(look, person, parts)
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
		# the hat and glasses from the wardrobe (Wardrobe.HATS, GLASSES), in their own colours
		var hat_i := int(look.get("hat_style", -1))
		if hat_i >= 0 and hat_i < Wardrobe.HATS.size():
			parts.append_array(Wardrobe.HATS[hat_i][1])
		if look.has("glasses_style"):
			parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "glasses")
			var gi := int(look["glasses_style"])
			if gi >= 0 and gi < Wardrobe.GLASSES.size():
				parts.append_array(Wardrobe.GLASSES[gi][1])
		if look.has("glasses_colour"):
			colours["glasses"] = Color(look["glasses_colour"])
	var swim: bool = look.get("outfit", "") == "swim"
	var swim_female := false
	if swim:
		# A bathing suit on their own head and hair (SWIM_PARTS): bare arms, legs and feet; trunks, or a one-piece
		# for a woman (the tank top in the trunks' colour).
		swim_female = _feminine(person) if not look.has("hair_style") else int(look["hair_style"]) == 1
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] in ["head", "neck", "hair"])
		parts.append_array(SWIM_PARTS)
	var names := {"skin": "skin", "hair": "hair", "eyes": "eyes", "top": "shirt", "bottom": "pants", "shoes": "shoes", "hat": "hat"}
	if hero:
		names["top"] = "top"
		names["bottom"] = "trousers"
	for slot in names:
		if look.has(names[slot]):
			colours[slot] = Color(look[names[slot]])
	colours["skin"] = colours.get("skin", Color(SKIN))
	# a hero with no hair colour chosen (a test's new game, or a save from before the character creator) has the
	# creator's first one, not the kit's own orange-and-white
	if hero and not m.begins_with("tf") and not colours.has("hair"):
		colours["hair"] = Color(HERO_HAIR)
	colours["eyes"] = colours.get("eyes", Color(EYE_COLOURS[seed % EYE_COLOURS.size()]))
	if swim:
		var suit := Color(look["swimsuit"]) if look.has("swimsuit") else Color(SWIM_COLOURS[(seed / 5) % SWIM_COLOURS.size()])
		colours["bottom"] = suit
		colours["top"] = suit if swim_female else colours["skin"]
		colours["shoes"] = colours["skin"]
		colours.erase("hat")
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
		if not look.has("hat") and has_hair and not hero:
			for h in hats:
				parts.erase(h)
		# a uniform's baseball cap instead of their own hat; and no glasses, for a look that says so
		if look.get("cap", false):
			parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "hat")
			parts.append(CAP)
		if not look.get("glasses", true):
			parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "glasses")
		# a temple robe over whoever they are (ROBES): their own face and hair, the robe's top, skirt and sleeves
		if ROBES.has(String(look.get("robe", ""))):
			var robe: Array = ROBES[String(look["robe"])]
			parts = parts.filter(func(id) -> bool: return not kinds[int(id)]["kind"] in ["top", "bottom", "arms", "back", "hat", "hood"])
			parts.append_array(robe)
			if look["robe"] == "hooded":
				parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] != "hair")
			# bareheaded: anyone whose hat was all the hair they had gets a hairdo (long for long hair)
			elif not parts.any(func(id) -> bool: return kinds[int(id)]["kind"] == "hair"):
				var hd: int = HAIRDOS[4 if int(look.get("hair_style", 0)) == 1 else 0][0]
				for id in people[hd]["parts"]:
					if kinds[int(id)]["kind"] == "hair":
						parts.append(id)
	_second_colours(colours, look, hero and not m.begins_with("tf"), swim)
	if look.get("islander", false):
		# The village's woven wrap skirt and sleeveless top, on everyone's own head and hair.
		parts = parts.filter(func(id) -> bool: return kinds[int(id)]["kind"] in ["head", "neck", "hair"])
		parts.append_array([54, 24, 156, 21, 159])
		if not parts.any(func(id) -> bool: return kinds[int(id)]["kind"] == "hair"):
			parts.append(5)
	return {"person": person, "parts": parts, "colours": colours}


## The wardrobe's second colours (see SLEEVE_SLOT): the hero's shirt's second colour ("top2", their top's in a look
## from before it) on its sleeves or trim (and its stripes, for a striped shirt: Wardrobe.SHIRTS), their pants',
## shoes' and hat's trim in their own colours; anyone else's plain sleeves in their top's, the rest of the trim as the
## kit painted it; bare feet (a bathing suit) all skin.
static func _second_colours(colours: Dictionary, look: Dictionary, hero: bool, swim: bool) -> void:
	if hero and not swim:
		var top2: Color = Color(look["top2"]) if look.has("top2") else colours.get("top", Color(0, 0, 0, 0))
		if top2.a > 0.0:
			colours["sleeve"] = top2
			colours["trim"] = top2
		for pair in [["bottom_trim", "bottom"], ["shoe_trim", "shoes"], ["hat_trim", "hat"]]:
			if colours.has(pair[1]):
				colours[pair[0]] = colours[pair[1]]
		if look.has("shirt_style"):
			var list := Wardrobe.pieces("shirt", String(look.get("body", "male")))
			var piece: Array = list[clampi(int(look["shirt_style"]), 0, list.size() - 1)]
			if piece.size() > 3 and piece[3] == true and top2.a > 0.0:
				colours["stripes"] = true
		return
	if colours.has("top"):
		colours["sleeve"] = colours["top"]
	if swim:
		colours["shoe_trim"] = colours["shoes"]


## The hero's clothes (Wardrobe): the shirt, pants and shoes their look's "shirt_style", "pants_style" and
## "shoes_style" pick from their body's wardrobe, each cut from its own kit person, over the rest of `person`'s parts
## (their head, hair and so on, sorted out after). A look without them (from before the wardrobe) wears all three
## from `person`, its outfit as it was.
static func _hero_clothes(look: Dictionary, person: int, parts: Array) -> Array:
	var people: Array = data()["people"]
	var kinds: Array = data()["parts"]
	var body := String(look.get("body", "male"))
	var cut := []
	for k in Wardrobe.KINDS:
		cut.append_array(Wardrobe.KINDS[k])
	var out := parts.filter(func(id) -> bool: return not kinds[int(id)]["kind"] in cut)
	for k in Wardrobe.KINDS:
		var from: Array = people[person]["parts"]
		var key: String = k + "_style"
		if look.has(key):
			var list := Wardrobe.pieces(k, body, String(look.get("gender", "")))
			var piece: Array = list[clampi(int(look[key]), 0, list.size() - 1)]
			from = piece[2] if piece.size() > 2 and piece[2] is Array else people[int(piece[1])]["parts"]
		for raw in from:
			var id := part_id(raw)
			if kinds[id]["kind"] in Wardrobe.KINDS[k] and not id in NOT_CLOTHES:
				out.append(id)
	return out


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
	if colours.get("stripes", false):
		key += "S"
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("cloth_tex", SurfaceFinish.texture("fabric"))
	mat.set_shader_parameter("cloth_level", SurfaceFinish.mean("fabric"))
	mat.set_shader_parameter("skin_tex", SurfaceFinish.texture("satin"))
	mat.set_shader_parameter("skin_level", SurfaceFinish.mean("satin"))
	for s in COLOURED:
		var c: Color = colours.get(s, Color(0, 0, 0, 0))
		mat.set_shader_parameter(s, Color(c.r, c.g, c.b, 1.0 if colours.has(s) else 0.0))
	mat.set_shader_parameter("stripes", 1.0 if colours.get("stripes", false) else 0.0)
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
