extends RefCounted
## Exercises HUD-only selection and action feedback with the live command panel and resolver.
## --scene=battle-focus --shots=res://build/shots/battle_focus
## --preview=trainer|beast|target|acting-trainer|acting-beast|acting-foe|acting-rival
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
		if shots == "" and not main._test.has("shot"):
			return
		await RenderingServer.frame_post_draw
		if shots != "":
			DirAccess.make_dir_recursive_absolute(shots.get_base_dir())
			main._save_shot(shots + "_" + label + ".png")
	check.call(battle.ally_grid.focus == -2, "trainer HUD icon is selected while choosing an action")
	check.call(battle.ally_grid.acting == -1 and battle.foe_grid.acting == -1, "selection marks only the character choosing an action")
	var middle = battle.ally_slots[1]
	middle.hp = maxi(1, roundi(middle.max_hp() * 0.38))
	battle._refresh()
	panel._redraw()
	await capture.call("trainer")
	if preview == "trainer":
		return
	await main._tap_at(battle.bars.get_global_transform_with_canvas() * battle.bars.pill_rect(0).get_center())
	check.call(panel.picking and battle.ally_grid.focus == -2, "tapping the relocated trainer bar retains its HUD selection while targeting")
	await main._press("ui_accept")
	await main._wait(0.12)
	var beast = panel.rows[panel.focus]["beast"]
	var slot: int = battle._slot_of(battle.ally_ring, beast)
	check.call(panel.focus == 1 and battle.ally_grid.focus == slot, "one confirm transfers the HUD outline to the first beast")
	check.call(battle.nodes[beast].find_children("*", "MeshInstance3D", true, false).all(func(mesh): return mesh.material_overlay == battle.nodes[beast].get_meta("flash")), "3D beast materials remain unchanged")
	await capture.call("beast")
	if preview == "beast":
		return
	await main._press("ui_accept")
	await main._wait(0.12)
	check.call(panel.picking and battle.ally_grid.focus == slot, "the beast's HUD icon stays selected while choosing its target")
	await main._press("ui_right")
	await main._wait(0.12)
	check.call(battle.ally_grid.focus == slot and battle.foe_grid.focus == -1, "changing the target leaves the outline on the choosing HUD character")
	await capture.call("target")
	if preview == "target":
		return
	await main._press("ui_cancel")
	await main._wait(0.12)
	check.call(not panel.picking and battle.ally_grid.focus == slot, "canceling targeting retains the HUD move-selection outline")
	# Actual actions exercise the shared resolver while the fixture's command panel waits.
	var foe = battle.foe_slots.filter(func(b): return b != null and b.hp > 0)[0]
	var actions := [
		["acting-trainer", {"type": "slingshot", "target": foe, "prio": 9}, battle.ally_grid, -2],
		["acting-beast", {"type": "defend", "actor": beast, "prio": 0}, battle.ally_grid, slot],
		["acting-foe", {"type": "defend", "actor": foe, "prio": 0}, battle.foe_grid, battle._slot_of(battle.foe_ring, foe)],
		["acting-rival", {"type": "rival_song", "song": "weaken", "prio": 0}, battle.foe_grid, -2],
	]
	for entry in actions:
		battle._show_option({}, {})
		battle._commanding = false
		battle._refresh()
		var done := [false]
		var resolve := func() -> void:
			await battle._resolve([entry[1]])
			done[0] = true
		resolve.call()
		await main._wait(0.08)
		var other = battle.foe_grid if entry[2] == battle.ally_grid else battle.ally_grid
		check.call(entry[2].acting == entry[3] and other.acting == -1 and battle.ally_grid.focus == -1 and battle.foe_grid.focus == -1, entry[0] + " outlines only the acting HUD icon")
		await capture.call(entry[0])
		if preview == entry[0]:
			return
		while not done[0]:
			await main.get_tree().process_frame
		check.call(battle.ally_grid.acting == -1 and battle.foe_grid.acting == -1, entry[0] + " clears its HUD outline after the action")
		await main._wait(0.4)
	check.call(battle._acting_ref == null, "action phase leaves no stale HUD actor")
	battle._select_hud_actor(null)
	print("BATTLE FOCUS DONE: %d problem(s)" % bad[0])
