extends SceneTree
## Exercise the real sale menus without loading or writing player saves.

var problems := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok:
		problems += 1

func run() -> void:
	var gs = root.get_node("GameState")
	var places = root.get_node("Places")
	var ui = root.get_node("UI")
	ui.auto = true
	gs.new_game("Egg Sales Test")
	gs.add_egg(0)
	gs.add_egg(24)
	gs.add_egg(0, true)
	gs.add_egg(39)
	check(places.egg_offer(gs.eggs[0]) == 100, "center ordinary egg offer")
	check(places.egg_offer(gs.eggs[2]) == 200, "center shadow egg offer")
	check(places.egg_offer(gs.eggs[3]) == 500, "center legendary egg offer")
	for town in places.WorldDB.ARENAS:
		for egg in gs.eggs:
			check(places.egg_offer(egg, town) == 0, town + " does not buy eggs")
		check(not places.has_eggs_to_sell(town), town + " offers no egg sale action")
	gs.eggs = []
	gs.add_egg(0)
	var before: int = gs.gold
	ui.auto_answers = [-1]
	await places.sell_eggs()
	check(gs.eggs.size() == 1 and gs.gold == before, "cancel egg selection leaves inventory and gold unchanged")
	ui.auto_answers = [0, 1, -1]
	await places.sell_eggs()
	check(gs.eggs.size() == 1 and gs.gold == before, "declining confirmation leaves egg and gold unchanged")
	ui.auto_answers = []
	await places.sell_eggs("tidewater")
	check(gs.eggs.size() == 1 and gs.gold == before, "master cannot buy nonmatching eggs")
	gs.party = [gs.Beasts.create(0, 1)]
	ui.auto_answers = [4, 0, 0, 3]
	await places.beast_center("caccoon")
	check(gs.eggs.is_empty() and gs.gold == before + 100, "Beast Center menu sells an egg")
	gs.party = []
	gs.add_egg(24)
	ui.auto_log.clear()
	ui.auto_answers = [-1]
	await places.arena({"name": "Test Arena"}, "tidewater")
	check(gs.eggs.size() == 1 and gs.gold == before + 100, "arena host never buys an egg")
	check(not ui.auto_log.any(func(line): return "Sell eggs" in String(line)), "arena host has no egg-selling menu")
	ui.auto_answers = []
	await places.leader_talk({"town": "tidewater"})
	check(gs.eggs.size() == 1 and gs.gold == before + 100, "master dialogue keeps eggs and gold unchanged")
	await places.sell_eggs("tidewater")
	check(gs.eggs.size() == 1 and gs.gold == before + 100, "direct arena sale cannot bypass the no-buying rule")
	gs.eggs = []
	await places.sell_eggs()
	check(gs.gold == before + 100, "empty egg inventory cannot generate gold")
	print("EGG SALES DONE: %d problem(s)" % problems)
	quit.call_deferred(1 if problems else 0)
