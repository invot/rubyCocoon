extends "res://scripts/ui/modal.gd"
## The beat attack's cue (rules: scripts/core/beat_chain.gd). A white ring floats above the target with a notch that
## spins round it once a beat, reaching the mark at the top on the beat as the ring pulses. Press A on the beat (the
## on-screen A on phones, the A key or gamepad A; a tap on the ring itself counts too) for each hit, on consecutive
## beats, up to `most`. Each press is graded at once (Perfect, Good or Miss: the word shows beside the ring) and `hit`
## is emitted so the throw follows the press; a Miss ends the chain (on the very first beat it still throws once,
## weakly: grade "weak"), as does the last hit. Pips under the ring count the hits allowed and landed.
## done emits the grades of the beats played, e.g. ["perfect", "good", "miss"].
##
## battle.gd sets `anchor` (a Callable giving the point above the target, in this screen's coordinates) and plays the
## hits. The beat comes from Sfx.beat_now (or `clock`, a Callable giving the beat, in tests); `injected`: presses for
## tests, each beat's offset in seconds from it (null for none), graded exactly where they fall.

signal hit(index: int, grade: String)

const BeatChain = preload("res://scripts/core/beat_chain.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

## the ring's radius, and how far a tap on it may be from its middle (UI units)
const RADIUS := 44.0
const TAP_RADIUS := 110.0
const LINE := 4.0
## how long the cue stays up after the chain ends, to show the last grade
const LINGER := 0.4

var most := 3
var easy := false
## practice (--scene=beat-click): no chain and no end; each press shows how far off the beat it was, and the average
## (to set Sfx.BEAT_LATENCY by on a device). B ends it.
var practice := false
var offsets: Array = []
var anchor: Callable
var clock: Callable
var injected: Array = []
var grades: Array = []
## the beat number of the first beat that counts
var first_beat := 0.0
var _finished := false
var _linger := 0.0
var _beat := 0.0
var _popups: Array = []
var _injected_next := 0
var _center := Vector2.ZERO
var _alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beat = _now()
	first_beat = ceilf(_beat + BeatChain.LEAD_BEATS)
	_center = _place()


func _now() -> float:
	var b: float = clock.call() if clock.is_valid() else Sfx.beat_now()
	return b if not is_nan(b) else _beat


func _period() -> float:
	return Sfx.beat_period()


## The beat now expected: the first that counts, plus one per beat already played.
func _expected() -> float:
	return first_beat + grades.size()


func _process(delta: float) -> void:
	_beat = _now()
	_alpha = minf(1.0, _alpha + delta * 6.0)
	_center = _center.lerp(_place(), 1.0 - exp(-delta * 14.0)) if _center != Vector2.ZERO else _place()
	for p in _popups:
		p["t"] = float(p["t"]) + delta
	_popups = _popups.filter(func(p): return float(p["t"]) < 0.8)
	if _finished:
		_linger += delta
		if _linger >= LINGER and not closed:
			close(grades)
		queue_redraw()
		return
	if practice:
		queue_redraw()
		return
	# test presses, graded exactly where they were meant to fall
	while _injected_next < injected.size() and _injected_next == grades.size():
		var off = injected[_injected_next]
		if off == null:
			break
		var at: float = _expected() + float(off) / _period()
		if _beat < at:
			break
		_injected_next += 1
		_press_at(at)
		if _finished:
			break
	# a beat let go by without a press is a Miss
	if not _finished and _beat > _expected() + BeatChain.late_limit(easy) / _period():
		if _injected_next == grades.size() and _injected_next < injected.size():
			_injected_next += 1
		_grade("miss")
	queue_redraw()


## A press of A on the beat.
func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact"):
		press()
	elif practice and ev.is_action_pressed("ui_cancel"):
		close(offsets)


## A tap on the ring counts as a press (taps anywhere else, and in the touch clusters' zones, do nothing here: the pad
## sends its own A).
func _input(ev: InputEvent) -> void:
	if closed or UI.stack.is_empty() or UI.stack.back() != self or ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var at: Vector2
	if ev is InputEventScreenTouch and ev.pressed:
		at = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		at = ev.position
	else:
		return
	if UI.touch_blocks(at):
		return
	get_viewport().set_input_as_handled()
	if at.distance_to(_center) <= TAP_RADIUS:
		press()


func press() -> void:
	if _finished:
		return
	_press_at(_now())


## Ends the chain early (everyone it aims at is down): the hits so far stand.
func finish() -> void:
	_finished = true


## A press at beat position `b`: graded against the beat it's nearest. Presses before the first beat's half (the cue
## spinning in) and a second press on a beat already played are ignored; one nearer a later beat than the one expected
## means that beat went by unplayed.
func _press_at(b: float) -> void:
	if practice:
		var dt := (b - roundf(b)) * _period()
		offsets.append(dt)
		var g := BeatChain.grade(dt, easy)
		_popups.append({"text": "%+d ms" % int(round(dt * 1000.0)), "t": 0.0, "grade": g})
		return
	var nearest := roundf(b)
	var want := _expected()
	if nearest < want:
		return
	if nearest > want:
		_grade("miss")
		return
	_grade(BeatChain.grade((b - nearest) * _period(), easy))


func _grade(g: String) -> void:
	if _finished:
		return
	var i := grades.size()
	grades.append(g)
	_popups.append({"text": {"perfect": "Perfect", "good": "Good", "miss": "Miss"}[g], "t": 0.0, "grade": g})
	if g == "miss":
		_finished = true
		if i == 0:
			hit.emit(0, "weak")
		else:
			Sfx.play("miss")
		return
	hit.emit(i, g)
	if grades.size() >= most:
		_finished = true


## Where the ring goes: above the target, inside the safe area, under the top bar and clear of the touch clusters.
func _place() -> Vector2:
	var p: Vector2 = anchor.call() if anchor.is_valid() else size * Vector2(0.5, 0.4)
	var safe := UIKit.safe_rect(self)
	var reach := RADIUS * 1.25
	var top := safe.position.y + reach + 12.0
	if UI.top_bar != null and UI.top_bar.visible:
		top = maxf(top, UI.top_bar.get_global_rect().end.y + reach + 12.0)
	var below := 60.0 + UIKit.body_px(32)
	p.x = clampf(p.x, safe.position.x + reach + 120.0, safe.end.x - reach - 120.0)
	p.y = clampf(p.y, top, safe.end.y - reach - below)
	# step up out of a touch cluster's zone (the d-pad and A/B sit low)
	for i in 12:
		if not (UI.touch_blocks(p + Vector2(0, reach)) or UI.touch_blocks(p + Vector2(reach, 0)) or UI.touch_blocks(p - Vector2(reach, 0))):
			break
		p.y -= 24.0
	return p


func _draw() -> void:
	var c := _center
	var a := _alpha
	var frac := fposmod(_beat, 1.0)
	var counting := _beat >= first_beat - 0.5 and not _finished
	# the ring pulses on each beat that counts (the lead-in beats only softly)
	var kick := exp(-frac * 7.0) * (1.0 if counting else 0.4)
	var r := RADIUS * (1.0 + 0.1 * kick)
	var shade := Color(0, 0, 0, 0.42 * a)
	var white := Color(1, 1, 1, a)
	# a landed hit glows round the ring in the gem: a soft band either side of the line, fading out
	if not _popups.is_empty():
		var last: Dictionary = _popups.back()
		var glow := 1.0 - clampf(float(last["t"]) / 0.35, 0.0, 1.0)
		if String(last["grade"]) != "miss" and glow > 0.0:
			for i in 5:
				var col := Color(UIKit.ACCENT, 0.85 * glow * a * (1.0 - float(i) / 5.0))
				draw_arc(c, r + LINE * 0.5 + 2.5 + 3.0 * i, 0.0, TAU, 64, col, 3.5, true)
				draw_arc(c, r - LINE * 0.5 - 2.5 - 3.0 * i, 0.0, TAU, 64, col, 3.5, true)
	draw_arc(c, r, 0.0, TAU, 64, shade, LINE + 5.0, true)
	draw_arc(c, r, 0.0, TAU, 64, white, LINE, true)
	# the mark at the top: where the notch meets the beat
	var top := c + Vector2(0, -r)
	var mark := PackedVector2Array([top + Vector2(-10, -16), top + Vector2(10, -16), top + Vector2(0, -3)])
	draw_colored_polygon(PackedVector2Array([mark[0] + Vector2(-3, -2), mark[1] + Vector2(3, -2), mark[2] + Vector2(0, 4)]), shade)
	draw_colored_polygon(mark, white)
	# the notch, round once a beat, at the top on the beat
	var ang := -PI / 2.0 + TAU * frac
	var notch := c + Vector2(cos(ang), sin(ang)) * r
	draw_circle(notch, 10.0, shade)
	draw_circle(notch, 7.5, Color(1, 1, 1, a * (1.0 if counting else 0.55)))
	var font := UIKit.font_body()
	var px := UIKit.body_px(32)
	if practice and not offsets.is_empty():
		var mean := 0.0
		for o in offsets:
			mean += float(o)
		var line := "Average %+d ms over %d presses" % [int(round(mean / offsets.size() * 1000.0)), offsets.size()]
		var at0 := c + Vector2(-font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5, r + 56.0)
		draw_string_outline(font, at0, line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 8, Color(0, 0, 0, 0.6 * a))
		draw_string(font, at0, line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, white)
	# the pips: one per hit allowed, filled as they land (the gem for a critical finish)
	var gap := 20.0
	var y := c.y + r + 22.0
	var x0 := c.x - gap * (most - 1) * 0.5
	for i in (0 if practice else most):
		var at := Vector2(x0 + gap * i, y)
		draw_circle(at, 8.0, shade)
		if i < grades.size() and String(grades[i]) != "miss":
			var full := grades.size() == most and i == most - 1 and not grades.has("miss")
			draw_circle(at, 6.0, Color(UIKit.ACCENT, a) if full else white)
			if full:
				draw_arc(at, 6.0, 0.0, TAU, 16, white, 1.5, true)
		elif i < grades.size():
			draw_arc(at, 5.5, 0.0, TAU, 16, Color(UIKit.BATTLE_DIM, 0.6 * a), 1.5, true)
		else:
			draw_arc(at, 5.5, 0.0, TAU, 16, white, 2.0, true)
	# the grade of the last press, beside the ring, rising a little as it fades (a newer one replaces it)
	if not _popups.is_empty():
		var p: Dictionary = _popups.back()
		var t := float(p["t"])
		var fade := a * (1.0 - smoothstep(0.45, 0.8, t))
		var text := String(p["text"])
		var at := c + Vector2(r + 18.0, font.get_ascent(px) * 0.35 - 14.0 * smoothstep(0.0, 0.8, t))
		var col := Color(UIKit.BATTLE_DIM, fade) if String(p["grade"]) == "miss" else Color(1, 1, 1, fade)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 8, Color(0, 0, 0, 0.6 * fade))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
