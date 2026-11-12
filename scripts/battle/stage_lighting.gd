extends RefCounted
## Battle-only warm key / cool fill. The overworld keeps its shared daylight unchanged.
const OutdoorLight = preload("res://scripts/gfx/outdoor_light.gd")
const Ground = preload("res://scripts/battle/stage_ground.gdshader")
static var _grass_floor: ArrayMesh


## Broad painted patches are baked into vertices once, instead of running noise
## over every floor pixel each frame. Alpha blends a few soft areas of bare earth.
static func grass_floor() -> ArrayMesh:
	if _grass_floor != null:
		return _grass_floor
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	plane.subdivide_width = 39
	plane.subdivide_depth = 39
	var arrays := plane.get_mesh_arrays()
	var colours := PackedColorArray()
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var broad := sin(p.x*0.31+sin(p.z*0.22))*sin(p.z*0.28-p.x*0.13)
		var light := 1.0 + broad*0.16
		var dirt := 0.0
		for patch in [Vector3(-6, 3.8, 1), Vector3(7, 4.5, -3), Vector3(-2, 3.4, 11)]:
			var d := Vector2(p.x-patch.x, (p.z-patch.z)*1.3).length()
			dirt = maxf(dirt, 1.0-smoothstep(patch.y*0.3, patch.y, d))
		colours.append(Color(light*1.02, light, light*0.91, dirt*0.7))
	arrays[Mesh.ARRAY_COLOR] = colours
	_grass_floor = ArrayMesh.new()
	_grass_floor.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _grass_floor


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


static func ground_material(texture: Texture2D, tiling: Vector2, biome: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Ground
	mat.set_shader_parameter("ground_texture", texture)
	mat.set_shader_parameter("tiling", tiling)
	mat.set_shader_parameter("edge_tint", edge_tint(biome))
	return mat
