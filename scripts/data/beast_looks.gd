extends RefCounted
## How each new beast is painted (beast_toon.gdshader, beast_rig.gd): its line's colours, from the creature packs
## the models came from, and per stage what changes. A look:
##   col: {group: colour} for the groups body, head, arms, legs, wings, tail, horn, deco (any left out: the body's)
##   tip: {group: [colour, from, soft, to]}: the part's own colour from `from` of the way out from its joint (0..1) to
##        `to` (default 1), easing in over `soft` (hands, feet, claws, spike tips; a range near 0: where it joins)
##   belly: [colour, from, groups]: a belly patch where those parts face forward and down more than `from` (0..1)
##   stripes / bands: {group: [colour, how many]} round the part, or up it per unit of height
##   eyes: [z, y, radius, front x, lid, brow, pupil, look up]: a pair of painted eyes, on the face's sculpted ones
##         (beast_toon.gdshader painted_eye(): the right one's place on the face, painted where it's forward of
##         front x; lid 0 open .. 1 shut; brow 0 none .. 1 angry, < 0: as angry, where the sculpt has its own brow;
##         pupil size; look up), with a 9th, the z they mirror about (z is then from there); or [pair, pair, ..]
##         (up to three: a pair for each face). A part "eye" is drawn by itself, or with eyes, as the face is.
##   lid: the colour of an eyelid (default: the head's, darker)
## Per line, "base" is every stage's look and "1", "2", "3" what each stage changes.

const LINES := {
	"dino": {"base": {"col": {"body": "#f4a27c", "head": "#f4a27c", "arms": "#d83a48", "legs": "#d83a48", "tail": "#f4a27c", "horn": "#ffe0b0"},
			"tip": {"legs": ["#ffc93c", 0.86, 0.0], "arms": ["#ffc93c", 0.82, 0.0], "head": ["#d83a48", 0.7, 0.05]},
			"belly": ["#f9c9a6", 0.62, ["body"]]},
		"1": {"col": {"body": "#f6aa8c", "head": "#f6aa8c"}, "eyes": [0.155, 0.75, 0.04, 0.313, 0.4, 0.7, 0.5, 0.0]},
		"2": {"eyes": [0.13, 0.69, 0.042, 0.441, 0.4, 0.7, 0.5, 0.0]},
		"3": {"eyes": [0.085, 0.765, 0.04, 0.171, 0.4, 0.9, 0.5, 0.0]}},
	"scorpion": {"base": {"col": {"body": "#3fc463", "head": "#3fc463", "arms": "#1f9d5e", "legs": "#8e4fd0", "tail": "#3fc463", "horn": "#9b5bd8"},
			"tip": {"tail": ["#9b5bd8", 0.8, 0.05]}, "belly": ["#5fd67e", 0.7, ["body"]]},
		# 1, 2: painted over their eyeballs (so they blink); 3: round eyes under its purple lids
		"1": {"eyes": [0.16, 0.615, 0.07, 0.13, 0.4, -0.8, 0.45, 0.0]},
		"2": {"eyes": [0.097, 0.56, 0.065, 0.194, 0.4, -0.9, 0.45, 0.0]},
		"3": {"eyes": [0.072, 0.758, 0.036, 0.05, 0.0, -0.9, 0.55, 0.0]}},
	"berry": {"base": {"col": {"body": "#2f6fe0", "arms": "#5cb84a", "horn": "#5fb14a"},
			"tip": {"arms": ["#e8409a", 0.72, 0.0]}},
		"1": {"eyes": [0.1, 0.59, 0.052, 0.068, 0.5, 1.0, 0.5, 0.0]},
		"2": {"eyes": [0.095, 0.495, 0.05, -0.095, 0.5, 1.0, 0.5, 0.0]},
		# three berries, a face each: the big one, the one on its left, the one below
		"3": {"eyes": [[0.085, 0.418, 0.045, 0.034, 0.5, 1.0, 0.5, 0.0, 0.185], [0.068, 0.356, 0.04, -0.162, 0.5, 1.0, 0.5, 0.0, -0.138],
				[0.055, 0.16, 0.035, -0.134, 0.5, 1.0, 0.5, 0.0, 0.045]]}},
	"beetle": {"base": {"col": {"body": "#2f6fb8", "head": "#5aa0e8", "arms": "#4a8ad8", "legs": "#4a8ad8", "tail": "#2f6fb8", "horn": "#e8b26a"},
			"tip": {"legs": ["#e8b26a", 0.8, 0.0], "arms": ["#e8b26a", 0.75, 0.0], "head": ["#e8b26a", 0.72, 0.05]},
			"belly": ["#5aa0e8", 0.66, ["body"]]},
		"1": {"eyes": [0.155, 0.41, 0.06, 0.371, 0.4, 0.9, 0.5, 0.0]},
		"2": {"eyes": [0.075, 0.59, 0.042, 0.157, 0.4, 0.9, 0.5, 0.0]},
		"3": {"eyes": [0.046, 0.71, 0.03, 0.064, 0.4, 0.9, 0.5, 0.0]}},
	"cactus": {"base": {"col": {"body": "#5cc552", "head": "#5cc552", "arms": "#4fb048", "legs": "#4fb048", "horn": "#ff9a4a"},
			"tip": {"horn": ["#ff5468", 0.55, 0.35]}, "stripes": {"body": ["#3e9a3e", 9]}, "lid": "#3e9a3e"},
		# 1, 3: painted over their eyeballs (so they blink)
		"1": {"eyes": [0.125, 0.79, 0.1, 0.086, 0.35, -0.7, 0.45, 0.0]},
		"2": {"eyes": [0.075, 0.622, 0.05, 0.13, 0.45, -0.7, 0.5, 0.0]},
		"3": {"eyes": [0.078, 0.752, 0.064, 0.091, 0.4, -0.9, 0.45, 0.0]}},
	"crab": {"base": {"col": {"body": "#e8304e", "head": "#e8304e", "arms": "#e83a50", "legs": "#36c6d6", "horn": "#e8304e", "tail": "#e8304e"},
			"belly": ["#ffd21f", 0.6, ["body"]], "lid": "#e8304e"},
		# painted on the fronts of its eye stalks (1's eye part is only a scrap of one) and eyeballs (2, 3: as sculpted,
		# under an angry lid, rather than the eye part's own forward-facing pupil)
		"1": {"eyes": [0.135, 0.68, 0.05, 0.155, 0.35, -0.8, 0.55, 0.0]},
		"2": {"eyes": [0.125, 0.86, 0.058, -0.089, 0.45, -0.8, 0.5, 0.0]},
		"3": {"eyes": [0.085, 0.885, 0.05, -0.02, 0.4, -0.8, 0.5, 0.0]}},
	"owl": {"base": {"col": {"body": "#f0882a", "head": "#f0882a", "wings": "#ffc22e", "legs": "#f5a030", "tail": "#ffc22e", "horn": "#ffcf3a"},
			"tip": {"wings": ["#e06a1e", 0.78, 0.1]}, "belly": ["#ffb050", 0.68, ["body"]], "lid": "#c86a20"},
		# (1's eye part is only a scrap of a brow)
		"1": {"eyes": [0.1, 0.635, 0.06, 0.089, 0.4, -0.9, 0.5, 0.0]},
		"2": {"eyes": [0.1, 0.565, 0.055, 0.015, 0.4, -0.8, 0.5, 0.0]},
		"3": {"eyes": [0.082, 0.68, 0.05, 0.026, 0.45, -1.0, 0.5, 0.0]}},
	"boar": {"base": {"col": {"body": "#9a6242", "head": "#4aa8d8", "legs": "#9a6242", "arms": "#a8e4f4", "tail": "#9a6242", "horn": "#a8e4f4"},
			"tip": {"legs": ["#f2c6a8", 0.82, 0.0], "head": ["#f2c6a8", 0.62, 0.04]}, "lid": "#2856a8"},
		"1": {"eyes": [0.15, 0.71, 0.065, 0.212, 0.4, 0.8, 0.5, 0.0]},
		"2": {"eyes": [0.12, 0.685, 0.048, 0.28, 0.35, 0.7, 0.5, 0.0]},
		"3": {"eyes": [0.105, 0.69, 0.04, 0.159, 0.35, 0.9, 0.5, 0.0]}},
	"bat": {"base": {"col": {"body": "#2a5c9c", "head": "#2a5c9c", "wings": "#c848b0", "arms": "#2a5c9c", "legs": "#2a5c9c", "tail": "#c848b0", "horn": "#e0408a"},
			"tip": {"arms": ["#e0408a", 0.78, 0.0], "wings": ["#2a5c9c", 0.0, 0.0, 0.18]}, "lid": "#1c3e6e"},
		"1": {"eyes": [0.1, 0.505, 0.05, 0.148, 0.6, 0.2, 0.5, 0.0]},
		"2": {"eyes": [0.083, 0.585, 0.048, 0.15, 0.0, 0.0, 0.55, 0.0]},
		"3": {"eyes": [0.043, 0.56, 0.03, 0.117, 0.3, 0.9, 0.5, 0.0]}},
	"worm": {"base": {"col": {"body": "#ff6f8f", "head": "#ff6f8f", "arms": "#ff6f8f", "tail": "#ff6f8f", "horn": "#26bcc4", "deco": "#8a5a3a"},
			"tip": {"arms": ["#26bcc4", 0.6, 0.0]}, "bands": {"body": ["#ff9fb5", 9.0], "tail": ["#ff9fb5", 9.0]}, "lid": "#d84a6a"},
		"1": {"eyes": [0.155, 0.62, 0.05, 0.107, 0.42, -0.8, 0.5, 0.0]},
		"2": {"eyes": [0.128, 0.692, 0.045, 0.033, 0.42, -0.8, 0.5, 0.0]},
		"3": {"eyes": [0.098, 0.782, 0.04, 0.317, 0.42, -0.8, 0.5, 0.0]}},
	"tree": {"base": {"col": {"body": "#f5b862", "head": "#f5b862", "arms": "#e08a40", "legs": "#f5b862", "horn": "#f5b862"},
			"tip": {"arms": ["#fbd9a0", 0.86, 0.0], "head": ["#e08a48", 0.0, 0.0, 0.22]}, "belly": ["#f9d49c", 0.64, ["body"]], "lid": "#e08a48"},
		"1": {"eyes": [0.1, 0.755, 0.06, -0.007, 0.0, 0.0, 0.55, 0.0]},
		"2": {"eyes": [0.075, 0.785, 0.044, 0.006, 0.4, -0.9, 0.5, 0.0]},
		"3": {"eyes": [0.083, 0.8, 0.032, 0.035, 0.45, -1.0, 0.5, 0.0]}},
	"frog": {"base": {"col": {"body": "#6fd6a2", "head": "#6fd6a2", "arms": "#6fd6a2", "legs": "#f27a62", "tail": "#6fd6a2", "horn": "#f27a62"},
			"tip": {"arms": ["#f27a62", 0.55, 0.0]}, "belly": ["#f2d870", 0.72, ["body"]]},
		"1": {"eyes": [0.134, 0.845, 0.064, 0.18, 0.0, 0.0, 0.55, 0.0]},
		"2": {"eyes": [0.19, 0.925, 0.05, -0.014, 0.0, 0.0, 0.55, 0.0]},
		"3": {"eyes": [0.185, 0.902, 0.041, -0.03, 0.35, -0.9, 0.5, 0.0]}},
	"marmot": {"base": {"col": {"body": "#f2709a", "head": "#f2709a", "arms": "#f2709a", "legs": "#f2709a", "horn": "#a33244"},
			"tip": {"arms": ["#f8e2b4", 0.86, 0.0], "head": ["#a33244", 0.66, 0.04]}, "belly": ["#f7a0bd", 0.64, ["body"]], "lid": "#a33244"},
		"1": {"eyes": [0.09, 0.79, 0.042, -0.008, 0.3, 0.8, 0.5, 0.0]},
		"2": {"eyes": [0.068, 0.795, 0.035, -0.019, 0.35, 0.9, 0.5, 0.0]},
		"3": {"col": {"arms": "#a33244"}, "eyes": [0.052, 0.762, 0.03, -0.03, 0.4, 1.0, 0.5, 0.0]}},
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
