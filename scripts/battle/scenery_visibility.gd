extends RefCounted
## Clear camera-to-fighter sightlines without removing the room shell or a whole scenery batch.
## Cache world bounds once; compact visible instances only when a prop changes state.
const INTERVAL := 0.08
const MARGIN := 0.3
var battle: Node3D
var batches: Array = []
var points: Array[Vector3] = []
var hidden_count := 0
var _elapsed := 0.0
var _camera_position := Vector3.INF
var _forward := Vector3.FORWARD
var _foreground_depth := INF


func _init(owner: Node3D) -> void:
	battle = owner


func register(node: MultiMeshInstance3D, originals: Array) -> void:
	var mm := node.multimesh
	var mesh_bounds := mm.mesh.get_aabb()
	var transforms: Array[Transform3D] = []
	var bounds: Array[AABB] = []
	var shown := PackedByteArray()
	for i in originals.size():
		# Keep the supplied CPU transforms; the headless RenderingServer returns identities for instance reads.
		var transform: Transform3D = originals[i]
		transforms.append(transform)
		bounds.append((node.global_transform * transform) * mesh_bounds)
		shown.append(1)
	batches.append({"node": node, "transforms": transforms, "bounds": bounds, "shown": shown})


func step(delta: float) -> void:
	_elapsed += delta
	# Cuts and quick camera moves clear the view immediately. Slow drifts reuse the last result for 80 ms.
	if _elapsed >= INTERVAL or battle.cam.global_position.distance_squared_to(_camera_position) > 0.12 \
		or (-battle.cam.global_basis.z).dot(_forward) < 0.999:
		update()


func update() -> void:
	if not is_instance_valid(battle.cam):
		return
	_elapsed = 0.0
	_camera_position = battle.cam.global_position
	_forward = -battle.cam.global_basis.z
	_foreground_depth = INF
	points.clear()
	_add_fighter(battle.PLAYER_POS, 1.6)
	if not battle.wild:
		_add_fighter(battle.RIVAL_POS, 1.6)
	for beast in battle.nodes:
		var node: Node3D = battle.nodes[beast]
		if is_instance_valid(node) and node.visible:
			_add_fighter(node.global_position, battle._ref_height(beast))
	# Clear the playing area between fighters too, including the foreground side of both rings.
	for center: Vector3 in [battle.ALLY_CENTER, battle.FOE_CENTER]:
		for x in [-3.0, 0.0, 3.0]:
			for z in [-3.0, 3.0]:
				points.append(center + Vector3(x, 0.65, z))
	hidden_count = 0
	for batch in batches:
		var changed := false
		var shown: PackedByteArray = batch["shown"]
		var bounds: Array = batch["bounds"]
		for i in bounds.size():
			var box: AABB = bounds[i]
			# Grass and low ground dressing don't cover a fighter's body.
			var depth := (box.get_center() - _camera_position).dot(_forward)
			# Clear the whole foreground, including side columns that frame across the playing area.
			var foreground := depth > 0.0 and depth < _foreground_depth
			var clear := box.size.y < 0.75 or (not foreground and not blocks(box, _camera_position, points))
			var state := 1 if clear else 0
			changed = changed or shown[i] != state
			shown[i] = state
			hidden_count += 1 - state
		batch["shown"] = shown
		if changed:
			var mm: MultiMesh = batch["node"].multimesh
			var count := 0
			for i in shown.size():
				if shown[i] == 1:
					mm.set_instance_transform(count, batch["transforms"][i])
					count += 1
			mm.visible_instance_count = count


func _add_fighter(at: Vector3, height: float) -> void:
	var depth := (at + Vector3.UP * height * 0.55 - _camera_position).dot(_forward)
	if depth > 0.0:
		_foreground_depth = minf(_foreground_depth, depth)
	points.append(at + Vector3.UP * 0.25)
	points.append(at + Vector3.UP * height * 0.55)
	points.append(at + Vector3.UP * height * 0.9)


static func blocks(bounds: AABB, camera: Vector3, targets: Array[Vector3]) -> bool:
	var box := bounds.grow(MARGIN)
	if box.has_point(camera):
		return true
	for target in targets:
		if box.intersects_segment(camera, target) != null:
			return true
	return false
