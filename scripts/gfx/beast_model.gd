extends RefCounted
## Which model a beast is drawn with, by its genes, for everywhere the game shows one (battle, the overworld, the
## portraits, the Sky Tower's bird):
##   - a line's forms (a "form" with a model in assets/beasts/) and merges of them (genes with a "recipe") are the new
##     beasts, animated (beast_rig.gd): rig() builds one, sized by its "size" gene
##   - the legendaries (a PSX "form") and the robots (a "model") keep their old models (voxel_beast.gd, voxel_assets.gd),
##     which each caller builds as before
## A ghost (shade over 0.5: a half-ghost merge has 0.62) is drawn in black and purple, wrapped in smoke.
## The battle's poses go through here for whatever a beast is drawn with (pose_cast, pose_guard, pose_block,
## pose_hit): a rig moves its own parts (beast_rig.gd); the old models lean, crouch and rock whole, a glow
## (cast_glow.gd) gathering at their front as they cast.

const Rig = preload("res://scripts/gfx/beast_rig.gd")
const CastGlow = preload("res://scripts/gfx/cast_glow.gd")
const DIR := "res://assets/beasts/"

## per form: whether it has a new model
static var _has := {}


## Whether these genes are drawn with a rig.
static func rigged(genes: Dictionary) -> bool:
	if genes.has("recipe"):
		return true
	var f := String(genes.get("form", ""))
	if not _has.has(f):
		_has[f] = f != "" and ResourceLoader.exists(DIR + f + ".res")
	return _has[f]


static func ghostly(genes: Dictionary) -> bool:
	return float(genes.get("shade", 0.0)) > 0.5


## The beast's rig, scaled by its size times k, or null for genes drawn the old way.
static func rig(genes: Dictionary, k := 1.0) -> Node3D:
	if not rigged(genes):
		return null
	var r: Rig = Rig.new()
	if genes.has("recipe"):
		r.setup_recipe(genes["recipe"], ghostly(genes))
	else:
		r.setup(String(genes["form"]), ghostly(genes))
	var s := float(genes.get("size", 1.0)) * k
	r.scale = Vector3(s, s, s)
	return r


## How tall a rig stands as scaled (a flyer hovering), in its parent's units.
static func height(r: Rig) -> float:
	return (r.height() + (Rig.HOVER if r.kind == "flyer" else 0.0)) * r.scale.y


## A rig's bounds in its own space, its pieces as they stand at rest (a flyer hovering).
static func bounds(r: Rig) -> AABB:
	return r.bounds()


## A rig cast as a statue: every piece in one material, holding still in its first pose.
static func cast(r: Rig, mat: Material) -> void:
	r.hold()
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	if r.smoke != null:
		r.smoke.queue_free()
		r.smoke = null


# ================================================================ battle poses
## Starts a cast, its glow in this colour (an elemental move); returns how long until it's let go (s).
static func pose_cast(model: Node3D, col: Color) -> float:
	var wind := Rig.CAST_TIME * Rig.RELEASE_AT
	if model is Rig:
		(model as Rig).cast(col)
		return wind
	if model == null:
		return wind
	# an old model: leaning back as the glow gathers at its front, then pitching forward as it lets it go
	var gl: Node3D = _old_glow(model)
	gl.begin(col)
	var tw := _old_tween(model)
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(gl):
			gl.gather(k), 0.0, 1.0, wind)
	tw.parallel().tween_method(func(k: float) -> void: _old_set(model, 0.2 * k, -0.03 * k, 1.0 + 0.05 * k), 0.0, 1.0, wind) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(gl):
			gl.release())
	tw.tween_method(func(k: float) -> void: _old_set(model, lerpf(0.2, -0.15, k), lerpf(-0.03, 0.07, k), lerpf(1.05, 0.95, k)),
		0.0, 1.0, 0.07)
	tw.tween_interval(0.15)
	_old_back(model, tw, 0.3)
	return wind


## Held braced while `on` (Defend).
static func pose_guard(model: Node3D, on: bool) -> void:
	if model is Rig:
		(model as Rig).guard = on
		return
	if model == null:
		return
	model.set_meta("pose_guard", on)
	_old_back(model, _old_tween(model), 0.2)


## A quick guard (a defended or resisted hit).
static func pose_block(model: Node3D) -> void:
	if model is Rig:
		(model as Rig).block()
		return
	if model == null:
		return
	var tw := _old_tween(model)
	tw.tween_method(func(k: float) -> void: _old_set(model, -0.1 * k, -0.07 * k, 1.0 - 0.08 * k), 0.0, 1.0, 0.06)
	_old_back(model, tw, 0.3)


## Knocked back by a hit, k (0..1) as hard as it was; heavy for a critical or extra effective one.
static func pose_hit(model: Node3D, k: float, heavy := false) -> void:
	if model is Rig:
		(model as Rig).recoil(k, heavy)
		return
	if model == null:
		return
	var a := (0.35 + 0.65 * clampf(k, 0.0, 1.0)) * (1.45 if heavy else 1.0)
	var tw := _old_tween(model)
	tw.tween_method(func(u: float) -> void: _old_set(model, 0.25 * a * u, -0.12 * a * u, 1.0 - 0.08 * a * u), 0.0, 1.0, 0.05)
	_old_back(model, tw, Rig.RECOIL_TIME + Rig.RECOIL_FULL * k, Tween.TRANS_BACK)


## Where a model's cast glows are now (world space): a burst as it lets go, the start of its streak at the foe.
static func glow_points(model: Node3D) -> Array:
	if model is Rig:
		return (model as Rig).glow_points()
	if model != null and model.has_meta("pose_glow"):
		var gl = model.get_meta("pose_glow")
		if is_instance_valid(gl) and gl.is_inside_tree():
			return [(gl as Node3D).global_position]
	return []


## (an old model's pose: its pitch (nose up), how far it's moved forward and its height, from where it rests, braced
## if it's guarding)
static func _old_set(model: Node3D, pitch: float, fwd: float, tall: float) -> void:
	if not is_instance_valid(model):
		return
	var rest: Transform3D = model.get_meta("pose_rest")
	var g := 1.0 if model.get_meta("pose_guard", false) else 0.0
	var xf := rest
	xf.basis = rest.basis * Basis(Vector3(0, 0, 1), pitch - 0.08 * g) * Basis.from_scale(Vector3(1.0, tall * (1.0 - 0.08 * g), 1.0))
	xf.origin = rest.origin + rest.basis * Vector3(fwd - 0.04 * g, 0.0, 0.0)
	model.transform = xf


## (a new tween for an old model's pose, in place of the one it had)
static func _old_tween(model: Node3D) -> Tween:
	if not model.has_meta("pose_rest"):
		model.set_meta("pose_rest", model.transform)
	var old = model.get_meta("pose_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := model.create_tween()
	model.set_meta("pose_tween", tw)
	return tw


## (easing an old model back from where it is to rest, or braced)
static func _old_back(model: Node3D, tw: Tween, time: float, trans := Tween.TRANS_SINE) -> void:
	# (from where it is when this step starts, not when the tween was made)
	var from := []
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(model):
			return
		if from.is_empty():
			from.append(model.transform)
		_old_set(model, 0.0, 0.0, 1.0)
		model.transform = (from[0] as Transform3D).interpolate_with(model.transform, u), 0.0, 1.0, time) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)


## (an old model's glow, at the front of it two-thirds of the way up, built the first time)
static func _old_glow(model: Node3D) -> Node3D:
	var gl = model.get_meta("pose_glow", null)
	if gl != null and is_instance_valid(gl):
		return gl
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false) + ([model] if model is MeshInstance3D else []):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var xf: Transform3D = model.global_transform.affine_inverse() * (mi as Node3D).global_transform if model.is_inside_tree() else Transform3D()
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	gl = CastGlow.new()
	gl.position = Vector3(box.end.x - box.size.x * 0.08, box.position.y + box.size.y * 0.7, box.get_center().z)
	gl.scale = Vector3.ONE * clampf(box.size.y, 0.6, 2.5)
	model.add_child(gl)
	model.set_meta("pose_glow", gl)
	return gl
