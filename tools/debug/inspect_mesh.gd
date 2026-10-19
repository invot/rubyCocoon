extends SceneTree
## Details of named meshes in a model file: vertex colours, UVs, material, node transform.
##   godot --headless --path . --script res://tools/debug/inspect_mesh.gd -- "<file under psx/>" Name1 Name2 ...

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var p := ProjectSettings.globalize_path("res://psx/") + args[0]
	var d := FBXDocument.new()
	var st := FBXState.new()
	d.append_from_file(p, st)
	var sc := d.generate_scene(st)
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if not (inst.get_parent().name in args.slice(1)):
			continue
		var arr := inst.mesh.surface_get_arrays(0)
		var cols = arr[Mesh.ARRAY_COLOR]
		var uvs = arr[Mesh.ARRAY_TEX_UV]
		var m = inst.get_active_material(0)
		var uniq := {}
		if cols != null:
			for c in cols:
				uniq[(c as Color).to_html(false)] = uniq.get((c as Color).to_html(false), 0) + 1
		print(inst.get_parent().name, "/", inst.name, " verts ", arr[Mesh.ARRAY_VERTEX].size(), " colors ", cols != null, " uv ", uvs != null)
		print("   mat ", m, " vcol_albedo ", m.vertex_color_use_as_albedo if m is BaseMaterial3D else "?", " tex ", m.albedo_texture if m is BaseMaterial3D else "?", " col ", m.albedo_color if m is BaseMaterial3D else "")
		var keys := uniq.keys()
		keys.sort_custom(func(a, b): return uniq[a] > uniq[b])
		print("   top colours ", keys.slice(0, 10).map(func(k): return "%s:%d" % [k, uniq[k]]))
		var xf := Transform3D.IDENTITY
		var cur: Node = inst
		while cur != null and cur != sc:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		print("   global xf ", xf)
		print("   aabb ", xf * inst.mesh.get_aabb())
		if uvs != null and m is BaseMaterial3D and m.albedo_texture:
			print("   tex size ", m.albedo_texture.get_size())
	sc.free()
	quit()
