extends Control
## While you pick a target in battle, one card for each beast (or trainer) the move can be aimed at, in a row at the
## top of the screen: its icon, name, level and element, and its HP. The one aimed at wears a bright frame in the gem
## that pulses, with a soft glow; the others are dimmed. ◄ ► (or the d-pad) move along the row, A confirms, and a card
## can be tapped (a second tap on the aimed-at one confirms, see command_panel.gd). A move that hits them all frames
## every card (sel -1). For a beast's Move, a card for each slot it could step to: its name and who's there.
## battle.gd fills the cards (see show_cards) and hides them once the target is chosen.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const Elements = preload("res://scripts/data/elements.gd")

signal tapped(index: int)

## [{name, lv, element, hp, max_hp, icon: Texture2D, weak: the move aimed is super effective on it, trainer: bool,
##   shield, max_shield, slot: bool (a Move's), note}]
var cards: Array = []
var sel := 0
## a card's size and the gap between cards (UI units), and its text sizes: compact, so the row stays clear of the foes
## standing below it
var card := Vector2(260, 110)
var gap := 16.0
const NAME_SIZE := 28
const INFO_SIZE := 16
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false


func show_cards(c: Array, s: int) -> void:
	cards = c
	sel = s
	visible = not c.is_empty()
	custom_minimum_size = Vector2(cards.size() * card.x + maxf(0.0, cards.size() - 1) * gap, card.y) + Vector2(24, 24)
	size = custom_minimum_size
	queue_redraw()


func hide_cards() -> void:
	cards = []
	visible = false


func _process(delta: float) -> void:
	_time += delta
	if visible:
		queue_redraw()


func card_rect(i: int) -> Rect2:
	return Rect2(Vector2(12.0 + i * (card.x + gap), 12.0), card)


func _draw() -> void:
	var font := UIKit.font_body()
	var big := UIKit.body_px(NAME_SIZE)
	var small := UIKit.body_px(INFO_SIZE)
	# the name at the top, the HP bar along the bottom, and the level and element just above it
	var name_y := card.y * 0.1 + font.get_ascent(big)
	var bar_h := card.y * 0.11
	var bar_y := card.y * 0.88 - bar_h
	var info_y := bar_y - card.y * 0.07 - font.get_descent(small)
	var pulse := 0.5 + 0.5 * sin(_time * TAU / 0.9)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var r := card_rect(i)
		var on := i == sel or sel < 0
		var fade := 1.0 if on else 0.5
		_draw_card(r, on, pulse)
		# the icon
		var ic := Rect2(r.position + Vector2(card.y * 0.12, card.y * 0.12), Vector2(card.y * 0.76, card.y * 0.76))
		var tex: Texture2D = c.get("icon", null)
		if tex != null:
			draw_texture_rect(tex, ic, false, Color(1, 1, 1, fade))
		var x0 := ic.end.x + card.y * 0.12
		var x1 := r.end.x - card.y * 0.14
		var col := UIKit.LIGHT if on else UIKit.INK
		col.a = fade
		# name, then level and element
		if c.get("weak", false):
			# the move aimed hits it hard: a star in the top corner
			var wk := "★ WEAK"
			var ws := font.get_string_size(wk, HORIZONTAL_ALIGNMENT_LEFT, -1, small)
			draw_string(font, Vector2(x1 - ws.x, r.position.y + info_y), wk, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(UIKit.GOLD_BRIGHT, fade))
		var name: String = _fit(font, String(c.get("name", "")), big, x1 - x0)
		draw_string(font, Vector2(x0, r.position.y + name_y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, big, col)
		var info := "Trainer" if c.get("trainer", false) else "Lv %d  %s" % [int(c.get("lv", 1)), Elements.label(String(c.get("element", "neutral")))]
		if c.get("slot", false):
			info = String(c.get("note", ""))
		draw_string(font, Vector2(x0, r.position.y + info_y), _fit(font, info, small, x1 - x0), HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(UIKit.GOLD_BRIGHT if on else UIKit.DIM, fade))
		if c.get("slot", false):
			continue
		# HP (a trainer: shield points)
		var bar := Rect2(Vector2(x0, r.position.y + bar_y), Vector2(x1 - x0, bar_h))
		if c.get("trainer", false):
			var n := int(c.get("max_shield", 0))
			var orb := bar.size.y * 1.1
			for k in maxi(n, 1):
				var full := k < int(c.get("shield", 0))
				draw_circle(bar.position + Vector2(orb * 0.6 + k * orb * 1.5, bar.size.y * 0.5), orb * 0.55, Color("#6ab0ff", fade) if full else Color(0.2, 0.25, 0.4, 0.8 * fade))
			continue
		var ratio := float(c.get("hp", 0)) / maxf(1.0, float(c.get("max_hp", 1)))
		draw_rect(bar.grow(2.0), Color(UIKit.BORDER, fade))
		draw_rect(bar, Color(0, 0, 0, 0.85 * fade))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), Color(UIKit.hp_color(ratio), fade))


## A card: the blurred dark box. The one aimed at is framed in white and ringed by crisp outlines in the gem that
## pulse outwards; the rest are framed in the gem, fainter.
func _draw_card(r: Rect2, on: bool, pulse: float) -> void:
	if on:
		for g in 3:
			var grow := 4.0 + g * 4.0 + roundf(pulse * 2.0) * 2.0
			draw_rect(r.grow(grow), Color(UIKit.ACCENT.lightened(0.2), (0.7 - g * 0.22) * (0.6 + 0.4 * pulse)), false, 2.0)
	draw_style_box(UIKit.row_box(Color(0, 0, 0, 0), Color.WHITE if on else UIKit.BORDER_DIM, 1.0 if on else 0.6, true), r)


static func _fit(font: Font, text: String, fs: int, w: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in cards.size():
		if card_rect(i).grow(6.0).has_point((ev as InputEventMouseButton).position):
			tapped.emit(i)
			accept_event()
			return
