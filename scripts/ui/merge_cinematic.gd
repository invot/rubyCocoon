extends Node2D
## The merge altar's film, in a dark, misty roundel-walled chamber with three platforms: the parents on two in the background,
## each in a pool of light from the hanging TCM Core above it, and an empty one in front. They rise into their own light and
## fade, and only then does a column of light come down from the centre's core, landing on its platform and washing the
## screen white to reveal their child. The camera holds still until then, and circles the child very slowly.
## Timed rather than confirm-driven, like beast_cinematic.gd: a held button cannot skip the reveal or select the next
## screen. UI.push only needs prev_focus, on_input and close, so this Node2D sits on the UI stack like any modal.

signal done(result)

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const BeastFilm = preload("res://scripts/ui/beast_cinematic.gd")
const HatcheryStage = preload("res://scripts/gfx/hatchery_stage.gd")

## The light climbs unseen, timing the parents: they go as it passes this height, and it only shows once it starts down.
const BEAST_LEVEL := 5.0
## The underside of the centre's core, which the column of light hangs from.
const CLAW_Y := 9.0
## The centre platform's deck, where the light lands.
const CENTER_Y := -2.0
## The stage is built for the hatch's close-up. At this size the wide orthographic view stays inside it, even at 20:9.
const STAGE_SCALE := 1.6
## World units of height in view at a zoom of 1.
const FRAME_HEIGHT := 7.0
## The background platforms and cores are smaller, since an orthographic view can't shrink them with distance.
const BACK_SIZE := 0.75
const BACK_CORE_SIZE := 0.7
const BACK_CORE_ABOVE := 6.8
const CENTER_CORE_Y := 11.9
const PARENT_LAMP_DIM := 7.0
const PARENT_LAMP_LIT := 7.0
## Even at rest each parent stands in a faint shaft of light, this bright.
const PARENT_SHAFT := 0.2
const CENTER_LAMP_DIM := 1.0
const CENTER_LAMP_LIT := 11.0
const CENTER_KEY_DIM := 1.0
const CENTER_KEY_LIT := 4.0
const LIGHT_ENERGY := 9.0
const LIGHT_ON_TIME := 0.35
const LIGHT_OFF_TIME := 0.45

@export var zoom := 0.5
## The room's ambient light, from 0 to 1. EffectsPlayer dims it further while the column of light is in the air.
@export_range(0.0, 1.0) var room_light := 1.0:
	set(value):
		room_light = value
		if _hatchery != null:
			_hatchery.set_house_lights(value)
## How strongly the hanging cores shine down on the parents, from 0 to 1. EffectsPlayer drives it.
@export_range(0.0, 1.0) var parent_light := 0.0:
	set(value):
		parent_light = value
		if is_node_ready():
			_light_stage()
## Moves the light from the parents' platforms to the child's, from 0 to 1. EffectsPlayer drives it.
@export_range(0.0, 1.0) var child_light := 0.0:
	set(value):
		child_light = value
		if is_node_ready():
			_light_stage()

var elapsed := 0.0
## The film ends here, with the child revealed since 6.5 seconds.
var duration := 10.0
var prev_focus = null
var result = null
var closed := false
var first := {}
var second := {}
var merged := {}
var _fell_at := -1.0
var _landed_at := -1.0
var _vanished := false
var _window := Vector2i.ZERO
var _screen := Vector2.ZERO
var _hatchery: Node3D
var _heading: Label

@onready var _view: SubViewport = $Viewport3D
@onready var _picture: Sprite2D = $Picture
@onready var _fill: Sprite2D = $ScreenFill
@onready var _overlay: Control = $Overlay
@onready var _title: PanelContainer = $Overlay/Title
@onready var _stage: Node3D = $Viewport3D/Stage
@onready var _camera: Camera3D = $Viewport3D/Stage/CameraRig/Camera
@onready var _cylinder: Node3D = $Viewport3D/Stage/LightCylinder
@onready var _shaft: Node3D = $Viewport3D/Stage/LightCylinder/Shaft
@onready var _lamp: OmniLight3D = $Viewport3D/Stage/LightCylinder/Light
@onready var _sparks: CPUParticles3D = $Viewport3D/Stage/LightCylinder/Sparks
@onready var _head: MeshInstance3D = $Viewport3D/Stage/LightCylinder/Head
@onready var _glow: MeshInstance3D = $Viewport3D/Stage/LightCylinder/Shaft/Glow
@onready var _core: MeshInstance3D = $Viewport3D/Stage/LightCylinder/Shaft/Core
@onready var _beast1: Node3D = $Viewport3D/Stage/Beast1
@onready var _beast2: Node3D = $Viewport3D/Stage/Beast2
@onready var _merged_beast: Node3D = $Viewport3D/Stage/MergedBeast
@onready var _parent_beam: MeshInstance3D = $Viewport3D/Stage/Beam1
@onready var _deck_glow: MeshInstance3D = $Viewport3D/Stage/DeckGlow1
@onready var _beam_player: AnimationPlayer = $BeamPlayer
@onready var _effects: AnimationPlayer = $EffectsPlayer


func setup(parent_a: Dictionary, parent_b: Dictionary, child: Dictionary) -> Node2D:
	first = parent_a
	second = parent_b
	merged = child
	return self


func _ready() -> void:
	_picture.texture = _view.get_texture()
	_camera.size = FRAME_HEIGHT / zoom
	_hatchery = HatcheryStage.new()
	_stage.add_child(_hatchery)
	_hatchery.build()
	_hatchery.use_roundels()
	_hatchery.enlarge(STAGE_SCALE)
	_hatchery.position.y = CENTER_Y - HatcheryStage.DECK_Y * STAGE_SCALE
	for slot: Node3D in [_beast1, _beast2]:
		var spot := _hatchery.to_local(slot.position)
		_hatchery.add_back_platform(Vector2(spot.x, spot.z), BACK_SIZE)
		_hatchery.add_hanging_core(_hatchery.to_local(slot.position + Vector3.UP * BACK_CORE_ABOVE), BACK_CORE_SIZE)
	_hatchery.add_hanging_core(_hatchery.to_local(Vector3.UP * CENTER_CORE_Y), 1.0)
	_beast1.stand(_model(first))
	_beast2.stand(_model(second))
	_merged_beast.stand(_model(merged))
	_title.add_theme_stylebox_override("panel", UIKit.box("slot", Vector4(22, 12, 22, 12)))
	_heading = UIKit.header("%s and %s are merging" % [first.name, second.name], UIKit.INK)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_child(_heading)
	_fit_to_screen()
	_update_light()
	_light_stage()
	_beam_player.animation_finished.connect(_on_beam_finished)
	_beam_player.play("rise")
	_effects.play("light_up")
	$SwellSound.play()


func _model(look: Dictionary) -> Node3D:
	var model := BeastFilm.stage_beast(look)
	model.scale = Vector3.ONE * STAGE_SCALE
	return model


func _process(delta: float) -> void:
	_fit_to_screen()
	elapsed += delta
	_update_light()
	_hatchery.animate(elapsed, false, false)
	if not _vanished and _cylinder.position.y >= BEAST_LEVEL:
		_vanished = true
		_effects.play("vanish")
		$VanishSound.play()
	if elapsed >= duration:
		close()


## The cylinder's node is the leading end of the light. Its shaft reaches from there back up to the core.
func _update_light() -> void:
	var power := smoothstep(0.0, LIGHT_ON_TIME, elapsed - _fell_at) if _fell_at >= 0.0 else 0.0
	if _landed_at >= 0.0:
		power = 1.0 - smoothstep(0.0, LIGHT_OFF_TIME, elapsed - _landed_at)
	_cylinder.visible = power > 0.0
	var length := maxf(0.05, CLAW_Y - _cylinder.position.y)
	_shaft.position.y = length * 0.5
	_shaft.scale.y = length
	_lamp.light_energy = power * LIGHT_ENERGY
	_glow.material_override.set_shader_parameter("power", power)
	_core.material_override.set_shader_parameter("power", power)
	_head.material_override.albedo_color.a = power * 0.7
	_sparks.emitting = _fell_at >= 0.0 and _landed_at < 0.0


## The pools of light: on the parents until they have gone, then on their child.
func _light_stage() -> void:
	var left := 1.0 - child_light
	_parent_beam.material_override.set_shader_parameter("power", lerpf(PARENT_SHAFT, 1.0, parent_light) * left)
	_deck_glow.material_override.albedo_color.a = parent_light * 0.8
	for lamp: SpotLight3D in [$Viewport3D/Stage/Lamp1, $Viewport3D/Stage/Lamp2]:
		lamp.light_energy = (PARENT_LAMP_DIM + parent_light * PARENT_LAMP_LIT) * lerpf(0.12, 1.0, left)
	$Viewport3D/Stage/CenterLamp.light_energy = lerpf(CENTER_LAMP_DIM, CENTER_LAMP_LIT, child_light)
	$Viewport3D/Stage/CenterBeam.material_override.set_shader_parameter("power", child_light)
	if _hatchery != null:
		_hatchery.get_node("OculusKey").light_energy = lerpf(CENTER_KEY_DIM, CENTER_KEY_LIT, child_light)


func _on_beam_finished(animation: StringName) -> void:
	if animation == &"rise":
		_fell_at = elapsed
		_beam_player.play("fall")
	elif animation == &"fall":
		_land()


func _land() -> void:
	_landed_at = elapsed
	_heading.text = "%s is born!" % merged.name
	# Lets the panel shrink to the shorter line; its minimum size re-centres it.
	_title.offset_left = 0
	_title.offset_right = 0
	_effects.play("reveal")
	$CameraPlayer.play("orbit")
	$RevealSound.play()


## Only the 3D picture uses the selected resolution; the overlay stays in full-resolution UI units.
func _fit_to_screen() -> void:
	var window := get_window().size
	var screen := get_viewport_rect().size
	var rendered := Prefs.render_size(window)
	if window == _window and screen == _screen and _view.size == rendered:
		return
	_window = window
	_screen = screen
	_view.size = rendered
	_picture.texture_filter = Prefs.render_filter(window)
	_picture.scale = screen / Vector2(rendered)
	_fill.scale = screen / _fill.texture.get_size()
	_overlay.size = screen


## Called by the UI manager with input that GUI controls didn't consume. Nothing here responds to it.
func on_input(_ev: InputEvent) -> void:
	pass


func close(r = null) -> void:
	if closed:
		return
	closed = true
	result = r
	UI.pop(self)
	done.emit(r)
