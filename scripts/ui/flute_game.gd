extends "res://scripts/ui/modal.gd"
## The flute minigame: sheet music you read, then play.
##   1. Listen (only while learning a song, or when someone else plays it): the song plays once and each note lights
##      up on the staff. The clock waits. A song you already know (in battle, practising) skips this: the sheet is up
##      and it's your turn straight away.
##   2. Study: the sheet stays up and the clock is running.
##   3. Play: play the notes in order; the sheet stays up the whole time, the notes you have played lit.
## Each staff position is a button: ← → A B from the bottom line up; higher-level songs add ↓ and ↑ above them.
## Two stacked notes are a chord: A or B pressed together with a direction.
## The timer bar shrinks green → yellow → orange → red, and the colour you finish in sets the song's power
## (green: full, red: about half). Each wrong note breaks a heart and costs a little power; the right note then
## peeks out. Three wrong notes, or running out of time, and the song fails.
## Modes: "play" (no listening first), "learn" (it plays once, then you play it back to learn the song; `goal` sets the
## bar to pass), "demo" (someone else plays it).
## opts: mode, goal, performer (who plays it while you listen), level (default: the song's level), lesson (true: a
## teacher's lesson: the beginner's 30-second clock, and the song always plays through before your turn).
## done emits {"acc": 0..1, "mistakes", "cancelled", "failed": "" / "time" / "misses", "zone": 0..3}.

const SongDB = preload("res://scripts/data/song_db.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const EdgeButton = preload("res://scripts/ui/edge_button.gd")
const FrameBox = preload("res://scripts/ui/frame_box.gd")
## the sheet: the world map's aged paper, its torn edges kept unstretched
const PAPER = preload("res://assets/ui/world_map/paper.png")
## the sheet's ink: staff lines and its quieter text
const SEPIA := Color("#3d2a17")
const SEPIA_DIM := Color("#6e5434")
## note heads are ovals tipped up to the right, like printed sheet music
const HEAD_RX := 1.22
const HEAD_RY := 0.9
const HEAD_TILT := -0.35
## the result card pops in over this long
const POP_TIME := 0.45
## the "A: Dismiss" button (and A) waits this long after the card appears
const DISMISS_DELAY := 1.0
## a prompt icon's drawn size over the note head's
const PROMPT_SCALE := 1.3

## note colours, by button: ← → A B ↑ ↓
const BTN_COLORS := [Color("#e8603a"), Color("#3f8fe0"), Color("#c8384e"), Color("#d89a28"), Color("#4fa860"), Color("#8a5ad0")]
## The timer's colours. `until`: share of the time used; `power`: what finishing in that colour is worth.
const ZONES := [
	{"until": 0.4, "col": Color("#5cb85c"), "power": 1.0, "name": "green"},
	{"until": 0.65, "col": Color("#e8c547"), "power": 0.85, "name": "yellow"},
	{"until": 0.85, "col": Color("#f08a3c"), "power": 0.7, "name": "orange"},
	{"until": 1.0, "col": Color("#d8443c"), "power": 0.5, "name": "red"},
]
## power kept after 0, 1 and 2 wrong notes
const SLIP_POWER := [1.0, 0.85, 0.7]
const LIVES := 3
## Each button's control prompt, by SongDB.BTN_* (left, right, A, B, up, down).
const PROMPTS := [preload("res://assets/ui/icons/prompts/left.png"), preload("res://assets/ui/icons/prompts/right.png"),
	preload("res://assets/ui/icons/prompts/a.png"), preload("res://assets/ui/icons/prompts/b.png"),
	preload("res://assets/ui/icons/prompts/up.png"), preload("res://assets/ui/icons/prompts/down.png")]
## seconds allowed between the two halves of a chord (unless the first is still held down)
const CHORD_WINDOW := 0.35
## pause before the first note while listening
const LISTEN_LEAD := 0.8
## half a staff space, in pixels
const STEP_PX := 20.0
const HEAD_R := 18.0

var song_id := "weaken"
var mode := "play"
## learn mode: {"accuracy": 0.5} or {"no_mistakes": true}
var goal: Dictionary = {}
var performer := ""
var subtitle := ""
var song: Dictionary
var level := 1
var melody: Array = []
var time_limit := 30.0
## listen, study, play, result
var phase := "listen"
## the next note to play
var pos := 0
var mistakes := 0
var cancelled := false
var failed := ""
var zone := 0
## a teacher's lesson (see setup)
var lesson := false
var _clock := 0.0
var _listen_t := 0.0
var _lit := -1
var _spb := 0.6
## chord half pressed -> clock time
var _chord := {}
var _pop := {}
var _wrong := {}
var _peek := 0.0
var _shake := 0.0
var _result_t := 0.0
var _panel_rect := Rect2()
## the result card, and the "A: Dismiss" button under its right end
var _card_rect := Rect2()
var _dismiss: Control
var _card_box: StyleBoxFlat
## each button's outlined prompt (a note not played yet), by SongDB.BTN_*; the filled one while it's still to be baked
static var _outlines: Array = []


func setup(_song_id: String, _subtitle := "", time_bonus := 0.0, opts := {}) -> Control:
	song_id = _song_id
	mode = opts.get("mode", "play")
	goal = opts.get("goal", {})
	performer = opts.get("performer", "")
	song = SongDB.get_song(song_id)
	subtitle = _subtitle
	dim = 0.45
	level = int(opts.get("level", GameState.song_level(song_id)))
	melody = SongDB.melody(song_id, level)
	lesson = opts.get("lesson", false)
	var base: float = SongDB.TUTORIAL_TIME if lesson else SongDB.BASE_TIME
	time_limit = SongDB.time_limit(melody.size(), base) * (1.0 + time_bonus)
	_spb = clampf(60.0 / float(song.get("bpm", 90)), 0.42, 0.7)
	# only a song being learned (or someone else's) plays by itself; a known one is yours to play straight away
	if mode == "play":
		phase = "study"
	return self


func _ready() -> void:
	# (the hearts and the notes' control prompts are smooth icons, shrunk from their baked size)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Sfx.music("")
	if UI.controls:
		UI.controls.set_flute_mode(true)


func _exit_tree() -> void:
	if UI.controls:
		UI.controls.set_flute_mode(false)


func _process(delta: float) -> void:
	for k in _pop.keys():
		_pop[k] = maxf(0.0, float(_pop[k]) - delta * 3.0)
	_peek = maxf(0.0, _peek - delta)
	_shake = maxf(0.0, _shake - delta)
	if not _wrong.is_empty():
		_wrong["t"] = float(_wrong["t"]) - delta
		if float(_wrong["t"]) <= 0.0:
			_wrong = {}
	queue_redraw()
	match phase:
		"listen":
			_listen(delta)
		"study", "play":
			_clock += delta
			_check_chord()
			if _clock >= time_limit and phase != "result":
				_fail("time")
		"result":
			# the card stays up until you dismiss it
			_result_t += delta
			if _result_t >= DISMISS_DELAY and _dismiss == null:
				_dismiss = EdgeButton.new().setup("A: Dismiss", true)
				_dismiss.pressed.connect(_on_dismiss)
				add_child(_dismiss)
			if _dismiss:
				_dismiss.place_under(Rect2(get_global_rect().position + _card_rect.position, _card_rect.size))


func _listen(delta: float) -> void:
	_listen_t += delta
	var k := int(floor((_listen_t - LISTEN_LEAD) / _spb))
	if k > _lit and k < melody.size():
		_lit = k
		_play_note(melody[k])
		_pop[k] = 1.0
	if _listen_t >= LISTEN_LEAD + _spb * melody.size() + 0.5:
		_end_listen()


func _end_listen() -> void:
	_lit = -1
	if mode == "demo":
		phase = "result"
		return
	phase = "study"


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	var b := _button_of(ev)
	if phase == "result":
		if _confirm(ev) and _result_t >= DISMISS_DELAY:
			_on_dismiss()
		return
	# Esc / Pause stop the song (S and B are a note)
	if ev.is_action_pressed("pause") or (ev.is_action_pressed("ui_cancel") and b < 0):
		Sfx.play("back")
		cancelled = true
		close(_result())
		return
	if b < 0:
		return
	match phase:
		"listen":
			# a lesson's song always plays through: the teacher's turn, then yours
			if not lesson:
				_end_listen()
		"study":
			phase = "play"
			_press(b)
		"play":
			_press(b)


func _on_dismiss() -> void:
	Sfx.play("confirm")
	close(_result())


func _button_of(ev: InputEvent) -> int:
	for i in 6:
		if ev.is_action_pressed("flute_%d" % (i + 1)):
			return i
	return -1


func _confirm(ev: InputEvent) -> bool:
	return ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact") or ev.is_action_pressed("flute_3")


func _press(b: int) -> void:
	var want: Array = melody[pos]
	if not want.has(b):
		_slip(b)
		return
	if want.size() > 1:
		_chord[b] = _clock
		if not _chord_done(want):
			Sfx.flute_note(SongDB.note_freq(song_id, b))
			return
	_hit()


## Both halves of the chord pressed close together (or the first still held down).
func _chord_done(want: Array) -> bool:
	for b in want:
		if not _chord.has(b):
			return false
		if _clock - float(_chord[b]) > CHORD_WINDOW and not Input.is_action_pressed("flute_%d" % (int(b) + 1)):
			return false
	return true


## Half a chord that was let go without the other half is a slip.
func _check_chord() -> void:
	var let_go := false
	for b in _chord:
		if _clock - float(_chord[b]) > CHORD_WINDOW and not Input.is_action_pressed("flute_%d" % (int(b) + 1)):
			let_go = true
	if let_go:
		_slip(-1)


func _hit() -> void:
	_play_note(melody[pos])
	_pop[pos] = 1.0
	_chord.clear()
	pos += 1
	if pos >= melody.size():
		phase = "result"
		zone = _zone_at(_clock / time_limit)
		Sfx.play("confirm")


func _slip(b: int) -> void:
	mistakes += 1
	_chord.clear()
	Sfx.play("squeak")
	_wrong = {"btn": b, "t": 0.5}
	_peek = 1.2
	_shake = 0.3
	if mistakes >= LIVES:
		_fail("misses")


func _fail(kind: String) -> void:
	failed = kind
	phase = "result"
	zone = ZONES.size() - 1
	Sfx.play("fail")


func _play_note(note: Array) -> void:
	for b in note:
		Sfx.flute_note(SongDB.note_freq(song_id, int(b)))


func _zone_at(used: float) -> int:
	for i in ZONES.size():
		if used < float(ZONES[i]["until"]):
			return i
	return ZONES.size() - 1


## 0..1: the timer colour you finished in, less a little for each wrong note. 0 if the song failed.
func accuracy() -> float:
	if failed != "" or cancelled or mode == "demo" or pos < melody.size():
		return 0.0
	return float(ZONES[zone]["power"]) * float(SLIP_POWER[mini(mistakes, SLIP_POWER.size() - 1)])


func passed() -> bool:
	if failed != "" or cancelled or pos < melody.size():
		return false
	if goal.get("no_mistakes", false) and mistakes > 0:
		return false
	return accuracy() >= float(goal.get("accuracy", 0.0))


func _result() -> Dictionary:
	# notes never played count as mistakes
	var slips := mistakes + (melody.size() - pos if mode != "demo" else 0)
	return {"acc": accuracy(), "mistakes": slips, "cancelled": cancelled, "failed": failed, "zone": zone}


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	super._draw()
	var font := UIKit.font_body()
	var hfont := UIKit.font_head()
	var touch: bool = UI.is_touch()
	var w := minf(1040.0, size.x - 32.0)
	var h := 412.0
	var avail := size.y - UI.bottom_reserve()
	var top := 12.0 if touch else roundf(maxf(12.0, (avail - h) / 2.0))
	_panel_rect = Rect2(roundf((size.x - w) / 2.0), top, w, h)
	var pr := _panel_rect
	if _shake > 0.0:
		pr.position.x += roundf(sin(_shake * 70.0) * 7.0 * _shake / 0.3)
	draw_style_box(UIKit.box("textfield"), pr)
	_draw_paper(pr)

	# header: song, who's playing, hearts, level
	draw_string(hfont, pr.position + Vector2(28, 46), song["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 330, UIKit.head_px(32), UIKit.HEAD)
	if subtitle != "":
		draw_multiline_string(font, pr.position + Vector2(28, 76), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w - 330, UIKit.body_px(22), 2, SEPIA_DIM)
	var hx := pr.end.x - 28.0 - LIVES * 40.0
	if mode == "demo":
		draw_string(font, Vector2(pr.end.x - 300, pr.position.y + 46), "♫ %s plays" % (performer if performer != "" else "Listen"), HORIZONTAL_ALIGNMENT_RIGHT, 272, UIKit.body_px(22), SEPIA)
	else:
		for i in LIVES:
			var ht: Texture2D = UIKit.tex("heart" if i < LIVES - mistakes else "heart_empty")
			if ht:
				draw_texture_rect(ht, Rect2(hx + i * 40.0, pr.position.y + 24, 33, 33), false)
	draw_string(font, Vector2(pr.end.x - 300, pr.position.y + 94), "Lv %d  ·  %d notes" % [level, melody.size()], HORIZONTAL_ALIGNMENT_RIGHT, 272, UIKit.body_px(22), SEPIA_DIM)

	# what to do now
	var status := ""
	match phase:
		"listen":
			if mode == "learn":
				status = ("%s plays it first. Listen..." % performer) if performer != "" else "Listen first..."
			else:
				status = ("%s plays..." % performer) if performer != "" else "Listen..."
			if not lesson:
				status += "   (press any note to skip)"
		"study":
			status = "Your turn! Play the notes from left to right."
		"play":
			status = "Note %d of %d" % [mini(pos + 1, melody.size()), melody.size()]
	if phase == "study":
		# your turn: on a chip in the gem, its edge pulsing until the first note
		var tw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(22)).x + 40.0
		var chip := Rect2(roundf(pr.get_center().x - tw / 2.0), pr.position.y + 98, roundf(tw), 40)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		draw_style_box(UIKit.chip(UIKit.ACCENT, UIKit.LIGHT.lerp(UIKit.BORDER_INNER, pulse), 10.0, Vector4.ZERO, 3.0), chip)
		draw_string(font, Vector2(pr.position.x, pr.position.y + 126), status, HORIZONTAL_ALIGNMENT_CENTER, w, UIKit.body_px(22), UIKit.LIGHT)
	elif status != "":
		draw_string(font, Vector2(pr.position.x, pr.position.y + 126), status, HORIZONTAL_ALIGNMENT_CENTER, w, UIKit.body_px(22), SEPIA)

	# the staff, in sepia ink. Chords with neighbouring notes put one head beside the other, so they get a wider slot.
	var legend_w := 64.0
	var units := []
	var total_units := 0.0
	for note in melody:
		var wide := _side_by_side(note)
		units.append(total_units + 0.5)
		total_units += 1.7 if wide else 1.0
	var spacing := minf(110.0, (w - 72.0 - legend_w - 40.0) / total_units)
	var staff_w := legend_w + 16.0 + spacing * total_units + 24.0
	var staff_l := roundf(pr.get_center().x - staff_w / 2.0)
	var staff_r := staff_l + staff_w
	var notes_l := staff_l + legend_w + 16.0
	var base_y := pr.position.y + 304.0
	# faint ink, so the notes stand out
	var ink := Color(SEPIA, 0.22)
	for k in 5:
		var ly := base_y - k * 2.0 * STEP_PX
		draw_line(Vector2(staff_l, ly), Vector2(staff_r, ly), ink, 2.0, true)
	var top_y := base_y - 8.0 * STEP_PX
	draw_line(Vector2(staff_l, top_y), Vector2(staff_l, base_y), ink, 2.0)
	draw_line(Vector2(staff_r - 7, top_y), Vector2(staff_r - 7, base_y), ink, 2.0)
	draw_line(Vector2(staff_r - 1, top_y), Vector2(staff_r - 1, base_y), Color(SEPIA, 0.35), 4.0)
	# which button each line and space is
	var u := SongDB.unlocks(song_id, level)
	var used := [SongDB.BTN_LEFT, SongDB.BTN_RIGHT, SongDB.BTN_A, SongDB.BTN_B]
	if u["up"]:
		used.append(SongDB.BTN_UP)
	if u["down"]:
		used.append(SongDB.BTN_DOWN)
	for b in used:
		var st: int = SongDB.BTN_STEP[b]
		var lc := Vector2(staff_l + legend_w / 2.0 + (-13.0 if st % 2 == 0 else 13.0), base_y - st * STEP_PX)
		_draw_prompt(PROMPTS[b], lc, 13.0, BTN_COLORS[b])
	draw_line(Vector2(staff_l + legend_w, top_y), Vector2(staff_l + legend_w, base_y), Color(SEPIA, 0.15), 2.0)

	# the notes
	for i in melody.size():
		var x := notes_l + spacing * float(units[i])
		_draw_note(melody[i], x, base_y, 1.0, float(_pop.get(i, 0.0)), i == _lit, _played(i))
	# where you are
	var cur := _lit if phase == "listen" else pos
	if cur >= 0 and cur < melody.size() and phase != "result":
		var cx := notes_l + spacing * float(units[cur])
		draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y + 16), Vector2(cx - 10, base_y + 30), Vector2(cx + 10, base_y + 30)]), UIKit.ACCENT)
		if phase == "play" and _peek > 0.0:
			_draw_note(melody[pos], cx, base_y, minf(1.0, _peek) * 0.55, 0.0, false, true)
		if not _wrong.is_empty() and int(_wrong["btn"]) >= 0:
			var wb: int = _wrong["btn"]
			var wc := Vector2(cx, base_y - SongDB.BTN_STEP[wb] * STEP_PX)
			var wa := clampf(float(_wrong["t"]) / 0.5, 0.0, 1.0)
			_draw_head(wc, HEAD_R, Color("#d8443c", wa))
			draw_line(wc + Vector2(-10, -10), wc + Vector2(10, 10), Color(UIKit.LIGHT, wa), 4.0)
			draw_line(wc + Vector2(-10, 10), wc + Vector2(10, -10), Color(UIKit.LIGHT, wa), 4.0)

	# the timer: shrinks and changes colour, no numbers
	var bar := Rect2(staff_l, base_y + 42, staff_w, 28)
	if mode != "demo":
		draw_style_box(UIKit.box("bar_frame"), bar)
		var inner := bar.grow(-6)
		var left := clampf(1.0 - _clock / time_limit, 0.0, 1.0)
		var zi := _zone_at(_clock / time_limit) if phase != "result" else zone
		var col: Color = ZONES[zi]["col"]
		if phase == "listen":
			col.a = 0.55
		elif zi == ZONES.size() - 1 and phase != "result" and int(_clock * 6.0) % 2 == 0:
			col = col.lightened(0.25)
		if left > 0.0:
			draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * left), inner.size.y)), col)
			draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * left), 4)), col.lightened(0.35))

	if phase == "result":
		_draw_result(pr, font, hfont)


## The aged paper inside the window: strongest at its sides, fading out toward the middle, so the staff sits on the
## window's own off-white. Clipped to the window's rounded shape, with the window's bezel drawn back over it.
func _draw_paper(pr: Rect2) -> void:
	const STRIPS := 24
	const SIDE_ALPHA := 0.9
	var rad: float = FrameBox.RADIUS["window"]
	var shape := UIKit.round_rect(pr, rad)
	# the paper's middle, cropped to the window's shape (its torn edges stay out of sight)
	var ts := PAPER.get_size()
	var uv := Rect2(0.06, 0.08, 0.88, 0.84)
	var want := (pr.size.x / pr.size.y) / ((ts.x * uv.size.x) / (ts.y * uv.size.y))
	if want > 1.0:
		var hh := uv.size.y / want
		uv = Rect2(uv.position.x, uv.position.y + (uv.size.y - hh) / 2.0, uv.size.x, hh)
	else:
		var ww := uv.size.x * want
		uv = Rect2(uv.position.x + (uv.size.x - ww) / 2.0, uv.position.y, ww, uv.size.y)
	for i in STRIPS:
		var x0 := pr.position.x + pr.size.x * float(i) / STRIPS
		var x1 := pr.position.x + pr.size.x * float(i + 1) / STRIPS
		var slab := PackedVector2Array([Vector2(x0, pr.position.y - 1), Vector2(x1, pr.position.y - 1), Vector2(x1, pr.end.y + 1), Vector2(x0, pr.end.y + 1)])
		for piece in Geometry2D.intersect_polygons(shape, slab):
			var cols := PackedColorArray()
			var uvs := PackedVector2Array()
			for p in piece:
				var t := (p - pr.position) / pr.size
				var side := absf(t.x - 0.5) * 2.0
				cols.append(Color(1, 1, 1, SIDE_ALPHA * smoothstep(0.12, 0.95, side)))
				uvs.append(uv.position + t * uv.size)
			draw_polygon(piece, cols, uvs, PAPER)
	FrameBox.draw_bezel(get_canvas_item(), pr, Vector4(rad, rad, rad, rad))


## The outcome on a card in its own colour that pops in with a bounce, notes bursting out of it; it stays until you
## dismiss it (A, or the "A: Dismiss" button under its right end).
func _draw_result(pr: Rect2, font: Font, hfont: Font) -> void:
	var title := ""
	var line := ""
	var col := Color("#3f8fe0")
	var happy := true
	var slips := "no slips" if mistakes == 0 else ("%d slip%s" % [mistakes, "" if mistakes == 1 else "s"])
	if mode == "demo":
		title = "That's how it goes!"
		line = "Now it's your turn."
	elif failed == "time":
		title = "Out of time!"
		line = "The song fizzled out before the end."
		col = Color("#8a63b8")
		happy = false
	elif failed == "misses":
		title = "Too many wrong notes!"
		line = "The melody fell apart."
		col = Color("#8a63b8")
		happy = false
	else:
		line = "Finished in the %s  ·  %s  ·  power %d%%" % [String(ZONES[zone]["name"]).to_upper(), slips, int(round(accuracy() * 100))]
		col = [Color("#3fa45a"), Color("#d39a12"), Color("#e9772c"), Color("#d8443c")][zone]
		if mode == "learn":
			title = "You've got it!" if passed() else "Not quite..."
			if not passed():
				col = Color("#e9772c")
				happy = false
				if goal.get("no_mistakes", false):
					line = "%s: it has to be flawless" % slips.capitalize()
		elif mistakes == 0 and zone == 0:
			title = "Masterful!"
		else:
			title = ["Full power!", "Strong!", "A bit shaky...", "Just made it!"][zone]
	var t := _result_t
	var card_size := Vector2(minf(640.0, pr.size.x - 80.0), 156.0)
	var centre := pr.get_center() + Vector2(0, 18)
	_card_rect = Rect2(centre - card_size / 2.0, card_size)
	# the burst of notes, behind the card
	_draw_burst(centre, card_size, col, happy, t)
	# pop in: overshoot, then a wobble that settles
	var k := clampf(t / POP_TIME, 0.0, 1.0)
	var s := _back_out(k)
	var tilt := sin(t * 13.0) * exp(-t * 4.0) * 0.09
	draw_set_transform(centre, tilt, Vector2(s, s))
	var r := Rect2(-card_size / 2.0, card_size)
	# the windows' shape, soft shadow and bezel (frame_box.gd), in the outcome's colour
	var rad: float = FrameBox.RADIUS["window"]
	if _card_box == null:
		_card_box = StyleBoxFlat.new()
		_card_box.anti_aliasing = true
		_card_box.corner_detail = 6
		_card_box.set_corner_radius_all(int(rad))
		_card_box.shadow_color = FrameBox.SHADOW
		_card_box.shadow_size = 10
		_card_box.shadow_offset = Vector2(0, 3)
	_card_box.bg_color = col
	draw_style_box(_card_box, r)
	FrameBox.draw_bezel(get_canvas_item(), r, Vector4(rad, rad, rad, rad), 1.0, true, col)
	# the title, its letters bouncing in a wave (a happy card) or drooping in turn (a sad one)
	var tpx := UIKit.head_px(40)
	var tw := hfont.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	var x := -tw / 2.0
	var shadow := col.darkened(0.45)
	for i in title.length():
		var ch := title[i]
		var dy := 0.0
		if happy:
			dy = -absf(sin(t * 5.0 - i * 0.45)) * 7.0
		else:
			dy = maxf(0.0, sin(t * 2.5 - i * 0.35)) * 4.0
		var p := Vector2(x, r.position.y + 70 + dy).round()
		draw_string(hfont, p + Vector2(0, 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Color(shadow, 0.6))
		draw_string(hfont, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, UIKit.LIGHT)
		x += hfont.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	draw_string(font, Vector2(r.position.x, r.position.y + 114), line, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UIKit.body_px(22), UIKit.LIGHT)
	# two little notes on the card's top corners, dancing (or drooping)
	for side in [-1.0, 1.0]:
		var bob := sin(t * 6.0 + side) * 5.0 if happy else 0.0
		var nc := Vector2(side * (r.size.x / 2.0 - 34.0), r.position.y + 2 + bob)
		_draw_little_note(nc, 15.0, Color(UIKit.LIGHT, 0.95), (0.25 * side) if happy else (0.6 * side))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Notes fly out of the card as it lands (up and away when happy, tumbling down when not), then fade.
func _draw_burst(centre: Vector2, card: Vector2, col: Color, happy: bool, t: float) -> void:
	const N := 12
	var life := 1.3
	if t > life:
		return
	var e := 1.0 - pow(1.0 - t / life, 3.0)
	for i in N:
		var ang := TAU * float(i) / N + 0.3 * sin(i * 7.1)
		var dir := Vector2(cos(ang), sin(ang) * 0.55)
		var dist := (card.x * 0.42) + (120.0 + 60.0 * fmod(i * 0.618, 1.0)) * e
		var p := centre + dir * dist
		p.y += (-50.0 if happy else 70.0) * e
		var tint: Color = BTN_COLORS[i % BTN_COLORS.size()] if happy else col.lightened(0.2)
		_draw_little_note(p, 11.0 + 4.0 * fmod(i * 0.37, 1.0), Color(tint, 1.0 - t / life), sin(t * 8.0 + i) * 0.4)


## A quaver: an oval head, a stem and a flag.
func _draw_little_note(c: Vector2, r: float, col: Color, ang := 0.0) -> void:
	var rot := Transform2D(ang, c)
	var head := _ellipse(Vector2.ZERO, r * HEAD_RX, r * HEAD_RY, HEAD_TILT, 16)
	draw_colored_polygon(rot * head, col)
	var sx := r * HEAD_RX * 0.9
	draw_line(rot * Vector2(sx, -r * 0.2), rot * Vector2(sx, -r * 3.2), col, maxf(2.0, r * 0.22))
	draw_colored_polygon(rot * PackedVector2Array([Vector2(sx, -r * 3.2), Vector2(sx + r * 1.3, -r * 2.2), Vector2(sx + r * 1.0, -r * 1.6), Vector2(sx, -r * 2.4)]), col)


## Easing that overshoots and settles back: the card's pop.
static func _back_out(k: float) -> float:
	const C1 := 2.4
	const C3 := C1 + 1.0
	var m := k - 1.0
	return 1.0 + C3 * m * m * m + C1 * m * m


## A note already played: heard while listening, or played on your turn (all of them once someone else's song ends).
func _played(i: int) -> bool:
	match phase:
		"listen":
			return i <= _lit
		"result":
			return mode == "demo" or i < pos
	return i < pos


## One note (or chord) on the staff: each head is its button's prompt in the button's colour, outlined until it's
## played; then it swells and comes back filled. No stems.
func _draw_note(note: Array, x: float, base_y: float, a: float, pop := 0.0, glow := false, played := false) -> void:
	var hi := -1
	for b in note:
		hi = maxi(hi, SongDB.BTN_STEP[b])
	# the pulse: grows over its first half, still outlined, and shrinks back filled
	var k := 1.0 - pop
	var r := HEAD_R * (1.0 + 0.5 * sin(k * PI) * (1.0 if pop > 0.0 else 0.0))
	var filled := played and (pop <= 0.0 or k >= 0.5)
	for b in note:
		var st: int = SongDB.BTN_STEP[b]
		var hx := x
		# neighbouring notes in a chord sit side by side, so neither hides the other
		if _side_by_side(note) and st == hi:
			hx += HEAD_R * 2.16
		var c := Vector2(hx, base_y - st * STEP_PX)
		var col: Color = BTN_COLORS[b]
		if glow:
			draw_circle(c, r + 8.0, Color(col, 0.25 * a))
		var tex: Texture2D = PROMPTS[b] if filled else _outline(b)
		_draw_prompt(tex, c, r, Color(col, a))


## A prompt icon centred on `c`, `r` across its half, tinted.
func _draw_prompt(tex: Texture2D, c: Vector2, r: float, col: Color) -> void:
	# (the baked icons leave a margin round the shape, so they're drawn a little larger than the head)
	var half := r * PROMPT_SCALE
	draw_texture_rect(tex, Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), false, col)


func _outline(b: int) -> Texture2D:
	if _outlines.is_empty():
		for i in PROMPTS.size():
			var path: String = (PROMPTS[i] as Texture2D).resource_path.replace(".png", "_outline.png")
			_outlines.append(load(path) if ResourceLoader.exists(path) else PROMPTS[i])
	return _outlines[b]


## The wrong note's mark: a filled red oval.
func _draw_head(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(_ellipse(c, r * HEAD_RX, r * HEAD_RY, HEAD_TILT, 28), col)


func _ellipse(c: Vector2, rx: float, ry: float, ang: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rot := Transform2D(ang, c)
	for i in segs:
		var a := TAU * float(i) / segs
		pts.append(rot * Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A chord whose notes are on neighbouring staff steps: its heads sit side by side.
func _side_by_side(note: Array) -> bool:
	return note.size() > 1 and absi(int(SongDB.BTN_STEP[note[0]]) - int(SongDB.BTN_STEP[note[1]])) == 1
