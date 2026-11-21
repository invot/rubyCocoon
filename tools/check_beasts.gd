extends SceneTree
## Verifies the beasts of the supplied creature lines (race_db.gd): every form has its name, elements and model; a beast grows into
## its line's next form at Lv 20 and Lv 40, keeping its moves; wild and trainers' beasts are the form their level
## gives; only final forms at their level limit merge, and a merge is built from both parents' models, in a recipe a
## save keeps.
## Run: godot --headless --path . --script res://tools/check_beasts.gd

const Beasts = preload("res://scripts/core/beasts.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

var bad := 0


func _init() -> void:
	for id in RaceDB.line_races():
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
	_check(evo.size() == 2 and evo[0].ends_with("Lv 20") and evo[1].ends_with("Lv 40"), "a replacement hatchling grows up: %s" % ", ".join(evo))
	_check(b.level == 40 and b.level_cap() == 40 and RaceDB.stage(b.race) == 3 and b.genes["form"] == RaceDB.form(2), "it stops at its level limit, Lv %d, as a %s (%s)" % [b.level, b.nickname, b.genes["form"]])
	# the level picks the form; the two-element lines are both
	for t in [[0, 5, 0], [0, 25, 1], [0, 45, 2], [9, 30, 10], [21, 50, 23], [30, 19, 30], [30, 20, 31]]:
		var x := Beasts.create(t[0], t[1])
		_check(x.race == t[2] and x.elements().size() == (2 if RaceDB.element2(t[0]) != "" else 1), "a Lv %d beast of race %d is a %s (%s)" % [t[1], t[0], x.nickname, x.element_text()])
	# merging: final forms at their limit only
	var a := Beasts.create(0, 40)
	var c := Beasts.create(30, 40)
	_check(Beasts.can_merge(a, c, false) == "", "a Pyrosaur and a Tempestrix can merge")
	var young := Beasts.create(3, 30)
	_check(Beasts.can_merge(young, a, false) != "", "a juvenile can't: \"%s\"" % Beasts.can_merge(young, a, false))
	var m := Beasts.merge(a, c)
	var recipe: Dictionary = m.genes.get("recipe", {})
	_check(recipe.has("frame") and recipe["frame"] in [RaceDB.form(2), RaceDB.form(32)] and m.rank == 2 and m.level_cap() == 60, "their merge, %s (%s), rank %d, limit Lv %d: %s" % [m.nickname, m.element_text(), m.rank, m.level_cap(), JSON.stringify(recipe)])
	var back := Beasts.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	_check(JSON.stringify(back.genes.get("recipe", {})) == JSON.stringify(recipe), "a save keeps its recipe")
	# move slots: two elemental at first, one more per growth, the best parent's plus two on a merge (split between two
	# elements), two plain; a full kind of slot waits for the player (Menus.decide_learn)
	_check(Beasts.create(0, 1).elem_slots == 2 and b.elem_slots == 4, "elemental slots: 2 when hatched, 4 grown up (%d)" % b.elem_slots)
	_check(m.elem_slots == maxi(a.elem_slots, c.elem_slots) + 2 and back.elem_slots == m.elem_slots, "a merge has the best parent's slots plus two: %d" % m.elem_slots)
	var split := m.slot_size(m.element) + (m.slot_size(m.element2) if m.element2 != "" else 0)
	_check(split == m.elem_slots and (m.element2 == "" or m.slot_size(m.element) == m.slot_size(m.element2)), "its slots split evenly between its elements (%s)" % m.element_text())
	var fits := true
	for id in RaceDB.line_races():
		for level in [1, 25, 45, 70]:
			var x := Beasts.create(id, level)
			for group in x.slot_groups():
				fits = fits and x.slot_moves(group).size() <= x.slot_size(group)
	_check(fits, "every new beast's moves fit their slots")
	var full := Beasts.create(0, 40)
	var before: Array = full.moves.duplicate()
	var fire_full: bool = full.slot_moves("fire").size() == full.slot_size("fire")
	_check(not fire_full or (full.learn("inferno") == "full" and full.moves == before), "a full slot leaves the moves for the player to choose")
	var legacy := full.to_dict()
	legacy.erase("elem_slots")
	legacy["moves"] = ["tackle", "scratch", "bite", "ember", "flame_fang", "fire_spin", "lava_slam", "heat_wave", "inferno"]
	legacy["known"] = legacy["moves"].duplicate()
	var old := Beasts.from_dict(legacy)
	_check(old.elem_slots == 4 and old.moves == ["scratch", "bite", "fire_spin", "lava_slam", "heat_wave", "inferno"] and old.known == old.moves,
		"an older save keeps the newest moves that fit: %s" % [old.moves])

	# Every supplied family is released and has an authored habitat, including late ids.
	var WorldDB = load("res://scripts/data/world_db.gd")
	var habitats := []
	for route in WorldDB.ROUTES.values():
		habitats.append_array(route["races"])
	_check(RaceDB.count() == 75 and RaceDB.first_forms().size() == 25, "all 25 supplied lines / 75 forms are released")
	for first in RaceDB.first_forms():
		_check(first in habitats, "%s has a wild habitat" % RaceDB.race_name(first))
	for i in RaceDB.LEGACY_LINES.size():
		var id: int = RaceDB.line_base(i) + 1
		var legacy_form: String = RaceDB.LEGACY_LINES[i] + "_2"
		_check(RaceDB.of_form(legacy_form) == id and RaceDB.canonical_form(legacy_form) == RaceDB.form(id), "legacy form alias %s resolves without changing race id" % legacy_form)
	var saved := Beasts.create(1, 25).to_dict()
	saved["nickname"] = "Cinderex"
	saved["genes"] = {"form": "dino_2", "body": "quad", "size": 0.86, "shade": 0.0}
	var saved_stats: Dictionary = saved["base"].duplicate(true)
	var migrated := Beasts.from_dict(saved)
	_check(migrated.race == 1 and migrated.genes["form"] == RaceDB.form(1) and is_equal_approx(float(migrated.genes["size"]), RaceDB.STAGE_SIZE[1])
		and migrated.nickname == RaceDB.race_name(1) and migrated.base == saved_stats, "loading a legacy beast changes appearance/default name and preserves race/stats")
	_check(RaceDB.canonical_name("Young Fire Axolotl", 0) == "Sizzlo" and RaceDB.canonical_name("Guardian Grey Owl", 32) == "Hoobertus"
		and RaceDB.canonical_name("Umbral Fire Draco", 49) == "Umbral Dracone", "interim roster names become the short stage names")
	saved["nickname"] = "Pebble"
	_check(Beasts.from_dict(saved).nickname == "Pebble", "loading preserves a player-written nickname")
	saved["genes"]["recipe"] = {"frame": "dino_2", "colours": "owl_2", "head": "owl_2"}
	var migrated_merge := Beasts.from_dict(saved)
	_check(migrated_merge.genes["recipe"]["frame"] == RaceDB.form(1) and migrated_merge.genes["recipe"]["head"] == RaceDB.form(31), "saved merged parts resolve replacement models")
	print("BEASTS CHECK DONE: %d problem(s)" % bad)
	quit()


func _check(ok: bool, what: String, show := true) -> void:
	if not ok:
		bad += 1
	if show or not ok:
		print("%s %s" % ["ok  " if ok else "FAIL", what])
