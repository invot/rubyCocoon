extends VBoxContainer
## A scroll bar with an up button at its top and a down button at its foot, beside a scrolling list or page (the
## Start book's two pages, a long menu). Each press of an arrow scrolls the content a row or more, and holding it keeps
## scrolling; the bar between them shows where you are: tap above or below its thumb to scroll a page, or drag the
## thumb. So all of it can be reached with taps alone (on a phone, dragging a list of buttons only presses them).
## Shown only while what it scrolls runs past one page.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

## how long a held arrow waits before it keeps scrolling
const HOLD_DELAY := 0.35
## the thumb's shortest length (UI units)
const THUMB_MIN := 28.0

var scroll: ScrollContainer
## Ordinary mobile lists use d-pad focus scrolling and direct taps rather than scroll buttons.
var enabled := true
## Keep the rail's width while there's nothing to scroll (a menu sized to its contents mustn't change width).
var reserve := false
## true while the content runs past one page (and the arrows and bar show)
var active := false
var _up: Arrow
var _down: Arrow
var _track: Control
var _moving: Tween
var _dirty := true
var _held := 0
var _hold_t := 0.0
var _pos := 0.0
## where on the thumb a drag took hold of it, or -1
var _grip := -1.0


func setup(s: ScrollContainer) -> Control:
	scroll = s
	return self


## The rail's width: as wide as a row is tall on a phone, so the arrows are square thumb-sized targets.
static func width() -> float:
	return 72.0 if UIKit.touch_ui() else 48.0


func _ready() -> void:
	custom_minimum_size.x = width()
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_up = _arrow(-1)
	add_child(_up)
	_track = Control.new()
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.mouse_filter = Control.MOUSE_FILTER_STOP
	_track.draw.connect(_draw_track)
	_track.gui_input.connect(_track_input)
	add_child(_track)
	_down = _arrow(1)
	add_child(_down)
	if enabled:
		# (the rail stands in for the container's own thin bar; the wheel and the d-pad still scroll it)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# (looked at once a frame: the bar announces its new length before its new page, and showing or hiding the rail
	# mid-layout would set the layout going round again before it settles)
	var bar := scroll.get_v_scroll_bar()
	bar.changed.connect(_queue_update)
	bar.value_changed.connect(func(_v: float) -> void: _queue_update())
	scroll.resized.connect(_queue_update)
	if is_instance_valid(Prefs):
		Prefs.changed.connect(_restyle)
	_update()


func _queue_update() -> void:
	_dirty = true


func _arrow(dir: int) -> Arrow:
	var b := Arrow.new()
	b.dir = dir
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width(), UIKit.row_h())
	b.button_down.connect(_hold.bind(dir))
	b.button_up.connect(func() -> void: _held = 0)
	UIKit.plate_button(b, Vector4.ZERO)
	return b


## A new gem or style while it's open.
func _restyle() -> void:
	if not is_inside_tree():
		return
	for b in [_up, _down]:
		UIKit.plate_button(b, Vector4.ZERO)
		b.queue_redraw()
	_track.queue_redraw()


## Shows the rail while there's more than a page, and greys out an arrow at its end.
func _update() -> void:
	if not is_instance_valid(scroll):
		return
	var bar := scroll.get_v_scroll_bar()
	var room := bar.max_value - bar.page
	active = enabled and room > 2.0
	for c in get_children():
		(c as Control).visible = active
	visible = enabled and (active or reserve)
	if not active:
		_held = 0
		return
	_up.disabled = bar.value <= 1.0
	_down.disabled = bar.value >= room - 1.0
	_track.queue_redraw()


## How far one press scrolls: half a page in whole rows (at least one), so the place is never lost.
func _step_size() -> float:
	var row := UIKit.row_h()
	return maxf(row, floorf(scroll.get_v_scroll_bar().page * 0.5 / row) * row)


func _room() -> float:
	var bar := scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


## An arrow pressed: a step that way now, then (held) a steady glide.
func _hold(dir: int) -> void:
	_held = dir
	_hold_t = HOLD_DELAY
	step(dir)


## One press's worth of scrolling: -1 up, 1 down.
func step(dir: int) -> void:
	Sfx.play("blip")
	_glide_to(_target() + dir * _step_size())


## Pressed again while the last step is still gliding: on from where that one was heading.
func _target() -> float:
	if _moving != null and _moving.is_valid() and _moving.is_running():
		return _pos
	return float(scroll.scroll_vertical)


func _glide_to(to: float) -> void:
	_pos = clampf(to, 0.0, _room())
	if _moving != null and _moving.is_valid():
		_moving.kill()
	_moving = create_tween()
	_moving.tween_property(scroll, "scroll_vertical", int(_pos), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_update()
	if _held == 0:
		return
	var b := _up if _held < 0 else _down
	if b.disabled or not b.is_visible_in_tree():
		_held = 0
		return
	_hold_t -= delta
	if _hold_t > 0.0:
		return
	if _moving != null and _moving.is_valid():
		_moving.kill()
		_pos = float(scroll.scroll_vertical)
	# (about a page and a half a second)
	var speed := maxf(UIKit.row_h() * 6.0, scroll.get_v_scroll_bar().page * 1.5)
	_pos = clampf(_pos + _held * speed * delta, 0.0, _room())
	scroll.scroll_vertical = int(_pos)


## The thumb's place on the bar.
func _thumb() -> Rect2:
	var bar := scroll.get_v_scroll_bar()
	var h := _track.size.y
	var th := clampf(h * bar.page / maxf(bar.max_value, 1.0), minf(THUMB_MIN, h), h)
	var at := (h - th) * bar.value / maxf(_room(), 1.0)
	var w := roundf(_track.size.x * 0.4)
	return Rect2(roundf((_track.size.x - w) / 2.0), roundf(at), w, roundf(th))


func _draw_track() -> void:
	if not active:
		return
	var t := _thumb()
	var mid := roundf(_track.size.x / 2.0)
	if UIKit.pixel():
		# a white hairline in the kit's pixels, and the thumb a plate with the gem behind the white
		var s := float(UIKit.PIXEL_SCALE)
		_track.draw_rect(Rect2(mid - s / 2.0, 0, s, _track.size.y), UIKit.PIXEL_DIM)
		_track.draw_style_box(UIKit.pixel_box("plate", UIKit.ACCENT, UIKit.PIXEL_LINE, Vector4.ZERO), t)
		return
	_track.draw_rect(Rect2(mid - 2.0, 0, 4.0, _track.size.y), Color(UIKit.BORDER_INNER, 0.8))
	_track.draw_style_box(UIKit.chip(UIKit.ACCENT, UIKit.BORDER, t.size.x / 2.0, Vector4.ZERO), t)


## The bar: a tap above or below the thumb scrolls a page that way; the thumb itself can be dragged.
func _track_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if not ev.pressed:
			_grip = -1.0
			return
		var t := _thumb()
		if ev.position.y >= t.position.y and ev.position.y <= t.end.y:
			_grip = ev.position.y - t.position.y
		else:
			var dir := -1 if ev.position.y < t.position.y else 1
			Sfx.play("page")
			_glide_to(_target() + dir * maxf(_step_size(), scroll.get_v_scroll_bar().page - UIKit.row_h() * 0.5))
		_track.accept_event()
	elif ev is InputEventMouseMotion and _grip >= 0.0:
		var t := _thumb()
		var free := maxf(_track.size.y - t.size.y, 1.0)
		if _moving != null and _moving.is_valid():
			_moving.kill()
		_pos = clampf((ev.position.y - _grip) / free * _room(), 0.0, _room())
		scroll.scroll_vertical = int(_pos)
		_track.accept_event()


## An arrow button: its triangle drawn over the button's plate (white; dim once there's no further to go).
class Arrow extends Button:
	const UIKit = preload("res://scripts/ui/ui_kit.gd")
	## -1 up, 1 down
	var dir := 1

	func _draw() -> void:
		var col := UIKit.LIGHT if not disabled else Color(UIKit.DIM, 0.4)
		var c := (size / 2.0).round()
		if UIKit.pixel():
			# stepped in the kit's pixels, so its edges stay crisp
			var s := float(UIKit.PIXEL_SCALE)
			var rows := 6
			var top := c.y - rows * s / 2.0
			for i in rows:
				var half := s * (0.5 + i)
				draw_rect(Rect2(c.x - half, top + (i if dir < 0 else rows - 1 - i) * s, half * 2.0, s), col)
			return
		var w := 13.0
		var h := 8.0 * dir
		var pts := PackedVector2Array([c + Vector2(-w, h), c + Vector2(w, h), c + Vector2(0, -h)])
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, col, 1.0, true)
