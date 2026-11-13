extends "res://scripts/battle/battle.gd"
## Render-only battle stage: no encounter, HUD, music, save changes or combat loop.
## Inherit the actual ring, placement, trainer appearance and beast model builders.

const FADED_LAYER := 1 << 18
var _faded_view: SubViewport
var _faded_camera: Camera3D
var _preview_environment: Environment
var selected_beast = null
var _slot_motion: Tween


func _ready() -> void:
	var environment := Environment.new()
	_preview_environment = environment
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	add_child(key)
	add_child(StageLighting.apply(environment, key, WorldDB.BIOMES["coast"], false))
	_build_ring("ally", false)
	cam = Camera3D.new()
	cam.cull_mask &= ~FADED_LAYER
	add_child(cam)
	# Preserve the battle's perspective and viewing direction, centering this one ring.
	var focus := ALLY_CENTER + Vector3.UP * 0.7
	cam.position = focus + (_cam_pos() - _cam_look())
	cam.look_at(focus)
	cam.current = true


func _exit_tree() -> void:
	pass # The preview never takes ownership of battle audio.


func _process(delta: float) -> void:
	_time += delta
	for beast in nodes:
		var root: Node3D = nodes[beast]
		if beast.hp > 0 and root.has_meta("phase"):
			root.get_node("Model").position.y = float(root.get_meta("lift")) + absf(sin(_time * 2.4 + float(root.get_meta("phase")))) * 0.05


func show_ring(placed: Dictionary, side: int) -> void:
	# Rotation changes only placement, so animated models survive repeated arrow presses.
	for beast in nodes.keys():
		if not placed.values().has(beast):
			remove_child(nodes[beast])
			nodes[beast].queue_free()
			nodes.erase(beast)
			st.erase(beast)
			participants.erase(beast)
			_hp_seen.erase(beast)
	ally_ring = placed
	ally_side = side
	ring_psi["ally"] = _psi_for("ally", side)
	for slot in placed:
		var beast = placed[slot]
		if beast != null and not nodes.has(beast):
			_spawn(beast, "ally", slot, false)
	_place_ring("ally")
	_light_pads("ally")


func face_offset(angle: float) -> void:
	ring_psi["ally"] = _psi_for("ally", ally_side) - angle
	_place_ring("ally")


## Separate the other beasts into an alpha-composited view so fading also works
## on Mobile and Compatibility without replacing their textured/animated materials.
func faded_texture() -> Texture2D:
	if _faded_view == null:
		_faded_view = SubViewport.new()
		_faded_view.world_3d = get_viewport().find_world_3d()
		_faded_view.transparent_bg = true
		_faded_view.handle_input_locally = false
		_faded_view.audio_listener_enable_3d = false
		add_child(_faded_view)
		_faded_camera = Camera3D.new()
		_faded_camera.cull_mask = FADED_LAYER
		_faded_camera.environment = _preview_environment
		_faded_view.add_child(_faded_camera)
		_faded_camera.current = true
		RenderingServer.frame_pre_draw.connect(_sync_faded_camera)
	_faded_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_faded_camera()
	return _faded_view.get_texture()


func _sync_faded_camera() -> void:
	if _faded_view == null:
		return
	_faded_view.size = get_viewport().size
	_faded_view.msaa_3d = get_viewport().msaa_3d
	_faded_camera.global_transform = cam.global_transform
	_faded_camera.fov = cam.fov
	_faded_camera.near = cam.near
	_faded_camera.far = cam.far


func show_placement(beast, slot: int) -> void:
	var same_beast: bool = selected_beast == beast
	var previous: Vector3 = nodes[beast].position if same_beast and nodes.has(beast) else Vector3.ZERO
	if _slot_motion != null and _slot_motion.is_running():
		_slot_motion.kill()
	selected_beast = beast
	if not nodes.has(beast):
		_spawn(beast, "ally", slot, false)
	_place_ring("ally")
	var root: Node3D = nodes[beast]
	var at := _slot_pos("ally", slot)
	var target := Vector3(at.x, root.position.y, at.z)
	if same_beast:
		root.position = previous
		_slot_motion = create_tween()
		_slot_motion.tween_property(root, "position", target, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		root.position = target
	set_front([beast])
	for other in nodes:
		for geometry: GeometryInstance3D in nodes[other].find_children("*", "GeometryInstance3D", true, false):
			geometry.layers = (geometry.layers | 1) & ~FADED_LAYER if other == beast else (geometry.layers & ~1) | FADED_LAYER
	if _faded_view != null:
		_faded_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func clear_placement() -> void:
	if _slot_motion != null and _slot_motion.is_running():
		_slot_motion.kill()
	selected_beast = null
	set_front([])
	for beast in nodes:
		for geometry: GeometryInstance3D in nodes[beast].find_children("*", "GeometryInstance3D", true, false):
			geometry.layers = (geometry.layers | 1) & ~FADED_LAYER
	_place_ring("ally")
	if _faded_view != null:
		_faded_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func fit_camera(view_size: Vector2) -> void:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var focus := ALLY_CENTER + Vector3.UP * 0.7
	cam.position = focus + (_cam_pos() - _cam_look())
	cam.look_at(focus)
	# Sample the circular ground art and the actual fighters, rather than fitting an
	# oversized box with empty upper corners. Leave room for idle poses and ring turns.
	var points := PackedVector3Array()
	for index in 64:
		var angle := TAU * index / 64.0
		points.append(ALLY_CENTER + Vector3(cos(angle), 0, sin(angle)) * (RING_R + 1.45))
	var fighters: Array = nodes.values()
	for fighter: Node3D in fighters:
		for mesh: MeshInstance3D in fighter.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			var bounds := mesh.get_aabb()
			for index in 8:
				points.append(mesh.global_transform * bounds.get_endpoint(index))
	var extent := Rect2()
	for index in points.size():
		var point := cam.to_local(points[index])
		var screen_plane := Vector2(point.x, point.y)
		extent = Rect2(screen_plane, Vector2.ZERO) if index == 0 else extent.expand(screen_plane)
	var middle := extent.get_center()
	cam.position += cam.basis * Vector3(middle.x, middle.y, 0)
	var tangent := 0.0
	var aspect := view_size.x / view_size.y
	for world_point in points:
		var point := cam.to_local(world_point)
		var depth := maxf(-point.z, 0.1)
		tangent = maxf(tangent, maxf(absf(point.y) / depth, absf(point.x) / (depth * aspect)))
	cam.fov = rad_to_deg(2.0 * atan(tangent * 1.12))
