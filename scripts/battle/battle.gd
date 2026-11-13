extends Node3D
## Turn-based ring battle (as in Jade Cocoon 2). Each trainer stands in the middle of a ring of eight slots (ring.gd):
## a side per element, with corners between. One side faces the foe: its three beasts fight, using only that side's
## element (and plain, neutral moves). At the start of each turn a trainer may turn the ring to another side with a
## beast standing on it. You choose your own action, then a move for each of your three beasts (command_panel.gd,
## in the floating menu beside the outlined 3D actor); then the two sides take their turns, the faster side first (its beasts' speed and
## its trainer's level). The foe's choices are never shown: they happen on its turn.
## If a side's middle beast is down (or its middle slot is empty), its trainer can be attacked directly: each hit
## breaks a shield point, and a hit with no shield left loses the battle. A trainer battle ends only that way, or
## when someone forfeits. Wild beasts have no ring and no trainer: beat them all to win.
## Fire = offense tanks, Water = healers, Earth = defenders, Air = status/evasion, Ghost = Legion.

signal finished(result: String)

const Beasts = preload("res://scripts/core/beasts.gd")
const OutdoorLight = preload("res://scripts/gfx/outdoor_light.gd")
const WaterShader = preload("res://scripts/gfx/water.gdshader")
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
const CastGlow = preload("res://scripts/gfx/cast_glow.gd")
const Rig = preload("res://scripts/gfx/beast_rig.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Ring = preload("res://scripts/core/ring.gd")
const CommandPanel = preload("res://scripts/battle/command_panel.gd")
const FloatingHUD = preload("res://scripts/battle/floating_hud.gd")
const Outline = preload("res://scripts/battle/selection_outline.gdshader")
const TargetArrow = preload("res://scripts/battle/target_arrow.gd")
const ActionIcons = preload("res://scripts/battle/action_icons.gd")
const Backdrop = preload("res://scripts/battle/backdrop.gd")
const BattleCamera = preload("res://scripts/battle/battle_camera.gd")
const StageLighting = preload("res://scripts/battle/stage_lighting.gd")
const StageDressing = preload("res://scripts/battle/stage_dressing.gd")
const SceneryVisibility = preload("res://scripts/battle/scenery_visibility.gd")
const BeatChain = preload("res://scripts/core/beat_chain.gd")
const BeatCue = preload("res://scripts/battle/beat_cue.gd")
const BattleTutorials = preload("res://scripts/core/battle_tutorials.gd")

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
## The director's wide summon composition, and a shake that dies away.
var summon_pos := Vector3.ZERO
var summon_look := Vector3.ZERO
var summon_shake_amt := 0.0
var stage_env: Environment
var surround: MeshInstance3D
var stage_sun: DirectionalLight3D
var stage_rim: DirectionalLight3D
var _stage_light := []
var round_no := 0
var biome: Dictionary
var indoor := false
var drops: Array = []
## XP is credited for each defeated foe, then applied and presented once the fighting has ended.
var pending_xp := {}
## songs the rival trainer played this battle (song id -> true); you may try to learn them afterwards
var heard_songs := {}
var rival_song_count := 0
## A guided battle (see LESSONS): each round there's one thing to pick on every bar and in every menu (what's being
## taught), and you can't lose: your beasts always keep at least 1 HP, and nobody can run, forfeit or hit you.
var tutorial := false
var lesson_id := ""
var lesson: Dictionary = {}
var rotation_lesson := false
## The guided battles: the Coastal Path's five teachers, met before you have a flute (Story.LESSON_TRAINERS), and your
## first lone wild beast after Uncle Rafe's lessons ("flute"). intro: what the teacher says before the first round
## (narration: a line before that, with no speaker; coach: who's speaking, if not the trainer). rounds: in turn (the
## last repeats), what the teacher says ({beast} is your beast, {foe} theirs), your own action ("you": Slingshot,
## Watch, Items or Flute, with "song": weaken), your beast's ("beast": Fight or Defend; "target":
## "trainer" sends it at the trainer). finish: the round the foe's beast goes down (0 never). trainer: the battle
## ends by striking the trainer rather than when their beasts are down. level: the level your beast reaches.
const LESSONS := {
	"rhythm": {"finish": 2,
		"intro": ["Dancing and weapon attacks share a secret: timing. We'll practise safely, then try your slingshot to the music."],
		"rounds": [
			{"say": ["Choose Slingshot, then its target. When the ring appears, press A on each beat as the notch meets the top mark. Your beasts will Defend."], "you": "Slingshot", "beast": "Defend"},
			{"say": ["Once more! Good and Perfect hits count. A miss ends the chain, but your earlier hits still land."], "you": "Slingshot", "beast": "Fight"},
		]},
	"summon": {"finish": 2,
		"intro": ["Abyssion answers your flute now. Let's try calling the water dragon together!",
			"Choose Summon beside your trainer, then play Abyssion's song. It strikes every foe at once.",
			"A summon costs one shield point and can answer only once per battle. I'll lend you a practice shield today."],
		"rounds": [
			{"say": ["Choose Summon, then play the song through. Your beasts will Defend while you practise."], "you": "Summon", "beast": "Defend"},
			{"say": ["There it is! A better performance makes the summon stronger. Save that shield point for when you need it.", "Now Watch and let your beasts finish our practice battle."], "you": "Watch", "beast": "Fight"},
		]},
	"screen": {"level": 2, "finish": 2,
		"intro": ["Let's learn a battle together! You're in the near ring; I'm in the far one.",
			"Lit pads show the side that fights. Empty pads stay dim; fainted beasts lie down.",
			"An outline shows who is choosing. HP is health; MP powers elemental attacks. Flashing MP is the cost.",
			"Pick your own action first, then each beast's. Left/right changes a choice, A chooses it, B goes back.",
			"Then aim left/right and A confirms. With touch, tap a foe to aim and tap it again to confirm.",
			"Lessons give you one choice at a time. Let's try it!"],
		"rounds": [
			{"say": ["This round you just Watch, and {beast} Fights with its best move.", "Pick Watch beside your trainer, then the move beside {beast}."],
				"you": "Watch", "beast": "Fight"},
			{"say": ["Nice hit! The number that popped up is the damage it did. Once more to finish my {foe}!"], "you": "Watch", "beast": "Fight"},
		]},
	"turns": {"level": 3, "finish": 3,
		"intro": ["Battles go in rounds, like the tide. Everybody picks what they'll do first, then the two sides take their turns.",
			"The side with the faster beasts goes first, and a higher trainer level helps too. I'll let you go first today. The fish can wait."],
		"rounds": [
			{"say": ["Uh oh, my {foe} is winding up something big!", "When a big hit is coming, Defend: a defending beast takes half damage until your side's next turn, and Defend always goes first.",
				"Watch beside your trainer, then Defend beside {beast}."], "you": "Watch", "beast": "Defend"},
			{"say": ["Barely a scratch! Now strike back.", "Elemental moves cost MP, but plain moves are free, so you can always fight."], "you": "Watch", "beast": "Fight"},
			{"say": ["Once more, with feeling!"], "you": "Watch", "beast": "Fight"},
		]},
	"slingshot": {"level": 3, "finish": 2,
		"intro": ["You're not just a spectator, you know! You get a turn too: you choose your own action first.",
			"Slingshot flings a pebble at a foe. Watch lets your beasts handle it. Items patch someone up. Once you have a flute, you can play songs.",
			"Run gets you out of a wild battle. Against a trainer it's Forfeit: it counts as a loss, but nobody holds a grudge. Except my cousin."],
		"rounds": [
			{"say": ["Fire your slingshot at my {foe}! On your side's turn your own action goes first, before your beasts move."], "you": "Slingshot", "beast": "Fight"},
			{"say": ["Pew! Again, both of you together!",
				"Seasoned trainers fire in time with the battle music and land a whole string of hits. You'll get there!"], "you": "Slingshot", "beast": "Fight"},
		]},
	"items": {"level": 4, "finish": 3,
		"intro": ["Picnic rule number one: never battle hungry. Rule number two: always, ALWAYS pack potions."],
		"rounds": [
			{"say": ["Warm-up round! You Watch, {beast} Fights."], "you": "Watch", "beast": "Fight"},
			{"say": ["Ouch, {beast} got nipped! Open Items beside your trainer and give it a Minor Potion.",
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
				"Every hit on a trainer breaks one of their shield points: the orbs beside them when you aim at them or land a hit. A trainer hit with no shield left loses the battle. I've got none today."],
				"you": "Watch", "beast": "Fight", "target": "trainer"},
		]},
	# Bellerive's arena coaches (story.gd ARENA_LESSONS). practice: the arena's practice beasts fill the empty slots of
	# the side facing the foe (and the coach's "practice_side" turns your ring to that side first), see _practice_beasts
	"team": {"finish": 2, "practice": true,
		"intro": ["In a real battle, every beast on the side of your ring facing the foe fights: up to three at once, each choosing its own move.",
			"The arena's practice beasts will stand in your empty slots today. They're very professional. They've been bonked by the best.",
			"After your own action, each beast's menu opens in turn. Up and down move between your beasts; left and right pick a move."],
		"rounds": [
			{"say": ["Pick a move for every one of your beasts. Today they all go for the same one of mine: in a real battle, the arrows show who each move is aimed at."], "you": "Watch", "beast": "Fight"},
			{"say": ["Teamwork! Two beasts on the same foe knock it out twice as fast. Finish my team!"], "you": "Watch", "beast": "Fight"},
		]},
	"elements": {"finish": 2, "practice": true,
		"intro": ["Every element has a weakness: fire beasts are weak to air, earth to water, water to air, and air to fire.",
			"Hit a beast with the element it's weak to and it takes double damage! Hit it with its own element, though, and it shrugs some off.",
			"As you aim, a red burst beside a foe's name means it's weak to that attack; a shield means it resists. Only the element of the side facing the foe can be used: turn your ring to the side that hits hardest. Today I've turned it for you."],
		"rounds": [
			{"say": ["My {foe} is weak to the element of your side. Pick the elemental move and watch it fly!"], "you": "Watch", "beast": "Fight"},
			{"say": ["Double damage! Finish it the same way. And remember: your beasts have weaknesses too."], "you": "Watch", "beast": "Fight"},
		]},
	# (egg: the beaten beast always leaves one, so the first egg found on the road is part of the lesson)
	"flute": {"finish": 2, "coach": "Uncle Rafe", "egg": true,
		"narration": "A wild {foe}! Uncle Rafe's advice comes back to you...",
		"intro": ["\"A wild beast's your chance to put that flute to work. Songs change how a fight goes. Weaken, for one, makes a foe drop its guard so your beasts hit harder.\""],
		"rounds": [
			{"say": ["\"Open Flute beside your trainer and play Weaken at it. Your beast can Fight in the meantime.\""],
				"you": "Flute", "song": "weaken", "beast": "Fight"},
			{"say": ["\"See it flinch? Now finish it. No song makes a wild beast yours: new beasts only ever come from eggs.\"",
				"\"Beat one and now and then it leaves an egg behind. Watch this round, and let {beast} Fight.\""],
				"you": "Watch", "beast": "Fight"},
		]},
}
## Defending halves the damage a beast takes until its side's next turn.
const DEFEND_MULT := 0.5

var cam: Camera3D
var camera_director: RefCounted
var scenery_visibility: RefCounted
## The original arcing arrow connects the attacker to every selected target.
var aim_mesh: MeshInstance3D
var _aim_geometry: Array = []
var _aim_from = null
## the option being aimed while a target is picked (see target_mark)
var _aim_option := {}
var _target_refs: Array = []
var _time := 0.0
var player_rig: Node3D
var rival_rig: Node3D
var _acting_ref = null
var shield_bubble: MeshInstance3D

var hud: Control
## Anchored choices and brief health changes; battle messages use UI.top_bar.
var floating: Control
var _selected_refs: Array = []
## hull outlines of selected ring pads, by slot
var _outline_mats := {}
var _outline_overlays := {}
var _hp_seen := {}
var _shield_orbs := {}
var _shield_until := {"ally": 0.0, "foe": 0.0}
var _speaker_icons: Dictionary = {}
var _message_subject = null
## whose action has the focus while commands are chosen (its prompt shows in the top bar)
var _prompt_ref = null
## true while the command controller is choosing actions
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
	scenery_visibility = SceneryVisibility.new(self)
	_build_stage()
	_build_hud()
	camera_director = BattleCamera.new(self)
	camera_director.play("opening")
	_battle_music()
	_run.call_deferred()


func _battle_music() -> void:
	Sfx.music("boss" if is_boss() else "battle")
	# the percussion layer plays along quietly, louder for a beat attack (_weapon_chain)
	Sfx.percussion("bed")


func _exit_tree() -> void:
	Sfx.percussion("off")
	Sfx.beat_end()


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
	# Perimeter scenery is batched and receives light without adding shadow-map work.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat:
		mi.material_override = mat
	add_child(mi)
	if scenery_visibility != null:
		scenery_visibility.register(mi, xforms)


func _tex_mat(t: Texture2D, uv := Vector2.ONE) -> ShaderMaterial:
	return StageLighting.ground_material(t, uv, biome)


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
	env.ambient_light_color = OutdoorLight.ambient_color(biome, 0.4) if not dark else Color("#a898c8")
	env.ambient_light_energy = OutdoorLight.ambient_energy(biome) + 0.1 if not dark else 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 0.9
	if not dark:
		OutdoorLight.grade(env)
	env.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile"
	env.ssao_intensity = 1.5
	env.fog_enabled = not dark
	env.fog_light_color = Color(biome["sky_hz"])
	env.fog_density = float(biome.get("fog", 0.004))
	env.fog_sky_affect = 0.0
	if dark:
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.15
		env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	stage_env = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(biome["sun"]) if not dark else Color("#d8c8ff")
	sun.light_energy = OutdoorLight.sun_energy(biome) if not dark else 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-50, 30, 0)
	if not dark:
		OutdoorLight.aim(sun)
	stage_rim = StageLighting.apply(env, sun, biome, dark)
	add_child(stage_rim)
	add_child(sun)
	stage_sun = sun
	_stage_light = [env.ambient_light_energy, sun.light_energy, stage_rim.light_energy]

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
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	ground.material_override = _tex_mat(ground_tex, Vector2(80, 80))
	if not fishing and not arena and not dark and not sandy:
		ground.mesh = StageLighting.grass_floor()
		var ground_material := ground.material_override as ShaderMaterial
		ground_material.set_shader_parameter("grass_patches", true)
		ground_material.set_shader_parameter("dirt_texture", VT.terrain("top_path", biome["path"]))
	ground.position = Vector3(0, 0, 1.5) if not fishing else Vector3(0, -0.6, -10)
	add_child(ground)
	if not dark:
		surround = Backdrop.build(biome, ground_tex)
		add_child(surround)
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
	StageDressing.build(self, rng)

	cam = Camera3D.new()
	cam.fov = CAM_FOV
	add_child(cam)
	cam.position = _cam_pos()
	cam.look_at(_cam_look(), Vector3.UP)
	cam.current = true
	aim_mesh = MeshInstance3D.new()
	aim_mesh.mesh = ArrayMesh.new()
	aim_mesh.material_override = TargetArrow.material()
	aim_mesh.visible = false
	aim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_mesh)
	# Only the fighters cast shadows; even the dock, rings and wild mound are scenery.
	for geometry in find_children("*", "GeometryInstance3D", true, false):
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
## run anticlockwise seen from above: a side's top slot stands at its front right.
func _psi_for(team: String, side: int) -> float:
	return _facing(team) + deg_to_rad(90.0 * side)


func _slot_pos(team: String, k: int) -> Vector3:
	var a := float(ring_psi[team]) - deg_to_rad(45.0 * k)
	return _center(team) + Vector3(cos(a), 0.0, sin(a)) * RING_R


## The glowing circle and the eight pads of a ring (they turn together; the beasts on them are placed each turn).
func _build_ring(team: String, trainer_dais := true) -> void:
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
	if trainer_dais:
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
const RING_ART := "res://assets/ui/battle/"
static var _baking_art := false


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


## tools/bake_battle_art.gd preserves the exact generated artwork, including mipmaps, as compressed resources.
static func bake_art(verify := false) -> int:
	_baking_art = true
	_circle_tex = null
	_sigils.clear()
	DirAccess.make_dir_recursive_absolute(RING_ART)
	var bad := _baked_texture(_circle_texture(), RING_ART + "circle.res", verify)
	for k in Ring.SLOTS:
		var els := Ring.slot_elements(k)
		bad += _baked_texture(_sigil_texture(els), RING_ART + _sigil_name(els), verify)
	_baking_art = false
	return bad


static func _baked_texture(texture: Texture2D, path: String, verify: bool) -> int:
	if verify:
		var baked: Texture2D = load(path) if ResourceLoader.exists(path) else null
		return int(baked == null or baked.get_image().get_data() != texture.get_image().get_data())
	return int(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) != OK)


static func _sigil_name(els: Array) -> String:
	return "sigil_" + "_".join(els) + ".res"


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
	if not _baking_art and ResourceLoader.exists(RING_ART + _sigil_name(els)):
		_sigils[key] = load(RING_ART + _sigil_name(els))
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
	if not _baking_art and ResourceLoader.exists(RING_ART + "circle.res"):
		_circle_tex = load(RING_ART + "circle.res")
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
		var ring: Dictionary = ally_ring if team == "ally" else foe_ring
		var occupied: bool = ring.get(k, null) != null
		m.emission_energy_multiplier = (1.5 if k in on else 0.3) if occupied else 0.06
		m.albedo_color = Color.WHITE if occupied else Color(0.32, 0.32, 0.32)


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
func _turn_ring(team: String, side: int, player_chosen := false) -> void:
	var from := float(ring_psi[team])
	var to := _psi_for(team, side)
	to = from + wrapf(to - from, -PI, PI)
	if team == "ally":
		ally_side = side
		if player_chosen:
			GameState.preferred_ring_side = side
	else:
		foe_side = side
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
	return Ring.middle_open(ally_slots if team == "ally" else foe_slots)


## Who an action aimed at `target` (a beast of `team_hit`, "trainer", or null) lands on now that its turn has come
## (Ring.retarget): the target if it still stands on the side facing the attacker, else the nearest standing beast
## there, else "trainer" when `can_strike` and that side's middle is open, else null: the action is dropped.
## `from` is the beast acting (null for a trainer). Lessons never turn a blow on a trainer by themselves.
func _retarget(target, team_hit: String, from = null, can_strike := true):
	var rows: Array = ally_slots if team_hit == "ally" else foe_slots
	var wanted := Ring.NO_TARGET
	if typeof(target) == TYPE_STRING:
		wanted = Ring.TRAINER
	elif target != null:
		wanted = rows.find(target)
	var has_trainer := can_strike and not (team_hit == "foe" and wild) and (not tutorial or wanted == Ring.TRAINER)
	var from_row: int = _mine(from).find(from) if from != null else -1
	var k := Ring.retarget(rows, wanted, from_row, has_trainer)
	if k == Ring.TRAINER:
		return "trainer"
	return rows[k] if k >= 0 else null


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
	for i in 6:
		var e: Array = trees[rng.randi_range(0, trees.size() - 1)]
		var name: String = e[0]
		var angle := PI + PI * (i + 0.5) / 6.0
		var radius := rng.randf_range(10.5, 11.5)
		var x := cos(angle) * radius
		var z := 1.5 + sin(angle) * radius
		var s := VA.fit_scale(name, rng.randf_range(2.2, 3.0))
		if not by_asset.has(name):
			by_asset[name] = []
		by_asset[name].append(_xf(Vector3(x, -VA.aabb(name).position.y * s, z), rng.randi_range(0, 3) * PI / 2.0, s))
	for i in 4:
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
	var shrubs: Array = biome.get("shrubs", [])
	var bushes := {}
	for i in (14 if not shrubs.is_empty() else 0):
		var name: String = shrubs[i % shrubs.size()]
		var s := VA.fit_scale(name, rng.randf_range(0.8, 1.3))
		# The whole lane between the parties and both rings remains open.
		var p := Vector3((1.0 if i%2 == 0 else -1.0)*rng.randf_range(8.5, 13.0), -VA.aabb(name).position.y*s, rng.randf_range(-8, 11))
		if not bushes.has(name):
			bushes[name] = []
		bushes[name].append(_xf(p, rng.randf_range(0, TAU), s))
	for name in bushes:
		_multimesh(VA.mesh(name), bushes[name])
	if biome["id"] in ["coast", "quarter", "island", "river", "reef"]:
		var water := MeshInstance3D.new()
		var wp := PlaneMesh.new()
		wp.size = Vector2(80, 14)
		wp.subdivide_width = 79
		wp.subdivide_depth = 13
		water.mesh = wp
		water.material_override = _clear_water(Color(biome["water"]), 1.5)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.extra_cull_margin = 0.1
		# The entire wave stays above the flat stage. Otherwise orbit views expose clipped blue triangles.
		water.position = Vector3(0, 0.08, -24)
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
	wp.subdivide_width = 109
	wp.subdivide_depth = 109
	water.mesh = wp
	water.material_override = _clear_water(Color(water_col))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.extra_cull_margin = 0.1
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
	for n in 4:
		var e: Array = trees[rng.randi_range(0, trees.size() - 1)]
		var name: String = e[0]
		var angle := PI + PI * (n + 0.5) / 4.0
		var p2 := Vector3(cos(angle) * 11.5, 0, 1.5 + sin(angle) * 11.5)
		var s4 := VA.fit_scale(name, rng.randf_range(2.2, 3.0))
		if not by_asset.has(name):
			by_asset[name] = []
		by_asset[name].append(_xf(p2 + Vector3(0, -VA.aabb(name).position.y * s4, 0), rng.randi_range(0, 3) * PI / 2.0, s4))
	for name in by_asset:
		_multimesh(VA.mesh(name), by_asset[name])
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


## The same clear, animated water as the world. Only the far background strip lacks a physical bed.
func _clear_water(col: Color, backdrop := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WaterShader
	mat.set_shader_parameter("frames", VT.frames("water"))
	mat.set_shader_parameter("tint", col)
	mat.set_shader_parameter("opacity", 0.96)
	# The battle's sandy stage is shallow throughout; a stronger tint keeps it reading as water from above.
	mat.set_shader_parameter("absorption_strength", 2.7)
	mat.set_shader_parameter("backdrop_depth", backdrop)
	return mat


func _arena_scenery(rng: RandomNumberGenerator) -> void:
	var xs := []
	var bx := []
	var tx := []
	var ps := VA.fit_scale("stone_pillar", 4.2)
	var bs := VA.fit_scale("banner", 3.0)
	var ts := VA.fit_scale("torch", 1.6)
	for i in 6:
		var angle := PI + PI * (i + 0.5) / 6.0
		var at := Vector3(cos(angle) * 11.5, 0, 1.5 + sin(angle) * 11.5)
		xs.append(_xf(at + Vector3.UP * (-VA.aabb("stone_pillar").position.y * ps), angle, ps))
		bx.append(_xf(at + Vector3(cos(angle + 0.1), 0, sin(angle + 0.1)) * 0.7 + Vector3.UP * (-VA.aabb("banner").position.y * bs), angle, bs))
		if i % 2 == 0:
			tx.append(_xf(at * Vector3(0.94, 1, 0.94) + Vector3.UP * (-VA.aabb("torch").position.y * ts), angle, ts))
	_multimesh(VA.mesh("stone_pillar"), xs)
	_multimesh(VA.mesh("banner"), bx)
	_multimesh(VA.mesh("torch"), tx)


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
	# A sealed stage room: the battle camera stays within these walls and below the ceiling.
	var wall_mat := VT.material("stone_dark")
	for part in [[Vector3(48, 12, 1), Vector3(0, 6, -22)], [Vector3(48, 12, 1), Vector3(0, 6, 25)],
		[Vector3(1, 12, 48), Vector3(-24, 6, 1.5)], [Vector3(1, 12, 48), Vector3(24, 6, 1.5)],
		[Vector3(48, 1, 48), Vector3(0, 12, 1.5)]]:
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		wall.mesh = mesh
		wall.material_override = wall_mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.position = part[1]
		add_child(wall)
	var px := []
	var ps := VA.fit_scale("stone_pillar", 5.0)
	for i in 7:
		px.append(_xf(Vector3(-13.5 + i * 4.5, -VA.aabb("stone_pillar").position.y * ps, -8.2), 0.0, ps))
	_multimesh(VA.mesh("stone_pillar"), px)
	var fill := OmniLight3D.new()
	fill.light_color = glow.lerp(Color.WHITE, 0.2)
	fill.light_energy = 0.55
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
	_build_shield_orbs("ally")
	shield_bubble = MeshInstance3D.new()
	shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	else:
		rival_rig = VPer.build(look)
		VPer.face(rival_rig, Vector2i(0, 1))
		rival_rig.rotation.y = atan2(g.x, g.z) - 0.25
	if rival_rig:
		rival_rig.position = RIVAL_POS + Vector3(0, 0.1, 0)
		add_child(rival_rig)
	_build_shield_orbs("foe")
	rival_bubble = MeshInstance3D.new()
	rival_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rival_bubble.mesh = shield_bubble.mesh
	var rbm: StandardMaterial3D = (shield_bubble.material_override as StandardMaterial3D).duplicate()
	rbm.albedo_color = Color(1.0, 0.75, 0.45, 0.0)
	rival_bubble.material_override = rbm
	rival_bubble.position = RIVAL_POS + Vector3(0, 0.9, 0)
	add_child(rival_bubble)


func _update_shield() -> void:
	for team in _shield_orbs:
		var targeted := _target_refs.has("trainer_self") or _target_refs.has("trainer") if team == "ally" else _target_refs.has("foe_trainer")
		var show: bool = targeted or _time < float(_shield_until[team])
		var count: int = GameState.shield if team == "ally" else foe_shield
		var origin: Vector3 = PLAYER_POS if team == "ally" else RIVAL_POS
		# The tag takes the roomier side of the screen; shield orbs use the other side of the trainer.
		var orb_side := -1.0 if cam.unproject_position(origin).x < cam.get_viewport().get_visible_rect().size.x * 0.5 else 1.0
		var incoming = _ref_pos(_aim_from)
		if targeted and incoming != null:
			orb_side = 1.0 if cam.unproject_position(incoming).x >= cam.unproject_position(origin).x else -1.0
		for i in _shield_orbs[team].size():
			var orb: MeshInstance3D = _shield_orbs[team][i]
			orb.visible = show
			orb.position = origin + Vector3.UP * (1.25 + i * 0.27) + cam.global_basis.x * 0.8 * orb_side
			var mat: StandardMaterial3D = orb.material_override
			mat.albedo_color = UIKit.ACCENT if i < count else UIKit.DARK
			mat.emission = UIKit.ACCENT if i < count else UIKit.DIM * 0.2


func _build_shield_orbs(team: String) -> void:
	var list := []
	var count: int = GameState.max_shield if team == "ally" else _trainer_shield()
	for i in count:
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.11
		sphere.height = 0.22
		sphere.radial_segments = 12
		sphere.rings = 6
		orb.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		orb.material_override = mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		add_child(orb)
		list.append(orb)
	_shield_orbs[team] = list


func _process(delta: float) -> void:
	_time += delta
	_recolor_outlines()
	for b in nodes:
		var n: Node3D = nodes[b]
		if is_instance_valid(n) and n.has_meta("phase"):
			var m: Node3D = n.get_node_or_null("Model")
			if m:
				m.position.y = float(n.get_meta("lift")) + absf(sin(_time * 2.4 + float(n.get_meta("phase")))) * 0.05
	# trainers stand about, or run (with the bat: _run_to)
	for rig in [player_rig, rival_rig]:
		if not is_instance_valid(rig):
			continue
		var gait: Array = _gaits.get(rig, [0.0, 0.0])
		if float(gait[0]) > 0.0:
			gait[1] = float(gait[1]) + VPer.phase_for(delta * float(gait[0]), float(gait[0]))
		VPer.animate(rig, float(gait[1]), float(gait[0]))
	if is_instance_valid(cam):
		if camera_director != null:
			camera_director.step(delta)
		if scenery_visibility != null:
			scenery_visibility.step(delta)
		_sync_front_cam()
	_update_shield()
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
	if nodes.has(ref):
		var node: Node3D = nodes[ref]
		return float(node.get_meta("height")) * node.scale.y * (0.45 if _st(ref)["down"] else 1.0)
	return 1.0


## Who is highlighted. Trainers and beasts get a flat outline round their silhouette, drawn by the HUD from the
## front render (floating_hud.gd); a ring pad (a Move's slot) keeps a hull outline. Hit flashes are untouched.
func _select_hud_actor(ref) -> void:
	_select_actors([] if ref == null else [ref])


## Your trainer is outlined in the gem; beasts, pads and the rival in the element their ring's facing side fights
## with (a wild beast: its own element).
func outline_color(ref) -> Color:
	if typeof(ref) == TYPE_STRING and ref != "foe_trainer":
		return UIKit.ACCENT
	if typeof(ref) == TYPE_OBJECT and wild and _team(ref) == "foe":
		return Elements.color(_fight_el(ref))
	var ours: bool = typeof(ref) == TYPE_INT or (typeof(ref) == TYPE_OBJECT and _team(ref) == "ally")
	return Elements.color(Ring.side_element(ally_side if ours else foe_side))


func _recolor_outlines() -> void:
	for ref in _outline_mats:
		(_outline_mats[ref] as ShaderMaterial).set_shader_parameter("gem", outline_color(ref))


func _select_actors(refs: Array) -> void:
	if refs == _selected_refs:
		_recolor_outlines()
		return
	for mesh in _outline_overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = _outline_overlays[mesh]
	_outline_overlays.clear()
	_outline_mats.clear()
	_selected_refs = refs.duplicate()
	for ref in refs:
		if typeof(ref) != TYPE_INT:
			continue
		var root: Node3D = pads["ally"].get(ref, null)
		if root == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = Outline
		mat.set_shader_parameter("gem", outline_color(ref))
		_outline_mats[ref] = mat
		for mesh in root.find_children("*", "MeshInstance3D", true, false):
			_outline_overlays[mesh] = mesh.material_overlay
			mesh.material_overlay = mat


func _set_acting(ref) -> void:
	_acting_ref = ref
	if ref != null:
		_camera_shot("attacker", ref)
	_hide_targets()
	_select_hud_actor(null)
	if floating != null:
		floating.clear_choice()


func _camera_shot(name: String, actor = null, target = null) -> void:
	if camera_director != null:
		camera_director.play(name, actor, target)


## The models drawn for someone: a beast's own geometry (the parts its hit flash covers), or a trainer's rig.
func _model_geometry(ref) -> Array:
	var out := []
	if typeof(ref) == TYPE_OBJECT and nodes.has(ref) and is_instance_valid(nodes[ref]):
		var flash = nodes[ref].get_meta("flash", null)
		for gi in (nodes[ref] as Node3D).find_children("*", "GeometryInstance3D", true, false):
			if not gi is CPUParticles3D and gi.material_overlay == flash:
				out.append(gi)
	elif typeof(ref) == TYPE_STRING:
		var rig: Node3D = rival_rig if ref == "foe_trainer" else player_rig
		if is_instance_valid(rig):
			out = rig.find_children("*", "MeshInstance3D", true, false)
	return out


## Someone's on-screen box (logical UI units) from their models' bounds; empty when they have none.
func screen_bounds(ref) -> Rect2:
	var k: Vector2 = hud.get_viewport_rect().size / cam.get_viewport().get_visible_rect().size
	var box := Rect2()
	var first := true
	for gi: GeometryInstance3D in _model_geometry(ref):
		if not gi.is_visible_in_tree():
			continue
		var aabb: AABB = gi.global_transform * gi.get_aabb()
		for i in 8:
			var corner := aabb.get_endpoint(i)
			if cam.is_position_behind(corner):
				continue
			var at := cam.unproject_position(corner) * k
			if first:
				box = Rect2(at, Vector2.ZERO)
				first = false
			else:
				box = box.expand(at)
	return box


## The chooser and targets are rendered a second time, alone, for their shapes (alpha): the HUD outlines those
## silhouettes and shows the 3D view through them over the ends of the bars, which then run behind the models. Only
## rendered while someone is listed (`set_front`); its lighting is never seen, so it is kept plain.
const FRONT_LAYER := 1 << 19
var _front_vp: SubViewport
var _front_cam: Camera3D
var _front_geometry: Array = []


func front_texture() -> Texture2D:
	if _front_vp == null:
		_front_vp = SubViewport.new()
		_front_vp.world_3d = cam.get_viewport().find_world_3d()
		_front_vp.transparent_bg = true
		_front_vp.msaa_3d = Viewport.MSAA_2X
		_front_vp.audio_listener_enable_3d = false
		_front_vp.handle_input_locally = false
		_front_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_front_vp)
		_front_cam = Camera3D.new()
		_front_cam.cull_mask = FRONT_LAYER
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.background_color = Color(0, 0, 0, 0)
		_front_cam.environment = env
		_front_vp.add_child(_front_cam)
		_front_cam.current = true
		# The camera director is a child and may move after the battle's _process.
		# Sample its final transform immediately before rendering both viewports,
		# otherwise the HUD masks use the previous view for one frame.
		RenderingServer.frame_pre_draw.connect(_sync_front_cam)
	return _front_vp.get_texture()


## Who is drawn in front of the HUD's bars this frame.
func set_front(refs: Array) -> void:
	var want := []
	for ref in refs:
		want.append_array(_model_geometry(ref))
	for gi in _front_geometry:
		if is_instance_valid(gi) and not want.has(gi):
			gi.layers &= ~FRONT_LAYER
	for gi: GeometryInstance3D in want:
		gi.layers |= FRONT_LAYER
	_front_geometry = want
	if _front_vp == null:
		if want.is_empty():
			return
		front_texture()
	_front_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if not want.is_empty() else SubViewport.UPDATE_DISABLED
	_sync_front_cam()


func _sync_front_cam() -> void:
	if _front_vp == null or _front_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	var main_vp := cam.get_viewport()
	_front_vp.msaa_3d = main_vp.msaa_3d
	_front_vp.screen_space_aa = main_vp.screen_space_aa
	if main_vp is SubViewport:
		_front_vp.size = (main_vp as SubViewport).size
	else:
		_front_vp.size = Vector2i(main_vp.get_visible_rect().size)
	_front_cam.global_transform = cam.global_transform
	_front_cam.fov = cam.fov
	_front_cam.near = cam.near
	_front_cam.far = cam.far
	_front_cam.h_offset = cam.h_offset
	_front_cam.v_offset = cam.v_offset


## Logical UI coordinates, accounting for the full-resolution 3D SubViewport.
func screen_anchor(ref, fraction := 1.0) -> Vector2:
	var at = _ref_pos(ref)
	if at == null:
		return Vector2.ZERO
	return cam.unproject_position(at + Vector3.UP * _ref_height(ref) * fraction) * hud.get_viewport_rect().size / cam.get_viewport().get_visible_rect().size


## Pick the nearest visible silhouette with a generous touch footprint; only legal row targets are considered.
func pick_ref(at: Vector2, refs: Array):
	var best = null
	var nearest := INF
	for ref in refs:
		if _ref_pos(ref) == null:
			continue
		var head := screen_anchor(ref)
		var foot := screen_anchor(ref, 0.0)
		var center := head.lerp(foot, 0.5)
		var radius := maxf(40.0 if UIKit.touch_ui() else 28.0, head.distance_to(foot) * 0.55)
		var distance := at.distance_to(center)
		if distance < radius and distance < nearest:
			nearest = distance
			best = ref
	return best


## Translucent yellow 3D arrows. Geometry changes only when its endpoints move; camera motion never rebuilds a ribbon.
func _draw_arcs() -> void:
	var origin = _ref_pos(_aim_from)
	if origin == null or _target_refs.is_empty():
		aim_mesh.visible = false
		_aim_geometry.clear()
		return
	# It rises from behind the chooser (pushed away from the camera), so they stand in front of it, not under it.
	var away := -cam.global_transform.basis.z
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	var h := _ref_height(_aim_from)
	var from: Vector3 = origin + Vector3.UP * h * 0.6 + away * clampf(h * 0.45, 0.35, 0.9)
	var ends := []
	for ref in _target_refs:
		var at = _ref_pos(ref)
		if at != null:
			ends.append(at + Vector3.UP * (_ref_height(ref) + 0.14))
	var geometry: Array = [from] + ends
	if geometry != _aim_geometry:
		_aim_geometry = geometry
		aim_mesh.mesh = TargetArrow.build(from, ends)
	aim_mesh.visible = not ends.is_empty()


## Aim the arch from the acting beast or trainer to the selected target(s).
func _show_targets(list: Array, sel: int, source = "trainer_self") -> void:
	_aim_from = source
	_target_refs = []
	for i in list.size():
		if sel < 0 or i == sel:
			var t = list[i]
			_target_refs.append(t["ref"] if typeof(t) == TYPE_DICTIONARY else t)
	# the chooser keeps its outline while it aims
	_select_actors(([source] if source != null and _ref_pos(source) != null and not _target_refs.has(source) else []) + _target_refs)
	if floating != null:
		floating.clear_choice()
	_update_shield()


func _hide_targets() -> void:
	_target_refs = []
	_aim_from = null
	_aim_option = {}
	if floating != null and floating.aiming:
		floating.clear_choice()
	_select_hud_actor(null)
	_update_shield()


## Shows a beast: on its pad (slot = its ring slot) for a trainer's ring, or in the wild line (slot = 0..2).
func _spawn(b, side: String, slot: int, animate := true) -> void:
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
	_hp_seen[b] = b.hp
	var final_scale := Vector3.ONE * (1.15 if ringed else 1.25) * big
	if animate:
		root.scale = Vector3(0.2, 0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(root, "scale", final_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		root.scale = final_scale
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


## Refresh the battle's model after its end-of-battle evolution reveal.
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
		# knocked out: down quicker than to rest, slumped, its eyes shut (beast_rig.gd faint())
		rig.faint()
		if not ease:
			rig.settle()
		return
	BeastModel.pose_guard(_model(b), false)
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
## The scene has no fixed ring grids or move bars; a single menu follows the current chooser.
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.hud.add_child(hud)
	floating = FloatingHUD.new()
	floating.battle = self
	hud.add_child(floating)
	_speaker_icons["trainer_self"] = _person_icon(GameState.hero_look(), 0.5)
	_speaker_icons["foe_trainer"] = _person_icon(trainer.get("look", {}), 0.5)
	UI.top_bar.begin_battle()
	hud.tree_exiting.connect(UI.top_bar.end_battle)


func _bar_width() -> float:
	return minf(860.0, UIKit.safe_rect(hud).size.x - 32.0)


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


## A battle message in the top bar, with the icon of whoever it's about (`subject`, else found in the text): on the
## left for the opposing side, on the right for yours. No text keeps the last message, except while commands are
## chosen, when the focused bar's prompt shows ("What will Grubbit do?").
func _caption(text: String, subject = null) -> void:
	if hud == null or UI.top_bar == null:
		return
	if text == "":
		if not _commanding or _prompt_ref == null:
			return
		subject = _prompt_ref
		text = ("What will you do, %s?" % GameState.player_name) if typeof(subject) == TYPE_STRING else ("What will %s do?" % subject.nickname)
	var ref = subject if subject != null else _message_ref(text)
	var icon: Texture2D = _speaker_icons.get(ref, null) if typeof(ref) == TYPE_STRING else (PixelArt.beast_texture(ref.genes) if ref != null else null)
	var player_subject: bool = ref in ["trainer_self", "trainer"] if typeof(ref) == TYPE_STRING else (ref != null and (GameState.party.has(ref) or ally_ring.values().has(ref)))
	UI.top_bar.say_battle(text, icon, player_subject, _bar_width())


## While aiming, the chooser's bar stays where it is and names the target after the action ("Bite > Tadlet"):
## left and right change the target and A confirms.
func _aim_control(row: Dictionary) -> void:
	if floating == null or _target_refs.is_empty() or _aim_from == null:
		return
	var options: Array = row.get("options", [])
	var shown: Dictionary = (options[clampi(int(row.get("sel", 0)), 0, options.size() - 1)] as Dictionary).duplicate() if not options.is_empty() else {}
	shown["label"] = "%s ► %s" % [String(shown.get("label", "")), "All" if _target_refs.size() > 1 else floating._name(_target_refs[0])]
	shown.erase("disabled")
	floating.choose(_aim_from, row, shown, true)


func _status_text(ref) -> String:
	if typeof(ref) == TYPE_OBJECT:
		var mark: String = {"weak": "  ·  Weak!", "resist": "  ·  Resists"}.get(target_mark(ref), "")
		return "%s  HP %d / %d%s" % [ref.nickname, maxi(0, ref.hp), ref.max_hp(), mark]
	return floating._name(ref)


## How the attack being aimed meets a beast it is aimed at (the rule _calc_damage uses): "weak" when its element takes
## double from the attack's, "resist" when the attack is of its own element, else "". Only attacks have one: a
## beast's attacking move, or an elemental bomb (`_aim_option`: the option being aimed, with "move" or "el").
func target_mark(ref) -> String:
	if typeof(ref) != TYPE_OBJECT or _aim_option.is_empty():
		return ""
	var el := String(_aim_option.get("el", ""))
	if _aim_option.has("move"):
		var m := MoveDB.get_move(String(_aim_option["move"]))
		if String(m["kind"]) != "attack":
			return ""
		el = String(m["el"])
	if el == "":
		return ""
	var eff := Elements.multiplier(el, _guard_el(ref))
	return "weak" if eff > 1.0 else ("resist" if eff < 1.0 else "")


## The top bar's words for the command being chosen: what the action does (the panel's own hint, `text`); while
## aiming, the action, who it is aimed at with their HP, and what it does.
func _command_info(row: Dictionary, _o: Dictionary, picking: bool, text: String) -> String:
	if rotation_lesson and row.get("kind", "") == "beast":
		return "Try turning: up past the top beast, or down past the bottom. Use the on-screen d-pad too."
	if not picking or String(row.get("pick_kind", "")) == "slot" or _target_refs.is_empty():
		return text
	var options: Array = row.get("options", [])
	if options.is_empty():
		return text
	var chosen: Dictionary = options[clampi(int(row.get("sel", 0)), 0, options.size() - 1)]
	var what := MoveDB.summary(String(chosen["move"])) if chosen.has("move") else String(chosen.get("desc", ""))
	var aim := "%s  ►  %s" % [String(chosen.get("label", "")), ",   ".join(_target_refs.map(_status_text))]
	return aim if what == "" else aim + "\n" + what.replace("\n", "  ")


## The control is pinned to the chooser. Its explanation, warnings and teaching hints use the shared top bar.
func _show_option(row: Dictionary, o: Dictionary) -> void:
	if floating == null:
		return
	if o.is_empty():
		if not floating.aiming:
			floating.clear_choice()
		return
	var ref = "trainer_self" if row.get("kind", "") == "trainer" else row.get("beast", null)
	floating.choose(ref, row, o)
	var note := String(o.get("note", ""))
	if note != "":
		_caption(note, ref)


## A small full-length picture for the shared top bar, turned `yaw` from facing the viewer
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
func _refresh() -> void:
	for team in ring_root:
		_light_pads(team)
	_update_shield()
	if floating != null:
		floating.queue_redraw()


## The command controller's view: only the chooser, or the targets and their arcing arrows.
func _render_rows(rows: Array, focus: int, picking: bool) -> void:
	var row: Dictionary = rows[focus]
	_prompt_ref = "trainer_self" if row["kind"] == "trainer" else row.get("beast", null)
	if picking:
		var ts: Array = row.get("targets", [])
		var opts: Array = row.get("options", [])
		_aim_option = opts[clampi(int(row.get("sel", 0)), 0, opts.size() - 1)] if not opts.is_empty() else {}
		_show_targets(ts, -1 if row.get("target_all", false) else int(row.get("target_sel", 0)), _prompt_ref)
		_aim_control(row)
	else:
		_hide_targets()
		_select_hud_actor(_prompt_ref)


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
	# Use the book's preferred opening side, with the same middle-beast protection as before. Guided lessons keep
	# their existing facing so a menu preference cannot change the action they teach.
	GameState.fix_ring()
	ally_ring = GameState.ring()
	var opening_side := GameState.ring_side if tutorial else GameState.starting_ring_side()
	ally_side = Ring.covered_side(ally_ring, opening_side)
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
	if ally_side != opening_side and not tutorial:
		await msg("Nobody stands in the middle of your %s side, so you turn your ring round." % Ring.side_element(opening_side).capitalize(), 1.0)
	if not go.is_empty():
		await msg("Your %s side faces the foe. Go, %s!" % [Ring.side_element(ally_side).capitalize(), ", ".join(go)], 0.9)
	await _start_passives()
	_check_end()
	await _check_exposed()
	if tutorial:
		if lesson.has("narration"):
			await UI.say([_tut_fill(lesson["narration"])])
		await _tut_say(lesson.get("intro", []))
		if lesson_id == "rhythm":
			await _rhythm_lesson()
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
	_select_hud_actor(null)
	_set_acting(null)
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
			if st[b]["defend"]:
				BeastModel.pose_guard(_model(b), false)
			st[b]["defend"] = false


# ================================================================ tutorial
## Who is teaching: the lesson's coach, else the trainer.
func _tut_who() -> String:
	return String(lesson.get("coach", ("%s %s" % [trainer.get("cls", ""), trainer.get("name", "")]).strip_edges()))


func _tut_say(lines: Array) -> void:
	if not lines.is_empty():
		await UI.say(lines.map(func(l): return _tut_fill(String(l))), _tut_who(), null, rival_rig if not lesson.has("coach") else null)


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
	# the last round's words aren't said again while it repeats, except one to try again
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
	return slots.filter(Ring.standing)


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
	if not tutorial:
		await _new_battle_lessons()
	if cfg.get("autoplay", false) or UI.auto:
		if rotation_lesson:
			await _turn_ring("ally", Ring.next_side(ally_ring, ally_side, 1))
			GameState.set_flag("ring_rotation_taught")
			rotation_lesson = false
		return await _auto_commands()
	flute_used = false
	if tutorial:
		await _tut_round_intro()
	var rows := _panel_rows()
	var focus := 0
	while true:
		if result != "":
			_select_hud_actor(null)
			return []
		if rows[0].get("done", false) and not _rows_waiting(rows):
			break
		var p := CommandPanel.new()
		p.setup(rows, _panel_info(), focus, _row_targets, {"render": _render_rows, "hint": _caption, "info": _command_info,
			"option": _show_option, "teach": _teach_option, "stage": self, "floating": floating})
		_commanding = true
		UI.push(p)
		var r: Dictionary = await p.done
		_commanding = false
		_show_option({}, {})
		_hide_targets()
		focus = int(r.get("focus", focus))
		match String(r.get("kind", "")):
			"go":
				break
			"rotate":
				_select_hud_actor(null)
				var ns := Ring.next_side(ally_ring, ally_side, int(r["dir"]))
				if ns != ally_side:
					await _turn_ring("ally", ns, true)
					if rotation_lesson:
						GameState.set_flag("ring_rotation_taught")
						rotation_lesson = false
						await _battle_lesson_say(["That's it! Turning costs no turn. Choose moves for this side now. Keep a standing beast in the middle to guard you."])
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
							# a song may have changed the field: the beasts' targets are chosen afresh
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
	_select_hud_actor(null)
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
	var t_opts := _weapon_options()
	t_opts.append_array([
		{"id": "items", "label": "Items", "icon": "item", "sub": true, "desc": "Heal, cure or revive your beasts, buff your team, or hit the foes with bombs and powders."},
		{"id": "flute", "label": "Flute", "icon": "flute", "sub": true, "disabled": not GameState.has_flute(),
			"desc": "Play a song: lift your team, or weaken the foes." if GameState.has_flute() else "You don't have a flute yet. Your uncle in Bellerive is keeping your father's."},
		{"id": "watch", "label": "Watch", "icon": "watch", "target": "none", "desc": "Let your beasts handle this round."},
	])
	if not GameState.summons.is_empty():
		# a captured temple guardian, called with its song: once per battle, for a shield point
		var why := ""
		if summoned:
			why = "You've already called a summon this battle."
		elif GameState.shield <= 0:
			why = "Summoning costs a shield point, and you have none left."
		elif not GameState.has_flute():
			why = "You need your flute to play a summon's song."
		t_opts.insert(t_opts.size() - 1, {"id": "summon", "label": "Summon", "icon": "summon", "sub": true, "disabled": why != "",
			"desc": why if why != "" else "Play a temple's song to call its guardian: it strikes every foe at once. Once per battle, for one shield point (%d left)." % GameState.shield})
	if wild:
		t_opts.append({"id": "run", "label": "Run", "icon": "run", "sub": true, "desc": "Try to escape."})
	else:
		t_opts.append({"id": "forfeit", "label": "Forfeit", "icon": "run", "sub": true, "disabled": tutorial,
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


## Your weapons for the trainer's bar (item_db.gd WEAPONS, the ones you own): the slingshot, then the boomerang and the
## bat once you have them. From trainer Lv 4 each one chains hits to the beat (scripts/core/beat_chain.gd).
func _weapon_options() -> Array:
	var out := []
	var most := BeatChain.max_hits(GameState.trainer_level)
	for id in GameState.weapons():
		var w := ItemDB.weapon(id)
		var desc: String = {"slingshot": "Fire a stone at a foe or an exposed trainer.",
			"boomerang": "Sweep every foe on the side facing you, a little softer on each; it comes back to your hand.",
			"bat": "Run up to a foe and swing: the hardest hit of the three."}.get(id, "")
		if most > 0 and (GameState.flag("dance_lesson_done") or lesson_id == "rhythm"):
			desc += " Press A on the beat: up to %d hits." % most
		out.append({"id": "weapon", "weapon": id, "icon": "attack", "label": ItemDB.item_name(id), "target": w.get("target", "enemy"), "desc": desc})
	return out


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
		out.append({"id": "move", "move": mv, "icon": ActionIcons.for_move(mv), "label": String(m["name"]), "right": right, "desc": desc, "note": note, "target": m["target"], "disabled": off})
	if el == "neutral" and not b.ghost:
		var plain := "%s can't use %s moves from the %s side: plain moves only." % [b.nickname, b.element_text(), Ring.side_element(ally_side).capitalize()]
		out[0]["desc"] = plain + "\n" + String(out[0]["desc"])
		if String(out[0].get("note", "")) == "":
			out[0]["note"] = plain
	var d := {"id": "defend", "label": "Defend", "icon": "defend", "target": "none", "right": "half damage",
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
	out.append({"id": "shift", "label": "Move", "icon": "move", "target": "slot", "right": "uses its turn", "desc": mv_desc, "disabled": spots.is_empty() or tutorial,
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
		"prompt": "What will you do, %s?" % GameState.player_name, "lesson": tutorial, "rotation_lesson": rotation_lesson}


## Teach at the first usable opportunity, including journeys saved before these lessons existed.
func _new_battle_lessons() -> void:
	if _alive(foe_slots).size() > 1:
		await _teach_topics(["retarget"])
	if _all_active().any(func(b): return not b.passives.is_empty() or not b.equip.is_empty()):
		await _teach_topics(["passives"])
	if not GameState.flag("ring_rotation_taught") and GameState.party.size() > 3 and Ring.next_side(ally_ring, ally_side, 1) != ally_side:
		rotation_lesson = true
		await _battle_lesson_say(["You have more than three beasts now. Only the three facing the foe can fight; turn the ring to bring the others forward.",
			"Choose your trainer's action first. Then press up past the top beast, or down past the bottom one. Use the on-screen d-pad on touch screens.",
			"Try a turn before choosing your beasts' moves. Turning is free, but the new side must choose its moves again."])


func _teach_option(option: Dictionary) -> void:
	if tutorial:
		return
	await _teach_topics(BattleTutorials.topics(option))


func _teach_topics(topics: Array) -> void:
	for topic in topics:
		var flag := "battle_tip_" + String(topic)
		if not GameState.flag(flag):
			await _battle_lesson_say([BattleTutorials.TIPS[topic]])
			GameState.set_flag(flag)


## Opposing trainers coach through their own anchored speech bubbles; wild encounters use a system window.
func _battle_lesson_say(lines: Array) -> void:
	if not wild and is_instance_valid(rival_rig):
		var who := ("%s %s" % [trainer.get("cls", ""), trainer.get("name", "Trainer")]).strip_edges()
		await UI.say(lines, who, null, rival_rig)
	else:
		await UI.say(lines)


## One safe, repeatable hit before real rhythm attacks. Nothing takes damage or spends a turn here.
func _rhythm_lesson() -> void:
	await _tut_say(["First, a practice beat; nobody attacks while you learn.",
		"Watch the white ring. Press A, or tap the ring, as the spinning notch meets the mark at the top. Listen for the beat."])
	Sfx.beat_begin()
	Sfx.percussion("full")
	var learned := false
	while not learned:
		_caption("Practice: press A or tap the ring when the notch reaches the top.", "trainer_self")
		var cue := BeatCue.new()
		cue.most = 1
		cue.easy = true
		cue.anchor = func(): return UI.root.get_viewport_rect().size * Vector2(0.5, 0.4)
		if UI.auto or cfg.get("autoplay", false):
			cue.injected = [0.0]
		UI.push(cue)
		var grades: Array = await cue.done
		learned = grades.has("good") or grades.has("perfect")
		if not learned:
			await _tut_say(["Let's try again. Wait for the notch to reach the top, then press A once. Each full circle is one beat."])
	Sfx.percussion("bed")
	Sfx.beat_end()
	await _tut_say(["That's the beat! In battle, keep pressing once on each beat to fill the pips. A miss ends the chain; hits already landed still count.",
		"Fill every pip and the last hit is critical. Your level sets the number of hits. Now choose a weapon when you're ready to try it."])


## Who a row's option can be aimed at: [{label, ref}]. An open rival
## trainer is a target too.
func _row_targets(row: Dictionary, opt: Dictionary) -> Array:
	var out := []
	match String(opt.get("target", "none")):
		"enemy":
			for b in _alive(foe_slots):
				out.append({"label": b.nickname, "ref": b})
			if _side_open("foe"):
				out.append({"label": String(trainer.get("name", "the trainer")), "ref": "foe_trainer"})
			# start on the foe facing this beast's own row
			var mine = row.get("beast", null)
			var i := ally_slots.find(mine)
			if i >= 0 and foe_slots[i] != null and foe_slots[i].hp > 0:
				row["target_sel"] = _alive(foe_slots).find(foe_slots[i])
		"ally":
			for b in _alive(ally_slots):
				out.append({"label": b.nickname, "ref": b})
		"ally_ko":
			for b in GameState.party.filter(func(x): return x.hp <= 0 and x.slot >= 0):
				out.append({"label": b.nickname, "ref": b})
		"enemies":
			for b in _alive(foe_slots):
				out.append({"label": b.nickname, "ref": b})
		"allies":
			for b in _alive(ally_slots):
				out.append({"label": b.nickname, "ref": b})
		"slot":
			# the slots it can Move to (one beast moves each round)
			for r2 in _rows_now:
				if r2 != row and r2.get("kind", "") == "beast" and r2.get("done", false) and String(r2["options"][int(r2.get("sel", 0))].get("id", "")) == "shift":
					return []
			for k in _shift_spots(row.get("beast", null)):
				var o = ally_ring.get(k, null)
				out.append({"label": Ring.slot_name(k), "ref": k,
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
			"weapon":
				acts.append({"type": "weapon", "weapon": String(o["weapon"]), "target": _row_ref(r0), "prio": 9})
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
				acts.append({"type": "weapon", "weapon": "slingshot", "target": f0, "prio": 9})
			"Items":
				if GameState.item_count("minor_potion") == 0:
					GameState.receive_item("minor_potion")
				if b0 != null:
					acts.append({"type": "item", "item": "minor_potion", "target": b0, "prio": 9})
			"Summon":
				acts.append(await _summon_flow())
			"Flute":
				acts.append({"type": "player_song", "song": String(_tut_round().get("song", "weaken")), "acc": 0.75, "prio": 9})
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
	# (test runs pick a weapon with --weapon; else the hardest hitter you own)
	var weapon: String = cfg.get("auto_weapon", GameState.weapons().back())
	if _side_open("foe"):
		return {"type": "weapon", "weapon": weapon, "target": "trainer", "prio": 9}
	if foes_alive.is_empty():
		return {}
	foes_alive.sort_custom(func(x, y): return x.hp_ratio() < y.hp_ratio())
	return {"type": "weapon", "weapon": weapon, "target": foes_alive[0], "prio": 9}


## `el`: the element of what is being aimed (an elemental bomb), for the targets' weak / resist marks.
func _choose_target(list: Array, title: String, el := ""):
	if list.is_empty():
		return null
	if list.size() == 1 and (title == "Target" or tutorial):
		return list[0]
	var targets := []
	for t in list:
		targets.append({"label": t.nickname, "ref": t})
	var row := {"kind": "trainer", "options": [{"label": title}], "targets": targets, "target_sel": 0}
	var panel := CommandPanel.new()
	panel.setup([row], {"target_only": true}, 0, Callable(), {
		"render": func(_rows, _focus, _picking):
			_aim_option = {"el": el} if el != "" else {}
			_show_targets(targets, int(row.get("target_sel", 0))),
		"hint": _caption, "info": _command_info, "stage": self, "floating": floating})
	panel.picking = true
	UI.push(panel)
	var choice: Dictionary = await panel.done
	_hide_targets()
	_show_option({}, {})
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
		if tutorial:
			# a lesson lists just the song it teaches
			if not ids.is_empty() or sid != String(_tut_round().get("song", "")):
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
	var played: bool
	if SongDB.is_summon(song):
		played = await _guardian_song_flow(song)
	else:
		played = await _effect_song_flow(song)
	_set_acting(null)
	return played


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
	_set_acting("trainer_self")
	await msg("You raise your flute and play %s..." % s["name"], 0.6)
	var acc: float = float((await UI.flute_ex(song, "%s  —  faster and cleaner means a stronger effect" % SongDB.tag(song), {"lesson": tutorial}))["acc"])
	_battle_music()
	if tutorial:
		acc = maxf(acc, 0.6)
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _apply_song(song, acc, "ally", target)
	if star:
		await msg("Your mastery of %s improved! It grew to %d notes." % [s["name"], SongDB.note_count(song, GameState.song_level(song))], 1.2)
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
		l.font = UIKit.font_body()
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
		l.font = UIKit.font_body()
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
		GameState.receive_item("minor_potion")
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
			t = await _choose_target(_alive(foe_slots), "Target", String(it2.get("bomb", {}).get("el", "")))
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
	_set_acting("trainer_self")
	if randf() < chance:
		Sfx.play("back")
		await msg("You got away safely!")
		_set_acting(null)
		return true
	await msg("Couldn't get away!")
	_set_acting(null)
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
	var song_now := _rival_wants_song()
	if song_now:
		out.append({"type": "rival_song", "song": String(trainer["song"]), "prio": 4})
	var weapon := _rival_weapon_action(song_now)
	if not weapon.is_empty():
		out.append(weapon)
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
	_select_hud_actor(null)
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
		# Skip inactive beasts before outlining their HUD icons, and clear before faint/end reports.
		if a.get("type", "") in ["move", "defend"] and (a["actor"].hp <= 0 or not _active(a["actor"])):
			continue
		if a.get("type", "none") in ["none", "flute"]:
			continue
		_message_subject = a.get("actor", "foe_trainer" if a.get("type", "") in ["rival_song", "rival_weapon"] else "trainer_self")
		_set_acting(_message_subject)
		match a.get("type", "none"):
			"item":
				await _do_item(a)
			"weapon", "slingshot":
				await _do_weapon(a)
			"rival_weapon":
				await _do_rival_weapon(a)
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
				_st(db)["defend"] = true
				# braced, held until its side's next turn (_end_defend)
				BeastModel.pose_guard(_model(db), true)
				Sfx.play("shield")
				_refresh()
				await msg("%s braces itself!" % db.nickname, 0.55)
			"move":
				var b = a["actor"]
				await _do_move(b, a["move"], a["target"])
			_:
				pass
		_set_acting(null)
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
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


# ================================================================ weapons and the beat attack
## How long a stone flies; how fast a trainer runs with the bat (game units a second).
const STONE_FLIGHT := 0.26
const BAT_RUN := 6.5
## the weapon throws and swings still on their way (a chain waits for them to land), and what a chain has dealt
var _flights := 0
var _weapon_dealt := 0
var _weapon_missed := []
## the last beat attack, for tests: {grades, landed, dealt, most, easy}
var last_chain := {}
## trainers on the move (running up with the bat): rig -> [pace, the stride's phase]
var _gaits := {}


## Your weapon (a: {weapon, target}; item_db.gd WEAPONS). Below trainer Lv 4 (and in lessons) one plain throw, as
## the slingshot always was: its accuracy roll, its damage times the weapon's power. From Lv 4 a beat attack: a cue
## spins above the target and each press of A on the beat lands one more hit (scripts/core/beat_chain.gd). At a
## trainer who's open it's one blow either way: a shield point. A foe that fell before your turn: the nearest one
## standing, then their open trainer, else nothing (the boomerang: every foe standing on the side facing you).
func _do_weapon(a: Dictionary) -> void:
	var id := String(a.get("weapon", "slingshot"))
	var targets := []
	var at_trainer := false
	if String(ItemDB.weapon(id).get("target", "enemy")) == "enemies":
		targets = _alive(foe_slots)
		at_trainer = targets.is_empty() and _side_open("foe") and not tutorial
	else:
		var t = _retarget(a.get("target", null), "foe")
		if t == null:
			return
		if typeof(t) == TYPE_STRING:
			at_trainer = true
		else:
			targets = [t]
	if targets.is_empty() and not at_trainer:
		return
	var aimed: String = String(trainer.get("name", "the trainer")) if at_trainer else (targets[0].nickname if targets.size() == 1 else "")
	await msg(_weapon_line(GameState.player_name, id, aimed), 0.5)
	VPer.set_ready(player_rig, id)
	if at_trainer:
		await _weapon_blow(player_rig, id, "foe")
	elif BeatChain.max_hits(GameState.trainer_level) <= 0 or (tutorial and lesson_id != "rhythm") or (not tutorial and not GameState.flag("dance_lesson_done")):
		await _weapon_plain(player_rig, id, targets)
	else:
		await _weapon_chain(id, targets)
	VPer.set_ready(player_rig, "")


## "Andrew fires the slingshot at Tadlet!" (`aimed` "": the boomerang at every foe)
func _weapon_line(who: String, id: String, aimed: String) -> String:
	match id:
		"boomerang":
			return "%s throws the boomerang%s!" % [who, " at %s" % aimed if aimed != "" else ""]
		"bat":
			return "%s runs at %s with the bat!" % [who, aimed if aimed != "" else "the foe"]
	return "%s fires the slingshot at %s!" % [who, aimed if aimed != "" else "the foe"]


## A weapon at a trainer who's open: one blow, a shield point (or the battle). `team_hit`: whose trainer.
func _weapon_blow(rig: Node3D, id: String, team_hit: String) -> void:
	var at := RIVAL_POS if team_hit == "foe" else PLAYER_POS
	var ref := "foe_trainer" if team_hit == "foe" else "trainer_self"
	_camera_shot("follow", "trainer_self" if team_hit == "foe" else "foe_trainer", ref)
	var home := rig.position
	if id == "bat":
		await _run_to(rig, at + (rig.position - at).normalized() * 1.1, at)
	await _weapon_hit(rig, id, [ref], 1.0, false, true)
	await _strike(null, team_hit)
	if id == "bat" and result == "":
		await _run_to(rig, home, at, true)


## One plain throw (or swing) at each target, as below trainer Lv 4: each rolls to hit.
func _weapon_plain(rig: Node3D, id: String, targets: Array) -> void:
	var home := rig.position
	_weapon_missed = []
	if id == "bat":
		await _run_to(rig, _front_of(targets[0], rig), _target_point(targets[0]))
	_camera_shot("follow", "trainer_self" if rig == player_rig else "foe_trainer", targets[targets.size() / 2])
	await _weapon_hit(rig, id, targets, 1.0, false, true)
	if not _weapon_missed.is_empty() and _weapon_missed.size() == targets.size():
		await msg("%s missed %s!" % ["The stone" if id == "slingshot" else "The " + ItemDB.item_name(id).to_lower(),
			targets[0].nickname if targets.size() == 1 else "everyone"], 0.6)
	elif id == "slingshot" and targets[0].hp > 0 and _weapon_missed.is_empty() and randf() < 0.1:
		await _inflict(targets[0], "stun")
	if id == "bat":
		await _run_to(rig, home, _target_point(targets[0]), true)


## Your beat attack: the cue spins above the target and every press of A on the beat throws (or swings) once more, up
## to as many hits as your trainer level allows (BeatChain.max_hits). The first time (and on the first road) the
## timing is easier, and the top bar says how. The percussion layer comes up meanwhile.
func _weapon_chain(id: String, targets: Array) -> void:
	var most := BeatChain.max_hits(GameState.trainer_level)
	var guided := not GameState.flag("beat_taught")
	var easy := guided or String(cfg.get("map", "")) == "route1"
	var home := player_rig.position
	_weapon_dealt = 0
	_weapon_missed = []
	if id == "bat":
		await _run_to(player_rig, _front_of(targets[0], player_rig), _target_point(targets[0]))
	Sfx.beat_begin()
	Sfx.percussion("full")
	_camera_shot("beat", "trainer_self", targets[targets.size() / 2])
	_caption("Press A just as the spinning notch reaches the top of the ring! Up to %d hits." % most if guided
		else "Press A on the beat: up to %d hits!" % most, "trainer_self")
	var landed := []
	var cue := BeatCue.new()
	cue.most = most
	cue.easy = easy
	cue.anchor = _cue_point.bind(targets)
	cue.hit.connect(func(i: int, g: String) -> void:
		var crit := i == most - 1 and g != "weak"
		landed.append(g)
		_weapon_hit(player_rig, id, targets, float(BeatChain.GRADE_MULT[g]) * (BeatChain.CRIT_MULT if crit else 1.0), crit, false, cue))
	var grades: Array = []
	if (UI.auto or cfg.get("autoplay", false)) and UI.auto_beats.is_empty():
		# simulated battles play a rolled chain, without the cue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cfg.get("seed", 0)) * 31 + round_no
		var hits := BeatChain.roll(0.7, most, rng)
		for i in hits.size():
			cue.hit.emit(i, String(hits[i]["grade"]))
			await get_tree().create_timer(0.2).timeout
		cue.free()
	else:
		if UI.auto or not UI.auto_beats.is_empty():
			cue.injected = UI.auto_beats.pop_front() if not UI.auto_beats.is_empty() else []
		UI.push(cue)
		grades = await cue.done
	while _flights > 0:
		await get_tree().process_frame
	Sfx.percussion("bed")
	Sfx.beat_end()
	GameState.set_flag("beat_taught")
	last_chain = {"grades": grades, "landed": landed, "dealt": _weapon_dealt, "most": most, "easy": easy}
	UI.auto_log.append("[beat] %s %s -> %s, %d damage" % [id, grades, landed, _weapon_dealt])
	_camera_shot("return")
	var n := landed.size()
	var text := ""
	if n == most and not landed.has("weak"):
		text = "A full chain of %d! The last hit was critical." % n
	elif landed == ["weak"]:
		text = "Off the beat: just a glancing blow."
	elif n > 0:
		text = "%d hit%s on the beat!" % [n, "" if n == 1 else "s"]
	if text != "":
		await msg(text, 0.8)
	if id == "slingshot" and n > 1 and targets[0].hp > 0 and randf() < 0.1:
		await _inflict(targets[0], "stun")
	if id == "bat":
		await _run_to(player_rig, home, _target_point(targets[0]), true)


## A foe trainer's weapon (a boss's: _ai_actions): at your beasts only, never at you. Their hits are rolled from their
## strength (BeatChain.roll) rather than played, a beat apart; below trainer Lv 4, one plain throw.
func _do_rival_weapon(a: Dictionary) -> void:
	if not is_instance_valid(rival_rig) or not rival_rig.has_meta("skeleton"):
		return
	var id := String(a.get("weapon", "slingshot"))
	var targets := _alive(ally_slots)
	if targets.is_empty():
		return
	if String(ItemDB.weapon(id).get("target", "enemy")) != "enemies":
		targets.sort_custom(func(x, y): return x.hp_ratio() < y.hp_ratio())
		targets = [targets[0]]
	var who := String(trainer.get("name", "The trainer"))
	await msg(_weapon_line(who, id, targets[0].nickname if targets.size() == 1 else "").replace("the slingshot", "a slingshot")
		.replace("the boomerang", "a boomerang").replace("the bat", "a bat"), 0.5)
	VPer.set_ready(rival_rig, id)
	var lv := _foe_trainer_level()
	var most := BeatChain.max_hits(lv)
	if most <= 0:
		await _weapon_plain(rival_rig, id, targets)
	else:
		var home := rival_rig.position
		if id == "bat":
			await _run_to(rival_rig, _front_of(targets[0], rival_rig), _target_point(targets[0]))
		_camera_shot("follow", "foe_trainer", targets[targets.size() / 2])
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var hits := BeatChain.roll(float(lv - 1) / float(GameState.TRAINER_LEVEL_MAX - 1), most, rng)
		_weapon_dealt = 0
		for h in hits:
			_weapon_hit(rival_rig, id, targets, float(h["mult"]), bool(h["crit"]), false)
			await get_tree().create_timer(0.5).timeout
		while _flights > 0:
			await get_tree().process_frame
		if hits.size() > 1:
			await msg("%d hits!" % hits.size(), 0.6)
		if id == "bat":
			await _run_to(rival_rig, home, _target_point(targets[0]), true)
	VPer.set_ready(rival_rig, "")


## The rival's weapon this round, if any: bosses and arena masters only (not in lessons, not a robot), now and then,
## never while they play a song. Their weapon goes with the region (trainer "weapon", else their beasts' level).
func _rival_weapon_action(song_now: bool) -> Dictionary:
	if wild or tutorial or song_now or not is_boss() or not is_instance_valid(rival_rig) or not rival_rig.has_meta("skeleton"):
		return {}
	if randf() >= 0.35 or _alive(ally_slots).is_empty():
		return {}
	var top := 0
	for f in foes:
		top = maxi(top, int(f.level))
	var id := String(trainer.get("weapon", "slingshot" if top < 11 else ("boomerang" if top < 15 else "bat")))
	return {"type": "rival_weapon", "weapon": id, "prio": 9}


## Where a beat cue goes: above the target's head (the middle of several), on the screen the cue is drawn on. It sits
## high enough that the damage numbers (_float_text) rise beneath it and fade before they reach its pips.
func _cue_point(targets: Array) -> Vector2:
	var top := Vector3.ZERO
	var n := 0
	for t in targets:
		if nodes.has(t) and is_instance_valid(nodes[t]):
			var nd: Node3D = nodes[t]
			top += nd.position + Vector3.UP * (float(nd.get_meta("height")) * nd.scale.y + 1.1)
			n += 1
	var screen := UI.root.get_viewport_rect().size
	if n == 0 or not is_instance_valid(cam) or cam.is_position_behind(top / n):
		return screen * Vector2(0.5, 0.35)
	var k: Vector2 = screen / cam.get_viewport().get_visible_rect().size
	return cam.unproject_position(top / n) * k - Vector2(0, BeatCue.RADIUS + 16.0)


## Where a trainer stands to swing a bat at a beast: just in front of it, on the trainer's side.
func _front_of(t, rig: Node3D) -> Vector3:
	var at: Vector3 = nodes[t].position if nodes.has(t) else FOE_CENTER
	var away := rig.position - at
	away.y = 0.0
	var reach := 0.75 + float(nodes[t].get_meta("height")) * 0.35 if nodes.has(t) else 1.0
	return Vector3(at.x, rig.position.y, at.z) + away.normalized() * reach


## A trainer runs to `dest`, then turns to face `look` (back home: `home` turns them to face the other ring again).
func _run_to(rig: Node3D, dest: Vector3, look: Vector3, home := false) -> void:
	var d := dest - rig.position
	d.y = 0.0
	var dist := d.length()
	if dist > 0.05:
		rig.rotation.y = atan2(d.x, d.z)
		_gaits[rig] = [BAT_RUN, float(_gaits.get(rig, [0.0, 0.0])[1])]
		var tw := create_tween()
		tw.tween_property(rig, "position", Vector3(dest.x, rig.position.y, dest.z), dist / BAT_RUN)
		await tw.finished
		_gaits[rig] = [0.0, float(_gaits[rig][1])]
	var f := _toward("ally" if rig == player_rig else "foe") if home else (look - rig.position)
	var yaw := atan2(f.x, f.z) - (0.25 if home and rig == rival_rig else 0.0)
	var turn := create_tween()
	turn.tween_property(rig, "rotation:y", rig.rotation.y + angle_difference(rig.rotation.y, yaw), 0.15)
	await turn.finished


## One use of a weapon by `rig` at `targets` (beasts, or a trainer's ref): the throw, swing or fling, the stone or the
## boomerang on its way, and each hit as it lands (`mult`: of a plain throw's damage; `plain`: rolls to hit, with its
## messages). Not awaited in a chain, so the next press can follow: _flights counts what's still on its way. A chain's
## cue ends early once everyone it aims at is down.
func _weapon_hit(rig: Node3D, id: String, targets: Array, mult: float, crit: bool, plain := false, cue = null) -> void:
	var live := targets.filter(func(t): return typeof(t) == TYPE_STRING or (t != null and t.hp > 0))
	if live.is_empty():
		return
	_flights += 1
	match id:
		"bat":
			VPer.set_action(rig, "swing")
			Sfx.play("slingshot", 0.15)
			await get_tree().create_timer(VPer.ACTION_HIT["swing"]).timeout
			await _weapon_land(id, live[0], mult, crit, plain)
		"boomerang":
			VPer.set_action(rig, "boomerang")
			await get_tree().create_timer(VPer.ACTION_HIT["boomerang"]).timeout
			VPer.show_weapon(rig, false)
			Sfx.play("fly", 0.1)
			await _boomerang_flight(rig, live, mult, crit, plain)
			VPer.show_weapon(rig, true)
			VPer.set_action(rig, "catch")
		_:
			VPer.set_action(rig, "throw")
			await get_tree().create_timer(VPer.ACTION_HIT["throw"]).timeout
			Sfx.play("slingshot", 0.1)
			await _stone_flight(VPer.weapon_point(rig), _weapon_aim(live[0]))
			await _weapon_land(id, live[0], mult, crit, plain)
	_flights -= 1
	if cue != null and is_instance_valid(cue) and targets.all(func(t): return typeof(t) != TYPE_STRING and (t == null or t.hp <= 0)):
		cue.finish()


## Where a weapon aims on someone: a beast's middle, or a trainer's chest.
func _weapon_aim(ref) -> Vector3:
	if typeof(ref) == TYPE_STRING:
		return (RIVAL_POS if ref == "foe_trainer" else PLAYER_POS) + Vector3(0, 1.1, 0)
	return _target_point(ref)


## A hit landing on a beast (a trainer's blow is _strike's): its damage, quietly in a chain; a plain throw rolls to
## hit first, as the slingshot always did. A beast out of sight (vanished) is always missed.
func _weapon_land(id: String, t, mult: float, crit: bool, plain: bool) -> void:
	if typeof(t) == TYPE_STRING or t == null or t.hp <= 0:
		return
	var acc := 0.9 / _acc_mult(int(_st(t)["stages"]["eva"]))
	if _st(t)["vanish"] or (plain and not tutorial and randf() > acc):
		Sfx.play("miss")
		_float_text(t, "Miss", Color.WHITE)
		_weapon_missed.append(t)
		return
	var tier := GameState.crest_count() if _team(t) == "foe" else _foe_trainer_level() - 1
	var power := float(ItemDB.weapon(id).get("power", 1.0))
	var dmg := maxi(1, int(round((3.0 + 3.0 * tier + t.max_hp() * 0.05) * randf_range(0.85, 1.15) * power * mult)))
	_weapon_dealt += dmg
	if plain:
		await _deal(null, t, {"dmg": dmg, "eff": 1.0, "crit": crit, "pierce": false})
	else:
		_deal(null, t, {"dmg": dmg, "eff": 1.0, "crit": crit, "pierce": false}, true)


## A stone from the slingshot: a quick, low arc.
func _stone_flight(from: Vector3, to: Vector3) -> void:
	var stone := MeshInstance3D.new()
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.13
	sm.radial_segments = 8
	sm.rings = 4
	stone.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#8a847a")
	stone.material_override = m
	stone.position = from
	add_child(stone)
	var mid := (from + to) / 2.0 + Vector3(0, 0.5, 0)
	var tw := create_tween()
	tw.tween_property(stone, "position", mid, STONE_FLIGHT * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(stone, "position", to, STONE_FLIGHT * 0.5).set_ease(Tween.EASE_IN)
	await tw.finished
	stone.queue_free()


## The boomerang: out in a curve through each target in turn (each hit as it passes) and back to the thrower's hand,
## spinning, within a beat.
func _boomerang_flight(rig: Node3D, targets: Array, mult: float, crit: bool, plain: bool) -> void:
	var bm := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d9a066")
	for s in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.04, 0.08)
		arm.mesh = box
		arm.material_override = mat
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.rotation.y = s * 0.85
		arm.position = Vector3(s * 0.1, 0, -0.06)
		bm.add_child(arm)
	var start := VPer.weapon_point(rig)
	bm.position = start
	add_child(bm)
	var points := [start]
	for t in targets:
		points.append(_weapon_aim(t))
	var back := rig.global_position + Vector3.UP * VPer.hand_height() * 1.2
	var trip := clampf(Sfx.beat_period() * 0.8, 0.4, 0.62)
	var out_part := 0.55
	var side := _right() * (1.2 if rig == player_rig else -1.2)
	var hit_at := []
	for i in targets.size():
		hit_at.append(out_part * float(i + 1) / float(targets.size()))
	var t0 := 0.0
	var next := 0
	while t0 < trip:
		await get_tree().process_frame
		t0 += get_process_delta_time()
		var u := clampf(t0 / trip, 0.0, 1.0)
		var p: Vector3
		if u < out_part:
			var k := u / out_part * float(points.size() - 1)
			var j := mini(int(k), points.size() - 2)
			p = (points[j] as Vector3).lerp(points[j + 1], smoothstep(0.0, 1.0, k - j))
		else:
			var k2 := (u - out_part) / (1.0 - out_part)
			p = (points.back() as Vector3).lerp(VPer.weapon_point(rig) if rig.is_inside_tree() else back, smoothstep(0.0, 1.0, k2))
			p += side * sin(PI * k2) * 0.8
		bm.position = p
		bm.rotation.y += get_process_delta_time() * 26.0
		while next < hit_at.size() and u >= float(hit_at[next]):
			await _weapon_land("boomerang", targets[next], mult, crit, plain)
			next += 1
	while next < targets.size():
		await _weapon_land("boomerang", targets[next], mult, crit, plain)
		next += 1
	bm.queue_free()


func _do_item(a: Dictionary) -> void:
	var id: String = a["item"]
	var it := ItemDB.get_item(id)
	if GameState.item_count(id) <= 0:
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
			# thrown at a foe that has fallen since: the nearest one standing (an item is never thrown at a trainer)
			var t0 = _retarget(a["target"], "foe", null, false)
			if t0 != null:
				targets = [t0]
		"ally_ko":
			# a revive is never passed on to someone else
			targets = [a["target"]]
		_:
			# care meant for an ally that has fallen since goes to the weakest beast standing
			var t1 = a["target"]
			if t1 == null or t1.hp <= 0:
				t1 = Ring.weakest(ally_slots)
			if t1 != null:
				targets = [t1]
	# with nobody left to use it on, the item stays in the bag and the action is dropped
	if targets.is_empty() or not GameState.remove_item(id):
		return
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
	_shield_until["ally" if bubble == shield_bubble else "foe"] = _time + 1.0
	_update_shield()
	var m: StandardMaterial3D = bubble.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)


## A blow at a trainer who is open to attack (`team_hit`: "ally" for you, "foe" for the rival): it breaks a shield
## point, or, with none left, ends the battle. `b` is the beast that strikes, or null for your slingshot.
func _strike(b, team_hit: String) -> void:
	var pos := PLAYER_POS if team_hit == "ally" else RIVAL_POS
	var target_ref := "trainer_self" if team_hit == "ally" else "foe_trainer"
	var who: String = GameState.player_name if team_hit == "ally" else String(trainer.get("name", "the trainer"))
	if b != null:
		await msg("%s charges straight at %s!" % [b.nickname, who], 0.6)
		_camera_shot("follow", b, target_ref)
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
	_shield_until[team_hit] = _time + 1.0
	_camera_shot("reaction", target_ref)
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
	_camera_shot("knockout", target_ref)
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
	var wanted_name := String(MoveDB.get_move(mv)["name"])
	var short: bool = cost > 0 and b.mp < cost
	if short:
		mv = "tackle"
	var m := MoveDB.get_move(mv)
	# who it lands on now (a target that fell is passed on, see _targets_for); with nobody left the move is dropped
	# without a word, and without costing its MP
	var targets := _targets_for(b, m, target)
	if targets.is_empty():
		return
	if short:
		await msg("%s doesn't have enough MP for %s!" % [b.nickname, wanted_name], 0.7)
	elif cost > 0:
		b.mp -= cost
		_refresh()
	if int(m.get("cd", 0)) > 0:
		s["cd"][mv] = int(m["cd"]) + 1
	# (a cast's cut to the caster asked for now, so it's on it by the time it starts to gather)
	if typeof(targets[0]) != TYPE_STRING and not (m["el"] == "neutral" and m["kind"] == "attack"):
		_camera_shot("cast", b)
	await msg("%s used %s!" % [b.nickname, m["name"]], 0.55, b)
	# straight at an open trainer
	if typeof(targets[0]) == TYPE_STRING:
		await _strike(b, "foe" if _team(b) == "ally" else "ally")
		return
	# a plain attack lunges at its target; any other move is cast (its element's glow, white for a plain one)
	if m["el"] == "neutral" and m["kind"] == "attack":
		_camera_shot("follow", b, targets[0])
		await _lunge(b, true)
	else:
		await _cast(b, m, targets)
	for t in targets:
		if result != "" or b.hp <= 0:
			break
		await _apply_move(b, t, mv, m)
	# (the shot held on a beast that cast on itself goes back)
	if _casting and camera_director != null and (camera_director.shot == "cast" or camera_director.pending == "cast"):
		_camera_shot("return")
	_casting = false


func _targets_for(b, m: Dictionary, target) -> Array:
	var mine := _mine(b)
	var theirs := _theirs(b)
	var fx: Dictionary = m.get("fx", {})
	match m["target"]:
		"self":
			return [b]
		"enemy":
			# a target that is down or gone: the nearest foe standing, then (for an attack) their open trainer
			var t = _retarget(target, "foe" if _team(b) == "ally" else "ally", b, m["kind"] == "attack")
			if t == null:
				return []
			if typeof(t) != TYPE_STRING and not fx.get("pierce", false):
				for x in _alive(theirs):
					if int(_st(x)["taunt"]) > 0:
						t = x
						break
			return [t]
		"enemies":
			return _alive(theirs)
		"ally":
			# a heal or boost for an ally that fell goes to the weakest one standing
			var t2 = target
			if t2 == null or t2.hp <= 0 or not mine.has(t2):
				t2 = Ring.weakest(mine)
			return [t2] if t2 != null else []
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
	# (a cast lands now: an attack's as it hits, or beside it as it misses)
	if m["kind"] != "attack":
		_cast_land(t)
	match m["kind"]:
		"attack":
			if not _hit_check(a, t, m):
				_cast_land(t, true)
				Sfx.play("miss")
				_float_text(t, "Miss", Color.WHITE)
				await msg("%s avoided the attack!" % t.nickname if _st(t)["vanish"] else "The attack missed %s!" % t.nickname, 0.7)
				return
			_cast_land(t)
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
			# (a flinch as it takes hold)
			BeastModel.pose_hit(_model(t), 0.1)
			if fx.has("debuff"):
				await _buff(t, fx["debuff"])
			if fx.has("status") and randf() < float(fx.get("chance", 1.0)) * trick:
				await _inflict(t, fx["status"])
		"status":
			if not _hit_check(a, t, m):
				Sfx.play("miss")
				await msg("It missed %s!" % t.nickname, 0.6)
				return
			BeastModel.pose_hit(_model(t), 0.1)
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


## `a` is the attacker beast, or null for a trainer's weapon and bombs. quiet: one hit of a beat attack's chain, which
## goes on without stopping: no messages (and no waiting), and the camera keeps its shot.
func _deal(a, t, r: Dictionary, quiet := false) -> int:
	# The summon owns its wide shot through all hits; regular attacks hold on their actual retargeted victim.
	# (a cast's cut to where it lands already holds on it)
	if (floating == null or floating.visible) and not _impact_on(t) and not quiet:
		_camera_shot("reaction", t)
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
	# knocked back as hard as the hit was (a quarter of its HP or more: all the way), harder for a critical or extra
	# effective one; a defended, resisted or absorbed hit is blocked
	var blocked: bool = s["defend"] or r["eff"] < 1.0 or dmg <= 0
	_hit_fx(t, r["crit"] or r["eff"] > 1.0, float(dmg) / maxf(float(t.max_hp()), 1.0) * 4.0, blocked)
	_float_text(t, "-%d" % dmg if dmg > 0 else "0", Color("#ffe060") if r["eff"] > 1.0 else Color("#ffffff"))
	_refresh()
	if quiet:
		if t.hp > 0 and t.status == "sleep" and randf() < 0.3:
			t.status = ""
			_refresh()
		return dmg
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
	_set_acting("trainer_self")
	await msg("You raise your flute and play the %s to %s..." % [SongDB.song_name(song), guardian_b.nickname], 0.8)
	var r: Dictionary = await UI.flute_ex(song, "Winning over %s  —  the cleaner you play, the surer it is" % guardian_b.nickname)
	_battle_music()
	var acc := float(r["acc"])
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _song_fx(PLAYER_POS, [guardian_b], true, acc < SongDB.FLAT_ACCURACY)
	await _guardian_capture(acc)
	if star and result == "":
		await msg("Your mastery of the %s improved!" % SongDB.song_name(song), 1.0)
	return true


## The temple's song reaches the guardian: a weakened guardian that hears it well is captured, ending the battle.
func _guardian_capture(acc: float) -> void:
	var t = guardian_b
	if t == null or t.hp <= 0:
		return
	_camera_shot("capture", t)
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
		if lesson_id == "summon" and tk != "water":
			continue
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
	_set_acting("trainer_self")
	await msg("You raise your flute and play the %s..." % SongDB.song_name(song), 0.7)
	var r: Dictionary = await UI.flute_ex(song, "Summoning %s  —  play its song through to call it" % who, {"lesson": tutorial})
	_battle_music()
	var acc := float(r["acc"])
	GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	# the song goes out to the foes the summon will strike
	await _song_fx(PLAYER_POS, _alive(foe_slots), true, acc < SongDB.FLAT_ACCURACY)
	if acc < SongDB.FLAT_ACCURACY:
		Sfx.play("fail")
		await msg("The song falters... %s doesn't answer." % who, 1.1)
		_set_acting(null)
		if lesson_id == "summon":
			await _tut_say(["No shield spent. Let's try that song again; play the notes in order before the bar runs out."])
			return await _summon_flow()
		return {"type": "none"}
	summoned = true
	GameState.shield -= 1
	Sfx.play("shield")
	_shield_pulse(shield_bubble)
	_update_shield()
	_refresh()
	await msg("%s hears your call! (one shield point spent)" % who, 0.9)
	_set_acting(null)
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
	_camera_shot("summon")
	# Summons own the frame; even brief HP tags wait until the cinematic ends.
	floating.visible = false


func summon_release() -> void:
	_camera_shot("return")
	floating.visible = true


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
	if stage_rim != null:
		tw.tween_property(stage_rim, "light_energy", float(_stage_light[2]) * k, 0.5)


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
			_camera_shot("knockout", b)
			var beaten_foe: bool = team == "foe"
			# Ring beasts on either side remain lying on their pads. Only defeated wild beasts leave the field.
			Sfx.play("defeat" if beaten_foe else "faint")
			if nodes.has(b):
				var n: Node3D = nodes[b]
				var tw := create_tween()
				if beaten_foe and wild:
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
	if lesson.get("egg", false) or randf() < GameState.egg_chance():
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
			amt = maxi(0, b.xp_for_level(int(lesson["level"])) - b.xp - int(pending_xp.get(b, 0)))
			if amt == 0:
				continue
		if b.level <= 3:
			amt = maxi(amt, 4)
		if b.at_cap():
			continue
		pending_xp[b] = int(pending_xp.get(b, 0)) + amt


## Resolve each beast in party order. Growth cannot heal or change a model in the middle of a round.
func _finish_growth() -> void:
	for b in GameState.party:
		var amt := int(pending_xp.get(b, 0))
		if amt <= 0:
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
					await UI.beast_cinematic("level", e["before"], e["look"])
					_refresh()
				"evolve":
					await UI.beast_cinematic("evolve", e["before"], e["after"])
					_remodel(b)
					who = e["to"]
					GameState.caught[str(e["after"]["race"])] = true
					GameState.seen[str(e["after"]["race"])] = true
				"learn":
					var mn: String = MoveDB.get_move(e["move"])["name"]
					if e["active"]:
						await msg("%s learned %s!" % [who, mn], 0.8)
					else:
						await Menus.decide_learn(b, e["move"])
				"cap":
					await msg("%s reached its level limit! Merge it at a Beast Center to grow stronger." % who, 1.6)
	pending_xp.clear()


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
	Sfx.percussion("off")
	match result:
		"win":
			_camera_shot("victory")
			Sfx.music("victory")
			# At the level cap there may be no reward messages to hold the victory shot on screen.
			if wild and pending_xp.is_empty() and drops.is_empty():
				await msg("You won!", 0.75)
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
	await _finish_growth()
	if result != "lose":
		for d in drops:
			# each egg has its own short film, like a level-up's (beast_cinematic.gd "egg")
			GameState.add_egg(int(d["race"]), bool(d["ghost"]))
			var found: Dictionary = GameState.eggs.back()
			await msg("%s left something behind..." % d["name"], 0.7)
			await UI.beast_cinematic("egg", {"name": String(d["name"])}, {}, found)
			await msg("You found %s %s!" % ["an" if GameState.egg_name(found).substr(0, 1) in ["A", "E", "I", "O", "U"] else "a", GameState.egg_name(found)], 0.9)
		if lesson_id == "flute" and result == "win":
			GameState.set_flag("flute_lesson_done")
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
		var beat_line := BeatChain.level_line(GameState.trainer_level - gained, GameState.trainer_level)
		if beat_line != "":
			await msg(beat_line if GameState.flag("dance_lesson_done") or GameState.trainer_level == 4 else "Once you learn rhythm attacks from Lucille in Dustwell, your weapons can chain up to %d hits." % BeatChain.max_hits(GameState.trainer_level), 1.6)
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
## A cast under way (_cast): its glow's colour, and whether it's kindly (a heal or a boost: rising motes where it
## lands, rather than a burst)
var _casting := false
var _cast_col := Color.WHITE
var _cast_soft := false
const CAST_SOUND := {"fire": "fire", "water": "ice", "earth": "smash", "air": "fly", "ghost": "ghost"}


## What a beast is drawn with on the field: its rig, or its old model (a legendary's, a robot's); null off it.
func _model(b) -> Node3D:
	if not nodes.has(b) or not is_instance_valid(nodes[b]):
		return null
	var h: Node3D = nodes[b].get_node_or_null("Model")
	return h.get_child(0) as Node3D if h != null and h.get_child_count() > 0 else null


## A move cast (beast_model.gd pose_cast): the shot on the caster as its glow gathers and it lets go, then a cut to
## where it lands (on whoever it's aimed at, or all of a side; none on itself), the glow streaking in from the caster's
## side. _apply_move bursts it on each one it reaches (_cast_land), and their hits and numbers land with it.
func _cast(b, m: Dictionary, targets: Array) -> void:
	var el := String(m["el"])
	_casting = true
	_cast_col = Elements.color(el) if el != "neutral" else Color(1.0, 0.97, 0.9)
	_cast_soft = _team(b) == _team(targets[0]) if typeof(targets[0]) != TYPE_STRING else false
	_camera_shot("cast", b)
	var wind := BeastModel.pose_cast(_model(b), _cast_col)
	await get_tree().create_timer(wind).timeout
	Sfx.play(String(CAST_SOUND.get(el, "buff")))
	var onto := targets.filter(func(t): return typeof(t) != TYPE_STRING and t != b and nodes.has(t))
	# (the glow let go, seen leaving before the cut)
	await get_tree().create_timer(0.24).timeout
	if onto.is_empty():
		return
	_camera_shot("impact", onto[0] if onto.size() == 1 else onto)
	var streak := 0.16
	for t in onto:
		_cast_streak(b, t, streak)
	await get_tree().create_timer(streak).timeout


## The cast's glow flying in to `t` from the caster's side, gone as it reaches it (the burst is _cast_land's).
func _cast_streak(b, t, time: float) -> void:
	var to = _ref_pos(t)
	var from = _ref_pos(b)
	if to == null or from == null:
		return
	var h := _ref_height(t)
	var end: Vector3 = to + Vector3.UP * h * 0.55
	var dir: Vector3 = (to - from)
	dir.y = 0.0
	dir = dir.normalized()
	var orb: Node3D = CastGlow.new()
	add_child(orb)
	orb.position = end - dir * (1.6 + h * 0.6) + Vector3.UP * 0.25
	orb.scale = Vector3.ONE * clampf(h, 0.8, 1.8) * 1.4
	orb.begin(_cast_col)
	orb.gather(1.0)
	var tw := create_tween()
	tw.tween_property(orb, "position", end - dir * 0.15, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(orb.queue_free)


## A cast landing on `t` (_apply_move): a burst in its colour (rising motes, for a kindly one), or one off to its side
## where it missed.
func _cast_land(t, miss := false) -> void:
	if not _casting:
		return
	var at = _ref_pos(t)
	if at == null:
		return
	var h := _ref_height(t)
	var spot: Vector3 = at + Vector3.UP * h * 0.55
	if miss:
		spot += cam.global_basis.x * (0.5 + h * 0.3)
	CastGlow.burst(self, spot, _cast_col, clampf(h, 0.8, 2.0) * (1.4 if not _cast_soft else 1.0), _cast_soft)


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


## A hit landing on `b` (the frame its number appears): a flash, and its hit pose (beast_model.gd): knocked back `k`
## (0..1) as hard as it was, heavier if `big` (a critical or extra effective hit), or a quick block.
func _hit_fx(b, big: bool, k := 0.3, blocked := false) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var flash: StandardMaterial3D = n.get_meta("flash")
	var tw := create_tween()
	tw.tween_property(flash, "albedo_color", Color(1, 1, 1, 0.85), 0.05)
	tw.tween_property(flash, "albedo_color", Color(1, 0.3, 0.3, 0.5), 0.08)
	tw.tween_property(flash, "albedo_color", Color(1, 1, 1, 0.0), 0.14)
	if blocked:
		BeastModel.pose_block(_model(b))
	else:
		BeastModel.pose_hit(_model(b), k, big)


## Whether a cast's cut to where it lands (the camera's "impact" shot) is on `t` now, or about to be.
func _impact_on(t) -> bool:
	if camera_director == null:
		return false
	var on = null
	if camera_director.shot == "impact":
		on = camera_director.source
	elif camera_director.pending == "impact":
		on = camera_director.pending_source
	else:
		return false
	return (on is Array and (on as Array).has(t)) or (not on is Array and is_same(on, t))


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
	# damage and healing numbers in the body font
	l.font = UIKit.font_body()
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
