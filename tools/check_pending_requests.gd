extends SceneTree
var bad := 0
class SaveContext extends Node:
	var _test := {"save_dir": "res://build/pending_requests/saves/"}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("GameState")
	var ui = root.get_node("UI")
	var menus = root.get_node("Menus")
	var context := SaveContext.new()
	root.add_child(context)
	state.main = context
	state.new_game("Tester")
	_check(state.weapons() == ["slingshot"], "new journey equips slingshot")
	_check(not state.equip_weapon("bat"), "unowned weapon rejected")
	state.receive_item("bat")
	state.receive_item("boomerang")
	ui.auto = true
	ui.auto_answers = [2]
	await menus.equip_trainer_slot("weapon")
	_check(state.weapons() == ["bat"], "equipment menu equips just the bat")
	_check(state.item_count("bat") == 1 and state.item_count("slingshot") == 1, "equipping retains ownership")
	_check(state.save_game(0), "isolated save succeeds")
	state.equip_weapon("boomerang")
	_check(state.load_game(0) and state.weapons() == ["bat"], "equipped weapon survives reload")
	var path: String = state.slot_path(0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["gear"].erase("weapon")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_check(state.load_game(0) and state.weapons() == ["slingshot"], "old save defaults to slingshot")
	var items = load("res://scripts/data/item_db.gd")
	_check(items.weapon("bat")["power"] > items.weapon("slingshot")["power"], "bat hits harder")
	_check(items.weapon("bat")["accuracy"] < 0.9, "bat plain swing is less accurate")
	var egg_model = load("res://scripts/gfx/egg_model.gd")
	var shell = egg_model.build({"race": 21})
	_check(shell.get_child_count() == 1, "aquatic shell has no fins")
	shell.free()
	var cinematic = load("res://scripts/ui/beast_cinematic.gd")
	for action in ["interact", "ui_accept", "ui_cancel"]:
		var film = cinematic.new().setup("egg", {"name": "Tester"}, {}, {"race": 21})
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		film.on_input(event)
		_check(film.closed, "fresh input dismisses egg before reveal: " + action)
	var hatch = cinematic.new().setup("hatch", {"name": "Tester"}, {}, {"race": 21})
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	hatch.on_input(event)
	_check(not hatch.closed, "hatching still waits for reveal")
	hatch.free()
	await process_frame
	print("PENDING REQUESTS DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)
