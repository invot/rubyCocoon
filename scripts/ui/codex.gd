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
## In battle the head stays up (pin); elsewhere it shows only while it talks.

const CodexDB = preload("res://scripts/data/codex_db.gd")
const CodexHead = preload("res://scripts/ui/codex_head.gd")
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
	return head


## Keep the head up (in battle) until unpin().
static func pin() -> void:
	if not has_codex() or UI.auto:
		return
	_pinned = true
	_ensure().visible = true


static func unpin() -> void:
	_pinned = false
	if is_instance_valid(head):
		head.tappable = false
		head.visible = false


## Whether a tap on the head asks a question (battle.gd, while you choose commands).
static func set_tappable(on: bool) -> void:
	if is_instance_valid(head):
		head.tappable = on and _pinned


## The head's tap signal, for battle.gd to connect.
static func tapped() -> Signal:
	return _ensure().tapped


## The Codex says `lines` ("[mood] text"; codex_db.gd), one bubble each, its brows changing with every one.
static func say(lines: Array) -> void:
	if lines.is_empty():
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
		UI.auto_log.append("%s: %s" % [NAME, texts[0]])
		await UI.get_tree().process_frame
		return
	var h := _ensure()
	var shown_before: bool = h.visible
	h.visible = true
	h.set_mood(String(moods[0]))
	var d := DialogBox.new()
	d.setup(texts, NAME)
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
	if not _pinned and not shown_before:
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
	await say(CodexDB.TOPICS[id]["lines"])
	return true


## Several new topics at once, each explained once.
static func chime_all(ids: Array) -> void:
	for id in ids:
		await chime(String(id))


static func explain(id: String) -> void:
	await say(CodexDB.TOPICS[id]["lines"])


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
		var pinned_before := _pinned
		_ensure().visible = true
		var i: int = await UI.choose("What would you like to know?", items, {"start": start, "cancel": true, "rows": 6, "width": 420})
		if i < 0:
			if not pinned_before and is_instance_valid(head):
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


## Mae hands over the Codex: it switches on and says hello.
static func receive() -> void:
	GameState.set_flag("has_codex")
	GameState.set_flag("codex_seen_codex")
	Sfx.play("capture")
	UI.toast("Got the Codex!", "notice")
	await say(["[surprised] Bzzt! Whirr... Oh! Hello!"] + CodexDB.TOPICS["codex"]["lines"])
