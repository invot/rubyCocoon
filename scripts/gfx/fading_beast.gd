extends Node3D
## A beast on a film's stage that fades as one piece. The film's AnimationPlayer tracks drive `opacity` and `glow`.

## 1 is solid and 0 is gone.
@export_range(0.0, 1.0) var opacity := 1.0:
	set(value):
		opacity = value
		_apply()
## How far the beast has turned to light: 0 shows its own colours and 1 is plain white.
@export_range(0.0, 1.0) var glow := 0.0:
	set(value):
		glow = value
		_apply()

var _parts: Array[GeometryInstance3D] = []
var _light: StandardMaterial3D


func stand(model: Node3D) -> void:
	add_child(model)
	_light = StandardMaterial3D.new()
	_light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light.emission_enabled = true
	_light.emission = Color.WHITE
	_light.emission_energy_multiplier = 2.0
	_light.disable_fog = true
	for part in model.find_children("*", "GeometryInstance3D", true, false):
		_parts.append(part)
		if part is MeshInstance3D:
			part.material_overlay = _light
	_apply()


func _apply() -> void:
	visible = opacity > 0.001
	for part in _parts:
		part.transparency = 1.0 - opacity
	if _light != null:
		_light.albedo_color = Color(1, 1, 1, glow)
