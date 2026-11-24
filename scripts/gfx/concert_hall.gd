extends RefCounted
## The Oasis Saloon's concert hall and the band's storeroom (interior_maps.gd "saloon_stage" and "saloon_back", the
## user's 2026-11-24 layout), dressed by room_builder.gd:
##  - The stage's gear ("stage_gear"): the band's instruments (the Lowpoly Instrument Set, painted) and a few pieces of
##    sound and light equipment, all switched off and some knocked over (tools/import_music_gear.gd bakes them as
##    assets/props/music_<name>.res). Each piece's tiles go in the map's "scenery_blocks", so nobody walks through it.
##  - The audience's tables (furniture "concert_table"): a tiny lamp on each, and drinks on some.
##  - The storeroom's lockers, cots and shelves of cans and boxes, built here from boxes and cylinders in the painted
##    "color" material (voxel_buildings.gd Kit), so they're chubby like the rest of the furniture.

const VB = preload("res://scripts/gfx/voxel_buildings.gd")
const PIECES := ["drink_glass", "lockers", "cot", "can_stack", "box_stack"]

static var _meshes := {}


static func piece(name: String) -> ArrayMesh:
	if not _meshes.has(name):
		var k = VB.Kit.new()
		match name:
			"drink_glass":
				# a short tumbler of something amber (sarsaparilla, says Dusty)
				VB._column(k, "glass", Vector3.ZERO, 0.034, 0.09, 10, Color("#e8f0f2"))
				VB._column(k, "color", Vector3(0, 0.006, 0), 0.028, 0.055, 10, Color("#c97a2a"))
			"lockers":
				_lockers(k)
			"cot":
				_cot(k)
			"can_stack":
				# three tins of beans, two below and one on top
				for c in [Vector3(-0.05, 0, 0), Vector3(0.05, 0, 0), Vector3(0, 0.12, 0)]:
					VB._column(k, "color", c, 0.045, 0.12, 10, Color("#c9ccd4"))
					VB._column(k, "color", c + Vector3(0, 0.025, 0), 0.047, 0.07, 10, Color("#b8323e") if c.y == 0.0 else Color("#3d6fa8"))
			"box_stack":
				# a cardboard box with a lighter tape stripe, and a smaller one on it
				k.box("color", Vector3(0, 0.08, 0), Vector3(0.24, 0.16, 0.2), Color("#b88a55"), true)
				k.box("color", Vector3(0, 0.161, 0), Vector3(0.05, 0.004, 0.2), Color("#e2c48a"))
				k.box("color", Vector3(0.02, 0.21, 0.01), Vector3(0.16, 0.1, 0.14), Color("#a87a48"), true)
		_meshes[name] = k.mesh()
	return _meshes[name]


## A bank of eight painted steel lockers, four tiles long (the "fit" kind stretches it to its run), with vents, handles
## and number cards on their doors.
static func _lockers(k) -> void:
	var body := Color("#5f8794")
	var door := Color("#6d9aa6")
	k.box("color", Vector3(0, 0.06, 0), Vector3(4.0, 0.12, 0.46), Color("#3e4b54"), true)
	k.box("color", Vector3(0, 1.0, 0), Vector3(4.0, 1.76, 0.5), body, true)
	k.box("color", Vector3(0, 1.9, 0.01), Vector3(4.04, 0.05, 0.54), body.darkened(0.15))
	for i in 8:
		var x := -1.75 + 0.5 * i
		k.box("color", Vector3(x, 1.0, 0.255), Vector3(0.44, 1.66, 0.02), door)
		for j in 3:
			k.box("color", Vector3(x, 1.62 - 0.07 * j, 0.268), Vector3(0.26, 0.025, 0.01), Color("#2f3a42"))
		k.box("color", Vector3(x + 0.15, 1.0, 0.275), Vector3(0.05, 0.16, 0.03), Color("#c8ccd6"))
		k.box("color", Vector3(x, 1.34, 0.268), Vector3(0.14, 0.08, 0.01), Color("#f0e5cc"))


## A camp cot one tile wide and two long (along z, its pillow at -z): a stout wooden frame on six legs, a canvas sling,
## a wool blanket over its foot and a pillow.
static func _cot(k) -> void:
	var wood := Color("#7a5434")
	for x in [-0.36, 0.36]:
		k.box("color", Vector3(x, 0.32, 0), Vector3(0.08, 0.08, 1.9), wood, true)
		for z in [-0.88, 0.0, 0.88]:
			k.box("color", Vector3(x, 0.15, z), Vector3(0.08, 0.3, 0.08), wood, true)
	for z in [-0.92, 0.92]:
		k.box("color", Vector3(0, 0.32, z), Vector3(0.8, 0.07, 0.07), wood, true)
	k.box("color", Vector3(0, 0.345, 0), Vector3(0.66, 0.04, 1.8), Color("#8c8a5e"), true)
	k.box("color", Vector3(0, 0.385, 0.38), Vector3(0.72, 0.05, 1.0), Color("#9a3a3a"), true)
	k.box("color", Vector3(0, 0.41, -0.7), Vector3(0.48, 0.1, 0.3), Color("#efe6d4"), true)


## Drinks on some of the concert tables (beside their tiny lamp, towards the chairs at each end), as the room's rng picks.
static func dress_table(rb, pos: Vector3, top_y: float, yaw: float, pieces: Array) -> void:
	var n: int = [0, 1, 1, 2][rb.rng.randi_range(0, 3)]
	var sides := [-1.0, 1.0]
	sides.shuffle()
	for i in n:
		var g := MeshInstance3D.new()
		g.mesh = piece("drink_glass")
		g.position = pos + Basis(Vector3.UP, yaw) * Vector3(float(sides[i]) * rb.rng.randf_range(0.2, 0.26), 0, rb.rng.randf_range(-0.1, 0.12)) + Vector3(0, top_y, 0)
		rb.parent.add_child(g)
		pieces.append(g)


## The storeroom's shelves ("goods": "pantry"): tins and boxes along each shelf. Returns them.
static func pantry_goods(rb, pos: Vector3, yaw: float, bb: AABB, sc: Vector3) -> Array:
	var out := []
	var basis := Basis(Vector3.UP, yaw)
	var width := bb.size.x * sc.x
	for shelf_y in [0.06, 0.36, 0.66]:
		var x := -width / 2.0 + 0.16
		while x < width / 2.0 - 0.14:
			var t := MeshInstance3D.new()
			t.mesh = piece(["can_stack", "box_stack", "can_stack"][rb.rng.randi_range(0, 2)])
			t.position = pos + basis * Vector3(x, bb.size.y * sc.y * shelf_y, 0.0)
			t.rotation.y = yaw + rb.rng.randf_range(-0.2, 0.2)
			rb.parent.add_child(t)
			out.append(t)
			x += rb.rng.randf_range(0.24, 0.3)
	return out


## The stage's gear (the room's "stage_gear"): each {"piece": music_<piece>, "at": [x, y] tile, "off": [x, z] from its
## middle, "yaw" and "tilt" ([about x, about z]) in degrees (tilted pieces lean or lie, the lowest point on the floor),
## "blocks": the tiles it stands on (its own tile if none)}.
static func dress_stage(rb) -> void:
	var room: Dictionary = rb.map.get("room", {})
	if not room.has("stage_gear"):
		return
	if not rb.map.has("scenery_blocks"):
		rb.map["scenery_blocks"] = {}
	for g in room["stage_gear"]:
		var path := "res://assets/props/music_%s.res" % g["piece"]
		if not ResourceLoader.exists(path):
			push_warning("missing stage gear: " + path)
			continue
		var mesh: Mesh = load(path)
		var at := Vector2i(int(g["at"][0]), int(g["at"][1]))
		var tilt: Array = g.get("tilt", [0, 0])
		var basis := Basis(Vector3.UP, deg_to_rad(float(g.get("yaw", 0.0)))) \
			* Basis.from_euler(Vector3(deg_to_rad(float(tilt[0])), 0, deg_to_rad(float(tilt[1]))))
		var low := (Transform3D(basis, Vector3.ZERO) * mesh.get_aabb()).position.y
		var off: Array = g.get("off", [0, 0])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.basis = basis
		mi.position = Vector3(at.x + 0.5 + float(off[0]), rb.dais_at(rb.map, at) - low, at.y + 0.5 + float(off[1]))
		rb.parent.add_child(mi)
		for b in g.get("blocks", [g["at"]]):
			rb.map["scenery_blocks"][Vector2i(int(b[0]), int(b[1]))] = true
