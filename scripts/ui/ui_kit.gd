extends RefCounted
## Shared UI construction helpers and the game theme, in one of two looks (Settings > Style, see set_style):
## - Pixel (the default): the 1-bit kit's crisp white frames on near-black windows, with the player's gem (Ruby,
##   Sapphire, Emerald or Hematite; see set_accent and Prefs.accent) behind the white only where something is picked
##   out: the selected row, the open tab, buttons, tags and name plates. Text and lines are plain white. Its pieces
##   are cut from the kits by tools/build_pixel_ui.gd and painted here (piece()).
## - Classic: the soft, rounded windows of a cosy PS2 RPG, all in one colour. Windows are deep shades of the gem with
##   a gentle gradient, a pale border, round corners and a soft shadow (cozy_box.gd); text, bars, tags and the
##   selection pill are lighter and brighter shades of the same gem.
## The small icons are drawn here, pixel by pixel (cached textures); a few come from the flatUI kit (assets/ui/flat,
## copied by tools/build_ui_icons.gd).
## Fonts: BoldPixels (ui/BoldPixels.ttf) for body text, menus and dialogue; Lunchtime Doubly So (ui/lunchds.ttf) only
## for headings (titles, tabs, name plates, map names).

const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const CozyBox = preload("res://scripts/ui/cozy_box.gd")

const UI_DIR := "res://assets/ui/"
const BODY_FONT := "res://ui/BoldPixels.ttf"
const HEAD_FONT := "res://ui/lunchds.ttf"
## Both fonts are drawn on a 16-pixels-per-em grid: sizes that are multiples of 16 on the real screen keep every
## stroke on whole pixels (see _crisp). On a 1080p screen (scale 1.5) body text lands on 32 screen pixels and
## dialogue on 48.
const BODY_SMALL := 21
const BODY_BIG := 21
## dialogue text: three lines fill the box
const BODY_HUGE := 32
const HEAD_SIZE := 22
const HEAD_SMALL := 21
const HEAD_BIG := 32
const FONT_STEP := 16.0

## The gem the whole interface is tinted with (Settings > Gem): every window, border, text, bar and tag is a shade
## of it, so the menus are one colour.
const ACCENTS := {"ruby": Color("#d6304f"), "sapphire": Color("#3a6ad8"), "emerald": Color("#26a468"),
	"hematite": Color("#6f7d90")}
const ACCENT_ORDER := ["ruby", "sapphire", "emerald", "hematite"]
## settings saved by older versions
const OLD_ACCENTS := {"red": "ruby", "blue": "sapphire", "green": "emerald", "silver": "hematite", "purple": "ruby", "amber": "ruby"}

## window corner radius
const RADIUS := 16.0

## The two looks (Settings > Style), and what they're called there.
const STYLES := ["pixel", "cozy"]
const STYLE_NAMES := {"pixel": "Pixel", "cozy": "Classic"}
const PIXEL_UI := "res://assets/ui/pixel_ui.res"
## the Pixel style's two colours (the 1-bit kit's own): its white and its near-black
const PIXEL_LINE := Color("#ebede9")
const PIXEL_FILL := Color("#090a14")
const PIXEL_DIM := Color("#9d9fa8")
## how many UI pixels each pixel of a piece covers (3 screen pixels on a 1080p phone)
const PIXEL_SCALE := 2
## For each frame piece: how far in from its edges its corners reach (piece pixels), so a window stretches only its
## straight sides and middle.
const PIECE_MARGIN := {"window": 16, "panel": 5, "plate": 4, "plate_small": 3, "panel_pins": 6, "panel_tall": 6}
## The game's icon names drawn with the 1-bit kit's icons in the Pixel style: [piece, fill, line] ("fill"/"line" are
## the style's own colours, "dim" its grey, "gem" the accent).
const PIXEL_ICONS := {
	"icon_star": ["star", "fill", "line"], "star": ["star", "fill", "line"],
	"icon_star_empty": ["star", "fill", "dim_dark"], "star_empty": ["star", "fill", "dim_dark"],
	"heart": ["heart", "fill", "line"], "heart_empty": ["heart", "fill", "dim_dark"],
	"icon_energy": ["shield", "fill", "line"], "icon_energy_empty": ["shield", "fill", "dim_dark"],
	"arrow_down": ["i_down", "fill", "line"], "icon_arrow": ["i_right", "fill", "line"],
	"tab_trainer": ["i_trophy", "fill", "line"], "icon_notes": ["i_sound", "fill", "line"], "tab_bag": ["potion", "fill", "line"],
	"icon_quill": ["i_list", "fill", "line"], "icon_map": ["i_target", "fill", "line"], "tab_settings": ["i_gear", "fill", "line"],
}

static var style := "pixel"
static var _pieces := {}
static var _piece_tex := {}

# ---- palette: shades of the gem (see set_accent) ----
static var accent_name := "ruby"
## the gem itself: the selection pill, tabs, headings, stripes
static var ACCENT := Color("#d6304f")
## highlighted text: the gem, lifted so it reads on the dark windows
static var GOLD := Color("#e57a8e")
static var GOLD_BRIGHT := Color("#efa6b4")
static var ORANGE := Color("#d6304f")
## text on the windows: white with a breath of the gem
static var INK := Color("#fff2f4")
static var LIGHT := Color("#fff9fa")
## secondary text
static var DIM := Color("#c9a3ab")
## the window fill (top and bottom of its gradient) and the border
static var WINDOW_TOP := Color(0.24, 0.10, 0.13, 0.94)
static var WINDOW_BOTTOM := Color(0.12, 0.04, 0.06, 0.94)
static var BORDER := Color("#f8dfe4")
static var BORDER_INNER := Color("#73404a")
static var PAGE := Color("#1e0c10")
static var BROWN := Color("#14080b")
static var BG := Color("#14080b")
## legacy name used across the game: TEXT = body ink
static var TEXT := INK

static var _fonts := {}
## How much the 1280x720 UI is scaled up on this screen (1.5 on a 1080p-tall phone or a 1920x1080 window).
static var screen_scale := 1.0
static var _tex := {}
static var _styles := {}


## Switches the gem (one of ACCENTS, or an older colour name) and derives every shade of the palette from it; the
## theme and any window built afterwards follow it.
static func set_accent(name: String) -> void:
	name = OLD_ACCENTS.get(name, name)
	if not ACCENTS.has(name):
		name = "ruby"
	accent_name = name
	var g: Color = ACCENTS[name]
	var h := g.h
	var sat := g.s
	ACCENT = g
	GOLD = g.lerp(Color.WHITE, 0.38)
	GOLD_BRIGHT = g.lerp(Color.WHITE, 0.58)
	ORANGE = g
	INK = Color.from_hsv(h, sat * 0.07, 1.0)
	LIGHT = Color.from_hsv(h, sat * 0.03, 1.0)
	DIM = Color.from_hsv(h, sat * 0.30, 0.80)
	WINDOW_TOP = Color.from_hsv(h, minf(1.0, sat * 0.62), 0.25, 0.94)
	WINDOW_BOTTOM = Color.from_hsv(h, minf(1.0, sat * 0.70), 0.12, 0.94)
	BORDER = Color.from_hsv(h, sat * 0.14, 0.98)
	BORDER_INNER = Color.from_hsv(h, sat * 0.50, 0.46)
	PAGE = Color.from_hsv(h, sat * 0.6, 0.12)
	BROWN = Color.from_hsv(h, sat * 0.6, 0.08)
	BG = BROWN
	if pixel():
		# white lines and text on near-black; the gem only fills what's picked out
		INK = PIXEL_LINE
		LIGHT = PIXEL_LINE
		GOLD = PIXEL_LINE
		GOLD_BRIGHT = PIXEL_LINE
		DIM = PIXEL_DIM
		BORDER = PIXEL_LINE
		BORDER_INNER = Color("#3b3d4a")
		WINDOW_TOP = Color(PIXEL_FILL, 0.95)
		WINDOW_BOTTOM = Color(PIXEL_FILL, 0.95)
		PAGE = PIXEL_FILL
		BROWN = PIXEL_FILL
		BG = PIXEL_FILL
	TEXT = INK
	_styles.clear()
	_piece_tex.clear()
	for k in _tex.keys():
		if String(k).begins_with("gen:"):
			_tex.erase(k)


## Switches the look ("pixel" or "cozy"; see the top) and derives the palette for it; like set_accent, the theme and
## any window built afterwards follow it.
static func set_style(name: String) -> void:
	style = name if name in STYLES else "pixel"
	set_accent(accent_name)


static func pixel() -> bool:
	return style == "pixel"


## A piece of the Pixel style (tools/build_pixel_ui.gd) painted: its fill, mid shade and lines in these colours, each
## of its pixels `scale` x `scale` (made once per piece and colours). Without a mid colour, the mid shade is a third
## of the way from the fill to the line. Null if there's no such piece.
static func piece(name: String, fill: Color, line := PIXEL_LINE, mid := Color(0, 0, 0, 0), scale := PIXEL_SCALE) -> ImageTexture:
	var key := "%s|%s|%s|%s|%d" % [name, fill.to_html(), line.to_html(), mid.to_html(), scale]
	if _piece_tex.has(key):
		return _piece_tex[key]
	if _pieces.is_empty():
		var res: Resource = load(PIXEL_UI) if ResourceLoader.exists(PIXEL_UI) else null
		_pieces = res.get_meta("pieces") if res != null else {"": null}
	var src: Image = _pieces.get(name, null)
	if src == null:
		return null
	if mid.a <= 0.0:
		mid = fill.lerp(line, 0.35)
	var w := src.get_width()
	var h := src.get_height()
	var data := src.get_data()
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var cols := [fill, mid, line]
	for i in w * h:
		if data[i * 4 + 3] < 128:
			continue
		var t := data[i * 4]
		var c: Color = cols[0 if t < 64 else (1 if t < 192 else 2)]
		out[i * 4] = c.r8
		out[i * 4 + 1] = c.g8
		out[i * 4 + 2] = c.b8
		out[i * 4 + 3] = c.a8
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_piece_tex[key] = tex
	return tex


## A frame piece as a window style: its corners kept, its sides and middle stretched; `pad`: the content padding
## (l, t, r, b) inside it.
static func pixel_box(name: String, fill: Color, line := PIXEL_LINE, pad := Vector4(14, 10, 14, 10)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = piece(name, Color(fill, 1.0), Color(line, 1.0))
	sb.modulate_color = Color(1, 1, 1, minf(fill.a, 1.0) if fill.a > 0.0 else 1.0)
	var m := float(int(PIECE_MARGIN.get(name, 4)) * PIXEL_SCALE)
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## The display name of a gem ("ruby" -> "Ruby").
static func gem_name(name: String) -> String:
	return String(OLD_ACCENTS.get(name, name)).capitalize()


## How tall a menu row is: about a centimetre on a phone (48 dp or more), a little less with keys and a mouse.
static func row_h() -> float:
	return 80.0 if is_instance_valid(UI) and UI.is_touch() else 52.0


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


## The font size closest to `size` that lands on whole screen pixels.
static func body_px(size: float) -> int:
	return _crisp(size, FONT_STEP)


static func head_px(size: float) -> int:
	return _crisp(size, FONT_STEP)


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
	# Lunchtime has no arrows or stars and neither font has notes: those come from BoldPixels, then Godot's default
	f.fallbacks = [ThemeDB.fallback_font] if path == BODY_FONT else [_font(BODY_FONT), ThemeDB.fallback_font]
	_fonts[path] = f
	return f


## A UI texture: one of the icons drawn here (see ICONS), a flatUI icon (assets/ui/flat), or an older texture.
static func tex(name: String) -> Texture2D:
	if pixel() and PIXEL_ICONS.has(name):
		var spec: Array = PIXEL_ICONS[name]
		var pal := {"fill": PIXEL_FILL, "line": PIXEL_LINE, "dim_dark": Color("#3b3d4a"), "gem": ACCENT}
		return piece(String(spec[0]), Color(0, 0, 0, 0) if spec[0] in ["star", "heart", "shield", "potion"] else pal[spec[1]], pal[spec[2]])
	var key := "gen:" + name if ICONS.has(name) or name in ["window", "banner", "cursor_bar", "slot"] else name
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
## A window in the theme's colours (Pixel: the 1-bit kit's frame; Classic: rounded); `pad` is extra content padding
## (l, t, r, b).
static func cozy(pad := Vector4(0, 0, 0, 0), radius := RADIUS) -> StyleBox:
	if pixel():
		return pixel_box("window" if radius >= RADIUS else "panel", WINDOW_BOTTOM, PIXEL_LINE,
			Vector4(34, 32, 34, 32) + pad if radius >= RADIUS else Vector4(16, 14, 16, 14) + pad)
	var sb := CozyBox.new()
	sb.top = WINDOW_TOP
	sb.bottom = WINDOW_BOTTOM
	sb.border = BORDER
	sb.radius = radius
	sb.content_margin_left = 14 + pad.x
	sb.content_margin_top = 10 + pad.y
	sb.content_margin_right = 14 + pad.z
	sb.content_margin_bottom = 10 + pad.w
	return sb


## The 1-bit plate in these colours, for drawing straight onto a control (draw_style_box): `alpha` fades it, `scale`
## makes its pixels bigger (a big button's edge). Kept, so it can be drawn every frame.
static func pixel_plate(fill: Color, line := PIXEL_LINE, alpha := 1.0, scale := PIXEL_SCALE) -> StyleBoxTexture:
	var key := "plate|%s|%s|%.2f|%d" % [fill.to_html(), line.to_html(), alpha, scale]
	if _styles.has(key):
		return _styles[key]
	var sb := StyleBoxTexture.new()
	sb.texture = piece("plate", Color(fill, 1.0), Color(line, 1.0), Color(0, 0, 0, 0), scale)
	sb.modulate_color = Color(1, 1, 1, alpha * fill.a)
	var m := float(int(PIECE_MARGIN["plate"]) * scale)
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	_styles[key] = sb
	return sb


## A small chip: `fill` inside a `edge` border (tags, key caps, name plates, buttons). Pixel: the 1-bit kit's plate in
## those colours.
static func chip(fill: Color, edge: Color, radius := 10.0, pad := Vector4(10, 2, 10, 2), edge_w := 2.0) -> StyleBox:
	if pixel():
		# (a little more room inside than the rounded chip gives: the plate's edge and corner ticks are square)
		return pixel_box("plate", fill, edge if edge.a > 0.3 else BORDER_INNER, pad + Vector4(4, 2, 4, 2))
	var sb := CozyBox.new()
	sb.top = fill.lightened(0.12)
	sb.bottom = fill.darkened(0.08)
	sb.border = edge
	sb.border_w = edge_w
	sb.radius = radius
	sb.rim = Color(1, 1, 1, 0.0)
	sb.shadow = Color(0, 0, 0, 0.22)
	sb.shadow_off = Vector2(0, 2)
	sb.shadow_size = 3.0
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## The window styles by their old texture names, so every screen picks up the new look: `pad` is extra content
## padding (l, t, r, b).
static func box(name: String, pad := Vector4(0, 0, 0, 0)) -> StyleBox:
	if pixel():
		match name:
			"banner":
				return pixel_box("panel_pins", WINDOW_BOTTOM, PIXEL_LINE, Vector4(24, 12, 22, 12) + pad)
			"nameplate", "ribbon", "ribbon_small":
				return pixel_box("plate", ACCENT, PIXEL_LINE, Vector4(20, 6, 20, 6) + pad)
			"frame":
				return pixel_box("plate", WINDOW_BOTTOM, PIXEL_LINE, Vector4(10, 3, 10, 3) + pad)
			"bar_frame":
				return pixel_box("plate", WINDOW_BOTTOM, PIXEL_LINE, Vector4.ZERO)
			"slot":
				return pixel_box("panel", WINDOW_BOTTOM, PIXEL_LINE, Vector4(14, 12, 14, 12) + pad)
		return pixel_box("window", WINDOW_BOTTOM, PIXEL_LINE, Vector4(34, 32, 34, 32) + pad)
	match name:
		"banner":
			# map names and notices: an accent stripe down the left edge
			var b: CozyBox = cozy(pad + Vector4(18, 2, 10, 2))
			b.stripe = ACCENT
			return b
		"dialogue":
			return cozy(pad + Vector4(0, 2, 0, 0), RADIUS + 6.0)
		"nameplate", "ribbon", "ribbon_small":
			var np := chip(ACCENT, BORDER, 14.0, Vector4(18 + pad.x, 4 + pad.y, 18 + pad.z, 4 + pad.w), 3.0)
			return np
		"frame":
			# key caps
			return chip(WINDOW_TOP, BORDER, 8.0, Vector4(8 + pad.x, 2 + pad.y, 8 + pad.z, 2 + pad.w))
		"bar_frame":
			return chip(WINDOW_BOTTOM, BORDER, 8.0, Vector4.ZERO)
		"slot":
			return cozy(pad + Vector4(-4, -2, -4, -2), 12.0)
	return cozy(pad + Vector4(4, 2, 4, 2))


# ================================================================ theme
## The selected row: a rounded pill in the accent, bright on the left and fading to the right, with a soft cream
## edge. `right` leaves room for a right-hand label.
static func highlight(right := 0.0) -> StyleBox:
	if pixel():
		# the gem behind the white: the 1-bit plate filled with it
		return pixel_box("plate", ACCENT, PIXEL_LINE, Vector4(22, 2, 12 + right, 2))
	var sb := CozyBox.new()
	sb.horizontal = true
	sb.top = Color(ACCENT.lightened(0.08), 0.95)
	sb.bottom = Color(ACCENT, 0.30)
	sb.border = Color(BORDER, 0.55)
	sb.border_w = 2.0
	sb.radius = 14.0
	sb.rim = Color(1, 1, 1, 0.16)
	sb.shadow = Color(0, 0, 0, 0.18)
	sb.shadow_off = Vector2(0, 2)
	sb.shadow_size = 3.0
	sb.content_margin_left = 22
	sb.content_margin_right = 12 + right
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = body_px(BODY_SMALL)
	var win := box("textfield")
	t.set_stylebox("panel", "PanelContainer", win)
	t.set_stylebox("panel", "Panel", win)

	# menu items (body font), with the accent pill behind the focused row
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 22
	empty.content_margin_right = 12
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	var hl := highlight()
	for st in ["normal", "disabled"]:
		t.set_stylebox(st, "Button", empty)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		t.set_stylebox(st, "Button", hl)
	t.set_font("font", "Button", font_body())
	t.set_font_size("font_size", "Button", body_px(BODY_BIG))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_constant("h_separation", "Button", 12)

	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 4)

	var le := chip(WINDOW_BOTTOM, ACCENT, 12.0, Vector4(14, 6, 14, 6))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.5))
	t.set_font("font", "LineEdit", font_body())
	t.set_font_size("font_size", "LineEdit", body_px(BODY_HUGE))

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(BORDER_INNER, 0.5)
	sb_bg.set_corner_radius_all(0 if pixel() else 6)
	sb_bg.content_margin_left = 4
	sb_bg.content_margin_right = 4
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = PIXEL_LINE if pixel() else ACCENT
	sb_grab.set_corner_radius_all(0 if pixel() else 6)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", sb_grab)
	t.set_stylebox("scroll", "VScrollBar", sb_bg)

	var sep := StyleBoxLine.new()
	sep.color = Color(BORDER, 0.22)
	sep.thickness = 2
	sep.grow_begin = -8
	sep.grow_end = -8
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)
	return t


# ================================================================ widgets
## Body text (BoldPixels): small (<24), big (24-31) or huge (32+, dialogue), each snapped to a crisp size for this
## screen.
static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	# (Pixel: text is white; the gem goes behind things, never into the letters)
	if pixel() and color.is_equal_approx(ACCENT):
		color = PIXEL_LINE
	l.text = text
	l.add_theme_font_override("font", font_body())
	l.add_theme_font_size_override("font_size", body_px(BODY_HUGE if size >= BODY_HUGE else (BODY_BIG if size >= 24 else BODY_SMALL)))
	l.add_theme_color_override("font_color", color)
	return l


## Heading text (Lunchtime Doubly So): titles, tabs, name plates, map names.
static func header(text: String, color := INK, size := HEAD_SIZE) -> Label:
	var l := Label.new()
	if pixel() and color.is_equal_approx(ACCENT):
		color = PIXEL_LINE
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


## A window with an accent stripe down its left edge (map names, notices).
static func banner_panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", box("banner"))
	return p


## A title tab: white text on the accent, for page and screen headings.
static func ribbon(text: String, small := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box("ribbon_small" if small else "ribbon"))
	var l := header(text, LIGHT, HEAD_SIZE)
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


## A small tag: light text on a rounded chip in a dark shade of `col` (Pixel: on `col` itself, edged in white).
static func tag(text: String, col: Color, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	if pixel():
		p.add_theme_stylebox_override("panel", chip(col.darkened(0.15), PIXEL_LINE, 9.0, Vector4(9, 0, 9, 0)))
	else:
		p.add_theme_stylebox_override("panel", chip(col.darkened(0.45), col.lerp(Color.WHITE, 0.55), 9.0, Vector4(9, 0, 9, 0)))
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
	if pixel():
		return PIXEL_LINE if ratio > 0.5 else (ACCENT.lerp(Color.WHITE, 0.25) if ratio > 0.2 else ACCENT)
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
