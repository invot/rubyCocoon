extends Node3D
## A duck: Liray 3D's stylized mallard (assets/animals/duck.glb, cut down to 5k triangles with its rig and clips:
## Idle, Walk, Run, Swim, Eat, Quack, Flap, Blink and the Emote_ ones). Ducks are animals, never characters: they
## never speak, they only quack (Sfx "quack"). Jared befriended them; they float on water, waddle on land, and a duck
## the player presses A beside quacks, each quack pitched a little up or down at random (see PITCH_STEPS).
const SCENE := "res://assets/animals/duck.glb"
## how big a duck stands beside people (the hero is about 1.44 tall; the model is 0.36 at 1)
const SIZE := 1.15
## how far a floating duck sits down into the water (its feet and belly under it), at SIZE
const SINK := 0.045
## how far each quack is shifted from the recording, in semitones (one picked at random per quack)
const PITCH_STEPS := [-2, -1, 0, 1, 2]
const LOOPS := ["Idle", "Walk", "Run", "Swim", "Eat"]
## how many quacks there have been, and the last one's shift in semitones (tools/debug/ducks.gd reads them)
static var quacks := 0
static var last_step := 0
var floating := false
## its size (SIZE beside people up close; the world's ducks a little bigger, to read from the gameplay camera)
var size := SIZE
## turning slowly about on the water by itself (the world's ducks; a film moves its own)
var wander := false
## what it does when it isn't quacking (one of LOOPS)
var mood := "Idle"
var _model: Node3D
var _anim: AnimationPlayer
var _clock := 0.0
var _phase := 0.0


func _ready() -> void:
	_model = (load(SCENE) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	for node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anim = _model.find_children("*", "AnimationPlayer", true, false).front() if _model.find_children("*", "AnimationPlayer", true, false).size() > 0 else null
	if _anim != null:
		for clip in LOOPS:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(_on_finished)
	_phase = fmod(absf(position.x * 3.1 + position.z * 1.7), TAU)
	set_floating(floating)


## On the water (bobbing, paddling, sat down into it) or on land.
func set_floating(on: bool) -> void:
	floating = on
	if _model != null:
		_model.position.y = -SINK * size / SIZE if on else 0.0
	act("Swim" if on else ("Idle" if mood == "Swim" else mood))


## Carry on doing `clip` (one of LOOPS): Walk while it waddles somewhere, Eat while it dabbles at food.
func act(clip: String, speed := 1.0) -> void:
	mood = clip
	# (a quack plays out first; _on_finished carries on with the mood)
	if _anim != null and _anim.current_animation == "Quack" and _anim.is_playing():
		return
	if _anim != null and _anim.has_animation(clip) and (_anim.current_animation != clip or not _anim.is_playing()):
		_anim.play(clip, 0.2, speed)


## Turn to face along `way` (on the ground).
func face(way: Vector3) -> void:
	if Vector2(way.x, way.z).length() > 0.001:
		rotation.y = atan2(way.x, way.z)


## A quack, a semitone or two up or down at random, and its bill opening with it.
func quack() -> void:
	last_step = PITCH_STEPS.pick_random()
	quacks += 1
	Sfx.play_tone("quack", pow(2.0, last_step / 12.0))
	if _anim != null and _anim.has_animation("Quack"):
		_anim.play("Quack", 0.1)


func _on_finished(clip: StringName) -> void:
	if clip == &"Quack":
		act(mood)


func _process(delta: float) -> void:
	if not floating or _model == null:
		return
	_clock += delta
	_model.position.y = -SINK * size / SIZE + sin(_clock * 1.7 + _phase) * 0.012
	_model.rotation.z = sin(_clock * 1.3 + _phase) * 0.04
	if wander:
		rotation.y += sin(_clock * 0.21 + _phase) * delta * 0.35


## Still water for ducks to float on (the game's shared water shader, as in a pool indoors).
static func water(tint := Color("#2a7f9a")) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/gfx/water.gdshader")
	mat.set_shader_parameter("frames", preload("res://scripts/gfx/voxel_textures.gd").frames("water"))
	mat.set_shader_parameter("frame_count", float(preload("res://scripts/gfx/voxel_textures.gd").WATER_FRAMES))
	mat.set_shader_parameter("fps", 6.0)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("opacity", 0.86)
	mat.set_shader_parameter("glow", 0.0)
	mat.set_shader_parameter("drift", Vector2(0.03, 0.0))
	return mat
