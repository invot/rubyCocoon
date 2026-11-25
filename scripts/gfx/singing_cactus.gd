extends Node3D
## The Singing Cactus (docs/visual_overhaul/exploration.md set pieces; the Scaraba Desert, desert_sights.gd): a tall old
## cactus that sings only to someone standing beside it with their back to it, and goes quiet the moment they turn
## round. Its tune is the same each time. (Learning it as a battle song waits on the song's effect being decided.)
const VA = preload("res://scripts/gfx/voxel_assets.gd")
## its tune: notes (Hz) and how long each is held
const TUNE := [[392.0, 0.45], [440.0, 0.3], [523.25, 0.6], [440.0, 0.3], [392.0, 0.45], [329.63, 0.9]]
## seconds the hero must stand still with their back to it before it starts
const SHY := 1.2
var tile := Vector2i.ZERO
var _waited := 0.0
var _singing := false
var _sung_for := false
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(VA.instance("cactus_3", 2.3))


func _process(delta: float) -> void:
	var main = GameState.main
	if main == null or not is_instance_valid(main.world) or main.world.player == null:
		return
	var w = main.world
	var away: Vector2i = w.player_pos - tile
	var beside := absi(away.x) + absi(away.y) == 1
	if not beside:
		_sung_for = false
		_waited = 0.0
		return
	if _singing or _sung_for or w.moving or w.busy or UI.busy():
		return
	# its back to it: facing straight away from the cactus
	if w.facing != away:
		_waited = 0.0
		return
	_waited += delta
	if _waited >= SHY:
		_sing(w)


func _sing(w) -> void:
	_singing = true
	_sung_for = true
	var first := not GameState.flag("cactus_heard")
	GameState.set_flag("cactus_heard")
	if first:
		UI.toast("Behind you, the cactus has started to sing!")
	for note in TUNE:
		if not is_instance_valid(w) or w.facing != w.player_pos - tile:
			break
		Sfx.flute_note(float(note[0]))
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector3(1.04, 0.97, 1.04), float(note[1]) * 0.4)
		tw.tween_property(_body, "scale", Vector3.ONE, float(note[1]) * 0.6)
		await get_tree().create_timer(float(note[1])).timeout
	_body.scale = Vector3.ONE
	_singing = false
