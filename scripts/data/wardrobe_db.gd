extends RefCounted
## The hero's wardrobe: what the character creator (scripts/ui/hero_maker.gd) lets them wear, each piece named, and
## the colours each can be dyed. Pieces are cut from the townfolk kit's people (townfolk.gd): a shirt is a person's top
## with its sleeves, arms and neck; pants their bottoms (trousers, shorts or a skirt) with the legs they show; shoes
## their shoes. Hats and glasses are the kit's own parts. Each body keeps its own shirts, pants and shoes (the kit's
## boys' and girls' clothes); hats and glasses fit either.
##
## A hero's look stores what they wear by index (see townfolk.gd outfit): "shirt_style", "pants_style", "shoes_style",
## "hat_style" and "glasses_style" (-1: none), dyed "top" (and "top2", the shirt's second colour), "trousers", "shoes",
## "hat" and "glasses_colour"; shoes' laces take the pack's "pack_colour". Nothing a piece wears keeps a colour of its
## own: what the kit painted in other colours is dyed too, in shades of the piece's colour (or the shirt's second).

## The kit part kinds that make up each kind of piece cut from a person.
const KINDS := {
	"shirt": ["top", "arms", "neck", "collar", "strap"],
	"pants": ["bottom", "legs", "belt"],
	"shoes": ["shoes"],
}

## Shirts, pants and shoes for each body: [name, the person in townfolk.json they come from]. A shirt has a third: what
## its second colour (the look's "top2") dyes, as the creator names its row: a plain shirt's sleeves, else its trim
## (townfolk.gd _dye_part sorts that out: the parts the kit painted in a second colour, or a plain shirt's sleeves).
const SHIRTS := {
	"male": [["Tank Top", 0, "Trim"], ["Rolled Tee", 13, "Sleeves"], ["Pocket Tee", 4, "Sleeves"],
		["Crew Tee", 10, "Sleeves"], ["Baggy Tee", 11, "Sleeves"], ["Polo Shirt", 29, "Sleeves"]],
	"female": [["Crew Tee", 62, "Sleeves"], ["Yoke Top", 7, "Yoke"], ["Varsity Sweater", 31, "Stripes"],
		["Smock", 72, "Trim"], ["Bow Blouse", 74, "Trim"], ["Striped Jumper", 77, "Stripes", true],
		["Puff-Sleeve Tee", 63, "Sleeves"], ["Flame Tee", 66, "Flames"], ["Hoodie", 33, "Trim"]],
}
## (a shirt's fourth: true for one drawn in thick stripes of its two colours round the body and sleeves, see
## townfolk.gd STRIPES)
const PANTS := {
	"male": [["Shorts", 0], ["Cropped Pants", 13], ["Cargo Shorts", -1, [24, "cargo_shorts"]], ["Board Shorts", 10],
		["Cuffed Shorts", 11], ["Kilt", 29]],
	"female": [["Cuffed Shorts", 62], ["Cropped Jeans", 7], ["Pleated Skirt", 8], ["Skater Skirt", 31],
		["Mini Skirt", 72], ["A-Line Skirt", 74], ["Puff Shorts", 77], ["Trousers", 63], ["Striped Skirt", 66]],
}
## Pieces a female hero has whatever their body, and a non-binary one on either: [name, a person (-1: none), the kit
## parts, when they aren't that person's]. They come after the body's own, so its pieces keep their numbers. A part
## named by a word is one made from the kit's as it loads (townfolk.gd DERIVED): the long skirt is the A-line skirt let
## down to the shin, the cargo shorts the knee shorts made baggy with pockets on the thighs.
const MORE_PANTS := [["Long Skirt", -1, [24, "long_skirt"]]]
const SHOES := {
	"male": [["Sneakers", 0], ["Runners", 13], ["Trail Shoes", 4], ["Boots", 10], ["High-Tops", 11], ["Slip-Ons", 29]],
	"female": [["Sneakers", 62], ["Mary Janes", 7], ["Platform Sneakers", 8], ["Trainers", 31], ["Canvas Shoes", 77],
		["Ankle Boots", 63]],
}

## Hats and glasses: [name, their parts in townfolk.json]. None comes first in the creator (index -1). Glasses have
## no lenses (townfolk.gd LENSES cuts them out of every pair).
const HATS := [
	["Sport Cap", [28]], ["Bobble Hat", [91]], ["Beret", [96]], ["Bucket Hat", [99]],
	["Rain Hat", [106]], ["Top Hat", [110]], ["Garden Hat", [115]], ["Sun Hat", [117]], ["Duckie Hat", [122]],
	["Ranger Hat", [127]], ["Headphones", [205, 206]], ["Sailor Cap", [208, 209]], ["Crown", [270]],
	["Wizard Hat", [275]], ["Horned Helmet", [303]],
]
const GLASSES := [
	["Round Specs", [141]], ["Wire Specs", [147]], ["Star Shades", [171]], ["Cat-Eye Shades", [176]],
	["Visor Shades", [184]], ["Ski Goggles", [195, 196]],
]
## The wardrobe's version, kept in a hero's look ("wardrobe"), and the pieces each version took out (by their old
## index), so a look from before keeps what it wore (see upgrade): version 2 (2026-11-17) took out the female Sailor
## Top, the Ball Cap and Goggle Cap, and the Swim Goggles (the Knee Shorts became Cargo Shorts in their place).
const VERSION := 2
const RETIRED := {2: {"shirt_style/female": [2], "hat_style": [0, 15], "glasses_style": [5]}}

## The dyes. Clothes, hats, glasses and the pack share one set; skin, hair and eyes have their own.
const CLOTH := ["#b93646", "#d8702a", "#d8b030", "#3a8a4a", "#2a8a8a", "#3a6ab8", "#39588a", "#7a4aa8",
	"#e0809e", "#e8e4dc", "#6a6a70", "#2a2a30", "#5a3e2a", "#9a8a62", "#8a2a2a", "#3e5a3a"]
const PACK := ["#7a4a2a", "#4a3020", "#a8865a", "#c8a040", "#b03a3a", "#d8702a", "#3a6ab8", "#3a5a8a",
	"#4a6a3a", "#2a8a8a", "#7a4aa8", "#e0809e", "#e8e4dc", "#5a5a62", "#2a2a30", "#8a2a2a"]
const SKIN := ["#f6d8c0", "#f0c8a0", "#e0ac84", "#c68a62", "#9a6440", "#6e4428", "#f8e0d0", "#b07850"]
const HAIR := ["#1a1410", "#3a2216", "#6a4026", "#8a3a20", "#c0602a", "#d8b060", "#e8d8a8", "#c8c8d0",
	"#d87a9a", "#4a5aa8", "#3a8a6a", "#8a4ab0"]
const EYES := ["#642a12", "#845613", "#198337", "#195bc4", "#657f94", "#be7909", "#3a3a3a", "#8a3a8a"]

## Each dye's name, as the creator shows it beside its colour (the same order as its list above).
const NAMES := {
	"CLOTH": ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Denim", "Purple", "Pink", "White", "Grey", "Black",
		"Brown", "Khaki", "Maroon", "Olive"],
	"PACK": ["Saddle", "Chocolate", "Tan", "Mustard", "Red", "Orange", "Blue", "Navy", "Green", "Teal", "Purple", "Pink",
		"White", "Grey", "Black", "Maroon"],
	"SKIN": ["Tone 1", "Tone 2", "Tone 3", "Tone 4", "Tone 5", "Tone 6", "Tone 7", "Tone 8"],
	"HAIR": ["Black", "Dark Brown", "Brown", "Auburn", "Copper", "Blonde", "Platinum", "Silver", "Pink", "Blue",
		"Teal", "Purple"],
	"EYES": ["Brown", "Amber", "Green", "Blue", "Grey", "Gold", "Charcoal", "Violet"],
}


## A set of dyes by name ("CLOTH", "PACK", "SKIN", "HAIR", "EYES").
static func dyes(set_name: String) -> Array:
	match set_name:
		"PACK":
			return PACK
		"SKIN":
			return SKIN
		"HAIR":
			return HAIR
		"EYES":
			return EYES
	return CLOTH


## A dye's name in its set ("" for a colour not in it: a look from before the set changed).
static func dye_name(set_name: String, hex: String) -> String:
	var i := dyes(set_name).find(hex)
	return String(NAMES[set_name][i]) if i >= 0 else ""


## What each body begins in (indices into the lists above, and colours).
const START := {
	"male": {"shirt_style": 0, "pants_style": 0, "shoes_style": 0, "hat_style": -1, "glasses_style": -1,
		"top": "#b93646", "top2": "#b93646", "trousers": "#39588a", "shoes": "#3a6ab8", "hat": "#b93646", "glasses_colour": "#2a2a30"},
	"female": {"shirt_style": 0, "pants_style": 0, "shoes_style": 0, "hat_style": -1, "glasses_style": -1,
		"top": "#e8e4dc", "top2": "#e8e4dc", "trousers": "#39588a", "shoes": "#e8e4dc", "hat": "#e0809e", "glasses_colour": "#2a2a30"},
}


## The pieces of one kind ("shirt", "pants", "shoes", "hat", "glasses") a body picks from (and a gender: a female or
## non-binary hero has MORE_PANTS too).
static func pieces(kind: String, body: String, gender := "") -> Array:
	match kind:
		"shirt":
			return SHIRTS.get(body, SHIRTS["male"])
		"pants":
			var list: Array = PANTS.get(body, PANTS["male"])
			if body == "female" or gender in ["female", "non_binary"]:
				return list + MORE_PANTS
			return list
		"shoes":
			return SHOES.get(body, SHOES["male"])
		"hat":
			return HATS
		"glasses":
			return GLASSES
	return []


## A hero's look brought up to this wardrobe (RETIRED): each piece's index moved down past the pieces taken out before
## it; a piece taken out becomes the body's first shirt, or no hat or glasses.
static func upgrade(look: Dictionary) -> Dictionary:
	var out := look.duplicate()
	var from := int(out.get("wardrobe", 1))
	if not (out.has("shirt_style") or out.has("hat_style") or out.has("glasses_style")):
		return out
	if from >= VERSION:
		return out
	for v in range(from + 1, VERSION + 1):
		var gone: Dictionary = RETIRED.get(v, {})
		for key in gone:
			var k := String(key).get_slice("/", 0)
			if "/" in String(key) and String(out.get("body", "male")) != String(key).get_slice("/", 1):
				continue
			if not out.has(k):
				continue
			var i := int(out[k])
			if i in gone[key]:
				out[k] = 0 if k == "shirt_style" else -1
			else:
				out[k] = i - (gone[key] as Array).filter(func(g: int) -> bool: return g < i).size()
	out["wardrobe"] = VERSION
	return out


## The index of the piece of `kind` cut from `person` (a look from before the wardrobe, which named only its outfit's
## person), or 0.
static func index_of_person(kind: String, body: String, person: int) -> int:
	var list := pieces(kind, body)
	for i in list.size():
		if int(list[i][1]) == person:
			return i
	return 0
