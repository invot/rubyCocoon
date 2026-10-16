extends "res://scripts/ui/modal.gd"
## The flute minigame: sheet music you memorise, then play back from memory.
##   1. Listen: the flute plays the song once and each note lights up on the staff. The clock waits.
##   2. Study: the sheet stays up, but the clock is running.
##   3. Play: your first note hides the sheet. Play the rest in order from memory.
## Each staff position is a button: ← → A B from the bottom line up; higher-level songs add ↓ and ↑ above them.
## Two stacked notes are a chord: A or B pressed together with a direction.
## The timer bar shrinks green → yellow → orange → red, and the colour you finish in sets the song's power
## (green: full, red: about half). Each wrong note breaks a heart and costs a little power; the right note then
## peeks out. Three wrong notes, or running out of time, and the song fails.
## Modes: "play", "learn" (play it back to learn the song; `goal` sets the bar to pass), "demo" (someone else plays it).
## opts: mode, goal, performer, level (default: the song's level), coach (speaker name: a step-by-step walkthrough),
## lesson (true: the beginner's 30-second clock).
## done emits {"acc": 0..1, "mistakes", "cancelled", "failed": "" / "time" / "misses", "zone": 0..3}.

const SongDB = preload("res://scripts/data/song_db.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

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
## seconds allowed between the two halves of a chord (unless the first is still held down)
const CHORD_WINDOW := 0.35
## pause before the first note while listening
const LISTEN_LEAD := 0.8
## half a staff space, in pixels
const STEP_PX := 20.0
const HEAD_R := 18.0
## The walkthrough. "when": before listening ("start") or once the song has been heard ("listened");
## "focus": what it points at.
const COACH := [
	{"when": "start", "focus": "staff", "text": "This is sheet music! A song is a short row of notes. You read it from left to right."},
	{"when": "start", "focus": "legend", "text": "Each line and space on the staff is one of your buttons. From the bottom: ← on the bottom line, → just above it, then A, then B."},
	{"when": "start", "focus": "staff", "text": "Bigger songs add higher notes, ↑ and then ↓. The biggest have chords: two notes stacked on one stem, pressed at the same time."},
	{"when": "start", "focus": "staff", "text": "First, just listen. The song plays once, and each note lights up as it sounds."},
	{"when": "listened", "focus": "timer", "text": "Your turn! This bar is your time. As soon as I stop talking, it starts to shrink."},
	{"when": "listened", "focus": "timer", "text": "Finish while it's green and the song works at full power. Yellow and orange are weaker. In the red it's only half as strong, and if the bar runs out, the song fails."},
	{"when": "listened", "focus": "hearts", "text": "These hearts are your slips. A wrong note breaks one, and the right note peeks out to help you. Break all three and the song falls apart."},
	{"when": "listened", "focus": "staff", "text": "Read the notes and remember them. The moment you play your first note, the sheet hides! Play the rest from memory. Ready? Go!"},
]

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
var coach_name := ""
var _clock := 0.0
var _listen_t := 0.0
var _lit := -1
var _spb := 0.6
var _hidden := false
## chord half pressed -> clock time
var _chord := {}
var _pop := {}
var _wrong := {}
var _peek := 0.0
var _shake := 0.0
var _result_t := 0.0
var _coach_steps: Array = []
var _coach_line := {}
var _focus := {}
var _panel_rect := Rect2()


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
	var base: float = SongDB.TUTORIAL_TIME if opts.get("lesson", false) or opts.get("coach", "") != "" else SongDB.BASE_TIME
	time_limit = SongDB.time_limit(melody.size(), base) * (1.0 + time_bonus)
	_spb = clampf(60.0 / float(song.get("bpm", 90)), 0.42, 0.7)
	coach_name = String(opts.get("coach", ""))
	if coach_name != "":
		_coach_steps = COACH.duplicate(true)
	return self


func _ready() -> void:
	Sfx.music("")
	if UI.controls:
		UI.controls.set_flute_mode(true)
	_coach("start")


func _exit_tree() -> void:
	if UI.controls:
		UI.controls.set_flute_mode(false)


## Shows the next walkthrough line for this moment, if there is one.
func _coach(when: String) -> void:
	if not _coach_steps.is_empty() and _coach_steps[0]["when"] == when:
		_coach_line = _coach_steps.pop_front()
		Sfx.play("select")
	else:
		_coach_line = {}


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
	if not _coach_line.is_empty():
		return
	match phase:
		"listen":
			_listen(delta)
		"study", "play":
			_clock += delta
			_check_chord()
			if _clock >= time_limit and phase != "result":
				_fail("time")
		"result":
			_result_t += delta
			if _result_t > 3.0:
				close(_result())


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
	_coach("listened")


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or not ev.is_pressed():
		return
	var b := _button_of(ev)
	if phase == "result":
		if _confirm(ev) and _result_t > 0.4:
			close(_result())
		return
	# Esc / Pause stop the song (S and B are a note)
	if ev.is_action_pressed("pause") or (ev.is_action_pressed("ui_cancel") and b < 0):
		Sfx.play("back")
		cancelled = true
		close(_result())
		return
	if not _coach_line.is_empty():
		if _confirm(ev):
			_coach(_coach_line["when"])
		return
	if b < 0:
		return
	match phase:
		"listen":
			_end_listen()
		"study":
			_hidden = true
			phase = "play"
			_press(b)
		"play":
			_press(b)


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
	var top := 12.0 if touch or coach_name != "" else roundf(maxf(12.0, (avail - h) / 2.0))
	_panel_rect = Rect2(roundf((size.x - w) / 2.0), top, w, h)
	var pr := _panel_rect
	if _shake > 0.0:
		pr.position.x += roundf(sin(_shake * 70.0) * 7.0 * _shake / 0.3)
	draw_style_box(UIKit.box("textfield"), pr)

	# header: song, who's playing, hearts, level
	draw_string(hfont, pr.position + Vector2(28, 46), song["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 330, UIKit.head_px(32), UIKit.ACCENT)
	if subtitle != "":
		draw_multiline_string(font, pr.position + Vector2(28, 76), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w - 330, UIKit.body_px(22), 2, UIKit.DIM)
	var hx := pr.end.x - 28.0 - LIVES * 40.0
	_focus["hearts"] = Rect2(hx - 8, pr.position.y + 16, LIVES * 40.0 + 12, 52)
	if mode == "demo":
		draw_string(font, Vector2(pr.end.x - 300, pr.position.y + 46), "♫ %s plays" % (performer if performer != "" else "Listen"), HORIZONTAL_ALIGNMENT_RIGHT, 272, UIKit.body_px(22), UIKit.INK)
	else:
		for i in LIVES:
			var ht: Texture2D = UIKit.tex("heart" if i < LIVES - mistakes else "heart_empty")
			if ht:
				draw_texture(ht, Vector2(hx + i * 40.0, pr.position.y + 24))
	draw_string(font, Vector2(pr.end.x - 300, pr.position.y + 94), "Lv %d  ·  %d notes" % [level, melody.size()], HORIZONTAL_ALIGNMENT_RIGHT, 272, UIKit.body_px(22), UIKit.DIM)

	# what to do now
	var status := ""
	match phase:
		"listen":
			status = ("%s plays..." % performer) if mode == "demo" and performer != "" else "Listen..."
			if coach_name == "" and _coach_line.is_empty():
				status += "   (press any note to skip)"
		"study":
			status = "Memorise it! Your first note hides the sheet."
		"play":
			status = "From memory!   Note %d of %d" % [mini(pos + 1, melody.size()), melody.size()]
	if status != "":
		draw_string(font, Vector2(pr.position.x, pr.position.y + 126), status, HORIZONTAL_ALIGNMENT_CENTER, w, UIKit.body_px(22), UIKit.INK)

	# the staff. Chords with neighbouring notes put one head beside the stem, so they get a wider slot.
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
	var ink := Color(UIKit.INK, 0.75)
	for k in 5:
		var ly := base_y - k * 2.0 * STEP_PX
		draw_line(Vector2(staff_l, ly), Vector2(staff_r, ly), ink, 2.0)
	var top_y := base_y - 8.0 * STEP_PX
	draw_line(Vector2(staff_l, top_y), Vector2(staff_l, base_y), ink, 2.0)
	draw_line(Vector2(staff_r - 7, top_y), Vector2(staff_r - 7, base_y), ink, 2.0)
	draw_line(Vector2(staff_r - 1, top_y), Vector2(staff_r - 1, base_y), UIKit.INK, 4.0)
	_focus["staff"] = Rect2(staff_l - 10, top_y - 56, staff_w + 20, 8.0 * STEP_PX + 90)
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
		draw_circle(lc, 12.0, BTN_COLORS[b])
		_draw_glyph(b, lc, 12.0, UIKit.LIGHT, 16)
	draw_line(Vector2(staff_l + legend_w, top_y), Vector2(staff_l + legend_w, base_y), Color(UIKit.INK, 0.3), 2.0)
	_focus["legend"] = Rect2(staff_l - 8, base_y - 6.0 * STEP_PX - 16, legend_w + 12, 6.0 * STEP_PX + 32)

	# the notes
	for i in melody.size():
		var x := notes_l + spacing * float(units[i])
		var shown := not _hidden or i < pos
		if shown:
			var a := 1.0
			if phase == "listen":
				a = 1.0 if i <= _lit else 0.4
			_draw_note(melody[i], x, base_y, a, float(_pop.get(i, 0.0)), i == _lit)
		else:
			draw_arc(Vector2(x, base_y - 4.0 * STEP_PX), HEAD_R - 2.0, 0, TAU, 20, Color(UIKit.DIM, 0.55), 2.0)
	# where you are
	var cur := _lit if phase == "listen" else pos
	if cur >= 0 and cur < melody.size() and phase != "result":
		var cx := notes_l + spacing * float(units[cur])
		draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y + 16), Vector2(cx - 10, base_y + 30), Vector2(cx + 10, base_y + 30)]), UIKit.ACCENT)
		if phase == "play" and _peek > 0.0:
			_draw_note(melody[pos], cx, base_y, minf(1.0, _peek) * 0.55)
		if not _wrong.is_empty() and int(_wrong["btn"]) >= 0:
			var wb: int = _wrong["btn"]
			var wc := Vector2(cx, base_y - SongDB.BTN_STEP[wb] * STEP_PX)
			var wa := clampf(float(_wrong["t"]) / 0.5, 0.0, 1.0)
			draw_circle(wc, HEAD_R, Color("#d8443c", wa))
			draw_line(wc + Vector2(-10, -10), wc + Vector2(10, 10), Color(UIKit.LIGHT, wa), 4.0)
			draw_line(wc + Vector2(-10, 10), wc + Vector2(10, -10), Color(UIKit.LIGHT, wa), 4.0)

	# the timer: shrinks and changes colour, no numbers
	var bar := Rect2(staff_l, base_y + 42, staff_w, 28)
	_focus["timer"] = bar.grow(8)
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
	if not _coach_line.is_empty():
		_draw_coach(pr, font, hfont)


func _draw_result(pr: Rect2, font: Font, hfont: Font) -> void:
	var title := ""
	var line := ""
	var slips := "no slips" if mistakes == 0 else ("%d slip%s" % [mistakes, "" if mistakes == 1 else "s"])
	if mode == "demo":
		title = "That's how it goes!"
		line = "Now it's your turn."
	elif failed == "time":
		title = "Out of time!"
		line = "The song fizzled out before the end."
	elif failed == "misses":
		title = "Too many wrong notes!"
		line = "The melody fell apart."
	else:
		line = "Finished in the %s  ·  %s  ·  power %d%%" % [String(ZONES[zone]["name"]).to_upper(), slips, int(round(accuracy() * 100))]
		if mode == "learn":
			title = "You've got it!" if passed() else "Not quite..."
			if not passed() and goal.get("no_mistakes", false):
				line = "%s: it has to be flawless" % slips.capitalize()
		elif mistakes == 0 and zone == 0:
			title = "Masterful!"
		else:
			title = ["Full power!", "Strong!", "A bit shaky...", "Just made it!"][zone]
	var box := Rect2(pr.get_center() - Vector2(280, 34), Vector2(560, 128))
	draw_style_box(UIKit.box("banner"), box)
	draw_string(hfont, box.position + Vector2(0, 56), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UIKit.head_px(32), UIKit.ACCENT)
	draw_string(font, box.position + Vector2(0, 98), line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UIKit.body_px(22), UIKit.INK)


## The walkthrough line under the sheet, with a glowing frame around what it talks about.
func _draw_coach(pr: Rect2, font: Font, hfont: Font) -> void:
	var f: String = _coach_line.get("focus", "")
	if _focus.has(f):
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(_focus[f], Color(UIKit.ORANGE, pulse), false, 4.0)
	var bw := minf(700.0, size.x - 32.0)
	var box := Rect2(roundf((size.x - bw) / 2.0), pr.end.y + 10, bw, 140)
	draw_style_box(UIKit.box("dialogue"), box)
	draw_string(hfont, box.position + Vector2(28, 36), coach_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(16), UIKit.ACCENT)
	draw_multiline_string(font, box.position + Vector2(28, 64), _coach_line["text"], HORIZONTAL_ALIGNMENT_LEFT, bw - 56, UIKit.body_px(22), 3, UIKit.INK)
	if int(Time.get_ticks_msec() / 400) % 2 == 0:
		var p := box.end - Vector2(40, 22)
		draw_string(hfont, p + Vector2(-26, 2), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(16), UIKit.ACCENT)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -12), p + Vector2(6, -6), p + Vector2(-6, 0)]), UIKit.ACCENT)


## One note (or chord) on the staff: coloured heads with the button on them, and a stem.
func _draw_note(note: Array, x: float, base_y: float, a: float, pop := 0.0, glow := false) -> void:
	var lo := 99
	var hi := -1
	for b in note:
		lo = mini(lo, SongDB.BTN_STEP[b])
		hi = maxi(hi, SongDB.BTN_STEP[b])
	var r := HEAD_R * (1.0 + pop * 0.35)
	var stem_x := x + HEAD_R - 1.5
	draw_line(Vector2(stem_x, base_y - lo * STEP_PX), Vector2(stem_x, base_y - (hi + 3.2) * STEP_PX), Color(UIKit.INK, a), 3.0)
	for b in note:
		var st: int = SongDB.BTN_STEP[b]
		var hx := x
		# neighbouring notes in a chord sit either side of the stem, like real sheet music
		if _side_by_side(note) and st == hi:
			hx += HEAD_R * 2.0 - 3.0
		var c := Vector2(hx, base_y - st * STEP_PX)
		var col: Color = BTN_COLORS[b]
		if glow:
			draw_circle(c, r + 9.0, Color(col, 0.3 * a))
		draw_circle(c, r, Color(col, a))
		draw_arc(c, r, 0, TAU, 24, Color(col.darkened(0.5), a), 2.0)
		_draw_glyph(b, c, 18.0, Color(UIKit.LIGHT, a), 32)


## A chord whose notes are on neighbouring staff steps: its heads sit either side of the stem.
func _side_by_side(note: Array) -> bool:
	return note.size() > 1 and absi(int(SongDB.BTN_STEP[note[0]]) - int(SongDB.BTN_STEP[note[1]])) == 1


## The button's mark: an arrow, or A / B.
func _draw_glyph(b: int, c: Vector2, s: float, col: Color, font_px := 16) -> void:
	if b == SongDB.BTN_A or b == SongDB.BTN_B:
		var dy := 11.0 if font_px >= 32 else 6.0
		draw_string(UIKit.font_head(), Vector2(c.x - 30, roundf(c.y + dy)), "A" if b == SongDB.BTN_A else "B", HORIZONTAL_ALIGNMENT_CENTER, 60, UIKit.head_px(font_px), col)
		return
	var ang := 0.0
	match b:
		SongDB.BTN_LEFT:
			ang = PI
		SongDB.BTN_UP:
			ang = -PI / 2.0
		SongDB.BTN_DOWN:
			ang = PI / 2.0
	var hs := s / 2.0
	draw_set_transform(c.round(), ang, Vector2.ONE)
	draw_rect(Rect2(-hs, -s / 6.0, hs + 1.0, s / 3.0), col)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -hs), Vector2(hs, 0), Vector2(0, hs)]), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
