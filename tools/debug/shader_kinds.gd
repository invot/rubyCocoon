extends RefCounted
## Which material kinds a room draws that the Compatibility renderer was not told to keep (voxel_textures.gd
## keep_shaders): each such kind is compiled afresh on every visit. --room=caccoon#0 (Cocoon Cove's Beast Center)
const Beasts = preload("res://scripts/core/beasts.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	var room := String(opts.get("room", "caccoon#0"))
	await main._do_goto("caccoon", "start")
	await main._do_goto(room, "entry")
	await main._do_goto("caccoon", "start")
	await main._do_goto(room, "entry")
	for i in 3:
		await main.get_tree().process_frame
	var missing := {}
	for node in main.world.find_children("*", "GeometryInstance3D", true, false):
		var mats := [node.material_override]
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
		if mesh != null:
			for s in mesh.get_surface_count():
				mats.append(node.get_active_material(s) if node is MeshInstance3D else mesh.surface_get_material(s))
		for m in mats:
			if m is BaseMaterial3D and not VT._kept_kinds.has(VT._kind_of(m)):
				var k := VT._kind_of(m)
				if not missing.has(k):
					missing[k] = []
				missing[k].append("%s %s" % [node.get_path().get_concatenated_names().right(60), (m as BaseMaterial3D).albedo_texture])
	for k in missing:
		print("[not kept] ", k, "\n    ", "\n    ".join(missing[k].slice(0, 4)))
	print("SHADER KINDS DONE: %d kind(s) not kept, %d kept" % [missing.size(), VT._kept_kinds.size()])
