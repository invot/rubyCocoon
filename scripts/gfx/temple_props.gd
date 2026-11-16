extends RefCounted
## The pieces of a temple's puzzles and the roads to it: the levers that drain its floods (map_loader.gd "floods"),
## treasure chests, and an ornate stone bridge. Built from VBld.Kit boxes, in the soft stone and wood of the rest.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")

const STONE := Color("#b8b0a0")
const BRONZE := Color("#c89a48")
const WOOD := Color("#8a5a32")
const GOLD := Color("#e8c050")
const LEVER_RED := Color("#d03a30")


## A lever on a stone block: its bronze arm leans back (north) until pulled, then forward. The arm is the "Arm" node,
## pivoting on its hinge, for Story to swing (pull()). `back` sets it that far north of its tile's middle (against a wall).
static func lever(pulled: bool, block := STONE, rod := BRONZE, knob := Color("#3a8ab0"), back := 0.0) -> Node3D:
	var root := Node3D.new()
	var k := VBld.Kit.new()
	k.box("color", Vector3(0, 0.22, 0), Vector3(0.62, 0.44, 0.5), block)
	k.box("color", Vector3(0, 0.47, 0), Vector3(0.7, 0.06, 0.58), block.lightened(0.12))
	# the slot the arm swings in
	k.box("color", Vector3(0, 0.505, 0), Vector3(0.12, 0.02, 0.42), Color("#2a2622"))
	var base := MeshInstance3D.new()
	base.mesh = k.mesh()
	base.position.z = -back
	root.add_child(base)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 0.5, -back)
	var a := VBld.Kit.new()
	a.box("tin", Vector3(0, 0.36, 0), Vector3(0.08, 0.72, 0.08), rod)
	a.box("color", Vector3(0, 0.76, 0), Vector3(0.18, 0.16, 0.18), knob)
	var am := MeshInstance3D.new()
	am.mesh = a.mesh()
	arm.add_child(am)
	arm.rotation.x = arm_angle(pulled)
	root.add_child(arm)
	return root


## A water puzzle's lever: a brown block, a red arm.
static func red_lever(pulled: bool, back := 0.0) -> Node3D:
	return lever(pulled, WOOD, LEVER_RED, LEVER_RED.lightened(0.2), back)


## The arm's lean: back (north, -z) before it's pulled, forward after.
static func arm_angle(pulled: bool) -> float:
	return 0.6 if pulled else -0.6


## Swings a lever's arm forward.
static func pull(node: Node3D) -> void:
	var arm: Node3D = node.get_node_or_null("Arm")
	if arm == null:
		return
	var tw := node.create_tween()
	tw.tween_property(arm, "rotation:x", arm_angle(true), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## Swings a lever's arm to `pulled` or back (a water puzzle's levers go both ways).
static func throw_lever(node: Node3D, pulled: bool) -> void:
	var arm: Node3D = node.get_node_or_null("Arm")
	if arm == null:
		return
	var tw := node.create_tween()
	tw.tween_property(arm, "rotation:x", arm_angle(pulled), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## How far a chest's lid swings back when it's opened (radians about its hinge; negative lifts the front).
const LID_OPEN := -1.9


## A treasure chest from Kay Lousberg's KayKit Dungeon Pack (tools/import_kaykit.gd), front facing +z, its lid ("Lid",
## hinged along the back) shut or thrown open: the plain one, for temple treasures and the items lying about the world
## alike (no prop shows gold coins: the user's 2026-11-14 direction). Falls back to the older box-built chest if the
## meshes are missing.
static func chest(open: bool) -> Node3D:
	var kind := "chest"
	var base: Mesh = load("res://assets/props/kaykit_%s_base.res" % kind) if ResourceLoader.exists("res://assets/props/kaykit_%s_base.res" % kind) else null
	var top: Mesh = load("res://assets/props/kaykit_%s_lid.res" % kind) if ResourceLoader.exists("res://assets/props/kaykit_%s_lid.res" % kind) else null
	if base == null or top == null:
		return _box_chest(open)
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = base
	root.add_child(body)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = base.get_meta("hinge", Vector3(0, 0.219, -0.247))
	var lm := MeshInstance3D.new()
	lm.mesh = top
	lid.add_child(lm)
	lid.rotation.x = LID_OPEN if open else 0.0
	root.add_child(lid)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## The older chest, built from VBld.Kit boxes.
static func _box_chest(open: bool) -> Node3D:
	var root := Node3D.new()
	var k := VBld.Kit.new()
	k.box("planks", Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.48), WOOD)
	for x: float in [-0.24, 0.24]:
		k.box("tin", Vector3(x, 0.2, 0), Vector3(0.07, 0.42, 0.5), GOLD)
	k.box("tin", Vector3(0, 0.26, 0.245), Vector3(0.12, 0.14, 0.02), GOLD)
	var body := MeshInstance3D.new()
	body.mesh = k.mesh()
	root.add_child(body)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.4, -0.24)
	var l := VBld.Kit.new()
	l.box("planks", Vector3(0, 0.08, 0.24), Vector3(0.72, 0.16, 0.5), WOOD.lightened(0.08))
	for x: float in [-0.24, 0.24]:
		l.box("tin", Vector3(x, 0.08, 0.24), Vector3(0.07, 0.18, 0.52), GOLD)
	var lm := MeshInstance3D.new()
	lm.mesh = l.mesh()
	lid.add_child(lm)
	lid.rotation.x = LID_OPEN if open else 0.0
	root.add_child(lid)
	return root


## Throws a chest's lid open, with a golden light and shimmers welling out of it (chest_glow()).
static func open_chest(node: Node3D) -> void:
	var lid: Node3D = node.get_node_or_null("Lid")
	if lid == null:
		return
	var tw := node.create_tween()
	tw.tween_property(lid, "rotation:x", LID_OPEN, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(chest_glow.bind(node, lid.position.y)).set_delay(0.12)
	await tw.finished


const GLOW_GOLD := Color(1.0, 0.82, 0.38)
static var _sparkle_tex: Texture2D
static var _shaft_tex: Texture2D


## A golden glow that wells up out of an opened chest's mouth (`mouth` high): a soft warm light on the room, a
## glowing shaft rising from the chest, and shimmering sparkles drifting up out of it. All of it fades in about two
## seconds and frees itself; nothing casts shadows. Works on the Mobile and Compatibility renderers (CPU particles,
## one omni light, additive unshaded quads).
static func chest_glow(node: Node3D, mouth := 0.25) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var fx := Node3D.new()
	fx.name = "ChestGlow"
	fx.position = Vector3(0, mouth, 0)
	node.add_child(fx)
	# the warm light it throws on the room around it
	var light := OmniLight3D.new()
	light.light_color = GLOW_GOLD
	light.omni_range = 2.6
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.25, 0.1)
	fx.add_child(light)
	# the shaft of light rising out of the open chest, turning to face the camera about its upright axis
	var shaft := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 1.9)
	q.center_offset = Vector3(0, 0.95, 0)
	shaft.mesh = q
	var sm := _glow_material(_shaft(), BaseMaterial3D.BILLBOARD_FIXED_Y)
	sm.albedo_color = Color(GLOW_GOLD, 0.0)
	shaft.material_override = sm
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.scale = Vector3(0.6, 0.3, 1)
	shaft.position.z = 0.08
	fx.add_child(shaft)
	# the shimmers: little four-pointed sparkles drifting up, twinkling as they shrink away
	var p := CPUParticles3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2.ONE
	p.mesh = pq
	p.material_override = _glow_material(_sparkle(), BaseMaterial3D.BILLBOARD_PARTICLES)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 36
	p.lifetime = 1.7
	p.one_shot = true
	p.explosiveness = 0.55
	p.randomness = 0.5
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.22, 0.03, 0.12)
	p.direction = Vector3(0, 1, 0)
	p.spread = 32.0
	p.initial_velocity_min = 1.3
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -0.5, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.angle_min = 0.0
	p.angle_max = 45.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.13
	p.scale_amount_max = 0.27
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.2))
	sc.add_point(Vector2(0.15, 1.0))
	sc.add_point(Vector2(0.55, 0.6))
	sc.add_point(Vector2(0.7, 1.0))
	sc.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(GLOW_GOLD, 0.0))
	ramp.add_point(0.5, Color(1.0, 0.86, 0.45, 0.95))
	p.color_ramp = ramp
	fx.add_child(p)
	p.emitting = true
	# swell, hold a moment, then fade away
	var tw := fx.create_tween().set_parallel()
	tw.tween_property(light, "light_energy", 2.4, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(sm, "albedo_color:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(shaft, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.45)
	tw.chain().tween_property(light, "light_energy", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_property(sm, "albedo_color:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_property(shaft, "scale:y", 1.25, 1.2)
	tw.chain().tween_interval(0.3)
	tw.chain().tween_callback(fx.queue_free)


## An unshaded, additive glow material for the chest's light, sampling `tex` smoothly.
static func _glow_material(tex: Texture2D, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.vertex_color_use_as_albedo = billboard == BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A soft four-pointed sparkle (made once, then shared): a round glow with two thin crossing rays.
static func _sparkle() -> Texture2D:
	if _sparkle_tex != null:
		return _sparkle_tex
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			var core := clampf(1.0 - sqrt(dx * dx + dy * dy) * 1.5, 0.0, 1.0)
			var rays := maxf(clampf(1.0 - dx, 0.0, 1.0) * clampf(1.0 - dy * 5.0, 0.0, 1.0), clampf(1.0 - dy, 0.0, 1.0) * clampf(1.0 - dx * 5.0, 0.0, 1.0))
			var a := clampf(core * core * 1.3 + rays, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_sparkle_tex = ImageTexture.create_from_image(img)
	return _sparkle_tex


## The shaft's glow (made once, then shared): brightest at its foot in the middle, fading up and out to its sides.
static func _shaft() -> Texture2D:
	if _shaft_tex != null:
		return _shaft_tex
	var w := 64
	var h := 128
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	for y in h:
		var up := float(y) / (h - 1)  # 0 at the top, 1 at the foot
		for x in w:
			var side := 1.0 - absf(x - (w - 1) / 2.0) / ((w - 1) / 2.0)
			var a := pow(side, 1.3) * pow(up, 0.9)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_shaft_tex = ImageTexture.create_from_image(img)
	return _shaft_tex


## An ornate stone bridge `span_len` tiles long and `wide` across, running along x (its middle at the origin, its deck at
## y = 0): a paved deck on a low arch, and balustrades of little columns under a capped rail, ending in a newel post
## at each corner.
static func ornate_bridge(span_len: int, wide: int) -> ArrayMesh:
	var k := VBld.Kit.new()
	var hl := span_len / 2.0
	var hw := wide / 2.0
	var pale := Color("#e6dccb")
	var warm := Color("#d4c4a6")
	# the deck, a shade warmer down its middle
	k.box("color", Vector3(0, -0.06, 0), Vector3(span_len + 0.2, 0.14, wide + 0.1), pale)
	k.box("color", Vector3(0, 0.005, 0), Vector3(span_len + 0.2, 0.01, wide - 0.6), warm)
	# the arch under it: stepped courses, deepest at the ends
	for i in 4:
		var span := span_len - 0.6 * i
		k.box("color", Vector3(0, -0.22 - 0.12 * i, 0), Vector3(span, 0.14, wide - 0.1), pale.darkened(0.06 * (i + 1)), true)
	for e: int in [-1, 1]:
		k.box("color", Vector3(e * (hl - 0.15), -0.55, 0), Vector3(0.5, 0.9, wide + 0.1), pale.darkened(0.1), true)
	# balustrades: base, columns, capped rail
	for s: int in [-1, 1]:
		var z := s * (hw - 0.08)
		k.box("color", Vector3(0, 0.07, z), Vector3(span_len + 0.2, 0.14, 0.2), pale)
		var n := int(span_len * 3)
		for i in n + 1:
			var x := -hl + float(i) * span_len / n
			k.box("color", Vector3(x, 0.32, z), Vector3(0.09, 0.36, 0.09), pale.lightened(0.05))
		k.box("color", Vector3(0, 0.55, z), Vector3(span_len + 0.2, 0.1, 0.24), pale.lightened(0.08))
		for e: int in [-1, 1]:
			var c := Vector3(e * (hl + 0.05), 0, z)
			k.box("color", c + Vector3(0, 0.38, 0), Vector3(0.32, 0.76, 0.32), pale)
			k.box("color", c + Vector3(0, 0.8, 0), Vector3(0.38, 0.08, 0.38), pale.lightened(0.08))
			k.box("color", c + Vector3(0, 0.92, 0), Vector3(0.22, 0.16, 0.22), pale.lightened(0.04))
	return k.mesh()


## Rails along a plain plank bridge's sides: posts at each tile's corner and a rope-bound rail, `span_len` tiles long,
## running along x (the deck's middle at the origin, its top at y = 0), `wide` tiles across.
static func bridge_rails(span_len: int, wide: int) -> ArrayMesh:
	var k := VBld.Kit.new()
	var hl := span_len / 2.0
	var hw := wide / 2.0
	for s: int in [-1, 1]:
		var z := s * (hw - 0.06)
		for i in span_len + 1:
			k.box("planks", Vector3(-hl + i, 0.3, z), Vector3(0.1, 0.6, 0.1), WOOD.darkened(0.1))
		k.box("planks", Vector3(0, 0.55, z), Vector3(span_len + 0.1, 0.07, 0.07), WOOD)
		k.box("color", Vector3(0, 0.33, z), Vector3(span_len, 0.03, 0.03), Color("#c8b080"))
	return k.mesh()
