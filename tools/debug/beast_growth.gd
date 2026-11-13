extends RefCounted
## Fresh-state reward regression and windowed cinematic previews; never reads or writes saves.
const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const Film = preload("res://scripts/ui/beast_cinematic.gd")
const Fixture = preload("res://tools/debug/growth_battle_fixture.gd")
const HatcheryStage = preload("res://scripts/gfx/hatchery_stage.gd")
const EggModel = preload("res://scripts/gfx/egg_model.gd")
var bad := 0


## Holds the real mouse back during a scripted tap-through: moved between a tap's press and release, it would pull the
## press off its button, and a hover would take the focus from the row being tested.
class PointerShield extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()


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
	await _check_merge_altar()
	await _check_merge_film(main)
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
	await _check_reward_confirmation(main)
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
			var shell_r := EggModel.radius_at(h, width)
			touching = touching and absf(Vector2(tip.x, tip.z).length() - shell_r) < 0.035 and h > 0.5 and h < 1.0
		check(touching, "all three actual TCM tong tips touch the %s shell" % EggLooks.name_for(egg))
	var plain := true
	for joint in stage.joints:
		for mi in joint.find_children("*", "MeshInstance3D", true, false):
			plain = plain and mi.layers == stage.TONG_LAYER and mi.material_override == null
			for surface in mi.mesh.get_surface_count():
				plain = plain and not mi.mesh.surface_get_material(surface).emission_enabled
	check(plain and (stage.spotlight.light_cull_mask & stage.TONG_LAYER) == 0,
		"tongs stay plain metal: they never emit and the core's inner light leaves them out")
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
	var look := Beasts.create(0, 1).growth_look()
	var hatch_film = Film.new().setup("hatch", look, look, {"race": 0})
	var evolve_film = Film.new().setup("evolve", look, look)
	main.add_child(hatch_film)
	main.add_child(evolve_film)
	await main.get_tree().process_frame
	check(hatch_film._set.get_node("Roundels").visible and not hatch_film._set.get_node("Room").visible, "a hatch plays in the roundel chamber")
	var hatch_core: MeshInstance3D = hatch_film._set.core.get_child(0)
	check(hatch_core.get_surface_override_material(0).resource_name.begins_with("steel") and not String(hatch_core.mesh.resource_path).contains("steel_"), "its core keeps full detail, in the chamber's steel paint")
	check(not evolve_film._set.has_node("Roundels") and evolve_film._set.get_node("Room").visible, "an evolution stays in the stone vault")
	hatch_film.queue_free()
	evolve_film.queue_free()
	await main.get_tree().process_frame


func _check_merge_altar() -> void:
	GameState.party = [Beasts.create(0, 40), Beasts.create(30, 40)]
	GameState.storage = []
	UI.auto_answers = [0, 0, 0]
	UI.auto_log.clear()
	await Places.merge_altar(false)
	check(GameState.party.size() == 1 and GameState.party[0].rank == 2, "the merge altar leaves one Rank 2 beast")
	check(UI.auto_log.filter(func(s): return String(s).begins_with("[cinematic] merge")).size() == 1, "a merge plays its cinematic once")
	GameState.party = []


## The real film, timed through its own animations: what happens when, and that input can't disturb it.
func _check_merge_film(main) -> void:
	UI.auto = false
	var a := Beasts.create(0, 40)
	var b := Beasts.create(30, 40)
	var child := Beasts.merge(a, b, true)
	var original_update: int = main.view.render_target_update_mode
	var finished := [false]
	var play := func():
		await main.trigger_merge_cinematic(a.growth_look(), b.growth_look(), child.growth_look())
		finished[0] = true
	play.call()
	var film = UI.stack.back()
	check(film is Node2D and film.scene_file_path == "res://scenes/MergeCinematic.tscn", "merging opens MergeCinematic.tscn with a Node2D root")
	check(main.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the merge film avoids rendering the hidden world")
	var stage: Node = film.get_node("Viewport3D/Stage")
	var light: Node3D = stage.get_node("LightCylinder")
	var rig: Node3D = stage.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera")
	var one = stage.get_node("Beast1")
	var two = stage.get_node("Beast2")
	var reveal = stage.get_node("MergedBeast")
	var fill: Sprite2D = film.get_node("ScreenFill")
	var beam: AnimationPlayer = film.get_node("BeamPlayer")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(camera.size, 14.0), "camera is orthographic at zoom 0.5")
	var back_count: int = stage.find_children("BackPlatform*", "Node3D", true, false).size()
	var core_count: int = stage.find_children("HangingCore*", "Node3D", true, false).size()
	check(back_count == 2 and core_count == 3, "the parents stand on two background platforms and a core hangs over each of the three platforms (%d, %d)" % [back_count, core_count])
	check(is_equal_approx(reveal.position.y, -2.0) and one.position.z < reveal.position.z - 8.0 and two.position.z < reveal.position.z - 8.0, "the child's deck is at Y=-2, with the parents far behind it")
	var back_deck: float = film.CENTER_Y - HatcheryStage.DECK_Y * film.STAGE_SCALE * (1.0 - film.BACK_SIZE)
	check(absf(one.position.y - back_deck) < 0.01 and absf(two.position.y - back_deck) < 0.01, "the parents stand on their platforms' decks")
	var room: Node = film._hatchery.get_node("Roundels")
	check(room.visible and not film._hatchery.get_node("Room").visible and film._hatchery.environment.fog_enabled, "the film takes place in the misty roundel chamber")
	var plinths := [[Vector3.ZERO, 3.85]]
	for parent in [one, two]:
		plinths.append([film._hatchery.to_local(parent.position), 3.85 * film.BACK_SIZE])
	var wall_gap := INF
	for si in room.mesh.get_surface_count():
		if room.mesh.surface_get_material(si).resource_name in ["roundel_wall", "roundel_panel", "roundel_column"]:
			for v: Vector3 in room.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				for entry in plinths:
					wall_gap = minf(wall_gap, Vector2(v.x, v.z).distance_to(Vector2(entry[0].x, entry[0].z)) - entry[1])
	check(wall_gap > 0.2, "all three platforms stand clear of the walls (%.2f units to spare)" % wall_gap)
	check(room.get_aabb().position.y >= -0.05, "the chamber's floor is level with the stage")
	var floor_reach := 0.0
	var wall_reach := 0.0
	for si in room.mesh.get_surface_count():
		var surface: String = room.mesh.surface_get_material(si).resource_name
		for v: Vector3 in room.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			if surface == "roundel_floor":
				floor_reach = maxf(floor_reach, Vector2(v.x, v.z).length())
			elif surface == "roundel_wall":
				wall_reach = maxf(wall_reach, Vector2(v.x, v.z).length())
	check(floor_reach * cos(PI / 72.0) > wall_reach, "the stone floor reaches every wall (%.1f, walls at %.1f)" % [floor_reach, wall_reach])
	var walls := _room_walls(room.mesh)
	var shallowest := INF
	var crooked := 0.0
	var pane_arrays := _roundel_surface(room.mesh, "roundel_panel")
	for i in pane_arrays[Mesh.ARRAY_VERTEX].size():
		var behind := -INF
		var off_wall := PI
		for wall: Array in walls:
			behind = maxf(behind, wall[1] - pane_arrays[Mesh.ARRAY_VERTEX][i].dot(wall[0]))
			off_wall = minf(off_wall, pane_arrays[Mesh.ARRAY_NORMAL][i].angle_to(wall[0]))
		shallowest = minf(shallowest, behind)
		crooked = maxf(crooked, off_wall)
	check(walls.size() == 5, "the chamber shows its five flat walls (%d)" % walls.size())
	check(shallowest > 0.4, "all the glass sits at the back of deep holes, behind the walls (%.2f deep at the shallowest)" % shallowest)
	check(rad_to_deg(crooked) < 2.0, "all the glass lies flat against its wall (%.1f degrees off at the worst)" % rad_to_deg(crooked))
	var column_verts: PackedVector3Array = _roundel_surface(room.mesh, "roundel_column")[Mesh.ARRAY_VERTEX]
	var bare_corners := 0
	for i in walls.size() - 1:
		var here: Array = walls[i]
		var next: Array = walls[i + 1]
		var turn: float = here[0].x * next[0].z - here[0].z * next[0].x
		var corner: Vector2 = Vector2(here[1] * next[0].z - next[1] * here[0].z, next[1] * here[0].x - here[1] * next[0].x) / turn
		if corner.y < 5.5 and not Array(column_verts).any(func(v: Vector3) -> bool: return Vector2(v.x, v.z).distance_to(corner) < 1.0):
			bare_corners += 1
	check(bare_corners == 0, "a column stands in every corner where the walls meet (%d bare)" % bare_corners)
	var wire_verts: PackedVector3Array = _roundel_surface(room.mesh, "roundel_wires")[Mesh.ARRAY_VERTEX]
	var wire_top := -INF
	for v in wire_verts:
		wire_top = maxf(wire_top, v.y)
	check(wire_verts.size() > 3000 and wire_top > 11.0, "the original cables are draped across the ceiling (%d vertices, up to %.1f)" % [wire_verts.size(), wire_top])
	var tongs_plain: bool = stage.get_children().filter(func(n): return n is Light3D).all(func(n): return (n.light_cull_mask & 2) == 0)
	check(tongs_plain, "the film's lights leave the tongs plain metal")
	var sounds: Array = ["SwellSound", "VanishSound", "RevealSound"].map(func(n): return film.get_node(n))
	check(sounds.all(func(s): return s.stream != null and s.bus == &"SFX"), "all three merge sounds load on the SFX bus")
	check(sounds[0].playing and one.opacity == 1.0 and not reveal.visible, "the swell starts with both parents visible and the child hidden")
	await main._press("ui_accept")
	await main._press("ui_cancel")
	await main._tap_at(Vector2(640, 360))
	check(UI.stack.back() == film and not film.closed, "A, B and a tap cannot skip or leak through the merge film")
	await main._press("pause")
	var held: float = film.elapsed
	var held_y: float = light.position.y
	await main._wait(0.2)
	check(main.get_tree().paused and is_equal_approx(film.elapsed, held) and is_equal_approx(light.position.y, held_y), "Pause freezes the merge film")
	await main._press("pause")
	await main._wait(0.05)
	check(not main.get_tree().paused and film.elapsed > held, "Pause resumes the merge film")
	var early := false
	var beam_early := false
	var beam_from_claw := true
	var lit_before_fade := false
	var highest := -2.0
	var peak := 0.0
	var fall_at := -1.0
	var fade_at := -1.0
	var fade_y := 0.0
	var gone_at := -1.0
	var vanish_sound := false
	var land_at := -1.0
	var land_y := 99.0
	var reveal_sound := false
	var wash := 0.0
	var wash_at := -1.0
	var clear_at := -1.0
	var opaque_at := -1.0
	var dimmest := 1.0
	var last_room_light := 0.0
	var moved_early := false
	var orbit := 0.0
	var off_centre := 0.0
	while is_instance_valid(film) and not film.closed:
		await main.get_tree().process_frame
		if not is_instance_valid(film) or film.closed:
			break
		var t: float = film.elapsed
		var y: float = light.position.y
		peak = maxf(peak, y)
		orbit = rig.rotation.y
		dimmest = minf(dimmest, film.room_light)
		last_room_light = film.room_light
		off_centre = maxf(off_centre, absf(camera.unproject_position(reveal.global_position).x - camera.get_viewport().size.x * 0.5))
		if fall_at < 0 and beam.current_animation == "fall":
			fall_at = t
		if fall_at < 0 and y < 4.95 and (one.opacity < 1.0 or two.opacity < 1.0):
			early = true
		highest = maxf(highest, one.position.y)
		if fade_at < 0 and one.opacity < 1.0:
			lit_before_fade = film.parent_light > 0.95 and one.glow > 0.25
			fade_at = t
			fade_y = y
			vanish_sound = sounds[1].playing
		if gone_at < 0 and one.opacity <= 0.0 and two.opacity <= 0.0:
			gone_at = t
		if gone_at < 0 and light.visible:
			beam_early = true
		if light.visible and y < film.CLAW_Y:
			# The film may have laid out its shaft a frame before the animation last moved the light.
			film._update_light()
			var shaft: Node3D = film._shaft
			beam_from_claw = beam_from_claw and absf(y + shaft.position.y + shaft.scale.y * 0.5 - film.CLAW_Y) < 0.06
		if land_at < 0 and (reveal.opacity > 0.0 or fill.modulate.a > 0.0):
			land_at = t
			land_y = y
			reveal_sound = sounds[2].playing
		if land_at < 0 and (not is_zero_approx(orbit) or not is_zero_approx(camera.position.x)):
			moved_early = true
		if fill.modulate.a > wash:
			wash = fill.modulate.a
			wash_at = t
		if clear_at < 0 and wash > 0.9 and fill.modulate.a <= 0.0:
			clear_at = t
		if opaque_at < 0 and reveal.opacity >= 1.0:
			opaque_at = t
	check(absf(peak - 10.0) < 0.05 and absf(fall_at - 3.0) < 0.1, "the light reaches Y=10 at 3 s and only then falls (%.2f at %.2f s)" % [peak, fall_at])
	check(not early and fade_y >= 4.95 and fade_y < 5.6 and vanish_sound, "the parents vanish, with their sound, when the light reaches Y=5 (Y=%.2f)" % fade_y)
	check(not beam_early, "the centre's beam stays dark until both parents have gone")
	check(beam_from_claw, "the centre's beam hangs from the core above it all the way down")
	check(lit_before_fade, "the parents light up before they start to fade")
	check(highest > -1.0, "the parents rise into the light as they fade")
	check(absf(gone_at - fade_at - 1.0) < 0.1, "the parents fade over one second (%.2f s)" % (gone_at - fade_at))
	check(absf(land_at - 5.0) < 0.12 and absf(land_y + 2.0) < 0.05 and reveal_sound, "the reveal and its sound wait for the light to land at Y=-2 (Y=%.2f at %.2f s)" % [land_y, land_at])
	check(wash > 0.97 and absf(wash_at - land_at - 0.5) < 0.1 and absf(clear_at - land_at - 1.0) < 0.1, "the white wash takes 0.5 s in and 0.5 s out")
	check(absf(opaque_at - land_at - 1.5) < 0.1, "the child fades in over 1.5 seconds (%.2f s)" % (opaque_at - land_at))
	check(dimmest < 0.2 and last_room_light > 0.99, "the room dims for the column of light and is bright again for the reveal")
	check(not moved_early, "the camera holds still until the child appears")
	check(orbit > 0.15 and orbit <= 0.27, "the camera then circles slightly around the child (%.2f rad)" % orbit)
	check(off_centre < 2.0, "the child stays centred while the camera circles it (%.1f px off)" % off_centre)
	await main._wait(0.05)
	check(finished[0] and UI.stack.is_empty(), "the merge film ends itself and returns cleanly")
	check(main.view.render_target_update_mode == original_update, "the merge film restores the world's viewport updates")
	UI.auto = true


func _starter_menu(main) -> void:
	Story._elder(null, {})
	for i in 20:
		await main._wait(0.15)
		if not UI.stack.is_empty() and UI.stack.back() is UI.ListMenu:
			break
		await main._press("ui_accept")
	await main._wait(0.25)


## One surface of the roundel chamber.
func _roundel_surface(mesh: Mesh, surface: String) -> Array:
	for si in mesh.get_surface_count():
		if mesh.surface_get_material(si).resource_name == surface:
			return mesh.surface_get_arrays(si)
	return []


## The chamber's flat walls in order around the room, as [direction into the room, distance along it].
func _room_walls(mesh: Mesh) -> Array:
	var arrays := _roundel_surface(mesh, "roundel_wall")
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var found := {}
	for t in range(0, idx.size(), 3):
		var nor := n[idx[t]]
		if absf(nor.y) > 0.5:
			continue
		var plane := Vector4i(roundi(nor.x * 20.0), 0, roundi(nor.z * 20.0), roundi(v[idx[t]].dot(nor) * 20.0))
		if not found.has(plane):
			found[plane] = [Vector3.ZERO, 0.0, 0.0]
		var area := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).length()
		found[plane][0] += nor * area
		found[plane][1] += v[idx[t]].dot(nor) * area
		found[plane][2] += area
	var walls := []
	for entry: Array in found.values():
		if entry[2] > 10.0:
			walls.append([Vector3(entry[0].x, 0.0, entry[0].z).normalized(), entry[1] / entry[2]])
	walls.sort_custom(func(a: Array, b: Array) -> bool: return atan2(a[0].z, a[0].x) < atan2(b[0].z, b[0].x))
	return walls


func _verify_ui(main) -> void:
	var shield := PointerShield.new()
	shield.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(shield)
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
	film.elapsed = film.duration
	await main._wait(0.3)
	check(not film.closed and film._stat_window.visible, "hatch holds its revealed stats until confirmation")
	await main._press("ui_accept")
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
	await main._wait(0.1)
	await main._press("ui_cancel")
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
				await main._wait(0.1)
				await main._press("ui_accept")
		if finished[0]:
			break
	check(finished[0] and seen == ["level:Embit", "evolve:Cinderex", "level:Hootlet"],
		"rendered reward queue shows each beast and each evolution once, in order: %s" % str(seen))
	battle.queue_free()
	shield.queue_free()


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
	elif mode == "merge":
		await _merge_preview(main, opts)
	else:
		var race := int(opts.get("race", "0"))
		var b := Beasts.create(race, 1 if mode == "hatch" else (19 if mode == "evolve" else 4), opts.get("ghost", "0") == "1")
		var before := b.growth_look()
		var level_look := {}
		if mode == "evolve":
			b.gain_xp(b.xp_for_level(20) - b.xp)
		elif mode == "level":
			# (--to: the level it reaches, from the one before; its event's look carries the moves it learned)
			var to := int(opts.get("to", "5"))
			if to > 2:
				b.level = to - 1
				b.xp = b.xp_for_level(to - 1)
				before = b.growth_look()
			for e in b.gain_xp(b.xp_for_level(to) - b.xp):
				if e["type"] == "level":
					level_look = e["look"]
		var egg := {"race": race, "kind": "legendary" if RaceDB.is_legendary(race) else RaceDB.element(race), "ghost": b.ghost}
		# ("egg": the film for an egg a beaten wild beast left behind)
		var film := Film.new().setup(mode, {"name": b.nickname} if mode == "egg" else before, {} if mode == "egg" else (level_look if not level_look.is_empty() else b.growth_look()), egg)
		if opts.has("at"):
			film.preview_time = float(opts.at)
		UI.push(film)
		if not opts.has("at"):
			if opts.has("shots"):
				var times := [0.6, 2.7, 3.8, 4.9, 5.7, 7.5] if mode == "hatch" else ([0.5, 0.8, 1.6, 3.2] if mode == "egg" else [0.4, 2.7, 4.0, 5.5])
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
			await _print_perf(main)
	if opts.has("shot"):
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts.shot))
	if opts.get("quit", "1") == "0":
		await main.get_tree().create_timer(3600).timeout


## --race and --other pick the parents. --at holds one instant (for --shot); --shots=path saves a frame at each beat.
func _merge_preview(main, opts: Dictionary) -> void:
	var a := Beasts.create(int(opts.get("race", "0")), 40, opts.get("ghost", "0") == "1")
	var b := Beasts.create(int(opts.get("other", "30")), 40)
	var child := Beasts.merge(a, b, true)
	main.trigger_merge_cinematic(a.growth_look(), b.growth_look(), child.growth_look())
	var film = UI.stack.back()
	if opts.has("at"):
		while film.elapsed < float(opts.at):
			await main.get_tree().process_frame
		main.get_tree().paused = true
		if opts.get("perf", "0") == "1":
			await _print_perf(main)
		return
	if opts.has("shots"):
		var times := [0.5, 1.7, 2.3, 3.0, 4.4, 5.3, 5.5, 5.9, 6.8, 9.7]
		for i in times.size():
			while film.elapsed < float(times[i]):
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts.shots) + "_%d.png" % i)
	await film.done


func _print_perf(main) -> void:
	var samples := PackedFloat64Array()
	for i in 120:
		await main.get_tree().process_frame
		samples.append(main.get_process_delta_time() * 1000)
	samples.sort()
	print("HATCHERY PERF: median %.2f ms, p95 %.2f ms, %d draws, %d primitives" % [samples[60], samples[114],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])


func _check_reward_confirmation(main) -> void:
	var b := Beasts.create(24, 1)
	var look := b.growth_look()
	for kind in ["hatch", "egg", "level"]:
		var film := Film.new().setup(kind, look, look, {"race": 24, "kind": "water"})
		UI.push(film)
		var press := InputEventAction.new()
		press.action = "ui_accept"
		press.pressed = true
		film.on_input(press)
		check(not film.closed, kind + " ignores confirmation before the reveal finishes")
		film.elapsed = film.duration
		film._process(0.0)
		await main._wait(0.2)
		check(not film.closed, kind + " holds for the player after its timeline")
		check(not film._notice.current_text().is_empty() and not film._notice.current_text().contains("Continue"), kind + " keeps only the reveal notice in the top HUD")
		if kind == "hatch":
			check(film._stat_window.visible and film._stat_rows.size() == 6, "hatch reveals six stats in the right window")
		film.on_input(press)
		check(film.closed, kind + " closes on a fresh confirmation")
		await main.get_tree().process_frame
