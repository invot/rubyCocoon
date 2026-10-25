extends RefCounted
## Fresh Bellerive arrival, no player saves. --scene=tidewater-arrival --verify=1
## Window previews: --preview=arrival|talk|house|odile --shot=res://build/shots/tidewater.png

const Beasts = preload("res://scripts/core/beasts.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")

var bad := 0


func run(main, opts: Dictionary) -> void:
	for flag in ["intro_done", "got_egg", "has_starter", "tutorial_done"]:
		GameState.set_flag(flag)
	GameState.add_beast(Beasts.create(0, 5))
	UI.auto = true
	UI.auto_log.clear()
	await main._go("tidewater", "west")
	_check(UI.auto_log.is_empty() and not main.world.busy, "first arrival leaves the player free, without dialogue")
	var nell: Dictionary = main._npc("rafe_neighbor")
	_check(not nell.is_empty(), "Nell waits by the entrance")
	if nell.is_empty():
		return
	var house: Dictionary = main._bld("uncle")
	_check(main.world.find_child("RafeFluteSign", true, false) != null, "Rafe's house has its flute landmark")
	_check(Story.npc_has_news(nell), "Nell offers a hint before the flute")
	var near: Vector2i = nell["pos"] + Vector2i(-1, 0)
	await main._walk_test([near])
	_check(main.world.player_pos == near, "the entrance road reaches Nell")
	if opts.get("verify", "0") == "1":
		main.world.facing = Vector2i(1, 0)
		await main.world._interact()
		_check(GameState.flag("met_rafe_neighbor") and UI.auto_log.back().begins_with("Neighbor Nell:"), "interacting starts Nell's conversation")
		_check(not Story.npc_has_news(nell) and not GameState.has_flute(), "directions clear her hint marker and leave Rafe's gift with him")
		await main.world._interact()
		_check(UI.auto_log.size() == 2, "Nell can repeat her directions")
		await main._walk_test([house["door"] + Vector2i(0, 1)])
		_check(main.world.player_pos == house["door"] + Vector2i(0, 1), "the marked front door is reachable")
		main.world.facing = Vector2i(0, -1)
		await main.world._interact()
		await main._settle(house["interior"])
		_check(not main._npc("uncle").is_empty(), "the marked house leads to Uncle Rafe")
		GameState.set_flag("seen_tidewater") # Existing saves may still have the old arrival flag.
		UI.auto_log.clear()
		await main._go("tidewater", "west")
		_check(UI.auto_log.is_empty() and not main._npc("rafe_neighbor").is_empty(), "return visits and existing arrival flags keep Nell and avoid popups")
		# Miss Odile in the park, feeding its wild beasts (walked to before the flute, while none roam)
		var odile: Dictionary = main._npc("park_feeder")
		_check(not odile.is_empty() and main.world.map["wild_area"].has(odile["pos"]), "Miss Odile stands in the park among the wild beasts")
		if not odile.is_empty():
			await main._walk_test([odile["pos"] + Vector2i(0, 1)])
			_check(main.world.player_pos == odile["pos"] + Vector2i(0, 1), "the park's paths reach her")
			main.world.facing = Vector2i(0, -1)
			UI.auto_log.clear()
			await main.world._interact()
			_check(not UI.auto_log.is_empty() and String(UI.auto_log.back()).begins_with("Miss Odile:") and "candy corn" in String(UI.auto_log.back()),
				"she feeds them candy corn, so they never attack her")
		GameState.gear["flute"] = "reed_flute"
		GameState.flags.erase("met_rafe_neighbor")
		_check(not Story.npc_has_news(main._npc("rafe_neighbor")), "players who already have the flute get no stale hint marker")
		print("TIDEWATER ARRIVAL DONE: %d problem(s)" % bad)
		UI.auto = false
		return
	UI.auto = false
	var preview := String(opts.get("preview", "arrival"))
	if preview == "odile":
		var odile: Dictionary = main._npc("park_feeder")
		await main._walk_test([odile["pos"] + Vector2i(0, 1)])
		main.world.facing = Vector2i(0, -1)
		VPer.face(main.world.player, main.world.facing)
		main.world._interact()
		await main._wait(0.8)
		var dialog = UI.stack.back()
		while not "candy corn" in dialog.text_label.text:
			dialog.text_label.visible_characters = -1
			dialog._advance()
			dialog.text_label.visible_characters = -1
	elif preview == "house":
		await main._walk_test([house["door"] + Vector2i(0, 1)])
		main.world.facing = Vector2i(0, -1)
		VPer.face(main.world.player, main.world.facing)
	elif preview == "talk":
		main.world.facing = Vector2i(1, 0)
		VPer.face(main.world.player, main.world.facing)
		main.world._interact()
		await main._wait(0.8)
		var dialog = UI.stack.back()
		# Advance through the greeting using the real dialogue controls, then show the directions.
		while not "golden flute" in dialog.text_label.text:
			dialog.text_label.visible_characters = -1
			dialog._advance()
			dialog.text_label.visible_characters = -1
	await main._wait(float(opts.get("wait", "2")))
	if opts.has("shot"):
		await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shot"]))


func _check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if not ok:
		bad += 1
