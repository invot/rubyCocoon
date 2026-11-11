extends CanvasLayer
## UI manager: a stack of modal screens plus HUD helpers (the top bar's notices, fades).

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ListMenu = preload("res://scripts/ui/list_menu.gd")
const DialogBox = preload("res://scripts/ui/dialog_box.gd")
const ConfirmPrompt = preload("res://scripts/ui/confirm_prompt.gd")
const TextEntry = preload("res://scripts/ui/text_entry.gd")
const BeastView = preload("res://scripts/ui/beast_view.gd")
const FluteGame = preload("res://scripts/ui/flute_game.gd")
const ControlsOverlay = preload("res://scripts/ui/controls_overlay.gd")
const PauseOverlay = preload("res://scripts/ui/pause_overlay.gd")
const SaveCard = preload("res://scripts/ui/save_card.gd")
const TopBar = preload("res://scripts/ui/top_bar.gd")
const Glyphs = preload("res://scripts/ui/glyphs.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

var root: Control
var hud: Control
var modal_layer: Control
var fade_rect: ColorRect
var spiral_rect: ColorRect
## the strip at the top centre for notices and battle messages (top_bar.gd)
var top_bar: TopBar
var stack: Array = []
var controls: CanvasLayer
## false on the title screen (no pausing there)
var allow_pause := true
var _last_close := 0
## Test mode: dialogs resolve instantly and menus take answers from this queue (-1 when empty).
var auto := false
var auto_answers: Array = []
var auto_log: Array = []
## test mode: queued flute results ({"acc", "mistakes"} or a float accuracy)
var auto_flute: Array = []
## test mode: queued beat attacks (battle/beat_cue.gd), each the presses to make: every beat's offset in seconds from
## it, or null to let it go by. With none queued, test battles roll their chains.
var auto_beats: Array = []


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIKit.set_screen_scale(Vector2(DisplayServer.window_get_size()))
	UIKit.set_accent(Prefs.accent)
	UIKit.set_blur(not "--no_blur" in OS.get_cmdline_user_args())
	get_tree().root.size_changed.connect(_on_window_resized)
	Prefs.changed.connect(_on_prefs_changed)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.make_theme()
	add_child(root)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	top_bar = TopBar.new()
	root.add_child(top_bar)
	spiral_rect = ColorRect.new()
	spiral_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	spiral_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/ui/spiral.gdshader")
	spiral_rect.material = sm
	spiral_rect.visible = false
	root.add_child(spiral_rect)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	controls = ControlsOverlay.new()
	add_child(controls)


## Heading sizes and the border's line width follow the screen's scale; when it changes, so does the theme.
func _on_window_resized() -> void:
	if UIKit.set_screen_scale(Vector2(DisplayServer.window_get_size())):
		root.theme = UIKit.make_theme()


## A new gem: the theme is rebuilt (screens built afterwards pick it up; the open book redraws itself).
func _on_prefs_changed() -> void:
	if Prefs.accent != UIKit.accent_name:
		UIKit.set_accent(Prefs.accent)
		root.theme = UIKit.make_theme()


## Height kept clear at the bottom of the screen for the key legend / touch buttons.
func bottom_reserve() -> float:
	if controls == null:
		return 0.0
	if controls.touch_visible():
		return 96.0
	return controls.LEGEND_H if controls.legend_visible() else 0.0


## True when the on-screen touch pad is showing (phones, tablets).
func is_touch() -> bool:
	return controls != null and controls.touch_visible()


## True if a screen point is under one of the touch buttons.
func touch_blocks(p: Vector2) -> bool:
	return controls != null and controls.covers(p)


func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause") and not ev.is_echo() and allow_pause and not auto:
		if stack.is_empty() or not (stack.back() is PauseOverlay or stack.back() is FluteGame):
			push(PauseOverlay.new())
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- stack
func busy() -> bool:
	return stack.size() > 0 or Time.get_ticks_msec() - _last_close < 180


func push(m) -> void:
	var fo = get_viewport().gui_get_focus_owner()
	m.prev_focus = fo if is_instance_valid(fo) else null
	get_viewport().gui_release_focus()
	modal_layer.add_child(m)
	stack.append(m)


func pop(m) -> void:
	stack.erase(m)
	_last_close = Time.get_ticks_msec()
	var pf = m.prev_focus
	m.queue_free()
	if is_instance_valid(pf) and pf.is_visible_in_tree():
		pf.grab_focus()


func _unhandled_input(ev: InputEvent) -> void:
	if stack.is_empty():
		return
	if ev is InputEventMouse or ev is InputEventJoypadMotion and not ev.is_action_type():
		return
	stack.back().on_input(ev)
	get_viewport().set_input_as_handled()


func clear_all() -> void:
	for m in stack.duplicate():
		m.close()


# ---------------------------------------------------------------- awaitable helpers
func say(lines, speaker := "", portrait: Texture2D = null, speaker_node: Node3D = null) -> void:
	if typeof(lines) == TYPE_STRING:
		lines = [lines]
	if lines.is_empty():
		return
	if auto:
		auto_log.append(("%s: " % speaker if speaker != "" else "") + str(lines[0]))
		await get_tree().process_frame
		return
	var d := DialogBox.new()
	d.setup(lines, speaker, portrait, speaker_node)
	push(d)
	await d.done


func choose(title: String, items: Array, opts := {}) -> int:
	if auto:
		await get_tree().process_frame
		var a: int = auto_answers.pop_front() if not auto_answers.is_empty() else -1
		if a < 0 and not opts.get("cancel", true):
			a = 0
		auto_log.append("[menu] %s -> %d" % [title.get_slice(char(10), 0), a])
		return a
	var m := ListMenu.new()
	m.setup(title, items, opts)
	push(m)
	var r = await m.done
	return int(r)


func ask(question: String, speaker := "", yes := "Yes", no := "No", speaker_node: Node3D = null) -> bool:
	if auto:
		await say([question], speaker)
		return await choose("", [yes, no]) == 0
	var prompt := ConfirmPrompt.new()
	prompt.yes_text = yes
	prompt.no_text = no
	prompt.confirmation_labels = {"a": yes, "b": no}
	prompt.setup([question], speaker, null, speaker_node)
	push(prompt)
	return await prompt.done == 0


func text_input(prompt: String, default := "") -> String:
	if auto:
		await get_tree().process_frame
		return default
	var t := TextEntry.new()
	t.setup(prompt, default)
	push(t)
	var r = await t.done
	return str(r)


## The character creator (hero_maker.gd, loaded only when a new game begins): {"name", "look"}, or null if backed
## out of.
func make_hero():
	if auto:
		await get_tree().process_frame
		return {"name": "Andrew", "look": {}}
	var script: GDScript = await GameState.main.wait_for_script("res://scripts/ui/hero_maker.gd")
	var m: Control = script.new()
	push(m)
	return await m.done


func show_beast(b, heading := "") -> void:
	if auto:
		await get_tree().process_frame
		return
	var v := BeastView.new()
	v.setup(b, heading)
	push(v)
	await v.done


## Loaded on demand so hatch/growth models do not delay the title screen.
func beast_cinematic(kind: String, before: Dictionary, after := {}, egg := {}) -> void:
	if auto:
		auto_log.append("[cinematic] %s %s" % [kind, after.get("name", before.get("name", ""))])
		await get_tree().process_frame
		return
	await play_film(load("res://scripts/ui/beast_cinematic.gd").new().setup(kind, before, after, egg))


## Shows a full-screen film and waits for it to end. The hidden world stops rendering until then.
func play_film(film) -> void:
	var world_view: SubViewport = GameState.main.view if GameState.main != null else null
	var previous_update := SubViewport.UPDATE_ALWAYS
	if is_instance_valid(world_view):
		previous_update = world_view.render_target_update_mode
		world_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	push(film)
	await film.done
	if is_instance_valid(world_view):
		world_view.render_target_update_mode = previous_update


## The "Game saved!" card with the slot's snapshot.
func show_save_card(slot: int) -> void:
	if auto:
		await get_tree().process_frame
		return
	var c := SaveCard.new()
	c.setup(slot)
	push(c)
	await c.done


func flute(song_id: String, subtitle := "") -> float:
	var r: Dictionary = await flute_ex(song_id, subtitle)
	return float(r["acc"])


## The flute minigame with options (see flute_game.gd): mode "play" / "learn" / "demo", goal, performer.
## Returns {"acc", "mistakes", "cancelled"}. In auto (test) mode the results come from auto_flute, else a clean run.
func flute_ex(song_id: String, subtitle := "", opts := {}) -> Dictionary:
	if auto:
		await get_tree().process_frame
		var a = auto_flute.pop_front() if not auto_flute.is_empty() else {"acc": 0.9, "mistakes": 0}
		var res: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {"acc": float(a), "mistakes": 0}
		res["cancelled"] = false
		auto_log.append("[flute] %s %s -> %d%%, %d mistakes" % [opts.get("mode", "play"), song_id, int(float(res["acc"]) * 100), int(res["mistakes"])])
		return res
	var g := FluteGame.new()
	var bonus := 0.0 if opts.get("mode", "play") == "demo" else GameState.flute_time_bonus()
	g.setup(song_id, subtitle, bonus, opts)
	push(g)
	var r = await g.done
	if typeof(r) != TYPE_DICTIONARY:
		return {"acc": 0.0, "mistakes": 99, "cancelled": true}
	return r


# ---------------------------------------------------------------- HUD bits
## A short notice in the top bar (it waits its turn, and for a battle to end). `icon`: a glyph name (glyphs.gd), a UI
## texture name (UIKit.tex), a texture, a beast or an item id prefixed "item:"; anything else gets the notice mark.
## `key`: notices with the same key merge into one ("Bought Potion x3").
func toast(text: String, icon: Variant = "notice", key := "") -> void:
	if auto:
		auto_log.append("[toast] " + text)
	top_bar.post(text, icon_texture(icon), {"key": key})


## An item collected: its name and glyph in the top bar, with its sound. More of the same while it shows (or waits)
## add up ("Potion x3").
func pickup(id: String, count := 1, sound := "item") -> void:
	Sfx.play(sound)
	var name := ItemDB.item_name(id)
	if auto:
		auto_log.append("[pickup] %s x%d" % [name, count])
	var sub := ""
	match String(ItemDB.get_item(id).get("kind", "")):
		"tgear":
			sub = "Put it on from your Bag in the Start book."
		"gear":
			sub = "Give it to a beast from your Bag in the Start book."
	top_bar.post(name, Glyphs.item(id), {"key": "item:" + id, "count": count, "sub": sub})


## Gold received: "+120 gold" by a coin (amounts close together add up).
func gold(amount: int) -> void:
	top_bar.post("", Glyphs.tex("coin"), {"key": "gold", "count": amount, "fmt": "+%d gold"})


## A place's name on entering it, in League Spartan Semibold and the gem heading colour: `icon` is
## its crest or a map pin.
func place_name(title: String, sub := "", icon: Texture2D = null) -> void:
	top_bar.post(title, icon if icon != null else Glyphs.tex("pin"), {"sub": sub, "heading": true, "key": "place", "replace": true})


## (older name) a place's name.
func banner(title: String, sub := "") -> void:
	place_name(title, sub)


## The texture a notice's icon stands for (see toast).
func icon_texture(icon: Variant) -> Texture2D:
	if icon is Texture2D:
		return icon
	if typeof(icon) == TYPE_OBJECT and icon != null and "genes" in icon:
		return PixelArt.beast_texture(icon.genes)
	if typeof(icon) in [TYPE_STRING, TYPE_STRING_NAME]:
		var s := String(icon)
		if s.begins_with("item:"):
			return Glyphs.item(s.substr(5))
		if Glyphs.GLYPHS.has(s):
			return Glyphs.tex(s)
		var t := UIKit.tex(s)
		if t != null:
			return t
	return Glyphs.tex("notice")


func fade_out(t := 0.3, col := Color.BLACK) -> void:
	fade_rect.color = Color(col, fade_rect.color.a)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, t)
	await tw.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## A spiral of colour that winds in from the centre until it fills the screen (wild battles).
func spiral_in(col: Color, t := 0.8) -> void:
	if auto:
		return
	var sm: ShaderMaterial = spiral_rect.material
	sm.set_shader_parameter("color", col)
	sm.set_shader_parameter("progress", 0.0)
	sm.set_shader_parameter("fade", 1.0)
	var vp := get_viewport().get_visible_rect().size
	sm.set_shader_parameter("aspect", vp.x / maxf(1.0, vp.y))
	spiral_rect.visible = true
	spiral_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_method(func(v): sm.set_shader_parameter("progress", v), 0.0, 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


## Fades the full-screen spiral away again.
func spiral_out(t := 0.35) -> void:
	if auto or not spiral_rect.visible:
		return
	var sm: ShaderMaterial = spiral_rect.material
	var tw := create_tween()
	tw.tween_method(func(v): sm.set_shader_parameter("fade", v), 1.0, 0.0, t)
	await tw.finished
	spiral_rect.visible = false
	spiral_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash(col := Color.WHITE, times := 3) -> void:
	if auto:
		return
	for i in times:
		fade_rect.color = Color(col, 0.0)
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 0.8, 0.07)
		tw.tween_property(fade_rect, "color:a", 0.0, 0.07)
		await tw.finished
