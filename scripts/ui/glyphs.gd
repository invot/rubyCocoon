extends RefCounted
## Shared item illustrations and notice symbols for menus and the top bar.
## Both are smooth painted icons baked by tools/build_icons.gd (assets/ui/icons/items and assets/ui/icons/glyphs);
## location symbols use the world map's pins.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")

const ITEM_DIR := "res://assets/ui/icons/items/"
const GLYPH_DIR := "res://assets/ui/icons/glyphs/"
## The notice symbols there (unknown names get "notice").
const GLYPHS := ["potion", "drop", "herb", "heart", "bomb", "pouch", "cup", "ring", "shield", "note", "hook", "book",
	"key", "shard", "coin", "slingshot", "boomerang", "bat", "notice"]

static var _cache := {}
## Item artwork uses permanent, item-specific colors, independent of the interface gem.
static var _items := {}
static var _locations := {}


## A notice symbol's texture (unknown names: the notice mark).
static func tex(name: String) -> Texture2D:
	if name in ["town", "pin"]:
		if not _locations.has(name):
			var path := "town" if name == "town" else "position"
			var location: Texture2D = load("res://assets/ui/world_map/%s.png" % path)
			location.set_meta("smooth_ui_icon", true)
			_locations[name] = location
		return _locations[name]
	if not name in GLYPHS:
		name = "notice"
	if not _cache.has(name):
		var t: Texture2D = load(GLYPH_DIR + name + ".png")
		t.set_meta("smooth_ui_icon", true)
		_cache[name] = t
	return _cache[name]


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


## The item's painted icon. Its colours are its own, never taken from UIKit.ACCENT.
static func item(id: String) -> Texture2D:
	if _items.has(id):
		return _items[id]
	var name := "_tome" if id.begins_with("tome_") else ("_sheet" if id.begins_with("sheet_") else id)
	var path := ITEM_DIR + name + ".png"
	if not ResourceLoader.exists(path):
		path = ITEM_DIR + "_unknown.png"
	var texture: Texture2D = load(path)
	texture.set_meta("item_art", true)
	texture.set_meta("smooth_ui_icon", true)
	_items[id] = texture
	return texture


static func smooth(texture: Texture2D) -> bool:
	return texture != null and bool(texture.get_meta("smooth_ui_icon", false))


static func has(name: String) -> bool:
	return name in ["town", "pin"] or name in GLYPHS
