extends SceneTree
## Bakes the temple guardians' resting poses: assets/summons/<element>_rest.res from assets/summons/<element>.res.
## The summon models come posed in flight and without a skeleton, so each gets a few hand-placed bones (RIGS, in the
## baked model's own space: +z forward, +y up, standing on y = 0). Every vertex is bound to its nearest bones
## (inverse distance to the bone's segment, to the fourth power), each bone is turned to point along its rest
## direction (wings folded back along the flanks, legs tucked, the neck and tail curled round), and the mesh is
## skinned into that pose. The result lies with its belly on y = 0, in the same units as the flying model, so
## voxel_beast.gd summon_mesh can scale it by the flying model's measure and it stays the same size.
## Run:  godot --headless --path . --script res://tools/summon_rest.gd [-- --only=fire]

const DIR := "res://assets/summons/"

## Bones, parents first. a / b: the bone's ends in the flying pose. at: where a root bone's start goes. dir: the
## direction the bone points at rest (its children follow it rigidly where they have no dir of their own).
## len: scale along the bone. squash: [axis, k], a scale across the bone (folding a wing's fan of fingers together).
## side: +1 / -1, only vertices on that side of x = 0 bind to it. ymin: only vertices above this height bind to it.
## reach: bind only vertices within this distance of the bone.
const RIGS := {
	# the sky serpent: coiled up flat, its head resting on top
	"air": {"coil": {"outer": 0.15, "gap": 0.042, "lift": 0.07, "head": 0.16, "y": 0.04, "rise": 0.05, "girth": 1.5}},
	"fire": {"bones": [
		{"n": "body", "a": Vector3(0, 0.22, -0.01), "b": Vector3(0, 0.40, 0.13), "at": Vector3(0, 0.11, -0.10), "dir": Vector3(0, 0.08, 1)},
		{"n": "neck", "p": "body", "a": Vector3(0, 0.40, 0.13), "b": Vector3(0, 0.37, 0.24), "dir": Vector3(0, -0.55, 1)},
		{"n": "head", "p": "neck", "a": Vector3(0, 0.37, 0.24), "b": Vector3(0, 0.31, 0.37), "dir": Vector3(0.12, -0.12, 1)},
		{"n": "tail1", "p": "body", "a": Vector3(0, 0.20, -0.01), "b": Vector3(0, 0.13, -0.12), "dir": Vector3(0.25, -0.05, -1)},
		{"n": "tail2", "p": "tail1", "a": Vector3(0, 0.13, -0.12), "b": Vector3(0, 0.06, -0.24), "dir": Vector3(1, -0.05, -0.35)},
		{"n": "tail3", "p": "tail2", "a": Vector3(0, 0.06, -0.24), "b": Vector3(0, 0.01, -0.37), "dir": Vector3(0.5, 0, 1)},
		{"n": "wingL", "p": "body", "side": 1, "ymin": 0.3, "a": Vector3(0.07, 0.42, 0.08), "b": Vector3(0.40, 0.85, 0.10),
			"dir": Vector3(0.2, 0.18, -1), "len": 0.75, "squash": [Vector3(0, 0, 1), 0.35]},
		{"n": "wingR", "p": "body", "side": -1, "ymin": 0.3, "a": Vector3(-0.07, 0.42, 0.08), "b": Vector3(-0.40, 0.85, 0.10),
			"dir": Vector3(-0.2, 0.18, -1), "len": 0.75, "squash": [Vector3(0, 0, 1), 0.35]},
		{"n": "armL", "p": "body", "side": 1, "reach": 0.08, "a": Vector3(0.05, 0.30, 0.16), "b": Vector3(0.06, 0.11, 0.21), "dir": Vector3(0.1, -0.15, 1)},
		{"n": "armR", "p": "body", "side": -1, "reach": 0.08, "a": Vector3(-0.05, 0.30, 0.16), "b": Vector3(-0.06, 0.11, 0.21), "dir": Vector3(-0.1, -0.15, 1)},
		{"n": "legL", "p": "body", "side": 1, "reach": 0.08, "a": Vector3(0.06, 0.24, 0.03), "b": Vector3(0.07, 0.12, 0.07), "dir": Vector3(0.3, -0.2, 1)},
		{"n": "legR", "p": "body", "side": -1, "reach": 0.08, "a": Vector3(-0.06, 0.24, 0.03), "b": Vector3(-0.07, 0.12, 0.07), "dir": Vector3(-0.3, -0.2, 1)},
	]},
	# standing on all fours with its feathered wings spread flat: it lies down, wings laid back along its sides
	"earth": {"bones": [
		{"n": "body", "a": Vector3(0, 0.10, -0.01), "b": Vector3(0, 0.12, 0.16), "at": Vector3(0, 0.06, -0.01), "dir": Vector3(0, 0.03, 1)},
		{"n": "neck", "p": "body", "a": Vector3(0, 0.12, 0.16), "b": Vector3(0, 0.11, 0.22), "dir": Vector3(0.15, -0.35, 1)},
		{"n": "head", "p": "neck", "a": Vector3(0, 0.11, 0.22), "b": Vector3(0, 0.09, 0.31), "dir": Vector3(0.3, -0.12, 1)},
		{"n": "tail1", "p": "body", "a": Vector3(0, 0.10, -0.01), "b": Vector3(0, 0.09, -0.10), "dir": Vector3(0.4, -0.1, -1)},
		{"n": "tail2", "p": "tail1", "a": Vector3(0, 0.09, -0.10), "b": Vector3(0, 0.08, -0.20), "dir": Vector3(1, -0.05, -0.1)},
		{"n": "tail3", "p": "tail2", "a": Vector3(0, 0.08, -0.20), "b": Vector3(0, 0.08, -0.31), "dir": Vector3(0.45, 0, 1)},
		{"n": "wingL", "p": "body", "side": 1, "a": Vector3(0.06, 0.13, 0.14), "b": Vector3(0.49, 0.13, 0.04),
			"dir": Vector3(0.12, 0.08, -1), "len": 0.7, "squash": [Vector3(0, 0, 1), 0.45]},
		{"n": "wingR", "p": "body", "side": -1, "a": Vector3(-0.06, 0.13, 0.14), "b": Vector3(-0.49, 0.13, 0.04),
			"dir": Vector3(-0.12, 0.08, -1), "len": 0.7, "squash": [Vector3(0, 0, 1), 0.45]},
		{"n": "armL", "p": "body", "side": 1, "reach": 0.05, "a": Vector3(0.04, 0.08, 0.15), "b": Vector3(0.04, 0.0, 0.17), "dir": Vector3(0.05, -0.1, 1)},
		{"n": "armR", "p": "body", "side": -1, "reach": 0.05, "a": Vector3(-0.04, 0.08, 0.15), "b": Vector3(-0.04, 0.0, 0.17), "dir": Vector3(-0.05, -0.1, 1)},
		{"n": "legL", "p": "body", "side": 1, "reach": 0.05, "a": Vector3(0.04, 0.08, 0.02), "b": Vector3(0.04, 0.0, 0.0), "dir": Vector3(0.2, -0.1, 1)},
		{"n": "legR", "p": "body", "side": -1, "reach": 0.05, "a": Vector3(-0.04, 0.08, 0.02), "b": Vector3(-0.04, 0.0, 0.0), "dir": Vector3(-0.2, -0.1, 1)},
	]},
	# rearing upright in the air, wings swept back: it tips forward onto its belly
	"water": {"bones": [
		{"n": "body", "a": Vector3(0, 0.20, 0.13), "b": Vector3(0, 0.38, 0.15), "at": Vector3(0, 0.08, -0.04), "dir": Vector3(0, 0.05, 1)},
		{"n": "neck", "p": "body", "a": Vector3(0, 0.38, 0.15), "b": Vector3(0, 0.48, 0.17), "dir": Vector3(0.1, 0.22, 1)},
		{"n": "head", "p": "neck", "a": Vector3(0, 0.48, 0.17), "b": Vector3(0, 0.45, 0.26), "dir": Vector3(0.3, -0.05, 1)},
		{"n": "tail1", "p": "body", "a": Vector3(0, 0.20, 0.13), "b": Vector3(0, 0.10, 0.13), "dir": Vector3(0.3, -0.1, -1)},
		{"n": "tail2", "p": "tail1", "a": Vector3(0, 0.10, 0.13), "b": Vector3(0, 0.03, 0.19), "dir": Vector3(1, -0.05, -0.3)},
		{"n": "tail3", "p": "tail2", "a": Vector3(0, 0.03, 0.19), "b": Vector3(0, 0.02, 0.0), "dir": Vector3(0.4, 0, 1)},
		{"n": "wingL", "p": "body", "side": 1, "ymin": 0.12, "a": Vector3(0.04, 0.45, 0.10), "b": Vector3(0.45, 0.50, -0.12),
			"dir": Vector3(0.2, -0.2, -1), "len": 0.65, "squash": [Vector3(0.1, 0.87, 0.47), 0.14]},
		{"n": "wingR", "p": "body", "side": -1, "ymin": 0.12, "a": Vector3(-0.04, 0.45, 0.10), "b": Vector3(-0.45, 0.50, -0.12),
			"dir": Vector3(-0.2, -0.2, -1), "len": 0.65, "squash": [Vector3(-0.1, 0.87, 0.47), 0.14]},
		{"n": "armL", "p": "body", "side": 1, "reach": 0.06, "a": Vector3(0.03, 0.36, 0.18), "b": Vector3(0.03, 0.30, 0.26), "dir": Vector3(0.1, -0.15, 1)},
		{"n": "armR", "p": "body", "side": -1, "reach": 0.06, "a": Vector3(-0.03, 0.36, 0.18), "b": Vector3(-0.03, 0.30, 0.26), "dir": Vector3(-0.1, -0.15, 1)},
		{"n": "legL", "p": "body", "side": 1, "reach": 0.06, "a": Vector3(0.04, 0.22, 0.15), "b": Vector3(0.04, 0.18, 0.21), "dir": Vector3(0.2, -0.15, 1)},
		{"n": "legR", "p": "body", "side": -1, "reach": 0.06, "a": Vector3(-0.04, 0.22, 0.15), "b": Vector3(-0.04, 0.18, 0.21), "dir": Vector3(-0.2, -0.15, 1)},
	]},
}

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for el in RIGS:
		if args.has("only") and String(args["only"]) != el:
			continue
		var t0 := Time.get_ticks_msec()
		var out := rest(load(DIR + el + ".res"), RIGS[el])
		var err := ResourceSaver.save(out, DIR + el + "_rest.res", ResourceSaver.FLAG_COMPRESS)
		print("%-6s -> %s (%s) in %.1f s, aabb %s" % [el, DIR + el + "_rest.res", error_string(err), (Time.get_ticks_msec() - t0) / 1000.0, out.get_aabb()])
	quit()


## The rest pose of `base` under `rig`, standing on y = 0.
static func rest(base: ArrayMesh, rig: Dictionary) -> ArrayMesh:
	if rig.has("coil"):
		return _coil(base, rig["coil"])
	var bones: Array = rig["bones"]
	var by_name := {}
	# each bone's pose: a transform taking a flying-pose point bound to it to its rest position
	var poses := []
	for bone in bones:
		var a: Vector3 = bone["a"]
		var d: Vector3 = (Vector3(bone["b"]) - a).normalized()
		var parent_pose := Transform3D.IDENTITY
		if bone.has("p"):
			parent_pose = poses[by_name[bone["p"]]]
		var start: Vector3 = Vector3(bone["at"]) if bone.has("at") else parent_pose * a
		var r := parent_pose.basis.orthonormalized()
		if bone.has("dir"):
			var from := (r * d).normalized()
			var to: Vector3 = Vector3(bone["dir"]).normalized()
			r = _arc(from, to) * r
		# scale in the flying pose's space: along the bone (len) and across it (squash)
		var s := Basis.IDENTITY
		if bone.has("len"):
			s = _axis_scale(d, float(bone["len"])) * s
		if bone.has("squash"):
			var ax: Vector3 = Vector3(bone["squash"][0])
			ax = (ax - d * ax.dot(d)).normalized()
			s = _axis_scale(ax, float(bone["squash"][1])) * s
		var basis := r * s
		poses.append(Transform3D(basis, start - basis * a))
		by_name[bone["n"]] = poses.size() - 1
	return _deform(base, func(v: Vector3) -> Transform3D:
		var w := _weights(v, bones)
		var m := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
		for k in w:
			var pose: Transform3D = poses[k]
			m.basis.x += pose.basis.x * w[k]
			m.basis.y += pose.basis.y * w[k]
			m.basis.z += pose.basis.z * w[k]
			m.origin += pose.origin * w[k]
		return m)


## `base` with every vertex moved by the transform `xform` gives for its old position (normals and tangents turned
## with it), dropped to stand on y = 0.
static func _deform(base: ArrayMesh, xform: Callable) -> ArrayMesh:
	var out := ArrayMesh.new()
	var lowest := INF
	var surfaces := []
	for si in base.get_surface_count():
		var arrays := base.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms = arrays[Mesh.ARRAY_NORMAL]
		var tans = arrays[Mesh.ARRAY_TANGENT]
		for i in verts.size():
			var m: Transform3D = xform.call(verts[i])
			verts[i] = m * verts[i]
			lowest = minf(lowest, verts[i].y)
			if norms != null:
				(norms as PackedVector3Array)[i] = (m.basis.inverse().transposed() * (norms as PackedVector3Array)[i]).normalized()
			if tans != null:
				var ti := i * 4
				var tn := (m.basis * Vector3(tans[ti], tans[ti + 1], tans[ti + 2])).normalized()
				tans[ti] = tn.x
				tans[ti + 1] = tn.y
				tans[ti + 2] = tn.z
		arrays[Mesh.ARRAY_VERTEX] = verts
		if norms != null:
			arrays[Mesh.ARRAY_NORMAL] = norms
		if tans != null:
			arrays[Mesh.ARRAY_TANGENT] = tans
		surfaces.append(arrays)
	for si in surfaces.size():
		var arrays: Array = surfaces[si]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i].y -= lowest
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, base.surface_get_material(si))
	return out


## The sky serpent's rest: its spine (the middle of the body along its length, from the tail at -z to the head at
## +z) laid on a flat spiral, the tail outermost and the head on top in the middle, each part of the body keeping
## its shape round the spine. outer: the spiral's outer radius; gap: how far each turn comes in; rise: how much
## higher each turn in lies; lift: how high the head rises over the last `head` of the spine.
static func _coil(base: ArrayMesh, cfg: Dictionary) -> ArrayMesh:
	# the spine: the middle of each slice along z, smoothed
	var bb := base.get_aabb()
	var bins := 48
	var sums := []
	var counts := []
	for i in bins:
		sums.append(Vector3.ZERO)
		counts.append(0)
	for si in base.get_surface_count():
		for v in (base.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var b := clampi(int((v.z - bb.position.z) / bb.size.z * bins), 0, bins - 1)
			sums[b] += v
			counts[b] += 1
	var raw := []
	for i in bins:
		if counts[i] > 0:
			raw.append(sums[i] / counts[i])
	var spine := []
	for i in raw.size():
		var acc := Vector3.ZERO
		var n := 0
		for j in range(maxi(0, i - 2), mini(raw.size(), i + 3)):
			acc += raw[j]
			n += 1
		spine.append(acc / n)
	var arc := [0.0]
	for i in range(1, spine.size()):
		arc.append(arc[i - 1] + (spine[i] as Vector3).distance_to(spine[i - 1]))
	var total: float = arc[-1]
	# the spiral, walked in small steps from the tail
	var outer: float = cfg.get("outer", 0.2)
	var gap: float = cfg.get("gap", 0.07)
	var lift: float = cfg.get("lift", 0.08)
	var head: float = cfg.get("head", 0.15)
	var y0: float = cfg.get("y", 0.04)
	var rise: float = cfg.get("rise", 0.0)
	# (a slender serpent coiled in a nest reads as a thin hose: its body is drawn this much thicker round its spine)
	var girth: float = cfg.get("girth", 1.0)
	var thick := Transform3D(Basis().scaled(Vector3(girth, girth, 1.0)), Vector3.ZERO)
	var path := []
	var theta := 0.0
	var steps := 400
	for i in steps + 1:
		var s := total * i / steps
		var r := maxf(0.05, outer - gap * theta / TAU)
		# each turn in lies a little higher on the one outside it, heaped up
		var h := y0 + rise * (1.0 - r / outer) / maxf(gap / outer, 0.01) * 0.25 + lift * smoothstep(total - head, total, s)
		path.append(Vector3(cos(theta) * r, h, sin(theta) * r))
		theta += total / steps / r
	return _deform(base, func(v: Vector3) -> Transform3D:
		# where along the spine this point is (its nearest spine segment)
		var best := INF
		var s := 0.0
		for i in range(1, spine.size()):
			var a: Vector3 = spine[i - 1]
			var ab: Vector3 = spine[i] - a
			var t := clampf((v - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := v.distance_squared_to(a + ab * t)
			if d < best:
				best = d
				s = lerpf(arc[i - 1], arc[i], t)
		var src := _frame(spine, arc, s)
		var dst := _frame(path, [], s * steps / total)
		return dst * thick * src.affine_inverse())


## A frame on a polyline at arc length s (or, with no arc table, at fractional index s): x across, y up, z along.
static func _frame(line: Array, arc: Array, s: float) -> Transform3D:
	var i := 1
	var t := 0.0
	if arc.is_empty():
		i = clampi(int(s) + 1, 1, line.size() - 1)
		t = clampf(s - (i - 1), 0.0, 1.0)
	else:
		while i < line.size() - 1 and arc[i] < s:
			i += 1
		t = clampf((s - arc[i - 1]) / maxf(arc[i] - arc[i - 1], 1e-6), 0.0, 1.0)
	var a: Vector3 = line[i - 1]
	var b: Vector3 = line[i]
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z), a.lerp(b, t))


## Bone index -> weight for a flying-pose point: inverse distance to each bone it may bind to, to the fourth power.
static func _weights(v: Vector3, bones: Array) -> Dictionary:
	var w := {}
	var total := 0.0
	for k in bones.size():
		var bone: Dictionary = bones[k]
		if bone.has("side") and signf(v.x) != float(bone["side"]):
			continue
		if bone.has("ymin") and v.y < float(bone["ymin"]):
			continue
		var d := _seg_dist(v, bone["a"], bone["b"])
		if bone.has("reach") and d > float(bone["reach"]):
			continue
		var x := 1.0 / pow(maxf(d, 0.004), 4.0)
		w[k] = x
		total += x
	if w.is_empty():
		return {0: 1.0}
	for k in w:
		w[k] /= total
	return w


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The shortest rotation taking unit vector `from` to unit vector `to`.
static func _arc(from: Vector3, to: Vector3) -> Basis:
	var c := from.cross(to)
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if c.length() < 1e-6:
		return Basis.IDENTITY if dot > 0.0 else Basis(Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT, PI)
	return Basis(c.normalized(), acos(dot))


## A scale by k along unit axis `ax`.
static func _axis_scale(ax: Vector3, k: float) -> Basis:
	var b := Basis.IDENTITY
	for i in 3:
		var e := Vector3.ZERO
		e[i] = 1.0
		b[i] = e + ax * ax.dot(e) * (k - 1.0)
	return b
