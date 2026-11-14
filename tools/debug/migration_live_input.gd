extends Node
## Observe manual input in the ordinary game using isolated state; inject nothing.
class EventObserver extends Node:
	var collector: Node
	func _input(event: InputEvent) -> void:
		collector.observe_input(event)

var root: Window
var output := ""
var journal := {"events": [], "snapshots": []}
var began := 0
var sequence := 0
var previous_keep_on := false
var game_root: Node

func _ready() -> void:
	root = get_tree().root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--event_output="):
			output = arg.trim_prefix("--event_output=")
	if not (output.begins_with("res://build/") or output.begins_with("user://bench/vo/")):
		push_error("Live migration input requires an isolated --event_output")
		get_tree().quit(1)
		return
	call_deferred("start_observation")

func start_observation() -> void:
	began = Time.get_ticks_usec()
	previous_keep_on = DisplayServer.screen_is_kept_on()
	DisplayServer.screen_set_keep_on(true)
	var prefs: Node = root.get_node("Prefs")
	prefs.set("graphics_quality", "min")
	prefs.set("render_height", 720)
	prefs.call("apply")
	DirAccess.make_dir_recursive_absolute(output)
	journal["engine"] = Engine.get_version_info()
	journal["platform"] = OS.get_name()
	journal["devices"] = []
	for device in Input.get_connected_joypads():
		journal.devices.append({"device": device, "name": Input.get_joy_name(device)})
	var scene: PackedScene = load("res://main.tscn")
	game_root = scene.instantiate()
	root.add_child(game_root)
	var observer := EventObserver.new()
	observer.collector = self
	root.add_child(observer)
	write_journal()
	await get_tree().create_timer(3.0).timeout
	await snapshot("initial")
	for second in 300:
		await get_tree().create_timer(1.0).timeout
		if FileAccess.file_exists(output.path_join("finish.flag")):
			break
	journal["finished"] = true
	write_journal()
	DisplayServer.screen_set_keep_on(previous_keep_on)
	get_tree().quit()

func observe_input(event: InputEvent) -> void:
	var kind := ""
	if event is InputEventJoypadButton:
		kind = "joypad_button"
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.7:
		kind = "joypad_axis"
	elif event is InputEventKey and not event.echo:
		kind = "key"
	elif event is InputEventScreenTouch:
		kind = "touch"
	elif event is InputEventMouseButton:
		kind = "mouse_button"
	if kind.is_empty():
		return
	var actions: Array = []
	for action in InputMap.get_actions():
		if event.is_action(action):
			actions.append(action)
	sequence += 1
	journal.events.append({"sequence": sequence, "kind": kind, "device": event.device,
		"pressed": event.is_pressed(), "description": event.as_text(), "actions": actions,
		"elapsed_ms": (Time.get_ticks_usec() - began) / 1000.0})
	write_journal()
	if event.is_pressed() or kind == "joypad_axis":
		snapshot("event_%03d" % sequence)

func snapshot(label: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	var stack: Array = []
	var ui := root.get_node_or_null("UI")
	if ui != null:
		for panel in ui.get("stack"):
			if is_instance_valid(panel):
				stack.append(panel.get_script().resource_path if panel.get_script() != null else panel.get_class())
	var row := {"label": label, "error": error, "ui_stack": stack}
	var world: Node = game_root.get("world")
	if is_instance_valid(world):
		var tile: Vector2i = world.get("player_pos")
		var player: Node3D = world.get("player")
		row["tile"] = [tile.x, tile.y]
		if is_instance_valid(player):
			row["player_position"] = [player.position.x, player.position.y, player.position.z]
	journal.snapshots.append(row)
	write_journal()

func write_journal() -> void:
	journal["current_devices"] = []
	for device in Input.get_connected_joypads():
		journal.current_devices.append({"device": device, "name": Input.get_joy_name(device)})
	var file := FileAccess.open(output.path_join("input.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(journal, "\t"))
