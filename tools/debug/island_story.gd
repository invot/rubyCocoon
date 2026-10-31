extends RefCounted
## Screenshot tour of the Isle of Tides story, from fresh state: Kelpwick's great hut and its healing machine, Chief
## Coralie and Chief Marlo, and Nerissa getting the villagers off the reef path. --shots=res://build/shots/island_story
const ML = preload("res://scripts/world/map_loader.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
var main
var dir := ""
var n := 0

func shot(label: String) -> void:
	n += 1
	if dir != "" and DisplayServer.get_name() != "headless":
		main._save_shot("%s/%02d_%s.png" % [dir, n, label])
	print("[island-story] ", label)

## Opens someone's conversation (not waiting for it), skips `pages` pages, then takes a shot and closes it.
func talk(id: String, pages: int, label: String) -> void:
	var who: Dictionary = main._npc(id)
	if who.is_empty():
		print("[island-story] missing ", id)
		return
	Story.talk(main.world, who)
	await main._wait(0.8)
	for i in pages:
		await main._press("ui_accept")
		await main._wait(0.5)
	shot(label)
	UI.auto = true
	await main._press("ui_accept")
	await main._wait(0.6)
	UI.clear_all()
	UI.auto = false

func run(game, opts: Dictionary) -> void:
	main = game
	dir = String(opts.get("shots", ""))
	if dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	GameState.set_flag("intro_done")
	GameState.set_flag("has_starter")
	if GameState.party.is_empty():
		GameState.add_beast(Beasts.create(30, 10))
	var town := ML.load_map("kelpwick", GameState.flags)
	var hut: Dictionary = town["buildings"].filter(func(b): return b["shop"] == "arena")[0]
	print("[island-story] kelpwick shops: ", town["buildings"].map(func(b): return b["shop"]), " hut ", hut["w"], "x", hut["d"], " door ", hut["door"])
	await main._go("kelpwick", hut["door"] + Vector2i(0, 4))
	await main._wait(1.5)
	shot("great_hut")
	await talk("chief_kelp", 1, "coralie_souvenirs")
	await talk("chief_kelp", 0, "coralie_proof")
	await main._go(hut["interior"], "entry")
	await main._wait(1.5)
	shot("hut_inside_healer")
	# the phone sits on the host's counter, clear of the healing machine: face it and press A
	var phone: Vector2i = main.world.map.get("counter_phone", Vector2i(-1, -1))
	await main._walk_test([phone + Vector2i.DOWN])
	main.world.facing = Vector2i.UP
	main.world._interact()
	await main._wait(1.2)
	print("[island-story] counter phone ", phone, " stood at ", main.world.player_pos, " call open: ", UI.stack.size() > 0)
	shot("counter_phone_call")
	# hang up with B, as a player would
	for i in 6:
		if UI.stack.is_empty():
			break
		await main._press("ui_cancel")
		await main._wait(0.5)
	# villagers stand across the reef path until Nerissa is beaten
	await main._go("kelpwick", Vector2i(35, 8))
	main.world.facing = Vector2i.RIGHT
	await main._wait(1.5)
	shot("reef_crowd")
	await talk("reef_crowd", 0, "reef_crowd_talk")
	Story.reef_opened("Reef Warden Nerissa")
	await main._wait(0.8)
	shot("nerissa_opens_gate")
	UI.auto = true
	await main._press("ui_accept")
	await main._wait(0.8)
	UI.clear_all()
	UI.auto = false
	await main._go("kelpwick", Vector2i(36, 8))
	await main._wait(1.5)
	print("[island-story] gate tiles left ", main.world.map["gate_tiles"].size())
	shot("gate_open")
	GameState.flags.erase("island_peace")
	await main._go("shellhaven", "dock")
	await main._wait(1.5)
	await talk("chief_shell", 2, "marlo_quaint")
	print("ISLAND STORY DONE")
