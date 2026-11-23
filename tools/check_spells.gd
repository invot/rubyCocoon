extends SceneTree
## The hero's elemental attacks (docs/dustwell-implementation-plan.md steps 3 and 4): spell storage and the two-per-
## element limit, trainer MP unlock, growth and recovery, saves old and new, the battle menu's weapon submenu, scrolls,
## beast crit chances by HP band, and the field water targets.
##   godot --headless --path . --script res://tools/check_spells.gd
var bad := 0
var ui: Node
var state: Node
var story: Node
var menus: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ui = root.get_node("UI")
	state = root.get_node("GameState")
	story = root.get_node("Story")
	menus = root.get_node("Menus")
	ui.auto = true
	# saves go to an isolated folder under build/, never the player's slots
	var fake_main := Node.new()
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar _test := {\"save_dir\": \"res://build/spell_test_saves/\"}\n"
	gs.reload()
	fake_main.set_script(gs)
	root.add_child(fake_main)
	var real_main = state.main
	state.main = fake_main
	_check(state.save_dir().begins_with("res://build/"), "isolated spell save folder")
	var SpellDB: GDScript = load("res://scripts/data/spell_db.gd")
	var ItemDB: GDScript = load("res://scripts/data/item_db.gd")
	var Battle: GDScript = load("res://scripts/battle/battle.gd")

	# ---------------- storage, MP unlock and growth
	state.new_game("Tester")
	state.trainer_level = 4
	_check(not state.trainer_mp_unlocked() and state.trainer_max_mp() == 0, "no MP before the first spell")
	_check(state.learn_spell("water") and state.knows_spell("water") and state.flag("learned_water"), "learn Water")
	_check(state.trainer_mp_unlocked() and state.trainer_mp == SpellDB.max_mp_at(4) and state.trainer_mp > 0, "first spell unlocks full MP")
	_check(not state.learn_spell("water"), "a known spell isn't learned twice")
	_check(state.learn_spell("torrent"), "second water spell fits")
	_check(not state.learn_spell("ice"), "a third water spell needs a forget")
	_check(state.learn_spell("ice", "water") and not state.knows_spell("water") and state.knows_spell("ice"), "forget Water to learn Ice")
	_check(state.learned_spell("water"), "a forgotten field spell still works with the song")
	_check(not state.learn_spell("blizzard", "fire_thing"), "forgetting an unknown spell is refused")
	var before_max: int = state.trainer_max_mp()
	state.trainer_mp = 0
	var gained: int = state.add_trainer_xp(state.trainer_xp_for(5) - state.trainer_xp)
	_check(gained == 1 and state.trainer_max_mp() == before_max + SpellDB.MP_PER_LEVEL and state.trainer_mp == SpellDB.MP_PER_LEVEL, "a trainer level raises max MP and fills the new room")
	_check(state.restore_trainer_mp(999) == state.trainer_max_mp() - SpellDB.MP_PER_LEVEL and state.trainer_mp == state.trainer_max_mp(), "MP recovery caps at max")
	_check(state.spend_trainer_mp(4) and not state.spend_trainer_mp(999), "spending MP")
	state.heal_party()
	_check(state.trainer_mp == state.trainer_max_mp(), "healing the party restores the hero's MP")

	# ---------------- saves
	_check(state.save_game(8), "save with spells")
	state.known_spells = []
	state.trainer_mp = 0
	_check(state.load_game(8) and state.known_spells == ["torrent", "ice"] and state.trainer_mp == state.trainer_max_mp(), "spells and MP survive a save")
	var f := FileAccess.open(state.slot_path(8), FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.erase("known_spells")
	d.erase("trainer_mp")
	d["flags"].erase("learned_torrent")
	d["flags"].erase("learned_ice")
	d["flags"].erase("trainer_mp_unlocked")
	d["flags"]["learned_water"] = false
	f = FileAccess.open(state.slot_path(8), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_check(state.load_game(8) and state.known_spells.is_empty() and not state.trainer_mp_unlocked(), "an old save starts with no spells")
	d["flags"]["learned_water"] = true
	f = FileAccess.open(state.slot_path(8), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_check(state.load_game(8) and state.known_spells == ["water"] and state.trainer_mp == state.trainer_max_mp(), "an old save that learned Water from Dale keeps it")

	d["flags"]["dance_shoes_returned"] = true
	d["inventory"]["dance_shoes"] = 1
	d["locker"]["dance_shoes"] = 1
	d["gear"]["feet"] = "dance_shoes"
	d["courier_request"] = {"service": 1, "items": {"dance_shoes": 1}}
	f = FileAccess.open(state.slot_path(8), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	_check(state.load_game(8) and state.flag("well_restored") and state.flag("river_restored") and state.flag("band_freed"), "completing the old dance gate preserves travel and band progression")
	_check(not state.flag("dance_shoes_returned") and state.item_count("dance_shoes") == 0
		and state.gear["feet"] == "" and not state.locker.has("dance_shoes"), "retired shoes leave inventory, equipment and storage")
	_check(int(state.courier_request.get("service", -1)) == 1 and state.courier_request.get("items", {}).is_empty(), "retiring reserved shoes preserves the requested courier service")

	# ---------------- scrolls and the forget prompt
	state.new_game("Tester")
	var scroll: Dictionary = ItemDB.get_item("scroll_ice")
	_check(scroll.get("kind", "") == "scroll" and scroll.get("spell", "") == "ice", "scroll items")
	state.receive_item("scroll_ice")
	await menus.use_bag_item("scroll_ice")
	_check(state.knows_spell("ice") and state.item_count("scroll_ice") == 0, "reading a scroll teaches its spell and uses it up")
	state.learn_spell("water")
	state.receive_item("scroll_torrent")
	await menus.use_bag_item("scroll_torrent")
	_check(not state.knows_spell("torrent") and state.item_count("scroll_torrent") == 1, "declining to forget keeps the scroll")
	ui.auto_answers = [0]
	await menus.use_bag_item("scroll_torrent")
	_check(state.known_spells == ["water", "torrent"] and state.item_count("scroll_torrent") == 0, "forgetting Ice makes room for Torrent")
	state.trainer_mp = 0
	state.receive_item("spirit_drop")
	await menus.apply_hero_item("spirit_drop")
	_check(state.trainer_mp == mini(15, state.trainer_max_mp()) and state.item_count("spirit_drop") == 3 + 1 - 1, "a Spirit Drop restores the hero's MP")

	# ---------------- beast crits by HP band (none for the hero: weapons pass crit false)
	_check(Battle._beast_crit_chance(0.8, 0.0) == 0.0 and Battle._beast_crit_chance(0.51, 0.0) == 0.0, "no crits in the green")
	_check(is_equal_approx(Battle._beast_crit_chance(0.5, 0.0), 0.05) and is_equal_approx(Battle._beast_crit_chance(0.25, 0.0), 0.15), "yellow 5% to 15%")
	_check(is_equal_approx(Battle._beast_crit_chance(0.0, 0.0), 0.30) and Battle._beast_crit_chance(0.2, 0.0) > 0.15, "red 15% to 30%")
	_check(is_equal_approx(Battle._beast_crit_chance(0.8, 0.1), 0.1), "a move's crit bonus adds on")
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	_check(src.count("\"crit\": true") == 0, "no weapon or trainer hit is ever critical")

	# ---------------- field water targets
	state.new_game("Tester")
	var map := {"id": "test", "kind": "route", "anchors": {"water_panel": Vector2i(2, 2), "river_lip": Vector2i(4, 2)}}
	var targets: Array = story._water_targets(map)
	_check(targets.size() == 2, "a map's tagged water targets stand there")
	for t in targets:
		if t.has("scene") and is_instance_valid(t["scene"]):
			t["scene"].free()
	state.set_flag("water_mages_found")
	targets = story._water_targets(map)
	_check(targets.size() == 1 and targets[0]["target"] == "river_lip", "a done target is gone")
	for t in targets:
		if t.has("scene") and is_instance_valid(t["scene"]):
			t["scene"].free()
	_check(story.WATER_TARGETS["river_lip"]["spell"] == ["torrent"] and story.WATER_TARGETS["water_panel"]["spell"].has("water"), "Water opens panels, Torrent raises the river")
	state.gear["acc"] = "wellspring_pendant"
	_check(is_equal_approx(state.gear_fx("spell_water"), 0.25) and state.gear_fx("spell_fire") == 0.0, "the Wellspring Pendant strengthens water attacks only")
	state.gear["acc"] = ""
	_check(src.contains("gear_fx(\"spell_\" + SpellDB.element(_weapon_spell))"), "the hero's elemental attacks read the spell_<element> gear effect")
	var story_src: String = FileAccess.get_file_as_string("res://scripts/autoload/story.gd")
	_check(story_src.count("flute_ex(\"song_tides\"") == 0 and story_src.get_slice("func field_cast", 1).get_slice("\nfunc ", 0).count("flute") == 0,
		"learning and casting elemental spells never uses the flute")

	state.main = real_main
	fake_main.queue_free()
	print("SPELLS DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)
