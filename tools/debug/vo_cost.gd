extends RefCounted
## Diagnostic inventories, never renderer draw-call or compiled-pipeline counters.
const Finish = preload("res://scripts/gfx/surface_finish.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")


static func pipeline_counters() -> Dictionary:
	var result := {}
	for key in ClassDB.class_get_integer_constant_list("RenderingServer"):
		if "PIPELINE_COMPILATIONS" in key:
			result[key] = RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer", key))
	return result


static func inventory(root: Node3D, camera: Camera3D = null) -> Dictionary:
	var result := {"geometry_nodes": 0, "surfaces": 0, "shadow_nodes": 0,
		"lights": 0, "shadow_lights": 0, "node_types": {}, "families": {},
		"material_modes": {}, "shader_features": {}, "finished_surfaces": 0}
	var materials := {}
	var finished := {}
	for node in root.find_children("*", "Node3D", true, false):
		if node is Light3D:
			if camera == null or node.is_visible_in_tree():
				result.lights += 1
				if node.shadow_enabled:
					result.shadow_lights += 1
		if not node is GeometryInstance3D:
			continue
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
		if mesh == null or (camera != null and not _in_view(node, camera)):
			continue
		result.geometry_nodes += 1
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			result.shadow_nodes += 1
		var count := mesh.get_surface_count()
		result.surfaces += count
		_add(result.node_types, node.get_class(), count)
		var family := "unlabelled"
		var owner_node: Node = node
		while owner_node != null:
			var script = owner_node.get_script()
			if script != null:
				family = script.resource_path
				break
			owner_node = owner_node.get_parent()
		_add(result.families, family, count)
		for s in count:
			var mat: Material = node.material_override
			if mat == null:
				mat = node.get_active_material(s) if node is MeshInstance3D else mesh.surface_get_material(s)
			_record(mat, result, materials, finished)
		if node.material_overlay != null:
			_record(node.material_overlay, result, materials, finished)
	result.distinct_materials = materials.size()
	result.distinct_finished_materials = finished.size()
	result.scope = "whole subtree, including hidden" if camera == null else "visible frustum AABB estimate; includes occluded and LOD alternatives"
	return result


static func _record(mat: Material, result: Dictionary, materials: Dictionary, finished: Dictionary) -> void:
	if mat == null:
		_add(result.material_modes, "default", 1)
		return
	materials[mat.get_instance_id()] = true
	var mode := "custom_unknown"
	var feature := "unknown"
	if mat is BaseMaterial3D:
		mode = ["opaque", "alpha_blend", "alpha_scissor", "alpha_hash", "alpha_depth_prepass"][mat.transparency]
		feature = "base:" + VT._kind_of(mat)
		if mat.has_meta(Finish.DONE):
			result.finished_surfaces += 1
			finished[mat.get_instance_id()] = true
	elif mat is ShaderMaterial and mat.shader != null:
		var code: String = mat.shader.code
		feature = "custom:" + mat.shader.resource_path
		# Source classification only; ALPHA mentions in comments may overcount.
		mode = "custom_alpha" if "ALPHA" in code else "custom_no_alpha"
		if "ALPHA_SCISSOR_THRESHOLD" in code or "ALPHA_HASH_SCALE" in code:
			mode = "custom_cutout"
	_add(result.material_modes, mode, 1)
	_add(result.shader_features, feature, 1)
	if mat.next_pass != null:
		# Count extra passes separately without pretending they are base mesh surfaces.
		_add(result.material_modes, "next_pass", 1)


static func _add(counts: Dictionary, key: String, count: int) -> void:
	counts[key] = counts.get(key, 0) + count


static func _in_view(node: GeometryInstance3D, camera: Camera3D) -> bool:
	if not node.is_visible_in_tree() or node.layers & camera.cull_mask == 0:
		return false
	var bounds: AABB = node.global_transform * node.get_aabb()
	for plane in camera.get_frustum():
		var inside := false
		for corner in 8:
			if not plane.is_point_over(bounds.get_endpoint(corner)):
				inside = true
				break
		if not inside:
			return false
	return true


static func script_probes(world: Node3D) -> Dictionary:
	# Isolated calls outside frame samples, not an inclusive profiler or additive costs.
	var result := {}
	for method in ["_fade_buildings", "_update_hole", "_animate_npcs", "_update_wilds", "_place_camera"]:
		var samples := []
		for i in 60:
			var began := Time.get_ticks_usec()
			if method in ["_update_hole", "_place_camera"]:
				world.call(method)
			else:
				world.call(method, 1.0 / 60.0)
			samples.append((Time.get_ticks_usec() - began) / 1000.0)
		samples.sort()
		result[method] = {"median_ms": (samples[29] + samples[30]) / 2.0, "p95_ms": samples[56], "max_ms": samples[59]}
	return result
