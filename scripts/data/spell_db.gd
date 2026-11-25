extends RefCounted
## The hero's elemental attacks (docs/dustwell-water-arc.md). A spell is learned once and each weapon delivers it in
## its own way: the slingshot fires it, the boomerang sweeps it across the facing side, the bat swings it. The hit
## takes the weapon's accuracy and power, then the spell's own power and element. It never crits.
##
## The hero keeps at most MAX_PER_ELEMENT spells of each element (as a beast keeps a few moves): learning another
## means forgetting one. Water and Torrent also work in the field (Story.field_cast). Field use rests on the
## permanent "learned_<id>" flag, so a spell forgotten for battle still works at a panel or the river's lip. Spells
## never use the flute: the hero learns each once from a teacher while carrying its element's stone.
##
## Keys: name, el (Elements), power (times the weapon's plain damage), mp (cost per use), tier (1 first), field
## (a field use exists), names (per weapon), fx (the colour each hit flashes and floats in), desc.
const Elements = preload("res://scripts/data/elements.gd")

const MAX_PER_ELEMENT := 2

const SPELLS := {
	"water": {"name": "Water", "el": "water", "power": 1.35, "mp": 4, "tier": 1, "field": true,
		"names": {"slingshot": "Water Shot", "boomerang": "Splash Arc", "bat": "Wave Swing"},
		"fx": "#4ab0ff", "desc": "Asks the water to move with your weapon. Strong against fire beasts."},
	"torrent": {"name": "Torrent", "el": "water", "power": 1.9, "mp": 8, "tier": 2, "field": true,
		"names": {"slingshot": "Torrent Shot", "boomerang": "Riptide Arc", "bat": "Breaker Swing"},
		"fx": "#2a7fe0", "desc": "A rushing surge behind every hit. Strong against fire beasts."},
	"ice": {"name": "Ice", "el": "water", "power": 1.6, "mp": 6, "tier": 2,
		"names": {"slingshot": "Ice Shot", "boomerang": "Frost Arc", "bat": "Glacier Swing"},
		"fx": "#a8e4ff", "desc": "Freezes the water around each hit. Strong against fire beasts."},
	"blizzard": {"name": "Blizzard", "el": "water", "power": 2.2, "mp": 11, "tier": 3,
		"names": {"slingshot": "Blizzard Shot", "boomerang": "Whiteout Arc", "bat": "Avalanche Swing"},
		"fx": "#e8f6ff", "desc": "A howling storm of ice. Strong against fire beasts."},
	# (Valkoog: the keepers' first lesson, once the hero carries an air stone)
	"gust": {"name": "Gust", "el": "air", "power": 1.45, "mp": 4, "tier": 1,
		"names": {"slingshot": "Gust Shot", "boomerang": "Squall Arc", "bat": "Gale Swing"},
		"fx": "#7fe8d0", "desc": "A sudden fist of wind behind each hit. Strong against earth beasts."},
}

## Trainer MP: the pool at trainer Lv 1, and what each trainer level adds to it.
const MP_BASE := 8
const MP_PER_LEVEL := 2


static func exists(id: String) -> bool:
	return SPELLS.has(id)


static func get_spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})


static func spell_name(id: String) -> String:
	return String(get_spell(id).get("name", id.capitalize()))


static func element(id: String) -> String:
	return String(get_spell(id).get("el", "neutral"))


static func mp_cost(id: String) -> int:
	return int(get_spell(id).get("mp", 0))


static func power(id: String) -> float:
	return float(get_spell(id).get("power", 1.0))


static func color(id: String) -> Color:
	var fx := String(get_spell(id).get("fx", ""))
	return Color(fx) if fx != "" else Elements.color(element(id))


## What the weapon calls this spell ("Water Shot", "Splash Arc", "Wave Swing").
static func attack_name(id: String, weapon: String) -> String:
	var names: Dictionary = get_spell(id).get("names", {})
	return String(names.get(weapon, "%s %s" % [spell_name(id), weapon.capitalize()]))


static func has_field_use(id: String) -> bool:
	return bool(get_spell(id).get("field", false))


## The maximum trainer MP at `level`.
static func max_mp_at(level: int) -> int:
	return MP_BASE + MP_PER_LEVEL * maxi(1, level)


## Spells of `el` among `known`.
static func of_element(known: Array, el: String) -> Array:
	return known.filter(func(id): return element(String(id)) == el)


## A scroll teaches a spell from the bag (ItemDB "scroll_<id>").
static func scroll_item(id: String) -> Dictionary:
	var s := get_spell(id)
	return {"name": "Scroll: " + spell_name(id), "kind": "scroll", "spell": id, "price": 0, "tier": 99,
		"desc": "%s\nRead it to learn %s (%s, %d MP). You keep two spells of each element." % [String(s.get("desc", "")),
			spell_name(id), Elements.label(element(id)).capitalize(), mp_cost(id)]}
