extends SceneTree
## Bakes the Codex's head from Quaternius's *Animated Robot* (CC0; the OBJ copied to psx/quaternius_robot/, see
## CREDITS.md) into assets/ui/codex/:
##   codex_head.res   the head's shell (surface 0, recoloured light blue) and its trim band (surface 1)
##   codex_eyes.res   both eyes, so they can blink
##   codex_brow_l.res / codex_brow_r.res   each eyebrow, centred on its own middle so it can tilt and lift
##     (its place on the head is the mesh's "pivot" metadata)
##   godot --headless --path . --script res://tools/import_codex_head.gd
##
## Only the head is used. It is scaled so it is 1.0 wide, centred on x/z and on its own height, facing +z (the pack's
## own way round). Every vertex carries its colour and a planar UV (x, y across the face), so the Codex's material
## (scripts/ui/codex_head.gdshader) paints it with a soft gradient texture rather than a bare flat colour.

const SRC := "res://psx/quaternius_robot/Robot.obj"
const OUT := "res://assets/ui/codex/"
## The pack's yellow becomes this light blue (the user's direction, 2026-11-14); its grey trim becomes off-white.
const SHELL := Color("#8ccdf0")
const TRIM := Color("#eef2f4")
const INK := Color("#1d2430")


func _init() -> void:
	var verts := PackedVector3Array()
	var faces := {}  # material -> [[i, i, i...], ...] of the head only
	var obj := ""
	var mat := ""
	for line in FileAccess.get_file_as_string(SRC).split("\n"):
		var t := line.strip_edges().split(" ", false)
		if t.is_empty():
			continue
		match t[0]:
			"v":
				verts.append(Vector3(float(t[1]), float(t[2]), float(t[3])))
			"o":
				obj = t[1]
			"usemtl":
				mat = t[1]
			"f":
				if obj == "Head_Cylinder":
					var f := []
					for k in range(1, t.size()):
						f.append(int(t[k].split("/")[0]) - 1)
					if not faces.has(mat):
						faces[mat] = []
					faces[mat].append(f)
	# the head's bounds: it is rescaled to 1.0 wide, centred
	var box := AABB()
	var first := true
	for m in faces:
		for f in faces[m]:
			for i in f:
				if first:
					box = AABB(verts[i], Vector3.ZERO)
					first = false
				else:
					box = box.expand(verts[i])
	var centre := box.get_center()
	var s := 1.0 / box.size.x
	var tf := func(p: Vector3) -> Vector3: return (p - centre) * s
	# the black parts: two big eyes and two small brows (the small pieces, highest on the face)
	var parts := _components(faces["Black"])
	parts.sort_custom(func(a, b): return a.size() > b.size())
	var eyes: Array = parts[0] + parts[1]
	var brows: Array = [parts[2], parts[3]]
	# left brow (the character's own left, at +x since it faces +z) first
	brows.sort_custom(func(a, b): return _mid(a, verts).x > _mid(b, verts).x)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var head := ArrayMesh.new()
	_add(head, faces["Main"], verts, tf, SHELL, Vector3.ZERO)
	_add(head, faces["Grey"], verts, tf, TRIM, Vector3.ZERO)
	ResourceSaver.save(head, OUT + "codex_head.res")
	var eye_mesh := ArrayMesh.new()
	_add(eye_mesh, eyes, verts, tf, INK, Vector3.ZERO)
	ResourceSaver.save(eye_mesh, OUT + "codex_eyes.res")
	for k in 2:
		var pivot: Vector3 = tf.call(_mid(brows[k], verts))
		var brow := ArrayMesh.new()
		_add(brow, brows[k], verts, tf, INK, pivot)
		brow.set_meta("pivot", pivot)
		ResourceSaver.save(brow, OUT + ("codex_brow_l.res" if k == 0 else "codex_brow_r.res"))
	print("codex head: %d shell, %d trim, %d eye, %d+%d brow faces; %s" % [faces["Main"].size(), faces["Grey"].size(),
		eyes.size(), brows[0].size(), brows[1].size(), box.size * s])
	quit()


## Faces grouped into pieces that share vertices.
func _components(fs: Array) -> Array:
	var parent := {}
	var find := func(a: int, me: Callable) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for f in fs:
		for i in f:
			if not parent.has(i):
				parent[i] = i
	for f in fs:
		for k in range(1, f.size()):
			parent[find.call(f[k], find)] = find.call(f[0], find)
	var groups := {}
	for f in fs:
		var r: int = find.call(f[0], find)
		if not groups.has(r):
			groups[r] = []
		groups[r].append(f)
	return groups.values()


func _mid(fs: Array, verts: PackedVector3Array) -> Vector3:
	var b := AABB(verts[fs[0][0]], Vector3.ZERO)
	for f in fs:
		for i in f:
			b = b.expand(verts[i])
	return b.get_center()


## Faces as one flat-shaded surface, moved so `origin` is at the mesh's own origin.
func _add(mesh: ArrayMesh, fs: Array, verts: PackedVector3Array, tf: Callable, col: Color, origin: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in fs:
		var p := []
		for i in f:
			p.append(tf.call(verts[i]))
		var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		for k in range(1, p.size() - 1):
			for q in [p[0], p[k], p[k + 1]]:
				st.set_color(col)
				st.set_normal(n)
				# planar UV across the face: the gradient texture runs light at the top to soft shade below
				st.set_uv(Vector2(q.x + 0.5, 0.5 - q.y))
				st.add_vertex(q - origin)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
