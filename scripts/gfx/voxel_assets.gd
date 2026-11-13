extends RefCounted
## Loads the scenery models listed in voxel_manifest.gd (baked by the tools/import_psx_*.gd importers).

const Manifest = preload("res://scripts/data/voxel_manifest.gd")

static var _meshes := {}


static func has(name: String) -> bool:
	return Manifest.ASSETS.has(name) or PROCEDURAL.has(name)


static func names_with(prefix: String) -> Array:
	var out := []
	for k in Manifest.ASSETS:
		if String(k).begins_with(prefix):
			out.append(k)
	return out


## Models drawn in code rather than loaded (nothing in the packs fits): name -> [builder, variant].
const PROCEDURAL := {"cactus_1": ["cactus", 0], "cactus_2": ["cactus", 1], "cactus_3": ["cactus", 2], "head_totem": ["totem", 0]}


## The model's mesh (with the materials it was baked with).
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if PROCEDURAL.has(name):
		var VP = load("res://scripts/gfx/voxel_props.gd")
		var p: Array = PROCEDURAL[name]
		_meshes[name] = VP.call(p[0], p[1])
		return _meshes[name]
	var path: String = Manifest.ASSETS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("voxel asset missing: " + name)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.5, 0.5)
		_meshes[name] = bm
		return bm
	var m: Mesh = _recentered(load(path))
	if FOLIAGE.any(func(prefix: String) -> bool: return name.begins_with(prefix)):
		_leafy(m)
	_meshes[name] = m
	return m


## The plants: their leaves wear the painted leaf texture, each plant a shade of its own (foliage.gdshader).
const FOLIAGE := ["tree_", "palm", "shrub_", "bush_", "grass_leaf_"]
const FoliageShader = preload("res://scripts/gfx/foliage.gdshader")
const LEAVES := "res://assets/textures/surfaces/foliage.png"
static var _two_sided: Shader = null


## The foliage shader drawn from both sides: one shared Shader object, so the title's Compatibility precompile
## (shader_precompile.gd) and the plants compile and keep the same program.
static func two_sided_foliage() -> Shader:
	if _two_sided == null:
		_two_sided = Shader.new()
		_two_sided.code = FoliageShader.code.replace("render_mode cull_back;", "render_mode cull_disabled;")
	return _two_sided


## Swap a plant's palette materials for the foliage shader, keeping each one's palette and whether it shows both sides.
static func _leafy(m: Mesh) -> void:
	if not ResourceLoader.exists(LEAVES):
		return
	for si in m.get_surface_count():
		var src := m.surface_get_material(si) as BaseMaterial3D
		if src == null or src.albedo_texture == null or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var mat := ShaderMaterial.new()
		mat.resource_name = "foliage"
		mat.shader = FoliageShader
		if src.cull_mode == BaseMaterial3D.CULL_DISABLED:
			mat.shader = two_sided_foliage()
		mat.set_shader_parameter("atlas", src.albedo_texture)
		mat.set_shader_parameter("leaves", load(LEAVES))
		m.surface_set_material(si, mat)


## Many pack models sit far from their origin. Re-centre them: X/Z centred, standing on y = 0.
static func _recentered(m: Mesh) -> Mesh:
	var bb := m.get_aabb()
	var off := Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	if off.length() < 0.01 or not (m is ArrayMesh):
		return m
	var src: ArrayMesh = m
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] -= off
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(src.surface_get_primitive_type(si), arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	return out


static func aabb(name: String) -> AABB:
	return mesh(name).get_aabb()


## The pack lamp's glass has its own atlas swatch. Split those existing triangles so the panes glow,
## leaving the ironwork dark. Shared by every lit street lamp; no new geometry, textures or shadow casters.
static func street_lamp(lit: bool) -> Mesh:
	if not lit:
		return mesh("lamp")
	if _meshes.has("lamp_lit"):
		return _meshes["lamp_lit"]
	var source := mesh("lamp")
	var out := ArrayMesh.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#ffe2a0")
	glass.emission_enabled = true
	glass.emission = Color("#ffd090")
	glass.emission_energy_multiplier = 2.0
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var iron := PackedInt32Array()
		var panes := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			var pane := true
			for j in 3:
				pane = pane and uv[indices[i + j]].x > 0.788 and uv[indices[i + j]].x < 0.794
			for j in 3:
				if pane:
					panes.append(indices[i + j])
				else:
					iron.append(indices[i + j])
		for part in [iron, panes]:
			if part.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = part
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var si := out.get_surface_count() - 1
			out.surface_set_name(si, "lit_glass" if part == panes else "iron")
			out.surface_set_material(si, glass if part == panes else source.surface_get_material(surface))
	_meshes["lamp_lit"] = out
	return out


## Uniform scale that makes the model `height` tall, or `width` wide (largest of X/Z).
static func fit_scale(name: String, height := -1.0, width := -1.0) -> float:
	var bb := aabb(name)
	if height > 0.0 and bb.size.y > 0.001:
		return height / bb.size.y
	if width > 0.0:
		return width / maxf(0.001, maxf(bb.size.x, bb.size.z))
	return 1.0


## A MeshInstance3D scaled so its footprint fits inside a w x d rectangle.
static func instance_footprint(name: String, w: float, d: float) -> MeshInstance3D:
	var bb := aabb(name)
	var s := minf(w / maxf(0.001, bb.size.x), d / maxf(0.001, bb.size.z))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(name)
	mi.scale = Vector3(s, s, s)
	mi.position.y = -bb.position.y * s
	return mi


## A MeshInstance3D standing on y=0, scaled to fit.
static func instance(name: String, height := -1.0, width := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(name)
	var s := fit_scale(name, height, width)
	mi.scale = Vector3(s, s, s)
	mi.position.y = -aabb(name).position.y * s
	return mi
