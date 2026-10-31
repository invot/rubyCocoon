extends Node3D
## A moonlit title tableau: a flat shadow dragon rises into a rose-tinted moon,
## with slow wingbeats, drifting motes and the gold logo.
## The camera keeps its height on wide phones. make_splash.gd captures its opening frame.

signal arrived

const SUMMON := "res://assets/summons/fire.res"
const FONT := preload("res://ui/lunchds.ttf")
const FOV := 30.0
const CAMERA := Vector3(0, 2.2, 12.0)
const LOOK := Vector3(0, 2.4, 0)
## where the moon sits on the screen (a fraction of its height down from the top), the dragon in front of it
const MOON_AT := 0.37
const MOON_SIZE := 23.0
## Separate the ground and logo lighting from the unlit dragon and sky.
const NEAR_LAYER := 1

## the logo (hidden while Load Game or the character creator is open)
var logo: Node3D
var _t := 0.0
var _arrived := false
var _dragon: MeshInstance3D
var _mats: Array[ShaderMaterial] = []
var _dragon_card: MeshInstance3D
var _dragon_rest := Vector3.ZERO
var _moon_at := Vector3.ZERO


func _ready() -> void:
	var cam := Camera3D.new()
	cam.fov = FOV
	add_child(cam)
	cam.position = CAMERA
	cam.look_at(LOOK, Vector3.UP)
	cam.current = true
	_environment()
	_lights()
	# the moon and the dragon lie along the ray through MOON_AT, the moon far behind the dragon
	var ray := cam.basis * Vector3(0, (0.5 - MOON_AT) * 2.0 * tan(deg_to_rad(FOV / 2.0)), -1.0)
	_moon(CAMERA + ray * ((CAMERA.z + 28.0) / -ray.z))
	_dragon_up(CAMERA + ray * ((CAMERA.z + 12.0) / -ray.z))
	_ground()
	_logo()
	_motes()
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_apply()
	if not _arrived and _t >= 4.2:
		_arrived = true
		arrived.emit()


## Stops at time `at` for a reproducible title / boot splash frame.
func freeze(at: float) -> void:
	_t = at
	set_process(false)
	_apply()
	# Finished-ascent previews can open the menu; early previews keep it hidden.
	if not _arrived and _t >= 4.2:
		_arrived = true
		arrived.emit()


func _apply() -> void:
	for m in _mats:
		m.set_shader_parameter("t", _t)
	# the body rises as the wings beat down (the downstroke is the first 0.4 of a beat, see title_dragon.gdshader)
	var ph := fposmod(_t * 0.55, 1.0)
	_dragon.position.y = 0.025 * sin(ph / 0.4 * PI) if ph < 0.4 else -0.012 * sin((ph - 0.4) / 0.6 * PI)
	# A single eased ascent, then hover; never snap back below the screen.
	var rise := smoothstep(0.0, 4.2, _t)
	_dragon_card.position = _dragon_rest + Vector3.DOWN * (1.0 - rise) * 12.0
	logo.rotation = Vector3(-0.2 + sin(_t * 0.7) * 0.03, sin(_t * 0.45) * 0.12, 0)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#34447a")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	# the distant red ground melts into the night
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.07, 0.09, 0.18)
	env.fog_depth_begin = 12.0
	env.fog_depth_end = 40.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(64, 28)
	sky.mesh = q
	sky.material_override = _shader("title_sky")
	sky.position = Vector3(0, 4.0, -30.0)
	add_child(sky)


func _shader(n: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/%s.gdshader" % n)
	_mats.append(m)
	return m


func _light(col: Color, energy: float, rot: Vector3, mask: int) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.rotation_degrees = rot
	l.light_cull_mask = mask
	add_child(l)


func _lights() -> void:
	# a soft warm light from in front for the ground and gold logo, and the moon behind them
	_light(Color("#ffe6cc"), 0.85, Vector3(-35, -28, 0), NEAR_LAYER)
	_light(Color("#b8ccff"), 1.6, Vector3(-24, 172, 0), NEAR_LAYER)


func _moon(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * MOON_SIZE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/title_moon.gdshader")
	mi.material_override = m
	mi.position = at
	_moon_at = at
	add_child(mi)


## Render the existing summon as a sharp unlit cutout in front of the moon.
func _dragon_up(at: Vector3) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 720)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var mesh: ArrayMesh = load(SUMMON)
	var m := _shader("title_dragon")
	m.set_shader_parameter("albedo_tex", (mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture)
	m.set_shader_parameter("scissor", (mesh.surface_get_material(0) as StandardMaterial3D).alpha_scissor_threshold)
	_dragon = MeshInstance3D.new()
	_dragon.mesh = mesh
	_dragon.material_override = m
	_dragon.rotation.y = 0.0
	# (the wings beat past the mesh's resting bounds)
	_dragon.extra_cull_margin = 1.0
	vp.add_child(_dragon)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.25
	vp.add_child(cam)
	cam.position = Vector3(0, 0.5, 3.0)
	cam.current = true
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(12.6, 9.45)
	card.mesh = q
	var h := _shader("title_haze")
	h.set_shader_parameter("view_tex", vp.get_texture())
	card.material_override = h
	_dragon_card = card
	_dragon_rest = at
	card.position = at
	add_child(card)


func _ground() -> void:
	var g := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(90, 60)
	g.mesh = p
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/surfaces/ground_grass.png")
	m.albedo_color = Color(0.28, 0.025, 0.04)
	m.uv1_scale = Vector3(18, 12, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	# The broad moonlight wash below supplies the sheen, without sharp white specular highlights.
	m.metallic_specular = 0.0
	g.material_override = m
	g.position = Vector3(0, 0, -12)
	g.layers = NEAR_LAYER
	add_child(g)
	var glow := MeshInstance3D.new()
	glow.mesh = p
	var shine := ShaderMaterial.new()
	shine.shader = load("res://scripts/gfx/title_ground_glow.gdshader")
	shine.set_shader_parameter("moon_at", _moon_at)
	shine.set_shader_parameter("moon_size", MOON_SIZE)
	shine.set_shader_parameter("ground_tex", m.albedo_texture)
	glow.material_override = shine
	glow.position.y = 0.005
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(glow)


## RUBY COCOON in the heading font: extruded gold letters, with a ruby rim and a dark edge round them on flat plates
## just behind (the same letters, outlined).
func _logo() -> void:
	logo = Node3D.new()
	logo.position = Vector3(0, 4.45, 1.0)
	add_child(logo)
	var tm := TextMesh.new()
	tm.text = "RUBY COCOON"
	tm.font = FONT
	tm.font_size = 64
	tm.pixel_size = 0.0145
	tm.depth = 0.22
	tm.curve_step = 0.5
	var gold := MeshInstance3D.new()
	gold.mesh = tm
	var m := _shader("gold_shimmer")
	var bb := tm.get_aabb()
	m.set_shader_parameter("lo", bb.position.y)
	m.set_shader_parameter("hi", bb.end.y)
	m.set_shader_parameter("left", bb.position.x)
	m.set_shader_parameter("right", bb.end.x)
	gold.material_override = m
	logo.add_child(gold)
	# (drawn four times as big as the mesh's font size, at a quarter of its pixel size: the same letters, crisper)
	for k in [[52, Color("#1c0508"), bb.position.z - 0.07], [30, Color("#c8142e"), bb.position.z - 0.04]]:
		var l := Label3D.new()
		l.text = tm.text
		l.font = FONT
		l.font_size = 256
		l.pixel_size = tm.pixel_size / 4.0
		l.modulate = k[1]
		l.outline_size = k[0]
		l.outline_modulate = k[1]
		l.position.z = k[2]
		logo.add_child(l)


## Motes of moonlit dust drifting up through the dark.
func _motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = 110
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 3, 5)
	p.position = Vector3(0, 2.5, -1.0)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.04, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.9, 1, 0))
	ramp.add_point(0.3, Color(0.85, 0.92, 1, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.85, 1, 0))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.3, 1.3, 1.4)
	q.material = m
	p.mesh = q
	add_child(p)
