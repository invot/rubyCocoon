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
	check(places.egg_offer(gs.eggs[0], "tidewater") == 0, "Water master refuses Fire egg")
	check(places.egg_offer(gs.eggs[1], "tidewater") == 200, "Water master pays double")
	check(places.egg_offer(gs.eggs[2], "emberfall") == 0, "shadow egg does not match underlying Fire race")
	check(places.egg_offer(gs.eggs[3], "tidewater") == 1000, "radiant egg matches guardian element and pays double")
	for town in places.WorldDB.ARENAS:
		var element: String = places.WorldDB.ARENAS[town]["element"]
		var race: int = {"water": 24, "fire": 0, "earth": 12, "air": 30}[element]
		gs.eggs = []
		gs.add_egg(race)
		check(places.has_eggs_to_sell(town) and places.egg_offer(gs.eggs[0], town) == 200, town + " accepts its element")
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
	gs.add_egg(24)
	gs.add_egg(24)
	ui.auto_answers = [0, 0, 0, 0]
	await places.sell_eggs("tidewater")
	check(gs.eggs.size() == 1 and gs.eggs[0]["kind"] == "fire" and gs.gold == before + 400,
		"repeated filtered sales remove only matching eggs at double price")
	gs.party = [gs.Beasts.create(0, 1)]
	ui.auto_answers = [4, 0, 0, 3]
	await places.beast_center("caccoon")
	check(gs.eggs.is_empty() and gs.gold == before + 500, "Beast Center menu sells an egg")
	gs.party = []
	gs.add_egg(24)
	# (the host's menu: the ladder, Leave, then Sell eggs)
	ui.auto_answers = [2, 0, 0, 1]
	await places.arena({"name": "Test Arena"}, "tidewater")
	check(gs.eggs.is_empty() and gs.gold == before + 700, "arena host sells eggs without a healthy party or completed lessons")
	gs.add_egg(24)
	ui.auto_answers = [2, 0, 0]
	await places.leader_talk({"town": "tidewater"})
	check(gs.eggs.is_empty() and gs.gold == before + 900, "master dialogue sells eggs before battle lesson gates")
	ui.auto_answers = []
	await places.sell_eggs()
	check(gs.gold == before + 900, "empty egg inventory cannot generate gold")
	print("EGG SALES DONE: %d problem(s)" % problems)
	quit.call_deferred(1 if problems else 0)
