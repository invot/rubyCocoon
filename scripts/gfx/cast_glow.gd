extends Node3D
## The glow a beast gathers as it casts an elemental move (beast_rig.gd cast(); beast_model.gd pose_cast() for the old
## models): a bright core in the element's colour swelling at its mouth, hands or horns, with sparks drawn in to it,
## then flaring and bursting outward as it lets go. Unshaded and additive, casting no shadow, hidden between casts; a
## beast builds its glows on its first cast and reuses them.

## the core's radius at its fullest, in its parent's units (a beast's larger measure is 1)
const CORE := 0.07

static var _puff: GradientTexture2D

var _core: MeshInstance3D
var _halo: MeshInstance3D
var _sparks: CPUParticles3D
var _core_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _colour := Color.WHITE
var _tw: Tween


static func _material(billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		if _puff == null:
			_puff = GradientTexture2D.new()
			_puff.width = 64
			_puff.height = 64
			_puff.fill = GradientTexture2D.FILL_RADIAL
			_puff.fill_from = Vector2(0.5, 0.5)
			_puff.fill_to = Vector2(1.0, 0.5)
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.add_point(0.35, Color(1, 1, 1, 0.55))
			g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
			_puff.gradient = g
		m.albedo_texture = _puff
	return m


func _ready() -> void:
	if _core != null:
		return
	visible = false
	_core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = CORE
	s.height = CORE * 2.0
	s.radial_segments = 12
	s.rings = 6
	_core.mesh = s
	_core_mat = _material(false)
	_core.material_override = _core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * CORE * 6.0
	_halo.mesh = q
	_halo_mat = _material(true)
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# sparks drawn in from round it to the core (pulled to the middle), fading in as they come
	_sparks = CPUParticles3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE * CORE * 0.9
	_spark_mat = _material(true)
	sq.material = _spark_mat
	_sparks.mesh = sq
	_sparks.amount = 16
	_sparks.lifetime = 0.38
	_sparks.emitting = false
	_sparks.local_coords = true
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_sparks.emission_sphere_radius = CORE * 4.5
	_sparks.gravity = Vector3.ZERO
	_sparks.initial_velocity_min = 0.0
	_sparks.initial_velocity_max = 0.0
	_sparks.radial_accel_min = -CORE * 50.0
	_sparks.radial_accel_max = -CORE * 40.0
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## Starts gathering in this colour, from nothing.
func begin(col: Color) -> void:
	_ready()
	if _tw != null:
		_tw.kill()
	_colour = col
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.add_point(0.4, Color(col.lightened(0.15), 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(col.lightened(0.35), 1.0))
	_sparks.color_ramp = ramp
	_sparks.emitting = true
	visible = true
	gather(0.0)


## How far it has gathered (0..1): the core and its halo swelling, brightening to white at the heart.
func gather(k: float) -> void:
	var g := clampf(k, 0.0, 1.0)
	var sz := 0.15 + 0.85 * g
	_core.scale = Vector3.ONE * sz
	_halo.scale = Vector3.ONE * (0.3 + 0.9 * g)
	# (additive: a saturated colour, its heart lightened only a little, so the element still reads on a bright day)
	_core_mat.albedo_color = Color(_colour.lerp(Color.WHITE, 0.25 * g), 0.6 + 0.4 * g)
	_halo_mat.albedo_color = Color(_colour * 0.9, 0.3 + 0.55 * g)


## Lets go: a flare, a burst of sparks flung outward (left where they were flung, as the beast moves on), and the glow
## gone.
func release() -> void:
	_ready()
	_sparks.emitting = false
	burst(get_parent(), global_position, _colour, global_basis.get_scale().x)
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(_core, "scale", Vector3.ONE * 1.8, 0.06)
	_tw.tween_property(_halo, "scale", Vector3.ONE * 2.4, 0.08)
	_tw.chain().tween_property(_halo_mat, "albedo_color:a", 0.0, 0.16)
	_tw.parallel().tween_property(_core_mat, "albedo_color:a", 0.0, 0.12)
	_tw.chain().tween_callback(hide)


## Stops at once (a battle ending mid-cast, a beast held still).
func clear() -> void:
	if _tw != null:
		_tw.kill()
	if _sparks != null:
		_sparks.emitting = false
	visible = false


## A one-off burst of sparks in `col` at `at` (world space) under `parent`, `size` times the usual (a beast's scale):
## a cast letting go, and an elemental hit landing (soft: rising motes for a heal or a boost).
static func burst(parent: Node, at: Vector3, col: Color, size := 1.0, soft := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE * CORE * (1.6 if soft else 1.3)
	sq.material = _material(true)
	p.mesh = sq
	p.amount = 18 if soft else 22
	p.one_shot = true
	p.explosiveness = 0.55 if soft else 0.95
	p.lifetime = 0.8 if soft else 0.42
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = CORE * (5.0 if soft else 1.5)
	p.direction = Vector3.UP
	p.spread = 25.0 if soft else 180.0
	p.gravity = Vector3(0, 0.6, 0) if soft else Vector3.ZERO
	p.initial_velocity_min = (0.3 if soft else 1.4)
	p.initial_velocity_max = (0.7 if soft else 2.6)
	p.damping_min = 0.5 if soft else 5.0
	p.damping_max = 1.0 if soft else 7.0
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.3 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.lerp(Color.WHITE, 0.3), 1.0))
	ramp.add_point(0.35, Color(col, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.scale = Vector3.ONE * size
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
