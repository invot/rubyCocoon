extends "res://scripts/ui/modal.gd"
## The character creator, before a new game. The hero stands in their own bedroom (the real room, built as a set: see
## main.gd build_set) beside a standing mirror that shows their other side, on the left of the screen; the choices
## are on the right, on four tabs that float above the window like the Start book's (You, Face, Torso, Legs), none
## with more rows than fit, so nothing scrolls. Clothes, hats and glasses come from the wardrobe
## (scripts/data/wardrobe_db.gd), each piece named, and each dyed on its own row: the row's swatch opens a grid of
## big colours over it (ColourPick) to choose from and confirm. Closes with {"name", "look"} (the look for
## GameState.hero), or null when backed out of.
## Keys: up and down pick a row (the tabs above the first, Confirm below the last), left and right change it (on the
## tabs: switch tab), A on a row with a colour opens its colours, on another row goes on to the next (from a tab's last
## row on to the next tab), and on Confirm begins; B backs out. Touch: tap the tabs, the arrows, the swatches and
## Confirm; drag the hero to turn them round.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const Townfolk = preload("res://scripts/gfx/townfolk.gd")
const Wardrobe = preload("res://scripts/data/wardrobe_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const HomeDecor = preload("res://scripts/gfx/home_decor.gd")
const SoftArrow = preload("res://scripts/ui/soft_arrow.gd")

## ten names for each body, the first the one it starts with
const NAMES := {
	"male": ["Andrew", "Ben", "Fritzy", "Sam", "Leo", "Max", "Kai", "Finn", "Theo", "Jack"],
	"female": ["Regan", "Tessa", "Christina", "Mia", "Lily", "Ava", "Nora", "Ivy", "Zoe", "Clara"],
}
const BODIES := ["male", "female"]
const BODY_NAMES := {"male": "Male", "female": "Female"}
## the tabs and the rows on each (at most four, so every tab fits without scrolling)
const TABS := [
	{"name": "You", "rows": ["name", "body", "skin"]},
	{"name": "Face", "rows": ["hairdo", "eyes", "hat", "glasses"]},
	{"name": "Torso", "rows": ["shirt", "pack"]},
	{"name": "Legs", "rows": ["pants", "shoes"]},
]
const ROW_NAMES := {"name": "Name", "body": "Body", "skin": "Skin", "hairdo": "Hair", "eyes": "Eyes", "hat": "Hat",
	"glasses": "Glasses", "shirt": "Shirt", "pack": "Pack", "pants": "Pants", "shoes": "Shoes"}
## The rows with a colour: the look's key for it and the dyes it picks from.
const DYES := {
	"skin": ["skin", Wardrobe.SKIN], "hairdo": ["hair", Wardrobe.HAIR], "eyes": ["eyes", Wardrobe.EYES],
	"hat": ["hat", Wardrobe.CLOTH], "glasses": ["glasses_colour", Wardrobe.CLOTH], "shirt": ["top", Wardrobe.CLOTH],
	"pack": ["pack_colour", Wardrobe.PACK], "pants": ["trousers", Wardrobe.CLOTH], "shoes": ["shoes", Wardrobe.CLOTH],
}
## The rows that only take a colour: their arrows step through it, their swatch opens the grid.
const COLOUR_ONLY := ["skin", "eyes", "pack"]
## The wardrobe kind each piece row picks from, and the look's key for it.
const PIECES := {"shirt": "shirt", "pants": "pants", "shoes": "shoes", "hat": "hat", "glasses": "glasses"}
## Hats and glasses can be none (index -1).
const OPTIONAL := ["hat", "glasses"]
## each body's skin to begin with
const DEFAULT_SKIN := 1
## the width of a row's name, and of the name in a stepped row
const LABEL_W := 150.0
const VALUE_W := 270.0
## on a touch screen, how far up from the bottom Start and Pause reach: Confirm stands clear above them
const PAD_CLEAR := 72.0
## Where the hero stands in the bedroom (a tile), and the mirror beside and behind them (metres from the hero, and
## its size); the camera's aim, off to the hero's left so they stand on the left of the screen, clear of the menu.
const HERO_TILE := Vector2i(6, 3)
const MIRROR_AT := Vector3(-1.2, 0.0, -0.75)
const MIRROR_SIZE := Vector2(0.78, 1.62)
const MIRROR_LAYER := 1 << 19
const CAM_AIM := Vector3(0.85, 0.6, 0.0)
const CAM_BACK := Vector3(0.0, 0.85, 4.3)
const CAM_FOV := 37.0
## The stage room has no front wall (the camera looks in through it); the mirror faces that way, so it sees one put
## up on a layer only its camera draws (MIRROR_ONLY), in the room's own wallpaper.
const MIRROR_ONLY := 1 << 18
## the hero's turn towards the camera as they stand (radians, to their left), and how fast a drag turns them
const HERO_YAW := -0.4
const DRAG_TURN := 0.012

var pick := {"name": 0, "body": 0, "hairdo": Townfolk.HERO_HAIRDO["male"], "shirt": 0, "pants": 0, "shoes": 0,
	"hat": -1, "glasses": -1}
## the colours chosen, by the look's key
var dye := {}
## what was last picked for each body, so switching back keeps it
var _by_body := {}
## the open tab, and the row being chosen on it: "tab" (the tab strip), one of its rows, or "start" (Confirm)
var tab := 0
var row := "name"
var _rows := {}
var _row_labels := {}
## each stepped row's label (the name it shows), and each row's swatch (a button)
var _values := {}
var _swatches := {}
var _arrows: Array = []
var _body_buttons: Array = []
var _tabs: Array = []
var _pages: Array = []
var _start: Button
var _column: VBoxContainer
var _picker = null
var _t := 0.0
## the scene: the bedroom set, the hero and the mirror
var _svc: SubViewportContainer
var _vp: SubViewport
var _set: Node3D
var _rig: Node3D
var _turn: Node3D
var _cam: Camera3D
var _yaw := 0.0
var _drag := false
var _still := 0.0
var _mirror_cam: Camera3D
var _mirror_mat: ShaderMaterial


func _init() -> void:
	super()
	dim = 0.0
	for b in BODIES:
		var start: Dictionary = Wardrobe.START[b]
		_by_body[b] = {"name": 0, "hairdo": Townfolk.HERO_HAIRDO[b], "shirt": start["shirt_style"],
			"pants": start["pants_style"], "shoes": start["shoes_style"], "top": start["top"], "shoes_colour": start["shoes"]}
	var s: Dictionary = Wardrobe.START["male"]
	dye = {"skin": Wardrobe.SKIN[DEFAULT_SKIN], "hair": Wardrobe.HAIR[0], "eyes": Wardrobe.EYES[0],
		"top": s["top"], "trousers": s["trousers"], "shoes": s["shoes"], "hat": s["hat"],
		"glasses_colour": s["glasses_colour"], "pack_colour": Wardrobe.PACK[0]}


func _ready() -> void:
	_build_scene()
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 0)
	add_child(_column)
	# the tabs, floating just above the window
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 18)
	inset.add_child(strip)
	_column.add_child(inset)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]["name"]
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(132, UIKit.row_h() - 8.0)
		tb.add_theme_font_override("font", UIKit.font_head())
		tb.add_theme_font_size_override("font_size", UIKit.head_px(UIKit.HEAD_BIG if UIKit.touch_ui() else 26))
		tb.pressed.connect(func() -> void:
			_open_tab(i, true)
			_go("tab", false))
		strip.add_child(tb)
		_tabs.append(tb)
	var p := UIKit.panel()
	_column.add_child(p)
	var pages := Control.new()
	p.add_child(pages)
	var biggest := Vector2.ZERO
	for t in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		for id in t["rows"]:
			page.add_child(_row(id))
		pages.add_child(page)
		_pages.append(page)
		biggest = biggest.max(page.get_combined_minimum_size())
	# every tab's page as big as the biggest (four rows), so nothing moves when the tab changes
	pages.custom_minimum_size = biggest
	for page in _pages:
		page.size = biggest
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	_column.add_child(gap)
	# Confirm, in the gem's colour, under the window at its left (clear of A and B on a touch screen)
	_start = _button("Confirm", func() -> void: _finish(), Vector2(240, UIKit.row_h()))
	_start.add_theme_font_override("font", UIKit.font_head())
	_start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.add_child(_start)
	if not UI.is_touch():
		var hint := UIKit.label("Up / Down choose   Left / Right change   A: Colours", 16, UIKit.LIGHT)
		hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		hint.add_theme_constant_override("shadow_offset_y", 2)
		_column.add_child(hint)
	_open_tab(0, false)
	_layout.call_deferred()
	resized.connect(_layout)


## The menu on the right of the screen, inside the safe area; on a touch screen high enough that Confirm clears Start
## and Pause, and its right edge clear of A and B where it can be.
func _layout() -> void:
	if not is_inside_tree() or _column == null:
		return
	var safe := UIKit.safe_rect(self)
	var want := _column.get_combined_minimum_size()
	_column.size = want
	var x := safe.end.x - want.x - 24.0
	var reserve := maxf(PAD_CLEAR, UI.bottom_reserve()) if UI.is_touch() else UI.bottom_reserve()
	var y := clampf(safe.position.y + (safe.size.y - reserve - want.y) * 0.5, safe.position.y + 12.0,
		maxf(safe.position.y + 12.0, safe.end.y - reserve - want.y - 8.0))
	_column.position = Vector2(maxf(safe.position.x + 8.0, x), y)
	_frame_camera()


# ---------------------------------------------------------------- the rows
func _row(id: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	pc.custom_minimum_size.y = UIKit.row_h()
	_rows[id] = pc
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	# a tap anywhere on a row picks it
	pc.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_go(id, false))
	# the row's name, on a gem bar with white text while it's the row being chosen
	var tag := PanelContainer.new()
	tag.custom_minimum_size = Vector2(LABEL_W, UIKit.row_h() - 8.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(ROW_NAMES[id], UIKit.BODY_HUGE, UIKit.DIM)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(l)
	_row_labels[id] = l
	hb.add_child(tag)
	var tall := UIKit.row_h() - 8.0
	if id == "body":
		for i in BODIES.size():
			var b := _button(BODY_NAMES[BODIES[i]], func() -> void: _choose_body(i), Vector2((VALUE_W + 128.0 + 8.0) / 2.0, tall))
			hb.add_child(b)
			_body_buttons.append(b)
		return pc
	var lt := _button("◄", func() -> void: _change(id, -1), Vector2(64, tall))
	_arrows.append(lt)
	hb.add_child(lt)
	if id in COLOUR_ONLY:
		# the colour itself between the arrows; a tap opens the grid
		var sw := _swatch_button(id, Vector2(VALUE_W, tall))
		hb.add_child(sw)
	else:
		var nl := UIKit.label("", UIKit.BODY_HUGE, UIKit.INK)
		nl.custom_minimum_size.x = VALUE_W
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(nl)
		_values[id] = nl
	var rt := _button("►", func() -> void: _change(id, 1), Vector2(64, tall))
	_arrows.append(rt)
	hb.add_child(rt)
	if DYES.has(id) and not id in COLOUR_ONLY:
		hb.add_child(_swatch_button(id, Vector2(tall * 1.2, tall)))
	elif not DYES.has(id):
		# (the name: a blank where the swatch would be, so the arrows line up down the page)
		var spacer := Control.new()
		spacer.custom_minimum_size.x = tall * 1.2
		hb.add_child(spacer)
	return pc


## A row's colour: a button showing it, which opens the grid of colours.
func _swatch_button(id: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		_go(id, false)
		_open_colours(id))
	_swatches[id] = b
	return b


func _button(text: String, on: Callable, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	if text in ["◄", "►"]:
		# the game's soft arrow (soft_arrow.gd) rather than the pointed glyph
		b.text = ""
		var glyph: Control = SoftArrow.make(Vector2.LEFT if text == "◄" else Vector2.RIGHT, UIKit.LIGHT)
		glyph.fill = 0.42
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(glyph)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UIKit.font_body())
	b.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BODY_HUGE))
	b.pressed.connect(on)
	return b


## A button's look: the gem when lit (an arrow is always lit), else a plain well with dim text.
static func _paint(b: Button, lit: bool, ring := false) -> void:
	var sb := UIKit.chip(UIKit.ACCENT if lit else UIKit.WELL, UIKit.BORDER if lit else UIKit.BORDER_INNER, 12.0, Vector4(10, 2, 10, 2), 3.0 if ring else 2.0)
	sb.ring = UIKit.INK if ring else Color(0, 0, 0, 0)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, UIKit.LIGHT if lit else UIKit.DIM)


# ---------------------------------------------------------------- choosing
## The rows the keys step through on the open tab: the tabs, its rows, Confirm.
func _nav() -> Array:
	return ["tab"] + TABS[tab]["rows"] + ["start"]


func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
		Sfx.play("back")
		close(null)
	elif ev.is_action_pressed("ui_up", true):
		_step(-1)
	elif ev.is_action_pressed("ui_down", true):
		_step(1)
	elif ev.is_action_pressed("ui_left", true):
		_change(row, -1)
	elif ev.is_action_pressed("ui_right", true):
		_change(row, 1)
	elif ev.is_action_pressed("ui_accept") and not ev.is_echo():
		match row:
			"start":
				_finish()
			"tab":
				_step(1)
			_:
				if DYES.has(row) and _dyeable(row):
					_open_colours(row)
					return
				# on to the next row; from a tab's last row, on to the next tab
				var rows: Array = TABS[tab]["rows"]
				if row == rows.back() and tab < TABS.size() - 1:
					_open_tab(tab + 1, true)
					_go(TABS[tab]["rows"][0], false)
				else:
					_step(1)


## Up or down a row (round from Confirm to the tabs).
func _step(d: int) -> void:
	var nav := _nav()
	_go(nav[posmod(nav.find(row) + d, nav.size())])


func _go(r: String, sound := true) -> void:
	if r == row:
		return
	row = r
	if sound:
		Sfx.play("blip")
	_show()


## Opens a tab (tapped, or left and right on the tab strip), keeping the tab strip chosen if it was.
func _open_tab(i: int, sound := true) -> void:
	i = posmod(i, TABS.size())
	if i != tab and sound:
		Sfx.play("page")
	tab = i
	for k in _pages.size():
		(_pages[k] as Control).visible = k == tab
	if row != "tab" and row != "start" and not (TABS[tab]["rows"] as Array).has(row):
		row = "tab"
	_show()


## Opens the tab a row is on (a row chosen from outside: a test, say).
func _reveal(id: String) -> void:
	if not (TABS[tab]["rows"] as Array).has(id):
		for k in TABS.size():
			if (TABS[k]["rows"] as Array).has(id):
				_open_tab(k, false)


## One step along a row (left or right).
func _change(id: String, d: int) -> void:
	_go(id, false)
	match id:
		"tab":
			_open_tab(tab + d)
		"start":
			pass
		"body":
			_choose_body(posmod(pick["body"] + d, BODIES.size()))
		"name":
			pick["name"] = posmod(pick["name"] + d, _names().size())
			Sfx.play("blip")
			# (some names are a little shorter: see GameState.SHORT_HEROES)
			_dress()
		_:
			if id in COLOUR_ONLY:
				var key: String = DYES[id][0]
				var pal: Array = DYES[id][1]
				_set_dye(key, pal[posmod(maxi(pal.find(dye[key]), 0) + d, pal.size())])
				Sfx.play("blip")
			else:
				_choose(id, _wrap(id, pick[id] + d))


## A style's index, wrapped round its list (hats and glasses through none, -1).
func _wrap(id: String, i: int) -> int:
	var n := _styles(id).size()
	if id in OPTIONAL:
		return posmod(i + 1, n + 1) - 1
	return posmod(i, n)


## The styles a row steps through: the names, hairdos or wardrobe pieces.
func _styles(id: String) -> Array:
	match id:
		"name":
			return _names()
		"hairdo":
			return Townfolk.HAIRDOS.map(func(h: Array) -> String: return h[1])
	return Wardrobe.pieces(PIECES[id], _body()).map(func(p: Array) -> String: return p[0])


## Picks a style on a row (a hairdo, a shirt, a hat...).
func _choose(id: String, i: int) -> void:
	_reveal(id)
	_go(id, false)
	if pick[id] == i:
		return
	Sfx.play("blip")
	pick[id] = i
	_dress()


## Picks the body: the name, hairdo and clothes go to what was last picked for it (to begin with, its own).
func _choose_body(i: int) -> void:
	_reveal("body")
	_go("body", false)
	if pick["body"] == i:
		return
	Sfx.play("blip")
	var was := _body()
	var now: String = BODIES[i]
	var mem: Dictionary = _by_body[was]
	for k in ["name", "hairdo", "shirt", "pants", "shoes"]:
		mem[k] = pick[k]
	mem["top"] = dye["top"]
	mem["shoes_colour"] = dye["shoes"]
	pick["body"] = i
	var back: Dictionary = _by_body[now]
	for k in ["name", "hairdo", "shirt", "pants", "shoes"]:
		pick[k] = back[k]
	# a top left in the last body's own colour takes this one's; one chosen stays
	if dye["top"] == Wardrobe.START[was]["top"]:
		dye["top"] = back["top"]
	if dye["shoes"] == Wardrobe.START[was]["shoes"]:
		dye["shoes"] = back["shoes_colour"]
	_dress()


## Whether a row's colour can be chosen now (a hat or glasses must be worn to dye them).
func _dyeable(id: String) -> bool:
	return not (id in OPTIONAL and int(pick[id]) < 0)


func _set_dye(key: String, hex: String) -> void:
	dye[key] = hex
	_dress()


## Opens the grid of colours over a row's swatch: moving through it dyes the hero as you go, A (or Confirm, or a
## second tap on the same colour) keeps it, B puts the old colour back.
func _open_colours(id: String) -> void:
	if not DYES.has(id) or not _dyeable(id) or _picker != null:
		return
	var key: String = DYES[id][0]
	var was: String = dye[key]
	Sfx.play("confirm")
	_picker = ColourPick.new()
	_picker.setup("%s colour" % ROW_NAMES[id], DYES[id][1], was, _column.get_global_rect(),
		func(hex: String) -> void: _set_dye(key, hex))
	UI.push(_picker)
	var got = await _picker.done
	_picker = null
	if got == null:
		_set_dye(key, was)
	else:
		_set_dye(key, String(got))


## The look chosen so far (see GameState.hero).
func look() -> Dictionary:
	var out := {"body": _body(), "person": Townfolk.HERO_OUTFITS[_body()][0], "hairdo": pick["hairdo"],
		"shirt_style": pick["shirt"], "pants_style": pick["pants"], "shoes_style": pick["shoes"],
		"hat_style": pick["hat"], "glasses_style": pick["glasses"]}
	out.merge(dye)
	return out


func _body() -> String:
	return BODIES[pick["body"]]


func _finish() -> void:
	Sfx.play("confirm")
	close({"name": _names()[pick["name"]], "look": look()})


## The names the chosen body picks from.
func _names() -> Array:
	return NAMES[_body()]


# ---------------------------------------------------------------- showing
func _show() -> void:
	if _start == null:
		return
	for id in _row_labels:
		var lit: bool = row == id
		var l: Label = _row_labels[id]
		l.add_theme_color_override("font_color", UIKit.LIGHT if lit else UIKit.INK)
		(l.get_parent() as PanelContainer).add_theme_stylebox_override("panel",
			UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 12.0, Vector4(12, 0, 8, 0)) if lit else _plain_tag())
	# the tabs: the open one the gem, the rest the window's off-white with dim text
	for k in _tabs.size():
		var open := k == tab
		var tb: Button = _tabs[k]
		var sb: StyleBox = UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 0.0, Vector4(6, -2, 6, -2)) if open \
			else UIKit.FrameBox.make("row", Color(0, 0, 0, 0), UIKit.FILL, false, Vector4(10, 0, 10, 0))
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			tb.add_theme_stylebox_override(st, sb)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			tb.add_theme_color_override(st, UIKit.LIGHT if open else UIKit.DIM)
		if not open:
			tb.modulate.a = 1.0
	for id in _values:
		var i: int = pick[id]
		var names := _styles(id)
		(_values[id] as Label).text = "None" if i < 0 else String(names[clampi(i, 0, names.size() - 1)])
	(_values["name"] as Label).text = _names()[pick["name"]]
	for a in _arrows:
		_paint(a, true)
	for i in _body_buttons.size():
		_paint(_body_buttons[i], pick["body"] == i)
	for id in _swatches:
		var b: Button = _swatches[id]
		var on := _dyeable(id)
		b.disabled = not on
		var col := Color(dye[DYES[id][0]]) if on else UIKit.WELL
		var sb: StyleBox = UIKit.chip(col, Color(0, 0, 0, 0.45) if on else UIKit.BORDER_INNER, 10.0, Vector4.ZERO, 2.0)
		sb.ring = UIKit.INK if row == id and on else Color(0, 0, 0, 0.12)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
	# Confirm is always the gem, ringed while it's the row being chosen
	_paint(_start, true, row == "start")


var _plain: StyleBox


## A row name's box while it isn't chosen: nothing to see, the text where the gem bar's would be.
func _plain_tag() -> StyleBox:
	if _plain == null:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 16
		sb.content_margin_right = 12
		_plain = sb
	return _plain


func _process(delta: float) -> void:
	_t += delta
	# the open tab's opacity pulses slowly while the tab strip is the row being chosen (as in the Start book)
	if tab < _tabs.size():
		(_tabs[tab] as Control).modulate.a = 0.72 + 0.28 * cos(_t * 3.0) if row == "tab" else 1.0
	if _drag:
		_still = 0.0
	else:
		_still += delta
		# let go, the hero eases back to face the camera and the mirror
		if _still > 1.2:
			_yaw = lerp_angle(_yaw, 0.0, minf(1.0, delta * 2.0))
	if _turn:
		_turn.rotation.y = HERO_YAW + _yaw
	if is_instance_valid(_rig):
		VPer.animate(_rig, 0.0, 0.0, _t)


# ---------------------------------------------------------------- the bedroom and the mirror
## The scene behind the menu: the hero's own bedroom, built as a set in a viewport of its own the size of the
## screen, the hero in it beside the mirror (dressed again as the choices change).
func _build_scene() -> void:
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_svc.mouse_filter = Control.MOUSE_FILTER_STOP
	_svc.gui_input.connect(_on_scene_input)
	add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	# (whatever is behind shows through until the room is built)
	_vp.transparent_bg = true
	_svc.add_child(_vp)
	_turn = Node3D.new()
	_turn.name = "Hero"
	_vp.add_child(_turn)
	_rig = VPer.build(_hero_look())
	VPer.face(_rig, Vector2i(0, 1))
	_turn.add_child(_rig)
	_load_room()


func _load_room() -> void:
	if GameState.main == null or not GameState.main.has_method("build_set"):
		return
	var home := MapLoader.interior_of("caccoon", "home")
	var id := MapLoader.wake_room(home) if home != "" else ""
	if id == "":
		return
	var stage := Node3D.new()
	stage.name = "Bedroom"
	_vp.add_child(stage)
	_set = await GameState.main.build_set(id, stage)
	if not is_inside_tree() or not is_instance_valid(_set):
		return
	if is_instance_valid(_set.player):
		_set.player.visible = false
	_set.cam_free = true
	_cam = _set.cam
	_cam.cull_mask &= ~MIRROR_ONLY
	_turn.position = _set.tile_pos(HERO_TILE)
	_build_mirror()
	_frame_camera()


## The camera in front of the hero, aimed off to their left so they stand left of the menu; it follows the screen's
## shape (a wider screen shows more of the room beside them).
func _frame_camera() -> void:
	if not is_instance_valid(_cam) or _turn == null:
		return
	_cam.fov = CAM_FOV
	var aim := _turn.position + CAM_AIM
	# on a wide screen the menu takes less of it: the hero moves a little right with it
	var aspect := size.x / maxf(size.y, 1.0)
	aim.x += clampf((aspect - 16.0 / 9.0) * -0.45, -0.5, 0.0)
	var at := aim + CAM_BACK
	_cam.global_transform = Transform3D(Basis.looking_at(aim - at, Vector3.UP), at)
	_aim_mirror()


## A standing mirror behind the hero and to their right (the screen's left), turned towards the camera: a chunky
## wooden frame on two stout feet, its glass showing the room from where the camera's reflection would stand (a
## second camera on the far side of the glass, its picture projected back onto it), so it shows the hero's back.
func _build_mirror() -> void:
	var holder := Node3D.new()
	holder.name = "Mirror"
	holder.position = _turn.position + MIRROR_AT
	_vp.add_child(holder)
	var frame := MeshInstance3D.new()
	frame.mesh = HomeDecor.frame_mesh(MIRROR_SIZE.x, MIRROR_SIZE.y, false)
	var wood: Material = HomeDecor.atlas_material("jewel_pop")
	frame.set_surface_override_material(0, wood)
	frame.position.y = 0.12 + MIRROR_SIZE.y / 2.0
	frame.layers = MIRROR_LAYER
	holder.add_child(frame)
	# its feet: two chubby blocks it stands on, in the frame's wood
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		HomeDecor._box(st, Vector3(side * (MIRROR_SIZE.x / 2.0 - 0.08), 0.07, 0.0), Vector3(0.16, 0.14, 0.42), Color(0, 0, 1, 0), HomeDecor.WOOD_CELL)
	var feet := MeshInstance3D.new()
	feet.mesh = st.commit()
	feet.material_override = wood
	feet.layers = MIRROR_LAYER
	holder.add_child(feet)
	# the glass (the frame's canvas, surface 1)
	_mirror_mat = ShaderMaterial.new()
	_mirror_mat.shader = _glass_shader()
	frame.set_surface_override_material(1, _mirror_mat)
	var rvp := SubViewport.new()
	rvp.size = Vector2i(320, 640)
	rvp.world_3d = _vp.find_world_3d()
	rvp.msaa_3d = Viewport.MSAA_2X
	rvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(rvp)
	_mirror_cam = Camera3D.new()
	_mirror_cam.cull_mask = 0xFFFFF & ~MIRROR_LAYER | MIRROR_ONLY
	rvp.add_child(_mirror_cam)
	_mirror_cam.current = true
	_mirror_mat.set_shader_parameter("refl", rvp.get_texture())
	_front_wall()
	_aim_mirror()


## The room's missing front wall, for the mirror alone (MIRROR_ONLY): its wallpaper from the hero's tile up to the
## ceiling's height, along the whole front of the room.
func _front_wall() -> void:
	var w: int = _set.map["w"]
	var h: int = _set.map["h"]
	var wall := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, 3.4)
	wall.mesh = qm
	if _set.room_walls != null:
		wall.material_override = _set.room_walls.wall_mat(_set.room_walls.zone(HERO_TILE.x, HERO_TILE.y))
	# facing back into the room (a quad faces +z: turned round)
	wall.position = Vector3(w / 2.0, 1.7, h - 0.5)
	wall.rotation.y = PI
	wall.layers = MIRROR_ONLY
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(wall)


## Turns the mirror to reflect the hero to the camera and puts its camera where the camera's reflection
## in the glass stands.
func _aim_mirror() -> void:
	if not is_instance_valid(_mirror_cam) or not is_instance_valid(_cam):
		return
	var holder: Node3D = _mirror_cam.get_parent().get_parent()
	var cam_at := _cam.global_position
	# turned halfway between the camera and the hero, so the camera sees the hero in it
	var to_cam := ((cam_at - holder.position) * Vector3(1, 0, 1)).normalized()
	var to_hero := ((_turn.position - holder.position) * Vector3(1, 0, 1)).normalized()
	var face := to_cam + to_hero
	holder.rotation.y = atan2(face.x, face.z)
	var n := holder.global_basis.z.normalized()
	var mid := holder.global_position + Vector3(0, 0.12 + MIRROR_SIZE.y / 2.0, 0)
	var dist := (cam_at - mid).dot(n)
	var refl_at := cam_at - n * 2.0 * dist
	_mirror_cam.global_transform = Transform3D(Basis.looking_at(mid - refl_at, Vector3.UP), refl_at)
	# wide enough to take in the whole glass, and nothing nearer than it (the wall behind the mirror)
	var half := Vector2(MIRROR_SIZE.x, MIRROR_SIZE.y) * 0.5
	var nearest := INF
	var widest := 0.0
	var view := _mirror_cam.global_transform.affine_inverse()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner: Vector3 = mid + holder.global_basis.x * half.x * c.x + Vector3.UP * half.y * c.y
		var local: Vector3 = view * corner
		nearest = minf(nearest, -local.z)
		widest = maxf(widest, maxf(absf(local.y), absf(local.x) * 0.5) / maxf(-local.z, 0.01))
	_mirror_cam.near = maxf(0.05, nearest - 0.08)
	_mirror_cam.fov = rad_to_deg(atan(widest) * 2.0) * 1.08
	_mirror_mat.set_shader_parameter("refl_vp", _mirror_cam.get_camera_projection() * Projection(view))


static var _glass: Shader


## The mirror's glass: the second camera's picture, laid back onto the glass by projecting each point of it into that
## camera's view, with a faint cool sheen.
static func _glass_shader() -> Shader:
	if _glass == null:
		_glass = Shader.new()
		_glass.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D refl : source_color, filter_linear_mipmap_anisotropic;
uniform mat4 refl_vp;
varying vec3 world_at;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 c = refl_vp * vec4(world_at, 1.0);
	vec2 uv = c.xy / c.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	vec3 col = texture(refl, uv).rgb;
	// a cool sheen, brighter towards the top
	col = mix(col, vec3(0.86, 0.92, 0.98), 0.03 + 0.05 * UV.y);
	ALBEDO = col;
}
"""
	return _glass


func _dress() -> void:
	if is_instance_valid(_rig):
		VPer.dress(_rig, _hero_look())
	_show()


func _hero_look() -> Dictionary:
	var l := {"face": "hero"}
	l.merge(look())
	var nm: String = _names()[pick["name"]]
	if GameState.SHORT_HEROES.has(nm):
		l["scale"] = GameState.SHORT_HEROES[nm]
	return l


## Dragging across the room turns the hero round (on the left, where they stand; the menu takes its own taps).
func _on_scene_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed and not UI.touch_blocks(ev.position)
		_still = 0.0
	elif ev is InputEventMouseMotion and _drag:
		_yaw += ev.relative.x * DRAG_TURN


func _exit_tree() -> void:
	if is_instance_valid(_set) and _set.has_method("keep_shaders"):
		_set.keep_shaders()


# ---------------------------------------------------------------- the colours
## The grid of colours over a row's swatch: big swatches (a fingertip's size on a touch screen) in a window, the one
## chosen ringed. Up, down, left and right move through it (dyeing the hero as they go, through `on_pick`); A or
## Confirm keeps it, and so does a second tap on the same colour; B gives back null.
class ColourPick extends "res://scripts/ui/modal.gd":
	const Kit = preload("res://scripts/ui/ui_kit.gd")
	const COLS := 4
	var title := ""
	var palette: Array = []
	var at := 0
	var near := Rect2()
	var on_pick: Callable
	var chips: Array = []
	var confirm: Button
	var box: PanelContainer

	func setup(heading: String, colours: Array, now: String, over: Rect2, pick_cb: Callable) -> void:
		title = heading
		palette = colours
		at = maxi(colours.find(now), 0)
		near = over
		on_pick = pick_cb

	func _ready() -> void:
		dim = 0.25
		box = Kit.panel()
		add_child(box)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		box.add_child(vb)
		vb.add_child(Kit.header(title))
		var grid := GridContainer.new()
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		vb.add_child(grid)
		var side := Kit.MIN_TOUCH_HEIGHT if Kit.touch_ui() else Kit.MIN_BUTTON_HEIGHT + 8.0
		for i in palette.size():
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(side, side)
			b.pressed.connect(_tapped.bind(i))
			grid.add_child(b)
			chips.append(b)
		confirm = Button.new()
		confirm.text = "Confirm"
		confirm.focus_mode = Control.FOCUS_NONE
		confirm.custom_minimum_size.y = Kit.row_h()
		confirm.add_theme_font_override("font", Kit.font_head())
		confirm.add_theme_font_size_override("font_size", Kit.body_px(Kit.BODY_HUGE))
		var sb := Kit.chip(Kit.ACCENT, Kit.BORDER, 12.0)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			confirm.add_theme_stylebox_override(st, sb)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			confirm.add_theme_color_override(st, Kit.LIGHT)
		confirm.pressed.connect(func() -> void: _keep())
		vb.add_child(confirm)
		_paint()
		_place.call_deferred()

	## Over the menu (`near`: its window), as near its middle as fits inside the safe area, clear of the key guide
	## and of the touch pad (moved left until no corner or edge of it is under A, B, Start or Pause).
	func _place() -> void:
		var safe := Kit.safe_rect(self)
		var want := box.get_combined_minimum_size()
		box.size = want
		var reserve := UI.bottom_reserve()
		var x := clampf(near.get_center().x - want.x / 2.0, safe.position.x + 8.0, safe.end.x - want.x - 8.0)
		var y := clampf(near.get_center().y - want.y / 2.0, safe.position.y + 8.0, maxf(safe.position.y + 8.0, safe.end.y - reserve - want.y - 8.0))
		while x > safe.position.x + 8.0 and _under_pad(Rect2(Vector2(x, y), want)):
			x -= 16.0
		box.position = Vector2(x, y)

	func _under_pad(r: Rect2) -> bool:
		for f in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(1, 0.75)]:
			if UI.touch_blocks(r.position + r.size * f):
				return true
		return false

	func _paint() -> void:
		for i in chips.size():
			var on := i == at
			var sb: StyleBox = Kit.chip(Color(palette[i]), Kit.LIGHT if on else Color(0, 0, 0, 0.45), 10.0, Vector4.ZERO, 4.0 if on else 2.0)
			sb.ring = Kit.INK if on else Color(0, 0, 0, 0.12)
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				(chips[i] as Button).add_theme_stylebox_override(st, sb)
			(chips[i] as Button).scale = Vector2.ONE * (1.1 if on else 1.0)
			(chips[i] as Button).pivot_offset = (chips[i] as Button).custom_minimum_size / 2.0

	func _move(d: int) -> void:
		at = posmod(at + d, palette.size())
		Sfx.play("blip")
		_paint()
		on_pick.call(String(palette[at]))

	func _tapped(i: int) -> void:
		if i == at:
			_keep()
			return
		at = i
		Sfx.play("blip")
		_paint()
		on_pick.call(String(palette[at]))

	func _keep() -> void:
		Sfx.play("confirm")
		close(String(palette[at]))

	func on_input(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
			Sfx.play("back")
			close(null)
		elif ev.is_action_pressed("ui_accept") and not ev.is_echo():
			_keep()
		elif ev.is_action_pressed("ui_left", true):
			_move(-1)
		elif ev.is_action_pressed("ui_right", true):
			_move(1)
		elif ev.is_action_pressed("ui_up", true):
			_move(-COLS)
		elif ev.is_action_pressed("ui_down", true):
			_move(COLS)
