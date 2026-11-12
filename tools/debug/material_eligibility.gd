extends RefCounted
## Conservative exact-property comparison. Identical resources are already shared, not duplicates.
const Finish = preload("res://scripts/gfx/surface_finish.gd")


static func audit(root: Node3D) -> Dictionary:
	var materials := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat: Material = node.material_override
			if mat == null:
				mat = node.get_active_material(s) if node is MeshInstance3D else mesh.surface_get_material(s)
			if not mat is BaseMaterial3D or not mat.has_meta(Finish.DONE):
				continue
			var id := mat.get_instance_id()
			if not materials.has(id):
				materials[id] = {"material": mat, "paths": []}
			if materials[id].paths.size() < 4:
				materials[id].paths.append(String(root.get_path_to(node)) + ":surface=" + str(s))
	var groups := {}
	for entry in materials.values():
		var mat: BaseMaterial3D = entry.material
		var properties := {}
		for prop in mat.get_property_list():
			var key: String = prop.name
			if not prop.usage & PROPERTY_USAGE_STORAGE or key in ["resource_name", "resource_path", "resource_local_to_scene", "script"] or key.begins_with("metadata/"):
				continue
			var value = mat.get(key)
			# Texture/next-pass identity is conservative: no image-content or shader equivalence guesses.
			properties[key] = ("resource_id:" + str(value.get_instance_id())) if value is Resource else var_to_bytes(value).hex_encode()
		var signature := var_to_bytes(properties).hex_encode()
		if not groups.has(signature):
			groups[signature] = []
		groups[signature].append({"name": mat.resource_name, "resource_path": mat.resource_path,
			"transparency": mat.transparency, "paths": entry.paths,
			"local_to_scene": mat.resource_local_to_scene})
	var duplicates := []
	var redundant := 0
	for group in groups.values():
		if group.size() > 1:
			duplicates.append(group)
			redundant += group.size() - 1
	return {"distinct_finished_materials": materials.size(), "exact_property_groups": groups.size(),
		"redundant_resources_upper_bound": redundant, "duplicate_groups": duplicates,
		"note": "Whole subtree, including hidden; equivalent properties do not establish safe shared mutation ownership."}
