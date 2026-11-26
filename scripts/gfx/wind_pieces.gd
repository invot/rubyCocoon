extends Node3D
## Valkoog's wind pieces and the wind itself, drawn (world/air_temple.gd runs them; world/wind_puzzle.gd has the
## rules). Cozy and readable from the room's camera: chunky sandstone, warm bronze, jewel-bright pinwheels, and the
## wind as soft glowing ribbons that run along its path.
##
## One of these sits in each wind room (node "WindPieces"): it keeps the parts that turn (spin()) turning and the
## streams' ribbons (draw_wind()).
const SAND := Color("#d8c49a")
const SAND_DARK := Color("#b89d72")
const BRONZE := Color("#c49a4a")
const BRONZE_DARK := Color("#8a6a34")
const TEAL := Color("#7fe8d0")
const CLAY := Color("#c8764a")
const CLAY_DARK := Color("#9a5636")
## the pinwheels' petals, jewel_pop
const PETALS := [Color("#3fc8b0"), Color("#ff7a6a"), Color("#ffc84a"), Color("#8a7aff")]

## [node, axis (0 x, 1 y, 2 z), turns a second] for each part turning now
var _spinning := {}
var _wind_node: Node3D = null
var _clock := 0.0

static var _mats := {}
static var _stream_shader: Shader = null
static var _curtain_shader: Shader = null


func _process(delta: float) -> void:
	_clock += delta
	for node: Node3D in _spinning.keys():
		if not is_instance_valid(node):
			_spinning.erase(node)
			continue
		var s: Array = _spinning[node]
		match int(s[0]):
			0:
				node.rotation.x += delta * float(s[1])
			1:
				node.rotation.y += delta * float(s[1])
			_:
				node.rotation.z += delta * float(s[1])


## Sets a part turning (`speed` turns a second about `axis`), or stops it with speed 0.
func spin(part: Node3D, axis: int, speed: float) -> void:
	if part == null:
		return
	if is_zero_approx(speed):
		_spinning.erase(part)
	else:
		_spinning[part] = [axis, speed * TAU]


# ---------------------------------------------------------------- materials
static func mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s:%.2f" % [c.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r_top: float, r_bot: float, hgt: float, at: Vector3, m: Material, seg := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = hgt
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, r: float, at: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


## The yaw that turns a piece's front (+z) to face way `d` (wind_puzzle.gd DIRS).
static func yaw(d: String) -> float:
	match d:
		"^":
			return PI
		">":
			return PI / 2.0
		"<":
			return -PI / 2.0
	return 0.0


# ---------------------------------------------------------------- the pieces
## A vent: a squat sandstone block with a round bronze-rimmed mouth breathing out its way, a teal glow deep in it.
static func vent(d: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.rotation.y = yaw(d)
	root.add_child(body)
	_box(body, Vector3(0.86, 0.18, 0.62), Vector3(0, 0.09, -0.06), mat(SAND_DARK))
	_box(body, Vector3(0.78, 0.78, 0.5), Vector3(0, 0.56, -0.1), mat(SAND))
	_box(body, Vector3(0.9, 0.12, 0.6), Vector3(0, 1.0, -0.08), mat(SAND_DARK))
	var rim := _cyl(body, 0.27, 0.27, 0.08, Vector3(0, 0.56, 0.16), mat(BRONZE))
	rim.rotation.x = PI / 2.0
	var mouth := _cyl(body, 0.2, 0.2, 0.1, Vector3(0, 0.56, 0.17), mat(Color("#2a3a3a")))
	mouth.rotation.x = PI / 2.0
	var glow := _cyl(body, 0.13, 0.13, 0.1, Vector3(0, 0.56, 0.19), mat(TEAL, 1.8))
	glow.rotation.x = PI / 2.0
	# a little scarab-and-wind carving over the mouth
	_box(body, Vector3(0.36, 0.06, 0.04), Vector3(0, 0.88, 0.16), mat(TEAL, 0.6))
	return root


## A fan: a bronze ring of blades on a turntable, a pointer on its base showing which way it sends the wind. Its
## "Head" node turns to face its way; its "Blades" spin while wind runs through it.
static func fan(d: String) -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.42, 0.46, 0.16, Vector3(0, 0.08, 0), mat(SAND_DARK), 20)
	_cyl(root, 0.36, 0.38, 0.06, Vector3(0, 0.19, 0), mat(BRONZE_DARK), 20)
	var head := Node3D.new()
	head.name = "Head"
	head.rotation.y = yaw(d)
	root.add_child(head)
	# the pointer on the turntable: a teal arrow
	var arrow := _box(head, Vector3(0.16, 0.03, 0.26), Vector3(0, 0.235, 0.2), mat(TEAL, 1.2))
	arrow.rotation.y = 0.0
	_box(head, Vector3(0.08, 0.7, 0.08), Vector3(0, 0.56, -0.12), mat(BRONZE_DARK))
	# the ring
	var ring := Node3D.new()
	ring.position = Vector3(0, 0.95, 0)
	head.add_child(ring)
	for i in 12:
		var a := TAU * i / 12.0
		var seg := _box(ring, Vector3(0.18, 0.07, 0.1), Vector3(cos(a) * 0.36, sin(a) * 0.36, 0), mat(BRONZE))
		seg.rotation.z = a + PI / 2.0
	var blades := Node3D.new()
	blades.name = "Blades"
	ring.add_child(blades)
	for i in 5:
		var a := TAU * i / 5.0
		var b := _box(blades, Vector3(0.12, 0.3, 0.025), Vector3(cos(a) * 0.17, sin(a) * 0.17, 0), mat(Color("#f2e6c8")))
		b.rotation.z = a - PI / 2.0
		b.rotation.y = 0.35
	_ball(blades, 0.07, Vector3.ZERO, mat(TEAL, 1.0))
	return root


## A sand jar: a big round terracotta jar with a teal band and a sand-coloured lid.
static func jar() -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.2, 0.24, 0.1, Vector3(0, 0.05, 0), mat(CLAY_DARK))
	_ball(root, 0.38, Vector3(0, 0.46, 0), mat(CLAY), 1.05)
	_cyl(root, 0.39, 0.39, 0.09, Vector3(0, 0.52, 0), mat(Color("#3fa898")))
	_cyl(root, 0.17, 0.22, 0.2, Vector3(0, 0.86, 0), mat(CLAY))
	_cyl(root, 0.23, 0.2, 0.07, Vector3(0, 0.98, 0), mat(CLAY_DARK))
	_ball(root, 0.19, Vector3(0, 1.02, 0), mat(SAND), 0.5)
	return root


## A pinwheel: four jewel-bright petals on a tall post. Its "Petals" spin while wind reaches it.
static func pinwheel() -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.24, 0.28, 0.14, Vector3(0, 0.07, 0), mat(SAND_DARK), 14)
	_cyl(root, 0.045, 0.05, 1.3, Vector3(0, 0.75, 0), mat(Color("#f2e6c8")), 8)
	var head := Node3D.new()
	head.position = Vector3(0, 1.42, 0.06)
	# (tipped a little towards the room's camera, so its face shows)
	head.rotation.x = -0.35
	root.add_child(head)
	var petals := Node3D.new()
	petals.name = "Petals"
	head.add_child(petals)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := TAU * i / 4.0
		var out := Vector3(cos(a), sin(a), 0)
		var side := Vector3(-sin(a), cos(a), 0)
		var col: Color = PETALS[i]
		# a curled petal: from the hub out to its tip, folded back towards the next
		var hub := Vector3.ZERO
		var tip := out * 0.46 + side * 0.08 + Vector3(0, 0, 0.06)
		var fold := out * 0.2 + side * 0.3
		for v in [[hub, tip, fold], [hub, fold, tip]]:
			var n := ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[2] as Vector3) - (v[0] as Vector3)).normalized()
			for p in v:
				st.set_color(col)
				st.set_normal(n)
				st.add_vertex(p)
	var pm := MeshInstance3D.new()
	pm.mesh = st.commit()
	var pmat := StandardMaterial3D.new()
	pmat.vertex_color_use_as_albedo = true
	pmat.roughness = 0.7
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.material_override = pmat
	petals.add_child(pm)
	_ball(petals, 0.06, Vector3(0, 0, 0.03), mat(Color("#fff4d8")))
	return root


## A vane: a bowed canvas sail between bronze spars on a mast, on a round stone base, standing on the diagonal ("/"
## or "\\"). Its "Sail" turns when it flips.
static func vane(tilt: String) -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.4, 0.44, 0.18, Vector3(0, 0.09, 0), mat(SAND_DARK), 20)
	_cyl(root, 0.1, 0.12, 0.12, Vector3(0, 0.24, 0), mat(BRONZE_DARK))
	var sail := Node3D.new()
	sail.name = "Sail"
	sail.rotation.y = vane_yaw(tilt)
	root.add_child(sail)
	_cyl(sail, 0.035, 0.04, 1.5, Vector3(0, 1.0, 0), mat(BRONZE_DARK), 8)
	_ball(sail, 0.07, Vector3(0, 1.78, 0), mat(TEAL, 1.0))
	# the canvas in two halves, bowed back a little from the mast, with a teal band across each
	var canvas := mat(Color("#f4ead2"))
	for side in [-1.0, 1.0]:
		var half := Node3D.new()
		half.rotation.y = side * 0.22
		sail.add_child(half)
		_box(half, Vector3(0.46, 1.04, 0.035), Vector3(side * 0.25, 0.98, 0), canvas)
		_box(half, Vector3(0.46, 0.09, 0.045), Vector3(side * 0.25, 1.12, 0), mat(TEAL, 0.5))
		_box(half, Vector3(0.46, 0.05, 0.045), Vector3(side * 0.25, 0.94, 0), mat(TEAL, 0.5))
	_box(sail, Vector3(1.04, 0.05, 0.06), Vector3(0, 1.51, 0.04), mat(BRONZE))
	_box(sail, Vector3(1.04, 0.05, 0.06), Vector3(0, 0.45, 0.04), mat(BRONZE))
	return root


## The sail's yaw for its tilt, as seen from above: "/" runs from the near left to the far right.
static func vane_yaw(tilt: String) -> float:
	return -PI / 4.0 if tilt == "/" else PI / 4.0


## A wind-stone: a faceted teal crystal standing point-up in a carved sandstone cradle, facing the way it will blow.
## Its "Crystal" glows once it wakes; its "Ring" of little shards turns.
static func wind_stone(d: String, awake: bool) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.rotation.y = yaw(d)
	root.add_child(body)
	_box(body, Vector3(0.82, 0.24, 0.82), Vector3(0, 0.12, 0), mat(SAND_DARK))
	_box(body, Vector3(0.6, 0.42, 0.6), Vector3(0, 0.45, 0), mat(SAND))
	_box(body, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.7, 0), mat(SAND_DARK))
	# its mouth: a teal-lit notch on the face it blows from
	_box(body, Vector3(0.22, 0.12, 0.04), Vector3(0, 0.46, 0.31), mat(TEAL, 1.2 if awake else 0.3))
	var crystal := Node3D.new()
	crystal.name = "Crystal"
	crystal.position = Vector3(0, 1.06, 0)
	body.add_child(crystal)
	var gem := mat(Color("#5fd8c0") if awake else Color("#7fa8a0"), 1.4 if awake else 0.1)
	# a long six-sided point above and a short one below: a crystal, never round
	_cyl(crystal, 0.0, 0.2, 0.5, Vector3(0, 0.25, 0), gem, 6)
	_cyl(crystal, 0.2, 0.0, 0.26, Vector3(0, -0.13, 0), gem, 6)
	var ring := Node3D.new()
	ring.name = "Ring"
	ring.position = Vector3(0, 1.06, 0)
	body.add_child(ring)
	for i in 3:
		var a := TAU * i / 3.0
		var shard := _cyl(ring, 0.0, 0.05, 0.14, Vector3(cos(a) * 0.36, 0.08 * sin(a * 2.0), sin(a) * 0.36), mat(TEAL, 1.4 if awake else 0.0), 4)
		shard.rotation.z = 0.3
	return root


## An updraft: a round bronze grate in the floor; when wind reaches it, a column of rising air ("Column").
static func updraft() -> Node3D:
	var root := Node3D.new()
	_cyl(root, 0.46, 0.46, 0.05, Vector3(0, 0.025, 0), mat(BRONZE_DARK), 24)
	_cyl(root, 0.36, 0.36, 0.055, Vector3(0, 0.03, 0), mat(Color("#2a3a3a")), 24)
	for i in 5:
		_box(root, Vector3(0.06, 0.06, 0.7), Vector3(-0.28 + i * 0.14, 0.05, 0), mat(BRONZE))
	var column := MeshInstance3D.new()
	column.name = "Column"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.38
	cm.height = 3.4
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	column.mesh = cm
	column.material_override = stream_material(true)
	column.position.y = 1.7
	column.visible = false
	root.add_child(column)
	return root


## The sand curtain across a stair (a "gate"): two little obelisks and a sheet of falling sand between them.
static func curtain() -> Node3D:
	var root := Node3D.new()
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.18, 1.6, 0.18), Vector3(s * 0.52, 0.8, 0), mat(SAND_DARK))
		var tip := _cyl(root, 0.0, 0.13, 0.22, Vector3(s * 0.52, 1.71, 0), mat(BRONZE), 4)
		tip.rotation.y = PI / 4.0
	var sheet := MeshInstance3D.new()
	sheet.name = "Sheet"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.94, 2.3)
	sheet.mesh = qm
	sheet.material_override = curtain_material()
	sheet.position = Vector3(0, 1.15, 0)
	root.add_child(sheet)
	var heap := _ball(root, 0.5, Vector3(0, 0.02, 0), mat(SAND), 0.18)
	heap.scale = Vector3(1.0, 1.0, 0.6)
	return root


# ---------------------------------------------------------------- the wind
static func stream_material(gale: bool) -> ShaderMaterial:
	if _stream_shader == null:
		_stream_shader = Shader.new()
		_stream_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.86, 1.0, 0.96, 0.5);
uniform float speed = 1.4;
uniform float gap = 0.9;
void fragment() {
	float across = UV.y;
	float edge = smoothstep(0.0, 0.4, across) * smoothstep(1.0, 0.6, across);
	float s = fract(UV.x / gap - TIME * speed + across * 0.35);
	float streak = smoothstep(0.0, 0.18, s) * smoothstep(0.75, 0.25, s);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * edge * (0.25 + 0.75 * streak);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _stream_shader
	if gale:
		m.set_shader_parameter("tint", Color(0.66, 1.0, 0.92, 0.72))
		m.set_shader_parameter("speed", 2.6)
		m.set_shader_parameter("gap", 0.7)
	return m


static func curtain_material() -> ShaderMaterial:
	if _curtain_shader == null:
		_curtain_shader = Shader.new()
		_curtain_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 sand : source_color = vec4(0.93, 0.82, 0.58, 0.8);
float h(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float col = floor(UV.x * 26.0);
	float fall = fract(UV.y * 1.6 - TIME * (0.9 + h(col) * 0.8) + h(col + 3.0));
	float grain = smoothstep(0.0, 0.2, fall) * smoothstep(0.9, 0.4, fall);
	float sides = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = sand.rgb * (0.85 + 0.25 * grain);
	ALPHA = sand.a * sides * (0.35 + 0.65 * grain) * smoothstep(1.0, 0.85, UV.y);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _curtain_shader
	return m


## Draws the room's wind (wind_puzzle.gd blow's "paths"): three soft ribbons along each path from its source, at
## knee, waist and head height (a gale's lower and brighter), streaking the way it blows.
func draw_wind(paths: Array, sources: Dictionary, gale: bool, lift: Callable) -> void:
	if _wind_node != null:
		_wind_node.queue_free()
	_wind_node = Node3D.new()
	_wind_node.name = "Wind"
	add_child(_wind_node)
	var m := stream_material(gale)
	for path in paths:
		var tiles: Array = path["tiles"]
		if tiles.is_empty():
			continue
		var src: Vector2i = sources.get(String(path["from"]), tiles[0])
		var pts: Array[Vector3] = [Vector3(src.x + 0.5, 0, src.y + 0.5)]
		for t: Vector2i in tiles:
			pts.append(Vector3(t.x + 0.5, float(lift.call(t)), t.y + 0.5))
		pts[0].y = pts[1].y
		# the last stretch ends at the face of what stops it
		var last: Vector3 = pts.back()
		var prev: Vector3 = pts[pts.size() - 2]
		pts[pts.size() - 1] = last + (last - prev).normalized() * 0.42
		pts[0] += (pts[1] - pts[0]).normalized() * 0.3
		var heights := [0.4, 0.85, 1.3] if not gale else [0.3, 0.7, 1.1]
		var widths := [0.22, 0.3, 0.2] if not gale else [0.36, 0.46, 0.3]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r in heights.size():
			var along := 0.0 + r * 0.37
			var wob := (r - 1) * 0.12
			for i in pts.size() - 1:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i + 1]
				var dvec := (b - a)
				var length := dvec.length()
				if length < 0.01:
					continue
				var dir := dvec / length
				var side := dir.cross(Vector3.UP).normalized() * float(widths[r]) / 2.0
				var off := dir.cross(Vector3.UP).normalized() * wob + Vector3(0, float(heights[r]), 0)
				var q := [a + off - side, b + off - side, b + off + side, a + off + side]
				var uv := [Vector2(along, 0), Vector2(along + length, 0), Vector2(along + length, 1), Vector2(along, 1)]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_uv(uv[k])
					st.set_normal(Vector3.UP)
					st.add_vertex(q[k])
				along += length
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wind_node.add_child(mi)


# ---------------------------------------------------------------- a chasm
## A chasm's sides: cut stone faces running down from every floor edge round it, a pale lip along the top, and far
## below a faint teal glow where the wind comes up from the pyramid's heart. `ground`: how high the floor beside it
## stands (tile -> height), so a face under a ledge starts at the ledge.
func build_chasm(map: Dictionary, void_tile: Callable, floor_tile: Callable, ground := Callable()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip := SurfaceTool.new()
	lip.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deep := -6.0
	var w: int = map["w"]
	var h: int = map["h"]
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if not void_tile.call(p):
				continue
			_quad(glow, Vector3(x, deep + 0.3, y), Vector3(x + 1, deep + 0.3, y), Vector3(x + 1, deep + 0.3, y + 1), Vector3(x, deep + 0.3, y + 1), Vector3.UP, Color.WHITE)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if void_tile.call(q):
					continue
				# the face between this chasm tile and its neighbour, looking into the chasm
				var c := Vector3(x + 0.5, 0, y + 0.5) + Vector3(d.x, 0, d.y) * 0.5
				var along := Vector3(absf(d.y), 0, absf(d.x)) * 0.5
				var n := -Vector3(d.x, 0, d.y)
				var shade := 0.92 if d.y == 0 else (0.78 if d.y < 0 else 1.0)
				var top := Vector3(0, float(ground.call(q)) if ground.is_valid() else 0.0, 0)
				_quad(st, c - along + top, c + along + top, c + along + Vector3(0, deep, 0), c - along + Vector3(0, deep, 0), n, Color(shade, shade, shade))
				if floor_tile.call(q):
					# the lip: a pale stone edge along the floor's side of it
					var lc := c + Vector3(d.x, 0, d.y) * 0.06 + top
					_box_st(lip, lc + Vector3(0, 0.03, 0), Vector3(absf(float(d.y)), 0, absf(float(d.x))) * 1.02 + Vector3(absf(float(d.x)), 0, absf(float(d.y))) * 0.14 + Vector3(0, 0.08, 0))
	var walls := MeshInstance3D.new()
	walls.mesh = st.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = SAND_DARK.darkened(0.25)
	wm.vertex_color_use_as_albedo = true
	wm.roughness = 0.95
	walls.material_override = wm
	add_child(walls)
	var lips := MeshInstance3D.new()
	lips.mesh = lip.commit()
	lips.material_override = mat(SAND.lightened(0.1))
	add_child(lips)
	var g := MeshInstance3D.new()
	g.mesh = glow.commit()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#123a36")
	gm.emission_enabled = true
	gm.emission = TEAL.darkened(0.55)
	gm.emission_energy_multiplier = 0.8
	g.material_override = gm
	add_child(g)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var tri := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:
		tri = [a, c, b, a, d, c]
	for v in tri:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


static func _box_st(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var hs := s / 2.0
	var x0 := c.x - hs.x
	var x1 := c.x + hs.x
	var y0 := c.y - hs.y
	var y1 := c.y + hs.y
	var z0 := c.z - hs.z
	var z1 := c.z + hs.z
	_quad(st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, Color.WHITE)
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, Color(0.92, 0.92, 0.92))
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, Color(0.85, 0.85, 0.85))
	_quad(st, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, Color(0.9, 0.9, 0.9))
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, Color(0.9, 0.9, 0.9))
