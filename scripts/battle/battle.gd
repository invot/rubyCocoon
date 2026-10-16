extends Node3D
## Turn-based battle: up to three beasts per side, plus the trainer's own turn.
## Fire = offense tanks, Water = healers, Earth = defenders, Air = status/evasion, Ghost = Legion.
## When all your beasts are down, foes attack you directly: each hit costs one shield point,
## and a hit with no shield left loses the battle.

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
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Bar = preload("res://scripts/ui/bar.gd")

const ALLY_POS := [Vector3(-1.7, 0, 1.5), Vector3(-3.5, 0, 0.5), Vector3(-5.3, 0, -0.5)]
const FOE_POS := [Vector3(1.7, 0, -1.3), Vector3(3.5, 0, -2.3), Vector3(5.3, 0, -3.3)]
const PLAYER_POS := Vector3(-7.0, 0, -1.5)
const RIVAL_POS := Vector3(7.2, 0, -4.6)
const CAM_POS := Vector3(0.0, 4.6, 9.8)
const CAM_LOOK := Vector3(0, 0.0, -1.6)
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
var round_no := 0
var biome: Dictionary
var indoor := false
var exposed := false
var drops: Array = []
## songs the rival trainer played this battle (song id -> true); you may try to learn them afterwards
var heard_songs := {}
var rival_song_count := 0
## Scout Bram's scripted first battle: only the taught option can be picked each round, and you always win.
var tutorial := false
## what the trainer and the beast must do each tutorial round (1-based)
const TUTORIAL_PLAN := {1: "Slingshot", 2: "Watch", 3: "Items"}
const TUTORIAL_BEAST := {1: "Fight", 2: "Defend", 3: "Fight"}
## Defending halves the damage a beast takes for the rest of the round.
const DEFEND_MULT := 0.5

var cam: Camera3D
var arrow: Label3D
var _arrow_target = null
var _time := 0.0
var player_rig: Node3D
var rival_rig: Node3D
var shield_label: Label3D
var shield_bubble: MeshInstance3D

var hud: Control
var msg_label: Label
var ally_panels: Array = []
var foe_panels: Array = []


func setup(c: Dictionary) -> void:
	cfg = c
	wild = c.get("wild", true)
	foes = c["foes"]
	trainer = c.get("trainer", {})
	tutorial = bool(trainer.get("tutorial", false))
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
	return not wild and (trainer.get("boss", false) or trainer.get("guardian", false))


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
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(biome["sun"]) if not dark else Color("#d8c8ff")
	sun.light_energy = float(biome["sun_e"]) if not dark else 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", randi()))
	var sandy: bool = biome["id"] in ["desert", "mesa", "western"]
	var ground_tex: Texture2D
	if arena:
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
	ground.position = Vector3(0, 0, -10)
	add_child(ground)
	# a low cobbled mound under each side: a flat oval top with a sloping rim
	for center in [Vector3(-3.5, 0, 0.5), Vector3(3.5, 0, -2.3)]:
		var k := VBld.Kit.new()
		var col := Color(biome["path"] if not arena else biome["plaza"]) if not dark else Color("#5a5664")
		var tex := "cobble" if not dark else "stone_dark"
		var n := 14
		var top := []
		var foot := []
		for i in n:
			var a := TAU * i / n
			var wob := 1.0 + rng.randf_range(-0.05, 0.05)
			top.append(Vector3(cos(a) * 3.6 * wob, 0.14, sin(a) * 2.1 * wob))
			foot.append(Vector3(cos(a) * 4.0 * wob, -0.02, sin(a) * 2.45 * wob))
		for i in n:
			var j := (i + 1) % n
			k.poly(tex, [Vector3(0, 0.14, 0), top[i], top[j]], Vector3.UP, col)
			var out: Vector3 = (top[i] + top[j]).normalized()
			k.poly(tex, [top[i], top[j], foot[j], foot[i]], (out + Vector3(0, 0.6, 0)).normalized(), col.darkened(0.12))
		var mi := MeshInstance3D.new()
		mi.mesh = k.mesh()
		mi.position = center
		add_child(mi)
	if arena:
		_arena_scenery(rng)
	elif dark:
		_indoor_scenery(rng)
	else:
		_outdoor_scenery(rng)

	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = CAM_POS
	cam.look_at(CAM_LOOK, Vector3.UP)
	cam.current = true
	arrow = Label3D.new()
	arrow.text = "▼"
	arrow.font_size = 64
	arrow.outline_size = 12
	arrow.modulate = Color("#ffd060")
	arrow.pixel_size = 0.008
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.visible = false
	add_child(arrow)
	_build_trainers()


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
	for i in 46:
		var p := Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-6, 4))
		if absf(p.x) < 7.2 and p.z > -4.2 and p.z < 3.0:
			p.x = (7.2 + rng.randf_range(0, 3)) * signf(p.x + 0.01)
		tufts[i % 3].append(_xf(p, rng.randi_range(0, 3) * PI / 2.0, rng.randf_range(0.9, 1.3)))
	for i in 3:
		_multimesh(VP.grass_tuft(biome["tuft"], i), tufts[i])
	if biome["id"] in ["coast", "island", "river"]:
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
	player_rig = VPer.build(GameState.main.world.PLAYER_LOOK if is_instance_valid(GameState.main) and GameState.main.world != null else {})
	player_rig.position = PLAYER_POS
	VPer.face(player_rig, Vector2i(1, 0))
	player_rig.rotation.y -= 0.35
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
	if String(trainer.get("robot_body", "")) != "":
		rival_rig = Node3D.new()
		rival_rig.add_child(VA.instance(String(trainer["robot_body"]), 1.9))
		rival_rig.rotation.y = PI / 2.0
	elif not look.is_empty():
		rival_rig = VPer.build(look)
		VPer.face(rival_rig, Vector2i(-1, 0))
		rival_rig.rotation.y += 0.35
	if rival_rig:
		rival_rig.position = RIVAL_POS
		add_child(rival_rig)


func _update_shield() -> void:
	if shield_label == null:
		return
	if GameState.max_shield <= 0:
		shield_label.text = ""
		return
	shield_label.text = "◆".repeat(GameState.shield) + "◇".repeat(GameState.max_shield - GameState.shield)


func _process(delta: float) -> void:
	_time += delta
	for b in nodes:
		var n: Node3D = nodes[b]
		if is_instance_valid(n) and n.has_meta("phase"):
			var m: Node3D = n.get_node_or_null("Model")
			if m:
				m.position.y = float(n.get_meta("lift")) + absf(sin(_time * 2.4 + float(n.get_meta("phase")))) * 0.05
	if is_instance_valid(player_rig):
		VPer.animate(player_rig, 0.0, 0.0)
	if is_instance_valid(cam):
		cam.position = CAM_POS + Vector3(sin(_time * 0.21) * 0.35, sin(_time * 0.17) * 0.08, 0)
		cam.look_at(CAM_LOOK, Vector3.UP)
	if _arrow_target != null and nodes.has(_arrow_target) and is_instance_valid(nodes[_arrow_target]):
		var n2: Node3D = nodes[_arrow_target]
		arrow.visible = true
		arrow.position = n2.position + Vector3(0, float(n2.get_meta("height")) + 0.35 + sin(_time * 6.0) * 0.08, 0)
	elif typeof(_arrow_target) == TYPE_STRING and _arrow_target == "trainer":
		arrow.visible = true
		arrow.position = PLAYER_POS + Vector3(0, 2.0 + sin(_time * 6.0) * 0.08, 0)
	else:
		arrow.visible = false


func _point_at(b) -> void:
	_arrow_target = b


func _spawn(b, side: String, slot: int) -> void:
	var root := Node3D.new()
	var model: Node3D
	var height := 1.2
	if b.genes.has("model"):
		model = VA.instance(String(b.genes["model"]), 1.3 * float(b.genes.get("size", 1.0)))
		height = 1.3 * float(b.genes.get("size", 1.0))
		model.rotation.y = PI / 2.0
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = VB.mesh(b.genes)
		model = mi
		height = mi.mesh.get_aabb().end.y
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(model)
	root.add_child(holder)
	var lift := 0.0
	if b.genes.get("body", "") in ["fish", "bird"]:
		lift = 0.35
	holder.position.y = lift
	root.rotation.y = -0.45 if side == "ally" else PI + 0.45
	root.position = (ALLY_POS if side == "ally" else FOE_POS)[slot]
	root.set_meta("height", height + lift)
	root.set_meta("lift", lift)
	root.set_meta("phase", randf() * TAU)
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color(1, 1, 1, 0)
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	root.set_meta("flash", flash)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		gi.material_overlay = flash
	add_child(root)
	nodes[b] = root
	root.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var s := _st(b)
	s["side"] = side
	s["down"] = false
	if side == "foe":
		GameState.mark_seen(b)
	else:
		participants[b] = true


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
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.hud.add_child(hud)
	var touch: bool = UI.is_touch()
	var reserve: float = UI.bottom_reserve()
	var pw := 236.0 if touch else 300.0
	# your beasts stand on the left of the field, the foes on the right: their readouts match
	var ally_row := VBoxContainer.new()
	ally_row.add_theme_constant_override("separation", 6)
	ally_row.position = Vector2(16, 12)
	hud.add_child(ally_row)
	var foe_row := VBoxContainer.new()
	foe_row.add_theme_constant_override("separation", 6)
	foe_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	foe_row.offset_left = -16 - pw
	foe_row.offset_right = -16
	foe_row.offset_top = 12
	foe_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(foe_row)
	for i in 3:
		foe_panels.append(_make_panel(foe_row, pw, false))
		ally_panels.append(_make_panel(ally_row, pw, true))
	# battle text looks like the dialogue box: same panel, same text size, three lines tall
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UIKit.box("dialogue", Vector4(26, 8, 26, 4)))
	mp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mp.offset_left = 270.0 if touch else 16.0
	mp.offset_right = -270.0 if touch else -450.0
	mp.offset_top = -10.0 - (3.0 * UIKit.body_px(UIKit.BODY_HUGE) + 44.0) - reserve
	mp.offset_bottom = -10.0 - reserve
	hud.add_child(mp)
	msg_label = UIKit.label("", UIKit.BODY_HUGE, UIKit.INK)
	msg_label.add_theme_constant_override("line_spacing", 0)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	mp.add_child(msg_label)


func _make_panel(row: BoxContainer, width: float, ally: bool) -> Dictionary:
	var p := UIKit.dark_panel(Vector2(width, 0))
	row.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	p.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)
	var tag_holder := HBoxContainer.new()
	top.add_child(tag_holder)
	var name_l := UIKit.label("", 20, UIKit.LIGHT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	top.add_child(name_l)
	var lv := UIKit.label("", 20, UIKit.GOLD_BRIGHT)
	top.add_child(lv)
	var bar := Bar.new(Vector2(width - 20, 30))
	vb.add_child(bar)
	var mpb := Bar.new(Vector2(width - 20, 8))
	mpb.fixed_color = Color("#5aa8ff")
	vb.add_child(mpb)
	var bottom := HBoxContainer.new()
	vb.add_child(bottom)
	var status := UIKit.label("", 20, UIKit.ORANGE)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	bottom.add_child(status)
	var hp := UIKit.label("", 20, UIKit.LIGHT)
	hp.visible = ally
	bottom.add_child(hp)
	p.visible = false
	return {"root": p, "name": name_l, "lv": lv, "bar": bar, "mp": mpb, "status": status, "hp": hp, "tags": tag_holder, "beast": null}


func _refresh() -> void:
	for side in [[ally_slots, ally_panels], [foe_slots, foe_panels]]:
		var slots: Array = side[0]
		var panels: Array = side[1]
		for i in 3:
			var b = slots[i]
			var p: Dictionary = panels[i]
			if b == null:
				p["root"].visible = false
				p["beast"] = null
				continue
			p["root"].visible = true
			if p["beast"] != b:
				p["beast"] = b
				for c in p["tags"].get_children():
					c.queue_free()
				p["tags"].add_child(UIKit.element_tag(b.element, 12))
				p["bar"].set_ratio(b.hp_ratio(), true)
				p["mp"].set_ratio(b.mp_ratio(), true)
			p["name"].text = " " + b.nickname
			p["lv"].text = "Lv%d" % b.level
			p["bar"].set_ratio(b.hp_ratio())
			p["mp"].set_ratio(b.mp_ratio())
			p["hp"].text = "%d/%d  MP %d" % [maxi(0, b.hp), b.max_hp(), b.mp]
			var s := _st(b)
			var bits := []
			if b.status != "":
				bits.append(MoveDB.STATUS_NAMES.get(b.status, b.status))
			if s["shield"] > 0:
				bits.append("Shield")
			if s["taunt"] > 0:
				bits.append("Taunting")
			if s["regen"] > 0:
				bits.append("Regen")
			if s["defend"]:
				bits.append("Defending")
			for k in s["stages"]:
				var v: int = s["stages"][k]
				if v != 0:
					bits.append("%s%s%d" % [k.to_upper(), "+" if v > 0 else "", v])
			p["status"].text = " ".join(bits)
	_update_shield()


func msg(text: String, wait := 0.95) -> void:
	msg_label.text = text
	var t := 0.0
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.12 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact")):
			break


# ================================================================ main loop
func _run() -> void:
	await get_tree().process_frame
	var alive := GameState.alive_party()
	for i in mini(3, alive.size()):
		ally_slots[i] = alive[i]
	for i in mini(3, foes.size()):
		foe_slots[i] = foes[i]
		_spawn(foes[i], "foe", i)
	_refresh()
	if wild:
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
		for i in 3:
			if foe_slots[i] != null:
				names2.append(foe_slots[i].nickname)
		await msg("%s sent out %s!" % [trainer.get("name", "The trainer"), ", ".join(names2)])
	var go := []
	for i in 3:
		if ally_slots[i] != null:
			_spawn(ally_slots[i], "ally", i)
			go.append(ally_slots[i].nickname)
	_refresh()
	if not go.is_empty():
		await msg("Go, %s!" % ", ".join(go), 0.8)
	await _start_passives()
	_check_end()
	if tutorial:
		await _tut_say(["Battles go in rounds. Each round, YOU get a turn first, then every beast you sent out.",
			"Then the foe acts, and the fastest moves happen first. Let's take it one step at a time!"])
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
		if ambush != "player":
			acts += _ai_actions()
		await _resolve(acts)
		if result != "":
			break
		await _end_round()
		if result != "":
			break
		await _refill()
		_check_end()
		await _check_exposed()
	await _finish()
	finished.emit(result)


# ================================================================ tutorial
func _tut_say(lines: Array) -> void:
	await UI.say(lines, ("%s %s" % [trainer.get("cls", ""), trainer.get("name", "")]).strip_edges())


## The attack the tutorial teaches: the beast's own-element attack if it has one, else its first attack.
func _tut_move(b) -> String:
	var first := ""
	for mv in b.battle_moves():
		var m := MoveDB.get_move(mv)
		if m["kind"] == "attack" and m["target"] == "enemy":
			if first == "":
				first = mv
			if m["el"] == b.element:
				return mv
	return first if first != "" else "tackle"


func _tut_round_intro() -> void:
	var b = _alive(ally_slots)[0] if not _alive(ally_slots).is_empty() else null
	match round_no:
		1:
			await _tut_say(["First, YOUR turn. Every trainer packs a slingshot. It's small, but it helps!",
				"Pick Slingshot."])
		2:
			await _tut_say(["Uh oh. Nugget's puffing up for a big attack!",
				"This round, just Watch. Then have %s Defend: a defending beast takes only half the damage until the round ends." % (b.nickname if b != null else "your beast")])
		3:
			await _tut_say(["Ouch, Nugget nipped %s! When a beast gets hurt, patch it up." % (b.nickname if b != null else "your beast"),
				"Open Items and give it a Minor Potion. Then finish the battle!"])


func _tut_damage(a, t) -> int:
	if _st(t)["side"] == "ally":
		return clampi(2, 0, maxi(0, t.hp - 1))
	var mx: int = t.max_hp()
	if a == null:
		return mini(maxi(1, ceili(mx * 0.15)), maxi(0, t.hp - 1))
	if round_no >= 3:
		return t.hp
	return mini(maxi(1, ceili(mx * 0.35)), maxi(0, t.hp - 1))


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


func _check_end() -> void:
	if result != "":
		return
	var left := foes.filter(func(f): return f.hp > 0)
	if left.is_empty():
		result = "win"


## When every beast is down, the trainer stands alone behind their shield.
func _check_exposed() -> void:
	if result != "":
		return
	var any_alive := not GameState.alive_party().is_empty()
	if any_alive:
		exposed = false
		return
	if exposed:
		return
	exposed = true
	await msg("All your beasts are down! The foes turn on you...", 1.2)
	if GameState.shield > 0:
		_shield_pulse()
		await msg("Your shield crackles to life! It can block %d hit%s." % [GameState.shield, "" if GameState.shield == 1 else "s"], 1.1)
	else:
		await msg("You have no shield! One more hit and it's over. Revive a beast, or run!" if wild else "You have no shield! Revive a beast quickly!", 1.3)


# ================================================================ player commands
func _command_phase() -> Array:
	if cfg.get("autoplay", false):
		var auto := []
		for b in _alive(ally_slots):
			auto.append(_ai_choose(b))
		var ta := _auto_trainer_action()
		if not ta.is_empty():
			auto.append(ta)
		return auto
	flute_used = false
	var actors: Array = ["trainer"]
	for i in 3:
		if ally_slots[i] != null and ally_slots[i].hp > 0:
			actors.append(ally_slots[i])
	var acts := {}
	var reserved := []
	var locked := false
	var k := 0
	if tutorial and not cfg.get("autoplay", false):
		await _tut_round_intro()
	while k < actors.size():
		var who = actors[k]
		if typeof(who) == TYPE_STRING:
			_point_at("trainer")
			var ta: Dictionary = await _trainer_menu()
			if result != "":
				return []
			if ta.is_empty():
				continue
			if ta.get("type", "") in ["flute", "run_failed"]:
				locked = true
			acts[k] = ta
			k += 1
			continue
		var b = who
		_point_at(b)
		msg_label.text = "What will %s do?" % b.nickname
		var want_b: String = TUTORIAL_BEAST.get(round_no, "Fight")
		if tutorial:
			if want_b == "Defend":
				await _tut_say(["Now %s's turn. Choose Defend!" % b.nickname])
			else:
				await _tut_say(["Now it's %s's turn. Choose Fight, then %s!" % [b.nickname, MoveDB.get_move(_tut_move(b))["name"]]])
		var items := [
			{"text": "Fight", "desc": "Use one of %s's moves." % b.nickname},
			{"text": "Defend", "desc": "Brace for impact: %s takes half damage until the end of the round. Defending happens before anything else." % b.nickname},
			{"text": "Swap", "desc": "Scout Bram: \"Swapping is for when you've got more beasts!\"" if tutorial else "Switch %s with a benched beast." % b.nickname, "disabled": tutorial},
		]
		if tutorial:
			for it in items:
				if it["text"] != want_b:
					it["disabled"] = true
					it["desc"] = "Scout Bram: \"Not now! %s this round.\"" % want_b
		var can_back: bool = not (k == 1 and locked) and not tutorial
		var c: int = await UI.choose("%s  Lv%d" % [b.nickname, b.level], items, {"anchor": "bottom_right", "width": 300, "cancel": can_back, "margin": Vector2(20, 20)})
		if c == -1:
			if can_back:
				var prev: Dictionary = acts.get(k - 1, {})
				if prev.get("type", "") == "swap":
					reserved.erase(prev["with"])
				acts.erase(k - 1)
				k -= 1
			continue
		var act := {}
		if c == 0:
			act = await _choose_move(b)
		elif c == 1:
			act = {"type": "defend", "actor": b, "prio": 7}
		else:
			act = await _choose_swap(b, reserved)
			if not act.is_empty():
				reserved.append(act["with"])
		if act.is_empty():
			continue
		acts[k] = act
		k += 1
	_point_at(null)
	return acts.values()


## The trainer's own action. Returns an action dict, or {} to ask again.
func _trainer_menu() -> Dictionary:
	msg_label.text = "What will you do, %s?" % GameState.player_name
	var shield := ""
	if GameState.max_shield > 0:
		shield = "   Shield " + "◆".repeat(GameState.shield) + "◇".repeat(GameState.max_shield - GameState.shield)
	var items := [
		{"text": "Slingshot", "desc": "Fire a stone at a foe. Small, but it never hurts to help!"},
		{"text": "Items", "desc": "Heal, cure or revive your beasts, buff your team, or hit the foes with bombs and powders."},
		{"text": "Flute", "desc": "Play a song: lift your team, weaken the foes, or charm a wild beast into joining you." if GameState.has_flute() else "You don't have a flute yet. Your uncle in Tidewater is keeping your father's.",
			"disabled": not GameState.has_flute()},
		{"text": "Watch", "desc": "Let your beasts handle this round."},
		{"text": "Run", "desc": "Try to escape." if wild else "There's no running from this battle!", "disabled": not wild},
	]
	if tutorial:
		var want: String = TUTORIAL_PLAN.get(round_no, "Watch")
		for it in items:
			if it["text"] != want:
				it["disabled"] = true
				it["desc"] = "Scout Bram: \"Not yet! Try %s this round.\"" % want
	var c: int = await UI.choose("%s%s" % [GameState.player_name, shield], items, {"anchor": "bottom_right", "width": 320, "cancel": false, "rows": 5, "margin": Vector2(20, 20)})
	match c:
		0:
			var t = await _choose_target(_alive(foe_slots), "Target")
			if t == null:
				return {}
			return {"type": "slingshot", "target": t, "prio": 3}
		1:
			return await _choose_item()
		2:
			var played: bool = await _flute_flow()
			if result != "":
				return {"type": "none"}
			return {"type": "flute"} if played else {}
		3:
			return {"type": "none"}
		4:
			if await _try_run():
				result = "run"
				return {"type": "none"}
			return {"type": "run_failed"}
	return {}


func _auto_trainer_action() -> Dictionary:
	var foes_alive := _alive(foe_slots)
	if foes_alive.is_empty():
		return {}
	if round_no == 1 and GameState.knows_song("weaken"):
		return {"type": "player_song", "song": "weaken", "acc": 0.75, "prio": 4}
	if exposed and GameState.item_count("revival_seed") > 0:
		var kos := GameState.party.filter(func(x): return x.hp <= 0)
		if not kos.is_empty():
			return {"type": "item", "item": "revival_seed", "target": kos[0], "prio": 5}
	foes_alive.sort_custom(func(x, y): return x.hp_ratio() < y.hp_ratio())
	return {"type": "slingshot", "target": foes_alive[0], "prio": 3}


func _choose_move(b) -> Dictionary:
	var list: Array = b.battle_moves().duplicate()
	# out of MP? a regular attack is always there
	if not list.any(func(mv): return MoveDB.mp_cost(mv) == 0 and MoveDB.get_move(mv)["kind"] == "attack"):
		list.append("tackle")
	var s := _st(b)
	var items := []
	for mv in list:
		var m := MoveDB.get_move(mv)
		var cd: int = s["cd"].get(mv, 0)
		var right: String = m["el"].to_upper()
		if m.has("power"):
			right += "  %d" % m["power"]
		var desc := MoveDB.summary(mv)
		if cd > 0:
			desc = "Recharging for %d more turn(s).\n" % cd + desc
			right = "wait %d" % cd
		var eff_hint := ""
		if m["kind"] == "attack" and m["target"] == "enemy":
			var best := 0.0
			for f in _alive(foe_slots):
				best = maxf(best, Elements.multiplier(m["el"], f.element))
			if best >= 2.0:
				eff_hint = "  ★"
		var cost := MoveDB.mp_cost(mv)
		if cost > 0:
			if cd <= 0:
				right = "MP %d" % cost
			desc = "Costs %d MP (%s has %d).\n" % [cost, b.nickname, b.mp] + desc
		var off: bool = cd > 0 or (tutorial and mv != _tut_move(b)) or b.mp < cost
		if b.mp < cost and cd <= 0:
			desc = "Not enough MP! Heal at a Beast Center or use a Spirit Drop.\n" + desc
		if tutorial and mv != _tut_move(b):
			desc = "Scout Bram: \"Use %s for now. You'll try the others soon!\"" % MoveDB.get_move(_tut_move(b))["name"]
		items.append({"text": m["name"] + eff_hint, "right": right, "disabled": off, "desc": desc})
	var c: int = await UI.choose("Moves", items, {"anchor": "bottom_right", "width": 420, "rows": 5, "margin": Vector2(20, 20), "cancel": not tutorial,
		"start": maxi(0, list.find(_tut_move(b))) if tutorial else 0})
	if c < 0:
		return {}
	var mv: String = list[c]
	var m2 := MoveDB.get_move(mv)
	var target = null
	match m2["target"]:
		"enemy":
			target = await _choose_target(_alive(foe_slots), "Target")
			if target == null:
				return {}
		"ally":
			target = await _choose_target(_alive(ally_slots), "Which ally?")
			if target == null:
				return {}
		"ally_ko":
			var kos := GameState.party.filter(func(x): return x.hp <= 0)
			if kos.is_empty():
				await msg("No one needs reviving right now.", 0.8)
				return {}
			target = await _choose_target(kos, "Revive whom?")
			if target == null:
				return {}
	return {"type": "move", "actor": b, "move": mv, "target": target, "prio": int(m2.get("prio", 0))}


func _choose_target(list: Array, title: String):
	if list.is_empty():
		return null
	if list.size() == 1 and title == "Target":
		return list[0]
	var items := []
	for t in list:
		items.append({"text": t.nickname, "right": "%d%%" % int(t.hp_ratio() * 100) if t.hp > 0 else "fainted"})
	var c: int = await UI.choose(title, items, {"anchor": "bottom_right", "width": 360, "margin": Vector2(20, 20),
		"on_focus": func(k): _point_at(list[k])})
	if c < 0:
		return null
	return list[c]


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
		if s["kind"] == "charm":
			if not wild:
				why = "You can't charm another trainer's beasts."
			elif _charmable(sid).is_empty():
				why = ("None of these beasts will listen to it (max Lv %d)." % GameState.capture_cap()) if not s.get("ghost", false) else "Only ghost beasts listen to the Requiem."
		if tutorial and sid != "weaken":
			why = "Scout Bram: \"Play Weaken for now!\""
		var stars := GameState.mastery_stars(sid)
		var desc := (why + "\n" if why != "" else "") + SongDB.describe(sid) + "\nMastery " + "★".repeat(stars) + "☆".repeat(5 - stars)
		ids.append(sid)
		items.append({"text": s["name"], "right": SongDB.tag(sid), "disabled": why != "", "desc": desc})
	var c: int = await UI.choose("Play which song?", items, {"anchor": "bottom_right", "width": 460, "margin": Vector2(20, 20), "cancel": not tutorial})
	if c < 0:
		return false
	var song: String = ids[c]
	if SongDB.is_charm(song):
		return await _charm_flow(song)
	return await _effect_song_flow(song)


func _charmable(song: String) -> Array:
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
	_point_at(null)
	await msg("You raise your flute and play %s..." % s["name"], 0.6)
	var acc: float = await UI.flute(song, "%s  —  faster and cleaner means a stronger effect" % SongDB.tag(song))
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
	_point_at(t)
	var flawless: bool = GameState.needs_flawless(t)
	if flawless:
		await msg("%s is stronger than any of your beasts. Only a flawless performance will reach it!" % t.nickname, 1.2)
	await msg("You raise your flute and play %s..." % SongDB.get_song(song)["name"], 0.7)
	var sub := "Charming %s (Lv %d)  —  play it FLAWLESSLY: not a single wrong note!" % [t.nickname, t.level] if flawless \
		else "Charming %s (Lv %d)  —  faster and cleaner means a better chance" % [t.nickname, t.level]
	var r: Dictionary = await UI.flute_ex(song, sub, {"goal": {"no_mistakes": true}} if flawless else {})
	var acc: float = float(r["acc"])
	var mistakes: int = int(r["mistakes"])
	_battle_music()
	var chance := GameState.capture_chance(t, song, acc, mistakes)
	var star := GameState.add_mastery(song, 1 if acc >= 0.6 else 0)
	await _note_effect(t)
	if flawless and mistakes > 0:
		Sfx.play("fail")
		await msg("%d mistake%s... %s is too strong to be charmed by anything less than perfect." % [mistakes, "" if mistakes == 1 else "s", t.nickname], 1.4)
		if star:
			UI.toast("Your mastery of %s improved!" % SongDB.get_song(song)["name"], UIKit.GOLD)
		_point_at(null)
		return true
	if mistakes == 0 and not r.get("cancelled", false):
		await msg("A flawless performance!", 0.6)
	if randf() < chance:
		Sfx.play("capture")
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
	_point_at(null)
	return true


## Applies an effect song played by `side` ("ally" = you, "foe" = the rival trainer) with accuracy `acc`.
func _apply_song(song: String, acc: float, side: String, target) -> void:
	var s := SongDB.get_song(song)
	var mine: Array = ally_slots if side == "ally" else foe_slots
	var theirs: Array = foe_slots if side == "ally" else ally_slots
	_song_fx(PLAYER_POS if side == "ally" else RIVAL_POS, side == "ally")
	if acc < SongDB.FLAT_ACCURACY:
		Sfx.play("fail")
		await msg("The melody falls flat... nothing happens.", 0.9)
		return
	var great := acc >= SongDB.GREAT_ACCURACY
	var mastery := GameState.mastery_stars(song) if side == "ally" else 2
	var power := (0.6 + acc) * (1.0 + 0.06 * mastery)
	if great:
		await msg("A stirring performance!", 0.6)
	var targets := []
	match s["target"]:
		"enemies":
			targets = _alive(theirs)
		"allies":
			targets = _alive(mine)
		_:
			var pool := _alive(theirs if s["target"] == "enemy" else mine)
			if target != null and pool.has(target):
				targets = [target]
			elif not pool.is_empty():
				targets = [pool.pick_random()]
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


## Musical notes drifting from the player (or rival) toward the other side.
func _song_fx(from: Vector3, toward_foes: bool) -> void:
	var dir := 1.0 if toward_foes else -1.0
	for i in 7:
		var l := Label3D.new()
		l.text = "♪" if i % 2 == 0 else "♫"
		l.font_size = 60
		l.outline_size = 8
		l.modulate = Color("#ffe080") if toward_foes else Color("#e0a0ff")
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = from + Vector3(0.3 * dir, 1.6, 0)
		add_child(l)
		var end := from + Vector3(dir * (5.0 + i * 0.9), 1.2 + sin(i * 1.7) * 0.8, -1.0 - i * 0.2)
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_property(l, "position", end, 1.0)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0)
		tw.tween_callback(l.queue_free)


## The rival trainer's flute: the song as you'd first learn it.
func _rival_melody(sid: String) -> void:
	_song_fx(RIVAL_POS, false)
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
	await _rival_melody(sid)
	var skill := clampf(float(trainer.get("flute_skill", 0.8)) * randf_range(0.9, 1.1), 0.0, 1.0)
	await _apply_song(sid, skill, "foe", null)


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
		ids.append(id)
		var lock: bool = tutorial and id != "minor_potion"
		items.append({"text": it["name"], "right": "x%d" % GameState.item_count(id), "disabled": lock,
			"desc": "Scout Bram: \"The Minor Potion, please!\"" if lock else it.get("desc", "")})
	if ids.is_empty():
		await msg("You have no usable items.", 0.8)
		return {}
	var c: int = await UI.choose("Items", items, {"anchor": "bottom_right", "width": 420, "margin": Vector2(20, 20), "cancel": not tutorial,
		"start": maxi(0, ids.find("minor_potion")) if tutorial else 0})
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


func _choose_swap(b, reserved: Array) -> Dictionary:
	var bench := GameState.party.filter(func(x): return x.hp > 0 and not ally_slots.has(x) and not reserved.has(x))
	if bench.is_empty():
		await msg("There's no one on the bench to swap in.", 0.8)
		return {}
	var items := []
	for x in bench:
		items.append({"text": x.nickname, "right": "Lv%d %d%%" % [x.level, int(x.hp_ratio() * 100)], "icon": PixelArt.beast_texture(x.genes)})
	var c: int = await UI.choose("Swap in whom?", items, {"anchor": "bottom_right", "width": 380, "margin": Vector2(20, 20)})
	if c < 0:
		return {}
	return {"type": "swap", "actor": b, "with": bench[c], "prio": 6}


func _try_run() -> bool:
	var mine := 0.0
	var theirs := 0.0
	for b in _alive(ally_slots):
		mine += _eff_stat(b, "spd")
	for b in _alive(foe_slots):
		theirs += _eff_stat(b, "spd")
	var chance := clampf(0.55 + (mine - theirs) / maxf(1.0, mine + theirs), 0.3, 0.95)
	if exposed:
		chance = 0.5
	if randf() < chance:
		Sfx.play("back")
		await msg("You got away safely!")
		return true
	await msg("Couldn't get away!")
	return false


# ================================================================ AI
func _ai_actions() -> Array:
	var out := []
	for b in foe_slots:
		if b != null and b.hp > 0:
			out.append(_ai_choose(b))
	if _rival_wants_song():
		out.append({"type": "rival_song", "song": String(trainer["song"]), "prio": 4})
	return out


func _ai_choose(b) -> Dictionary:
	if tutorial:
		var enemies0 := _alive(_theirs(b))
		if enemies0.is_empty():
			return {"type": "none"}
		return {"type": "move", "actor": b, "move": _tut_move(b), "target": enemies0[0], "prio": 0}
	var s := _st(b)
	var moves: Array = b.battle_moves().filter(func(mv): return int(s["cd"].get(mv, 0)) <= 0 and MoveDB.mp_cost(mv) <= b.mp)
	if moves.is_empty():
		moves = ["tackle"]
	var allies := _alive(_mine(b))
	var enemies := _alive(_theirs(b))
	if enemies.is_empty():
		if s["side"] == "foe" and exposed:
			return {"type": "strike_trainer", "actor": b, "prio": 0}
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
					var eff := Elements.multiplier(m["el"], e.element)
					var sc: float = float(m["power"]) * eff * (1.25 if m["el"] == b.element else 1.0) * float(m.get("acc", 100)) / 100.0
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
	return {"type": "move", "actor": b, "move": best_mv, "target": best_t, "prio": int(MoveDB.get_move(best_mv).get("prio", 0))}


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
		match a.get("type", "none"):
			"swap":
				await _do_swap(a)
			"item":
				await _do_item(a)
			"slingshot":
				await _do_slingshot(a)
			"strike_trainer":
				await _do_strike_trainer(a)
			"rival_song":
				await _do_rival_song(a)
			"player_song":
				await _apply_song(a["song"], float(a["acc"]), "ally", null)
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
		await _handle_faints()
		_check_end()
	if tutorial and round_no >= 3 and result == "":
		for f in _alive(foe_slots):
			f.hp = 0
			_refresh()
		await _handle_faints()
		_check_end()


func _do_swap(a: Dictionary) -> void:
	var b = a["actor"]
	var nb = a["with"]
	var i := ally_slots.find(b)
	if i < 0 or nb.hp <= 0 or ally_slots.has(nb):
		return
	await msg("%s, come back! Go, %s!" % [b.nickname, nb.nickname], 0.8)
	_despawn(b)
	st.erase(b)
	ally_slots[i] = nb
	_spawn(nb, "ally", i)
	_refresh()


## Puts a just-revived beast straight into an empty battle slot.
func _field_revived(t) -> void:
	if ally_slots.has(t):
		return
	for i in 3:
		if ally_slots[i] == null:
			ally_slots[i] = t
			_spawn(t, "ally", i)
			exposed = false
			return


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
	if t == null or t.hp <= 0 or not foe_slots.has(t):
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
		await _trainer_throw(_target_point(targets[0]) if not targets.is_empty() else FOE_POS[0], col)
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
		var eff := Elements.multiplier(bomb["el"], t.element)
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


func _shield_pulse() -> void:
	if shield_bubble == null:
		return
	var m: StandardMaterial3D = shield_bubble.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)


func _do_strike_trainer(a: Dictionary) -> void:
	var b = a["actor"]
	if b.hp <= 0 or not _active(b):
		return
	if not _alive(ally_slots).is_empty():
		var redo := _ai_choose(b)
		if redo.get("type", "") == "move":
			await _do_move(b, redo["move"], redo["target"])
		return
	_point_at("trainer")
	await msg("%s charges straight at %s!" % [b.nickname, GameState.player_name], 0.6)
	if nodes.has(b):
		var n: Node3D = nodes[b]
		var start := n.position
		var tw := create_tween()
		tw.tween_property(n, "position", start.lerp(PLAYER_POS, 0.75), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "position", start, 0.25)
		await get_tree().create_timer(0.22).timeout
	_point_at(null)
	if GameState.shield > 0:
		GameState.shield -= 1
		Sfx.play("shield")
		_shield_pulse()
		_update_shield()
		await msg("Your shield absorbed the blow! (%d left)" % GameState.shield, 0.9)
	else:
		Sfx.play("crit")
		await UI.flash(Color("#ff4040"), 1)
		if is_instance_valid(player_rig):
			var tw2 := create_tween()
			tw2.tween_property(player_rig, "rotation:z", -1.4, 0.3)
		await msg("%s was knocked off their feet!" % GameState.player_name, 1.2)
		result = "lose"


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
				var d := maxi(1, int(b.max_hp() * 0.08))
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
	_point_at(null)
	await msg("%s used %s!" % [b.nickname, m["name"]], 0.55)
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
			var t = target
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
	if t.element == "air":
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
				var rc := maxi(1, int(dealt * float(fx["recoil"])))
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
			st.erase(t)
			Sfx.play("heal")
			if _st(a)["side"] == "ally":
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
	var stab := 1.25 if m["el"] == a.element else 1.0
	var eff := Elements.multiplier(m["el"], t.element)
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
		await msg("A critical hit!", 0.55)
	if r["eff"] > 1.0:
		await msg("It's super effective!", 0.6)
	elif r["eff"] < 1.0:
		await msg("It's not very effective...", 0.6)
	if absorbed > 0:
		await msg("The shield absorbed %d damage." % absorbed, 0.55)
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
			var rd := maxi(1, int(dmg * refl))
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
		s["defend"] = false
		var cds: Dictionary = s["cd"]
		for mv in cds.keys():
			cds[mv] = int(cds[mv]) - 1
			if cds[mv] <= 0:
				cds.erase(mv)
	_refresh()
	await _handle_faints()
	_check_end()


func _tick_damage(b, d: int, text: String) -> void:
	b.hp = maxi(0, b.hp - d)
	_hit_fx(b, false)
	_float_text(b, "-%d" % d, Color("#c080ff"))
	_refresh()
	await msg(text % b.nickname, 0.6)


func _handle_faints() -> void:
	for side in [ally_slots, foe_slots]:
		for i in 3:
			var b = side[i]
			if b == null or b.hp > 0:
				continue
			var s := _st(b)
			if s["down"]:
				continue
			if b.gear_fx("phoenix", false) and not s["phoenix"]:
				s["phoenix"] = true
				b.hp = maxi(1, b.max_hp() / 4)
				Sfx.play("heal")
				_refresh()
				await msg("%s's Phoenix Plume blazes! It rises again!" % b.nickname, 1.0)
				continue
			s["down"] = true
			var beaten_foe: bool = _st(b)["side"] == "foe"
			# a beaten foe vanishes with a smack in a puff of smoke; your own beast just keels over
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
					tw.tween_property(n, "rotation:z", -1.4, 0.35)
					tw.parallel().tween_property(n, "position:y", -0.4, 0.5)
					tw.parallel().tween_property(n, "scale", Vector3(0.6, 0.6, 0.6), 0.5)
			await msg("%s fainted!" % b.nickname, 0.8)
			if nodes.has(b):
				nodes[b].queue_free()
				nodes.erase(b)
			side[i] = null
			_refresh()
			if is_same(side, foe_slots):
				_roll_egg(b)
				await _award_xp(b)


## Defeated wild beasts sometimes leave an egg (collected when the battle ends).
func _roll_egg(b) -> void:
	if not wild or RaceDB.is_robot(b.race) or RaceDB.is_legendary(b.race):
		return
	if b.ghost and not GameState.flag("ghost_merge"):
		return
	if randf() < EGG_CHANCE:
		drops.append({"race": b.race, "ghost": b.ghost, "name": b.nickname})


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
		if tutorial:
			amt = maxi(0, b.xp_for_level(2) - b.xp)
			if amt == 0:
				continue
		if b.level <= 3:
			amt = maxi(amt, 4)
		if b.at_cap():
			continue
		var events: Array = b.gain_xp(amt)
		if participants.has(b):
			await msg("%s gained %d XP." % [b.nickname, amt], 0.5)
		for e in events:
			match e["type"]:
				"level":
					Sfx.play("levelup")
					_refresh()
					await msg("%s grew to Lv %d!" % [b.nickname, e["level"]], 0.8)
				"learn":
					var mn: String = MoveDB.get_move(e["move"])["name"]
					if e["active"]:
						await msg("%s learned %s!" % [b.nickname, mn], 0.8)
					else:
						await msg("%s can now use %s! Swap it in from the Beasts menu." % [b.nickname, mn], 1.1)
				"cap":
					await msg("%s reached its level limit! Merge it at a Beast Center to grow stronger." % b.nickname, 1.6)
		if GameState.next_capture_ready() and not GameState.flag("capture_hint_%d" % GameState.capture_level()):
			GameState.set_flag("capture_hint_%d" % GameState.capture_level())
			Sfx.play("notify")
			await msg("%s reached Lv %d! You can now practise %s from the Flute page of your book." % [b.nickname, b.level,
				SongDB.get_song(SongDB.capture_id(GameState.capture_level() + 1))["name"]], 1.8)


func _refill() -> void:
	for i in 3:
		if foe_slots[i] != null:
			continue
		for f in foes:
			if f.hp > 0 and not foe_slots.has(f):
				foe_slots[i] = f
				_spawn(f, "foe", i)
				_refresh()
				await msg("%s sent out %s!" % [trainer.get("name", "The foe"), f.nickname], 0.8)
				break
	for i in 3:
		if ally_slots[i] != null:
			continue
		var bench := GameState.party.filter(func(x): return x.hp > 0 and not ally_slots.has(x))
		if bench.is_empty():
			continue
		var pick = bench[0]
		if bench.size() > 1:
			var items := []
			for x in bench:
				items.append({"text": x.nickname, "right": "Lv%d %d%%" % [x.level, int(x.hp_ratio() * 100)], "icon": PixelArt.beast_texture(x.genes)})
			var c: int = 0 if cfg.get("autoplay", false) else await UI.choose("Send out which beast?", items, {"anchor": "bottom_right", "cancel": false, "width": 380, "margin": Vector2(20, 20)})
			pick = bench[maxi(0, c)]
		ally_slots[i] = pick
		_spawn(pick, "ally", i)
		_refresh()
		await msg("Go, %s!" % pick.nickname, 0.7)


func _finish() -> void:
	_point_at(null)
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
			if GameState.lucky_battles > 0:
				GameState.lucky_battles -= 1
			if not cfg.get("autoplay", false) or UI.auto:
				for sid in heard_songs:
					if not GameState.knows_song(sid):
						await _learn_heard_song(sid)
		"lose":
			await msg("Everything goes dark...")
			await msg("You were carried to the nearest Beast Center.", 1.2)
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


# ================================================================ effects
func _lunge(b, attack: bool) -> void:
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var dir := 1.0 if _st(b)["side"] == "ally" else -1.0
	var start := n.position
	var tw := create_tween()
	if attack:
		tw.tween_property(n, "position", start + Vector3(0.6 * dir, 0.15, -0.25 * dir), 0.1)
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
	if not nodes.has(b):
		return
	var n: Node3D = nodes[b]
	var l := Label3D.new()
	l.text = text
	# damage and healing numbers in the chunky pixel font
	l.font = UIKit.font_head()
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
