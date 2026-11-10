extends RefCounted
## Cinematic HUD regression with real inputs and the shared resolver. --preview=trainer|beast|target|hit|shield|action
const UIKit = preload("res://scripts/ui/ui_kit.gd")

func run(main: Node) -> void:
	main._test["stop"] = "trainer"
	await main._battlecmd_test()
	var battle: Node
	for child in main.view.get_children():
		if child.get_script() == load(main.BATTLE_PATH):
			battle = child
	var bad := [0]
	var check := func(ok: bool, label: String) -> void:
		if not ok:
			bad[0] += 1
		print("%s %s" % ["ok  " if ok else "FAIL", label])
	if battle == null:
		check.call(false, "battle fixture opened")
		return
	var panel = UI.stack.back()
	var preview := String(main._test.get("preview", ""))
	var shots := String(main._test.get("shots", ""))
	var capture := func(label: String) -> void:
		if shots == "":
			return
		await main._wait(0.3)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(shots.get_base_dir())
		main._save_shot(shots + "_" + label + ".png")
	var layout := func(label: String) -> void:
		battle.floating.layout()
		var rect: Rect2 = battle.floating.menu_rect
		check.call(UIKit.safe_rect(battle.hud).encloses(rect), label + " menu stays in the safe area")
		check.call(battle.floating.action_rect.size.y >= UIKit.row_h(), label + " action is full height")
		if UI.is_touch():
			for group in UI.controls.CLUSTERS:
				var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
				check.call(not rect.intersects(zone), label + " leaves touch clusters clear")
	var tap := func(at: Vector2) -> void:
		if UIKit.touch_ui():
			var pixels := at * Vector2(main.get_window().size) / main.get_viewport().get_visible_rect().size
			main._touch(pixels, true)
			await main.get_tree().process_frame
			main._touch(pixels, false)
			await main._wait(0.12)
		else:
			await main._tap_at(at)
	check.call(battle._selected_refs == ["trainer_self"] and battle.floating.actor == "trainer_self", "trainer has the 3D outline and the only menu")
	check.call(battle._shield_orbs.values().all(func(orbs): return orbs.all(func(orb): return not orb.visible)), "shields are hidden during ordinary choosing")
	layout.call("trainer")
	await capture.call("trainer")
	if preview == "trainer":
		return
	await tap.call(battle.floating.action_rect.get_center())
	check.call(panel.picking and panel.focus == 0 and not panel.rows[0].get("done", false), "a menu tap confirms only the move")
	check.call(battle.floating.actor == null and battle._selected_refs == battle._target_refs, "targeting moves the outline to the target and hides the choice")
	# A controller press and release, through the actual input map.
	for down in [true, false]:
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_A
		joy.pressed = down
		Input.parse_input_event(joy)
		await main.get_tree().process_frame
	await main._wait(0.15)
	check.call(panel.focus == 1 and not panel.picking, "gamepad A confirms once and advances to the first beast")
	var beast = panel.rows[panel.focus]["beast"]
	check.call(battle._selected_refs == [beast] and battle.nodes[beast].get_meta("flash").next_pass == battle._outline, "chooser has a gem hull without replacing its hit flash")
	layout.call("beast")
	if main._test.get("profile_hud", "0") == "1":
		var started := Time.get_ticks_usec()
		for frame in 60:
			await main.get_tree().process_frame
		print("CINEMATIC HUD PROFILE: %.1f rendered fps, %d draw calls (desktop host)" % [
			60000000.0 / (Time.get_ticks_usec() - started), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	await capture.call("beast")
	if preview == "beast":
		return
	var cost_found := false
	var original_focus: int = panel.focus
	for index in range(1, panel.rows.size()):
		var choice: Dictionary = panel.rows[index]
		for i in choice["options"].size():
			var move: Dictionary = choice["options"][i]
			if not move.has("move") or battle.MoveDB.mp_cost(String(move["move"])) <= 0 or move.get("disabled", false):
				continue
			var selected := int(choice.get("sel", 0))
			panel._focus_row(index)
			choice["sel"] = i
			panel._redraw()
			var cost_beast = choice["beast"]
			var mp: int = cost_beast.mp
			await capture.call("cost")
			check.call(cost_beast.mp == mp and battle.floating.option["move"] == move["move"], "MP cost preview leaves MP unspent until the action")
			if preview == "cost":
				return
			choice["sel"] = selected
			panel._focus_row(original_focus)
			panel._redraw()
			cost_found = true
			break
		if cost_found:
			break
	check.call(cost_found, "fixture includes an available elemental MP cost")
	# Runtime palettes update the same live hull and anchored boxes.
	for gem in UIKit.ACCENT_ORDER:
		UIKit.set_accent(gem)
		await main._wait(0.05)
		check.call(battle._outline.get_shader_parameter("gem") == UIKit.ACCENT, gem + " updates the live 3D outline")
		await capture.call(gem)
	UIKit.set_accent(String(main._test.get("gem", "ruby")))
	# Long names/moves wrap without reducing the font or hit target.
	var nickname: String = beast.nickname
	beast.nickname = "A Rather Remarkably Long Beast Name"
	var option: Dictionary = panel.rows[panel.focus]["options"][int(panel.rows[panel.focus].get("sel", 0))].duplicate()
	option["label"] = "A Rather Remarkably Long Move Name"
	battle.floating.choose(beast, panel.rows[panel.focus], option)
	layout.call("long label")
	await capture.call("long_label")
	beast.nickname = nickname
	panel._redraw()
	await main._press("ui_accept")
	await main._wait(0.15)
	await main._press("ui_right")
	await main._wait(0.15)
	check.call(panel.picking and battle._selected_refs == battle._target_refs and battle._selected_refs != [beast], "keyboard aiming outlines the target")
	await capture.call("target")
	if preview == "target":
		return
	await main._press("ui_cancel")
	await main._wait(0.12)
	check.call(not panel.picking and battle._selected_refs == [beast], "B restores the chooser and their menu")
	await main._press("ui_accept")
	await main._wait(0.12)
	var target_row: Dictionary = panel.rows[panel.focus]
	var targets: Array = target_row["targets"]
	var other := posmod(int(target_row.get("target_sel", 0)) + 1, targets.size())
	var aim = targets[other]["ref"]
	await tap.call(battle.screen_anchor(aim, 0.5))
	check.call(panel.picking and int(target_row["target_sel"]) == other and not target_row.get("done", false), "a direct 3D tap aims without confirming")
	await tap.call(battle.screen_anchor(aim, 0.5))
	check.call(not panel.picking and target_row.get("done", false), "a second 3D tap confirms once")
	# Actions clear choices and target tags. HP changes alone add a short-lived tag, including healing.
	battle._commanding = false
	battle._set_acting(beast)
	await main.get_tree().process_frame
	check.call(battle.floating.actor == null and battle._target_refs.is_empty(), "actions have no persistent tags")
	await capture.call("action")
	if preview == "action":
		return
	beast.hp -= 1
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	check.call(battle.floating.hp_changes.has(beast), "damage creates a transient HP tag")
	await capture.call("hit")
	if preview == "hit":
		return
	await main._wait(1.3)
	check.call(not battle.floating.hp_changes.has(beast), "HP tag fades after about a second")
	beast.hp += 1
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	check.call(battle.floating.hp_changes.has(beast), "healing also creates a transient HP tag")
	await main._wait(1.3)
	if battle.wild:
		var foe = battle.foe_slots.filter(func(b): return b != null and b.hp > 0)[0]
		var hp: int = foe.hp
		await battle._resolve([{"type": "slingshot", "target": foe, "prio": 9}])
		check.call(foe.hp < hp and battle.floating.actor == null, "wild pack resolves a real action with no persistent readouts")
		await capture.call("wild_action")
		print("BATTLE FOCUS DONE: %d problem(s)" % bad[0])
		return
	battle._show_targets([{"ref": "foe_trainer"}], 0)
	await main.get_tree().process_frame
	check.call(battle._shield_orbs["foe"].all(func(orb): return orb.visible), "targeted trainer shows shield orbs")
	battle.floating.layout()
	var shield_tag: Rect2 = battle.floating.tag_rects.get("foe_trainer", Rect2())
	for orb in battle._shield_orbs["foe"]:
		var at: Vector2 = battle.cam.unproject_position(orb.position) * battle.hud.get_viewport_rect().size / battle.cam.get_viewport().get_visible_rect().size
		check.call(not shield_tag.grow(6.0).has_point(at), "trainer tag leaves the shield orbs visible")
	await capture.call("shield")
	if preview == "shield":
		return
	battle._hide_targets()
	battle._shield_pulse(battle.rival_bubble)
	await main.get_tree().process_frame
	check.call(battle._shield_orbs["foe"].all(func(orb): return orb.visible), "a trainer hit shows shield orbs")
	await main._wait(1.2)
	check.call(battle._shield_orbs["foe"].all(func(orb): return not orb.visible), "shield orbs hide after the hit")
	battle._set_acting(null)
	print("BATTLE FOCUS DONE: %d problem(s)" % bad[0])
