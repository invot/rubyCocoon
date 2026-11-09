extends SceneTree
## python tools/prepare_kelpwick_arena.py path/to/stylized_house.glb; then this, smoothing, and --import.
func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/arena_source/model.json"))
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://build/arena_source/colour.png"))
	image.resize(768, 768, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for index in data["idx"]:
		var p: Array = data["v"][index]
		var n: Array = data["n"][index]
		var uv: Array = data["uv"][index]
		st.set_normal(Vector3(n[0], n[1], n[2]))
		st.set_uv(Vector2(uv[0], uv[1]))
		st.add_vertex(Vector3(p[0], p[1], p[2]))
	st.index()
	var mesh := st.commit()
	ResourceSaver.save(mesh, "res://assets/exteriors/kelpwick_arena.res", ResourceSaver.FLAG_COMPRESS)
	print("KELPWICK ARENA BAKED: ", data["idx"].size() / 3, " triangles")
	quit()
