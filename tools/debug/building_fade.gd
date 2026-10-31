extends RefCounted
## Building base visibility, deferred construction and renderer-independent arrival fades.
const WorldDB = preload("res://scripts/data/world_db.gd")
var bad := 0

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	var towns: Array = [String(opts["town"])] if opts.has("town") else WorldDB.TOWN_ORDER
	for town in towns:
		await main._go(town, "start")
		var world = main.world
		# This rendering/navigation audit must not enter an unrelated trainer lesson.
		for npc in world.npcs.values():
			if npc.get("kind", "") == "trainer":
				npc["manual_only"] = true
		world.set_process(false)
		var tested := 0
		var longest_load_us := 0
		for f in world.building_fades:
			var b: Dictionary = f["b"]
			var base := Vector3(float(b["x"]) + float(b["w"]) / 2.0, world._lift(b["door"]), float(b["y"]) + float(b["d"]) / 2.0)
			# Aim well north: even a tall southern roof must not cause its building to load.
			world.cam.position = base + Vector3(0, 7, -30)
			world.cam.look_at(base + Vector3(0, 0, -41))
			world._fade_buildings(1.0)
			_check(not world._building_base_visible(b) and not is_instance_valid(f["node"]), "%s: %s stays unloaded with its base off-screen" % [town, b["name"]])
			world.cam.position = base + world.CAM_OFFSET
			world.cam.look_at(base + Vector3(0, world.CAM_LOOK_Y, 0))
			for attempt in world.building_fades.size():
				var began := Time.get_ticks_usec()
				world._fade_buildings(0.0)
				longest_load_us = maxi(longest_load_us, Time.get_ticks_usec() - began)
				if is_instance_valid(f["node"]):
					break
			world._fade_buildings(0.1)
			_check(is_instance_valid(f["node"]) and is_equal_approx(f["opacity"], 0.3), "visible base constructs the building and starts its fade")
			for binding in f.get("fade_materials", {}).get("bindings", []):
				var mat: BaseMaterial3D = binding["mesh"].get_active_material(binding["surface"])
				_check(mat == binding["faded"] and mat != binding["original"] and is_equal_approx(mat.albedo_color.a, binding["original"].albedo_color.a * 0.3), "isolated fade works on all renderers")
			world._fade_buildings(1.0)
			_check(f["opacity"] == 1.0, "arrival finishes opaque")
			for binding in f.get("fade_materials", {}).get("bindings", []):
				_check(binding["mesh"].get_active_material(binding["surface"]) == binding["original"], "opaque materials restored")
			tested += 1
		_check(tested > 0, "%s: audited %d buildings (slowest visibility update %.1f ms)" % [town, tested, longest_load_us / 1000.0])
		if town == "tidewater":
			world.set_process(true)
			world.spawn_at(Vector2i(12, 15))
			# Actual whole-tile walking down the reopened lane and onto the western pier.
			for goals in [[Vector2i(12, 16)], [Vector2i(12, 19)], [Vector2i(12, 23), Vector2i(13, 23)], [Vector2i(10, 24)], [Vector2i(10, 28)]]:
				await main._walk_test(goals)
				_check(world.player_pos in goals, "western dock waypoint %s reached" % str(goals))
			_check(world.player_pos == Vector2i(10, 28), "square-to-western-dock route is walkable")
			world.spawn_at(Vector2i(12, 18) if opts.get("preview", "") == "lane" else Vector2i(10, 33))
			await main._wait(0.5)
	UI.auto = false
	print("BUILDING FADE DONE: %d problem(s)" % bad)

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
	elif "audited" in label or "dock" in label:
		print("ok   ", label)
