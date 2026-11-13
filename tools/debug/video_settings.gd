extends RefCounted
## Resolution/quality matrix, persistence, resizing and actual book inputs. Only explicit build/ settings files.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Book = preload("res://scripts/ui/book_menu.gd")
const Quality = preload("res://scripts/gfx/render_quality.gd")
var main: Node
var book: Control
var bad := 0


func run(root: Node, opts: Dictionary) -> void:
	main = root
	if not Prefs.prefs_path().begins_with("res://build/"):
		_check(false, "supply --prefs_path=res://build/video_settings/settings.cfg for isolated settings")
		return
	UI.auto = true
	await main._go("caccoon", "center")
	UI.auto = false
	main.world.frozen = true
	if opts.get("verify", "1") == "1":
		await _matrix()
		_persistence()
		await _new_scene()
		await _inputs()
	else:
		_open()
	if opts.get("profile", "0") == "1" and DisplayServer.get_name() != "headless":
		book.close()
		await _profile(opts)
		_open()
	Prefs.render_height = int(opts.get("render_height", "540"))
	Prefs.graphics_quality = String(opts.get("graphics_quality", "min"))
	Prefs.apply()
	book._open_tab(6)
	await main._wait(0.3)
	var shots := String(opts.get("shots", ""))
	if shots != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		for gem in UIKit.ACCENT_ORDER:
			Prefs.accent = gem
			Prefs.apply()
			await main._wait(0.2)
			await _shot(shots.path_join("settings_%s.png" % gem))
		book.row_buttons[1].grab_focus()
		await main._wait(0.2)
		await _shot(shots.path_join("settings_graphics.png"))
		book.close()
		for pair in [[540, "min"], [720, "mid"], [1080, "max"], [1440, "max"]]:
			Prefs.render_height = pair[0]
			Prefs.graphics_quality = pair[1]
			Prefs.apply()
			await main._wait(0.3)
			await _shot(shots.path_join("world_%dp_%s.png" % pair))
		# Same scene, resolution and Max effects: isolate only the distant blur for visual review.
		Prefs.render_height = 1080
		Prefs.graphics_quality = "max"
		Prefs.apply()
		var focus: CameraAttributesPractical = main.world.cam.attributes
		var enabled := focus.dof_blur_far_enabled
		focus.dof_blur_far_enabled = false
		await main._wait(0.3)
		await _shot(shots.path_join("distant_blur_before.png"))
		focus.dof_blur_far_enabled = enabled
		await main._wait(0.3)
		await _shot(shots.path_join("distant_blur_after.png"))
		_open()
		await main._wait(0.2)
	print("VIDEO SETTINGS DONE: %d problem(s)" % bad)


func _matrix() -> void:
	var window: Vector2i = main.get_window().size
	for height in Prefs.RESOLUTIONS:
		for quality in Prefs.QUALITY_ORDER:
			Prefs.render_height = height
			Prefs.graphics_quality = quality
			Prefs.apply()
			await main.get_tree().process_frame
			_check(main.view.size.y == height and absi(main.view.size.x - roundi(float(window.x) * height / window.y)) <= 1,
				"%dp/%s preserves aspect and internal height" % [height, quality])
			var ui_size: Vector2 = main.get_viewport().get_visible_rect().size
			_check(main.to_view(ui_size * 0.5).is_equal_approx(Vector2(main.view.size) * 0.5), "world taps map to the render viewport")
			_check(main.screen.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "smooth (bilinear) enlargement and reduction")
			var sharpen: bool = height < window.y and RenderingServer.get_current_rendering_method() != "gl_compatibility"
			_check((main.screen.material != null) == sharpen, "mild sharpen only when enlarging on Forward+/Mobile")
			for node in main.get_tree().get_nodes_in_group(Quality.GROUP):
				var base: Dictionary = node.get_meta(Quality.BASELINE)
				if node is SubViewport:
					_check(node.msaa_3d == {"min": 0, "mid": 1, "max": 2}[quality], "viewport anti-aliasing follows quality")
				elif node is Light3D:
					_check(node.shadow_enabled == (base["shadow"] and quality != "min"), "quality preserves authored shadow exclusions")
				elif node is WorldEnvironment:
					_check(node.environment.glow_enabled == (base["glow"] and quality != "min"), "glow follows quality")
				elif node is Camera3D and node.attributes is CameraAttributesPractical:
					var enabled: bool = quality == "max" and RenderingServer.get_current_rendering_method() != "gl_compatibility"
					_check(node.attributes.dof_blur_far_enabled == (base["dof_far"] and enabled), "distant blur follows quality and renderer")
					_check(not node.attributes.dof_blur_near_enabled, "foreground remains sharp")
			var subject_depth: float = (main.world.player.position - main.world.cam.position).dot(-main.world.cam.basis.z)
			_check(main.world.cam.attributes.dof_blur_far_distance >= subject_depth + 3.9, "hero and nearby tiles stay in focus")
	# A phone resize must keep the selected render height and expand width without stretching the camera.
	main.get_window().size = Vector2i(2400, 1080)
	await main._wait(0.15)
	_check(main.view.size == Prefs.render_size(main.get_window().size), "resizing reapplies the internal resolution")
	main.get_window().size = window
	await main._wait(0.15)


func _persistence() -> void:
	Prefs.render_height = 720
	Prefs.graphics_quality = "max"
	Prefs.save_prefs()
	Prefs.render_height = 540
	Prefs.graphics_quality = "min"
	Prefs.load_prefs()
	_check(Prefs.render_height == 720 and Prefs.graphics_quality == "max", "video settings survive save/reload")
	var config := ConfigFile.new()
	config.set_value("audio", "music", 0.4)
	config.save(Prefs.prefs_path())
	Prefs.load_prefs()
	_check(Prefs.render_height == 1080 and Prefs.graphics_quality == "mid" and is_equal_approx(Prefs.music_volume, 0.4),
		"old settings get sensible video defaults and retain audio preferences")
	config.set_value("video", "render_height", -1)
	config.set_value("video", "graphics_quality", "unknown")
	config.save(Prefs.prefs_path())
	Prefs.load_prefs()
	Prefs.apply()
	_check(Prefs.render_height == 1080 and Prefs.graphics_quality == "mid", "invalid video settings recover safely")


func _new_scene() -> void:
	Prefs.graphics_quality = "min"
	Prefs.apply()
	var stage := Node3D.new()
	main.view.add_child(stage)
	var env_node := WorldEnvironment.new()
	env_node.environment = Environment.new()
	env_node.environment.glow_enabled = true
	env_node.environment.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile"
	# Use an isolated viewport: two environments must never compete for the world's camera.
	var vp := SubViewport.new()
	vp.own_world_3d = true
	main.add_child(vp)
	vp.add_child(env_node)
	var lamp := DirectionalLight3D.new()
	lamp.shadow_enabled = true
	stage.add_child(lamp)
	var camera := Camera3D.new()
	camera.attributes = CameraAttributesPractical.new()
	camera.attributes.dof_blur_far_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	stage.add_child(camera)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	_check(not lamp.shadow_enabled and not env_node.environment.glow_enabled and vp.msaa_3d == Viewport.MSAA_DISABLED,
		"new scenes honor Min immediately")
	_check(not camera.attributes.dof_blur_far_enabled, "camera first loaded at Min has no distant blur")
	var shared_view := SubViewport.new()
	shared_view.own_world_3d = true
	main.add_child(shared_view)
	var shared_env := WorldEnvironment.new()
	shared_env.environment = env_node.environment
	shared_view.add_child(shared_env)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	Prefs.graphics_quality = "max"
	Prefs.apply()
	_check(lamp.shadow_enabled and env_node.environment.glow_enabled and vp.msaa_3d == Viewport.MSAA_4X,
		"Max restores authored effects even for scenes first loaded at Min")
	_check(env_node.environment.ssao_enabled == (RenderingServer.get_current_rendering_method() != "mobile"),
		"ambient occlusion only runs on a supported renderer")
	_check(camera.attributes.dof_blur_far_enabled == (RenderingServer.get_current_rendering_method() != "gl_compatibility"),
		"Max restores distant blur on a camera first loaded at Min")
	stage.queue_free()
	vp.queue_free()
	shared_view.queue_free()
	await main.get_tree().process_frame


func _open() -> void:
	book = Book.new().setup(main.world, "settings")
	UI.push(book)


func _inputs() -> void:
	Prefs.render_height = 540
	Prefs.graphics_quality = "min"
	Prefs.apply()
	_open()
	await main._wait(0.3)
	var position: Vector2i = main.world.player_pos
	await main._tap_at(book.row_buttons[0].get_global_rect().get_center())
	_check(Prefs.render_height == 720 and UI.stack.size() == 1, "one resolution tap advances once (got %dp)" % Prefs.render_height)
	await main._press("ui_right")
	_check(Prefs.render_height == 1080, "Right adjusts the focused resolution (got %dp)" % Prefs.render_height)
	await main._press("ui_left")
	_check(Prefs.render_height == 720, "Left reverses resolution (got %dp)" % Prefs.render_height)
	await main._tap_at(book.row_buttons[1].get_global_rect().get_center())
	_check(Prefs.graphics_quality == "mid", "one quality tap advances once (got %s)" % Prefs.graphics_quality)
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_A
		ev.pressed = down
		Input.parse_input_event(ev)
		await main.get_tree().process_frame
	_check(Prefs.graphics_quality == "max", "one gamepad A advances quality once (got %s)" % Prefs.graphics_quality)
	for i in book.rows.size() - 2:
		await main._press("ui_down")
		await main._wait(0.03)
	await main._wait(0.2)
	var needs_scroll: bool = book.list_box.size.y > book.list_scroll.size.y + 1.0
	_check(book.focus_row == book.rows.size() - 1 and (not needs_scroll or book.list_scroll.scroll_vertical > 0),
		"Down reaches and scrolls to the final setting (row %d/%d, scroll %d)" % [book.focus_row, book.rows.size() - 1, book.list_scroll.scroll_vertical])
	var button: Button = book.row_buttons[book.focus_row]
	_check(button.get_global_rect().intersection(book.list_scroll.get_global_rect()).size.y >= UIKit.row_h() - 1,
		"focused row remains fully visible")
	_check(button.size.y >= UIKit.row_h() and main.world.player_pos == position, "full-size rows and no movement from menu taps")
	await main._press("menu")
	_check(UI.stack.is_empty(), "Start closes Settings")
	_open()
	await main._wait(0.2)


func _shot(path: String) -> void:
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main._save_shot(path)


## GPU render time isolates the resolution/effect cost even with VSync or the mobile 60 fps cap.
func _profile(opts: Dictionary) -> void:
	var viewport: RID = main.view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var report := {"platform": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "window": str(main.get_window().size), "samples": {}}
	for height in Prefs.RESOLUTIONS:
		for quality in Prefs.QUALITY_ORDER:
			Prefs.render_height = height
			Prefs.graphics_quality = quality
			Prefs.apply()
			for i in 45:
				await main.get_tree().process_frame
			var gpu: Array[float] = []
			var cpu: Array[float] = []
			for i in maxi(10, int(opts.get("frames", "120"))):
				await main.get_tree().process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			gpu.sort()
			cpu.sort()
			var sample := {"render_size": str(main.view.size), "frames": gpu.size(), "gpu_median_ms": gpu[gpu.size() / 2],
				"gpu_p95_ms": gpu[int(gpu.size() * 0.95)], "render_cpu_median_ms": cpu[cpu.size() / 2]}
			var label := "%dp_%s" % [height, quality]
			report["samples"][label] = sample
			print("VIDEO PROFILE ", label, " ", JSON.stringify(sample))
	RenderingServer.viewport_set_measure_render_time(viewport, false)
	var path := String(opts.get("report", "res://build/video_profile.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))


func _check(ok: bool, what: String) -> void:
	if not ok:
		bad += 1
		print("FAIL video settings: ", what)
