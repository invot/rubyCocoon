extends RefCounted
signal shot_changed(name: String)
## Named, bounded shots. Requests never delay battle logic.
## A single pending request coalesces rapid effects, so no two shot changes occur within half a second.
const MIN_SHOT_TIME := 0.5
const DURATIONS := {"opening": 1.1, "home": -1.0, "choose": -1.0, "attacker": 0.7,
	"follow": 0.6, "reaction": 0.65, "return": 0.4, "summon": -1.0,
	"capture": 1.2, "knockout": 0.8, "victory": -1.0, "cast": -1.0, "impact": 1.3}
## A cast's shots are cuts, in and out: on the caster as it gathers and lets go its glow (held until the cut to where
## it lands, or "return" for a cast on itself), then on where it lands.
const CUTS := ["cast", "impact"]
const STAGE_CENTER := Vector3(0, 0, 1.5)
const OUTDOOR_CAMERA_RADIUS := 27.0
var battle: Node3D
var shot := "home"
var elapsed := MIN_SHOT_TIME
var clock := 0.0
var source = null
var target = null
var pending := ""
var pending_source = null
var pending_target = null
var changes := 0
var shortest_gap := INF
var _last_change := -INF
var _look := Vector3.ZERO
var _position := Vector3.ZERO
var _goal_look := Vector3.ZERO
var _goal_position := Vector3.ZERO
var _goal_fov := 24.0
## the next frame jumps straight to the shot (a cut) rather than moving to it
var _cut := false


func _init(owner: Node3D) -> void:
	battle = owner
	_position = battle.cam.position
	_look = battle._cam_look()


func play(name: String, actor = null, subject = null) -> void:
	assert(DURATIONS.has(name))
	if shot == name and typeof(source) == typeof(actor) and source == actor and typeof(target) == typeof(subject) and target == subject:
		return
	if elapsed < MIN_SHOT_TIME:
		pending = name
		pending_source = actor
		pending_target = subject
		return
	_accept(name, actor, subject)


func _accept(name: String, actor, subject) -> void:
	_cut = name in CUTS or shot in CUTS
	shortest_gap = minf(shortest_gap, clock - _last_change)
	_last_change = clock
	changes += 1
	shot = name
	source = actor
	target = subject
	elapsed = 0.0
	pending = ""
	pending_source = null
	pending_target = null
	shot_changed.emit(shot)


func step(delta: float) -> void:
	clock += delta
	elapsed += delta
	if elapsed >= MIN_SHOT_TIME:
		if pending != "":
			_accept(pending, pending_source, pending_target)
		elif float(DURATIONS[shot]) >= 0.0 and elapsed >= float(DURATIONS[shot]):
			var next := "choose" if not battle._selected_refs.is_empty() else "home"
			if shot in ["attacker", "follow", "reaction", "capture", "knockout"]:
				next = "return"
			_accept(next, null, null)
		elif shot in ["home", "choose"]:
			var choosing: bool = not battle._selected_refs.is_empty()
			if choosing != (shot == "choose"):
				_accept("choose" if choosing else "home", null, null)
	_pose()
	# Keep the camera inside the sealed room/surround, even for the largest summon and its shake.
	var desired_distance := _goal_position.distance_to(_goal_look)
	_goal_position = constrain(_goal_position)
	var actual_distance := _goal_position.distance_to(_goal_look)
	if actual_distance < desired_distance:
		_goal_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_goal_fov * 0.5)) * desired_distance / maxf(actual_distance, 1.0)))
	if _cut:
		_cut = false
		_position = _goal_position
		_look = _goal_look
		battle.cam.fov = clampf(_goal_fov, 24.0, 65.0)
	var speed := 5.0 if shot in ["home", "choose", "victory"] else 9.0
	var blend := 1.0 - exp(-delta * speed)
	_position = constrain(_position.lerp(_goal_position, blend))
	_look = _look.lerp(_goal_look, blend)
	battle.cam.fov = lerpf(battle.cam.fov, clampf(_goal_fov, 24.0, 65.0), blend)
	var shake: float = battle.summon_shake_amt
	var offset := Vector3.ZERO
	if shake > 0.0:
		offset = Vector3(sin(clock * 63.0), sin(clock * 79.0), sin(clock * 57.0)) * shake * 0.35
		battle.summon_shake_amt = maxf(0.0, shake - delta * 1.6)
	battle.cam.position = constrain(_position + offset)
	battle.cam.look_at(_look, Vector3.UP)


func constrain(at: Vector3) -> Vector3:
	if battle.indoor and not battle.cfg.get("arena", false):
		return Vector3(clampf(at.x, -21.5, 21.5), clampf(at.y, 2.6, 10.0), clampf(at.z, -19.5, 22.5))
	var radial := Vector2(at.x - STAGE_CENTER.x, at.z - STAGE_CENTER.z).limit_length(OUTDOOR_CAMERA_RADIUS)
	return Vector3(radial.x + STAGE_CENTER.x, clampf(at.y, 2.6, 20.0), radial.y + STAGE_CENTER.z)


func _point(ref) -> Vector3:
	var at = battle._ref_pos(ref)
	if at == null:
		return battle._cam_look()
	return at + Vector3.UP * battle._ref_height(ref) * 0.6


func _pose() -> void:
	var base: Vector3 = battle._cam_pos()
	var center: Vector3 = battle._cam_look()
	_goal_position = base
	_goal_look = center
	_goal_fov = battle.CAM_FOV
	match shot:
		"opening":
			var sweep := (1.0 - smoothstep(0.0, 1.1, elapsed)) * 0.22
			_goal_position = center + (base - center).rotated(Vector3.UP, sweep)
		"home", "choose":
			_goal_position += Vector3(sin(clock * 0.21) * 0.25, sin(clock * 0.17) * 0.06, 0)
			if shot == "choose" and not battle._selected_refs.is_empty():
				# Frame the chooser, including while aiming at somebody else.
				var shift := (_point(battle._selected_refs[0]) - center) * 0.55
				_goal_position += shift * 0.6
				_goal_look += shift
		"attacker", "reaction", "capture", "knockout":
			var focus := _point(source)
			var shift := (focus - center) * 0.7
			_goal_position += shift * 0.65
			_goal_look += shift
			_goal_fov = 28.0
		"follow":
			var focus := _point(source).lerp(_point(target), smoothstep(0.0, 0.35, elapsed))
			var shift := (focus - center) * 0.7
			_goal_position += shift * 0.65
			_goal_look += shift
			_goal_fov = 30.0
		"cast", "impact":
			# close on one beast (or a side's) from in front of it, three-quarters on from the camera's side of the
			# stage: the caster gathering its glow and letting it go, then where it lands as it arrives
			var refs: Array = source if source is Array else [source]
			var focus := Vector3.ZERO
			var tall := 0.6
			for ref in refs:
				focus += _point(ref)
				tall = maxf(tall, battle._ref_height(ref))
			focus /= float(refs.size())
			var spread := 0.0
			for ref in refs:
				spread = maxf(spread, (_point(ref) - focus).length())
			var facing: Vector3 = battle._toward(battle._team(refs[0])) if typeof(refs[0]) == TYPE_OBJECT else -battle._toward("ally")
			var turn := deg_to_rad(50.0 if shot == "cast" else 35.0)
			var view: Vector3 = facing * cos(turn) - battle._right() * sin(turn)
			var dist := clampf(tall * 2.4 + 3.4, 4.5, 9.0) + spread * 1.8
			_goal_look = focus
			_goal_position = focus + view * dist + Vector3.UP * dist * 0.3
			_goal_fov = 30.0
		"summon":
			_goal_position = battle.summon_pos
			_goal_look = battle.summon_look
			_goal_fov = 32.0
		"victory":
			_goal_look = battle.ALLY_CENTER + Vector3.UP * 0.8
			_goal_position = _goal_look + (base - center).rotated(Vector3.UP, sin(elapsed * 0.18) * 0.22)
			_goal_fov = 34.0
