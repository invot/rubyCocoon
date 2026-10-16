extends SceneTree
## Debug: lists a map's buildings.  godot --headless -s tools/debug/buildings.gd -- tidewater
func _init() -> void:
	var MapLoader = load("res://scripts/world/map_loader.gd")
	for id in OS.get_cmdline_user_args():
		var m: Dictionary = MapLoader.load_map(id, {})
		for b in m["buildings"]:
			print(id, ": ", b["shop"], " at ", b["x"], ",", b["y"], " ", b["w"], "x", b["d"], " door ", b["door"], " -> ", b["interior"])
		print(id, " npcs: ", m["npcs"].map(func(n): return n.get("id", n.get("kind", ""))))
	quit()
