extends RefCounted
## A skinned beaver on the shared trainer rig keeps the same facing and dialogue/battle anchors.
const MODEL := preload("res://assets/animals/beaver.glb")

static func dress(rig: Node3D) -> void:
	for mesh in rig.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	var model := MODEL.instantiate() as Node3D
	rig.get_node("Body").add_child(model)
	# The source stands about 15 units high and faces +X. Trainers face +Z.
	model.scale = Vector3.ONE * 0.105
	model.rotation.y = -PI / 2.0
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in [&"Idle_Walk", &"Walk"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(&"Idle_Walk")
	rig.set_meta("critter_visual", model)
	# how far ahead its toe tips reach (its skinned feet, measured), where it pivots leaning forward when beaten (voxel_person.gd)
	rig.set_meta("critter_toes", 0.66)
	rig.set_meta("beaver_animation", player)

static func animate(player: AnimationPlayer, speed: float) -> void:
	var clip := &"Walk" if speed > 0.05 else &"Idle_Walk"
	if player.current_animation != clip:
		player.play(clip, 0.15)
