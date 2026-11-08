extends RefCounted
## Fresh-state reward regression and windowed cinematic previews; never reads or writes saves.
const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const Film = preload("res://scripts/ui/beast_cinematic.gd")
const Fixture = preload("res://tools/debug/growth_battle_fixture.gd")
const HatcheryStage = preload("res://scripts/gfx/hatchery_stage.gd")
var bad := 0


func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok:
		bad += 1


func run(main, opts: Dictionary) -> void:
	var preview := String(opts.get("preview", ""))
	if preview != "":
		await _preview(main, opts, preview)
		return
	UI.auto = true
	await _check_hatchery(main)
	var signatures := {}
	for race in EggLooks.SHELLS:
		var egg := {"race": race}
		var look := EggLooks.look(egg)
		var key := str([look.shell, look.mark, look.motif, look.width, look.crown])
		check(not signatures.has(key), "%s has a unique shell" % EggLooks.name_for(egg))
		signatures[key] = true
		check(RaceDB.race_name(race) in EggLooks.name_for(egg), "egg names its hatchling")
	check(EggLooks.name_for({"race": 2, "kind": "fire"}) == "Embit Egg", "old higher-form egg names its first form")
	check(EggLooks.name_for({"race": 0, "kind": "ghost"}) == "Shadow Embit Egg", "shadow name keeps species")
	check(EggLooks.name_for({"race": 39, "kind": "legendary"}) == "Radiant Abyssion Egg", "radiant name keeps species")
	for race in RaceDB.STARTERS:
		check(not RaceDB.is_legendary(race) and RaceDB.stage(race) == 1, "starter restriction is unchanged")
	var b := Beasts.create(0, 1)
	b.hp = 1
	b.mp = 0
	b.gain_xp(1)
	check(b.hp == 1 and b.mp == 0, "XP without a level does not heal")
	b.gain_xp(b.xp_for_level(2) - b.xp)
	check(b.level == 2 and b.hp == b.max_hp() and b.mp == b.max_mp(), "level fully restores HP and MP")
	b.nickname = "Pebble"
	b.hp = 0
	b.mp = 0
	b.evolve(1)
	check(b.nickname == "Pebble" and b.hp == b.max_hp() and b.mp == b.max_mp(), "direct evolution restores both pools and preserves a nickname")
	var jumper := Beasts.create(0, 19)
	var events: Array = jumper.gain_xp(jumper.xp_for_level(40) - jumper.xp)
	var evos: Array = events.filter(func(e): return e.type == "evolve")
	check(evos.size() == 2 and evos[0].before.race == 0 and evos[0].after.race == 1
		and evos[1].before.race == 1 and evos[1].after.race == 2, "large XP award retains each evolution's actual two forms")
	check(jumper.hp == jumper.max_hp() and jumper.mp == jumper.max_mp(), "multiple levels heal to the final form's maxima")
	GameState.party = []
	GameState.storage = []
	GameState.eggs = []
	for race in [0, 24, 12, 30]:
		GameState.add_egg(race)
	UI.auto_answers = [0, 0, 0, 0]
	UI.auto_log.clear()
	await Places.hatchery()
	check(GameState.party.size() == 3 and GameState.storage.size() == 1 and GameState.eggs.is_empty(), "every egg hatches including overflow to storage")
	check(UI.auto_log.filter(func(s): return String(s).begins_with("[cinematic] hatch")).size() == 4, "each hatch plays a cinematic")
	var battle := Fixture.new()
	main.add_child(battle)
	var one := Beasts.create(0, 19)
	var two := Beasts.create(24, 1)
	GameState.party = [one, two]
	var foe := Beasts.create(30, 20)
	one.hp = 1
	one.mp = 0
	two.hp = 1
	two.mp = 0
	one.xp = one.xp_for_level(20) - 1
	battle.participants = {one: true, two: true}
	battle._award_xp(foe)
	check(one.level == 19 and two.level == 1 and one.hp == 1 and two.mp == 0,
		"defeating a foe queues XP without growing or healing during the fight")
	UI.auto_log.clear()
	await battle._finish_growth()
	var films: Array = UI.auto_log.filter(func(s): return String(s).begins_with("[cinematic]"))
	check(films.size() >= 3 and films[0] == "[cinematic] level Embit" and films[1] == "[cinematic] evolve Cinderex"
		and String(films[2]).ends_with("Clawlet"), "end-of-battle sequences finish one beast before the next")
	check(one.hp == one.max_hp() and one.mp == one.max_mp() and two.hp == two.max_hp() and two.mp == two.max_mp(),
		"all beasts that grew end with full HP and MP")
	check(battle.pending_xp.is_empty(), "rewards drain once")
	var count := UI.auto_log.size()
	await battle._finish_growth()
	check(UI.auto_log.size() == count, "drained rewards cannot repeat their films")
	battle.queue_free()
	if opts.get("verify_ui", "0") == "1":
		await _verify_ui(main)
	print("BEAST GROWTH DONE: %d problem(s)" % bad)


func _check_hatchery(main) -> void:
	var stage := HatcheryStage.new()
	main.add_child(stage)
	stage.build()
	var triangles := 0
	var textured := true
	for mi in stage.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.mesh.resource_path).begins_with("res://assets/interiors/hatch_"):
			continue
		for surface in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var mat = mi.mesh.surface_get_material(surface)
			textured = textured and mat is StandardMaterial3D and mat.albedo_texture != null \
				and mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	check(textured, "all imported chamber, platform and core surfaces retain smoothly filtered textures")
	check(triangles <= 125000, "complete hatchery geometry stays inside its isolated-scene budget (%d triangles)" % triangles)
	for race in EggLooks.SHELLS:
		var egg := {"race": race}
		stage.fit_shell(egg)
		stage.animate(3.95, true, false)
		var touching := true
		var width: float = EggLooks.look(egg).width
		for i in 3:
			var tip: Vector3 = stage.joints[i].to_global(stage.contact_points[i])
			var h := tip.y - stage.DECK_Y
			var shell_r := 0.52 * width * (1.0 - h / 1.38 * 0.22) * sqrt(maxf(0, 1.0 - pow((h - 0.69) / 0.69, 2)))
			touching = touching and absf(Vector2(tip.x, tip.z).length() - shell_r) < 0.035 and h > 0.5 and h < 1.0
		check(touching, "all three actual TCM tong tips touch the %s shell" % EggLooks.name_for(egg))
	check((-stage.spotlight.global_basis.z).dot(Vector3.DOWN) > 0.999 and stage.spotlight.light_energy > 0 \
		and is_zero_approx(stage.spotlight.global_position.x) and is_zero_approx(stage.spotlight.global_position.z),
		"central core light shines down onto the egg")
	check(stage.environment.fog_enabled and stage.environment.fog_density > 0, "chamber has renderer-compatible fog")
	stage.animate(7.4, true, true)
	var clear := true
	for i in 3:
		clear = clear and stage.joints[i].to_global(stage.contact_points[i]).y > stage.DECK_Y + 2.0
	check(clear and not stage.beam.visible, "core retracts and switches off the shaft before the beast reveal")
	stage.queue_free()
	await main.get_tree().process_frame


func _starter_menu(main) -> void:
	Story._elder(null, {})
	for i in 20:
		await main._wait(0.15)
		if not UI.stack.is_empty() and UI.stack.back() is UI.ListMenu:
			break
		await main._press("ui_accept")
	await main._wait(0.25)


func _verify_ui(main) -> void:
	UI.auto = false
	GameState.eggs = []
	GameState.set_flag("got_egg", false)
	await _starter_menu(main)
	var menu = UI.stack.back()
	check(menu is UI.ListMenu and menu.items.size() == 4, "real starter chooser has exactly four named eggs")
	for button in menu.buttons:
		check(button.size.y >= (80 if UI.is_touch() else 56), "starter tap target meets the platform minimum")
		check(menu.get_viewport_rect().encloses(button.get_global_rect()), "starter row stays inside the viewport")
	await main._press("ui_down")
	check(menu._focus == 1, "d-pad focuses the next named egg")
	await main._tap_at(menu.buttons[3].get_global_rect().get_center())
	await main._wait(0.25)
	check(UI.stack.back() is UI.ConfirmPrompt and GameState.eggs.is_empty(), "one row tap opens confirmation without taking an egg")
	await main._press("ui_cancel")
	await main._wait(0.25)
	check(GameState.eggs.is_empty() and UI.stack.back() is UI.ListMenu, "B declines and returns to egg selection")
	menu = UI.stack.back()
	await main._tap_at(menu.buttons[1].get_global_rect().get_center())
	await main._wait(0.25)
	await main._press("ui_accept")
	await main._wait(0.25)
	check(GameState.eggs.size() == 1 and GameState.eggs[0].race == 24, "A takes only the confirmed Clawlet egg")
	UI.auto = true
	UI.stack.back().close()
	await main._wait(0.3)
	UI.auto = false
	var original_update: int = main.view.render_target_update_mode
	Places.hatchery()
	await main._wait(0.25)
	menu = UI.stack.back()
	await main._tap_at(menu.buttons[0].get_global_rect().get_center())
	await main._wait(0.3)
	var film = UI.stack.back()
	check(film is Film and film.kind == "hatch" and film.egg.race == 24, "real hatchery opens the selected species' cinematic")
	check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "cinematic avoids rendering the hidden world a second time")
	await main._press("ui_accept")
	await main._press("ui_cancel")
	await main._tap_at(film.size * 0.5)
	check(UI.stack.back() == film and not film.closed, "A, B and a scene tap cannot skip or leak through the cinematic")
	await main._press("pause")
	var held: float = film.elapsed
	await main._wait(0.2)
	check(main.get_tree().paused and is_equal_approx(film.elapsed, held), "Pause freezes the hatch timeline")
	await main._press("pause")
	await main._wait(0.1)
	check(not main.get_tree().paused and film.elapsed > held, "Pause resumes the hatch timeline")
	film.elapsed = film.duration - 0.02
	await film.done
	UI.auto = true
	await main._wait(0.2)
	if not UI.stack.is_empty():
		UI.stack.back().close()
	await main._wait(0.2)
	check(GameState.eggs.is_empty() and UI.stack.is_empty(), "hatch consumes exactly one egg and returns cleanly")
	check(main.view.render_target_update_mode == original_update, "hatch restores the world's viewport updates")
	UI.auto = false
	for race in EggLooks.SHELLS:
		GameState.add_egg(race)
	GameState.add_egg(36, true)
	Places.hatchery()
	await main._wait(0.25)
	menu = UI.stack.back()
	for i in menu.items.size() - 1:
		await main._press("ui_down")
	await main._wait(0.25)
	var last = menu.buttons.back()
	check(menu._focus == menu.items.size() - 1 and menu._scroll.scroll_vertical > 0,
		"long egg inventory scrolls the selected species into view")
	check(menu._scroll.get_global_rect().intersects(last.get_global_rect()) and last.text == "Shadow Berrypuff Egg",
		"long species name remains visible at the end of the egg inventory")
	await main._tap_at(last.get_global_rect().get_center())
	await main._wait(0.2)
	film = UI.stack.back()
	check(film is Film and film.egg.race == 36 and film.egg.ghost, "a scrolled egg row directly hatches the chosen Shadow species")
	film.elapsed = film.duration
	await film.done
	UI.auto = true
	await main._wait(0.15)
	if not UI.stack.is_empty():
		UI.stack.back().close()
	await main._wait(0.2)
	GameState.eggs = []
	# Exercise the real sequential reward presenter with visible films, including multiple party members.
	var battle := Fixture.new()
	main.add_child(battle)
	var one := Beasts.create(0, 19)
	var two := Beasts.create(30, 3)
	GameState.party = [one, two]
	battle.pending_xp = {one: one.xp_for_level(20) - one.xp, two: two.xp_for_level(4) - two.xp}
	UI.auto = false
	var finished := [false]
	var reward := func():
		await battle._finish_growth()
		finished[0] = true
	reward.call()
	var seen := []
	var seen_films := {}
	for i in 300:
		await main.get_tree().process_frame
		if not UI.stack.is_empty() and UI.stack.back() is Film:
			var current = UI.stack.back()
			if current.elapsed > 0.15 and not seen_films.has(current.get_instance_id()):
				seen_films[current.get_instance_id()] = true
				seen.append(current.kind + ":" + String(current.after.name))
				current.elapsed = current.duration
		if finished[0]:
			break
	check(finished[0] and seen == ["level:Embit", "evolve:Cinderex", "level:Hootlet"],
		"rendered reward queue shows each beast and each evolution once, in order: %s" % str(seen))
	battle.queue_free()


func _preview(main, opts: Dictionary, mode: String) -> void:
	UI.auto = false
	if mode == "starters":
		await _starter_menu(main)
	elif mode == "eggs":
		GameState.eggs = []
		for race in EggLooks.SHELLS:
			GameState.add_egg(race)
		GameState.add_egg(36, true)
		Places.hatchery()
		await main._wait(0.3)
		for i in int(opts.get("downs", "0")):
			await main._press("ui_down")
		await main._wait(0.3)
	else:
		var race := int(opts.get("race", "0"))
		var b := Beasts.create(race, 1 if mode == "hatch" else (19 if mode == "evolve" else 4), opts.get("ghost", "0") == "1")
		var before := b.growth_look()
		if mode == "evolve":
			b.gain_xp(b.xp_for_level(20) - b.xp)
		elif mode == "level":
			b.gain_xp(b.xp_for_level(5) - b.xp)
		var egg := {"race": race, "kind": "legendary" if RaceDB.is_legendary(race) else RaceDB.element(race), "ghost": b.ghost}
		var film := Film.new().setup(mode, before, b.growth_look(), egg)
		if opts.has("at"):
			film.preview_time = float(opts.at)
		UI.push(film)
		if not opts.has("at"):
			if opts.has("shots"):
				var times := [0.6, 2.7, 3.8, 4.9, 5.7, 7.5] if mode == "hatch" else [0.4, 2.7, 4.0, 5.5]
				var frame := 0
				while is_instance_valid(film) and not film.closed:
					await main.get_tree().process_frame
					if not is_instance_valid(film):
						break
					if frame < times.size() and film.elapsed >= float(times[frame]):
						await RenderingServer.frame_post_draw
						main._save_shot(String(opts.shots) + "_%d.png" % frame)
						frame += 1
			else:
				await film.done
		await main._wait(0.5)
		if opts.get("perf", "0") == "1" and opts.has("at"):
			var samples := PackedFloat64Array()
			for i in 120:
				await main.get_tree().process_frame
				samples.append(main.get_process_delta_time() * 1000)
			samples.sort()
			print("HATCHERY PERF: median %.2f ms, p95 %.2f ms, %d draws, %d primitives" % [samples[60], samples[114],
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if opts.has("shot"):
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts.shot))
	if opts.get("quit", "1") == "0":
		await main.get_tree().create_timer(3600).timeout
