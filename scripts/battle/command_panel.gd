extends "res://scripts/ui/modal.gd"
## Choosing the round's commands (as in Jade Cocoon 2). Nothing of its own is drawn: it drives the move bars and the
## grids of the battle HUD (battle_bars.gd, ring_grid.gd).
##   ◄ / ►  change the chosen bar's action: your own, or the beast's move (the side's element, neutral or Defend)
##   A       confirm it; a move aimed at someone then picks its target with ◄ / ► (a foe on the side facing you, or
##           their trainer when the middle of that side is down) and A
##   B       go back a step
##   ▲ / ▼   move between the beasts; ▲ on the top beast turns the ring anticlockwise, ▼ on the bottom one clockwise
##           (to the next side with a beast standing on it; the beasts' choices are then made afresh)
## You choose your own action first, then the beasts'. When every standing beast has its move, the round begins. The
## bars, the foe's tiles and the target cards can be tapped too.
##
## rows (built by battle.gd) keep their state, so the panel can close for a sub-menu (items, the flute) or a turn of
## the ring and open again where it left off. done emits {"kind": "go"} when everything is chosen, {"kind": "rotate",
## "dir": -1 / 1}, or {"kind": "sub", "row": i} (the chosen option needs battle.gd's own menu).
## rows: [{kind: "trainer" | "beast", beast, options: [{label, target, disabled, desc, sub, move}], sel, done,
##         target_sel, targets: [{label, ref, tile, grid}], status: "" | "down" | "empty", locked}]
## info: {up, down, prompt}; hooks: {render: Callable(rows, focus, picking), hint: Callable(text), point: Callable(ref),
##        bars, foe_grid, ally_grid, cards (to listen for taps)}

var rows: Array = []
var info: Dictionary = {}
var focus := 0
var picking := false
var targets_for: Callable
var hooks: Dictionary = {}


func setup(_rows: Array, _info: Dictionary, _focus: int, _targets_for: Callable, _hooks: Dictionary) -> Control:
	rows = _rows
	info = _info
	focus = clampi(_focus, 0, rows.size() - 1)
	targets_for = _targets_for
	hooks = _hooks
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bars = hooks.get("bars", null)
	if bars != null:
		bars.tapped.connect(_bar_tapped)
	for g in ["foe_grid", "ally_grid"]:
		var grid = hooks.get(g, null)
		if grid != null:
			grid.tile_tapped.connect(_tile_tapped.bind(g))
	var cards = hooks.get("cards", null)
	if cards != null:
		cards.tapped.connect(_card_tapped)
	_point_row()
	_redraw()


func _exit_tree() -> void:
	var bars = hooks.get("bars", null)
	if bars != null and bars.tapped.is_connected(_bar_tapped):
		bars.tapped.disconnect(_bar_tapped)
	for g in ["foe_grid", "ally_grid"]:
		var grid = hooks.get(g, null)
		if grid != null:
			for c in grid.tile_tapped.get_connections():
				grid.tile_tapped.disconnect(c["callable"])
	var cards = hooks.get("cards", null)
	if cards != null and cards.tapped.is_connected(_card_tapped):
		cards.tapped.disconnect(_card_tapped)


func _redraw() -> void:
	if hooks.has("render"):
		(hooks["render"] as Callable).call(rows, focus, picking)
	var text := ""
	if picking:
		text = "Choose a target."
	elif focus == 0 and not rows[0].get("done", false):
		text = String(info.get("prompt", ""))
	_hint(text)


func _hint(text: String) -> void:
	if hooks.has("hint"):
		(hooks["hint"] as Callable).call(text)


## The beasts' bars open once your own action is chosen.
func _row_enabled(i: int) -> bool:
	return i == 0 or rows[0].get("done", false)


# ---------------------------------------------------------------- input
func on_input(ev: InputEvent) -> void:
	if ev.is_echo() and not (ev.is_action("ui_left") or ev.is_action("ui_right")):
		return
	if not ev.is_pressed():
		return
	if ev.is_action_pressed("ui_left", true):
		_cycle(-1)
	elif ev.is_action_pressed("ui_right", true):
		_cycle(1)
	elif ev.is_action_pressed("ui_up"):
		_move(-1)
	elif ev.is_action_pressed("ui_down"):
		_move(1)
	elif ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact"):
		_confirm()
	elif ev.is_action_pressed("ui_cancel"):
		_back()


func _bar_tapped(i: int, zone: String) -> void:
	if closed:
		return
	if i != focus:
		if _row_enabled(i):
			_focus_row(i)
		return
	match zone:
		"left":
			_cycle(-1)
		"right":
			_cycle(1)
		_:
			_confirm()


## Tapping a foe's tile while picking a target aims at it (and confirms when it's already the one aimed at).
func _tile_tapped(tile: int, grid: String) -> void:
	if closed or not picking:
		return
	var row: Dictionary = rows[focus]
	var ts: Array = row.get("targets", [])
	for j in ts.size():
		if int(ts[j].get("tile", -100)) == tile and String(ts[j].get("grid", "")) == grid:
			if j == int(row.get("target_sel", 0)):
				_confirm()
			else:
				row["target_sel"] = j
				Sfx.play("select")
				_point_row()
				_redraw()
			return


## Tapping a target card aims at it (and confirms when it's already the one aimed at).
func _card_tapped(j: int) -> void:
	if closed or not picking:
		return
	var row: Dictionary = rows[focus]
	if j < 0 or j >= (row.get("targets", []) as Array).size():
		return
	if j == int(row.get("target_sel", 0)):
		_confirm()
		return
	row["target_sel"] = j
	Sfx.play("select")
	_point_row()
	_redraw()


func _focus_row(i: int) -> void:
	if i == focus or not _row_enabled(i):
		return
	picking = false
	focus = i
	Sfx.play("select")
	_point_row()
	_redraw()


func _point_row() -> void:
	if not hooks.has("point"):
		return
	var row: Dictionary = rows[focus]
	var ref = null
	if picking:
		var ts: Array = row.get("targets", [])
		ref = ts[clampi(int(row.get("target_sel", 0)), 0, ts.size() - 1)]["ref"] if not ts.is_empty() else null
	else:
		ref = "trainer_self" if row["kind"] == "trainer" else row.get("beast", null)
	(hooks["point"] as Callable).call(ref)


func _cycle(dir: int) -> void:
	var row: Dictionary = rows[focus]
	if row.get("status", "") != "" or row.get("locked", false) or not _row_enabled(focus):
		return
	if picking:
		var ts: Array = row.get("targets", [])
		if ts.size() > 1:
			row["target_sel"] = posmod(int(row.get("target_sel", 0)) + dir, ts.size())
			Sfx.play("select")
			_point_row()
		_redraw()
		return
	var n: int = row["options"].size()
	if n <= 1:
		return
	row["sel"] = posmod(int(row.get("sel", 0)) + dir, n)
	row["done"] = false
	Sfx.play("select")
	_redraw()


## ▲ / ▼: to the next beast that can act (skipping empty slots and fainted beasts); past the top or bottom one, turn
## the ring.
func _move(dir: int) -> void:
	if picking:
		return
	if focus == 0:
		if dir > 0 and rows[0].get("done", false):
			var first := _next_beast(0, 1)
			if first > 0:
				_focus_row(first)
			else:
				_rotate(1)
		return
	var nxt := _next_beast(focus, dir)
	if nxt < 0:
		_rotate(dir)
		return
	_focus_row(nxt)


## The next beast's row from `from` in direction `dir` that can act, or -1.
func _next_beast(from: int, dir: int) -> int:
	var i := from + dir
	while i >= 1 and i < rows.size():
		if rows[i].get("status", "") == "":
			return i
		i += dir
	return -1


func _rotate(dir: int) -> void:
	if not rows[0].get("done", false) or String(info.get("up" if dir < 0 else "down", "")) == "":
		Sfx.play("error")
		return
	close({"kind": "rotate", "dir": dir, "focus": 1 if dir < 0 else rows.size() - 1})


func _confirm() -> void:
	var row: Dictionary = rows[focus]
	if not _row_enabled(focus):
		return
	if row.get("status", "") != "" or row.get("locked", false):
		_advance()
		return
	var o: Dictionary = row["options"][clampi(int(row.get("sel", 0)), 0, row["options"].size() - 1)]
	if o.get("disabled", false):
		Sfx.play("error")
		_hint(String(o.get("desc", "")))
		return
	if picking:
		picking = false
		row["done"] = true
		Sfx.play("confirm")
		_advance()
		return
	if o.get("sub", false):
		Sfx.play("confirm")
		close({"kind": "sub", "row": focus, "focus": focus})
		return
	var kind: String = o.get("target", "none")
	if kind in ["enemy", "ally", "ally_ko"]:
		var ts: Array = targets_for.call(row, o) if targets_for.is_valid() else []
		if ts.is_empty():
			Sfx.play("error")
			_hint("There's no one to use that on right now.")
			return
		row["targets"] = ts
		row["target_sel"] = clampi(int(row.get("target_sel", 0)), 0, ts.size() - 1)
		if ts.size() > 1:
			picking = true
			Sfx.play("confirm")
			_point_row()
			_redraw()
			return
		row["target_sel"] = 0
	else:
		row["targets"] = []
	row["done"] = true
	Sfx.play("confirm")
	_advance()


## After a confirmation: on to the next beast that still needs a move, or begin the round when all are set.
func _advance() -> void:
	for i in range(1, rows.size()):
		var k := posmod(focus - 1 + i, rows.size() - 1) + 1 if focus > 0 else i
		var r: Dictionary = rows[k]
		if r.get("status", "") == "" and not r.get("done", false) and not r.get("locked", false):
			focus = k
			_point_row()
			_redraw()
			return
	if rows[0].get("done", false):
		if hooks.has("point"):
			(hooks["point"] as Callable).call(null)
		close({"kind": "go", "focus": focus})
		return
	focus = 0
	_redraw()


func _back() -> void:
	if picking:
		picking = false
		Sfx.play("back")
		_point_row()
		_redraw()
		return
	var row: Dictionary = rows[focus]
	if row.get("done", false) and not row.get("locked", false):
		row["done"] = false
		Sfx.play("back")
		_redraw()
		return
	if focus > 0:
		# back up to the beast chosen last, or to your own action
		for k in range(focus - 1, 0, -1):
			if rows[k].get("done", false):
				rows[k]["done"] = false
				_focus_row(k)
				return
		if not rows[0].get("locked", false):
			rows[0]["done"] = false
			Sfx.play("back")
			_focus_row(0)
			_redraw()
		return
	Sfx.play("error")
