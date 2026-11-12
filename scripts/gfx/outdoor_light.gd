extends RefCounted
## The open air's light, shared by the overworld, roofs open to the sky and battles: a gentler sun from the side, so
## everything shows a lit and a shaded face and its shadow falls beside it. (The camera looks north, so a sun at its
## back lights the scene flat and hides each shadow behind whatever casts it.)
## The grade costs nothing extra: tone mapping, glow and the colour adjustment all run in the renderer's one final
## pass, on the Mobile and Compatibility renderers too.

## On each biome's own "sun_e" and "amb" (world_db.gd), which also decide which places count as gloomy.
const SUN_SCALE := 0.86
const AMBIENT_SCALE := 0.72
## Sky light mixed with some warmth, so shade stays cosy instead of falling to a dark teal.
const AMBIENT_WARM := Color("#fff0dc")
const AMBIENT_LIFT := 0.32
## Low enough for long shadows, from the south-east so that fronts facing the camera still catch the sun.
const SUN_ANGLE := Vector3(-42.0, 52.0, 0.0)
## How much of the shade's light comes from the sky itself (cool from above, the ground's warm bounce from below)
## rather than one flat colour, so faces in shade still read by which way they face.
const SKY_SHARE := 0.3


## The sky's light on the ground, tinted by what it bounces off.
static func ambient_color(biome: Dictionary, bounce := 0.35) -> Color:
	return Color(biome["sky_top"]).lerp(Color(biome["ground"]), bounce).lerp(AMBIENT_WARM, AMBIENT_LIFT)


static func ambient_energy(biome: Dictionary) -> float:
	return float(biome["amb"]) * tune("ambient", AMBIENT_SCALE)


static func sun_energy(biome: Dictionary) -> float:
	return float(biome["sun_e"]) * tune("sun", SUN_SCALE)


static var _tuning := {}


## For comparing looks without editing: --light_<name>=<value> on the command line (a test run's) replaces a value
## here (sun, ambient, sky, exposure, contrast, saturation, white, glow).
static func tune(name: String, value: float) -> float:
	if _tuning.is_empty():
		_tuning["-"] = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--light_") and "=" in a:
				_tuning[a.substr(8).get_slice("=", 0)] = float(a.get_slice("=", 1))
	return float(_tuning.get(name, value))


## Filmic tone mapping that leaves room for colour, a glow only real highlights reach (the sunlit ground used to pass
## the old threshold, so the whole screen bloomed) and contrast and saturation to make up for the dimmer light.
## (Exposure was lowered with the sky-lit shade so scenes keep their old brightness, and colour richer: 2026-11-12.)
static func grade(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = tune("white", 2.6)
	env.tonemap_exposure = tune("exposure", 0.72)
	env.glow_enabled = true
	env.glow_intensity = tune("glow", 0.35)
	env.glow_hdr_threshold = 1.3
	env.adjustment_enabled = true
	env.adjustment_contrast = tune("contrast", 1.2)
	env.adjustment_saturation = tune("saturation", 1.28)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# (the web's renderer comes out brighter and punchier from the same light)
		env.tonemap_exposure = tune("exposure", 0.72) * 0.907
		env.adjustment_contrast = 1.0 + (tune("contrast", 1.2) - 1.0) * 0.25
		env.adjustment_saturation = 1.0 + (tune("saturation", 1.28) - 1.0) * 0.15


## Aims and softens a sun whose colour and strength the caller has set.
static func aim(sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = SUN_ANGLE
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6


## The open air's sky, lighting the shade as well as filling the background: the biome's sky above, its ground's
## warm bounce below. ambient(): the shade lit from it, mixed with the warm flat light (SKY_SHARE).
static func sky(biome: Dictionary) -> Sky:
	var sm := ProceduralSkyMaterial.new()
	# (the sky's blue only tints its light: full blue from above greyed the sunlit grass and paving)
	sm.sky_top_color = Color(biome["sky_top"]).lerp(AMBIENT_WARM, 0.55)
	sm.sky_horizon_color = Color(biome["sky_hz"]).lerp(AMBIENT_WARM, 0.3)
	sm.ground_bottom_color = Color(biome["ground"]).lerp(AMBIENT_WARM, 0.25).darkened(0.35)
	sm.ground_horizon_color = Color(biome["sky_hz"]).lerp(Color(biome["ground"]), 0.3)
	sm.sun_angle_max = 20.0
	var s := Sky.new()
	s.sky_material = sm
	# (a small radiance map: the shade only needs the broad light of the sky, and it is built once)
	s.radiance_size = Sky.RADIANCE_SIZE_64
	s.process_mode = Sky.PROCESS_MODE_QUALITY
	return s


static func ambient(env: Environment, biome: Dictionary, bounce := 0.35) -> void:
	if env.sky == null:
		env.sky = sky(biome)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = tune("sky", SKY_SHARE)
	env.ambient_light_color = ambient_color(biome, bounce)
	env.ambient_light_energy = ambient_energy(biome)

