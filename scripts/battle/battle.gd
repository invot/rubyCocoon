extends Node3D
## Turn-based ring battle (as in Jade Cocoon 2). Each trainer stands in the middle of a ring of eight slots (ring.gd):
## a side per element, with corners between. One side faces the foe: its three beasts fight, using only that side's
## element (and plain, neutral moves). At the start of each turn a trainer may turn the ring to another side with a
## beast standing on it. You choose your own action, then a move for each of your three beasts (command_panel.gd, on
## the move bars beside your grid); then the two sides take their turns, the faster side first (its beasts' speed and
## its trainer's level). The foe's choices are never shown: they happen on its turn.
## If a side's middle beast is down (or its middle slot is empty), its trainer can be attacked directly: each hit
## breaks a shield point, and a hit with no shield left loses the battle. A trainer battle ends only that way, or
## when someone forfeits. Wild beasts have no ring and no trainer: beat them all to win.
## Fire = offense tanks, Water = healers, Earth = defenders, Air = status/evasion, Ghost = Legion.

signal finished(result: String)

const Beasts = preload("res://scripts/core/beasts.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const SongDB = preload("res://scripts/data/song_db.gd")
const Elements = preload("res://scripts/data/elements.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const SummonFX = preload("res://scripts/battle/summon_fx.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const Rig = preload("res://scripts/gfx/beast_rig.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const CommandPanel = preload("res://scripts/battle/command_panel.gd")
const RingGrid = preload("res://scripts/battle/ring_grid.gd")
const BattleBars = preload("res://scripts/battle/battle_bars.gd")

## the middles of the two rings: you in front, at the bottom right, seen over your shoulder; the foe further back, at
## the top left
const ALLY_CENTER := Vector3(2.4, 0, 5.4)
const FOE_CENTER := Vector3(-2.6, 0, -2.4)
const PLAYER_POS := ALLY_CENTER
const RIVAL_POS := FOE_CENTER
## a ring's radius (to the middle of its pads)
const RING_R := 2.25
## the camera, behind you and off to your left (in metres, along and across the line from your ring to the foe's), and
## where on that line it looks (0 = you, 1 = the foe)
const CAM_BACK := 10.5
const CAM_SIDE := 8.0
const CAM_HIGH := 7.5
const CAM_T := 0.35
const CAM_FOV := 24.0
const STAGE_NAMES := {"atk": "Attack", "def": "Defense", "spr": "Spirit", "spd": "Speed", "eva": "Evasion", "acc": "Accuracy"}
const EGG_CHANCE := 0.2

var cfg: Dictionary = {}
var wild := true
var trainer: Dictionary = {}
var foes: Array = []
var ally_slots: Array = [null, null, null]
var foe_slots: Array = [null, null, null]
var st := {}
var nodes := {}
var participants := {}
var result := ""
var flute_used := false
## a temple guardian battle (Story._guardian): its temple ("water", ...) and the guardian itself, which can't faint
## (it rises again) and is only won by playing the temple's song to it (_guardian_song_flow)
var guardian_tk := ""
var guardian_b = null
## you've called your one summon this battle (the Summon command)
var summoned := false
## a summon's camera, blended over the usual one while summon_mix > 0 (summon_cam), and a shake that dies away
var summon_mix := 0.0
var summon_pos := Vector3.ZERO
var summon_look := Vector3.ZERO
var summon_shake_amt := 0.0
var stage_env: Environment
var stage_sun: DirectionalLight3D
var _stage_light := []
var round_no := 0
var biome: Dictionary
var indoor := false
var drops: Array = []
## songs the rival trainer played this battle (song id -> true); you may try to learn them afterwards
var heard_songs := {}
var rival_song_count := 0
## A guided battle (see LESSONS): each round there's one thing to pick on every bar and in every menu (what's being
## taught), and you can't lose: your beasts always keep at least 1 HP, and nobody can run, forfeit or hit you.
var tutorial := false
var lesson_id := ""
var lesson: Dictionary = {}
## The guided battles: the Coastal Path's five teachers, met before you have a flute (Story.LESSON_TRAINERS), and your
## first lone wild beast after Uncle Rafe's lessons ("flute"). intro: what the teacher says before the first round
## (narration: a line before that, with no speaker; coach: who's speaking, if not the trainer). rounds: in turn (the
## last repeats), what the teacher says ({beast} is your beast, {foe} theirs), your own action ("you": Slingshot,
## Watch, Items or Flute, with "song": weaken or capture), your beast's ("beast": Fight or Defend; "target":
## "trainer" sends it at the trainer). finish: the round the foe's beast goes down (0 never). trainer: the battle
## ends by striking the trainer rather than when their beasts are down. level: the level your beast reaches.
const LESSONS := {
	"screen": {"level": 2, "finish": 2,
		"intro": ["Ooh, a brand-new trainer! I'll show you around a battle. It's less scary than it looks. Mostly.",
			"That's you at the bottom right, in the middle of your battle ring. I'm up at the top left, in mine.",
			"The little grids in the corners are the rings seen from above: mine top left, yours bottom right. Each tile is a slot, with a beast's icon and a tiny health bar on it.",
			"Beside your grid are the move bars, one for each beast: its level, the move it'll use, and underneath, its HP (its health) and MP (the energy elemental moves use).",
			"Each round you pick your own action first, on the gold-trimmed bar, then a move for each beast. Left and right change the choice, A confirms it, B goes back.",
			"In a lesson there's just the one thing to pick, so A it is! In a real battle, left and right (or a tap on a foe's grid tile) choose your target. The arrow shows who you're aiming at. A confirms."],
		"rounds": [
			{"say": ["This round you just Watch, and {beast} Fights with its best move.", "Pick Watch on your own bar, then the move on {beast}'s bar."],
				"you": "Watch", "beast": "Fight"},
			{"say": ["Nice hit! The number that popped up is the damage it did. Once more to finish my {foe}!"], "you": "Watch", "beast": "Fight"},
		]},
	"turns": {"level": 3, "finish": 3,
		"intro": ["Battles go in rounds, like the tide. Everybody picks what they'll do first, then the two sides take their turns.",
			"The side with the faster beasts goes first, and a higher trainer level helps too. I'll let you go first today. The fish can wait."],
		"rounds": [
			{"say": ["Uh oh, my {foe} is winding up something big!", "When a big hit is coming, Defend: a defending beast takes half damage until your side's next turn, and Defend always goes first.",
				"Watch on your own bar, then Defend on {beast}'s."], "you": "Watch", "beast": "Defend"},
			{"say": ["Barely a scratch! Now strike back.", "Elemental moves cost MP, but plain moves are free, so you can always fight."], "you": "Watch", "beast": "Fight"},
			{"say": ["Once more, with feeling!"], "you": "Watch", "beast": "Fight"},
		]},
	"slingshot": {"level": 3, "finish": 2,
		"intro": ["You're not just a spectator, you know! You get a turn too: your own bar comes first.",
			"Slingshot flings a pebble at a foe. Watch lets your beasts handle it. Items patch someone up. Once you have a flute, you can play songs.",
			"Run gets you out of a wild battle. Against a trainer it's Forfeit: it counts as a loss, but nobody holds a grudge. Except my cousin."],
		"rounds": [
			{"say": ["Fire your slingshot at my {foe}! On your side's turn your own action goes first, before your beasts move."], "you": "Slingshot", "beast": "Fight"},
			{"say": ["Pew! Again, both of you together!"], "you": "Slingshot", "beast": "Fight"},
		]},
	"items": {"level": 4, "finish": 3,
		"intro": ["Picnic rule number one: never battle hungry. Rule number two: always, ALWAYS pack potions."],
		"rounds": [
			{"say": ["Warm-up round! You Watch, {beast} Fights."], "you": "Watch", "beast": "Fight"},
			{"say": ["Ouch, {beast} got nipped! Open Items on your own bar and give it a Minor Potion.",
				"Potions heal HP, Spirit Drops bring back MP, and there are cures, bombs and tonics too. The apothecary in every town sells them."],
				"you": "Items", "beast": "Fight"},
			{"say": ["Good as new! Now finish it!"], "you": "Watch", "beast": "Fight"},
		]},
	"ring": {"level": 4, "finish": 1, "trainer": true,
		"intro": ["Last lesson before Bellerive: the battle ring. This is how the pros fight.",
			"Every trainer stands in the middle of a ring of eight slots. It has a side for each element, round it in this order: Fire, Air, Water, Earth.",
			"Only the side facing the foe fights, with that side's element or plain moves. With more beasts, you can turn your ring: up on the top beast, or down on the bottom one.",
			"The beast in the MIDDLE of the side facing the foe guards its trainer. Knock out the foe's middle beast, and the trainer behind it is open to attack!"],
		"rounds": [
			{"say": ["My {foe} is guarding me. Take it down!"], "you": "Watch", "beast": "Fight"},
			{"say": ["My middle beast is down, so I'm wide open! Have {beast} attack me directly. Go on, I can take it.",
				"Every hit on a trainer breaks one of their shield points: the blue orbs under their grid. A trainer hit with no shield left loses the battle. I've got none today."],
				"you": "Watch", "beast": "Fight", "target": "trainer"},
		]},
	# Bellerive's arena coaches (story.gd ARENA_LESSONS). practice: the arena's practice beasts fill the empty slots of
	# the side facing the foe (and the coach's "practice_side" turns your ring to that side first), see _practice_beasts
	"team": {"finish": 2, "practice": true,
		"intro": ["In a real battle, every beast on the side of your ring facing the foe fights: up to three at once, each with its own bar.",
			"The arena's practice beasts will stand in your empty slots today. They're very professional. They've been bonked by the best.",
			"After your own action, each beast's bar opens in turn. Up and down move between your beasts; left and right pick a move."],
		"rounds": [
			{"say": ["Pick a move for every one of your beasts. Today they all go for the same one of mine: in a real battle, the arrows show who each move is aimed at."], "you": "Watch", "beast": "Fight"},
			{"say": ["Teamwork! Two beasts on the same foe knock it out twice as fast. Finish my team!"], "you": "Watch", "beast": "Fight"},
		]},
	"elements": {"finish": 2, "practice": true,
		"intro": ["Every element has a weakness: fire beasts are weak to air, earth to water, water to air, and air to fire.",
			"Hit a beast with the element it's weak to and it takes double damage! Hit it with its own element, though, and it shrugs some off.",
			"After a hit, a message tells you when it was extra effective or the target is resistant. Only the element of the side facing the foe can be used: turn your ring to the side that hits hardest. Today I've turned it for you."],
		"rounds": [
			{"say": ["My {foe} is weak to the element of your side. Pick the elemental move and watch it fly!"], "you": "Watch", "beast": "Fight"},
			{"say": ["Double damage! Finish it the same way. And remember: your beasts have weaknesses too."], "you": "Watch", "beast": "Fight"},
		]},
	"flute": {"finish": 6, "coach": "Uncle Rafe",
		"narration": "A wild {foe}! Uncle Rafe's advice comes back to you...",
		"intro": ["\"A wild beast's your chance to put that flute to work. Songs change how a fight goes. Weaken, for one, makes a foe drop its guard so your beasts hit harder.\""],
		"rounds": [
			{"say": ["\"Open Flute on your own bar and play Weaken at it. Your beast can Fight in the meantime.\""],
				"you": "Flute", "song": "weaken", "beast": "Fight"},
			{"say": ["\"See it flinch? Weakened and worn down, a beast listens much better. So does one that's asleep or out of sorts.\"",
				"\"Now play Capture, and it might just join you! Have {beast} Defend, so you don't knock it out first.\""],
				"you": "Flute", "song": "capture", "beast": "Defend"},
			{"say": ["\"So close! Play it again, nice and steady.\""], "you": "Flute", "song": "capture", "beast": "Defend"},
		]},
}
## Defending halves the damage a beast takes until its side's next turn.
const DEFEND_MULT := 0.5

var cam: Camera3D
## The original arcing arrow connects the attacker to every selected target.
var aim_mesh: MeshInstance3D
var _aim_from = null
var _target_refs: Array = []
var _time := 0.0
var player_rig: Node3D
var rival_rig: Node3D
var shield_label: Label3D
var shield_bubble: MeshInstance3D

var hud: Control
var msg_label: Label
var caption: PanelContainer
## while commands are chosen: the window at the top explaining the highlighted action or move (see _show_option)
var move_info: PanelContainer
var _info_hint := ""
var bars: Control
var message_line: HBoxContainer
var message_icon: TextureRect
var _speaker_icons: Dictionary = {}
var _message_subject = null
var ally_grid: Control
var foe_grid: Control
var cmd_root: Control
## true while the command panel owns the bars
var _commanding := false
## the command panel's rows this round (see _panel_rows)
var _rows_now: Array = []

## the rings: {slot: beast}. Wild beasts stand in a plain line (foe_slots) with no ring.
var ally_ring := {}
var foe_ring := {}
## the side of each ring facing the other (0 Fire, 1 Air, 2 Water, 3 Earth)
var ally_side := 0
var foe_side := 0
## the rival trainer's shield (yours is GameState.shield)
var foe_shield := 0
var foe_max_shield := 0
## each ring's turn (radians), and its pads and circle
var ring_psi := {"ally": 0.0, "foe": 0.0}
var ring_root := {}
var pads := {"ally": {}, "foe": {}}
var rival_shield_label: Label3D
var rival_bubble: MeshInstance3D
## whether each trainer was open to attack at the last check (for the announcements)
var _open_was := {"ally": false, "foe": false}


func setup(c: Dictionary) -> void:
	cfg = c
	wild = c.get("wild", true)
	foes = c["foes"]
	trainer = c.get("trainer", {})
	guardian_tk = String(c.get("guardian", ""))
	if guardian_tk != "" and not foes.is_empty():
		guardian_b = foes[0]
	lesson_id = String(c.get("lesson", trainer.get("lesson", "")))
	lesson = LESSONS.get(lesson_id, {})
	tutorial = not lesson.is_empty()
	var map_id: String = c.get("map", "route1")
	biome = WorldDB.biome_of(map_id)
	indoor = "#" in map_id


func _ready() -> void:
	_build_stage()
	_build_hud()
	_battle_music()
	_run.call_deferred()


func _battle_music() -> void:
	Sfx.music("boss" if is_boss() else "battle")


## Bosses: temple guardians, arena leaders, the CEO, the bandit boss and the Legion's commanders.
func is_boss() -> bool:
	return guardian_tk != "" or (not wild and (trainer.get("boss", false) or trainer.get("guardian", false)))


# ================================================================ stage
func _xf(pos: Vector3, rot_y := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3(s, s, s)), pos)


func _multimesh(mesh: Mesh, xforms: Array, mat: Material = null) -> void:
	if xforms.is_empty() or mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat:
		mi.material_override = mat
	add_child(mi)


func _tex_mat(t: Texture2D, uv := Vector2.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(uv.x, uv.y, 1)
	m.roughness = 1.0
	return m


func _build_stage() -> void:
	var arena: bool = cfg.get("arena", false)
	var dark: bool = indoor and not arena
	var env := Environment.new()
	if dark:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#0d0a12")
	else:
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(biome["sky_top"])
		sm.sky_horizon_color = Color(biome["sky_hz"])
		sm.ground_horizon_color = Color(biome["sky_hz"])
		sm.ground_bottom_color = Color(biome["ground"]).darkened(0.5)
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(biome["sky_top"]).lerp(Color(biome["ground"]), 0.4) if not dark else Color("#a898c8")
	env.ambient_light_energy = float(biome["amb"]) + 0.1 if not dark else 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.fog_enabled = not dark
	env.fog_light_color = Color(biome["sky_hz"])
	env.fog_density = float(biome.get("fog", 0.004))
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	stage_env = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(biome["sun"]) if not dark else Color("#d8c8ff")
	sun.light_energy = float(biome["sun_e"]) if not dark else 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	stage_sun = sun
	_stage_light = [env.ambient_light_energy, sun.light_energy]

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", randi()))
	var sandy: bool = biome["id"] in ["desert", "mesa", "western"]
	# a beast you've reeled in: you on a plank dock, the beach behind you, the beast out on the water
	var fishing: bool = cfg.get("fishing", false)
	var ground_tex: Texture2D
	if fishing:
		ground_tex = VT.terrain("top_sand", biome.get("sand", "#ecd8a0"))
	elif arena:
		ground_tex = VT.terrain("top_plaza", biome["plaza"])
	elif dark:
		ground_tex = VT.terrain("top_plaza", "#4a4652")
	elif sandy:
		ground_tex = VT.terrain("top_sand", biome["sand"])
	else:
		ground_tex = VT.terrain("top_grass", biome["ground"])
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 50)
	ground.mesh = pm
	ground.material_override = _tex_mat(ground_tex, Vector2(70, 50))
	ground.position = Vector3(0, 0, -10) if not fishing else Vector3(0, -0.6, -10)
	add_child(ground)
	_build_ring("ally")
	if not wild:
		_build_ring("foe")
	# a low cobbled mound under the wild beasts (not out on the water)
	for center in ([] if not wild or fishing else [FOE_CENTER + _toward("foe") * 0.9]):
		var k := VBld.Kit.new()
		var col := Color(biome["path"] if not arena else biome["plaza"]) if not dark else Color("#5a5664")
		var tex := "cobble" if not dark else "stone_dark"
		var n := 14
		var top := []
		var foot := []
		for i in n:
			var a := TAU * i / n
			var wob := 1.0 + rng.randf_range(-0.05, 0.05)
			top.append(Vector3(cos(a) * 3.4 * wob, 0.14, sin(a) * 2.0 * wob))
			foot.append(Vector3(cos(a) * 3.8 * wob, -0.02, sin(a) * 2.35 * wob))
		for i in n:
			var j := (i + 1) % n
			k.poly(tex, [Vector3(0, 0.14, 0), top[i], top[j]], Vector3.UP, col)
			var out: Vector3 = (top[i] + top[j]).normalized()
			k.poly(tex, [top[i], top[j], foot[j], foot[i]], (out + Vector3(0, 0.6, 0)).normalized(), col.darkened(0.12))
		var mi := MeshInstance3D.new()
		mi.mesh = k.mesh()
		mi.position = center
		add_child(mi)
	if fishing:
		_fishing_scenery(rng)
	elif arena:
		_arena_scenery(rng)
	elif dark:
		_indoor_scenery(rng)
	else:
		_outdoor_scenery(rng)

	cam = Camera3D.new()
	cam.fov = CAM_FOV
	add_child(cam)
	cam.position = _cam_pos()
	cam.look_at(_cam_look(), Vector3.UP)
	cam.current = true
	aim_mesh = MeshInstance3D.new()
	aim_mesh.mesh = ImmediateMesh.new()
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.vertex_color_use_as_albedo = true
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.no_depth_test = true
	am.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.render_priority = 10
	aim_mesh.material_override = am
	aim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_mesh)
	_build_trainers()



# ================================================================ rings
## Which way a team faces: the direction (in the ground plane) from its ring to the other side.
func _toward(team: String) -> Vector3:
	var d := (FOE_CENTER - ALLY_CENTER) if team == "ally" else (ALLY_CENTER - FOE_CENTER)
	d.y = 0.0
	return d.normalized()


func _facing(team: String) -> float:
	var d := _toward(team)
	return atan2(d.z, d.x)


## Your right, looking at the foe.
func _right() -> Vector3:
	var f := _toward("ally")
	return Vector3(-f.z, 0, f.x)


## Over your shoulder: behind you and off to your left, so you stand at the bottom right and the foe at the top left.
func _cam_pos() -> Vector3:
	return ALLY_CENTER - _toward("ally") * CAM_BACK - _right() * CAM_SIDE + Vector3(0, CAM_HIGH, 0)


func _cam_look() -> Vector3:
	return ALLY_CENTER.lerp(FOE_CENTER, CAM_T) + Vector3(0, 0.6, 0)


## Beasts face the other side, turned a little towards the camera.
func _beast_yaw(team: String) -> float:
	return -(_facing(team) + (-0.5 if team == "ally" else 0.35))


func _center(team: String) -> Vector3:
	return ALLY_CENTER if team == "ally" else FOE_CENTER


## The ring's turn that puts `side`'s middle slot towards the foe. Slot k sits at angle psi - k * 45 deg, so the slots
## run anticlockwise seen from above (as on the grids in the HUD): a side's top slot stands at its front right.
func _psi_for(team: String, side: int) -> float:
	return _facing(team) + deg_to_rad(90.0 * side)


func _slot_pos(team: String, k: int) -> Vector3:
	var a := float(ring_psi[team]) - deg_to_rad(45.0 * k)
	return _center(team) + Vector3(cos(a), 0.0, sin(a)) * RING_R


## The glowing circle and the eight pads of a ring (they turn together; the beasts on them are placed each turn).
func _build_ring(team: String) -> void:
	var root := Node3D.new()
	root.position = _center(team)
	add_child(root)
	ring_root[team] = root
	var circle := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RING_R * 2.0 + 2.9, RING_R * 2.0 + 2.9)
	circle.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = _circle_texture()
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color("#ffe39a") if team == "ally" else Color("#ffc890")
	cm.emission_enabled = true
	cm.emission = cm.albedo_color
	cm.emission_energy_multiplier = 1.4
	circle.material_override = cm
	circle.position.y = 0.03
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(circle)
	# the trainer's own dais in the middle
	root.add_child(_dais())
	for k in Ring.SLOTS:
		var pad := _make_pad(k)
		var a := -deg_to_rad(45.0 * k)
		pad.position = Vector3(cos(a), 0.0, sin(a)) * RING_R
		pad.rotation.y = -a
		root.add_child(pad)
		pads[team][k] = pad
	ring_psi[team] = _psi_for(team, ally_side if team == "ally" else foe_side)
	root.rotation.y = -float(ring_psi[team])


## A pad: a six-sided stone plinth on a wider foot, trimmed in gold, with gold studs at its corners and a glowing sigil
## of its slot's element(s) on top.
func _make_pad(k: int) -> Node3D:
	var pad := Node3D.new()
	var stone := VT.material("stone")
	var foot := MeshInstance3D.new()
	foot.mesh = _hex_mesh(0.78, 0.84, 0.08)
	foot.material_override = stone
	foot.position.y = 0.04
	pad.add_child(foot)
	var body := MeshInstance3D.new()
	body.mesh = _hex_mesh(0.62, 0.7, 0.14)
	body.material_override = stone
	body.position.y = 0.15
	pad.add_child(body)
	var trim := MeshInstance3D.new()
	trim.mesh = _hex_mesh(0.645, 0.645, 0.04)
	trim.material_override = _gold_mat()
	trim.position.y = 0.235
	pad.add_child(trim)
	var studs := []
	for i in 6:
		var a := TAU * i / 6.0
		studs.append(Transform3D(Basis(), Vector3(cos(a) * 0.74, 0.11, sin(a) * 0.74)))
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.11
	sm.radial_segments = 6
	sm.rings = 3
	for x in studs:
		var st_mi := MeshInstance3D.new()
		st_mi.mesh = sm
		st_mi.material_override = _gold_mat()
		st_mi.transform = x
		pad.add_child(st_mi)
	var top := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.12, 1.12)
	top.mesh = q
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _sigil_texture(Ring.slot_elements(k))
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tm.emission_enabled = true
	tm.emission_texture = tm.albedo_texture
	tm.emission_energy_multiplier = 0.35
	tm.roughness = 0.6
	top.material_override = tm
	top.position.y = 0.262
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.add_child(top)
	pad.set_meta("sigil", tm)
	return pad


## The trainer's dais: a low round step with a gold rim.
func _dais() -> Node3D:
	var n := Node3D.new()
	var base := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.82
	cy.bottom_radius = 0.92
	cy.height = 0.1
	cy.radial_segments = 16
	cy.rings = 1
	base.mesh = cy
	base.material_override = VT.material("stone")
	base.position.y = 0.05
	n.add_child(base)
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.76
	tor.outer_radius = 0.84
	tor.rings = 24
	tor.ring_segments = 4
	rim.mesh = tor
	rim.material_override = _gold_mat()
	rim.position.y = 0.1
	n.add_child(rim)
	return n


static var _hex_cache := {}
static var _gold: StandardMaterial3D = null
static var _sigils := {}


## Paints the ring's textures and makes its pieces ahead of the first battle (main.gd, while a map loads behind the
## fade): painted pixel by pixel, they held the first battle's swirl still for seconds on a phone, as if it had hung.
static func prewarm() -> void:
	_circle_texture()
	for k in Ring.SLOTS:
		_sigil_texture(Ring.slot_elements(k))
	_hex_mesh(0.78, 0.84, 0.08)
	_hex_mesh(0.62, 0.7, 0.14)
	_hex_mesh(0.645, 0.645, 0.04)
	_gold_mat()
	VT.material("stone")


## A six-sided prism (a squat hexagonal cylinder), cached by size.
static func _hex_mesh(top_r: float, bottom_r: float, h: float) -> CylinderMesh:
	var key := "%s:%s:%s" % [top_r, bottom_r, h]
	if _hex_cache.has(key):
		return _hex_cache[key]
	var cy := CylinderMesh.new()
	cy.top_radius = top_r
	cy.bottom_radius = bottom_r
	cy.height = h
	cy.radial_segments = 6
	cy.rings = 1
	_hex_cache[key] = cy
	return cy


static func _gold_mat() -> StandardMaterial3D:
	if _gold == null:
		_gold = StandardMaterial3D.new()
		_gold.albedo_color = Color("#d9b25a")
		_gold.metallic = 0.7
		_gold.roughness = 0.35
		_gold.emission_enabled = true
		_gold.emission = Color("#6a4a10")
		_gold.emission_energy_multiplier = 0.4
	return _gold


## A pad's sigil: a gold ring with rune ticks round a disc in its element's colour (a corner's disc split between its
## two), with the element's sign in the middle.
static func _sigil_texture(els: Array) -> ImageTexture:
	var key := ",".join(els)
	if _sigils.has(key):
		return _sigils[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n, n) / 2.0
	var gold := Color("#f4d27a")
	var c0 := Elements.color(String(els[0]))
	var c1 := Elements.color(String(els[els.size() - 1]))
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length() / (n / 2.0)
			var ang := atan2(p.y, p.x)
			var col := Color(0, 0, 0, 0)
			if r < 0.74:
				# the disc: its element's colour, darker at the rim, split on a diagonal for a corner
				var base := c0 if (els.size() == 1 or p.x + p.y < 0.0) else c1
				col = base.darkened(0.15 + 0.35 * r)
				col.a = 0.92
			# the gold ring, its inner hairline and the rune ticks between them
			var ring := clampf(1.0 - absf(r - 0.86) / 0.05, 0.0, 1.0)
			ring = maxf(ring, clampf(1.0 - absf(r - 0.74) / 0.02, 0.0, 1.0))
			if r > 0.76 and r < 0.84:
				var t := fposmod(ang / TAU * 24.0, 1.0)
				if t < 0.18 or (t > 0.45 and t < 0.55 and r < 0.8):
					ring = maxf(ring, 0.85)
			if ring > 0.0:
				col = col.lerp(gold, ring)
				col.a = maxf(col.a, ring)
			img.set_pixel(x, y, col)
	_draw_sign(img, String(els[0]) if els.size() == 1 else "", gold)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_sigils[key] = tex
	return tex


## The element's sign in the middle of a sigil: a flame (triangle), a drop (circle), a swirl (three arcs) or a stone
## (diamond). Corners get a small star.
static func _draw_sign(img: Image, el: String, col: Color) -> void:
	var n := img.get_width()
	var c := Vector2(n, n) / 2.0
	var s := n * 0.2
	for y in n:
		for x in n:
			var p := (Vector2(x + 0.5, y + 0.5) - c) / s
			var on := false
			match el:
				"fire":
					on = p.y < 0.85 and p.y > -1.0 and absf(p.x) < (p.y + 1.0) * 0.45 and not (absf(p.x) < (p.y + 0.4) * 0.25 and p.y > 0.0)
				"water":
					var r := p.length()
					on = (r < 0.75 and r > 0.48) or (p.y < -0.5 and absf(p.x) < (p.y + 1.25) * 0.5 and p.y > -1.2)
				"air":
					for i in 3:
						var q := p - Vector2(0, (i - 1) * 0.55)
						var w := 0.9 - absf(i - 1) * 0.2
						on = on or (absf(q.y + sin(q.x * 3.0) * 0.12) < 0.1 and absf(q.x) < w)
				"earth":
					on = absf(p.x) + absf(p.y) < 0.95 and absf(p.x) + absf(p.y) > 0.62
				"ghost":
					on = p.length() < 0.7 and p.length() > 0.45
				_:
					var a := atan2(p.y, p.x)
					var r2 := p.length()
					on = r2 < 0.35 + 0.35 * pow(absf(cos(a * 2.0)), 6.0)
			if on:
				img.set_pixel(x, y, col)


static var _circle_tex: ImageTexture = null


## The ring's circle on the ground: a double outer ring with a band of runes, an eight-pointed star and an inner ring,
## in soft white (the material tints and lights it).
static func _circle_texture() -> ImageTexture:
	if _circle_tex != null:
		return _circle_tex
	var n := 384
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2(n, n) / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# the runes: short strokes in cells round the band between the two outer rings
	var runes := []
	for i in 40:
		var strokes := []
		for j in rng.randi_range(2, 3):
			strokes.append([Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))])
		runes.append(strokes)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length() / (n / 2.0)
			var a := 0.0
			a = maxf(a, clampf(1.0 - absf(r - 0.95) / 0.012, 0.0, 1.0))
			a = maxf(a, clampf(1.0 - absf(r - 0.83) / 0.008, 0.0, 1.0) * 0.8)
			a = maxf(a, clampf(1.0 - absf(r - 0.3) / 0.01, 0.0, 1.0) * 0.8)
			a = maxf(a, clampf(1.0 - absf(r - 0.26) / 0.005, 0.0, 1.0) * 0.6)
			if r > 0.85 and r < 0.93:
				var ang := fposmod(atan2(p.y, p.x), TAU)
				var cell := int(ang / TAU * 40.0)
				var lx := (fposmod(ang / TAU * 40.0, 1.0) - 0.5) * 2.0 / 0.7
				var ly := (r - 0.89) / 0.03
				if absf(lx) < 1.0 and absf(ly) < 1.0:
					for sk in runes[cell]:
						var d := Geometry2D.get_closest_point_to_segment(Vector2(lx, ly), sk[0], sk[1]).distance_to(Vector2(lx, ly))
						a = maxf(a, clampf(1.0 - d / 0.22, 0.0, 1.0) * 0.75)
			if r < 0.83:
				for i in 8:
					var p0 := Vector2(cos(TAU * i / 8.0), sin(TAU * i / 8.0)) * 0.83 * n / 2.0
					var p1 := Vector2(cos(TAU * (i + 3) / 8.0), sin(TAU * (i + 3) / 8.0)) * 0.83 * n / 2.0
					var d2 := Geometry2D.get_closest_point_to_segment(p, p0, p1).distance_to(p) / (n / 2.0)
					a = maxf(a, clampf(1.0 - d2 / 0.007, 0.0, 1.0) * 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex


## Lights the sigils of the side facing the foe.
func _light_pads(team: String) -> void:
	var side := ally_side if team == "ally" else foe_side
	var on := Ring.side_slots(side)
	for k in pads[team]:
		var pad: Node3D = pads[team][k]
		var m: StandardMaterial3D = pad.get_meta("sigil")
		m.emission_energy_multiplier = 1.5 if k in on else 0.3


## Puts every beast of a ring on its pad (after the ring turns), facing the foe.
func _place_ring(team: String) -> void:
	if ring_root.has(team):
		(ring_root[team] as Node3D).rotation.y = -float(ring_psi[team])
	var r: Dictionary = ally_ring if team == "ally" else foe_ring
	for k in r:
		var b = r[k]
		if b == null or not nodes.has(b):
			continue
		var n: Node3D = nodes[b]
		var p := _slot_pos(team, k)
		n.position = Vector3(p.x, n.position.y, p.z)
		n.rotation.y = _beast_yaw(team)


## Turns a ring so `side` faces the foe (a short spin), and makes that side's beasts the active three.
func _turn_ring(team: String, side: int) -> void:
	var from := float(ring_psi[team])
	var to := _psi_for(team, side)
	to = from + wrapf(to - from, -PI, PI)
	var was := ally_side if team == "ally" else foe_side
	if team == "ally":
		ally_side = side
	else:
		foe_side = side
	var grid: Control = ally_grid if team == "ally" else foe_grid
	if grid != null and not (team == "foe" and wild):
		grid.side = side
		grid.animate_turn(was)
	Sfx.play("page")
	var tw := create_tween()
	tw.tween_method(func(v: float): ring_psi[team] = v; _place_ring(team), from, to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	ring_psi[team] = to
	_place_ring(team)
	_sync_slots()
	_light_pads(team)
	_refresh()


## The three active rows of each side, from the rings (top corner, middle, bottom corner).
func _sync_slots() -> void:
	var a := []
	for k in Ring.side_slots(ally_side):
		a.append(ally_ring.get(k, null))
	ally_slots = a
	if not wild:
		var f := []
		for k in Ring.side_slots(foe_side):
			f.append(foe_ring.get(k, null))
		foe_slots = f


## True if a trainer can be attacked directly: the middle beast of the side facing the foe is down, or missing.
## Wild beasts have no trainer to attack.
func _side_open(team: String) -> bool:
	if team == "foe" and wild:
		return false
	var mid = (ally_slots if team == "ally" else foe_slots)[1]
	return mid == null or mid.hp <= 0


func _team(b) -> String:
	return String(_st(b)["side"])


## The element a beast fights with right now (see ring.gd); a wild beast fights with its own.
func _fight_el(b) -> String:
	if _team(b) == "foe" and wild:
		return "ghost" if b.ghost else String(b.element)
	return Ring.fighting_element(b, ally_side if _team(b) == "ally" else foe_side)


func _guard_el(b) -> String:
	if _team(b) == "foe" and wild:
		return String(b.element)
	return Ring.guarding_element(b, ally_side if _team(b) == "ally" else foe_side)


## The moves a beast can use this round: those of the element it fights with, and neutral ones (always including a
## plain attack, in case it has none).
func _usable_moves(b) -> Array:
	var el := _fight_el(b)
	var out := []
	for mv in b.battle_moves():
		var m := MoveDB.get_move(mv)
		if m["el"] == "neutral" or m["el"] == el:
			out.append(mv)
	if not out.any(func(mv): return MoveDB.mp_cost(mv) == 0 and MoveDB.get_move(mv)["kind"] == "attack" and MoveDB.get_move(mv)["el"] == "neutral"):
		out.append("tackle")
	return out


## Where a wild beast stands (row i of up to three), in a loose line in front of the foe's side.
func _wild_pos(i: int) -> Vector3:
	var d := _toward("foe")
	var perp := Vector3(-d.z, 0, d.x)
	if guardian_tk != "":
		# the guardian at the back in the middle, its helpers in front to either side
		if i == 0:
			return FOE_CENTER - d * 0.7
		return FOE_CENTER + d * 1.3 + perp * (1.7 if i == 1 else -1.7)
	var n := mini(3, foes.size())
	var off := (float(i) - float(n - 1) / 2.0) * 2.1
	return FOE_CENTER + d * 0.9 + perp * off


func _outdoor_scenery(rng: RandomNumberGenerator) -> void:
	var trees: Array = biome["trees"]
	var by_asset := {}
	for i in 22:
		var e: Array = trees[rng.randi_range(0, trees.size() - 1)]
		var name: String = e[0]
		var x := rng.randf_range(-18, 18)
		var z := rng.randf_range(-16, -6.5)
		var s := VA.fit_scale(name, rng.randf_range(2.4, 3.4))
		if not by_asset.has(name):
			by_asset[name] = []
		by_asset[name].append(_xf(Vector3(x, -VA.aabb(name).position.y * s, z), rng.randi_range(0, 3) * PI / 2.0, s))
	for i in 7:
		var rocks: Array = biome["rocks"]
		var rn: String = rocks[rng.randi_range(0, rocks.size() - 1)]
		var s2 := VA.fit_scale(rn, -1.0, rng.randf_range(0.9, 1.6))
		var x2 := rng.randf_range(-12, 12)
		if absf(x2) < 7.5:
			x2 = 7.5 * signf(x2 + 0.01) + x2 * 0.3
		if not by_asset.has(rn):
			by_asset[rn] = []
		by_asset[rn].append(_xf(Vector3(x2, -VA.aabb(rn).position.y * s2, rng.randf_range(-6, -3.5)), rng.randi_range(0, 3) * PI / 2.0, s2))
	for name in by_asset:
		_multimesh(VA.mesh(name), by_asset[name])
	var tufts := [[], [], []]
	for i in 56:
		var p := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-7, 10))
		# clear of both rings
		for c: Vector3 in [ALLY_CENTER, FOE_CENTER]:
			var off: Vector3 = p - c
			if off.length() < 4.0:
				p = c + off.normalized() * rng.randf_range(4.0, 5.5)
		tufts[i % 3].append(_xf(p, rng.randi_range(0, 3) * PI / 2.0, rng.randf_range(0.9, 1.3)))
	for i in 3:
		_multimesh(VP.grass_tuft(biome["tuft"], i), tufts[i])
	if biome["id"] in ["coast", "quarter", "island", "river", "reef"]:
		var water := MeshInstance3D.new()
		var wp := PlaneMesh.new()
		wp.size = Vector2(80, 14)
		water.mesh = wp
		var wm := _tex_mat(VT.terrain("water", biome["water"]), Vector2(80, 14))
		wm.roughness = 0.15
		wm.metallic_specular = 0.9
		water.material_override = wm
		water.position = Vector3(0, 0.02, -24)
		add_child(water)


## The fishing battle: open water from just past your ring out to a far shore of trees, your ring on a plank dock
## running out from the beach, mooring posts along it, a few rocks in the water, and ripples round the beast you hooked.
func _fishing_scenery(rng: RandomNumberGenerator) -> void:
	var f := _toward("ally")
	var side := Vector3(-f.z, 0, f.x)
	var water_col := String(biome.get("water", "#3a90e0"))
	# the water a little below the dock (the sandy bed sinks out of sight under it), and the beach on your side of a
	# shoreline just behind your ring
	var turn := -atan2(f.z, f.x) + PI / 2.0
	var shore := ALLY_CENTER - f * 4.0
	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(110, 110)
	water.mesh = wp
	var wm := _tex_mat(VT.terrain("water", water_col), Vector2(110, 110))
	wm.roughness = 0.15
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.position = FOE_CENTER + Vector3(0, -0.15, 0)
	add_child(water)
	var beach := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(90, 40)
	beach.mesh = bp
	beach.material_override = _tex_mat(VT.terrain("top_sand", biome.get("sand", "#ecd8a0")), Vector2(90, 40))
	beach.position = shore - f * 20.0
	beach.rotation.y = turn
	add_child(beach)
	# the dock: planks across, from the beach out past your ring, with mooring posts down each side
	var k := VBld.Kit.new()
	var wood := Color("#9a7448")
	var start := -4.4
	var stop := 3.4
	var half := 3.0
	var t := start
	var i := 0
	while t < stop:
		var c := ALLY_CENTER + f * t
		var col := wood if i % 3 != 1 else wood.darkened(0.12)
		var corners := [c - side * half, c + side * half, c + side * half + f * 0.28, c - side * half + f * 0.28]
		for q in 4:
			corners[q].y = 0.02
		k.poly("planks", corners, Vector3.UP, col)
		t += 0.3
		i += 1
	for s in [-1.0, 1.0]:
		var d := start + 0.6
		while d < stop:
			var pp: Vector3 = ALLY_CENTER + f * d + side * s * (half + 0.12) + Vector3(0, 0.2, 0)
			k.box("color", pp, Vector3(0.22, 0.7, 0.22), Color("#5a3e26"))
			d += 2.2
	# the dock's edge, a beam along each side
	for s2 in [-1.0, 1.0]:
		var a: Vector3 = ALLY_CENTER + f * start + side * s2 * half
		var b: Vector3 = ALLY_CENTER + f * stop + side * s2 * half
		k.poly("color", [a + Vector3(0, 0.02, 0), b + Vector3(0, 0.02, 0), b + Vector3(0, -0.35, 0), a + Vector3(0, -0.35, 0)], side * s2, Color("#6a4a2a"))
	var dock := MeshInstance3D.new()
	dock.mesh = k.mesh()
	add_child(dock)
	# rocks in the water and a far shore of trees
	var by_asset := {}
	var rocks: Array = biome.get("rocks", ["rock_small"])
	for n in 6:
		var rn: String = rocks[rng.randi_range(0, rocks.size() - 1)]
		var s3 := VA.fit_scale(rn, -1.0, rng.randf_range(0.8, 1.5))
		var p := FOE_CENTER + side * rng.randf_range(-11.0, 11.0) + f * rng.randf_range(2.0, 9.0)
		if (p - FOE_CENTER).length() < 4.0:
			p += side * 5.0
		if not by_asset.has(rn):
			by_asset[rn] = []
		by_asset[rn].append(_xf(p + Vector3(0, -VA.aabb(rn).position.y * s3 - 0.25, 0), rng.randi_range(0, 3) * PI / 2.0, s3))
	var trees: Array = biome.get("trees", [["palm", 1]])
	for n in 26:
		var e: Array = trees[rng.randi_range(0, trees.size() - 1)]
		var name: String = e[0]
		var p2 := FOE_CENTER + f * rng.randf_range(16.0, 22.0) + side * rng.randf_range(-24.0, 24.0)
		var s4 := VA.fit_scale(name, rng.randf_range(2.6, 3.6))
		if not by_asset.has(name):
			by_asset[name] = []
		by_asset[name].append(_xf(p2 + Vector3(0, -VA.aabb(name).position.y * s4, 0), rng.randi_range(0, 3) * PI / 2.0, s4))
	for name in by_asset:
		_multimesh(VA.mesh(name), by_asset[name])
	# the far shore's sand under those trees
	var far := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(90, 12)
	far.mesh = fp
	far.material_override = _tex_mat(VT.terrain("top_sand", biome.get("sand", "#ecd8a0")), Vector2(90, 12))
	far.position = FOE_CENTER + f * 20.0
	far.rotation.y = turn
	add_child(far)
	# ripples round the beasts out on the water
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.55)
	for j in mini(3, foes.size()):
		for r in 2:
			var ring := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.75 + r * 0.45
			tor.outer_radius = 0.85 + r * 0.45
			tor.rings = 28
			tor.ring_segments = 4
			tor.material = rm
			ring.mesh = tor
			ring.position = _wild_pos(j) + Vector3(0, -0.12, 0)
			add_child(ring)


func _arena_scenery(rng: RandomNumberGenerator) -> void:
	var xs := []
	var bx := []
	var tx := []
	var ps := VA.fit_scale("stone_pillar", 4.2)
	var bs := VA.fit_scale("banner", 3.0)
	var ts := VA.fit_scale("torch", 1.6)
	for i in 9:
		var x := -12.0 + i * 3.0
		xs.append(_xf(Vector3(x, -VA.aabb("stone_pillar").position.y * ps, -8.0), 0.0, ps))
		bx.append(_xf(Vector3(x + 1.5, -VA.aabb("banner").position.y * bs, -8.2), 0.0, bs))
		if i % 2 == 0:
			tx.append(_xf(Vector3(x, -VA.aabb("torch").position.y * ts, -6.8), 0.0, ts))
			var l := OmniLight3D.new()
			l.light_color = Color("#ffb060")
			l.light_energy = 0.9
			l.omni_range = 4.0
			l.position = Vector3(x, 1.8, -6.6)
			add_child(l)
	_multimesh(VA.mesh("stone_pillar"), xs)
	_multimesh(VA.mesh("banner"), bx)
	_multimesh(VA.mesh("torch"), tx)
	var k := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(40, 2.2, 1.2)
	k.mesh = bm
	k.material_override = VT.material("brick")
	k.position = Vector3(0, 1.1, -9.5)
	add_child(k)


func _indoor_scenery(rng: RandomNumberGenerator) -> void:
	var map_id: String = cfg.get("map", "")
	var glow := Color("#b090ff")
	if map_id.contains("#"):
		var m: Dictionary = {}
		if is_instance_valid(GameState.main) and GameState.main.world != null:
			m = GameState.main.world.map
		var b: Dictionary = m.get("building", {})
		if b.has("glow"):
			glow = Color(b["glow"])
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(44, 7, 1)
	wall.mesh = bm
	wall.material_override = VT.material("stone_dark")
	wall.position = Vector3(0, 3.5, -9.5)
	add_child(wall)
	var px := []
	var ps := VA.fit_scale("stone_pillar_dark", 5.0)
	for i in 7:
		px.append(_xf(Vector3(-13.5 + i * 4.5, -VA.aabb("stone_pillar_dark").position.y * ps, -8.2), 0.0, ps))
		var l := OmniLight3D.new()
		l.light_color = glow
		l.light_energy = 1.1
		l.omni_range = 5.0
		l.position = Vector3(-11.25 + i * 4.5, 2.4, -7.6)
		add_child(l)
	_multimesh(VA.mesh("stone_pillar_dark"), px)
	var fill := OmniLight3D.new()
	fill.light_color = glow.lerp(Color.WHITE, 0.6)
	fill.light_energy = 1.4
	fill.omni_range = 14.0
	fill.position = Vector3(0, 5, 3)
	add_child(fill)


func _build_trainers() -> void:
	player_rig = VPer.build(GameState.hero_look())
	player_rig.position = PLAYER_POS + Vector3(0, 0.1, 0)
	# your back to the camera, facing the foe
	VPer.face(player_rig, Vector2i(0, 1))
	var f := _toward("ally")
	player_rig.rotation.y = atan2(f.x, f.z)
	add_child(player_rig)
	shield_label = Label3D.new()
	shield_label.font_size = 52
	shield_label.outline_size = 10
	shield_label.pixel_size = 0.008
	shield_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shield_label.modulate = Color("#7af0ff")
	shield_label.position = PLAYER_POS + Vector3(0, 2.25, 0)
	add_child(shield_label)
	shield_bubble = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.95
	sp.height = 1.9
	sp.radial_segments = 12
	sp.rings = 6
	shield_bubble.mesh = sp
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.95, 1.0, 0.0)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_bubble.material_override = bm
	shield_bubble.position = PLAYER_POS + Vector3(0, 0.9, 0)
	add_child(shield_bubble)
	_update_shield()
	if wild:
		return
	var look: Dictionary = trainer.get("look", {})
	var g := _toward("foe")
	if String(trainer.get("robot_body", "")) != "":
		rival_rig = Node3D.new()
		rival_rig.add_child(VA.instance(String(trainer["robot_body"]), 1.9))
		rival_rig.rotation.y = atan2(-g.x, -g.z)
	elif not look.is_empty():
		rival_rig = VPer.build(look)
		VPer.face(rival_rig, Vector2i(0, 1))
		rival_rig.rotation.y = atan2(g.x, g.z) - 0.25
	if rival_rig:
		rival_rig.position = RIVAL_POS + Vector3(0, 0.1, 0)
		add_child(rival_rig)
	# the rival's shield: pips above their head and a bubble that flashes when it takes a hit
	rival_shield_label = Label3D.new()
	rival_shield_label.font_size = 52
	rival_shield_label.outline_size = 10
	rival_shield_label.pixel_size = 0.008
	rival_shield_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rival_shield_label.modulate = Color("#ffc890")
	rival_shield_label.position = RIVAL_POS + Vector3(0, 2.3, 0)
	add_child(rival_shield_label)
	rival_bubble = MeshInstance3D.new()
	rival_bubble.mesh = shield_bubble.mesh
	var rbm: StandardMaterial3D = (shield_bubble.material_override as StandardMaterial3D).duplicate()
	rbm.albedo_color = Color(1.0, 0.75, 0.45, 0.0)
	rival_bubble.material_override = rbm
	rival_bubble.position = RIVAL_POS + Vector3(0, 0.9, 0)
	add_child(rival_bubble)


func _update_shield() -> void:
	if ally_grid != null:
		ally_grid.shield = GameState.shield
		ally_grid.max_shield = GameState.max_shield
		ally_grid.queue_redraw()
	# your own shield points are under your bar (battle_bars.gd), not over your head as well
	if shield_label != null:
		shield_label.text = ""
	if rival_shield_label != null:
		rival_shield_label.text = "◆".repeat(foe_shield) + "◇".repeat(maxi(0, foe_max_shield - foe_shield)) if foe_max_shield > 0 else ""


func _process(delta: float) -> void:
	_time += delta
	if caption != null:
		caption.visible = msg_label.text != ""
	for b in nodes:
		var n: Node3D = nodes[b]
		if is_instance_valid(n) and n.has_meta("phase"):
			var m: Node3D = n.get_node_or_null("Model")
			if m:
				m.position.y = float(n.get_meta("lift")) + absf(sin(_time * 2.4 + float(n.get_meta("phase")))) * 0.05
	if is_instance_valid(player_rig):
		VPer.animate(player_rig, 0.0, 0.0)
	if is_instance_valid(rival_rig):
		VPer.animate(rival_rig, 0.0, 0.0)
	if is_instance_valid(cam):
		var cp := _cam_pos() + Vector3(sin(_time * 0.21) * 0.25, sin(_time * 0.17) * 0.06, 0)
		var cl := _cam_look()
		if summon_mix > 0.0:
			cp = cp.lerp(summon_pos, summon_mix)
			cl = cl.lerp(summon_look, summon_mix)
		if summon_shake_amt > 0.0:
			cp += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * summon_shake_amt * 0.35
			summon_shake_amt = maxf(0.0, summon_shake_amt - delta * 1.6)
		cam.position = cp
		cam.look_at(cl, Vector3.UP)
	_draw_arcs()


## Where someone (or somewhere) aimed at stands, on the ground: a beast, a trainer ("foe_trainer"; "trainer" or
## "trainer_self" for you), or a slot of your ring (an int: a Move's), or null.
func _ref_pos(ref):
	if ref == null:
		return null
	if typeof(ref) == TYPE_INT:
		return _slot_pos("ally", ref)
	if typeof(ref) == TYPE_STRING:
		return RIVAL_POS if ref == "foe_trainer" else (PLAYER_POS if ref in ["trainer", "trainer_self"] else null)
	if nodes.has(ref) and is_instance_valid(nodes[ref]):
		return (nodes[ref] as Node3D).position
	return null


func _ref_height(ref) -> float:
	if typeof(ref) == TYPE_INT:
		return 0.2
	if typeof(ref) == TYPE_STRING:
		return 1.65
	return float(nodes[ref].get_meta("height")) if nodes.has(ref) else 1.0


## The aiming arcs: from the beast (or you) choosing, a glowing arch over to each target ending in an arrowhead, with a
## white core and pulses running along it towards the target, over a dark edge so it reads against bright ground.
func _draw_arcs() -> void:
	var im := aim_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	var a = _ref_pos(_aim_from)
	if a == null or _target_refs.is_empty() or cam == null:
		return
	var view := cam.global_transform.basis.z
	var glow := Color.from_hsv(UIKit.ACCENT.h, UIKit.ACCENT.s * 0.6, 1.0)
	var from: Vector3 = a + Vector3.UP * _ref_height(_aim_from) * 0.75
	var began := false
	for t in _target_refs:
		var b = _ref_pos(t)
		if b == null:
			continue
		var to: Vector3 = b + Vector3.UP * _ref_height(t) * 0.6
		var top := (from + to) / 2.0 + Vector3.UP * (1.2 + from.distance_to(to) * 0.22)
		if not began:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			began = true
		_arc_strip(im, from, top, to, 0.52, Color(0, 0, 0, 0.55), false, view)
		_arc_strip(im, from, top, to, 0.34, glow, true, view)
		_arc_strip(im, from, top, to, 0.1, Color(1, 1, 1, 0.9), true, view)
	if began:
		im.surface_end()


## One arc as a ribbon facing the camera along the curve from p0 over c to p2 (stopping short for its arrowhead).
func _arc_strip(im: ImmediateMesh, p0: Vector3, c: Vector3, p2: Vector3, w: float, col: Color, pulse: bool, view: Vector3) -> void:
	const N := 32
	const HEAD := 0.86
	var pts := []
	for i in N + 1:
		var u := HEAD * float(i) / N
		pts.append(p0 * (1.0 - u) * (1.0 - u) + c * 2.0 * (1.0 - u) * u + p2 * u * u)
	for i in N:
		var d: Vector3 = pts[i + 1] - pts[i]
		var side := d.cross(view).normalized() * w * 0.5
		var cc := col
		if pulse:
			# brighter pulses running from the beast to its target
			var wave := fposmod(float(i) / N * 2.5 - _time * 1.6, 1.0)
			cc.a = col.a * (0.82 + 0.18 * pow(wave, 3.0))
			cc = cc.lerp(Color(1, 1, 1, cc.a), 0.55 * pow(wave, 6.0))
		var q := [pts[i] - side, pts[i] + side, pts[i + 1] + side, pts[i + 1] - side]
		for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			im.surface_set_color(cc)
			im.surface_add_vertex(v)
	var base: Vector3 = pts[N]
	var side2 := (p2 - base).cross(view).normalized() * w * 2.0
	for v in [base - side2, base + side2, p2]:
		im.surface_set_color(Color(col, 1.0) if pulse else col)
		im.surface_add_vertex(v)


## Aim the arch from the acting beast or trainer to the selected target(s).
func _show_targets(list: Array, sel: int, source = "trainer_self") -> void:
	_aim_from = source
	_target_refs = []
	for i in list.size():
		if sel < 0 or i == sel:
			var t = list[i]
			_target_refs.append(t["ref"] if typeof(t) == TYPE_DICTIONARY else t)


func _hide_targets() -> void:
	_target_refs = []
	_aim_from = null


## Shows a beast: on its pad (slot = its ring slot) for a trainer's ring, or in the wild line (slot = 0..2).
func _spawn(b, side: String, slot: int) -> void:
	var root := Node3D.new()
	var holder := Node3D.new()
	holder.name = "Model"
	root.add_child(holder)
	var lift := 0.16
	var big := 1.0
	if b == guardian_b:
		# a temple guardian towers over its helpers, and the winged ones hover
		big = 1.7
		if guardian_tk in ["water", "air", "fire"]:
			lift = 0.7
	holder.position.y = lift
	root.rotation.y = _beast_yaw(side)
	var ringed: bool = side == "ally" or not wild
	root.position = _slot_pos(side, slot) if ringed else _wild_pos(slot)
	root.set_meta("slot", slot)
	root.set_meta("lift", lift)
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color(1, 1, 1, 0)
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	root.set_meta("flash", flash)
	_build_model(root, b)
	add_child(root)
	nodes[b] = root
	root.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * (1.15 if ringed else 1.25) * big, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var s := _st(b)
	s["side"] = side
	s["down"] = b.hp <= 0
	if b.hp <= 0:
		# already down when the battle began: lying on its pad
		_lie_down(b, false)
	if side == "foe":
		GameState.mark_seen(b)
	else:
		participants[b] = true


## Builds a beast's model in its node's holder ("Model"), in place of any it had: the new beasts animated (beast_rig.gd:
## bobbing and blinking on their own; meta "rig"), the legendaries' PSX models and the robots bobbing in _process
## (meta "phase"). Every piece but a ghost's smoke takes the node's flash overlay (_hit_fx, and dimming the beasts not
## aimed at).
func _build_model(root: Node3D, b) -> void:
	var holder: Node3D = root.get_node("Model")
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	holder.position = Vector3(0, float(root.get_meta("lift")), 0)
	var model: Node3D = BeastModel.rig(b.genes)
	var height := 1.2
	if model != null:
		height = BeastModel.height(model)
		root.set_meta("rig", model)
		root.remove_meta("phase")
	else:
		if b.genes.has("model"):
			# a robot (assets/robots): faces +x like the beasts
			model = VA.instance(String(b.genes["model"]), 1.3 * float(b.genes.get("size", 1.0)))
			height = 1.3 * float(b.genes.get("size", 1.0))
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = VB.mesh(b.genes)
			model = mi
			height = mi.mesh.get_aabb().end.y
		root.remove_meta("rig")
		root.set_meta("phase", randf() * TAU)
	holder.add_child(model)
	root.set_meta("height", height + float(root.get_meta("lift")))
	for gi in holder.find_children("*", "GeometryInstance3D", true, false):
		if not gi is CPUParticles3D:
			gi.material_overlay = root.get_meta("flash")


## A beast's rig on the field, or null (not on it, or drawn the old way).
func _rig(b) -> Node3D:
	if not nodes.has(b) or not is_instance_valid(nodes[b]) or not nodes[b].has_meta("rig"):
		return null
	var r = nodes[b].get_meta("rig")
	return r if is_instance_valid(r) else null


## A beast that grew into its next form mid-battle (an "evolve" event of Beast.gain_xp) takes on its new model, in a
## flash of light.
func _remodel(b) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	_build_model(n, b)
	var flash: StandardMaterial3D = n.get_meta("flash")
	flash.albedo_color = Color(1, 1, 1, 0.9)
	var tw := create_tween()
	tw.tween_property(flash, "albedo_color", Color(1, 1, 1, 0.0), 0.5)
	var sc := n.scale
	var tw2 := create_tween()
	tw2.tween_property(n, "scale", sc * 1.2, 0.12).set_ease(Tween.EASE_OUT)
	tw2.tween_property(n, "scale", sc, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A fainted beast on its pad: a new beast lies down to rest (beast_rig.gd), an old model keels over on its side
## (eased, or there at once).
func _lie_down(b, ease := true) -> void:
	var rig := _rig(b)
	if rig != null:
		rig.state = "lie"
		if not ease:
			rig.settle()
		return
	var n: Node3D = nodes[b]
	if not ease:
		n.rotation.z = -1.4
		n.position.y = -0.3
		return
	var tw := create_tween()
	tw.tween_property(n, "rotation:z", -1.4, 0.35)
	tw.parallel().tween_property(n, "position:y", -0.3, 0.5)
	tw.parallel().tween_property(n, "scale", Vector3(0.6, 0.6, 0.6), 0.5)


func _despawn(b) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	nodes.erase(b)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(0.1, 0.1, 0.1), 0.2)
	tw.tween_callback(n.queue_free)


func _st(b) -> Dictionary:
	if not st.has(b):
		st[b] = {
			"stages": {"atk": 0, "def": 0, "spr": 0, "spd": 0, "eva": 0, "acc": 0},
			"shield": 0, "taunt": 0, "regen": 0, "counter": 0, "vanish": false, "wraith": 0,
			"cd": {}, "sturdy": false, "phoenix": false, "side": "ally", "down": false, "defend": false,
		}
	return st[b]


# ================================================================ HUD
## The HUD is kept to what JC2 shows: the foe's grid at the top left, your grid at the bottom right with the move bars
## beside it, and one slim line of battle text at the top.
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.hud.add_child(hud)
	var touch: bool = UI.is_touch()
	# big enough to read across a phone held at arm's length
	var k := 1.5 if touch else 1.4
	# the foe's grid, top left (a wild pack: a line of three)
	foe_grid = RingGrid.new("foe", wild, k * 0.9)
	foe_grid.show_shield = not wild
	foe_grid.position = Vector2(12, 8)
	hud.add_child(foe_grid)
	# your bars and grid, bottom right (on a phone, over START and PAUSE)
	cmd_root = Control.new()
	cmd_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cmd_root)
	bars = BattleBars.new(k)
	cmd_root.add_child(bars)
	ally_grid = RingGrid.new("ally", false, k)
	# (your shield points show under your own bar instead: battle_bars.gd)
	ally_grid.show_shield = false
	cmd_root.add_child(ally_grid)
	cmd_root.move_child(bars, -1) # bars draw and receive taps above the faded front column
	# the trainers in the middle of their grids, locking eyes across the screen: you from behind, looking up and left
	# to the foe's grid; the rival from the front, looking down and right to yours
	ally_grid.trainer_icon = _person_icon(GameState.hero_look(), PI + 0.5)
	if not wild and not (trainer.get("look", {}) as Dictionary).is_empty():
		foe_grid.trainer_icon = _person_icon(trainer["look"], 0.5)
	_speaker_icons["trainer_self"] = _person_icon(GameState.hero_look(), 0.5)
	_speaker_icons["foe_trainer"] = foe_grid.trainer_icon if foe_grid.trainer_icon != null else _person_icon(trainer.get("look", {}), 0.5)
	var gap := 8.0 * k
	bars.position = Vector2.ZERO
	bars.size = bars.custom_minimum_size
	ally_grid.position = Vector2(bars.size.x + gap - 4.0 * k - 2.0 * ally_grid.slant, bars.pitch_y + bars.pill_h * 0.5 - ally_grid.top_pad())
	ally_grid.size = ally_grid.custom_minimum_size
	var block := Vector2(ally_grid.position.x + ally_grid.size.x, maxf(bars.size.y, ally_grid.position.y + ally_grid.size.y))
	cmd_root.size = block
	if touch:
		# phones: the bars and the grid stand centred just above START and PAUSE, clear of the d-pad and of A and B
		cmd_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		cmd_root.offset_left = -roundf(block.x / 2.0)
		cmd_root.offset_right = cmd_root.offset_left + block.x
		cmd_root.offset_top = -78.0 - block.y
		cmd_root.offset_bottom = cmd_root.offset_top + block.y
	else:
		cmd_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cmd_root.offset_left = -16.0 - block.x
		cmd_root.offset_right = -16.0
		cmd_root.offset_top = -10.0 - block.y
		cmd_root.offset_bottom = -10.0
	# Both top windows use the same compact frame and padding.
	caption = _top_panel()
	hud.add_child(caption)
	message_line = HBoxContainer.new()
	message_line.add_theme_constant_override("separation", 8)
	caption.add_child(message_line)
	message_icon = TextureRect.new()
	message_icon.custom_minimum_size = Vector2(40, 48)
	message_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	message_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	message_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	message_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_line.add_child(message_icon)
	msg_label = UIKit.label("", UIKit.BODY_HUGE, UIKit.INK)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_line.add_child(msg_label)
	move_info = _top_panel()
	hud.add_child(move_info)
	_place_caption()


func _top_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.chip(Color(UIKit.WINDOW_TOP, 0.94), UIKit.BORDER, 14.0, Vector4(12, 8, 12, 8), 3.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	return panel


## Centre on the whole screen, leaving equal space for the foe's grid on either side.
func _top_width() -> float:
	var edge := foe_grid.position.x + foe_grid.size.x + 12.0
	return minf(640.0, hud.get_viewport_rect().size.x - 2.0 * edge)


func _center_top(panel: Control) -> void:
	panel.reset_size()
	panel.position = Vector2(roundf((hud.get_viewport_rect().size.x - panel.size.x) * 0.5), 10.0)


## Fit the battle message to its words and avatar, with the same inset as the move window.
func _place_caption() -> void:
	if caption == null:
		return
	var icon_w := 48.0 if message_icon.visible else 0.0
	var font := UIKit.font_body()
	var fs := UIKit.body_px(UIKit.BODY_HUGE)
	var w := minf(_top_width() - 24.0 - icon_w, font.get_string_size(msg_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	msg_label.custom_minimum_size = Vector2(maxf(1.0, ceilf(w)), 0)
	caption.visible = msg_label.text != ""
	_center_top(caption)
	if move_info != null and move_info.visible:
		_center_top(move_info)


## Resolve named subjects first, then the current actor for short messages such as critical hits or misses.
func _message_ref(text: String):
	var ref = "trainer_self" if text.begins_with("You ") or text.begins_with("Your ") else _message_subject
	var first := text.length()
	var names := {"trainer_self": GameState.player_name}
	if not wild:
		names["foe_trainer"] = String(trainer.get("name", "Trainer"))
	for b in GameState.party + foes + ally_ring.values() + foe_ring.values():
		if b == null:
			continue
		names[b] = b.nickname
	for who in names:
		var name := String(names[who])
		var at := text.findn(name) if name != "" else -1
		if at >= 0 and at < first:
			first = at
			ref = who
	return ref


func _caption(text: String, subject = null) -> void:
	if msg_label == null:
		return
	_info_hint = text
	if _commanding and move_info != null and move_info.visible:
		var foot := move_info.find_child("Foot", true, false) as Label
		if foot != null:
			foot.text = text
			foot.visible = text != ""
		text = ""
	msg_label.text = text
	var ref = subject if subject != null else _message_ref(text)
	message_icon.texture = _speaker_icons.get(ref, null) if typeof(ref) == TYPE_STRING else (PixelArt.beast_texture(ref.genes) if ref != null else null)
	var player_subject: bool = ref in ["trainer_self", "trainer"] if typeof(ref) == TYPE_STRING else (ref != null and (GameState.party.has(ref) or ally_ring.values().has(ref)))
	message_line.move_child(message_icon, -1 if player_subject else 0)
	message_icon.visible = text != "" and message_icon.texture != null
	_place_caption()
	# Wrapped labels update their minimum height after layout; shrink again once that has settled.
	if not get_tree().process_frame.is_connected(_settle_top):
		get_tree().process_frame.connect(_settle_top, CONNECT_ONE_SHOT)


## What each kind of move is called in the move window.
const KIND_NAMES := {"attack": "Attack", "buff": "Boost", "debuff": "Weaken", "heal": "Heal", "revive": "Revive",
	"cleanse": "Cleanse", "shield": "Shield", "status": "Status", "taunt": "Taunt", "special": "Special"}
const TARGET_NAMES := {"enemy": "one foe", "enemies": "all foes", "ally": "one ally", "allies": "all allies",
	"self": "itself", "ally_ko": "a fainted ally", "none": ""}


## The window at the top while you choose: the highlighted move's name, element and kind, who it reaches, its MP cost
## (against the beast's MP), power and accuracy, what it does, and any warning (recharging, short of MP, a lesson);
## for your own actions and Defend, just what they do. Empty: hides it.
func _show_option(row: Dictionary, o: Dictionary) -> void:
	if move_info == null:
		return
	for c in move_info.get_children():
		move_info.remove_child(c)
		c.queue_free()
	var status_desc := String(row.get("status_desc", "")) if row.get("status", "") != "" else ""
	if o.is_empty() or (String(o.get("label", "")) == "" and status_desc == ""):
		move_info.visible = false
		_place_caption()
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	move_info.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var content_w := _top_width() - 24.0
	var facts_row := HBoxContainer.new()
	facts_row.add_theme_constant_override("separation", 8)
	vb.add_child(facts_row)
	var b = row.get("beast", null)
	var title := String(o.get("label", ""))
	var desc := String(o.get("desc", ""))
	var note := String(o.get("note", ""))
	if status_desc != "":
		title = String(row.get("name", ""))
		desc = status_desc
	top.add_child(UIKit.header(title, UIKit.LIGHT, UIKit.HEAD_BIG))
	if o.has("move"):
		var mv := String(o["move"])
		var m := MoveDB.get_move(mv)
		top.add_child(_info_tag(UIKit.element_tag(String(m["el"]), 18)))
		var kind := String(KIND_NAMES.get(String(m.get("kind", "")), String(m.get("kind", "")).capitalize()))
		var reach := String(TARGET_NAMES.get(String(m.get("target", "enemy")), ""))
		facts_row.add_child(_info_tag(UIKit.label(kind + (" · " + reach if reach != "" else ""), UIKit.BODY_BIG, UIKit.GOLD_BRIGHT)))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts_row.add_child(gap)
		var cost := MoveDB.mp_cost(mv)
		var mp_text := "No MP"
		if cost > 0:
			mp_text = "MP %d" % cost + (" (has %d)" % b.mp if b != null else "")
		var short: bool = b != null and b.mp < cost
		facts_row.add_child(_info_tag(UIKit.label(mp_text, UIKit.BODY_BIG, UIKit.ACCENT.lightened(0.35) if short else UIKit.INK)))
		var facts := []
		if m.has("power"):
			facts.append("Power %d" % m["power"])
		if m.has("acc"):
			facts.append("Accuracy %d" % m["acc"])
		if int(m.get("cd", 0)) > 0:
			facts.append("Rests %d turn%s after use" % [m["cd"], "" if int(m["cd"]) == 1 else "s"])
		if not facts.is_empty():
			vb.add_child(UIKit.label("   ".join(facts), UIKit.BODY_BIG, UIKit.DIM))
		desc = String(m.get("desc", ""))
	elif o.get("id", "") == "defend":
		top.add_child(_info_tag(UIKit.label("Guard · itself", UIKit.BODY_BIG, UIKit.GOLD_BRIGHT)))
		if b != null:
			desc = "Brace for impact: %s takes half damage until your side's next turn." % b.nickname
	elif row.get("kind", "") == "trainer" and status_desc == "":
		top.add_child(_info_tag(UIKit.label("Your action", UIKit.BODY_BIG, UIKit.GOLD_BRIGHT)))
	var d := UIKit.label(desc, UIKit.BODY_HUGE, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_constant_override("line_spacing", -10)
	d.custom_minimum_size.x = content_w
	vb.add_child(d)
	if note != "":
		var nl := UIKit.label(note, UIKit.BODY_BIG, UIKit.GOLD_BRIGHT)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = content_w
		vb.add_child(nl)
	var foot := UIKit.label(_info_hint, UIKit.BODY_BIG, UIKit.DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size.x = content_w
	foot.name = "Foot"
	foot.visible = _info_hint != ""
	vb.add_child(foot)
	move_info.visible = true
	_center_top(move_info)
	if not get_tree().process_frame.is_connected(_settle_top):
		get_tree().process_frame.connect(_settle_top, CONNECT_ONE_SHOT)
	msg_label.text = ""
	_place_caption()


## The move window shrunk to its laid-out words, and the things under it placed again (a frame after it changes).
func _settle_top() -> void:
	if move_info != null and move_info.visible:
		move_info.reset_size()
	_place_caption()


## A small full-length picture of a person for the middle of a ring grid, turned `yaw` from facing the viewer
## (positive: towards the right of the screen; PI: their back): rendered off screen for a moment, then kept as it is.
func _person_icon(look: Dictionary, yaw: float) -> Texture2D:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(132, 176)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.25
	vp.add_child(sun)
	var rig := VPer.build(look)
	VPer.face(rig, Vector2i(0, 1))
	rig.rotation.y = yaw
	vp.add_child(rig)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VPer.height() * 1.12
	var at := Vector3(0, 1.6, 5.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, VPer.height() * 0.52, 0) - at, Vector3.UP), at)
	vp.add_child(cam)
	cam.current = true
	# a picture, not a scene: stop drawing it once it's had a moment to render
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


## A tag in the move window, centred on its line.
func _info_tag(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _refresh() -> void:
	if ally_grid != null:
		ally_grid.set_ring(ally_ring, ally_side)
		ally_grid.open = _side_open("ally")
	if foe_grid != null:
		if wild:
			foe_grid.set_line(foe_slots)
		else:
			foe_grid.set_ring(foe_ring, foe_side)
			foe_grid.shield = foe_shield
			foe_grid.max_shield = foe_max_shield
			foe_grid.open = _side_open("foe")
	if bars != null and not _commanding:
		bars.set_rows(_idle_rows(), -1)
	_update_shield()


## The bars out of the command phase: the names of the beasts facing the foe (and yours, which only shows while you
## choose your action).
func _idle_rows() -> Array:
	var out := [{"kind": "trainer", "lv": GameState.trainer_level, "text": GameState.player_name, "shield": GameState.shield, "max_shield": GameState.max_shield}]
	for b in ally_slots:
		out.append(_beast_bar(b, "" if b == null else b.nickname))
	return out


func _beast_bar(b, text: String) -> Dictionary:
	if b == null:
		return {"kind": "beast", "status": "empty", "text": "—"}
	return {"kind": "beast", "lv": b.level, "text": text if b.hp > 0 else "Fainted", "status": "" if b.hp > 0 else "down",
		"hp": maxi(0, b.hp), "max_hp": b.max_hp(), "mp": b.mp, "max_mp": b.max_mp()}


## How many of a bar's options ◄ ► move between (in a lesson, only the ones that can be picked: see command_panel.gd).
func _choices(opts: Array) -> int:
	return opts.filter(func(o): return not o.get("disabled", false)).size() if tutorial else opts.size()


## The command panel's view of its rows: the bars, the chosen beast's tile and the target being aimed at.
func _render_rows(rows: Array, focus: int, picking: bool) -> void:
	var out := []
	for i in rows.size():
		var r: Dictionary = rows[i]
		var opts: Array = r.get("options", [])
		var o: Dictionary = opts[clampi(int(r.get("sel", 0)), 0, opts.size() - 1)] if not opts.is_empty() else {}
		var text := String(o.get("label", ""))
		if r.has("act"):
			var act: Dictionary = r["act"]
			if act.get("type", "") == "item":
				text = ItemDB.item_name(String(act["item"]))
		var targets: Array = r.get("targets", [])
		if (picking and i == focus) or (r.get("done", false) and not targets.is_empty()):
			var t: Dictionary = targets[clampi(int(r.get("target_sel", 0)), 0, targets.size() - 1)] if not targets.is_empty() else {}
			if r.get("target_all", false):
				text += " → all"
			elif not t.is_empty():
				text += " → " + String(t["label"])
		if r["kind"] == "trainer":
			out.append({"kind": "trainer", "lv": GameState.trainer_level, "text": text, "arrows": not r.get("locked", false) and _choices(opts) > 1 and not picking,
				"done": r.get("done", false), "disabled": o.get("disabled", false), "shield": GameState.shield, "max_shield": GameState.max_shield})
			continue
		var bb = r.get("beast", null)
		var row := _beast_bar(bb, text)
		if row.get("status", "") == "":
			row["arrows"] = _choices(opts) > 1 and not picking
			row["done"] = r.get("done", false)
			row["disabled"] = o.get("disabled", false)
			row["cost"] = MoveDB.mp_cost(String(o["move"])) if o.has("move") else 0
		out.append(row)
	bars.set_rows(out, focus)
	var fr: Dictionary = rows[focus]
	# your own turn lights your centre cell, a beast's its tile
	ally_grid.focus = -2 if fr["kind"] == "trainer" else -1
	if fr["kind"] == "beast" and focus >= 1:
		ally_grid.focus = Ring.side_slots(ally_side)[focus - 1]
	ally_grid.target = -1
	foe_grid.target = -1
	ally_grid.targets = []
	foe_grid.targets = []
	if picking:
		var ts: Array = fr.get("targets", [])
		if not ts.is_empty():
			var all: bool = fr.get("target_all", false)
			var sel := -1 if all else clampi(int(fr.get("target_sel", 0)), 0, ts.size() - 1)
			_show_targets(ts, sel, fr.get("beast", null) if fr["kind"] == "beast" else "trainer_self")
	else:
		_hide_targets()
	ally_grid.queue_redraw()
	foe_grid.queue_redraw()


func msg(text: String, wait := 0.95, subject = null) -> void:
	_caption(text, subject)
	if OS.has_feature("editor") and GameState.main != null and "--battle-log" in OS.get_cmdline_user_args():
		print("  | ", text)
	var t := 0.0
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.12 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact")):
			break


# ================================================================ main loop
func _run() -> void:
	await get_tree().process_frame
	# your ring, turned to the side you last fought with if the beast in its middle is standing, else round to the
	# nearest side whose middle beast is (see Ring.covered_side)
	GameState.fix_ring()
	ally_ring = GameState.ring()
	ally_side = Ring.covered_side(ally_ring, GameState.ring_side)
	if tutorial and lesson.get("practice", false):
		_practice_beasts()
	if not wild:
		var placed := Ring.arrange(foes)
		for k in placed:
			if int(k) >= 0:
				foe_ring[k] = placed[k]
		foe_side = maxi(0, Ring.best_side(foe_ring))
		foe_max_shield = _trainer_shield()
		foe_shield = foe_max_shield
	for team in ring_root:
		ring_psi[team] = _psi_for(team, ally_side if team == "ally" else foe_side)
		_light_pads(team)
	_sync_slots()
	if wild:
		for i in mini(3, foes.size()):
			foe_slots[i] = foes[i]
			_spawn(foes[i], "foe", i)
	else:
		for k in foe_ring:
			_spawn(foe_ring[k], "foe", k)
		_place_ring("foe")
	_refresh()
	if guardian_tk != "":
		Sfx.play("growl")
		await msg("%s, guardian of the %s, rises to test you!" % [guardian_b.nickname, String(WorldDB.TEMPLES[guardian_tk]["name"])], 1.2)
		await msg("It can't be beaten, only won over: wear it down, then play the %s to it!" % SongDB.song_name(_guardian_song()), 1.4)
	elif wild:
		var names := []
		for f in foes:
			names.append(f.nickname)
		if foes.size() == 1:
			await msg("A wild %s (Lv %d) appeared!" % [foes[0].nickname, foes[0].level])
		else:
			await msg("Wild beasts appeared: %s!" % ", ".join(names))
		for f in foes:
			if f.abandoned:
				await msg("%s looks lonely... It seems to have been abandoned by its trainer." % f.nickname, 1.4)
		match String(cfg.get("ambush", "")):
			"player":
				await msg("You caught it off guard! It can't act this round.", 1.1)
			"foe":
				await msg("It snuck up on you! You can't act this round!", 1.1)
	elif trainer.get("guardian", false):
		Sfx.play("growl")
		await msg("The guardian %s rises, flanked by its temple's beasts!" % trainer.get("name", ""))
	else:
		if is_boss():
			Sfx.play("stinger")
		await msg("%s %s wants to battle!" % [trainer.get("cls", "Trainer"), trainer.get("name", "")])
		var names2 := []
		for b in _alive(foe_slots):
			names2.append(b.nickname)
		await msg("%s faces you with the %s side of their ring: %s!" % [trainer.get("name", "The trainer"), Ring.side_element(foe_side).capitalize(), ", ".join(names2)])
		if foe_max_shield > 0:
			await msg("%s's shield holds %d point%s." % [trainer.get("name", "The trainer"), foe_max_shield, "" if foe_max_shield == 1 else "s"], 0.8)
	var go := []
	for k in ally_ring:
		_spawn(ally_ring[k], "ally", k)
	_place_ring("ally")
	for b in _alive(ally_slots):
		go.append(b.nickname)
	_refresh()
	if ally_side != GameState.ring_side and not tutorial:
		await msg("Nobody stands in the middle of your %s side, so you turn your ring round." % Ring.side_element(GameState.ring_side).capitalize(), 1.0)
	if not go.is_empty():
		await msg("Your %s side faces the foe. Go, %s!" % [Ring.side_element(ally_side).capitalize(), ", ".join(go)], 0.9)
	await _start_passives()
	_check_end()
	await _check_exposed()
	if tutorial:
		if lesson.has("narration"):
			await UI.say([_tut_fill(lesson["narration"])])
		await _tut_say(lesson.get("intro", []))
	while result == "":
		round_no += 1
		for b in ally_slots:
			if b != null:
				participants[b] = true
		var acts: Array = []
		var ambush: String = String(cfg.get("ambush", "")) if round_no == 1 else ""
		if ambush == "foe":
			await msg("You're still reeling from the ambush!", 0.8)
		else:
			acts = await _command_phase()
		if result != "":
			break
		# then the two sides take their turns, the faster one first (its beasts' speed, and its trainer's level);
		# the foe's choices are only made, and seen, when its turn comes
		var first := _who_first()
		if not tutorial and ambush == "":
			var who := "You move" if first == "ally" else ("The wild beasts move" if wild else "%s moves" % trainer.get("name", "The trainer"))
			await msg("%s first!" % who, 0.6)
		for team in [first, "foe" if first == "ally" else "ally"]:
			if result != "":
				break
			_end_defend(team)
			if team == "ally":
				if ambush != "foe":
					await _resolve(acts)
			elif ambush != "player":
				await _resolve(await _ai_actions())
		if result != "":
			break
		await _end_round()
		if result != "":
			break
		await _refill()
		_check_end()
		await _check_exposed()
		_refresh()
	await _finish()
	finished.emit(result)


## Which side takes its turn first this round: the one whose beasts facing the foe are faster, helped by its
## trainer's level (a wild pack has none). A lesson lets you go first.
func _who_first() -> String:
	if tutorial:
		return "ally"
	return "ally" if _initiative("ally") >= _initiative("foe") else "foe"


func _initiative(team: String) -> float:
	var alive := _alive(ally_slots if team == "ally" else foe_slots)
	var spd := 0.0
	for b in alive:
		spd += _eff_stat(b, "spd")
	spd = spd / alive.size() if not alive.is_empty() else 10.0
	var lv := 0.0
	if team == "ally":
		lv = GameState.trainer_level
	elif not wild:
		lv = _foe_trainer_level()
	return spd * (1.0 + 0.08 * lv) * randf_range(0.9, 1.1)


## A rival's trainer level: given by the battle (the arena ladder's rank), or judged from their beasts.
func _foe_trainer_level() -> int:
	if trainer.has("level"):
		return int(trainer["level"])
	var sum := 0
	for f in foes:
		sum += int(f.level)
	return clampi(sum / maxi(1, foes.size()) / 4 + 1, 1, GameState.TRAINER_LEVEL_MAX)


## A side's Defend lasts until that side's next turn.
func _end_defend(team: String) -> void:
	for b in st:
		if String(st[b]["side"]) == team:
			st[b]["defend"] = false


# ================================================================ tutorial
## Who is teaching: the lesson's coach, else the trainer.
func _tut_who() -> String:
	return String(lesson.get("coach", ("%s %s" % [trainer.get("cls", ""), trainer.get("name", "")]).strip_edges()))


func _tut_say(lines: Array) -> void:
	if not lines.is_empty():
		await UI.say(lines.map(func(l): return _tut_fill(String(l))), _tut_who())


## A lesson line with {beast} (your beast) and {foe} (theirs) filled in.
func _tut_fill(line: String) -> String:
	var b = _alive(ally_slots)[0] if not _alive(ally_slots).is_empty() else null
	var f = _alive(foe_slots)[0] if not _alive(foe_slots).is_empty() else (foes[0] if not foes.is_empty() else null)
	return line.replace("{beast}", b.nickname if b != null else "your beast").replace("{foe}", f.nickname if f != null else "beast")


## This round of the lesson (the last one repeats).
func _tut_round() -> Dictionary:
	var rounds: Array = lesson.get("rounds", [])
	if rounds.is_empty():
		return {}
	return rounds[clampi(round_no, 1, rounds.size()) - 1]


## What you, and your beast, may do this round of the lesson.
func _tut_you() -> String:
	return String(_tut_round().get("you", "Watch"))


func _tut_beast() -> String:
	return String(_tut_round().get("beast", "Fight"))


## Whether the foe's beast goes down this round of the lesson.
func _tut_finish() -> bool:
	var f := int(lesson.get("finish", 0))
	return f > 0 and round_no >= f


## The attack the tutorial teaches, of those the beast can use right now (with the MP for it, and not recharging): its
## own-element attack if it has one, else its first attack. So there's always one to pick: a plain attack is free.
func _tut_move(b) -> String:
	var first := ""
	for mv in _usable_moves(b):
		var m := MoveDB.get_move(mv)
		if m["kind"] == "attack" and m["target"] == "enemy" and int(_st(b)["cd"].get(mv, 0)) <= 0 and MoveDB.mp_cost(mv) <= b.mp:
			if first == "":
				first = mv
			if m["el"] == b.element:
				return mv
	return first if first != "" else "tackle"


func _tut_round_intro() -> void:
	var rounds: Array = lesson.get("rounds", [])
	# the last round's words aren't said again while it repeats, except a capture to try again
	if round_no <= rounds.size() or _tut_you() == "Flute":
		await _tut_say(_tut_round().get("say", []))


## How much of `d` damage `b` takes from recoil, confusion or a status: in a lesson your side's beasts always keep at
## least 1 HP (the foes' blows are kept small already, see _tut_damage).
func _spare(b, d: int) -> int:
	return clampi(d, 0, maxi(0, b.hp - 1)) if tutorial and _st(b)["side"] == "ally" else d


func _tut_damage(a, t) -> int:
	if _st(t)["side"] == "ally":
		return clampi(2, 0, maxi(0, t.hp - 1))
	var mx: int = t.max_hp()
	if a == null:
		return mini(maxi(1, ceili(mx * 0.15)), maxi(0, t.hp - 1))
	if _tut_finish():
		return t.hp
	return mini(maxi(1, ceili(mx * 0.35)), maxi(0, t.hp - 1))


## The arena's practice beasts for a lesson: one of the side's element in each empty slot of the side facing the foe
## (a coach's "practice_side" turns your ring to that side first). They only stand in for the battle: never yours.
const PRACTICE_RACES := {"fire": 3, "water": 27, "earth": 15, "air": 36}


func _practice_beasts() -> void:
	if trainer.has("practice_side"):
		ally_side = Ring.side_index(String(trainer["practice_side"]))
	var el := Ring.side_element(ally_side)
	for k in Ring.side_slots(ally_side):
		if ally_ring.get(k, null) == null:
			var b := Beasts.create(int(PRACTICE_RACES[el]), maxi(2, GameState.best_level()))
			b.nickname = "Practice " + b.nickname
			ally_ring[k] = b


func _start_passives() -> void:
	for b in _all_active():
		var changes := {}
		if b.passives.has("Rooted"):
			changes["def"] = 1
		if b.passives.has("Swift"):
			changes["spd"] = 1
		if int(b.gear_fx("eva", 0)) > 0:
			changes["eva"] = int(b.gear_fx("eva", 0))
		if not changes.is_empty():
			await _buff(b, changes, true)


func _all_active() -> Array:
	var out := []
	for b in ally_slots + foe_slots:
		if b != null and b.hp > 0:
			out.append(b)
	return out


func _alive(slots: Array) -> Array:
	return slots.filter(func(b): return b != null and b.hp > 0)


func _active(b) -> bool:
	return ally_slots.has(b) or foe_slots.has(b)


func _mine(b) -> Array:
	return ally_slots if _st(b)["side"] == "ally" else foe_slots


func _theirs(b) -> Array:
	return foe_slots if _st(b)["side"] == "ally" else ally_slots


## Wild battles end when every wild beast is down (most lessons too). Trainer battles end only when a trainer is hit
## with no shield left (see _strike), or someone forfeits.
func _check_end() -> void:
	if result != "":
		return
	if wild or (tutorial and not lesson.get("trainer", false)):
		var left := foes.filter(func(f): return f.hp > 0)
		if left.is_empty():
			result = "win"


## Announces a trainer coming open to attack: the middle beast of the side facing the foe is down (or missing).
func _check_exposed() -> void:
	if result != "":
		return
	for team in ["ally", "foe"]:
		if team == "foe" and wild:
			continue
		var open := _side_open(team)
		if open and not bool(_open_was[team]):
			if team == "ally":
				var anyone := not GameState.alive_party().is_empty()
				await msg(("The middle of your %s side is down! The foe can attack you directly." % Ring.side_element(ally_side).capitalize()) if anyone
					else "All your beasts are down! The foes turn on you...", 1.2)
				if GameState.shield > 0:
					_shield_pulse(shield_bubble)
					await msg("Your shield crackles to life! It can block %d hit%s." % [GameState.shield, "" if GameState.shield == 1 else "s"], 1.0)
				else:
					await msg("You have no shield! One more hit and it's over. %s" % ("Turn your ring to a side with a beast in its middle!" if anyone else ("Revive a beast, or run!" if wild else "Revive a beast, or forfeit!")), 1.3)
			else:
				await msg("%s's middle beast is down! Your beasts can attack %s directly." % [trainer.get("name", "The trainer"), trainer.get("name", "them")], 1.1)
		_open_was[team] = open


# ================================================================ player commands
func _command_phase() -> Array:
	if not Ring.side_alive(ally_ring, ally_side):
		# everyone facing the foe is down: the ring turns to the nearest side with a beast standing in its middle
		var ns := Ring.covered_side(ally_ring, ally_side)
		if ns != ally_side:
			await msg("Everyone on your %s side is down! You turn your ring to the %s side." % [Ring.side_element(ally_side).capitalize(), Ring.side_element(ns).capitalize()], 1.0)
			await _turn_ring("ally", ns)
	if cfg.get("autoplay", false) or UI.auto:
		return await _auto_commands()
	flute_used = false
	if tutorial:
		await _tut_round_intro()
	var rows := _panel_rows()
	var focus := 0
	while true:
		if result != "":
			return []
		if rows[0].get("done", false) and not _rows_waiting(rows):
			break
		var p := CommandPanel.new()
		p.setup(rows, _panel_info(), focus, _row_targets, {"render": _render_rows, "hint": _caption,
			"option": _show_option, "bars": bars, "foe_grid": foe_grid, "ally_grid": ally_grid})
		_commanding = true
		UI.push(p)
		var r: Dictionary = await p.done
		_commanding = false
		_show_option({}, {})
		_hide_targets()
		ally_grid.focus = -1
		ally_grid.target = -1
		foe_grid.target = -1
		ally_grid.targets = []
		foe_grid.targets = []
		ally_grid.queue_redraw()
		foe_grid.queue_redraw()
		focus = int(r.get("focus", focus))
		match String(r.get("kind", "")):
			"go":
				break
			"rotate":
				var ns := Ring.next_side(ally_ring, ally_side, int(r["dir"]))
				if ns != ally_side:
					await _turn_ring("ally", ns)
					# a new side: its beasts choose afresh
					var keep: Dictionary = rows[0]
					rows = _panel_rows()
					rows[0] = keep
				# on to the new side's first beast that can act
				focus = 1
				for i in range(1, rows.size()):
					if rows[i].get("status", "") == "":
						focus = i
						break
			"sub":
				var opt: Dictionary = rows[0]["options"][int(rows[0]["sel"])]
				match String(opt["id"]):
					"items":
						var act := await _choose_item()
						if not act.is_empty():
							act["prio"] = 9
							rows[0]["act"] = act
							rows[0]["done"] = true
							focus = 1
					"flute":
						var played: bool = await _flute_flow()
						if result != "":
							return []
						if played:
							rows[0]["act"] = {"type": "flute"}
							rows[0]["done"] = true
							rows[0]["locked"] = true
							focus = 1
							# a charmed beast has left the field: the beasts' targets are chosen afresh
							var keep2: Dictionary = rows[0]
							rows = _panel_rows()
							rows[0] = keep2
					"summon":
						var sact := await _summon_flow()
						if result != "":
							return []
						if not sact.is_empty():
							rows[0]["act"] = sact
							rows[0]["done"] = true
							rows[0]["locked"] = true
							focus = 1
					"run":
						if await _try_run():
							result = "run"
							return []
						rows[0]["act"] = {"type": "none"}
						rows[0]["done"] = true
						rows[0]["locked"] = true
						focus = 1
					"forfeit":
						if await UI.ask("Forfeit the battle? It counts as a loss, but you keep your gold."):
							result = "forfeit"
							return []
	_caption("")
	_refresh()
	return _acts_from_rows(rows)


## True while a standing beast on the active side still needs its move.
func _rows_waiting(rows: Array) -> bool:
	for i in range(1, rows.size()):
		var r: Dictionary = rows[i]
		if r.get("status", "") == "" and not r.get("done", false):
			return true
	return false


## The command panel's rows: you, then the three slots of the side facing the foe.
## (_rows_now: the rows being chosen, so a target list can see what the other beasts have chosen)
func _panel_rows() -> Array:
	var rows := []
	var shield := ""
	if GameState.max_shield > 0:
		shield = "Shield " + "◆".repeat(GameState.shield) + "◇".repeat(GameState.max_shield - GameState.shield) + "   "
	var t_opts := [
		{"id": "slingshot", "label": "Slingshot", "target": "enemy", "desc": "Fire a stone at a foe or an exposed trainer."},
		{"id": "items", "label": "Items", "sub": true, "desc": "Heal, cure or revive your beasts, buff your team, or hit the foes with bombs and powders."},
		{"id": "flute", "label": "Flute", "sub": true, "disabled": not GameState.has_flute(),
			"desc": "Play a song: lift your team, weaken the foes, or charm a wild beast into joining you." if GameState.has_flute() else "You don't have a flute yet. Your uncle in Bellerive is keeping your father's."},
		{"id": "watch", "label": "Watch", "target": "none", "desc": "Let your beasts handle this round."},
	]
	if not GameState.summons.is_empty():
		# a captured temple guardian, called with its song: once per battle, for a shield point
		var why := ""
		if summoned:
			why = "You've already called a summon this battle."
		elif GameState.shield <= 0:
			why = "Summoning costs a shield point, and you have none left."
		elif not GameState.has_flute():
			why = "You need your flute to play a summon's song."
		t_opts.insert(3, {"id": "summon", "label": "Summon", "sub": true, "disabled": why != "",
			"desc": why if why != "" else "Play a temple's song to call its guardian: it strikes every foe at once. Once per battle, for one shield point (%d left)." % GameState.shield})
	if wild:
		t_opts.append({"id": "run", "label": "Run", "sub": true, "desc": "Try to escape."})
	else:
		t_opts.append({"id": "forfeit", "label": "Forfeit", "sub": true, "disabled": tutorial,
			"desc": "Give up the battle. It counts as a loss, but you keep your gold and can try again." if not tutorial else "%s: \"No giving up in the middle of a lesson!\"" % _tut_who()})
	if tutorial:
		var want := _tut_you()
		for o in t_opts:
			if o["label"] != want:
				o["disabled"] = true
				o["desc"] = "%s: \"Not yet! Try %s this round.\"" % [_tut_who(), want]
	var start := 0
	for i in t_opts.size():
		if not t_opts[i].get("disabled", false):
			start = i
			break
	rows.append({"kind": "trainer", "name": GameState.player_name, "sub": "%sTrainer Lv %d" % [shield, GameState.trainer_level],
		"icon": UIKit.tex("tab_trainer"), "options": t_opts, "sel": start, "done": false})
	for k in Ring.side_slots(ally_side):
		var b = ally_ring.get(k, null)
		if b == null:
			rows.append({"kind": "beast", "beast": null, "name": Ring.slot_name(k), "sub": "", "status": "empty", "options": [{"label": ""}],
				"status_desc": "Nobody stands on the %s of your ring." % Ring.slot_name(k)})
			continue
		var row := {"kind": "beast", "beast": b, "name": b.nickname, "icon": PixelArt.beast_texture(b.genes),
			"sub": "Lv %d  HP %d/%d  MP %d" % [b.level, maxi(0, b.hp), b.max_hp(), b.mp], "sel": 0, "done": false}
		if b.hp <= 0:
			row["status"] = "down"
			row["options"] = [{"label": ""}]
			row["status_desc"] = "%s has fainted. Revive it with an item, or turn the ring to another side." % b.nickname
		else:
			row["options"] = _move_options(b)
			for i in row["options"].size():
				if not row["options"][i].get("disabled", false):
					row["sel"] = i
					break
		rows.append(row)
	_rows_now = rows
	return rows


## A beast's choices this round: its moves of the element it fights with and neutral ones, then Defend.
func _move_options(b) -> Array:
	var out := []
	var s := _st(b)
	var el := _fight_el(b)
	for mv in _usable_moves(b):
		var m := MoveDB.get_move(mv)
		var cd: int = s["cd"].get(mv, 0)
		var cost := MoveDB.mp_cost(mv)
		var right: String = String(m["el"]).to_upper()
		if m.has("power"):
			right += "  %d" % m["power"]
		if cost > 0:
			right += "   MP %d" % cost
		var desc := MoveDB.summary(mv)
		var off: bool = cd > 0 or b.mp < cost
		# (note: the move window's warning line)
		var note := ""
		if cd > 0:
			desc = "Recharging for %d more turn(s).\n" % cd + desc
			note = "Recharging: ready again in %d turn%s." % [cd, "" if cd == 1 else "s"]
			right = "wait %d" % cd
		elif b.mp < cost:
			desc = "Not enough MP! (%d of %d) Heal at a Beast Center or use a Spirit Drop.\n" % [b.mp, cost] + desc
			note = "Not enough MP (%d of %d). Heal at a Beast Center or use a Spirit Drop." % [b.mp, cost]
		elif cost > 0:
			desc = "Costs %d MP (%s has %d).\n" % [cost, b.nickname, b.mp] + desc
		if tutorial:
			var want_b := _tut_beast()
			if want_b != "Fight" or mv != _tut_move(b):
				off = true
				desc = "%s: \"%s\"" % [_tut_who(), "Defend this round!" if want_b == "Defend" else "Use %s for now. You'll try the others soon!" % MoveDB.get_move(_tut_move(b))["name"]]
				note = desc
		out.append({"id": "move", "move": mv, "label": String(m["name"]), "right": right, "desc": desc, "note": note, "target": m["target"], "disabled": off})
	if el == "neutral" and not b.ghost:
		var plain := "%s can't use %s moves from the %s side: plain moves only." % [b.nickname, b.element_text(), Ring.side_element(ally_side).capitalize()]
		out[0]["desc"] = plain + "\n" + String(out[0]["desc"])
		if String(out[0].get("note", "")) == "":
			out[0]["note"] = plain
	var d := {"id": "defend", "label": "Defend", "target": "none", "right": "half damage",
		"desc": "Brace for impact: %s takes half damage until your side's next turn." % b.nickname}
	if tutorial and _tut_beast() != "Defend":
		d["disabled"] = true
		d["note"] = "%s: \"Not now! Attack this round.\"" % _tut_who()
		d["desc"] = String(d["note"])
	out.append(d)
	# Move: to another slot of the ring (see _shift_spots), in place of its move this round
	var spots := _shift_spots(b)
	var mv_desc := "%s steps over to another slot of your ring (▲ ▼ to choose it): the side it moves to faces the foe. It uses up its turn." % b.nickname
	if spots.is_empty():
		mv_desc = ("%s guards you from the middle of the side: if it left, you'd be open to attack." % b.nickname) if _slot_of(ally_ring, b) == ally_side * 2 \
			else "There's no open slot %s can move to without leaving you open to attack." % b.nickname
	if tutorial:
		mv_desc = "%s: \"Not in a lesson! Attack this round.\"" % _tut_who()
	out.append({"id": "shift", "label": "Move", "target": "slot", "right": "uses its turn", "desc": mv_desc, "disabled": spots.is_empty() or tutorial,
		"none_hint": "Only one beast can move each round."})
	return out


## True if the beast in the middle of a ring's side is standing.
func _middle_standing(r: Dictionary, side: int) -> bool:
	var m = r.get(posmod(side, 4) * 2, null)
	return m != null and m.hp > 0


## Where a beast on the side facing the other trainer can Move to (`team`: "ally" for yours, "foe" for theirs): any
## other slot it can stand on that's empty, or holds a fainted beast that can stand on the slot it leaves (they trade
## places), as long as that doesn't leave the side then facing the foe (see _shift_side) without a beast standing in
## its middle when it had one: so the beast guarding its trainer can't just walk off, but a corner beast can step into
## a fallen one's place. In ring order from its own slot, as ▲ ▼ go through them.
func _shift_spots(b, team := "ally") -> Array:
	var r: Dictionary = ally_ring if team == "ally" else foe_ring
	var s := _slot_of(r, b)
	if s < 0 or b.hp <= 0 or not (ally_slots if team == "ally" else foe_slots).has(b):
		return []
	var covered := _middle_standing(r, ally_side if team == "ally" else foe_side)
	var out := []
	for i in range(1, Ring.SLOTS):
		var k := posmod(s + i, Ring.SLOTS)
		if not Ring.can_hold(b, k):
			continue
		var o = r.get(k, null)
		if o != null and (o.hp > 0 or not Ring.can_hold(o, s)):
			continue
		var after := _ring_after(r, b, k)
		if covered and not _middle_standing(after, _shift_side(after, k, b, team)):
			continue
		out.append(k)
	return out


## A ring as it would be once `b` moved to slot k (trading places with whoever is there).
func _ring_after(r: Dictionary, b, k: int) -> Dictionary:
	var s := _slot_of(r, b)
	var after := r.duplicate()
	var o = r.get(k, null)
	after[k] = b
	if o != null:
		after[s] = o
	else:
		after.erase(s)
	return after


## The side that faces the other trainer once a beast has moved to slot k (the ring as it is then): k's side; for a
## corner, of its two sides the one facing them already, else the one with a beast standing in its middle, else the
## one of the beast's own element.
func _shift_side(r: Dictionary, k: int, b, team := "ally") -> int:
	if not Ring.is_corner(k):
		return k / 2
	var a := k / 2
	var c := (a + 1) % 4
	var now := ally_side if team == "ally" else foe_side
	if now == a or now == c:
		return now
	var sa := _middle_standing(r, a)
	var sc := _middle_standing(r, c)
	if sa != sc:
		return a if sa else c
	return c if Ring.side_element(c) in b.elements() else a


## A beast's Move: it steps over to slot k (trading places with a fainted beast there), and the side it moved to turns
## to face the other trainer. Checked again now, as the ring may have changed since it was chosen.
func _do_shift(b, k: int) -> void:
	var team := _team(b)
	var r: Dictionary = ally_ring if team == "ally" else foe_ring
	var s := _slot_of(r, b)
	var who: String = b.nickname if team == "ally" else "%s's %s" % [trainer.get("name", "The trainer"), b.nickname]
	if not k in _shift_spots(b, team):
		if b.hp > 0 and _active(b):
			await msg("%s couldn't move to the %s." % [who, Ring.slot_name(k)], 0.7)
		return
	var o = r.get(k, null)
	r.erase(s)
	r[k] = b
	if o != null:
		r[s] = o
	if team == "ally":
		b.slot = k
		if o != null:
			o.slot = s
	await msg("%s moves over to the %s!" % [who, Ring.slot_name(k)], 0.5)
	Sfx.play("step_grass")
	var tw := create_tween()
	for pair in [[b, k], [o, s]]:
		if pair[0] != null and nodes.has(pair[0]):
			var n: Node3D = nodes[pair[0]]
			var p := _slot_pos(team, int(pair[1]))
			_walk_to(pair[0], p)
			tw.parallel().tween_property(n, "position", Vector3(p.x, n.position.y, p.z), 0.45).set_trans(Tween.TRANS_SINE)
	await tw.finished
	for who2 in [b, o]:
		if who2 != null:
			_walk_to(who2, null)
	var side := _shift_side(r, k, b, team)
	if side != (ally_side if team == "ally" else foe_side):
		await _turn_ring(team, side)
		if team == "ally":
			await msg("Your %s side faces the foe now." % Ring.side_element(side).capitalize(), 0.7)
		else:
			await msg("%s's %s side faces you now." % [trainer.get("name", "The trainer"), Ring.side_element(side).capitalize()], 0.7)
	else:
		_place_ring(team)
		_sync_slots()
		_refresh()
	await _check_exposed()


## A beast's rig walking over to `to` (a Move), turned the way it goes; to = null: it stops, facing the foe again.
## (A fainted one is slid along lying down.)
func _walk_to(b, to) -> void:
	var rig := _rig(b)
	if rig == null or _st(b)["down"]:
		return
	var n: Node3D = nodes[b]
	var yaw := 0.0
	if to != null:
		var d: Vector3 = n.basis.inverse() * ((to as Vector3) - n.position)
		yaw = atan2(-d.z, d.x)
	rig.state = "idle" if to == null else "walk"
	rig.pace = 1.6
	var tw := create_tween()
	tw.tween_property(n.get_node("Model"), "rotation:y", yaw, 0.15)


func _panel_info() -> Dictionary:
	var up := Ring.next_side(ally_ring, ally_side, -1)
	var down := Ring.next_side(ally_ring, ally_side, 1)
	return {"up": Ring.side_element(up).capitalize() if up != ally_side and not tutorial else "",
		"down": Ring.side_element(down).capitalize() if down != ally_side and not tutorial else "",
		"prompt": "What will you do, %s?" % GameState.player_name, "lesson": tutorial}


## Who a row's option can be aimed at: [{label, ref, tile, grid}] (tile: where it stands on its grid). An open rival
## trainer is a target too.
func _row_targets(row: Dictionary, opt: Dictionary) -> Array:
	var out := []
	match String(opt.get("target", "none")):
		"enemy":
			for b in _alive(foe_slots):
				out.append({"label": b.nickname, "ref": b, "grid": "foe_grid", "tile": foe_slots.find(b) if wild else _slot_of(foe_ring, b)})
			if _side_open("foe"):
				out.append({"label": String(trainer.get("name", "the trainer")), "ref": "foe_trainer", "grid": "foe_grid", "tile": -2})
			# start on the foe facing this beast's own row
			var mine = row.get("beast", null)
			var i := ally_slots.find(mine)
			if i >= 0 and foe_slots[i] != null and foe_slots[i].hp > 0:
				row["target_sel"] = _alive(foe_slots).find(foe_slots[i])
		"ally":
			for b in _alive(ally_slots):
				out.append({"label": b.nickname, "ref": b, "grid": "ally_grid", "tile": _slot_of(ally_ring, b)})
		"ally_ko":
			for b in GameState.party.filter(func(x): return x.hp <= 0 and x.slot >= 0):
				out.append({"label": b.nickname, "ref": b, "grid": "ally_grid", "tile": int(b.slot)})
		"enemies":
			for b in _alive(foe_slots):
				out.append({"label": b.nickname, "ref": b, "grid": "foe_grid", "tile": foe_slots.find(b) if wild else _slot_of(foe_ring, b)})
		"allies":
			for b in _alive(ally_slots):
				out.append({"label": b.nickname, "ref": b, "grid": "ally_grid", "tile": _slot_of(ally_ring, b)})
		"slot":
			# the slots it can Move to (one beast moves each round)
			for r2 in _rows_now:
				if r2 != row and r2.get("kind", "") == "beast" and r2.get("done", false) and String(r2["options"][int(r2.get("sel", 0))].get("id", "")) == "shift":
					return []
			for k in _shift_spots(row.get("beast", null)):
				var o = ally_ring.get(k, null)
				out.append({"label": Ring.slot_name(k), "ref": k, "grid": "ally_grid", "tile": k,
					"note": "Empty" if o == null else "%s (down) trades places" % o.nickname})
	if tutorial and out.size() > 1 and String(opt.get("target", "")) in ["enemy", "ally", "ally_ko"]:
		# a lesson aims at one: the trainer when that's the lesson, else the teacher's first beast (or your first one)
		var want := 0
		for j in out.size():
			if typeof(out[j]["ref"]) == TYPE_STRING and _tut_round().get("target", "") == "trainer":
				want = j
		out = [out[want]]
		row["target_sel"] = 0
	return out


func _slot_of(r: Dictionary, b) -> int:
	for k in r:
		if r[k] == b:
			return int(k)
	return -1


## Your side's actions from the panel's rows: on your side's turn, your own action goes first.
func _acts_from_rows(rows: Array) -> Array:
	var acts := []
	var r0: Dictionary = rows[0]
	if r0.has("act"):
		acts.append(r0["act"])
	else:
		var o: Dictionary = r0["options"][int(r0["sel"])]
		match String(o["id"]):
			"slingshot":
				acts.append({"type": "slingshot", "target": _row_ref(r0), "prio": 9})
			_:
				acts.append({"type": "none"})
	for i in range(1, rows.size()):
		var r: Dictionary = rows[i]
		if r.get("status", "") != "" or r.get("beast", null) == null:
			continue
		var b = r["beast"]
		var o2: Dictionary = r["options"][int(r["sel"])]
		if o2["id"] == "defend":
			acts.append({"type": "defend", "actor": b, "prio": 7})
		elif o2["id"] == "shift":
			# last of your side's turn, so the others' moves land before the ring turns
			acts.append({"type": "shift", "actor": b, "slot": int(_row_ref(r)), "prio": -9})
		else:
			var mv: String = o2["move"]
			var ref = "trainer" if tutorial and _tut_round().get("target", "") == "trainer" else _row_ref(r)
			acts.append({"type": "move", "actor": b, "move": mv, "target": ref, "prio": int(MoveDB.get_move(mv).get("prio", 0))})
	return acts


func _row_ref(r: Dictionary):
	var ts: Array = r.get("targets", [])
	if ts.is_empty():
		return null
	var ref = ts[clampi(int(r.get("target_sel", 0)), 0, ts.size() - 1)]["ref"]
	return "trainer" if typeof(ref) == TYPE_STRING and ref == "foe_trainer" else ref


## Test runs and simulated battles: you play like the AI does (a lesson by its plan).
func _auto_commands() -> Array:
	var acts := []
	if not Ring.side_alive(ally_ring, ally_side) or (_side_open("ally") and not tutorial):
		var ns := -1
		for side in 4:
			var mid = ally_ring.get(side * 2, null)
			if mid != null and mid.hp > 0:
				ns = side
				break
		if ns < 0:
			ns = Ring.best_side(ally_ring)
		if ns >= 0 and ns != ally_side:
			await _turn_ring("ally", ns)
	if tutorial:
		var b0 = _alive(ally_slots)[0] if not _alive(ally_slots).is_empty() else null
		var f0 = _alive(foe_slots)[0] if not _alive(foe_slots).is_empty() else null
		match _tut_you():
			"Slingshot":
				acts.append({"type": "slingshot", "target": f0, "prio": 9})
			"Items":
				if GameState.item_count("minor_potion") == 0:
					GameState.add_item("minor_potion")
				if b0 != null:
					acts.append({"type": "item", "item": "minor_potion", "target": b0, "prio": 9})
			"Flute":
				if String(_tut_round().get("song", "")) == "weaken":
					acts.append({"type": "player_song", "song": "weaken", "acc": 0.75, "prio": 9})
				else:
					# played right away, as from the panel (UI.auto_flute gives the performance)
					for sid in SongDB.ordered(GameState.songs):
						var s := SongDB.get_song(sid)
						if s["kind"] == "charm" and not s.get("ghost", false) and GameState.knows_song(sid):
							await _charm_flow(sid)
							break
		# every beast on the side facing the foe (in most lessons, just yours)
		for b in _alive(ally_slots):
			if _tut_beast() == "Defend":
				acts.append({"type": "defend", "actor": b, "prio": 7})
			else:
				acts.append({"type": "move", "actor": b, "move": _tut_move(b), "target": "trainer" if _tut_round().get("target", "") == "trainer" else f0, "prio": 0})
		UI.auto_log.append("[menu] lesson %s round %d -> %s, %s" % [lesson_id, round_no, _tut_you(), _tut_beast()])
		return acts
	for b in _alive(ally_slots):
		acts.append(_ai_choose(b))
	var ta := _auto_trainer_action()
	if not ta.is_empty():
		acts.append(ta)
	return acts


func _auto_trainer_action() -> Dictionary:
	var foes_alive := _alive(foe_slots)
	if guardian_b != null and guardian_b.hp > 0 and guardian_b.hp_ratio() <= GUARDIAN_CAPTURE_HP and GameState.knows_song(_guardian_song()):
		return {"type": "guardian_song", "acc": float(cfg.get("auto_song_acc", 0.85)), "prio": 9}
	if cfg.get("auto_summon", "") != "" and not summoned and GameState.shield > 0 and not foes_alive.is_empty():
		summoned = true
		GameState.shield -= 1
		_update_shield()
		return {"type": "summon", "el": String(cfg["auto_summon"]), "acc": 0.9, "prio": 11}
	if round_no == 1 and GameState.knows_song("weaken") and not foes_alive.is_empty():
		return {"type": "player_song", "song": "weaken", "acc": 0.75, "prio": 9}
	if _side_open("ally") and GameState.item_count("revival_seed") > 0:
		var kos := GameState.party.filter(func(x): return x.hp <= 0 and x.slot >= 0)
		if not kos.is_empty():
			return {"type": "item", "item": "revival_seed", "target": kos[0], "prio": 9}
	if _side_open("foe"):
		return {"type": "slingshot", "target": "trainer", "prio": 9}
	if foes_alive.is_empty():
		return {}
	foes_alive.sort_custom(func(x, y): return x.hp_ratio() < y.hp_ratio())
	return {"type": "slingshot", "target": foes_alive[0], "prio": 9}


func _choose_target(list: Array, title: String):
	if list.is_empty():
		return null
	if list.size() == 1 and (title == "Target" or tutorial):
		return list[0]
	var targets := []
	for t in list:
		var ally: bool = ally_ring.values().has(t)
		targets.append({"label": t.nickname, "ref": t, "grid": "ally_grid" if ally else "foe_grid",
			"tile": _slot_of(ally_ring, t) if ally else (foe_slots.find(t) if wild else _slot_of(foe_ring, t))})
	var row := {"kind": "trainer", "options": [{"label": title}], "targets": targets, "target_sel": 0}
	var panel := CommandPanel.new()
	panel.setup([row], {"target_only": true}, 0, Callable(), {
		"render": func(_rows, _focus, _picking): _show_targets(targets, int(row.get("target_sel", 0))),
		"hint": _caption, "foe_grid": foe_grid, "ally_grid": ally_grid})
	panel.picking = true
	UI.push(panel)
	var choice: Dictionary = await panel.done
	_hide_targets()
	_caption("")
	if choice.get("kind", "") != "go":
		return null
	return list[int(row.get("target_sel", 0))]


func _flute_flow() -> bool:
	if flute_used:
		await msg("You've already played your flute this turn.")
		return false
	if GameState.songs.is_empty():
		await msg("You don't know any songs yet!")
		return false
	var ids := []
	var items := []
	for sid in SongDB.ordered(GameState.songs):
		if not GameState.knows_song(sid):
			continue
		var s := SongDB.get_song(sid)
		var why := ""
		if s["kind"] == "summon":
			# only the guardian's own song, in its battle; the others are played with Summon
			if sid != _guardian_song():
				continue
			if guardian_b.hp_ratio() > GUARDIAN_CAPTURE_HP:
				why = "%s is still too strong to listen. Wear it down below 60%% of its HP first." % guardian_b.nickname
		elif s["kind"] == "charm":
			if not wild:
				why = "You can't charm another trainer's beasts."
			elif _charmable(sid).is_empty():
				why = ("None of these beasts will listen to it (max Lv %d)." % GameState.capture_cap()) if not s.get("ghost", false) else "Only ghost beasts listen to the Requiem."
		if tutorial:
			# a lesson lists just the song it teaches (for Capture, the first capture song you know); its beast always
			# listens
			var want_song := String(_tut_round().get("song", ""))
			if not ids.is_empty() or not (sid == want_song or (want_song == "capture" and s["kind"] == "charm" and not s.get("ghost", false))):
				continue
			why = ""
		var stars := GameState.mastery_stars(sid)
		var desc := (why + "\n" if why != "" else "") + SongDB.describe(sid) + "\nMastery " + "★".repeat(stars) + "☆".repeat(5 - stars)
		ids.append(sid)
		items.append({"text": s["name"], "right": SongDB.tag(sid), "disabled": why != "", "desc": desc})
	var c: int = await UI.choose("Play which song?", items, {"anchor": "bottom_right", "width": 460, "margin": Vector2(20, 20), "cancel": not tutorial,
		"font_size": 28, "rows": 6})
	if c < 0:
		return false
	var song: String = ids[c]
	if SongDB.is_summon(song):
		return await _guardian_song_flow(song)
	if SongDB.is_charm(song):
		return await _charm_flow(song)
	return await _effect_song_flow(song)


func _charmable(song: String) -> Array:
	if lesson_id == "flute":
		return _alive(foe_slots)
	return _alive(foe_slots).filter(func(f): return GameState.song_can_charm(song, f) == "")


func _effect_song_flow(song: String) -> bool:
	var s := SongDB.get_song(song)
	var target = null
	match s["target"]:
		"enemy":
			target = await _choose_target(_alive(foe_slots), "Target")
			if target == null:
				return false
		"ally":
			target = await _choose_target(_alive(ally_slots), "Which ally?")
			if target == null:
				return false
	flute_used = true
	await msg("You raise your flute and play %s..." % s["name"], 0.6)
	var acc: float = float((await UI.flute_ex(song, "%s  —  faster and cleaner means a stronger effect" % SongDB.tag(song), {"lesson": tutorial}))["acc"])
	_battle_music()
	if tutorial:
		acc = maxf(acc, 0.6)
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _apply_song(song, acc, "ally", target)
	if star:
		UI.toast("Your mastery of %s improved! It grew to %d notes." % [s["name"], SongDB.note_count(song, GameState.song_level(song))], UIKit.GOLD)
	return true


func _charm_flow(song: String) -> bool:
	var targets := _charmable(song)
	if targets.is_empty():
		return false
	var t = await _choose_target(targets, "Charm which beast?") if targets.size() > 1 else targets[0]
	if t == null:
		return false
	flute_used = true
	var flawless: bool = GameState.needs_flawless(t) and not tutorial
	if flawless:
		await msg("%s is stronger than any of your beasts. Only a flawless performance will reach it!" % t.nickname, 1.2)
	await msg("You raise your flute and play %s..." % SongDB.get_song(song)["name"], 0.7)
	var sub := "Charming %s (Lv %d)  —  play it FLAWLESSLY: not a single wrong note!" % [t.nickname, t.level] if flawless \
		else "Charming %s (Lv %d)  —  faster and cleaner means a better chance" % [t.nickname, t.level]
	var r: Dictionary = await UI.flute_ex(song, sub, {"goal": {"no_mistakes": true}} if flawless else {"lesson": tutorial})
	var acc: float = float(r["acc"])
	var mistakes: int = int(r["mistakes"])
	_battle_music()
	var chance := GameState.capture_chance(t, song, acc, mistakes)
	if tutorial and acc > 0.0:
		# the lesson's beast joins whenever the song is played through
		chance = 1.0
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _song_fx(PLAYER_POS, [t], true, acc < SongDB.FLAT_ACCURACY)
	await _note_effect(t)
	if flawless and mistakes > 0:
		Sfx.play("fail")
		await msg("%d mistake%s... %s is too strong to be charmed by anything less than perfect." % [mistakes, "" if mistakes == 1 else "s", t.nickname], 1.4)
		if star:
			UI.toast("Your mastery of %s improved!" % SongDB.get_song(song)["name"], UIKit.GOLD)
		return true
	if mistakes == 0 and not r.get("cancelled", false):
		await msg("A flawless performance!", 0.6)
	if randf() < chance:
		Sfx.play("capture")
		if lesson_id == "flute":
			GameState.set_flag("flute_lesson_done")
		await msg("%s was charmed by your melody!" % t.nickname)
		var slot := foe_slots.find(t)
		if slot >= 0:
			foe_slots[slot] = null
		foes.erase(t)
		_despawn(t)
		st.erase(t)
		var where := GameState.add_beast(t)
		_refresh()
		if where == "party":
			await msg("%s joined your party!" % t.nickname)
		else:
			await msg("%s was sent to your Beast Center storage." % t.nickname)
		_check_end()
	else:
		Sfx.play("fail")
		await msg("%s shook off the melody! (%d%% chance)" % [t.nickname, int(chance * 100)], 1.2)
		if randf() < 0.3:
			await _buff(t, {"atk": 1})
	if star:
		UI.toast("Your mastery of %s improved!" % SongDB.get_song(song)["name"], UIKit.GOLD)
	return true


## Who an effect song played by `side` reaches: all foes or all allies, or one (`target`, if it can hear it, else one
## at random).
func _song_targets(song: String, side: String, target) -> Array:
	var s := SongDB.get_song(song)
	var mine: Array = ally_slots if side == "ally" else foe_slots
	var theirs: Array = foe_slots if side == "ally" else ally_slots
	match s["target"]:
		"enemies":
			return _alive(theirs)
		"allies":
			return _alive(mine)
	var pool := _alive(theirs if s["target"] == "enemy" else mine)
	if target != null and pool.has(target):
		return [target]
	return [pool.pick_random()] if not pool.is_empty() else []


## Applies an effect song played by `side` ("ally" = you, "foe" = the rival trainer) with accuracy `acc`. The notes fly
## from the flute to whoever it reaches first (unless `shown`: they already have, as the rival played).
func _apply_song(song: String, acc: float, side: String, target, shown := false) -> void:
	var s := SongDB.get_song(song)
	var targets := _song_targets(song, side, target)
	if not shown:
		await _song_fx(PLAYER_POS if side == "ally" else RIVAL_POS, targets, side == "ally", acc < SongDB.FLAT_ACCURACY)
	if acc < SongDB.FLAT_ACCURACY:
		Sfx.play("fail")
		await msg("The melody falls flat... nothing happens.", 0.9)
		return
	var great := acc >= SongDB.GREAT_ACCURACY
	var mastery := GameState.mastery_stars(song) if side == "ally" else 2
	var power := (0.6 + acc) * (1.0 + 0.06 * mastery)
	if great:
		await msg("A stirring performance!", 0.6)
	if targets.is_empty():
		await msg("But nobody was there to hear it...", 0.7)
		return
	for t in targets:
		if result != "" or t.hp <= 0:
			continue
		if s.has("buff"):
			await _buff(t, _song_stages(s["buff"], great))
		if s.has("debuff"):
			await _buff(t, _song_stages(s["debuff"], great))
		if s.has("heal_pct"):
			if t.status == "haunt":
				await msg("%s is haunted and can't be healed!" % t.nickname, 0.6)
			else:
				var amt := maxi(1, int(t.max_hp() * float(s["heal_pct"]) * power))
				var before: int = t.hp
				t.hp = mini(t.max_hp(), t.hp + amt)
				if t.hp > before:
					Sfx.play("heal")
					_float_text(t, "+%d" % (t.hp - before), Color("#70ff90"))
					_refresh()
					await msg("%s recovered %d HP." % [t.nickname, t.hp - before], 0.55)
		if s.get("cure", false) and t.status != "" and acc >= 0.6:
			t.status = ""
			_refresh()
			await msg("%s's ailment melted away!" % t.nickname, 0.6)
		if s.has("status"):
			var chance := float(s["chance"]) * power + (0.1 if great else 0.0)
			if randf() < chance:
				await _inflict(t, s["status"], true)
			else:
				await msg("%s shook off the melody." % t.nickname, 0.5)


func _song_stages(changes: Dictionary, great: bool) -> Dictionary:
	var out := {}
	for k in changes:
		out[k] = int(changes[k]) * (2 if great else 1)
	return out


## Musical notes from a trainer's flute (the trainer standing at `from`) to whoever the song reaches: `to` holds beasts
## (or points in the world). The notes are shared out among them, each looping up and over in an arc of its own and
## landing with a twinkle; gold for your songs, violet for the rival's. A song that falls `flat` sends them out only to
## drop short and fade. Returns as the first notes land (the rest still on their way).
func _song_fx(from: Vector3, to: Array, mine: bool, flat := false) -> void:
	var col := Color("#ffe080") if mine else Color("#e0a0ff")
	var flute := from + Vector3(0, VPer.height() * 0.62, 0) + (FOE_CENTER - ALLY_CENTER).normalized() * (0.35 if mine else -0.35)
	var ends := []
	for x in to:
		if x is Vector3:
			ends.append(x)
		elif nodes.has(x):
			ends.append((nodes[x] as Node3D).position + Vector3(0, 0.75, 0))
	if ends.is_empty():
		# nobody to hear it: out over the field
		ends.append(flute.lerp(RIVAL_POS if mine else PLAYER_POS, 0.6) + Vector3(0, 0.6, 0))
	var count := clampi(ends.size() * 3, 6, 12)
	var fly := 0.85
	for i in count:
		var end: Vector3 = ends[i % ends.size()] + Vector3(randf_range(-0.25, 0.25), randf_range(-0.15, 0.3), randf_range(-0.2, 0.2))
		if flat:
			end = flute.lerp(end, 0.45) + Vector3(0, -0.9, 0)
		var dist := flute.distance_to(end)
		# each arc bows up, and a little to one side or the other
		var side := Vector3.UP.cross(end - flute).normalized() * randf_range(-0.9, 0.9)
		var peak := flute.lerp(end, 0.5) + Vector3(0, 0.6 + dist * 0.22, 0) + side
		var l := Label3D.new()
		l.text = "♪" if i % 3 != 1 else "♫"
		l.font_size = 60
		l.outline_size = 8
		l.modulate = col
		l.pixel_size = 0.011
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = flute
		l.scale = Vector3.ONE * 0.5
		l.visible = false
		add_child(l)
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_callback(func() -> void: l.visible = true)
		tw.tween_method(func(t: float) -> void:
			var a := flute.lerp(peak, t)
			var b := peak.lerp(end, t)
			l.position = a.lerp(b, t)
			l.scale = Vector3.ONE * (0.5 + 0.6 * sin(PI * minf(t * 1.4, 1.0)) + 0.35 * t), 0.0, 1.0, fly).set_trans(Tween.TRANS_SINE)
		if flat:
			tw.tween_property(l, "modulate:a", 0.0, 0.25)
		else:
			# the twinkle as it lands
			tw.tween_property(l, "scale", Vector3.ONE * 1.6, 0.12)
			tw.parallel().tween_property(l, "modulate", Color(1, 1, 1, 0), 0.18)
		tw.tween_callback(l.queue_free)
	await get_tree().create_timer(fly + 0.1).timeout


## The rival trainer's flute: the song as you'd first learn it, the notes flying to `targets` as they play.
func _rival_melody(sid: String, targets: Array) -> void:
	_song_fx(RIVAL_POS, targets, false)
	var spb := clampf(60.0 / float(SongDB.get_song(sid)["bpm"]), 0.42, 0.7)
	for note in SongDB.melody(sid, 1):
		for btn in note:
			Sfx.flute_note(SongDB.note_freq(sid, int(btn)))
		await get_tree().create_timer(spb).timeout
	await get_tree().create_timer(0.3).timeout


func _rival_wants_song() -> bool:
	if wild or String(trainer.get("song", "")) == "" or rival_song_count >= 3:
		return false
	return round_no == 1 or randf() < 0.35


func _do_rival_song(a: Dictionary) -> void:
	var sid: String = a["song"]
	if _alive(foe_slots).is_empty():
		return
	rival_song_count += 1
	heard_songs[sid] = true
	var who: String = trainer.get("name", "The trainer")
	await msg("%s raises a flute and plays the %s!" % [who, SongDB.song_name(sid)], 0.7)
	# (who it reaches is settled first, so the notes go where the song does)
	var targets := _song_targets(sid, "foe", null)
	await _rival_melody(sid, targets)
	var skill := clampf(float(trainer.get("flute_skill", 0.8)) * randf_range(0.9, 1.1), 0.0, 1.0)
	await _apply_song(sid, skill, "foe", targets[0] if targets.size() == 1 else null, true)


## After a win: try to play back a song you heard the rival play. No mistakes allowed.
func _learn_heard_song(sid: String) -> void:
	var name := SongDB.song_name(sid)
	await msg("%s's melody is still ringing in your ears: the %s." % [trainer.get("name", "The trainer"), name], 1.2)
	if not GameState.has_flute():
		await msg("You'd love to play it back... but you don't have a flute yet. Maybe %s will play it again some day." % trainer.get("name", "they"), 1.6)
		return
	var c: int = await UI.choose("Try to play the %s back?" % name, [
		{"text": "Play it back", "desc": "No mistakes allowed: one wrong note and it slips away.\n" + SongDB.describe(sid)},
		{"text": "Let it go"}], {"anchor": "bottom_right", "width": 420, "cancel": false, "margin": Vector2(20, 20)})
	if c != 0:
		await msg("The melody fades from your memory...", 0.8)
		return
	var r: Dictionary = await UI.flute_ex(sid, "Play it back without a single mistake to learn it!", {"mode": "learn", "goal": {"no_mistakes": true}})
	if not r["cancelled"] and int(r["mistakes"]) == 0:
		GameState.learn_song(sid)
		Sfx.play("levelup")
		UI.toast("Learned the song: %s!" % name, UIKit.GOLD)
		await msg("Note-perfect! You learned the %s!" % name, 1.2)
	else:
		Sfx.play("fail")
		var again := " Maybe %s will play it again sometime." % trainer.get("name", "they") if trainer.get("encore", false) else ""
		await msg("%d mistake%s... the melody slips away.%s" % [int(r["mistakes"]), "" if int(r["mistakes"]) == 1 else "s", again], 1.4)


func _note_effect(t) -> void:
	if not nodes.has(t):
		return
	var base: Vector3 = nodes[t].position
	for i in 6:
		var l := Label3D.new()
		l.text = "♪" if i % 2 == 0 else "♫"
		l.font_size = 56
		l.outline_size = 8
		l.modulate = Color("#ffe080")
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = base + Vector3(cos(i * 1.05) * 0.9, 0.2, sin(i * 1.05) * 0.4)
		add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "position", base + Vector3(cos(i * 1.05 + 2.0) * 0.3, 1.5, 0), 0.9)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
		tw.tween_callback(l.queue_free)
	await get_tree().create_timer(0.9).timeout


func _item_target_kind(it: Dictionary) -> String:
	if it.has("target"):
		return it["target"]
	if it.has("revive_pct"):
		return "ally_ko"
	return "ally"


func _choose_item() -> Dictionary:
	var ids := []
	var items := []
	var keys := GameState.inventory.keys()
	keys.sort_custom(func(a, b): return ItemDB.item_name(a) < ItemDB.item_name(b))
	if tutorial and GameState.item_count("minor_potion") == 0:
		GameState.add_item("minor_potion")
		keys = GameState.inventory.keys()
	for id in keys:
		var it := ItemDB.get_item(id)
		if it.get("kind", "") != "use" or it.get("field_only", false):
			continue
		if tutorial and id != "minor_potion":
			continue
		ids.append(id)
		items.append({"text": it["name"], "right": "x%d" % GameState.item_count(id), "desc": it.get("desc", "")})
	if ids.is_empty():
		await msg("You have no usable items.", 0.8)
		return {}
	var c: int = await UI.choose("Items", items, {"anchor": "bottom_right", "width": 420, "margin": Vector2(20, 20), "cancel": not tutorial,
		"font_size": 28, "rows": 6})
	if c < 0:
		return {}
	var id: String = ids[c]
	var it2 := ItemDB.get_item(id)
	var kind := _item_target_kind(it2)
	var t = null
	match kind:
		"ally_ko":
			var kos := GameState.party.filter(func(x): return x.hp <= 0)
			if kos.is_empty():
				await msg("No one has fainted.", 0.8)
				return {}
			t = await _choose_target(kos, "Revive whom?")
		"ally":
			var pool: Array = _alive(ally_slots) if it2.has("buff") else GameState.alive_party()
			if tutorial:
				# the beast the teacher's just nipped
				pool = _alive(ally_slots).slice(0, 1)
			if pool.is_empty():
				await msg("There's no one to use it on.", 0.8)
				return {}
			t = await _choose_target(pool, "Use on whom?")
		"enemy":
			t = await _choose_target(_alive(foe_slots), "Target")
		"allies":
			if _alive(ally_slots).is_empty():
				await msg("None of your beasts are standing.", 0.8)
				return {}
			t = "all"
		"enemies":
			t = "all"
	if t == null:
		return {}
	return {"type": "item", "item": id, "target": t, "prio": 5}


func _try_run() -> bool:
	var mine := 0.0
	var theirs := 0.0
	for b in _alive(ally_slots):
		mine += _eff_stat(b, "spd")
	for b in _alive(foe_slots):
		theirs += _eff_stat(b, "spd")
	var chance := clampf(0.55 + (mine - theirs) / maxf(1.0, mine + theirs), 0.3, 0.95)
	if _side_open("ally"):
		chance = 0.5
	if randf() < chance:
		Sfx.play("back")
		await msg("You got away safely!")
		return true
	await msg("Couldn't get away!")
	return false


# ================================================================ AI
## The foe's turn: a trainer may first turn its ring (to a side whose middle still stands, or now and then to a
## stronger side); then each of its active beasts picks a move.
func _ai_actions() -> Array:
	var out := []
	var mover = null
	if not wild and not tutorial:
		# a fallen middle beast: one of the corner beasts may step into its place instead of the ring turning
		var shift := _ai_shift()
		if not shift.is_empty():
			mover = shift["actor"]
			out.append(shift)
		else:
			var ns := _ai_pick_side()
			if ns != foe_side:
				await msg("%s turns their ring to the %s side!" % [trainer.get("name", "The trainer"), Ring.side_element(ns).capitalize()], 0.8)
				await _turn_ring("foe", ns)
	for b in foe_slots:
		if b != null and b.hp > 0 and b != mover:
			out.append(_ai_choose(b))
	if _rival_wants_song():
		out.append({"type": "rival_song", "song": String(trainer["song"]), "prio": 4})
	return out


## The foe trainer's Move (see _shift_spots): when the beast in the middle of the side facing you is down (or gone), a
## beast on that side steps into a slot that covers the trainer again, if that keeps at least as many of their beasts
## fighting as turning the ring to a side whose middle beast stands would (_ai_pick_side). Last in their turn, like
## yours. {} for none.
func _ai_shift() -> Dictionary:
	if not _side_open("foe"):
		return {}
	var turn_to := _ai_pick_side()
	var there := 0
	if turn_to != foe_side and _middle_standing(foe_ring, turn_to):
		there = _alive(Ring.side_slots(turn_to).map(func(k): return foe_ring.get(k, null))).size()
	var best := {}
	var best_score := -1.0
	for b in _alive(foe_slots):
		for k in _shift_spots(b, "foe"):
			var after := _ring_after(foe_ring, b, k)
			var side := _shift_side(after, k, b, "foe")
			if not _middle_standing(after, side):
				continue
			var n := _alive(Ring.side_slots(side).map(func(q): return after.get(q, null))).size()
			var sc: float = float(n) + (0.5 if side == foe_side else 0.0) + b.hp_ratio() * 0.1
			if sc > best_score:
				best_score = sc
				best = {"type": "shift", "actor": b, "slot": k, "prio": -9}
	if best.is_empty() or best_score < float(there):
		return {}
	return best


func _ai_pick_side() -> int:
	var best := Ring.best_side(foe_ring)
	if best < 0:
		return foe_side
	if not Ring.side_alive(foe_ring, foe_side) or _side_open("foe"):
		# guard the trainer: a side whose middle beast still stands
		var pick := -1
		var score := -1.0
		for side in 4:
			var mid = foe_ring.get(side * 2, null)
			if mid == null or mid.hp <= 0:
				continue
			var sc := 0.0
			for k in Ring.side_slots(side):
				var b = foe_ring.get(k, null)
				if b != null and b.hp > 0:
					sc += 1.0 + b.hp_ratio()
			if sc > score:
				score = sc
				pick = side
		return pick if pick >= 0 else best
	if best != foe_side and randf() < 0.15:
		return best
	return foe_side


func _ai_choose(b) -> Dictionary:
	if tutorial:
		var enemies0 := _alive(_theirs(b))
		if enemies0.is_empty():
			return {"type": "none"}
		return {"type": "move", "actor": b, "move": _tut_move(b), "target": enemies0[0], "prio": 0}
	var s := _st(b)
	var moves: Array = _usable_moves(b).filter(func(mv): return int(s["cd"].get(mv, 0)) <= 0 and MoveDB.mp_cost(mv) <= b.mp)
	if moves.is_empty():
		moves = ["tackle"]
	var allies := _alive(_mine(b))
	var enemies := _alive(_theirs(b))
	var other := "foe" if _team(b) == "ally" else "ally"
	var open := _side_open(other)
	if enemies.is_empty():
		if open:
			return {"type": "move", "actor": b, "move": _best_attack(b, moves), "target": "trainer", "prio": 0}
		return {"type": "none"}
	if not tutorial and b.hp_ratio() < 0.3 and randf() < 0.25:
		return {"type": "defend", "actor": b, "prio": 7}
	var best_mv: String = moves[0]
	var best_t = null
	var best_score := -1.0
	for mv in moves:
		var m := MoveDB.get_move(mv)
		var score := 0.0
		var target = null
		match m["kind"]:
			"attack":
				for e in enemies:
					var eff := Elements.multiplier(m["el"], _guard_el(e))
					var sc: float = float(m["power"]) * eff * (1.25 if m["el"] == _fight_el(b) else 1.0) * float(m.get("acc", 100)) / 100.0
					if m["target"] == "enemies":
						sc *= 0.7 * enemies.size()
					if e.hp_ratio() < 0.3:
						sc *= 1.3
					if sc > score:
						score = sc
						target = e
				if b.ghost:
					score *= 1.3
			"heal", "cleanse":
				var low = b
				if m["target"] != "self":
					for a in allies:
						if a.hp_ratio() < low.hp_ratio():
							low = a
				target = low
				if low.hp_ratio() < 0.5:
					score = 130.0 * (1.0 - low.hp_ratio())
			"revive":
				var pool: Array = foes if _st(b)["side"] == "foe" else GameState.party
				var kos := pool.filter(func(x): return x.hp <= 0)
				if not kos.is_empty():
					target = kos[0]
					score = 140.0
			"buff", "shield", "taunt", "special":
				target = b if m["target"] == "self" else allies.pick_random()
				score = 45.0 if round_no <= 2 else 18.0
				if m["kind"] == "taunt" and s["taunt"] > 0:
					score = 0.0
			"status", "debuff":
				var cands := enemies.filter(func(e): return e.status == "")
				if not cands.is_empty():
					target = cands.pick_random()
					score = 50.0 if round_no <= 3 else 25.0
		score *= randf_range(0.5, 1.5) if wild else randf_range(0.8, 1.2)
		if score > best_score:
			best_score = score
			best_mv = mv
			best_t = target
	# an open trainer is a tempting target: every hit breaks a shield point, and one more ends the battle
	if open and MoveDB.get_move(best_mv)["kind"] == "attack":
		var other_shield: int = GameState.shield if other == "ally" else foe_shield
		if randf() < (0.85 if other_shield == 0 else 0.45):
			best_t = "trainer"
	return {"type": "move", "actor": b, "move": best_mv, "target": best_t, "prio": int(MoveDB.get_move(best_mv).get("prio", 0))}


func _best_attack(b, moves: Array) -> String:
	var best := "tackle"
	var power := -1
	for mv in moves:
		var m := MoveDB.get_move(mv)
		if m["kind"] == "attack" and int(m.get("power", 0)) > power:
			power = int(m.get("power", 0))
			best = mv
	return best


# ================================================================ resolution
func _stage_mult(v: int) -> float:
	return (2.0 + v) / 2.0 if v >= 0 else 2.0 / (2.0 - v)


func _acc_mult(v: int) -> float:
	return (3.0 + v) / 3.0 if v >= 0 else 3.0 / (3.0 - v)


func _eff_stat(b, s: String) -> float:
	var v := float(b.stat(s)) * _stage_mult(int(_st(b)["stages"].get(s, 0)))
	if s == "atk" and b.status == "burn":
		v *= 0.75
	if s == "atk" and b.status == "fear":
		v *= 0.85
	if s == "spd" and b.status == "shock":
		v *= 0.6
	return v


func _resolve(acts: Array) -> void:
	for a in acts:
		var actor = a.get("actor", null)
		a["spd"] = (_eff_stat(actor, "spd") if actor != null else 1000.0) * randf_range(0.9, 1.1)
		if actor != null and float(actor.gear_fx("quick", 0.0)) > randf():
			a["prio"] = int(a.get("prio", 0)) + 1
	acts.sort_custom(func(x, y):
		if int(x.get("prio", 0)) != int(y.get("prio", 0)):
			return int(x.get("prio", 0)) > int(y.get("prio", 0))
		return float(x["spd"]) > float(y["spd"]))
	for a in acts:
		if result != "":
			return
		_message_subject = a.get("actor", "foe_trainer" if a.get("type", "") == "rival_song" else "trainer_self")
		match a.get("type", "none"):
			"item":
				await _do_item(a)
			"slingshot":
				await _do_slingshot(a)
			"strike_trainer":
				await _strike(a.get("actor", null), "ally")
			"shift":
				await _do_shift(a["actor"], int(a["slot"]))
			"rival_song":
				await _do_rival_song(a)
			"player_song":
				await _apply_song(a["song"], float(a["acc"]), "ally", null)
			"summon":
				await _do_summon(a)
			"guardian_song":
				if guardian_b != null:
					await _song_fx(PLAYER_POS, [guardian_b], true)
				await _guardian_capture(float(a["acc"]))
			"defend":
				var db = a["actor"]
				if db.hp <= 0 or not _active(db):
					continue
				_st(db)["defend"] = true
				Sfx.play("shield")
				_refresh()
				await msg("%s braces itself!" % db.nickname, 0.55)
			"move":
				var b = a["actor"]
				if b.hp <= 0 or not _active(b):
					continue
				await _do_move(b, a["move"], a["target"])
			_:
				continue
		_message_subject = null
		await _handle_faints()
		_check_end()
	if tutorial and _tut_finish() and result == "":
		for f in _alive(foe_slots):
			f.hp = 0
			_refresh()
		_message_subject = null
		await _handle_faints()
		_check_end()


## A revived beast gets back up on its pad.
func _field_revived(t) -> void:
	_st(t)["down"] = false
	if nodes.has(t):
		var n: Node3D = nodes[t]
		n.show()
		var rig := _rig(t)
		if rig != null:
			rig.state = "idle"
		var tw := create_tween()
		tw.tween_property(n, "rotation:z", 0.0, 0.3)
		tw.parallel().tween_property(n, "position:y", 0.0, 0.3)
		tw.parallel().tween_property(n, "scale", Vector3.ONE * 1.15, 0.3)
	_refresh()


func _trainer_throw(target_pos: Vector3, col: Color) -> void:
	VPer.animate(player_rig, 1.2, 1.0)
	var stone := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, 0.16)
	stone.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = col != Color("#8a847a")
	m.emission = col
	m.emission_energy_multiplier = 1.5
	stone.material_override = m
	stone.position = PLAYER_POS + Vector3(0.4, 1.3, 0)
	add_child(stone)
	var mid := (stone.position + target_pos) / 2.0 + Vector3(0, 1.4, 0)
	var tw := create_tween()
	tw.tween_property(stone, "position", mid, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(stone, "position", target_pos, 0.18).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(stone, "rotation", Vector3(4, 6, 2), 0.36)
	await tw.finished
	stone.queue_free()


func _target_point(b) -> Vector3:
	if nodes.has(b):
		var n: Node3D = nodes[b]
		return n.position + Vector3(0, float(n.get_meta("height")) * 0.55, 0)
	return Vector3(3, 1, -2)


func _do_slingshot(a: Dictionary) -> void:
	var t = a["target"]
	if typeof(t) == TYPE_STRING and t == "trainer" and _side_open("foe"):
		await msg("%s fires the slingshot at %s!" % [GameState.player_name, trainer.get("name", "the trainer")], 0.5)
		Sfx.play("slingshot")
		await _trainer_throw(RIVAL_POS + Vector3(0, 1.2, 0), Color("#8a847a"))
		await _strike(null, "foe")
		return
	if typeof(t) == TYPE_STRING or t == null or t.hp <= 0 or not foe_slots.has(t):
		var alive := _alive(foe_slots)
		if alive.is_empty():
			return
		t = alive.pick_random()
	await msg("%s fires the slingshot at %s!" % [GameState.player_name, t.nickname], 0.5)
	Sfx.play("slingshot")
	await _trainer_throw(_target_point(t), Color("#8a847a"))
	var acc := 0.9 / _acc_mult(int(_st(t)["stages"]["eva"]))
	if not tutorial and (_st(t)["vanish"] or randf() > acc):
		Sfx.play("miss")
		_float_text(t, "Miss", Color.WHITE)
		await msg("The stone whizzed past %s!" % t.nickname, 0.6)
		return
	var dmg := int((3.0 + 3.0 * GameState.crest_count() + t.max_hp() * 0.05) * randf_range(0.85, 1.15))
	dmg = maxi(1, dmg)
	await _deal(null, t, {"dmg": dmg, "eff": 1.0, "crit": false, "pierce": false})
	if t.hp > 0 and randf() < 0.1:
		await _inflict(t, "stun")


func _do_item(a: Dictionary) -> void:
	var id: String = a["item"]
	var it := ItemDB.get_item(id)
	if not GameState.remove_item(id):
		await msg("But you've run out of %s!" % it["name"])
		return
	var kind := _item_target_kind(it)
	var targets := []
	match kind:
		"allies":
			targets = _alive(ally_slots)
		"enemies":
			targets = _alive(foe_slots)
		"enemy":
			var t0 = a["target"]
			if t0 == null or t0.hp <= 0 or not foe_slots.has(t0):
				var alive := _alive(foe_slots)
				if not alive.is_empty():
					t0 = alive.pick_random()
			if t0 != null:
				targets = [t0]
		_:
			targets = [a["target"]]
	var who: String = "everyone" if kind in ["allies", "enemies"] else (targets[0].nickname if not targets.is_empty() and targets[0] != null else "nobody")
	await msg("%s used a %s%s." % [GameState.player_name, it["name"], "" if who == "nobody" else " on %s" % who], 0.7)
	if kind in ["enemy", "enemies"]:
		var col := Color("#c0a0ff")
		if it.has("bomb"):
			col = Color({"fire": "#ff7a30", "water": "#4ab0ff", "earth": "#c89a50", "air": "#c8fff0"}.get(it["bomb"]["el"], "#ffffff"))
		await _trainer_throw(_target_point(targets[0]) if not targets.is_empty() else FOE_CENTER, col)
		if it.has("bomb"):
			Sfx.play("explosion")
	for t in targets:
		if result != "" or t == null:
			continue
		await _apply_item(it, t)


func _apply_item(it: Dictionary, t) -> void:
	if it.has("revive_pct"):
		if t.hp > 0:
			await msg("It had no effect.")
			return
		t.hp = maxi(1, int(t.max_hp() * float(it["revive_pct"])))
		st.erase(t)
		_st(t)["side"] = "ally"
		Sfx.play("heal")
		_field_revived(t)
		_refresh()
		await msg("%s was revived!" % t.nickname)
		return
	if t.hp <= 0:
		await msg("It had no effect on %s." % t.nickname, 0.6)
		return
	if it.has("bomb"):
		var bomb: Dictionary = it["bomb"]
		var eff := Elements.multiplier(bomb["el"], _guard_el(t))
		var dmg := maxi(1, int(t.max_hp() * float(bomb["pct"]) * eff * randf_range(0.9, 1.1)))
		await _deal(null, t, {"dmg": dmg, "eff": eff, "crit": false, "pierce": false})
	if it.has("heal") or it.has("heal_pct"):
		if t.status == "haunt":
			await msg("%s is haunted and can't be healed!" % t.nickname, 0.7)
		else:
			var amt := int(it.get("heal", 0)) + int(t.max_hp() * float(it.get("heal_pct", 0.0)))
			var before: int = t.hp
			t.hp = mini(t.max_hp(), t.hp + amt)
			Sfx.play("heal")
			_float_text(t, "+%d" % (t.hp - before), Color("#70ff90"))
			_refresh()
			await msg("%s recovered %d HP." % [t.nickname, t.hp - before], 0.7)
	if it.has("mp") or it.has("mp_pct"):
		var before_mp: int = t.mp
		t.mp = mini(t.max_mp(), t.mp + int(it.get("mp", 0)) + int(ceil(t.max_mp() * float(it.get("mp_pct", 0.0)))))
		Sfx.play("heal")
		_float_text(t, "+%d MP" % (t.mp - before_mp), Color("#7ac8ff"))
		_refresh()
		await msg("%s recovered %d MP." % [t.nickname, t.mp - before_mp], 0.7)
	if it.get("cure", false) and t.status != "":
		t.status = ""
		_refresh()
		await msg("%s was cured!" % t.nickname, 0.7)
	if it.has("buff"):
		await _buff(t, it["buff"])
	if it.has("debuff"):
		await _buff(t, it["debuff"])
	if it.has("status"):
		if randf() < float(it.get("chance", 1.0)):
			await _inflict(t, it["status"], true)
		else:
			await msg("%s shrugged it off!" % t.nickname, 0.6)


func _shield_pulse(bubble: MeshInstance3D = null) -> void:
	if bubble == null:
		bubble = shield_bubble
	if bubble == null:
		return
	var m: StandardMaterial3D = bubble.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)


## A blow at a trainer who is open to attack (`team_hit`: "ally" for you, "foe" for the rival): it breaks a shield
## point, or, with none left, ends the battle. `b` is the beast that strikes, or null for your slingshot.
func _strike(b, team_hit: String) -> void:
	var pos := PLAYER_POS if team_hit == "ally" else RIVAL_POS
	var who: String = GameState.player_name if team_hit == "ally" else String(trainer.get("name", "the trainer"))
	if b != null:
		await msg("%s charges straight at %s!" % [b.nickname, who], 0.6)
		if nodes.has(b):
			var n: Node3D = nodes[b]
			var start := n.position
			var tw := create_tween()
			var lead := 0.0
			var rig := _rig(b)
			if rig != null:
				# rearing back first (its attack, beast_rig.gd), the blow landing as it reaches them
				rig.attack()
				lead = maxf(Rig.ATTACK_TIME * Rig.HIT_AT - 0.22, 0.0)
				tw.tween_interval(lead)
			tw.tween_property(n, "position", start.lerp(pos, 0.75), 0.22).set_ease(Tween.EASE_IN)
			tw.tween_property(n, "position", start, 0.25)
			await get_tree().create_timer(lead + 0.22).timeout
	var left: int = GameState.shield if team_hit == "ally" else foe_shield
	if left > 0:
		if team_hit == "ally":
			GameState.shield -= 1
		else:
			foe_shield -= 1
		Sfx.play("shield")
		_shield_pulse(shield_bubble if team_hit == "ally" else rival_bubble)
		_update_shield()
		_refresh()
		await msg("%s shield absorbed the blow! (%d left)" % ["Your" if team_hit == "ally" else "%s's" % who, left - 1], 0.9)
		return
	Sfx.play("crit")
	if team_hit == "ally":
		await UI.flash(Color("#ff4040"), 1)
	# a beaten trainer drops to one knee, catching their breath (never knocked flat: nobody gets hurt); a robot
	# powers down, slumping forward
	var rig: Node3D = player_rig if team_hit == "ally" else rival_rig
	var robot := false
	if is_instance_valid(rig):
		if rig.has_meta("skeleton"):
			VPer.set_pose(rig, "kneel")
		elif rig.get_child_count() > 0:
			robot = true
			var body: Node3D = rig.get_child(0)
			var tw2 := create_tween()
			tw2.tween_property(body, "rotation:z", -0.4, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw2.parallel().tween_property(body, "position:y", body.position.y - 0.12, 0.6)
	await msg(("%s powers down!" if robot else "%s drops to one knee!") % who, 1.2)
	result = "lose" if team_hit == "ally" else "win"


func _do_move(b, mv: String, target) -> void:
	var s := _st(b)
	match b.status:
		"sleep":
			b.status_turns -= 1
			if b.status_turns <= 0:
				b.status = ""
				_refresh()
				await msg("%s woke up!" % b.nickname, 0.7)
			else:
				await msg("%s is fast asleep." % b.nickname, 0.7)
				return
		"stun":
			b.status = ""
			_refresh()
			await msg("%s is stunned and can't move!" % b.nickname, 0.8)
			return
		"shock":
			if randf() < 0.25:
				await msg("%s is paralyzed! It can't move!" % b.nickname, 0.8)
				return
		"fear":
			if randf() < 0.25:
				await msg("%s cowers in fear!" % b.nickname, 0.8)
				return
		"confuse":
			if randf() < 0.33:
				await msg("%s is confused and hurt itself!" % b.nickname, 0.7)
				var d := _spare(b, maxi(1, int(b.max_hp() * 0.08)))
				b.hp = maxi(0, b.hp - d)
				_hit_fx(b, false)
				_float_text(b, "-%d" % d, Color("#ff7070"))
				_refresh()
				return
	var cost := MoveDB.mp_cost(mv)
	if cost > 0:
		if b.mp < cost:
			await msg("%s doesn't have enough MP for %s!" % [b.nickname, MoveDB.get_move(mv)["name"]], 0.7)
			mv = "tackle"
		else:
			b.mp -= cost
			_refresh()
	var m := MoveDB.get_move(mv)
	if int(m.get("cd", 0)) > 0:
		s["cd"][mv] = int(m["cd"]) + 1
	await msg("%s used %s!" % [b.nickname, m["name"]], 0.55, b)
	# straight at an open trainer
	if typeof(target) == TYPE_STRING and target == "trainer":
		var other := "foe" if _team(b) == "ally" else "ally"
		if m["kind"] == "attack" and _side_open(other):
			await _strike(b, other)
			return
		target = null
	await _lunge(b, m["kind"] == "attack")
	var targets := _targets_for(b, m, target)
	if targets.is_empty():
		await msg("But there was no target...", 0.6)
		return
	for t in targets:
		if result != "" or b.hp <= 0:
			return
		await _apply_move(b, t, mv, m)


func _targets_for(b, m: Dictionary, target) -> Array:
	var mine := _mine(b)
	var theirs := _theirs(b)
	var fx: Dictionary = m.get("fx", {})
	match m["target"]:
		"self":
			return [b]
		"enemy":
			var t = target if typeof(target) != TYPE_STRING else null
			if not fx.get("pierce", false):
				for x in _alive(theirs):
					if int(_st(x)["taunt"]) > 0:
						t = x
						break
			if t == null or t.hp <= 0 or not theirs.has(t):
				var alive := _alive(theirs)
				if alive.is_empty():
					return []
				t = alive.pick_random()
			return [t]
		"enemies":
			return _alive(theirs)
		"ally":
			var t2 = target
			if t2 == null or t2.hp <= 0 or not mine.has(t2):
				var alive2 := _alive(mine)
				if alive2.is_empty():
					return []
				alive2.sort_custom(func(x, y): return x.hp_ratio() < y.hp_ratio())
				t2 = alive2[0]
			return [t2]
		"allies":
			return _alive(mine)
		"ally_ko":
			if target != null and target.hp <= 0:
				return [target]
			return []
	return []


func _hit_check(a, t, m: Dictionary) -> bool:
	if tutorial:
		return true
	var fx: Dictionary = m.get("fx", {})
	if _st(t)["vanish"] and not fx.get("ignore_eva", false):
		return false
	if fx.get("ignore_eva", false):
		return true
	var acc := float(m.get("acc", 100)) / 100.0
	acc *= _acc_mult(int(_st(a)["stages"]["acc"])) / _acc_mult(int(_st(t)["stages"]["eva"]))
	if a.status == "blind":
		acc *= 0.6
	if t.passives.has("Slippery"):
		acc *= 0.9
	if "air" in t.elements():
		acc *= 0.95
	return randf() < acc


func _apply_move(a, t, mv: String, m: Dictionary) -> void:
	var fx: Dictionary = m.get("fx", {})
	var trick := 1.5 if a.passives.has("Trickster") else 1.0
	match m["kind"]:
		"attack":
			if not _hit_check(a, t, m):
				Sfx.play("miss")
				_float_text(t, "Miss", Color.WHITE)
				await msg("%s avoided the attack!" % t.nickname if _st(t)["vanish"] else "The attack missed %s!" % t.nickname, 0.7)
				return
			var r := _calc_damage(a, t, m)
			var dealt: int = await _deal(a, t, r)
			if t.hp > 0 and fx.has("status") and randf() < float(fx.get("chance", 0.0)) * trick:
				await _inflict(t, fx["status"])
			if t.hp > 0 and fx.has("debuff") and randf() < float(fx.get("chance", 1.0)):
				await _buff(t, fx["debuff"])
			if fx.has("drain") and a.hp > 0 and dealt > 0:
				if a.status == "haunt":
					await msg("The curse stops %s from draining life!" % a.nickname, 0.6)
				else:
					var h := maxi(1, int(dealt * float(fx["drain"])))
					a.hp = mini(a.max_hp(), a.hp + h)
					_float_text(a, "+%d" % h, Color("#70ff90"))
					_refresh()
					await msg("%s drained %d HP!" % [a.nickname, h], 0.6)
			if fx.has("recoil") and dealt > 0:
				var rc := _spare(a, maxi(1, int(dealt * float(fx["recoil"]))))
				a.hp = maxi(0, a.hp - rc)
				_float_text(a, "-%d" % rc, Color("#ff9070"))
				_refresh()
				await msg("%s is hurt by recoil!" % a.nickname, 0.6)
			if fx.has("self_buff"):
				await _buff(a, fx["self_buff"])
		"heal":
			await _heal(a, t, float(fx.get("heal_pct", 0.25)))
			if fx.has("self_buff"):
				await _buff(a, fx["self_buff"])
		"buff":
			if fx.has("buff"):
				await _buff(t, fx["buff"])
			if fx.has("self_buff"):
				await _buff(t, fx["self_buff"])
			if fx.has("regen"):
				_st(t)["regen"] = int(fx["regen"])
				Sfx.play("heal")
				_refresh()
				await msg("%s is wrapped in a soothing veil." % t.nickname, 0.7)
			if fx.has("counter"):
				_st(t)["counter"] = int(fx["counter"])
				_refresh()
				await msg("%s bristles with thorns!" % t.nickname, 0.7)
			if fx.has("wraith"):
				_st(t)["wraith"] = int(fx["wraith"])
				t.status = ""
				_refresh()
				await msg("%s fades into a wraith!" % t.nickname, 0.7)
		"debuff":
			if not _hit_check(a, t, m):
				await msg("%s wasn't affected." % t.nickname, 0.6)
				return
			if fx.has("debuff"):
				await _buff(t, fx["debuff"])
			if fx.has("status") and randf() < float(fx.get("chance", 1.0)) * trick:
				await _inflict(t, fx["status"])
		"status":
			if not _hit_check(a, t, m):
				Sfx.play("miss")
				await msg("It missed %s!" % t.nickname, 0.6)
				return
			await _inflict(t, fx["status"], true)
		"shield":
			var amt := int(t.max_hp() * float(fx.get("shield_pct", 0.2)))
			_st(t)["shield"] = int(_st(t)["shield"]) + amt
			Sfx.play("buff")
			_refresh()
			await msg("A stone shield guards %s! (%d)" % [t.nickname, amt], 0.7)
		"taunt":
			_st(a)["taunt"] = int(fx.get("taunt", 2))
			Sfx.play("buff")
			_refresh()
			await msg("%s draws all the foes' attention!" % a.nickname, 0.7)
			if fx.has("self_buff"):
				await _buff(a, fx["self_buff"])
		"revive":
			if t.hp > 0:
				await msg("But it failed!", 0.6)
				return
			t.hp = maxi(1, int(t.max_hp() * float(fx.get("revive_pct", 0.3))))
			var side_t := _team(a)
			st.erase(t)
			_st(t)["side"] = side_t
			Sfx.play("heal")
			_field_revived(t)
			_refresh()
			await msg("%s was revived!" % t.nickname)
		"cleanse":
			t.status = ""
			await _heal(a, t, float(fx.get("heal_pct", 0.1)))
			_refresh()
			await msg("%s feels refreshed." % t.nickname, 0.6)
		"special":
			if fx.get("vanish", false):
				_st(a)["vanish"] = true
				Sfx.play("buff")
				await msg("%s vanished on the wind!" % a.nickname, 0.7)


func _calc_damage(a, t, m: Dictionary) -> Dictionary:
	var atk := _eff_stat(a, "atk")
	var df := _eff_stat(t, "def")
	var lvl: float = a.level
	var base := ((2.0 * lvl / 5.0 + 2.0) * float(m["power"]) * atk / maxf(1.0, df)) / 50.0 + 2.0
	var stab := 1.25 if m["el"] == _fight_el(a) else 1.0
	var eff := Elements.multiplier(m["el"], _guard_el(t))
	var crit := randf() < 0.0625 + float(m.get("fx", {}).get("crit", 0.0))
	var dmg := base * stab * eff * randf_range(0.85, 1.0) * (1.5 if crit else 1.0)
	if a.passives.has("Blaze") and a.hp_ratio() < 0.34:
		dmg *= 1.3
	dmg *= 1.0 + float(a.gear_fx("boost_" + m["el"], 0.0))
	if t.passives.has("Thick Hide"):
		dmg *= 0.85
	if t.passives.has("Rock Skin") and int(m["power"]) >= 80:
		dmg *= 0.75
	if m["el"] == "ghost":
		dmg *= 1.0 - float(t.gear_fx("ghost_resist", 0.0))
	return {"dmg": maxi(1, int(dmg)), "eff": eff, "crit": crit, "pierce": m.get("fx", {}).get("pierce", false)}


## `a` is the attacker beast, or null for the trainer's slingshot and bombs.
func _deal(a, t, r: Dictionary) -> int:
	var s := _st(t)
	var dmg: int = r["dmg"]
	if tutorial:
		dmg = _tut_damage(a, t)
		r["crit"] = false
	if s["defend"] and dmg > 0:
		dmg = maxi(1, int(ceil(dmg * DEFEND_MULT))) if not tutorial else dmg
	var absorbed := 0
	if int(s["shield"]) > 0 and not r["pierce"]:
		absorbed = mini(int(s["shield"]), dmg)
		s["shield"] = int(s["shield"]) - absorbed
		dmg -= absorbed
	var sturdy := false
	if not tutorial and t.passives.has("Sturdy") and not s["sturdy"] and t.hp == t.max_hp() and dmg >= t.hp:
		dmg = t.hp - 1
		s["sturdy"] = true
		sturdy = true
	t.hp = maxi(0, t.hp - dmg)
	if r["crit"]:
		Sfx.play("crit")
	elif t.genes.has("model"):
		Sfx.play("metal_hit", 0.1)
	else:
		Sfx.play("hit", 0.1)
	_hit_fx(t, r["crit"])
	_float_text(t, "-%d" % dmg if dmg > 0 else "0", Color("#ffe060") if r["eff"] > 1.0 else Color("#ffffff"))
	_refresh()
	if r["crit"]:
		await msg("A critical hit!", 0.55, a)
	if r["eff"] > 1.0:
		await msg("Extra effective!", 0.6, t)
	elif r["eff"] < 1.0:
		await msg("%s is resistant." % t.nickname, 0.6, t)
	if absorbed > 0:
		await msg("The shield absorbed %d damage." % absorbed, 0.55, t)
	if sturdy:
		await msg("%s endured the hit thanks to Sturdy!" % t.nickname, 0.8)
	if t.hp > 0 and t.status == "sleep" and randf() < 0.3:
		t.status = ""
		_refresh()
		await msg("%s woke up!" % t.nickname, 0.6)
	if a != null and dmg > 0 and a != t and a.hp > 0:
		var refl := float(t.gear_fx("thorns", 0.0))
		if int(s["counter"]) > 0:
			refl += 0.3
		if refl > 0.0:
			var rd := _spare(a, maxi(1, int(dmg * refl)))
			a.hp = maxi(0, a.hp - rd)
			_float_text(a, "-%d" % rd, Color("#ff9070"))
			_refresh()
			await msg("%s is hurt by the thorns!" % a.nickname, 0.6)
	if t.passives.has("Fury") and t.hp > 0 and randf() < 0.3:
		await _buff(t, {"atk": 1})
	return dmg


func _heal(healer, t, pct: float) -> void:
	if t.hp <= 0:
		return
	if t.status == "haunt":
		await msg("%s is haunted and can't be healed!" % t.nickname, 0.7)
		return
	var mult := 1.0
	if healer.passives.has("Healing Tide"):
		mult += 0.25
	mult += float(healer.gear_fx("heal_boost", 0.0))
	var amt := maxi(1, int(t.max_hp() * pct * mult))
	var before: int = t.hp
	t.hp = mini(t.max_hp(), t.hp + amt)
	Sfx.play("heal")
	_float_text(t, "+%d" % (t.hp - before), Color("#70ff90"))
	_refresh()
	await msg("%s recovered %d HP." % [t.nickname, t.hp - before], 0.65)


func _buff(t, changes: Dictionary, quiet_fail := false) -> void:
	if t.hp <= 0:
		return
	var stages: Dictionary = _st(t)["stages"]
	for k in changes:
		var v: int = int(changes[k])
		var before: int = stages.get(k, 0)
		stages[k] = clampi(before + v, -3, 3)
		var name: String = STAGE_NAMES.get(k, k)
		if stages[k] == before:
			if not quiet_fail:
				await msg("%s's %s won't go any %s!" % [t.nickname, name, "higher" if v > 0 else "lower"], 0.55)
			continue
		Sfx.play("buff" if v > 0 else "debuff")
		_refresh()
		var how := ("sharply rose" if v >= 2 else "rose") if v > 0 else ("harshly fell" if v <= -2 else "fell")
		await msg("%s's %s %s!" % [t.nickname, name, how], 0.6)


func _inflict(t, status: String, announce := false) -> void:
	if t.hp <= 0 or (tutorial and _st(t)["side"] == "ally"):
		return
	if t.status != "":
		if announce:
			await msg("But %s is already %s!" % [t.nickname, MoveDB.STATUS_NAMES.get(t.status, t.status).to_lower()], 0.6)
		return
	if (t.passives.has("Phantom") and status != "haunt") or int(_st(t)["wraith"]) > 0:
		if announce:
			await msg("%s is unaffected!" % t.nickname, 0.6)
		return
	if t.passives.has("Purity") and status in ["burn", "poison"]:
		if announce:
			await msg("%s's Purity protects it!" % t.nickname, 0.6)
		return
	t.status = status
	var turns := {"sleep": randi_range(1, 3), "confuse": randi_range(2, 4), "fear": 2, "blind": 3, "shock": 3,
		"burn": 4, "poison": 5, "haunt": 4, "stun": 1}
	t.status_turns = int(turns.get(status, 3))
	Sfx.play("debuff")
	_refresh()
	var texts := {"burn": "%s was burned!", "poison": "%s was poisoned!", "sleep": "%s fell asleep!",
		"shock": "%s is paralyzed!", "blind": "%s was blinded!", "confuse": "%s became confused!",
		"fear": "%s is terrified!", "stun": "%s was stunned!", "haunt": "%s is haunted by a curse!"}
	await msg(texts.get(status, "%s is affected!") % t.nickname, 0.7)


func _end_round() -> void:
	for b in _all_active():
		var s := _st(b)
		var mx: int = b.max_hp()
		match b.status:
			"burn":
				await _tick_damage(b, maxi(1, mx / 16), "%s is hurt by its burn!")
			"poison":
				await _tick_damage(b, maxi(1, mx / 10), "%s is hurt by poison!")
			"haunt":
				await _tick_damage(b, maxi(1, mx / 8), "The curse saps %s's life!")
		if b.hp > 0 and b.status != "haunt":
			var h := 0
			if int(s["regen"]) > 0:
				h += maxi(1, mx / 8)
			if b.passives.has("Regenerate"):
				h += maxi(1, mx / 16)
			if h > 0 and b.hp < mx:
				b.hp = mini(mx, b.hp + h)
				_float_text(b, "+%d" % h, Color("#70ff90"))
				_refresh()
				await msg("%s regenerated some HP." % b.nickname, 0.5)
		if b.status in ["burn", "poison", "haunt", "blind", "shock", "confuse", "fear"]:
			b.status_turns -= 1
			if b.status_turns <= 0 and b.hp > 0:
				var old: String = MoveDB.STATUS_NAMES.get(b.status, b.status)
				b.status = ""
				_refresh()
				await msg("%s is no longer %s." % [b.nickname, old.to_lower()], 0.55)
		for k in ["taunt", "counter", "regen", "wraith"]:
			s[k] = maxi(0, int(s[k]) - 1)
		s["vanish"] = false
		var cds: Dictionary = s["cd"]
		for mv in cds.keys():
			cds[mv] = int(cds[mv]) - 1
			if cds[mv] <= 0:
				cds.erase(mv)
	_refresh()
	await _handle_faints()
	_check_end()


func _tick_damage(b, d: int, text: String) -> void:
	d = _spare(b, d)
	b.hp = maxi(0, b.hp - d)
	_hit_fx(b, false)
	_float_text(b, "-%d" % d, Color("#c080ff"))
	_refresh()
	await msg(text % b.nickname, 0.6)


# ================================================================ temple guardians and summons
## A guardian's HP share at or below which its temple's song can win it over.
const GUARDIAN_CAPTURE_HP := 0.6


## The song that captures this battle's guardian ("" outside a guardian battle).
func _guardian_song() -> String:
	return String(WorldDB.TEMPLES[guardian_tk]["song"]) if guardian_tk != "" else ""


## A guardian worn down to nothing rises again: it can only be captured.
func _guardian_rises(b) -> void:
	b.hp = maxi(1, int(b.max_hp() * 0.3))
	Sfx.play("growl")
	if nodes.has(b):
		_hit_fx(b, true)
	_float_text(b, "RISES", Color(String(WorldDB.TEMPLES[guardian_tk]["glow"])))
	_refresh()
	await msg("%s won't fall! It rises again, its strength fading..." % b.nickname, 1.0)
	if GameState.knows_song(_guardian_song()):
		await msg("Now's your chance: play the %s!" % SongDB.song_name(_guardian_song()), 0.9)


func _guardian_song_flow(song: String) -> bool:
	flute_used = true
	await msg("You raise your flute and play the %s to %s..." % [SongDB.song_name(song), guardian_b.nickname], 0.8)
	var r: Dictionary = await UI.flute_ex(song, "Winning over %s  —  the cleaner you play, the surer it is" % guardian_b.nickname)
	_battle_music()
	var acc := float(r["acc"])
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _song_fx(PLAYER_POS, [guardian_b], true, acc < SongDB.FLAT_ACCURACY)
	await _guardian_capture(acc)
	if star and result == "":
		UI.toast("Your mastery of the %s improved!" % SongDB.song_name(song), UIKit.GOLD)
	return true


## The temple's song reaches the guardian: a weakened guardian that hears it well is captured, ending the battle.
func _guardian_capture(acc: float) -> void:
	var t = guardian_b
	if t == null or t.hp <= 0:
		return
	await _note_effect(t)
	var chance := 0.0
	if acc >= SongDB.FLAT_ACCURACY and t.hp_ratio() <= GUARDIAN_CAPTURE_HP:
		chance = clampf(0.55 + acc * 0.35 + (GUARDIAN_CAPTURE_HP - t.hp_ratio()) * 0.8, 0.0, 1.0)
	if randf() >= chance:
		Sfx.play("fail")
		if acc < SongDB.FLAT_ACCURACY:
			await msg("The song falls apart, and %s roars over it!" % t.nickname, 1.1)
		else:
			await msg("%s shakes its head... It isn't won over yet! (%d%% chance)" % [t.nickname, int(chance * 100)], 1.2)
		return
	var glow := Color(String(WorldDB.TEMPLES[guardian_tk]["glow"]))
	Sfx.play("capture")
	await msg("The %s fills the hall. %s lowers its great head..." % [SongDB.song_name(_guardian_song()), t.nickname], 1.2)
	if nodes.has(t):
		var n: Node3D = nodes[t]
		var fx := SummonFX.new()
		add_child(fx)
		fx.setup(self, guardian_tk, n.position, _toward("foe"), [])
		fx._ring_burst(n.position + Vector3(0, 0.1, 0), glow, 6.0, 0.8)
		fx._particles(n.position + Vector3(0, 1.0, 0), Color.WHITE, glow, 120, 1.2, Vector2(1.0, 4.0), 0.3,
			{"spread": 180.0, "radius": 1.2, "gravity": Vector3(0, 3.0, 0)})
		var tw := create_tween()
		tw.tween_property(n, "scale", n.scale * 1.15, 0.2)
		tw.tween_property(n, "scale", Vector3(0.02, 0.02, 0.02), 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(n.hide)
		var lt := create_tween()
		lt.tween_interval(2.0)
		lt.tween_callback(fx.queue_free)
	UI.flash(glow, 2)
	await get_tree().create_timer(0.7).timeout
	var slot := foe_slots.find(t)
	if slot >= 0:
		foe_slots[slot] = null
	foes.erase(t)
	if not GameState.summons.has(guardian_tk):
		GameState.summons.append(guardian_tk)
	GameState.set_flag("guardian_" + guardian_tk)
	GameState.mark_seen(t)
	await msg("%s is yours! You can summon it in battle now." % t.nickname, 1.2)
	await _award_xp(t)
	_refresh()
	result = "win"


## Choosing Summon: pick one of your summons, play its song, and (if it answers) it comes first this round.
## Returns the action, {"type": "none"} if the song failed (your turn is spent), or {} if you backed out.
func _summon_flow() -> Dictionary:
	var ids := []
	var items := []
	for tk in WorldDB.TEMPLES:
		if not GameState.summons.has(tk):
			continue
		var t: Dictionary = WorldDB.TEMPLES[tk]
		var sid: String = t["song"]
		ids.append(tk)
		items.append({"text": RaceDB.race_name(int(t["guardian"])), "right": String(t["element"]).to_upper(),
			"desc": "Play the %s to call it. It strikes every foe at once: hard, and harder still where its element is strong.\nOnce per battle, for one shield point." % SongDB.song_name(sid)})
	if ids.is_empty():
		return {}
	var c := 0
	if ids.size() > 1:
		c = await UI.choose("Call which summon?", items, {"anchor": "bottom_right", "width": 460, "margin": Vector2(20, 20), "font_size": 28})
		if c < 0:
			return {}
	var tk: String = ids[c]
	var song: String = WorldDB.TEMPLES[tk]["song"]
	var who := RaceDB.race_name(int(WorldDB.TEMPLES[tk]["guardian"]))
	await msg("You raise your flute and play the %s..." % SongDB.song_name(song), 0.7)
	var r: Dictionary = await UI.flute_ex(song, "Summoning %s  —  play its song through to call it" % who)
	_battle_music()
	var acc := float(r["acc"])
	GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	# the song goes out to the foes the summon will strike
	await _song_fx(PLAYER_POS, _alive(foe_slots), true, acc < SongDB.FLAT_ACCURACY)
	if acc < SongDB.FLAT_ACCURACY:
		Sfx.play("fail")
		await msg("The song falters... %s doesn't answer." % who, 1.1)
		return {"type": "none"}
	summoned = true
	GameState.shield -= 1
	Sfx.play("shield")
	_shield_pulse(shield_bubble)
	_update_shield()
	_refresh()
	await msg("%s hears your call! (one shield point spent)" % who, 0.9)
	return {"type": "summon", "el": tk, "acc": acc, "prio": 11}


## The summon arrives beside the foes and strikes every one of them for about half its HP (more where its element is
## strong, a little more for a better performance). Bosses' beasts and guardians are left standing.
func _do_summon(a: Dictionary) -> void:
	var tk: String = a["el"]
	var acc := float(a.get("acc", 0.9))
	var t: Dictionary = WorldDB.TEMPLES[tk]
	var who := RaceDB.race_name(int(t["guardian"]))
	var targets := _alive(foe_slots)
	if targets.is_empty():
		return
	var hits := []
	for f in targets:
		hits.append(_target_point(f))
	# it looms up behind the foes, facing them and you
	var d := _toward("ally")
	var where := FOE_CENTER + d * (3.8 if guardian_tk != "" else 2.2)
	var fx := SummonFX.new()
	add_child(fx)
	fx.setup(self, tk, where, -d, hits)
	await msg("%s answers your song!" % who, 0.4)
	await fx.arrive()
	var landed := [false]
	var strike := func() -> void:
		landed[0] = true
	await fx.attack(strike)
	var el: String = t["element"]
	for f in targets:
		if f.hp <= 0 or not _active(f):
			continue
		var eff := Elements.multiplier(el, _guard_el(f))
		var dmg := maxi(1, int(f.max_hp() * 0.5 * (0.8 + 0.2 * acc) * eff * randf_range(0.95, 1.05)))
		if is_boss() or f == guardian_b:
			dmg = mini(dmg, f.hp - 1)
		await _deal(null, f, {"dmg": maxi(0, dmg), "eff": eff, "crit": false, "pierce": true})
	await fx.leave()


## The summon's camera: pulled back and lifted so the summon at `at` and the foes are both in shot.
func summon_cam(at: Vector3, size: float) -> void:
	var back := (_cam_pos() - _cam_look()).normalized()
	summon_look = FOE_CENTER.lerp(at, 0.45) + Vector3(0, 1.3 + minf(size, 7.0) * 0.14, 0)
	summon_pos = summon_look + back * (13.5 + minf(size, 8.0) * 1.5)
	var tw := create_tween()
	tw.tween_property(self, "summon_mix", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	# a cutscene: the bars and grids step aside while it plays
	for c in [bars, ally_grid, foe_grid]:
		if c != null:
			c.visible = false


func summon_release() -> void:
	var tw := create_tween()
	tw.tween_property(self, "summon_mix", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	for c in [bars, ally_grid, foe_grid]:
		if c != null:
			c.visible = true


func summon_shake(amount: float) -> void:
	summon_shake_amt = maxf(summon_shake_amt, amount)


## Dims the stage's light to `k` of its usual (1 = back to normal).
func summon_dim(k: float) -> void:
	if stage_env == null or _stage_light.is_empty():
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(stage_env, "ambient_light_energy", float(_stage_light[0]) * k, 0.5)
	if stage_sun != null:
		tw.tween_property(stage_sun, "light_energy", float(_stage_light[1]) * k, 0.5)


func summon_flash(c: Color) -> void:
	UI.flash(c, 1)


func _handle_faints() -> void:
	var groups := [["ally", ally_ring.values()], ["foe", foe_ring.values() if not wild else foe_slots.duplicate()]]
	for g in groups:
		var team: String = g[0]
		for b in g[1]:
			if b == null or b.hp > 0:
				continue
			var s := _st(b)
			if s["down"]:
				continue
			if b == guardian_b:
				await _guardian_rises(b)
				continue
			if b.gear_fx("phoenix", false) and not s["phoenix"]:
				s["phoenix"] = true
				b.hp = maxi(1, b.max_hp() / 4)
				Sfx.play("heal")
				_refresh()
				await msg("%s's Phoenix Plume blazes! It rises again!" % b.nickname, 1.0)
				continue
			s["down"] = true
			var beaten_foe: bool = team == "foe"
			# a beaten foe vanishes with a smack in a puff of smoke; your own beast keels over on its pad
			Sfx.play("defeat" if beaten_foe else "faint")
			if nodes.has(b):
				var n: Node3D = nodes[b]
				var tw := create_tween()
				if beaten_foe:
					var h := float(n.get_meta("height"))
					_smoke_puff(n.position + Vector3(0, h * 0.45, 0), clampf(h, 0.8, 2.4))
					tw.tween_property(n, "scale", n.scale * 1.15, 0.06)
					tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.14).set_ease(Tween.EASE_IN)
					tw.tween_callback(n.hide)
				else:
					tw.kill()
					_lie_down(b)
			await msg("%s fainted!" % b.nickname, 0.8)
			if beaten_foe and wild:
				var i := foe_slots.find(b)
				if i >= 0:
					foe_slots[i] = null
				if nodes.has(b):
					nodes[b].queue_free()
					nodes.erase(b)
			_refresh()
			if beaten_foe:
				_roll_egg(b)
				await _award_xp(b)


func _roll_egg(b) -> void:
	if not wild or RaceDB.is_robot(b.race) or RaceDB.is_legendary(b.race):
		return
	if b.ghost and not GameState.flag("ghost_merge"):
		return
	if randf() < EGG_CHANCE:
		# (an egg of its line's first form: a Cinderex leaves an Embit's egg)
		drops.append({"race": RaceDB.first_form(b.race), "ghost": b.ghost, "name": b.nickname})


func _award_xp(foe) -> void:
	var base := RaceDB.xp_yield(foe.race) * float(foe.level) / 8.0
	if not wild:
		base *= 1.5
	if GameState.lucky_battles > 0:
		base *= 1.5
	for b in GameState.party:
		if b.hp <= 0:
			continue
		var share := 1.0 if participants.has(b) else 0.5
		var amt := int(base * share * (1.0 + float(b.gear_fx("xp", 0.0)) + GameState.gear_fx("xp")))
		if lesson.has("level"):
			amt = maxi(0, b.xp_for_level(int(lesson["level"])) - b.xp)
			if amt == 0:
				continue
		if b.level <= 3:
			amt = maxi(amt, 4)
		if b.at_cap():
			continue
		# (called by its old name until it grows into its next form: "Cinderex grew to Lv 40!", "Cinderex grew into
		# Pyrosaur!")
		var who: String = b.nickname
		var events: Array = b.gain_xp(amt)
		for e in events:
			if e["type"] == "evolve":
				who = e["from"]
				break
		if participants.has(b):
			await msg("%s gained %d XP." % [who, amt], 0.5)
		for e in events:
			match e["type"]:
				"level":
					Sfx.play("levelup")
					_refresh()
					await msg("%s grew to Lv %d!" % [who, e["level"]], 0.8)
				"evolve":
					# grown into its line's next form: its new model, in a flash
					_remodel(b)
					Sfx.play("merge")
					who = e["to"]
					GameState.caught[str(b.race)] = true
					GameState.seen[str(b.race)] = true
					await msg("%s grew into %s!" % [e["from"], e["to"]], 1.4)
				"learn":
					var mn: String = MoveDB.get_move(e["move"])["name"]
					if e["active"]:
						await msg("%s learned %s!" % [who, mn], 0.8)
					else:
						await msg("%s can now use %s! Swap it in from the Beasts menu." % [who, mn], 1.1)
				"cap":
					await msg("%s reached its level limit! Merge it at a Beast Center to grow stronger." % who, 1.6)
		if GameState.next_capture_ready() and not GameState.flag("capture_hint_%d" % GameState.capture_level()):
			GameState.set_flag("capture_hint_%d" % GameState.capture_level())
			Sfx.play("notify")
			await msg("%s reached Lv %d! You can now practise %s from the Flute page of your book." % [b.nickname, b.level,
				SongDB.get_song(SongDB.capture_id(GameState.capture_level() + 1))["name"]], 1.8)


## Wild beasts beyond the first three step up as others fall. (Ring battles have no bench: everyone is on the ring.)
func _refill() -> void:
	if not wild:
		return
	for i in 3:
		if foe_slots[i] != null:
			continue
		for f in foes:
			if f.hp > 0 and not foe_slots.has(f):
				foe_slots[i] = f
				_spawn(f, "foe", i)
				_refresh()
				await msg("Another %s joins the fight!" % f.nickname, 0.8)
				break


func _finish() -> void:
	GameState.ring_side = ally_side
	match result:
		"win":
			Sfx.music("victory")
			if not wild:
				if not trainer.get("guardian", false):
					await msg("You defeated %s %s!" % [trainer.get("cls", "Trainer"), trainer.get("name", "")])
				var dl = trainer.get("defeat", "")
				if typeof(dl) == TYPE_STRING and dl != "":
					await msg("%s: \"%s\"" % [trainer.get("name", ""), dl], 1.4)
				var gold: int = trainer.get("reward", 0)
				if gold <= 0:
					for f in foes:
						gold += f.level * 22
				if GameState.lucky_battles > 0:
					gold = int(gold * 1.5)
				GameState.gold += gold
				await msg("You received %d gold." % gold)
				await _trainer_xp()
			if GameState.lucky_battles > 0:
				GameState.lucky_battles -= 1
			if not cfg.get("autoplay", false) or UI.auto:
				for sid in heard_songs:
					if not GameState.knows_song(sid):
						await _learn_heard_song(sid)
		"lose":
			await msg("Everything goes dark...")
			await msg("You were carried to the nearest Beast Center.", 1.2)
		"forfeit":
			await msg("You forfeited the battle.", 0.9)
	if result != "lose":
		for d in drops:
			GameState.add_egg(int(d["race"]), bool(d["ghost"]))
			Sfx.play("capture")
			await msg("%s left something behind... You found a%s %s!" % [d["name"], "n" if GameState.egg_name(GameState.eggs.back()).substr(0, 1) in ["A", "E", "I", "O", "U"] else "", GameState.egg_name(GameState.eggs.back())], 1.3)
	for b in GameState.party:
		b.status = ""
		b.status_turns = 0
	if is_instance_valid(hud):
		hud.queue_free()


## Trainer XP for beating a trainer: their beasts' levels, more for bosses and arena opponents.
func _trainer_xp() -> void:
	if tutorial:
		return
	var xp := 0
	for f in foes:
		xp += int(f.level)
	xp = int(xp * (1.5 if trainer.get("arena", false) else 1.0) * (2.0 if is_boss() else 1.0))
	var before_slots := GameState.slot_cap()
	var before_shield := GameState.shield_cap()
	var gained := GameState.add_trainer_xp(xp)
	await msg("You gained %d trainer XP." % xp, 0.6)
	if gained > 0:
		Sfx.play("levelup")
		await msg("You're now a Lv %d trainer!" % GameState.trainer_level, 1.0)
		if GameState.slot_cap() > before_slots or GameState.shield_cap() > before_shield:
			await msg("Volt at Sparkwire Electronics in Bellerive can now fit you with %s." % ("another beast slot and a shield point" if GameState.slot_cap() > before_slots and GameState.shield_cap() > before_shield
				else ("another beast slot" if GameState.slot_cap() > before_slots else "another shield point")), 1.4)


## How many shield points a rival trainer has: none for the weakest, more for strong trainers and bosses.
func _trainer_shield() -> int:
	if trainer.has("shield"):
		return int(trainer["shield"])
	if tutorial:
		return 0
	var top := 0
	for f in foes:
		top = maxi(top, int(f.level))
	var sh := 0 if top < 12 else (1 if top < 30 else 2)
	if is_boss() or trainer.get("guardian", false):
		sh += 1
	return mini(sh, 4)


# ================================================================ effects
func _lunge(b, attack: bool) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var start := n.position
	var rig := _rig(b)
	if attack and rig != null:
		# its own attack (beast_rig.gd): rearing back, then lunging at the foe, its model leaping that way with it; the
		# move goes on as the blow lands, while it springs back and settles
		rig.attack()
		var h: Node3D = n.get_node("Model")
		var rest := Vector3(0, float(n.get_meta("lift")), 0)
		var hit := Rig.ATTACK_TIME * Rig.HIT_AT
		var lt := create_tween()
		lt.tween_interval(hit * 0.65)
		lt.tween_property(h, "position", rest + n.basis.inverse() * (_toward(_team(b)) * 0.55 + Vector3(0, 0.08, 0)), hit * 0.35).set_ease(Tween.EASE_IN)
		lt.tween_interval(0.1)
		lt.tween_property(h, "position", rest, 0.3).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(hit).timeout
		return
	var tw := create_tween()
	if attack:
		tw.tween_property(n, "position", start + _toward(_team(b)) * 0.65 + Vector3(0, 0.15, 0), 0.1)
		tw.tween_property(n, "position", start, 0.12)
	else:
		tw.tween_property(n, "position", start + Vector3(0, 0.35, 0), 0.12)
		tw.tween_property(n, "position", start, 0.12)
	await tw.finished


func _hit_fx(b, big: bool) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var flash: StandardMaterial3D = n.get_meta("flash")
	var tw := create_tween()
	tw.tween_property(flash, "albedo_color", Color(1, 1, 1, 0.85), 0.05)
	tw.tween_property(flash, "albedo_color", Color(1, 0.3, 0.3, 0.5), 0.08)
	tw.tween_property(flash, "albedo_color", Color(1, 1, 1, 0.0), 0.14)
	var base_x := n.position.x
	var tw2 := create_tween()
	for i in 4:
		tw2.tween_property(n, "position:x", base_x + (0.12 if i % 2 == 0 else -0.12) * (1.6 if big else 1.0), 0.04)
	tw2.tween_property(n, "position:x", base_x, 0.04)


## A cloud of soft grey voxel puffs that swell, drift up and fade (a beaten foe vanishing). `size` ~ the beast's height.
func _smoke_puff(pos: Vector3, size: float) -> void:
	for layer in 2:
		var p := CPUParticles3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * (0.5 if layer == 0 else 0.24) * size
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		cube.material = mat
		p.mesh = cube
		p.amount = 22 if layer == 0 else 16
		p.one_shot = true
		p.explosiveness = 0.92
		p.lifetime = 0.8 if layer == 0 else 0.6
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.4 * size
		p.spread = 180.0
		p.initial_velocity_min = 0.5 * size
		p.initial_velocity_max = (1.6 if layer == 0 else 2.4) * size
		p.damping_min = 2.0
		p.damping_max = 3.0
		p.gravity = Vector3(0, 0.7, 0)
		p.angular_velocity_min = -180.0
		p.angular_velocity_max = 180.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.45))
		grow.add_point(Vector2(0.35, 1.0))
		grow.add_point(Vector2(1.0, 1.15))
		p.scale_amount_curve = grow
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.95))
		fade.set_color(1, Color(0.72, 0.72, 0.78, 0.0))
		fade.add_point(0.45, Color(0.9, 0.9, 0.93, 0.85))
		p.color_ramp = fade
		p.position = pos
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _float_text(b, text: String, col: Color) -> void:
	if OS.has_feature("editor") and "--battle-log" in OS.get_cmdline_user_args():
		print("  |   %s %s (HP %d/%d)" % [b.nickname, text, b.hp, b.max_hp()])
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var l := Label3D.new()
	l.text = text
	# damage and healing numbers in the chunky pixel font
	l.font = UIKit.font_body()
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.font_size = 64
	l.outline_size = 14
	l.modulate = col
	l.pixel_size = 0.009
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = n.position + Vector3(0, float(n.get_meta("height")) + 0.1, 0.3)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)
