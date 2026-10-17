extends RefCounted
## People, PS1/PS2 style: the hero and the townsfolk are the character packs' own models (assets/psx/people, baked by
## tools/import_psx_people.gd with anime eyes on their faces), each on its own skeleton, posed and walked here bone
## by bone.
##
## build(look) picks the person who fits a look best:
##   look "model": that person outright (an id from people.json);
##   face "hero": the hero;
##   outfit "armor": the Umbral Legion, in black tactical gear; "robe": the elders; Beast Center staff (a white
##   "uniform" with red trim): the doctors and nurses;
##   hair_style 1 (long hair) is a woman, other styles a man; with no hair_style the look itself decides;
## then the closest colours of shirt, trousers, skin and hair win, with a little variety among the closest few.
## The same look always gives the same person.
## Rig: Person > Body (rotate for facing) > the baked person, scaled from metres. Faces +Z.

const DIR := "res://assets/psx/people/"
## Game units per metre: a man of 1.75 m stands about 1.65 tall, taller than the doors the old chibi people used
## (the buildings are to grow to suit).
const SCALE := 0.94
## Heads are drawn larger than life, a touch of anime proportion.
const HEAD_SCALE := 1.25
const LEGION := ["21_police", "22_police", "25_female_police", "26_female_police"]
const CENTER_STAFF := ["23_female_doctor", "24_female_doctor", "25_doctor", "26_doctor"]

static var _list := {}
static var _scenes := {}
static var _rigs := {}


static func _people() -> Dictionary:
	if _list.is_empty():
		_list = JSON.parse_string(FileAccess.get_file_as_string(DIR + "people.json"))
	return _list


## The person (an id in people.json) a look is drawn as.
static func model_for(look: Dictionary) -> String:
	var people := _people()
	if people.has(String(look.get("model", ""))):
		return look["model"]
	if look.get("face", "") == "hero" or look.is_empty():
		return "hero"
	var seed := absi(str(look).hash())
	var female: bool = int(look["hair_style"]) == 1 if look.has("hair_style") else seed % 2 == 0
	var outfit: String = look.get("outfit", "")
	var shirt := Color(look.get("shirt", "#808080"))
	var pool := []
	if outfit == "armor":
		pool = LEGION
	elif outfit == "uniform" and shirt.get_luminance() > 0.85 and _is_red(Color(look.get("trim", "#000000"))):
		pool = CENTER_STAFF
	else:
		# robes, and white or grey hair, are the elders
		var hair := Color(look.get("hair", "#000000"))
		var groups := ["elder"] if outfit == "robe" or (hair.s < 0.2 and hair.v > 0.6) else ["town"]
		for id in people:
			if people[id]["group"] in groups:
				pool.append(id)
	# the woman's or man's version where the pool has both
	var matched := pool.filter(func(id: String) -> bool: return bool(people[id]["female"]) == female)
	if not matched.is_empty():
		pool = matched
	# closest colours first; then one of the closest few
	var want := {"shirt": shirt, "pants": Color(look.get("pants", "#404040")), "skin": Color(look.get("skin", "#f0c8a0")),
		"hair": Color(look.get("hair", "#2a1a10"))}
	var weight := {"shirt": 2.0, "pants": 1.0, "skin": 1.5, "hair": 1.0}
	var scored := []
	for id in pool:
		var pal: Dictionary = people[id]["palette"]
		var d := 0.0
		for k in want:
			d += weight[k] * _distance(want[k], Color(pal[k]))
		scored.append([d, id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var pick := mini(scored.size(), 3)
	return scored[seed % pick][1] if pick > 0 else "01"


static func _is_red(c: Color) -> bool:
	return c.r > 0.6 and c.g < 0.35 and c.b < 0.4


## How different two colours look: lightness counts, and so does hue where the colours aren't grey.
static func _distance(a: Color, b: Color) -> float:
	var dl := a.get_luminance() - b.get_luminance()
	var dc := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return dl * dl * 2.0 + dc.length_squared()


## Builds a rig. Children: Body (rotate for facing) > the baked person.
static func build(look: Dictionary) -> Node3D:
	var id := model_for(look)
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".scn")
	var model: Node3D = (_scenes[id] as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	var root := Node3D.new()
	root.name = "Person"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	body.add_child(model)
	root.set_meta("model", id)
	var sk: Skeleton3D = model.get_node(model.get_meta("skeleton"))
	root.set_meta("skeleton", sk)
	var head := sk.find_bone(model.get_meta("bones")["head"])
	sk.set_bone_pose_scale(head, sk.get_bone_rest(head).basis.get_scale() * HEAD_SCALE)
	animate(root, 0.0, 0.0)
	return root


static func face(rig: Node3D, dir: Vector2i) -> void:
	var body: Node3D = rig.get_node("Body")
	var ang := 0.0
	if dir == Vector2i(0, -1):
		ang = PI
	elif dir == Vector2i(1, 0):
		ang = PI / 2.0
	elif dir == Vector2i(-1, 0):
		ang = -PI / 2.0
	body.rotation.y = ang


## What posing a person's skeleton needs, worked out once per model from its rest pose, in the skeleton's own space
## (whatever its axes and units): the side-to-side axis the limbs swing about, and for each limb bone its index, its
## parent's rest rotation and its own; the arms also get the turn that lowers them from the pack's T or A pose to
## hang at the sides, a little out and forward.
static func _rig(rig: Node3D) -> Dictionary:
	var id: String = rig.get_meta("model")
	if _rigs.has(id):
		return _rigs[id]
	var sk: Skeleton3D = rig.get_meta("skeleton")
	var model: Node3D = rig.get_node("Body").get_child(0)
	var map: Dictionary = model.get_meta("bones")
	# the skeleton's axes as seen from the person (y up, facing +z)
	var basis := Basis.IDENTITY
	var n: Node = sk
	while n != model:
		basis = (n as Node3D).transform.basis * basis
		n = n.get_parent()
	var inv := basis.orthonormalized().inverse()
	var lat := (inv * Vector3.RIGHT).normalized()
	var down := (inv * Vector3.DOWN).normalized()
	var fwd := (inv * Vector3.BACK).normalized()
	var info := {"lat": lat}
	var rot := func(i: int) -> Quaternion:
		return _global_rest(sk, i).basis.orthonormalized().get_rotation_quaternion() if i >= 0 else Quaternion.IDENTITY
	var hips := _global_rest(sk, sk.find_bone(map["hips"])).origin
	for role in ["l_arm", "r_arm", "l_forearm", "r_forearm", "l_thigh", "r_thigh", "l_shin", "r_shin"]:
		var i := sk.find_bone(map[role])
		info[role] = {"i": i, "parent": rot.call(sk.get_bone_parent(i)),
			"local": sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()}
	for side in ["l", "r"]:
		var arm: int = info[side + "_arm"]["i"]
		var fore: int = info[side + "_forearm"]["i"]
		var a := _global_rest(sk, arm).origin
		var dir := (_global_rest(sk, fore).origin - a).normalized()
		var out := signf((a - hips).dot(lat))
		var hang := (down + lat * out * 0.14 + fwd * 0.04).normalized()
		info[side + "_arm"]["down"] = Quaternion(dir, hang)
	_rigs[id] = info
	return info


## A bone's rest transform in skeleton space, put together from the rests along its chain (asking the skeleton
## instead, before it is in the scene tree, leaves the first pose set on it unseen).
static func _global_rest(sk: Skeleton3D, i: int) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while i >= 0:
		xf = sk.get_bone_rest(i) * xf
		i = sk.get_bone_parent(i)
	return xf


## Turns one bone by a rotation given in skeleton space, on top of its rest pose; the parent's skeleton-space
## rotation (rest, or as just posed) is passed in. Returns the bone's new skeleton-space rotation.
static func _turn(sk: Skeleton3D, bone: Dictionary, parent: Quaternion, by: Quaternion) -> Quaternion:
	var g: Quaternion = by * parent * bone["local"]
	sk.set_bone_pose_rotation(bone["i"], parent.inverse() * g)
	return g


## Walk cycle. phase in radians; amount 0 (standing) .. 1 (full stride). Arms hang at the sides, elbows a little
## bent, and swing against the legs; each knee bends as its leg comes forward.
static func animate(rig: Node3D, phase: float, amount: float) -> void:
	if not rig.has_meta("skeleton"):
		return
	var sk: Skeleton3D = rig.get_meta("skeleton")
	var r := _rig(rig)
	var lat: Vector3 = r["lat"]
	var swing := sin(phase) * 0.45 * amount
	var lift := cos(phase) * amount
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		# legs: forward is a turn that brings the foot towards +z
		var thigh: Dictionary = r[side + "_thigh"]
		var tg := _turn(sk, thigh, thigh["parent"], Quaternion(lat, -s * swing))
		var shin: Dictionary = r[side + "_shin"]
		_turn(sk, shin, tg, Quaternion(lat, 0.05 + 0.75 * maxf(0.0, s * lift)))
		# arms: lowered, then swung against the leg on the same side
		var arm: Dictionary = r[side + "_arm"]
		var ag := _turn(sk, arm, arm["parent"], Quaternion(lat, s * swing * 1.1) * arm["down"])
		var fore: Dictionary = r[side + "_forearm"]
		_turn(sk, fore, ag, Quaternion(lat, -0.12 - 0.2 * maxf(0.0, -s * swing)))
	rig.get_node("Body").position.y = absf(sin(phase)) * 0.025 * amount


static func height() -> float:
	return 1.78 * SCALE
