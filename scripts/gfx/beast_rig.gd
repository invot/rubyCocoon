extends Node3D
## A beast as it stands in the world: its model (assets/beasts/<form>.res, tools/import_new_beasts.gd) on a skeleton
## of one bone per part, painted by its look (scripts/data/beast_looks.gd) with the toon shader (beast_toon.gdshader),
## and moved by hand rather than by baked animations, so every form, and every merge of two, moves the same way:
##   - idle: a bouncy bob, squashing down and springing up, the head nodding after it and the tail swaying; flyers
##     hover and flap
##   - walk: legs stepping (a trot on four, side by side on two) with the arms swinging against them; serpents
##     wriggle, blobs hop, flyers fly
##   - lie: lying down to rest (legs folded, the head low, the eyes half shut); a worm in its hole sinks into it
##   - attack(): once, then back to what it was doing: rearing back, then lunging, its arms (claws, wings) striking
## A ghost is the same beast in black and purple, wrapped in smoke.
## A merged beast (setup_merge()) is built from two parents' models: one gives the frame (the body, and what the
## other doesn't), the other some of its parts (head, arms, wings, tail, legs), each set where the frame's own was;
## it's painted in one parent's colours.
## Beast space: facing +x, standing on y = 0, its larger measure 1 unit (scale the node for its size).

const Looks = preload("res://scripts/data/beast_looks.gd")
const SHADER = preload("res://scripts/gfx/beast_toon.gdshader")
const DIR := "res://assets/beasts/"
const PARTS := Looks.PARTS
## the parts a merge can take from the parent that doesn't give the frame
const GROUPS := {"head": ["head"], "arms": ["arm_l", "arm_r"], "wings": ["wing_l", "wing_r"], "tail": ["tail"],
	"legs": ["leg_fl", "leg_fr", "leg_bl", "leg_br"]}
## how long an attack takes (s), and when in it the blow lands (0..1)
const ATTACK_TIME := 0.75
const HIT_AT := 0.42
## flyers hover this high while awake
const HOVER := 0.22

## the blow of attack() lands
signal hit

var form := ""
## quad, biped, flyer, serpent or blob (the frame's)
var kind := "quad"
## idle, walk or lie (it eases from one to the next)
var state := "idle"
var ghost := false
## steps per second while walking, as a part of its usual pace
var pace := 1.0

var pivot: Node3D
var skel: Skeleton3D
var mats: Array[ShaderMaterial] = []
var smoke: CPUParticles3D = null

## each piece's own eyelid (eye_style.x), to close them for blinking and sleeping
var _lids: Array[float] = []
var _joint := {}
var _rest := {}
var _centre := Vector3.ZERO
## how far the body sinks lying down, and the frame's height
var _drop := 0.0
var _height := 1.0
var _hole := false
var _t := 0.0
var _bounce := 0.0
var _step := 0.0
var _flap := 0.0
var _atk := -1.0
var _walk := 0.0
var _lie := 0.0
var _blink := 2.0

## per form: {mesh, arrays, joints, parents, kind, lo, hi} (lo/hi: each part's bounds)
static var _forms := {}


## A beast of this form (as "dino_3").
func setup(f: String, as_ghost := false) -> void:
	_build({"frame": f}, as_ghost)


## A merged beast of two forms, mixed by the seed: which gives the frame, which its colours, what the other gives.
func setup_merge(a: String, b: String, seed_n: int, as_ghost := false) -> void:
	_build(merge_recipe(a, b, seed_n), as_ghost)


## How a merge of a and b is put together: {frame, colours, head/arms/wings/tail/legs: the form each comes from}.
## The parent that isn't the frame gives at least one part (two, when it can): a head only onto a frame with a head
## of its own (a face drawn on the body stays the body's), legs only for as many legs.
static func merge_recipe(a: String, b: String, seed_n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var frame := a if rng.randf() < 0.5 else b
	var other := b if frame == a else a
	var r := {"frame": frame, "colours": a if rng.randf() < 0.5 else b}
	var fi := info(frame)
	var oi := info(other)
	var can := []
	for g in GROUPS:
		if not _has_group(oi, g):
			continue
		if g == "head" and not _has_group(fi, "head"):
			continue
		if g == "legs" and (_has_group(fi, "legs") != _has_group(oi, "legs") or fi["lo"].has("leg_bl") != oi["lo"].has("leg_bl")):
			continue
		can.append(g)
	var order := can.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var want := mini(order.size(), 2 + (1 if rng.randf() < 0.35 else 0))
	for i in want:
		r[order[i]] = other
	return r


static func _has_group(fi: Dictionary, g: String) -> bool:
	for p in GROUPS[g]:
		if fi["lo"].has(p):
			return true
	return false


static func info(f: String) -> Dictionary:
	if _forms.has(f):
		return _forms[f]
	var m: ArrayMesh = load(DIR + f + ".res")
	var arrays := m.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lo := {}
	var hi := {}
	for i in verts.size():
		var p: String = PARTS[clampi(roundi(cols[i].r * 15.0), 0, PARTS.size() - 1)]
		if not lo.has(p):
			lo[p] = verts[i]
			hi[p] = verts[i]
		else:
			lo[p] = (lo[p] as Vector3).min(verts[i])
			hi[p] = (hi[p] as Vector3).max(verts[i])
	var d := {"mesh": m, "arrays": arrays, "joints": m.get_meta("joints", {}), "parents": m.get_meta("parents", {}),
		"kind": String(m.get_meta("body", "quad")), "lo": lo, "hi": hi}
	_forms[f] = d
	return d


## Starts an attack (its blow lands HIT_AT of the way through: the hit signal).
func attack() -> void:
	_atk = 0.0


func attacking() -> bool:
	return _atk >= 0.0


## Its height in beast units (as it stands, before the node's scale).
func height() -> float:
	return _height


func _build(recipe: Dictionary, as_ghost: bool) -> void:
	for c in get_children():
		c.queue_free()
	mats.clear()
	_lids.clear()
	ghost = as_ghost
	var frame: String = recipe["frame"]
	form = frame
	var fi := info(frame)
	kind = fi["kind"]
	_hole = fi["lo"].has("deco")
	pivot = Node3D.new()
	add_child(pivot)
	skel = Skeleton3D.new()
	pivot.add_child(skel)
	# the frame's joints, and where a part it lacks would go (a socket on its body)
	var flo: Dictionary = fi["lo"]
	var fhi: Dictionary = fi["hi"]
	var blo: Vector3 = flo.get("body", Vector3.ZERO)
	var bhi: Vector3 = fhi.get("body", Vector3(0.2, 0.5, 0.2))
	_centre = Vector3((blo.x + bhi.x) / 2.0, blo.y if kind == "serpent" else (blo.y + bhi.y) / 2.0, 0.0)
	_joint = {}
	for p in PARTS:
		_joint[p] = fi["joints"].get(p, _socket(p, blo, bhi))
	# the pieces: the frame less what the other parent gives, and what it gives, moved onto the frame's sockets
	var given := {}
	for g in GROUPS:
		if recipe.has(g) and recipe[g] != frame:
			for p in GROUPS[g]:
				given[p] = recipe[g]
	var pieces := {frame: {}}
	for p in given:
		pieces[given[p]] = {}
	var parents: Dictionary = fi["parents"]
	var colours := Looks.look(String(recipe.get("colours", frame)))
	for donor in pieces:
		var di := info(donor)
		var keep := {}
		var moves := {}
		for p in PARTS:
			var mine: bool = given.get(p, frame) == donor
			if not mine:
				continue
			keep[p] = true
			if donor != frame:
				moves[p] = _move(p, fi, di, given)
		var mesh := _piece(di, keep, moves)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		# painted eyes: from the form whose face this piece carries
		var face_here: bool = keep.has("head") or not info(donor)["lo"].has("head")
		var eyes: Array = Looks.look(donor).get("eyes", []) if face_here else []
		paint(mat, colours, eyes)
		mat.set_shader_parameter("ghost", 1.0 if ghost else 0.0)
		mi.material_override = mat
		mats.append(mat)
		_lids.append(float(eyes[4]) if eyes.size() > 4 else 0.0)
		skel.add_child(mi)
	# one bone per part, at its joint, under its parent (the dirt round a worm in its hole stays where it is)
	for p in PARTS:
		skel.add_bone(p)
	for i in PARTS.size():
		var p: String = PARTS[i]
		var par := -1
		if p != "body" and p != "deco":
			par = maxi(PARTS.find(String(parents.get(p, "body"))), 0)
		skel.set_bone_parent(i, par)
		var at: Vector3 = _centre if p == "body" else _joint[p]
		var from: Vector3 = Vector3.ZERO if par < 0 else (_centre if par == 0 else _joint[PARTS[par]])
		skel.set_bone_rest(i, Transform3D(Basis(), at - from))
		_rest[i] = at - from
	skel.reset_bone_poses()
	var skin := skel.create_skin_from_rest_transforms()
	for mi in skel.get_children():
		(mi as MeshInstance3D).skin = skin
	# lying down: the body comes down to rest on the ground (a worm sinks into its hole)
	var hip := 0.0
	var legs := 0
	for p in GROUPS["legs"]:
		if flo.has(p):
			hip += (_joint[p] as Vector3).y
			legs += 1
	_drop = blo.y * 0.9
	if kind == "biped" and legs > 0:
		_drop = minf(blo.y, hip / legs) * 0.8
	if _hole:
		_drop = (bhi.y - blo.y) * 0.3
	var top := 0.0
	for p in fhi:
		top = maxf(top, (fhi[p] as Vector3).y)
	_height = top
	if ghost:
		_add_smoke(blo, bhi)
	_t = randf() * 10.0
	_pose()


## Where a part the frame lacks would join it, on its body's bounds.
func _socket(p: String, blo: Vector3, bhi: Vector3) -> Vector3:
	var c := (blo + bhi) / 2.0
	var hw := (bhi.z - blo.z) / 2.0
	var side := -1.0 if p.ends_with("_l") else 1.0
	match p:
		"head":
			return Vector3(lerpf(c.x, bhi.x, 0.6), bhi.y * 0.92, 0.0)
		"arm_l", "arm_r":
			return Vector3(lerpf(c.x, bhi.x, 0.25), lerpf(blo.y, bhi.y, 0.6), side * hw * 0.85)
		"wing_l", "wing_r":
			return Vector3(lerpf(c.x, blo.x, 0.2), lerpf(blo.y, bhi.y, 0.8), side * hw * 0.6)
		"tail":
			return Vector3(lerpf(c.x, blo.x, 0.9), lerpf(blo.y, bhi.y, 0.35), 0.0)
	return c


## How a part a merge takes from donor `di` is set onto the frame `fi`: [donor's joint, frame's socket, scale].
## Limbs and tails keep their size against the body halfway; legs are made as long as the frame's, so it stands;
## a head keeps its size against the frame's head halfway.
func _move(p: String, fi: Dictionary, di: Dictionary, given: Dictionary) -> Array:
	var dj: Dictionary = di["joints"]
	var g := ""
	for k in GROUPS:
		if p in GROUPS[k]:
			g = k
	var src: Vector3 = dj.get(p, Vector3.ZERO)
	var s := 1.0
	var fsz := _size(fi, "body")
	var dsz := _size(di, "body")
	if g == "head":
		fsz = _size(fi, "head")
		dsz = _size(di, "head")
	if g == "legs":
		s = clampf((_joint[p] as Vector3).y / maxf(src.y, 0.02), 0.5, 2.0)
	elif dsz > 0.001:
		s = clampf(sqrt(fsz / dsz), 0.6, 1.6)
	return [src, _joint[p], s]


static func _size(fi: Dictionary, p: String) -> float:
	if not fi["lo"].has(p):
		return 0.0
	var e: Vector3 = fi["hi"][p] - fi["lo"][p]
	return maxf(e.x, maxf(e.y, e.z))


## The donor's mesh cut down to the parts in `keep` (by the bone each vertex is fixed to, so horns and eyes go with
## the part they're on), those in `moves` set onto the frame ([from, to, scale]).
func _piece(di: Dictionary, keep: Dictionary, moves: Dictionary) -> ArrayMesh:
	var arrays: Array = di["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var n := verts.size()
	var all := true
	var take := PackedInt32Array()
	take.resize(n)
	var count := 0
	for i in n:
		var p: String = PARTS[bones[i * 4]]
		if keep.has(p):
			take[i] = count
			count += 1
		else:
			take[i] = -1
			all = false
	if count == 0:
		return null
	if all and moves.is_empty():
		return di["mesh"]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var nu2 := PackedVector2Array()
	var nb := PackedInt32Array()
	var nw := PackedFloat32Array()
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var src_u: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_u2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var src_w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i in n:
		if take[i] < 0:
			continue
		var p: String = PARTS[bones[i * 4]]
		var v := verts[i]
		if moves.has(p):
			var m: Array = moves[p]
			v = (m[1] as Vector3) + (v - (m[0] as Vector3)) * float(m[2])
		nv.append(v)
		nn.append(src_n[i])
		nc.append(src_c[i])
		nu.append(src_u[i])
		nu2.append(src_u2[i])
		for k in 4:
			nb.append(bones[i * 4 + k])
			nw.append(src_w[i * 4 + k])
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ni := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var a := take[idx[t]]
		var b := take[idx[t + 1]]
		var c := take[idx[t + 2]]
		if a >= 0 and b >= 0 and c >= 0:
			ni.append_array([a, b, c])
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nn
	out[Mesh.ARRAY_COLOR] = nc
	out[Mesh.ARRAY_TEX_UV] = nu
	out[Mesh.ARRAY_TEX_UV2] = nu2
	out[Mesh.ARRAY_BONES] = nb
	out[Mesh.ARRAY_WEIGHTS] = nw
	out[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## Sets the toon shader's colours from a look (beast_looks.gd), with painted eyes ([] for none).
static func paint(mat: ShaderMaterial, look: Dictionary, eyes: Array) -> void:
	var col: Dictionary = look.get("col", {})
	var tips: Dictionary = look.get("tip", {})
	var stripes: Dictionary = look.get("stripes", {})
	var bands: Dictionary = look.get("bands", {})
	var belly: Array = look.get("belly", [])
	var body := Color(String(col.get("body", "#c8c8c8")))
	var pc := PackedVector3Array()
	var tc := PackedVector3Array()
	var sc := PackedVector3Array()
	var tf := PackedFloat32Array()
	var tt := PackedFloat32Array()
	var ts := PackedFloat32Array()
	var sn := PackedFloat32Array()
	var bn := PackedFloat32Array()
	var bo := PackedFloat32Array()
	for p in PARTS:
		var g: String = Looks.GROUP[p]
		var c := Color(String(col[g])) if col.has(g) else body
		pc.append(_lin(c))
		var tip: Array = tips.get(g, [])
		tc.append(_lin(Color(String(tip[0]))) if not tip.is_empty() else _lin(c))
		tf.append(float(tip[1]) if not tip.is_empty() else 2.0)
		ts.append(float(tip[2]) if not tip.is_empty() else 0.0)
		tt.append(float(tip[3]) if tip.size() > 3 else 1.01)
		var st: Array = stripes.get(g, bands.get(g, []))
		sc.append(_lin(Color(String(st[0]))) if not st.is_empty() else _lin(c))
		sn.append(float(stripes[g][1]) if stripes.has(g) else 0.0)
		bn.append(float(bands[g][1]) if bands.has(g) else 0.0)
		bo.append(1.0 if belly.size() > 2 and g in belly[2] else 0.0)
	mat.set_shader_parameter("part_col", pc)
	mat.set_shader_parameter("tip_col", tc)
	mat.set_shader_parameter("tip_from", tf)
	mat.set_shader_parameter("tip_to", tt)
	mat.set_shader_parameter("tip_soft", ts)
	mat.set_shader_parameter("stripe_col", sc)
	mat.set_shader_parameter("stripes", sn)
	mat.set_shader_parameter("bands", bn)
	mat.set_shader_parameter("belly_on", bo)
	if belly.size() > 1:
		mat.set_shader_parameter("belly_col", _lin(Color(String(belly[0]))))
		mat.set_shader_parameter("belly_from", float(belly[1]))
	var head := Color(String(col["head"])) if col.has("head") else body
	var lid := Color(String(look["lid"])) if look.has("lid") else head.darkened(0.3)
	mat.set_shader_parameter("lid_col", _lin(lid))
	if eyes.size() >= 8:
		mat.set_shader_parameter("eye_pos", Vector4(eyes[0], eyes[1], eyes[2], eyes[3]))
		mat.set_shader_parameter("eye_style", Vector4(eyes[4], eyes[5], eyes[6], eyes[7]))
	else:
		mat.set_shader_parameter("eye_pos", Vector4(0, 0, 0, 9))
		mat.set_shader_parameter("eye_style", Vector4(0, 0, 0.5, 0))


static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


func _add_smoke(blo: Vector3, bhi: Vector3) -> void:
	smoke = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var puff := GradientTexture2D.new()
	puff.width = 64
	puff.height = 64
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	m.albedo_texture = puff
	q.material = m
	smoke.mesh = q
	smoke.amount = 26
	smoke.lifetime = 1.8
	smoke.preprocess = 1.8
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var top := Vector3(bhi.x, _height, bhi.z)
	smoke.position = Vector3((blo.x + top.x) / 2.0, _height * 0.4, 0.0)
	smoke.emission_box_extents = Vector3((top.x - blo.x) * 0.45, _height * 0.4, maxf(bhi.z - blo.z, 0.2) * 0.45)
	smoke.direction = Vector3.UP
	smoke.spread = 35.0
	smoke.gravity = Vector3(0, 0.12, 0)
	smoke.initial_velocity_min = 0.04
	smoke.initial_velocity_max = 0.14
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.3
	var sz := Curve.new()
	sz.add_point(Vector2(0, 0.35))
	sz.add_point(Vector2(1, 1.4))
	smoke.scale_amount_curve = sz
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.2, 0.75, 0.0))
	ramp.add_point(0.25, Color(0.3, 0.1, 0.5, 0.55))
	ramp.add_point(0.7, Color(0.08, 0.03, 0.14, 0.4))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.02, 0.0, 0.04, 0.0))
	smoke.color_ramp = ramp
	pivot.add_child(smoke)


func _process(delta: float) -> void:
	if skel == null:
		return
	_t += delta
	_walk = move_toward(_walk, 1.0 if state == "walk" else 0.0, delta * 5.0)
	_lie = move_toward(_lie, 1.0 if state == "lie" else 0.0, delta * 1.6)
	_bounce += delta * TAU * 1.5
	_step += delta * TAU * 1.8 * pace
	_flap += delta * TAU * (2.4 + 1.6 * _walk)
	if _atk >= 0.0:
		var was := _atk
		_atk += delta / ATTACK_TIME
		if was < HIT_AT and _atk >= HIT_AT:
			hit.emit()
		if _atk >= 1.0:
			_atk = -1.0
	_blink -= delta
	if _blink < -0.13:
		_blink = randf_range(2.2, 4.8)
	_pose()


static func _ease(x: float) -> float:
	return smoothstep(0.0, 1.0, x)


## The pose now: each bone turned (x: roll, y: yaw, z: pitch, about its joint) and moved from its rest.
func _pose() -> void:
	var lie := _ease(_lie)
	var awake := 1.0 - lie
	var walk := _walk * awake
	var rot := {}
	var off := {}
	for p in PARTS:
		rot[p] = Vector3.ZERO
		off[p] = Vector3.ZERO
	var flyer := kind == "flyer"
	# idle: squash at the bottom of the bounce, stretch on the way up
	var amp := (0.045 if not flyer else 0.015) * (1.0 - walk * 0.5) * (1.0 - lie * 0.6)
	var sy := 1.0 - amp * cos(_bounce)
	var lift := 0.0
	if flyer:
		lift = HOVER * awake + 0.03 * sin(_bounce) * awake
	rot["head"].z += 0.06 * sin(_bounce - 0.9) * awake
	rot["tail"].y += 0.25 * sin(_bounce * 0.5)
	for s in [-1.0, 1.0]:
		var arm := "arm_l" if s < 0 else "arm_r"
		rot[arm].x += s * -0.06 * sin(_bounce - 0.5) * awake
	# wings flap while it's up (faster as it flies), and fold when it lands
	var fl := sin(_flap)
	if flyer:
		rot["wing_l"].x += (0.55 * fl + 0.15) * awake - 0.35 * lie
		rot["wing_r"].x -= (0.55 * fl + 0.15) * awake - 0.35 * lie
		rot["body"].z -= 0.14 * walk
	else:
		rot["wing_l"].x += 0.12 * sin(_bounce) * awake
		rot["wing_r"].x -= 0.12 * sin(_bounce) * awake
	# walking
	var st := sin(_step)
	match kind:
		"quad":
			for p in ["leg_fl", "leg_br"]:
				rot[p].z += 0.45 * st * walk
			for p in ["leg_fr", "leg_bl"]:
				rot[p].z -= 0.45 * st * walk
			off["body"].y += 0.025 * absf(sin(_step)) * walk
			rot["head"].z += 0.05 * sin(_step * 2.0) * walk
		"biped":
			rot["leg_fl"].z += 0.5 * st * walk
			rot["leg_fr"].z -= 0.5 * st * walk
			rot["body"].x += 0.07 * st * walk
			off["body"].y += 0.02 * absf(st) * walk
		"serpent":
			rot["body"].y += 0.18 * st * walk
			rot["body"].x += 0.1 * sin(_step + 1.0) * walk
			rot["tail"].y -= 0.5 * sin(_step - 0.8) * walk
			rot["head"].y -= 0.15 * st * walk
		"blob":
			var hop := absf(sin(_step * 0.5))
			lift += 0.1 * hop * walk
			sy *= 1.0 - 0.08 * (1.0 - hop) * walk
		"flyer":
			rot["leg_fl"].z -= 0.5 * walk
			rot["leg_fr"].z -= 0.5 * walk
	rot["arm_l"].z -= 0.4 * st * walk
	rot["arm_r"].z += 0.4 * st * walk
	if kind == "quad":
		rot["arm_l"].z = rot["arm_l"].z * 0.5
		rot["arm_r"].z = rot["arm_r"].z * 0.5
	# lying down
	if lie > 0.0:
		off["body"].y -= _drop * lie
		rot["head"].z -= 0.3 * lie
		match kind:
			"quad":
				for p in ["leg_fl", "leg_fr"]:
					rot[p].z += 1.25 * lie
				for p in ["leg_bl", "leg_br"]:
					rot[p].z -= 1.25 * lie
				rot["tail"].y += 0.5 * lie
			"biped":
				for p in ["leg_fl", "leg_fr"]:
					rot[p].z += 1.35 * lie
				rot["body"].z += 0.1 * lie
				rot["arm_l"].z += 0.3 * lie
				rot["arm_r"].z += 0.3 * lie
			"flyer":
				rot["leg_fl"].z += 1.2 * lie
				rot["leg_fr"].z += 1.2 * lie
			"serpent":
				rot["tail"].y += 0.5 * lie
			"blob":
				sy *= 1.0 - 0.15 * lie
	# attacking: rear back, lunge, recover
	if _atk >= 0.0:
		var k := _atk
		var a := 0.0
		var s := 0.0
		if k < 0.3:
			a = _ease(k / 0.3)
		elif k < HIT_AT:
			var u := (k - 0.3) / (HIT_AT - 0.3)
			a = 1.0 - u
			s = _ease(u)
		else:
			s = 1.0 - _ease((k - HIT_AT) / (1.0 - HIT_AT))
		var lean := 0.2 if kind != "serpent" else 0.3
		off["body"].x += -0.05 * a + 0.2 * s
		off["body"].y += 0.03 * a
		rot["body"].z += 0.18 * a - lean * s
		rot["head"].z += 0.12 * a - 0.35 * s
		rot["arm_l"].z += -0.7 * a + 1.2 * s
		rot["arm_r"].z += -0.7 * a + 1.2 * s
		rot["arm_l"].y -= 0.4 * s
		rot["arm_r"].y += 0.4 * s
		rot["wing_l"].x += 0.9 * a - 0.6 * s
		rot["wing_r"].x -= 0.9 * a - 0.6 * s
		rot["tail"].z += 0.25 * a - 0.7 * s
		if kind == "blob":
			lift += 0.15 * sin(clampf(k / HIT_AT, 0.0, 1.0) * PI)
		if flyer:
			off["body"].y -= 0.1 * s
	pivot.position.y = lift
	var sx := 1.0 / sqrt(sy)
	pivot.scale = Vector3(sx, sy, sx)
	# feet stay where they stand, unless it's flying or lying down
	var plant := 0.0 if flyer else awake
	var body_q := Quaternion.from_euler(rot["body"])
	for i in PARTS.size():
		var p: String = PARTS[i]
		var q := Quaternion.from_euler(rot[p])
		var at: Vector3 = _rest[i] + off[p]
		if p.begins_with("leg_") and plant > 0.0:
			var planted: Vector3 = body_q.inverse() * (_rest[i] - off["body"])
			at = at.lerp(planted, plant)
			q = Quaternion.IDENTITY.slerp(body_q.inverse(), plant) * q
		skel.set_bone_pose_position(i, at)
		skel.set_bone_pose_rotation(i, q)
	# eyes half shut lying down, and a blink now and then
	for i in mats.size():
		var lid := lerpf(_lids[i], 0.85, lie)
		if _blink < 0.0:
			lid = 1.0
		var es: Vector4 = mats[i].get_shader_parameter("eye_style")
		if es.x != lid:
			es.x = lid
			mats[i].set_shader_parameter("eye_style", es)
