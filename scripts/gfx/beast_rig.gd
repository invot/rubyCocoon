extends Node3D
## A beast as it stands in the world: its model (assets/beasts/<form>.res, tools/import_new_beasts.gd) on a skeleton
## of one bone per part, painted by its look (scripts/data/beast_looks.gd) with the toon shader (beast_toon.gdshader),
## and moved by hand rather than by baked animations, so every form, and every merge of two, moves the same way:
##   - idle: a bouncy bob, squashing down and springing up, the head nodding after it and the tail and arms swaying
##     behind; flyers hover and flap
##   - walk: feet stepping (a trot on four, one then the other on two, knuckles too on arms that reach the ground)
##     with the arms swinging against them and the body bobbing and waddling; serpents wriggle, blobs hop, flyers fly
##   - lie: lying down to rest, the body on the ground and the legs folded out (on two: sitting, legs out in front),
##     the head low, breathing slowly with the eyes half shut; flyers land, folding their wings; a worm in its hole
##     sinks into it
##   - attack(): once, then back to what it was doing: rearing back, then lunging, its arms (claws, wings, talons)
##     striking, then settling back (a plain move)
##   - cast(colour): once: a long wind-up, standing tall and trembling as the element's glow (cast_glow.gd) gathers at
##     its horns, its hands (on two, or claws on four, that it doesn't stand on) or its mouth, then letting go, thrust
##     at the foe with a kick back from it, its feet planted (an elemental move; the released signal)
##   - guard: held while it's true (Defend): braced, low and squat, head tucked, arms (claws) raised across in front,
##     wings wrapped forward, a serpent coiled down, a blob squashed
##   - block(): a quick guard, shoved back a little (a defended or resisted hit)
##   - recoil(k, heavy): knocked back by a hit, k (0..1) as hard as the hit was, its head snapping back and its eyes
##     wincing shut; heavy (a critical or extra effective hit) harder still, rocking it off balance
##   - faint(): lying down, quicker, slumped over with its eyes shut (state "lie"; getting up again clears it)
## Its feet stay where they stand (each leg turned and stretched to reach its foot) while the body moves over them.
## A ghost or a merge takes all of these from its frame (its kind and its measured limbs).
## A ghost is the same beast in black and purple, wrapped in smoke.
## A merged beast (setup_merge(), or setup_recipe() from the recipe it keeps) is built from two parents' models
## (beast_parts.gd: one gives the frame, the other some of its parts), painted in one parent's colours.
## Beast space: facing +x, standing on y = 0, its larger measure 1 unit (scale the node for its size).

const Looks = preload("res://scripts/data/beast_looks.gd")
const Parts = preload("res://scripts/gfx/beast_parts.gd")
const CastGlow = preload("res://scripts/gfx/cast_glow.gd")
const SHADER = preload("res://scripts/gfx/beast_toon.gdshader")
const PARTS := Looks.PARTS
## how long an attack takes (s), and when in it the blow lands (0..1)
const ATTACK_TIME := 0.75
const HIT_AT := 0.42
## how long a cast takes (s), and when in it the glow is let go (0..1)
const CAST_TIME := 1.1
const RELEASE_AT := 0.6
## a quick guard (block), and a recoil from a light hit, a full one and a heavy one's extra (s)
const BLOCK_TIME := 0.45
const RECOIL_TIME := 0.45
const RECOIL_FULL := 0.2
const RECOIL_HEAVY := 0.15
## flyers hover this high while awake
const HOVER := 0.22

## the blow of attack() lands
signal hit
## cast() lets its glow go
signal released

var form := ""
## quad, biped, flyer, serpent or blob (the frame's)
var kind := "quad"
## idle, walk or lie (it eases from one to the next)
var state := "idle"
var ghost := false
## steps per second while walking, as a part of its usual pace
var pace := 1.0
## braced (Defend): it eases into the stance and holds it while this is true
var guard := false
## Only the courier's owl uses this pose; ordinary beasts keep their existing rig and animations.
var mounted := false
var _mount_seat := Vector3.ZERO

var pivot: Node3D
var skel: Skeleton3D
var mats: Array[ShaderMaterial] = []
var smoke: CPUParticles3D = null

## how far its eyelids are shut over its own (the shader's lid_shut), for blinking and sleeping
var _shut := -1.0
var _joint := {}
var _rest := {}
var _centre := Vector3.ZERO
## how far the body sinks lying down, and the frame's height
var _drop := 0.0
var _height := 1.0
var _hole := false
## what it stands on (legs, and arms that reach the ground): {part: [its foot at rest, its joint's height over it,
## its step's phase in the gait, which way its foot goes lying down, where its foot is from under its joint, its
## length]}
var _feet := {}
## per arm: [how far it turns (pitch) winding up, and striking], from the way it points; its lowest point's height,
## and how far that is below its joint
var _swing := {}
## per wing: its turn from the way it points to folded (back along the side, a little down), for landing
var _fold := {}
## it stands on its arms alone (no legs): letting go to strike, it sits down on its seat
var _on_hands := false
## how far it's let down to stand on the ground (a merge that would stand on parts it hasn't got)
var _ground := 0.0
var _t := 0.0
var _bounce := 0.0
## Held still (hold): a statue, an exhibit or an icon never moves, even once it's in the scene (Godot turns a node's
## processing back on as it becomes ready).
var _held := false
var _step := 0.0
var _flap := 0.0
var _atk := -1.0
var _walk := 0.0
var _lie := 0.0
var _blink := 2.0
## a cast, a block and a recoil under way (0..1, or -1), the recoil's strength and whether it's heavy, how far into
## its braced stance it is, and whether (and how far) it has fainted
var _cst := -1.0
var _blk := -1.0
var _rec := -1.0
var _rec_k := 0.5
var _rec_heavy := false
var _rec_time := RECOIL_TIME
var _grd := 0.0
var _out := false
var _ko := 0.0
## where it gathers its glow casting: [part, where in that part's own space] for each point, and from what ("horn",
## "hand" or "mouth"); the glows there, built on its first cast
var _glow_at: Array = []
var cast_from := "mouth"
var _glows: Array = []

## built beasts' pieces and joints, by recipe (cutting a merge's meshes is slow; every beast of a recipe shares them)
static var _built := {}
## Geometry measurements are identical for every instance of a recipe, including ghosts and portraits.
## Cache the small result, never the vertex arrays returned by the renderer.
static var _measurements := {}
static var _mount_meshes: Array[ArrayMesh] = []
const RECIPE_CACHE_LIMIT := 96

## A beast of this form (as "dino_3").
func setup(f: String, as_ghost := false) -> void:
	_build({"frame": f}, as_ghost)


## A merged beast of two forms, mixed by the seed: which gives the frame, which its colours, what the other gives.
func setup_merge(a: String, b: String, seed_n: int, as_ghost := false) -> void:
	_build(Parts.merge_recipe(a, b, seed_n), as_ghost)


## A merged beast from its recipe (as Parts.merge_recipe() gives it, and its genes keep it).
func setup_recipe(recipe: Dictionary, as_ghost := false) -> void:
	_build(recipe, as_ghost)


func mount() -> void:
	if mounted or form != "owl_3":
		return
	mounted = true
	var fi := Parts.info(form)
	var lo: Vector3 = fi["lo"]["body"]
	var hi: Vector3 = fi["hi"]["body"]
	var neck := Vector3(_centre.x, lerpf(lo.y, hi.y, 0.58), 0)
	_mount_seat = Vector3(lerpf(lo.x, hi.x, 0.25), lerpf(lo.y, hi.y, 0.78), 0)
	var head := PARTS.find("head")
	# This model's painted face is part of the body mesh; its original head bone owns only the ear tufts.
	# Rebind the upper face to a neck joint, blending through the neck so the mesh stays sealed.
	var old_head: Vector3 = _joint["head"]
	_joint["head"] = neck
	_rest[head] = neck - _centre
	skel.set_bone_rest(head, Transform3D(Basis(), _rest[head]))
	for i in PARTS.size():
		if skel.get_bone_parent(i) == head:
			_rest[i] += old_head - neck
			skel.set_bone_rest(i, Transform3D(Basis(), _rest[i]))
	var skin := skel.create_skin_from_rest_transforms()
	var index := 0
	for child in skel.get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if index >= _mount_meshes.size():
			var mesh := ArrayMesh.new()
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				for v in vertices.size():
					if bones[v * 4] != 0:
						continue
					var blend := smoothstep(neck.y - 0.06, neck.y + 0.07, vertices[v].y)
					bones[v * 4] = 0
					bones[v * 4 + 1] = head
					weights[v * 4] = 1.0 - blend
					weights[v * 4 + 1] = blend
					weights[v * 4 + 2] = 0.0
					weights[v * 4 + 3] = 0.0
				arrays[Mesh.ARRAY_BONES] = bones
				arrays[Mesh.ARRAY_WEIGHTS] = weights
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			_mount_meshes.append(mesh)
		mi.mesh = _mount_meshes[index]
		mi.skin = skin
		index += 1
	_pose()


## A point on the posed back, in world space. The rider follows the bob without inheriting the body's pitch.
func mount_seat() -> Vector3:
	var body := skel.get_bone_global_pose(0)
	return skel.to_global(body * (_mount_seat - _centre))


## Starts an attack (its blow lands HIT_AT of the way through: the hit signal).
func attack() -> void:
	_atk = 0.0


func attacking() -> bool:
	return _atk >= 0.0


## Starts a cast, its glow in this colour (let go RELEASE_AT of the way through: the released signal).
func cast(col: Color) -> void:
	if skel == null:
		return
	_cst = 0.0
	if _glows.is_empty():
		for g in _glow_at:
			var at := BoneAttachment3D.new()
			at.bone_name = String(g[0])
			skel.add_child(at)
			var gl: Node3D = CastGlow.new()
			gl.position = g[1]
			at.add_child(gl)
			_glows.append(gl)
	for gl in _glows:
		gl.begin(col)


func casting() -> bool:
	return _cst >= 0.0


## Where its glows are now, in world space (for a burst, or aiming from).
func glow_points() -> Array:
	var out := []
	for gl in _glows:
		if is_instance_valid(gl) and gl.is_inside_tree():
			out.append((gl as Node3D).global_position)
	return out


## A quick guard (a defended or resisted hit).
func block() -> void:
	_blk = 0.0


## Knocked back by a hit: k (0..1) as hard as it was; heavy for a critical or extra effective one.
func recoil(k: float, heavy := false) -> void:
	_rec = 0.0
	_rec_k = clampf(k, 0.0, 1.0)
	_rec_heavy = heavy
	_rec_time = RECOIL_TIME + RECOIL_FULL * _rec_k + (RECOIL_HEAVY if heavy else 0.0)


## Knocked out: lying down (quicker than to rest), slumped over, its eyes shut, until its state is set back.
func faint() -> void:
	state = "lie"
	_out = true
	guard = false


## Its height in beast units (as it stands, before the node's scale).
func height() -> float:
	return _height


## Takes up its state at once (a beast already down when a battle starts lies there from the first frame).
func settle() -> void:
	_walk = 1.0 if state == "walk" else 0.0
	_lie = 1.0 if state == "lie" else 0.0
	if state != "lie":
		_out = false
	_ko = 1.0 if _out else 0.0
	_grd = 1.0 if guard else 0.0
	_pose()


## Stands still in its state's resting pose, neither squashed nor stretched, eyes open, and stops animating (a
## statue, a museum exhibit, an icon).
func hold() -> void:
	_atk = -1.0
	_cst = -1.0
	_blk = -1.0
	_rec = -1.0
	guard = false
	for gl in _glows:
		gl.clear()
	_bounce = PI / 2.0
	_flap = 0.0
	_step = 0.0
	_blink = 2.0
	settle()
	_held = true
	set_process(false)


## Its bounds in its own space, its pieces as they stand now (a flyer hovering).
func bounds() -> AABB:
	var bb := AABB()
	var first := true
	for mi in find_children("*", "MeshInstance3D", true, false):
		# (its own pieces, not a cast's glow)
		if mi.get_parent() != skel:
			continue
		var xf: Transform3D = pivot.transform * skel.transform * (mi as MeshInstance3D).transform
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


func _build(recipe: Dictionary, as_ghost: bool) -> void:
	for c in get_children():
		c.queue_free()
	mats.clear()
	_glows.clear()
	_shut = -1.0
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
	var key := JSON.stringify(recipe)
	if not _built.has(key):
		if _built.size() >= RECIPE_CACHE_LIMIT:
			var oldest: String = _built.keys()[0]
			_built.erase(oldest)
			_measurements.erase(oldest)
		var j := Parts.joints(fi)
		# (pieces() moves the joints of the parts it sets onto the frame)
		var pcs := Parts.pieces(recipe, j)
		_built[key] = {"pieces": pcs, "joints": j}
	_joint = (_built[key]["joints"] as Dictionary).duplicate()
	var parents: Dictionary = fi["parents"]
	var colours := Looks.look(String(recipe.get("colours", frame)))
	var meshes := []
	for pc in _built[key]["pieces"]:
		var mi := MeshInstance3D.new()
		mi.mesh = pc["mesh"]
		meshes.append(pc["mesh"])
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		# painted eyes: from the form whose face this piece carries
		var eyes: Array = Looks.look(pc["face"]).get("eyes", []) if pc["face"] != "" else []
		Parts.paint(mat, colours, eyes)
		mat.set_shader_parameter("ghost", 1.0 if ghost else 0.0)
		mi.material_override = mat
		mats.append(mat)
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
		# (a mesh isn't bound to the skeleton it sits under until it's told so)
		(mi as MeshInstance3D).skeleton = NodePath("..")
		(mi as MeshInstance3D).skin = skin
	# (measured on what was built: a merge can stand taller than its frame)
	var top := 0.0
	for m in meshes:
		top = maxf(top, (m as Mesh).get_aabb().end.y)
	_height = top
	if _measurements.has(key):
		var measures: Dictionary = _measurements[key]
		_feet = measures["feet"].duplicate(true)
		_swing = measures["swing"].duplicate(true)
		_fold = measures["fold"].duplicate()
		_on_hands = measures["on_hands"]
		_drop = measures["drop"]
		_ground = measures["ground"]
		_height = measures["height"]
		_glow_at = measures["glow"].duplicate(true)
		cast_from = measures["cast_from"]
	else:
		_measure(meshes, fi, blo, bhi)
		_measurements[key] = {"feet": _feet.duplicate(true), "swing": _swing.duplicate(true),
			"fold": _fold.duplicate(), "on_hands": _on_hands, "drop": _drop, "ground": _ground, "height": _height,
			"glow": _glow_at.duplicate(true), "cast_from": cast_from}
	if ghost:
		_add_smoke(blo, bhi)
	_t = randf() * 10.0
	_pose()


## What it stands on and how it lies down, from its meshes as built (so a merge's parts are where they were set):
##   - each leg's foot (its lowest point), and each arm's that reaches the ground (it walks on its knuckles), for
##     _pose() to keep on the ground: its step in the gait (a trot on four; on two, one then the other, the arms
##     against the legs), and which way it goes lying down (front feet forward, back ones back, on two out in front;
##     splayed ones further out)
##   - each arm's swing to strike: from the way it points round to forward and a little down (arms it stands on: up
##     over its head, then down)
##   - how far the body sinks lying down: till its belly (on two, its seat) is on the ground, its legs folding out;
##     flyers settle on their feet, and a worm in its hole sinks into it as far as its head (on the dirt round it)
func _measure(meshes: Array, fi: Dictionary, blo: Vector3, bhi: Vector3) -> void:
	var flo: Dictionary = fi["lo"]
	_feet.clear()
	_swing.clear()
	_fold.clear()
	_on_hands = false
	var limbs: Array[String] = ["arm_l", "arm_r", "wing_l", "wing_r", "leg_fl", "leg_fr", "leg_bl", "leg_br"]
	var legs := []
	for p in Parts.GROUPS["legs"]:
		if flo.has(p):
			legs.append(p)
	# the belly: the lowest of the body between its legs (or, on two, anywhere under it), but for a stray few
	var x0 := -9.0
	var x1 := 9.0
	if kind == "quad" and not legs.is_empty():
		x0 = 9.0
		x1 = -9.0
		for p in legs:
			x0 = minf(x0, (_joint[p] as Vector3).x - 0.05)
			x1 = maxf(x1, (_joint[p] as Vector3).x + 0.05)
	var hw := maxf(-blo.z, bhi.z) * 0.6
	var under := PackedFloat32Array()
	var bottom := 9.0
	var lowest := {}
	var far := {}
	var arrays := []
	for m in meshes:
		var a: Array = (m as Mesh).surface_get_arrays(0)
		arrays.append(a)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var cs: PackedColorArray = a[Mesh.ARRAY_COLOR]
		for i in vs.size():
			var v := vs[i]
			var p: String = PARTS[bs[i * 4]]
			bottom = minf(bottom, v.y)
			if p in limbs:
				lowest[p] = minf(lowest.get(p, 9.0), v.y)
				far[p] = maxf(far.get(p, 0.0), v.distance_to(_joint[p]))
			elif p == "body" and roundi(cs[i].r * 15.0) == 0 and absf(v.z) < hw and v.x > x0 and v.x < x1:
				under.append(v.y)
	# each limb's foot (the middle of its lowest), tip (the middle of its far end) and middle
	var feet := {}
	var tips := {}
	var mids := {}
	var n := {}
	for a in arrays:
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		for i in vs.size():
			var p: String = PARTS[bs[i * 4]]
			if not lowest.has(p):
				continue
			var v := vs[i]
			var c: Vector3 = n.get(p, Vector3.ZERO) + Vector3(0, 0, 1)
			mids[p] = mids.get(p, Vector3.ZERO) + v
			if v.y < float(lowest[p]) + 0.03:
				feet[p] = feet.get(p, Vector3.ZERO) + Vector3(v.x, 0.0, v.z)
				c.x += 1
			if v.distance_to(_joint[p]) > float(far[p]) * 0.85:
				tips[p] = tips.get(p, Vector3.ZERO) + v
				c.y += 1
			n[p] = c
	# the way the arms point, on average (a quad's claws by their tips, other arms by their middles), and how far
	# they hang below their joints
	var hangs := 0.0
	var points := Vector2.ZERO
	for p in ["arm_l", "arm_r"]:
		if lowest.has(p):
			var j: Vector3 = _joint[p]
			var c: Vector3 = n[p]
			var to: Vector3 = tips[p] / maxf(c.y, 1.0) if kind == "quad" else mids[p] / maxf(c.z, 1.0)
			hangs = maxf(hangs, j.y - float(lowest[p]))
			points += Vector2(to.x - j.x, to.y - j.y).normalized()
	var walks := kind == "quad" or kind == "biped" or kind == "flyer"
	for p in limbs:
		if not lowest.has(p):
			continue
		if p.begins_with("wing"):
			continue
		var j: Vector3 = _joint[p]
		var c: Vector3 = n[p]
		var foot: Vector3 = feet[p] / maxf(c.x, 1.0) + Vector3(0.0, lowest[p], 0.0)
		var arm := p.begins_with("arm")
		# (an arm stands on the ground with a hand on it, not just a stray point or two)
		var stands := walks and (not arm or (kind == "biped" and float(lowest[p]) < 0.05 and c.x >= 6.0))
		if arm:
			_swing[p] = _strike(stands, hangs, points.angle(), kind == "quad")
			_swing[p] += [float(lowest[p]), maxf(j.y - foot.y, 0.02)]
		if not stands or skel.get_bone_parent(PARTS.find(p)) != 0:
			continue
		var ly := maxf(j.y - foot.y, 0.02)
		var out := Vector3(foot.x - j.x, 0.0, foot.z - j.z)
		# front feet go forward, back ones back (on two, out in front), and splayed ones further out
		var dir := Vector3.LEFT if p.begins_with("leg_b") else Vector3.RIGHT
		dir.z = signf(out.z) * clampf(absf(out.z) / ly - 0.3, 0.0, 1.5)
		dir = dir.normalized()
		var ph := 0.0
		match p:
			"leg_fr", "leg_bl":
				ph = PI
			"arm_l":
				ph = PI if not legs.is_empty() else 0.0
			"arm_r":
				ph = 0.0 if not legs.is_empty() else PI
		_feet[p] = [foot, ly, ph, dir, out, (foot - j).length()]
	_on_hands = legs.is_empty() and (_feet.has("arm_l") or _feet.has("arm_r"))
	# lying down: how far the body comes down (its legs folding out as it does, as far as they bend well); on two,
	# not past any of its seat
	under.sort()
	var clear: float = under[int(under.size() * (0.05 if kind == "quad" else 0.01))] if not under.is_empty() else blo.y
	var hip := 9.0
	for p in _feet:
		if p.begins_with("leg") or legs.is_empty():
			hip = minf(hip, float(_feet[p][1]))
	match kind:
		"quad", "biped":
			_drop = clampf(clear - 0.01, 0.0, (hip if hip < 9.0 else 0.0) * (0.72 if kind == "quad" else 0.65))
		"flyer":
			_drop = (hip if hip < 9.0 else 0.0) * 0.2
		"serpent":
			if _hole:
				_drop = (_height - blo.y) * 0.42
				if flo.has("head"):
					_drop = clampf(float(flo["head"].y) - float(fi["hi"]["deco"].y) - 0.03, 0.0, _drop)
		_:
			_drop = 0.0
	_ground = bottom if bottom > 0.01 and bottom < 9.0 else 0.0
	_height -= _ground
	# the wings folded back along its sides, down as far as keeps their tips off the ground
	for p in ["wing_l", "wing_r"]:
		if lowest.has(p):
			var j: Vector3 = _joint[p]
			var c: Vector3 = n[p]
			var to: Vector3 = tips[p] / maxf(c.y, 1.0) - j
			var side := -1.0 if p.ends_with("_l") else 1.0
			var down := clampf((j.y - _ground - _drop - 0.06) / maxf(to.length(), 0.01), 0.0, 0.6)
			_fold[p] = Quaternion(to.normalized(), Vector3(-sqrt(1.0 - down * down - 0.0225), -down, 0.15 * side))
	_measure_glow(arrays)


## Where it gathers its glow casting (cast()), from its meshes as built (a merge's parts where they were set): the tips
## of its horns, where they stand out (one glow, or one on each side for a pair); else its hands, on two (or claws, on
## four) that it doesn't stand on; else its mouth, the front of its head (of its body, without one).
func _measure_glow(arrays: Array) -> void:
	var verts := {"horn": [], "arm_l": [], "arm_r": [], "head": [], "body": []}
	for a in arrays:
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
		for i in vs.size():
			var p: String = PARTS[bs[i * 4]]
			if verts.has(p):
				verts[p].append(vs[i])
	_glow_at = []
	# horns: their tips (the far end from the joint), split left and right for a pair
	if (verts["horn"] as Array).size() >= 12:
		var j: Vector3 = _joint.get("horn", _centre)
		var far := 0.0
		for v in verts["horn"]:
			far = maxf(far, (v as Vector3).distance_to(j))
		if far > 0.07:
			var sides := {-1: [Vector3.ZERO, 0], 0: [Vector3.ZERO, 0], 1: [Vector3.ZERO, 0]}
			for v in verts["horn"]:
				if (v as Vector3).distance_to(j) > far * 0.82:
					var sd := 0 if absf(v.z) < 0.04 else int(signf(v.z))
					sides[sd][0] += v
					sides[sd][1] += 1
			for sd in sides:
				if int(sides[sd][1]) > 0:
					_glow_at.append(["horn", sides[sd][0] / float(sides[sd][1]) - j])
			if not _glow_at.is_empty():
				cast_from = "horn"
				return
	# hands: each arm's far end, on arms that hang free and reach out far enough to show
	if kind == "biped" or kind == "quad":
		for p in ["arm_l", "arm_r"]:
			if _feet.has(p) or (verts[p] as Array).size() < 12:
				continue
			var j: Vector3 = _joint.get(p, _centre)
			var far := 0.0
			for v in verts[p]:
				far = maxf(far, (v as Vector3).distance_to(j))
			if far < 0.12:
				continue
			var tip := Vector3.ZERO
			var n := 0
			for v in verts[p]:
				if (v as Vector3).distance_to(j) > far * 0.85:
					tip += v
					n += 1
			_glow_at.append([p, tip / float(maxi(n, 1)) - j])
		if not _glow_at.is_empty():
			cast_from = "hand"
			return
	# the mouth: the front of the head (the body's upper front, without one)
	var face := "head" if (verts["head"] as Array).size() >= 12 else "body"
	var j: Vector3 = _joint.get("head", _centre) if face == "head" else _centre
	var front := -9.0
	var mid := _ground + _height * 0.5
	for v in verts[face]:
		if face == "head" or v.y > mid:
			front = maxf(front, v.x)
	var at := Vector3.ZERO
	var n := 0
	for v in verts[face]:
		if v.x > front - 0.03 and (face == "head" or v.y > mid):
			at += v
			n += 1
	at = at / float(maxi(n, 1)) if n > 0 else j + Vector3(0.1, 0.0, 0.0)
	# (just in front of it, so the glow isn't buried in the face)
	_glow_at.append([face, at + Vector3(0.03, 0.0, 0.0) - j])
	cast_from = "mouth"


## An arm's turn (pitch) [winding up, striking], from the way the arms point (`at`, the angle up from forward) and how
## far they hang below their joints: one it stands on goes up over its head, then slams down in front; a quad's
## claws pointing up chop down, ones pointing forward rise and snap down; other arms hanging down swing forward (ones
## pointing forward, or up, as claws do).
static func _strike(stands: bool, hangs: float, at: float, quad: bool) -> Array:
	if stands:
		return [2.4, 0.6]
	if not quad and hangs > 0.09:
		return [-0.6, 1.2]
	if at > 0.9:
		return [0.6, -1.4]
	return [0.6, -0.45]


## The turn, and stretch along its length, that puts the foot of limb bone i (at `foot` at rest) at `to` (both in the
## skeleton's space), the body bone now `body` and the limb's joint at `at` on it: [Quaternion, stretch].
func _reach(i: int, body: Transform3D, at: Vector3, foot: Vector3, to: Vector3) -> Array:
	var v: Vector3 = foot - _joint[PARTS[i]]
	var t: Vector3 = body.basis.inverse() * (to - body * at)
	var s := 1.0
	if absf(v.y) > 0.02:
		s = clampf(sqrt(maxf(t.length_squared() - v.x * v.x - v.z * v.z, 0.0)) / absf(v.y), 0.6, 1.4)
	var u := Vector3(v.x, v.y * s, v.z)
	return [Quaternion(u.normalized(), t.normalized()), s]


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
	if _held:
		set_process(false)
		return
	if skel == null:
		return
	_t += delta
	_walk = move_toward(_walk, 1.0 if state == "walk" else 0.0, delta * 4.0)
	if state != "lie":
		_out = false
	# (knocked out: down quicker than lying down to rest)
	_lie = move_toward(_lie, 1.0 if state == "lie" else 0.0, delta * (3.2 if _out else 1.4))
	_ko = move_toward(_ko, 1.0 if _out else 0.0, delta * 3.0)
	_grd = move_toward(_grd, 1.0 if guard else 0.0, delta * 5.0)
	if _cst >= 0.0:
		var was_c := _cst
		_cst += delta / CAST_TIME
		if was_c < RELEASE_AT and _cst >= RELEASE_AT:
			for gl in _glows:
				gl.release()
			released.emit()
		elif _cst < RELEASE_AT:
			for gl in _glows:
				gl.gather(_cst / RELEASE_AT)
		if _cst >= 1.0:
			_cst = -1.0
	if _blk >= 0.0:
		_blk += delta / BLOCK_TIME
		if _blk >= 1.0:
			_blk = -1.0
	if _rec >= 0.0:
		_rec += delta / _rec_time
		if _rec >= 1.0:
			_rec = -1.0
	# (slow breaths lying down)
	_bounce += delta * TAU * lerpf(1.5, 0.55, _ease(_lie))
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


## The pose now: each bone turned (x: roll, y: yaw, z: pitch, about its joint) and moved from its rest, then each
## foot it stands on reached for (`reach`: where it goes from where it rests), and the whole squashed and stretched
## (`sy`: its height, `sx`: along its length) about the ground under it.
func _pose() -> void:
	var lie := _ease(_lie)
	var awake := 1.0 - lie
	var walk := _ease(_walk) * awake
	var still := 1.0 - walk
	var rot := {}
	var off := {}
	for p in PARTS:
		rot[p] = Vector3.ZERO
		off[p] = Vector3.ZERO
	var reach := {}
	for p in _feet:
		reach[p] = Vector3.ZERO
	var flyer := kind == "flyer"
	var sy := 1.0
	var sx := 1.0
	var lift := 0.0
	# the battle's poses now: braced (gw: held, or a quick block, shoved back by it), a cast gathering (cg) and let go
	# (cr), and knocked back by a hit (hr: as hard as it was, bouncing back a little after)
	var gw := _ease(_grd)
	var shove := 0.0
	if _blk >= 0.0:
		gw = maxf(gw, clampf(_blk / 0.12, 0.0, 1.0) * (1.0 - smoothstep(0.6, 1.0, _blk)))
		shove = sin(PI * clampf((_blk - 0.06) / 0.4, 0.0, 1.0))
	gw *= awake
	var cg := 0.0
	var cr := 0.0
	if _cst >= 0.0:
		if _cst < RELEASE_AT:
			cg = _ease(_cst / RELEASE_AT)
		else:
			var u := (_cst - RELEASE_AT) / (1.0 - RELEASE_AT)
			cg = 1.0 - smoothstep(0.0, 0.12, u)
			cr = clampf(u / 0.15, 0.0, 1.0) * (1.0 - _ease(clampf((u - 0.5) / 0.5, 0.0, 1.0)))
	var hr := 0.0
	if _rec >= 0.0:
		var u := _rec
		var h := u / 0.08 if u < 0.08 else exp(-(u - 0.08) * 3.5) * cos((u - 0.08) * 6.0)
		hr = h * (1.0 - smoothstep(0.8, 1.0, u)) * (0.35 + 0.65 * _rec_k) * (1.45 if _rec_heavy else 1.0)
	# (held still, braced or gathering: the idle's sway and the wings' beat calmed)
	var calm := 1.0 - 0.75 * maxf(gw, cg)
	# idle: squashing down and springing up (the body dipping on its legs), the head nodding after it, the tail and
	# arms swaying behind
	var bob := cos(_bounce)
	var amp: float = {"blob": 0.06, "serpent": 0.045, "flyer": 0.012}.get(kind, 0.04)
	sy -= amp * bob * (1.0 - 0.7 * walk) * (1.0 - 0.3 * lie) * calm
	if not flyer and not _feet.is_empty():
		off["body"].y -= 0.02 * (0.5 + 0.5 * bob) * still * awake * calm
	rot["head"].z -= 0.05 * cos(_bounce - 0.8) * still * calm
	rot["tail"].y += 0.22 * sin(_bounce * 0.5) * calm
	rot["tail"].z += 0.06 * cos(_bounce - 1.2) * still * calm
	rot["arm_l"].x += 0.07 * cos(_bounce - 0.6) * still * calm
	rot["arm_r"].x -= 0.07 * cos(_bounce - 0.6) * still * calm
	# wings flap while it's up (faster as it flies, the body rising on each beat), and fold when it lands
	var fl := sin(_flap) * calm
	if flyer:
		lift = (HOVER - 0.022 * fl) * awake
		rot["wing_l"].x += (0.6 * fl + 0.15) * awake
		rot["wing_r"].x -= (0.6 * fl + 0.15) * awake
		# flying on: leaning into it, the feet tucked back
		rot["body"].z -= 0.18 * walk
		for p in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
			rot[p].z += 0.12 * sin(_bounce - 1.0) * awake - 0.6 * walk
	else:
		rot["wing_l"].x += 0.12 * sin(_bounce) * awake
		rot["wing_r"].x -= 0.12 * sin(_bounce) * awake
	# walking
	var ph := _step
	if walk > 0.0:
		match kind:
			"quad", "biped":
				# each foot lifts and swings forward, then pushes back along the ground
				for p in _feet:
					var f: Array = _feet[p]
					var ly: float = f[1]
					var at := ph + float(f[2])
					var stride := clampf(ly * 0.32, 0.03, 0.08)
					var up := clampf(ly * 0.3, 0.025, 0.07)
					reach[p] += Vector3(stride * sin(at), up * maxf(cos(at), 0.0), 0.0) * walk
				# the body high over the feet it stands on, low (and squashed) as the others land
				var over := cos(2.0 * ph)
				off["body"].y += 0.014 * over * walk
				sy *= 1.0 - 0.03 * (0.5 - 0.5 * over) * walk
				rot["head"].z += 0.05 * cos(2.0 * ph - 0.7) * walk
				rot["tail"].y += 0.3 * sin(ph - 0.8) * walk
				if kind == "quad":
					rot["body"].x += 0.035 * sin(ph) * walk
					rot["head"].y += 0.05 * sin(ph) * walk
					rot["arm_l"].z += 0.15 * sin(ph) * walk
					rot["arm_r"].z -= 0.15 * sin(ph) * walk
				else:
					# a waddle: leaning over the foot it stands on, the hips turning with the step, the arms swinging
					# against the legs, the head kept level
					rot["body"].x += 0.07 * cos(ph) * walk
					rot["body"].y -= 0.08 * sin(ph) * walk
					rot["head"].x -= 0.05 * cos(ph) * walk
					rot["arm_l"].z -= 0.5 * sin(ph) * walk
					rot["arm_r"].z += 0.5 * sin(ph) * walk
			"serpent":
				# wriggling on, stretching and bunching up, the head looking ahead
				rot["body"].y += 0.2 * sin(ph) * walk
				rot["body"].x += 0.1 * sin(ph + 1.0) * walk
				rot["tail"].y -= 0.5 * sin(ph - 0.8) * walk
				rot["head"].y -= 0.22 * sin(ph) * walk
				sy *= 1.0 + 0.05 * sin(2.0 * ph) * walk
			"blob":
				# hopping: squashed as it lands and springs off, stretched in the air
				var hop := absf(sin(ph * 0.5))
				lift += 0.15 * hop * walk
				var landed := pow(maxf(1.0 - hop * 2.5, 0.0), 2.0)
				sy *= 1.0 + (0.08 * hop - 0.18 * landed) * walk
				rot["body"].z -= 0.06 * walk
				rot["arm_l"].x += 0.3 * (hop - 0.5) * walk
				rot["arm_r"].x -= 0.3 * (hop - 0.5) * walk
			"flyer":
				lift += 0.05 * walk
	# lying down: the body comes down, its feet sliding out as its legs fold (front ones forward, back ones back; on
	# two, sitting with them out in front)
	if lie > 0.0:
		var d := _drop * lie
		off["body"].y -= d
		match kind:
			"quad":
				rot["head"].z -= 0.3 * lie
				rot["tail"].y += 0.6 * lie
			"biped":
				# leaning back as it sits (one that can't, its seat already on the ground, slumping a little)
				var hip := 0.0
				for p in _feet:
					hip = maxf(hip, float(_feet[p][1]))
				rot["body"].z += (0.18 * clampf(_drop / maxf(hip * 0.4, 0.01), 0.0, 1.0) - 0.06) * lie
				rot["head"].z -= 0.2 * lie
			"flyer":
				rot["head"].z -= 0.12 * lie
			"serpent":
				if not _hole:
					# curled up low, the head down on it
					sy *= 1.0 - 0.22 * lie
					rot["head"].z -= 0.35 * lie
					rot["tail"].y += 0.6 * lie
			"blob":
				sy *= 1.0 - 0.16 * lie
				rot["arm_l"].x -= 0.2 * lie
				rot["arm_r"].x += 0.2 * lie
		# arms hanging low enough to touch the ground come forward over it (resting on the lap, on two)
		for p in _swing:
			var w: Array = _swing[p]
			if not _feet.has(p) and (kind == "quad" or kind == "biped"):
				var low := d - float(w[2]) + 0.02 + (0.05 if kind == "biped" else 0.0)
				rot[p].z += acos(clampf(1.0 - maxf(low, 0.0) / float(w[3]), -1.0, 1.0)) * lie
		if not flyer:
			for p in _feet:
				# (as far along its way as keeps the leg its length, the joint now lower)
				var f: Array = _feet[p]
				var ly: float = f[1]
				var len: float = f[5]
				var dir: Vector3 = f[3]
				var out: Vector3 = f[4]
				var along := out.dot(dir)
				var room := len * len - (ly - d) * (ly - d) - out.length_squared()
				reach[p] += dir * maxf(-along + sqrt(maxf(along * along + room, 0.0)), 0.0)
	# attacking: rearing back and crouching (a), lunging and striking (s, landing at HIT_AT), holding, then settling
	# back; stretched out along the lunge (snap)
	var a := 0.0
	var s := 0.0
	var snap := 0.0
	if _atk >= 0.0:
		var k := _atk
		if k < 0.3:
			a = _ease(k / 0.3)
		elif k < HIT_AT:
			var u := (k - 0.3) / (HIT_AT - 0.3)
			a = 1.0 - u
			s = 1.0 - (1.0 - u) * (1.0 - u)
		elif k < 0.55:
			s = 1.0
		else:
			s = 1.0 - _ease((k - 0.55) / 0.45)
		snap = sin(PI * clampf((k - 0.28) / 0.27, 0.0, 1.0))
		var lunge: float = {"serpent": 0.04 if _hole else 0.1, "flyer": 0.2, "blob": 0.18}.get(kind, 0.15)
		off["body"].x += -0.07 * a + lunge * s
		rot["head"].z += 0.25 * a - 0.35 * s
		rot["tail"].z += 0.25 * a - 0.7 * s
		for p in _swing:
			var w: Array = _swing[p]
			rot[p].z += float(w[0]) * a + float(w[1]) * s
		# claws open winding up and close striking
		rot["arm_l"].y += 0.35 * a - 0.3 * s
		rot["arm_r"].y -= 0.35 * a - 0.3 * s
		match kind:
			"flyer":
				# up and back, wings high, then swooping on it, wings and talons striking
				lift += 0.1 * a - 0.08 * s
				rot["body"].z += 0.3 * a - 0.4 * s
				rot["wing_l"].x += 0.9 * a - 0.7 * s
				rot["wing_r"].x -= 0.9 * a - 0.7 * s
				for p in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
					rot[p].z += -0.4 * a + 1.1 * s
			"serpent":
				# rearing up, coiled, then striking with the head (one along the ground keeping its coils on it)
				if _hole:
					rot["body"].z += 0.3 * a - 0.35 * s
				else:
					rot["body"].z += 0.06 * a - 0.08 * s
					rot["head"].z += 0.15 * a - 0.25 * s
				sy *= 1.0 + 0.07 * a
			"blob":
				# a deep crouch, then a leap on to it
				sy *= 1.0 - 0.22 * a
				lift += 0.16 * sin(PI * clampf((k - 0.3) / 0.4, 0.0, 1.0))
				rot["body"].z += 0.1 * a - 0.15 * s
			_:
				off["body"].y -= 0.03 * a
				rot["body"].z += 0.2 * a - 0.2 * s
				sy *= 1.0 - 0.07 * a
				# the front feet pounce forward with it
				for p in _feet:
					if p.begins_with("leg_f") and kind == "quad":
						reach[p] += Vector3(lunge * 0.6 * s, 0.05 * snap, 0.0)
		sx += 0.1 * snap
		sy *= 1.0 - 0.04 * snap
	# casting: standing tall and leaning back as it gathers, trembling as it builds, then letting go, thrust at the foe
	# with its feet planted (no lunge, unlike an attack), and settling
	if cg > 0.0 or cr > 0.0:
		var shiver := cg * cg * sin(_t * 70.0) * 0.008
		off["body"].x += -0.035 * cg + 0.05 * cr + shiver
		rot["tail"].z += 0.3 * cg - 0.25 * cr
		sy *= 1.0 + 0.05 * cg - 0.06 * cr
		sx += 0.06 * cr
		match cast_from:
			"horn":
				# lowering its horns at the foe as the glow builds on them, then tossing them up
				rot["head"].z += -0.32 * cg + 0.22 * cr
				rot["body"].z += -0.08 * cg + 0.06 * cr
				if not _feet.is_empty() and not flyer:
					off["body"].y -= 0.025 * cg
			"hand":
				# its hands raised high and apart, the glow in them, then flung forward at the foe
				rot["head"].z += 0.12 * cg - 0.08 * cr
				rot["body"].z += 0.06 * cg - 0.06 * cr
				for p in _swing:
					if _feet.has(p):
						continue
					var hanging: bool = float(_swing[p][0]) < 0.0
					rot[p].z += (2.0 if hanging else 0.8) * cg + (1.3 if hanging else -0.25) * cr
					rot[p].x += (0.4 if p == "arm_l" else -0.4) * cg
			_:
				# rearing up, its head back, drawing it in, then thrusting its head forward with it
				rot["head"].z += 0.38 * cg - 0.3 * cr
				rot["body"].z += 0.12 * cg - 0.1 * cr
		if cast_from != "hand":
			# arms held out a little, tense
			rot["arm_l"].x += 0.15 * cg
			rot["arm_r"].x -= 0.15 * cg
		match kind:
			"flyer":
				# wings spread high and held, then swept forward
				lift += 0.06 * cg - 0.03 * cr
				rot["wing_l"].x += 0.75 * cg - 0.4 * cr
				rot["wing_r"].x -= 0.75 * cg - 0.4 * cr
			"serpent":
				rot["body"].z += (0.2 if _hole else 0.06) * cg - (0.15 if _hole else 0.05) * cr
			"blob":
				# swelling as it fills, then squeezing it out
				sy *= 1.0 + 0.1 * cg - 0.16 * cr
	# braced (Defend; a block for a moment): low and squat, leaning into it with its head tucked, its arms (claws)
	# raised across in front, wings wrapped round to the front, a serpent coiled down (a worm into its hole), a blob
	# squashed; a block shoves it back
	if gw > 0.0 or shove > 0.0:
		if not _feet.is_empty() and not flyer:
			off["body"].y -= 0.03 * gw
		off["body"].x -= 0.03 * gw + 0.07 * shove
		rot["body"].z -= 0.08 * gw
		rot["head"].z -= 0.22 * gw + 0.08 * shove
		rot["tail"].z -= 0.15 * gw
		sy *= 1.0 - 0.07 * gw - 0.04 * shove
		for p in _swing:
			if _feet.has(p):
				continue
			var hanging: bool = float(_swing[p][0]) < 0.0
			rot[p].z += (1.2 if hanging else 0.55) * gw
			rot[p].x += (-0.3 if p == "arm_l" else 0.3) * gw
		match kind:
			"flyer":
				lift *= 1.0 - 0.35 * gw
				rot["wing_l"].y -= 0.9 * gw
				rot["wing_r"].y += 0.9 * gw
				rot["wing_l"].x -= 0.15 * gw
				rot["wing_r"].x += 0.15 * gw
			"serpent":
				sy *= 1.0 - 0.1 * gw
				rot["head"].z -= 0.12 * gw
				if _hole:
					off["body"].y -= _drop * 0.35 * gw
			"blob":
				sy *= 1.0 - 0.12 * gw
	# knocked back by a hit: the body rocked back, the head snapping back, arms and wings flung out; a heavy hit rocks
	# it off balance too
	if hr != 0.0:
		off["body"].x -= 0.09 * hr
		rot["body"].z += 0.2 * hr
		rot["head"].z += 0.4 * hr
		rot["tail"].z -= 0.2 * hr
		rot["arm_l"].x += 0.35 * hr
		rot["arm_r"].x -= 0.35 * hr
		rot["wing_l"].x += 0.5 * hr
		rot["wing_r"].x -= 0.5 * hr
		sy *= 1.0 - 0.1 * hr
		sx -= 0.05 * hr
		if _rec_heavy:
			rot["body"].x += 0.14 * hr
			rot["head"].x -= 0.12 * hr
		if flyer:
			lift -= 0.08 * hr
		elif kind == "blob":
			sy *= 1.0 - 0.08 * hr
	# knocked out: slumped over to one side, its head lolling down
	if _ko > 0.0 and lie > 0.0:
		var ko := _ease(_ko) * lie
		rot["body"].x += 0.2 * ko
		rot["head"].z -= 0.25 * ko
		rot["head"].x += 0.2 * ko
	if mounted:
		rot["body"].z = -PI / 4.0
		rot["head"].z = PI / 4.0
	pivot.position = Vector3(0.0, lift - _ground, 0.0)
	var wide := 1.0 / sqrt(sy)
	pivot.scale = Vector3(wide * sx, sy / sqrt(sx), wide)
	var inv := pivot.transform.affine_inverse()
	var body := Transform3D(Basis(Quaternion.from_euler(rot["body"])), _rest[0] + off["body"])
	# the feet stand where they are (flyers' once they've landed), but for arms letting go to strike
	var plant := lie if flyer else 1.0
	var grip := 1.0 - clampf(a + s, 0.0, 1.0)
	if _on_hands:
		body.origin.y -= _drop * (1.0 - grip) * awake
	for i in PARTS.size():
		var p: String = PARTS[i]
		var q := Quaternion.from_euler(rot[p])
		var at: Vector3 = _rest[i] + off[p]
		var sc := Vector3.ONE
		if _feet.has(p):
			var f: Array = _feet[p]
			var on := plant * (grip if p.begins_with("arm") else 1.0)
			if on > 0.0:
				var to: Vector3 = (f[0] as Vector3) + reach[p] - Vector3(0.0, _ground, 0.0)
				var r := _reach(i, body, at, f[0], inv * to)
				q = q.slerp(r[0], on)
				sc.y = lerpf(1.0, r[1], on)
		elif p == "deco":
			# the dirt round a worm in its hole stays where it is
			at = inv * at
			sc = Vector3.ONE / pivot.scale
		if _fold.has(p):
			q = Quaternion.IDENTITY.slerp(_fold[p], lie) * q
		if i == 0:
			q = body.basis.get_rotation_quaternion()
			at = body.origin
		skel.set_bone_pose_position(i, at)
		skel.set_bone_pose_rotation(i, q)
		skel.set_bone_pose_scale(i, sc)
	# eyes half shut lying down (shut, knocked out), and a blink now and then; wincing shut at a hit, narrowed braced
	# or gathering a cast
	var shut := 1.0 if _blink < 0.0 else lerpf(0.0, 0.85, lie)
	if (_ko > 0.5 and lie > 0.5) or hr > 0.35:
		shut = 1.0
	elif gw > 0.5 or cg > 0.5:
		shut = maxf(shut, 0.35)
	if shut != _shut:
		_shut = shut
		for m in mats:
			m.set_shader_parameter("lid_shut", shut)
