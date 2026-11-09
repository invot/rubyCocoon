extends RefCounted
## The open air's light, shared by the overworld, roofs open to the sky and battles: a gentler sun from the side, so
## everything shows a lit and a shaded face and its shadow falls beside it. (The camera looks north, so a sun at its
## back lights the scene flat and hides each shadow behind whatever casts it.)
## The grade costs nothing extra: tone mapping, glow and the colour adjustment all run in the renderer's one final
## pass, on the Mobile and Compatibility renderers too.

## On each biome's own "sun_e" and "amb" (world_db.gd), which also decide which places count as gloomy.
const SUN_SCALE := 0.8
const AMBIENT_SCALE := 0.78
## Sky light mixed with some warmth, so shade stays cosy instead of falling to a dark teal.
const AMBIENT_WARM := Color("#fff0dc")
const AMBIENT_LIFT := 0.32
## Low enough for long shadows, from the south-east so that fronts facing the camera still catch the sun.
const SUN_ANGLE := Vector3(-42.0, 52.0, 0.0)


## The sky's light on the ground, tinted by what it bounces off.
static func ambient_color(biome: Dictionary, bounce := 0.35) -> Color:
	return Color(biome["sky_top"]).lerp(Color(biome["ground"]), bounce).lerp(AMBIENT_WARM, AMBIENT_LIFT)


static func ambient_energy(biome: Dictionary) -> float:
	return float(biome["amb"]) * AMBIENT_SCALE


static func sun_energy(biome: Dictionary) -> float:
	return float(biome["sun_e"]) * SUN_SCALE


## Filmic tone mapping that leaves room for colour, a glow only real highlights reach (the sunlit ground used to pass
## the old threshold, so the whole screen bloomed) and contrast and saturation to make up for the dimmer light.
static func grade(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.6
	env.tonemap_exposure = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 1.2
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# (the web's renderer comes out brighter and punchier from the same light)
		env.tonemap_exposure = 0.68
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 1.04


## Aims and softens a sun whose colour and strength the caller has set.
static func aim(sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = SUN_ANGLE
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
