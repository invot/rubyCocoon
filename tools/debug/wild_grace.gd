extends RefCounted
## Isolated return-to-field regression. --scene=wild-grace [--shot=res://build/shots/wild_grace.png]
## --preview=pulse replays the real battle's return effect for windowed inspection.

const Beasts = preload("res://scripts/core/beasts.gd")

var bad := 0


func run(main, opts: Dictionary) -> void:
	main.get_window().title = "Ruby Cocoon - wild battle grace"
	UI.auto = true
	for teacher in Story.LESSON_TRAINERS:
		GameState.set_flag("lesson_" + String(teacher["lesson"]))
	await main._go("route1", "west")
	await main._wait(0.3)
	var world = main.world
	_clear_wilds(world)
	var home := _open_patch(world)
	world.spawn_at(home)
	var nearby := _beast(world, home + Vector2i(0, -2))
	world.wilds.append(nearby)
	# Hold the field still during the real battle; an existing pursuer must forget the player on return.
	world.busy = true
	nearby["state"] = "chase"
	world._set_mark(nearby, "!", world.MARK_SPOTTED)
	Engine.time_scale = 12.0
	var result: String = await main.start_battle({"wild": true, "foes": [Beasts.create(27, 1)], "seed": 7, "autoplay": true})
	Engine.time_scale = 1.0
	_check(result == "win", "a real wild battle ends in victory")
	_check(is_equal_approx(GameState.wild_grace_left, 3.0), "return grants three full seconds after the fade")
	_check(GameState.wild_grace_pulse, "wild victory enables the opacity pulse")
	world.busy = false
	world._update_wilds(0.0)
	_check(nearby["state"] == "wander" and not nearby["mark"].visible, "an existing chase and its mark are cleared")
	_check(not world._wild_sees(nearby), "a beast looking straight at the player cannot see them")
	world.moving = true
	world.move_speed = 7.8
	_check(not world._wild_sees(nearby), "running cannot be heard during protection")
	world.moving = false
	# Direct contact uses the same encounter guard as a chase reaching the player.
	world._bump_wild(nearby)
	world._wild_encounter(nearby, "ambush")
	_check(not main.in_battle and not world.busy, "contact and an ambush cannot start another battle")
	for state in ["alert", "flee", "search"]:
		nearby["state"] = state
		world._set_mark(nearby, "!")
		world._update_wilds(0.0)
		_check(nearby["state"] == "wander" and not nearby["mark"].visible, "%s also returns to roaming" % state)
	# Keep this beast in sight for the expiry check, without random wandering moving it away.
	nearby["t"] = 99.0
	if opts.get("preview", "") == "pulse":
		_clear_wilds(world)
		UI.auto = false
		while main.is_inside_tree():
			await main.get_tree().process_frame
			if GameState.wild_grace_left <= 0.0:
				await main._wait(1.0)
				GameState.wild_grace_left = GameState.WILD_BATTLE_GRACE
		return
	_check_opacity(world)
	var captured := {"low": false, "middle": false, "high": false}
	var elapsed := 0.0
	UI.auto = false
	while elapsed < 3.3 and GameState.wild_grace_left > 0.0:
		await main.get_tree().process_frame
		elapsed += main.get_process_delta_time()
		_check_silent(world.player.visible, "the protected player must never disappear")
		var opacity: float = world._player_grace_material.get_shader_parameter("opacity")
		if GameState.wild_grace_left > 0.1:
			_check_silent(not world._wild_sees(nearby), "detected before grace expired")
		var phase := "low" if opacity <= 0.39 else ("high" if opacity >= 0.76 else "middle")
		if opts.has("shot") and not captured[phase] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var path := String(opts["shot"])
			main._save_shot(path.get_basename() + "_" + phase + ".png")
			captured[phase] = true
	_check(GameState.wild_grace_left == 0.0 and _is_opaque(world), "expiry restores the player's opaque materials")
	if opts.has("shot") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]).get_basename() + "_opaque.png")
		_check(captured.values().all(func(done): return done), "captures show three distinct pulse phases")
	_check(elapsed >= 2.9 and elapsed < 3.3, "protection lasts three seconds of field time (%.2fs)" % elapsed)
	_check(world._wild_sees(nearby), "normal detection returns after expiry")
	# Pause semantics and map handoff are checked with an active, partially used countdown.
	world.busy = true
	GameState.wild_grace_left = 1.25
	world._update_wild_grace(0.5)
	var paused_opacity: float = world._player_grace_material.get_shader_parameter("opacity")
	_check(GameState.wild_grace_left == 1.25, "field interactions pause the countdown")
	world.busy = false
	world.frozen = true
	world._update_wild_grace(0.5)
	_check(GameState.wild_grace_left == 1.25, "frozen field movement pauses the countdown")
	world.frozen = false
	UI.push(load("res://scripts/ui/modal.gd").new())
	world._update_wild_grace(0.5)
	_check(GameState.wild_grace_left == 1.25, "an open menu pauses the countdown")
	_check(world._player_grace_material.get_shader_parameter("opacity") == paused_opacity, "paused protection also holds the opacity pulse")
	UI.pop(UI.stack.back())
	UI.auto = true
	await main._go("caccoon", "start")
	_check(GameState.wild_grace_left > 1.1, "remaining protection follows the player across maps")
	_check(not _is_opaque(main.world) and main.world.player.visible, "a new map immediately applies the remaining opacity effect")
	# End-to-end battle return paths: escaping, capture (a win), and defeat all use the wild flag.
	for outcome in ["run", "win", "lose", "forfeit"]:
		var wild: bool = outcome != "forfeit"
		main.world.busy = true
		Engine.time_scale = 12.0
		var force_result := func():
			for child in main.view.get_children():
				if child.get_script() == load(main.BATTLE_PATH):
					child.result = outcome
		main.get_tree().process_frame.connect(force_result)
		result = await main.start_battle({"wild": wild, "foes": [Beasts.create(27, 1)], "seed": 8,
			"autoplay": true, "trainer": {"name": "Tess", "cls": "Tester", "team": []}})
		main.get_tree().process_frame.disconnect(force_result)
		Engine.time_scale = 1.0
		_check(result == outcome, "battle return handles %s" % outcome)
		_check(GameState.wild_grace_left == (3.0 if wild else 0.0), "%s %s grants the expected protection" % ["wild" if wild else "trainer", outcome])
		main.world._update_wild_grace(0.0)
		_check(GameState.wild_grace_pulse == (wild and outcome == "win") and _is_opaque(main.world) == (outcome != "win"), "%s returns %s" % [outcome, "with the opacity pulse" if outcome == "win" else "fully opaque"])
		main.world.busy = false
		if outcome == "lose":
			await main._settle("caccoon")
			_check(GameState.wild_grace_left > 2.3, "wild defeat carries protection to the Beast Center")
			_check(_is_opaque(main.world), "return to the Beast Center after defeat stays fully opaque")
			if opts.has("shot") and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				main._save_shot(String(opts["shot"]).get_basename() + "_defeat.png")
	# A trainer victory must also clear any previous wild protection.
	main.world.busy = true
	GameState.wild_grace_left = 1.5
	Engine.time_scale = 12.0
	result = await main.start_battle({"wild": false, "foes": [Beasts.create(27, 1)], "seed": 9, "autoplay": true,
		"trainer": {"name": "Tess", "cls": "Tester", "shield": 0, "team": []}})
	Engine.time_scale = 1.0
	main.world.busy = false
	main.world._update_wild_grace(0.0)
	_check(result == "win" and GameState.wild_grace_left == 0.0 and _is_opaque(main.world), "trainer victory grants no opacity pulse or detection immunity")
	GameState.wild_grace_left = 1.0
	GameState.wild_grace_pulse = true
	GameState.new_game("Tester")
	_check(GameState.wild_grace_left == 0.0 and not GameState.wild_grace_pulse, "new or loaded games start without transient protection")
	UI.auto = false
	print("WILD GRACE DONE: %d problem(s)" % bad)


func _check_opacity(world) -> void:
	var remaining: float = GameState.wild_grace_left
	world.busy = true
	var bounded := true
	var smooth := true
	var shades := {}
	var previous := -1.0
	for i in 300:
		GameState.wild_grace_left = 3.0 - i * 0.01
		world._update_wild_grace(0.0)
		var opacity: float = world._player_grace_material.get_shader_parameter("opacity")
		bounded = bounded and opacity >= 0.35 and opacity <= 0.8 and world.player.visible
		smooth = smooth and (previous < 0.0 or absf(opacity - previous) < 0.05)
		shades[roundi(opacity * 100.0)] = true
		previous = opacity
	_check(bounded, "the entire protection pulse stays visible and strictly below full opacity")
	_check(smooth and shades.size() > 10, "opacity transitions through many intermediate shades without flashing")
	_check(world._player_meshes.all(func(mesh): return mesh.material_override == world._player_grace_material), "all player parts use the same isolated fading material")
	_check(world._player_material.shader == world.Townfolk.SHADER, "the shared opaque material is unchanged")
	GameState.wild_grace_left = remaining
	world.busy = false
	world._update_wild_grace(0.0)


func _is_opaque(world) -> bool:
	return world.player.visible and world._player_meshes.all(func(mesh): return mesh.material_override == world._player_material)


func _open_patch(world) -> Vector2i:
	var candidates: Array = world._wild_cands.duplicate()
	var center := Vector2(world.map["w"], world.map["h"]) * 0.5
	candidates.sort_custom(func(a, b): return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	for q in candidates:
		if world._walkable(q) and world._wild_free(q + Vector2i(0, -1), {}, q) \
				and world._wild_free(q + Vector2i(0, -2), {}, q + Vector2i(0, -1)):
			return q
	_check(false, "a clear patch exists for sight and hearing checks")
	return world.player_pos


func _beast(world, pos: Vector2i) -> Dictionary:
	var w := {"beasts": [Beasts.create(27, 12)], "pos": pos, "home": pos, "facing": Vector2i(0, 1),
		"state": "wander", "t": 99.0, "moving": false, "from": world.tile_pos(pos), "to": world.tile_pos(pos),
		"mt": 0.0, "speed": world.WILD_WANDER_SPEED, "lost": 0.0, "phase": 0.0}
	world._make_wild_node(w)
	return w


func _clear_wilds(world) -> void:
	for w in world.wilds:
		w["node"].queue_free()
	world.wilds.clear()
	world._wild_target = 0


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	_check_silent(ok, label)


func _check_silent(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		push_error(label)
