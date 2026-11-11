extends RefCounted
## Fresh-state checks of the continuous beach, with real walking and screen taps.
const MG = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const Shore = preload("res://scripts/world/shoreline.gd")
const ML = preload("res://scripts/world/map_loader.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
var bad := 0

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok:
		bad += 1

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.gear["flute"] = ""
	GameState.set_flag("reed_flute", false)
	for lesson in ["screen", "turns", "slingshot", "items", "ring"]:
		GameState.set_flag("lesson_" + lesson)
	await main._go("route1", Vector2i(10, 9))
	# Let the real arrival fade release input before sending the first movement press in a windowed run.
	await main._wait(0.8)
	var world = main.world
	var map: Dictionary = world.map
	var terrain = world._ground_mesh
	var verge_ok := true
	var pillow_ok := true
	for z in int(map["h"]):
		for x in int(map["w"]):
			var i: int = x + z * int(map["w"])
			if terrain.grassy_layer(terrain.layer[i]) and world._beach_verge(x, z):
				verge_ok = verge_ok and VT.GROUND_LAYERS[terrain.layer[i]] == "grass"
				if terrain.lifted[i] == 1:
					pillow_ok = pillow_ok and is_equal_approx(terrain._vertex_y(x, z, x * 2 + 1, z * 2 + 1), Elev.surface(map, Vector2i(x, z)) + terrain.LIFT)
	check(verge_ok, "no dark grass beside beach sand")
	check(pillow_ok, "beach verge retains its raised grass pillow")
	check(terrain.corners[9 + 12 * int(map["w"])] & terrain.SE != 0, "sand corner uses the same chamfer as a path")
	var rocks_ok := true
	for z in int(map["h"]):
		for x in int(map["w"]):
			if MG.get_t(map, x, z) != MG.ROCK or not world._beach_verge(x, z):
				continue
			var tile := Vector2i(x, z)
			rocks_ok = rocks_ok and world._ground_tile(tile) == MG.GRASS
			for name in world.biome["rocks"]:
				var xf: Transform3D = world._beach_rock_transform(name, tile, 2.0, 0.7)
				var box: AABB = xf * world.VA.aabb(name)
				rocks_ok = rocks_ok and box.position.x > x and box.end.x < x + 1.0 and box.position.z > z and box.end.z < z + 1.0
				rocks_ok = rocks_ok and is_equal_approx(box.position.y, world.tile_pos(tile).y - 0.025)
	check(rocks_ok, "beach-edge rocks fit entirely on grass with grounded bases")
	# Keep random encounters and roaming NPCs out of this navigation fixture.
	world._wild_target = 0
	for wild in world.wilds.duplicate():
		world._remove_wild(wild)
	for npc in world.npcs.values():
		npc["still"] = true
	for z in range(10, 18):
		await main._press("move_down")
		await main._wait(0.4)
		check(world.player_pos == Vector2i(10, z), "grassy approach and beach reach %s" % Vector2i(10, z))
		if z == 10:
			await main._press("move_left")
			await main._wait(0.4)
			check(world.player_pos == Vector2i(10, 10), "movement cannot enter the bush beside the beach approach")
	var depth: float = Shore.WATER_Y - world.player.position.y
	check(depth > 0.0 and depth <= Shore.MAX_WADE_DEPTH + 0.001, "five-centimetre wading shelf")
	await main._press("move_down")
	await main._wait(0.4)
	check(world.player_pos == Vector2i(10, 17), "deep sea stays blocked")
	var tile := Vector2i(11, 17)
	var at: Vector2 = world.cam.unproject_position(world.tile_pos(tile))
	if DisplayServer.get_name() == "headless":
		# Headless reports a dummy window size; test ground picking here, and real screen input in windowed runs.
		world.tap_at(at)
	else:
		# Input.parse_input_event receives window pixels, then Godot applies the root's content scaling.
		at *= Vector2(main.get_window().size) / Vector2(main.view.size)
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = at
			event.pressed = pressed
			Input.parse_input_event(event)
			await main.get_tree().process_frame
	await main._wait(0.6)
	check(world.player_pos == tile, "tap reaches neighboring shallows (at %s)" % world.player_pos)
	for x in range(8, 18):
		for z in range(14, 18):
			check(MG.get_t(map, x, z) in [MG.SAND, MG.SHALLOWS] and is_zero_approx(Elev.surface(map, Vector2i(x, z))), "continuous flat beach at %s" % Vector2i(x, z))
	var falls := false
	for source in world._ground_mesh._fall_sides:
		falls = falls or (source.x >= 7 and source.x <= 19 and source.y >= 12 and source.y <= 18)
	check(not falls, "no beach waterfalls")
	check(not map["npcs"].any(func(n): return n["pos"].y >= 12 and n["pos"].x >= 7 and n["pos"].x <= 19), "beach has no residents or sunbathers")
	for end in [Vector2i(17, 15), Vector2i(8, 15)]:
		await main._walk_test([end])
		check(world.player_pos == end, "walks across the unbroken sand to %s" % end)
	await main._walk_test([Vector2i(10, 9)])
	check(world.player_pos == Vector2i(10, 9), "returns to the route (at %s, busy %s, moving %s)" % [world.player_pos, world.busy, world.moving])
	# The beach is west of the creek. Walking round its mouth must never replace Hal's bridge puzzle.
	var closed := ML.load_map("route1", {})
	var bridge_flag := ""
	for obstacle in closed["obstacles"].values():
		if obstacle["kind"] == "broken_bridge":
			bridge_flag = obstacle["flag"]
	check(not _crosses_river(closed), "unmended river still blocks the entire route, including the beach")
	check(bridge_flag != "" and _crosses_river(ML.load_map("route1", {bridge_flag: true})), "mending the bridge restores the only crossing")
	check(not Shore.contains(map, 28.5, 15.5), "beach seabed stops before the river mouth")
	await main._wait(0.4)
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		world.spawn_at(Vector2i(12, 15))
		await main._wait(1.5)
		main._save_shot(String(opts["shot"]))
	UI.auto = false
	print("COASTAL PATH DONE: %d problem(s)" % bad)

func _crosses_river(map: Dictionary) -> bool:
	var start := Vector2i(0, 8)
	var seen := {start: true}
	var queue := [start]
	var cursor := 0
	while cursor < queue.size():
		var p: Vector2i = queue[cursor]
		cursor += 1
		if p.x == 55:
			return true
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q := p + d
			if q.x < 0 or q.y < 0 or q.x >= int(map["w"]) or q.y >= int(map["h"]):
				continue
			if not seen.has(q) and MG.walkable(MG.get_t(map, q.x, q.y)) and Elev.joined(map, p, q):
				seen[q] = true
				queue.append(q)
	return false
