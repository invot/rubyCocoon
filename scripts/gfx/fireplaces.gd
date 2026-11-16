extends RefCounted
## The approved fieldstone/limestone hearths: fixed two-square width, half-square depth.
## Named surfaces let room authors recolour stone and furniture wood independently.
const DIR := "res://assets/interiors/fireplaces/"
const STONE := {"fieldstone": "#b9b1a0", "limestone": "#d7c9a6"}
static var _materials := {}


static func make(style: String, stone: Color, wood: Color) -> MeshInstance3D:
	if not STONE.has(style):
		style = "fieldstone"
	var mi := MeshInstance3D.new()
	mi.name = "Fireplace_" + style
	var mesh: ArrayMesh = load(DIR + style + ".res")
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var kind: String = mesh.surface_get_name(i)
		if kind not in ["stone", "wood"]:
			continue
		var colour := stone if kind == "stone" else wood
		var key := "%s:%s" % [kind, colour.to_html()]
		if not _materials.has(key):
			var mat := mi.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			mat.albedo_color = colour
			_materials[key] = mat
		mi.set_surface_override_material(i, _materials[key])
	return mi
