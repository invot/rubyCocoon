extends Node3D
## Standalone 010c feature trial, copied into an isolated project by the launcher.
var camera: Camera3D
var streaming: Object
var opts := {}
var rows: Array = []
var problems: Array = []
var textures: Array[Texture2D] = []

func _ready() -> void:
	Engine.max_fps = 60
	get_window().focus_exited.connect(func(): problems.append("trial lost foreground focus"))
	DisplayServer.screen_set_keep_on(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	streaming = Engine.get_singleton("TextureStreaming") if Engine.has_singleton("TextureStreaming") else null
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.12, 0.15, 0.19)
	add_child(world)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	var mode: String = opts.get("mode", "streamed")
	for index in 3:
		var texture: Texture2D = load("res://%s/coast_%d.png" % [mode, index])
		if texture == null:
			problems.append("texture missing: %d" % index)
			continue
		textures.append(texture)
		var panel := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(4.0, 2.0)
		panel.mesh = mesh
		panel.position.x = (index - 1) * 4.2
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.albedo_texture = texture
		panel.material_override = material
		add_child(panel)
	await sample("first_near", Vector3(0, 0, 3.0), 120)
	await sample("far", Vector3(0, 0, 40.0), 180)
	await sample("away", Vector3(0, 0, 3.0), 300)
	await sample("return_near", Vector3(0, 0, 3.0), 180)
	if streaming != null and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		streaming.set("min_lod_override", 3)
		streaming.set("max_lod_override", 3)
		await sample("forced_low", Vector3(0, 0, 3.0), 120)
		streaming.set("min_lod_override", 0)
		streaming.set("max_lod_override", 0)
		await sample("forced_full", Vector3(0, 0, 3.0), 120)
	var classes: Array = []
	for texture in textures:
		var info := {"class": texture.get_class(), "path": texture.resource_path, "size": [texture.get_width(), texture.get_height()]}
		if mode == "astc":
			var image := texture.get_image()
			if image != null:
				info["image_format"] = image.get_format()
				info["image_size"] = [image.get_width(), image.get_height()]
		classes.append(info)
	var formats := {}
	var device := RenderingServer.get_rendering_device()
	if device != null:
		for name in ["ASTC_4x4", "ASTC_6x6", "ASTC_8x8", "ETC2"]:
			var format: int = {"ASTC_4x4": RenderingDevice.DATA_FORMAT_ASTC_4x4_UNORM_BLOCK,
				"ASTC_6x6": RenderingDevice.DATA_FORMAT_ASTC_6x6_UNORM_BLOCK,
				"ASTC_8x8": RenderingDevice.DATA_FORMAT_ASTC_8x8_UNORM_BLOCK,
				"ETC2": RenderingDevice.DATA_FORMAT_ETC2_R8G8B8_UNORM_BLOCK}[name]
			formats[name] = device.texture_is_format_supported_for_usage(format, RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)
	var report := {"engine": Engine.get_version_info(), "platform": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"mode": mode, "enabled": ProjectSettings.get_setting("rendering/textures/streaming/enabled", false),
		"max_fps": Engine.max_fps, "android_swappy_mode": ProjectSettings.get_setting("display/window/frame_pacing/android/swappy_mode", 2),
		"memory_budget_enabled": ProjectSettings.get_setting("rendering/textures/streaming/memory_budget_enabled", false),
		"textures": classes, "samples": rows, "formats_sampling_supported": formats, "problems": problems,
		"scope": "Isolated copied backdrop family on unlit panels; desktop evidence unless platform is Android/Web. Not gameplay acceptance."}
	var output: String = opts.get("output", "user://trial")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write diagnostic report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("TEXTURE STREAMING TRIAL DONE: %d problem(s)" % problems.size())
	DisplayServer.screen_set_keep_on(false)
	get_tree().quit(0 if problems.is_empty() else 1)

func sample(label: String, position: Vector3, frames: int) -> void:
	camera.position = position
	camera.look_at(position + Vector3.BACK if label == "away" else Vector3.ZERO)
	var trace: Array = []
	var bytes: Array = []
	var previous := Time.get_ticks_usec()
	for frame in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		trace.append((now - previous) / 1000.0)
		bytes.append(streaming.call("get_memory_budget_bytes_used") if streaming != null else 0)
		previous = now
	var output: String = opts.get("output", "user://trial")
	DirAccess.make_dir_recursive_absolute(output)
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		problems.append("screenshot failed: " + label)
	rows.append({"label": label, "frame_ms": trace, "streamed_bytes": bytes,
		"texture_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)})
