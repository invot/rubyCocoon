extends SceneTree
## Diagonal cliff halves must keep the same raised turf and lip joins as the surrounding lawn.
const Terrain = preload("res://scripts/world/terrain_mesh.gd")
const Elev = preload("res://scripts/world/elevation.gd")
var bad := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for code in Terrain.HALF_SIDES:
		for surface in ["grass", "grass_dark", "path", "sand", "bed"]:
			var t := _fixture(code, surface)
			t._prepare_halves()
			t._prepare_corners()
			var pair: Array = t.halves[4]
			for k in 2:
				var half: Dictionary = pair[k]
				var expected := Terrain.LIFT if surface in ["grass", "grass_dark"] else 0.0
				var g := t._half_grid(1, 1, k)
				# Submerged beds have a small shared noise offset; dry ground must match exactly.
				var actual: float = g[4].y - float(half["level"]) - float(half["top"])
				check(absf(actual - expected) <= (0.031 if surface == "bed" else 0.00001),
					"%d %s half %d has the surface's pillow height" % [code, surface, k])
				if expected > 0.0:
					# One side has matching grass. The other is path: its missing lift must not sink the half.
					var d: Vector2i = Terrain.HALF_SIDES[code][k][0]
					var p := Vector2i.ONE + d
					var a := t._side(1, 1, d)
					var b := t._side(p.x, p.y, -d)
					var ai := 4 + d.x + 3 * d.y
					var bi := 4 - d.x - 3 * d.y
					check(a[ai].is_equal_approx(b[bi]), "%d %s half %d joins its lawn without a step" % [code, surface, k])
			var faces: Dictionary = await t._faces(null, 0, [Time.get_ticks_usec()])
			var diagonal: Dictionary = {}
			for batch: Array in faces.values():
				for face: Dictionary in batch:
					if (face["top"][1] as Vector3).is_equal_approx(t._half_grid(1, 1, 0)[4]):
						diagonal = face
			check(not diagonal.is_empty() and diagonal.get("turf", false) == (surface in ["grass", "grass_dark"]),
				"%d %s diagonal lip follows its surface" % [code, surface])
			if surface == "grass":
				# A continuing diagonal has no whole-tile lift flag, even when both its halves are grass.
				var d: Vector2i = Terrain.HALF_SIDES[code][0][0]
				var p := Vector2i.ONE + d
				t.ramp[p.x + p.y * 3] = code
				t.lifted[p.x + p.y * 3] = 0
				t._prepare_halves()
				t._grids.clear()
				check(t.halves[4][0]["lifted"] == 1 and is_equal_approx(t._half_grid(1, 1, 0)[4].y, 1.0 + Terrain.LIFT),
					"%d grass remains raised beside another diagonal" % code)
	print("TERRAIN CHECK DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)

func _fixture(code: int, surface: String) -> Terrain:
	var lo := PackedFloat32Array()
	lo.resize(9)
	var hi := lo.duplicate()
	var dirs := PackedByteArray()
	dirs.resize(9)
	dirs[4] = code
	hi[4] = 1.0
	for d: Vector2i in Terrain.HALF_SIDES[code][0]:
		var p := Vector2i.ONE + d
		lo[p.x + p.y * 3] = 1.0
		hi[p.x + p.y * 3] = 1.0
	var t := Terrain.new()
	t.setup(3, 3, 42, {"elev": {"lo": lo, "hi": hi, "dir": dirs}})
	for z in 3:
		for x in 3:
			t.set_tile(x, z, surface, -0.42 if surface == "bed" else 0.0, false,
				1 if surface == "bed" else 0, surface in ["grass", "grass_dark"] and Vector2i(x, z) != Vector2i.ONE)
	if surface in ["grass", "grass_dark"]:
		for k in 2:
			var d: Vector2i = Terrain.HALF_SIDES[code][k][1]
			var p := Vector2i.ONE + d
			t.set_tile(p.x, p.y, "path", 0.0)
	return t

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok:
		bad += 1
