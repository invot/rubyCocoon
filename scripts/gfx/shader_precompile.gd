extends Node
## Compatibility (desktop OpenGL) compiles a shader program the first time something is drawn with it,
## and the first time a game runs on a machine that can take seconds per map (step 009b). While the title menu waits
## for a choice, this draws every shader combination the maps use (assets/shaders/compat_warmup.scn, written by
## --scene=shader-manifest) once, a few per frame, in small off-screen views lit as the maps are. The copied materials
## are kept for the rest of the session so their programs stay compiled; each map's own warm-up (world.gd
## _warm_shaders) still runs and finds them ready. Choosing a menu item cancels the rest; nothing else changes.
## The other renderers compile without stalling, and skip this.
const MANIFEST := "res://assets/shaders/compat_warmup.scn"
## (voxel_assets.gd is loaded only when needed: preloading it here would slow the title screen's first draw)
const VOXEL_ASSETS := "res://scripts/gfx/voxel_assets.gd"
## frame budget: grow the batch while frames stay short, shrink it while compiling makes them long
const FAST_MS := 40.0
const SLOW_MS := 120.0
const MAX_BATCH := 64

static var done := false
## materials and environments kept alive: freeing the last user of a shader frees its compiled program
static var _kept := []

var stats := {}
var _cancelled := false


## Desktop Compatibility with the engine's shader cache off only (the dedicated compatibility_build export, see
## project.godot). On the web the browser translates every program again (step 009b measured ~59 s of title compiling
## with multi-second freezes); with the native cache on, loading cached programs stalls (51 s at the title). Both keep
## compiling map by map behind each fade instead.
static func wanted() -> bool:
	return not done and RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and not OS.has_feature("web") and ResourceLoader.exists(MANIFEST) \
		and not ProjectSettings.get_setting_with_override("rendering/shader_compiler/shader_cache/enabled")


func cancel() -> void:
	_cancelled = true


## Draws the manifest. `template` is the game's 3D view, whose output settings the off-screen views copy.
func run(template: SubViewport) -> Dictionary:
	var started := Time.get_ticks_usec()
	stats = {"drawn": 0, "total": 0, "frames": 0, "worst_frame_ms": 0.0, "cancelled": false}
	var packed: PackedScene = load(MANIFEST)
	var root: Node = packed.instantiate()
	stats["load_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	var branches := root.get_children()
	for branch in branches:
		stats["total"] += branch.find_children("*", "GeometryInstance3D", true, false).size()
	var batch := 4
	for branch in branches:
		if _cancelled:
			break
		var vp := SubViewport.new()
		vp.size = Vector2i(128, 128)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if template != null:
			vp.msaa_3d = template.msaa_3d
			vp.screen_space_aa = template.screen_space_aa
			vp.scaling_3d_mode = template.scaling_3d_mode
			vp.scaling_3d_scale = template.scaling_3d_scale
			vp.use_debanding = template.use_debanding
			vp.positional_shadow_atlas_size = template.positional_shadow_atlas_size
		add_child(vp)
		root.remove_child(branch)
		branch.owner = null
		for n in branch.find_children("*", "", true, false):
			n.owner = null
		vp.add_child(branch)
		var cam := Camera3D.new()
		cam.fov = 70.0
		cam.near = 0.05
		cam.far = 60.0
		vp.add_child(cam)
		cam.current = true
		var we := branch.get_node_or_null("Environment")
		if we != null:
			_kept.append(we.environment)
		var specks := branch.find_children("*", "GeometryInstance3D", true, false)
		for s in specks:
			var m: Material = s.material_override
			if m is ShaderMaterial and m.has_meta("warmup_shader"):
				m.shader = load(VOXEL_ASSETS).two_sided_foliage()
			while m != null:
				_kept.append(m)
				m = m.next_pass
		var i := 0
		while i < specks.size() and not _cancelled:
			var shown := specks.slice(i, i + batch)
			for s in shown:
				s.visible = true
			var t0 := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			for s in shown:
				if is_instance_valid(s):
					s.visible = false
			stats["frames"] += 1
			stats["worst_frame_ms"] = maxf(stats["worst_frame_ms"], ms)
			stats["drawn"] += shown.size()
			i += shown.size()
			if ms < FAST_MS:
				batch = mini(batch * 2, MAX_BATCH)
			elif ms > SLOW_MS:
				batch = maxi(batch / 2, 1)
		vp.queue_free()
	root.queue_free()
	stats["cancelled"] = _cancelled
	stats["ms"] = (Time.get_ticks_usec() - started) / 1000.0
	if not _cancelled:
		done = true
	return stats
