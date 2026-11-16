extends RefCounted
## The one shared material for exterior window glass: an opaque pane reflecting the sky, shimmering as the camera
## moves (window_glass.gdshader). Builders put their glass in its own surface with this material: cartoon_windows.gd
## ("window_glass" surfaces and Windows.paint), the building kit's "glass" surface (voxel_buildings.gd Kit).

const SHADER := preload("res://scripts/gfx/window_glass.gdshader")
const CLOUDS := "res://assets/textures/surfaces/glass_sky.png"
const SHIMMER := preload("res://assets/textures/surfaces/glass_shimmer.png")
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.resource_name = "window_glass"
		_material.shader = SHADER
		_material.set_shader_parameter("glass_shimmer", SHIMMER)
		if ResourceLoader.exists(CLOUDS):
			_material.set_shader_parameter("clouds", load(CLOUDS))
	return _material
