extends "res://scripts/ui/modal.gd"
## The character creator, before a new game. The hero stands in their own bedroom (the real room, built as a set: see
## main.gd build_set) beside a standing mirror that shows their other side, on the left of the screen; the choices
## are on the right, on four tabs that float just above the window, together as wide as it (Self, Face, Torso, Legs), none
## with more rows than fit, so nothing scrolls. Clothes, hats and glasses come from the wardrobe
## (scripts/data/wardrobe_db.gd), each piece named, and each dyed on its own row: the row's swatch opens a grid of
## big colours over it (ColourPick) to choose from and confirm. Closes with {"name", "look"} (the look for
## GameState.hero), or null when backed out of.
## Keys: up and down pick a row (the tabs above the first), left and right change it (on the tabs: switch tab), A on
## a color row opens its colors, on another row goes on to the next (from a tab's last row on to the next
## tab); Start (Space, a controller's Start, the touch pad's Start) begins, as the small gem "[Start] Confirm" button hanging
## off the window's bottom right says; B backs out. Touch: tap the tabs, the rows' arrows, the color rows and that
## button; drag the hero to turn them round.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const Townfolk = preload("res://scripts/gfx/townfolk.gd")
const Wardrobe = preload("res://scripts/data/wardrobe_db.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const HomeDecor = preload("res://scripts/gfx/home_decor.gd")
const SoftArrow = preload("res://scripts/ui/soft_arrow.gd")

## Names for each gender, the first the one it starts with.
const NAMES := {
	"male": ["Andrew", "Ben", "Fritzy", "Sam", "Leo", "Max", "Kai", "Finn", "Theo", "Jack"],
	"female": ["Regan", "Tessa", "Christina", "Tra", "Mia", "Lily", "Ava", "Nora", "Ivy", "Zoe", "Clara"],
	"non_binary": ["Moss", "Rowan", "River", "Sage", "Ash", "Quinn", "Avery", "Robin", "Ember", "Sky"],
}
const GENDERS := ["male", "female", "non_binary"]
const GENDER_NAMES := {"male": "Male", "female": "Female", "non_binary": "Non-Binary"}
## the bodies the kit dresses; gender picks one (Male and Female their own, Non-Binary keeps the one before)
const BODIES := ["male", "female"]
## the tabs and the rows on each (at most four, so every tab fits without scrolling); "heads": a small header (bold
## capitals over a line) before a row, naming the thing its Type and Color rows below are for
const TABS := [
	{"name": "Self", "rows": ["gender", "name", "skin"], "heads": {}, "look_at": "body"},
	{"name": "Hair", "rows": ["hairdo", "hair_color", "hat", "hat_color"], "heads": {"hairdo": "Hair", "hat": "Hat"},
		"look_at": "head"},
	{"name": "Face", "rows": ["eyes", "glasses", "glasses_color"], "heads": {"eyes": "Eyes", "glasses": "Glasses"},
		"look_at": "head"},
	{"name": "Torso", "rows": ["shirt", "shirt_color", "pack"], "heads": {"shirt": "Shirt", "pack": "Pack"},
		"look_at": "torso"},
	{"name": "Legs", "rows": ["pants", "pants_color", "shoes", "shoes_color"], "heads": {"pants": "Pants", "shoes": "Shoes"},
		"look_at": "legs"},
]
## Where the camera looks for each tab's part of the hero: its aim's height (metres) and how much nearer it comes
## (a share of the way in), a little closer than the whole body.
const LOOK_AT := {"body": [0.6, 0.0], "head": [1.15, 0.3], "torso": [0.85, 0.2], "legs": [0.35, 0.2]}
## how fast the camera eases to a tab's part (a share of the way a second)
const LOOK_EASE := 4.0
const ROW_NAMES := {"name": "Name", "gender": "Gender", "skin": "Skin", "eyes": "Color", "hairdo": "Type",
	"hair_color": "Color", "hat": "Type", "hat_color": "Color", "glasses": "Type", "glasses_color": "Color",
	"shirt": "Type", "shirt_color": "Color", "pack": "Color", "pants": "Type", "pants_color": "Color", "shoes": "Type",
	"shoes_color": "Color"}
## The color rows: the look's key for the color, its set of dyes (Wardrobe.dyes), the piece it dyes (none worn,
## nothing to dye), and the color grid's title.
const COLORS := {
	"skin": ["skin", "SKIN", "", "Skin color"], "eyes": ["eyes", "EYES", "", "Eye color"],
	"hair_color": ["hair", "HAIR", "", "Hair color"], "hat_color": ["hat", "CLOTH", "hat", "Hat color"],
	"glasses_color": ["glasses_colour", "CLOTH", "glasses", "Glasses color"],
	"shirt_color": ["top", "CLOTH", "", "Shirt color"], "pack": ["pack_colour", "PACK", "", "Pack color"],
	"pants_color": ["trousers", "CLOTH", "", "Pants color"], "shoes_color": ["shoes", "CLOTH", "", "Shoes color"],
}
## The wardrobe kind each piece row picks from.
const PIECES := {"shirt": "shirt", "pants": "pants", "shoes": "shoes", "hat": "hat", "glasses": "glasses"}
## Hats and glasses can be none (index -1).
const OPTIONAL := ["hat", "glasses"]
## each body's skin to begin with
const DEFAULT_SKIN := 1
## the window's rows: at least this wide, the value (its arrows, swatch and name) on the right taking this much
const ROW_W := 640.0
const VALUE_W := 330.0
## how much of each end of the value a tap counts as its arrow
const ARROW_HIT := 70.0
## the gap between the tabs, and between them and the window below
const TAB_SEP := 8
const TAB_GAP := 10.0
## on a touch screen, how far up from the bottom Start and Pause reach: the menu stands clear above them
const PAD_CLEAR := 72.0
## how far across the screen the menu may move left (to clear A and B) at most
const MENU_LEAST := 0.33
## Where the hero stands in the bedroom (a tile), and the mirror beside and behind them (metres from the hero, and
## its size); the camera's aim, off to the hero's left so they stand on the left of the screen, clear of the menu.
const HERO_TILE := Vector2i(6, 3)
const MIRROR_AT := Vector3(-1.2, 0.0, -0.75)
const MIRROR_SIZE := Vector2(0.78, 1.62)
const MIRROR_LAYER := 1 << 19
const CAM_AIM := Vector3(0.0, 0.6, 0.0)
## the middle of the hero and the mirror, across the screen (metres from the hero)
const GROUP_X := -0.55
const CAM_BACK := Vector3(0.0, 0.85, 4.3)
const CAM_FOV := 37.0
## The stage room has no front wall (the camera looks in through it); the mirror faces that way, so it sees one put
## up on a layer only its camera draws (MIRROR_ONLY), in the room's own wallpaper.
const MIRROR_ONLY := 1 << 18
## the hero's turn towards the camera as they stand (radians, to their left), and how fast a drag turns them
const HERO_YAW := -0.4
const DRAG_TURN := 0.012

var pick := {"name": 0, "gender": 0, "body": 0, "hairdo": Townfolk.HERO_HAIRDO["male"], "shirt": 0, "pants": 0, "shoes": 0,
	"hat": -1, "glasses": -1}
## the colors chosen, by the look's key
var dye := {}
## what was last picked for each body, so switching back keeps it
var _by_body := {}
## The last name chosen for each gender.
var _by_gender := {"male": 0, "female": 0, "non_binary": 0}
## the open tab, and the row being chosen on it: "tab" (the tab strip) or one of its rows
var tab := 0
var row := "gender"
## each row (a button the width of the window, its name on the left), and on its right: the value's name, a color
## row's swatch, and the arrows either side
var _rows := {}
var _heads: Array = []
var _values := {}
var _swatches := {}
var _arrows := {}
var _tabs: Array = []
var _pages: Array = []
var _start: Button
var _start_hit: Control
var _hint: Label
var _panel: Control
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
## the camera's aim height and how far in it has come (LOOK_AT), easing towards the open tab's
var _look := Vector2(0.6, 0.0)
var _mirror_mat: ShaderMaterial


func _init() -> void:
	super()
	dim = 0.0
	for b in BODIES:
		var start: Dictionary = Wardrobe.START[b]
		_by_body[b] = {"hairdo": Townfolk.HERO_HAIRDO[b], "shirt": start["shirt_style"],
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
	# the tabs, floating just above the window with a gap between: together as wide as it, each an equal share
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", TAB_SEP)
	_column.add_child(strip)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]["name"]
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(0, UIKit.row_h() - 8.0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_override("font", UIKit.font_head())
		tb.add_theme_font_size_override("font_size", UIKit.head_px(28 if UIKit.touch_ui() else 24))
		tb.pressed.connect(func() -> void:
			_open_tab(i, true)
			_go("tab", false))
		strip.add_child(tb)
		_tabs.append(tb)
	var tab_gap := Control.new()
	tab_gap.custom_minimum_size.y = TAB_GAP
	_column.add_child(tab_gap)
	var p := UIKit.panel()
	_column.add_child(p)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	p.add_child(inside)
	var pages := Control.new()
	inside.add_child(pages)
	var biggest := Vector2.ZERO
	for t in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		for id in t["rows"]:
			if (t["heads"] as Dictionary).has(id):
				page.add_child(_head(t["heads"][id]))
			page.add_child(_row(id))
		pages.add_child(page)
		_pages.append(page)
		biggest = biggest.max(page.get_combined_minimum_size())
	# every tab's page as big as the biggest (four rows), so nothing moves when the tab changes
	pages.custom_minimum_size = biggest
	for page in _pages:
		page.size = biggest
	_panel = p
	# Start confirms: a small gem button hanging off the window's bottom right corner says so, like "B: Cancel" under
	# a menu (edge_button.gd), the Start button's own prompt before the word (a tap on it does the same)
	_start_hit = load("res://scripts/ui/edge_button.gd").new().setup("Confirm", false, start_icon())
	_start = _start_hit.button
	_start_hit.pressed.connect(func() -> void: _finish())
	add_child(_start_hit)
	var hang := Control.new()
	hang.custom_minimum_size.y = _start_hit.overhang() + 6.0
	_column.add_child(hang)
	if not UI.is_touch():
		var hint := UIKit.label("Up / Down choose   Left / Right change   A: Color   Space: Start", 16, UIKit.LIGHT)
		_hint = hint
		hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		hint.add_theme_constant_override("shadow_offset_y", 2)
		_column.add_child(hint)
	_open_tab(0, false)
	_layout.call_deferred()
	resized.connect(_layout)


## The menu on the right of the screen, inside the safe area; on a touch screen high enough to clear Start and Pause,
## and far enough left that its Start button clears A and B.
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
	# the Start button (under the window's bottom right) clear of A and B: the menu moves left until it is
	var bs: Vector2 = _start_hit.button_size()
	var hint_h := _hint.get_combined_minimum_size().y if _hint != null else 0.0
	# (the window's bottom right corner: the last row's right arrow and the Start button hanging under it)
	var bottom: float = want.y - hint_h - _start_hit.overhang() + bs.y * (1.0 - _start_hit.OVERLAP) + 8.0
	var left: float = minf(want.x - _start_hit.INSET - bs.x - 12.0, want.x - ARROW_HIT - 24.0)
	var top: float = bottom - bs.y - 16.0 - UIKit.row_h()
	var box := Rect2(Vector2(left, top), Vector2(want.x - left, bottom - top))
	# (but never past the middle of the screen, over the hero and the d-pad: on a narrow touch screen the box may meet
	# A's edge, and the pad's own Start does the same)
	var least := maxf(safe.position.x + 8.0, safe.position.x + safe.size.x * MENU_LEAST)
	while x > least and _under_pad(Rect2(Vector2(x, y) + box.position, box.size)):
		x -= 8.0
	_column.position = Vector2(maxf(least, x) if x < safe.end.x - want.x - 24.0 else x, y)
	_place_start.call_deferred()
	_frame_camera()


## The Start button under the window's bottom right corner.
func _place_start() -> void:
	if _start_hit != null and _panel != null:
		_start_hit.place_under(_panel.get_global_rect())


## The Start button's prompt for the input in use (edge_button.gd prompt).
static func start_icon() -> Texture2D:
	return load("res://scripts/ui/edge_button.gd").prompt("start")


## Whether any corner or edge of a rectangle lies under the touch pad's buttons (or their no-tap zones).
static func _under_pad(r: Rect2) -> bool:
	for f in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0.5, 0.5)]:
		if UI.touch_blocks(r.position + r.size * f):
			return true
	return false


# ---------------------------------------------------------------- the rows
## A group's header: its name in small bold capitals over a line, the Type and Color rows under it.
func _head(text: String) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_top", 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, 20, UIKit.HEAD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(l)
	vb.add_child(pad)
	var line := UIKit.divider(0.0, "none")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(line)
	_heads.append(vb)
	return vb


## A row as the Settings page has them: the width of the window, its name on the left and its value on the right
## between the game's soft arrows (a color row's value is a swatch of the color and its name); the chosen row is a
## gem bar with white text. A tap on an arrow steps it that way; a tap elsewhere on a color row opens its colors, on
## any other row steps it on.
func _row(id: String) -> Control:
	var b := Button.new()
	b.text = ROW_NAMES[id]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ROW_W, UIKit.row_h())
	b.add_theme_font_override("font", UIKit.font_body())
	b.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BODY_HUGE))
	b.gui_input.connect(_row_input.bind(id))
	_rows[id] = b
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	hb.offset_left = -VALUE_W - 12.0
	hb.offset_right = -12.0
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var arrows := []
	for d in [Vector2.LEFT, Vector2.RIGHT]:
		var a: Control = SoftArrow.make(d, UIKit.ACCENT, Vector2(28, 28))
		a.fill = 0.55
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrows.append(a)
	hb.add_child(arrows[0])
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(mid)
	if COLORS.has(id):
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(34, 34)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(sw)
		_swatches[id] = sw
	var v := UIKit.label("", UIKit.BODY_HUGE, UIKit.INK)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(v)
	_values[id] = v
	hb.add_child(arrows[1])
	_arrows[id] = arrows
	return b


## A tap (or click) on a row: at the value's left end steps back, at its right end steps on; on the rest of a color
## row opens its colors, on the rest of any other row steps on.
func _row_input(ev: InputEvent, id: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var b: Button = _rows[id]
	b.accept_event()
	_go(id, false)
	var x: float = ev.position.x
	var value_at := b.size.x - 12.0 - VALUE_W
	if x >= value_at and x < value_at + ARROW_HIT:
		_change(id, -1)
	elif x >= b.size.x - 12.0 - ARROW_HIT:
		_change(id, 1)
	elif COLORS.has(id):
		_open_colors(id)
	else:
		_change(id, 1)


## Where a row's arrow is on screen (side -1 the left one, 1 the right), for a tap on it.
func arrow_rect(id: String, side: int) -> Rect2:
	return (_arrows[id][0 if side < 0 else 1] as Control).get_global_rect()


# ---------------------------------------------------------------- choosing
## The rows the keys step through on the open tab: the tabs and its rows (Start confirms, from any of them).
func _nav() -> Array:
	return ["tab"] + TABS[tab]["rows"]


func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
		Sfx.play("back")
		close(null)
	elif ev.is_action_pressed("menu") and not ev.is_echo():
		_finish()
	elif ev.is_action_pressed("ui_up", true):
		_step(-1)
	elif ev.is_action_pressed("ui_down", true):
		_step(1)
	elif ev.is_action_pressed("ui_left", true):
		_change(row, -1)
	elif ev.is_action_pressed("ui_right", true):
		_change(row, 1)
	elif ev.is_action_pressed("ui_accept") and not ev.is_echo():
		if row == "tab":
			_step(1)
			return
		if COLORS.has(row) and _dyeable(row):
			_open_colors(row)
			return
		# on to the next row; from a tab's last row, on to the next tab
		var rows: Array = TABS[tab]["rows"]
		if row == rows.back() and tab < TABS.size() - 1:
			_open_tab(tab + 1, true)
			_go(TABS[tab]["rows"][0], false)
		else:
			_step(1)


## Up or down a row (round from the last to the tabs).
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
	if row != "tab" and not (TABS[tab]["rows"] as Array).has(row):
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
		"gender":
			_choose_gender(posmod(pick["gender"] + d, GENDERS.size()))
		"name":
			pick["name"] = posmod(pick["name"] + d, _names().size())
			Sfx.play("blip")
			# (some names change the hero's size: see GameState.HERO_SCALES)
			_dress()
		_:
			if COLORS.has(id):
				if not _dyeable(id):
					return
				var key: String = COLORS[id][0]
				var pal := Wardrobe.dyes(COLORS[id][1])
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


## Picks gender and restores its name; Male and Female wear their own body, Non-Binary keeps the one before.
func _choose_gender(i: int) -> void:
	_reveal("gender")
	_go("gender", false)
	if pick["gender"] == i:
		return
	Sfx.play("blip")
	_by_gender[_gender()] = pick["name"]
	pick["gender"] = i
	pick["name"] = _by_gender[_gender()]
	var b := BODIES.find(_gender())
	if b >= 0 and b != pick["body"]:
		_choose_body(b, false)
	else:
		_dress()


## Picks the body (through gender, or a test's --picks): the hairdo and clothes go to what was last picked for it (to
## begin with, its own).
func _choose_body(i: int, sound := true) -> void:
	if pick["body"] == i:
		return
	if sound:
		Sfx.play("blip")
	var was := _body()
	var now: String = BODIES[i]
	var mem: Dictionary = _by_body[was]
	for k in ["hairdo", "shirt", "pants", "shoes"]:
		mem[k] = pick[k]
	mem["top"] = dye["top"]
	mem["shoes_colour"] = dye["shoes"]
	pick["body"] = i
	var back: Dictionary = _by_body[now]
	for k in ["hairdo", "shirt", "pants", "shoes"]:
		pick[k] = back[k]
	# a top left in the last body's own color takes this one's; one chosen stays
	if dye["top"] == Wardrobe.START[was]["top"]:
		dye["top"] = back["top"]
	if dye["shoes"] == Wardrobe.START[was]["shoes"]:
		dye["shoes"] = back["shoes_colour"]
	_dress()


## Whether a color row can be chosen now (a hat or glasses must be worn to dye them).
func _dyeable(id: String) -> bool:
	if not COLORS.has(id):
		return false
	var piece: String = COLORS[id][2]
	return piece == "" or int(pick[piece]) >= 0


func _set_dye(key: String, hex: String) -> void:
	dye[key] = hex
	_dress()


## Opens the grid of colors over the menu: moving through it dyes the hero as you go, A (or Confirm, or a second tap
## on the same color) keeps it, B puts the old color back.
func _open_colors(id: String) -> void:
	if not _dyeable(id) or _picker != null:
		return
	_reveal(id)
	_go(id, false)
	var key: String = COLORS[id][0]
	var was: String = dye[key]
	Sfx.play("confirm")
	_picker = ColourPick.new()
	_picker.setup(COLORS[id][3], Wardrobe.dyes(COLORS[id][1]), was, _column.get_global_rect(),
		func(hex: String) -> void: _set_dye(key, hex))
	UI.push(_picker)
	# (the Start button hangs over the grid's corner otherwise: it steps aside while the grid is up)
	_start_hit.visible = false
	var got = await _picker.done
	_picker = null
	if is_instance_valid(_start_hit):
		_start_hit.visible = true
	if got == null:
		_set_dye(key, was)
	else:
		_set_dye(key, String(got))


## The look chosen so far (see GameState.hero).
func look() -> Dictionary:
	var out := {"gender": _gender(), "body": _body(), "person": Townfolk.HERO_OUTFITS[_body()][0], "hairdo": pick["hairdo"],
		"shirt_style": pick["shirt"], "pants_style": pick["pants"], "shoes_style": pick["shoes"],
		"hat_style": pick["hat"], "glasses_style": pick["glasses"]}
	out.merge(dye)
	return out


func _body() -> String:
	return BODIES[pick["body"]]


func _gender() -> String:
	return GENDERS[pick["gender"]]


func _finish() -> void:
	Sfx.play("confirm")
	close({"name": _names()[pick["name"]], "look": look()})


## The names the chosen gender picks from.
func _names() -> Array:
	return NAMES[_gender()]


# ---------------------------------------------------------------- showing
## What a row shows on its right: the name, the gender, a piece's name ("None" for no hat or glasses) or a color's.
func _value_text(id: String) -> String:
	match id:
		"name":
			return _names()[pick["name"]]
		"gender":
			return GENDER_NAMES[_gender()]
	if COLORS.has(id):
		if not _dyeable(id):
			return "None"
		return Wardrobe.dye_name(COLORS[id][1], dye[COLORS[id][0]])
	var i: int = pick[id]
	var names := _styles(id)
	return "None" if i < 0 else String(names[clampi(i, 0, names.size() - 1)])


func _show() -> void:
	if _start == null:
		return
	for id in _rows:
		var lit: bool = row == id
		var b: Button = _rows[id]
		var off: bool = COLORS.has(id) and not _dyeable(id)
		var sb: StyleBox = UIKit.highlight(VALUE_W) if lit else _plain_row()
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		var ink := UIKit.LIGHT if lit else (UIKit.DIM if off else UIKit.INK)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(st, ink)
		var v: Label = _values[id]
		v.text = _value_text(id)
		v.add_theme_color_override("font_color", ink)
		for a in _arrows[id]:
			(a as Control).visible = not off
			a.color = UIKit.LIGHT if lit else UIKit.ACCENT
			(a as Control).queue_redraw()
		if _swatches.has(id):
			var sw: Panel = _swatches[id]
			sw.visible = not off
			if not off:
				var chip: StyleBox = UIKit.chip(Color(dye[COLORS[id][0]]), Color(1, 1, 1, 0.9) if lit else Color(0, 0, 0, 0.35), 8.0, Vector4.ZERO, 2.0)
				sw.add_theme_stylebox_override("panel", chip)
	# the tabs: the open one the gem, the rest the window's off-white with dim text
	for k in _tabs.size():
		var open := k == tab
		var tb: Button = _tabs[k]
		var tsb: StyleBox = UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 0.0, Vector4(6, -2, 6, -2)) if open \
			else UIKit.FrameBox.make("row", Color(0, 0, 0, 0), UIKit.FILL, false, Vector4(10, 0, 10, 0))
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			tb.add_theme_stylebox_override(st, tsb)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			tb.add_theme_color_override(st, UIKit.LIGHT if open else UIKit.DIM)
		if not open:
			tb.modulate.a = 1.0


var _plain: StyleBox


## A row's box while it isn't the one chosen: nothing to see, its name where the gem bar's would put it.
func _plain_row() -> StyleBox:
	if _plain == null:
		var lit: StyleBox = UIKit.highlight(VALUE_W)
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = lit.content_margin_left
		sb.content_margin_right = lit.content_margin_right
		sb.content_margin_top = lit.content_margin_top
		sb.content_margin_bottom = lit.content_margin_bottom
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
	# the camera eases in on the open tab's part of the hero (and the mirror's camera follows)
	var want: Array = LOOK_AT[TABS[tab]["look_at"]]
	var goal := Vector2(want[0], want[1])
	if _look.distance_to(goal) > 0.001:
		_look = _look.lerp(goal, minf(1.0, delta * LOOK_EASE))
		_frame_camera()


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


## The camera in front of the hero, aimed so the hero and the mirror stand in the middle of the room left of the
## menu, whatever the screen's shape and wherever the menu stands.
func _frame_camera() -> void:
	if not is_instance_valid(_cam) or _turn == null:
		return
	_cam.fov = CAM_FOV
	var aim := _turn.position + CAM_AIM
	aim.y = _turn.position.y + _look.x
	# the hero and the mirror (GROUP_X: between them) centred in the room left of the menu, wherever it stands
	var aspect := size.x / maxf(size.y, 1.0)
	var half_w := tan(deg_to_rad(CAM_FOV / 2.0)) * CAM_BACK.length() * (1.0 - _look.y) * aspect
	var left := (_column.position.x / maxf(size.x, 1.0)) if _column != null and size.x > 0.0 else 0.45
	aim.x = _turn.position.x + GROUP_X + (0.5 - left * 0.5) * 2.0 * half_w
	var at := aim + CAM_BACK * (1.0 - _look.y)
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
	if GameState.HERO_SCALES.has(nm):
		l["scale"] = GameState.HERO_SCALES[nm]
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
## The grid of colors over the menu: big swatches (a fingertip's size on a touch screen) in a window, the one chosen
## ringed. The arrows (up, down, left and right) move through it, dyeing the hero as they go (through `on_pick`); A
## keeps the color and B gives back null, as the "B: Cancel" and "A: Confirm" buttons hanging off the middle of its
## bottom edge say (a tap on them does the same); a second tap on the same color keeps it too.
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
	var cancel: Button
	var confirm_hit: Control
	var cancel_hit: Control
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
		# A: Confirm and B: Cancel hang off the grid's bottom right corner, as under the other menus (edge_button.gd)
		var hang := Control.new()
		vb.add_child(hang)
		var EdgeButton = load("res://scripts/ui/edge_button.gd")
		confirm_hit = EdgeButton.new().setup("A: Confirm")
		confirm = confirm_hit.button
		confirm_hit.pressed.connect(func() -> void: _keep())
		add_child(confirm_hit)
		cancel_hit = EdgeButton.new().setup("B: Cancel")
		cancel = cancel_hit.button
		cancel_hit.pressed.connect(func() -> void:
			Sfx.play("back")
			close(null))
		add_child(cancel_hit)
		hang.custom_minimum_size.y = confirm_hit.overhang() * 0.6
		_paint()
		_place.call_deferred()

	## Over the menu (`near`: its window), as near its middle as fits inside the safe area, clear of the key guide
	## and of the touch pad (moved left until no corner or edge of it is under A, B, Start or Pause; failing that,
	## in the middle of the screen).
	func _place() -> void:
		var safe := Kit.safe_rect(self)
		var want := box.get_combined_minimum_size()
		box.size = want
		var reserve := UI.bottom_reserve()
		var x := clampf(near.get_center().x - want.x / 2.0, safe.position.x + 8.0, safe.end.x - want.x - 8.0)
		var y := clampf(near.get_center().y - want.y / 2.0, safe.position.y + 8.0, maxf(safe.position.y + 8.0, safe.end.y - reserve - want.y - 8.0 - 40.0))
		# moved left until clear of the pad; where nothing near the menu is, the middle of the screen (between the
		# d-pad and A and B)
		var tried := x
		while tried > safe.position.x + 8.0 and _under_pad(Rect2(Vector2(tried, y), want)):
			tried -= 16.0
		if _under_pad(Rect2(Vector2(tried, y), want)):
			tried = safe.get_center().x - want.x / 2.0
		box.position = Vector2(tried, y)
		# the two side by side, centred along its bottom edge
		var r := Rect2(box.position, want)
		var gap := 12.0
		var both: float = cancel_hit.button_size().x + gap + confirm_hit.button_size().x
		var right_of: float = r.end.x - confirm_hit.INSET - (r.get_center().x + both / 2.0)
		confirm_hit.place_under(r, right_of)
		cancel_hit.place_under(r, right_of + confirm_hit.button_size().x + gap)

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
