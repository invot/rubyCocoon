extends RefCounted
## Small pixel icons for short notices (the top bar, top_bar.gd): what kind of item was found, gold, a map pin for
## places, a note for songs, and a mark for anything else. Each is a 12 x 12 bitmap ("#" white line, "+" the gem,
## "o" a light shade of the gem, "." clear) made once per gem, so it scales by whole screen pixels (12 x 4 UI units).

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
	"notice": ["...######...", "..#++++++#..", ".#+++##+++#.", "#++++##++++#", "#++++##++++#", "#++++##++++#",
		"#++++##++++#", "#++++++++++#", ".#+++##+++#.", "..#++##++#..", "...######...", "............"],
}

static var _cache := {}


## A glyph's texture in the current gem (unknown names: the notice mark). Shown at SIZE x 4 UI units.
static func tex(name: String) -> Texture2D:
	if not GLYPHS.has(name):
		name = "notice"
	var key := "%s|%s" % [name, UIKit.ACCENT.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = GLYPHS[name]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cols := {"#": UIKit.LIGHT, "+": UIKit.ACCENT, "o": UIKit.GOLD_BRIGHT}
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


## The texture for an item's glyph.
static func item(id: String) -> Texture2D:
	return tex(item_glyph(id))
