extends RefCounted
## People, PS1/PS2 style: the hero and the townsfolk are the character packs' own models (assets/psx/people, baked by
## tools/import_psx_people.gd with anime eyes on their faces), each on its own skeleton, posed and walked here bone
## by bone, with chunkier arms and legs than the packs gave them.
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
## Limbs are drawn chunkier than the packs made them, a toy-like look: how much wider each part is (see _thicken).
const LIMBS := {"l_arm": 1.45, "r_arm": 1.45, "l_forearm": 1.4, "r_forearm": 1.4,
	"l_thigh": 1.25, "r_thigh": 1.25, "l_shin": 1.3, "r_shin": 1.3}
const HAND := 1.2
const FOOT := 1.15
const LEGION := ["21_police", "22_police", "25_female_police", "26_female_police"]
const CENTER_STAFF := ["23_female_doctor", "24_female_doctor", "25_doctor", "26_doctor"]

static var _list := {}
static var _scenes := {}
static var _rigs := {}
static var _fat_meshes := {}


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
	_thicken(model, sk)
	animate(root, 0.0, 0.0, 0.0)
	return root


## Swaps a person's meshes for copies with chunkier arms and legs (made once per mesh, then shared).
static func _thicken(model: Node3D, sk: Skeleton3D) -> void:
	var map: Dictionary = model.get_meta("bones")
	# bone index -> [the bone's far end, in its own space; how much fatter; tapered where it joins the body]
	var fat := {}
	for role in LIMBS:
		var i := sk.find_bone(map[role])
		var end := _bone_end(sk, i)
		if end != Vector3.ZERO:
			fat[i] = [end, LIMBS[role], role.ends_with("_arm") or role.ends_with("thigh")]
		# the hand past each forearm and the foot past each shin, a touch bigger to match
		if role.ends_with("forearm") or role.ends_with("shin"):
			var tip := _far_child(sk, i)
			var tip_end := _bone_end(sk, tip) if tip >= 0 else Vector3.ZERO
			if tip_end != Vector3.ZERO:
				fat[tip] = [tip_end, HAND if role.ends_with("forearm") else FOOT, false]
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or not mi.mesh is ArrayMesh:
			continue
		var key: int = mi.mesh.get_instance_id()
		if not _fat_meshes.has(key):
			_fat_meshes[key] = _fat_mesh(mi.mesh, mi.skin, sk, fat)
		mi.mesh = _fat_meshes[key]


## A copy of a skinned mesh with every vertex on a fattened bone pushed out from that bone's line, weighted by how
## much the bone moves it (so limbs blend smoothly into the body).
static func _fat_mesh(mesh: ArrayMesh, skin: Skin, sk: Skeleton3D, fat: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var fmt: int = mesh.surface_get_format(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := 8 if fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
		if bones.size() == verts.size() * per and weights.size() == bones.size():
			for v in verts.size():
				var p := verts[v]
				var push := Vector3.ZERO
				for k in per:
					var w := weights[v * per + k]
					if w <= 0.0:
						continue
					var bind := bones[v * per + k]
					var b := skin.get_bind_bone(bind)
					if b < 0:
						b = sk.find_bone(skin.get_bind_name(bind))
					if not fat.has(b):
						continue
					var pose := skin.get_bind_pose(bind)
					var q := pose * p
					var end: Vector3 = fat[b][0]
					var raw := q.dot(end) / end.length_squared()
					var grow := float(fat[b][1]) - 1.0
					# no shoulder pads: an upper arm or thigh swells only once it is clear of the body
					if fat[b][2]:
						grow *= smoothstep(-0.05, 0.3, raw)
					push += w * (pose.basis.inverse() * ((q - end * clampf(raw, 0.0, 1.0)) * grow))
				verts[v] = p + push
			arr[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arr, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, mesh.surface_get_material(s))
		out.surface_set_name(s, mesh.surface_get_name(s))
	return out


## Where a bone ends, in its own space: at its longest child (the elbow for an upper arm, the middle finger for a hand).
static func _bone_end(sk: Skeleton3D, i: int) -> Vector3:
	var c := _far_child(sk, i)
	return sk.get_bone_rest(c).origin if c >= 0 else Vector3.ZERO


static func _far_child(sk: Skeleton3D, i: int) -> int:
	var best := -1
	var far := 0.0
	for c in sk.get_bone_children(i):
		var d := sk.get_bone_rest(c).origin.length()
		if d > far:
			far = d
			best = c
	return best


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
	var info := {"lat": lat, "up": -down, "fwd": fwd}
	var rot := func(i: int) -> Quaternion:
		return _global_rest(sk, i).basis.orthonormalized().get_rotation_quaternion() if i >= 0 else Quaternion.IDENTITY
	var bone := func(i: int) -> Dictionary:
		return {"i": i, "parent": rot.call(sk.get_bone_parent(i)), "local": sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()}
	var hips_i := sk.find_bone(map["hips"])
	var hips := _global_rest(sk, hips_i).origin
	for role in ["l_arm", "r_arm", "l_forearm", "r_forearm", "l_thigh", "r_thigh", "l_shin", "r_shin"]:
		info[role] = bone.call(sk.find_bone(map[role]))
	# the torso: the hips, then the chain of spine bones up to the head (posed in turn, each on the one below)
	info["hips"] = bone.call(hips_i)
	var head_i := sk.find_bone(map["head"])
	info["head"] = bone.call(head_i)
	var spine := []
	var j := sk.get_bone_parent(head_i)
	while j >= 0 and j != hips_i:
		spine.push_front(bone.call(j))
		j = sk.get_bone_parent(j)
	info["spine"] = spine
	for side in ["l", "r"]:
		var arm: int = info[side + "_arm"]["i"]
		var fore: int = info[side + "_forearm"]["i"]
		var a := _global_rest(sk, arm).origin
		var dir := (_global_rest(sk, fore).origin - a).normalized()
		var out := signf((a - hips).dot(lat))
		# held a little further out than life, to clear the (thickened) body
		var hang := (down + lat * out * 0.2 + fwd * 0.04).normalized()
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


## Walk cycle and idle, cartoon-bouncy. phase in radians; amount 0 (standing) .. 1 (full stride), up to 1.3 for a
## run. The body springs up as the legs pass under it and squashes a little as each foot lands; the hips twist and rock
## with the stride while the chest twists back and leans into the walk; arms swing wide against the legs, elbows
## bending as they come forward; each knee lifts as its leg comes through.
## Standing, a person breathes, shifts their weight and looks about a little. That motion runs on `t` (seconds;
## by default the clock, offset per person so a crowd doesn't move in step), so call this every frame to see it.
static func animate(rig: Node3D, phase: float, amount: float, t := -1.0) -> void:
	if not rig.has_meta("skeleton"):
		return
	var sk: Skeleton3D = rig.get_meta("skeleton")
	var r := _rig(rig)
	var lat: Vector3 = r["lat"]
	var up: Vector3 = r["up"]
	var fwd: Vector3 = r["fwd"]
	if t < 0.0:
		t = Time.get_ticks_msec() / 1000.0 + float(rig.get_instance_id() % 1000) * 0.61
	var walk := clampf(amount, 0.0, 1.3)
	var still := 1.0 - clampf(amount, 0.0, 1.0)
	var swing := sin(phase) * 0.5 * walk
	var lift := cos(phase) * walk
	# 1 as the legs pass under the body, 0 at the full stride
	var bob := absf(cos(phase))
	var breath := sin(t * 2.2)
	var sway := sin(t * 0.85)
	var rock := sin(phase) * 0.07 * walk + sway * 0.035 * still
	# torso: forward is a positive turn about lat for a bone pointing up
	var hips: Dictionary = r["hips"]
	var g := _turn(sk, hips, hips["parent"], Quaternion(up, swing * 0.28) * Quaternion(fwd, rock))
	var spine: Array = r["spine"]
	var each := 1.0 / maxf(1.0, spine.size())
	var lean := 0.16 * walk * (0.6 + 0.4 * bob) + breath * 0.03 * still
	for bone in spine:
		g = _turn(sk, bone, g, Quaternion(lat, lean * each) * Quaternion(up, -swing * 0.5 * each) * Quaternion(fwd, -rock * each))
	var head: Dictionary = r["head"]
	_turn(sk, head, g, Quaternion(up, sin(t * 0.53) * 0.14 * still) * Quaternion(lat, -0.08 * walk * bob + sin(t * 1.1) * 0.02 * still))
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		# legs: forward is a turn that brings the foot towards +z
		var thigh: Dictionary = r[side + "_thigh"]
		var tg := _turn(sk, thigh, thigh["parent"], Quaternion(lat, -s * swing))
		var shin: Dictionary = r[side + "_shin"]
		_turn(sk, shin, tg, Quaternion(lat, 0.05 + 0.95 * maxf(0.0, s * lift) + 0.18 * walk * (1.0 - bob)))
		# arms: lowered, then swung against the leg on the same side
		var arm: Dictionary = r[side + "_arm"]
		var a_swing := s * swing * 1.05 + sin(t * 2.2 + s) * 0.035 * still
		var ag := _turn(sk, arm, arm["parent"], Quaternion(lat, a_swing) * arm["down"])
		var fore: Dictionary = r[side + "_forearm"]
		_turn(sk, fore, ag, Quaternion(lat, -0.14 - 0.1 * walk - 0.3 * maxf(0.0, -s * swing)))
	var body: Node3D = rig.get_node("Body")
	body.position.y = pow(bob, 1.5) * 0.085 * walk + (breath * 0.5 + 0.5) * 0.01 * still
	var squash := (bob - 0.5) * 0.07 * walk + breath * 0.012 * still
	body.scale = Vector3(1.0 - squash * 0.5, 1.0 + squash, 1.0 - squash * 0.5)


static func height() -> float:
	return 1.78 * SCALE
