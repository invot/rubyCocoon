extends RefCounted
## Windowed surround survey and reproducible frame timing. Headless runs check geometry/shot safety only.
const Fixture = preload("res://tools/debug/battle_stage_fixture.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const Backdrop = preload("res://scripts/battle/backdrop.gd")
const Director = preload("res://scripts/battle/battle_camera.gd")
const Visibility = preload("res://scripts/battle/scenery_visibility.gd")
var bad := 0


func _entrance(map_id: String, shop: String) -> String:
	# The earth temple is deliberately absent before the ritual. Audit its revealed building.
	for building in MapLoader.load_map(map_id, {"ritual_done": true})["buildings"]:
		if building["shop"] == shop:
			return String(building["interior"])
	return ""

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])


func run(main: Node) -> void:
	Engine.time_scale = 1.0
	GameState.party = [Beasts.create(0, 20), Beasts.create(3, 20), Beasts.create(30, 20)]
	GameState.beast_slots = 3
	for i in 3:
		GameState.party[i].slot = [7, 0, 1][i]
	if main.world != null and main.world.get_parent() == main.view:
		main.view.remove_child(main.world)
	var settings := []
	for id in WorldDB.BIOMES:
		var map_id := "route1"
		for candidate in WorldDB.ROUTES.keys() + WorldDB.TOWNS.keys():
			if WorldDB.biome_of(candidate)["id"] == id:
				map_id = candidate
				break
		settings.append({"label": id, "map": map_id, "biome": id})
	settings.append({"label": "fishing", "map": "route1", "fishing": true})
	settings.append({"label": "arena", "map": MapLoader.interior_of("tidewater", "arena"), "arena": true})
	for tk in WorldDB.TEMPLES:
		var temple: Dictionary = WorldDB.TEMPLES[tk]
		var entrance := _entrance(temple["route"], "cathedral" if tk == "ghost" else "temple")
		var floor_no := 2 if tk == "ghost" else 1
		if temple.has("rooms"):
			floor_no = temple["rooms"].find(temple["room"]) + 1
		settings.append({"label": "temple_" + tk, "map": MapLoader.floor_id(entrance, floor_no)})
	for floor_no in range(1, 5):
		settings.append({"label": "tower_%d" % floor_no, "map": MapLoader.floor_id(MapLoader.interior_of("cogsworth", "ceo_tower"), floor_no)})
	for floor_no in [1, 2]:
		settings.append({"label": "sky_tower_%d" % floor_no, "map": MapLoader.floor_id(MapLoader.interior_of("tidewater", "skytower"), floor_no)})
	var only := String(main._test.get("setting", ""))
	var shots := String(main._test.get("shots", ""))
	var report := {}
	for setting in settings:
		var label: String = setting["label"]
		if only != "" and label not in only.split(","):
			continue
		var battle := Fixture.new()
		var config := {"wild": bool(setting.get("fishing", false)), "map": setting["map"], "foes": [Beasts.create(12, 20), Beasts.create(15, 20)],
			"trainer": {"name": "Tess", "cls": "Tester"}, "seed": 7,
			"fishing": setting.get("fishing", false), "arena": setting.get("arena", false)}
		battle.setup(config)
		if main.world != null:
			main.world.map = MapLoader.load_map(setting["map"], {"ritual_done": true})
		if setting.has("biome"):
			battle.biome = WorldDB.BIOMES[setting["biome"]].duplicate()
			battle.biome["id"] = setting["biome"]
		main.view.add_child(battle)
		await main._wait(1.8)
		if main._test.get("profile", "0") == "1":
			await main._wait(1.5)
			var samples: Array[float] = []
			var cpu: Array[float] = []
			var last := Time.get_ticks_usec()
			for i in int(main._test.get("frames", "240")):
				await main.get_tree().process_frame
				var now := Time.get_ticks_usec()
				samples.append((now - last) / 1000.0)
				cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				last = now
			samples.sort()
			cpu.sort()
			report[label] = {"frames": samples.size(), "median_ms": samples[samples.size() / 2],
				"p95_ms": samples[int(samples.size() * 0.95)], "cpu_median_ms": cpu[cpu.size() / 2],
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"renderer": RenderingServer.get_current_rendering_method(), "touch": UIKit.touch_ui(),
				"window": str(main.get_window().size), "platform": OS.get_name()}
			print("BATTLE FRAME TIME ", label, " ", JSON.stringify(report[label]))
		await _verify(main, battle, label, shots)
		if main._test.get("hold", "0") == "1":
			return # --quit=0 keeps this isolated reverse-angle view open for inspection.
		# HUDs live in UI.hud rather than under the stage, just as normal _finish() cleans them up.
		battle.hud.queue_free()
		main.view.remove_child(battle)
		battle.queue_free()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
	var report_path := String(main._test.get("report", ""))
	if report_path != "":
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("BATTLE STAGE DONE: %d problem(s)" % bad)


func _capture(main: Node, path: String) -> void:
	if path == "":
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	await RenderingServer.frame_post_draw
	main._save_shot(path)


func _verify(main: Node, battle: Node3D, label: String, shots: String) -> void:
	var prefix := shots + "/" + label if shots != "" else ""
	if label.begins_with("temple_"):
		_check(battle.indoor, label + " uses its real interior")
	await _capture(main, prefix + "_choose.png" if prefix != "" else "")
	_check(battle.indoor or battle.surround != null, label + " has a complete shell or surround")
	_check(Backdrop.mesh() == Backdrop.mesh(), "surround reuses cached geometry")
	var shadows := 0
	for child in battle.get_children():
		if child is SubViewport or child == battle.player_rig or child == battle.rival_rig or child in battle.nodes.values():
			continue
		var geometry := child.find_children("*", "GeometryInstance3D", true, false)
		if child is GeometryInstance3D:
			geometry.append(child)
		for mesh in geometry:
			shadows += int(mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				print("scenery shadow: ", mesh.get_path())
	_check(shadows == 0, label + " scenery adds no shadow casters")
	_visibility_probe(battle, label)
	if main._test.get("survey", "0") == "1":
		battle._commanding = false
		battle._set_acting(null)
		battle.camera_director.play("victory")
		await main._wait(0.65)
		await _capture(main, prefix + "_victory.png" if prefix != "" else "")
		await _survey(main, battle, label, prefix)
		return
	var director = battle.camera_director
	var seen := []
	var listener := func(name): seen.append(name)
	director.shot_changed.connect(listener)
	# Real action dispatch, including retargeting, must drive attacker -> follow -> reaction.
	if main._test.get("events", "1") == "1":
		battle._commanding = false
		var victim = battle.foe_slots.filter(func(b): return b != null)[0]
		battle._st(victim)["stages"]["eva"] = -6
		await battle._resolve([{"type": "slingshot", "target": victim, "prio": 9}])
		await main._wait(0.7)
		_check(seen.has("attacker") and seen.has("follow") and seen.has("reaction"), label + " real attack drives the director")
	# Every named shot is finite and enclosed; rapidly arriving requests coalesce without flicker.
	var beast = GameState.party[0]
	for name in ["capture", "knockout", "victory", "return", "cast", "impact"]:
		director.play(name, beast if name in ["capture", "knockout", "cast", "impact"] else null)
		await main._wait(0.6)
		_check(seen.has(name), label + " has a " + name + " shot")
		_check(battle.cam.position.is_equal_approx(director.constrain(battle.cam.position)), label + " " + name + " stays enclosed")
		await _capture(main, prefix + "_" + name + ".png" if prefix != "" and name == "victory" else "")
	battle.summon_cam(battle.FOE_CENTER + Vector3(-4, 0, 0), 30.0)
	await main._wait(0.7)
	_check(director.shot == "summon" and battle.cam.position.is_equal_approx(director.constrain(battle.cam.position)), label + " largest summon stays within the shell")
	battle.summon_release()
	await main._wait(0.6)
	_check(director.shortest_gap >= Director.MIN_SHOT_TIME - 0.001, label + " never changes shots twice within half a second")
	await _survey(main, battle, label, prefix)
	director.shot_changed.disconnect(listener)


func _survey(main: Node, battle: Node3D, label: String, prefix: String) -> void:
	# Inspect all four sides, including the normally unseen side behind the shoulder camera.
	# Freeze only this fixture's director; these survey views are not extra gameplay shots.
	battle.set_process(false)
	battle._select_hud_actor("trainer_self")
	var row: Dictionary = battle._panel_rows()[0]
	battle._show_option(row, row["options"][0])
	for angle in 4:
		var turn := float(angle) * PI * 0.5
		battle.cam.position = Vector3(cos(turn) * 18.0, 7.5, 1.5 + sin(turn) * 18.0)
		battle.cam.fov = 40.0
		battle.cam.look_at(battle._cam_look(), Vector3.UP)
		battle.scenery_visibility.update()
		if battle.indoor and not battle.cfg.get("arena", false) and angle == 3:
			_check(battle.scenery_visibility.hidden_count > 0, label + " foreground columns are hidden from the reverse angle")
		battle._sync_front_cam()
		await main._wait(0.08)
		battle.floating.layout()
		var rect: Rect2 = battle.floating.menu_rect
		_check(UIKit.safe_rect(battle.hud).encloses(rect) and rect.position.y >= UI.top_bar.get_global_rect().end.y,
			label + " angle %d keeps the menu and top bar clear" % angle)
		if UIKit.touch_ui():
			for group in UI.controls.CLUSTERS:
				var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
				_check(not rect.intersects(zone), label + " survey keeps touch clusters clear")
		await _capture(main, prefix + "_angle%d.png" % angle if prefix != "" else "")


func _visibility_probe(battle: Node3D, label: String) -> void:
	var original: Transform3D = battle.cam.global_transform
	var probe := MultiMeshInstance3D.new()
	probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Exercise the actual cached column geometry on every renderer.
	mm.mesh = battle.VA.mesh("stone_pillar")
	var size: float = battle.VA.fit_scale("stone_pillar", 8.0)
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
	mm.instance_count = 2
	var transforms := [Transform3D(basis, original.origin.lerp(battle.PLAYER_POS + Vector3.UP, 0.5)), Transform3D(basis, Vector3(-40, 0, -40))]
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	probe.multimesh = mm
	battle.add_child(probe)
	var visibility := Visibility.new(battle)
	visibility.register(probe, transforms)
	visibility.update()
	_check(mm.visible_instance_count == 1, label + " hides the blocking instance while retaining its batch sibling (%d visible)" % mm.visible_instance_count)
	battle.cam.global_position = battle.PLAYER_POS + Vector3(0, 8, -24)
	battle.cam.look_at(battle.PLAYER_POS + Vector3.UP, Vector3.UP)
	visibility.update()
	_check(mm.visible_instance_count == 2, label + " restores scenery when the camera clears it (%d visible)" % mm.visible_instance_count)
	battle.cam.global_transform = original
	probe.free()
