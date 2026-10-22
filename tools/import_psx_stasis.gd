extends SceneTree
## Bakes the Beast Center's healing machine, the stasis chamber in psx/stasis_chamber.glb (see CREDITS.md), into
## assets/psx/interior/stasis_chamber.res:
##   godot --headless --path . --script res://tools/import_psx_stasis.gd
##
## PS1-style: each part cut down to a fraction of its triangles, the normal and metal maps left off, the textures shrunk
## to 128 px and sampled sharp. The glass tube is its own surface, named "glass", with a texture of its own cut from the
## pack's atlas (so its hex pattern stays crisp at 128 px), so the game can light it up while it heals (world.gd).

const B = preload("res://tools/psx_bake.gd")
const SRC := "res://psx/stasis_chamber.glb"
const OUT := "res://assets/psx/interior/stasis_chamber.res"
## game units per pack unit: a little taller than the townsfolk (1.77)
const SCALE := 1.05
## the share of each part's triangles kept: the coiled pipes and the clamps round the top are the fussiest
const KEEP := {"Tube_low": 0.12, "Hooks_low": 0.1, "Lights_low": 0.25}
const KEEP_DEFAULT := 0.5
const GLASS := "Container_low"


func _init() -> void:
	var sc := B.load_model(ProjectSettings.globalize_path(SRC))
	if sc == null:
		push_error("could not load " + SRC)
		quit(1)
		return
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var src_mat: BaseMaterial3D = null
	var glass_uv := Rect2()
	var bb := AABB()
	var first := true
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var b := B.xf_to(mi as MeshInstance3D, sc) * (mi as MeshInstance3D).mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	var xf := Transform3D(Basis().scaled(Vector3.ONE * SCALE), Vector3.ZERO) \
		* Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z))
	var full := 0
	var kept := 0
	for mi in sc.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var part := String(inst.get_parent().name)
		src_mat = inst.get_active_material(0) as BaseMaterial3D
		var arrays := _cut(inst.mesh.surface_get_arrays(0), float(KEEP.get(part, KEEP_DEFAULT)))
		full += (inst.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		kept += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if part == GLASS:
			glass_uv = _uv_box(arrays[Mesh.ARRAY_TEX_UV])
			glass.append_from(m, 0, xf * B.xf_to(inst, sc))
		else:
			body.append_from(m, 0, xf * B.xf_to(inst, sc))
	sc.free()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.commit_to_arrays())
	mesh.surface_set_material(0, _material(src_mat, Rect2(0, 0, 1, 1)))
	mesh.surface_set_name(0, "body")
	# the tube's own corner of the atlas, its UVs moved to match
	var ga := glass.commit_to_arrays()
	var uv: PackedVector2Array = ga[Mesh.ARRAY_TEX_UV]
	for i in uv.size():
		uv[i] = (uv[i] - glass_uv.position) / glass_uv.size
	ga[Mesh.ARRAY_TEX_UV] = uv
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ga)
	mesh.surface_set_material(1, _material(src_mat, glass_uv))
	mesh.surface_set_name(1, "glass")
	var err := ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	print("  %s  %d -> %d tris  %s  %s" % [OUT, full, kept, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	quit()


## A part's triangles cut down to about `keep` of them (its UV seams kept).
func _cut(arrays: Array, keep: float) -> Array:
	var im := ImporterMesh.new()
	for a in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1]:
		arrays[a] = null
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var full: PackedInt32Array = im.get_surface_arrays(0)[Mesh.ARRAY_INDEX]
	var pick := full
	for l in im.get_surface_lod_count(0):
		pick = im.get_surface_lod_indices(0, l)
		if pick.size() <= full.size() * keep:
			break
	var out := im.get_surface_arrays(0)
	out[Mesh.ARRAY_INDEX] = pick
	return out


static func _uv_box(uv: PackedVector2Array) -> Rect2:
	var r := Rect2(uv[0], Vector2.ZERO)
	for p in uv:
		r = r.expand(p)
	return r


## The pack's material made plain: its colours and glow, `region` of the atlas only, shrunk to 128 px and sampled sharp.
func _material(src: BaseMaterial3D, region: Rect2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.5
	m.metallic_specular = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_texture = _tex(src.albedo_texture, region)
	m.emission_enabled = true
	m.emission = Color.BLACK
	m.emission_texture = _tex(src.emission_texture, region)
	return m


static func _tex(t: Texture2D, region: Rect2) -> ImageTexture:
	var img := t.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var px := Rect2i(Vector2i(region.position * Vector2(img.get_size())), Vector2i((region.size * Vector2(img.get_size())).ceil()))
	img = img.get_region(px.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.resize(mini(128, img.get_width()), mini(128, img.get_height()), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
