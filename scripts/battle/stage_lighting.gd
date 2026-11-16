extends RefCounted
## Battle-only warm key / cool fill. The overworld keeps its shared daylight unchanged.
const OutdoorLight = preload("res://scripts/gfx/outdoor_light.gd")
const Ground = preload("res://scripts/battle/stage_ground.gdshader")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
## terrain_mesh.gd TEX_LEVEL: the ground layers' average brightness, divided out of their tints
const TEX_LEVEL := 0.71
static var _floors := {}


## A plain floor grid about a unit per cell: the ground shader works out its patches per vertex, not per pixel.
static func floor_mesh(size: Vector2) -> ArrayMesh:
	if _floors.has(size):
		return _floors[size]
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = int(size.x) - 1
	plane.subdivide_depth = int(size.y) - 1
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	_floors[size] = out
	return out


static func apply(env: Environment, key: DirectionalLight3D, biome: Dictionary, indoor: bool) -> DirectionalLight3D:
	var cool := Color(biome["sky_top"]).lerp(Color("#8b83d8"), 0.5)
	env.ambient_light_color = cool
	env.ambient_light_energy = 0.24 if indoor else float(biome["amb"]) * 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.2
	env.tonemap_exposure = 0.72 if RenderingServer.get_current_rendering_method() != "gl_compatibility" else 0.63
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.18
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_hdr_threshold = 1.5
	env.fog_light_color = cool.lerp(Color(biome["ground"]), 0.2).darkened(0.1)
	env.fog_density = float(biome.get("fog", 0.004)) * 0.65
	key.light_color = Color(biome["sun"]).lerp(Color("#ffd0a0"), 0.35)
	key.light_energy = 0.65 if indoor else OutdoorLight.sun_energy(biome) * 0.633  # (0.68 of the sun before its 0.8 -> 0.86 scale)
	key.light_specular = 0.25
	key.rotation_degrees = Vector3(-32, -48, 0)
	key.shadow_blur = 2.0
	var rim := DirectionalLight3D.new()
	rim.name = "CoolRimLight"
	rim.light_color = cool.lerp(Color("#96b9ed"), 0.3)
	rim.light_energy = 0.28
	rim.light_specular = 0.15
	rim.rotation_degrees = Vector3(-24, 135, 0)
	rim.shadow_enabled = false
	return rim


static func backdrop_tint(biome: Dictionary) -> Color:
	return Color(biome["sun"]).lerp(Color("#9aa6dd"), 0.4)


static func edge_tint(biome: Dictionary) -> Color:
	return Color(biome["sky_top"]).lerp(Color("#b6b0e0"), 0.65)


## The world's painted ground layers in the biome's colours (world.gd's tints): grass with darker patches and worn
## dirt; sand with dirt and rock; an arena's packed earth with stretches of cobble and a little grass; a dark hall's stone; a beach.
static func ground_material(biome: Dictionary, look: String) -> ShaderMaterial:
	var grass_dark := Color(biome["ground"]).darkened(0.3).lerp(Color("#1e5a3a"), 0.2)
	var rock := Color("#8a8478").lerp(Color(biome["side"]).lightened(0.15), 0.55)
	var sand := Color(biome.get("sand", "#ecd8a0"))
	# [base layer, colour], [patch layer, colour, cover], [worn layer, colour, cover], mottle
	var spec: Array = {
		"grass": [["grass", Color(biome["ground"])], ["grass_dark", grass_dark, 0.42], ["path", Color(biome["path"]), 0.2], 1.0],
		"sand": [["sand", sand], ["path", Color(biome["path"]), 0.32], ["rock", rock, 0.14], 0.6],
		"arena": [["sand", Color(biome["path"]).lerp(Color(biome["plaza"]), 0.35)], ["plaza", Color(biome["plaza"]), 0.38], ["grass", Color(biome["ground"]).darkened(0.1), 0.22], 0.8],
		"dark": [["plaza", Color("#4a4652")], ["paving", Color("#3e3a46"), 0.4], ["rock", Color("#55505c"), 0.18], 0.4],
		"beach": [["sand", sand], ["bed", sand.darkened(0.18), 0.3], ["path", Color(biome["path"]), 0.1], 0.5],
	}[look]
	var mat := ShaderMaterial.new()
	mat.shader = Ground
	mat.set_shader_parameter("layers", VT.ground_layers())
	for i in 3:
		var key: String = ["base", "patch", "worn"][i]
		var entry: Array = spec[i]
		mat.set_shader_parameter(key + "_layer", VT.GROUND_LAYERS.find(entry[0]))
		var lin: Color = (entry[1] as Color).srgb_to_linear()
		mat.set_shader_parameter(key + "_tint", Vector3(lin.r, lin.g, lin.b) / TEX_LEVEL)
		if i > 0:
			mat.set_shader_parameter(key + "_cover", entry[2])
	mat.set_shader_parameter("mottle_strength", spec[3])
	mat.set_shader_parameter("edge_tint", edge_tint(biome))
	return mat
