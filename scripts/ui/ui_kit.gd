extends RefCounted
## Shared UI construction helpers and the game theme: the windows of an early PS2 RPG. Near-black, slightly
## see-through windows with a white double border and white text; the selection, headings, tabs, bars and tags take
## the player's accent colour (see set_accent and Prefs.accent).
## Window frames, the selection bar and the small icons are drawn here, pixel by pixel (cached textures); a few icons
## come from the flatUI kit (assets/ui/flat, copied by tools/build_ui_icons.gd).
## Font: Lunchtime Doubly So (ui/lunchds.ttf) for everything.

const Elements = preload("res://scripts/data/elements.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")

const UI_DIR := "res://assets/ui/"
const BODY_FONT := "res://ui/lunchds.ttf"
const HEAD_FONT := "res://ui/lunchds.ttf"
## Lunchtime Doubly So is drawn on an 8-pixels-per-em grid: sizes that are multiples of 8 on the real screen keep
## every stroke on whole pixels (see _crisp).
const BODY_SMALL := 24
const BODY_BIG := 32
## dialogue text: three lines fill the box
const BODY_HUGE := 40
const HEAD_SIZE := 32
const HEAD_SMALL := 24
const FONT_STEP := 8.0

## The accent colours the player can pick (Settings > Highlight).
const ACCENTS := {"red": Color("#d42a3c"), "blue": Color("#2f72dc"), "green": Color("#2c9e50"), "purple": Color("#8a46d6"),
	"silver": Color("#7e8a9c")}
const ACCENT_ORDER := ["red", "blue", "green", "purple", "silver"]

# ---- palette ----
## text on the windows
const INK := Color("#f2f2ee")
const LIGHT := Color("#ffffff")
## secondary text
const DIM := Color("#9c9ca6")
## the window fill (top and bottom of its gradient) and the border
const WINDOW_TOP := Color(0.11, 0.11, 0.13, 0.95)
const WINDOW_BOTTOM := Color(0.02, 0.02, 0.03, 0.95)
const BORDER := Color("#f4f4f4")
const BORDER_INNER := Color("#6c6c76")
const PAGE := Color("#0c0c10")
const BROWN := Color("#060608")
const BG := Color("#060608")
## legacy name used across the game: TEXT = body ink
const TEXT := INK
## the accent and its shades (follow set_accent)
static var accent_name := "red"
static var ACCENT := Color("#d42a3c")
## highlighted text: the accent, lifted so it reads on black
static var GOLD := Color("#e85a68")
static var GOLD_BRIGHT := Color("#f08a94")
static var ORANGE := Color("#d42a3c")

static var _fonts := {}
## How much the 1280x720 UI is scaled up on this screen (1.5 on a 1080p-tall phone or a 1920x1080 window).
static var screen_scale := 1.0
static var _tex := {}
static var _styles := {}


## Switches the accent colour (one of ACCENTS); the theme and any window built afterwards follow it.
static func set_accent(name: String) -> void:
	if not ACCENTS.has(name):
		name = "red"
	accent_name = name
	ACCENT = ACCENTS[name]
	GOLD = ACCENT.lerp(Color.WHITE, 0.28)
	GOLD_BRIGHT = ACCENT.lerp(Color.WHITE, 0.5)
	ORANGE = ACCENT
	_styles.clear()
	for k in _tex.keys():
		if String(k).begins_with("gen:"):
			_tex.erase(k)


## How tall a menu row is: about a centimetre on a phone (48 dp or more), a little less with keys and a mouse.
static func row_h() -> float:
	return 84.0 if is_instance_valid(UI) and UI.is_touch() else 60.0


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
	# Lunchtime has no arrows, stars or notes: those come from Godot's default font
	f.fallbacks = [ThemeDB.fallback_font]
	_fonts[path] = f
	return f


## A UI texture: one of the icons drawn here (see ICONS), a flatUI icon (assets/ui/flat), or an older texture.
static func tex(name: String) -> Texture2D:
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
## A window's frame: a vertical gradient from WINDOW_TOP to WINDOW_BOTTOM inside a 2-pixel white border, a 1-pixel gap
## and a fine grey inner line, the corners clipped by a pixel. Drawn tall so the gradient spans the whole window when
## the middle is stretched. `stripe` adds an accent bar down the left edge (map names and notices).
static func _window_image(stripe: bool) -> Image:
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var fill := WINDOW_TOP.lerp(WINDOW_BOTTOM, clampf((y - 4.0) / (h - 8.0), 0.0, 1.0))
		for x in w:
			var edge := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			var corner := (x < 2 or x > w - 3) and (y < 2 or y > h - 3)
			var c := fill
			if edge < 2:
				c = BORDER
			elif edge == 3:
				c = BORDER_INNER
			if corner and ((x == 0 or x == w - 1) and (y == 0 or y == h - 1)):
				c = Color(0, 0, 0, 0)
			if stripe and edge >= 4 and x >= 4 and x < 8:
				c = ACCENT
			img.set_pixel(x, y, c)
	return img


static func _window_box(key: String, stripe: bool, pad: Vector4) -> StyleBoxTexture:
	var tkey := "gen:" + ("banner" if stripe else "window")
	if not _tex.has(tkey):
		_tex[tkey] = ImageTexture.create_from_image(_window_image(stripe))
	var sb := StyleBoxTexture.new()
	sb.texture = _tex[tkey]
	sb.texture_margin_left = 8 if stripe else 6
	sb.texture_margin_right = 6
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = (8 if stripe else 6) + pad.x
	sb.content_margin_top = 6 + pad.y
	sb.content_margin_right = 6 + pad.z
	sb.content_margin_bottom = 6 + pad.w
	return sb


## The window styles by their old texture names, so every screen picks up the new look: `pad` is extra content
## padding (l, t, r, b).
static func box(name: String, pad := Vector4(0, 0, 0, 0)) -> StyleBox:
	match name:
		"banner":
			return _window_box(name, true, pad + Vector4(14, 4, 14, 4))
		"nameplate", "ribbon", "ribbon_small":
			var sb := StyleBoxFlat.new()
			sb.bg_color = ACCENT
			sb.border_color = BORDER
			sb.set_border_width_all(2)
			sb.content_margin_left = 14 + pad.x
			sb.content_margin_right = 14 + pad.z
			sb.content_margin_top = 4 + pad.y
			sb.content_margin_bottom = 4 + pad.w
			sb.anti_aliasing = false
			return sb
		"frame":
			# key caps
			var kc := StyleBoxFlat.new()
			kc.bg_color = Color("#1c1c22")
			kc.border_color = BORDER
			kc.set_border_width_all(2)
			kc.content_margin_left = 6 + pad.x
			kc.content_margin_right = 6 + pad.z
			kc.content_margin_top = 2 + pad.y
			kc.content_margin_bottom = 2 + pad.w
			kc.anti_aliasing = false
			return kc
		"bar_frame":
			var bf := StyleBoxFlat.new()
			bf.bg_color = Color("#101014")
			bf.border_color = BORDER
			bf.set_border_width_all(2)
			bf.anti_aliasing = false
			return bf
	return _window_box(name, false, pad + Vector4(10, 6, 10, 6))


# ================================================================ theme
## The selected row: a bar in the accent colour fading out to the right, with a solid edge on the left (the cursor of
## the PS2 menus). `right` leaves room for a right-hand label.
static func highlight(right := 0.0) -> StyleBox:
	if not _tex.has("gen:cursor_bar"):
		var w := 64
		var h := 8
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var a := lerpf(0.95, 0.12, clampf((x - 6.0) / (w - 8.0), 0.0, 1.0))
				var c := ACCENT if x >= 6 else BORDER
				if x < 4:
					c = BORDER
				elif x < 6:
					c = ACCENT.lerp(BORDER, 0.5)
				img.set_pixel(x, y, Color(c, 1.0 if x < 6 else a))
		_tex["gen:cursor_bar"] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _tex["gen:cursor_bar"]
	sb.texture_margin_left = 8
	sb.texture_margin_right = 2
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
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

	# menu items, with the accent bar behind the focused row
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
	t.set_font("font", "Button", font_head())
	t.set_font_size("font_size", "Button", head_px(HEAD_SIZE))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_constant("h_separation", "Button", 12)

	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 2)

	var le := StyleBoxFlat.new()
	le.bg_color = Color("#101014")
	le.border_color = ACCENT
	le.set_border_width_all(2)
	le.content_margin_left = 12
	le.content_margin_right = 12
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.5))
	t.set_font("font", "LineEdit", font_body())
	t.set_font_size("font_size", "LineEdit", body_px(BODY_BIG))

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color("#26262c")
	sb_bg.content_margin_left = 4
	sb_bg.content_margin_right = 4
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = ACCENT
	sb_grab.border_color = BORDER
	sb_grab.set_border_width_all(1)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(st, "VScrollBar", sb_grab)
	t.set_stylebox("scroll", "VScrollBar", sb_bg)

	var sep := StyleBoxLine.new()
	sep.color = BORDER_INNER
	sep.thickness = 2
	sep.content_margin_top = 6
	sep.content_margin_bottom = 6
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)
	return t


# ================================================================ widgets
## Body text: small (<24), big (24-39) or huge (40+), each snapped to a crisp size for this screen.
static func label(text: String, size := 20, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_body())
	l.add_theme_font_size_override("font_size", body_px(BODY_HUGE if size >= 40 else (BODY_BIG if size >= 24 else BODY_SMALL)))
	l.add_theme_color_override("font_color", color)
	return l


## Header / menu text.
static func header(text: String, color := INK, size := HEAD_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_head())
	l.add_theme_font_size_override("font_size", head_px(size))
	l.add_theme_color_override("font_color", color)
	return l


## White text with a black outline, for text drawn straight over the 3D world.
static func shadow_label(text: String, size := 20, color := LIGHT) -> Label:
	var l := header(text, color, 64 if size >= 60 else HEAD_SIZE) if size >= 28 else label(text, size, color)
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


## A small tag: white text on a dark chip edged in `col`.
static func tag(text: String, col: Color, size := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.35)
	sb.border_color = col.lerp(Color.WHITE, 0.3)
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, LIGHT)
	p.add_child(l)
	return p


## An element's tag, in the accent (its name tells the element apart).
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


## A health bar's colour: the accent, dimming as it runs low (everything in the UI takes the accent).
static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return ACCENT.lerp(Color.WHITE, 0.12)
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
