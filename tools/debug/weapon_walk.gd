extends RefCounted
## Real road walks and input dispatch, with saves confined to build/.
const ML = preload("res://scripts/world/map_loader.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const Rules = preload("res://scripts/core/weapon_obstacles.gd")
const Elev = preload("res://scripts/world/elevation.gd")
var bad := 0
var main
var opts: Dictionary


func check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1


func run(game, options: Dictionary) -> void:
	main = game
	opts = options
	check(GameState.save_dir().begins_with("res://build/"), "isolated test saves")
	if bad > 0:
		return
	UI.auto = true
	for flag in ["intro_done", "got_egg", "has_starter", "tutorial_done", "flute_lesson_done", "guardian_water"]:
		GameState.set_flag(flag)
	# Static rules are checked on the real map, before any weapon has been awarded.
	check(not GameState.weapon_seen("boomerang") and not GameState.weapon_seen("bat"), "later weapons start unknown")
	var selected: String = opts.get("weapon", "all")
	for id in ["route1", "route2", "route3", "route4"]:
		var map := ML.load_map(id, {})
		for o in map["weapon_obstacles"]:
			if selected != "all" and o["weapon"] != selected:
				continue
			await exercise(id, o)
	UI.auto = false
	print("WEAPON WALK DONE: %d problem(s)" % bad)


func quiet_world() -> void:
	# Encounters aren't part of these isolated walks; keep chest story objects live.
	main.world.map["encounter"] = {}
	main.world._wild_target = 0
	for w in main.world.wilds:
		w["node"].queue_free()
	main.world.wilds.clear()
	for n in main.world.npcs.values():
		if n.get("kind", "") == "trainer":
			GameState.set_flag(n["flag"])
			n["sight"] = 0


func exercise(id: String, source: Dictionary) -> void:
	var from: Vector2i = source["use_from"]
	var target: Vector2i = source["targets"][0]
	var facing := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
	var map := ML.load_map(id, GameState.flags)
	var approach := from
	var side := Vector2i(facing.y, facing.x)
	for d in [side, -side, -facing, facing]:
		if MG.walkable(MG.get_t(map, from.x + d.x, from.y + d.y)) and Elev.joined(map, from, from + d):
			approach = from + d
			break
	GameState.flags.erase(source["flag"])
	await main._go(id, approach)
	quiet_world()
	var world = main.world
	var o: Dictionary = world.map["weapon_targets"][target]
	await main._walk_test([from])
	check(world.player_pos == from and not world.moving, source["id"] + ": walk to the firing tile")
	world.facing = facing
	world.VPer.face(world.player, facing)
	check(Rules.can_use(world.map, o, from, facing), "clear, cardinal shot " + source["id"])
	check(world.weapon_obstacles.approach(o) == from, "a tap in reach needs no extra walking")
	check(not Rules.can_use(world.map, o, from, -facing), "facing away cannot use " + source["id"])
	if o["weapon"] != "bat":
		var between := from + facing
		var floor_kind := MG.get_t(world.map, between.x, between.y)
		MG.set_t(world.map, between.x, between.y, MG.TREE)
		check(not Rules.can_use(world.map, o, from, facing), "a tree blocks the projectile")
		MG.set_t(world.map, between.x, between.y, floor_kind)
		if between != target:
			world.map["npcs"].append({"pos": between})
			check(not Rules.can_use(world.map, o, from, facing), "a person blocks the projectile")
			world.map["npcs"].pop_back()
			var i: int = between.x + between.y * int(world.map["w"])
			var saved_height: float = world.map["elev"]["hi"][i]
			var saved_low: float = world.map["elev"]["lo"][i]
			world.map["elev"]["hi"][i] = saved_height + 8.0
			world.map["elev"]["lo"][i] = saved_low + 8.0
			check(not Rules.can_use(world.map, o, from, facing), "intervening high ground blocks the projectile")
			world.map["elev"]["hi"][i] = saved_height
			world.map["elev"]["lo"][i] = saved_low
	var weapon: String = o["weapon"]
	GameState.inventory.erase(weapon)
	GameState.flags.erase("seen_weapon_" + weapon)
	UI.auto_log.clear()
	await world._interact()
	check(not GameState.flag(o["flag"]), "missing weapon leaves the mechanism locked")
	check(not str(UI.auto_log).to_lower().contains(weapon), "unknown weapon is not named")
	GameState.add_item(weapon)
	GameState.remove_item(weapon)
	UI.auto_log.clear()
	await world._interact()
	check(str(UI.auto_log).to_lower().contains(weapon), "seen weapon is named in the hint")
	GameState.add_item(weapon)
	await capture(source["id"] + "_before")
	# Test the real A action, gamepad A, and world taps rather than calling the solve routine.
	if UI.is_touch() and DisplayServer.get_name() != "headless":
		# Start one tile away: tapping any switch walks to the firing tile and uses the entire line once.
		world.spawn_at(approach)
		await main._wait(0.6)
		var last: Vector2i = o["targets"].back()
		var at: Vector2 = world.cam.unproject_position(world.tile_pos(last) + Vector3(0, 0.5 if o["weapon"] == "bat" else 1.15, 0))
		check(world._pick(at).get("tile", Vector2i(-1, -1)) == last, "tap ray hits the visible weapon fixture")
		var ui_point: Vector2 = at * main.get_viewport().get_visible_rect().size / Vector2(main.view.size)
		check(not UI.touch_blocks(ui_point), "fixture tap stays clear of touch clusters")
		at *= Vector2(main.get_window().size) / Vector2(main.view.size)
		for pressed in [true, false]:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.position = at
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await main.get_tree().process_frame
	elif o["type"] == "cracked_rock":
		for pressed in [true, false]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = JOY_BUTTON_A
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await main._wait(0.08)
	else:
		await main._press("interact")
	for i in 100:
		await main._wait(0.1)
		if GameState.flag(o["flag"]) and not world.busy:
			break
	check(GameState.flag(o["flag"]) and not world.busy, "one input solves " + source["id"])
	check(world.player_pos == from and not world.moving, "input ends on the firing tile")
	check(GameState.item_count(weapon) == 1, "weapon is not consumed")
	for p in o.get("blocks", []):
		check(world._walkable(p), "released path is walkable at %s" % p)
	await capture(source["id"] + "_after")
	if o.get("effect", "") == "ladder":
		await main._walk_test(o["blocks"])
		check(world.player_pos == o["blocks"][0], "walk up the released ladder")
		check(not Elev.joined(world.map, from + Vector2i.RIGHT, o["blocks"][0]), "ladder cannot be approached from the side")
		await main._walk_test([from])
	var reward: Dictionary = o["reward"]
	var before := GameState.item_count(reward["item"])
	world._go_use(reward["pos"], "npc", false)
	for i in 100:
		await main._wait(0.1)
		if GameState.flag(o["flag"] + "_chest") and not world.busy:
			break
	check(GameState.item_count(reward["item"]) == before + 1, "walk to and open the reward chest")
	await world._interact()
	check(GameState.item_count(reward["item"]) == before + 1, "one press cannot award treasure twice")
	check(GameState.save_game(8), "save solved obstacle and chest")
	GameState.flags.erase(o["flag"])
	check(GameState.load_game(8) and GameState.flag(o["flag"]), "load restores the stable obstacle flag")
	await main._go(id, from)
	quiet_world()
	check(not main.world.map["weapon_targets"].has(target), "solved state survives map re-entry")
	for p in o.get("blocks", []):
		check(MG.walkable(MG.get_t(main.world.map, p.x, p.y)), "released floor survives re-entry")
	check(GameState.flag(o["flag"] + "_chest"), "collected chest survives re-entry")


func capture(name: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await main._wait(0.5)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(opts["shots"]))
		main._save_shot(String(opts["shots"]).path_join(name + ".png"))
