extends MeshInstance3D
## A see-through landmark (see_through.gdshader; Dustwell's old church, frontier_builder.gd _church): keeps its
## materials told where the hero stands, so the part of it between the camera and them dissolves, and thins the whole
## of it away while it stands anywhere between the camera and the hero (CUTAWAY), as it does on the street behind it.
## The world it stands in is the nearest ancestor with a hero ("player") and a camera ("cam").

## how far it thins away (the rest of it stays as a faint dither, so you still see where it stands), and how fast
const CUTAWAY := 0.85
const CUTAWAY_RATE := 3.0

## its own material and those of what hangs on it (the emblems, the seal behind its walls)
var see_materials: Array = []
var _world: Node
var _last := Vector3.INF
var _cut := 0.0


func _process(delta: float) -> void:
	if see_materials.is_empty():
		return
	if _world == null:
		var at := get_parent()
		while at != null and not ("player" in at and "terrain_mats" in at):
			at = at.get_parent()
		if at == null:
			return
		_world = at
	var hero = _world.get("player")
	if not hero is Node3D or not is_instance_valid(hero):
		return
	var p: Vector3 = (hero as Node3D).global_position
	if p != _last:
		_last = p
		for m: ShaderMaterial in see_materials:
			m.set_shader_parameter("hole", Vector4(p.x, p.y, p.z, 1.0))
	var cut := 0.0
	var cam = _world.get("cam")
	if mesh != null and cam is Camera3D and is_instance_valid(cam):
		var box: AABB = global_transform * mesh.get_aabb()
		if box.intersects_segment(p + Vector3(0, 0.9, 0), (cam as Camera3D).global_position):
			cut = CUTAWAY
	if cut != _cut:
		_cut = move_toward(_cut, cut, delta * CUTAWAY_RATE)
		for m: ShaderMaterial in see_materials:
			m.set_shader_parameter("cutaway", _cut)
