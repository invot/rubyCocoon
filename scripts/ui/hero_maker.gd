extends "res://scripts/ui/modal.gd"
## The character creator, before a new game: the hero's name (one of their body's NAMES: no keyboard), body, and the colours of
## their top, trousers, hair and eyes, on a turning preview. Closes with {"name", "look"} (the look for
## GameState.hero), or null when backed out of.
## Keys: up and down pick a row, left and right change it, A on Start begins, B backs out. Touch: tap the arrows,
## the swatches and Start; drag the preview to turn the hero round.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")

## ten names for each body, the first the one it starts with
const NAMES := {
	"male": ["Andrew", "Ben", "Fritzy", "Sam", "Leo", "Max", "Kai", "Finn", "Theo", "Jack"],
	"female": ["Regan", "Tessa", "Christina", "Mia", "Lily", "Ava", "Nora", "Ivy", "Zoe", "Clara"],
}
const BODIES := ["male", "female"]
const BODY_NAMES := {"male": "Male", "female": "Female"}
const SWATCHES := {
	"top": ["#b93646", "#3a6ab8", "#3a8a4a", "#d8b030", "#7a4aa8", "#2a2a30", "#e8e4dc", "#d8702a"],
	"trousers": ["#39588a", "#222228", "#5a3e2a", "#9a8a62", "#6a6a70", "#d8d4cc", "#3e5a3a", "#8a2a2a"],
	"hair": ["#1a1410", "#3a2216", "#6a4026", "#8a3a20", "#c0602a", "#d8b060", "#c8c8d0", "#d87a9a"],
	"eyes": ["#5a3020", "#7a5a2a", "#3a7a4a", "#3a6ab0", "#7a8a96", "#b07a20"],
}
## each body's own top to begin with: his red jacket, her white top
const DEFAULT_TOP := {"male": 0, "female": 6}
const ROWS := ["name", "body", "top", "trousers", "hair", "eyes", "start"]
const ROW_NAMES := {"name": "Name", "body": "Body", "top": "Top", "trousers": "Trousers", "hair": "Hair", "eyes": "Eyes"}
const CHIP := 46.0

var pick := {"name": 0, "body": 0, "top": 0, "trousers": 0, "hair": 0, "eyes": 0}
## the name last picked for each body, so switching back keeps it
var _names_by_body := {"male": 0, "female": 0}
var row := 0
var _rows := {}
var _name_label: Label
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
	hb.add_child(_preview())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", -2)
	hb.add_child(right)
	var rib := UIKit.ribbon("Who are you?", true)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rib.z_index = 1
	right.add_child(rib)
	var p := UIKit.panel()
	right.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	vb.add_child(gap)
	for id in ROWS:
		vb.add_child(_row(id))
	if not UI.is_touch():
		var hint := UIKit.label("Up / Down choose   Left / Right change", 16, UIKit.DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(hint)
	UIKit.place(hb, "center")
	_build_rig()
	_show()


## The hero on a small stage, turning slowly (drag to turn them yourself).
func _preview() -> Control:
	var frame := UIKit.panel()
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(340, 520)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_preview_input)
	frame.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(340, 520)
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
	var at := Vector3(0, 1.1, 3.8)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.84, 0) - at, Vector3.UP), at)
	vp.add_child(cam)
	cam.current = true
	return frame


func _row(id: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	pc.custom_minimum_size.y = 58
	_rows[id] = pc
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	# a tap anywhere on a row picks it
	pc.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_go(ROWS.find(id), false))
	if id == "start":
		_start = _button("Start your journey", func() -> void: _finish(), Vector2(0, 54))
		_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(_start)
		return pc
	var l := UIKit.label(ROW_NAMES[id], UIKit.BODY_HUGE, UIKit.GOLD)
	l.custom_minimum_size.x = 150
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l)
	match id:
		"name":
			_arrows.append(_button("<", func() -> void: _change("name", -1), Vector2(58, 50)))
			hb.add_child(_arrows[0])
			_name_label = UIKit.label("", UIKit.BODY_HUGE, UIKit.LIGHT)
			_name_label.custom_minimum_size.x = 200
			_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(_name_label)
			_arrows.append(_button(">", func() -> void: _change("name", 1), Vector2(58, 50)))
			hb.add_child(_arrows[1])
		"body":
			_chips["body"] = []
			for i in BODIES.size():
				var b := _button(BODY_NAMES[BODIES[i]], func() -> void: _choose("body", i), Vector2(150, 50))
				hb.add_child(b)
				_chips["body"].append(b)
		_:
			_chips[id] = []
			for i in (SWATCHES[id] as Array).size():
				var b := _button("", func() -> void: _choose(id, i), Vector2(CHIP, CHIP))
				hb.add_child(b)
				_chips[id].append(b)
	return pc


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
func on_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not ev.is_echo():
		Sfx.play("back")
		close(null)
	elif ev.is_action_pressed("ui_up", true):
		_go(row - 1)
	elif ev.is_action_pressed("ui_down", true):
		_go(row + 1)
	elif ev.is_action_pressed("ui_left", true):
		_change(ROWS[row], -1)
	elif ev.is_action_pressed("ui_right", true):
		_change(ROWS[row], 1)
	elif ev.is_action_pressed("ui_accept") and not ev.is_echo():
		if ROWS[row] == "start":
			_finish()
		else:
			_go(row + 1)


func _go(r: int, sound := true) -> void:
	r = posmod(r, ROWS.size())
	if r == row:
		return
	row = r
	if sound:
		Sfx.play("blip")
	_show()


## One step along a row (left or right).
func _change(id: String, d: int) -> void:
	_go(ROWS.find(id), false)
	match id:
		"name":
			pick["name"] = posmod(pick["name"] + d, _names().size())
			Sfx.play("blip")
			_show()
		"body":
			_choose("body", posmod(pick["body"] + d, BODIES.size()))
		"start":
			pass
		_:
			_choose(id, posmod(pick[id] + d, (SWATCHES[id] as Array).size()))


func _choose(id: String, i: int) -> void:
	_go(ROWS.find(id), false)
	if pick[id] == i:
		return
	Sfx.play("blip")
	if id == "body":
		# a top left as the last body's own becomes this one's
		if pick["top"] == DEFAULT_TOP[BODIES[pick["body"]]]:
			pick["top"] = DEFAULT_TOP[BODIES[i]]
		# and the name: the one last picked for this body (to begin with, its own)
		_names_by_body[BODIES[pick["body"]]] = pick["name"]
		pick["name"] = _names_by_body[BODIES[i]]
		pick["body"] = i
		_build_rig()
	else:
		pick[id] = i
		VPer.dress(_rig, look())
	_show()


## The look chosen so far (see GameState.hero).
func look() -> Dictionary:
	var out := {"body": BODIES[pick["body"]]}
	for k in SWATCHES:
		out[k] = SWATCHES[k][pick[k]]
	return out


func _finish() -> void:
	Sfx.play("confirm")
	close({"name": _names()[pick["name"]], "look": look()})


## The names the chosen body picks from.
func _names() -> Array:
	return NAMES[BODIES[pick["body"]]]


# ---------------------------------------------------------------- showing
func _show() -> void:
	for id in _rows:
		(_rows[id] as PanelContainer).add_theme_stylebox_override("panel", UIKit.highlight() if ROWS[row] == id else StyleBoxEmpty.new())
	_name_label.text = _names()[pick["name"]]
	for a in _arrows:
		_paint(a, false)
	_paint(_start, ROWS[row] == "start")
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
			b.pivot_offset = Vector2(CHIP, CHIP) / 2.0


func _build_rig() -> void:
	if is_instance_valid(_rig):
		_rig.queue_free()
	_rig = VPer.build(_hero_look())
	VPer.face(_rig, Vector2i(0, 1))
	_turn.add_child(_rig)


func _hero_look() -> Dictionary:
	var l := {"face": "hero"}
	l.merge(look())
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
