extends RefCounted
## A wild beast met from the side turns smoothly to face you before the battle, as people do.
## --scene=beast-turn [--shot=res://build/shots/beast_turn.png: before, mid-turn and facing frames]

const Beasts = preload("res://scripts/core/beasts.gd")

var bad := 0


func run(main, opts: Dictionary) -> void:
	main.get_window().title = "Ruby Cocoon - beast turn"
	UI.auto = true
	for teacher in Story.LESSON_TRAINERS:
		GameState.set_flag("lesson_" + String(teacher["lesson"]))
	await main._go("route1", "west")
	await main._wait(0.3)
	var world = main.world
	for w in world.wilds:
		w["node"].queue_free()
	world.wilds.clear()
	world._wild_target = 0
	var home := _open_patch(world)
	world.spawn_at(home)
	# the beast stands just east of you, looking north: you meet it from its side
	var pos := home + Vector2i(1, 0)
	var w := {"beasts": [Beasts.create(27, 2)], "pos": pos, "home": pos, "facing": Vector2i(0, -1),
		"state": "stunned", "t": 99.0, "moving": false, "from": world.tile_pos(pos), "to": world.tile_pos(pos),
		"mt": 0.0, "speed": world.WILD_WANDER_SPEED, "lost": 0.0, "phase": 0.0}
	world._make_wild_node(w)
	world.wilds.append(w)
	world.facing = Vector2i(1, 0)
	VPer_face(world)
	await main._wait(0.4)
	var node: Node3D = w["node"]
	var start := node.rotation.y
	var shooting: bool = opts.has("shot") and DisplayServer.get_name() != "headless"
	if shooting:
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]).get_basename() + "_before.png")
	var target := atan2(0.0, -1.0)  # facing (-1, 0): west, towards you (world._face_wild)
	world._wild_encounter(w, "wild")
	var steps := 0
	var biggest := 0.0
	var last := start
	var mid_shot := false
	var elapsed := 0.0
	while elapsed < 0.6 and not main.in_battle:
		await main.get_tree().process_frame
		elapsed += main.get_process_delta_time()
		var jump := absf(angle_difference(last, node.rotation.y))
		biggest = maxf(biggest, jump)
		if jump > 0.001:
			steps += 1
		last = node.rotation.y
		if shooting and not mid_shot and absf(angle_difference(node.rotation.y, target)) > 0.4 and absf(angle_difference(node.rotation.y, start)) > 0.3:
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts["shot"]).get_basename() + "_mid.png")
			mid_shot = true
		if shooting and mid_shot and absf(angle_difference(node.rotation.y, target)) < 0.1:
			await RenderingServer.frame_post_draw
			main._save_shot(String(opts["shot"]).get_basename() + "_facing.png")
			shooting = false
	print("turn: start %.2f target %.2f now %.2f, %d frames turning, biggest step %.2f rad" % [start, target, node.rotation.y, steps, biggest])
	_check(absf(angle_difference(start, target)) > 1.4, "the beast starts side-on to you")
	_check(steps >= 4, "the beast turns over several frames (%d)" % steps)
	_check(biggest < 0.9, "no single frame snaps the beast round (%.2f rad)" % biggest)
	_check(absf(angle_difference(node.rotation.y, target)) < 0.1, "the beast ends facing you")
	while main.in_battle or world.busy:
		Engine.time_scale = 12.0
		var b = _battle(main)
		if b != null:
			b.result = "run"
		await main._wait(0.2)
	Engine.time_scale = 1.0
	print("BEAST TURN DONE: %d problem(s)" % bad)


func VPer_face(world) -> void:
	load("res://scripts/gfx/voxel_person.gd").face(world.player, world.facing)


func _battle(main):
	for child in main.view.get_children():
		if child.get_script() == load(main.BATTLE_PATH):
			return child
	return null


func _open_patch(world) -> Vector2i:
	var candidates: Array = world._wild_cands.duplicate()
	var center := Vector2(world.map["w"], world.map["h"]) * 0.5
	candidates.sort_custom(func(a, b): return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	for q in candidates:
		if world._walkable(q) and world._wild_free(q + Vector2i(1, 0), {}, q):
			return q
	_check(false, "a clear patch exists")
	return world.player_pos


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
		push_error(label)
