extends RefCounted
## Red/blue paint across shared renderers and permanent voices at every red door.
const Maps = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Chatter = preload("res://scripts/data/chatter_db.gd")
const Houses = preload("res://scripts/gfx/house_models.gd")
const Walls = preload("res://scripts/gfx/house_builder.gd")
const Interiors = preload("res://scripts/data/maps/interior_maps.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
var bad := 0

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	if opts.has("preview"):
		await _input_preview(main,opts)
		return
	for i in range(1,9):
		var mesh: Mesh = Walls.piece("door_%d" % i)
		var painted := false
		for s in mesh.get_surface_count():
			if mesh.surface_get_name(s) == "door":
				painted = true
				_check(mesh.surface_get_material(s).albedo_color == (Houses.LOCKED_DOOR if i == 1 else Houses.OPEN_DOOR), "wall-section door %d has the correct paint" % i)
		_check(painted, "wall-section door %d contains a painted leaf" % i)
	var seen := {}
	var red := []
	for town in WorldDB.TOWN_ORDER:
		var map: Dictionary = Maps.load_map(town,{})
		for b in map["buildings"]:
			if not Places.door_locked(b):
				continue
			var identity := String(b["interior"])
			_check(Chatter.DOOR_VOICES.has(identity), identity+" has an authored voice")
			var lines: Array = Chatter.DOOR_VOICES.get(identity,[])
			_check(not lines.is_empty() and not seen.has(str(lines)), identity+" has a distinct reply")
			seen[str(lines)] = true
			red.append(b)
	for b in red:
		UI.auto_log.clear()
		await Places.knock(b)
		var first := UI.auto_log.duplicate()
		var moved: Dictionary = b.duplicate()
		moved["door"] += Vector2i(3,2)
		moved["seed"] = 1
		UI.auto_log.clear()
		await Places.knock(moved)
		_check(first == UI.auto_log and not first.is_empty(), String(b["interior"])+" keeps its resident after another knock or a layout change")
	for key in Interiors.ROOMS:
		var room: Dictionary = Interiors.ROOMS[key]
		var rows: String = "".join(room.get("rows",[]))
		if "L" in rows and not room.has("stone_doors"):
			_check(Chatter.ROOM_DOOR_VOICES.has(key), key+" has an indoor knock reply")
		if "Z" in rows:
			_check(Chatter.STAFF_DOOR_VOICES.has(key), key+" has a staff knock reply")
	# Exercise the actual red indoor door through the normal interaction path.
	await main._go("caccoon#1", "entry")
	var room: Dictionary = main.world.map
	for tile in room.get("locked_text",{}):
		UI.auto_log.clear()
		await Places.prop(MapGen.LOCKED,room,main.world,tile)
		_check(UI.auto_log.any(func(line): return "Locked." in String(line)) and not UI.auto_log.any(func(line): return "Muffled Voice" in String(line)), "the home kitchen gives a locked-door observation without an invented speaker")
		break
	await main._go("caccoon", "start")
	for f in main.world.building_fades:
		var b: Dictionary = f["b"]
		if not b.get("knockable", false):
			continue
		_check(main.world.doors.has(b["door"]) and Places.door_locked(b), "Cove scenery door registers as a locked interaction")
		main.world.spawn_at(b["door"] + Vector2i.DOWN)
		main.world.facing = Vector2i.UP
		await main._wait(0.1)
		var pixel: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(b["door"]) + Vector3(0, 0.9, 0))
		_check(main.world._pick(pixel).get("tile", Vector2i(-1, -1)) == b["door"], "visible scenery door wins over hidden building bounds")
		UI.auto_log.clear()
		main.world._enter_building(b)
		await main._wait(1.0)
		_check(UI.auto_log.any(func(line): return "Muffled Voice" in String(line)), "Cove scenery neighbor answers a knock")
	print("DOOR VOICES DONE: %d problem(s)" % bad)
	if opts.has("verify"):
		await _input_preview(main,opts)
		await _edge_checks(main, opts)

func _input_preview(main, opts: Dictionary) -> void:
	await main._go("caccoon", "start")
	var b: Dictionary = main.world.doors[Vector2i(25, 5)] if opts.get("preview", "") == "scenery" else main.world.map["buildings"][4]
	main.world.spawn_at(b["door"]+Vector2i.DOWN)
	if opts.get("preview", "") == "scenery":
		_check(main.world.player_pos == b["door"] + Vector2i.DOWN, "scenery door approach is walkable")
	main.world.facing = Vector2i.UP
	UI.auto = false
	await main._wait(0.4)
	if UI.is_touch():
		var pixel: Vector2 = main.world.cam.unproject_position(main.world.tile_pos(b["door"])+Vector3(0,0.9,0))
		if opts.get("preview", "") == "scenery":
			_check(main.world._pick(pixel).get("tile", Vector2i(-1, -1)) == b["door"], "tap ray picks the scenery house's door")
			for down in [true, false]:
				var ev := InputEventScreenTouch.new()
				ev.index = 8
				ev.pressed = down
				ev.position = pixel * Vector2(main.get_window().size) / Vector2(main.view.size)
				Input.parse_input_event(ev)
				await main.get_tree().process_frame
		else:
			await main._tap_at(pixel*main.get_viewport().get_visible_rect().size/Vector2(main.view.size))
	else:
		await main._press("interact")
	await main._wait(1.2)
	_check(not UI.stack.is_empty() and main.world.map_id == "caccoon", "the red door answers a real input and keeps the player outdoors")
	if not UI.stack.is_empty():
		_check(UI.stack.back()._anchored and UI.stack.back().speaker_node.has_meta("speech_bounds"), "the voice is anchored to the actual door")
		UI.stack.back().text_label.visible_characters = -1
	await main._wait(float(opts.get("wait","1")))
	if opts.has("shot"):
		main._save_shot(String(opts["shot"]))
	if opts.has("verify"):
		var dialog = UI.stack.back()
		var pages: int = dialog.lines.size()
		await _confirm(main)
		await main._wait(0.3)
		_check(UI.stack.is_empty() if pages == 1 else is_instance_valid(dialog) and dialog.idx == 1, "one confirmation advances exactly one dialogue page")
		for i in range(1,pages):
			if UI.stack.is_empty():
				break
			UI.stack.back().text_label.visible_characters = -1
			await _confirm(main)
			await main._wait(0.3)
		_check(UI.stack.is_empty(), "the final page closes without knocking again")
		print("DOOR INPUT DONE: %d problem(s)" % bad)


func _edge_checks(main, opts: Dictionary) -> void:
	var b: Dictionary = main.world.map["buildings"][4]
	var source: Node3D = main.world.door_speaker(b["door"])
	var camera: Camera3D = main.world.cam
	main.world.cam_free = true
	var original := camera.global_transform
	var bounds: AABB = source.get_meta("speech_bounds")
	var top := source.global_position + Vector3(0, bounds.end.y, 0)
	for edge in ["top", "bottom", "left", "right"]:
		camera.global_transform = original
		var fraction := Vector2(0.5, 0.04) if edge == "top" else Vector2(0.5, 0.88)
		if edge in ["left", "right"]:
			fraction = Vector2(0.04 if edge == "left" else 0.96, 0.5)
		var current := camera.unproject_position(top)
		var depth := -camera.to_local(top).z
		camera.global_position += camera.project_position(current, depth) - camera.project_position(Vector2(main.view.size) * fraction, depth)
		Places.knock(b, main.world)
		await main._wait(1.1)
		var dialog = UI.stack.back()
		dialog.text_label.visible_characters = -1
		var footprint: Rect2 = dialog._bubble_rect.merge(dialog.name_panel.get_global_rect())
		_check(dialog.bubble_mode and dialog._anchored and not dialog._tail.is_empty(), edge + ": door reply keeps its white bubble and pointer")
		_check(dialog._below == (edge == "top"), edge + ": pointer uses the bottom/top of the door to fit the viewport")
		_check(UIKit.safe_rect(dialog).encloses(footprint), edge + ": whole bubble and name plate stay in the safe area")
		if UI.is_touch():
			for group in UI.controls.CLUSTERS:
				_check(not footprint.intersects(UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)), edge + ": door reply stays clear of touch controls")
		if opts.has("shot") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts["shot"]).get_basename() + "_" + edge + ".png")
		dialog.close()
		await main._wait(0.2)
	camera.global_transform = original
	# Ordinary locked rooms use written observations, without inventing a speaker.
	UI.auto = true
	await main._go("caccoon#1", "entry")
	UI.auto = false
	for tile in main.world.map.get("locked_text", {}):
		Places.prop(MapGen.LOCKED, main.world.map, main.world, tile)
		await main._wait(1.1)
		var dialog = UI.stack.back()
		_check(not dialog.bubble_mode and dialog.speaker == "" and dialog.speaker_node == null, "indoor locked door uses the dark observation window")
		dialog.text_label.visible_characters = -1
		if opts.has("shot") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts["shot"]).get_basename() + "_indoors.png")
		dialog.close()
		break
	print("DOOR BUBBLES DONE: %d problem(s)" % bad)

func _confirm(main) -> void:
	if UI.is_touch():
		var button = UI.controls._buttons["a"]
		await main._tap_at(button.get_global_transform_with_canvas()*Vector2(UI.controls.ROUND/2.0,UI.controls.ROUND/2.0))
	else:
		await main._press("ui_accept")

func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ",label)
	if not ok:
		bad += 1
