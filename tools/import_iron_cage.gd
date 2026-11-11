extends SceneTree
## Bakes the iron cage Gearhart keeps his captives in (the prologue's freight room, scripts/story/opening.gd) from
## psx/iron_cage/rustbound_iron_cage.glb (see CREDITS.md) into assets/props/iron_cage.res:
##   godot --headless --path . --script res://tools/import_iron_cage.gd
##   godot --headless --path . --script res://tools/smooth_textures.gd
##   godot --headless --path . --import
##
## The model comes as a base and 36 separate bars sharing one rusted-metal material. They are merged into one mesh
## standing on y = 0, centred on x/z, 2 units square and 2.15 tall; only its colour texture is kept (512 px, smooth
## sampling), without the normal and metal maps, so it sits with the game's flat painted look.

const SRC := "res://psx/iron_cage/rustbound_iron_cage.glb"
const OUT := "res://assets/props/iron_cage.res"


func _init() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC), state)
	if err != OK:
		push_error("could not read %s (%d)" % [SRC, err])
		quit(1)
		return
	var root := doc.generate_scene(state)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour: Image = null
	var parts := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var at: Node = mi
		while at != null and at is Node3D:
			xf = (at as Node3D).transform * xf
			at = at.get_parent()
		for s in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, s, xf)
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if colour == null and mat != null and mat.albedo_texture != null:
				colour = mat.albedo_texture.get_image()
		parts += 1
	var arrays := st.commit_to_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bb := AABB(v[0], Vector3.ZERO)
	for p in v:
		bb = bb.expand(p)
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for i in v.size():
		v[i] -= off
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_TEX_UV2] = null
	var material := StandardMaterial3D.new()
	if colour != null:
		if colour.is_compressed():
			colour.decompress()
		colour.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		colour.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(colour)
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	root.free()
	print("IRON CAGE BAKED: %d parts, %d triangles, %s" % [parts, (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, bb.size])
	quit()
