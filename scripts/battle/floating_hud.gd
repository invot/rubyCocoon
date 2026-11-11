extends Control
## Compact white bars pinned to the live 3D stage, framed in their model's outline colour, the left edge leaning in
## at the top bar's angle: the level in small black text and a thin divider, one line of text, and full-width HP / MP
## gauges along the bottom inside the frame.
##   - The chooser's bar (you first, then each beast in turn; only one at a time): its level, then ◄ the action ►,
##     with ▲ / ▼ (or a short rounded line where that way leads nowhere) above and below it. A beast's has its HP
##     and MP; the part of the MP the move would spend slowly flashes. While aiming it reads
##     "Bite ► Tadlet" and ◄ ► change the target.
##   - A target's bar while it is aimed at: level, name, HP.
## Bars show only while something is being chosen; nothing appears during actions.
## A bar stands to the left of its model (to the right when there is no room) and its inner end runs behind it: the
## highlighted models are shown again over the bars (the 3D view, cut to their shapes by battle.gd front_texture),
## each with a flat outline round its
## silhouette in its colour (battle.gd outline_color), so a bar meets the outline behind its beast. Bars slide out
## from behind their models. What an action does is said in the top bar.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const FrameBox = preload("res://scripts/ui/frame_box.gd")
const OutlineShader = preload("res://scripts/battle/silhouette_outline.gdshader")
const MaskShader = preload("res://scripts/battle/front_mask.gdshader")
const SLIDE_TIME := 0.2
const TEXT_PX := 26
## The level: small text at the left of the bar's content, with a thin divider after it.
const LV_PX := 15
const LV_W := 40.0
const LV_GAP := 8.0
const ARROW_W := 16.0
## HP and MP: one full-width row inside the bar, along its bottom, each gauge in a white border.
const GAUGE_H := 10.0
const GAUGE_EDGE := 2.0
## Between the gauges' row and the content's right end.
const GAUGE_MARGIN := 10.0
## How far the gauges' row tucks up under the text row.
const GAUGE_TUCK := 9.0
## How far a bar runs in behind its model: to its middle (a part of its width), at most MAX_TUCK UI units.
const TUCK := 0.5
const MAX_TUCK := 140.0
## The outline's width (UI units).
const OUTLINE := 3.0
const MP_COLOR := Color("#5f8fe8")
## The bar's frame, in its model's outline colour.
const BORDER := 3.0
## Between an action and its target on the chooser's bar ("Bite ► Tadlet").
const AIM_MARK := " ► "
## The yellow pointer drawn in its place: a short triangle, about as wide as it is tall, with a gap either side.
const AIM_W := 11.0
const AIM_H := 13.0
const AIM_GAP := 7.0
## While you choose: every beast's HP and MP above its head (no border), and your shield orbs in a white box.
const MINI_W := 66.0
const MINI_HP_H := 6.0
const MINI_MP_H := 5.0
const ORB_R := 6.5
const SHIELD_COLOR := Color("#3fc8e6")
## The readout plates: as dark as the top-centre bar, and the room inside their line.
const PLATE_ALPHA := 0.78
const PLATE_PAD := 5.0
## The ▲ / ▼ (or, where up / down leads nowhere, a short rounded line) above and below the chooser's bar.
const NAV_GAP := 7.0
const NAV_SIZE := 7.0
const TargetArrow = preload("res://scripts/battle/target_arrow.gd")

var battle: Node
var actor = null
var option := {}
var row := {}
## The chooser's bar names a target (◄ ► aim, A confirms) after its action.
var aiming := false
## The chooser's bar (pill and gauges), and its pill grown to a full-height tap target.
var menu_rect := Rect2()
var action_rect := Rect2()
var tag_rects := {}
var _clock := 0.0
var _pressed := ""
var _pressed_until := 0.0
var _can_cycle := true
var _paragraphs := {}
## This frame's bars: [{key, ref, rect, pill, inner, from, clip, front, loose, cap, label, arrows, gauges, alpha}]
var _bars: Array = []
## One layer for each bar: [{clip (hides what is still behind its model), canvas, front (its model, over its end),
## front_tex}]
var _layers: Array = []
var _born := {}
var _sides := {}
var _front_refs: Array = []
var _outline_clip: Control
var _outline_rect: TextureRect
var _outline_mat: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_clip = Control.new()
	_outline_clip.clip_contents = true
	_outline_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_clip.z_index = 1
	_outline_clip.visible = false
	add_child(_outline_clip)
	_outline_rect = TextureRect.new()
	_outline_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_outline_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OutlineShader
	_outline_rect.material = _outline_mat
	_outline_clip.add_child(_outline_rect)


func choose(ref, data: Dictionary, move: Dictionary, aim := false) -> void:
	actor = ref
	row = data
	option = move
	aiming = aim
	if aim:
		_can_cycle = (data.get("targets", []) as Array).size() > 1 and not data.get("target_all", false)
	else:
		var options: Array = data.get("options", [])
		_can_cycle = (options.filter(func(o): return not o.get("disabled", false)).size() if battle.tutorial else options.size()) > 1
	layout()


func clear_choice() -> void:
	actor = null
	option = {}
	aiming = false
	layout()


func _process(delta: float) -> void:
	_clock += delta
	layout()


func _pill_h() -> float:
	return 48.0 if UIKit.touch_ui() else 40.0


## One line, trimmed with an ellipsis.
func _line(text: String, width: float, px := TEXT_PX) -> TextParagraph:
	var key := "%d:%d:%s" % [px, int(width), text]
	if not _paragraphs.has(key):
		if _paragraphs.size() > 96:
			_paragraphs.clear()
		var p := TextParagraph.new()
		p.add_string(text, UIKit.font_body(), UIKit.body_px(px))
		p.width = width
		p.max_lines_visible = 1
		p.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_paragraphs[key] = p
	return _paragraphs[key]


func _name(ref) -> String:
	if typeof(ref) == TYPE_INT:
		return battle.Ring.slot_name(ref)
	if typeof(ref) == TYPE_STRING:
		return String(battle.trainer.get("name", "Trainer")) if ref == "foe_trainer" else GameState.player_name
	return ref.nickname


func _key(ref) -> String:
	return str(ref.get_instance_id()) if typeof(ref) == TYPE_OBJECT else str(ref)


func _snap(at: Vector2) -> Vector2:
	var scale := get_viewport().get_screen_transform().get_scale()
	return (at * scale).round() / scale


## The screen footprint of a beast, trainer or pad: its models' projected bounds, or an estimate from its height.
func model_rect(ref) -> Rect2:
	var box: Rect2 = battle.screen_bounds(ref) if typeof(ref) != TYPE_INT else Rect2()
	if box.size.x >= 8.0 and box.size.y >= 8.0:
		return box
	var head: Vector2 = battle.screen_anchor(ref)
	var foot: Vector2 = battle.screen_anchor(ref, 0.0)
	var h := maxf(foot.y - head.y, 36.0)
	var half := maxf(24.0, h * 0.4)
	return Rect2(head.x - half, foot.y - h, half * 2.0, h)


## What a bar may not rest on: the touch clusters, and a trainer's shield orbs while they show.
func _keep_clear() -> Array:
	var out := []
	if UI.is_touch():
		for group in UI.controls.CLUSTERS:
			var zone: Rect2 = UI.controls.cluster_zone(group, UI.controls.TOUCH_SLOP + UI.controls.NO_TAP_MARGIN)
			if zone.has_area():
				out.append(zone.grow(6.0))
	var k: Vector2 = get_viewport_rect().size / battle.cam.get_viewport().get_visible_rect().size
	for team in battle._shield_orbs:
		for orb in battle._shield_orbs[team]:
			if orb.visible:
				out.append(Rect2(battle.cam.unproject_position(orb.position) * k - Vector2(22, 22), Vector2(44, 44)))
	return out


## A bar for `ref`, level with the middle of its model: to its left (`side` -1) unless only the right has room, its
## inner end running `tuck` behind the model. The text keeps clear of the model. `tall`: the height its tap target needs.
func _bar(key: String, ref, label: String, cap: String, arrows: bool, gauges: String, tall := 0.0) -> Dictionary:
	var safe := UIKit.safe_rect(self).grow(-12.0)
	safe.position.y = maxf(safe.position.y, UI.top_bar.bottom() + 8.0)
	safe.size.y = UIKit.safe_rect(self).end.y - 12.0 - safe.position.y
	var pill_h := _pill_h()
	var label_w := clampf(UIKit.font_body().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.body_px(TEXT_PX)).x + 4.0, 96.0, 330.0)
	var content := 12.0 + (ARROW_W * 2.0 if arrows else 0.0) + label_w + (LV_GAP * 2.0 + LV_W if cap != "" else 0.0) + 12.0
	var body := model_rect(ref)
	# The model's true middle (its projected origin): a bounding box can be much wider than the model it holds.
	var center_x: float = battle.screen_anchor(ref, 0.5).x
	var half := clampf(center_x - body.position.x, 16.0, maxf(24.0, body.size.y * 0.6))
	# Only a model drawn again in front of the bars (a highlighted one) can hide a bar's end: its bar runs in to its
	# middle. Anyone else's (a brief HP bar) rests above its head instead, covering nothing.
	var behind := _front_refs.has(ref)
	var tuck := minf(MAX_TUCK, half) if behind else 0.0
	var gap := 8.0 if behind else 0.0
	var height := pill_h + (GAUGE_H + BORDER - GAUGE_TUCK if gauges != "" else 0.0)
	# the left edge leans in towards the bottom at the top bar's angle
	var slant: float = height * UI.top_bar.TAPER / maxf(1.0, UI.top_bar.bottom())
	var w := content + gap + tuck + slant
	var extent := Vector2(w, height)
	var mid_y := body.get_center().y
	var spare := maxf(0.0, tall - pill_h) * 0.5
	var blocked := _keep_clear()
	var first := int(_sides.get(key, -1))
	var out := {}
	if not behind:
		var head: Vector2 = battle.screen_anchor(ref)
		var above := Rect2(Vector2(center_x - w * 0.5, head.y - 10.0 - extent.y), extent)
		above.position.x = clampf(above.position.x, safe.position.x, maxf(safe.position.x, safe.end.x - w))
		above.position.y = clampf(above.position.y, safe.position.y, maxf(safe.position.y, safe.end.y - extent.y))
		out = {"rect": above, "side": -1, "loose": false, "clip": Rect2(-4000.0, -4000.0, 8000.0, 8000.0),
			"from": above.position + Vector2(0, 12.0)}
	for side: int in ([] if not behind else [first, -first]):
		var x := center_x - w if side < 0 else center_x
		var rect := Rect2(Vector2(x, mid_y - pill_h * 0.5), extent)
		rect.position.y = clampf(rect.position.y, safe.position.y + spare, maxf(safe.position.y + spare, safe.end.y - extent.y - spare))
		var fits := rect.position.x >= safe.position.x and rect.end.x <= safe.end.x
		for zone: Rect2 in blocked:
			fits = fits and not rect.grow_individual(0, spare, 0, spare).intersects(zone)
		if fits or out.is_empty():
			# it slides out from the model's middle, hidden until it clears it
			var edge := center_x
			out = {"rect": rect, "side": side, "loose": not fits,
				"clip": Rect2(edge - 8000.0, -4000.0, 8000.0, 8000.0) if side < 0 else Rect2(edge, -4000.0, 8000.0, 8000.0),
				"from": Vector2(edge if side < 0 else edge - w, rect.position.y)}
		if fits:
			break
	var rect: Rect2 = out["rect"]
	if out["loose"]:
		# nowhere beside the model: keep it on screen and off anything it may not cover, with a pointer to its model
		rect.position.x = clampf(rect.position.x, safe.position.x, maxf(safe.position.x, safe.end.x - w))
		for zone: Rect2 in blocked:
			if rect.grow_individual(0, spare, 0, spare).intersects(zone):
				rect.position.y = maxf(safe.position.y + spare, minf(rect.position.y, zone.position.y - extent.y - spare - 8.0))
		out["clip"] = Rect2(-4000.0, -4000.0, 8000.0, 8000.0)
		out["from"] = rect.position
	rect.position = _snap(rect.position)
	_sides[key] = out["side"]
	if not _born.has(key):
		_born[key] = _clock
	var pill := Rect2(rect.position, extent)
	# the content: on the open end, clear of the tucked one
	var inner := Rect2(pill.position + Vector2(tuck + gap + slant if out["side"] > 0 else slant, 0), Vector2(content, pill_h))
	out.merge({"key": key, "ref": ref, "rect": rect, "pill": pill, "inner": inner, "label": label, "label_w": label_w,
		"cap": cap, "arrows": arrows, "gauges": gauges, "top": pill_h, "slant": slant, "alpha": 1.0, "front": _front_refs.has(ref) and not out["loose"],
		"body": body}, true)
	return out


func _level(ref) -> String:
	if typeof(ref) == TYPE_OBJECT:
		return "Lv%d" % ref.level
	return "Lv%d" % GameState.trainer_level if typeof(ref) == TYPE_STRING and ref != "foe_trainer" else ""


func layout() -> void:
	if battle == null or battle.cam == null:
		return
	# the highlighted trainers and beasts are drawn again in front of the bars, outlined
	var front: Array = battle._selected_refs.filter(func(r): return typeof(r) != TYPE_INT and battle._ref_pos(r) != null)
	if front != _front_refs:
		_front_refs = front
		battle.set_front(front)
	menu_rect = Rect2()
	action_rect = Rect2()
	tag_rects.clear()
	_bars.clear()
	var hit_h := maxf(UIKit.row_h(), _pill_h())
	if actor != null and not option.is_empty() and battle._ref_pos(actor) != null:
		var bar := _bar("menu:" + _key(actor), actor, String(option.get("label", "")), _level(actor), true,
			"both" if typeof(actor) == TYPE_OBJECT else "", hit_h)
		_bars.append(bar)
		menu_rect = bar["rect"]
		var pill: Rect2 = bar["pill"]
		var inner: Rect2 = bar["inner"]
		action_rect = Rect2(inner.position.x, pill.get_center().y - hit_h * 0.5, inner.size.x, hit_h)
	for ref in battle._target_refs:
		if is_same(ref, actor) or battle._ref_pos(ref) == null:
			continue
		var bar := _bar("tag:" + _key(ref), ref, _name(ref), _level(ref), false, "hp" if typeof(ref) == TYPE_OBJECT else "")
		_bars.append(bar)
		tag_rects[ref] = bar["rect"]
	for key in _born.keys():
		if not _bars.any(func(b): return b["key"] == key):
			_born.erase(key)
			_sides.erase(key)
	_layout_layers()
	_layout_outline()
	queue_redraw()


func _layout_layers() -> void:
	var view := get_viewport_rect().size
	while _layers.size() < _bars.size():
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		var canvas := Control.new()
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.draw.connect(_draw_bar.bind(_layers.size()))
		clip.add_child(canvas)
		var front := Control.new()
		front.clip_contents = true
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(front)
		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mask := ShaderMaterial.new()
		mask.shader = MaskShader
		tex.material = mask
		front.add_child(tex)
		_layers.append({"clip": clip, "canvas": canvas, "front": front, "front_tex": tex})
	for i in _layers.size():
		var layer: Dictionary = _layers[i]
		var clip: Control = layer["clip"]
		var front: Control = layer["front"]
		clip.visible = i < _bars.size()
		front.visible = clip.visible and _bars[i]["front"]
		if not clip.visible:
			continue
		var bar: Dictionary = _bars[i]
		var area: Rect2 = bar["clip"]
		clip.position = area.position
		clip.size = area.size
		(layer["canvas"] as Control).position = -area.position
		(layer["canvas"] as Control).queue_redraw()
		if front.visible:
			# its own model, over the end of the bar that runs behind it
			var over: Rect2 = (bar["rect"] as Rect2).intersection((bar["body"] as Rect2).grow(OUTLINE + 2.0))
			front.visible = over.has_area()
			front.position = over.position
			front.size = over.size
			var tex: TextureRect = layer["front_tex"]
			tex.texture = battle.cam.get_viewport().get_texture()
			(tex.material as ShaderMaterial).set_shader_parameter("mask", battle.front_texture())
			tex.position = -over.position
			tex.size = view


## The flat outline round every highlighted model's silhouette, over everything else on the stage.
func _layout_outline() -> void:
	_outline_clip.visible = not _front_refs.is_empty()
	if not _outline_clip.visible:
		return
	var view := get_viewport_rect().size
	var all := Rect2()
	var boxes := []
	var colors := []
	for ref in _front_refs:
		if boxes.size() >= 8:
			break
		var box := model_rect(ref).grow(OUTLINE + 4.0)
		all = box if boxes.is_empty() else all.merge(box)
		boxes.append(Vector4(box.position.x / view.x, box.position.y / view.y, box.end.x / view.x, box.end.y / view.y))
		colors.append(battle.outline_color(ref))
	_outline_clip.position = all.position
	_outline_clip.size = all.size
	_outline_rect.texture = battle.front_texture()
	_outline_rect.position = -all.position
	_outline_rect.size = view
	var tex_size := Vector2(_outline_rect.texture.get_size()) if _outline_rect.texture != null else view
	_outline_mat.set_shader_parameter("width", OUTLINE * tex_size.x / view.x)
	_outline_mat.set_shader_parameter("count", boxes.size())
	_outline_mat.set_shader_parameter("boxes", boxes)
	_outline_mat.set_shader_parameter("colors", colors)


func hit_menu(at: Vector2) -> String:
	if not action_rect.has_area() or not action_rect.has_point(at) or _bars.is_empty():
		return ""
	var inner: Rect2 = _bars[0]["inner"]
	var level := LV_GAP * 2.0 + LV_W if String(_bars[0]["cap"]) != "" else 0.0
	var zone := "body"
	if at.x < inner.position.x + 12.0 + level + ARROW_W + 8.0:
		zone = "left"
	elif at.x > inner.end.x - 12.0 - ARROW_W - 8.0:
		zone = "right"
	_pressed = zone
	_pressed_until = _clock + 0.14
	return zone


## A pointer, only for a bar that had to rest away from its model (a touch cluster or the screen's edge was in the way).
func _draw() -> void:
	if battle == null:
		return
	for bar in _bars:
		if not bar["loose"]:
			continue
		var rect: Rect2 = bar["pill"]
		var tip: Vector2 = battle.screen_anchor(bar["ref"], 0.5)
		if rect.grow(8.0).has_point(tip):
			continue
		var edge := Vector2(clampf(tip.x, rect.position.x + 8, rect.end.x - 8), clampf(tip.y, rect.position.y + 8, rect.end.y - 8))
		draw_line(_snap(edge), _snap(tip), Color(UIKit.BORDER, bar["alpha"]), 2.0 / UIKit.screen_scale, true)
		draw_circle(_snap(tip), 3.0, Color(UIKit.ACCENT, bar["alpha"]))
	_draw_readouts()


## While you choose your own action (or aim it), small plates styled like the top-centre bar (the windows' near-black
## in a thin white line, square): every standing beast without a bar of its own shows its HP over its MP above its
## head, and each trainer (you, and a rival trainer) their shield points as orbs. Nothing shows while a beast is
## choosing.
func _draw_readouts() -> void:
	if not (typeof(actor) == TYPE_STRING and actor == "trainer_self"):
		return
	for b in battle.nodes:
		if typeof(b) != TYPE_OBJECT or b.hp <= 0 or tag_rects.has(b) or battle._ref_pos(b) == null:
			continue
		var size := Vector2(MINI_W, PLATE_PAD * 2.0 + MINI_HP_H + MINI_MP_H + 2.0)
		var plate := _plate_above(b, size)
		var inner := _plate(plate)
		var hp := Rect2(inner.position, Vector2(inner.size.x, MINI_HP_H))
		_well(hp, clampf(float(b.hp) / maxf(1.0, b.max_hp()), 0.0, 1.0), UIKit.hp_color(clampf(float(b.hp) / maxf(1.0, b.max_hp()), 0.0, 1.0)))
		var mp := Rect2(hp.position + Vector2(0, MINI_HP_H + 2.0), Vector2(inner.size.x, MINI_MP_H))
		_well(mp, clampf(float(b.mp) / maxf(1.0, b.max_mp()), 0.0, 1.0), MP_COLOR)
	_shield_plate("trainer_self", int(GameState.shield), int(GameState.max_shield))
	if not battle.wild:
		_shield_plate("foe_trainer", int(battle.foe_shield), int(battle.foe_max_shield))


func _shield_plate(ref, left: int, most: int) -> void:
	if most <= 0 or battle._ref_pos(ref) == null:
		return
	var step := ORB_R * 2.0 + 4.0
	var size := Vector2(most * step - 4.0 + PLATE_PAD * 2.0 + 4.0, ORB_R * 2.0 + PLATE_PAD * 2.0)
	var inner := _plate(_plate_above(ref, size))
	for i in most:
		var c := inner.position + Vector2(ORB_R + i * step, inner.size.y * 0.5)
		if i < left:
			draw_circle(c, ORB_R, SHIELD_COLOR.darkened(0.25))
			draw_circle(c, ORB_R - 1.5, SHIELD_COLOR)
			draw_circle(c + Vector2(-ORB_R * 0.3, -ORB_R * 0.35), ORB_R * 0.3, Color(1, 1, 1, 0.85))
		else:
			draw_arc(c, ORB_R - 1.0, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 1.5, true)


## Where a readout plate rests: centred above someone's head, in the safe area.
func _plate_above(ref, size: Vector2) -> Rect2:
	var head: Vector2 = battle.screen_anchor(ref)
	var safe := UIKit.safe_rect(self).grow(-8.0)
	var at := Vector2(head.x - size.x * 0.5, head.y - 8.0 - size.y)
	at.x = clampf(at.x, safe.position.x, maxf(safe.position.x, safe.end.x - size.x))
	at.y = maxf(at.y, UI.top_bar.bottom() + 4.0)
	return Rect2(_snap(at), size)


## A small plate like the top-centre bar: the windows' near-black (faintly tinted with the gem) in a thin white line.
## Returns the room inside it.
func _plate(rect: Rect2) -> Rect2:
	draw_rect(rect, Color(FrameBox.shade, PLATE_ALPHA))
	var line := FrameBox.unit
	draw_rect(rect.grow(-line * 0.5), UIKit.BORDER, false, line)
	return rect.grow(-PLATE_PAD)


## A gauge on a dark plate: a faint well with a coloured fill.
func _well(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.16))
	if ratio > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), col)


func _draw_bar(index: int) -> void:
	if battle == null or index >= _bars.size():
		return
	var bar: Dictionary = _bars[index]
	var canvas: Control = _layers[index]["canvas"]
	var ci := canvas.get_canvas_item()
	var pill: Rect2 = bar["pill"]
	var inner: Rect2 = bar["inner"]
	var alpha := snappedf(float(bar["alpha"]), 0.1)
	var slide := clampf((_clock - float(_born.get(bar["key"], _clock))) / SLIDE_TIME, 0.0, 1.0)
	canvas.draw_set_transform(_snap(((bar["from"] as Vector2) - pill.position) * pow(1.0 - slide, 3.0)))
	var menu: bool = bar["arrows"]
	var held := _pressed if menu and _clock < _pressed_until else ""
	var solid := held == "body"
	# the pill: white, framed in its model's outline colour so it meets the outline behind the model (grey while pressed)
	var edge: Color = battle.outline_color(bar["ref"])
	var slant := float(bar["slant"])
	var shape := PackedVector2Array([pill.position, Vector2(pill.end.x, pill.position.y), pill.end,
		Vector2(pill.position.x + slant, pill.end.y)])
	canvas.draw_colored_polygon(shape, Color(Color(0.82, 0.82, 0.84) if solid else Color.WHITE, alpha))
	# the frame, just inside the shape
	var h := BORDER * 0.5
	var k := slant / maxf(1.0, pill.size.y)
	var frame := PackedVector2Array([Vector2(pill.position.x + h + k * h, pill.position.y + h), Vector2(pill.end.x - h, pill.position.y + h),
		Vector2(pill.end.x - h, pill.end.y - h), Vector2(pill.position.x + slant + h - k * h, pill.end.y - h)])
	frame.append(frame[0])
	frame.append(frame[1])
	canvas.draw_polyline(frame, Color(edge, alpha), BORDER, true)
	var ink := Color(UIKit.DARK, alpha)
	var off := Color(Color(0.55, 0.55, 0.58), alpha)
	if menu and option.get("disabled", false):
		ink = off
	var x := inner.position.x + 12.0
	var right := inner.end.x - 12.0
	var top := float(bar["top"])
	var mid_y := pill.position.y + top * 0.5
	var cap_text: String = bar["cap"]
	if cap_text != "":
		# the level, at the left in small black text, set off by a thin divider after it
		var lv := _line(cap_text, LV_W, LV_PX)
		lv.alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.draw(ci, _snap(Vector2(x, mid_y - lv.get_size().y * 0.5)), Color(Color.BLACK, alpha))
		x += LV_W + LV_GAP
		var rule := _snap(Vector2(x, pill.position.y + 9.0))
		var rule_end := pill.position.y + (top - GAUGE_TUCK - 3.0 if String(bar["gauges"]) != "" else top - 9.0)
		canvas.draw_line(rule, Vector2(rule.x, rule_end), Color(0.72, 0.72, 0.75, alpha), 1.5)
		x += LV_GAP
	if menu:
		_tri(canvas, Vector2(x + ARROW_W * 0.35, mid_y), -1, off if not _can_cycle else (edge if held == "left" else ink))
		_tri(canvas, Vector2(right - ARROW_W * 0.35, mid_y), 1, off if not _can_cycle else (edge if held == "right" else ink))
		x += ARROW_W
	if menu and not aiming:
		_nav_hints(canvas, inner, pill, edge, alpha)
	# "Bite ► Tadlet": the arrow between the action and its target is the 3D arrow's yellow
	var label: String = bar["label"]
	var parts := label.split(AIM_MARK, true, 1)
	if parts.size() == 2:
		var label_end := x + float(bar["label_w"])
		var font := UIKit.font_body()
		var px := UIKit.body_px(TEXT_PX)
		for i in 2:
			var piece: String = parts[i]
			var p := _line(piece, maxf(8.0, minf(label_end - x, font.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 2.0)))
			var top_y := mid_y - p.get_size().y * 0.5
			p.draw(ci, _snap(Vector2(x, top_y)), ink)
			x += p.get_size().x
			if i == 0:
				# a short yellow pointer, centred on the capitals (the baseline less half the cap height)
				var cy := top_y + font.get_ascent(px) - font.get_ascent(px) * 0.36
				x += AIM_GAP
				_aim_pointer(canvas, Vector2(x, cy), alpha)
				x += AIM_W + AIM_GAP
	else:
		var text := _line(label, float(bar["label_w"]))
		text.draw(ci, _snap(Vector2(x, mid_y - text.get_size().y * 0.5)), ink)
	var kind: String = bar["gauges"]
	if kind == "":
		return
	# along the bottom, inside the frame: HP, and for the chooser MP, where the part this move would spend slowly flashes
	var ref = bar["ref"]
	var left := maxf(inner.position.x, pill.position.x + slant + BORDER)
	var row := Rect2(left, pill.position.y + top - GAUGE_TUCK, inner.end.x - GAUGE_MARGIN - left, GAUGE_H)
	var hp := Rect2(row.position, Vector2(row.size.x * (0.58 if kind == "both" else 1.0), GAUGE_H))
	var hp_ratio := clampf(float(ref.hp) / maxf(1.0, ref.max_hp()), 0.0, 1.0)
	_gauge(canvas, hp, hp_ratio, UIKit.hp_color(hp_ratio), alpha)
	if kind != "both":
		return
	var mp := Rect2(hp.end.x, row.position.y, row.size.x - hp.size.x, GAUGE_H)
	var most := maxf(1.0, ref.max_mp())
	var cost := float(battle.MoveDB.mp_cost(String(option["move"]))) if option.has("move") else 0.0
	var keep := maxf(0.0, ref.mp - cost)
	_gauge(canvas, mp, keep / most, MP_COLOR, alpha)
	var well := mp.grow(-GAUGE_EDGE)
	if cost > 0.0:
		var pulse := 0.15 + 0.85 * (0.5 + 0.5 * sin(_clock * 2.4))
		canvas.draw_rect(Rect2(well.position + Vector2(well.size.x * keep / most, 0), Vector2(well.size.x * (minf(ref.mp, most) - keep) / most, well.size.y)), Color(MP_COLOR, pulse * alpha))
		if ref.mp < cost:
			canvas.draw_rect(well, Color(UIKit.ACCENT, 0.5 * pulse * alpha), false, 1.5)


## A gauge in a white border: a grey well with a coloured fill.
func _gauge(canvas: Control, r: Rect2, ratio: float, col: Color, alpha: float) -> void:
	canvas.draw_rect(r, Color(Color.WHITE, alpha))
	var well := r.grow(-GAUGE_EDGE)
	canvas.draw_rect(well, Color(0.3, 0.3, 0.33, alpha))
	if ratio > 0.0:
		canvas.draw_rect(Rect2(well.position, Vector2(well.size.x * clampf(ratio, 0.0, 1.0), well.size.y)), Color(col, alpha))


func _tri(canvas: Control, c: Vector2, dir: int, col: Color) -> void:
	var s := _pill_h() * 0.13
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s, 0), c + Vector2(-dir * s * 0.7, -s), c + Vector2(-dir * s * 0.7, s)]), col)


## The yellow pointer between an action and its target ("Bite ► Tadlet"): a short, wide triangle (the 3D arrow's
## yellow) with a thin dark edge so it reads on white. `at`: the middle of its left side.
func _aim_pointer(canvas: Control, at: Vector2, alpha: float) -> void:
	var half := AIM_H * 0.5
	var pts := PackedVector2Array([at + Vector2(0, -half), at + Vector2(AIM_W, 0), at + Vector2(0, half)])
	var rim := PackedVector2Array([at + Vector2(-1.2, -half - 1.6), at + Vector2(AIM_W + 1.8, 0), at + Vector2(-1.2, half + 1.6)])
	canvas.draw_colored_polygon(rim, Color(0.3, 0.24, 0.05, alpha))
	canvas.draw_colored_polygon(pts, Color(TargetArrow.YELLOW, alpha))


## Above and below the chooser's bar: ▲ / ▼ where up / down leads somewhere (another beast, or a turn of the ring),
## otherwise a short, thick rounded line.
func _nav_hints(canvas: Control, inner: Rect2, pill: Rect2, col: Color, alpha: float) -> void:
	var panel = UI.stack.back() if not UI.stack.is_empty() else null
	if panel == null or not panel.has_method("can_move"):
		return
	var cx := _snap(Vector2(inner.get_center().x, 0)).x
	for dir in [-1, 1]:
		var y := pill.position.y - NAV_GAP - NAV_SIZE * 0.5 if dir < 0 else pill.end.y + NAV_GAP + NAV_SIZE * 0.5
		var shadow := Color(0, 0, 0, 0.35 * alpha)
		if panel.can_move(dir):
			var tip := Vector2(cx, y + NAV_SIZE * 0.6 * dir)
			var pts := PackedVector2Array([tip, Vector2(cx - NAV_SIZE * 1.1, y - NAV_SIZE * 0.6 * dir), Vector2(cx + NAV_SIZE * 1.1, y - NAV_SIZE * 0.6 * dir)])
			var under := PackedVector2Array()
			for pt in pts:
				under.append(pt + Vector2(0, 1.5))
			canvas.draw_colored_polygon(under, shadow)
			canvas.draw_colored_polygon(pts, Color(col, alpha))
		else:
			var a := Vector2(cx - NAV_SIZE, y)
			var b := Vector2(cx + NAV_SIZE, y)
			var w := 4.0
			canvas.draw_line(a + Vector2(0, 1.5), b + Vector2(0, 1.5), shadow, w)
			for end in [a, b]:
				canvas.draw_circle(end + Vector2(0, 1.5), w * 0.5, shadow)
			canvas.draw_line(a, b, Color(col, 0.75 * alpha), w)
			for end in [a, b]:
				canvas.draw_circle(end, w * 0.5, Color(col, 0.75 * alpha))
