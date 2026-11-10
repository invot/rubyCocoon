extends Control
## Only the current choice, current targets, and brief HP changes. All anchors come from the live 3D stage.
const UIKit = preload("res://scripts/ui/ui_kit.gd")

var battle: Node
var actor = null
var option := {}
var row := {}
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window = UIKit.box("window", Vector4(12, 10, 12, 10))
	_selected = UIKit.highlight()
	_solid = UIKit.pressed_row()


func choose(ref, data: Dictionary, move: Dictionary) -> void:
	actor = ref
	row = data
	option = move
	var options: Array = data.get("options", [])
	_can_cycle = (options.filter(func(o): return not o.get("disabled", false)).size() if battle.tutorial else options.size()) > 1
	_paragraphs.clear()
	layout()
	queue_redraw()


func clear_choice() -> void:
	actor = null
	option = {}
	menu_rect = Rect2()
	action_rect = Rect2()
	queue_redraw()


func hp_changed(ref) -> void:
	hp_changes[ref] = _clock + 1.15


func _process(delta: float) -> void:
	_clock += delta
	for ref in hp_changes.keys():
		if hp_changes[ref] <= _clock or not battle.nodes.has(ref):
			hp_changes.erase(ref)
	layout()
	queue_redraw()


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


## Prefer the side with the most room. Move the whole footprint above every touch exclusion zone it meets.
## The leader is drawn to the original projected anchor, so it stretches when the box must move.
func place(at: Vector2, extent: Vector2, occupied: Array = [], preferred_side := 0) -> Rect2:
	var safe := UIKit.safe_rect(self).grow(-16.0)
	safe.position.y = maxf(safe.position.y, UI.top_bar.bottom() + 10.0)
	safe.size.y = UIKit.safe_rect(self).end.y - 16.0 - safe.position.y
	var right := preferred_side > 0 if preferred_side != 0 else at.x < safe.get_center().x
	var pos := at + Vector2(34 if right else -extent.x - 34, -extent.y * 0.5)
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - extent.x)
	pos.y = clampf(pos.y, safe.position.y, safe.end.y - extent.y)
	var rect := Rect2(pos, extent)
	var obstacles := occupied.duplicate()
	if UI.is_touch():
		for group in UI.controls.CLUSTERS:
			var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
			if zone.has_area():
				obstacles.append(zone.grow(6.0))
	for obstacle: Rect2 in obstacles:
		if rect.intersects(obstacle):
			rect.position.y = minf(rect.position.y, obstacle.position.y - extent.y - 8.0)
	rect.position.y = maxf(safe.position.y, rect.position.y)
	rect.position = _snap(rect.position)
	return rect


func layout() -> void:
	if battle == null or battle.cam == null:
		return
	menu_rect = Rect2()
	action_rect = Rect2()
	var occupied := []
	if actor != null and not option.is_empty():
		var w := minf(450.0 if UIKit.touch_ui() else 420.0, UIKit.safe_rect(self).size.x - 32.0)
		var name_h := _paragraph(_name(actor), w - 32, true).get_size().y
		var label_w := w - UIKit.row_h() * 2 - 44.0
		var move_h := maxf(UIKit.row_h(), _paragraph("A: " + String(option.get("label", "")), label_w, false, 32).get_size().y + 20.0)
		var stats_h := 70.0 if typeof(actor) == TYPE_OBJECT else 0.0
		var h := name_h + stats_h + move_h + 40.0
		menu_rect = place(battle.screen_anchor(actor), Vector2(w, h))
		action_rect = Rect2(menu_rect.position + Vector2(12, name_h + stats_h + 20), Vector2(w - 24, move_h))
		occupied.append(menu_rect.grow(8.0))
	tag_rects.clear()
	var refs: Array = battle._target_refs.duplicate()
	for ref in hp_changes:
		if not refs.has(ref) and not is_same(ref, actor):
			refs.append(ref)
	if not refs.is_empty():
		# Small target tags must leave the other creatures' faces visible for direct aiming.
		for beast in battle.nodes:
			var head: Vector2 = battle.screen_anchor(beast)
			occupied.append(Rect2(head - Vector2(32, 20), Vector2(64, 60)))
		for trainer in (["trainer_self"] if battle.wild else ["trainer_self", "foe_trainer"]):
			var head: Vector2 = battle.screen_anchor(trainer)
			occupied.append(Rect2(head - Vector2(32, 20), Vector2(64, 60)))
	for ref in refs:
		if is_same(ref, actor) or battle._ref_pos(ref) == null:
			continue
		var w := minf(300.0, maxf(220.0, UIKit.font_body().get_string_size(_name(ref), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 32))
		var h := _paragraph(_name(ref), w - 24, true).get_size().y + (46.0 if typeof(ref) == TYPE_OBJECT else 14.0)
		var anchor: Vector2 = battle.screen_anchor(ref)
		var side := 0
		if battle._target_refs.has(ref) and battle._aim_from != null:
			# The incoming 3D arrow owns one side of the target; its HP tag takes the opposite side.
			side = -1 if battle.screen_anchor(battle._aim_from).x >= anchor.x else 1
		var rect := place(anchor, Vector2(w, h), occupied, side)
		tag_rects[ref] = rect
		occupied.append(rect.grow(6.0))


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


func _leader(rect: Rect2, ref, alpha := 1.0) -> void:
	var tip: Vector2 = battle.screen_anchor(ref)
	var edge := Vector2(clampf(tip.x, rect.position.x + 12, rect.end.x - 12), clampf(tip.y, rect.position.y + 12, rect.end.y - 12))
	draw_line(_snap(edge), _snap(tip), Color(UIKit.BORDER, alpha), 2.0 / UIKit.screen_scale, true)
	draw_circle(_snap(tip), 3.0, Color(UIKit.ACCENT, alpha))


func _text(text: String, at: Vector2, width: float, heading := false, px := 26, color := Color.WHITE) -> void:
	_paragraph(text, width, heading, px).draw(get_canvas_item(), _snap(at), color)


func _draw() -> void:
	if battle == null:
		return
	if menu_rect.has_area():
		_leader(menu_rect, actor)
		draw_style_box(_window, menu_rect)
		_text(_name(actor), menu_rect.position + Vector2(16, 8), menu_rect.size.x - 32, true, 26, UIKit.HEAD)
		if typeof(actor) == TYPE_OBJECT:
			var y := action_rect.position.y - 66
			_text("HP %d / %d" % [maxi(0, actor.hp), actor.max_hp()], Vector2(menu_rect.position.x + 16, y), 240)
			var cost: int = battle.MoveDB.mp_cost(String(option["move"])) if option.has("move") else 0
			_text("MP %d / %d%s" % [actor.mp, actor.max_mp(), "  (-%d)" % cost if cost > 0 else ""], Vector2(menu_rect.position.x + 16, y + 30), 360)
			var meter := Rect2(menu_rect.end.x - 154, y + 11, 134, 12)
			draw_rect(meter, Color(UIKit.DIM, 0.2))
			draw_rect(Rect2(meter.position, Vector2(meter.size.x * actor.hp / actor.max_hp(), meter.size.y)), UIKit.ACCENT)
			meter.position.y += 30
			draw_rect(meter, Color(UIKit.DIM, 0.2))
			var ratio := float(actor.mp) / maxi(1, actor.max_mp())
			draw_rect(Rect2(meter.position, Vector2(meter.size.x * ratio, meter.size.y)), UIKit.ACCENT)
			if cost > 0:
				var amount := minf(ratio, float(cost) / maxi(1, actor.max_mp()))
				draw_rect(Rect2(meter.position + Vector2(meter.size.x * (ratio - amount), 0), Vector2(meter.size.x * amount, meter.size.y)), UIKit.ACCENT.darkened(0.75 * (1.0 - absf(sin(_clock * 3.0)))))
		var disabled: bool = option.get("disabled", false)
		var side := UIKit.row_h()
		var rects := [Rect2(action_rect.position, Vector2(side, action_rect.size.y)), Rect2(action_rect.position + Vector2(side + 4, 0), Vector2(action_rect.size.x - side * 2 - 8, action_rect.size.y)), Rect2(action_rect.end.x - side, action_rect.position.y, side, action_rect.size.y)]
		for i in 3:
			var zone: String = ["left", "body", "right"][i]
			var held := zone == _pressed and _clock < _pressed_until
			var off := disabled if i == 1 else not _can_cycle
			if not off:
				draw_style_box(_solid if held else _selected, rects[i])
			var label: String = ["◄", "A: " + String(option.get("label", "")), "►"][i]
			var p := _paragraph(label, rects[i].size.x - 16, false, 32)
			p.alignment = HORIZONTAL_ALIGNMENT_CENTER
			p.draw(get_canvas_item(), _snap(rects[i].position + Vector2(8, (rects[i].size.y - p.get_size().y) * 0.5)), UIKit.DIM if off else (UIKit.DARK if held else UIKit.INK))
	for ref in tag_rects:
		var rect: Rect2 = tag_rects[ref]
		var alpha := 1.0 if battle._target_refs.has(ref) else clampf((float(hp_changes.get(ref, _clock)) - _clock) / 0.25, 0.0, 1.0)
		_leader(rect, ref, alpha)
		_window.alpha = alpha
		_window.line.a = alpha
		draw_style_box(_window, rect)
		_text(_name(ref), rect.position + Vector2(12, 4), rect.size.x - 24, true, 26, Color(UIKit.HEAD, alpha))
		if typeof(ref) == TYPE_OBJECT:
			_text("HP %d / %d" % [maxi(0, ref.hp), ref.max_hp()], rect.position + Vector2(12, rect.size.y - 38), rect.size.x - 24, false, 26, Color(UIKit.INK, alpha))
	_window.alpha = 1.0
	_window.line.a = 1.0
