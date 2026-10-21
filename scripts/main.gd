extends Node
## Game root: owns the 3D view, the title screen, map transitions and battles.

## The world and battle scripts (with everything they preload) are the slowest part of starting up, so they aren't
## preloaded: the title screen shows its menu first and loads them in the background (see _title_backdrop).
const WORLD_PATH := "res://scripts/world/world.gd"
const BATTLE_PATH := "res://scripts/battle/battle.gd"
const PANEL_PATH := "res://scripts/battle/command_panel.gd"
## Resources the world's scripts preload that have to be loaded on the main thread (see _title_backdrop).
const THREAD_SHY := ["res://scripts/gfx/terrain.gdshader", "res://scripts/gfx/water.gdshader", "res://scripts/gfx/wall_fade.gdshader"]
## project.godot's boot splash colour
const SPLASH_COLOR := Color(0.184, 0.141, 0.141)
const WorldDB = preload("res://scripts/data/world_db.gd")
const Beasts = preload("res://scripts/core/beasts.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Ring = preload("res://scripts/core/ring.gd")

## The 3D world renders at the window's full resolution, smoothed by 2x MSAA; the UI is drawn on top.
## Shows the 3D view, filling the window.
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
	# the same colour as the boot splash, behind the title until its town has been built
	RenderingServer.set_default_clear_color(SPLASH_COLOR)
	if Prefs.is_mobile():
		# a steady 60 fps: chasing a 120-144 Hz screen makes uneven frames and heats the phone until it throttles
		Engine.max_fps = 60
	view = SubViewport.new()
	view.handle_input_locally = false
	view.audio_listener_enable_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_2X
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(view)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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


## Sizes the 3D view to the window, pixel for pixel.
func _fit_view() -> void:
	var win := get_window().size
	if win.y < 1:
		return
	view.size = win


## A point on the screen (in UI units) -> the same point in the 3D view.
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
	UI.controls.set_title_mode(true)
	# the menu comes up straight away; the town behind it is built a moment later
	_title_backdrop()
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
	_title_nodes = [box]
	while true:
		var items := []
		# (--saves=0: a test run shows the title as a first launch would)
		if GameState.has_save() and _test.get("saves", "1") == "1":
			items.append("Continue")
			items.append("Load Game")
		items.append("New Game")
		if not Prefs.is_mobile():
			items.append("Quit")
		# big enough to read across a phone; with no save yet, "New Game" is a big glowing button with no box round it
		# (Quit, on desktops, plain text under it)
		var first := not items.has("Continue")
		var c: int = await UI.choose("", items, {"anchor": "bottom", "width": 320, "cancel": false, "margin": Vector2(0, 70 if first else 60),
			"font_size": 64 if first else UIKit.BODY_HUGE, "bare": first})
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
		if load_slot >= 0 and GameState.slot_outdated(load_slot):
			UI.toast("That save is from before the new beasts, so it can't be loaded. Start a new game!", UIKit.ACCENT)
		elif load_slot >= 0 and GameState.load_game(load_slot):
			_clear_title()
			UI.allow_pause = true
			var spawn = GameState.pos if GameState.pos.x >= 0 else "center"
			_pending_goto = {"map": GameState.map_id, "spawn": spawn}
			return
		if pick == "New Game":
			# who you are: a name, a body and your colours
			_title_nodes[0].visible = false
			var made = await UI.make_hero()
			_title_nodes[0].visible = true
			if made == null:
				continue
			GameState.new_game(made["name"], made["look"])
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
	UI.controls.set_title_mode(false)
	for n in _title_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_title_nodes = []


# ================================================================ maps
## Behind the title's menu: loads the world's scripts in the background, builds the town and fades it in (unless a game
## has started meanwhile), then loads the battle scripts, the travel book and the world map in the background too.
func _title_backdrop() -> void:
	screen.modulate.a = 0.0
	# shaders can't be loaded off the main thread: load the ones the world's scripts preload first
	for sh in THREAD_SHY:
		load(sh)
	ResourceLoader.load_threaded_request(WORLD_PATH)
	# a frame at least, so the menu is up first
	await get_tree().process_frame
	while ResourceLoader.load_threaded_get_status(WORLD_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if not _title_nodes.is_empty() and _pending_goto.is_empty():
		_load_world("caccoon", "start", true)
		await get_tree().process_frame
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.8)
	for path in [BATTLE_PATH, Menus.BOOK_PATH, Menus.MAP_PATH]:
		ResourceLoader.load_threaded_request(path)


## A script loaded in the background (see _title_backdrop), or loaded now if it wasn't asked for or isn't done yet.
func loaded_script(path: String) -> GDScript:
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return ResourceLoader.load_threaded_get(path)
	return load(path)


func _load_world(id: String, spawn, demo := false, face := Vector2i.ZERO) -> void:
	if world != null:
		if world.get_parent():
			world.get_parent().remove_child(world)
		world.queue_free()
		world = null
	world = loaded_script(WORLD_PATH).new()
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
	var b = loaded_script(BATTLE_PATH).new()
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
	GameState.set_flag("flute_lesson_done")
	GameState.gear["flute"] = "reed_flute"
	GameState.set_flag("reed_flute")
	GameState.learn_song("weaken")
	GameState.learn_song("capture3")
	# a Pricklet, a Clawlet and a Grubbit: fire, water and earth (none of Cocoon Cove's dino line, for --scene=mascot)
	for r in [3, 24, 12]:
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
		var foes := [Beasts.create(27, 10), Beasts.create(30, 11), Beasts.create(9, 12, true)]
		if _test.get("kind", "") == "robots":
			foes = [Beasts.create(44, 12), Beasts.create(45, 12), Beasts.create(46, 12)]
			start_battle({"wild": false, "foes": foes, "seed": 5, "trainer": {"name": "Gearhart", "cls": "CEO", "look": {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}}})
		else:
			start_battle({"wild": true, "foes": foes, "seed": 5})
		# (--keys: pressed once the command panel is up, as for --scene=ring)
		await _battle_keys()
		await get_tree().create_timer(wait).timeout
	elif scene == "ring":
		# a trainer battle on the ring, driven by key presses once the command panel is up:
		#   --keys=a,r,a,d,u,b...  (a = A, b = B, l / r = left / right, u / d = up / down), --kind=wild for wild beasts
		_do_goto("route3", "south")
		await _wait(1.0)
		var flv := int(_test.get("foe_level", "10"))
		# water beasts (the worm, earth and water, too)
		var team := [Beasts.create(27, flv), Beasts.create(24, flv + 1), Beasts.create(21, flv), Beasts.create(27, flv - 1), Beasts.create(24, flv)]
		if _test.get("kind", "") == "wild":
			start_battle({"wild": true, "foes": [Beasts.create(27, 10), Beasts.create(30, 11)], "seed": 5})
		else:
			start_battle({"wild": false, "foes": team, "seed": 5, "trainer": {"name": "Marina", "cls": "Swimmer", "shield": int(_test.get("foe_shield", "1")),
				"look": {"skin": "#e0b090", "hair": "#2a4a8a", "shirt": "#3a8ac8", "pants": "#1a2a4a"}}})
		await _battle_keys()
		await _wait(wait)
	elif scene == "defeat":
		# a foe vanishing in a puff of smoke, with a damage number on its partner (--at = seconds after the puff)
		_do_goto("route3", "south")
		await _wait(1.0)
		start_battle({"wild": true, "foes": [Beasts.create(27, 10), Beasts.create(30, 11)], "seed": 5})
		await _wait(2.5)
		var bt: Node = null
		for c in view.get_children():
			if c.get_script() == load(BATTLE_PATH):
				bt = c
		bt.msg_label.text = "Pricklet gained 27 XP. Grubbit grew to Lv 13!"
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
				foes2.append(Beasts.create(randi_range(0, RaceDB.NORMAL_COUNT - 1), randi_range(9, 14), randf() < 0.3))
			var r: String = await start_battle({"wild": i % 2 == 0, "foes": foes2, "autoplay": true, "trainer": {"name": "Sim", "cls": "Bot"}})
			tally[r] = tally.get(r, 0) + 1
			print("battle ", i, ": ", r, "  party lv ", GameState.party.map(func(x): return x.level))
		print("SIM RESULTS ", tally)
		# merge checks: final forms at their level limit (Lv 40 at rank 1), a fire one and an air one
		var a := Beasts.create(0, 40)
		var b2 := Beasts.create(30, 40)
		var m := Beasts.merge(a, b2, true)
		print("merge: ", m.nickname, " rank ", m.rank, " lv ", m.level, " el ", m.element_text(), " moves ", m.moves, " genes ", m.genes)
		var g := Beasts.create(6, 40, true)
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
		# into the Sky Tower, a word at the ticket desk, up the stairs to the roof and away on the Tempestrix
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
		GameState.add_egg(27)
		for id in ["potion", "fire_bomb", "haste_tonic", "power_collar", "sheet_hymn", "silver_flute"]:
			GameState.add_item(id, 2)
		var m := Beasts.merge(Beasts.create(0, 40), Beasts.create(30, 40))
		m.level = 44
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
	elif scene == "walk4":
		# four-way walking on the grid (--touch adds the d-pad): two keys at once, a change of way mid-step, the
		# gamepad's d-pad and stick, B to run, tap to walk and a porch's raised deck; every stop must be on a tile centre
		await _walk4_test()
		await _wait(wait)
	elif scene == "coaches":
		# the teachers stop you: a new trainer walks the Coastal Path to Tidewater and into its arena talking to no one,
		# and every teacher must spot them and give their lesson
		await _coaches_test()
	elif scene == "mascot":
		# each town's mascot and its signature move: the move's rules, then teaching it (Lv 39: not yet; Lv 40: yes),
		# another race, and a merge. With --plaque (rendered): reads the statue's plaque on screen instead.
		if _test.has("plaque"):
			_do_goto("caccoon", Vector2i(17, 12), Vector2i(0, -1))
			await _wait(1.5)
			world._interact()
			for i in int(_test.get("pages", "2")):
				await _wait(0.8)
				_press("ui_accept")
			await _wait(wait)
		else:
			await _mascot_test()
	elif scene == "flutelesson":
		# the first lone wild beast after Uncle Rafe's lessons: Weaken, then Capture (played by the autoplay)
		GameState.set_flag("flute_lesson_done", false)
		# a new trainer's: just the starter caught so far
		GameState.caught = {}
		_do_goto("route1", "west")
		await _wait(1.5)
		UI.auto = true
		UI.auto_flute = [{"acc": 0.8, "mistakes": 0}]
		var before := GameState.party.size() + GameState.storage.size()
		var res: String = await Story.wild_battle(world, [Beasts.create(27, 3)], "wild")
		print("flute lesson: result ", res, "  done ", GameState.flag("flute_lesson_done"), "  beasts before ", before, " after ", GameState.party.size() + GameState.storage.size())
		for l in UI.auto_log:
			if l.begins_with("[menu]"):
				print("   ", l)
	elif scene == "tutorial":
		# the starter-egg state: one fresh Lv1 hatchling, no lessons yet; --lesson=screen|turns|slingshot|items|ring, or
		# Tidewater's arena coaches: team|elements (--egg=race: the hatchling's race, e.g. 12 for an earth one)
		GameState.party = [Beasts.create(int(_test.get("egg", "0")), 1)]
		GameState.fix_ring()
		GameState.ring_side = maxi(0, Ring.best_side(GameState.ring()))
		if _test.get("lesson", "") == "elements":
			GameState.set_flag("lesson_team")
		GameState.party[0].heal_full()
		GameState.gear["flute"] = ""
		GameState.set_flag("tutorial_done", false)
		var spot := _teacher_spot(String(_test.get("lesson", "screen")))
		# (Youngster Kit and the arena's coaches stop you as you come in, so their lessons begin by themselves)
		UI.auto = _test.get("auto", "0") == "1"
		_do_goto(spot[0], spot[1])
		await _wait(1.5)
		var teacher := _lesson_trainer(String(_test.get("lesson", "screen")))
		var begun: bool = world.busy or in_battle
		if UI.auto:
			while world.busy or in_battle:
				await _wait(0.2)
			if not begun:
				await Story.talk(world, teacher)
			print("lesson result: won=", GameState.flag(teacher.get("flag", "")), " level=", GameState.party[0].level, " hp=", GameState.party[0].hp, "/", GameState.party[0].max_hp())
			for l in UI.auto_log:
				if l.begins_with("[menu]"):
					print("   ", l)
		else:
			if not begun:
				Story.talk(world, teacher)
			await _battle_keys()
			await _wait(wait)
			for i in int(_test.get("presses", "6")):
				await _wait(0.7)
				_press("ui_accept")
			await _wait(wait)
	elif scene == "battlecmd":
		# the command panel played with keys and a touch A (--stop=arc|all|move: stop there for a screenshot)
		await _battlecmd_test()
		await _wait(wait)
	elif scene == "ringedit":
		# arranging your beasts: the ring editor's rules, then tapping its cells (--shot: with a beast picked up)
		await _ringedit_test()
		await _wait(wait)
	elif scene == "lessons":
		# every guided battle played by a button masher: one thing to pick on every bar and in every menu, your beasts
		# never down, and every lesson won
		await _lessons_test()
	elif scene == "newbeasts":
		# the new beasts side by side: a column per line, its stages down it (--lines=dino,owl,..., --stages=1,3,
		# --anim=idle|walk|lie|attack (--at: a screenshot that long into the first attack), --ghost=1, --view=three|
		# side|front, --yaw, --zoom, --centre (raise the view's centre); --merge=dino_3+owl_3,... (--seeds=1,2,3): a
		# row per pair, with their merges)
		await _newbeasts_test()
		await _wait(wait)
	elif scene == "capture":
		UI.auto = true
		GameState.songs = []
		GameState.gear["flute"] = ""
		GameState.set_flag("reed_flute", false)
		GameState.party = [Beasts.create(0, 2)]
		await _do_goto("tidewater", "west")
		await _wait(0.5)
		var arena := _bld("arena")
		print("arena without a flute -> allowed: ", await Story.can_enter(world, arena))
		UI.auto_flute = [{"acc": 0.0, "mistakes": 3, "failed": "misses"}]
		UI.auto_answers = [1]
		print("uncle: fail Weaken and give up -> done: ", await Story.uncle_lessons(), "  flute ", GameState.has_flute(), "  songs ", GameState.songs)
		print("uncle again, pass both -> done: ", await Story.uncle_lessons(), "  songs ", GameState.songs)
		print("arena with a flute -> allowed: ", await Story.can_enter(world, arena))
		var weak := Beasts.create(6, 2)
		var strong := Beasts.create(6, 3)
		var too_big := Beasts.create(6, 6)
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
		# (beasts face any of the eight ways; you only bump into one head on)
		w0["facing"] = Vector2i(1, 0)
		world._face_wild(w0)
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
		# route1: the washed-out footbridge, mended with the logs Youngster Kit hands over after his lesson
		await _go("route1", "west")
		await _wait(1.0)
		var bridge_at := Vector2i(-1, -1)
		for t in world.map["obstacles"]:
			if world.map["obstacles"][t]["kind"] == "broken_bridge" and bridge_at.x < 0:
				bridge_at = t
		var bridge_grp: Dictionary = world.map["obstacles"][bridge_at]
		await Story.field_move(world, bridge_grp)
		print("logs lying along the path: ", world.items.values().filter(func(it): return it["item"] == "bridge_log").size(),
			"  logs Kit would give: ", Story.logs_missing())
		# (an older save: two logs found along the path before Kit kept them)
		GameState.add_item("bridge_log", 2)
		UI.auto_answers = [0]
		await Story.field_move(world, bridge_grp)
		print("two logs placed: ", GameState.flags.get(bridge_grp["flag"] + "_logs", 0), "  fixed: ", GameState.flag(bridge_grp["flag"]),
			"  Kit makes up the rest: ", Story.logs_missing())
		Story._give({"bridge_log": 5})
		UI.auto_answers = [0]
		await Story.field_move(world, bridge_grp)
		print("bridge with five logs fixed: ", GameState.flag(bridge_grp["flag"]), "  tile now walkable: ", world._walkable(bridge_at),
			"  logs left over: ", GameState.item_count("bridge_log"))
		if _test.has("shot"):
			world.player_pos = bridge_at + Vector2i(-2, 0)
			world.player.position = world.tile_pos(world.player_pos)
			await _wait(1.0)
			get_viewport().get_texture().get_image().save_png(String(_test["shot"]).replace(".png", "_bridge.png"))
		# route3: the cliff needs a beast with wings
		await _go("route3", "south")
		await _wait(1.0)
		var cliff: Dictionary = world.map["obstacles"][Vector2i(15, 21)]
		await Story.field_move(world, cliff)
		print("cliff without wings: ", GameState.flag(cliff["flag"]))
		# a Hootlet: the owls are flyers
		GameState.party.append(Beasts.create(30, 12))
		UI.auto_answers = [0]
		await Story.field_move(world, cliff)
		print("cliff with a Hootlet: ", GameState.flag(cliff["flag"]), "  rope walkable: ", world._walkable(Vector2i(15, 20)))
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
	elif scene == "maker":
		# the character creator over the town; --picks=body:1,top:3,row:2 as if chosen (row: the one highlighted)
		_do_goto("caccoon", "start")
		await _wait(1.0)
		var m: Control = load("res://scripts/ui/hero_maker.gd").new()
		UI.push(m)
		await get_tree().process_frame
		for kv in String(_test.get("picks", "")).split(",", false):
			if kv.get_slice(":", 0) == "row":
				m._go(int(kv.get_slice(":", 1)), false)
			else:
				m._choose(kv.get_slice(":", 0), int(kv.get_slice(":", 1)))
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
		# a Pyrosaur and a Tempestrix, final forms at their level limit
		var c := Beasts.merge(Beasts.create(0, 40), Beasts.create(30, 40), true)
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


## Where the teacher who gives `lesson` stands: [map, spawn] (the Coastal Path, Youngster Kit's cabin, or for the
## coaches' lessons the arena of their town).
func _teacher_spot(lesson: String) -> Array:
	for t in Story.ARENA_LESSONS:
		if t["lesson"] == lesson:
			return [MapLoader.interior_of(String(t["town"]), "arena"), "entry"]
	for t in Story.LESSON_TRAINERS:
		if t["lesson"] == lesson and not MapLoader.load_map("route1", {})["anchors"].has(t["anchor"]):
			return [MapLoader.interior_of("route1", "cabin"), "entry"]
	return ["route1", "west"]


## The teacher who gives `lesson` (see Story.LESSON_TRAINERS and ARENA_LESSONS).
func _lesson_trainer(lesson: String) -> Dictionary:
	for p in world.npcs:
		if world.npcs[p].get("lesson", "") == lesson:
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
	print("east exits with a beast: ", world.map["exits"].values().filter(func(e): return e["to"] == "route1").size(),
		"  guard has news: ", Story.npc_has_news(_npc("guard")), "  hint: ", Story.next_goal())
	_step("Scout Bram sends you off", [])
	await Story.talk(world, _npc("guard"))
	await _go("route1", "west")
	await _wait(1.5)
	print("now on ", world.map_id, " encounter ", world.map["encounter"].keys(), " transitioning ", _transitioning,
		"  wild beasts before the flute: ", world.wilds.size())
	for t in Story.LESSON_TRAINERS:
		_step("Coastal Path lesson: " + String(t["lesson"]), [])
		var spot := _teacher_spot(String(t["lesson"]))
		if world.map_id != spot[0]:
			await _go(spot[0], spot[1])
			await _wait(1.0)
		# (Youngster Kit stops you at his door; the others are talked to here: --scene=coaches walks the path)
		if GameState.flag("lesson_" + String(t["lesson"])):
			print(t["name"], " stopped you as you came in")
		else:
			await Story.talk(world, _lesson_trainer(String(t["lesson"])))
		await _wait(0.5)
		if t["lesson"] == "slingshot":
			# Kit's logs, laid across the footbridge just outside his cabin
			print("Kit's logs: ", GameState.item_count("bridge_log"), "  hint: ", Story.next_goal())
			await _go("route1", "west")
			await _wait(1.0)
			for q in world.map["obstacles"]:
				var bridge: Dictionary = world.map["obstacles"][q]
				if bridge["kind"] == "broken_bridge":
					UI.auto_answers = [0]
					await Story.field_move(world, bridge)
					print("footbridge mended: ", GameState.flag(bridge["flag"]), "  logs left ", GameState.item_count("bridge_log"), "  hint: ", Story.next_goal())
					break
	print("after the lessons: tutorial_done ", GameState.flag("tutorial_done"), "  starter ", GameState.party[0].nickname, " Lv", GameState.party[0].level,
		"  minor potions ", GameState.item_count("minor_potion"), "  hint: ", Story.next_goal())
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
	for r in [6, 27, 15, 33]:
		GameState.add_beast(Beasts.create(r, 20))
	print("starting songs: ", GameState.songs)
	await _go("route1", "west")
	await _wait(1.0)
	print("wild beasts on the Coastal Path with a flute: ", world.wilds.size(), "  sizes ", world.wilds.map(func(w): return (w["beasts"] as Array).size()))
	await _go("route2", "west")
	await _wait(1.0)
	var bard := {}
	for p in world.npcs:
		if world.npcs[p].get("song", "") != "":
			bard = world.npcs[p]
	print("bard on route2: ", bard.get("name", "none"), " plays ", bard.get("song", ""))
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
	_step("ferry before the Wave Crest", [0])
	await Story.talk(world, _npc("ferry"))
	await _wait(1.0)
	print("still in ", world.map_id, "  hint: ", Story.next_goal())
	_step("arena: Coach Rory, Coach Ondine, then Tide Captain Marina", [])
	await Places.leader_talk(_bld("arena"))
	print("Marina before the lessons: ", UI.auto_log.back(), "  crest ", GameState.crests.has("Wave Crest"))
	print("  the host's Challenge before the lessons: ", await Places.arena_challenge("tidewater"))
	# walking in, Coach Rory stops you at the door, and Coach Ondine right after him
	await _go(MapLoader.interior_of("tidewater", "arena"), "entry")
	await _wait(1.0)
	for l in ["team", "elements"]:
		print("  lesson ", l, ": done ", GameState.flag("lesson_" + l))
	print("arena lessons done: ", Story.arena_lessons_done("tidewater"), "  hint: ", Story.next_goal())
	GameState.heal_party()
	print("Marina: ", await Places.arena_challenge("tidewater"), "  Wave Crest ", GameState.crests.has("Wave Crest"), "  hint: ", Story.next_goal())
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
		leg.level = 40
		var other = GameState.party.filter(func(x): return x != leg)[0]
		other.level = 40
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
		print("floor ", f, " room ", world.map.get("room_key", "(not in the tower: " + world.map_id + ")"), " stairs ok: ", await Story.can_use_exit(world, {"to": MapLoader.floor_id(ct["interior"], f + 1)}))
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
	for r in [9, 27, 18, 33, 6, 24]:
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
	GameState.party = [Beasts.create(0, 2)]
	GameState.max_shield = 1
	GameState.recharge_shield()
	await _go("route10", "west")
	await _wait(1.5)
	var r: String = await start_battle({"wild": true, "foes": [Beasts.create(21, 40)], "seed": 3})
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


## The four-way walking test (--scene=walk4): prints each check and a count of problems at the end.
func _walk4_test() -> void:
	_do_goto("caccoon", "start")
	await _wait(1.5)
	var w = world
	var bad := [0]
	# every frame: someone walking the grid is always on a tile's middle line across one axis or the other
	var watch := func():
		if not is_instance_valid(w) or not w.is_inside_tree():
			return
		var pos: Vector3 = w.player.position
		if absf(fposmod(pos.x, 1.0) - 0.5) > 0.01 and absf(fposmod(pos.z, 1.0) - 0.5) > 0.01:
			bad[0] += 1
			print("  OFF THE GRID at ", pos)
	get_tree().process_frame.connect(watch)
	# open ground east of the plaza
	var start := Vector2i(22, 10)
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	var check := func(what: String, want: Vector2i) -> void:
		# (the world sees a key a frame after it's pressed)
		await get_tree().process_frame
		await get_tree().process_frame
		for i in 100:
			if not w.moving:
				break
			await get_tree().process_frame
		var at: Vector2i = w.player_pos
		var centred: bool = not w.moving and (w.player.position as Vector3).is_equal_approx(w.tile_pos(at))
		var four: bool = absi(w.facing.x) + absi(w.facing.y) == 1
		var ok: bool = centred and four and (want.x == -999 or at == want)
		if not ok:
			bad[0] += 1
		print("%s %s: at %s%s, facing %s, on the tile's centre %s" % ["ok  " if ok else "FAIL", what, at, "" if want.x == -999 or at == want else " (wanted %s)" % want, w.facing, centred])
	# two keys pressed together: one of the four ways, never a diagonal
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _wait(0.45)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await check.call("keys right+down together", Vector2i(-999, -999))
	var p: Vector2i = w.player_pos
	var straight: bool = p.x == start.x or p.y == start.y
	if not straight:
		bad[0] += 1
	print("%s   ... walked straight from %s to %s" % ["ok  " if straight else "FAIL", start, p])
	# holding right, then down too: keep going right; let go of right: down
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	Input.action_press("move_right")
	await _wait(0.25)
	Input.action_press("move_down")
	await _wait(0.4)
	var mid: Vector2i = w.player_pos
	var kept: bool = mid.y == start.y and mid.x > start.x
	if not kept:
		bad[0] += 1
	print("%s right held, then down too: still going right (at %s)" % ["ok  " if kept else "FAIL", mid])
	Input.action_release("move_right")
	await _wait(0.3)
	Input.action_release("move_down")
	await check.call("let go of right, down takes over", Vector2i(-999, -999))
	var turned: bool = w.player_pos.y > mid.y
	if not turned:
		bad[0] += 1
	print("%s   ... then went down (at %s)" % ["ok  " if turned else "FAIL", w.player_pos])
	# the briefest tap still makes one whole step
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	await _press("move_right")
	await check.call("a one-frame tap right", start + Vector2i(1, 0))
	# a change of way part way through a step: the step finishes first
	start = w.player_pos
	Input.action_press("move_up")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("move_up")
	Input.action_press("move_left")
	await _wait(0.05)
	Input.action_release("move_left")
	await check.call("up, switched to left mid-step", Vector2i(-999, -999))
	var finished: bool = w.player_pos.y == start.y - 1
	if not finished:
		bad[0] += 1
	print("%s   ... the step up finished first (at %s)" % ["ok  " if finished else "FAIL", w.player_pos])
	# the gamepad's d-pad
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_DOWN
	jb.pressed = true
	Input.parse_input_event(jb)
	await _wait(0.3)
	var jb2 := InputEventJoypadButton.new()
	jb2.button_index = JOY_BUTTON_DPAD_DOWN
	Input.parse_input_event(jb2)
	await check.call("gamepad d-pad down", Vector2i(-999, -999))
	# the gamepad's left stick pushed between right and down (mostly right): right only
	p = w.player_pos
	for ax in [[JOY_AXIS_LEFT_X, 0.8], [JOY_AXIS_LEFT_Y, 0.55]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = ax[0]
		jm.axis_value = ax[1]
		Input.parse_input_event(jm)
	await _wait(0.4)
	for ax in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var jm2 := InputEventJoypadMotion.new()
		jm2.axis = ax
		jm2.axis_value = 0.0
		Input.parse_input_event(jm2)
	await check.call("gamepad stick right and a little down", Vector2i(-999, -999))
	var stick_ok: bool = w.player_pos.y == p.y and w.player_pos.x > p.x
	if not stick_ok:
		bad[0] += 1
	print("%s   ... went right only (%s to %s)" % ["ok  " if stick_ok else "FAIL", p, w.player_pos])
	# B held: a run
	start = Vector2i(22, 10)
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	Input.action_press("run")
	Input.action_press("move_right")
	await _wait(0.2)
	var pace: float = w.move_speed
	Input.action_release("move_right")
	Input.action_release("run")
	await check.call("running right (pace %.1f)" % pace, Vector2i(-999, -999))
	if pace < 7.0:
		bad[0] += 1
		print("FAIL   ... B held should run")
	# the touch d-pad
	if UI.is_touch():
		var to_window := Vector2(get_window().size) / get_viewport().get_visible_rect().size
		var arm: float = UI.controls.ARM
		var right_btn: TouchScreenButton = UI.controls._buttons["right"]
		w.player_pos = start
		w.player.position = w.tile_pos(start)
		var at: Vector2 = right_btn.position + Vector2(arm, arm) / 2.0
		_touch(at * to_window, true)
		await _wait(0.35)
		_touch(at * to_window, false)
		await check.call("touch d-pad: right arm", Vector2i(-999, -999))
		# a thumb on the corner between up and right holds just one of them
		var up_btn: TouchScreenButton = UI.controls._buttons["up"]
		var corner: Vector2 = up_btn.position + Vector2(arm + 4.0, arm - 4.0)
		_touch(corner * to_window, true)
		await get_tree().process_frame
		var both: bool = Input.is_action_pressed("move_up") and Input.is_action_pressed("move_right")
		var one: bool = Input.is_action_pressed("move_up") or Input.is_action_pressed("move_right")
		await _wait(0.3)
		_touch(corner * to_window, false)
		if both or not one:
			bad[0] += 1
		print("%s touch d-pad: a thumb between up and right holds one arrow (up %s, right %s)" % ["ok  " if one and not both else "FAIL",
			Input.is_action_pressed("move_up"), Input.is_action_pressed("move_right")])
		await check.call("   ... and walks one way", Vector2i(-999, -999))
	# tap to walk, a few tiles away round a corner
	w.player_pos = start
	w.player.position = w.tile_pos(start)
	await _wait(0.2)
	var goal := start + Vector2i(3, 2)
	w.tap_at(w.cam.unproject_position(w.tile_pos(goal)))
	for i in 60:
		await _wait(0.1)
		if w._path.is_empty() and not w.moving:
			break
	await check.call("tap to walk to %s" % goal, goal)
	# a porch's raised deck: walk up onto it and off again
	var decks: Array = w.ground_h.keys().filter(func(t): return float(w.ground_h[t]) > 0.0 and w._walkable(t))
	if decks.is_empty():
		print("(no raised porch on this map)")
	else:
		var deck: Vector2i = decks[0]
		await _walk_test([deck])
		await check.call("onto a porch deck at height %.2f" % float(w.ground_h[deck]), deck)
		var y_ok: bool = is_equal_approx(w.player.position.y, float(w.ground_h[deck]))
		if not y_ok:
			bad[0] += 1
		print("%s   ... standing on the deck (y %.2f)" % ["ok  " if y_ok else "FAIL", w.player.position.y])
		await _walk_test([deck + Vector2i(0, 2)])
		await check.call("off the deck again", deck + Vector2i(0, 2))
	get_tree().process_frame.disconnect(watch)
	print("WALK TEST DONE: %d problem(s)" % bad[0])


## A finger touching (or lifting off) the screen at `at` (window pixels).
func _touch(at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.pressed = down
	t.position = at
	Input.parse_input_event(t)


## --scene=battlecmd: a trainer battle's command panel played with the keys and a touch A, your fire beasts on the
## ring's fire side (top corner, middle) and an air one on its fire / air corner, and the ring last turned to the air
## side: the battle turns it round to a side with a beast standing in its middle; one tap of A confirms once; your
## own action, then each beast from the top, has its move and then its target confirmed (one target still has it
## picked out, with its card and an arc; a move that hits them all shows them all); ▲ on your own bar turns the ring;
## Move's rules (the beast in the middle can't leave it, a corner beast steps into a fallen one's place or over to
## another side, which then faces the foe; one beast moves each round); and with everyone facing the foe down, the
## ring turns by itself. --stop=arc|all|move stops at that moment (for --shot). Prints "BATTLE COMMANDS DONE: n".
func _battlecmd_test() -> void:
	Engine.time_scale = 2.0
	_do_goto("route1", "west")
	await _wait(1.5)
	var bad := [0]
	var check := func(ok: bool, what: String) -> void:
		if not ok:
			bad[0] += 1
		print("%s %s" % ["ok  " if ok else "FAIL", what])
	var stop := String(_test.get("stop", ""))
	var fire_a := Beasts.create(0, 20)
	var fire_b := Beasts.create(3, 20)
	var air_c := Beasts.create(30, 20)
	var water := Beasts.create(24, 20)
	fire_b.moves.append("fire_spin")
	GameState.beast_slots = 4
	GameState.party = [fire_a, fire_b, air_c, water]
	fire_a.slot = 7
	fire_b.slot = 0
	air_c.slot = 1
	water.slot = 4
	water.hp = 0
	GameState.storage = []
	GameState.ring_side = 1
	GameState.max_shield = 4
	GameState.shield = 4
	var foes := [Beasts.create(12, 20), Beasts.create(15, 20)]
	start_battle({"wild": false, "foes": foes, "trainer": {"name": "Tess", "cls": "Tester", "team": []}, "seed": 7})
	var bt: Node = null
	var heal_foes := [true]
	var panel := func():
		# the next command panel, with the foes healed (so the test's battle lasts)
		for i in 3000:
			var top = UI.stack.back() if not UI.stack.is_empty() else null
			if top != null and top.get_script() == load(PANEL_PATH) and not top.closed:
				for f in foes:
					if heal_foes[0]:
						f.hp = f.max_hp()
				return top
			await get_tree().process_frame
		return null
	var key := func(a: String) -> void:
		await _press(a)
		await _wait(0.12)
	var opt_to := func(p, id: String, move := "") -> void:
		# ◄ ► round the focused bar to an option
		for i in 12:
			var o: Dictionary = p.rows[p.focus]["options"][int(p.rows[p.focus].get("sel", 0))]
			if String(o.get("id", "")) == id and (move == "" or String(o.get("move", "")) == move):
				return
			await key.call("ui_right")
	var p = await panel.call()
	for c in view.get_children():
		if c.get_script() == load(BATTLE_PATH):
			bt = c
	check.call(p != null and bt != null, "the command panel opens")
	if p == null:
		print("BATTLE COMMANDS DONE: %d problem(s)" % bad[0])
		return
	check.call(bt.ally_side == 0, "the ring last faced the air side (nobody in its middle): it starts turned to the %s side" % Ring.side_element(bt.ally_side))
	# one touch A: your slingshot, picked out on its target, but not confirmed twice
	UI.controls._send("a", true)
	await get_tree().process_frame
	UI.controls._send("a", false)
	await _wait(0.2)
	check.call(p.picking and p.focus == 0 and not p.rows[0].get("done", false), "one tap of A: the slingshot only goes on to its target (picking %s, your action done %s)" % [p.picking, p.rows[0].get("done", false)])
	check.call(bt.target_cards.visible and bt._aim_from == "trainer_self" and bt._aim_to.size() == 1, "its target's card shows, and an arc runs from you to it")
	await key.call("ui_accept")
	check.call(p.rows[0].get("done", false) and p.focus == 1 and not p.picking, "A confirms the target: on to the top beast (focus %d)" % p.focus)
	# the top beast: its move, then its target (two foes)
	await opt_to.call(p, "move")
	await key.call("ui_accept")
	check.call(p.picking and p.focus == 1 and not p.rows[1].get("done", false), "the top beast's move needs its target before it's set")
	await _wait(0.1)
	var arcs: int = (bt.aim_mesh.mesh as ImmediateMesh).get_surface_count()
	check.call(bt._aim_from == fire_a and bt._aim_to.size() == 1 and arcs > 0, "an arc runs from %s to its target (%d surface)" % [fire_a.nickname, arcs])
	var first_target = bt._aim_to[0]
	await key.call("ui_right")
	check.call(bt._aim_to.size() == 1 and bt._aim_to[0] != first_target and bt.target_cards.sel == int(p.rows[1]["target_sel"]), "► aims at the other foe, and the arc and the framed card follow")
	if stop == "arc":
		return
	await key.call("ui_accept")
	check.call(p.rows[1].get("done", false) and p.focus == 2 and not p.rows[2].get("done", false), "A: the top beast is set, on to the middle one (the round waits)")
	# the middle beast: Move is out (it guards you); Fire Spin hits them all
	var shift: Dictionary = {}
	for o in p.rows[2]["options"]:
		if o.get("id", "") == "shift":
			shift = o
	check.call(not shift.is_empty() and shift.get("disabled", false), "the beast in the middle can't Move: \"%s\"" % shift.get("desc", ""))
	await opt_to.call(p, "move", "fire_spin")
	await key.call("ui_accept")
	check.call(p.picking and p.rows[2].get("target_all", false) and bt.target_cards.sel == -1 and bt._aim_to.size() == 2, "Fire Spin shows both foes framed, with an arc to each, to confirm")
	if stop == "all":
		return
	await key.call("ui_left")
	check.call(bt._aim_to.size() == 2, "◄ doesn't pick one out of a move that hits them all")
	await key.call("ui_accept")
	check.call(p.rows[2].get("done", false) and p.focus == 3, "A: on to the bottom beast")
	await opt_to.call(p, "move")
	await key.call("ui_accept")
	await key.call("ui_accept")
	# the middle beast falls before the round is over (as if knocked out), for round two
	fire_b.hp = 0
	p = await panel.call()
	check.call(p != null and bt.round_no == 2, "after the bottom beast's target, the round played out (now round %d)" % bt.round_no)
	if p == null:
		print("BATTLE COMMANDS DONE: %d problem(s)" % bad[0])
		return
	fire_a.hp = fire_a.max_hp()
	air_c.hp = air_c.max_hp()
	# round two: Watch, then ▲ on your own bar turns the ring
	await opt_to.call(p, "watch")
	await key.call("ui_accept")
	var side_was: int = bt.ally_side
	await key.call("ui_up")
	p = await panel.call()
	check.call(bt.ally_side != side_was, "▲ on your own bar turns the ring (%s side now)" % Ring.side_element(bt.ally_side))
	# and round to the fire side again: ▼ past the bottom beast
	for i in 4:
		if bt.ally_side == 0:
			break
		while p.focus < p.rows.size() - 1 and p._next_beast(p.focus, 1) > 0:
			await key.call("ui_down")
		await key.call("ui_down")
		p = await panel.call()
	check.call(bt.ally_side == 0, "▼ past the bottom beast turns it back to the fire side")
	# Move: the air beast on the fire / air corner may step to the air side's middle, or its corner
	var air_row := -1
	var fire_row := -1
	for i in p.rows.size():
		if p.rows[i].get("beast", null) == air_c:
			air_row = i
		if p.rows[i].get("beast", null) == fire_a:
			fire_row = i
	var spots: Array = bt._shift_spots(air_c)
	check.call(spots.has(2) and not spots.has(0), "%s may Move to %s (not the fire side's middle)" % [air_c.nickname, spots.map(func(k): return Ring.slot_name(k))])
	check.call(bt._shift_spots(fire_a) == [0], "%s may Move into the fallen middle beast's place: %s" % [fire_a.nickname, bt._shift_spots(fire_a).map(func(k): return Ring.slot_name(k))])
	while p.focus != air_row:
		await key.call("ui_down" if p.focus < air_row else "ui_up")
	await opt_to.call(p, "shift")
	await key.call("ui_accept")
	check.call(p.picking and String(p.rows[air_row].get("pick_kind", "")) == "slot", "Move picks a slot")
	var first_slot: int = int(p.rows[air_row]["targets"][int(p.rows[air_row]["target_sel"])]["ref"])
	await key.call("ui_down")
	var second_slot: int = int(p.rows[air_row]["targets"][int(p.rows[air_row]["target_sel"])]["ref"])
	check.call(spots.size() < 2 or first_slot != second_slot, "▼ goes on to the next slot (%s, then %s)" % [Ring.slot_name(first_slot), Ring.slot_name(second_slot)])
	while int(p.rows[air_row]["targets"][int(p.rows[air_row]["target_sel"])]["ref"]) != 2:
		await key.call("ui_down")
	if stop == "move":
		return
	await key.call("ui_accept")
	check.call(p.rows[air_row].get("done", false), "A: %s will Move to the air side's middle" % air_c.nickname)
	# one beast moves each round
	while p.focus != fire_row:
		await key.call("ui_up" if p.focus > fire_row else "ui_down")
	await opt_to.call(p, "shift")
	await key.call("ui_accept")
	check.call(not p.picking and not p.rows[fire_row].get("done", false), "a second beast can't Move the same round")
	await opt_to.call(p, "move")
	await key.call("ui_accept")
	await key.call("ui_accept")
	for i in 20:
		if UI.stack.is_empty() or UI.stack.back() != p:
			break
		await key.call("ui_accept")
	p = await panel.call()
	check.call(air_c.slot == 2 and bt.ally_side == 1, "%s moved to the %s, and the air side faces the foe now (%s side)" % [air_c.nickname, Ring.slot_name(air_c.slot), Ring.side_element(bt.ally_side)])
	# everyone facing the foe down: the ring turns by itself
	UI.stack.back().close({"kind": "go"})
	air_c.hp = 0
	p = await panel.call()
	check.call(p != null and bt.ally_side != 1 and Ring.side_alive(bt.ally_ring, bt.ally_side), "with everyone on the air side down, the ring turned by itself to the %s side" % Ring.side_element(bt.ally_side))
	# Tess's Move: her middle beast falls, and her corner beast steps into its place
	var mid_foe = bt.foe_ring.get(bt.foe_side * 2, null)
	var corner_foe = null
	for k in Ring.side_slots(bt.foe_side):
		var f = bt.foe_ring.get(k, null)
		if f != null and f != mid_foe and f.hp > 0:
			corner_foe = f
	check.call(mid_foe != null and corner_foe != null, "Tess's ring: %s in the middle, %s on a corner" % [mid_foe.nickname if mid_foe != null else "nobody", corner_foe.nickname if corner_foe != null else "nobody"])
	if mid_foe != null and corner_foe != null:
		mid_foe.hp = 0
		heal_foes[0] = false
		# your side braces (Defend, and you Watch), so nobody knocks the corner beast out first
		for r in p.rows:
			var want := "watch" if r["kind"] == "trainer" else "defend"
			for i in (r["options"] as Array).size():
				if String(r["options"][i].get("id", "")) == want:
					r["sel"] = i
			r["done"] = true
		p.close({"kind": "go"})
		p = await panel.call()
		var now_mid = bt.foe_ring.get(bt.foe_side * 2, null)
		check.call(now_mid == corner_foe and corner_foe.hp > 0 and not bt._side_open("foe"),
			"Tess's %s moved into the middle, covering her again (middle now: %s)" % [corner_foe.nickname, now_mid.nickname if now_mid != null else "nobody"])
	print("BATTLE COMMANDS DONE: %d problem(s)" % bad[0])


## --scene=ringedit: the ring editor (ring_editor.gd, GameState.ring_move): who may go where on the ring and in and out
## of storage, every lit cell agreeing with the rules, and taps (as a finger would) picking a beast up and putting it
## down. Prints each check and "RING EDIT DONE: n problem(s)".
func _ringedit_test() -> void:
	_do_goto("tidewater", "center")
	await _wait(1.5)
	var bad := [0]
	var check := func(ok: bool, what: String) -> void:
		if not ok:
			bad[0] += 1
		print("%s %s" % ["ok  " if ok else "FAIL", what])
	# fire, water and air beasts on the ring (3 / 3), an earth and a second fire one in storage
	var fire := Beasts.create(0, 6)
	var water := Beasts.create(24, 6)
	var air := Beasts.create(30, 6)
	var earth := Beasts.create(12, 6)
	var fire2 := Beasts.create(3, 4)
	GameState.beast_slots = 3
	GameState.party = [fire, water, air]
	fire.slot = 0
	water.slot = 4
	air.slot = 2
	GameState.storage = [earth, fire2]
	GameState.ring_side = 0
	check.call(GameState.ring_move_reason(fire, {"slot": 4}) != "", "a fire beast can't stand on the water side: \"%s\"" % GameState.ring_move_reason(fire, {"slot": 4}))
	check.call(GameState.ring_move(fire, {"slot": 1}) == "" and fire.slot == 1, "fire to the empty fire / air corner")
	check.call(GameState.ring_move_reason(fire, {"slot": 2}) != "", "fire can't trade places with the air side's middle: \"%s\"" % GameState.ring_move_reason(fire, {"slot": 2}))
	check.call(GameState.ring_move_reason(air, {"slot": 1}) != "", "air can't trade places with fire on the fire / air corner, as fire can't stand on the air side: \"%s\"" % GameState.ring_move_reason(air, {"slot": 1}))
	check.call(GameState.ring_move_reason(earth, {"slot": 6}) != "", "a full ring takes no one from storage onto an empty slot: \"%s\"" % GameState.ring_move_reason(earth, {"slot": 6}))
	check.call(GameState.ring_move_reason(earth, {"slot": 4}) != "", "earth can't take the water side's middle")
	check.call(GameState.ring_move(fire2, {"slot": 1}) == "" and fire2.slot == 1 and GameState.storage.has(fire) and fire.slot == -1,
		"the stored fire beast trades places with the one on the corner")
	check.call(GameState.ring_move_reason(earth, {"slot": 2}) != "", "earth can't swap in for the air side's beast")
	check.call(GameState.ring_move(water, {"store": GameState.storage.size()}) == "" and GameState.storage.has(water) and GameState.party.size() == 2,
		"water into storage's empty cell")
	check.call(GameState.ring_move(earth, {"slot": 6}) == "" and earth.slot == 6, "now there's room: earth onto the earth side")
	check.call(GameState.ring_move(water, {"store": 0}) == "" and GameState.storage[0] == water, "storage reorders freely")
	GameState.ring_move(earth, {"store": GameState.storage.size()})
	GameState.ring_move(fire2, {"store": GameState.storage.size()})
	check.call(GameState.party.size() == 1 and GameState.ring_move_reason(air, {"store": GameState.storage.size()}) != "",
		"the last beast stays with you: \"%s\"" % GameState.ring_move_reason(air, {"store": GameState.storage.size()}))
	# back to fire, water and air on the ring, earth and fire2 in storage, for the screen
	for b in [fire, water]:
		GameState.ring_move(b, {"slot": 0 if b == fire else 4})
	# the editor: lit cells match the rules
	world.frozen = true
	var ed: Node = load("res://scripts/ui/ring_editor.gd").new()
	UI.push(ed)
	await _wait(0.6)
	var cell_of := func(dest: Dictionary):
		for c in ed.cells:
			if c.dest == dest:
				return c
		return null
	var tap := func(c) -> void:
		var at: Vector2 = (c as Control).get_global_rect().get_center()
		var vp := get_viewport()
		var px: Vector2 = vp.get_screen_transform() * vp.get_canvas_transform() * at
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = px
			ev.global_position = px
			Input.parse_input_event(ev)
			await get_tree().process_frame
		await get_tree().process_frame
	await tap.call(cell_of.call({"slot": 0}))
	check.call(ed.picked == fire, "tapping the fire beast picks it up (picked: %s)" % (ed.picked.nickname if ed.picked != null else "none"))
	var lit := []
	var agree := true
	for c in ed.cells:
		var rule: bool = GameState.ring_move_reason(fire, c.dest) == "" and ed.beast_in(c.dest) != fire
		if ed.can_go(c.dest) != rule:
			agree = false
		if ed.can_go(c.dest):
			lit.append(c.dest)
	check.call(agree, "the lit cells are just the ones the rules allow: %s" % [lit])
	check.call(not ed.can_go({"slot": 4}) and not ed.can_go({"slot": 2}), "the water and air sides stay dark for a fire beast")
	await tap.call(cell_of.call({"slot": 4}))
	check.call(fire.slot == 0 and ed.picked == fire and ed.hint.text != "", "tapping a dark cell does nothing but say why: \"%s\"" % ed.hint.text)
	await tap.call(cell_of.call({"slot": 7}))
	check.call(fire.slot == 7 and ed.picked == null, "tapping a lit slot moves it there (now on the %s)" % Ring.slot_name(fire.slot))
	await tap.call(cell_of.call({"store": 1}))
	await tap.call(cell_of.call({"slot": 7}))
	check.call(fire2.slot == 7 and GameState.storage.has(fire), "a stored beast tapped onto an occupied slot trades places with it")
	await tap.call(cell_of.call({"slot": 7}))
	await tap.call(cell_of.call({"slot": 7}))
	check.call(ed.picked == null and fire2.slot == 7, "tapping the picked-up beast again puts it back down")
	# for the screenshot: the air beast picked up
	await tap.call(cell_of.call({"slot": 2}))
	print("RING EDIT DONE: %d problem(s)" % bad[0])


## --scene=coaches: a new trainer (a Lv 1 hatchling, no flute, no lessons) walks the Coastal Path by tapped walks from
## Cocoon Cove to Tidewater, in and out of Youngster Kit's cabin and over his footbridge, then (with a flute) into
## Tidewater's arena. Nobody is talked to: every teacher must stop you and give their lesson, in the path's order.
func _coaches_test() -> void:
	Engine.time_scale = 8.0
	UI.auto = true
	autoplay = true
	GameState.party = [Beasts.create(0, 1)]
	GameState.storage = []
	GameState.fix_ring()
	GameState.ring_side = maxi(0, Ring.best_side(GameState.ring()))
	GameState.gear["flute"] = ""
	GameState.set_flag("tutorial_done", false)
	var bad := [0]
	var teachers: Array = Story.LESSON_TRAINERS + Story.ARENA_LESSONS
	# every frame: a lesson that's just been given, and where you were
	var given := []
	var watch := func():
		for t in teachers:
			if GameState.flag("lesson_" + String(t["lesson"])) and not given.has(t["lesson"]):
				given.append(t["lesson"])
				print("  %s %s stopped you (%s, at %s)" % [t["cls"], t["name"], world.map_id, world.player_pos])
	get_tree().process_frame.connect(watch)
	await _go("route1", "west")
	await _settle("route1")
	# along the trail to Kit's door, and in: he sees you come in
	var cabin := _bld("cabin")
	await _walk_road([cabin["door"] + Vector2i(0, 1)])
	world._step(Vector2i(0, -1), false)
	await _settle(MapLoader.interior_of("route1", "cabin"))
	await _walk_road(world.map["exits"].keys())
	await _settle("route1")
	# his logs, across the footbridge
	var post := Vector2i(-999, -999)
	for q in world.map["obstacles"]:
		var r: Vector2i = q + Vector2i(-1, 0)
		if world.map["obstacles"][q]["kind"] == "broken_bridge" and not world.map["obstacles"].has(r) and world._walkable(r):
			post = r
	await _walk_road([post])
	world.facing = Vector2i(1, 0)
	UI.auto_answers = [0]
	await world._interact()
	var mended: bool = not world.map["obstacles"].has(post + Vector2i(1, 0))
	print("%s footbridge mended with Kit's logs" % ("ok  " if mended else "FAIL"))
	if not mended:
		bad[0] += 1
	# on along the trail to Tidewater
	await _walk_road(world.map["exits"].keys().filter(func(e): return world.map["exits"][e]["to"] == "tidewater"))
	await _settle("tidewater")
	var path_lessons: Array = Story.LESSON_TRAINERS.map(func(t): return t["lesson"])
	var ok: bool = given == path_lessons and GameState.flag("tutorial_done")
	print("%s the Coastal Path's teachers, in order: %s (wanted %s), tutorial_done %s" % ["ok  " if ok else "FAIL", given, path_lessons, GameState.flag("tutorial_done")])
	if not ok:
		bad[0] += 1
	# Uncle Rafe's flute, then into the arena: Coach Rory at the door, then Coach Ondine
	GameState.gear["flute"] = "reed_flute"
	GameState.set_flag("reed_flute")
	var arena := _bld("arena")
	await _walk_road([arena["door"] + Vector2i(0, 1)])
	world._step(Vector2i(0, -1), false)
	await _settle(MapLoader.interior_of("tidewater", "arena"))
	var all_lessons: Array = teachers.map(func(t): return t["lesson"])
	ok = given == all_lessons and Story.arena_lessons_done("tidewater")
	print("%s the arena's coaches, in order: %s (wanted %s)" % ["ok  " if ok else "FAIL", given.slice(path_lessons.size()), all_lessons.slice(path_lessons.size())])
	if not ok:
		bad[0] += 1
	get_tree().process_frame.disconnect(watch)
	print("starter ", GameState.party[0].nickname, " Lv", GameState.party[0].level, "  hint: ", Story.next_goal())
	print("coaches DONE: %d problem(s)" % bad[0])


## --scene=lessons: every guided battle (the Coastal Path's teachers, Tidewater's arena coaches and the flute lesson)
## played by a button masher (random presses of A, B and the d-pad, nothing automatic), once with just a hatchling and
## once with a second beast beside it. Every bar and every menu must offer exactly one thing to pick, your beasts must
## never go down, and every lesson must be won. --seed=n
func _lessons_test() -> void:
	Engine.time_scale = 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_test.get("seed", "1"))
	var bad := [0]
	var teachers: Array = Story.LESSON_TRAINERS + Story.ARENA_LESSONS
	for party in [[0], [0, 3]]:
		for t in teachers + [{"lesson": "flute", "name": "Uncle Rafe"}]:
			var lesson := String(t["lesson"])
			while _transitioning or not _pending_goto.is_empty() or in_battle:
				await _wait(0.1)
			# a new trainer's hatchling (and a second fire beast, as if adopted from the kennel), with no lessons yet
			GameState.party = []
			for r in party:
				GameState.party.append(Beasts.create(r, 1 if lesson != "flute" else 3))
			GameState.storage = []
			GameState.fix_ring()
			GameState.ring_side = maxi(0, Ring.best_side(GameState.ring()))
			for l in teachers:
				GameState.set_flag("lesson_" + String(l["lesson"]), false)
			GameState.set_flag(String(t.get("needs", "")), true)
			GameState.set_flag("tutorial_done", lesson == "flute")
			GameState.set_flag("flute_lesson_done", false)
			GameState.caught = {}
			GameState.gear["flute"] = "reed_flute" if lesson == "flute" else ""
			var res := [""]
			if lesson == "flute":
				_do_goto("route1", "west")
				await _wait(1.5)
				var wild := func(): res[0] = await Story.wild_battle(world, [Beasts.create(27, 3)], "wild")
				wild.call()
			else:
				var spot := _teacher_spot(lesson)
				_do_goto(spot[0], spot[1])
				await _wait(1.5)
				# (Youngster Kit and the arena's coaches have stopped you already)
				if not (world.busy or in_battle):
					Story.talk(world, _lesson_trainer(lesson))
			var problems := {}
			var presses := 0
			var lowest := 999
			for i in 6000:
				if not in_battle and (res[0] != "" or GameState.flag("lesson_" + lesson)) and not world.busy and not UI.busy():
					break
				var top = UI.stack.back() if not UI.stack.is_empty() else null
				if top != null and top.get_script() == load(PANEL_PATH):
					for j in top.rows.size():
						var row: Dictionary = top.rows[j]
						var open: Array = row["options"].filter(func(o): return not o.get("disabled", false))
						if row.get("status", "") == "" and not row.get("locked", false) and open.size() != 1:
							problems["a bar offers %s" % [open.map(func(o): return o.get("label", ""))]] = true
						if top.picking and j == top.focus and (row.get("targets", []) as Array).size() != 1:
							problems["%d targets to pick from" % (row["targets"] as Array).size()] = true
				elif top is UI.ListMenu:
					var open2: Array = top.items.filter(func(o): return not o.get("disabled", false))
					if open2.size() != 1:
						problems["the %s menu offers %s" % [top.title, open2.map(func(o): return o.get("text", ""))]] = true
				if in_battle:
					for c in view.get_children():
						if c.get_script() == load(BATTLE_PATH):
							for b in c.ally_slots:
								if b != null:
									lowest = mini(lowest, b.hp)
									if b.hp <= 0:
										problems["%s went down" % b.nickname] = true
				_press(["ui_accept", "ui_accept", "ui_accept", "ui_left", "ui_right", "ui_up", "ui_down", "ui_cancel"][rng.randi() % 8])
				presses += 1
				await _wait(0.12)
			var won: bool = res[0] == "win" if lesson == "flute" else GameState.flag("lesson_" + lesson)
			if not won:
				problems["not won"] = true
			bad[0] += problems.size()
			print("%s %s's lesson (%s), %d beast(s): %d presses, lowest HP %d%s" % ["ok  " if problems.is_empty() else "FAIL", t["name"], lesson, party.size(), presses, lowest,
				"" if problems.is_empty() else "  " + ", ".join(problems.keys())])
	print("lessons DONE: %d problem(s)" % bad[0])


func _newbeasts_test() -> void:
	var Rig = load("res://scripts/gfx/beast_rig.gd")
	var root := Node3D.new()
	view.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9cc3e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var anim := String(_test.get("anim", "idle"))
	var ghost: bool = _test.get("ghost", "0") == "1"
	# the cells, [column, row, label, form or [a, b, seed]]: a column per line, its stages down it; or a row per pair
	# of parents, then a few of their merges
	var cells := []
	if _test.has("merge"):
		var r := 0
		for pair in String(_test["merge"]).split(","):
			var a := pair.get_slice("+", 0)
			var b := pair.get_slice("+", 1)
			cells.append([0, r, a, a])
			cells.append([1, r, b, b])
			var seeds := String(_test.get("seeds", "1,2,3")).split(",")
			for k in seeds.size():
				cells.append([2 + k, r, "%s × %s #%s" % [a.get_slice("_", 0), b.get_slice("_", 0), seeds[k]], [a, b, int(seeds[k])]])
			r += 1
	else:
		var c := 0
		var stages := String(_test.get("stages", "1,2,3")).split(",")
		for line in String(_test.get("lines", "dino,scorpion,berry,beetle,cactus")).split(","):
			for k in stages.size():
				var f := "%s_%s" % [line, stages[k]]
				cells.append([c, k, f, f])
			c += 1
	var cols := 0
	var rows := 0
	for cell in cells:
		cols = maxi(cols, cell[0] + 1)
		rows = maxi(rows, cell[1] + 1)
	# --view: three (three quarters, the default), side or front (looking it in the face)
	var vw := String(_test.get("view", "three"))
	var across := Vector3(1, 0, 0) if vw != "front" else Vector3(0, 0, -1)
	var back := Vector3(0, 0, -1) if vw != "front" else Vector3(-1, 0, 0)
	var yaw := float(_test.get("yaw", "-60" if vw == "three" else "0"))
	var dx := 2.2
	var dy := 1.8
	var rigs := []
	for cell in cells:
		var rig: Node3D = Rig.new()
		root.add_child(rig)
		if cell[3] is Array:
			rig.setup_merge(cell[3][0], cell[3][1], cell[3][2], ghost)
		else:
			rig.setup(cell[3], ghost)
		var s: float = 1.0 if cell[3] is Array else [0.72, 0.86, 1.0][int(String(cell[3]).get_slice("_", 1)) - 1]
		var at: Vector3 = across * (cell[0] * dx) + Vector3(0, -cell[1] * dy, 0) + back * (cell[1] * 0.8)
		rig.position = at
		rig.scale = Vector3(s, s, s)
		rig.rotation_degrees.y = yaw
		rig.state = "idle" if anim == "attack" else anim
		rigs.append(rig)
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.75
		cyl.height = 0.04
		pad.mesh = cyl
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color("#8fbf6a")
		pad.material_override = pm
		pad.position = at - Vector3(0, 0.02, 0)
		root.add_child(pad)
		var lb := Label3D.new()
		lb.text = cell[2]
		lb.font_size = 36
		lb.outline_size = 8
		lb.pixel_size = 0.004
		lb.position = at + Vector3(0, -0.22, 0) - back * 0.8
		if vw == "front":
			lb.rotation_degrees.y = 90.0
		root.add_child(lb)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var vs := get_viewport().get_visible_rect().size
	cam.size = maxf(rows * dy + 0.3, (cols * dx + 0.2) * vs.y / vs.x) / float(_test.get("zoom", "1"))
	var mid: Vector3 = across * ((cols - 1) * dx / 2.0) + Vector3(0, -(rows - 1) * dy / 2.0 + 0.5, 0) + back * ((rows - 1) * 0.4)
	mid.y += float(_test.get("centre", "0"))
	cam.position = mid - back * 10.0 + Vector3(0, 2.0, 0)
	cam.look_at(mid, Vector3.UP)
	cam.current = true
	if anim == "attack":
		# an attack every 1.3 s, the first 0.4 s in (--at: a screenshot that long into it)
		var tm := Timer.new()
		tm.wait_time = 1.3
		root.add_child(tm)
		tm.timeout.connect(func() -> void:
			for rig in rigs:
				rig.attack())
		await _wait(0.4)
		for rig in rigs:
			rig.attack()
		tm.start()
		if _test.has("at"):
			await _wait(float(_test["at"]))


## Tapped walks to the nearest of `goals` on this map, again after each stop (a teacher's lesson, say), until you're on
## one or the map changes.
func _walk_road(goals: Array) -> void:
	var w = world
	for i in 3000:
		if world != w or _transitioning or not _pending_goto.is_empty():
			return
		if w.player_pos in goals and not w.moving:
			return
		if not (w.busy or w.moving or in_battle or UI.busy()) and w._path.is_empty():
			w._walk_to(goals, Vector2i(-999, -999), false)
		await _wait(0.1)
	print("FAIL   couldn't walk to ", goals, " (at ", w.player_pos, ")")


## Waits until you're on map `id` with nothing going on (its arrival and any lesson that stops you there done).
func _settle(id: String) -> void:
	for i in 3000:
		if world != null and world.map_id == id and not _transitioning and _pending_goto.is_empty() and not world.busy and not in_battle and not UI.busy():
			await _wait(0.5)
			if not (world.busy or in_battle):
				return
		await _wait(0.1)
	print("FAIL   never settled on ", id)


## The mascot test (--scene=mascot): prints each check and a count of problems at the end.
func _mascot_test() -> void:
	var MoveDB = load("res://scripts/data/move_db.gd")
	var bad := 0
	for id in WorldDB.TOWN_ORDER:
		var race: int = WorldDB.TOWNS[id]["mascot"]
		var mv: String = WorldDB.TOWNS[id].get("signature", "")
		var m: Dictionary = MoveDB.get_move(mv)
		# (a dual line's move may be of its second element)
		var el := RaceDB.element2(race) if String(m.get("el", "")) == RaceDB.element2(race) else RaceDB.element(race)
		var strongest := 0
		for p in MoveDB.POOLS[el]:
			strongest = maxi(strongest, int(MoveDB.get_move(p).get("power", 0)))
		var levelled: bool = RaceDB.learnset(race).any(func(e): return e[1] == mv)
		var ok: bool = mv != "" and MoveDB.MOVES.has(mv) and m["el"] == el and m["kind"] == "attack" and int(m["power"]) > strongest and not levelled and int(MoveDB.SIGNATURE.get(mv, -1)) == RaceDB.first_form(race)
		if not ok:
			bad += 1
		print("%s %-11s %-12s %-18s %s power %d (strongest %s move by levelling: %d)  %s statue" % ["ok  " if ok else "FAIL", id, RaceDB.race_name(race), m.get("name", "?"), el, int(m.get("power", 0)), el, strongest, WorldDB.statue_metal(id)])
	UI.auto = true
	_do_goto("caccoon", "start")
	await _wait(1.5)
	var mascot := _npc("mascot")
	# (straight into the party: the mascot only teaches a beast you have with you)
	# a Cinderex (the dino line's second form, as the Pyrosaur mascot's line)
	var kin := Beasts.create(0, 39)
	GameState.party.append(kin)
	UI.auto_answers = [0]
	await Story.talk(world, mascot)
	var early: bool = not kin.known.has("bandit_blaze")
	print("%s a Lv 39 %s can't learn it yet: %s" % ["ok  " if early else "FAIL", kin.nickname, UI.auto_log.back()])
	kin.level = 40
	UI.auto_answers = [0]
	await Story.talk(world, mascot)
	var learned: bool = kin.known.has("bandit_blaze")
	print("%s at Lv 40 it learns Bandit Blaze: %s  (moves %s)" % ["ok  " if learned else "FAIL", learned, kin.moves])
	GameState.party.erase(kin)
	var other := Beasts.create(3, 45)
	GameState.party.append(other)
	UI.auto_answers = [0]
	await Story.talk(world, mascot)
	var refused: bool = not other.known.has("bandit_blaze")
	print("%s a %s (another fire line) isn't taught: %s" % ["ok  " if refused else "FAIL", other.nickname, UI.auto_log.back()])
	var child := Beasts.merge(other, kin, true)
	var kept: bool = child.known.has("bandit_blaze") == (RaceDB.first_form(child.race) == 0)
	print("%s a merge (%s) keeps Bandit Blaze only if it's of the dino line: %s" % ["ok  " if kept else "FAIL", RaceDB.race_name(child.race), child.known.has("bandit_blaze")])
	for ok2 in [early, learned, refused, kept]:
		if not ok2:
			bad += 1
	UI.auto = false
	print("MASCOT TEST DONE: %d problem(s)" % bad)


## Battle test scenes: once the command panel is up, presses --keys (a b l r u d: A, B, left, right, up, down), one
## every --gap seconds.
func _battle_keys() -> void:
	if not _test.has("keys"):
		return
	var tries := 0
	while tries < 1200 and not (UI.stack.size() > 0 and UI.stack.back().get_script() == load(PANEL_PATH)):
		await get_tree().process_frame
		tries += 1
		# (a lesson's words come first: read on through them)
		if tries % 30 == 0 and UI.stack.size() > 0 and UI.stack.back() is UI.DialogBox:
			_press("ui_accept")
	for k in String(_test.get("keys", "")).split(",", false):
		await _press({"a": "ui_accept", "b": "ui_cancel", "l": "ui_left", "r": "ui_right", "u": "ui_up", "d": "ui_down"}.get(k, "ui_accept"))
		await _wait(float(_test.get("gap", "0.4")))
	# --tapcard=i: then taps target card i (as a finger would), printing who's aimed at
	if _test.has("tapcard") and UI.stack.size() > 0:
		var panel = UI.stack.back()
		var cards: Control = panel.hooks.get("cards", null) if "hooks" in panel else null
		if cards == null or not cards.visible:
			print("tapcard: no target cards showing")
			return
		var at: Vector2 = cards.get_global_transform_with_canvas() * cards.card_rect(int(_test["tapcard"])).get_center()
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = at * Vector2(get_window().size) / get_viewport().get_visible_rect().size
			Input.parse_input_event(ev)
			await get_tree().process_frame
		var row: Dictionary = panel.rows[panel.focus]
		print("tapcard %s: aiming at %s (card %d framed)" % [_test["tapcard"], row["targets"][int(row.get("target_sel", 0))]["label"], cards.sel])


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
	# --body=female --top=3a6ab8 --trousers=... --hair=... --eyes=...: the hero as the character creator can make them
	var look := {"face": "hero"}
	for k in ["body", "top", "trousers", "hair", "eyes"]:
		if _test.has(k):
			look[k] = _test[k]
	if _test.has("model"):
		look = {"model": _test["model"]}
	# --pose=walk: side views an eighth of a stride apart (--speed: 1.7 a stroll, 4.6 the hero's jog, 7.8 a sprint)
	var walk: bool = _test.get("pose", "") == "walk"
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i in 4:
		var rig: Node3D = VPer.build(look)
		VPer.face(rig, Vector2i(1, 0) if walk else dirs[i])
		if walk:
			VPer.animate(rig, i * PI / 4.0 + float(_test.get("phase", "0")), float(_test.get("speed", "4.6")), 0.0)
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
		# the lines' forms, then the legendaries
		for i in range(page * 12, mini(page * 12 + 12, RaceDB.NORMAL_COUNT + RaceDB.LEGENDARY.size())):
			genes_list.append([RaceDB.race_name(i), RaceDB.genes(i)])
	else:
		# merges of final forms (Lv 40), some with a ghost
		for i in 12:
			var a := Beasts.create(i * 3, 40, i % 3 == 0)
			var b := Beasts.create((i * 7 + 13) % RaceDB.NORMAL_COUNT, 40)
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
