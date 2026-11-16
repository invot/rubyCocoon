extends RefCounted
## The hero's wardrobe: what the character creator (scripts/ui/hero_maker.gd) lets them wear, each piece named, and
## the colours each can be dyed. Pieces are cut from the townfolk kit's people (townfolk.gd): a shirt is a person's top
## with its sleeves, arms and neck; pants their bottoms (trousers, shorts or a skirt) with the legs they show; shoes
## their shoes. Hats and glasses are the kit's own parts. Each body keeps its own shirts, pants and shoes (the kit's
## boys' and girls' clothes); hats and glasses fit either.
##
## A hero's look stores what they wear by index (see townfolk.gd outfit): "shirt_style", "pants_style", "shoes_style",
## "hat_style" and "glasses_style" (-1: none), dyed "top", "trousers", "shoes", "hat" and "glasses_colour".

## The kit part kinds that make up each kind of piece cut from a person.
const KINDS := {
	"shirt": ["top", "arms", "neck", "collar", "strap"],
	"pants": ["bottom", "legs", "belt"],
	"shoes": ["shoes"],
}

## Shirts, pants and shoes for each body: [name, the person in townfolk.json they come from].
const SHIRTS := {
	"male": [["Tank Top", 0], ["Rolled Tee", 13], ["Pocket Tee", 4], ["Crew Tee", 10], ["Baggy Tee", 11],
		["Polo Shirt", 29]],
	"female": [["Crew Tee", 62], ["Yoke Top", 7], ["Sailor Top", 8], ["Varsity Sweater", 31], ["Smock", 72],
		["Bow Blouse", 74], ["Striped Jumper", 77], ["Puff-Sleeve Tee", 63], ["Flame Tee", 66], ["Hoodie", 33]],
}
const PANTS := {
	"male": [["Shorts", 0], ["Cropped Pants", 13], ["Knee Shorts", 4], ["Board Shorts", 10], ["Cuffed Shorts", 11],
		["Kilt", 29]],
	"female": [["Cuffed Shorts", 62], ["Cropped Jeans", 7], ["Pleated Skirt", 8], ["Skater Skirt", 31],
		["Mini Skirt", 72], ["A-Line Skirt", 74], ["Puff Shorts", 77], ["Trousers", 63], ["Striped Skirt", 66]],
}
const SHOES := {
	"male": [["Sneakers", 0], ["Runners", 13], ["Trail Shoes", 4], ["Boots", 10], ["High-Tops", 11], ["Slip-Ons", 29]],
	"female": [["Sneakers", 62], ["Mary Janes", 7], ["Platform Sneakers", 8], ["Trainers", 31], ["Canvas Shoes", 77],
		["Ankle Boots", 63]],
}

## Hats and glasses: [name, their parts in townfolk.json]. None comes first in the creator (index -1). Glasses have
## no lenses (townfolk.gd LENSES cuts them out of every pair).
const HATS := [
	["Ball Cap", [13]], ["Sport Cap", [28]], ["Bobble Hat", [91]], ["Beret", [96]], ["Bucket Hat", [99]],
	["Rain Hat", [106]], ["Top Hat", [110]], ["Garden Hat", [115]], ["Sun Hat", [117]], ["Mushroom Hat", [122]],
	["Ranger Hat", [127]], ["Headphones", [205, 206]], ["Sailor Cap", [208, 209]], ["Crown", [270]],
	["Wizard Hat", [275]], ["Goggle Cap", [286, 287]], ["Horned Helmet", [303]],
]
const GLASSES := [
	["Round Specs", [141]], ["Wire Specs", [147]], ["Star Shades", [171]], ["Cat-Eye Shades", [176]],
	["Visor Shades", [184]], ["Swim Goggles", [188, 189]], ["Ski Goggles", [195, 196]],
]

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
		"top": "#b93646", "trousers": "#39588a", "shoes": "#3a6ab8", "hat": "#b93646", "glasses_colour": "#2a2a30"},
	"female": {"shirt_style": 0, "pants_style": 0, "shoes_style": 0, "hat_style": -1, "glasses_style": -1,
		"top": "#e8e4dc", "trousers": "#39588a", "shoes": "#e8e4dc", "hat": "#e0809e", "glasses_colour": "#2a2a30"},
}


## The pieces of one kind ("shirt", "pants", "shoes", "hat", "glasses") a body picks from.
static func pieces(kind: String, body: String) -> Array:
	match kind:
		"shirt":
			return SHIRTS.get(body, SHIRTS["male"])
		"pants":
			return PANTS.get(body, PANTS["male"])
		"shoes":
			return SHOES.get(body, SHOES["male"])
		"hat":
			return HATS
		"glasses":
			return GLASSES
	return []


## The index of the piece of `kind` cut from `person` (a look from before the wardrobe, which named only its outfit's
## person), or 0.
static func index_of_person(kind: String, body: String, person: int) -> int:
	var list := pieces(kind, body)
	for i in list.size():
		if int(list[i][1]) == person:
			return i
	return 0
