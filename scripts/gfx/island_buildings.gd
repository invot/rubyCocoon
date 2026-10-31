extends RefCounted
## Island architecture uses the shared wall sections and roof mesher, kept inside each existing plot.
const VB = preload("res://scripts/gfx/voxel_buildings.gd")
const HB = preload("res://scripts/gfx/house_builder.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const PERSON = preload("res://scripts/gfx/voxel_person.gd")
const WORLD = preload("res://scripts/data/world_db.gd")
const PASTELS := ["#f1b8ae", "#f3d995", "#b5d9c8", "#c9bce1", "#aed4e2"]

static var _wood: ShaderMaterial

static func wood_material() -> ShaderMaterial:
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = preload("res://scripts/gfx/island_wood.gdshader")
	return _wood

static func _door(k: VB.Kit, dx: float, face: float, locked: bool) -> void:
	var col := Color("#a43842") if locked else Color("#9c673d")
	k.box("color", Vector3(dx, 1.1, face + 0.02), Vector3(1.05, 2.2, 0.10), col)
	for side in [-1.0, 1.0]:
		k.box("color", Vector3(dx + side * 0.59, 1.15, face + 0.04), Vector3(0.13, 2.3, 0.16), Color("#694729"))
	k.box("color", Vector3(dx, 2.31, face + 0.04), Vector3(1.31, 0.13, 0.16), Color("#694729"))
	k.box("color", Vector3(dx, 2.5, face), Vector3(1.2, 0.30, 0.15), Color("#aa7b49"))
	k.box("color", Vector3(dx + 0.34, 1.08, face + 0.105), Vector3(0.08, 0.16, 0.06), Color("#e6c66e"))

## An open hut window on the wall side a-c: a dark opening behind bamboo bars in a wooden frame, under a woven shutter
## propped open on a stick (no glass).
static func _hut_window(k: VB.Kit, a: Vector2, c: Vector2, center: Vector2) -> void:
	var mid := (a + c) / 2.0
	var along := (c - a).normalized()
	var out2 := Vector2(along.y, -along.x)
	if out2.dot(mid - center) < 0.0:
		out2 = -out2
	var t := Vector3(along.x, 0, along.y)
	var n := Vector3(out2.x, 0, out2.y)
	var p := Vector3(mid.x, 0, mid.y) + n * 0.03
	var hw := 0.38
	var y0 := 1.12
	var y1 := 1.78
	var up := Vector3.UP
	k.poly("color", [p - t * hw + up * y0, p + t * hw + up * y0, p + t * hw + up * y1, p - t * hw + up * y1], n, Color("#2a1c12"))
	var f := p + n * 0.04
	var frame := Color("#694729")
	VB._beam(k, "color", f - t * (hw + 0.14) + up * y0, f + t * (hw + 0.14) + up * y0, 0.1, frame)
	VB._beam(k, "color", f - t * (hw + 0.06) + up * y1, f + t * (hw + 0.06) + up * y1, 0.09, frame)
	for s in [-1.0, 1.0]:
		VB._beam(k, "color", f + t * s * hw + up * y0, f + t * s * hw + up * y1, 0.09, frame)
	for x in [-0.5, 0.0, 0.5]:
		VB._beam(k, "color", f + t * x * hw + up * y0, f + t * x * hw + up * y1, 0.05, Color("#c9a35a"))
	var hinge := p + n * 0.07 + up * (y1 + 0.07)
	var lip := p + n * 0.5 + up * (y1 - 0.12)
	VB._slope(k, "thatch", [hinge - t * (hw + 0.1), hinge + t * (hw + 0.1), lip + t * (hw + 0.1), lip - t * (hw + 0.1)], Color("#b48a45"), t)
	VB._beam(k, "color", f + n * 0.04 + up * y0, lip - up * 0.02, 0.04, Color("#8a633d"))


## A small thatched awning over the door on two brackets, kept above head height.
static func _awning(k: VB.Kit, dx: float, face: float) -> void:
	var hinge := Vector3(dx, 2.72, face + 0.02)
	var lip := Vector3(dx, 2.44, face + 0.62)
	var side := Vector3(0.85, 0, 0)
	VB._slope(k, "thatch", [hinge - side, hinge + side, lip + side, lip - side], Color("#b48a45"), Vector3.RIGHT)
	for s in [-1.0, 1.0]:
		VB._beam(k, "color", Vector3(dx + s * 0.74, 2.1, face + 0.04), Vector3(dx + s * 0.74, 2.44, face + 0.55), 0.07, Color("#694729"))


## Overlapping courses of bundled grass, with a gently uneven eave instead of a smooth tent cone.
## An oval hut passes its wider east-west radius as `rx`.
static func _thatch(k: VB.Kit, center: Vector2, radius: float, top: float, rise: float, rx := 0.0) -> void:
	rx = maxf(rx, radius)
	var n := 32 if rx <= radius else 48
	for course in 10:
		var low := float(course) / 10.0
		var high := float(course + 1) / 10.0
		var outer := VB._loop(center, rx * (1.0 - low) + 0.13, radius * (1.0 - low) + 0.13, n, PI / float(n))
		var inner := VB._loop(center, maxf(0.015, rx * (1.0 - high)), maxf(0.015, radius * (1.0 - high)), n, PI / float(n))
		for j in outer.size():
			var a: Vector2 = outer[j]
			var b: Vector2 = outer[(j + 1) % outer.size()]
			var c: Vector2 = inner[(j + 1) % inner.size()]
			var d: Vector2 = inner[j]
			var fringe := -0.04 if course > 0 else 0.0
			VB._slope(k, "thatch", [Vector3(a.x, top + low * rise + fringe, a.y), Vector3(b.x, top + low * rise + fringe, b.y), Vector3(c.x, top + high * rise, c.y), Vector3(d.x, top + high * rise, d.y)], Color("#c39a50"), Vector3(b.x - a.x, 0, b.y - a.y))

static func build(b: Dictionary, style: String) -> Node3D:
	var node := Node3D.new()
	var k := VB.Kit.new()
	var hb := HB.new()
	hb.node = node
	var w := float(b["w"])
	var d := float(b["d"])
	var dx := float(b["door"].x) + 0.5 - float(b["x"]) - w / 2.0
	var shop := String(b["shop"])
	var wood := style == "roundwood"
	var hotel: bool = b.get("hotel", false)
	var wall: Material = wood_material() if wood else _stucco(int(b["seed"]))
	# the arena is the village's great hut: taller walls and a steep, high roof
	var great := wood and shop == "arena"
	var top := (3.1 if great else 2.65) if wood else (8.4 if hotel else 5.6)
	var rise := 2.6 if great else 1.5
	var face := d / 2.0 - 0.16
	if wood:
		# One flat tangent is centered exactly on the map door; every other wall follows the ring (an oval for the
		# great hut, with enough sides that the door's tangent stays about a door wide).
		var r := float(b.get("hut_radius", minf(w / 2.0 - 0.12, d / 2.0 - 0.12)))
		var rx := maxf(r, float(b.get("hut_rx", r)))
		var sides := maxi(20, ceili(PI / asin(clampf(0.66 / rx, 0.01, 1.0))))
		var rot := PI / float(sides)
		var center := Vector2(dx, face - r)
		var pts := VB._loop(center, rx, r, sides, rot)
		# open shuttered windows on the front and back diagonals (and the great hut's ends), never on the door's side
		var windows := {}
		for t in [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0] + ([PI / 2.0, 3.0 * PI / 2.0] if great else []):
			windows[posmod(roundi((t - rot) / (TAU / float(sides)) - 0.5), sides)] = true
		windows.erase(sides - 1)
		for i in pts.size():
			var a: Vector2 = pts[i]
			var c: Vector2 = pts[(i + 1) % pts.size()]
			# the last side is the one straddling the front, where the door goes
			if i != pts.size() - 1:
				hb.span("wall_1", a, c, 0.0, wall, center, top)
				if windows.has(i):
					_hut_window(k, a, c, center)
			elif top > 2.7:
				# the great hut's walls stand taller than the door frame: close the wall above it
				hb.span("wall_1", a, c, 2.6, wall, center, top - 2.6)
			# log posts round the wall, except either side of the door
			if i % 2 == 0 and i != 0:
				var out := (a - center).normalized() * 0.05
				VB._column(k, "color", Vector3(a.x + out.x, 0.0, a.y + out.y), 0.09, top - 0.05, 6, Color("#7a5432"))
		# Wooden entry and flanking windows are placed on the front tangent.
		_door(k, dx, face, b.get("locked", false))
		_awning(k, dx, face)
		_thatch(k, center, r, top, rise, rx)
		VB._skirt(k, "planks", pts, 0.05, 0.16, Color("#8a633d"), center)
		# a lashed wall plate under the eaves, a hanging straw fringe, and a tied bundle on the peak
		VB._skirt(k, "color", VB._scaled(pts, center, 1.012), top - 0.24, 0.14, Color("#5e3f22"), center)
		VB._skirt(k, "thatch", VB._loop(center, rx + 0.13, r + 0.13, sides, rot), top - 0.3, 0.3, Color("#b8904a"), center)
		VB._column(k, "thatch", Vector3(center.x, top + rise - 0.12, center.y), 0.16, 0.5, 8, Color("#c39a50"))
		VB._column(k, "color", Vector3(center.x, top + rise + 0.02, center.y), 0.18, 0.09, 8, Color("#5e3f22"))
	else:
		hb.w = w
		hb.d = d
		var levels := 3 if hotel else 2
		for level in levels:
			hb.storey(float(level) * 2.8, wall, "door_3" if level == 0 else "", dx, {2: ["win_small_1"]}, false, true)
		VB._hip(k, w - 0.12, d - 0.12, top, 0.36, 0.08, false, "tiles", Color("#bf7054"), Color("#f8edda"))
		# Pale mission arches and pilasters frame the entrance; a curved parapet crowns it.
		for side in [-1.0, 1.0]:
			k.box("plaster", Vector3(dx + side * 0.71, 1.15, face + 0.025), Vector3(0.15, 2.3, 0.15), Color("#fff0d6"))
		for i in 16:
			var a := PI * float(i) / 16.0
			var c := PI * float(i + 1) / 16.0
			VB._beam(k, "plaster", Vector3(dx + cos(a) * 0.71, 2.3 + sin(a) * 0.55, face + 0.025), Vector3(dx + cos(c) * 0.71, 2.3 + sin(c) * 0.55, face + 0.025), 0.16, Color("#fff0d6"))
		k.box("plaster", Vector3(dx, top + 0.08, 0), Vector3(1.7, 0.38, 0.28), Color("#f8e6c8"))
		# Mission bell opening on the hotel, above the red tile roof.
		if hotel:
			for side in [-1.0, 1.0]:
				k.box("plaster", Vector3(dx + side * 0.57, top + 0.8, 0), Vector3(0.22, 1.4, 0.4), Color("#f8e6c8"))
			k.box("plaster", Vector3(dx, top + 1.5, 0), Vector3(1.36, 0.23, 0.46), Color("#f8e6c8"))
			VB._column(k, "metal", Vector3(dx, top + 0.75, 0), 0.22, 0.4, 12, Color("#d5ad54"))
	if not wood and shop in ["apothecary", "cafe", "center"]:
		var brand := Color("#439d93") if shop == "apothecary" else Color("#bd757b")
		for stripe in 8:
			k.box("color", Vector3(dx - 1.4 + float(stripe) * 0.4, 2.7, face + 0.1), Vector3(0.4, 0.12, 0.65), brand if stripe % 2 == 0 else Color("#fff3dc"))
	if hotel:
		var title := Label3D.new()
		title.text = "HOTEL MARIPOSA"
		title.font = preload("res://ui/lunchds.ttf")
		title.font_size = 48
		title.pixel_size = 0.005
		title.position = Vector3(dx, 3.35, face + 0.08)
		title.modulate = Color("#704c38")
		node.add_child(title)
	hb.finish()
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	var surface_index := 0
	for kind in k.surf:
		if kind == "thatch":
			var straw := ShaderMaterial.new()
			straw.shader = preload("res://scripts/gfx/island_wood.gdshader")
			straw.set_shader_parameter("roofing", true)
			straw.set_shader_parameter("wood_colour", Color("#a47a35"))
			mi.set_surface_override_material(surface_index, straw)
		surface_index += 1
	node.add_child(mi)
	b["height"] = top + (rise + 0.4 if wood else 1.8)
	if shop != "house":
		var plaque := MeshInstance3D.new()
		plaque.mesh = VP.icon(shop if shop != "house" else "cafe")
		plaque.position = Vector3(dx, (3.05 if great else 2.75) if wood else 3.5, face + 0.12)
		plaque.scale = Vector3.ONE * 0.65
		node.add_child(plaque)
	return node

static func _stucco(seed_value: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(PASTELS[absi(seed_value) % PASTELS.size()])
	m.roughness = 0.95
	return m

## Beach furniture has real occupied tiles. Open aisles connect both ramps and the ferry.
static func beach(world: Node3D) -> void:
	for i in 6:
		var x := 15 + WORLD.SHELLHAVEN_WEST_PADDING + i * 4
		var z := 19
		for occupied in [Vector2i(x, z), Vector2i(x - 1, z), Vector2i(x - 1, z + 1)]:
			MG.set_t(world.map, occupied.x, occupied.y, MG.STREET_PROP)
		var k := VB.Kit.new()
		var color := Color(PASTELS[i % PASTELS.size()])
		VB._column(k, "planks", Vector3(x + 0.5, 0.95, z + 0.5), 0.035, 1.9, 8, Color("#b18b5d"))
		var ring := VB._loop(Vector2(x + 0.5, z + 0.5), 1.05, 1.05, 16)
		VB._spire(k, "plaster", ring, 1.85, Vector2(x + 0.5, z + 0.5), 0.38, color)
		# Low chaise, sloping back, and legs. Its two-tile footprint stays off the promenade.
		var chair_x := x - 1.0
		k.box("planks", Vector3(chair_x, 0.27, z + 0.7), Vector3(0.7, 0.1, 1.4), Color("#faf1dd"))
		VB._beam(k, "planks", Vector3(chair_x, 0.28, z + 0.05), Vector3(chair_x, 0.7, z - 0.5), 0.58, color)
		for end in [-0.45, 0.45]:
			k.box("planks", Vector3(chair_x, 0.12, z + 0.7 + end), Vector3(0.65, 0.24, 0.08), Color("#b98c63"))
		var mesh := MeshInstance3D.new()
		mesh.mesh = k.mesh()
		world.add_child(mesh)
		# The existing character rig reclines on the chaise, with bare arms/legs and swim trunks.
		var skin: String = ["#e7b58c", "#bd8059", "#8f5f45"][i % 3]
		var person := PERSON.build({"skin": skin, "shirt": skin, "pants": PASTELS[(i + 2) % 5], "shoes": skin, "hair": "#593a27", "body": "male", "hair_style": 0, "model": "tf0", "outfit": "swim"})
		person.rotation.x = -PI / 2.0
		person.position = Vector3(chair_x, 0.42, z + 1.35)
		person.scale = Vector3.ONE * 0.75
		world.add_child(person)
