extends RefCounted
## People, PS1/PS2 style: the hero and the townsfolk are the character packs' own models (assets/psx/people, baked by
## tools/import_psx_people.gd with anime eyes on their faces), each on its own skeleton, posed and walked here bone
## by bone, with chunkier arms and legs than the packs gave them.
##
## build(look) picks the person who fits a look best:
##   look "model": that person outright (an id from people.json);
##   face "hero": the hero, in the body the character creator gave them ("body": a key of HERO_BODIES), with the top,
##   trousers, hair and eyes it coloured (see dress());
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
const LIMBS := {"l_arm": 1.4, "r_arm": 1.4, "l_forearm": 1.35, "r_forearm": 1.35,
	"l_thigh": 1.55, "r_thigh": 1.55, "l_shin": 1.6, "r_shin": 1.6}
const HAND := 1.2
const FOOT := 1.25
## the body between the hips and the neck, a little fuller to carry the limbs
const TORSO := 1.15
## How far out from the sides the arms hang (the sideways part of their direction, against 1 down).
const ARM_OUT := 0.12
const LEGION := ["21_police", "22_police", "25_female_police", "26_female_police"]
const CENTER_STAFF := ["23_female_doctor", "24_female_doctor", "25_doctor", "26_doctor"]
## The bodies the hero can have (the character creator's choice), never anyone else's.
const HERO_BODIES := {"male": "hero", "female": "50_female"}
## What dress() colours, by the label tools/make_hero_masks.gd gave a texel.
const DYED := {1: "top", 2: "trousers", 3: "hair", 4: "eyes"}

static var _list := {}
static var _scenes := {}
static var _rigs := {}
static var _fat_meshes := {}
static var _dye_src := {}
static var _dyed := {}


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
		return HERO_BODIES.get(String(look.get("body", "male")), "hero")
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
			if people[id]["group"] in groups and not id in HERO_BODIES.values():
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
	dress(root, look)
	animate(root, 0.0, 0.0, 0.0)
	return root


## Colours a hero's top, trousers, hair and eyes as a look asks (its "top", "trousers", "hair" and "eyes"), keeping
## the folds, weave and shading their texture has; whatever the look leaves out stays as the model has it. Again on
## the same rig, it changes them (the character creator). Bodies without masks (everyone but the hero) are left be.
static func dress(rig: Node3D, look: Dictionary) -> void:
	var id: String = rig.get_meta("model")
	var src := _dye_source(id)
	if src.is_empty():
		return
	var want := {}
	for k in DYED.values():
		if look.has(k):
			want[k] = Color(look[k])
	var model: Node3D = rig.get_node("Body").get_child(0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var which := "face" if mi.mesh.surface_get_name(si) == "face" else "body"
			if src.has(which):
				mi.set_surface_override_material(si, _dyed_material(id, which, want))


## A body's textures and masks, read once: for its body and its face texture, the material, the texture's texels and
## where the labelled ones are.
static func _dye_source(id: String) -> Dictionary:
	if _dye_src.has(id):
		return _dye_src[id]
	var out := {}
	var path := DIR + id + "_recolour.res"
	if id in HERO_BODIES.values() and ResourceLoader.exists(path):
		var res: Resource = load(path)
		out["colours"] = res.get_meta("colours")
		if not _scenes.has(id):
			_scenes[id] = load(DIR + id + ".scn")
		var model: Node3D = (_scenes[id] as PackedScene).instantiate()
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			for si in mi.mesh.get_surface_count():
				var which := "face" if mi.mesh.surface_get_name(si) == "face" else "body"
				var mat := mi.get_surface_override_material(si) as StandardMaterial3D
				if out.has(which) or mat == null or mat.albedo_texture == null or not res.has_meta(which):
					continue
				var img := mat.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
				img.clear_mipmaps()
				img.convert(Image.FORMAT_RGBA8)
				var mask: Image = res.get_meta(which)
				var md := mask.get_data()
				var at := PackedInt32Array()
				var lab := PackedByteArray()
				for i in md.size():
					if md[i] > 0:
						at.append(i * 4)
						lab.append(md[i])
				out[which] = {"mat": mat, "img": img, "at": at, "lab": lab}
		model.free()
	_dye_src[id] = out
	return out


## The material for one of a body's textures dyed as `want` says (made once per body and colours, a few kept).
static func _dyed_material(id: String, which: String, want: Dictionary) -> Material:
	var src: Dictionary = _dye_src[id][which]
	if want.is_empty():
		return src["mat"]
	var key := id + "/" + which
	for k in DYED.values():
		key += "/" + (want[k].to_html(false) if want.has(k) else "-")
	if _dyed.has(key):
		return _dyed[key]
	var ref: Dictionary = _dye_src[id]["colours"]
	var tint := {}
	for l in DYED:
		var k: String = DYED[l]
		if want.has(k):
			var rl := Color(ref[k]).get_luminance()
			var tl := maxf((want[k] as Color).get_luminance(), 0.02)
			# dark hair dyed light: its darkest strands softened, or they'd show as black streaks
			tint[l] = [want[k], rl, tl, clampf(sqrt(rl / tl), 0.45, 1.0)]
	var img: Image = src["img"]
	var px := img.get_data()
	var at: PackedInt32Array = src["at"]
	var lab: PackedByteArray = src["lab"]
	for i in at.size():
		var l := lab[i]
		if not tint.has(l):
			continue
		var o := at[i]
		var t: Color = tint[l][0]
		var rl: float = tint[l][1]
		var tl: float = tint[l][2]
		var lum := (0.2126 * px[o] + 0.7152 * px[o + 1] + 0.0722 * px[o + 2]) / 255.0
		# a texel as much darker or lighter than the part's own colour as it was; lighter, by whichever is less:
		# the same proportion (a white shirt's sheen stays faint when it's dyed black) or the same share of the way
		# on to white (dark hair's highlights don't flare when it's dyed blond)
		var nl := tl * pow(lum / maxf(rl, 0.02), tint[l][3]) if lum < rl else tl * lum / maxf(rl, 0.02)
		if lum > rl:
			nl = minf(nl, tl + (1.0 - tl) * (lum - rl) / maxf(1.0 - rl, 0.02))
		var c := Color(t.r, t.g, t.b) * (nl / tl) if nl <= tl else t.lerp(Color.WHITE, (nl - tl) / maxf(1.0 - tl, 0.02))
		px[o] = clampi(roundi(c.r * 255.0), 0, 255)
		px[o + 1] = clampi(roundi(c.g * 255.0), 0, 255)
		px[o + 2] = clampi(roundi(c.b * 255.0), 0, 255)
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, px)
	out.generate_mipmaps()
	var mat: StandardMaterial3D = (src["mat"] as StandardMaterial3D).duplicate()
	mat.albedo_texture = ImageTexture.create_from_image(out)
	# the creator tries many colours: only the latest few are kept
	if _dyed.size() >= 12:
		_dyed.clear()
	_dyed[key] = mat
	return mat


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
	# the spine, from the hips up to (not including) the neck under the head
	var j := sk.get_bone_parent(sk.get_bone_parent(sk.find_bone(map["head"])))
	var hips := sk.find_bone(map["hips"])
	while j >= 0 and j != hips:
		var end := _bone_end(sk, j)
		if end != Vector3.ZERO:
			fat[j] = [end, TORSO, false]
		j = sk.get_bone_parent(j)
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


## Turns a person to look along `dir` (any of the eight ways); smooth: over a moment, as they're animated (see
## animate), rather than at once.
static func face(rig: Node3D, dir: Vector2i, smooth := false) -> void:
	var body: Node3D = rig.get_node("Body")
	var ang := atan2(float(dir.x), float(dir.y)) if dir != Vector2i.ZERO else 0.0
	body.set_meta("yaw_to", ang)
	if not smooth:
		body.rotation.y = ang


## What posing a person's skeleton needs, worked out once per model from its rest pose, in the skeleton's own space
## (whatever its axes and units): the side-to-side axis the limbs swing about, and for each limb bone its index, its
## parent's rest rotation and its own; the arms also get the turn that lowers them from the pack's T or A pose to
## hang at the sides, just clear of the body and a touch forward.
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
		# close to the sides, just clear of the (thickened) body: about 7 degrees out
		var hang := (down + lat * out * ARM_OUT + fwd * 0.03).normalized()
		info[side + "_arm"]["down"] = Quaternion(dir, hang)
	# the legs measured in the Body's space (y up, facing +z, standing on y = 0), to place the feet: where the hip and
	# ankle are, how long the thigh and shin are and how far forward each points at rest, the foot's length; the ankle
	# is the toe's parent (or the toe itself, if the pack's foot is one bone)
	var to_body := model.transform
	var chain := Transform3D.IDENTITY
	n = sk
	while n != model:
		chain = (n as Node3D).transform * chain
		n = n.get_parent()
	to_body = to_body * chain
	for side in ["l", "r"]:
		var shin_i: int = info[side + "_shin"]["i"]
		var toe_i := sk.find_bone(map[side + "_foot"])
		var ank_i := sk.get_bone_parent(toe_i)
		if ank_i == shin_i or ank_i < 0:
			ank_i = toe_i
		var hip_p := to_body * _global_rest(sk, info[side + "_thigh"]["i"]).origin
		var knee_p := to_body * _global_rest(sk, shin_i).origin
		var ank_p := to_body * _global_rest(sk, ank_i).origin
		var toe_p := to_body * _global_rest(sk, toe_i).origin
		info[side + "_ankle"] = bone.call(ank_i)
		info[side + "_leg"] = {"hip": hip_p, "ankle": ank_p, "thigh": hip_p.distance_to(knee_p), "shin": knee_p.distance_to(ank_p),
			"a0": atan2(knee_p.z - hip_p.z, hip_p.y - knee_p.y), "s0": atan2(ank_p.z - knee_p.z, knee_p.y - ank_p.y),
			"foot": maxf(0.1, Vector2(toe_p.z - ank_p.z, toe_p.y - ank_p.y).length())}
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


## How people walk, after the animators' rules for a walk cycle. The cadence follows the speed and the stride lengthens
## with it (step_length), so a planted foot stays put instead of skating. Each foot follows its own path: the heel
## strikes with the toes up, the foot rolls flat, the heel peels up for the toe-off, then the foot swings through,
## lifting; the knee bends just enough for the leg to reach it. The hips settle as each foot lands and rise as the legs
## pass; they twist with the stride while the chest twists back; the arms swing against the legs and trail them a
## little, the forearms trailing the arms; the head stays level, looking ahead. A stroll (speed about 1.7) blends into
## the hero's jog (4.6: leaning in, a moment in the air between steps, elbows bent and pumping) and a sprint (7.8).
## Standing, a person breathes, shifts their weight and looks about. That runs on `t` (seconds; by default the clock,
## offset per person so a crowd doesn't move in step), so call this every frame to see it; `t` also eases turns (face).
## phase: radians, a step every half turn (see phase_for); speed: game units a second, 0 standing.
static func animate(rig: Node3D, phase: float, speed: float, t := -1.0) -> void:
	if not rig.has_meta("skeleton"):
		return
	var sk: Skeleton3D = rig.get_meta("skeleton")
	var r := _rig(rig)
	var lat: Vector3 = r["lat"]
	var up: Vector3 = r["up"]
	var fwd: Vector3 = r["fwd"]
	var body: Node3D = rig.get_node("Body")
	if t < 0.0:
		t = Time.get_ticks_msec() / 1000.0 + float(rig.get_instance_id() % 1000) * 0.61
	# turning to a new facing: quickly, but not all at once
	var dt := clampf(t - float(rig.get_meta("clock", t)), 0.0, 0.1)
	rig.set_meta("clock", t)
	var yaw_to: float = body.get_meta("yaw_to", body.rotation.y)
	if dt <= 0.0 or absf(angle_difference(body.rotation.y, yaw_to)) < 0.02:
		body.rotation.y = yaw_to
	else:
		body.rotation.y = lerp_angle(body.rotation.y, yaw_to, 1.0 - exp(-dt * 18.0))
	speed = maxf(speed, 0.0)
	# how much of a gait there is (0 standing), how much of it is a run, how much a sprint
	var m := clampf(speed / 1.2, 0.0, 1.0)
	var run := smoothstep(2.4, 4.2, speed)
	var sprint := smoothstep(4.6, 7.8, speed)
	var still := 1.0 - m
	var breath := sin(t * 2.2)
	var shift := sin(t * 0.85)
	# the part of each step a foot is on the ground, how far it travels back meanwhile, and how far ahead it lands
	var duty := lerpf(0.62, 0.36, run) - 0.06 * sprint
	var reach := 2.0 * duty * step_length(speed) * m
	var front := reach * lerpf(0.42, 0.34, run)
	var lift := lerpf(0.1, 0.3, run) * m
	var heel := lerpf(0.3, 0.08, run)
	var toe_off := lerpf(0.55, 0.45, run)
	# where the left leg is in its cycle, 0 as its heel strikes; the right leg is half a cycle on
	var u := fposmod(phase / TAU, 1.0)
	# knees a little bent on the move, a little more to run; standing, shifting the weight dips the hips a touch
	var body_y := -lerpf(0.012, 0.05, run) * m - 0.008 * still * (0.5 + 0.5 * shift)
	# a run leaves the ground between steps: lowest with a foot under the body, highest in the air
	body_y += 0.045 * run * m * (0.5 - 0.5 * cos(TAU * 2.0 * (u - duty * 0.5)))
	var feet := {}
	for side in ["l", "r"]:
		var leg: Dictionary = r[side + "_leg"]
		var w := fposmod(u + (0.0 if side == "l" else 0.5), 1.0)
		var z := 0.0
		var y := 0.0
		var toe := 0.0
		var planted := w < duty
		if planted:
			var k := w / duty
			z = front - reach * k
			toe = -heel * (1.0 - smoothstep(0.0, 0.25, k)) + toe_off * smoothstep(0.6, 1.0, k)
		else:
			var k := (w - duty) / (1.0 - duty)
			z = lerpf(front - reach, front, 0.5 - 0.5 * cos(PI * k))
			y = lift * sin(PI * pow(k, 0.75))
			toe = lerpf(toe_off, -heel, smoothstep(0.0, 0.8, k))
		toe *= m
		# rolling up onto the toes lifts the ankle
		y += float(leg["foot"]) * sin(maxf(toe, 0.0))
		var ankle: Vector3 = leg["ankle"]
		var hip: Vector3 = leg["hip"]
		var target := Vector2(ankle.z + z, ankle.y + y)
		feet[side] = [target, toe]
		if planted:
			# the hips can't be higher than a planted foot lets them
			var long: float = (float(leg["thigh"]) + float(leg["shin"])) * 0.995
			var dz := target.x - hip.z
			body_y = minf(body_y, target.y + sqrt(maxf(0.0, long * long - dz * dz)) - hip.y)
	body.position.y = body_y
	# the hips twist so the leg that lands leads; they dip on the side of the leg in the air
	var twist := -lerpf(0.11, 0.16, run) * m * cos(TAU * u)
	var roll := lerpf(0.045, 0.025, run) * m * sin(TAU * u) + 0.03 * still * shift
	var posed := {}
	var hips: Dictionary = r["hips"]
	var g := _turn(sk, hips, hips["parent"], Quaternion(up, twist) * Quaternion(fwd, roll))
	posed[hips["i"]] = g
	# the chest leans into the pace and twists back past straight, so the shoulders turn against the hips
	var lean := lerpf(0.05, 0.2, run) * m + 0.06 * sprint + breath * 0.025 * still
	var spine: Array = r["spine"]
	var each := 1.0 / maxf(1.0, spine.size())
	for bone in spine:
		g = _turn(sk, bone, g, Quaternion(lat, lean * each) * Quaternion(up, -1.5 * twist * each) * Quaternion(fwd, -0.8 * roll * each))
		posed[bone["i"]] = g
	# the head keeps looking ahead, nodding a little behind each step
	var head: Dictionary = r["head"]
	var nod := 0.025 * m * sin(TAU * 2.0 * u - 1.2)
	_turn(sk, head, g, Quaternion(up, 0.5 * twist + sin(t * 0.53) * 0.14 * still)
		* Quaternion(lat, -0.7 * lean + nod + sin(t * 1.1) * 0.02 * still) * Quaternion(fwd, 0.2 * roll))
	# each leg bent to reach its foot (the thigh and shin as a two-bone chain, in the Body's side view)
	for side in ["l", "r"]:
		var leg: Dictionary = r[side + "_leg"]
		var thigh: Dictionary = r[side + "_thigh"]
		var shin: Dictionary = r[side + "_shin"]
		var target: Vector2 = feet[side][0]
		var hip: Vector3 = leg["hip"]
		var d := target - Vector2(hip.z, hip.y + body_y)
		var lt: float = leg["thigh"]
		var ls: float = leg["shin"]
		var dist := clampf(d.length(), absf(lt - ls) + 0.01, (lt + ls) * 0.999)
		var bend := PI - acos(clampf((lt * lt + ls * ls - dist * dist) / (2.0 * lt * ls), -1.0, 1.0))
		# how far forward the thigh and the shin point, from straight down
		var a := atan2(d.x, -d.y) + acos(clampf((lt * lt + dist * dist - ls * ls) / (2.0 * lt * dist), -1.0, 1.0))
		var s := a - bend
		var tg := _place_bone(sk, thigh, _posed_rot(sk, sk.get_bone_parent(thigh["i"]), posed),
			Quaternion(lat, -(a - float(leg["a0"]))) * thigh["parent"] * thigh["local"])
		var sg := _place_bone(sk, shin, tg, Quaternion(lat, -(s - float(leg["s0"]))) * shin["parent"] * shin["local"])
		var ank: Dictionary = r[side + "_ankle"]
		_place_bone(sk, ank, sg, Quaternion(lat, float(feet[side][1])) * ank["parent"] * ank["local"])
	# arms swing against the legs, a little behind them, and as in life further back than forward (the swing centred a
	# little behind the hip); walking, the forearm lifts a little as the arm comes forward; a run bends the elbows to a
	# steady angle and swings from the shoulder less, the hands passing the hips, never reaching out in front
	var arm_amp := lerpf(0.24, 0.34, run) * m + 0.08 * sprint
	var arm_back := lerpf(0.06, 0.2, run) * m
	var ahead_part := lerpf(0.7, 0.5, run)
	var elbow := lerpf(0.14, 0.95, run) * m + 0.12 * still
	for side in ["l", "r"]:
		var sgn := 1.0 if side == "l" else -1.0
		# 1 at the arm's furthest forward: the left arm leads as the right heel lands
		var ahead := -sgn * cos(TAU * (u - 0.06))
		var trail := -sgn * cos(TAU * (u - 0.14))
		var arm: Dictionary = r[side + "_arm"]
		var a_swing := arm_amp * ahead * (ahead_part if ahead > 0.0 else 1.0) - arm_back + sin(t * 2.2 + sgn) * 0.03 * still
		var ag := _turn(sk, arm, arm["parent"], Quaternion(lat, -a_swing) * arm["down"])
		var fore: Dictionary = r[side + "_forearm"]
		_turn(sk, fore, ag, Quaternion(lat, -(elbow + lerpf(0.22, 0.08, run) * m * maxf(0.0, trail))))


## How far one step carries a person at `speed` (game units a second): the faster, the longer the stride (a stroll's
## step is about 0.67, the hero's jog about 1.2, a sprint 1.7).
static func step_length(speed: float) -> float:
	return clampf(0.38 + 0.17 * speed, 0.5, 1.7)


## The walk's phase (radians) after going `dist` at `speed`: half a turn a step, so the feet keep pace with the ground.
static func phase_for(dist: float, speed: float) -> float:
	return dist * PI / step_length(speed)


## Poses one bone so it ends up turned `g` in skeleton space, under a parent now turned `parent`. Returns g.
static func _place_bone(sk: Skeleton3D, bone: Dictionary, parent: Quaternion, g: Quaternion) -> Quaternion:
	sk.set_bone_pose_rotation(bone["i"], parent.inverse() * g)
	return g


## A bone's skeleton-space rotation as posed this frame: the bones posed so far from `posed`, others from their parent.
static func _posed_rot(sk: Skeleton3D, i: int, posed: Dictionary) -> Quaternion:
	if i < 0:
		return Quaternion.IDENTITY
	if posed.has(i):
		return posed[i]
	return _posed_rot(sk, sk.get_bone_parent(i), posed) * sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()


static func height() -> float:
	return 1.78 * SCALE
