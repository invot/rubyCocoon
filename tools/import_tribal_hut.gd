extends SceneTree
## Bake the supplied tropical hut; prepare build/hut_source using tools/prepare_tribal_hut.py first.
## Then run tools/smooth_textures.gd -- --only=res://assets/exteriors/tribal_hut and --import.
const OUT := "res://assets/exteriors/tribal_hut.res"

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/hut_source/mesh.json"))
	var image := Image.load_from_file("res://build/hut_source/Color.png")
	var alpha := Image.load_from_file("res://build/hut_source/Alpha.png")
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var col := image.get_pixel(x, y)
			col.a = 1.0 - alpha.get_pixel(x, y).r
			image.set_pixel(x, y, col)
	var timber := image.get_region(Rect2i(1810, 650, 190, 470))
	timber.resize(128, 256, Image.INTERPOLATE_LANCZOS)
	timber.generate_mipmaps()
	ResourceSaver.save(ImageTexture.create_from_image(timber), "res://assets/exteriors/tribal_hut_wood.res", ResourceSaver.FLAG_COMPRESS)
	image.resize(768, 768, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var mesh := ArrayMesh.new()
	for roof in [false, true]:
		var material := StandardMaterial3D.new()
		material.resource_name = "roof" if roof else "body"
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.roughness = 0.95
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if roof:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.5
			material.albedo_color = Color("#eddbc1")
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material)
		for triangle in data["roof"].size():
			if data["roof"][triangle] != roof:
				continue
			for corner in [0, 2, 1]:
				var i: int = triangle * 3 + corner
				var p: Array = data["v"][i]
				var uv: Array = data["uv"][i]
				var n: Array = data["n"][i]
				# Centre the front door, floor y=0, and keep source dimensions as metadata-scaled coordinates.
				st.set_normal(Vector3(n[0], n[1], n[2]))
				st.set_uv(Vector2(uv[0], 1.0 - uv[1]))
				st.add_vertex(Vector3((p[0] + 0.6173) / 200.0, p[1], (p[2] - 196.27645) / 200.0))
		st.index()
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, material.resource_name)
	ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	print("TRIBAL HUT BAKED: ", data["roof"].size(), " triangles")
	quit()
