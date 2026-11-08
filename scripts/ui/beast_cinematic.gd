extends "res://scripts/ui/modal.gd"
## One modal, isolated 3D stage for every hatch, evolution and level reward.
## Timed rather than confirm-driven: a held battle button cannot skip a reveal or select the next screen.
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const EggModel = preload("res://scripts/gfx/egg_model.gd")
const EggLooks = preload("res://scripts/data/egg_looks.gd")
const HatcheryStage = preload("res://scripts/gfx/hatchery_stage.gd")

var kind := "hatch"
var before := {}
var after := {}
var egg := {}
var elapsed := 0.0
var duration := 8.6
## Preview harness can hold a particular instant without changing the real timing.
var preview_time := -1.0
var _vp: SubViewport
var _stage: Node3D
var _ring: Node3D
var _subject: Node3D
var _reveal: Node3D
var _cam: Camera3D
var _lamp: OmniLight3D
var _set: Node3D
var _glow: StandardMaterial3D
var _white: ColorRect
var _heading: Label
var _detail: Label
var _sound_played := false
var _ring_sound := false
var _motes: Array[MeshInstance3D] = []


func _init() -> void:
	super._init()
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(mode: String, old_look: Dictionary, new_look := {}, shell := {}) -> Control:
	kind = mode
	before = old_look
	after = new_look if not new_look.is_empty() else old_look
	egg = shell
	duration = 2.5 if kind == "level" else (7.0 if kind == "evolve" else 8.6)
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
	_subject = EggModel.build(egg) if kind == "hatch" else _beast(before)
	_stage.add_child(_subject)
	_subject.position.y = 1.07
	_reveal = _beast(after)
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
	_lamp.light_color = Color("#d6f8ff")
	_stage.add_child(_lamp)
	var spark := _material(Color("#d1efff"))
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 24:
		var sphere := SphereMesh.new()
		sphere.radius = 0.018 + float(i % 3) * 0.008
		sphere.height = sphere.radius * 2
		var mote := _mesh(_stage, sphere, Vector3.ZERO, spark)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append(mote)
	# Existing window styling and typography, kept central and clear of side controls.
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", UIKit.box("slot", Vector4(22, 12, 22, 12)))
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 28
	title.offset_bottom = 104
	_heading = UIKit.header("", UIKit.INK)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(_heading)
	_detail = UIKit.label("", 32, UIKit.LIGHT)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_color_override("font_shadow_color", Color.BLACK)
	_detail.add_theme_constant_override("shadow_offset_x", 2)
	_detail.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_detail)
	_detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_detail.offset_top = -192
	_detail.offset_bottom = -132
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)
	_update(0)


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
	_set.build()


func _beast(look: Dictionary) -> Node3D:
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
	_vp.size = get_window().size
	if preview_time >= 0:
		_update(preview_time)
		return
	elapsed += delta
	_update(elapsed)
	if elapsed >= duration:
		close()


func _update(t: float) -> void:
	var hatch := kind == "hatch"
	var level := kind == "level"
	var reveal_at := 5.65 if hatch else (0.45 if level else 3.8)
	var glow_start := 4.1 if hatch else 1.4
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
		Sfx.play("hatch" if hatch else ("levelup" if level else "merge"))
	var heading: String
	if hatch:
		heading = "%s hatched!" % after.name if revealed else EggLooks.name_for(egg)
	elif level:
		heading = "%s · Level %d" % [after.name, after.level]
	else:
		heading = "%s evolved!" % after.name if revealed else "%s is evolving..." % before.name
	_heading.text = heading
	_detail.text = ("HP %d  /  MP %d · Fully restored" % [after.hp, after.mp]) if revealed and not hatch else ("A new friend awakens" if revealed else ("" if level else "The shell stirs..." if t > 4.0 and hatch else ""))
	# Gentle dolly, generous framing at both 16:9 and 20:9; no aspect-dependent art stretching.
	var zoom := smoothstep(0.0, duration, t)
	_cam.position = Vector3(5.0 - zoom * 0.4, 3.9 - zoom * 0.15, 8.0 - zoom * 0.65)
	_cam.look_at(Vector3(0, 2.3, 0))
	if level:
		_reveal.position.y = 1.07 + sin(clampf((t - reveal_at) / 0.65, 0, 1) * PI) * 0.20
		_ring.visible = false
		_lamp.light_energy = 0.4 + sin(t * 4.0) * 0.1
	for i in _motes.size():
		var a := float(i) * 2.4 + t * 0.6
		var rise := fposmod(float(i) * 0.23 + t * (0.85 if level else 0.40), 2.8)
		_motes[i].position = Vector3(cos(a) * 1.1, 1.1 + rise, sin(a) * 1.1)
		_motes[i].visible = level or t > glow_start
