extends RefCounted
## Fresh-state regression and windowed captures for the desktop usability pass.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Maps = preload("res://scripts/world/map_loader.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const Room = preload("res://scripts/gfx/room_builder.gd")
const Film = preload("res://scripts/ui/beast_cinematic.gd")
var bad := 0
var main
var opts: Dictionary

func run(host, options: Dictionary) -> void:
	main = host
	opts = options
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen", "called_dad", "got_egg", "has_starter"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	for symbol in "◄►▲▼♂♀★":
		_check(UIKit.font_body().has_char(symbol.unicode_at(0)), "bundled glyph: "+symbol)
	var lettering = load("res://scripts/gfx/world_lettering.gd")
	var encoded: String = lettering.encode("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	_check(encoded.length() == 26 and lettering.encode("hotel") == lettering.encode("HOTEL"), "world alphabet is deterministic and case insensitive")
	for ch in encoded:
		_check(lettering.FONT.has_char(ch.unicode_at(0)), "world alphabet glyph coverage")
	var native_body: Font = load(UIKit.BODY_FONT_FILE)
	_check(absf(UIKit.font_body().get_height(32) - native_body.get_height(32)) <= 1.0, "symbol fallback preserves body face line height")
	_check(Maps.load_map("route1", {}).get("weapon_obstacles", []).is_empty(), "first road has no weapon puzzles")
	for name in ["floor_lamp", "table_lamp"]:
		for palette in 5:
			var mesh := Room.lamp_mesh(name, palette)
			_check(mesh != null and mesh.get_surface_count() >= 2, name+": fabric and fittings remain distinct")
	_check(not "pallet" in Room.KINDS["boxes"]["m"], "ordinary furnished rooms cannot select a pallet")
	await main._go("caccoon", "start")
	var town: Dictionary = main.world.map
	_check(town["buildings"][1]["cove_stucco"] == "red" and not Places.door_locked(town["buildings"][1]), "home is red with an opening blue door")
	for f in main.world.building_fades:
		if f.get("scenery", false):
			_check(f["b"].get("locked", false), "non-enterable scenery home has a red door")
	for y in range(31, int(town["h"])):
		for x in int(town["w"]):
			_check(MG.get_t(town,x,y) != MG.LAMP, "dock has no lightpost at %d,%d" % [x,y])
	for spot in [["home", Vector2i(9,10)], ["waterfront", Vector2i(30,27)], ["docks", Vector2i(40,38)], ["center", town["buildings"][0]["door"]+Vector2i.DOWN]]:
		main.world.spawn_at(spot[1])
		await main._wait(0.6)
		await _shot(String(spot[0]))
	await main._go("caccoon#1", "entry")
	_check(main.world.map["furniture"].get(Vector2i(11,2), "") == "phone", "living-room phone touches the stair wall")
	await _shot("living-room")
	UI.auto = false
	for tile in main.world.map["locked_text"]:
		Places.prop(MG.LOCKED, main.world.map, main.world, tile)
		await main._wait(0.15)
		var dialog = UI.stack.back()
		dialog.text_label.visible_characters = -1
		_check(not dialog.bubble_mode and dialog.speaker == "", "locked kitchen is an observation")
		await _shot("locked-kitchen")
		dialog.close()
		break
	UI.auto = true
	await main._go("caccoon#0", "entry")
	UI.auto = false
	Places.heal_machine(main.world)
	await main._wait(0.2)
	var prompt = UI.stack.back()
	_check(prompt.bubble_mode and prompt.speaker == "Automated Voice" and prompt._anchored, "healing machine speaks from its chamber")
	await _shot("automated-voice")
	await main._press("ui_cancel")
	if not UI.is_touch():
		_check(prompt._answering and prompt._buttons[0].modulate.a == 0 and prompt._buttons[1].modulate.a == 1, "No highlights and Yes disappears")
		await _shot("answer-no")
	await main._wait(0.45)
	_check(UI.stack.is_empty(), "one reply closes the prompt after feedback")
	var beast := Beasts.create(0, 39)
	beast.nickname = "A friend with a long name"
	var view := UI.BeastView.new().setup(beast, beast.nickname)
	UI.push(view)
	await main._wait(0.2)
	_check(UIKit.safe_rect(view).encloses(view._panel.get_global_rect()), "beast summary stays inside the viewport")
	await _shot("beast-info")
	for i in 12:
		await main._press("ui_down")
	await _shot("beast-info-scrolled")
	await main._press("ui_cancel")
	var b := Beasts.create(0, 4)
	var previous := b.growth_look()
	var events: Array = b.gain_xp(b.xp_for_level(5)-b.xp)
	_check(events[0]["before"]["stats"] == previous["stats"] and events[0]["look"]["stats"]["hp"] == b.max_hp(), "level reward preserves its actual old/new stats")
	var film := Film.new().setup("level", events[0]["before"], events[0]["look"])
	film.preview_time = 0.7
	UI.push(film)
	await main._wait(0.1)
	_check(film._stat_rows[0].modulate.a == 1 and film._stat_rows[1].modulate.a == 0, "level cinematic starts with one stat line")
	await _shot("level-first-stat")
	film.preview_time = 3.0
	await main._wait(0.1)
	_check(film._stat_rows.all(func(row): return row.modulate.a == 1), "level cinematic reveals all six stat changes")
	await _shot("level-all-stats")
	film.close()
	UI.place_name("Cocoon Cove")
	UI.pickup("old_sneakers")
	_check(UI.top_bar.current_text() == "Old Sneakers", "pickup replaces arrival notice immediately")
	await _shot("pickup")
	UI.auto = false
	print("POLISH DONE: %d problem(s)" % bad)

func _shot(name: String) -> void:
	if not opts.has("shots") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(String(opts["shots"]))
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main._save_shot(String(opts["shots"]).path_join(name+".png"))

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)
