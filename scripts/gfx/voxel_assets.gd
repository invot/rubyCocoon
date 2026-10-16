extends RefCounted
## Loads the converted voxel models listed in voxel_manifest.gd (see tools/import_voxel_assets.py).

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
const PROCEDURAL := {"cactus_1": ["cactus", 0], "cactus_2": ["cactus", 1], "cactus_3": ["cactus", 2]}


## The model's mesh with its palette material set to sharp (nearest) sampling.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if PROCEDURAL.has(name):
		var VP = load("res://scripts/gfx/voxel_props.gd")
		var p: Array = PROCEDURAL[name]
		_meshes[name] = VP.call(p[0], p[1])
		return _meshes[name]
	var path: String = Manifest.ASSETS.get(name, "")
	# the most detailed trees have a half-resolution version (tools/voxel_lod.py): a quarter of the triangles,
	# and from the game's camera you can't tell them apart
	var light := path.trim_suffix(".obj") + "_lo.obj"
	if path != "" and ResourceLoader.exists(light):
		path = light
	if path == "" or not ResourceLoader.exists(path):
		push_warning("voxel asset missing: " + name)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.5, 0.5)
		_meshes[name] = bm
		return bm
	var m: Mesh = _recentered(load(path))
	# PSX models (assets/psx/models) come with their own materials; the voxel OBJs get sharp palette sampling
	for s in (m.get_surface_count() if path.ends_with(".obj") else 0):
		var mat = m.surface_get_material(s)
		if mat is BaseMaterial3D:
			var nm: BaseMaterial3D = mat.duplicate()
			nm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			nm.roughness = 1.0
			nm.metallic_specular = 0.2
			m.surface_set_material(s, nm)
	_meshes[name] = m
	return m


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
