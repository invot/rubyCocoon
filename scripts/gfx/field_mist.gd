extends RefCounted
## Continuous local cloud fields and sparse motes, supported on Mobile and Compatibility.
const FogShader = preload("res://scripts/gfx/field_mist.gdshader")
static var _noise: Texture2D
static var _mote: Material

static func build(placements: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "FieldMist"
	if placements.is_empty():
		return root
	var first: Transform3D = placements[0]
	var bounds := Rect2(first.origin.x - 0.5, first.origin.z - 0.5, 1, 1)
	var points := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for xf: Transform3D in placements:
		bounds = bounds.merge(Rect2(xf.origin.x - 0.5, xf.origin.z - 0.5, 1, 1))
		points.append(xf.origin + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.2, 0.9), rng.randf_range(-0.45, 0.45)))
	bounds = bounds.grow(2.0)
	# A continuous coverage field; cubic interpolation feathers adjoining tile patches.
	var coverage := Image.create(ceili(bounds.size.x), ceili(bounds.size.y), false, Image.FORMAT_RGBA8)
	coverage.fill(Color(0, 0, 0, 1))
	for xf: Transform3D in placements:
		coverage.set_pixel(floori(xf.origin.x - bounds.position.x), floori(xf.origin.z - bounds.position.y), Color.WHITE)
	coverage.resize(maxi(3, coverage.get_width() / 2), maxi(3, coverage.get_height() / 2), Image.INTERPOLATE_LANCZOS)
	coverage.resize(256, 256, Image.INTERPOLATE_CUBIC)
	coverage.generate_mipmaps()
	var mask := ImageTexture.create_from_image(coverage)
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = 719
		noise.frequency = 0.025
		noise.fractal_octaves = 3
		var image := noise.get_seamless_image(256, 256)
		image.generate_mipmaps()
		_noise = ImageTexture.create_from_image(image)
	for layer in 3:
		var fog := MeshInstance3D.new()
		fog.name = "FogLayer%d" % layer
		var plane := PlaneMesh.new()
		plane.size = bounds.size
		plane.subdivide_width = 12
		plane.subdivide_depth = 12
		var mat := ShaderMaterial.new()
		mat.shader = FogShader
		mat.set_shader_parameter("coverage", mask)
		mat.set_shader_parameter("clouds", _noise)
		mat.set_shader_parameter("layer", float(layer))
		mat.set_shader_parameter("opacity", 1.8 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
		plane.material = mat
		fog.mesh = plane
		fog.position = Vector3(bounds.get_center().x, first.origin.y + 0.15 + layer * 0.28, bounds.get_center().y)
		fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fog)
	var p := CPUParticles3D.new()
	p.name = "Motes"
	p.amount = mini(32, placements.size())
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = points
	p.direction = Vector3(0.4, 0.3, 0.1)
	p.spread = 55.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.015
	p.scale_amount_max = 0.03
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.9, 0.9, 0))
	fade.add_point(0.25, Color(0.8, 0.9, 0.9, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(0.8, 0.9, 0.9, 0))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.material = _mote_material()
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	return root

static func _mote_material() -> Material:
	if _mote != null:
		return _mote
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1, 1, 1, 0))
	texture.gradient = soft
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	_mote = mat
	return _mote
