extends SceneTree
## Debug: prints a map's tile grid, one hex digit (or letter) per tile code.
## godot --headless --path . -s tools/debug/dump_map.gd -- caccoon
func _init() -> void:
	var MapLoader = load("res://scripts/world/map_loader.gd")
	var MapGen = load("res://scripts/world/map_gen.gd")
	var id: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "caccoon"
	var m: Dictionary = MapLoader.load_map(id, {})
	for y in m["h"]:
		var row := ""
		for x in m["w"]:
			var c: int = MapGen.get_t(m, x, y)
			row += "%X" % c if c < 16 else char(65 + c - 16)
		print(row)
	quit()
