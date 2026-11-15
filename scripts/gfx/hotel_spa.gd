extends RefCounted
## Hotel spa dressing; navigation and steps come from the room's shared dais.

static func build(parent: Node3D, at: Vector3, tile: Material, ivory: Material, dark: Material) -> void:
	var spa := Node3D.new()
	spa.name = "HotelSpa"
	spa.position = at
	parent.add_child(spa)
	var basin := CylinderMesh.new()
	basin.top_radius = 1.06
	basin.bottom_radius = 1.06
	basin.height = 0.42
	basin.radial_segments = 48
	_piece(spa, basin, tile, Vector3(0, 0.21, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.87
	rim.outer_radius = 1.12
	rim.rings = 48
	rim.ring_segments = 12
	var lip := _piece(spa, rim, ivory, Vector3(0, 0.43, 0))
	lip.scale.y = 0.55
	var pool := CylinderMesh.new()
	pool.top_radius = 0.91
	pool.bottom_radius = 0.91
	pool.height = 0.025
	pool.radial_segments = 48
	var water := ShaderMaterial.new()
	water.shader = preload("res://scripts/gfx/water.gdshader")
	var textures = preload("res://scripts/gfx/voxel_textures.gd")
	water.set_shader_parameter("frames", textures.frames("water"))
	water.set_shader_parameter("frame_count", float(textures.WATER_FRAMES))
	water.set_shader_parameter("tint", Color("#edafc9"))
	water.set_shader_parameter("shallow_tint", Color("#eab0c7"))
	water.set_shader_parameter("deep_tint_scale", Vector3(0.85, 0.85, 0.85))
	water.set_shader_parameter("absorption_strength", 4.0)
	water.set_shader_parameter("opacity", 0.95)
	water.set_shader_parameter("backdrop_depth", 0.5)
	water.set_shader_parameter("wave_height", 0.006)
	water.set_shader_parameter("spec", 0.0)
	water.set_shader_parameter("drift", Vector2(0.01, 0.015))
	var surface := _piece(spa, pool, water, Vector3(0, 0.425, 0))
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A freestanding sign beside the bath, facing into the room, with the pack's smooth painted steam symbol.
	var post := CylinderMesh.new()
	post.top_radius = 0.055
	post.bottom_radius = 0.075
	post.height = 1.12
	_piece(spa, post, dark, Vector3(1.5, 0.56, -0.55))
	var board := BoxMesh.new()
	board.size = Vector3(0.78, 0.78, 0.08)
	_piece(spa, board, ivory, Vector3(1.5, 1.3, -0.55))
	var logo := QuadMesh.new()
	logo.size = Vector2(0.7, 0.7)
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = load("res://assets/ui/icons/glyphs/spa_steam.png")
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_piece(spa, logo, ink, Vector3(1.5, 1.3, -0.503))
	_steam(spa)

static func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)
	return piece

static func _steam(parent: Node3D) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.position.y = 0.49
	steam.amount = 20
	steam.lifetime = 2.8
	steam.preprocess = 2.8
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam.emission_box_extents = Vector3(0.65, 0.01, 0.65)
	steam.direction = Vector3.UP
	steam.spread = 18.0
	steam.gravity = Vector3(0.025, 0.035, 0)
	steam.initial_velocity_min = 0.16
	steam.initial_velocity_max = 0.28
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.1
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.94, 0.96, 0))
	fade.add_point(0.2, Color(1, 0.94, 0.96, 0.32))
	fade.add_point(0.6, Color(1, 0.97, 0.98, 0.2))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	steam.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.5))
	steam.scale_amount_curve = grow
	var puff := GradientTexture2D.new()
	puff.width = 64
	puff.height = 64
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	var mist := StandardMaterial3D.new()
	mist.albedo_texture = puff
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist.vertex_color_use_as_albedo = true
	mist.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = mist
	steam.mesh = quad
	parent.add_child(steam)
