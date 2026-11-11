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
## The water standing in a basin and running across the path: above the pale coping along the path's edge.
const BASIN_Y := 0.07
const RUN_Y := 0.06

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
	# (a lattice is open to the water below it)
	return Elev.surface(map, p) < y or map["lattices"].has(p)


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
## into the basin at the wall's foot, then out through the basin's open front, across the path and over its edge into the
## pool. The basin, the outlet and the dark wet channel it runs in stay when the water stops.
func _build_wall_fall(p: Vector2i, water: ShaderMaterial, on: bool) -> void:
	var cx := p.x + 0.5
	var front := float(p.y)
	var stone: Color = walls.stone if walls != null else Color("#b8b0a0")
	var curb := StandardMaterial3D.new()
	curb.albedo_color = stone.lightened(0.12)
	curb.roughness = 0.85
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = BRONZE
	bronze.roughness = 0.45
	var wet_stone := StandardMaterial3D.new()
	wet_stone.albedo_color = Color(0.1, 0.24, 0.32, 0.42)
	wet_stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet_stone.roughness = 0.5
	_flat(self, cx - 1.36, cx + 1.36, WALL_FACE, front, 0.015, wet_stone)
	_flat(self, cx - 0.5, cx + 0.5, front, front + 0.92, 0.015, wet_stone)
	# the basin's curb, open at the middle of its front
	var mid_z := (WALL_FACE + front) / 2.0
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(cx + side * 1.43, 0.08, mid_z), Vector3(0.14, 0.16, front - WALL_FACE), curb)
		_box(self, Vector3(cx + side, 0.08, front - 0.07), Vector3(1.0, 0.16, 0.14), curb)
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
	# (z out from the wall, y down from the outlet: a sheet hugging the wall, curving out as it lands)
	var low := BASIN_Y - WALL_FALL_TOP
	var profile: Array[Vector2] = [Vector2(0.3, -0.04), Vector2(0.2, -0.5), Vector2(0.15, -1.5), Vector2(0.17, low + 0.34), Vector2(0.3, low + 0.1), Vector2(0.56, low)]
	_ribbon(stream, profile, WALL_FALL_WIDE / 2.0, down)
	var foot := _foam(self, Vector3(cx, BASIN_Y + 0.03, WALL_FACE + 0.6), 1.5, 0.62)
	# what it does once it has landed, fading in and out with it
	var wet := Node3D.new()
	add_child(wet)
	var pool_y := level if not is_nan(level) else -0.12
	var basin_water := _fall_water(water, 0.8, Vector2(0.03, -0.1))
	var run := _fall_water(water, 0.84, Vector2(0.0, -1.5))
	_flat(wet, cx - 1.36, cx + 1.36, WALL_FACE, front, BASIN_Y, basin_water)
	_flat(wet, cx - 0.5, cx + 0.5, front - 0.14, front + 1.04, RUN_Y, run)
	_mesh_of(PackedVector3Array([Vector3(cx - 0.5, pool_y, front + 1.04), Vector3(cx + 0.5, pool_y, front + 1.04), Vector3(cx + 0.5, RUN_Y, front + 1.04),
		Vector3(cx - 0.5, pool_y, front + 1.04), Vector3(cx + 0.5, RUN_Y, front + 1.04), Vector3(cx - 0.5, RUN_Y, front + 1.04)]), Vector3.BACK, run, wet)
	_foam(wet, Vector3(cx, pool_y + 0.03, front + 1.3), 1.4, 0.56)
	stream.scale.y = 1.0 if on else 0.001
	stream.visible = on
	foot.visible = on
	wet.visible = on
	if not on:
		for mat: ShaderMaterial in [basin_water, run]:
			mat.set_shader_parameter("opacity", 0.0)
	_falls[String(map["fall_spots"][p])] = {"stream": stream, "foam": foot, "on": on, "drop": WALL_FALL_TOP - BASIN_Y, "wet": wet, "fades": [[basin_water, 0.8], [run, 0.84]]}


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
	# the ceiling's outlet, only over a lattice with water falling through it
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
	stream.add_child(outlet)
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
	# (so it never hides you, walking behind it)
	if walls != null:
		walls.add_prop([column], p, Vector2.ONE)
	var foam := _foam(root, Vector3(0, -(top - bottom) + 0.03, 0), 1.24, 1.24)
	stream.scale.y = 1.0 if on else 0.001
	stream.visible = on
	foam.visible = on
	_falls[String(map["fall_spots"][p])] = {"stream": stream, "foam": foam, "on": on, "drop": top - bottom}


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
				stream.position.y = 0.0)
		if f.has("wet"):
			_fade_wet(f, on)


## The water a wall fall spreads after landing: it comes once the fall reaches the floor, and runs away as the fall stops.
func _fade_wet(f: Dictionary, on: bool) -> void:
	var wet: Node3D = f["wet"]
	wet.visible = true
	var tw := create_tween().set_parallel()
	for pair: Array in f["fades"]:
		var mat: ShaderMaterial = pair[0]
		var full: float = pair[1]
		tw.tween_method(func(a: float) -> void: mat.set_shader_parameter("opacity", a), 0.0 if on else full, full if on else 0.0, 0.3).set_delay(0.25 if on else 0.1)
	if not on:
		tw.chain().tween_callback(func() -> void: wet.visible = false)


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
