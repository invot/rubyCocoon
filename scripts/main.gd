extends Node
## Game root: owns the pixelated 3D view, the title screen, map transitions and battles.

const World = preload("res://scripts/world/world.gd")
const Battle = preload("res://scripts/battle/battle.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const CommandPanelScript = preload("res://scripts/battle/command_panel.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

## PSX look: the 3D world renders at about this many lines, then each pixel is blown up by a whole number of screen
## pixels (4x at 1080p, 3x at 900p...) with nearest sampling, so the pixels stay crisp and evenly sized. The UI is
## drawn on top at full resolution.
const PSX_LINES := 270

## Shows the low-resolution 3D view, scaled up to fill the window.
var screen: TextureRect
var view: SubViewport
var world = null
var in_battle := false
var _pending_goto: Dictionary = {}
var _transitioning := false
var _title_nodes: Array = []
var _test := {}
var autoplay := false


func _ready() -> void:
	GameState.main = self
	if Prefs.is_mobile():
		# a steady 60 fps: chasing a 120-144 Hz screen makes uneven frames and heats the phone until it throttles
		Engine.max_fps = 60
	view = SubViewport.new()
	view.handle_input_locally = false
	view.audio_listener_enable_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# hard pixel edges, like the hardware: no anti-aliasing at this resolution
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(view)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	get_window().size_changed.connect(_fit_view)
	_fit_view()
	_parse_test_args()
	if _test.has("scene"):
		_run_test.call_deferred()
	else:
		_title.call_deferred()


func _exit_tree() -> void:
	if world != null and is_instance_valid(world) and not world.is_inside_tree():
		world.free()


## Taps (and mouse clicks) on the world walk the player there; see world.gd tap_at().
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed and world != null and not in_battle and not _transitioning and not world.demo:
		if UI.touch_blocks(ev.position) or not UI.stack.is_empty():
			return
		world.tap_at(to_view(ev.position))


## Sizes the 3D view to the window: PSX_LINES tall, give or take, at a whole-number scale.
func _fit_view() -> void:
	var win := Vector2(get_window().size)
	if win.y < 1.0:
		return
	var k := maxf(1.0, roundf(win.y / float(PSX_LINES)))
	view.size = Vector2i(ceili(win.x / k), ceili(win.y / k))


## A point on the screen (in UI units) -> the same point in the low-resolution 3D view.
func to_view(p: Vector2) -> Vector2:
	return p * Vector2(view.size) / get_viewport().get_visible_rect().size


func _process(_delta: float) -> void:
	if not _pending_goto.is_empty() and not _transitioning and not in_battle:
		if world == null or (not world.busy and not UI.busy()):
			var g := _pending_goto
			_pending_goto = {}
			_do_goto(g["map"], g["spawn"], g.get("face", Vector2i.ZERO))


# ================================================================ title
func _title() -> void:
	UI.allow_pause = false
	_load_world("caccoon", "start", true)
	Sfx.music("title")
	Sfx.ambience("")
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 70
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	UI.hud.add_child(box)
	var t := UIKit.shadow_label("RUBY COCOON", 64, UIKit.GOLD_BRIGHT)
	t.add_theme_font_size_override("font_size", UIKit.head_px(96))
	t.add_theme_constant_override("outline_size", 18)
	t.add_theme_color_override("font_outline_color", Color("#493333"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var rib := UIKit.ribbon("Hatch · Train · Merge · Battle")
	rib.custom_minimum_size.x = 640
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rib)
	_title_nodes = [box]
	while true:
		var items := []
		if GameState.has_save():
			items.append("Continue")
			items.append("Load Game")
		items.append("New Game")
		if not Prefs.is_mobile():
			items.append("Quit")
		var c: int = await UI.choose("", items, {"anchor": "bottom", "width": 280, "cancel": false, "margin": Vector2(0, 60)})
		var pick: String = items[c]
		if pick == "Quit":
			get_tree().quit()
			return
		var load_slot := -1
		if pick == "Continue":
			load_slot = GameState.latest_slot()
		elif pick == "Load Game":
			_title_nodes[0].visible = false
			load_slot = await slot_manager()
			_title_nodes[0].visible = true
		if load_slot >= 0 and GameState.load_game(load_slot):
			_clear_title()
			UI.allow_pause = true
			var spawn = GameState.pos if GameState.pos.x >= 0 else "center"
			_pending_goto = {"map": GameState.map_id, "spawn": spawn}
			return
		if pick == "New Game":
			var nm := await UI.text_input("What's your name, trainer?", "Andrew")
			GameState.new_game(nm)
			_clear_title()
			UI.allow_pause = true
			var home := MapLoader.interior_of("caccoon", "home")
			# the first morning starts in your bedroom
			_pending_goto = {"map": home if home != "" else "caccoon", "spawn": "wake" if home != "" else "start"}
			return


## From the Start book: back to the title screen.
func back_to_title() -> void:
	await UI.fade_out(0.3)
	UI.clear_all()
	_pending_goto = {}
	await get_tree().process_frame
	_title()
	await UI.fade_in(0.3)


func _clear_title() -> void:
	_hide_slot_preview()
	for n in _title_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_title_nodes = []


# ================================================================ maps
func _load_world(id: String, spawn, demo := false, face := Vector2i.ZERO) -> void:
	if world != null:
		if world.get_parent():
			world.get_parent().remove_child(world)
		world.queue_free()
		world = null
	world = World.new()
	world.demo = demo
	view.add_child(world)
	world.build(id)
	if demo:
		world.player.visible = false
	else:
		world.spawn_at(spawn, face)


func music_for(id: String) -> String:
	if MapLoader.is_interior(id):
		var m := MapLoader.load_map(id, GameState.flags)
		return String(WorldDB.ROOM_MUSIC.get(m.get("building", {}).get("shop", ""), "shop"))
	if WorldDB.MAP_MUSIC.has(id):
		return WorldDB.MAP_MUSIC[id]
	return String(WorldDB.biome_of(id).get("music", "coast"))


func ambience_for(id: String) -> String:
	if MapLoader.is_interior(id):
		var m := MapLoader.load_map(id, GameState.flags)
		return String(WorldDB.ROOM_AMBIENCE.get(m.get("building", {}).get("shop", ""), ""))
	return String(WorldDB.BIOME_AMBIENCE.get(WorldDB.biome_of(id)["id"], ""))


## Queue a transition; it runs as soon as the current interaction finishes.
func goto_map(id: String, spawn = "start", face := Vector2i.ZERO) -> void:
	_pending_goto = {"map": id, "spawn": spawn, "face": face}
	if world != null:
		world.frozen = true


func reload_map() -> void:
	if world == null:
		return
	GameState.facing = world.facing
	goto_map(world.map_id, world.player_pos)


func _do_goto(id: String, spawn, face := Vector2i.ZERO) -> void:
	_transitioning = true
	if world != null and not world.demo:
		Sfx.play("door")
	await UI.fade_out(0.25)
	_load_world(id, spawn, false, face)
	GameState.map_id = id
	GameState.visit(id)
	GameState.pos = world.player_pos
	Sfx.music(music_for(id))
	Sfx.ambience(ambience_for(id))
	await UI.fade_in(0.3)
	var sub := ""
	var title := WorldDB.map_name(id)
	if MapLoader.is_interior(id):
		title = world.map["name"]
		sub = WorldDB.map_name(MapLoader.parent_of(id))
		if int(world.map.get("floors", 1)) > 1:
			sub = "Floor %d  ·  %s" % [int(world.map["floor_num"]), sub]
	elif WorldDB.is_town(id):
		sub = WorldDB.TOWNS[id]["size"].capitalize()
	elif WorldDB.ROUTES.has(id):
		var lv: Array = WorldDB.ROUTES[id]["lv"]
		sub = "Wild beasts Lv %d-%d" % [lv[0], lv[1]]
	if (typeof(spawn) != TYPE_VECTOR2I or MapLoader.is_interior(id)) and not (MapLoader.is_interior(id) and world.map["building"]["shop"] == "house"):
		UI.banner(title, sub)
	_transitioning = false
	await Story.on_map_enter(world)


## Saves into the game's own slot, or the first empty one on its first save (asking which to overwrite if all ten
## are full), with a snapshot of the world without any UI.
func save_now() -> bool:
	if world != null:
		GameState.pos = world.player_pos
		GameState.facing = world.facing
		GameState.map_id = world.map_id
	var slot := GameState.current_slot
	if slot < 0:
		slot = GameState.first_free_slot()
	if slot < 0:
		slot = await pick_slot("All ten slots are full. Overwrite which one?")
		if slot < 0:
			return false
	return GameState.save_game(slot, snapshot())


## Saves and shows the "Game saved!" card.
func save_with_card() -> bool:
	var ok: bool = await save_now()
	if ok:
		Sfx.play("levelup")
		await UI.show_save_card(GameState.current_slot)
	else:
		Sfx.play("error")
		UI.toast("The game was not saved.", UIKit.ACCENT)
	return ok


## The 3D view only (no HUD or menus), shrunk to a thumbnail.
func snapshot() -> Image:
	if view == null or DisplayServer.get_name() == "headless":
		return null
	var img := view.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var w := 384
	img.resize(w, maxi(1, int(w * float(img.get_height()) / float(img.get_width()))), Image.INTERPOLATE_BILINEAR)
	return img


# ================================================================ save slots
var _slot_preview: Control = null


## Picks one of the ten slots. `preview` shows the slot's snapshot beside the list: only when saving during play.
## Returns -1 if cancelled.
func pick_slot(title: String, only_filled := false, preview := true) -> int:
	var items := _slot_items(only_filled)
	var opts := {"anchor": "right", "width": 420, "rows": 10, "margin": Vector2(40, 0)}
	if preview:
		_show_slot_preview(0)
		opts["on_focus"] = func(k): _show_slot_preview(k)
	var c: int = await UI.choose(title, items, opts)
	_hide_slot_preview()
	return c


## The ten slots as menu rows: name and play time, with where and when in the description.
func _slot_items(only_filled: bool) -> Array:
	var items := []
	for i in GameState.SLOT_COUNT:
		var info := GameState.slot_info(i)
		if info.is_empty():
			items.append({"text": "Slot %d" % (i + 1), "right": "empty", "disabled": only_filled, "desc": "An empty slot."})
		else:
			items.append({"text": "Slot %d   %s" % [i + 1, info["name"]], "right": GameState.time_text(info["play_time"]),
				"desc": "%s  ·  saved %s
%s" % [info["place"], info["date"], ", ".join((info["party"] as Array).slice(0, 3)) if not (info["party"] as Array).is_empty() else "No beasts yet"]})
	return items


func _show_slot_preview(i: int) -> void:
	_hide_slot_preview()
	if UI.auto:
		return
	var p := UIKit.panel(Vector2(500, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var info := GameState.slot_info(i)
	vb.add_child(UIKit.header("Slot %d" % (i + 1), UIKit.ACCENT))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box("slot", Vector4(4, 4, 4, 4)))
	vb.add_child(frame)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(448, 252)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = GameState.slot_texture(i)
	frame.add_child(tr)
	if info.is_empty():
		vb.add_child(UIKit.label("An empty slot.", 24, UIKit.DIM))
	else:
		vb.add_child(UIKit.label("%s  ·  %s" % [info["name"], info["place"]], 33, UIKit.INK))
		vb.add_child(UIKit.label("Play time %s   ·   saved %s" % [GameState.time_text(info["play_time"]), info["date"]], 20, UIKit.DIM))
		vb.add_child(UIKit.label(", ".join((info["party"] as Array).slice(0, 6)) if not (info["party"] as Array).is_empty() else "No beasts yet", 20, UIKit.DIM))
	UI.hud.add_child(p)
	UIKit.place(p, "left", Vector2(40, 0))
	_slot_preview = p


func _hide_slot_preview() -> void:
	if _slot_preview != null and is_instance_valid(_slot_preview):
		_slot_preview.queue_free()
	_slot_preview = null


## The title screen's slot manager: load, copy or delete saves. Returns the slot to load, or -1.
func slot_manager() -> int:
	var last := 0
	while true:
		if not GameState.has_save():
			return -1
		var c: int = await UI.choose("Saved games", _slot_items(true), {"anchor": "right", "width": 420, "rows": 10, "margin": Vector2(40, 0), "start": last})
		if c < 0:
			return -1
		last = c
		var a: int = await UI.choose("Slot %d" % (c + 1), [
			{"text": "Load", "desc": "Continue this journey."},
			{"text": "Copy", "desc": "Copy this save into another slot."},
			{"text": "Delete", "desc": "Erase this save for good."},
			{"text": "Back"}], {"anchor": "right", "width": 300, "margin": Vector2(40, 0)})
		match a:
			0:
				return c
			1:
				var to := await pick_slot("Copy slot %d to..." % (c + 1), false, false)
				if to >= 0 and to != c:
					if GameState.slot_exists(to) and not await UI.ask("Slot %d already has a save. Overwrite it?" % (to + 1)):
						continue
					if GameState.copy_slot(c, to):
						Sfx.play("confirm")
						UI.toast("Copied slot %d to slot %d." % [c + 1, to + 1])
						last = to
			2:
				if await UI.ask("Delete the save in slot %d? This can't be undone." % (c + 1)):
					GameState.delete_slot(c)
					Sfx.play("back")
					UI.toast("Slot %d deleted." % (c + 1))
	return -1


# ================================================================ battles
## Wild battles open with a spiral: green when you sneak up on a beast, blue face to face, red when it ambushes you.
const SPIRAL_COLORS := {"sneak": Color("#3fbf5a"), "wild": Color("#3f8fe0"), "ambush": Color("#d83a3a")}


func start_battle(cfg: Dictionary) -> String:
	in_battle = true
	if autoplay:
		cfg["autoplay"] = true
	Sfx.play("encounter")
	if not _test.is_empty():
		print("[battle] intro=", cfg.get("intro", "trainer"), " ambush=", cfg.get("ambush", ""), " foes=", cfg["foes"].map(func(f): return "%s L%d" % [f.nickname, f.level]))
	var spiral: bool = SPIRAL_COLORS.has(String(cfg.get("intro", "")))
	if spiral:
		await UI.spiral_in(SPIRAL_COLORS[String(cfg["intro"])], 0.8)
	else:
		await UI.flash(Color.WHITE, 2)
		await UI.fade_out(0.2)
	view.remove_child(world)
	var b := Battle.new()
	cfg["map"] = GameState.map_id
	b.setup(cfg)
	view.add_child(b)
	if spiral:
		await UI.spiral_out(0.35)
	else:
		await UI.fade_in(0.25)
	var result: String = await b.finished
	await UI.fade_out(0.3)
	view.remove_child(b)
	b.queue_free()
	view.add_child(world)
	world.cam.current = true
	world.refresh_locks()
	Sfx.music(music_for(world.map_id))
	in_battle = false
	GameState.recharge_shield()
	if result == "lose":
		GameState.heal_party()
		GameState.gold = int(GameState.gold * 0.5)
		var town := WorldDB.nearest_center(world.map_id, GameState.visited)
		GameState.last_center = town
		goto_map(town, "center")
		UI.toast("You lost half your gold...", UIKit.ACCENT)
	await UI.fade_in(0.3)
	return result


# ================================================================ test / screenshot harness
## Usage: godot --path . -- --scene=world:caccoon --shot=C:/tmp/a.png --wait=3
func _parse_test_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			_test[kv[0]] = kv[1]


func _run_test() -> void:
	var scene: String = _test["scene"]
	var wait := float(_test.get("wait", "3"))
	if _test.has("gem"):
		# try a gem for this run only (the player's saved setting is left alone)
		UIKit.set_accent(String(_test["gem"]))
		UI.root.theme = UIKit.make_theme()
		UI.controls.refresh()
	GameState.new_game("Tester")
	GameState.set_flag("intro_done")
	GameState.set_flag("got_egg")
	GameState.set_flag("has_starter")
	GameState.set_flag("tutorial_done")
	GameState.gear["flute"] = "reed_flute"
	GameState.set_flag("reed_flute")
	GameState.learn_song("weaken")
	GameState.learn_song("capture3")
	for r in [1, 12, 24]:
		var b := Beasts.create(r, 12)
		GameState.add_beast(b)
	if scene.begins_with("world:"):
		var id := scene.substr(6)
		var sp = _test.get("spawn", "start")
		if "," in String(sp):
			sp = Vector2i(int(String(sp).get_slice(",", 0)), int(String(sp).get_slice(",", 1)))
		if _test.has("flags"):
			for f in String(_test["flags"]).split("+"):
				GameState.set_flag(f)
		_do_goto(id, sp)
		if _test.has("overview"):
			# look down on the whole map from high above its south edge (--overview=1, or =height)
			while not is_instance_valid(world) or world.cam == null:
				await get_tree().process_frame
			world.cam_free = true
			var mw: float = world.map["w"]
			var mh: float = world.map["h"]
			var hgt := maxf(float(_test["overview"]), 1.0) if float(_test["overview"]) > 1.0 else maxf(mw, mh) * 0.75
			world.cam.position = Vector3(mw / 2.0, hgt, mh + hgt * 0.45)
			world.cam.look_at(Vector3(mw / 2.0, 0, mh * 0.45), Vector3.UP)
		await get_tree().create_timer(wait).timeout
	elif scene == "battle":
		_do_goto("route3", "south")
		await get_tree().create_timer(1.0).timeout
		var foes := [Beasts.create(13, 10), Beasts.create(36, 11), Beasts.create(7, 12, true)]
		if _test.get("kind", "") == "robots":
			foes = [Beasts.create(53, 12), Beasts.create(54, 12), Beasts.create(55, 12)]
			start_battle({"wild": false, "foes": foes, "seed": 5, "trainer": {"name": "Gearhart", "cls": "CEO", "look": {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}}})
		else:
			start_battle({"wild": true, "foes": foes, "seed": 5})
		await get_tree().create_timer(wait).timeout
	elif scene == "ring":
		# a trainer battle on the ring, driven by key presses once the command panel is up:
		#   --keys=a,r,a,d,u,b...  (a = A, b = B, l / r = left / right, u / d = up / down), --kind=wild for wild beasts
		_do_goto("route3", "south")
		await _wait(1.0)
		var flv := int(_test.get("foe_level", "10"))
		var team := [Beasts.create(13, flv), Beasts.create(16, flv + 1), Beasts.create(23, flv), Beasts.create(20, flv - 1), Beasts.create(12, flv)]
		if _test.get("kind", "") == "wild":
			start_battle({"wild": true, "foes": [Beasts.create(13, 10), Beasts.create(36, 11)], "seed": 5})
		else:
			start_battle({"wild": false, "foes": team, "seed": 5, "trainer": {"name": "Marina", "cls": "Swimmer", "shield": int(_test.get("foe_shield", "1")),
				"look": {"skin": "#e0b090", "hair": "#2a4a8a", "shirt": "#3a8ac8", "pants": "#1a2a4a"}}})
		var tries := 0
		while tries < 400 and not (UI.stack.size() > 0 and UI.stack.back() is CommandPanelScript):
			await get_tree().process_frame
			tries += 1
		for k in String(_test.get("keys", "")).split(",", false):
			await _press({"a": "ui_accept", "b": "ui_cancel", "l": "ui_left", "r": "ui_right", "u": "ui_up", "d": "ui_down"}.get(k, "ui_accept"))
			await _wait(float(_test.get("gap", "0.4")))
		await _wait(wait)
	elif scene == "defeat":
		# a foe vanishing in a puff of smoke, with a damage number on its partner (--at = seconds after the puff)
		_do_goto("route3", "south")
		await _wait(1.0)
		start_battle({"wild": true, "foes": [Beasts.create(13, 10), Beasts.create(36, 11)], "seed": 5})
		await _wait(2.5)
		var bt: Node = null
		for c in view.get_children():
			if c is Battle:
				bt = c
		bt.msg_label.text = "Emberkit gained 27 XP. Redcoon grew to Lv 13!"
		bt.foe_slots[0].hp = 0
		bt._handle_faints()
		bt._float_text(bt.foe_slots[1], "-27", Color("#ffe060"))
		await _wait(float(_test.get("at", "0.2")))
	elif scene == "flute":
		_do_goto("route1", "south")
		await get_tree().create_timer(1.0).timeout
		var fo := {}
		if _test.has("level"):
			fo["level"] = int(_test["level"])
		if _test.has("coach"):
			fo["coach"] = "Mom"
		UI.flute_ex(_test.get("song", "shanty"), "Test", fo)
		if _test.has("play"):
			await get_tree().create_timer(0.3).timeout
			var g = UI.stack.back()
			g._end_listen()
			for i in int(_test["play"]):
				g.phase = "play"
				for btn in g.melody[i]:
					g._press(int(btn))
				await get_tree().create_timer(0.3).timeout
			if _test.has("slip"):
				g._slip(0)
		await get_tree().create_timer(wait).timeout
	elif scene == "sim":
		Engine.time_scale = 40.0
		_do_goto("route5", "south")
		await get_tree().create_timer(1.0).timeout
		var tally := {}
		for i in int(_test.get("n", "6")):
			GameState.heal_party()
			var foes2 := []
			for k in randi_range(1, 3):
				foes2.append(Beasts.create(randi_range(0, 47), randi_range(9, 14), randf() < 0.3))
			var r: String = await start_battle({"wild": i % 2 == 0, "foes": foes2, "autoplay": true, "trainer": {"name": "Sim", "cls": "Bot"}})
			tally[r] = tally.get(r, 0) + 1
			print("battle ", i, ": ", r, "  party lv ", GameState.party.map(func(x): return x.level))
		print("SIM RESULTS ", tally)
		# merge checks
		var a := Beasts.create(1, 20)
		var b2 := Beasts.create(36, 20)
		var m := Beasts.merge(a, b2, true)
		print("merge: ", m.nickname, " rank ", m.rank, " lv ", m.level, " el ", m.element, " moves ", m.moves, " genes ", m.genes)
		var g := Beasts.create(5, 20, true)
		print("ghost merge allowed? ", Beasts.can_merge(m, g, false), " | ", Beasts.can_merge(a, g, true))
		print("capture chance lv5 Capture III acc1 full hp: ", GameState.capture_chance(Beasts.create(0, 5), "capture3", 1.0))
		Engine.time_scale = 1.0
	elif scene == "flow":
		await _flow_test()
	elif scene == "dialog":
		_do_goto("caccoon", "start")
		await get_tree().create_timer(1.5).timeout
		UI.say(["Ah, Tester! There you are. Today you become a beast trainer. Every trainer needs a partner, and I have four young beasts here."], "Elder Rowan")
		await get_tree().create_timer(wait).timeout
	elif scene == "center":
		_do_goto("caccoon", "center")
		await get_tree().create_timer(1.5).timeout
		Places.storage()
		await get_tree().create_timer(0.3).timeout
		Menus.pick_beast("Withdraw which beast?", GameState.party)
		await get_tree().create_timer(wait).timeout
	elif scene == "input":
		_do_goto("caccoon", "start")
		await _wait(1.5)
		var start_pos: Vector2i = world.player_pos
		Input.action_press("move_right")
		await _wait(0.6)
		Input.action_release("move_right")
		await _wait(0.4)
		print("walked from ", start_pos, " to ", world.player_pos)
		_press("menu")
		await _wait(0.3)
		print("menu open: ", UI.stack.size())
		_press("ui_down")
		await _wait(0.15)
		_press("ui_down")
		await _wait(0.15)
		_press("ui_accept")
		await _wait(0.4)
		print("after accept stack: ", UI.stack.size(), " top title: ", UI.stack.back().title if UI.stack.size() > 0 and "title" in UI.stack.back() else "?")
		_press("ui_cancel")
		await _wait(0.3)
		_press("ui_cancel")
		await _wait(0.3)
		_press("ui_cancel")
		await _wait(0.3)
		print("menus closed: ", UI.stack.size() == 0)
		_press("pause")
		await _wait(0.3)
		print("paused: ", get_tree().paused, " overlay: ", UI.stack.size())
		_press("pause")
		await _wait(0.3)
		print("unpaused: ", not get_tree().paused)
		_press("interact")
		await _wait(0.3)
		print("interact ok, stack: ", UI.stack.size())
		while UI.stack.size() > 0:
			_press("ui_accept")
			await _wait(0.2)
		Input.action_press("move_up")
		await _wait(0.8)
		Input.action_release("move_up")
		await _wait(0.3)
		print("walked to ", world.player_pos)
	elif scene == "doors":
		_do_goto("caccoon", "center")
		await _wait(1.5)
		print("outside at ", world.player_pos, " facing ", world.facing, " map ", world.map_id)
		Input.action_press("move_up")
		await _wait(0.3)
		Input.action_release("move_up")
		await _wait(1.5)
		print("after walking into door: map ", world.map_id, " at ", world.player_pos, " npcs ", world.npcs.size())
		# up to the nurse's counter
		Input.action_press("move_up")
		await _wait(2.0)
		Input.action_release("move_up")
		await _wait(0.4)
		_press("interact")
		await _wait(0.6)
		print("talk to nurse at ", world.player_pos, " -> stack ", UI.stack.size(), " top ", UI.stack.back().title if UI.stack.size() > 0 and "title" in UI.stack.back() else "")
		while UI.stack.size() > 0:
			_press("ui_cancel")
			await _wait(0.25)
		Input.action_press("move_down")
		await _wait(2.6)
		Input.action_release("move_down")
		await _wait(1.5)
		print("after leaving: map ", world.map_id, " at ", world.player_pos, " facing ", world.facing)
	elif scene == "knock":
		# locked doors: you knock and someone shouts through it; the cathedral opens once its guard is beaten
		UI.auto = true
		for spec in [["tidewater", "house"], ["gravenmoor", "cathedral"]]:
			_do_goto(spec[0], "start")
			await _wait(1.0)
			for b in world.map["buildings"]:
				if b["shop"] != spec[1]:
					continue
				print("%s %s door %s locked=%s" % [spec[0], b["shop"], b["door"], b.get("locked", false)])
				if b.get("locked", false):
					await world._enter_building(b)
					print("  knock -> ", UI.auto_log, "  still on ", world.map_id)
					UI.auto_log.clear()
			if spec[1] == "cathedral":
				GameState.set_flag("tr_gravenmoor_gate")
				world.refresh_locks()
				for b in world.map["buildings"]:
					if b["shop"] == "cathedral":
						print("  after the guard falls: locked=%s" % b.get("locked", false))
		UI.auto = false
	elif scene == "skytower":
		# into the Sky Tower, a word at the ticket desk, up the stairs to the roof and away on the Thunderhawk
		UI.auto = true
		GameState.visited = ["caccoon", "tidewater"]
		GameState.gold = 500
		_do_goto("tidewater", "skytower")
		await _wait(1.0)
		await world._enter_building(world.doors[world.player_pos + Vector2i(0, -1)])
		await _wait(1.2)
		print("inside: ", world.map_id, " at ", world.player_pos)
		for p in world.npcs:
			if world.npcs[p].get("kind", "") == "keeper":
				await Story.talk(world, world.npcs[p])
		print("  desk -> ", UI.auto_log)
		UI.auto_log.clear()
		var stairs: Vector2i = world.map["exits"].keys().filter(func(t): return "@2" in String(world.map["exits"][t]["to"]))[0]
		world.player_pos = stairs + Vector2i(0, 1)
		world.player.position = world.tile_pos(world.player_pos)
		world._step(Vector2i(0, -1), false)
		await _wait(2.0)
		print("upstairs: ", world.map_id, " at ", world.player_pos, " npcs ", world.npcs.values().map(func(n): return n.get("name", "")))
		UI.auto_answers = [0]
		for p in world.npcs:
			if world.npcs[p].get("id", "") == "thunderhawk":
				await Story.talk(world, world.npcs[p])
		await _wait(2.0)
		print("  bird -> ", UI.auto_log, "  now at ", world.map_id, " gold ", GameState.gold)
		UI.auto = false
	elif scene == "worldmap":
		GameState.visited = ["caccoon", "tidewater", "shellhaven", "kelpwick", "dustwell"]
		GameState.crests = ["Wave Crest", "Coral Crest"]
		_do_goto("route3", "south")
		await _wait(1.5)
		Menus.world_map()
		await _wait(wait)
	elif scene.begins_with("beasts:"):
		await _beast_gallery(int(scene.substr(7)))
		await _wait(wait)
	elif scene.begins_with("styles:"):
		await _style_gallery(scene.substr(7))
		await _wait(wait)
	elif scene.begins_with("gallery:"):
		var parts := scene.split(":")
		await _gallery(parts[1], int(parts[2]) if parts.size() > 2 else 0)
		await _wait(wait)
	elif scene.begins_with("book"):
		_do_goto(_test.get("map", "tidewater"), "center")
		await _wait(1.5)
		GameState.gold = 4321
		GameState.max_shield = 2
		GameState.shield = 2
		GameState.shards = 3
		GameState.crests = ["Wave Crest", "Coral Crest", "Spur Crest"]
		GameState.learn_song("jig")
		GameState.learn_song("lullaby")
		GameState.add_egg(14)
		for id in ["potion", "fire_bomb", "haste_tonic", "power_collar", "sheet_hymn", "silver_flute"]:
			GameState.add_item(id, 2)
		var m := Beasts.merge(Beasts.create(1, 20), Beasts.create(36, 20))
		m.level = 24
		GameState.beast_slots = 4
		GameState.add_beast(m)
		for i in 10:
			GameState.seen[str(i * 3)] = true
		Menus.pause_menu(world, scene.get_slice(":", 1))
		await _wait(0.6)
		for i in int(_test.get("downs", "0")):
			_press("ui_down")
			await _wait(0.12)
		await _wait(wait)
	elif scene == "tutorial":
		# the starter-egg state: one fresh Lv1 hatchling, lesson not done yet
		GameState.party = [Beasts.create(1, 1)]
		GameState.party[0].heal_full()
		GameState.set_flag("tutorial_done", false)
		_do_goto("caccoon", "center")
		await _wait(1.5)
		if _test.get("auto", "0") == "1":
			UI.auto = true
			# R1 slingshot, Fight, Ember | R2 watch, Defend | R3 items, Minor Potion, on Emberkit, Fight, Ember
			GameState.gear["flute"] = ""
			UI.auto_answers = [0, 0, 1, 3, 1, 1, 0, 0, 0, 1]
			await Story.talk(world, _npc("guard"))
			print("tutorial result: done=", GameState.flag("tutorial_done"), " level=", GameState.party[0].level, " hp=", GameState.party[0].hp, "/", GameState.party[0].max_hp(),
				" leftover answers=", UI.auto_answers.size())
			for l in UI.auto_log:
				if l.begins_with("[menu]") or l.begins_with("[flute]") or l.begins_with("Scout"):
					print("   ", l)
		else:
			Story.talk(world, _npc("guard"))
			for i in int(_test.get("presses", "6")):
				await _wait(0.7)
				_press("ui_accept")
			await _wait(wait)
	elif scene == "capture":
		UI.auto = true
		GameState.songs = []
		GameState.gear["flute"] = ""
		GameState.set_flag("reed_flute", false)
		GameState.party = [Beasts.create(1, 2)]
		await _do_goto("tidewater", "west")
		await _wait(0.5)
		var arena := _bld("arena")
		print("arena without a flute -> allowed: ", await Story.can_enter(world, arena))
		UI.auto_flute = [{"acc": 0.0, "mistakes": 3, "failed": "misses"}]
		UI.auto_answers = [1]
		print("uncle: fail Weaken and give up -> done: ", await Story.uncle_lessons(), "  flute ", GameState.has_flute(), "  songs ", GameState.songs)
		print("uncle again, pass both -> done: ", await Story.uncle_lessons(), "  songs ", GameState.songs)
		print("arena with a flute -> allowed: ", await Story.can_enter(world, arena))
		var weak := Beasts.create(0, 2)
		var strong := Beasts.create(0, 3)
		var too_big := Beasts.create(0, 6)
		print("best beast Lv", GameState.best_level(), "  Capture cap ", GameState.capture_cap())
		print("Lv2 target, 90%%, 2 mistakes: %.2f" % GameState.capture_chance(weak, "capture1", 0.9, 2))
		print("Lv3 target (stronger than yours), 2 mistakes: %.2f   flawless: %.2f" % [GameState.capture_chance(strong, "capture1", 0.9, 2), GameState.capture_chance(strong, "capture1", 1.0, 0)])
		print("Lv2 target, 40%% vs 90%% accuracy: %.2f vs %.2f" % [GameState.capture_chance(weak, "capture1", 0.4, 6), GameState.capture_chance(weak, "capture1", 0.9, 1)])
		print("Lv6 target: '", GameState.song_can_charm("capture1", too_big), "'")
		print("next level ready at Lv2: ", GameState.next_capture_ready())
		GameState.party[0].level = 5
		print("next level ready at Lv5: ", GameState.next_capture_ready())
		UI.auto_flute = [0.95]
		print("practised next level: ", await Places.practice_next_capture(), "  songs ", GameState.songs, "  cap ", GameState.capture_cap())
		print("Lv6 target now: '", GameState.song_can_charm(GameState.capture_song(), too_big), "'  needs flawless: ", GameState.needs_flawless(too_big))
	elif scene == "wilds":
		autoplay = true
		UI.auto = true
		_do_goto("route1", "west")
		await _wait(2.0)
		print("wild beasts on route1: ", world.wilds.size(), " target ", world._wild_target, " ", world.wilds.map(func(w): return "%s x%d L%d %s" % [w["beasts"][0].nickname, w["beasts"].size(), w["beasts"][0].level, w["pos"]]))
		# 1. creep up behind one and walk into it
		var w0: Dictionary = world.wilds[0]
		w0["state"] = "stunned"
		w0["t"] = 99.0
		var behind: Vector2i = w0["pos"] - w0["facing"]
		world.player_pos = behind
		world.player.position = world.tile_pos(behind)
		world._step(w0["facing"], false)
		await _wait(1.0)
		while in_battle:
			await _wait(0.3)
		await _wait(1.2)
		print("after the sneak attack: ", world.wilds.size(), " wild beasts left, the one you beat is gone: ", not world.wilds.has(w0))
		# 2. a strong beast spots you and comes running
		for b in GameState.party:
			b.level = 1
		GameState.heal_party()
		var w1: Dictionary = world.wilds[0]
		w1["state"] = "wander"
		var front: Vector2i = w1["pos"] + w1["facing"] * 3
		if world._wild_free(front, w1):
			world.player_pos = front
			world.player.position = world.tile_pos(front)
			world.facing = w1["facing"]
			for i in 40:
				await _wait(0.1)
				if in_battle or String(w1["state"]) != "wander":
					break
			print("strong beast state after seeing you: ", w1["state"], " mark '", w1["mark"].text, "' visible ", w1["mark"].visible)
			for i in 60:
				await _wait(0.1)
				if in_battle:
					break
			while in_battle:
				await _wait(0.3)
		else:
			print("(no room in front of beast 2)")
		# 3. a weak beast flees (back on the route first: the last fight may have sent you to a Beast Center)
		GameState.heal_party()
		_do_goto("route1", "west")
		await _wait(2.0)
		for b in GameState.party:
			b.level = 30
		var w2: Dictionary = world.wilds[0] if not world.wilds.is_empty() else {}
		if not w2.is_empty():
			w2["state"] = "wander"
			var fr: Vector2i = w2["pos"] + w2["facing"] * 2
			if world._wild_free(fr, w2):
				world.player_pos = fr
				world.player.position = world.tile_pos(fr)
				for i in 15:
					await _wait(0.1)
				print("weak beast state: ", w2["state"], " mark '", w2["mark"].text, "' colour ", w2["mark"].modulate.to_html(false), " moved to ", w2["pos"])
	elif scene == "marks":
		_do_goto("route1", "west")
		await _wait(2.0)
		var near: Array = world.wilds.duplicate()
		near.sort_custom(func(a, b): return Vector2(a["pos"] - world.player_pos).length() < Vector2(b["pos"] - world.player_pos).length())
		var labels := [["!", world.MARK_SPOTTED], ["!", world.MARK_SCARED], ["?", world.MARK_LOST]]
		for i in mini(3, near.size()):
			near[i]["state"] = "stunned"
			near[i]["t"] = 99.0
			world._set_mark(near[i], labels[i][0], labels[i][1])
		var p0: Vector2i = near[0]["pos"] + Vector2i(0, 2)
		if world._wild_free(p0, {}):
			world.player_pos = p0
			world.player.position = world.tile_pos(p0)
		await _wait(wait)
	elif scene == "lod":
		# the detailed tree models next to their half-resolution versions (tools/voxel_lod.py)
		var root := Node3D.new()
		view.add_child(root)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#86a8cc")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		env.ambient_light_energy = 0.5
		var we := WorldEnvironment.new()
		we.environment = env
		root.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52, 28, 0)
		sun.shadow_enabled = true
		root.add_child(sun)
		var x := 0.0
		for n in String(_test.get("models", "palm,dead_tree,tree_big,tree_oak,tree_birch,tree_round_3")).split(","):
			for lod in [false, true]:
				var m: Mesh = load("res://assets/voxel/nature/%s%s.obj" % [n, "_lo" if lod else ""])
				var mi := MeshInstance3D.new()
				mi.mesh = m
				var bb := m.get_aabb()
				var s := 2.8 / bb.size.y
				mi.scale = Vector3(s, s, s)
				mi.position = Vector3(x - bb.get_center().x * s, -bb.position.y * s, -bb.get_center().z * s)
				root.add_child(mi)
				x += 2.6
			x += 0.8
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 34
		cam.position = Vector3(x / 2.0, 12.0, 14.0)
		cam.fov = 70
		cam.look_at(Vector3(x / 2.0, 1.2, 0), Vector3.UP)
		cam.current = true
		await _wait(wait)
	elif scene == "perf":
		# what the GPU has to draw on a few typical maps (run with --rendering-method mobile to match phones)
		UI.auto = true
		for spot in String(_test.get("maps", "tidewater:20,13|route1:west|cogsworth:20,13|caccoon#0:entry")).split("|"):
			var id := spot.get_slice(":", 0)
			var sp = spot.get_slice(":", 1)
			if "," in String(sp):
				sp = Vector2i(int(String(sp).get_slice(",", 0)), int(String(sp).get_slice(",", 1)))
			await _go(id, sp)
			await _wait(2.0)
			var frames := 0
			var t0 := Time.get_ticks_usec()
			while frames < 60:
				await get_tree().process_frame
				frames += 1
			var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
			var rs := RenderingServer
			print("[perf] %-12s objects %5d  draw calls %5d  primitives %8d  (%.1f ms/frame here)" % [id,
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), ms])
			if _test.get("detail", "0") == "1":
				_perf_breakdown(world)
	elif scene == "tapzone":
		# taps on or near the on-screen controls never walk you anywhere; taps on open ground do
		Prefs.touch_controls = "on"
		UI.controls.refresh()
		_do_goto("caccoon", "start")
		await _wait(1.5)
		var oc = UI.controls
		var vp := get_viewport().get_visible_rect().size
		var spots := [["d-pad middle", oc._buttons["up"].position + Vector2(44, 132)],
			["d-pad corner", oc._buttons["up"].position + Vector2(-40, 30)],
			["just past the right arrow", oc._buttons["right"].position + Vector2(88 + 55, 44)],
			["between A and B", (oc._buttons["a"].position + oc._buttons["b"].position) / 2.0 + Vector2(52, 52)],
			["open ground", vp / 2.0 + Vector2(150, -90)]]
		for spot in spots:
			var from: Vector2i = world.player_pos
			var ev := InputEventScreenTouch.new()
			ev.pressed = true
			ev.position = spot[1]
			Input.parse_input_event(ev)
			var up := InputEventScreenTouch.new()
			up.position = spot[1]
			Input.parse_input_event(up)
			await _wait(1.4)
			print("tap %s at %s: covered %s, walked %s" % [spot[0], spot[1], oc.covers(spot[1]), world.player_pos != from])
	elif scene == "tap":
		_do_goto("caccoon", "start")
		await _wait(1.5)
		var from: Vector2i = world.player_pos
		var dest: Vector2i = from + Vector2i(4, -2)
		world.tap_at(world.cam.unproject_position(world.tile_pos(dest)))
		await _wait(2.5)
		print("tap walk: ", from, " -> ", world.player_pos, " (wanted ", dest, ")")
		var back: Vector2i = from
		var sp: Vector2 = world.cam.unproject_position(world.tile_pos(back))
		world.tap_at(sp)
		world.tap_at(sp)
		await _wait(0.4)
		print("double tap runs: ", world.move_speed > 6.0, " speed ", snappedf(world.move_speed, 0.1))
		await _wait(2.0)
		var elder := _npc("elder")
		UI.auto = true
		world.tap_at(world.cam.unproject_position(world.tile_pos(elder["pos"])))
		for i in 40:
			await _wait(0.1)
			if UI.auto_log.size() > 0:
				break
		print("tapped the elder from afar -> walked next to him and talked: ", UI.auto_log.slice(0, 1), " at ", world.player_pos, " elder ", elder["pos"])
		UI.auto = false
		await _wait(0.5)
		var cb := _bld("center")
		var sp2: Vector2 = world.cam.unproject_position(world.tile_pos(Vector2i(int(cb["x"]) + 1, int(cb["y"]) + 1)) + Vector3(0, 1.0, 0))
		var tt: Vector2i = world._tile_under(sp2)
		print("building tap tile ", tt, " building ", world._building_at(tt).get("shop", "-"), " door ", cb["door"], " busy ", world.busy, " ui ", UI.busy(), " player ", world.player_pos)
		world.tap_at(sp2)
		await _wait(0.2)
		print("path ", world._path, " goal ", world._path_goal)
		for i in 60:
			await _wait(0.1)
			if world.map_id != "caccoon":
				break
		await _wait(1.0)
		print("tapped the Beast Center building -> now in ", world.map_id)
	elif scene == "puzzles":
		UI.auto = true
		# route1: the washed-out footbridge, rebuilt one log at a time
		await _go("route1", "west")
		await _wait(1.0)
		var bridge_grp: Dictionary = world.map["obstacles"][Vector2i(37, 6)]
		await Story.field_move(world, bridge_grp)
		var logs: Array = world.items.values().filter(func(it): return it["item"] == "bridge_log")
		print("logs lying along the path: ", logs.size(), " ", logs.map(func(it): return it["pos"]))
		await world._pickup(logs[0])
		await world._pickup(logs[1])
		UI.auto_answers = [0, 0, 0]
		await Story.field_move(world, bridge_grp)
		print("two logs placed: ", GameState.flags.get(bridge_grp["flag"] + "_logs", 0), "  fixed: ", GameState.flag(bridge_grp["flag"]))
		for it in logs.slice(2):
			await world._pickup(it)
		UI.auto_answers = [0, 0, 0, 0]
		await Story.field_move(world, bridge_grp)
		print("bridge with five logs fixed: ", GameState.flag(bridge_grp["flag"]), "  tile now walkable: ", world._walkable(Vector2i(37, 6)))
		if _test.has("shot"):
			world.player_pos = Vector2i(35, 7)
			world.player.position = world.tile_pos(world.player_pos)
			await _wait(1.0)
			get_viewport().get_texture().get_image().save_png(String(_test["shot"]).replace(".png", "_bridge.png"))
		# route3: the cliff needs a beast with wings
		await _go("route3", "south")
		await _wait(1.0)
		var cliff: Dictionary = world.map["obstacles"][Vector2i(15, 21)]
		await Story.field_move(world, cliff)
		print("cliff without wings: ", GameState.flag(cliff["flag"]))
		GameState.party.append(Beasts.create(36, 12))
		UI.auto_answers = [0]
		await Story.field_move(world, cliff)
		print("cliff with a Zephyrling: ", GameState.flag(cliff["flag"]), "  rope walkable: ", world._walkable(Vector2i(15, 20)))
		# route4: push the boulders, following the solver's moves
		await _go("route4", "south")
		await _wait(1.0)
		await _solve_pushes([[Vector2i(10, 17), Vector2i(0, -1)], [Vector2i(9, 17), Vector2i(-1, 0)], [Vector2i(9, 16), Vector2i(0, -1)], [Vector2i(10, 16), Vector2i(1, 0)], [Vector2i(9, 15), Vector2i(-1, 0)]], Vector2i(15, 21))
		await _walk_test([world.map["anchors"]["puzzle_exit"]])
		print("rockslide solved: ", GameState.flag("puzzle_route4"), "  player at ", world.player_pos)
		# route8: slide the ice
		await _go("route8", "east")
		await _wait(1.0)
		await _solve_pushes([[Vector2i(37, 10), Vector2i(-1, 0)], [Vector2i(37, 11), Vector2i(0, 1)], [Vector2i(36, 11), Vector2i(-1, 0)], [Vector2i(36, 10), Vector2i(0, -1)]], Vector2i(40, 9))
		await _walk_test([world.map["anchors"]["puzzle_exit"]])
		print("frozen pond solved: ", GameState.flag("puzzle_route8"), "  player at ", world.player_pos)
		await _go("route8", "east")
		await _wait(1.0)
		print("route8 reloaded: blocks kept where you left them: ", world.pushables.keys())
		# route6: the checkpoint
		await _go("route6", "west")
		await _wait(1.0)
		await Story.talk(world, _npc("inspector"))
		print("checkpoint without a pass: open ", GameState.flag("mine_pass_ok"))
		GameState.add_item("miner_pass")
		await Story.talk(world, _npc("inspector"))
		print("checkpoint with the pass: open ", GameState.flag("mine_pass_ok"), "  inspector still there: ", not _npc("inspector").is_empty())
		# route9 / route10: the battle blockers
		autoplay = true
		for b in GameState.party:
			b.level = 80
			b.heal_full()
		await _go("route9", "north")
		await _wait(1.0)
		await Story.talk(world, _npc("warden"))
		print("warden beaten: ", GameState.flag("warden_beaten"))
		for b in GameState.party:
			b.heal_full()
		await _go("route10", "west")
		await _wait(1.0)
		await Story.talk(world, _npc("sentinel"))
		print("sentinel beaten: ", GameState.flag("sentinel_beaten"))
	elif scene == "heal":
		await _go("caccoon#0", "entry")
		await _wait(1.0)
		# in front of the healing machine's bay
		world.player_pos = Vector2i(2, 2)
		world.player.position = world.tile_pos(Vector2i(2, 2))
		world.facing = Vector2i(0, -1)
		load("res://scripts/gfx/voxel_person.gd").face(world.player, Vector2i(0, -1))
		if _test.get("what", "heal") == "hatch":
			world.play_hatch_fx()
		else:
			world.play_heal_fx(3)
		await _wait(wait)
	elif scene == "slots":
		_do_goto("tidewater", "center")
		await _wait(1.5)
		GameState.play_time = 5025.0
		await save_now()
		GameState.copy_slot(GameState.current_slot, 3)
		_load_world("caccoon", "start", true)
		slot_manager()
		await _wait(wait)
	elif scene == "spiral":
		_do_goto("route1", "west")
		await _wait(1.5)
		UI.spiral_in(SPIRAL_COLORS[_test.get("kind", "sneak")], 1.0)
		await _wait(wait)
	elif scene == "saves":
		for i in GameState.SLOT_COUNT:
			GameState.delete_slot(i)
		_do_goto("tidewater", "center")
		await _wait(1.5)
		print("first save ok: ", await save_now(), " slot ", GameState.current_slot)
		GameState.play_time = 3725.0
		print("second save same slot: ", await save_now(), " slot ", GameState.current_slot, " info ", GameState.slot_info(GameState.current_slot))
		print("copy 0->4: ", GameState.copy_slot(0, 4), "  slot 5 exists ", GameState.slot_exists(4), " shot ", FileAccess.file_exists(GameState.slot_shot_path(4)))
		GameState.delete_slot(4)
		print("after delete slot 5 exists: ", GameState.slot_exists(4), "  latest ", GameState.latest_slot())
		GameState.new_game("Second")
		print("new game slot ", GameState.current_slot, " -> saves into ", GameState.first_free_slot())
		print("load slot 1: ", GameState.load_game(0), " name ", GameState.player_name, " time ", GameState.time_text())
		if _test.has("card"):
			UI.show_save_card(0)
			await _wait(wait)
	elif scene == "hero":
		await _hero_gallery()
		await _wait(wait)
	elif scene == "pause":
		_do_goto("tidewater", "center")
		await _wait(1.5)
		UI.push(UI.PauseOverlay.new())
		await _wait(wait)
	elif scene == "title":
		_title()
		await get_tree().create_timer(wait).timeout
	elif scene == "view":
		_do_goto("caccoon", "start")
		await get_tree().create_timer(1.0).timeout
		var a = GameState.party[0]
		var c := Beasts.merge(a, GameState.party[1], true)
		UI.show_beast(c, "A new beast is born!")
		await get_tree().create_timer(wait).timeout
	if _test.has("shot"):
		var img := get_viewport().get_texture().get_image()
		img.save_png(_test["shot"])
		print("screenshot saved: ", _test["shot"])
	if _test.get("quit", "1") == "1":
		get_tree().quit()


# ---------------------------------------------------------------- automated flow test
func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _bld(shop: String) -> Dictionary:
	for b in world.map["buildings"]:
		if b["shop"] == shop:
			return b
	return {}


func _npc(id: String) -> Dictionary:
	for p in world.npcs:
		if world.npcs[p].get("id", "") == id:
			return world.npcs[p]
	return {}


func _step(name: String, answers: Array) -> void:
	UI.auto_answers = answers
	print("--- ", name, "  gold=", GameState.gold, " party=", GameState.party.map(func(x): return "%s L%d" % [x.nickname, x.level]))


## Waits for any queued map change to finish, then jumps to `id` (flow test helper).
func _go(id: String, spawn = "start") -> void:
	for i in 200:
		if _pending_goto.is_empty() and not _transitioning:
			break
		await _wait(0.1)
	await _do_goto(id, spawn)


func _flow_test() -> void:
	Engine.time_scale = 30.0
	UI.auto = true
	autoplay = true
	GameState.new_game("Flow")
	var home := MapLoader.interior_of("caccoon", "home")
	await _go(home, "entry")
	await _wait(2.5)
	print("intro done? ", GameState.flag("intro_done"), " songs ", GameState.songs, " party ", GameState.party.size())
	await _go("caccoon", "start")
	await _wait(2.0)
	print("east exits while beastless: ", world.map["exits"].values().filter(func(e): return e["to"] == "route1").size())
	_step("elder egg", [0, 0])
	await Story.talk(world, _npc("elder"))
	print("eggs: ", GameState.eggs)
	await _go(MapLoader.interior_of("caccoon", "center"), "entry")
	await _wait(1.5)
	_step("hatch at center", [0])
	await Places.beast_center("caccoon")
	print("party after hatch: ", GameState.party.map(func(x): return "%s L%d" % [x.nickname, x.level]), " has_starter ", GameState.flag("has_starter"))
	await _go("caccoon", "center")
	await _wait(1.5)
	print("east exits before the lesson: ", world.map["exits"].values().filter(func(e): return e["to"] == "route1").size(),
		"  guard has news: ", Story.npc_has_news(_npc("guard")))
	_step("Scout Bram's battle lesson", [])
	await Story.talk(world, _npc("guard"))
	await _wait(1.5)
	print("after the lesson: tutorial_done ", GameState.flag("tutorial_done"), "  starter ", GameState.party[0].nickname, " Lv", GameState.party[0].level,
		"  east exits: ", world.map["exits"].values().filter(func(e): return e["to"] == "route1").size())
	await _go("route1", "west")
	await _wait(1.5)
	print("now on ", world.map_id, " encounter ", world.map["encounter"].keys(), " transitioning ", _transitioning)
	_step("wild battle at Lv1", [])
	world.busy = true
	await Story.wild_encounter(world)
	world.busy = false
	await _wait(1.0)
	for i in 6:
		GameState.heal_party()
		if world.map_id != "route1":
			await _go("route1", "west")
		world.busy = true
		await Story.wild_encounter(world)
		world.busy = false
	print("after 7 wild battles: ", GameState.party.map(func(x): return "%s L%d" % [x.nickname, x.level]), " eggs ", GameState.eggs.size())
	print("flute before Tidewater: ", GameState.has_flute(), "  songs ", GameState.songs)
	await _go("tidewater", "west")
	await _wait(1.5)
	_step("uncle's flute lessons", [])
	await Story.talk(world, _npc("uncle"))
	print("after the uncle: flute ", GameState.has_flute(), "  songs ", GameState.songs)
	_pending_goto = {}
	GameState.heal_party()
	GameState.gold = 99999
	for r in [3, 14, 27, 40]:
		GameState.add_beast(Beasts.create(r, 20))
	print("starting songs: ", GameState.songs)
	await _go("route1", "west")
	await _wait(1.0)
	var bard := {}
	for p in world.npcs:
		if world.npcs[p].get("song", "") != "":
			bard = world.npcs[p]
	print("bard on route1: ", bard.get("name", "none"), " plays ", bard.get("song", ""))
	_step("bard battle, fumble the song", [])
	UI.auto_flute = [{"acc": 0.8, "mistakes": 2}]
	await Story.talk(world, bard)
	print("after fumble knows jig: ", GameState.knows_song("jig"))
	GameState.heal_party()
	_step("bard encore, perfect playback", [0])
	await Story.talk(world, bard)
	print("after encore knows jig: ", GameState.knows_song("jig"))
	await _go("cogsworth", "center")
	await _wait(1.0)
	GameState.gold = 99999
	_step("music shop: free song, then sheet music", [0, 0, 0, 1, 0, -1, 2, 0, 4])
	await Places.open(_bld("music_shop"), world)
	print("songs after music shop: ", GameState.songs, " free used: ", GameState.flag("maestro_free_song"))
	_step("music shop: failing a sheet keeps it", [1, 0, -1, 2, 0, 1, 4])
	UI.auto_flute = [{"acc": 0.0, "mistakes": 3, "failed": "misses"}]
	await Places.open(_bld("music_shop"), world)
	print("sheets owned after a failed try: ", GameState.inventory.keys().filter(func(k): return String(k).begins_with("sheet_")))
	await _go("tidewater", "center")
	await _wait(2.0)
	_step("electronics (no shards)", [0, 2])
	await Places.open(_bld("electronics"), world)
	GameState.shards = 11
	_step("electronics upgrade x2", [0, 0, 1, 0, -1, 2, 2])
	await Places.open(_bld("electronics"), world)
	print("shield ", GameState.max_shield, " shards ", GameState.shards)
	_step("apothecary", [0, 0, 0, -1, 2])
	await Places.open(_bld("apothecary"), world)
	_step("sky tower (fly to caccoon)", [0])
	await Places.skytower(_bld("skytower"))
	await _wait(2.0)
	print("after sky tower: ", world.map_id, " at ", world.player_pos)
	await _go("tidewater", "dock")
	await _wait(1.5)
	_step("ferry", [0])
	await Story.talk(world, _npc("ferry"))
	await _wait(2.0)
	print("after ferry: ", world.map_id)
	_step("chief shell", [])
	await Story.talk(world, _npc("chief_shell"))
	await _go("kelpwick", "center")
	await _wait(1.5)
	print("kelpwick gate tiles: ", world.map["gate_tiles"].size())
	_step("chief kelp", [])
	await Story.talk(world, _npc("chief_kelp"))
	await _go("route2", "west")
	await _wait(1.5)
	_step("culprit", [])
	print("culprit present: ", not _npc("culprit").is_empty())
	await Story.talk(world, _npc("culprit"))
	print("culprit_beaten ", GameState.flag("culprit_beaten"))
	await _go("kelpwick", "center")
	await _wait(1.5)
	_step("chief kelp peace", [])
	await Story.talk(world, _npc("chief_kelp"))
	await _wait(1.5)
	print("island_peace ", GameState.flag("island_peace"), " gate tiles now ", world.map["gate_tiles"].size())
	await _go("reef", "west")
	await _wait(1.5)
	var tb := _bld("temple")
	await _go(tb["interior"], "entry")
	await _wait(1.5)
	for p in world.npcs:
		if world.npcs[p].get("kind", "") == "guardian":
			for b in GameState.party:
				b.level = 40
				b.heal_full()
			_step("water guardian", [])
			await Story.talk(world, world.npcs[p])
			break
	print("guardian_water ", GameState.flag("guardian_water"), " eggs ", GameState.eggs.map(func(e): return e["kind"]))
	await _go(MapLoader.interior_of("kelpwick", "center"), "entry")
	await _wait(1.0)
	var hatch_answers := [0]
	for e in GameState.eggs:
		hatch_answers.append(0)
	hatch_answers.append(3)
	_step("hatch all", hatch_answers)
	await Places.beast_center("kelpwick")
	var leg = null
	for b in GameState.all_beasts():
		if RaceDB.is_legendary(b.race):
			leg = b
	print("legendary hatched: ", leg.nickname if leg != null else "none")
	if leg != null:
		leg.level = 20
		var other = GameState.party.filter(func(x): return x != leg)[0]
		other.level = 20
		var child := Beasts.merge(leg, other)
		print("80/20 merge: ", child.nickname, " race ", RaceDB.race_name(child.race), " el ", child.element)
	await _go("sundown", "center")
	await _wait(1.5)
	_step("sheriff", [])
	await Story.talk(world, _npc("sheriff"))
	await _go("route5", "south")
	await _wait(1.5)
	var hid := _bld("hideout")
	await _go(hid["interior"], "entry")
	await _wait(1.5)
	for n in world.npcs.values().duplicate():
		if n.get("bandit_boss", false):
			for b in GameState.party:
				b.heal_full()
			_step("bandit boss", [])
			await Story.talk(world, n)
	print("bandits_cleared ", GameState.flag("bandits_cleared"))
	await _go("route5", "south")
	await _wait(1.5)
	print("route5 gate tiles ", world.map["gate_tiles"].size())
	await _go("cogsworth", "center")
	await _wait(1.5)
	var ct := _bld("ceo_tower")
	for f in [1, 2, 3, 4]:
		await _go(MapLoader.floor_id(ct["interior"], f), "entry")
		await _wait(1.5)
		# people walk about their rooms, so go by who's there rather than where they stood
		for n2 in world.npcs.values().duplicate():
			if n2.has("robot_body") and not GameState.flag(n2["flag"]):
				for b in GameState.party:
					b.heal_full()
				await Story.talk(world, n2)
		print("floor ", f, " room ", world.map["room_key"], " stairs ok: ", await Story.can_use_exit(world, {"to": MapLoader.floor_id(ct["interior"], f + 1)}))
	for b in GameState.party:
		b.heal_full()
	_step("ceo", [])
	await Story.talk(world, _npc("ceo"))
	print("ceo_defeated ", GameState.flag("ceo_defeated"), " shards ", GameState.shards)
	await _go("vinehollow", "center")
	await _wait(1.5)
	_step("shaman", [])
	await Story.talk(world, _npc("shaman"))
	await _wait(1.5)
	await Story.talk(world, _npc("relic"))
	await _go("route8", "west")
	await _wait(1.5)
	await Story.talk(world, _npc("relic"))
	await _go("route9", "north")
	await _wait(1.5)
	print("route9 temple before ritual: ", not _bld("temple").is_empty())
	await Story.talk(world, _npc("relic"))
	await _go("vinehollow", "center")
	await _wait(1.5)
	_step("shrine ritual", [])
	await Story.talk(world, _npc("shrine"))
	await _go("route9", "north")
	await _wait(1.5)
	print("ritual_done ", GameState.flag("ritual_done"), " route9 temple now: ", not _bld("temple").is_empty())
	await _go("gravenmoor", "west")
	await _wait(2.0)
	print("ghost_merge ", GameState.flag("ghost_merge"))
	_step("gravedigger", [])
	await Story.talk(world, _npc("gravedigger"))
	GameState.party = []
	for r in [7, 18, 31, 42, 3, 22]:
		GameState.party.append(Beasts.create(r, 72))
	for n3 in world.npcs.values().duplicate():
		if n3.get("flag", "") == "tr_gravenmoor_gate":
			await Story.talk(world, n3)
	var cat := _bld("cathedral")
	await _go(cat["interior"], "entry")
	await _wait(1.5)
	_step("nyx", [])
	await Story.talk(world, _npc("nyx"))
	await _go(MapLoader.floor_id(cat["interior"], 3), "entry")
	await _wait(1.5)
	for b in GameState.party:
		b.heal_full()
	_step("finale", [])
	print("vexmora present: ", not _npc("vexmora").is_empty(), " room ", world.map.get("room_key", ""))
	await Story.talk(world, _npc("vexmora"))
	print("game_cleared=", GameState.flag("game_cleared"))
	_step("shield loss battle", [])
	GameState.party = [Beasts.create(1, 2)]
	GameState.max_shield = 1
	GameState.recharge_shield()
	await _go("route10", "west")
	await _wait(1.5)
	var r: String = await start_battle({"wild": true, "foes": [Beasts.create(23, 40)], "seed": 3})
	await _wait(2.0)
	print("hopeless battle -> ", r, "  now at ", world.map_id if world else "?", "  shield ", GameState.shield, "/", GameState.max_shield)
	_step("save/load", [])
	var n_before := GameState.all_beasts().size()
	await save_now()
	GameState.load_game(GameState.current_slot)
	print("save roundtrip beasts: ", n_before, " -> ", GameState.all_beasts().size(), " eggs ", GameState.eggs.size(), " shield ", GameState.max_shield)
	print("LOG TAIL:")
	for l in UI.auto_log.slice(maxi(0, UI.auto_log.size() - 12)):
		print("   ", l)
	print("FLOW TEST DONE")
	Engine.time_scale = 1.0


## Walks the player (by tapped path) to one of `goals` and waits until they arrive.
func _walk_test(goals: Array) -> void:
	world._walk_to(goals, Vector2i(-999, -999), false)
	for i in 120:
		await _wait(0.1)
		if world._path.is_empty() and not world.moving:
			break


## Plays a push puzzle: for each [block tile, direction], walk behind the block and push it.
func _solve_pushes(moves: Array, start: Vector2i) -> void:
	world.player_pos = start
	world.player.position = world.tile_pos(start)
	for m in moves:
		var block: Vector2i = m[0]
		var d: Vector2i = m[1]
		if not world.pushables.has(block):
			print("   no block at ", block, " (blocks: ", world.pushables.keys(), ")")
			return
		await _walk_test([block - d])
		if world.player_pos != block - d:
			print("   couldn't reach ", block - d, " (at ", world.player_pos, ")")
			return
		world._step(d, false)
		await _wait(0.8)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)


func _gallery(cat: String, page := 0) -> void:
	var VA = load("res://scripts/gfx/voxel_assets.gd")
	var root := Node3D.new()
	view.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6a8ab0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var names := []
	for k in VA.Manifest.ASSETS:
		if String(VA.Manifest.ASSETS[k]).contains("/" + cat + "/"):
			names.append(k)
	names = names.slice(page * 12, page * 12 + 12)
	var cols := 4
	var i := 0
	for n in names:
		var bb: AABB = VA.aabb(n)
		var mi: MeshInstance3D = VA.instance(n, 2.4) if bb.size.y >= maxf(bb.size.x, bb.size.z) else VA.instance(n, -1.0, 2.6)
		mi.position += Vector3((i % cols) * 3.2, 0, (i / cols) * 3.4)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = n
		l.font_size = 40
		l.pixel_size = 0.008
		l.outline_size = 8
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3((i % cols) * 3.2, 2.5, (i / cols) * 3.4 + 0.8)
		root.add_child(l)
		i += 1
	var rows := int(ceil(names.size() / float(cols)))
	var cam := Camera3D.new()
	root.add_child(cam)
	var center := Vector3((cols - 1) * 1.6, 0, (rows - 1) * 1.7)
	cam.fov = 45
	cam.position = center + Vector3(0, 7.5, 9.5)
	cam.look_at(center, Vector3.UP)
	cam.current = true


## Close-up of the player character from four sides (test scene "hero").
func _hero_gallery() -> void:
	var VPer = load("res://scripts/gfx/voxel_person.gd")
	var root := Node3D.new()
	view.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#7aa0c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var look: Dictionary = load("res://scripts/world/world.gd").PLAYER_LOOK
	if _test.has("model"):
		look = {"model": _test["model"]}
	# --pose=walk: side views a quarter of a stride apart (--amount = stride, 1 walk, 1.25 run)
	var walk: bool = _test.get("pose", "") == "walk"
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i in 4:
		var rig: Node3D = VPer.build(look)
		VPer.face(rig, Vector2i(1, 0) if walk else dirs[i])
		if walk:
			VPer.animate(rig, i * PI / 4.0, float(_test.get("amount", "1")), 0.0)
		rig.position = Vector3(i * 1.4, 0, 0)
		root.add_child(rig)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	cam.position = Vector3(2.1, 2.2, 5.6)
	cam.look_at(Vector3(2.1, 0.85, 0), Vector3.UP)
	cam.current = true


func _beast_gallery(page: int) -> void:
	var VB = load("res://scripts/gfx/voxel_beast.gd")
	var RaceDB = load("res://scripts/data/race_db.gd")
	var root := Node3D.new()
	view.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#7aa0c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var genes_list := []
	if page < 4:
		for i in range(page * 12, page * 12 + 12):
			genes_list.append([RaceDB.race_name(i), RaceDB.genes(i)])
	else:
		for i in 12:
			var a := Beasts.create(i * 4, 20, i % 3 == 0)
			var b := Beasts.create((i * 7 + 13) % 48, 20)
			var c := Beasts.merge(a, b, true)
			genes_list.append([c.nickname, c.genes])
	var t0 := Time.get_ticks_msec()
	for i in genes_list.size():
		var mi := MeshInstance3D.new()
		mi.mesh = VB.mesh(genes_list[i][1])
		mi.rotation.y = -0.6
		mi.position = Vector3((i % 4) * 2.6, 0, (i / 4) * 2.6)
		root.add_child(mi)
		var l := Label3D.new()
		l.text = genes_list[i][0]
		l.font_size = 36
		l.pixel_size = 0.008
		l.outline_size = 8
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = mi.position + Vector3(0, 2.2, 0.6)
		root.add_child(l)
	print("built %d beasts in %d ms" % [genes_list.size(), Time.get_ticks_msec() - t0])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	cam.position = Vector3(3.9, 6.5, 10.5)
	cam.look_at(Vector3(3.9, 0.6, 2.6), Vector3.UP)
	cam.current = true


func _style_gallery(which: String) -> void:
	var VBld = load("res://scripts/gfx/voxel_buildings.gd")
	var root := Node3D.new()
	view.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#86a8cc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 25, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#6a9a4a")
	ground.material_override = gm
	root.add_child(ground)
	var specs := []
	if which == "special":
		specs = [["coastal", "arena", 8, 5], ["coastal", "skytower", 3, 3], ["steampunk", "electronics", 5, 3], ["steampunk", "ceo_tower", 5, 4], ["gothic", "cathedral", 8, 7], ["western", "hideout", 4, 3], ["jungle", "temple", 6, 4]]
	else:
		for shop in ["center", "apothecary", "house", "home", "bookstore", "cafe"]:
			specs.append([which, shop, 6 if shop == "center" else (4 if shop == "house" else 5), 4 if shop == "center" else 3])
	var x := 0.0
	var t0 := Time.get_ticks_msec()
	for sp in specs:
		var b := {"shop": sp[1], "w": sp[2], "d": sp[3], "x": 0, "y": 0, "door": Vector2i(int(sp[2]) / 2, int(sp[3]) - 1), "height": 2.6 if int(sp[3]) >= 4 else 2.2, "seed": 3, "glow": "#5ad06a"}
		var n: Node3D = VBld.build(b, sp[0])
		n.position = Vector3(x + float(sp[2]) / 2.0, 0, 0)
		root.add_child(n)
		x += float(sp[2]) + 1.5
	print("built buildings in %d ms" % (Time.get_ticks_msec() - t0))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 45
	cam.position = Vector3(x / 2.0, 9.0, 15.0)
	cam.look_at(Vector3(x / 2.0, 1.5, 0), Vector3.UP)
	cam.current = true


## Triangles per mesh in a world (perf test): which meshes cost the most, counting every multimesh instance.
func _perf_breakdown(root: Node) -> void:
	var tally := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mesh: Mesh = null
		var count := 1
		var shadow := false
		if n is MultiMeshInstance3D and n.multimesh != null:
			mesh = n.multimesh.mesh
			count = n.multimesh.instance_count
			shadow = n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n is MeshInstance3D:
			mesh = n.mesh
			shadow = n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh == null:
			continue
		var tris := 0
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key := "%s %s#%d%s" % [n.get_class(), mesh.resource_path.get_file() if mesh.resource_path != "" else mesh.get_class(), mesh.get_instance_id() % 10000, " (shadow)" if shadow else ""]
		if not tally.has(key):
			tally[key] = [0, 0]
		tally[key][0] += tris * count
		tally[key][1] += count
	var keys := tally.keys()
	keys.sort_custom(func(a, b): return tally[a][0] > tally[b][0])
	for k in keys.slice(0, 18):
		print("    %9d tris  x%-5d %s" % [tally[k][0], tally[k][1], k])
