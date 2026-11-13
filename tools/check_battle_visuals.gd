extends SceneTree
## Solid arrow topology and complete, imported biome mural assets. Gameplay/input checks remain in battle-focus.
const Arrow = preload("res://scripts/battle/target_arrow.gd")
const Backdrop = preload("res://scripts/battle/backdrop.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Director = preload("res://scripts/battle/battle_camera.gd")
var bad := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func _initialize() -> void:
	for targets in [[Vector3(-5, 1, -7)], [Vector3(0, 0.7, 0)],
		[Vector3(-3, 0.8, -5), Vector3(0, 1.2, -7), Vector3(3, 1, -5)], [Vector3(0.01, 1, 0.01)]]:
		_arrow(Arrow.build(Vector3(0, 1, 0), targets))
	var material := Arrow.material()
	_check(is_equal_approx(material.get_shader_parameter("opacity"), Arrow.OPACITY), "yellow arrow retains its translucency")
	var yellow: Vector3 = material.get_shader_parameter("yellow")
	_check(Color(yellow.x, yellow.y, yellow.z) == Arrow.YELLOW, "arrow stays yellow in every gem")
	var wall := Backdrop.mesh()
	_check(wall == Backdrop.mesh(), "surround geometry is cached between encounters")
	_check(Backdrop.PROFILE[0].x > Director.OUTDOOR_CAMERA_RADIUS + 1.0, "every directed outdoor camera is inside the surround")
	var arrays := wall.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for row in Backdrop.PROFILE.size():
		_check(vertices[row * (Backdrop.SEGMENTS + 1)].distance_to(vertices[(row + 1) * (Backdrop.SEGMENTS + 1) - 1]) < 0.0001,
			"mural row %d closes around the whole stage" % row)
	for id in WorldDB.BIOMES:
		var path := Backdrop.DIR + String(id) + ".png"
		var texture: Texture2D = load(path)
		_check(texture != null and texture.get_width() == 1024 and texture.get_height() == 512, id + " has baked mural artwork")
		if texture != null:
			_check(texture.get_image().has_mipmaps(), id + " artwork has mipmaps")
	print("BATTLE VISUALS DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)


func _arrow(mesh: ArrayMesh) -> void:
	_check(mesh.get_surface_count() == 1, "arrow uses one solid mesh surface")
	if mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(uvs.size() == vertices.size(), "all arrow faces have pattern coordinates")
	var forward := true
	# Each ring has four pairs, with distance increasing toward the target.
	for i in range(8, (Arrow.STEPS + 1) * 8, 8):
		forward = forward and uvs[i].y > uvs[i - 8].y
	_check(forward, "stem pattern runs from attacker to target")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var edges := {}
	var welded := {}
	var finite := true
	var whole := true
	for v in vertices:
		finite = finite and v.is_finite()
	for normal in normals:
		finite = finite and normal.is_finite() and normal.length() > 0.9
	for i in range(0, indices.size(), 3):
		var tri := [indices[i], indices[i + 1], indices[i + 2]]
		var ab: Vector3 = vertices[tri[1]] - vertices[tri[0]]
		var ac: Vector3 = vertices[tri[2]] - vertices[tri[0]]
		whole = whole and ab.cross(ac).length_squared() > ab.length_squared() * ac.length_squared() * 0.00000001
		for j in 3:
			# Hard-edged faces have their own vertices, so edges are matched by position.
			var a: int = _weld(welded, vertices[tri[j]])
			var b: int = _weld(welded, vertices[tri[(j + 1) % 3]])
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = int(edges.get(key, 0)) + 1
	_check(finite and whole, "curved arrow has finite normals and no degenerate fans")
	_check(edges.values().all(func(count): return count == 2), "every arrow edge is sealed by exactly two faces")


func _weld(welded: Dictionary, at: Vector3) -> int:
	if not welded.has(at):
		welded[at] = welded.size()
	return int(welded[at])
