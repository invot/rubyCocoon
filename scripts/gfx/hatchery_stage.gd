extends Node3D
## The hatching vault: a baked stone cocoon (tools/hatchery_chamber.gd) around the egg platform, with the articulated
## TCM Core descending from the dark. All geometry is baked and smoothed ahead of time. The three real tongs close
## against each species' shell, not a fixed ring, and stay plain metal; the only light from the mechanism is a warm
## shaft shining down from inside it. The hatch and merge films move all this into the roundel chamber (use_roundels).
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const EggModel = preload("res://scripts/gfx/egg_model.gd")
const DIR := "res://assets/interiors/hatch_"
const CORE_SCALE := 1.5
const DECK_Y := 1.07
## Height above its base at which the tongs grip a shell.
const GRIP := 0.60
const CORE_START_Y := 9.0
## How far the core rises after the hatch: clear of the frame, leaving the beast alone on the platform.
const CORE_LIFT := 5.5
## Render layer holding the tongs. The core's own lights leave it out, so the tongs never brighten or change colour.
const TONG_LAYER := 2
const INNER_LIGHT := Color("#ffefd2")
const LANTERN_GLOW := Color("#ffc58a")
## Lantern positions as (x, z): a horseshoe around the plinth, open towards the camera.
const LANTERNS: Array[Vector2] = [Vector2(4.44, 1.19), Vector2(-4.44, 1.19), Vector2(3.98, -2.30), Vector2(-3.98, -2.30),
	Vector2(1.19, -4.44), Vector2(-1.19, -4.44)]
const LANTERN_TOP := 1.64
const ROUNDEL_GLOOM := Color("#04080b")
const ROUNDEL_MIST := Color("#3f6670")
const ROUNDEL_FLOOR_PAINT := Color("#c8cbd2")
const ROUNDEL_FOG := 0.03
const HOUSE_LIGHTS_DIM := 0.09
const HOUSE_LIGHTS_FULL := 0.24
static var _meshes := {}
static var _tong_data: Array = []
static var _halo_texture: GradientTexture2D

var core: Node3D
var joints: Array[Node3D] = []
var closed_angles: Array[float] = []
var contact_points: Array[Vector3] = []
var contact_height := 3.9
var beam: MeshInstance3D
var beam_material: ShaderMaterial
var emitter_material: StandardMaterial3D
var spotlight: SpotLight3D
var environment: Environment
var _emitter_halo: StandardMaterial3D
var _lantern_halo: StandardMaterial3D
var _lantern_glow: StandardMaterial3D
var _dust: ShaderMaterial
var _lantern_halos: Array[Node3D] = []


## `steel` paints the core in the roundel chamber's white and steel.
func build(steel := false) -> void:
	_environment()
	var room := _mesh(self, "room")
	for si in room.mesh.get_surface_count():
		var mat = room.mesh.surface_get_material(si)
		if mat is StandardMaterial3D and mat.emission_enabled:
			_lantern_glow = mat.duplicate() as StandardMaterial3D
			room.set_surface_override_material(si, _lantern_glow)
	# Turned so that none of the rim's four spurs stands dead centre in front of the egg.
	_mesh(self, "platform").rotation.y = PI * 0.25
	_build_air()
	_lantern_halo = _halo_material(LANTERN_GLOW)
	for at in LANTERNS:
		_lantern_halos.append(_halo(self, Vector3(at.x, LANTERN_TOP, at.y), 2.3, _lantern_halo))
	_build_core(steel)


## Moves the scene into the roundel-walled chamber, a dark, misty room behind the Beast Center, lit by its aqua glass.
## The vault's stone floor and plinth stay, so every platform keeps its steps, and the floor is carried on to the walls.
## The vault's walls and lanterns go.
func use_roundels() -> void:
	get_node("Room").visible = false
	get_node("OculusShaft").visible = false
	for halo in _lantern_halos:
		halo.visible = false
	for side in [1, 2]:
		get_node("LanternWarmth%d" % side).visible = false
	var cloud: Texture2D = load(DIR + "mist.res")
	for child in get_children():
		if child.name.begins_with("Mist"):
			child.material_override.set_shader_parameter("tint", ROUNDEL_MIST)
	# Low banks gathered at the foot of the back wall, leaving the windows above them clear.
	_mist(QuadMesh.new(), Vector2(22, 3.4), Vector3(0, 1.3, -10.2), Vector3.ZERO, cloud,
		{"tiling": 1.6, "opacity": 0.3, "outer": 0.5, "inner": 0.1, "tint": ROUNDEL_MIST})
	_mist(QuadMesh.new(), Vector2(20, 2.4), Vector3(0, 0.8, -8.6), Vector3.ZERO, cloud,
		{"tiling": 1.3, "opacity": 0.26, "outer": 0.5, "inner": 0.1, "tint": ROUNDEL_MIST, "drift": Vector2(-0.016, 0.005)})
	environment.background_color = ROUNDEL_GLOOM
	environment.ambient_light_color = Color("#9cc7cc")
	environment.fog_light_color = Color("#12303a")
	environment.fog_density = ROUNDEL_FOG
	environment.glow_intensity = 0.45
	get_node("OculusKey").spot_angle = 20.0
	# The default bias stripes the platform's rim with shadow acne on the Compatibility renderer.
	get_node("OculusKey").shadow_bias = 0.15
	get_node("OculusKey").shadow_normal_bias = 2.5
	get_node("FrontFill").light_energy = 0.4
	set_house_lights(1.0)
	var room := _mesh(self, "roundels")
	for si in room.mesh.get_surface_count():
		if room.mesh.surface_get_material(si).resource_name == "roundel_floor":
			room.set_surface_override_material(si, _vault_paint("vault_floor", ROUNDEL_FLOOR_PAINT))
	add_child(_vault_piece("vault_floor", ROUNDEL_FLOOR_PAINT))
	add_child(_vault_piece("vault_plinth", Color.WHITE))


## Quietens the walls for a film whose camera looks straight at them: `glass` scales the windows' glow and `mist` the haze
## in front of them.
func hush_walls(glass: float, mist: float) -> void:
	var room: MeshInstance3D = get_node("Roundels")
	for si in room.mesh.get_surface_count():
		if room.mesh.surface_get_material(si).resource_name == "roundel_panel":
			var dimmed: StandardMaterial3D = room.mesh.surface_get_material(si).duplicate()
			dimmed.emission_energy_multiplier *= glass
			dimmed.albedo_color *= Color(glass, glass, glass)
			room.set_surface_override_material(si, dimmed)
	for child in get_children():
		if child.name.begins_with("Mist"):
			var layer: ShaderMaterial = child.material_override
			layer.set_shader_parameter("opacity", float(layer.get_shader_parameter("opacity")) * mist)


## Grows the whole vault for a film that needs a wider view than the hatch's. A light's range ignores its node's scale,
## so each one is stretched to match.
func enlarge(factor: float) -> void:
	scale = Vector3.ONE * factor
	for light in find_children("*", "OmniLight3D", true, false):
		light.omni_range *= factor
	for light in find_children("*", "SpotLight3D", true, false):
		light.spot_range *= factor


## How brightly the roundel chamber's ceiling lights are on, from 0 to 1.
func set_house_lights(amount: float) -> void:
	environment.ambient_light_energy = lerpf(HOUSE_LIGHTS_DIM, HOUSE_LIGHTS_FULL, amount)


## Stands a smaller copy of the centre's plinth and platform on the vault floor, at (x, z) = `at`.
func add_back_platform(at: Vector2, size: float) -> void:
	var holder := Node3D.new()
	holder.name = "BackPlatform%d" % get_child_count()
	holder.position = Vector3(at.x, 0, at.y)
	holder.scale = Vector3.ONE * size
	add_child(holder)
	holder.add_child(_vault_piece("vault_plinth", Color.WHITE))
	var top := _mesh(holder, "platform")
	top.rotation.y = PI * 0.25
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hangs another TCM Core from the vault, unlit and with its tongs open, in the white-and-steel bake whose wires keep
## their colours. `at` is where its body hangs.
func add_hanging_core(at: Vector3, size: float) -> void:
	var tongs: Array[Node3D] = []
	var hanging := _core_frame(tongs, "steel_")
	hanging.name = "HangingCore%d" % get_child_count()
	hanging.position = at
	hanging.scale *= size
	for joint in tongs:
		joint.rotation.x = -0.15
	for part in hanging.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Gives full-detail core parts the steel paint of their simplified copies, for a film that sees them up close.
func _paint_steel(frame: Node3D) -> void:
	for part: MeshInstance3D in frame.find_children("*", "MeshInstance3D", true, false):
		var paint: Mesh = load(String(part.mesh.resource_path).replace(DIR, DIR + "steel_"))
		for si in part.mesh.get_surface_count():
			part.set_surface_override_material(si, paint.surface_get_material(si))


## One surface of the stone vault as its own piece, freshly painted.
func _vault_piece(surface: String, paint: Color) -> MeshInstance3D:
	var room: Mesh = _meshes["room"]
	var mesh := ArrayMesh.new()
	for si in room.get_surface_count():
		if room.surface_get_material(si).resource_name == surface:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, room.surface_get_arrays(si))
			mesh.surface_set_material(0, _vault_paint(surface, paint))
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


func _vault_paint(surface: String, paint: Color) -> StandardMaterial3D:
	var room: Mesh = _meshes["room"]
	for si in room.get_surface_count():
		if room.surface_get_material(si).resource_name == surface:
			var material: StandardMaterial3D = room.surface_get_material(si).duplicate()
			material.albedo_color = paint
			material.roughness = 0.45
			return material
	return null


func _build_air() -> void:
	var mist: Texture2D = load(DIR + "mist.res")
	# Ground haze hugs the floor and opens around the plinth, so its planes never slice the stone steps.
	_mist(PlaneMesh.new(), Vector2(30, 30), Vector3(0, 0.14, 0), Vector3.ZERO, mist,
		{"tiling": 5.0, "opacity": 0.24, "tint": Color("#a9b1c6"), "hole": 0.125})
	_mist(PlaneMesh.new(), Vector2(24, 24), Vector3(0, 0.30, 0), Vector3(0, 1.4, 0), mist,
		{"tiling": 3.3, "opacity": 0.15, "tint": Color("#c0c6d6"), "drift": Vector2(-0.013, 0.006), "hole": 0.16})
	# Thin banks behind the plinth put the dark vault at a distance without hiding its ribs.
	_mist(QuadMesh.new(), Vector2(26, 9), Vector3(0, 2.6, -6.5), Vector3.ZERO, mist,
		{"tiling": 1.6, "opacity": 0.15, "tint": Color("#6f7790"), "outer": 0.5, "inner": 0.05})
	_mist(QuadMesh.new(), Vector2(12, 5), Vector3(-6.6, 1.9, -1.8), Vector3(0, 0.5, 0), mist,
		{"tiling": 1.2, "opacity": 0.14, "tint": Color("#7c84a0"), "drift": Vector2(0.016, 0.004)})
	_mist(QuadMesh.new(), Vector2(12, 5), Vector3(6.6, 2.1, -2.4), Vector3(0, -0.5, 0), mist,
		{"tiling": 1.2, "opacity": 0.14, "tint": Color("#7c84a0"), "drift": Vector2(-0.014, 0.005)})
	# Pale daylight falling from the oculus, far above.
	var cone := _open_cone(1.3, 4.9)
	var shaft := MeshInstance3D.new()
	shaft.name = "OculusShaft"
	shaft.mesh = cone
	shaft.scale.y = 15.0
	shaft.position.y = 7.5
	var pale := ShaderMaterial.new()
	pale.shader = preload("res://scripts/gfx/hatchery_beam.gdshader")
	pale.set_shader_parameter("power", 1.0)
	pale.set_shader_parameter("strength", 0.075)
	pale.set_shader_parameter("light_color", Color("#c9d2e8"))
	shaft.material_override = pale
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)
	var motes := MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.mesh = QuadMesh.new()
	motes.instance_count = 56
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in motes.instance_count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 7.0
		motes.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cos(a) * r, rng.randf() * 7.0, sin(a) * r)))
	_dust = ShaderMaterial.new()
	_dust.shader = preload("res://scripts/gfx/hatchery_dust.gdshader")
	var dust := MultiMeshInstance3D.new()
	dust.name = "Dust"
	dust.multimesh = motes
	dust.material_override = _dust
	dust.custom_aabb = AABB(Vector3(-9, -1, -9), Vector3(18, 10, 18))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


## The core's body, its conduit and three tongs, without any of its lights. Each tong's joint is added to `tongs`.
## `bake` picks a set of the meshes: "" for the full-detail bronze, "steel_" for the merge film's simplified background copies.
func _core_frame(tongs: Array[Node3D], bake := "") -> Node3D:
	var frame := Node3D.new()
	frame.name = "TCMCore"
	frame.scale = Vector3.ONE * CORE_SCALE
	# Puts the odd tong behind the egg, so the two in front frame the shell instead of crossing it.
	frame.rotation.y = PI
	add_child(frame)
	_mesh(frame, bake + "core")
	# Metal and bundled wires rise from the core's crown past the top of the frame, so it hangs from the vault.
	_mesh(frame, bake + "conduit")
	if _tong_data.is_empty():
		_tong_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tongs.json"))
	for i in 3:
		var entry: Dictionary = _tong_data[i]
		var arm := Node3D.new()
		arm.name = "Tong%d" % (i + 1)
		arm.position = Vector3(entry.pivot[0], entry.pivot[1], entry.pivot[2])
		arm.rotation.y = float(entry.angle)
		frame.add_child(arm)
		var joint := Node3D.new()
		arm.add_child(joint)
		_mesh(joint, bake + "tong_%d" % i).layers = TONG_LAYER
		tongs.append(joint)
	return frame


func _build_core(steel: bool) -> void:
	core = _core_frame(joints)
	if steel:
		_paint_steel(core)
	for entry in _tong_data:
		contact_points.append(Vector3(entry.tip[0], entry.tip[1], entry.tip[2]))
		closed_angles.append(0.4)
	emitter_material = StandardMaterial3D.new()
	emitter_material.albedo_color = INNER_LIGHT
	emitter_material.emission_enabled = true
	emitter_material.emission = INNER_LIGHT
	emitter_material.emission_energy_multiplier = 0.0
	var lens := CylinderMesh.new()
	lens.top_radius = 0.26
	lens.bottom_radius = 0.26
	lens.height = 0.035
	lens.radial_segments = 32
	var emitter := MeshInstance3D.new()
	emitter.name = "InnerLightLens"
	emitter.mesh = lens
	emitter.material_override = emitter_material
	emitter.position.y = -1.20
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(emitter)
	_emitter_halo = _halo_material(INNER_LIGHT)
	_halo(core, Vector3(0, -1.26, 0), 2.1, _emitter_halo)
	spotlight = SpotLight3D.new()
	spotlight.name = "CoreDownlight"
	spotlight.position.y = -1.25
	spotlight.rotation.x = -PI * 0.5
	spotlight.light_color = INNER_LIGHT
	spotlight.light_cull_mask = 1
	spotlight.spot_range = 9
	spotlight.spot_angle = 42
	spotlight.spot_angle_attenuation = 1.3
	core.add_child(spotlight)
	beam = MeshInstance3D.new()
	beam.name = "CentralLightShaft"
	beam.mesh = _open_cone(0.2, 1.3)
	beam_material = ShaderMaterial.new()
	beam_material.shader = preload("res://scripts/gfx/hatchery_beam.gdshader")
	beam_material.set_shader_parameter("light_color", INNER_LIGHT)
	beam_material.set_shader_parameter("strength", 0.15)
	beam_material.set_shader_parameter("falloff", 2.4)
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _mesh(parent: Node3D, key: String) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = load(DIR + key + ".res")
	var mi := MeshInstance3D.new()
	mi.name = key.capitalize()
	mi.mesh = _meshes[key]
	# Only the close-up subject and mechanism need to cast shadows. The chamber uses its textured shading.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["room", "conduit", "roundels"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _mist(mesh: PrimitiveMesh, size: Vector2, pos: Vector3, rot: Vector3, cloud: Texture2D, params: Dictionary) -> void:
	mesh.size = size
	var layer := MeshInstance3D.new()
	layer.name = "Mist%d" % get_child_count()
	layer.mesh = mesh
	layer.position = pos
	layer.rotation = rot
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/gfx/hatchery_mist.gdshader")
	material.set_shader_parameter("mist_texture", cloud)
	for key in params:
		material.set_shader_parameter(key, params[key])
	layer.material_override = material
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)


func _open_cone(top: float, bottom: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = top
	cone.bottom_radius = bottom
	cone.height = 1.0
	cone.radial_segments = 48
	cone.cap_top = false
	cone.cap_bottom = false
	return cone


func _halo_material(tint: Color) -> StandardMaterial3D:
	if _halo_texture == null:
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		_halo_texture = GradientTexture2D.new()
		_halo_texture.gradient = ramp
		_halo_texture.width = 64
		_halo_texture.height = 64
		_halo_texture.fill = GradientTexture2D.FILL_RADIAL
		_halo_texture.fill_from = Vector2(0.5, 0.5)
		_halo_texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.disable_fog = true
	material.albedo_texture = _halo_texture
	material.albedo_color = tint
	return material


func _halo(parent: Node3D, pos: Vector3, size: float, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.position = pos
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(halo)
	return halo


func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#06080d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8b8ea3")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.03
	# Ordinary depth/height fog works on Mobile and Compatibility too; no volumetric-only dependency.
	environment.fog_enabled = true
	environment.fog_light_color = Color("#1c2230")
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.055
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	# A soft pale key from the oculus, the only shadow caster. Neutral, so the mechanism's bronze stays bronze.
	var key := SpotLight3D.new()
	key.name = "OculusKey"
	key.position = Vector3(1.6, 12.5, 5.0)
	key.spot_range = 26
	key.spot_angle = 26
	key.spot_angle_attenuation = 1.2
	key.light_color = Color("#e4e4ec")
	key.light_energy = 9.0
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	add_child(key)
	key.look_at_from_position(key.position, Vector3(0, 1.4, 0))
	var fill := OmniLight3D.new()
	fill.name = "FrontFill"
	fill.position = Vector3(0.5, 2.8, 7.5)
	fill.light_color = Color("#d5d2dc")
	fill.light_energy = 1.4
	fill.omni_range = 13.0
	add_child(fill)
	for side in [-1.0, 1.0]:
		var warm := OmniLight3D.new()
		warm.name = "LanternWarmth%d" % (1 if side > 0 else 2)
		warm.position = Vector3(side * 3.6, 1.9, -2.6)
		warm.light_color = LANTERN_GLOW
		warm.light_energy = 1.7
		warm.omni_range = 6.5
		add_child(warm)


func fit_shell(egg: Dictionary) -> void:
	var radius := EggModel.radius_at(GRIP, EggLooks.look(egg).width)
	contact_height = 0
	for i in 3:
		var lo := 0.0
		var hi := 0.9
		var tip := contact_points[i]
		for step in 20:
			var a := (lo + hi) * 0.5
			var r := CORE_SCALE * (0.52 + sin(a) * tip.y + cos(a) * tip.z)
			if r > radius:
				lo = a
			else:
				hi = a
		var a := (lo + hi) * 0.5
		closed_angles[i] = a
		contact_height += DECK_Y + GRIP - CORE_SCALE * (-0.85 + cos(a) * tip.y - sin(a) * tip.z)
	contact_height /= 3.0


func animate(t: float, hatch: bool, revealed: bool) -> void:
	core.visible = hatch
	var lowered := smoothstep(0.8, 2.8, t)
	var released := smoothstep(5.65, 6.9, t)
	core.position.y = lerpf(CORE_START_Y, contact_height, lowered) + released * CORE_LIFT
	var closed := smoothstep(2.8, 3.8, t) * (1.0 - released)
	# The inner light wakes as the core settles over the egg and goes out with the whiteout.
	var power := smoothstep(1.9, 3.5, t) * (1.0 - smoothstep(5.6, 6.4, t)) if hatch else 0.0
	for i in 3:
		joints[i].rotation.x = lerpf(-0.15, closed_angles[i], closed)
	spotlight.light_energy = power * 3.0
	emitter_material.emission_energy_multiplier = power * 6.0
	_emitter_halo.albedo_color.a = power * 0.55
	var origin_y := core.position.y - 1.22 * CORE_SCALE
	var length := maxf(0.1, origin_y - DECK_Y)
	beam.position.y = DECK_Y + length * 0.5
	beam.scale.y = length
	beam.visible = hatch and not revealed
	beam_material.set_shader_parameter("power", power)
	var flicker := 0.92 + 0.08 * sin(t * 5.3) * sin(t * 2.1)
	_lantern_glow.emission_energy_multiplier = (0.85 + power * 0.25) * flicker
	_lantern_halo.albedo_color.a = (0.15 + power * 0.05) * flicker
	_dust.set_shader_parameter("strength", 0.42 + power * 0.3)
