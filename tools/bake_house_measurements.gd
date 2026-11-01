extends SceneTree
## Cache geometry analysis only; source meshes, textures, fitting rules and visuals remain unchanged.
## Run after importing houses. -- --verify compares the baked results to freshly measured source geometry.

func _initialize() -> void:
	var houses = load("res://scripts/gfx/house_models.gd")
	var verify := "--verify" in OS.get_cmdline_user_args()
	var previous: Resource = load(houses.MEASUREMENTS) if verify and ResourceLoader.exists(houses.MEASUREMENTS) else null
	houses._measurements_loaded = true
	houses._shapes = {}
	houses._steps = {}
	houses._porches = {}
	houses._porch_roofs = {}
	var count := 0
	for file in DirAccess.get_files_at(houses.DIR):
		if not file.ends_with(".res") or file == "measurements.res":
			continue
		var key := file.get_basename()
		houses.shape(key)
		houses.steps(key)
		houses.porch(key)
		houses.porch_roof(key)
		count += 1
	var data := Resource.new()
	data.set_meta("shapes", houses._shapes)
	data.set_meta("steps", houses._steps)
	data.set_meta("porches", houses._porches)
	data.set_meta("porch_roofs", houses._porch_roofs)
	var bad := 0
	if verify:
		for key in data.get_meta_list():
			if previous == null or previous.get_meta(key, {}) != data.get_meta(key):
				bad += 1
	else:
		bad = int(ResourceSaver.save(data, houses.MEASUREMENTS, ResourceSaver.FLAG_COMPRESS) != OK)
	print("HOUSE MEASUREMENTS DONE: %d problem(s), %d houses" % [bad, count])
	quit(bad)
