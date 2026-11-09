extends RefCounted
## Town buildings seen from outside (AGENTS.md, "Building exteriors"), every building of every town and its scenery
## houses, built as the world builds them:
##   godot --headless --path . -- --scene=exteriors [--town=caccoon] [--verbose=1]
## - Sealed: from points the building encloses (walled on all four sides and roofed), a line towards anywhere the
##   gameplay camera can look from must meet an opaque face of the building turned towards that camera. One-sided
##   faces seen from behind are culled, and see-through ones (alpha, cut-outs) hide nothing, so neither counts; the
##   house pack's rooms behind its walls ("inside") don't either. A miss is a hole, an open doorway, a window with no
##   pane, or a gap at a corner, a roof's edge or between pieces.
## - Doors: every door anyone uses is a full-size door (at least DOOR_MIN tall, well over the hero's head) whose leaf
##   lies in its wall: no further in front of the wall beside it than DOOR_PROUD.

const WorldDB = preload("res://scripts/data/world_db.gd")
const HouseModels = preload("res://scripts/gfx/house_models.gd")
const VoxelPerson = preload("res://scripts/gfx/voxel_person.gd")

## the hero is 1.44 tall: a door this tall clears their head with room to spare (house_models.gd DOOR_H is 1.8)
const DOOR_MIN := 1.7
const DOOR_PROUD := 0.12
## the collision layers the audit's own copies of the buildings use (nothing else in the world is on them)
const ALL := 1 << 18
const SHELL := 1 << 19
## where the gameplay camera can be from a point: world.gd CAM_OFFSET is 7 up and 11 south of whoever it follows,
## who may stand to either side of the point or further south
const VIEW_X := [-8.0, -4.0, 0.0, 4.0, 8.0]
const VIEW_Z := [11.0, 16.0]
const REACH := 14.0

var bad := 0
var verbose := false
var show_at := []
var _front_sign := 1.0


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	verbose = opts.has("verbose")
	_front_sign = _winding()
	var towns: Array = [String(opts["town"])] if opts.has("town") else WorldDB.TOWN_ORDER
	var counted := 0
	for town in towns:
		await main._go(town, "start")
		var world = main.world
		for npc in world.npcs.values():
			if npc.get("kind", "") == "trainer":
				npc["manual_only"] = true
		world.set_process(false)
		for f in world.building_fades:
			world._load_building(f)
			world._set_building_opacity(f, 1.0)
			(f["node"] as Node3D).show()
		var bodies := []
		for f in world.building_fades:
			bodies.append(_body(world, f["node"]))
		await main.get_tree().physics_frame
		await main.get_tree().physics_frame
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		for i in world.building_fades.size():
			var f: Dictionary = world.building_fades[i]
			var body: Dictionary = bodies[i]
			# only this building: the others' copies leave the space while it's measured
			for j in bodies.size():
				for part in [[ALL, "all"], [SHELL, "shell"]]:
					var sb = bodies[j].get(part[1])
					if sb != null:
						(sb as StaticBody3D).collision_layer = part[0] if j == i else 0
			await main.get_tree().physics_frame
			var b: Dictionary = f["b"]
			var label := "%s %s (%d,%d)" % [town, String(b.get("name", b.get("shop", "?"))), int(b["x"]), int(b["y"])]
			# (which pack house or kit model it is)
			var model := String((b.get("house_plan", f.get("plan", {})) as Dictionary).get("key", b.get("cove_model", "")))
			if model != "":
				label += " [%s]" % model
			var leak = _sealed(space, world, b, body, label)
			if not f.get("scenery", false) and String(b.get("shop", "")) != "decor":
				_door(space, world, b, body, label)
			# --show=<part of a building's name>: a windowed run ends looking at its first leak (or at its door from
			# the side), for --shot
			if opts.has("show") and show_at.is_empty() and label.contains(String(opts["show"])):
				var door := Vector3(float(b["door"].x) + 0.5, world._lift(b["door"]) + 1.0, float(b["y"]) + float(b["d"]))
				show_at = leak if leak != null else [door + Vector3(2.2, 0.8, 2.2), door]
			counted += 1
		for body in bodies:
			for part in ["all", "shell"]:
				if body.get(part) != null:
					(body[part] as Node).queue_free()
		if not show_at.is_empty():
			world.cam_free = true
			world.cam.position = show_at[0]
			world.cam.look_at(show_at[1], Vector3.UP)
			await main.get_tree().create_timer(0.5).timeout
	UI.auto = false
	print("EXTERIORS DONE: %d building(s), %d problem(s)" % [counted, bad])


## Godot draws a triangle's front where its corners run clockwise; which way the cross product of its edges points
## then, measured on a box (whose faces all face out).
func _winding() -> float:
	var arr := BoxMesh.new().surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var out := 0
	for t in range(0, (idx as PackedInt32Array).size(), 3):
		var a: Vector3 = vs[idx[t]]
		var n := (vs[idx[t + 1]] - a).cross(vs[idx[t + 2]] - a)
		out += 1 if n.dot((a + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0) > 0.0 else -1
	return 1.0 if out > 0 else -1.0


## A static copy of a building's opaque faces for the rays: "all" (everything that hides what's behind it) and "shell"
## (without the house pack's rooms behind the walls), with each face's outward normal and whether it's drawn from
## both sides.
func _body(world: Node3D, node: Node3D) -> Dictionary:
	var all := PackedVector3Array()
	var shell := PackedVector3Array()
	var normals := PackedVector3Array()
	var both := PackedByteArray()
	# which mesh surface each shell face came from (a door's leaf, a door piece's leaf and frame)
	var parts := PackedInt32Array()
	var part := 0
	for gi in node.find_children("*", "MeshInstance3D", true, false):
		var mi := gi as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf := mi.global_transform
		var mirrored := xf.basis.determinant() < 0.0
		for s in mi.mesh.get_surface_count():
			part += 1
			var mat := mi.get_active_material(s)
			if _see_through(mat):
				continue
			var inside := mat != null and String(mat.resource_name) == "inside"
			var two := _two_sided(mat)
			var flip := mirrored != _culls_front(mat)
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or (idx as PackedInt32Array).is_empty():
				idx = PackedInt32Array(range(vs.size()))
			for t in range(0, (idx as PackedInt32Array).size() - 2, 3):
				var a: Vector3 = xf * vs[idx[t]]
				var b: Vector3 = xf * vs[idx[t + 1]]
				var c: Vector3 = xf * vs[idx[t + 2]]
				all.append_array([a, b, c])
				if inside:
					continue
				shell.append_array([a, b, c])
				var n := (b - a).cross(c - a) * _front_sign
				normals.append(-n if flip else n)
				both.append(1 if two else 0)
				parts.append(part)
	var out := {"normals": normals, "both": both, "faces": shell, "parts": parts}
	for face_set in [[all, "all"], [shell, "shell"]]:
		var faces: PackedVector3Array = face_set[0]
		if faces.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		body.add_child(cs)
		world.add_child(body)
		out[face_set[1]] = body
	return out


static func _see_through(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		var m := mat as BaseMaterial3D
		return m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.albedo_color.a < 0.99
	if mat is ShaderMaterial:
		var sh := (mat as ShaderMaterial).shader
		return sh != null and (sh.code.contains("ALPHA =") or sh.code.contains("ALPHA="))
	return false


static func _two_sided(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	if mat is ShaderMaterial:
		var sh := (mat as ShaderMaterial).shader
		return sh != null and sh.code.contains("cull_disabled")
	return false


static func _culls_front(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_FRONT
	return false


## The first hit along from -> to on `mask`, or {}.
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.hit_back_faces = true
	q.hit_from_inside = false
	return space.intersect_ray(q)


## Does anything of the building's shell, drawn towards someone looking back along `dir`, lie between `from` and
## `REACH` away? Returns the distance to it, or -1.
func _blocked(space: PhysicsDirectSpaceState3D, body: Dictionary, from: Vector3, dir: Vector3, reach := REACH) -> float:
	var at := from
	var gone := 0.0
	for k in 48:
		var hit := _ray(space, at, from + dir * reach, SHELL)
		if hit.is_empty():
			return -1.0
		var fi := int(hit.get("face_index", -1))
		var p: Vector3 = hit["position"]
		gone = (p - from).length()
		if fi >= 0 and fi < (body["normals"] as PackedVector3Array).size():
			if (body["both"] as PackedByteArray)[fi] == 1 or (body["normals"] as PackedVector3Array)[fi].dot(dir) > 0.0:
				return gone
		at = p + dir * 0.003
	return gone


## Returns the first leak as [where the camera would be, the point inside it sees], or null.
func _sealed(space: PhysicsDirectSpaceState3D, world, b: Dictionary, body: Dictionary, label: String):
	var floor_y: float = world._lift(b["door"])
	var top := float(b.get("height", 3.0))
	var x0 := float(b["x"])
	var z0 := float(b["y"])
	var leaks := []
	var enclosed := 0
	# (the grid and the views are set a little off round numbers, so no line runs exactly along the seam between two
	# wall pieces, which a ray can slip through but nobody sees)
	var h := 0.511
	while h <= minf(top - 0.3, 9.0):
		var x := x0 + 0.263
		while x < x0 + float(b["w"]):
			var z := z0 + 0.257
			while z < z0 + float(b["d"]):
				var p := Vector3(x, floor_y + h, z)
				if _enclosed(space, p):
					enclosed += 1
					for vx in VIEW_X:
						for vz in VIEW_Z:
							var view := Vector3(vx + 0.031, 7.0 - h, vz + 0.017)
							if _blocked(space, body, p, view.normalized()) < 0.0:
								leaks.append([p, view])
				z += 0.5
			x += 0.5
		h += 0.6
	if leaks.is_empty():
		if verbose:
			print("ok   %s sealed (%d enclosed points)" % [label, enclosed])
		return null
	bad += 1
	# where the lines get out: the last face they pass (one drawn only from inside), or where they leave the plot
	var spots := {}
	var box := AABB(Vector3(x0, floor_y, z0), Vector3(float(b["w"]), top, float(b["d"])))
	var first_exit := Vector3.INF
	for l in leaks:
		var p: Vector3 = l[0]
		var dir: Vector3 = (l[1] as Vector3).normalized()
		var last := Vector3.INF
		var at := p
		for k in 32:
			var hit := _ray(space, at, p + dir * REACH, ALL)
			if hit.is_empty():
				break
			last = hit["position"]
			at = last + dir * 0.003
		var where := ""
		var exit := p
		if last != Vector3.INF:
			exit = last
			where = "culled face at %s" % last.snappedf(0.25)
		else:
			var out = box.intersects_ray(p + dir * 30.0, -dir)
			exit = out if out != null else p
			where = "opening at %s" % exit.snappedf(0.25)
		if first_exit == Vector3.INF:
			first_exit = exit
		spots[where] = int(spots.get(where, 0)) + 1
	var shown := []
	for where in spots.keys().slice(0, 6):
		shown.append("%s (%d)" % [where, spots[where]])
	print("FAIL %s: the inside shows from outside along %d line(s): %s" % [label, leaks.size(), ", ".join(shown)])
	return [first_exit + (leaks[0][1] as Vector3).normalized() * 2.5, leaks[0][0]]


## Walled in all round (eight ways) and roofed over by the building itself (anything of it, either side, within
## reach), solidly: each way, five lines side by side (a little apart across and up) all meet it, so posts, railings
## and lattice round an open porch, gallery or arcade don't count as walls.
func _enclosed(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3(1, 0, 1), Vector3(1, 0, -1),
			Vector3(-1, 0, 1), Vector3(-1, 0, -1), Vector3.UP]:
		var n: Vector3 = d.normalized()
		var across := n.cross(Vector3.UP).normalized() if absf(n.y) < 0.5 else Vector3.RIGHT
		var up := Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
		for o in [Vector3.ZERO, across * 0.2, -across * 0.2, up * 0.25, -up * 0.25]:
			if _ray(space, p + o, p + o + n * 12.0, ALL).is_empty():
				return false
	return true


## The front door: how tall it stands (the highest the doorway's own part reaches: the leaf, or a door piece's leaf
## and jambs, from the sill up), and how far it stands out from the wall either side of it. A few places on the leaf
## are tried, so a knob, a padlock's straps or a glazed panel don't hide it.
func _door(space: PhysicsDirectSpaceState3D, world, b: Dictionary, body: Dictionary, label: String) -> void:
	var floor_y: float = world._lift(b["door"]) + float(b.get("door_sill", 0.0))
	var dx := float(b["door"].x) + 0.5
	var front := float(b["y"]) + float(b["d"]) + 3.0
	var back := float(b["y"]) - 1.0
	var top := -1.0
	var leaf_z := 0.0
	for sx in [-0.2, 0.0, 0.15]:
		for sy in [0.7, 1.0, 1.5]:
			var hit := _front_hit(space, body, Vector3(dx + sx, floor_y + sy, front), back)
			if hit.is_empty():
				continue
			var z: float = (hit["position"] as Vector3).z
			var t := _part_top(body, int(hit["face"]), (hit["position"] as Vector3).x, z) - floor_y
			if t > top:
				top = t
				leaf_z = z
	if top < 0.0:
		bad += 1
		print("FAIL %s: no door found in front at x %.1f" % [label, dx])
		return
	# the wall either side, from just past a frame out to a door's width away: only faces turned to the street like the
	# door (a round or eight-sided wall turning away beside it, or the tower behind an entrance porch, isn't the wall
	# the door is set in); the lower middle reading, so a slab the door and frame stand out on doesn't count as wall
	var walls := []
	for sx in [-1.0, 1.0]:
		for off in [0.6, 0.75, 0.95, 1.25]:
			for wy in [1.2, 1.6]:
				var hit := _front_hit(space, body, Vector3(dx + sx * off, floor_y + wy, front), back)
				if hit.is_empty() or absf((hit["position"] as Vector3).z - leaf_z) >= 1.0:
					continue
				if absf((body["normals"] as PackedVector3Array)[int(hit["face"])].z) < 0.85:
					continue
				walls.append((hit["position"] as Vector3).z)
	walls.sort()
	var wall_z: float = walls[(walls.size() - 1) / 2] if not walls.is_empty() else leaf_z
	if verbose and leaf_z - wall_z > DOOR_PROUD:
		print("     %s wall readings behind the leaf: %s" % [label, ", ".join(walls.map(func(z): return "%.2f" % (leaf_z - z)))])
	var proud := leaf_z - wall_z
	var line := "%s door %.2f tall, %.2f in front of its wall" % [label, top, proud]
	if top < DOOR_MIN:
		bad += 1
		print("FAIL %s: shorter than %.2f (the hero is %.2f)" % [line, DOOR_MIN, VoxelPerson.height()])
	elif proud > DOOR_PROUD:
		bad += 1
		print("FAIL %s: it floats off the wall" % line)
	elif verbose:
		print("ok   ", line)


## The first face seen looking north (towards -z) from `from`, drawn towards the viewer.
func _front_hit(space: PhysicsDirectSpaceState3D, body: Dictionary, from: Vector3, to_z: float) -> Dictionary:
	var dir := Vector3.FORWARD
	var at := from
	for k in 32:
		var hit := _ray(space, at, Vector3(from.x, from.y, to_z), SHELL)
		if hit.is_empty():
			return {}
		var fi := int(hit.get("face_index", -1))
		if fi >= 0 and fi < (body["normals"] as PackedVector3Array).size():
			if (body["both"] as PackedByteArray)[fi] == 1 or (body["normals"] as PackedVector3Array)[fi].dot(-dir) > 0.0:
				hit["face"] = fi
				return hit
		at = (hit["position"] as Vector3) + dir * 0.003
	return {}


## How high the part face `fi` belongs to reaches in the doorway, within a door's width of x `hx` and near depth `z`,
## counting only its faces that rise from near the sill (a leaf, a jamb; not a lintel, a strap or a sign above).
func _part_top(body: Dictionary, fi: int, hx: float, z: float) -> float:
	var parts: PackedInt32Array = body["parts"]
	var faces: PackedVector3Array = body["faces"]
	var part := parts[fi]
	if not body.has("tris"):
		# each part's faces, and how low it reaches
		var tris := {}
		var lows := {}
		for i in parts.size():
			if not tris.has(parts[i]):
				tris[parts[i]] = []
				lows[parts[i]] = INF
			(tris[parts[i]] as Array).append(i)
			lows[parts[i]] = minf(lows[parts[i]], minf(faces[i * 3].y, minf(faces[i * 3 + 1].y, faces[i * 3 + 2].y)))
		body["tris"] = tris
		body["lows"] = lows
	var low: float = body["lows"][part]
	var top := -INF
	for i in (body["tris"][part] as Array):
		var a := faces[i * 3]
		var b := faces[i * 3 + 1]
		var c := faces[i * 3 + 2]
		var lo := minf(a.y, minf(b.y, c.y))
		if lo > low + 0.7 or minf(a.x, minf(b.x, c.x)) < hx - 1.0 or maxf(a.x, maxf(b.x, c.x)) > hx + 1.0 \
				or absf((a.z + b.z + c.z) / 3.0 - z) > 0.15:
			continue
		top = maxf(top, maxf(a.y, maxf(b.y, c.y)))
	return top
