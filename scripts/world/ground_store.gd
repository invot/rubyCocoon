extends RefCounted
## The ground's meshes on disk, so a map's ground is read back rather than generated (terrain_mesh.gd _shape: a third
## to a half of a map's loading time). Two places are looked in, by the same key the generator remembers shapes by:
##   res://assets/ground/   shipped with the game, baked for every outdoor map by tools/bake_ground.gd
##   user://ground/         what this device generated itself (a map whose ground the story has changed), kept for
##                          next time; bounded to KEEP files
## A shape is only as good as the generator that made it. The shipped set records the generator's sources
## (index.json "generator"), and a run that can read them (the editor, the tests) ignores a set baked by other code;
## an exported game has only compiled scripts, and trusts the set it was exported with (run_tests.sh "ground" checks
## it is current). The device's own files carry the generator in their names.
const BAKED_DIR := "res://assets/ground/"
const USER_DIR := "user://ground/"
const INDEX := BAKED_DIR + "index.json"
const KEEP := 24
## The scripts a shape comes from.
const SOURCES := ["res://scripts/world/terrain_mesh.gd", "res://scripts/world/elevation.gd", "res://scripts/world/shoreline.gd"]
const WATER_ID := 1000000
const LAVA_ID := 1000001

static var _generator := ""
static var _baked_ok := -1
## Set by the bake tool and the tests: no reading (generate afresh) or no writing to the device.
static var reading := true
static var writing := true
## The bake tool's: called with (key, shape) for every shape generated, instead of keeping it on the device.
static var on_generated := Callable()


## What the generator is, as far as this run can tell: its sources' text, or "" where only compiled scripts exist.
static func generator() -> String:
	if _generator == "":
		var text := ""
		for path in SOURCES:
			var source := FileAccess.get_file_as_string(path)
			if not "func " in source:
				_generator = "compiled"
				return _generator
			text += source.replace("\r\n", "\n")
		_generator = text.md5_text()
	return _generator


static func _baked_usable() -> bool:
	if _baked_ok < 0:
		_baked_ok = 0
		if FileAccess.file_exists(INDEX):
			var index = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
			if index is Dictionary:
				if generator() == "compiled" or String(index.get("generator", "")) == generator():
					_baked_ok = 1
				else:
					push_warning("The baked ground in assets/ground is from other terrain code: run tools/bake_ground.gd.")
	return _baked_ok == 1


static func file_name(key: String) -> String:
	return key.md5_text() + ".res"


static func _user_path(key: String) -> String:
	return USER_DIR + (key + generator()).md5_text() + ".res"


## The shape stored for this key ({"chunks", "water", "lava"} as terrain_mesh.gd makes it), or {} if there is none.
static func fetch(key: String) -> Dictionary:
	if not reading:
		return {}
	var path := BAKED_DIR + file_name(key)
	if not (_baked_usable() and ResourceLoader.exists(path)):
		path = _user_path(key)
		if generator() == "compiled" or not FileAccess.file_exists(path):
			return {}
	var lib := ResourceLoader.load(path, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE) as MeshLibrary
	if lib == null:
		return {}
	return unpack(lib)


## Keeps a shape this device just generated, for the next time it is wanted.
static func keep(key: String, shape: Dictionary) -> void:
	if on_generated.is_valid():
		on_generated.call(key, shape)
		return
	# (the web's storage is written on the game's own thread, and its maps are in the shipped set)
	if not writing or generator() == "compiled" or OS.has_feature("web"):
		return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	if ResourceSaver.save(pack(shape), _user_path(key), ResourceSaver.FLAG_COMPRESS) != OK:
		return
	var dir := DirAccess.open(USER_DIR)
	if dir == null:
		return
	var files := []
	for f in dir.get_files():
		files.append([FileAccess.get_modified_time(USER_DIR + f), f])
	files.sort()
	for i in files.size() - KEEP:
		dir.remove(files[i][1])


static func pack(shape: Dictionary) -> MeshLibrary:
	var lib := MeshLibrary.new()
	var chunks: Array = shape["chunks"]
	lib.set_meta("chunks", chunks.size())
	for i in chunks.size():
		for k in 2:
			if chunks[i][k] != null:
				lib.create_item(i * 2 + k)
				lib.set_item_mesh(i * 2 + k, chunks[i][k])
	for extra in [[WATER_ID, "water"], [LAVA_ID, "lava"]]:
		if shape[extra[1]] != null:
			lib.create_item(extra[0])
			lib.set_item_mesh(extra[0], shape[extra[1]])
	return lib


static func unpack(lib: MeshLibrary) -> Dictionary:
	var ids := {}
	for id in lib.get_item_list():
		ids[id] = true
	var chunks := []
	for i in int(lib.get_meta("chunks", 0)):
		if not ids.has(i * 2):
			return {}
		chunks.append([lib.get_item_mesh(i * 2), lib.get_item_mesh(i * 2 + 1) if ids.has(i * 2 + 1) else null])
	if chunks.is_empty():
		return {}
	return {"chunks": chunks, "water": lib.get_item_mesh(WATER_ID) if ids.has(WATER_ID) else null,
		"lava": lib.get_item_mesh(LAVA_ID) if ids.has(LAVA_ID) else null}
