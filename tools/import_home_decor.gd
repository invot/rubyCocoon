extends SceneTree
## Bakes the approved home decor kit (Claude's art candidate rev_001, runbook 037a; built procedurally, see
## docs/visual_overhaul/art_candidates/home_decor.md) into assets/interiors/home/<piece>.res, one mesh per piece.
##   godot --headless --path . --script res://tools/import_home_decor.gd -- --textures
##   godot --headless --path . --script res://tools/smooth_textures.gd      (smooths the atlas once)
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/import_home_decor.gd
##
## The first pass copies the kit's atlas to assets/interiors/tex/home_decor_atlas.png (smoothed once by
## tools/smooth_textures.gd, as that folder is in its list) and the print masks to assets/interiors/home/art_masks.png
## (NEVER smoothed: its channels are coverage masks), with the print and scheme data beside them. The second keeps
## each piece's two surfaces: 0 the atlas, its tint mask in the vertex colours (R fabric, G ceramic, B wood, A trim),
## and 1, on framed pieces, the print canvas. home_decor.gd gives them their room's materials. Pieces keep the kit's
## orientation: floor and top pieces centred on their base, wall pieces with their back face on z = 0, facing +z.

const REV := "res://build/art_candidates/home_decor/rev_001/"
const OUT := "res://assets/interiors/home/"
const ATLAS := "res://assets/interiors/tex/home_decor_atlas.png"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--textures" in OS.get_cmdline_user_args():
		_textures()
	else:
		_bake_all()
	quit()


func _copy(from: String, to: String) -> void:
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	print("%s -> %s%s" % [from, to, "" if err == OK else " FAILED %d" % err])


func _textures() -> void:
	_copy(REV + "textures/decor_atlas.png", ATLAS)
	_copy(REV + "textures/art_masks.png", OUT + "art_masks.png")
	_copy(REV + "textures/art_layout.json", OUT + "art_layout.json")
	_copy(REV + "source/generator/schemes.json", OUT + "schemes.json")
	# the pieces' notes (sizes, default prints), trimmed to what the game reads
	var ready: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REV + "READY.json"))
	var pieces := {}
	for name in ready["pieces"]:
		var p: Dictionary = ready["pieces"][name]
		pieces[name] = {"category": p["category"], "mount": p["mount"], "size": p["size_xyz"], "print": p["print"]}
	var f := FileAccess.open(OUT + "pieces.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(pieces, " ", false))
	f.close()
	print("now smooth the atlas (tools/smooth_textures.gd), run --import, then run this again without --textures")


func _bake_all() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(REV + "mesh/home_decor_kit.glb"), st) != OK:
		push_error("could not read the kit")
		return
	var scene := doc.generate_scene(st)
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "pieces.json"))
	var placeholder := StandardMaterial3D.new()
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var name := String(mi.name)
		if not pieces.has(name) or mi.mesh == null:
			continue
		# the piece's own turn and scale, without where the kit's lineup put it
		var basis := Basis()
		var cur: Node = mi
		while cur != null and cur != scene:
			if cur is Node3D:
				basis = (cur as Node3D).basis * basis
			cur = cur.get_parent()
		var mesh := ArrayMesh.new()
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vs.size():
				vs[i] = basis * vs[i]
				ns[i] = (basis * ns[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vs
			arrays[Mesh.ARRAY_NORMAL] = ns
			# tangents would be stale after the turn; the shaders don't use them
			arrays[Mesh.ARRAY_TANGENT] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var src := mi.mesh.surface_get_material(si)
			var canvas := src != null and "canvas" in String(src.resource_name).to_lower()
			mesh.surface_set_name(si, "canvas" if canvas or si == 1 else "atlas")
			mesh.surface_set_material(si, placeholder)
		mesh.set_meta("print", pieces[name]["print"])
		mesh.set_meta("mount", pieces[name]["mount"])
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		var has_col := mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR != 0
		print("%s: %s, %d surfaces, colours %s%s" % [name, mesh.get_aabb(), mesh.get_surface_count(), has_col,
			"" if err == OK else " SAVE FAILED"])
		n += 1
	scene.free()
	print("baked %d of %d pieces" % [n, pieces.size()])
