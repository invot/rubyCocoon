extends Control
## The Codex's little robot head (scripts/ui/codex.gd), floating at the top-left of the screen in a soft glow (no
## window: the user's 2026-11-14 direction). The glow breathes slowly and brightens while it talks.
## The head is Quaternius's robot head recoloured orange (tools/import_codex_head.gd), rendered in its own small
## 3D world. Its brows move with its mood (MOODS), which changes with every speech bubble; it blinks now and then,
## and bobs while it talks. In battle it stays up, and a tap (or click) on it asks it a question (signal tapped).

signal tapped

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const DIR := "res://assets/ui/codex/"
## Its size, in UI units (taller than the 80-unit touch minimum, so the whole glow is the tap target).
const BOX := Vector2(124, 112)
const MARGIN := Vector2(16, 12)
## How far the glow reaches past the head's box.
const GLOW_PAD := 40.0
## A mood's brows: lift (up, in head widths) and tilt (radians; more raises the inner ends), for each brow
## [left, right] (the head's own left and right).
const MOODS := {
	"neutral": [[0.0, 0.0], [0.0, 0.0]],
	"happy": [[0.016, 0.12], [0.016, 0.12]],
	"excited": [[0.03, 0.05], [0.03, 0.05]],
	"proud": [[0.004, -0.18], [0.004, -0.18]],
	"curious": [[0.035, 0.22], [-0.012, -0.12]],
	"worried": [[0.012, 0.45], [0.012, 0.45]],
	"surprised": [[0.042, 0.1], [0.042, 0.1]],
	"determined": [[-0.02, -0.42], [-0.02, -0.42]],
}

var mood := "neutral"
var talking := false
## Whether a tap asks a question (battle.gd sets it while you choose commands).
var tappable := false

var _view: SubViewport
var _pivot: Node3D
var _eyes: MeshInstance3D
var _brows: Array = []
var _brow_home: Array = []
var _cur := [[0.0, 0.0], [0.0, 0.0]]
var _t := 0.0
var _blink_in := 2.5
var _blink := 0.0
## The glow behind the head. It's a separate node (codex.gd keeps it in the menu layer, under the Codex's speech
## bubble, so it never washes over the words), kept in place round the head every frame.
var glow: TextureRect
var _hint: Label
var _gem := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# a soft round glow behind the head
	glow = TextureRect.new()
	glow.texture = _glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	box.add_child(_view)
	_build_scene()
	# a small "?" in the corner while a tap asks a question
	_hint = UIKit.label("?", 22, Color.WHITE)
	_hint.add_theme_font_override("font", UIKit.font_head())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 14.0, Vector4.ZERO))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size = Vector2(28, 28)
	dot.position = BOX - Vector2(30, 30)
	dot.add_child(_hint)
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dot)
	_hint.set_meta("dot", dot)
	_layout()
	get_viewport().size_changed.connect(_layout)


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#f0e8df")
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_view.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff3e2")
	key.light_energy = 0.85
	key.rotation_degrees = Vector3(-35, 30, 0)
	_view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#bcd6ff")
	rim.light_energy = 0.45
	rim.rotation_degrees = Vector3(-10, 200, 0)
	_view.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 0.06, 2.2)
	cam.rotation_degrees = Vector3(-2, 0, 0)
	_view.add_child(cam)
	_pivot = Node3D.new()
	_pivot.rotation_degrees = Vector3(6, -6, 0)
	_view.add_child(_pivot)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ui/codex_head.gdshader")
	mat.set_shader_parameter("paint", _paint())
	var head := MeshInstance3D.new()
	head.mesh = load(DIR + "codex_head.res")
	head.material_override = mat
	_pivot.add_child(head)
	_eyes = MeshInstance3D.new()
	_eyes.mesh = load(DIR + "codex_eyes.res")
	_eyes.material_override = mat
	_pivot.add_child(_eyes)
	for n in ["codex_brow_l.res", "codex_brow_r.res"]:
		var brow := MeshInstance3D.new()
		brow.mesh = load(DIR + n)
		brow.material_override = mat
		var home: Vector3 = brow.mesh.get_meta("pivot", Vector3.ZERO)
		brow.position = home
		_pivot.add_child(brow)
		_brows.append(brow)
		_brow_home.append(home)


## The glow: bluish white at the middle, fading softly to nothing at the edge.
func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.78, 1.0])
	g.colors = PackedColorArray([Color(0.94, 0.99, 1.0, 0.6), Color(0.8, 0.93, 1.0, 0.5), Color(0.58, 0.82, 1.0, 0.22), Color(0.5, 0.76, 1.0, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t


## The painted wash: light at the top of each part, falling softly to shade at the bottom.
func _paint() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.06, 1.06, 1.06))
	g.set_color(1, Color(0.8, 0.82, 0.86))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 64
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	return t


func _layout() -> void:
	var safe := UIKit.safe_rect(self)
	position = safe.position + MARGIN
	size = BOX


func set_mood(m: String) -> void:
	mood = m if MOODS.has(m) else "neutral"


func _process(delta: float) -> void:
	_t += delta
	var want: Array = MOODS[mood]
	for k in 2:
		for j in 2:
			_cur[k][j] = lerpf(_cur[k][j], float(want[k][j]), minf(1.0, delta * 12.0))
		var brow: MeshInstance3D = _brows[k]
		var bob := sin(_t * 18.0 + k) * 0.006 if talking else 0.0
		brow.position = _brow_home[k] + Vector3(0, float(_cur[k][0]) + bob, 0)
		# the head's left brow is at +x: a positive tilt raises its inner (-x) end
		brow.rotation.z = -float(_cur[k][1]) if k == 0 else float(_cur[k][1])
	# a bob and a little sway while talking, a slow drift otherwise
	var nod := sin(_t * 9.0) * 3.0 if talking else sin(_t * 1.3) * 1.2
	_pivot.rotation_degrees = Vector3(6 + nod, -6 + sin(_t * 0.7) * 3.0, sin(_t * 1.1) * 1.5)
	# the glow breathes, and brightens while it talks
	glow.visible = is_visible_in_tree()
	glow.global_position = global_position - Vector2(GLOW_PAD, GLOW_PAD)
	glow.size = size + Vector2(GLOW_PAD, GLOW_PAD) * 2.0
	glow.modulate.a = lerpf(glow.modulate.a, (0.85 if talking else 0.7) + sin(_t * 2.0) * 0.06, minf(1.0, delta * 6.0))
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.14
		_blink_in = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	_eyes.scale.y = 0.12 if _blink > 0.0 else 1.0
	var dot: Control = _hint.get_meta("dot")
	dot.visible = tappable
	if _gem != UIKit.accent_name:
		_gem = UIKit.accent_name
		dot.add_theme_stylebox_override("panel", UIKit.chip(UIKit.ACCENT, Color(0, 0, 0, 0), 14.0, Vector4.ZERO))


func _exit_tree() -> void:
	if is_instance_valid(glow):
		glow.queue_free()


func _gui_input(ev: InputEvent) -> void:
	if ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var click: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	var tap: bool = ev is InputEventScreenTouch and ev.pressed and ev.index == 0
	if click or tap:
		accept_event()
		if tappable:
			tapped.emit()
