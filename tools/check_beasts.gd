extends SceneTree
## Verifies the beasts of the 13 lines (race_db.gd): every form has its name, elements and model; a beast grows into
## its line's next form at Lv 20 and Lv 40, keeping its moves; wild and trainers' beasts are the form their level
## gives; only final forms at their level limit merge, and a merge is built from both parents' models, in a recipe a
## save keeps.
## Run: godot --headless --path . --script res://tools/check_beasts.gd

const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

var bad := 0


func _init() -> void:
	for id in RaceDB.count():
		var f := RaceDB.form(id)
		_check(ResourceLoader.exists("res://assets/beasts/%s.res" % f) and RaceDB.of_form(f) == id, "%2d %-10s %-11s %s" % [id, RaceDB.race_name(id), f, " / ".join([RaceDB.element(id), RaceDB.element2(id)]).trim_suffix(" / ")])
	# growing up from an egg: two evolutions, at Lv 20 and Lv 40, the moves kept
	var b := Beasts.create(0, 1)
	var evo := []
	var moves := 0
	while not b.at_cap():
		moves = b.known.size()
		for e in b.gain_xp(Beasts.Beast.xp_for_level(b.level + 1) - b.xp):
			if e["type"] == "evolve":
				evo.append("%s → %s at Lv %d" % [e["from"], e["to"], b.level])
		_check(b.known.size() >= moves, "", false)
	_check(evo.size() == 2 and evo[0].ends_with("Lv 20") and evo[1].ends_with("Lv 40"), "an Embit grows up: %s" % ", ".join(evo))
	_check(b.level == 40 and b.level_cap() == 40 and RaceDB.stage(b.race) == 3 and b.genes["form"] == "dino_3", "it stops at its level limit, Lv %d, as a %s (%s)" % [b.level, b.nickname, b.genes["form"]])
	# the level picks the form; the two-element lines are both
	for t in [[0, 5, 0], [0, 25, 1], [0, 45, 2], [9, 30, 10], [21, 50, 23], [30, 19, 30], [30, 20, 31]]:
		var x := Beasts.create(t[0], t[1])
		_check(x.race == t[2] and x.elements().size() == (2 if RaceDB.element2(t[0]) != "" else 1), "a Lv %d beast of race %d is a %s (%s)" % [t[1], t[0], x.nickname, x.element_text()])
	# merging: final forms at their limit only
	var a := Beasts.create(0, 40)
	var c := Beasts.create(30, 40)
	_check(Beasts.can_merge(a, c, false) == "", "a Pyrosaur and a Tempestrix can merge")
	var young := Beasts.create(3, 30)
	_check(Beasts.can_merge(young, a, false) != "", "a Spinesear can't: \"%s\"" % Beasts.can_merge(young, a, false))
	var m := Beasts.merge(a, c)
	var recipe: Dictionary = m.genes.get("recipe", {})
	_check(recipe.has("frame") and recipe["frame"] in ["dino_3", "owl_3"] and m.rank == 2 and m.level_cap() == 60, "their merge, %s (%s), rank %d, limit Lv %d: %s" % [m.nickname, m.element_text(), m.rank, m.level_cap(), JSON.stringify(recipe)])
	var back := Beasts.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	_check(JSON.stringify(back.genes.get("recipe", {})) == JSON.stringify(recipe), "a save keeps its recipe")
	print("BEASTS CHECK DONE: %d problem(s)" % bad)
	quit()


func _check(ok: bool, what: String, show := true) -> void:
	if not ok:
		bad += 1
	if show or not ok:
		print("%s %s" % ["ok  " if ok else "FAIL", what])
