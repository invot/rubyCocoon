extends RefCounted
## How each new beast is painted (beast_toon.gdshader, beast_rig.gd): its line's colours, from the creature packs
## the models came from, and per stage what changes. A look:
##   col: {group: colour} for the groups body, head, arms, legs, wings, tail, horn, deco (any left out: the body's)
##   tip: {group: [colour, from, soft, to]}: the part's own colour from `from` of the way out from its joint (0..1) to
##        `to` (default 1), easing in over `soft` (hands, feet, claws, spike tips; a range near 0: where it joins)
##   belly: [colour, from, groups]: a belly patch where those parts face forward and down more than `from` (0..1)
##   stripes / bands: {group: [colour, how many]} round the part, or up it per unit of height
##   eyes: [z, y, radius, front x, lid, brow, pupil, look up]: painted eyes (a part "eye" is drawn by itself)
##   lid: the colour of an eyelid (default: the head's, darker)
## Per line, "base" is every stage's look and "1", "2", "3" what each stage changes.

const LINES := {
	"dino": {"base": {"col": {"body": "#f4a27c", "head": "#f4a27c", "arms": "#d83a48", "legs": "#d83a48", "tail": "#f4a27c", "horn": "#ffe0b0"},
			"tip": {"legs": ["#ffc93c", 0.86, 0.0], "arms": ["#ffc93c", 0.82, 0.0], "head": ["#d83a48", 0.7, 0.05]},
			"belly": ["#f9c9a6", 0.62, ["body"]]},
		"1": {"col": {"body": "#f6aa8c", "head": "#f6aa8c"}}},
	"scorpion": {"base": {"col": {"body": "#3fc463", "head": "#3fc463", "arms": "#1f9d5e", "legs": "#8e4fd0", "tail": "#3fc463", "horn": "#9b5bd8"},
			"tip": {"tail": ["#9b5bd8", 0.8, 0.05]}, "belly": ["#5fd67e", 0.7, ["body"]]}},
	"berry": {"base": {"col": {"body": "#2f6fe0", "arms": "#5cb84a", "horn": "#5fb14a"},
			"tip": {"arms": ["#e8409a", 0.72, 0.0]}}},
	"beetle": {"base": {"col": {"body": "#2f6fb8", "head": "#5aa0e8", "arms": "#4a8ad8", "legs": "#4a8ad8", "tail": "#2f6fb8", "horn": "#e8b26a"},
			"tip": {"legs": ["#e8b26a", 0.8, 0.0], "arms": ["#e8b26a", 0.75, 0.0], "head": ["#e8b26a", 0.72, 0.05]},
			"belly": ["#5aa0e8", 0.66, ["body"]]}},
	"cactus": {"base": {"col": {"body": "#5cc552", "head": "#5cc552", "arms": "#4fb048", "legs": "#4fb048", "horn": "#ff9a4a"},
			"tip": {"horn": ["#ff5468", 0.55, 0.35]}, "stripes": {"body": ["#3e9a3e", 9]}, "lid": "#3e9a3e"}},
	"crab": {"base": {"col": {"body": "#e8304e", "head": "#e8304e", "arms": "#e83a50", "legs": "#36c6d6", "horn": "#e8304e", "tail": "#e8304e"},
			"belly": ["#ffd21f", 0.6, ["body"]], "lid": "#e8304e"}},
	"owl": {"base": {"col": {"body": "#f0882a", "head": "#f0882a", "wings": "#ffc22e", "legs": "#f5a030", "tail": "#ffc22e", "horn": "#ffcf3a"},
			"tip": {"wings": ["#e06a1e", 0.78, 0.1]}, "belly": ["#ffb050", 0.68, ["body"]], "lid": "#c86a20"}},
	"boar": {"base": {"col": {"body": "#9a6242", "head": "#4aa8d8", "legs": "#9a6242", "arms": "#a8e4f4", "tail": "#9a6242", "horn": "#a8e4f4"},
			"tip": {"legs": ["#f2c6a8", 0.82, 0.0], "head": ["#f2c6a8", 0.62, 0.04]}, "lid": "#2856a8"}},
	"bat": {"base": {"col": {"body": "#2a5c9c", "head": "#2a5c9c", "wings": "#c848b0", "arms": "#2a5c9c", "legs": "#2a5c9c", "tail": "#c848b0", "horn": "#e0408a"},
			"tip": {"arms": ["#e0408a", 0.78, 0.0], "wings": ["#2a5c9c", 0.0, 0.0, 0.18]}, "lid": "#1c3e6e"}},
	"worm": {"base": {"col": {"body": "#ff6f8f", "head": "#ff6f8f", "arms": "#ff6f8f", "tail": "#ff6f8f", "horn": "#26bcc4", "deco": "#8a5a3a"},
			"tip": {"arms": ["#26bcc4", 0.6, 0.0]}, "bands": {"body": ["#ff9fb5", 9.0], "tail": ["#ff9fb5", 9.0]}, "lid": "#d84a6a"}},
	"tree": {"base": {"col": {"body": "#f5b862", "head": "#f5b862", "arms": "#e08a40", "legs": "#f5b862", "horn": "#f5b862"},
			"tip": {"arms": ["#fbd9a0", 0.86, 0.0], "head": ["#e08a48", 0.0, 0.0, 0.22]}, "belly": ["#f9d49c", 0.64, ["body"]], "lid": "#e08a48"}},
	"frog": {"base": {"col": {"body": "#6fd6a2", "head": "#6fd6a2", "arms": "#6fd6a2", "legs": "#f27a62", "tail": "#6fd6a2", "horn": "#f27a62"},
			"tip": {"arms": ["#f27a62", 0.55, 0.0]}, "belly": ["#f2d870", 0.72, ["body"]]}},
	"marmot": {"base": {"col": {"body": "#f2709a", "head": "#f2709a", "arms": "#f2709a", "legs": "#f2709a", "horn": "#a33244"},
			"tip": {"arms": ["#f8e2b4", 0.86, 0.0], "head": ["#a33244", 0.66, 0.04]}, "belly": ["#f7a0bd", 0.64, ["body"]], "lid": "#a33244"},
		"3": {"col": {"arms": "#a33244"}}},
}

## the shader's parts (tools/new_beasts/bake.py PARTS) and the look group each belongs to
const PARTS := ["body", "head", "arm_l", "arm_r", "wing_l", "wing_r", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "horn", "eye", "deco"]
const GROUP := {"body": "body", "head": "head", "arm_l": "arms", "arm_r": "arms", "wing_l": "wings", "wing_r": "wings",
	"leg_fl": "legs", "leg_fr": "legs", "leg_bl": "legs", "leg_br": "legs", "tail": "tail", "horn": "horn", "eye": "eye", "deco": "deco"}


## A form's look ("dino_3": the dino line's stage 3), its line's base with that stage's changes laid over it.
static func look(form: String) -> Dictionary:
	var line := form.get_slice("_", 0)
	var stage := form.get_slice("_", 1)
	var l: Dictionary = LINES.get(line, {})
	var out: Dictionary = (l.get("base", {}) as Dictionary).duplicate(true)
	var over: Dictionary = l.get(stage, {})
	for k in over:
		if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY:
			(out[k] as Dictionary).merge(over[k], true)
		else:
			out[k] = over[k]
	return out
