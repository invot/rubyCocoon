extends SceneTree
## Bakes assets/interiors/side_table.res: a boxy little chest of three drawers, the table the red telephone stands on
## (room_builder.gd's "phone"). The furniture pack has no such piece, so it is made of boxes here, in the pack's own
## manner (see import_psx_furniture.gd): the shared wood and plain materials, colours in the vertices over the
## box-mapped grain, darkening towards the floor; centred on x/z, standing on y = 0, facing +z with its back to -z.
##   godot --headless --path . --script res://tools/make_side_table.gd

const OUT := "res://assets/interiors/side_table.res"
## one repeat of the grain, in game units (as import_psx_furniture.gd)
const WOOD_REPEAT := 0.6
const BODY := Color("#a8683c")
const FRONTS := Color("#c98f55")
const PLINTH := Color("#7a4e30")
const KNOB := Color("#d8b04a")
## the drawers, bottom to top: [from y, to y], deepest at the bottom
const DRAWERS := [[0.10, 0.28], [0.30, 0.46], [0.48, 0.61]]

var _part := 0


func _init() -> void:
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plain := SurfaceTool.new()
	plain.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a recessed plinth, the carcass, and a top overhanging it a little at the front and sides
	_box(wood, Vector3(-0.31, 0.0, -0.22), Vector3(0.31, 0.07, 0.2), PLINTH)
	_box(wood, Vector3(-0.34, 0.07, -0.25), Vector3(0.34, 0.65, 0.23), BODY)
	_box(wood, Vector3(-0.37, 0.65, -0.26), Vector3(0.37, 0.7, 0.27), BODY.lightened(0.05))
	for d in DRAWERS:
		var lo := float(d[0])
		var hi := float(d[1])
		_box(wood, Vector3(-0.305, lo, 0.23), Vector3(0.305, hi, 0.245), FRONTS)
		_knob(plain, Vector3(0.0, (lo + hi) / 2.0, 0.245))
	var mesh := ArrayMesh.new()
	for pair in [[wood, "wood"], [plain, "plain"]]:
		var st: SurfaceTool = pair[0]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, load("res://assets/interiors/furniture_%s.res" % pair[1]))
	var err := ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	print("  side_table  %s  %s" % [mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	quit()


## A box from `a` to `b` (its bottom left out: nothing sees under it), one part with its own slight shade.
func _box(st: SurfaceTool, a: Vector3, b: Vector3, c: Color) -> void:
	var shade := _shade()
	var x := [a.x, b.x]
	var y := [a.y, b.y]
	var z := [a.z, b.z]
	for axis in 3:
		for side in 2:
			if axis == 1 and side == 0:
				continue
			var n := Vector3.ZERO
			n[axis] = 1.0 if side == 1 else -1.0
			var corners := []
			for i in 4:
				var u := 1 if i == 1 or i == 2 else 0
				var v := 1 if i >= 2 else 0
				var p := Vector3.ZERO
				p[axis] = [x, y, z][axis][side]
				p[(axis + 1) % 3] = [x, y, z][(axis + 1) % 3][u]
				p[(axis + 2) % 3] = [x, y, z][(axis + 2) % 3][v]
				corners.append(p)
			_quad(st, corners, n, c, shade)


## A round brass knob on a drawer's face, sticking out along +z.
func _knob(st: SurfaceTool, at: Vector3) -> void:
	var shade := _shade()
	var r := 0.024
	var out := 0.028
	var rim := []
	for i in 8:
		var ang := TAU * (i + 0.5) / 8.0
		rim.append(Vector2(cos(ang), sin(ang)) * r)
	for i in 8:
		var p: Vector2 = rim[i]
		var q: Vector2 = rim[(i + 1) % 8]
		var n := Vector3((p + q).x, (p + q).y, 0.0).normalized()
		_quad(st, [at + Vector3(p.x, p.y, 0), at + Vector3(q.x, q.y, 0), at + Vector3(q.x, q.y, out),
			at + Vector3(p.x, p.y, out)], n, KNOB, shade)
		_tri(st, [at + Vector3(0, 0, out), at + Vector3(p.x, p.y, out), at + Vector3(q.x, q.y, out)], Vector3.BACK, KNOB, shade)


func _quad(st: SurfaceTool, p: Array, n: Vector3, c: Color, shade: float) -> void:
	_tri(st, [p[0], p[1], p[2]], n, c, shade)
	_tri(st, [p[0], p[2], p[3]], n, c, shade)


## One triangle, wound clockwise seen from its front (Godot's front faces), box-mapped onto the grain.
func _tri(st: SurfaceTool, p: Array, n: Vector3, c: Color, shade: float) -> void:
	if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(n) > 0.0:
		p = [p[0], p[2], p[1]]
	var fn := n.abs()
	for v: Vector3 in p:
		var uv := Vector2(v.x, v.y) if fn.z >= fn.x and fn.z >= fn.y else (Vector2(v.z, v.y) if fn.x >= fn.y else Vector2(v.x, v.z))
		var f := shade * lerpf(0.72, 1.0, clampf(v.y / 0.25, 0.0, 1.0))
		st.set_color(Color(c.r * f, c.g * f, c.b * f))
		st.set_normal(n)
		st.set_uv(uv / WOOD_REPEAT)
		st.add_vertex(v)


## Each part a shade lighter or darker than the next, as the pack's pieces are.
func _shade() -> float:
	_part += 1
	return 1.0 + (float((_part * 7919) % 13) / 12.0 - 0.5) * 0.08
