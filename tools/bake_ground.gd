extends RefCounted
## Bakes every outdoor map's ground meshes into assets/ground/ (see scripts/world/ground_store.gd), so the game reads
## them back instead of generating them while the screen is black. Each map is baked as a new game finds it and with
## every story gate, obstacle and flood on it changed, so the common states are all shipped; any other ground a story
## makes is generated once on the device and kept there.
##   godot --headless --path . -- --scene=bake-ground            bake (then godot --headless --path . --import)
##   godot --headless --path . -- --scene=bake-ground --verify=1 check the shipped set matches the terrain code
const GroundStore = preload("res://scripts/world/ground_store.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const Beasts = preload("res://scripts/core/beasts.gd")

var _wanted := {}
var bad := 0


func run(main, opts: Dictionary) -> void:
	var verify: bool = opts.get("verify", "0") == "1"
	UI.auto = true
	GameState.party = [Beasts.create(0, 10)]
	var script = await main.wait_for_script(main.WORLD_PATH)
	GroundStore.reading = false
	GroundStore.on_generated = func(key: String, shape: Dictionary) -> void:
		_wanted[GroundStore.file_name(key)] = shape
	var ids: Array = WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys()
	if opts.has("maps"):
		ids = Array(String(opts["maps"]).split(","))
	var base := {"intro_done": true, "tutorial_done": true, "ritual_done": true, "opening_seen": true}
	for id in ids:
		for changed in [false, true]:
			GameState.flags = base.duplicate()
			if changed:
				for flag in _story_flags(id):
					GameState.flags[flag] = true
			script.clear_scenery_cache()
			await main._load_world(id, "start")
			main.world.frozen = true
	GroundStore.on_generated = Callable()
	GroundStore.reading = true
	if verify:
		_verify()
	else:
		_write()
	UI.auto = false
	print("GROUND BAKE DONE: %d shape(s), %d problem(s)" % [_wanted.size(), bad])


## Every flag that changes this map's tiles: its gate, obstacles and floods.
func _story_flags(id: String) -> Array:
	var m := MapLoader.load_map(id, {})
	var out := []
	if m.has("gate"):
		out.append(String(m["gate"]["flag"]))
	for grp in m.get("obstacles", {}).values():
		if not grp["flag"] in out:
			out.append(grp["flag"])
	for f in m.get("flood_flags", []):
		if not f in out:
			out.append(f)
	return out


func _write() -> void:
	DirAccess.make_dir_recursive_absolute(GroundStore.BAKED_DIR)
	var dir := DirAccess.open(GroundStore.BAKED_DIR)
	for f in dir.get_files():
		if f.ends_with(".res") and not _wanted.has(f):
			dir.remove(f)
	for f in _wanted:
		var err := ResourceSaver.save(GroundStore.pack(_wanted[f]), GroundStore.BAKED_DIR + f, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			bad += 1
			print("FAIL could not save ", f)
	var files := _wanted.keys()
	files.sort()
	var index := FileAccess.open(GroundStore.INDEX, FileAccess.WRITE)
	index.store_string(JSON.stringify({"generator": GroundStore.generator(), "files": files}, "\t"))


func _verify() -> void:
	if not FileAccess.file_exists(GroundStore.INDEX):
		bad += 1
		print("FAIL no baked ground: run --scene=bake-ground")
		return
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GroundStore.INDEX))
	if String(index.get("generator", "")) != GroundStore.generator():
		bad += 1
		print("FAIL the baked ground is from other terrain code: run --scene=bake-ground")
	for f in _wanted:
		if not ResourceLoader.exists(GroundStore.BAKED_DIR + f):
			bad += 1
			print("FAIL missing baked ground ", f)
			continue
		var stored := GroundStore.unpack(ResourceLoader.load(GroundStore.BAKED_DIR + f, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE))
		if not _same(stored, _wanted[f]):
			bad += 1
			print("FAIL baked ground differs from the generator's ", f)


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or a["chunks"].size() != b["chunks"].size():
		return false
	var pairs := []
	for i in a["chunks"].size():
		pairs.append([a["chunks"][i][0], b["chunks"][i][0]])
		pairs.append([a["chunks"][i][1], b["chunks"][i][1]])
	pairs.append([a["water"], b["water"]])
	pairs.append([a["lava"], b["lava"]])
	for p in pairs:
		if (p[0] == null) != (p[1] == null):
			return false
		if p[0] == null:
			continue
		if p[0].get_surface_count() != p[1].get_surface_count():
			return false
		for s in p[0].get_surface_count():
			var x: Array = p[0].surface_get_arrays(s)
			var y: Array = p[1].surface_get_arrays(s)
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX]:
				if x[k] != y[k]:
					return false
	return true
