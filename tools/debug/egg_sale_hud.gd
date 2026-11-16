extends RefCounted
## Exercise the actual sale, camera hold, A/B input and HUD tap targets with isolated state.

const MapLoader = preload("res://scripts/world/map_loader.gd")
const People = preload("res://scripts/gfx/townfolk.gd")
var bad := 0
var main


func check(ok: bool, text: String) -> void:
	print("ok " if ok else "FAIL ", text)
	bad += int(not ok)


func run(root, opts: Dictionary) -> void:
	main = root
	UI.auto = true
	await main._go(MapLoader.interior_of("caccoon", "center"), "entry")
	UI.auto = false
	var w = main.world
	for p in w.npcs:
		var n: Dictionary = w.npcs[p]
		if n.get("kind", "") == "keeper":
			w.player_pos = p + Vector2i(0, 2)
			w.player.position = w.tile_pos(w.player_pos)
			w.facing = Vector2i(0, -1)
			load("res://scripts/gfx/voxel_person.gd").face(w.player, w.facing)
			w.shot_subject = n["node"]
			break
	var look: Dictionary = MapLoader.KEEPER_LOOKS["center"].duplicate()
	var dressed := People.outfit(look)
	look.erase("face_person")
	var original := People.outfit(look)
	check(dressed.person == original.person, "friendly face preserves keeper identity")
	var kinds: Array = People.data()["parts"]
	check(dressed.parts.filter(func(id): return kinds[int(id)].kind != "head") == original.parts.filter(func(id): return kinds[int(id)].kind != "head"), "hair and clothing are unchanged")
	GameState.eggs.clear()
	GameState.add_egg(0)
	GameState.add_egg(24)
	GameState.add_egg(2)
	var gold: int = GameState.gold
	Places.sell_eggs()
	await main._wait(1.2)
	var egg_list = UI.stack.back()
	await shot(opts, "menu")
	await main._press("ui_accept")
	await main._wait(0.8)
	var prompt = UI.stack.back()
	check(prompt.get_script().resource_path.ends_with("hud_confirm.gd"), "sale uses the HUD decision")
	check(UI.stack.size() == 2 and UI.stack[0] == egg_list and not egg_list.visible, "only the confirmation is visible while deciding")
	check(egg_list._panel.get_global_rect().position.distance_to(prompt.panel.get_global_rect().position) < 1.0, "confirmation uses the egg list HUD position")
	check(w._shot_on, "close menu camera remains active during confirmation")
	var camera: Transform3D = w.cam.transform
	await main._wait(0.5)
	check(camera.origin.distance_to(w.cam.transform.origin) < 0.02, "camera stays in place while deciding")
	check(GameState.eggs.size() == 3 and GameState.gold == gold, "opening press does not sell an egg")
	await shot(opts, "confirm")
	await main._press("ui_cancel")
	await main._wait(0.3)
	check(GameState.eggs.size() == 3 and GameState.gold == gold, "B cancels without selling")
	check(UI.stack.back() == egg_list and egg_list.visible and egg_list._focus == 0, "cancel restores the same list and selected egg")
	await main._press("ui_accept")
	await main._wait(0.2)
	prompt = UI.stack.back()
	await main._tap_at(prompt.cancel.get_global_rect().get_center())
	await main._wait(0.3)
	check(GameState.eggs.size() == 3 and GameState.gold == gold, "Cancel button leaves inventory unchanged")
	await main._press("ui_accept")
	await main._wait(0.2)
	prompt = UI.stack.back()
	await main._tap_at(prompt.confirm.get_global_rect().get_center())
	await main._wait(0.3)
	check(GameState.eggs.size() == 2 and GameState.gold == gold + 100, "Confirm tap sells exactly one egg")
	check(UI.stack.back().get_script().resource_path.ends_with("list_menu.gd"), "sale immediately returns to the egg list")
	await main._press("ui_accept")
	await main._wait(0.2)
	await main._press("ui_accept")
	await main._wait(0.3)
	check(GameState.eggs.size() == 1 and GameState.gold == gold + 200, "A confirms the next sale")
	await main._press("ui_cancel")
	await main._wait(0.3)
	print("EGG SALE HUD DONE: %d problem(s)" % bad)


func shot(opts: Dictionary, suffix: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot("%s_%s.png" % [opts["shots"], suffix])
