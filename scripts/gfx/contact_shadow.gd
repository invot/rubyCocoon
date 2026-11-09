class_name ContactShadow
extends MeshInstance3D
## A soft patch of shade on the ground under someone standing outdoors. It keeps people and beasts planted even in the
## shade of a building, where the sun's own shadow can't show them, and on phones, where that shadow is coarser.
## Everyone shares one quad and one material.

const SHADER := preload("res://scripts/gfx/contact_shadow.gdshader")
## Just clear of the ground, so it neither flickers against it nor floats.
const LIFT := 0.03

static var _mesh: PlaneMesh
static var _material: ShaderMaterial

var radius := 0.4


func _init(r := 0.4) -> void:
	radius = r
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2.ONE
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	mesh = _mesh
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Lies along the ground's slope (world.gd: an identity basis for flat ground, or a ramp's).
func lay(ground: Basis) -> void:
	global_basis = ground * Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0))
