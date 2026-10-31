extends "res://scripts/ui/modal.gd"
## The character creator, before a new game, on two tabs: Look (the hero's name, one of their body's NAMES: no
## keyboard; their body, outfit and hairdo, see townfolk.gd HERO_OUTFITS and HAIRDOS) and Colours (their pack, skin,
## top, trousers, hair and eyes), beside a turning preview with Confirm under it. Closes with {"name", "look"} (the look
## for GameState.hero), or null when backed out of.
## Keys: up and down pick a row (the tabs above the first, Confirm below the last), left and right change it (on the
## tabs: switch tab), A goes on to the next row (from Look's last row on to the Colours tab) and on Confirm begins, B
## backs out. Touch: tap the tabs, the arrows, the swatches and Confirm; drag the preview to turn the hero round.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const Townfolk = preload("res://scripts/gfx/townfolk.gd")

## ten names for each body, the first the one it starts with
const NAMES := {
	"male": ["Andrew", "Ben", "Fritzy", "Sam", "Leo", "Max", "Kai", "Finn", "Theo", "Jack"],
	"female": ["Regan", "Tessa", "Christina", "Mia", "Lily", "Ava", "Nora", "Ivy", "Zoe", "Clara"],
}
const BODIES := ["male", "female"]
const BODY_NAMES := {"male": "Male", "female": "Female"}
const SWATCHES := {
	"skin": ["#f6d8c0", "#f0c8a0", "#e0ac84", "#c68a62", "#9a6440", "#6e4428"],
	"top": ["#b93646", "#3a6ab8", "#3a8a4a", "#d8b030", "#7a4aa8", "#2a2a30", "#e8e4dc", "#d8702a", "#e0809e"],
	"trousers": ["#39588a", "#222228", "#5a3e2a", "#9a8a62", "#6a6a70", "#d8d4cc", "#3e5a3a", "#8a2a2a", "#e0809e"],
	"hair": ["#1a1410", "#3a2216", "#6a4026", "#8a3a20", "#c0602a", "#d8b060", "#c8c8d0", "#d87a9a"],
	"eyes": ["#642a12", "#845613", "#198337", "#195bc4", "#657f94", "#be7909"],
	# the pack (townfolk.gd PACK): brown to begin with
	"pack": ["#7a4a2a", "#4a3020", "#a8865a", "#b03a3a", "#3a5a8a", "#4a6a3a", "#5a5a62", "#c8a040", "#e0809e"],
}
## each body's own top to begin with: his red jacket, her white top
const DEFAULT_TOP := {"male": 0, "female": 6}
## each body's skin to begin with
const DEFAULT_SKIN := 1
## the two tabs and the rows on each
const TABS := [
	{"name": "Look", "rows": ["name", "body", "outfit", "hairdo"]},
	{"name": "Colours", "rows": ["pack", "skin", "top", "trousers", "hair", "eyes"]},
]
const ROW_NAMES := {"name": "Name", "body": "Body", "outfit": "Outfit", "hairdo": "Hairdo", "pack": "Pack", "skin": "Skin",
	"top": "Top", "trousers": "Trousers", "hair": "Hair", "eyes": "Eyes"}
## the rows stepped through with arrows, and the label each shows
const STEPPED := ["name", "outfit", "hairdo"]
## a swatch's size (at least; touch screens get bigger ones)
const CHIP := 44.0
const CHIP_TOUCH := 54.0
## the preview's size at least (Confirm goes under it)
const PREVIEW := Vector2i(340, 464)
## on a touch screen, how far up from the bottom Start and Pause reach: the creator stands clear above them
const PAD_CLEAR := 72.0

var pick := {"name": 0, "body": 0, "outfit": 0, "hairdo": Townfolk.HERO_HAIRDO["male"], "pack": 0,
	"skin": DEFAULT_SKIN, "top": 0, "trousers": 0, "hair": 0, "eyes": 0}
## the name, outfit and hairdo last picked for each body, so switching back keeps them
var _names_by_body := {"male": 0, "female": 0}
var _outfit_by_body := {"male": 0, "female": 0}
var _hairdo_by_body := Townfolk.HERO_HAIRDO.duplicate()
## the open tab, and the row being chosen on it: "tab" (the tab strip), one of its rows, or "start" (Confirm)
var tab := 0
var row := "name"
var _rows := {}
var _name_label: Label
## the labels of the rows stepped through with arrows (the name's too)
var _stepped := {}
## each row's name: white on the row being chosen, dim on the rest (the rows themselves aren't highlighted, so
## nothing in them moves)
var _row_labels := {}
var _tabs: Array = []
var _pages: Array = []
var _start: Button
var _arrows: Array = []
var _chips := {}
var _turn: Node3D
var _rig: Node3D
var _t := 0.0
var _yaw := -0.35
var _drag := false
var _still := 0.0


func _init() -> void:
	super()
	dim = 0.35


func _ready() -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	# (the preview grows to stand as tall as the panel beside it, Confirm along its foot)
	var pv := _preview()
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(pv)
	# Confirm, in the gem's colour, under the hero (the last row for the keys)
	_start = _button("Confirm", func() -> void: _finish(), Vector2(0, UIKit.row_h()))
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UIKit.touch_ui():
		# (on a touch screen, at the right of the column, clear of the d-pad in the corner below the preview)
		_start.custom_minimum_size.x = 220
		_start.size_flags_horizontal = Control.SIZE_SHRINK_END
	left.add_child(_start)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", -2)
	hb.add_child(right)
	var rib := UIKit.ribbon("Who are you?", true)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rib.z_index = 1
	right.add_child(rib)
	# the tabs, over the panel
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	right.add_child(strip)
	for i in TABS.size():
		var tb := _button(TABS[i]["name"], func() -> void: _open_tab(i, true), Vector2(0, UIKit.row_h()))
		tb.add_theme_font_override("font", UIKit.font_head())
		tb.add_theme_font_size_override("font_size", UIKit.head_px(UIKit.HEAD_SIZE))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.add_child(tb)
		_tabs.append(tb)
	# (on a touch screen the rows are taller, so the spacing goes: the panel must clear Start and Pause)
	var tight := UIKit.touch_ui()
	var gap := Control.new()
	gap.custom_minimum_size.y = 0 if tight else 8
	right.add_child(gap)
	var p := UIKit.panel()
	right.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	# both tabs' pages in one place, as big as the bigger of them, so nothing moves when the tab changes
	var pages := Control.new()
	vb.add_child(pages)
	var biggest := Vector2.ZERO
	for t in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 0 if tight else 4)
		for id in t["rows"]:
			page.add_child(_row(id))
		pages.add_child(page)
		_pages.append(page)
		biggest = biggest.max(page.get_combined_minimum_size())
	pages.custom_minimum_size = biggest
	for page in _pages:
		page.size = biggest
	if not UI.is_touch():
		var hint := UIKit.label("Up / Down choose   Left / Right change", 16, UIKit.DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(hint)
	UIKit.place(hb, "center")
	_build_rig()
	_open_tab(0, false)
	_clear_pad(hb)


## On a touch screen, Start and Pause sit under the middle of the screen: the creator moves up clear of them.
func _clear_pad(hb: Control) -> void:
	await get_tree().process_frame
	if not UI.is_touch():
		return
	var over := hb.position.y + hb.size.y - (size.y - PAD_CLEAR)
	if over > 0.0:
		hb.position.y = maxf(8.0, hb.position.y - over)


## The hero on a small stage, turning slowly (drag to turn them yourself).
func _preview() -> Control:
	var frame := UIKit.panel()
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(PREVIEW)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_preview_input)
	frame.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = PREVIEW
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	# a soft shadow to stand on
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.01
	disc.mesh = cyl
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0, 0, 0, 0.35)
	disc.material_override = dm
	vp.add_child(disc)
	_turn = Node3D.new()
	vp.add_child(_turn)
	var cam := Camera3D.new()
	cam.fov = 30
	var at := Vector3(0, VPer.height() * 0.75, 3.3)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, VPer.height() * 0.52, 0) - at, Vector3.UP), at)
	vp.add_child(cam)
	cam.current = true
	return frame


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
	var l := UIKit.label(ROW_NAMES[id], UIKit.BODY_HUGE, UIKit.GOLD)
	l.custom_minimum_size.x = 150
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_labels[id] = l
	hb.add_child(l)
	var tall := UIKit.row_h() - 8.0
	match id:
		"name", "outfit", "hairdo":
			var lt := _button("<", func() -> void: _change(id, -1), Vector2(64, tall))
			_arrows.append(lt)
			hb.add_child(lt)
			var nl := UIKit.label("", UIKit.BODY_HUGE, UIKit.LIGHT)
			nl.custom_minimum_size.x = 220
			nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(nl)
			_stepped[id] = nl
			if id == "name":
				_name_label = nl
			var rt := _button(">", func() -> void: _change(id, 1), Vector2(64, tall))
			_arrows.append(rt)
			hb.add_child(rt)
		"body":
			_chips["body"] = []
			for i in BODIES.size():
				var b := _button(BODY_NAMES[BODIES[i]], func() -> void: _choose("body", i), Vector2(170, tall))
				hb.add_child(b)
				_chips["body"].append(b)
		_:
			_chips[id] = []
			var chip := _chip_size()
			for i in (SWATCHES[id] as Array).size():
				var b := _button("", func() -> void: _choose(id, i), Vector2(chip, chip))
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hb.add_child(b)
				_chips[id].append(b)
	return pc


## A swatch's size: bigger on a touch screen, for a fingertip.
func _chip_size() -> float:
	return CHIP_TOUCH if UIKit.touch_ui() else CHIP


func _button(text: String, on: Callable, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UIKit.font_body())
	b.add_theme_font_size_override("font_size", UIKit.body_px(UIKit.BODY_HUGE))
	b.pressed.connect(on)
	return b


## A button's look: a chip in the gem when it's lit, else a dark one.
static func _paint(b: Button, lit: bool) -> void:
	var sb := UIKit.chip(UIKit.ACCENT if lit else UIKit.WINDOW_BOTTOM, UIKit.BORDER if lit else UIKit.BORDER_INNER, 12.0)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
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
				# on to the next row; from the last of Look's, on to the Colours tab
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


## One step along a row (left or right).
func _change(id: String, d: int) -> void:
	_go(id, false)
	match id:
		"tab":
			_open_tab(tab + d)
		"name":
			pick["name"] = posmod(pick["name"] + d, _names().size())
			Sfx.play("blip")
			# (some names are a little shorter: see GameState.SHORT_HEROES)
			VPer.dress(_rig, _hero_look())
			_show()
		"body":
			_choose("body", posmod(pick["body"] + d, BODIES.size()))
		"outfit":
			_choose("outfit", posmod(pick["outfit"] + d, _outfits().size()))
		"hairdo":
			_choose("hairdo", posmod(pick["hairdo"] + d, Townfolk.HAIRDOS.size()))
		"start":
			pass
		_:
			_choose(id, posmod(pick[id] + d, (SWATCHES[id] as Array).size()))


func _choose(id: String, i: int) -> void:
	# (a row on the other tab, chosen from outside: a test, say)
	if not (TABS[tab]["rows"] as Array).has(id):
		for k in TABS.size():
			if (TABS[k]["rows"] as Array).has(id):
				_open_tab(k, false)
	_go(id, false)
	if pick[id] == i:
		return
	Sfx.play("blip")
	if id == "body":
		# a top left as the last body's own becomes this one's
		if pick["top"] == DEFAULT_TOP[BODIES[pick["body"]]]:
			pick["top"] = DEFAULT_TOP[BODIES[i]]
		# and the name, outfit and hairdo: the ones last picked for this body (to begin with, its own)
		var was: String = BODIES[pick["body"]]
		var now: String = BODIES[i]
		_names_by_body[was] = pick["name"]
		_outfit_by_body[was] = pick["outfit"]
		_hairdo_by_body[was] = pick["hairdo"]
		pick["name"] = _names_by_body[now]
		pick["outfit"] = _outfit_by_body[now]
		pick["hairdo"] = _hairdo_by_body[now]
		pick["body"] = i
		_build_rig()
	else:
		pick[id] = i
		VPer.dress(_rig, _hero_look())
	_show()


## The look chosen so far (see GameState.hero).
func look() -> Dictionary:
	var out := {"body": BODIES[pick["body"]], "person": _outfits()[pick["outfit"]], "hairdo": pick["hairdo"]}
	for k in SWATCHES:
		out["pack_colour" if k == "pack" else k] = SWATCHES[k][pick[k]]
	return out


## The outfits the chosen body picks from (people in townfolk.json).
func _outfits() -> Array:
	return Townfolk.HERO_OUTFITS[BODIES[pick["body"]]]


func _finish() -> void:
	Sfx.play("confirm")
	close({"name": _names()[pick["name"]], "look": look()})


## The names the chosen body picks from.
func _names() -> Array:
	return NAMES[BODIES[pick["body"]]]


# ---------------------------------------------------------------- showing
func _show() -> void:
	if _name_label == null:
		return
	for id in _row_labels:
		(_row_labels[id] as Label).add_theme_color_override("font_color", UIKit.LIGHT if row == id else UIKit.DIM)
	# the tabs: the open one filled with the gem, edged in white while the tab strip is the row being chosen
	for k in _tabs.size():
		var open := k == tab
		var tb: Button = _tabs[k]
		var edge := UIKit.LIGHT if open and row == "tab" else (UIKit.BORDER if open else UIKit.BORDER_INNER)
		var sb := UIKit.chip(UIKit.ACCENT if open else UIKit.WINDOW_BOTTOM, edge, 14.0, Vector4(10, 2, 10, 2), 3.0 if open and row == "tab" else 2.0)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			tb.add_theme_stylebox_override(st, sb)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			tb.add_theme_color_override(st, UIKit.LIGHT if open else UIKit.DIM)
	_name_label.text = _names()[pick["name"]]
	_stepped["outfit"].text = "%d of %d" % [pick["outfit"] + 1, _outfits().size()]
	_stepped["hairdo"].text = Townfolk.HAIRDOS[pick["hairdo"]][1]
	for a in _arrows:
		_paint(a, false)
	# Confirm is always in the gem's colour, edged in white while it's the row being chosen
	var confirm_on: bool = row == "start"
	var csb := UIKit.chip(UIKit.ACCENT, UIKit.LIGHT if confirm_on else UIKit.BORDER, 12.0, Vector4(10, 2, 10, 2), 3.0 if confirm_on else 2.0)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_start.add_theme_stylebox_override(st, csb)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_start.add_theme_color_override(st, UIKit.LIGHT)
	var chip := _chip_size()
	for id in _chips:
		var bs: Array = _chips[id]
		for i in bs.size():
			var on: bool = pick[id] == i
			var b: Button = bs[i]
			if id == "body":
				_paint(b, on)
				continue
			# a swatch: the colour itself, ringed in white when it's the one chosen
			var sw := UIKit.chip(Color(SWATCHES[id][i]), UIKit.LIGHT if on else Color(0, 0, 0, 0.55), 10.0, Vector4.ZERO, 4.0 if on else 2.0)
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				b.add_theme_stylebox_override(st, sw)
			b.scale = Vector2.ONE * (1.12 if on else 1.0)
			b.pivot_offset = Vector2(chip, chip) / 2.0


func _build_rig() -> void:
	if is_instance_valid(_rig):
		_rig.queue_free()
	_rig = VPer.build(_hero_look())
	VPer.face(_rig, Vector2i(0, 1))
	_turn.add_child(_rig)


func _hero_look() -> Dictionary:
	var l := {"face": "hero"}
	l.merge(look())
	var nm: String = _names()[pick["name"]]
	if GameState.SHORT_HEROES.has(nm):
		l["scale"] = GameState.SHORT_HEROES[nm]
	return l


func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_still = 0.0
	elif ev is InputEventMouseMotion and _drag:
		_yaw += ev.relative.x * 0.012


func _process(delta: float) -> void:
	_t += delta
	if _drag:
		_still = 0.0
	else:
		_still += delta
		if _still > 1.5:
			_yaw += delta * 0.45
	if _turn:
		_turn.rotation.y = _yaw
	if is_instance_valid(_rig):
		VPer.animate(_rig, 0.0, 0.0, _t)
