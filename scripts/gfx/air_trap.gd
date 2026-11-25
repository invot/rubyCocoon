extends Node3D
## The moving part of one of Valkoog's traps (world/air_temple.gd): a fan's blades turning, a dust column
## spinning, a wind gate's funnel, or a pair of blades swinging across the door. Nothing here changes the rules; the
## trap's blocking tile does that, and the floor's star takes it away.
var part: Node3D = null
## Turns a second (negative the other way).
var spin := 2.0
## Swings this far each way instead of turning (radians).
var swing := 0.0

var _clock := 0.0


func _process(delta: float) -> void:
	if part == null:
		return
	_clock += delta * spin
	if swing > 0.0:
		part.rotation.z = sin(_clock) * swing
	else:
		part.rotation.y = _clock
