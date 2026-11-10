extends RefCounted
## Supplied fences: collision, open yard gates, saved interior identities and gameplay-camera captures.
const ML = preload("res://scripts/world/map_loader.gd")
const FM = preload("res://scripts/gfx/fence_models.gd")
var bad := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)


func run(main, opts: Dictionary) -> void:
	main.get_window().title = "Ruby Cocoon - Fence boundaries"
	for flag in ["intro_done", "got_egg", "has_starter", "tutorial_done", "flute_lesson_done", "island_peace", "reed_flute"]:
		GameState.set_flag(flag)
	UI.auto = true
	for style in ["fence", "stone_fence", "iron_fence"]:
		for mask in 16:
			var mesh := FM.tile(style, mask)
			var bb := mesh.get_aabb()
			check(bb.size.y >= 0.65 and bb.size.y <= 1.05, "%s stays below the hero's head" % style)
			check(mesh.get_surface_count() == 1, "%s joins share one material batch" % style)
			check((mesh.surface_get_material(0) as BaseMaterial3D).disable_receive_shadows,
				"%s avoids dark shadow-map patches on its thin sections" % style)
	var cove := ML.load_map("caccoon", {})
	check(cove["buildings"][4]["x"] == 7 and cove["buildings"][4]["y"] == 16, "Cove neighbour retains interior #4")
	check(cove["buildings"][6]["shop"] == "shack", "gear shack retains interior #6")
	# The two island houses demonstrate both supplied yard materials without story encounters.
	for entry in [["kelpwick", Vector2i(5, 5), Vector2i(3, 6), Vector2i(5, 6)],
		["kelpwick", Vector2i(32, 5), Vector2i(30, 6), Vector2i(32, 6)]]:
		await main._go(entry[0], entry[1])
		var world = main.world
		check(world.player_pos == entry[1], "spawn on open front lawn %s (actual %s)" % [entry[1], world.player_pos])
		check(not world._walkable(entry[2]), "fence blocks movement at %s" % entry[2])
		check(world._can_step(entry[1], entry[3]), "two-tile gate remains clear at %s" % entry[3])
		if world.player_pos == entry[1]:
			world.spawn_at(entry[2] + Vector2i.UP)
			if UI.is_touch() and DisplayServer.get_name() != "headless":
				await load("res://tools/debug/waterfront.gd").new()._tap(main, entry[2])
				check(world.player_pos != entry[2], "a world tap cannot cross the fence")
			else:
				await _direction(main, "move_down")
				await main._wait(0.3)
				check(world.player_pos == entry[2] + Vector2i.UP, "directional input stops at the fence")
			world.spawn_at(entry[1])
			if UI.is_touch() and DisplayServer.get_name() != "headless":
				await load("res://tools/debug/waterfront.gd").new()._tap(main, entry[3])
			else:
				await _direction(main, "move_down")
			await main._wait(0.4)
			check(world.player_pos == entry[3] and not world.moving, "walk through the gate stops at its tile centre")
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		var preview: String = opts.get("preview", "wood")
		var scenes := {"wood": ["kelpwick", Vector2i(5, 7)], "stone": ["kelpwick", Vector2i(32, 7)],
			"iron": ["tidewater", Vector2i(45, 20)], "graveyard": ["gravenmoor", Vector2i(31, 13)],
			"nature": ["route1", Vector2i(42, 7)], "cove": ["caccoon", Vector2i(9, 10)],
			"garden-stairs": ["caccoon", Vector2i(27, 15)]}
		var view: Array = scenes.get(preview, scenes["wood"])
		await main._go(view[0], view[1])
		await main._wait(1.0)
		main._save_shot(opts["shot"])
	UI.auto = false
	print("FENCES DONE: %d problem(s)" % bad)


func _direction(main, action: String) -> void:
	# World movement polls held actions; a menu's one-frame InputEventAction can be missed headless.
	Input.action_press(action)
	await main._wait(0.08)
	Input.action_release(action)
