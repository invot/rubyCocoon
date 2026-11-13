extends RefCounted
## Shared UI construction helpers and the game theme. There is one look:
## - Every window is a near-black box at 60% with the scene behind it blurred, framed by a thin white ornamental border
##   from Kenney's Fantasy UI Borders. The black carries a faint tint of the player's gem (Ruby, Sapphire, Emerald or
##   Hematite; see set_accent and Prefs.accent); the border stays white. frame_box.gd draws it; the builders here (box, chip, highlight, plate_button, tag, ribbon...)
##   hand out its variants.
## - Headings take the gem; body text stays white. The gem also colours bars and filled (selected) slots.
## - Selected or focused: a bordered frame with corner marks. Primary or pressed: solid white with dark text.
##   Disabled: dim text, no frame. Item slots: square bordered tiles, the selected one filled.
## - The pack's divider separates sections (HSeparator, divider()) and flanks banner text (flanked()).
## The small icons are drawn here, pixel by pixel (cached textures); a few come from the flatUI kit (assets/ui/flat,
## copied by tools/build_ui_icons.gd).
## Fonts: Short Stack for body text, menu actions, dialogue and damage; League Spartan Semibold for
## names and headings. Missing symbols use bundled Noto Sans Symbols, then Godot's fallback.

const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const FrameBox = preload("res://scripts/ui/frame_box.gd")
const DividerBox = preload("res://scripts/ui/divider_box.gd")

const UI_DIR := "res://assets/ui/"
const FONT_FILE := "res://ui/LeagueSpartan.ttf"
const BODY_FONT_FILE := "res://ui/ShortStack-Regular.ttf"
const SYMBOL_FONT := preload("res://ui/NotoSansSymbols.ttf")
const TRIANGLE_FONT := preload("res://ui/NotoSansSymbols2.ttf")
## Shared League Spartan weights; keep ordinary text light and headings semibold.
const BODY_WEIGHT := 400
const HEAD_WEIGHT := 600
const BODY_SMALL := 21
const BODY_BIG := 21
## dialogue text: three lines fill the box
const BODY_HUGE := 32
const HEAD_SIZE := 22
const HEAD_SMALL := 21
const HEAD_BIG := 32
## Interactive text stays larger than captions. Long menus must page instead of shrinking their buttons.
const BUTTON_FONT_SIZE := 32
const MIN_BUTTON_HEIGHT := 56.0
const MIN_TOUCH_HEIGHT := 80.0

## The gem the interface is tinted with (Settings > Color): the windows' black, headings, bars and filled slots.
const ACCENTS := {"ruby": Color("#d21f2c"), "sapphire": Color("#3a6ad8"), "emerald": Color("#26a468"),
	"hematite": Color("#6f7d90")}
const ACCENT_ORDER := ["ruby", "sapphire", "emerald", "hematite"]
## settings saved by older versions
const OLD_ACCENTS := {"red": "ruby", "blue": "sapphire", "green": "emerald", "silver": "hematite", "purple": "ruby", "amber": "ruby"}

## How thick the border's lines are, in UI units; on screen they are the nearest whole number of pixels.
const LINE_W := 2.0
## text on a solid white (primary or pressed) fill
const DARK := Color("#101216")
## how much of the gem is mixed into the windows' black
const SHADE_MIX := 0.16

# ---- palette (see set_accent) ----
static var accent_name := "ruby"
## the gem itself: bars, fills, stripes
static var ACCENT := Color("#d21f2c")
## headings: the gem, lifted a little so it reads on the dark windows (not so far that red turns pink)
static var HEAD := Color("#dc4a54")
## highlighted text: lighter shades of the gem
static var GOLD := Color("#e05a63")
static var GOLD_BRIGHT := Color("#e98a90")
static var ORANGE := Color("#d21f2c")
## body text: white
static var INK := Color.WHITE
static var LIGHT := Color.WHITE
## secondary text
static var DIM := Color("#b9bcc6")
## the window fill, where a screen paints one itself: black with a faint tint of the gem, at 60%
static var FILL := Color(0.034, 0.005, 0.007, 0.6)
static var WINDOW_TOP := FILL
static var WINDOW_BOTTOM := FILL
## the border: white in every gem
static var BORDER := Color.WHITE
## an unselected frame beside a selected (white) one
static var BORDER_DIM := Color(0.6, 0.61, 0.66)
## faint rules inside a window
static var BORDER_INNER := Color(1, 1, 1, 0.22)
static var PAGE := Color("#08090c")
static var BROWN := Color("#08090c")
static var BG := Color("#08090c")
## legacy name used across the game: TEXT = body ink
static var TEXT := INK

static var _fonts := {}
## How much the 1280x720 UI is scaled up on this screen (1.5 on a 1080p-tall phone or a 1920x1080 window).
static var screen_scale := 1.0
static var _tex := {}
static var _styles := {}


## Speech is the bright exception: softly shaded white paper and a gem-coloured name plate.
static func speech_box(plate := false) -> StyleBox:
	var style: StyleBox = StyleBoxFlat.new() if plate else StyleBoxEmpty.new()
	if plate:
		style.bg_color = ACCENT
		style.set_corner_radius_all(10)
		style.shadow_color = Color(DARK, 0.18)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 16.0 if plate else 26.0
	style.content_margin_right = style.content_margin_left
	style.content_margin_top = 5.0 if plate else 18.0
	style.content_margin_bottom = 5.0 if plate else 30.0
	return style


## A single, antialiased paper/pointer silhouette; no screen reads or renderer-specific effects.
static func speech_surface() -> ColorRect:
	var paper := ColorRect.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/ui/speech.gdshader")
	material.set_shader_parameter("paper_top", INK)
	material.set_shader_parameter("paper_bottom", INK.lerp(DARK, 0.065))
	material.set_shader_parameter("shade", Color(DARK, 0.22))
	paper.material = material
	return paper


## Device safe area in logical UI coordinates (the same conversion for HUD notices and speech).
static func safe_rect(control: Control) -> Rect2:
	var full := control.get_viewport_rect()
	if not OS.has_feature("mobile"):
		return full
	var sa := DisplayServer.get_display_safe_area()
	var win := Vector2(DisplayServer.window_get_size())
	if sa.size.x <= 0 or win.x <= 0.0:
		return full
	var k := full.size / win
	var r := Rect2(Vector2(sa.position - DisplayServer.window_get_position()) * k, Vector2(sa.size) * k)
	var clip := full.intersection(r)
	return clip if clip.has_area() else full


## Switches the gem (one of ACCENTS, or an older colour name) and derives the tints from it; the theme and any window
## built afterwards follow it.
static func set_accent(name: String) -> void:
	name = OLD_ACCENTS.get(name, name)
	if not ACCENTS.has(name):
		name = "ruby"
	accent_name = name
	var g: Color = ACCENTS[name]
	ACCENT = g
	var text_gem := g.lerp(Color.WHITE, 0.55) if name == "hematite" else g
	HEAD = text_gem.lerp(Color.WHITE, 0.16)
	GOLD = text_gem.lerp(Color.WHITE, 0.25)
	GOLD_BRIGHT = text_gem.lerp(Color.WHITE, 0.45)
	ORANGE = g
	BORDER = Color.WHITE
	FrameBox.shade = Color.BLACK.lerp(g, SHADE_MIX)
	FILL = Color(FrameBox.shade, FrameBox.FILL_ALPHA)
	WINDOW_TOP = FILL
	WINDOW_BOTTOM = FILL
	_styles.clear()
	for k in _tex.keys():
		if String(k).begins_with("gen:"):
			_tex.erase(k)


## Turns the blur behind the windows on or off (off: plain boxes, a little more opaque; for a renderer the blur costs
## too much on).
static func set_blur(on: bool) -> void:
	FrameBox.blur_on = on


## The display name of a gem ("ruby" -> "Ruby").
static func gem_name(name: String) -> String:
	return String(OLD_ACCENTS.get(name, name)).capitalize()


## Input capability, independent of whether the on-screen pad is currently visible (it hides on the title).
static func touch_ui() -> bool:
	return is_instance_valid(Prefs) and (Prefs.is_mobile() or Prefs.touch_enabled())


## How tall an interactive row is. Keep the same touch minimum on the title and while the pad steps aside.
static func row_h() -> float:
	var floor_h := MIN_TOUCH_HEIGHT if touch_ui() else MIN_BUTTON_HEIGHT
	return maxf(floor_h, font_body().get_height(body_px(BUTTON_FONT_SIZE)) + 16.0)


static func _button_pad_y() -> float:
	return maxf(2.0, (row_h() - font_body().get_height(body_px(BUTTON_FONT_SIZE))) / 2.0)


# ================================================================ font sizes
## Call when the window size changes. Returns true if the scale changed.
static func set_screen_scale(window_size: Vector2) -> bool:
	var s := maxf(0.25, minf(window_size.x / 1280.0, window_size.y / 720.0))
	if is_equal_approx(s, screen_scale):
		return false
	screen_scale = s
	_sync_frames()
	return true


## The border art's cells cover a whole number of screen pixels.
static func _sync_frames() -> void:
	FrameBox.unit = maxf(1.0, roundf(LINE_W * screen_scale)) / screen_scale


## Body text's size (a smooth font: any size is sharp).
static func body_px(size: float) -> int:
	return maxi(1, int(round(size)))


## A heading's size.
static func head_px(size: float) -> int:
	return maxi(1, int(round(size)))


# ================================================================ resources
static func font_body() -> Font:
	return _font(BODY_WEIGHT)


static func font_head() -> Font:
	return _font(HEAD_WEIGHT)


## Compatibility alias for numeric labels: ordinary text uses the shared Regular weight.
static func font_bold() -> Font:
	return font_body()


## League Spartan at `weight`; bundled symbols keep arrows available in every export.
static func _font(weight: int) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f: FontFile = load(BODY_FONT_FILE if weight == BODY_WEIGHT else FONT_FILE)
	if f == null:
		return ThemeDB.fallback_font
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# Each face has its own fallback metrics; Short Stack and Spartan have different heights.
	var fallbacks: Array[Font] = []
	for source in [TRIANGLE_FONT, SYMBOL_FONT]:
		var symbols: FontFile = source.duplicate()
		for px in range(8, 97):
			symbols.set_cache_ascent(0, px, f.get_ascent(px))
			symbols.set_cache_descent(0, px, f.get_descent(px))
		fallbacks.append(symbols)
	f.fallbacks = []
	var fv := FontVariation.new()
	fv.base_font = f
	fv.fallbacks = fallbacks
	if weight == HEAD_WEIGHT:
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = fv
	return fv


## A UI texture: one of the icons drawn here (see ICONS), a flatUI icon (assets/ui/flat), or an older texture.
static func tex(name: String) -> Texture2D:
	var key := "gen:" + name if ICONS.has(name) else name
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	if ICONS.has(name):
		t = _icon_tex(name)
	elif ResourceLoader.exists(UI_DIR + "flat/" + name + ".png"):
		t = load(UI_DIR + "flat/" + name + ".png")
	elif ResourceLoader.exists(UI_DIR + name + ".png"):
		t = load(UI_DIR + name + ".png")
	_tex[key] = t
	return t


# ================================================================ windows
## A window: the blurred dark box in the window border. `pad` is extra content padding (l, t, r, b).
static func window(pad := Vector4(0, 0, 0, 0)) -> StyleBox:
	return FrameBox.make("window", BORDER, Color(0, 0, 0, 0), true, Vector4(24, 20, 24, 20) + pad)


## A small box in the row border: `fill` inside an `edge` border (tags, key caps, plates, buttons). The radius and
## edge width of the older rounded chips are ignored.
static func chip(fill: Color, edge: Color, _radius := 10.0, pad := Vector4(10, 2, 10, 2), _edge_w := 2.0) -> StyleBox:
	return FrameBox.make("row", edge, fill, false, pad + Vector4(4, 2, 4, 2))


## The same small box over the blurred scene (plates and buttons that stand on their own).
static func plate(edge := BORDER, pad := Vector4(14, 4, 14, 4)) -> StyleBox:
	return FrameBox.make("row", edge, Color(0, 0, 0, 0), true, pad)


## Primary or pressed: solid white (its text is DARK).
static func solid(pad := Vector4(14, 4, 14, 4)) -> StyleBox:
	return FrameBox.make("row", Color.WHITE, Color.WHITE, false, pad)


## The row border kept for drawing straight onto a control every frame (draw_style_box): `fill` inside `edge`,
## faded by `alpha`; `blurred` puts the blurred scene under it instead of a fill.
static func row_box(fill: Color, edge: Color, alpha := 1.0, blurred := false) -> StyleBox:
	var key := "row|%s|%s|%.2f|%s" % [fill.to_html(), edge.to_html(), alpha, blurred]
	if not _styles.has(key):
		var sb := FrameBox.make("row", Color(edge, edge.a * alpha), Color(fill, fill.a * alpha), blurred)
		sb.alpha = alpha
		_styles[key] = sb
	return _styles[key]


## The slot border kept for drawing straight onto a control every frame: a square tile, `fill` inside `edge`.
static func tile_box(fill: Color, edge: Color, alpha := 1.0) -> StyleBox:
	var key := "tile|%s|%s|%.2f" % [fill.to_html(), edge.to_html(), alpha]
	if not _styles.has(key):
		_styles[key] = FrameBox.make("slot", Color(edge, edge.a * alpha), Color(fill, fill.a * alpha))
	return _styles[key]


## An item slot: a square bordered tile; the selected one is filled with the gem.
static func slot_box(selected := false, pad := Vector4(8, 8, 8, 8)) -> StyleBox:
	if selected:
		return FrameBox.make("slot", Color.WHITE, ACCENT, false, pad)
	return FrameBox.make("slot", BORDER, Color(FrameBox.shade, 0.35), false, pad)


## A button standing on its own (not a list row): a dark bordered plate, its border white while focused; solid white
## with dark text while held; dim text and no frame once it's disabled.
static func plate_button(b: Button, pad := Vector4(12, 2, 12, 2)) -> void:
	var p := pad + Vector4(4, 2, 4, 2)
	var up := plate(BORDER, p)
	var focus := plate(Color.WHITE, p)
	var held := solid(p)
	var off := StyleBoxEmpty.new()
	off.content_margin_left = p.x
	off.content_margin_top = p.y
	off.content_margin_right = p.z
	off.content_margin_bottom = p.w
	b.add_theme_stylebox_override("normal", up)
	for st in ["hover", "focus"]:
		b.add_theme_stylebox_override(st, focus)
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, held)
	b.add_theme_stylebox_override("disabled", off)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, LIGHT)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, DARK)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.45))


## The boxes by their old texture names, so every screen picks up the look: `pad` is extra content padding
## (l, t, r, b).
static func box(name: String, pad := Vector4(0, 0, 0, 0)) -> StyleBox:
	match name:
		"banner":
			# map names and notices
			return plate(BORDER, Vector4(26, 10, 26, 10) + pad)
		"nameplate", "ribbon", "ribbon_small":
			return plate(BORDER, Vector4(20, 6, 20, 6) + pad)
		"frame":
			# key caps
			return FrameBox.make("row", DIM, Color(FrameBox.shade, 0.45), false, Vector4(12, 4, 12, 4) + pad)
		"bar_frame":
			return FrameBox.make("row", BORDER, FILL)
		"slot":
			# HUD readouts
			return plate(BORDER, Vector4(16, 12, 16, 12) + pad)
	return window(pad)


# ================================================================ theme
## The selected or focused row: a bordered frame with corner marks around it. `right` leaves room for a right-hand
## label.
static func highlight(right := 0.0) -> StyleBox:
	var pad_y := _button_pad_y()
	return FrameBox.make("row", Color.WHITE, Color(1, 1, 1, 0.07), false, Vector4(22, pad_y, 12 + right, pad_y))


## A pressed row: solid white (its text turns DARK).
static func pressed_row(right := 0.0) -> StyleBox:
	var pad_y := _button_pad_y()
	return solid(Vector4(22, pad_y, 12 + right, pad_y))


static func make_theme() -> Theme:
	_sync_frames()
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = body_px(BODY_SMALL)
	var win := window()
	t.set_stylebox("panel", "PanelContainer", win)
	t.set_stylebox("panel", "Panel", win)

	# menu items (body font): a frame around the focused row, solid white while it's pressed
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 22
	empty.content_margin_right = 12
	empty.content_margin_top = _button_pad_y()
	empty.content_margin_bottom = _button_pad_y()
	var hl := highlight()
	var held := pressed_row()
	for st in ["normal", "disabled"]:
		t.set_stylebox(st, "Button", empty)
	for st in ["hover", "focus"]:
		t.set_stylebox(st, "Button", hl)
	for st in ["pressed", "hover_pressed"]:
		t.set_stylebox(st, "Button", held)
	t.set_font("font", "Button", font_body())
	t.set_font_size("font_size", "Button", body_px(BUTTON_FONT_SIZE))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", DARK)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_constant("h_separation", "Button", 12)

	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 2)

	var le := chip(Color(FrameBox.shade, 0.45), BORDER, 12.0, Vector4(14, 6, 14, 6))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.5))
	t.set_font("font", "LineEdit", font_body())
	t.set_font_size("font_size", "LineEdit", body_px(BODY_HUGE))

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(1, 1, 1, 0.12)
	sb_bg.content_margin_left = 4
	sb_bg.content_margin_right = 4
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = BORDER
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", sb_grab)
	t.set_stylebox("scroll", "VScrollBar", sb_bg)

	var sep := DividerBox.new()
	sep.line = BORDER
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", int(ceil(FrameBox.divider_height())) + 8)
	return t


# ================================================================ widgets
## Body text (League Spartan Regular): small (<24), big (24-31) or huge (32+, dialogue).
static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_body())
	l.add_theme_font_size_override("font_size", body_px(BODY_HUGE if size >= BODY_HUGE else (BODY_BIG if size >= 24 else BODY_SMALL)))
	l.add_theme_color_override("font_color", color)
	return l


## Heading text (League Spartan Semibold): titles, tabs, name plates, map names. Headings take the gem (HEAD); the body
## white or the raw gem passed in by a caller is taken as "the heading colour".
static func header(text: String, color := HEAD, size := HEAD_SIZE) -> Label:
	var l := Label.new()
	if color.is_equal_approx(INK) or color.is_equal_approx(ACCENT):
		color = HEAD
	l.text = text
	l.add_theme_font_override("font", font_head())
	l.add_theme_font_size_override("font_size", head_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## White text with a black outline, for text drawn straight over the 3D world.
static func shadow_label(text: String, size := 20, color := LIGHT) -> Label:
	var l := header(text, color, 64 if size >= 60 else HEAD_BIG) if size >= 28 else label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8 if size >= 28 else 6)
	return l


## A window (the default PanelContainer style).
static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


## A window for HUD readouts.
static func dark_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", box("slot", Vector4(0, -2, 0, -2)))
	return p


## A bordered plate for map names and notices.
static func banner_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", box("banner"))
	return p


## The pack's divider as a control `w` wide, tinted in the gem; `ends`: "both", "left", "right" or "none" carry the
## ornament.
static func divider(w := 0.0, ends := "both") -> Panel:
	var p := Panel.new()
	var sb := DividerBox.new()
	sb.line = BORDER
	sb.left_end = ends in ["both", "left"]
	sb.right_end = ends in ["both", "right"]
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, ceil(FrameBox.divider_height()))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Banner text flanked by the divider: [line, ornament] text [ornament, line]. `w`: each side's width (0: the
## sides stretch to fill the row).
static func flanked(c: Control, w := 70.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var a := divider(w, "right")
	var b := divider(w, "left")
	if w <= 0.0:
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(a)
	hb.add_child(c)
	hb.add_child(b)
	return hb


## A title plate: a heading in the gem on a bordered plate, for page and screen headings.
static func ribbon(text: String, small := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("ribbon_small" if small else "ribbon"))
	var l := header(text, HEAD, HEAD_SIZE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func icon(name: String, px := 0.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex(name)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if px > 0.0:
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## A small tag: white text in a bordered box tinted `col`.
static func tag(text: String, col: Color, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(Color(col.darkened(0.55), 0.7), col.lerp(Color.WHITE, 0.22), 9.0, Vector4(9, 0, 9, 0)))
	var l := label(text, size, LIGHT)
	p.add_child(l)
	return p


## An element's tag, in the gem like everything else (its name tells the element apart).
static func element_tag(el: String, size := 14) -> PanelContainer:
	return tag(Elements.label(el), ACCENT, size)


## Rank as stars.
static func stars(n: int, of := 0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	for i in maxi(n, of):
		hb.add_child(icon("icon_star" if i < n else "icon_star_empty"))
	return hb


static func beast_icon(b, px := 64) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = PixelArt.beast_texture(b.genes)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return tr


## Positions a control inside a full-rect parent.
static func place(c: Control, where: String, margin := Vector2(24, 24)) -> void:
	if where in ["bottom_right", "bottom"]:
		var reserve: float = UI.bottom_reserve() if is_instance_valid(UI) else 0.0
		margin.y += reserve
		if where == "bottom_right" and is_instance_valid(UI) and UI.is_touch():
			margin.x = maxf(margin.x, 290.0)
	match where:
		"center":
			c.set_anchors_preset(Control.PRESET_CENTER, true)
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
		"bottom_right":
			c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
			c.offset_right = -margin.x
			c.offset_bottom = -margin.y
			c.offset_left = -margin.x
			c.offset_top = -margin.y
		"right":
			c.set_anchors_preset(Control.PRESET_CENTER_RIGHT, true)
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
			c.offset_right = -margin.x
			c.offset_left = -margin.x
		"left":
			c.set_anchors_preset(Control.PRESET_CENTER_LEFT, true)
			c.grow_horizontal = Control.GROW_DIRECTION_END
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
			c.offset_left = margin.x
			c.offset_right = margin.x
		"top_left":
			c.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
			c.offset_left = margin.x
			c.offset_top = margin.y
		"top_right":
			c.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.offset_right = -margin.x
			c.offset_left = -margin.x
			c.offset_top = margin.y
			c.offset_bottom = margin.y
		"bottom":
			c.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
			c.offset_bottom = -margin.y
			c.offset_top = -margin.y


## The outline of a rectangle with round corners (touch shapes).
static func round_rect(rect: Rect2, r: float) -> PackedVector2Array:
	r = clampf(r, 0.0, minf(rect.size.x, rect.size.y) / 2.0)
	var pts := PackedVector2Array()
	var seg := clampi(int(r / 2.0), 3, 10)
	var centres := [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r)]
	var starts := [PI, PI * 1.5, 0.0, PI * 0.5]
	for k in 4:
		for i in seg + 1:
			var a: float = starts[k] + PI * 0.5 * float(i) / seg
			var point: Vector2 = centres[k] + Vector2(cos(a), sin(a)) * r
			if pts.is_empty() or not pts[-1].is_equal_approx(point):
				pts.append(point)
	if pts.size() > 1 and pts[-1].is_equal_approx(pts[0]):
		pts.remove_at(pts.size() - 1)
	return pts


## The cross over a fallen beast: one bold X, a single shape with square-cut arms (a plus turned 45 degrees), filled in
## the gem's light shade inside a dark outline. `c`: its middle; `s`: half its width.
static func draw_cross(ci: CanvasItem, c: Vector2, s: float) -> void:
	var t := s * 0.3
	var outline := _cross_shape(c, s + 2.5, t + 2.5)
	ci.draw_colored_polygon(outline, Color(0, 0, 0, 0.75))
	ci.draw_colored_polygon(_cross_shape(c, s, t), ACCENT.lightened(0.25))


## An X: a plus sign with arms `s` long and `t` thick either side of the middle, turned 45 degrees.
static func _cross_shape(c: Vector2, s: float, t: float) -> PackedVector2Array:
	var plus := [Vector2(-t, -s), Vector2(t, -s), Vector2(t, -t), Vector2(s, -t), Vector2(s, t), Vector2(t, t),
		Vector2(t, s), Vector2(-t, s), Vector2(-t, t), Vector2(-s, t), Vector2(-s, -t), Vector2(-t, -t)]
	var out := PackedVector2Array()
	for p in plus:
		out.append(c + (p as Vector2).rotated(PI / 4.0))
	return out


## A health bar's colour: a light shade of the gem while healthy, the gem when hurt, a dark shade when nearly out.
static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return ACCENT.lerp(Color.WHITE, 0.30)
	if ratio > 0.2:
		return ACCENT
	return ACCENT.darkened(0.35)


# ================================================================ drawn icons
## Small icons drawn here as pixel bitmaps ("#" the colour, "+" the accent, "." clear), so they stay crisp and take the
## accent: [rows...].
const ICONS := {
	"icon_star": ["....+....", "....+....", "...+++...", "+++++++++", ".+++++++.", "..+++++..", "..++.++..", ".++...++.", ".+.....+."],
	"icon_star_empty": ["....#....", "....#....", "...#.#...", "###...###", ".#.....#.", "..#...#..", "..#.#.#..", ".##...##.", ".#.....#."],
	"star": ["....+....", "....+....", "...+++...", "+++++++++", ".+++++++.", "..+++++..", "..++.++..", ".++...++.", ".+.....+."],
	"star_empty": ["....#....", "....#....", "...#.#...", "###...###", ".#.....#.", "..#...#..", "..#.#.#..", ".##...##.", ".#.....#."],
	"heart": [".++...++.", "++++.++++", "+++++++++", "+++++++++", ".+++++++.", "..+++++..", "...+++...", "....+....", "........."],
	"heart_empty": [".##...##.", "#..#.#..#", "#...#...#", "#.......#", ".#.....#.", "..#...#..", "...#.#...", "....#....", "........."],
	"icon_coin": ["..#####..", ".#+++++#.", "#++###++#", "#+#+++++#", "#+#+++++#", "#+#+++++#", "#++###++#", ".#+++++#.", "..#####.."],
	"icon_energy": ["....+++..", "...+++...", "..+++....", ".+++++++.", "....+++..", "...+++...", "..+++....", ".++......", ".+......."],
	"icon_energy_empty": ["....###..", "...#.#...", "..#.#....", ".#.....#.", "....#.#..", "...#.#...", "..#.#....", ".##......", ".#......."],
	"arrow_down": ["#########", ".#######.", "..#####..", "...###...", "....#...."],
	"icon_arrow": ["#........", "###......", "#####....", "#######..", "#########", "#######..", "#####....", "###......", "#........"],
	"tab_beasts": ["..##.##..", ".####.###", ".###..##.", "...###...", "#.#####.#", "##.###.##", "..#####..", ".#######.", ".#######.", "..#####.."],
}


## The icon's bitmap, each of its pixels drawn 3 x 3 (the icons are tiny), so it can be used at its own size.
static func _icon_tex(name: String) -> ImageTexture:
	var rows: Array = ICONS[name]
	var w := String(rows[0]).length()
	var h := rows.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var r: String = rows[y]
		for x in w:
			match r[x]:
				"#":
					img.set_pixel(x, y, BORDER)
				"+":
					img.set_pixel(x, y, ACCENT.lerp(Color.WHITE, 0.15))
	img.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
