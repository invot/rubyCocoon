extends Control
## Only the current chooser's bar and brief HP changes, pinned to the live 3D stage. One bar shows at a time, for you
## first and then each beast in turn: ◄ its level and action ►, with a beast's HP and MP under it (the MP the move
## would spend flashes). While aiming the same bar reads "Bite ► Tadlet" and ◄ ► change the target. It slides out
## from behind its model and rests beside it, clear of the other creatures. What the action does, and the target's
## HP, is said in the top bar.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
## Between a box's border and its contents.
const PAD := 16.0
## Between a pinned box and the model it belongs to.
const GAP := 10.0
const SLIDE_TIME := 0.22
## A resting place is kept until another is this much better (overlapped UI units squared), so boxes do not flicker.
const STICKY := 2500.0
const CAP_W := 74.0
const GAUGE_H := 10.0
const GAUGE_GAP := 12.0
const MP_COLOR := Color("#a9c8ff")

var battle: Node
var actor = null
var option := {}
var row := {}
## The bar names a target (◄ ► aim, A confirms) after the chooser's action.
var aiming := false
var menu_rect := Rect2()
var action_rect := Rect2()
var tag_rects := {}
var hp_changes := {}
var _clock := 0.0
var _pressed := ""
var _pressed_until := 0.0
var _window: StyleBox
var _selected: StyleBox
var _solid: StyleBox
var _paragraphs := {}
var _can_cycle := true
var _slide := 1.0
var _menu_spot := -1
var _menu_from := Vector2.ZERO
var _tag_spots := {}
var _clip: Control
var _menu: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window = UIKit.box("window", Vector4(PAD, PAD, PAD, PAD))
	_selected = UIKit.highlight()
	_solid = UIKit.pressed_row()
	# The control is drawn inside a clip that ends at its model, so it appears from behind it.
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_menu = Control.new()
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.draw.connect(_draw_menu)
	_clip.add_child(_menu)


func choose(ref, data: Dictionary, move: Dictionary, aim := false) -> void:
	if not is_same(ref, actor) or aim != aiming:
		_slide = 0.0
		_menu_spot = -1
	actor = ref
	row = data
	option = move
	aiming = aim
	if aim:
		_can_cycle = (data.get("targets", []) as Array).size() > 1 and not data.get("target_all", false)
	else:
		var options: Array = data.get("options", [])
		_can_cycle = (options.filter(func(o): return not o.get("disabled", false)).size() if battle.tutorial else options.size()) > 1
	_paragraphs.clear()
	layout()
	queue_redraw()
	_menu.queue_redraw()


func clear_choice() -> void:
	actor = null
	option = {}
	aiming = false
	menu_rect = Rect2()
	action_rect = Rect2()
	queue_redraw()
	_menu.queue_redraw()


func hp_changed(ref) -> void:
	hp_changes[ref] = _clock + 1.15


func _process(delta: float) -> void:
	_clock += delta
	_slide = minf(1.0, _slide + delta / SLIDE_TIME)
	for ref in hp_changes.keys():
		if hp_changes[ref] <= _clock or not battle.nodes.has(ref):
			hp_changes.erase(ref)
			_tag_spots.erase(ref)
	layout()
	queue_redraw()
	_menu.queue_redraw()


func _paragraph(text: String, width: float, heading := false, px := 26) -> TextParagraph:
	var key := "%s:%d:%d:%s" % [heading, px, int(width), text]
	if not _paragraphs.has(key):
		var p := TextParagraph.new()
		p.add_string(text, UIKit.font_head() if heading else UIKit.font_body(), UIKit.head_px(px) if heading else UIKit.body_px(px))
		p.width = width
		p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		_paragraphs[key] = p
	return _paragraphs[key]


func _name(ref) -> String:
	if typeof(ref) == TYPE_INT:
		return battle.Ring.slot_name(ref)
	if typeof(ref) == TYPE_STRING:
		return String(battle.trainer.get("name", "Trainer")) if ref == "foe_trainer" else GameState.player_name
	return ref.nickname


func _snap(at: Vector2) -> Vector2:
	var scale := get_viewport().get_screen_transform().get_scale()
	return (at * scale).round() / scale


## The screen footprint of a beast, trainer or pad: what a pinned box must stay off.
func model_rect(ref) -> Rect2:
	var head: Vector2 = battle.screen_anchor(ref)
	var foot: Vector2 = battle.screen_anchor(ref, 0.0)
	var h := maxf(foot.y - head.y, 36.0)
	var half := maxf(28.0, h * 0.5)
	return Rect2(head.x - half, foot.y - h, half * 2.0, h)


## Everyone on the stage except `skip`.
func _others(skip) -> Array:
	var out := []
	for beast in battle.nodes:
		if not is_same(beast, skip) and battle._ref_pos(beast) != null:
			out.append(model_rect(beast))
	for trainer in (["trainer_self"] if battle.wild else ["trainer_self", "foe_trainer"]):
		if not is_same(trainer, skip):
			out.append(model_rect(trainer))
	# a targeted or struck trainer's shield orbs stay in view
	var k: Vector2 = get_viewport_rect().size / battle.cam.get_viewport().get_visible_rect().size
	for team in battle._shield_orbs:
		for orb in battle._shield_orbs[team]:
			if orb.visible:
				out.append(Rect2(battle.cam.unproject_position(orb.position) * k - Vector2(22, 22), Vector2(44, 44)))
	return out


func _overlap(a: Rect2, b: Rect2) -> float:
	return a.intersection(b).get_area() if a.intersects(b) else 0.0


## A box pinned beside `ref`: to its right or left (level, raised or lowered), above or below, whichever keeps it
## furthest off the other creatures (`avoid`) and the touch clusters. `spot` is the place it had last frame.
## Returns {rect, spot, from (where it slides out from, hidden behind the model), clip (what the model leaves visible)}.
func pin(ref, extent: Vector2, avoid: Array, spot := -1) -> Dictionary:
	var safe := UIKit.safe_rect(self).grow(-16.0)
	safe.position.y = maxf(safe.position.y, UI.top_bar.bottom() + 10.0)
	safe.size.y = UIKit.safe_rect(self).end.y - 16.0 - safe.position.y
	var body := model_rect(ref)
	var mid := body.get_center()
	var zones := []
	if UI.is_touch():
		for group in UI.controls.CLUSTERS:
			var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
			if zone.has_area():
				zones.append(zone.grow(6.0))
	var places := []
	for lift in [0.0, -0.45, 0.45]:
		places.append(Vector2(body.end.x + GAP, mid.y - extent.y * 0.5 + extent.y * lift))
		places.append(Vector2(body.position.x - GAP - extent.x, mid.y - extent.y * 0.5 + extent.y * lift))
	places.append(Vector2(mid.x - extent.x * 0.5, body.position.y - GAP - extent.y))
	places.append(Vector2(mid.x - extent.x * 0.5, body.end.y + GAP))
	var best := 0
	var best_cost := INF
	var best_rect := Rect2()
	for i in places.size():
		var want: Vector2 = places[i]
		var pos := Vector2(clampf(want.x, safe.position.x, maxf(safe.position.x, safe.end.x - extent.x)),
			clampf(want.y, safe.position.y, maxf(safe.position.y, safe.end.y - extent.y)))
		var rect := Rect2(pos, extent)
		# order of preference when nothing is in the way: level beside it, then raised or lowered, then above, below
		var cost := float(i) * 40.0 + pos.distance_to(want) * 60.0 + _overlap(rect, body) * 4.0
		for other: Rect2 in avoid:
			cost += _overlap(rect, other.grow(8.0))
		for zone: Rect2 in zones:
			cost += _overlap(rect, zone) * 1000.0
		if i == spot:
			cost -= STICKY
		if cost < best_cost:
			best_cost = cost
			best = i
			best_rect = rect
	# Never rest on a touch cluster: lift the whole box above any it still meets.
	for zone: Rect2 in zones:
		if best_rect.intersects(zone):
			best_rect.position.y = maxf(safe.position.y, minf(best_rect.position.y, zone.position.y - extent.y - 8.0))
	best_rect.position = _snap(best_rect.position)
	var far := 4000.0
	var clip: Rect2
	var from := best_rect.position
	if best >= 7:
		clip = Rect2(-far, body.end.y - body.size.y * 0.2, far * 2.0, far)
		from.y = clip.position.y - extent.y
	elif best == 6:
		clip = Rect2(-far, -far, far * 2.0, far + body.position.y + body.size.y * 0.3)
		from.y = clip.end.y
	elif best % 2 == 0:
		clip = Rect2(mid.x + body.size.x * 0.15, -far, far, far * 2.0)
		from.x = clip.position.x - extent.x
	else:
		clip = Rect2(-far, -far, far + mid.x - body.size.x * 0.15, far * 2.0)
		from.x = clip.end.x
	return {"rect": best_rect, "spot": best, "from": from, "clip": clip}


func layout() -> void:
	if battle == null or battle.cam == null:
		return
	menu_rect = Rect2()
	action_rect = Rect2()
	var taken := []
	if actor != null and not option.is_empty() and battle._ref_pos(actor) != null:
		var side := UIKit.row_h()
		var label := String(option.get("label", ""))
		var most := minf(300.0, UIKit.safe_rect(self).size.x - 64.0 - side * 2.0 - PAD * 2.0 - CAP_W)
		var label_w := clampf(UIKit.font_body().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(32)).x + 36.0, 150.0, most)
		var move_h := maxf(side, _paragraph(label, label_w - 24.0, false, 32).get_size().y + 20.0)
		var gauges := GAUGE_GAP + GAUGE_H if typeof(actor) == TYPE_OBJECT else 0.0
		var extent := Vector2(side * 2.0 + 8.0 + CAP_W + label_w + PAD * 2.0, move_h + gauges + PAD * 2.0)
		var placed := pin(actor, extent, _others(actor), _menu_spot)
		_menu_spot = placed["spot"]
		_menu_from = placed["from"]
		menu_rect = placed["rect"]
		action_rect = Rect2(menu_rect.position + Vector2(PAD, PAD), Vector2(extent.x - PAD * 2.0, move_h))
		_clip.position = (placed["clip"] as Rect2).position
		_clip.size = (placed["clip"] as Rect2).size
		_menu.position = -_clip.position
		taken.append(menu_rect.grow(8.0))
	tag_rects.clear()
	for ref in hp_changes:
		if is_same(ref, actor) or battle._ref_pos(ref) == null:
			continue
		var name_w := UIKit.font_head().get_string_size(_name(ref), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.head_px(26)).x
		var w := clampf(name_w + PAD * 2.0 + 8.0, 210.0, 320.0)
		var h := PAD * 2.0 + _paragraph(_name(ref), w - PAD * 2.0, true).get_size().y
		if typeof(ref) == TYPE_OBJECT:
			h += 6.0 + _paragraph("HP 0 / 0", w - PAD * 2.0).get_size().y
		var placed := pin(ref, Vector2(w, h), _others(ref) + taken, int(_tag_spots.get(ref, -1)))
		_tag_spots[ref] = placed["spot"]
		tag_rects[ref] = placed["rect"]
		taken.append((placed["rect"] as Rect2).grow(6.0))


func hit_menu(at: Vector2) -> String:
	if not menu_rect.has_area() or not menu_rect.has_point(at):
		return ""
	if not action_rect.has_point(at):
		return "consume"
	var zone := "body"
	if at.x < action_rect.position.x + UIKit.row_h():
		zone = "left"
	elif at.x > action_rect.end.x - UIKit.row_h():
		zone = "right"
	_pressed = zone
	_pressed_until = _clock + 0.14
	queue_redraw()
	return zone


## Only when a box had to rest away from its model (a touch cluster or the screen's edge was in the way).
func _leader(rect: Rect2, ref, alpha := 1.0) -> void:
	if rect.grow(GAP + 24.0).intersects(model_rect(ref)):
		return
	var tip: Vector2 = battle.screen_anchor(ref)
	var edge := Vector2(clampf(tip.x, rect.position.x + 12, rect.end.x - 12), clampf(tip.y, rect.position.y + 12, rect.end.y - 12))
	draw_line(_snap(edge), _snap(tip), Color(UIKit.BORDER, alpha), 2.0 / UIKit.screen_scale, true)
	draw_circle(_snap(tip), 3.0, Color(UIKit.ACCENT, alpha))


## The bar: ◄, the chooser's level and action (then its target, while aiming) and ►, each a full-height button
## inside the padding; under them a beast's HP and MP.
func _draw_menu() -> void:
	if battle == null or not menu_rect.has_area():
		return
	var eased := 1.0 - pow(1.0 - _slide, 3.0)
	_menu.draw_set_transform(_snap((_menu_from - menu_rect.position) * (1.0 - eased)))
	_menu.draw_style_box(_window, menu_rect)
	var disabled: bool = option.get("disabled", false)
	var side := UIKit.row_h()
	var rects := [Rect2(action_rect.position, Vector2(side, action_rect.size.y)), Rect2(action_rect.position + Vector2(side + 4, 0), Vector2(action_rect.size.x - side * 2 - 8, action_rect.size.y)), Rect2(action_rect.end.x - side, action_rect.position.y, side, action_rect.size.y)]
	var ci := _menu.get_canvas_item()
	for i in 3:
		var zone: String = ["left", "body", "right"][i]
		var held := zone == _pressed and _clock < _pressed_until
		var off := disabled if i == 1 else not _can_cycle
		if not off:
			_menu.draw_style_box(_solid if held else _selected, rects[i])
		var ink := UIKit.DIM if off else (UIKit.DARK if held else UIKit.INK)
		var room: Rect2 = rects[i]
		if i == 1:
			# the level, in a cap at the left of the action
			var cap := Rect2(room.position + Vector2(8, 8), Vector2(CAP_W - 8.0, room.size.y - 16.0))
			_menu.draw_style_box(UIKit.row_box(Color(0, 0, 0, 0.4), UIKit.DARK if held else UIKit.BORDER), cap)
			var lv := _paragraph("Lv%d" % (GameState.trainer_level if typeof(actor) != TYPE_OBJECT else actor.level), cap.size.x, false, 22)
			lv.alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv.draw(ci, _snap(cap.position + Vector2(0, (cap.size.y - lv.get_size().y) * 0.5)), UIKit.DARK if held else UIKit.HEAD)
			room = Rect2(room.position + Vector2(CAP_W, 0), room.size - Vector2(CAP_W, 0))
		var p := _paragraph(["◄", String(option.get("label", "")), "►"][i], room.size.x - 24, false, 32)
		p.alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.draw(ci, _snap(room.position + Vector2(12, (room.size.y - p.get_size().y) * 0.5)), ink)
	if typeof(actor) != TYPE_OBJECT:
		return
	# HP and MP under the bar; the part of the MP this move would spend slowly flashes
	var under := Rect2(action_rect.position.x, action_rect.end.y + GAUGE_GAP, action_rect.size.x, GAUGE_H)
	var hp := Rect2(under.position, Vector2(under.size.x * 0.58, GAUGE_H))
	var mp := Rect2(hp.end.x + 10.0, under.position.y, under.size.x - hp.size.x - 10.0, GAUGE_H)
	var hp_ratio := clampf(float(actor.hp) / maxf(1.0, actor.max_hp()), 0.0, 1.0)
	_gauge(hp, hp_ratio, UIKit.hp_color(hp_ratio))
	var most := maxf(1.0, actor.max_mp())
	var cost := float(battle.MoveDB.mp_cost(String(option["move"]))) if option.has("move") else 0.0
	var keep := maxf(0.0, actor.mp - cost) if cost > 0.0 else float(actor.mp)
	_gauge(mp, keep / most, MP_COLOR)
	if cost > 0.0:
		var pulse := 0.15 + 0.85 * (0.5 + 0.5 * sin(_clock * 2.4))
		_menu.draw_rect(Rect2(mp.position + Vector2(mp.size.x * keep / most, 0), Vector2(mp.size.x * (minf(actor.mp, most) - keep) / most, GAUGE_H)), Color(MP_COLOR, pulse))
		if actor.mp < cost:
			_menu.draw_rect(mp, Color(UIKit.ACCENT, 0.5 * pulse), false, 1.5)


## A thin gauge: a dark trough with a coloured fill.
func _gauge(r: Rect2, ratio: float, col: Color) -> void:
	_menu.draw_rect(r.grow(1.5), Color(0, 0, 0, 0.55))
	_menu.draw_rect(r, Color(UIKit.DIM, 0.2))
	if ratio > 0.0:
		_menu.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), col)


func _draw() -> void:
	if battle == null:
		return
	if menu_rect.has_area() and _slide >= 1.0:
		_leader(menu_rect, actor)
	for ref in tag_rects:
		var rect: Rect2 = tag_rects[ref]
		var alpha := clampf((float(hp_changes.get(ref, _clock)) - _clock) / 0.25, 0.0, 1.0)
		_leader(rect, ref, alpha)
		_window.alpha = alpha
		_window.line.a = alpha
		draw_style_box(_window, rect)
		var inner := rect.size.x - PAD * 2.0
		var title := _paragraph(_name(ref), inner, true)
		title.draw(get_canvas_item(), _snap(rect.position + Vector2(PAD, PAD)), Color(UIKit.HEAD, alpha))
		if typeof(ref) == TYPE_OBJECT:
			_paragraph("HP %d / %d" % [maxi(0, ref.hp), ref.max_hp()], inner).draw(get_canvas_item(),
				_snap(rect.position + Vector2(PAD, PAD + title.get_size().y + 6.0)), Color(UIKit.INK, alpha))
	_window.alpha = 1.0
	_window.line.a = 1.0
