extends SceneTree
## Lists the meshes in a model file from psx/ (name, triangles, size, materials):
##   godot --headless --path . --script res://tools/debug/inspect_model.gd -- "Creatures/.../file.fbx"

func _init() -> void:
	for rel in OS.get_cmdline_user_args():
		var p := ProjectSettings.globalize_path("res://psx/") + rel
		var sc: Node = null
		var ext := p.get_extension().to_lower()
		if ext in ["glb", "gltf"]:
			var d := GLTFDocument.new()
			var st := GLTFState.new()
			if d.append_from_file(p, st) == OK:
				sc = d.generate_scene(st)
		elif ext == "fbx":
			var d2 := FBXDocument.new()
			var st2 := FBXState.new()
			if d2.append_from_file(p, st2) == OK:
				sc = d2.generate_scene(st2)
		elif ext == "obj":
			var m = load(p) if false else null
		if sc == null:
			print("could not load ", rel)
			continue
		var mis := sc.find_children("*", "MeshInstance3D", true, false)
		print(rel, ": ", mis.size(), " meshes")
		for mi in mis:
			var inst := mi as MeshInstance3D
			if inst.mesh == null:
				continue
			var tris := 0
			for s in inst.mesh.get_surface_count():
				var arr := inst.mesh.surface_get_arrays(s)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
			var mats := []
			for s in inst.mesh.get_surface_count():
				var m = inst.get_active_material(s)
				mats.append((m.resource_name if m else "-") + ("[T]" if m is BaseMaterial3D and m.albedo_texture else ""))
			print("  %-40s %6d tris  %s  %s  %s" % [inst.name, tris, inst.mesh.get_aabb().size, inst.get_parent().name, mats])
		sc.free()
	quit()
