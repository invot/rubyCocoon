extends Node3D
## Tam and Saffi walking behind the hero (scaraba_town.gd on_enter, once met_twins is set): two small people who step
## onto the tiles the hero has just left, a tile apart. They never block and can't be talked to; they're scenery that
## proves the twins came along.
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const STEP := 0.32
const SCALE := 0.72

var world
var kids: Array[Node3D] = []
## the hero's recent tiles, newest first
var trail: Array[Vector2i] = []
var phase := 0.0
## how big each follower is drawn (the twins are small; the beavers are not)
var size := SCALE


func setup(w, looks: Array, at_size := SCALE) -> void:
	world = w
	size = at_size
	# they arrive a step or two behind the hero (on the hero's tile where there's no floor behind)
	trail = [world.player_pos]
	for i in looks.size():
		var behind: Vector2i = world.player_pos - world.facing * (i + 1)
		trail.append(behind if world._walkable(behind) else trail.back())
	for i in looks.size():
		var k: Node3D = VPer.build(looks[i])
		k.scale = Vector3.ONE * size
		add_child(k)
		k.position = world.tile_pos(trail[i + 1])
		VPer.face(k, world.facing)
		kids.append(k)


func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var at: Vector2i = world.player_pos
	if trail.is_empty() or trail[0] != at:
		trail.push_front(at)
		if trail.size() > 6:
			trail.resize(6)
	var moving := false
	for i in kids.size():
		var k := kids[i]
		var target_tile: Vector2i = trail[mini(i + 1, trail.size() - 1)]
		var target: Vector3 = world.tile_pos(target_tile)
		var d := Vector3(target.x - k.position.x, 0, target.z - k.position.z)
		if d.length() > 0.02:
			moving = true
			var stepped := minf(d.length(), delta / STEP * maxf(1.0, d.length()))
			k.position += d.normalized() * stepped
			k.position.y = target.y
			VPer.face(k, Vector2i(roundi(signf(d.x)), 0) if absf(d.x) > absf(d.z) else Vector2i(0, roundi(signf(d.z))), true)
	if moving:
		phase += delta / STEP
		for k in kids:
			VPer.animate(k, phase, 1.0 / STEP)
	elif phase != 0.0:
		phase = 0.0
		for k in kids:
			VPer.animate(k, 0.0, 0.0)
