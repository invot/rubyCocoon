extends SceneTree
## Streets reject foliage whose trunk is outside the pavement, including rotated/off-centre meshes.
const MG = preload("res://scripts/world/map_gen.gd")
var bad := 0

func _initialize() -> void:
	var world = load("res://scripts/world/world.gd").new()
	world.map = MG._new_map("paving_test", "town", 8, 8)
	world.biome = {"stone_streets": true}
	var grid: PackedByteArray = world.map.grid.duplicate()
	var p := Vector2i(4, 4)
	var bounds := AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 2, 0.8))
	var on_street := Transform3D(Basis.IDENTITY, Vector3(4.5, 0, 4.5))
	var beside_street := Transform3D(Basis.IDENTITY, Vector3(3.5, 0, 4.5))
	for tile in [MG.PATH, MG.PLAZA, MG.DOOR, MG.STATUE]:
		MG.set_t(world.map, p.x, p.y, tile)
		_check(world._plant_on_paving(bounds, on_street), "plant on paved tile %d is rejected" % tile)
		_check(not world._plant_on_paving(bounds, beside_street), "plant contained in nearby grass is allowed")
		var wide := AABB(Vector3(-0.8, 0, -0.4), Vector3(1.6, 2, 0.8))
		_check(world._plant_on_paving(wide, beside_street), "overhanging canopy is rejected")
		var offset := AABB(Vector3(-0.4, 0, -1.5), Vector3(0.8, 2, 1.5))
		var turned := Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(3.5, 0, 4.5))
		_check(world._plant_on_paving(offset, turned), "rotated off-centre foliage is rejected")
	MG.set_t(world.map, p.x, p.y, MG.BUSH)
	_check(world._ground_tile(p) == MG.BUSH, "planted bed keeps natural ground in a stone town")
	_check(not world._plant_on_paving(bounds, on_street), "plant inside its bed is allowed")
	MG.set_t(world.map, p.x, p.y, MG.GRASS)
	_check(world.map.grid == grid, "placement checks preserve the movement grid")
	# Exercise actual shrub placement, rather than just its paving filter. Grass and sand walk like roads.
	var VA = load("res://scripts/gfx/voxel_assets.gd")
	var shrub: String = load("res://scripts/data/world_db.gd").BIOMES["coast"]["shrubs"][0]
	for tile in [MG.GRASS, MG.SAND, MG.PATH, MG.TALL, MG.SHALLOWS]:
		MG.set_t(world.map, p.x, p.y, tile)
		var batches := {}
		world._add_plant(batches, shrub, on_street)
		_check(batches.is_empty(), "no walk-through bush on traversable tile %d" % tile)
	MG.set_t(world.map, p.x, p.y, MG.BUSH)
	var batches := {}
	var oversized := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 3.0), Vector3(4.8, 0, 4.7))
	world._add_plant(batches, shrub, oversized)
	_check(not batches.is_empty(), "blocking bush remains visible beside walkable lawn")
	for placements in batches.values():
		for xf: Transform3D in placements:
			_check(not world._plant_on_walkable(VA.aabb(shrub), xf), "full rotated bush foliage stays on blocking ground")
	_check(not world._walkable(p), "bush tile itself blocks the hero")
	world.free()
	print("PLANT PAVING DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL " + message)
