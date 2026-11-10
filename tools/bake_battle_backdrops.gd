extends SceneTree
## Bake the existing region-specific scenery into repeating mural artwork. Run with a renderer (not --headless).
## godot --path . --rendering-method gl_compatibility --script res://tools/bake_battle_backdrops.gd
## Then tools/smooth_textures.gd -- --only=res://assets/battle/backdrops/ and godot --headless --path . --import.
const WorldDB = preload("res://scripts/data/world_db.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const DIR := "res://assets/battle/backdrops/"
const WIDTH := 20.0


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--biome="):
			only = arg.trim_prefix("--biome=")
	for id in WorldDB.BIOMES:
		if only != "" and id != only:
			continue
		await _region(String(id), WorldDB.BIOMES[id])
	print("BATTLE BACKDROPS BAKED")
	quit()


func _region(id: String, biome: Dictionary) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1024, 512)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(biome["sky_hz"])
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_color = Color(biome["sun"])
	sun.light_energy = 0.8
	world.add_child(sun)
	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 10)
	canvas.mesh = quad
	canvas.position = Vector3(0, 3.8, -8)
	var paint := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec4 sky : source_color;
uniform vec4 horizon : source_color;
uniform vec4 soil : source_color;
uniform vec4 hill : source_color;
void fragment() {
	float edge = 0.75 + sin(UV.x * 25.13274) * 0.035 + cos(UV.x * 37.69911) * 0.02;
	vec3 above = mix(sky.rgb, horizon.rgb, smoothstep(0.0, 0.8, UV.y));
	vec3 below = mix(hill.rgb, soil.rgb, smoothstep(edge, 1.0, UV.y));
	ALBEDO = mix(above, below, smoothstep(edge - 0.003, edge + 0.003, UV.y));
}"""
	paint.shader = shader
	paint.set_shader_parameter("sky", Color(biome["sky_top"]))
	paint.set_shader_parameter("horizon", Color(biome["sky_hz"]))
	paint.set_shader_parameter("soil", Color(biome["ground"]))
	paint.set_shader_parameter("hill", Color(biome["side"]).lerp(Color(biome["ground"]), 0.5))
	canvas.material_override = paint
	world.add_child(canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	# Repeat the entire composition beyond both image edges, including identical rotations, to make a seamless tile.
	for i in 20:
		var tree: String = biome["trees"][rng.randi_range(0, biome["trees"].size() - 1)][0]
		var at := Vector3(-WIDTH * 0.5 + WIDTH * i / 20.0 + rng.randf_range(-0.25, 0.25), -0.25, rng.randf_range(-2.5, 1.0))
		var height := rng.randf_range(3.2, 6.8)
		var rotation := rng.randf_range(0, TAU)
		for repeat in [-1, 0, 1]:
			var model := VA.instance(tree, height)
			model.position = at + Vector3.RIGHT * WIDTH * repeat
			model.rotation.y = rotation
			world.add_child(model)
	for i in 8:
		var rock: String = biome["rocks"][rng.randi_range(0, biome["rocks"].size() - 1)]
		var at := Vector3(-WIDTH * 0.5 + WIDTH * i / 8.0, -0.4, 1.5)
		var height := rng.randf_range(0.7, 1.5)
		for repeat in [-1, 0, 1]:
			var model := VA.instance(rock, height)
			model.position = at + Vector3.RIGHT * WIDTH * repeat
			world.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0, 3.8, 20)
	world.add_child(camera)
	camera.look_at(Vector3(0, 3.8, 0))
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var error := image.save_png(DIR + id + ".png")
	print("BACKDROP ", id, ": ", error_string(error))
	view.queue_free()
	await process_frame
