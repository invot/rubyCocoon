extends RefCounted
## A room's own fog (its "fog", 1-10, set in DunGen's Room tab): one haze over the whole room, never a tile at a time.
## Each step is thicker, and 10 hides the room's far wall. The fog takes the room's wall colour, paled, so a warm room
## hazes warm and a dark one grey. Rooms without it keep the clear air their light gives them.

## how much of the fog one step of the room's "fog" lays on
const STEP := 0.0055


## Lays `room`'s fog into `env` (world.gd _build_room, and the dungeon exporter's preview) and returns its amount, 0
## when the room has none.
static func apply(env: Environment, room: Dictionary) -> int:
	var amount := clampi(int(room.get("fog", 0)), 0, 10)
	if amount <= 0:
		return 0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = colour(room)
	env.fog_density = STEP * amount
	env.fog_sky_affect = 0.0
	return amount


## The colour the room's fog takes: its wall colour, paled towards white.
static func colour(room: Dictionary) -> Color:
	return Color(str(room.get("wall", "#e8d8c0"))).lightened(0.35)
