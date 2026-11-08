extends Node3D
## The cleared TARDIS chamber, Sci-Fi platform and articulated TCM Core. All geometry is baked, UV-textured and
## smoothed ahead of time. The three real source tongs close against each species' shell, not a fixed ring.
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const DIR := "res://assets/interiors/hatch_"
const CORE_SCALE := 1.1
const DECK_Y := 1.07
static var _meshes := {}
static var _tong_data: Array = []

var core: Node3D
var tongs: Array[Node3D] = []
var joints: Array[Node3D] = []
var tong_materials: Array[StandardMaterial3D] = []
var closed_angles: Array[float] = []
var contact_points: Array[Vector3] = []
var contact_height := 3.9
var beam: MeshInstance3D
var beam_material: ShaderMaterial
var emitter_material: StandardMaterial3D
var spotlight: SpotLight3D
var environment: Environment
var _roundels: StandardMaterial3D


func build() -> void:
	_environment()
	_mesh(self, "room")
	_mesh(self, "platform")
	# Thin, softly drifting ground haze complements the depth fog on every renderer.
	for i in 2:
		var mist := MeshInstance3D.new()
		mist.name = "FloorMist%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(22, 22)
		mist.mesh = plane
		mist.position.y = 0.10 + i * 0.13
		mist.rotation.y = i * 1.4
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/gfx/hatchery_mist.gdshader")
		material.set_shader_parameter("mist_texture", _roundels.albedo_texture)
		mist.material_override = material
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mist)
	core = Node3D.new()
	core.name = "TCMCore"
	core.scale = Vector3.ONE * CORE_SCALE
	add_child(core)
	_mesh(core, "core")
	if _tong_data.is_empty():
		_tong_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tongs.json"))
	for i in 3:
		var entry: Dictionary = _tong_data[i]
		var arm := Node3D.new()
		arm.name = "Tong%d" % (i + 1)
		arm.position = Vector3(entry.pivot[0], entry.pivot[1], entry.pivot[2])
		arm.rotation.y = float(entry.angle)
		core.add_child(arm)
		var joint := Node3D.new()
		arm.add_child(joint)
		var mi := _mesh(joint, "tong_%d" % i)
		var material := mi.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission_texture = material.albedo_texture
		material.emission = Color("#3795b0")
		material.emission_energy_multiplier = 0.0
		mi.material_override = material
		tong_materials.append(material)
		tongs.append(arm)
		joints.append(joint)
		contact_points.append(Vector3(entry.tip[0], entry.tip[1], entry.tip[2]))
		closed_angles.append(0.4)
	emitter_material = StandardMaterial3D.new()
	emitter_material.albedo_color = Color("#bcebf0")
	emitter_material.emission_enabled = true
	emitter_material.emission = Color("#b3f0ff")
	emitter_material.emission_energy_multiplier = 0.5
	var lens := CylinderMesh.new()
	lens.top_radius = 0.22
	lens.bottom_radius = 0.22
	lens.height = 0.035
	lens.radial_segments = 32
	var emitter := MeshInstance3D.new()
	emitter.name = "BottomCenterEmitter"
	emitter.mesh = lens
	emitter.material_override = emitter_material
	emitter.position.y = -1.23
	core.add_child(emitter)
	spotlight = SpotLight3D.new()
	spotlight.name = "CoreDownlight"
	spotlight.position.y = -1.25
	spotlight.rotation.x = -PI * 0.5
	spotlight.light_color = Color("#b4ecff")
	spotlight.spot_range = 7
	spotlight.spot_angle = 28
	spotlight.spot_angle_attenuation = 1.6
	core.add_child(spotlight)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.9
	cone.height = 1.0
	cone.radial_segments = 48
	beam = MeshInstance3D.new()
	beam.name = "CentralLightShaft"
	beam.mesh = cone
	beam_material = ShaderMaterial.new()
	beam_material.shader = preload("res://scripts/gfx/hatchery_beam.gdshader")
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _mesh(parent: Node3D, key: String) -> MeshInstance3D:
	if not _meshes.has(key):
		_meshes[key] = load(DIR + key + ".res")
	var mi := MeshInstance3D.new()
	mi.name = key.capitalize()
	mi.mesh = _meshes[key]
	if key == "room":
		for si in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(si)
			if mat is StandardMaterial3D and mat.emission_enabled:
				_roundels = mat.duplicate() as StandardMaterial3D
				_roundels.emission = Color("#ad8a59")
				_roundels.emission_energy_multiplier = 0.09
				mi.set_surface_override_material(si, _roundels)
	# Only the close-up subject and mechanism need to cast shadows. The chamber uses its textured shading.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key == "room" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#08131b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#6f989f")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	# Ordinary depth/height fog works on Mobile and Compatibility too; no volumetric-only dependency.
	environment.fog_enabled = true
	environment.fog_light_color = Color("#254854")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.024
	environment.fog_height = 0.4
	environment.fog_height_density = 0.10
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)
	var key := SpotLight3D.new()
	key.position = Vector3(2.5, 6.5, 4.5)
	key.rotation_degrees = Vector3(-48, 25, 0)
	key.spot_range = 16
	key.spot_angle = 48
	key.light_color = Color("#b8e4e9")
	key.light_energy = 3.0
	key.shadow_enabled = true
	key.shadow_blur = 1.4
	add_child(key)
	key.look_at_from_position(key.position, Vector3(0, 2, 0))
	for entry in [Vector3(-6.8, 3.2, -5), Vector3(6.8, 3.5, -5.5), Vector3(0, 5.5, -7.5)]:
		var light := OmniLight3D.new()
		light.position = entry
		light.light_color = Color("#e8bc82")
		light.light_energy = 1.25
		light.omni_range = 7.5
		add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.7, 2.8, 1)
	rim.light_color = Color("#609cb9")
	rim.light_energy = 0.75
	rim.omni_range = 5
	add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1, 2.8, 3.5)
	fill.light_color = Color("#c4dcd9")
	fill.light_energy = 1.1
	fill.omni_range = 6.0
	add_child(fill)


func fit_shell(egg: Dictionary) -> void:
	var width: float = EggLooks.look(egg).width
	var radius := 0.52 * width * (1.0 - (0.77 / 1.38) * 0.22) * sqrt(1.0 - pow((0.77 - 0.69) / 0.69, 2))
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
		contact_height += DECK_Y + 0.77 - CORE_SCALE * (-0.85 + cos(a) * tip.y - sin(a) * tip.z)
	contact_height /= 3.0


func animate(t: float, hatch: bool, revealed: bool) -> void:
	core.visible = hatch
	var lowered := smoothstep(0.8, 2.8, t)
	var released := smoothstep(5.65, 6.9, t)
	core.position.y = lerpf(6.6, contact_height, lowered) + released * 3.0
	var closed := smoothstep(2.8, 3.8, t) * (1.0 - released)
	var power := smoothstep(2.6, 4.65, t) * (1.0 - smoothstep(5.6, 6.4, t)) if hatch else 0.0
	_roundels.emission_energy_multiplier = 0.09 - power * 0.04
	for i in 3:
		joints[i].rotation.x = lerpf(-0.15, closed_angles[i], closed)
		tong_materials[i].emission_energy_multiplier = smoothstep(3.6, 4.7, t) * 1.6 * (1.0 - released)
	spotlight.light_energy = power * 4.0
	emitter_material.emission_energy_multiplier = 0.5 + power * 3.0
	var origin_y := core.position.y - 1.25 * CORE_SCALE
	var length := maxf(0.1, origin_y - DECK_Y)
	beam.position.y = DECK_Y + length * 0.5
	beam.scale.y = length
	beam.visible = hatch and not revealed
	beam_material.set_shader_parameter("power", power)
