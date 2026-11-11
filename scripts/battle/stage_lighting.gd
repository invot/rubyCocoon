extends RefCounted
## Battle-only warm key / cool fill. The overworld keeps its shared daylight unchanged.
const OutdoorLight = preload("res://scripts/gfx/outdoor_light.gd")


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
	key.light_color = Color(biome["sun"]).lerp(Color("#ffd0a0"), 0.35)
	key.light_energy = 0.65 if indoor else OutdoorLight.sun_energy(biome) * 0.68
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
