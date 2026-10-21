extends RefCounted
## Reads one of the townfolk collection's OBJ pieces (new models/townfolk collection, see import_townfolk.gd; or of
## another pack laid out the same way, from `dir`):
## positions (the pack's centimetres), UVs into its swatch texture, and triangles. Returns
## {"v": PackedVector3Array, "uv": PackedVector2Array, "n": PackedVector3Array (normals), "tri": PackedInt32Array
## (3 per triangle: [vert, uv] pairs flattened as v0, t0, v1, t1, v2, t2), "ntri": PackedInt32Array (each corner's
## normal)}, or {} if there's no such piece. The OBJ winds its triangles counter-clockwise (Godot's front faces wind
## clockwise), and its pieces face +z.

const DIR := "res://new models/townfolk collection/"


static func read(n: int, dir := DIR) -> Dictionary:
	var f := FileAccess.open(dir + "model_%d.obj" % n, FileAccess.READ)
	if f == null:
		return {}
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var tri := PackedInt32Array()
	var nrm := PackedVector3Array()
	var ntri := PackedInt32Array()
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.split(" ", false)
			v.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("vt "):
			var p := line.split(" ", false)
			uv.append(Vector2(float(p[1]), float(p[2])))
		elif line.begins_with("vn "):
			var p := line.split(" ", false)
			nrm.append(Vector3(float(p[1]), float(p[2]), float(p[3])))
		elif line.begins_with("f "):
			var p := line.split(" ", false)
			var c := []
			for i in range(1, p.size()):
				var q := p[i].split("/")
				c.append([int(q[0]) - 1, (int(q[1]) - 1) if q.size() > 1 and q[1] != "" else -1,
					(int(q[2]) - 1) if q.size() > 2 and q[2] != "" else -1])
			for i in range(1, c.size() - 1):
				for k in [c[0], c[i], c[i + 1]]:
					tri.append(k[0])
					tri.append(k[1])
					ntri.append(k[2])
	return {"v": v, "uv": uv, "n": nrm, "tri": tri, "ntri": ntri}
