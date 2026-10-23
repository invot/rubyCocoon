extends SceneTree
## Real adoption paths with fresh state; never reads or writes player saves.

var problems := 0
var gs
var places
var ui


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok:
		problems += 1


func _seed_beast(level: int, yours := false):
	gs.new_game("Kennel Test")
	gs.add_beast(gs.Beasts.create(0, 1))
	var b = gs.Beasts.create(24, level)
	b.abandoned = true
	b.hp = 1
	b.mp = 0
	b.status = "poison"
	gs.kennels = {"caccoon": [{"beast": b, "yours": yours, "since": gs.play_time}]}
	ui.auto_answers = []
	ui.auto_log = []
	return b


func run() -> void:
	gs = root.get_node("GameState")
	places = root.get_node("Places")
	ui = root.get_node("UI")
	ui.auto = true
	for pair in [[1, 40], [20, 78], [40, 118], [99, 236]]:
		check(gs.kennel_adoption_fee(_seed_beast(pair[0])) == pair[1], "modest fee at level %d" % pair[0])
	var b = _seed_beast(20)
	gs.gold = 78
	ui.auto_answers = [0]
	await places.kennel_pen(null, "caccoon", 0)
	check(gs.gold == 0 and gs.all_beasts().has(b) and gs.all_beasts().size() == 2, "exact funds charged once and beast joins")
	check(gs.kennels["caccoon"][0]["beast"] == null, "successful adoption empties pen")
	check(b.hp == b.max_hp() and b.mp == b.max_mp() and b.status == "" and not b.abandoned and b.origin == "trade", "adoption keeps healing and origin behavior")
	check(str(ui.auto_log).contains("78 gold"), "confirmation includes actual adoption fee")
	for answer in [1, -1]:
		b = _seed_beast(40)
		ui.auto_answers = [answer]
		await places.kennel_pen(null, "caccoon", 0)
		check(gs.gold == 300 and gs.kennels["caccoon"][0]["beast"] == b and not gs.all_beasts().has(b), "decline/cancel %d changes neither gold nor beast" % answer)
	for funds in [0, 77]:
		b = _seed_beast(20)
		gs.gold = funds
		ui.auto_answers = [0]
		await places.kennel_pen(null, "caccoon", 0)
		check(gs.gold == funds and gs.kennels["caccoon"][0]["beast"] == b and not gs.all_beasts().has(b), "insufficient funds (%d) leave pen and gold intact" % funds)
		check(b.hp == 1 and b.status == "poison" and ui.auto_answers.size() == 1, "unaffordable adoption neither heals nor offers confirmation")
	b = _seed_beast(40, true)
	gs.gold = 0
	ui.auto_answers = [0]
	await places.kennel_pen(null, "caccoon", 0)
	check(gs.gold == 0 and gs.all_beasts().has(b), "reclaiming your own beast stays free")
	b = _seed_beast(20)
	gs.party = []
	for i in 8:
		var carried = gs.Beasts.create(0, 1)
		carried.slot = i
		gs.party.append(carried)
	ui.auto_answers = [0]
	await places.kennel_pen(null, "caccoon", 0)
	check(gs.gold == 222 and gs.storage.has(b), "full ring sends paid adoption to storage")
	b = _seed_beast(1)
	ui.auto_answers = [0, 0, 0, -1]
	await places.kennel(null, "caccoon")
	check(gs.gold == 260 and gs.all_beasts().has(b), "keeper menu uses same fee as direct pen interaction")
	await places.kennel_pen(null, "caccoon", 0)
	await places.kennel_pen(null, "caccoon", -1)
	await places.kennel_pen(null, "caccoon", 4)
	check(gs.gold == 260 and gs.all_beasts().size() == 2, "empty/invalid pens cannot charge or duplicate beasts")
	print("KENNEL DONE: %d problem(s)" % problems)
	quit.call_deferred(1 if problems else 0)
