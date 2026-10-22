extends SceneTree
## Loads every script in scripts/ and tools/ and reports any that don't parse or compile, including ones no test
## scene reaches. Scripts that need the game's autoloads (GameState, Story, ...) compile here too: Godot resolves
## them from project.godot.
## Run: godot --headless --path . --script res://tools/check_scripts.gd  (or tools/run_tests.sh)


func _initialize() -> void:
	var bad := 0
	var n := 0
	var stack := ["res://scripts", "res://tools"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if not sub.begins_with("."):
				stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			n += 1
			var s = load(d + "/" + f)
			if s == null or not (s as GDScript).can_instantiate():
				bad += 1
				print("FAIL ", d + "/" + f)
	print("SCRIPTS CHECK DONE: %d of %d script(s) broken" % [bad, n])
	quit(1 if bad > 0 else 0)
