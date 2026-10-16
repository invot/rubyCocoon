extends RefCounted
## Element rules. Fire is weak to Air, Earth to Water, Water to Air, Air to Fire.
## Ghost beasts (made by the Umbral Legion) have no weakness.

const ELEMENTS := ["fire", "water", "earth", "air"]

## defender element -> attacking element it is weak to
const WEAK_TO := {"fire": "air", "earth": "water", "water": "air", "air": "fire"}

const ROLE := {
	"fire": "Offense Tank", "water": "Healer", "earth": "Defender",
	"air": "Trickster", "ghost": "Phantom", "neutral": "",
}

const COLOR := {
	"fire": Color("#ff6a3d"), "water": Color("#3fa4ff"), "earth": Color("#c8964f"),
	"air": Color("#7fe6c8"), "ghost": Color("#a56bff"), "neutral": Color("#c8c8c8"),
}


static func multiplier(atk_el: String, def_el: String) -> float:
	if def_el == "ghost" or atk_el == "neutral" or atk_el == "ghost":
		return 1.0
	if WEAK_TO.get(def_el, "") == atk_el:
		return 2.0
	if atk_el == def_el:
		return 0.75
	return 1.0


static func color(el: String) -> Color:
	return COLOR.get(el, Color.WHITE)


static func label(el: String) -> String:
	return el.to_upper()
