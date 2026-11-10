extends RefCounted
## Shared supplied fence sections, joined at corners and junctions and batched by the world.
const VA = preload("res://scripts/gfx/voxel_assets.gd")
static var _meshes := {}


static func tile(style: String, mask: int) -> ArrayMesh:
	var key := "%s:%d" % [style, mask]
	if _meshes.has(key):
		return _meshes[key]
	var source: Mesh = VA.mesh(style)
	var arms := mask
	if arms in [0, 1, 2]:
		arms = 3
	elif arms in [4, 8]:
		arms = 12
	var directions := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if arms in [3, 12]:
		st.append_from(source, 0, Transform3D(Basis(Vector3.UP, 0 if arms == 3 else PI / 2), Vector3.ZERO))
	else:
		# Half-length sections meet at the centre, so bends never leave diagonal gaps.
		for i in 4:
			if arms & (1 << i):
				var yaw: float = [PI, 0.0, PI / 2, -PI / 2][i]
				st.append_from(source, 0, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.5, 1, 0.5)), directions[i] * 0.25))
	st.set_material(source.surface_get_material(0))
	st.index()
	_meshes[key] = st.commit()
	return _meshes[key]
