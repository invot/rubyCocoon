extends Node3D
## The title screen (main.gd _title), live in the 3D view: the fire summon beating its wings over a ruby glow, the
## lines' first forms gathered on the ground below it in their idle animations, and RUBY COCOON in extruded gold with a
## shimmer sweeping across it. tools/make_splash.gd renders a moment of it as the boot splash, so the boot splash gives
## way to the title without a jump. The camera keeps the frame's height, so a wider screen shows more at the sides
## while the logo, the dragon and the room for the menu between the two groups of beasts keep their places.

const Model = preload("res://scripts/gfx/beast_model.gd")
const SUMMON := "res://assets/summons/fire.res"
const FONT := preload("res://ui/lunchds.ttf")
## the beasts: form, where it stands (flyers hover), its turn from facing the camera (towards the middle) and size
const BEASTS := [
	["crab_1", Vector3(-4.3, 0, 1.4), 0.45, 0.95], ["cactus_1", Vector3(-3.1, 0, 2.3), 0.35, 0.85],
	["tree_1", Vector3(-2.7, 0, 0.2), 0.3, 0.85], ["bat_1", Vector3(-3.0, 1.9, 1.0), 0.4, 0.85],
	["frog_1", Vector3(4.3, 0, 1.4), -0.45, 0.95], ["berry_1", Vector3(3.1, 0, 2.3), -0.35, 0.85],
	["marmot_1", Vector3(2.7, 0, 0.2), -0.3, 0.85], ["owl_1", Vector3(3.0, 2.0, 1.0), -0.4, 0.85],
]
## render layers, so each group gets its own light: the beasts and the ground, the dragon, the logo
const BEAST_LAYER := 1
const DRAGON_LAYER := 2
const LOGO_LAYER := 4

## the logo (hidden while Load Game or the character creator is open)
var logo: Node3D
var _t := 0.0
var _dragon: MeshInstance3D
var _dragon_y := 0.0
var _mats: Array[ShaderMaterial] = []
var _rigs: Array = []


func _ready() -> void:
	_environment()
	_lights()
	_ground()
	_dragon_up()
	for b in BEASTS:
		_beast(b[0], b[1], b[2], b[3])
	_logo()
	_motes()
	var cam := Camera3D.new()
	cam.fov = 30.0
	add_child(cam)
	cam.position = Vector3(0, 2.2, 12.0)
	cam.look_at(Vector3(0, 2.4, 0), Vector3.UP)
	cam.current = true
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_apply()


## Stops at time `at`, every beast standing still in its rest pose (the boot splash's moment).
func freeze(at: float) -> void:
	_t = at
	for r in _rigs:
		r.hold()
	set_process(false)
	_apply()


func _apply() -> void:
	for m in _mats:
		m.set_shader_parameter("t", _t)
	# the body rises as the wings beat down (the downstroke is the first 0.4 of a beat, see wing_flap.gdshader)
	var ph := fposmod(_t * 0.55, 1.0)
	_dragon.position.y = _dragon_y + (0.18 * sin(ph / 0.4 * PI) if ph < 0.4 else -0.08 * sin((ph - 0.4) / 0.6 * PI))
	logo.rotation = Vector3(-0.2 + sin(_t * 0.7) * 0.03, sin(_t * 0.45) * 0.12, 0)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a4058")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	# the far ground melts into the dark
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.1, 0.025, 0.04)
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 34.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# the glow behind it all
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(60, 26)
	card.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/title_glow.gdshader")
	card.material_override = m
	_mats.append(m)
	card.position = Vector3(0, 3.6, -30.0)
	add_child(card)


func _light(col: Color, energy: float, rot: Vector3, mask: int) -> void:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.rotation_degrees = rot
	l.light_cull_mask = mask
	add_child(l)


func _lights() -> void:
	# beasts and the logo: a soft warm key; the dragon its own warmer key from the side; a ruby rim from behind on
	# everyone; a cool fill so the shadows aren't black
	_light(Color("#fff0dc"), 1.0, Vector3(-38, -28, 0), BEAST_LAYER | LOGO_LAYER)
	_light(Color("#ffd8a8"), 1.5, Vector3(-26, -52, 0), DRAGON_LAYER)
	_light(Color("#ff4a5a"), 1.1, Vector3(-14, 165, 0), BEAST_LAYER | LOGO_LAYER)
	_light(Color("#ff3a50"), 2.4, Vector3(-14, 160, 0), DRAGON_LAYER)


func _ground() -> void:
	var g := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(80, 60)
	g.mesh = p
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/surfaces/ground_rock.png")
	m.albedo_color = Color("#3a2026")
	m.uv1_scale = Vector3(14, 10, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	g.material_override = m
	g.position = Vector3(0, 0, -10)
	g.layers = BEAST_LAYER
	add_child(g)


func _dragon_up() -> void:
	var mesh: ArrayMesh = load(SUMMON)
	var src := mesh.surface_get_material(0) as StandardMaterial3D
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/wing_flap.gdshader")
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("scissor", src.alpha_scissor_threshold)
	_mats.append(m)
	_dragon = MeshInstance3D.new()
	_dragon.mesh = mesh
	_dragon.material_override = m
	_dragon.layers = DRAGON_LAYER
	_dragon.scale = Vector3.ONE * 6.0
	_dragon.rotation.y = -0.5
	_dragon_y = 1.0
	_dragon.position = Vector3(0.3, _dragon_y, -4.0)
	# (the wings beat past the mesh's resting bounds)
	_dragon.extra_cull_margin = 1.0
	add_child(_dragon)
	# a soft round shadow on the ground beneath it
	add_child(_blob(Vector3(0.3, 0.02, -4.0), 3.2, 0.35))


func _beast(form: String, at: Vector3, turn: float, size: float) -> void:
	var r: Node3D = Model.rig({"form": form}, size)
	r.rotation.y = -PI / 2.0 + turn
	r.position = at
	add_child(r)
	for mi in r.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = BEAST_LAYER
	_rigs.append(r)
	add_child(_blob(Vector3(at.x, 0.02, at.z), 0.55 * size, 0.5 if at.y < 0.1 else 0.25))


## A soft dark disc lying on the ground.
func _blob(at: Vector3, radius: float, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 1.2)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, alpha))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = at
	mi.layers = BEAST_LAYER
	return mi


## RUBY COCOON in the heading font: extruded gold letters, with a ruby rim and a dark edge round them on flat plates
## just behind (the same letters, outlined).
func _logo() -> void:
	logo = Node3D.new()
	logo.position = Vector3(0, 4.0, 1.0)
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
	gold.layers = LOGO_LAYER
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/gold_shimmer.gdshader")
	var bb := tm.get_aabb()
	m.set_shader_parameter("lo", bb.position.y)
	m.set_shader_parameter("hi", bb.end.y)
	m.set_shader_parameter("left", bb.position.x)
	m.set_shader_parameter("right", bb.end.x)
	_mats.append(m)
	gold.material_override = m
	logo.add_child(gold)
	# (drawn four times as big as the mesh's font size, at a quarter of its pixel size: the same letters, crisper)
	for k in [[48, Color("#1c0508"), -0.16], [26, Color("#c8142e"), -0.13]]:
		var l := Label3D.new()
		l.text = tm.text
		l.font = FONT
		l.font_size = 256
		l.pixel_size = tm.pixel_size / 4.0
		l.modulate = k[1]
		l.outline_size = k[0]
		l.outline_modulate = k[1]
		l.position.z = k[2]
		l.layers = LOGO_LAYER
		logo.add_child(l)


## Motes of light drifting up through the dark.
func _motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = 140
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(12, 4, 5)
	p.position = Vector3(0, 3.0, -1.0)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.04, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.8, 0.7, 0))
	ramp.add_point(0.3, Color(1, 0.85, 0.75, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.6, 0.6, 0))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.4, 1.1, 1.0)
	q.material = m
	p.mesh = q
	p.layers = LOGO_LAYER
	add_child(p)
