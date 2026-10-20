extends "res://scripts/ui/modal.gd"
## Fishing (see scripts/world/fishing.gd): the line is in the water.
##   1. Wait: the float bobs. Maybe something nibbles, maybe not (B reels in).
##   2. Nibble: the float dips. Tap A quickly to strike, or it lets go.
##   3. Reel: every tap of A pulls the line tighter and the tension bar fills; it slackens on its own. Tap it up into
##      the marked zone, then keep it there by tapping at a steady pace while the catch meter fills. Tap too fast and the
##      line goes over the zone and snaps; too slow and it falls slack and the beast slips off.
## opts: bite (seconds until something nibbles; -1: nothing will), strength (0..1, how hard the beast fights: a
## narrower zone, a faster slackening line, longer to land), lesson (a gentler line and a coach's words), coach (their
## name), on_nibble (Callable, to dip the float in the world).
## done emits {"result": "landed" / "nothing" / "missed" / "too_fast" / "too_slow" / "cancelled"}.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

## each tap of A: how much tighter the line pulls (share of the bar)
const TAP := 0.11
## how quickly the line slackens, per second, for the weakest and the strongest beasts
const DRAIN := Vector2(0.3, 0.44)
## the zone: its middle, and how wide it is for the weakest and the strongest beasts
const ZONE_MID := 0.62
const ZONE_W := Vector2(0.26, 0.17)
## seconds in the zone to land it, weakest and strongest
const HOLD := Vector2(3.0, 5.0)
## seconds over the zone before the line snaps, and under it before the beast slips off
const STRAIN_GRACE := 0.5
const SLACK_GRACE := 0.9
## seconds to strike once it nibbles, and to tap the line up into the zone
const STRIKE_TIME := 1.5
const PULL_TIME := 6.0
## how long you wait for nothing before giving up
const NOTHING_AFTER := 7.0

var opts: Dictionary = {}
var phase := "wait"
var tension := 0.0
var progress := 0.0
var strain := 0.0
var slack := 0.0
var _t := 0.0
var _phase_t := 0.0
var _taps := []
var _box: PanelContainer
var _title: Label
var _hint: Label
var _gauge: Control
var _coach_said := {}


func setup(_opts: Dictionary) -> Control:
	opts = _opts
	return self


func _strength() -> float:
	return clampf(float(opts.get("strength", 0.3)), 0.0, 1.0) * (0.4 if opts.get("lesson", false) else 1.0)


func _zone() -> Vector2:
	var w := lerpf(ZONE_W.x, ZONE_W.y, _strength()) * (1.25 if opts.get("lesson", false) else 1.0)
	return Vector2(ZONE_MID - w / 2.0, ZONE_MID + w / 2.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = UIKit.panel(Vector2(620, 0))
	add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_box.add_child(vb)
	_title = UIKit.header("", UIKit.LIGHT, UIKit.HEAD_BIG)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(580, 92)
	_gauge.draw.connect(_draw_gauge)
	vb.add_child(_gauge)
	_hint = UIKit.label("", UIKit.BODY_BIG, UIKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 580
	vb.add_child(_hint)
	UIKit.place(_box, "top_right" if UI.is_touch() else "bottom", Vector2(24, 24))
	_show()


func _show() -> void:
	match phase:
		"wait":
			_title.text = "Waiting for a bite..."
			_hint.text = "B to reel in your line."
		"nibble":
			_title.text = "Something's nibbling!"
			_hint.text = "Tap A to strike!"
		"reel":
			_title.text = "Reel it in!"
			_hint.text = "Tap A to pull the line up into the zone, then keep it there with steady taps. Too fast and it snaps, too slow and it slips away."
	_gauge.visible = phase == "reel"
	_gauge.queue_redraw()


func _coach(key: String, text: String) -> void:
	if not opts.get("lesson", false) or _coach_said.has(key):
		return
	_coach_said[key] = true
	_hint.text = "%s: \"%s\"" % [String(opts.get("coach", "")), text]


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_cancel"):
		if phase == "wait":
			Sfx.play("back")
			close({"result": "cancelled"})
		return
	if not (ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact")):
		return
	match phase:
		"nibble":
			Sfx.play("confirm")
			phase = "reel"
			_phase_t = 0.0
			tension = 0.12
			_show()
			_coach("reel", "Got it! Now tap A, tap A, tap A... and get that marker up into the bright zone!")
		"reel":
			tension += TAP
			_taps.append(_t)
			Sfx.play("blip", 0.25)


func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	match phase:
		"wait":
			var bite := float(opts.get("bite", -1.0))
			if bite >= 0.0 and _phase_t >= bite:
				phase = "nibble"
				_phase_t = 0.0
				Sfx.play("encounter")
				if opts.has("on_nibble"):
					(opts["on_nibble"] as Callable).call()
				_show()
				_coach("nibble", "There! The float's dipping! Strike now: tap A!")
			elif bite < 0.0 and _phase_t >= NOTHING_AFTER:
				close({"result": "nothing"})
		"nibble":
			if _phase_t >= STRIKE_TIME * (2.0 if opts.get("lesson", false) else 1.0):
				Sfx.play("fail")
				close({"result": "missed"})
		"reel":
			_reel(delta)
	if phase == "reel":
		_gauge.queue_redraw()


func _reel(delta: float) -> void:
	var lesson: bool = opts.get("lesson", false)
	var s := _strength()
	tension = maxf(0.0, tension - lerpf(DRAIN.x, DRAIN.y, s) * delta)
	var z := _zone()
	if tension >= 1.0:
		_lose("too_fast")
		return
	if tension > z.y:
		strain += delta
		slack = maxf(0.0, slack - delta)
		_coach("fast", "Easy, easy! Not so fast, or the line will snap!")
	elif tension < z.x:
		# still pulling it up into the zone for the first time: no rush yet
		if progress <= 0.0:
			if _phase_t > PULL_TIME * (3.0 if lesson else 1.0):
				_lose("too_slow")
				return
		else:
			slack += delta
			_coach("slow", "Faster! The line's going slack!")
		strain = maxf(0.0, strain - delta)
	else:
		progress += delta / lerpf(HOLD.x, HOLD.y, s) * (1.25 if lesson else 1.0)
		strain = maxf(0.0, strain - delta * 2.0)
		slack = maxf(0.0, slack - delta * 2.0)
		_coach("zone", "That's it! Keep tapping at that pace and hold it right there.")
	var grace := 2.0 if lesson else 1.0
	if strain > STRAIN_GRACE * grace:
		_lose("too_fast")
		return
	if slack > SLACK_GRACE * grace:
		_lose("too_slow")
		return
	if progress >= 1.0:
		Sfx.play("levelup")
		close({"result": "landed"})


func _lose(why: String) -> void:
	Sfx.play("fail")
	close({"result": why})


## The tension bar (the zone bright in the gem, the marker coloured by how it's going) over the catch meter.
func _draw_gauge() -> void:
	var w := _gauge.size.x
	var bar := Rect2(10, 8, w - 20, 34)
	var z := _zone()
	_gauge.draw_rect(bar.grow(3), UIKit.BORDER)
	_gauge.draw_rect(bar, UIKit.WINDOW_BOTTOM)
	var zr := Rect2(bar.position.x + bar.size.x * z.x, bar.position.y, bar.size.x * (z.y - z.x), bar.size.y)
	_gauge.draw_rect(zr, Color(UIKit.ACCENT, 0.85))
	# the danger end: the last tenth, where the line snaps
	_gauge.draw_rect(Rect2(bar.position.x + bar.size.x * 0.9, bar.position.y, bar.size.x * 0.1, bar.size.y), Color(0.85, 0.2, 0.2, 0.35))
	var col := UIKit.LIGHT
	if tension > z.y:
		col = Color("#ff6a4a")
	elif tension < z.x and progress > 0.0:
		col = Color("#f0c040")
	var x := bar.position.x + bar.size.x * clampf(tension, 0.0, 1.0)
	var wob := sin(_t * 30.0) * minf(strain * 6.0, 3.0)
	_gauge.draw_rect(Rect2(x - 4 + wob, bar.position.y - 6, 8, bar.size.y + 12), Color.BLACK)
	_gauge.draw_rect(Rect2(x - 3 + wob, bar.position.y - 5, 6, bar.size.y + 10), col)
	var font := UIKit.font_body()
	var fs := UIKit.body_px(UIKit.BODY_SMALL)
	_gauge.draw_string(font, Vector2(bar.position.x, bar.end.y + 22), "Slack", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.DIM)
	_gauge.draw_string(font, Vector2(bar.end.x - 46, bar.end.y + 22), "Snap!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.DIM)
	# the catch meter
	var pm := Rect2(bar.position.x + 90, bar.end.y + 10, bar.size.x - 180, 14)
	_gauge.draw_rect(pm.grow(2), UIKit.BORDER)
	_gauge.draw_rect(pm, UIKit.WINDOW_BOTTOM)
	_gauge.draw_rect(Rect2(pm.position, Vector2(pm.size.x * clampf(progress, 0.0, 1.0), pm.size.y)), UIKit.hp_color(1.0))
