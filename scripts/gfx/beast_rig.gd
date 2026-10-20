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
## A merged beast (setup_merge()) is built from two parents' models (beast_parts.gd: one gives the frame, the other
## some of its parts), painted in one parent's colours.
## Beast space: facing +x, standing on y = 0, its larger measure 1 unit (scale the node for its size).

const Looks = preload("res://scripts/data/beast_looks.gd")
const Parts = preload("res://scripts/gfx/beast_parts.gd")
const SHADER = preload("res://scripts/gfx/beast_toon.gdshader")
const PARTS := Looks.PARTS
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

## A beast of this form (as "dino_3").
func setup(f: String, as_ghost := false) -> void:
	_build({"frame": f}, as_ghost)


## A merged beast of two forms, mixed by the seed: which gives the frame, which its colours, what the other gives.
func setup_merge(a: String, b: String, seed_n: int, as_ghost := false) -> void:
	_build(Parts.merge_recipe(a, b, seed_n), as_ghost)


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
	var fi := Parts.info(frame)
	kind = fi["kind"]
	_hole = fi["lo"].has("deco")
	pivot = Node3D.new()
	add_child(pivot)
	skel = Skeleton3D.new()
	pivot.add_child(skel)
	var flo: Dictionary = fi["lo"]
	var fhi: Dictionary = fi["hi"]
	var blo: Vector3 = flo.get("body", Vector3.ZERO)
	var bhi: Vector3 = fhi.get("body", Vector3(0.2, 0.5, 0.2))
	_centre = Vector3((blo.x + bhi.x) / 2.0, blo.y if kind == "serpent" else (blo.y + bhi.y) / 2.0, 0.0)
	_joint = Parts.joints(fi)
	var parents: Dictionary = fi["parents"]
	var colours := Looks.look(String(recipe.get("colours", frame)))
	for pc in Parts.pieces(recipe, _joint):
		var mi := MeshInstance3D.new()
		mi.mesh = pc["mesh"]
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		# painted eyes: from the form whose face this piece carries
		var eyes: Array = Looks.look(pc["face"]).get("eyes", []) if pc["face"] != "" else []
		Parts.paint(mat, colours, eyes)
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
	for p in Parts.GROUPS["legs"]:
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
