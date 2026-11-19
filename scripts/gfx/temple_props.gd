extends RefCounted
## The pieces of a temple's puzzles and the roads to it: the levers that drain its floods (map_loader.gd "floods"),
## treasure chests, and an ornate stone bridge. Supplied switches share the world's painted wood and stone.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")

const STONE := Color("#b8b0a0")
const BRONZE := Color("#c89a48")
const WOOD := Color("#8a5a32")
const GOLD := Color("#e8c050")
const LEVER_RED := Color("#d03a30")
## Warm mid-grey, so the switches read as carved stone under warm torchlight rather than white plastic.
const SWITCH_STONE := Color("#9c9488")
## Stout proportions for the supplied parts: the floor lever's shaft and grip twice as thick and a third shorter, its
## base a little taller. (The wall switch is built from boxes: _wall_plate, _wall_handle.)
const FLOOR_ARM_SCALE := Vector3(2.0, 0.68, 2.0)
const FLOOR_BASE_SCALE := Vector3(1.0, 1.25, 1.0)
## The floor lever's grip: a round red knob on the top of the wooden shaft.
const KNOB_RADIUS := 0.14
const KNOB_Y := 0.6
## A stone collar round the shaft's end, its top sunk into the knob, so shaft, collar and knob read as one piece
## (the thick wood stops at about 0.44; above it only the old grip's thin core runs on).
const COLLAR_Y := 0.46
## The wall switch's stone backing slab, and how far it stands the mount off the cubby's back.
const BACKING := Vector3(0.84, 1.3, 0.06)


## The supplied stout floor lever: a grey stone base and axle arches, with
## a wooden shaft like the picket fence, a stone collar and a round red knob.
## Keep the shared Arm node and angles for story animation and saved puzzle states.
static func lever(pulled: bool, back := 0.0) -> Node3D:
	var root := Node3D.new()
	_switch_part(root, "floor_base", Vector3(0, 0, -back)).scale = FLOOR_BASE_SCALE
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, (1.4 - 0.043) * 0.19 * FLOOR_BASE_SCALE.y, -back + 0.008 * 0.19)
	var shaft := MeshInstance3D.new()
	shaft.mesh = _floor_shaft()
	shaft.scale = FLOOR_ARM_SCALE
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(shaft)
	var collar := MeshInstance3D.new()
	collar.mesh = _collar()
	collar.position.y = COLLAR_Y
	collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(collar)
	var knob := MeshInstance3D.new()
	knob.mesh = _knob()
	knob.position.y = KNOB_Y
	knob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(knob)
	arm.rotation.x = arm_angle(pulled)
	root.add_child(arm)
	return root


## Water puzzles use the same wooden floor lever and red grip.
static func red_lever(pulled: bool, back := 0.0) -> Node3D:
	return lever(pulled, back)


## The reference's third (compact) wall switch, stone with a red handle.
## Its back starts at -back, so it mounts just ahead of the recess's rear lining.
static func wall_lever(pulled: bool, back := 0.0) -> Node3D:
	var root := Node3D.new()
	var slab := MeshInstance3D.new()
	slab.mesh = _wall_backing()
	slab.position = Vector3(0, 0.12, -back)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slab)
	var plate := MeshInstance3D.new()
	plate.mesh = _wall_plate()
	plate.position = Vector3(0, 0.28, -back + BACKING.z)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plate)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(-0.009 * 0.22, 0.28 + 2.226 * 0.235, -back + BACKING.z + 0.446 * 0.14)
	var handle := MeshInstance3D.new()
	handle.mesh = _wall_handle()
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm.add_child(handle)
	arm.rotation.x = arm_angle(pulled)
	root.add_child(arm)
	return root


static var _plate: ArrayMesh


## The wall switch's mount, in place of the supplied plate (whose simplified mesh folded over itself): a chunky stepped
## stone block on a wide foot, with a knuckle either side of the handle's axle. Its back is at z = 0, like the
## supplied one, and the handle's axle sits where it did.
static func _wall_plate() -> ArrayMesh:
	if _plate == null:
		var k := VBld.Kit.new()
		k.box("color", Vector3(0, 0.5, 0.07), Vector3(0.62, 0.96, 0.14), SWITCH_STONE)
		k.box("color", Vector3(0, 0.5, 0.165), Vector3(0.48, 0.82, 0.05), SWITCH_STONE.lightened(0.06))
		k.box("color", Vector3(0, 0.07, 0.13), Vector3(0.7, 0.14, 0.26), SWITCH_STONE.darkened(0.06))
		for x: float in [-0.3, 0.3]:
			k.box("color", Vector3(x, 0.523, 0.11), Vector3(0.1, 0.2, 0.22), SWITCH_STONE.darkened(0.04))
		_plate = _stoned(k.mesh())
	return _plate


static var _backing: ArrayMesh


## A plain stone slab the wall switch is mounted on, its back at z = 0 and its foot at y = 0.
static func _wall_backing() -> ArrayMesh:
	if _backing == null:
		var k := VBld.Kit.new()
		k.box("color", Vector3(0, BACKING.y / 2.0, BACKING.z / 2.0), BACKING, SWITCH_STONE)
		_backing = _stoned(k.mesh())
	return _backing


## A Kit mesh with every surface in the switches' grey cliff stone.
static func _stoned(m: ArrayMesh) -> ArrayMesh:
	for i in m.get_surface_count():
		m.surface_set_material(i, _switch_material("stone"))
	return m


static var _shaft_mesh: ArrayMesh
static var _knob_mesh: SphereMesh


## The supplied floor arm's wooden shaft alone (its red grip is replaced by _knob).
static func _floor_shaft() -> ArrayMesh:
	if _shaft_mesh == null:
		var src: ArrayMesh = load("res://assets/props/switch_floor_arm.res")
		_shaft_mesh = ArrayMesh.new()
		for i in src.get_surface_count():
			if src.surface_get_name(i) != "red":
				_shaft_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
				_shaft_mesh.surface_set_material(_shaft_mesh.get_surface_count() - 1, VT.wood_material())
	return _shaft_mesh


static var _collar_mesh: CylinderMesh


## The low-poly grey stone ring under the knob.
static func _collar() -> CylinderMesh:
	if _collar_mesh == null:
		_collar_mesh = CylinderMesh.new()
		_collar_mesh.top_radius = 0.135
		_collar_mesh.bottom_radius = 0.155
		_collar_mesh.height = 0.1
		_collar_mesh.radial_segments = 10
		_collar_mesh.rings = 1
		_collar_mesh.material = _switch_material("stone")
	return _collar_mesh


## A low-poly round red knob.
static func _knob() -> SphereMesh:
	if _knob_mesh == null:
		_knob_mesh = SphereMesh.new()
		_knob_mesh.radius = KNOB_RADIUS
		_knob_mesh.height = KNOB_RADIUS * 2.0
		_knob_mesh.radial_segments = 12
		_knob_mesh.rings = 6
		_knob_mesh.material = _switch_material("red")
	return _knob_mesh


static var _handle: ArrayMesh


## The wall switch's handle, about its axle: two stout red arms out of the knuckles and a thick solid grip across
## their ends (the supplied one was an open tray from above).
static func _wall_handle() -> ArrayMesh:
	if _handle == null:
		var k := VBld.Kit.new()
		for x: float in [-0.21, 0.21]:
			k.box("color", Vector3(x, 0, 0.14), Vector3(0.1, 0.12, 0.28), LEVER_RED.darkened(0.08))
		k.box("color", Vector3(0, 0, 0.33), Vector3(0.54, 0.18, 0.15), LEVER_RED)
		_handle = k.mesh()
	return _handle


const BUTTONS := ["mushroom", "small", "round"]
const BUTTON_TRAVEL := 0.075

## A stone button and red cap. Weapon fixtures face it outward at the existing
## projectile height; its Button child depresses instead of tipping the whole post.
static func button(pressed: bool, variant := 0) -> Node3D:
	var root := Node3D.new()
	var kind: String = BUTTONS[posmod(variant, BUTTONS.size())]
	_switch_part(root, "button_%s_base" % kind)
	var cap := Node3D.new()
	cap.name = "Button"
	_switch_part(cap, "button_%s_cap" % kind)
	cap.position.y = -BUTTON_TRAVEL if pressed else 0.0
	root.add_child(cap)
	return root


## The weapon target's short stone post reuses a bevelled supplied housing, so
## its corners stay soft without adding another mesh or a bare box support.
static func button_target(pressed: bool, variant := 0) -> Node3D:
	var root := Node3D.new()
	var post := _switch_part(root, "button_mushroom_base", Vector3(0, 0, -0.1))
	post.scale = Vector3(0.72, 2.65, 0.72)
	var face := button(pressed, variant)
	face.name = "Switch"
	face.position = Vector3(0, 1.15, 0.02)
	face.rotation.x = PI / 2.0
	root.add_child(face)
	return root


static var _switch_meshes := {}
static var _switch_materials := {}


static func _switch_part(parent: Node3D, kind: String, at := Vector3.ZERO) -> MeshInstance3D:
	if not _switch_meshes.has(kind):
		var mesh: ArrayMesh = load("res://assets/props/switch_%s.res" % kind)
		for si in mesh.get_surface_count():
			var finish := mesh.surface_get_name(si)
			mesh.surface_set_material(si, VT.wood_material() if finish in ["wood", "wood_tip"] else _switch_material(finish))
		_switch_meshes[kind] = mesh
	var part := MeshInstance3D.new()
	part.mesh = _switch_meshes[kind]
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


static var _grey_rock_tex: ImageTexture


## The cliff faces' rock texture (terrain_mesh.gd "cliff_rock"), desaturated to grey and brightened back to a mid tone,
## for the switches' carved stone.
static func grey_cliff_texture() -> ImageTexture:
	if _grey_rock_tex == null:
		var img: Image = VT.texture("cliff_rock").get_image().duplicate()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		img.adjust_bcs(1.35, 1.0, 0.0)
		img.generate_mipmaps()
		_grey_rock_tex = ImageTexture.create_from_image(img)
	return _grey_rock_tex


static func _switch_material(kind: String) -> StandardMaterial3D:
	if not _switch_materials.has(kind):
		var mat := StandardMaterial3D.new()
		# A smooth painted finish on the carved stone and red controls, rather than
		# the source pack's scratched industrial atlas and English PULL lettering.
		# (stone: the cliffs' painted rock, in grey)
		mat.albedo_texture = VT.texture("soft") if kind == "red" else grey_cliff_texture()
		mat.albedo_color = LEVER_RED if kind == "red" else SWITCH_STONE
		mat.roughness = 0.88 if kind == "red" else 0.98
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * (2.0 if kind == "red" else 1.4)
		_switch_materials[kind] = mat
	return _switch_materials[kind]


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
