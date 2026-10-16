extends RefCounted
## Shared UI construction helpers and the game theme: a warm pixel-art storybook look.
## Textures come from assets/ui (built by tools/build_ui_assets.py from the kits in ui/).
## Fonts: Ticketing for body text, BoldPixels for menu items and headers.

const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

const UI_DIR := "res://assets/ui/"
const BODY_FONT := "res://ui/Ticketing.ttf"
const HEAD_FONT := "res://ui/BoldPixels.ttf"
## Ticketing is drawn on a 30-unit grid: 22 and 33 px keep its strokes on whole pixels.
const BODY_SMALL := 22
const BODY_BIG := 33
## dialogue text: three lines fill the box
const BODY_HUGE := 44
## BoldPixels is crisp at multiples of 16.
const HEAD_SIZE := 32
const HEAD_SMALL := 16

# ---- palette (sampled from the TravelBook pack) ----
const INK := Color("#3a2626")
const ACCENT := Color("#9c4351")
const PAGE := Color("#ffd7a8")
const LIGHT := Color("#ffe3c6")
const GOLD_BRIGHT := Color("#ffd071")
const ORANGE := Color("#ffa34d")
const BROWN := Color("#45292a")
## legacy names used across the game: TEXT = body ink, GOLD = highlighted text, DIM = secondary text
const TEXT := INK
const GOLD := ACCENT
const DIM := Color("#8a6656")
const BG := Color("#45292a")

static var _fonts := {}
## How much the 1280x720 UI is scaled up on this screen (1.5 on a 1080p-tall phone or a 1920x1080 window).
static var screen_scale := 1.0
## Both fonts are pixel fonts drawn on a grid: Ticketing steps every 3% of its size (33.3 px per em), BoldPixels
## every 1/16. They only look pixel-crisp when, on the real screen, that step is a whole number of pixels, so every
## size is snapped to the nearest such size (see body_px / head_px).
const TICKETING_STEP := 100.0 / 3.0
const BOLDPIXELS_STEP := 16.0
static var _tex := {}
static var _manifest := {}


# ================================================================ crisp pixel fonts
## Call when the window size changes. Returns true if the scale changed.
static func set_screen_scale(window_size: Vector2) -> bool:
	var s := maxf(0.25, minf(window_size.x / 1280.0, window_size.y / 720.0))
	if is_equal_approx(s, screen_scale):
		return false
	screen_scale = s
	return true


static func _crisp(target: float, step: float) -> int:
	var k := maxi(1, int(round(target * screen_scale / step)))
	return maxi(1, int(round(k * step / screen_scale)))


## The Ticketing size closest to `size` that lands on whole screen pixels.
static func body_px(size: float) -> int:
	return _crisp(size, TICKETING_STEP)


## The BoldPixels size closest to `size` that lands on whole screen pixels.
static func head_px(size: float) -> int:
	return _crisp(size, BOLDPIXELS_STEP)


# ================================================================ resources
static func font_body() -> Font:
	return _font(BODY_FONT)


static func font_head() -> Font:
	return _font(HEAD_FONT)


static func _font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: FontFile = load(path)
	if f == null:
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	_fonts[path] = f
	return f


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := UI_DIR + name + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = t
	return t


static func _margins(name: String) -> Array:
	if _manifest.is_empty():
		var f := FileAccess.open(UI_DIR + "ui_manifest.json", FileAccess.READ)
		if f:
			_manifest = JSON.parse_string(f.get_as_text())
	return _manifest.get(name, {}).get("margins", [8, 8, 8, 8])


## A nine-slice StyleBoxTexture from a UI texture; `pad` is extra content padding (l, t, r, b).
static func box(name: String, pad := Vector4(0, 0, 0, 0)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	var m := _margins(name)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = m[0] + pad.x
	sb.content_margin_top = m[1] + pad.y
	sb.content_margin_right = m[2] + pad.z
	sb.content_margin_bottom = m[3] + pad.w
	return sb


# ================================================================ theme
## The selected menu row: a yellow frame with a soft yellow fill. `right` leaves room for a right-hand label.
static func highlight(right := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff3a0", 0.55)
	sb.border_color = Color("#f5c400")
	sb.set_border_width_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 12 + right
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.anti_aliasing = false
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = body_px(BODY_SMALL)
	var parchment := box("textfield", Vector4(10, 6, 10, 8))
	t.set_stylebox("panel", "PanelContainer", parchment)
	t.set_stylebox("panel", "Panel", parchment)

	# menu items: BoldPixels, with the gold selection strip behind the focused row
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 18
	empty.content_margin_right = 12
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	var hl := highlight()
	for st in ["normal", "disabled"]:
		t.set_stylebox(st, "Button", empty)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		t.set_stylebox(st, "Button", hl)
	t.set_font("font", "Button", font_head())
	t.set_font_size("font_size", "Button", head_px(HEAD_SIZE))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	t.set_constant("h_separation", "Button", 10)

	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 2)

	var le := box("textfield_small", Vector4(10, 4, 10, 4))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ORANGE, 0.5))
	t.set_font("font", "LineEdit", font_body())
	t.set_font_size("font_size", "LineEdit", body_px(BODY_BIG))

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color("#dea974")
	sb_bg.content_margin_left = 3
	sb_bg.content_margin_right = 3
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = ACCENT
	sb_grab.border_color = INK
	sb_grab.set_border_width_all(2)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", sb_grab)
	t.set_stylebox("scroll", "VScrollBar", sb_bg)

	var sep := StyleBoxTexture.new()
	sep.texture = tex("separator")
	sep.texture_margin_left = 18
	sep.texture_margin_right = 18
	sep.content_margin_top = 8
	sep.content_margin_bottom = 8
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 18)
	return t


# ================================================================ widgets
## Body text in Ticketing: small (<24), big (24-39) or huge (40+), each snapped to a crisp size for this screen.
static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_body())
	l.add_theme_font_size_override("font_size", body_px(BODY_HUGE if size >= 40 else (BODY_BIG if size >= 24 else BODY_SMALL)))
	l.add_theme_color_override("font_color", color)
	return l


## Header / menu text in BoldPixels.
static func header(text: String, color := INK, size := HEAD_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_head())
	l.add_theme_font_size_override("font_size", head_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## Light text with a dark outline, for text drawn straight over the 3D world.
static func shadow_label(text: String, size := 20, color := LIGHT) -> Label:
	var l := header(text, color, 64 if size >= 60 else HEAD_SIZE) if size >= 28 else label(text, size, color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8 if size >= 28 else 6)
	return l


## Parchment panel (the default PanelContainer style).
static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


## Dark-brown panel for HUD readouts; put LIGHT text on it.
static func dark_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", box("slot", Vector4(8, 4, 8, 6)))
	return p


## The TravelBook banner: parchment strip with a maroon rim and gold corners.
static func banner_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", box("banner", Vector4(16, 4, 16, 6)))
	return p


## A maroon ribbon with a BoldPixels title, for page and screen headings.
static func ribbon(text: String, small := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("ribbon_small" if small else "ribbon", Vector4(10, 0, 10, 0)))
	var l := header(text, LIGHT, HEAD_SIZE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color("#493333"))
	l.add_theme_constant_override("outline_size", 4)
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


static func tag(text: String, col: Color, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.15)
	sb.border_color = col.darkened(0.55)
	sb.set_border_width_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = -2
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, LIGHT)
	l.add_theme_color_override("font_outline_color", col.darkened(0.6))
	l.add_theme_constant_override("outline_size", 3)
	p.add_child(l)
	return p


static func element_tag(el: String, size := 14) -> PanelContainer:
	return tag(Elements.label(el), Elements.color(el), size)


## Rank as gold stars.
static func stars(n: int, of := 0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	for i in maxi(n, of):
		hb.add_child(icon("star" if i < n else "star_empty"))
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


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("#5aa840")
	if ratio > 0.2:
		return Color("#f0b830")
	return Color("#d8402e")
