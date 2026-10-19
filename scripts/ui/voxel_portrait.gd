extends SubViewportContainer
## A small live 3D view of one voxel beast, slowly turning. Used on summary cards and when eggs hatch.

const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const VPer = preload("res://scripts/gfx/voxel_person.gd")

var _pivot: Node3D
var spin_speed := 0.7


## A voxel person (the trainer) instead of a beast.
func setup_person(look: Dictionary, px := 200) -> SubViewportContainer:
	return setup({}, px, look)


func setup(genes: Dictionary, px := 280, person := {}) -> SubViewportContainer:
	custom_minimum_size = Vector2(px, px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(px, px)
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	var bb: AABB
	if not person.is_empty():
		var rig := VPer.build(person)
		VPer.face(rig, Vector2i(0, 1))
		_pivot.add_child(rig)
		var h := VPer.height()
		bb = AABB(Vector3(-0.4, 0, -0.3), Vector3(0.8, h, 0.6))
		spin_speed = 0.35
	elif genes.has("model"):
		var inst := VA.instance(String(genes["model"]), 1.6)
		_pivot.add_child(inst)
		bb = AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 1.6, 1.6))
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = VB.mesh(genes)
		bb = mi.mesh.get_aabb()
		mi.position = Vector3(-bb.get_center().x, 0, -bb.get_center().z)
		_pivot.add_child(mi)
	_pivot.rotation.y = -0.7
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var extent := maxf(bb.end.y, maxf(bb.size.x, bb.size.z))
	cam.size = extent * 1.25
	var look := Vector3(0, bb.end.y * 0.5, 0)
	var pos := look + Vector3(0, 2.2, 6.0)
	cam.transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	vp.add_child(cam)
	cam.current = true
	return self


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += delta * spin_speed
