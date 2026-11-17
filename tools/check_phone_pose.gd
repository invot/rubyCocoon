extends SceneTree
## Verifies receiver pickup/hold/hangup on both sides and at different character sizes.
const Person = preload("res://scripts/gfx/voxel_person.gd")
var bad := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for size in [0.75, 1.0, 1.25]:
		for side in ["l", "r"]:
			var rig := Person.build({"model": "tf0", "scale": size})
			root.add_child(rig)
			Person.face(rig, Vector2i(1, 0))
			var receiver := Person.begin_phone(rig, side, Vector3(1, 0.8, 0))
			for frame in 40:
				Person.animate(rig, 0, 0, frame / 60.0)
			var sk: Skeleton3D = rig.get_meta("skeleton")
			var hand := sk.get_bone_global_pose(sk.find_bone(side + "_hand")).origin
			var head := sk.get_bone_global_pose(sk.find_bone("head")).origin
			var grip := sk.to_local(receiver.global_position)
			_check(hand.distance_to(grip) < 0.02, "%s hand holds receiver (%f)" % [side, hand.distance_to(grip)])
			_check(absf(grip.x - head.x) > 0.2 and grip.distance_to(head) < 0.35, "receiver beside ear")
			_check(receiver.has_meta("speech_origin"), "caller speech comes from receiver")
			Person.end_phone(rig)
			for frame in range(40, 70):
				Person.animate(rig, 0, 0, frame / 60.0)
			_check(not rig.has_meta("phone_prop") and not receiver.visible, "hangup releases hand and hides receiver")
			rig.queue_free()
			await process_frame
	print("PHONE POSE DONE: %d problem(s)" % bad)
	quit(1 if bad else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", message)
