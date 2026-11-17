extends CPUParticles3D
## Moss's charged attack: a small, continuous halo using the existing soft four-point sparkle artwork.

func _ready() -> void:
	var art: Texture2D = preload("res://assets/ui/battle_sparkle.png")
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = art
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.texture_repeat = false
	var frames := float(art.get_width()) / float(art.get_height())
	mat.uv1_scale = Vector3(1.0 / frames, 1.0, 1.0)
	mat.uv1_offset = Vector3(3.0 / frames, 0.0, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = mat
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = 24
	lifetime = 1.3
	preprocess = 0.8
	emission_shape = EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.7
	position.y = 0.9
	direction = Vector3.UP
	spread = 35.0
	initial_velocity_min = 0.1
	initial_velocity_max = 0.4
	gravity = Vector3.ZERO
	scale_amount_min = 0.55
	scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.2, Color.WHITE)
	fade.add_point(0.7, Color.WHITE)
	color_ramp = fade
	emitting = true
