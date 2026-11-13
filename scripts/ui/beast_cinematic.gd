extends "res://scripts/ui/modal.gd"
## One modal, isolated 3D stage for every hatch, evolution and level reward, and for an egg left behind after a battle
## ("egg": the shell drops into the light, turning, with its name; before.name is the beast that left it).
## Reveals finish before a fresh A/B press can dismiss a hatch, egg drop or level reward.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const EggModel = preload("res://scripts/gfx/egg_model.gd")
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const HatcheryStage = preload("res://scripts/gfx/hatchery_stage.gd")
const ActionIcons = preload("res://scripts/battle/action_icons.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")
## How far right of the beast a level-up's camera looks (world units), so the beast stands in the left part of the
## screen and its window has the right.
const LEVEL_SHIFT := 2.6
## This camera looks straight at the roundel chamber's walls, so they are kept down to leave the egg as the focus.
const HATCH_GLASS := 0.5
const HATCH_MIST := 1.8

var kind := "hatch"
var before := {}
var after := {}
var egg := {}
var elapsed := 0.0
var duration := 8.6
## Preview harness can hold a particular instant without changing the real timing.
var preview_time := -1.0
var _vp: SubViewport
var _screen: TextureRect
var _stage: Node3D
var _ring: Node3D
var _subject: Node3D
var _reveal: Node3D
var _cam: Camera3D
var _lamp: OmniLight3D
var _set: Node3D
var _glow: StandardMaterial3D
var _white: ColorRect
var _sound_played := false
var _ring_sound := false
var _motes: Array[MeshInstance3D] = []
const STAT_ORDER := ["hp", "mp", "atk", "def", "spr", "spd"]
const STAT_LABELS := ["HP", "MP", "Attack", "Defense", "Spirit", "Speed"]
## each stat's row (its cells), and each new move's row, revealed one at a time
var _stat_rows: Array = []
var _move_rows: Array[Control] = []
var _stat_window: PanelContainer
var _notice: Control
var _notice_text := ""


func _init() -> void:
	super._init()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# This stage owns its title and reward information; field/battle notices sit
	# behind the full-screen film instead of covering its heading.
	z_index = 1


func setup(mode: String, old_look: Dictionary, new_look := {}, shell := {}) -> Control:
	kind = mode
	before = old_look
	after = new_look if not new_look.is_empty() else old_look
	egg = shell
	duration = 4.2 if kind == "level" else (4.4 if kind == "egg" else (7.0 if kind == "evolve" else 8.6))
	if kind == "level":
		duration += 0.6 * mini(2, (after.get("learned", []) as Array).size())
	return self


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#141d29")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	add_child(_vp)
	var screen := TextureRect.new()
	_screen = screen
	screen.texture = _vp.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_build_stage()
	_ring = _set.core
	if kind == "hatch":
		_set.fit_shell(egg)
	_glow = _material(Color(1, 1, 1, 0), 1.0)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.emission_enabled = true
	_glow.emission = Color.WHITE
	_glow.emission_energy_multiplier = 2.0
	_subject = EggModel.build(egg) if kind == "hatch" else (Node3D.new() if kind == "egg" else stage_beast(before))
	_stage.add_child(_subject)
	_subject.position.y = 1.07
	_reveal = _found_egg() if kind == "egg" else stage_beast(after)
	_stage.add_child(_reveal)
	_reveal.position.y = 1.07
	_reveal.visible = false
	var shadow := _material(Color(0.035, 0.045, 0.055, 0.18))
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cylinder(_stage, Vector3(0, 1.075, 0), 0.53, 0.002, shadow)
	for mi in _subject.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _glow
	_cam = Camera3D.new()
	_cam.fov = 39
	_stage.add_child(_cam)
	_cam.current = true
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 2.4, 0)
	_lamp.omni_range = 5.0
	_lamp.light_color = HatcheryStage.INNER_LIGHT
	_lamp.light_cull_mask = 1
	_stage.add_child(_lamp)
	var spark := _material(Color("#fff1d6"))
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 24:
		var sphere := SphereMesh.new()
		sphere.radius = 0.018 + float(i % 3) * 0.008
		sphere.height = sphere.radius * 2
		var mote := _mesh(_stage, sphere, Vector3.ZERO, spark)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append(mote)
	_notice = preload("res://scripts/ui/top_bar.gd").new()
	add_child(_notice)
	if kind in ["level", "hatch"]:
		_level_window()
		_place_stats.call_deferred()
		get_viewport().size_changed.connect(_place_stats)
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)
	_update(0)


## A level-up's one window, on the right: the beast's name and element, its level going up, each stat's old and new
## value and gain, and any move it learned with the move's icon.
func _level_window() -> void:
	_stat_window = UIKit.panel()
	_stat_window.custom_minimum_size.x = 500
	_stat_window.add_theme_stylebox_override("panel", UIKit.window(Vector4(8, 6, 8, 8)))
	add_child(_stat_window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_stat_window.add_child(col)
	# name, with its element tags on the right
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var name_label := UIKit.header(String(after.get("name", "")), UIKit.INK, UIKit.HEAD_BIG)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	for el in after.get("elements", [after.get("element", "")]):
		if String(el) != "":
			var t := UIKit.element_tag(String(el), 18)
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(t)
	# "LEVEL UP" caption and the level going up
	var lv := HBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	col.add_child(lv)
	var cap := UIKit.label("Hatched" if kind == "hatch" else "Level up", 18, UIKit.DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(cap)
	var old_lv := int(before.get("level", int(after.get("level", 1)) - 1))
	if kind != "hatch":
		lv.add_child(UIKit.label("Lv %d" % old_lv, 32, UIKit.DIM))
		lv.add_child(UIKit.label("►", 32, UIKit.DIM))
	lv.add_child(UIKit.header("Lv %d" % int(after.get("level", old_lv + 1)), UIKit.HEAD, UIKit.HEAD_BIG))
	col.add_child(UIKit.divider(0.0, "none"))
	# the stats: name, old value, new value, gain
	var grid := GridContainer.new()
	grid.columns = 2 if kind == "hatch" else 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	for i in STAT_ORDER.size():
		var key: String = STAT_ORDER[i]
		var old := int(before.get("stats", {}).get(key, before.get(key, 0)))
		var current := int(after.get("stats", {}).get(key, after.get(key, old)))
		var cells: Array = [UIKit.label(STAT_LABELS[i], 32, UIKit.INK), UIKit.label(str(old), 32, UIKit.DIM),
			UIKit.label("►", 32, UIKit.DIM), UIKit.label(str(current), 32, UIKit.INK),
			UIKit.label(("+%d" % (current - old)) if current > old else "", 32, UIKit.GOLD)]
		if kind == "hatch":
			for c in [cells[1], cells[2], cells[4]]:
				c.free()
			cells = [cells[0], cells[3]]
		(cells[0] as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for c in cells.slice(1):
			(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if kind != "hatch":
			(cells[4] as Label).custom_minimum_size.x = 64
		for c in cells:
			grid.add_child(c)
		_stat_rows.append(cells)
	# moves it learned at this level
	var learned: Array = after.get("learned", [])
	if not learned.is_empty():
		col.add_child(UIKit.divider(0.0, "none"))
		var mcap := UIKit.label("New move" if learned.size() == 1 else "New moves", 18, UIKit.DIM)
		col.add_child(mcap)
		_move_rows.append(mcap)
		for e in learned:
			var id := String(e.get("move", "")) if e is Dictionary else String(e)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var icon := Control.new()
			icon.custom_minimum_size = Vector2(36, 36)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var kind_id := ActionIcons.for_move(id)
			icon.draw.connect(func(): ActionIcons.draw(icon, kind_id, icon.size / 2.0, 16.0))
			row.add_child(icon)
			var mname := UIKit.label(String(MoveDB.get_move(id).get("name", id)), 32, UIKit.INK)
			mname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(mname)
			if e is Dictionary and not bool(e.get("active", true)):
				var note := UIKit.label("In reserve", 18, UIKit.DIM)
				note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(note)
			col.add_child(row)
			_move_rows.append(row)


func _place_stats() -> void:
	if _stat_window == null:
		return
	var safe := UIKit.safe_rect(self).grow(-24)
	if _notice != null and _notice.visible:
		var top := maxf(safe.position.y, _notice.bottom() + 12.0)
		safe.size.y -= top - safe.position.y
		safe.position.y = top
	_stat_window.reset_size()
	var x := safe.end.x - 24.0 - _stat_window.size.x
	var reserve: float = UI.controls.menu_bottom_reserve(x, safe.end.x) if UI.controls != null else 0.0
	_stat_window.position = Vector2(x, maxf(safe.position.y, minf(safe.get_center().y - _stat_window.size.y / 2.0, safe.end.y - reserve - _stat_window.size.y)))


func _material(col: Color, rough := 0.75, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	return mat


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 48
	return _mesh(parent, mesh, pos, mat)


func _build_stage() -> void:
	_set = HatcheryStage.new()
	_stage.add_child(_set)
	if kind == "hatch":
		_set.build(true)
		_set.use_roundels()
		_set.hush_walls(HATCH_GLASS, HATCH_MIST)
	else:
		_set.build()


## The egg a beaten beast left: larger than life on the platform, so its shell and markings read.
func _found_egg() -> Node3D:
	var root := Node3D.new()
	var shell := EggModel.build(egg)
	shell.scale = Vector3.ONE * 1.35
	root.add_child(shell)
	return root


static func stage_beast(look: Dictionary) -> Node3D:
	var root := Node3D.new()
	var genes: Dictionary = look.genes
	var model: Node3D
	var bounds: AABB
	if BeastModel.rigged(genes):
		model = BeastModel.rig(genes)
		model.scale = Vector3.ONE
		bounds = BeastModel.bounds(model)
	elif genes.has("model"):
		model = VA.instance(String(genes.model), 1.8)
		bounds = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.8, 1.6))
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = VB.mesh(genes)
		bounds = mi.mesh.get_aabb()
		model = mi
	var extent := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z))
	# Both forms use the same camera and fit the platform; grown forms remain visibly larger.
	var s := 1.65 / maxf(extent, 0.1) * clampf(float(genes.get("size", 1.0)), 0.65, 1.25)
	model.scale = Vector3.ONE * s
	model.position = Vector3(-bounds.get_center().x * s, -bounds.position.y * s, -bounds.get_center().z * s)
	root.add_child(model)
	root.rotation.y = -PI * 0.5
	return root


func _process(delta: float) -> void:
	if _vp == null:
		return
	var render_size := Prefs.render_size(get_window().size)
	if _vp.size != render_size:
		_vp.size = render_size
	_screen.texture_filter = Prefs.render_filter(get_window().size)
	if preview_time >= 0:
		_update(preview_time)
		return
	elapsed += delta
	_update(elapsed)
	if elapsed >= duration and kind == "evolve":
		close()


func _update(t: float) -> void:
	var hatch := kind == "hatch"
	var found := kind == "egg"
	# (an egg found plays on the level-up's quiet stage: no machinery, no whiteout)
	var level := kind == "level" or found
	var reveal_at := 5.65 if hatch else (0.45 if level else 3.8)
	var glow_start := 4.5 if hatch else 1.4
	var revealed := t >= reveal_at
	_set.animate(t, hatch, revealed)
	_subject.visible = not revealed
	_reveal.visible = revealed
	var glow := smoothstep(glow_start, reveal_at - 0.15, t) if not level and not revealed else 0.0
	_glow.albedo_color = Color(1, 1, 1, glow)
	_subject.rotation.z = sin(t * 23) * glow * 0.045 if hatch else 0.0
	_lamp.light_energy = 0.08 + glow * 0.65
	var white := 0.0
	if not level:
		white = smoothstep(reveal_at - 0.60, reveal_at - 0.10, t) * (1.0 - smoothstep(reveal_at + 0.20, reveal_at + 1.15, t))
	_white.color = Color(1, 1, 1, white)
	if not _ring_sound and t >= 0.9 and hatch and preview_time < 0:
		_ring_sound = true
		Sfx.play("lever")
	if not _sound_played and revealed and preview_time < 0:
		_sound_played = true
		Sfx.play("hatch" if hatch else ("bird_cry" if found else ("levelup" if level else "merge")))
	var heading: String
	if hatch:
		heading = "%s hatched!" % after.name if revealed else EggLooks.name_for(egg)
	elif found:
		heading = EggLooks.name_for(egg)
	elif level:
		heading = "%s · Level %d" % [after.name, after.level]
	else:
		heading = "%s evolved!" % after.name if revealed else "%s is evolving..." % before.name
	var notice := heading
	if found:
		notice = "%s left %s!" % [String(before.get("name", "A beast")), EggLooks.name_for(egg)]
	if notice != _notice_text:
		_notice_text = notice
		_notice.post(notice, null, {"key": "reveal", "replace": true, "priority": true, "hold": 86400.0})
		_place_stats.call_deferred()
	if _stat_window != null:
		if _stat_window.visible != revealed:
			_stat_window.visible = revealed
			_place_stats.call_deferred()
	for i in _stat_rows.size():
		for c in _stat_rows[i]:
			(c as Control).modulate.a = 1.0 if t >= 0.65 + i * 0.4 else 0.0
	for i in _move_rows.size():
		_move_rows[i].modulate.a = 1.0 if t >= 0.65 + _stat_rows.size() * 0.4 + 0.2 + i * 0.3 else 0.0
	# Gentle dolly, generous framing at both 16:9 and 20:9; no aspect-dependent art stretching.
	var zoom := smoothstep(0.0, duration, t)
	# A hatch frames the egg and the core above it, then moves in on the beast while the screen is fully white.
	var near := smoothstep(5.5, 5.75, t) if hatch else 1.0
	# (a level-up looks to the right of the beast, leaving the right of the screen to its window)
	var shift := LEVEL_SHIFT * near if kind in ["level", "hatch"] else 0.0
	_cam.position = Vector3(1.5 - zoom * 0.9 + shift, 2.5 - zoom * 0.25 - near * 0.3, 11.3 - zoom * 1.5 - near * 2.3)
	_cam.look_at(Vector3(shift, lerpf(2.75, 2.15, near), 0))
	if level:
		_reveal.position.y = 1.07 + sin(clampf((t - reveal_at) / 0.65, 0, 1) * PI) * 0.20
		if found:
			# it drops in from the light, settles with a wobble, and turns slowly to show its markings
			var fall := clampf((t - reveal_at) / 0.55, 0.0, 1.0)
			_reveal.position.y = 1.07 + (1.0 - fall * fall) * 2.6 + sin(clampf((t - reveal_at - 0.55) / 0.5, 0, 1) * PI) * 0.12
			_reveal.rotation.y = t * 0.9
			_reveal.rotation.z = sin(t * 9.0) * 0.07 * clampf(1.6 - t, 0.0, 1.0)
		_ring.visible = false
		_lamp.light_energy = 0.4 + sin(t * 4.0) * 0.1
	for i in _motes.size():
		var a := float(i) * 2.4 + t * 0.6
		var rise := fposmod(float(i) * 0.23 + t * (0.85 if level else 0.40), 2.8)
		_motes[i].position = Vector3(cos(a) * 1.1, 1.1 + rise, sin(a) * 1.1)
		_motes[i].visible = level or t > glow_start


func on_input(ev: InputEvent) -> void:
	if preview_time >= 0 or elapsed < duration or ev.is_echo():
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact") or ev.is_action_pressed("ui_cancel"):
		close()
