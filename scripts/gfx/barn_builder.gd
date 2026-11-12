extends RefCounted
## The kennel barns out on the roads (map letter "?", shop "kennel"): Kennel Keeper Pip's adoption kennels.
## The barn is the supplied Small Barn (tools/import_kennel_barn.gd, licenses/kennel_barn.md): lap-board walls, a
## bowed barn roof with a cupola, and closed double barn doors braced with crosses under a hayloft door. Its paint
## and roof take a region's colours (PAINTS); the trim stays cream, so it's always plainly a barn.
## A plot is the barn's five tiles at its east end (the barn is four across, its doors on the door tile, see
## map_loader.gd _add_building) with any tiles west of them a fenced paddock: the supplied wood fence round a water
## trough and hay bales. The pawprint sign from the Beast Centers hangs by the doors, with a lantern over them.
## A building's local origin is the centre of its plot at ground level; its front faces +z (as voxel_buildings.gd).

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const MESH := "res://assets/exteriors/kennel_barn.res"
const TROUGH := "res://assets/exteriors/water_trough.res"
## the barn's tiles across, how far its walls stand in from the plot's front and back, and its height (the cupola's top)
const TILES := 5
const INSET := 0.16
const HEIGHT := 5.0
## [paint, roof] by biome (world_db.gd BIOMES); the others take the coast's
const PAINTS := {
	"coast": ["#c8483c", "#5c525a"],
	"island": ["#d9694e", "#6e5c54"],
	"desert": ["#cf7440", "#7c5e4c"],
	"mesa": ["#c9623c", "#74564a"],
	"western": ["#c9623c", "#74564a"],
	"mountain": ["#ab443c", "#515060"],
	"volcano": ["#a03c38", "#48444c"],
	"jungle": ["#b9523e", "#56604e"],
	"moor": ["#9c4a4c", "#4a4858"],
}
const TRIM := Color("#f4ecdc")
const STRAW := Color("#f2cf62")
const TWINE := Color("#c09a44")
const WOOD := Color("#8a5a36")
const IRON := Color("#2a2a30")

static var _mats := {}
static var _meshes := {}


static func available() -> bool:
	return ResourceLoader.exists(MESH)


static func build(b: Dictionary, biome_id: String) -> Node3D:
	var node := Node3D.new()
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var front := d / 2.0 - INSET
	var length := d - INSET * 2.0
	b["height"] = HEIGHT
	var k := VBld.Kit.new()
	if available():
		var mesh: Mesh = load(MESH)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3(1.0, 1.0, length)
		mi.position = Vector3(door_lx, 0.0, front - length / 2.0)
		var pal: Array = PAINTS.get(biome_id, PAINTS["coast"])
		var cols := {"paint": Color(pal[0]), "trim": TRIM, "roof": Color(pal[1])}
		for s in mesh.get_surface_count():
			var sn: String = mesh.surface_get_name(s)
			if cols.has(sn):
				mi.set_surface_override_material(s, _material(mesh.surface_get_material(s), cols[sn]))
		node.add_child(mi)
	# the pawprint sign on its board beside the doors, a lantern over them, and a locked door's straps
	var sx := 1.0 if door_lx <= 0.0 else -1.0
	var sign_x := door_lx + sx * 1.32
	k.box("planks", Vector3(sign_x, 1.55, front + 0.035), Vector3(0.74, 0.74, 0.07), TRIM)
	var paw := MeshInstance3D.new()
	paw.mesh = VP.icon("center")
	paw.position = Vector3(sign_x, 1.55, VBld._on_face(paw.mesh, front + 0.07))
	node.add_child(paw)
	k.box("color", Vector3(door_lx, 2.52, front + 0.1), Vector3(0.07, 0.07, 0.2), IRON)
	k.box("color", Vector3(door_lx, 2.46, front + 0.2), Vector3(0.2, 0.05, 0.2), IRON)
	k.box("glow", Vector3(door_lx, 2.33, front + 0.2), Vector3(0.15, 0.21, 0.15), Color("#ffd890"))
	k.box("color", Vector3(door_lx, 2.21, front + 0.2), Vector3(0.18, 0.04, 0.18), IRON)
	if bool(b.get("locked", false)):
		VBld._door_lock(k, Vector3(door_lx, 1.0, front + 0.09), 1.3, 1.9)
	# the paddock: every tile west of the barn's five
	var pad := w - float(TILES)
	if pad >= 1.0:
		_paddock(node, k, -w / 2.0 + 0.14, door_lx - 1.95, -d / 2.0 + 0.3, d / 2.0 - 0.22)
	else:
		# no room for one: a couple of bales against the barn's side instead
		hay_bale(k, Vector3(door_lx + 1.5, 0.0, front + 0.02), 0.0, 0.62)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return node


## A surface's material in a region's colour (shared between barns).
static func _material(base: Material, col: Color) -> Material:
	var key := col.to_html()
	if not _mats.has(key):
		var m: StandardMaterial3D = base.duplicate()
		m.albedo_color = col
		_mats[key] = m
	return _mats[key]


## The paddock between x0 (its west fence) and x1 (the barn's side), z0 (back) to z1 (front): the supplied wood
## fence along its three open sides, a water trough along the barn, and hay bales in the back corner.
static func _paddock(node: Node3D, k: VBld.Kit, x0: float, x1: float, z0: float, z1: float) -> void:
	var fence: Mesh = VA.mesh("fence")
	var fb := fence.get_aabb()
	var runs := [[Vector3(x0, 0, z1), Vector3(x1, 0, z1)], [Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)]]
	for run in runs:
		var a: Vector3 = run[0]
		var c: Vector3 = run[1]
		var span := a.distance_to(c)
		var n := maxi(1, int(round(span / maxf(0.5, fb.size.x))))
		var along_x := absf(c.x - a.x) > absf(c.z - a.z)
		for i in n:
			var mi := MeshInstance3D.new()
			mi.mesh = fence
			var mid := a.lerp(c, (float(i) + 0.5) / n)
			var basis := Basis(Vector3.UP, 0.0 if along_x else PI / 2.0).scaled_local(Vector3(span / n / fb.size.x, 1.0, 1.0))
			mi.transform = Transform3D(basis, mid - basis * Vector3(fb.get_center().x, fb.position.y, fb.get_center().z))
			node.add_child(mi)
	# hay: two bales side by side at the back with a third on top, and one out in the paddock
	var hx := (x0 + x1) / 2.0
	hay_bale(k, Vector3(hx - 0.35, 0.0, z0 + 0.5), 0.0)
	hay_bale(k, Vector3(hx + 0.5, 0.0, z0 + 0.5), 0.0)
	hay_bale(k, Vector3(hx + 0.05, 0.44, z0 + 0.5), 0.0)
	if z1 - z0 > 2.0:
		hay_bale(k, Vector3(x0 + 0.55, 0.0, z1 - 0.75), PI / 2.0)
	# the trough along the barn's side
	if ResourceLoader.exists(TROUGH) and x1 - x0 > 1.5:
		var tm: Mesh = load(TROUGH)
		var tb := tm.get_aabb()
		var ti := MeshInstance3D.new()
		ti.mesh = tm
		var s := minf(1.3 / maxf(tb.size.x, tb.size.z), 0.6 / tb.size.y)
		var yaw := PI / 2.0 if tb.size.x > tb.size.z else 0.0
		var tbasis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
		ti.transform = Transform3D(tbasis, Vector3(x1 - 0.42, 0.0, (z0 + z1) / 2.0 + 0.45) - tbasis * Vector3(tb.get_center().x, tb.position.y, tb.get_center().z))
		node.add_child(ti)


## A hay bale standing on `at` (the middle of its foot), its long side along x unless turned: straw with two twine
## bands, a lighter cut end.
static func hay_bale(k: VBld.Kit, at: Vector3, yaw: float, scale := 1.0) -> void:
	var turned := absf(sin(yaw)) > 0.5
	var size := Vector3(0.82, 0.44, 0.5) * scale
	var s := Vector3(size.z, size.y, size.x) if turned else size
	var c := at + Vector3(0, size.y / 2.0, 0)
	k.box("color", c, s, STRAW, true)
	for f in [-0.24, 0.24]:
		var band := Vector3(0.05 * scale, size.y + 0.02, size.z + 0.02)
		var off := Vector3(size.x * f, 0, 0)
		if turned:
			band = Vector3(band.z, band.y, band.x)
			off = Vector3(0, 0, off.x)
		k.box("color", c + off, band, TWINE, true)


## A stack of hay bales for a barn's room (room_builder.gd "hay"): two below, one across the top; about a tile square.
static func hay_stack() -> ArrayMesh:
	if not _meshes.has("hay"):
		var k := VBld.Kit.new()
		hay_bale(k, Vector3(0, 0, -0.2), 0.0, 0.98)
		hay_bale(k, Vector3(0, 0, 0.26), 0.0, 0.98)
		hay_bale(k, Vector3(0.02, 0.43, 0.02), PI / 2.0, 0.98)
		_meshes["hay"] = k.mesh()
	return _meshes["hay"]


## A barn lantern for a room's wall (its back to z = 0, hanging out towards +z): an iron bracket and a glowing glass.
static func lantern() -> ArrayMesh:
	if not _meshes.has("lantern"):
		var k := VBld.Kit.new()
		k.box("color", Vector3(0, 0.2, 0.09), Vector3(0.05, 0.05, 0.18), IRON, true)
		k.box("color", Vector3(0, 0.13, 0.16), Vector3(0.17, 0.04, 0.17), IRON, true)
		k.box("glow", Vector3(0, 0.0, 0.16), Vector3(0.13, 0.22, 0.13), Color("#ffd890"), true)
		k.box("color", Vector3(0, -0.13, 0.16), Vector3(0.16, 0.04, 0.16), IRON, true)
		_meshes["lantern"] = k.mesh()
	return _meshes["lantern"]
