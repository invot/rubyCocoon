extends Node3D
## The Temple of Tides' moving water, in a room of several levels (a room's "water_levels", [[flag, y], ...]: the water
## stands at the first y whose flag isn't set yet, and is gone once they all are): a sheet over every tile lower than it,
## the waterfalls of a water puzzle (tide_puzzles.gd) on their spots, and the drain when a puzzle is solved.

const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")
const TidePuzzles = preload("res://scripts/data/tide_puzzles.gd")
const BRONZE := Color("#b08840")
const FALL_RADIUS := 0.44
const DRAIN_SECS := 2.6
## The back wall's face (walls stand 0.2 thick in the middle of their tile), and where a fall on it starts.
const WALL_FACE := 0.6
const WALL_FALL_TOP := 2.5
const WALL_FALL_WIDE := 1.14
## How long the stretch of path a fall runs across takes to sink to the pool's floor (as the fall starts) or rise (once
## it has stopped).
const SINK_SECS := 0.7
const RISE_SECS := 1.1

var map: Dictionary
var walls: RefCounted = null
var level := NAN
var _sheet: MeshInstance3D
var _front: MeshInstance3D
var _falls := {}
var _bottom := 0.0


func build(m: Dictionary, water: ShaderMaterial, flags: Dictionary, room_walls: RefCounted) -> void:
	map = m
	walls = room_walls
	level = _water_level(flags)
	_bottom = 0.0
	if not is_nan(level):
		_build_sheet(water)
	if String(map.get("puzzle", "")) != "":
		var running: Array = TidePuzzles.running(String(map["puzzle"]), flags)
		for p: Vector2i in map["fall_spots"]:
			var on: bool = String(map["fall_spots"][p]) in running
			if map["lattices"].has(p):
				_build_fall(p, water, on)
			else:
				_build_wall_fall(p, water, on)


func _water_level(flags: Dictionary) -> float:
	for lv: Array in map["room"].get("water_levels", []):
		if not flags.get(String(lv[0]), false):
			return float(lv[1])
	return NAN


## True if tile p's floor lies under a water level at y (front row: the half tile of floor before the open edge).
func _under(p: Vector2i, y: float) -> bool:
	var c := MapGen.get_t(map, p.x, p.y)
	if p.y == int(map["h"]) - 1:
		return not c in [MapGen.IVOID, MapGen.IDIAG_A, MapGen.IDIAG_B] and _under(p + Vector2i.UP, y)
	if c in [MapGen.IWALL, MapGen.IWINDOW, MapGen.IDOOR, MapGen.LOCKED, MapGen.IVOID]:
		return false
	if c in [MapGen.IDIAG_A, MapGen.IDIAG_B]:
		return true
	# (a lattice is open to the water below it, and so is the shaft of a path that sinks under a fall)
	return Elev.surface(map, p) < y or map["lattices"].has(p) or RoomBuilder.sunk_tile(map, p)


func _build_sheet(water: ShaderMaterial) -> void:
	# (no highlights: the room's many lamps would each leave a white patch on it)
	water.set_shader_parameter("spec", 0.0)
	var verts := PackedVector3Array()
	var front := PackedVector3Array()
	var w: int = map["w"]
	var h: int = map["h"]
	var y := level
	_bottom = y
	for z in h:
		for x in w:
			var p := Vector2i(x, z)
			if not _under(p, y):
				continue
			_bottom = minf(_bottom, Elev.surface(map, p))
			var c := MapGen.get_t(map, x, z)
			if c in [MapGen.IDIAG_A, MapGen.IDIAG_B]:
				var a := Vector3(x, y, z)
				var b := Vector3(x + 1, y, z)
				var e := Vector3(x + 1, y, z + 1)
				var d := Vector3(x, y, z + 1)
				# the half of a diagonal tile on the room's side of the wall
				if c == MapGen.IDIAG_A:
					verts.append_array([b, e, d] if _inside(x, z, Vector2i(1, 0)) else [a, b, d])
				else:
					verts.append_array([a, e, d] if _inside(x, z, Vector2i(-1, 0)) else [a, b, e])
				continue
			var far := z + 1.0 if z < h - 1 else z + 0.5
			verts.append_array([Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, far), Vector3(x, y, z), Vector3(x + 1, y, far), Vector3(x, y, far)])
			if z == h - 1:
				var low := Elev.surface(map, p)
				front.append_array([Vector3(x, low, far), Vector3(x + 1, low, far), Vector3(x + 1, y, far), Vector3(x, low, far), Vector3(x + 1, y, far), Vector3(x, y, far)])
	_sheet = _mesh_of(verts, Vector3.UP, water)
	if not front.is_empty():
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.16, 0.56, 0.74, 0.82)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.roughness = 0.2
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_front = _mesh_of(front, Vector3.BACK, fm)


func _inside(x: int, z: int, d: Vector2i) -> bool:
	var q := Vector2i(x + d.x, z + d.y)
	return q.x >= 0 and q.x < int(map["w"]) and MapGen.get_t(map, q.x, q.y) != MapGen.IVOID


func _mesh_of(verts: PackedVector3Array, normal: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


## A flat rectangle of `mat` at height y.
func _flat(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y: float, mat: Material) -> void:
	_mesh_of(PackedVector3Array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]), Vector3.UP, mat, parent)


## A copy of the room's water for a fall: flat parts of it drifting by `drift` (negative z: towards the room's front).
func _fall_water(water: ShaderMaterial, opacity: float, drift: Vector2) -> ShaderMaterial:
	var mat: ShaderMaterial = water.duplicate()
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("fall_swell", true)
	mat.set_shader_parameter("fall_rim", true)
	mat.set_shader_parameter("drift", drift)
	return mat


## A white patch of foam, an oval flat on the water.
func _foam(parent: Node3D, at: Vector3, wide: float, deep: float) -> MeshInstance3D:
	var foam := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	disc.radial_segments = 16
	disc.rings = 1
	foam.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.94, 0.98, 1.0, 0.72)
	foam.material_override = fm
	foam.position = at
	foam.scale = Vector3(wide, 1.0, deep)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(foam)
	return foam


## A waterfall down the back wall above spot p, the tile of the path it crosses: from a bronze outlet high on the wall
## into the basin at the wall's foot, which lies open to the pool through the gap where that stretch of the path has sunk
## under the water. When the fall stops the path rises back up out of the water (show_running); the outlet stays.
func _build_wall_fall(p: Vector2i, water: ShaderMaterial, on: bool) -> void:
	var cx := p.x + 0.5
	var front := float(p.y)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = BRONZE
	bronze.roughness = 0.45
	var root := Node3D.new()
	root.position = Vector3(cx, WALL_FALL_TOP, WALL_FACE)
	add_child(root)
	_box(root, Vector3(0, 0.03, 0.16), Vector3(WALL_FALL_WIDE + 0.2, 0.14, 0.32), bronze)
	_box(root, Vector3(0, 0.14, 0.05), Vector3(WALL_FALL_WIDE + 0.46, 0.1, 0.12), bronze)
	var stream := Node3D.new()
	root.add_child(stream)
	var down := _fall_water(water, 0.92, Vector2(0.0, -1.2))
	down.set_shader_parameter("fall_stretch", 4.5)
	down.set_shader_parameter("froth", 0.62)
	# (it lands in its basin, sunk to the pool's floor and full of the pool's own water, level and seamless with the rest:
	# room_builder.gd sunk_basin; or on the dry floor once the room has drained)
	var pool_y := level if not is_nan(level) else -0.12
	var land_y := pool_y if not is_nan(level) else _lowest_floor()
	# (z out from the wall, y down from the outlet: a sheet hugging the wall, curving out as it lands)
	var low := land_y - WALL_FALL_TOP
	var profile: Array[Vector2] = [Vector2(0.3, -0.04), Vector2(0.2, -0.5), Vector2(0.15, -1.5), Vector2(0.17, low + 0.34), Vector2(0.3, low + 0.1), Vector2(0.56, low)]
	_ribbon(stream, profile, WALL_FALL_WIDE / 2.0, down)
	var foot := _foam(self, Vector3(cx, land_y + 0.03, WALL_FACE + 0.6), 1.5, 0.62)
	var slab := _path_slab(p, pool_y)
	slab.position.y = _sunk_by(p, pool_y) if on else 0.0
	stream.scale.y = 1.0 if on else 0.001
	stream.visible = on
	foot.visible = on
	_falls[String(map["fall_spots"][p])] = {"stream": stream, "foam": foot, "on": on, "drop": WALL_FALL_TOP - land_y,
		"slab": slab, "sunk": _sunk_by(p, pool_y), "ripple": Vector3(cx, pool_y + 0.03, front + 0.5)}


## How far the stretch of path on tile p drops: down to the pool's floor (the room's lowest), so the water over it is
## as deep as the rest of the pool and looks the same.
func _sunk_by(p: Vector2i, _pool_y: float) -> float:
	return _lowest_floor() - Elev.surface(map, p)


func _lowest_floor() -> float:
	var low := INF
	for z in int(map["h"]):
		for x in int(map["w"]):
			low = minf(low, Elev.surface(map, Vector2i(x, z)))
	return low


## The stretch of path on tile p that sinks under a fall: a block of the path's own floor and stone, filling the shaft
## the room leaves for it (room_builder.gd rising_path) from the path's level down to the room's lowest floor, with the
## pale coping along its front edge like the rest of the path's.
func _path_slab(p: Vector2i, pool_y: float) -> Node3D:
	var slab := Node3D.new()
	add_child(slab)
	var top := Elev.surface(map, p)
	var low := minf(_lowest_floor(), pool_y)
	var x0 := p.x + 0.005
	var x1 := p.x + 0.995
	var z0 := p.y + 0.005
	var z1 := p.y + 0.995
	var stone: Color = walls.stone if walls != null else Color("#b8b0a0")
	var floor_mat: Material = walls.floor_mat(walls.zone(p.x, p.y)) if walls != null else RoomBuilder.floor_surface("floor_ancient")
	var face := RoomBuilder.surface("drop", stone.darkened(0.2))
	var coping := RoomBuilder.surface("coping", stone.lightened(0.14))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for v: Vector3 in [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)
	var top_mesh := MeshInstance3D.new()
	top_mesh.mesh = st.commit()
	top_mesh.material_override = floor_mat
	slab.add_child(top_mesh)
	# its sides, sliding past the shaft's stone (the room's drops) as it moves
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(x0, z1), Vector2(x1, z1), Vector2(x1, z0), Vector2(x0, z0)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := Vector3(a.y - b.y, 0, b.x - a.x).normalized()
		var along := absf(b.x - a.x) + absf(b.y - a.y)
		# (wound clockwise seen from outside)
		for q: Array in [[a, low, 0.0], [b, top, along], [b, low, along], [a, low, 0.0], [a, top, 0.0], [b, top, along]]:
			var at: Vector2 = q[0]
			sides.set_normal(n)
			sides.set_uv(Vector2(float(q[2]), top - float(q[1])))
			sides.add_vertex(Vector3(at.x, float(q[1]), at.y))
	var side_mesh := MeshInstance3D.new()
	side_mesh.mesh = sides.commit()
	side_mesh.material_override = face
	slab.add_child(side_mesh)
	var lip := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.98, 0.05, 0.1)
	lip.mesh = lb
	lip.material_override = coping
	lip.position = Vector3(p.x + 0.5, top + 0.02, p.y + 0.97)
	slab.add_child(lip)
	for mi in slab.get_children():
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return slab


## A strip of water `half` to either side, its middle line following `profile` ((z, y) points below the parent).
func _ribbon(parent: Node3D, profile: Array[Vector2], half: float, mat: Material) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		var n := Vector3(0, b.x - a.x, a.y - b.y).normalized()
		var quad := [Vector3(-half, a.y, a.x), Vector3(half, a.y, a.x), Vector3(half, b.y, b.x), Vector3(-half, a.y, a.x), Vector3(half, b.y, b.x), Vector3(-half, b.y, b.x)]
		for v: Vector3 in quad:
			verts.append(v)
			normals.append(n)
			uvs.append(Vector2(2.0, profile[0].y - v.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## One waterfall on a lattice, spot p: a column of water from the ceiling's outlet down through it to the pool, foam
## where it lands.
func _build_fall(p: Vector2i, water: ShaderMaterial, on: bool) -> void:
	var top := RoomBuilder.H + 0.1
	var bottom := level if not is_nan(level) else Elev.surface(map, p)
	var root := Node3D.new()
	root.position = Vector3(p.x + 0.5, top, p.y + 0.5)
	add_child(root)
	var spout := StandardMaterial3D.new()
	spout.albedo_color = BRONZE
	spout.roughness = 0.45
	var stream := Node3D.new()
	root.add_child(stream)
	# the ceiling's outlet, only over a lattice with water falling through it: it stays put while the last of the water
	# runs out below it, and goes once the fall has stopped (show_running)
	var outlet := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = FALL_RADIUS * 0.95
	ring.bottom_radius = FALL_RADIUS * 0.95
	ring.height = 0.05
	ring.radial_segments = 14
	ring.rings = 1
	outlet.mesh = ring
	outlet.material_override = spout
	outlet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outlet)
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = FALL_RADIUS * 0.82
	cyl.bottom_radius = FALL_RADIUS
	cyl.height = top - bottom
	cyl.radial_segments = 14
	cyl.rings = 1
	column.mesh = cyl
	var mat: ShaderMaterial = water.duplicate()
	mat.set_shader_parameter("opacity", 0.72)
	column.material_override = mat
	column.position.y = -(top - bottom) / 2.0
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.add_child(column)
	# (never faded out in front of you like other tall things: a vanishing fall would look like it had stopped)
	var foam := _foam(root, Vector3(0, -(top - bottom) + 0.03, 0), 1.24, 1.24)
	stream.scale.y = 1.0 if on else 0.001
	stream.visible = on
	foam.visible = on
	outlet.visible = on
	_falls[String(map["fall_spots"][p])] = {"stream": stream, "foam": foam, "on": on, "drop": top - bottom, "outlet": outlet}


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


## Turns the falls to those on the spots in `running` (some starting, some stopping).
func show_running(running: Array) -> void:
	for spot: String in _falls:
		var f: Dictionary = _falls[spot]
		var on: bool = spot in running
		if on == bool(f["on"]):
			continue
		f["on"] = on
		var stream: Node3D = f["stream"]
		var foam: Node3D = f["foam"]
		var tw := create_tween()
		if on:
			stream.visible = true
			if f.has("outlet"):
				(f["outlet"] as Node3D).visible = true
			tw.tween_property(stream, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: foam.visible = true)
		else:
			foam.visible = false
			# (it stops at the top, and the last of it runs out at the bottom)
			var drop: float = f["drop"]
			tw.tween_method(func(s: float) -> void:
				stream.scale.y = s
				stream.position.y = -drop * (1.0 - s), 1.0, 0.001, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				stream.visible = false
				if f.has("outlet"):
					(f["outlet"] as Node3D).visible = false
				stream.position.y = 0.0)
		if f.has("slab"):
			_move_slab(f, on)


## The stretch of path under a wall fall: it sinks under the pool as the water arrives, and rises back up out of it once
## the fall has run dry, a ring of foam spreading where it breaks the surface.
func _move_slab(f: Dictionary, on: bool) -> void:
	var slab: Node3D = f["slab"]
	var tw := create_tween()
	if on:
		tw.tween_property(slab, "position:y", float(f["sunk"]), SINK_SECS).set_delay(0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	tw.tween_property(slab, "position:y", 0.0, RISE_SECS).set_delay(0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ring := _foam(self, f["ripple"], 0.9, 0.9)
	ring.visible = false
	var mat: StandardMaterial3D = ring.material_override
	var spread := create_tween()
	spread.tween_interval(0.45 + RISE_SECS * 0.45)
	spread.tween_callback(func() -> void: ring.visible = true)
	spread.tween_property(ring, "scale", Vector3(1.7, 1.0, 1.5), 0.8).set_ease(Tween.EASE_OUT)
	spread.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
	spread.tween_callback(ring.queue_free)


## The water sinks to the bottom of the room and is gone.
func drain() -> void:
	if _sheet == null:
		return
	var tw := create_tween()
	tw.tween_property(_sheet, "position:y", _bottom - level, DRAIN_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _front != null:
		# (the water's front edge, where the room is open to the camera, comes down with it)
		var low := _bottom
		var front := _front
		tw.parallel().tween_method(func(s: float) -> void:
			front.scale.y = maxf(s, 0.001)
			front.position.y = low * (1.0 - front.scale.y), 1.0, 0.0, DRAIN_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_sheet.visible = false
	if _front != null:
		_front.visible = false
	level = NAN
