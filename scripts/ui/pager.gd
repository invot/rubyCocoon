extends HBoxContainer
## Prev and Next buttons, with "page / pages" between them, under a scrolling list or page (the Start book's two
## pages, a long menu): each press turns a whole page, so everything can be reached without a d-pad (on a phone the
## pad steps aside while the book is open, and dragging a list of buttons only presses them). Shown only while what it
## pages through runs past one page.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

var scroll: ScrollContainer
var _prev: Button
var _next: Button
var _count: Label
var _turning: Tween


func setup(s: ScrollContainer) -> Control:
	scroll = s
	return self


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prev = _button("◄ Prev", -1)
	add_child(_prev)
	_count = UIKit.label("", 20, UIKit.DIM)
	_count.custom_minimum_size.x = 70
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_count)
	_next = _button("Next ►", 1)
	add_child(_next)
	var bar := scroll.get_v_scroll_bar()
	bar.changed.connect(_update)
	bar.value_changed.connect(func(_v: float) -> void: _update())
	scroll.resized.connect(_update)
	visible = false
	_update.call_deferred()


func _button(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, UIKit.row_h())
	var up := UIKit.chip(UIKit.WINDOW_BOTTOM, UIKit.BORDER, 12.0, Vector4(12, 2, 12, 2))
	var held := UIKit.chip(UIKit.ACCENT, UIKit.BORDER, 12.0, Vector4(12, 2, 12, 2))
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, up)
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, held)
	b.add_theme_stylebox_override("disabled", up)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UIKit.LIGHT)
	b.add_theme_color_override("font_disabled_color", Color(UIKit.DIM, 0.45))
	b.pressed.connect(_turn.bind(dir))
	return b


## Which page is showing, of how many; hidden while it all fits.
func _update() -> void:
	if not is_instance_valid(scroll):
		return
	var bar := scroll.get_v_scroll_bar()
	var page := maxf(bar.page, 1.0)
	var room := bar.max_value - page
	visible = room > 2.0
	if not visible:
		return
	var pages := ceili(bar.max_value / page - 0.02)
	var at := clampi(roundi(bar.value / page) + 1, 1, pages)
	if bar.value >= room - 1.0:
		at = pages
	_count.text = "%d / %d" % [at, pages]
	_prev.disabled = bar.value <= 1.0
	_next.disabled = bar.value >= room - 1.0


## A page on (1) or back (-1), leaving a row's worth of the last page in view so the place isn't lost.
func _turn(dir: int) -> void:
	var bar := scroll.get_v_scroll_bar()
	var step := maxf(bar.page - UIKit.row_h() * 0.5, bar.page * 0.5)
	var to := clampf(bar.value + dir * step, 0.0, maxf(0.0, bar.max_value - bar.page))
	Sfx.play("page")
	if _turning != null and _turning.is_valid():
		_turning.kill()
	_turning = create_tween()
	_turning.tween_property(scroll, "scroll_vertical", int(to), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
