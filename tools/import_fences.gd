extends SceneTree
## Bake the supplied fences through the shared material and scenery LOD pipeline.
## Run prepare_fences.py first, then this script, smooth_textures.gd and --import.
const Bake = preload("res://tools/psx_bake.gd")
const SOURCE := "res://build/fences_source/"


func _init() -> void:
	for name in ["fence", "stone_fence"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + name + ".json"))
		var mat := StandardMaterial3D.new()
		if name == "fence":
			# Reuse the huts' already-smoothed timber, with grain fitted per board by prepare_fences.py.
			mat.albedo_texture = load("res://assets/exteriors/tribal_hut_wood.res")
		else:
			var img := Image.load_from_file(d["texture"])
			img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
			mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.roughness = 0.95
		# Thin pickets and rails otherwise collect dark, jagged tree-shadow patches.
		# Keep the painted texture and directional lighting, without receiving shadow maps.
		mat.disable_receive_shadows = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0, d["v"].size(), 3):
			for j in [0, 2, 1]:
				var p: Array = d["v"][i + j]
				var uv: Array = d["uv"][i + j]
				var n: Array = d["n"][i + j]
				st.set_uv(Vector2(uv[0], uv[1]))
				st.set_normal(Vector3(n[0], n[1], n[2]).normalized())
				st.add_vertex(Vector3(p[0], p[1], p[2]))
		st.set_material(mat)
		st.index()
		_save(Bake.with_lods(st.commit()), name)
	# Take one panel, one plinth and two capped piers from the iron display kit.
	var pieces := [["Fence 1", Vector3(1.0, 0.70, 0.045), Vector3(0, 0.25, 0)],
		["Base 2", Vector3(1.0, 0.25, 0.16), Vector3.ZERO],
		["Pylon", Vector3(0.13, 1.0, 0.13), Vector3(-0.5, 0, 0)],
		["Pylon", Vector3(0.13, 1.0, 0.13), Vector3(0.5, 0, 0)]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material: Material
	for part in pieces:
		var sc := Bake.load_model(SOURCE + "iron_fence.glb#" + part[0])
		var mesh := Bake.bake(sc, {})
		sc.free()
		var bb := mesh.get_aabb()
		var scale: Vector3 = part[1] / bb.size
		st.append_from(mesh, 0, Transform3D(Basis().scaled(scale), part[2]))
		material = mesh.surface_get_material(0)
	st.set_material(material)
	(material as BaseMaterial3D).disable_receive_shadows = true
	st.index()
	_save(Bake.with_lods(st.commit()), "iron_fence")
	quit()


func _save(mesh: ArrayMesh, name: String) -> void:
	var err := ResourceSaver.save(mesh, "res://assets/props/" + name + ".res", ResourceSaver.FLAG_COMPRESS)
	assert(err == OK, "Could not save " + name)
	print("FENCE BAKED: ", name, " ", mesh.get_aabb())
