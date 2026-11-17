extends RefCounted
## The Codex: the little orange robot head Picnicker Mae gives you after the Coastal Path's lessons
## (scripts/data/codex_db.gd has its topics). It talks from a small window at the top-left of the screen
## (codex_head.gd), its white speech bubbles hanging under it; its brows change with every bubble, and now and then it
## starts one with a beep or a boop.
##   Codex.chime(id)   the first time something new comes up in battle: it explains it once
##   Codex.ask()       the list of topics you may ask about (its battle row "Codex ?", a tap on it, the Start book)
##   Codex.explain(id) one topic
## Its chime-ins can be switched off ("codex_off", the Start book's Settings); on a journey played for hours before
## the Codex existed it switches them off itself, saying so (veteran).
## In battle the head stays up (pin) while its tips are on; with them off, and everywhere else, it shows only while it
## talks or you ask it something.

const CodexDB = preload("res://scripts/data/codex_db.gd")
const CodexHead = preload("res://scripts/ui/codex_head.gd")
const CodexSkip = preload("res://scripts/ui/codex_skip.gd")
const DialogBox = preload("res://scripts/ui/dialog_box.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")

const NAME := "Codex"
## The moods a line without one may take (codex_head.gd MOODS).
const EASY_MOODS := ["happy", "curious", "excited", "proud", "neutral"]
## How often a talk starts one of its bubbles with a beep (codex_db.gd BEEPS).
const BEEP_CHANCE := 0.4

static var head: Control = null
static var _pinned := false
static var _last_mood := ""
## Whether its question list is up (a tap on the head then does nothing).
static var _asking := false
## battle.gd's say on a tap while you choose commands: true if it took the tap (it closes its panel and asks).
static var tap_handler := Callable()
## A lesson in progress (begin_lesson / end_lesson nest), whether it was skipped, and battle.gd's hooks: on_lesson(on)
## as one starts and ends (the stage's simulation look), on_skip() when it is skipped.
static var _lesson_depth := 0
static var _skipped := false
static var on_lesson := Callable()
static var on_skip := Callable()
static var _skip_ui: Control = null
## The topic of the lesson running now (its first chime), so a skip is remembered against it.
static var _lesson_topic := ""
## Whether the lesson running now has really started (_activate).
static var _active := false
static var _dialog: Control = null


static func has_codex() -> bool:
	return CodexDB.has_codex()


static func _ensure() -> Control:
	if not is_instance_valid(head):
		head = CodexHead.new()
		head.visible = false
		UI.root.add_child(head)
		# over the menus and the top bar, under the screen fades; its glow under the menus (see _glow_under)
		UI.root.move_child(head, UI.top_bar.get_index() + 1)
		UI.modal_layer.add_child(head.glow)
		UI.modal_layer.move_child(head.glow, 0)
		head.tapped.connect(_on_tapped)
		head.tappable = true
	return head


## A tap on the head, whenever it shows: its question list comes up (pausing whatever is going on), unless it's up
## already. In battle the battle takes the tap (tap_handler): between its menus while you choose, else at its next
## message or action, since a paused tree would freeze its films while the battle's script ran on.
static func _on_tapped() -> void:
	if _asking or not has_codex():
		return
	if tap_handler.is_valid() and bool(tap_handler.call()):
		return
	var tree := UI.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	await ask()
	tree.paused = was_paused


## Whether a press at screen point `at` lands on the head (or its Skip lesson button) while it takes taps, so screens
## that catch every press themselves (the battle's command panel) leave it to them.
static func hit(at: Vector2) -> bool:
	if is_instance_valid(head) and head.is_visible_in_tree() and head.tappable and head.get_global_rect().has_point(at):
		return true
	return is_instance_valid(_skip_ui) and _skip_ui.is_visible_in_tree() and _skip_ui.get_global_rect().has_point(at)


## Keep the head up (in battle) until unpin(); with its tips switched off ("codex_off") it stays hidden between talks.
static func pin() -> void:
	if not has_codex() or UI.auto:
		return
	_pinned = true
	_ensure().visible = _shown()


static func unpin() -> void:
	_pinned = false
	tap_handler = Callable()
	on_lesson = Callable()
	on_skip = Callable()
	_lesson_depth = 0
	_active = false
	_skipped = false
	if is_instance_valid(_skip_ui):
		_skip_ui.visible = false
	if is_instance_valid(head):
		head.visible = false


## Whether the head stays up between talks: pinned in battle, with its tips on.
static func _shown() -> bool:
	return _pinned and not GameState.flag("codex_off")


## The head reacts to the battle while it's up (its tips on): `mood` (codex_head.gd MOODS: "sad" when one of yours
## faints, "excited" when a foe does...) for `secs`, bouncing if `bounce` (a win). Nothing while it's talking or off.
static func react(mood: String, secs := 2.5, bounce := false) -> void:
	if not is_instance_valid(head) or not head.visible or head.talking or not _shown():
		return
	head.react(mood, secs, bounce)


## A lesson begins: the battle's stage turns into the Codex's simulation (on_lesson) and "Hold B: Skip lesson" shows
## beside the head. Lessons nest (a chime inside a longer lesson); the outermost one decides.
static func begin_lesson() -> void:
	if not has_codex():
		return
	_lesson_depth += 1
	if _lesson_depth > 1:
		return
	_skipped = false
	_lesson_topic = ""
	_active = false


## The lesson really starts (its first chime speaks): the simulation and the skip button come up. A lesson that ends
## up teaching nothing (its topic told long ago) never shows either.
static func _activate() -> void:
	if _active or _lesson_depth <= 0:
		return
	_active = true
	if UI.auto:
		if on_lesson.is_valid():
			on_lesson.call(true)
		return
	var h := _ensure()
	if not is_instance_valid(_skip_ui):
		_skip_ui = CodexSkip.new()
		UI.root.add_child(_skip_ui)
		UI.root.move_child(_skip_ui, h.get_index() + 1)
		_skip_ui.skip.connect(skip)
	_skip_ui.visible = true
	_skip_ui.place_beside(Rect2(h.global_position, h.size))
	if on_lesson.is_valid():
		on_lesson.call(true)


static func end_lesson() -> void:
	if _lesson_depth <= 0:
		return
	_lesson_depth -= 1
	if _lesson_depth > 0:
		return
	_lesson_topic = ""
	if not _active:
		return
	_active = false
	if is_instance_valid(_skip_ui):
		_skip_ui.visible = false
	if on_lesson.is_valid():
		on_lesson.call(false)


static func in_lesson() -> bool:
	return _lesson_depth > 0


## Whether the lesson running now was skipped (its remaining talk and practice are left out).
static func skipped() -> bool:
	return _lesson_depth > 0 and _skipped


## Skips the lesson running now: its bubble closes, the rest of its talk is left out, and the battle ends any practice.
static func skip() -> void:
	if _lesson_depth <= 0 or _skipped:
		return
	_skipped = true
	if _lesson_topic != "":
		GameState.set_flag("codex_skipped_" + _lesson_topic)
	Sfx.play("back")
	if is_instance_valid(_skip_ui):
		_skip_ui.visible = false
	if is_instance_valid(_dialog) and not _dialog.closed:
		_dialog.close()
	if on_skip.is_valid():
		on_skip.call()


## The Codex says `lines` ("[mood] text"; codex_db.gd), one bubble each, its brows changing with every one.
static func say(lines: Array) -> void:
	if lines.is_empty() or skipped():
		return
	var parsed: Array = lines.map(func(l): return CodexDB.parse(String(l)))
	if randf() < BEEP_CHANCE:
		var k := randi() % parsed.size()
		parsed[k] = [parsed[k][0], "%s %s" % [CodexDB.BEEPS[randi() % CodexDB.BEEPS.size()], parsed[k][1]]]
	var moods := []
	for p in parsed:
		var m := String(p[0])
		if m == "" or m == _last_mood:
			# no two bubbles in a row share a face
			var pool: Array = EASY_MOODS.filter(func(x): return x != _last_mood)
			m = String(pool[randi() % pool.size()])
		moods.append(m)
		_last_mood = m
	var texts: Array = parsed.map(func(p): return String(p[1]))
	if UI.auto:
		UI.auto_log.append("%s: %s" % [GameState.codex_name(), texts[0]])
		await UI.get_tree().process_frame
		return
	var h := _ensure()
	var shown_before: bool = h.visible
	h.visible = true
	h.set_mood(String(moods[0]))
	var d := DialogBox.new()
	d.setup(texts, GameState.codex_name())
	d.anchor_control = h
	# its own pixel voice (UIKit.font_codex), in a wider bubble since the face is wide
	d.speech_font = UIKit.font_codex()
	d.speech_font_size = UIKit.CODEX_SIZE
	d.speech_line_gap = UIKit.CODEX_LINE_GAP
	d._speech_width = 860.0
	d.page_shown.connect(func(src: int) -> void:
		if is_instance_valid(h):
			h.set_mood(String(moods[clampi(src, 0, moods.size() - 1)])))
	UI.push(d)
	_dialog = d
	# the glow just under this bubble (over any menu it's asked from), so it never washes over the words
	if is_instance_valid(h.glow):
		var at := d.get_index()
		UI.modal_layer.move_child(h.glow, at - 1 if h.glow.get_index() < at else at)
	while is_instance_valid(d) and not d.closed:
		h.talking = d.typing()
		await UI.get_tree().process_frame
	h.talking = false
	if is_instance_valid(h.glow) and h.glow.get_parent() == UI.modal_layer:
		UI.modal_layer.move_child(h.glow, 0)
	if not _shown() and not shown_before:
		h.visible = false


## A little two-note beep as the Codex chimes in (it doesn't hold up the bubble).
static func _beep() -> void:
	Sfx.tone(1320.0, 0.06, "square", -22.0)
	UI.get_tree().create_timer(0.08).timeout.connect(func() -> void: Sfx.tone(1760.0, 0.08, "square", -22.0))


## The first time `id` comes up: the Codex explains it (once; afterwards it's yours to ask about). True if it did.
static func chime(id: String) -> bool:
	# (switched off: nothing is marked as told, so turning it back on still explains it)
	if not has_codex() or GameState.flag("codex_off") or GameState.flag("codex_seen_" + id) or not CodexDB.TOPICS.has(id):
		return false
	GameState.set_flag("codex_seen_" + id)
	if not CodexDB.eligible(id):
		GameState.set_flag("codex_seen_" + id, false)
		return false
	if not UI.auto:
		_beep()
	begin_lesson()
	_activate()
	if _lesson_topic == "":
		_lesson_topic = id
	await say(CodexDB.TOPICS[id]["lines"])
	end_lesson()
	return true


## Topics the Coastal Path's trainers teach (and "codex", its hello): the Codex only answers questions about them, so
## they're no lesson of its own.
const BASICS := ["codex", "attack", "defend", "turns", "items", "slingshot", "run"]


## The Codex's achievement (the user's 2026-11-15 direction): every one of its lessons taught to the end, none ever
## skipped (a skip can't be made up), with its tips on. Then once a battle it heals your beasts in the red
## (battle.gd _codex_heal).
static func mastered() -> bool:
	if not has_codex() or GameState.flag("codex_off"):
		return false
	for id in CodexDB.TOPICS:
		if BASICS.has(id):
			continue
		if not GameState.flag("codex_seen_" + String(id)) or GameState.flag("codex_skipped_" + String(id)):
			return false
	return true


## Several new topics at once, each explained once.
static func chime_all(ids: Array) -> void:
	for id in ids:
		await chime(String(id))


static func explain(id: String) -> void:
	# (asked for: a skipped lesson doesn't silence it)
	var was := _skipped
	_skipped = false
	await say(CodexDB.TOPICS[id]["lines"])
	_skipped = was


## The topics you may ask about, until you back out with B.
static func ask() -> void:
	if not has_codex():
		return
	var start := 0
	while true:
		var ids := []
		var items := []
		for g in CodexDB.menu():
			for id in g["ids"]:
				ids.append(id)
				items.append(CodexDB.title(id))
		if ids.is_empty():
			return
		_ensure().visible = true
		_asking = true
		head.tappable = false
		var i: int = await UI.choose("What would you like to know?", items, {"start": start, "cancel": true, "rows": 6, "width": 420})
		_asking = false
		if is_instance_valid(head):
			head.tappable = true
		if i < 0:
			# (still up if it was talking when you tapped it)
			if not _shown() and is_instance_valid(head) and not (is_instance_valid(_dialog) and not _dialog.closed):
				head.visible = false
			return
		start = i
		await explain(String(ids[i]))


## A journey played for hours before the Codex existed (GameState.codex_veteran): it says it's switching its tips off.
static func veteran() -> void:
	if not GameState.codex_veteran or not has_codex():
		return
	GameState.codex_veteran = false
	GameState.set_flag("codex_off")
	if not UI.auto:
		_beep()
	await say(["[surprised] Beep! Whoa, look at all these battles you've won. You're an old hand!",
		"[proud] You don't need my tips, so I'm switching them off. Bzzt.",
		"[happy] You can turn them back on from the Settings page of your Start book. And you can still ask me anything!"])
	# tips off: the head leaves the battle screen until it's asked something
	if is_instance_valid(head):
		head.visible = _shown()


## Mae hands over the Codex: it switches on and says hello.
static func receive() -> void:
	GameState.set_flag("has_codex")
	GameState.set_flag("codex_seen_codex")
	Sfx.play("capture")
	UI.toast(GameState.codex_text("Got the Codex!"), "notice")
	if UI.auto:
		await say(["[surprised] Bzzt! Whirr... Oh! Hello!"] + CodexDB.TOPICS["codex"]["lines"])
		return
	# it swirls up into the middle of the screen to introduce itself, then settles in its corner (the user's
	# 2026-11-15 direction)
	var h := _ensure()
	_whoosh()
	await h.swirl_in()
	_beep()
	await say(["[surprised] Bzzt! Whirr... Oh! Hello!"] + CodexDB.TOPICS["codex"]["lines"])
	h.visible = true
	await h.fly_home()
	if not _shown():
		h.visible = false


## A rising swirl of notes as the Codex flies in.
static func _whoosh() -> void:
	for i in 8:
		UI.get_tree().create_timer(0.16 * i).timeout.connect(func() -> void: Sfx.tone(440.0 * pow(1.19, i), 0.1, "triangle", -20.0))
