extends RefCounted
## Shared item illustrations and notice symbols for menus and the top bar.
## Items and location symbols use supplied PNGs; two missing item shapes use SVGs.
## Legacy notice glyphs are 12 x 12 bitmaps ("#" white, "+" gem, "o" gold, "." clear), cached per gem.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

const SIZE := 12

const GLYPHS := {
	"potion": ["....####....", "....#..#....", "....#..#....", "...##..##...", "..#......#..", ".#++++++++#.",
		".#++++++++#.", ".#+o++++++#.", ".#+o++++++#.", ".#++++++++#.", "..#++++++#..", "...######..."],
	"drop": [".....##.....", ".....##.....", "....#++#....", "....#++#....", "...#++++#...", "...#++++#...",
		"..#++++++#..", "..#+o++++#..", "..#+o++++#..", "..#++++++#..", "...#++++#...", "....####...."],
	"herb": ["........###.", "......##++#.", ".....#+++#..", "....#+o+#...", "...#+o+##...", "..#++++#....",
		"..#+++#.....", "..#++#......", "..####......", ".#..........", "#...........", "............"],
	"heart": ["............", "..##....##..", ".#++#..#++#.", "#+o++##++++#", "#+o++++++++#", "#++++++++++#",
		".#++++++++#.", "..#++++++#..", "...#++++#...", "....#++#....", ".....##.....", "............"],
	"bomb": ["........#.#.", ".......#.#..", "......##....", ".....##.....", "...######...", "..#++++++#..",
		".#+o++++++#.", ".#+o++++++#.", ".#++++++++#.", ".#++++++++#.", "..#++++++#..", "...######..."],
	"pouch": ["...##..##...", "....#..#....", ".....##.....", "....####....", "...#++++#...", "..#++++++#..",
		".#++o+++++#.", ".#+o++++++#.", ".#++++++++#.", ".#++++++++#.", ".#++++++++#.", "..########.."],
	"cup": ["............", "...o..o.....", "....o..o....", "...o..o.....", ".#########..", ".#+++++++###",
		".#+++++++#.#", ".#+++++++#.#", ".#+++++++###", "..#+++++#...", "...#####....", "............"],
	"ring": ["....####....", "...#+o++#...", "....####....", "...#....#...", "..#......#..", ".#........#.",
		".#........#.", ".#........#.", "..#......#..", "...#....#...", "....####....", "............"],
	"shield": [".##########.", ".#++++++++#.", ".#+o++++++#.", ".#+o++++++#.", ".#++++++++#.", ".#++++++++#.",
		"..#++++++#..", "..#++++++#..", "...#++++#...", "....#++#....", ".....##.....", "............"],
	"note": ["....#######.", "....#######.", "....#.....#.", "....#.....#.", "....#.....#.", "....#.....#.",
		"....#.....#.", "..###...###.", ".#++#..#++#.", ".#+o#..#+o#.", "..##....##..", "............"],
	"hook": ["......##....", ".....#..#...", "......##....", "......#.....", "......#.....", "......#.....",
		"......#.....", "#.....#.....", "##....#.....", "#.#..#......", ".#..#.......", "..##........"],
	"book": ["............", ".##########.", ".#++++++++##", ".#+######+##", ".#++++++++##", ".#+######+##",
		".#++++++++##", ".#++++++++##", ".#++++++++##", ".##########.", "..#########.", "............"],
	"key": ["............", "..####......", ".#++++#.....", "#++##++#....", "#+#..#+#....", "#+#..#+#####",
		"#++##++++++#", ".#++++#####.", "..####.#.#..", ".......#.#..", "............", "............"],
	"shard": ["....####....", "...#++++#...", "..#+o++++#..", ".#+o++++++#.", "#+o++++++++#", "############",
		".#++++++++#.", "..#++++++#..", "...#++++#...", "....#++#....", ".....##.....", "............"],
	"coin": ["...######...", ".##++++++##.", ".#++####++#.", "#++#oooo#++#", "#+#o+++++#+#", "#+#o+++++#+#",
		"#+#o+++++#+#", "#+#++++++#+#", "#++#++++#++#", ".#++####++#.", ".##++++++##.", "...######..."],
	"pin": ["...######...", "..#++++++#..", ".#++####++#.", ".#+#....#+#.", ".#+#....#+#.", ".#++####++#.",
		"..#++++++#..", "...#++++#...", "....#++#....", "....#++#....", ".....##.....", "............"],
	# the trainer weapons (item_db.gd WEAPONS)
	"slingshot": ["..#......#..", ".#+#....#+#.", ".#+#....#+#.", ".#+#....#+#.", "..#+#..#+#..", "...#+##+#...",
		"....#++#....", "....#++#....", "....#++#....", "....#o+#....", "....#++#....", ".....##....."],
	"boomerang": ["............", "..##........", ".#++#.......", ".#+o+#......", "..#++#......", "..#+o+#.....",
		"...#++######", "...#+o+++++#", "....#++++++#", ".....######.", "............", "............"],
	"bat": [".........##.", "........#++#", ".......#+o+#", "......#+o+#.", ".....#+o+#..", "....#+++#...",
		"...#++#.....", "..#++#......", ".#++#.......", "##+#........", "#+##........", ".#.........."],
	"notice": ["...######...","..#++++++#..", ".#+++##+++#.", "#++++##++++#", "#++++##++++#", "#++++##++++#",
		"#++++##++++#", "#++++++++++#", ".#+++##+++#.", "..#++##++#..", "...######...", "............"],
}

## glyphs drawn in their own colours rather than the gem's ("+" and "o"): gold is always gold
const OWN_COLORS := {"coin": [Color(0.91, 0.69, 0.19), Color(1.0, 0.89, 0.52)]}

static var _cache := {}
## Item artwork uses permanent, item-specific colors, independent of the interface gem.
static var _items := {}
static var _locations := {}


## A glyph's texture in the current gem (unknown names: the notice mark). Shown at SIZE x 4 UI units.
static func tex(name: String) -> Texture2D:
	if name in ["town", "pin"]:
		if not _locations.has(name):
			var path := "town" if name == "town" else "position"
			var location: Texture2D = load("res://assets/ui/world_map/%s.png" % path)
			location.set_meta("smooth_ui_icon", true)
			_locations[name] = location
		return _locations[name]
	if not GLYPHS.has(name):
		name = "notice"
	var key := "%s|%s" % [name, UIKit.ACCENT.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = GLYPHS[name]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cols := {"#": UIKit.INK, "+": UIKit.ACCENT, "o": UIKit.GOLD_BRIGHT}
	if OWN_COLORS.has(name):
		cols["+"] = OWN_COLORS[name][0]
		cols["o"] = OWN_COLORS[name][1]
	for y in mini(SIZE, rows.size()):
		var r: String = rows[y]
		for x in mini(SIZE, r.length()):
			if cols.has(r[x]):
				img.set_pixel(x, y, cols[r[x]])
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Which glyph stands for an item: by what it does or what kind of thing it is.
static func item_glyph(id: String) -> String:
	var it := ItemDB.get_item(id)
	match String(it.get("kind", "")):
		"gear":
			return "ring"
		"tgear":
			return "note" if String(it.get("slot", "")) == "flute" else "shield"
		"sheet":
			return "note"
		"bait":
			return "hook"
		"tome":
			return "book"
		"key":
			if it.has("weapon"):
				return id
			return "hook" if id == "fishing_rod" else "key"
		"use":
			if it.has("bomb"):
				return "bomb"
			if it.has("revive_pct"):
				return "heart"
			if it.get("battle_only", false) and (it.has("buff") or it.has("heal")) and it.get("target", "") == "ally":
				return "cup"
			if it.has("heal") or it.has("heal_pct"):
				return "potion"
			if it.has("mp") or it.has("mp_pct"):
				return "drop"
			if it.get("cure", false):
				return "herb"
			if it.get("xp_level", false):
				return "cup"
			return "pouch"
	return "pouch"


## Supplied pack artwork. Variant colors are baked into the image, never taken from UIKit.ACCENT.
static func item(id: String) -> Texture2D:
	if _items.has(id):
		return _items[id]
	var name := "_tome" if id.begins_with("tome_") else ("_sheet" if id.begins_with("sheet_") else id)
	var extension := "svg" if name in ["bat", "lucky_clover"] else "png"
	var path := "res://assets/ui/items/%s.%s" % [name, extension]
	if not ResourceLoader.exists(path):
		path = "res://assets/ui/items/_unknown.png"
	var texture: Texture2D = load(path)
	texture.set_meta("item_art", true)
	texture.set_meta("smooth_ui_icon", extension == "svg")
	_items[id] = texture
	return texture


static func smooth(texture: Texture2D) -> bool:
	return texture != null and bool(texture.get_meta("smooth_ui_icon", false))


static func has(name: String) -> bool:
	return name == "town" or GLYPHS.has(name)
