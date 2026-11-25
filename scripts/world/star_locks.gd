extends RefCounted
## The Scaraba Desert's star locks (docs/scaraba-implementation-plan.md WP3, U16): one puzzle, several faces. Five
## points stand round a centre, numbered one to five clockwise from the top, and every lock is answered the same way:
## the points touched 1, 3, 5, 2, 4 and the top again (desert_layout.gd STAR). A wrong point puts the lock out.
##
## The faces (VARIANTS), each one seeded per join and saved with the desert's layout:
##   ring     five standing stones, a crystal lighting on each
##   pillars  five carved pillars, each turning to face the next point of the star
##   ducks    five stepping pads round a little pond, and a duck that paddles over to each pad touched (it only
##            quacks: it's an ordinary duck, never owned or fought)
##   bells    five sand bells on posts, each ringing its note
## A carved tablet at each lock's foot explains it. Until the rule's been learned (star_taught), reading it shows the
## order point by point, and each right touch says where the next one is.
const Layout = preload("res://scripts/world/desert_layout.gd")
const Shoreline = preload("res://scripts/world/shoreline.gd")
const VARIANTS := ["ring", "pillars", "ducks", "bells"]
const AIR_GLOW := Color("#7fe8d0")
## the points' notes, a rising pentatonic (C D E G A)
const NOTES := [523.25, 587.33, 659.25, 783.99, 880.0]
## the tablet stands this far south of the centre, between points 3 and 4
const TABLET := Vector2i(0, 3)
## how far each lock has been touched (lock id -> touches so far): not saved, kept while in the desert
static var progress := {}


static func half_solved() -> bool:
	return progress.values().any(func(v): return int(v) > 0)


static func clear_progress() -> void:
	progress.clear()


## The tiles a variant changes round its centre (the duck pond's water): {Vector2i offset: char}.
static func tiles(variant: String) -> Dictionary:
	var out := {}
	if variant == "ducks":
		for y in range(-1, 2):
			for x in range(-1, 2):
				out[Vector2i(x, y)] = "~"
	return out


## Every tile a lock stands on (points, tablet, pond), for map checks.
static func footprint(center: Vector2i, variant: String) -> Array:
	var out := [center + TABLET]
	for k in Layout.STAR_POINTS:
		out.append(center + Layout.STAR_POINTS[k])
	for d in tiles(variant):
		out.append(center + d)
	return out


# ---------------------------------------------------------------- the objects
## A section's lock as story objects (Story.extra_npcs, via desert_crossing.gd).
static func objects(lock: Dictionary) -> Array:
	var rid := String(lock["id"])
	var variant := String(lock.get("variant", "ring"))
	var c := Vector2i(int(lock["center"][0]), int(lock["center"][1]))
	var lit := Layout.ring_open(rid, GameState.flags)
	var out := []
	for k in range(1, 6):
		var made := _point_node(variant, k, lit, c)
		out.append({"kind": "story", "id": "star_point", "name": "", "lock": rid, "variant": variant, "point": k,
			"center": c, "pos": c + Layout.STAR_POINTS[k], "scene": made[0], "glow": made[1], "light": made[2],
			"turn": made[3], "facing": Vector2i(0, 1), "still": true})
	out.append({"kind": "story", "id": "star_tablet", "name": "", "lock": rid, "variant": variant, "center": c,
		"pos": c + TABLET, "scene": _tablet_node(), "facing": Vector2i(0, 1), "still": true})
	if variant == "ducks":
		var holder := Node3D.new()
		var duck: Node3D = preload("res://scripts/gfx/duck.gd").new()
		duck.floating = true
		duck.size = 1.6
		duck.name = "Duck"
		duck.position.y = Shoreline.WATER_Y
		holder.add_child(duck)
		out.append({"kind": "story", "id": "star_duck", "name": "", "lock": rid, "pos": c, "scene": holder,
			"facing": Vector2i(0, 1), "still": true})
	return out


## A point's node for its variant: [node, glow material, light, the part that turns (or null)].
static func _point_node(variant: String, k: int, lit: bool, c: Vector2i) -> Array:
	var root := Node3D.new()
	var stone := _mat(Color("#c9a46a"))
	var turn: Node3D = null
	var glow_y := 1.38
	match variant:
		"pillars":
			_box(root, Vector3(0.62, 0.22, 0.62), 0.11, stone)
			turn = Node3D.new()
			root.add_child(turn)
			_box(turn, Vector3(0.38, 1.3, 0.38), 0.87, stone)
			# the carved beak at its top, the way it points
			_box(turn, Vector3(0.16, 0.16, 0.36), 1.36, _mat(Color("#a8834e")), Vector3(0, 0, 0.3))
			glow_y = 1.62
			# (they start facing the centre)
			var to := Vector2(-Layout.STAR_POINTS[k].x, -Layout.STAR_POINTS[k].y)
			turn.rotation.y = atan2(to.x, to.y)
		"ducks":
			# a round stepping pad, low on the bank
			var pad := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.42
			cm.bottom_radius = 0.46
			cm.height = 0.16
			cm.radial_segments = 10
			pad.mesh = cm
			pad.material_override = stone
			pad.position.y = 0.08
			root.add_child(pad)
			glow_y = 0.24
		"bells":
			var wood := _mat(Color("#7a5232"))
			_box(root, Vector3(0.12, 1.5, 0.12), 0.75, wood, Vector3(-0.32, 0, 0))
			_box(root, Vector3(0.12, 1.5, 0.12), 0.75, wood, Vector3(0.32, 0, 0))
			_box(root, Vector3(0.8, 0.1, 0.12), 1.5, wood)
			turn = Node3D.new()
			turn.position.y = 1.45
			root.add_child(turn)
			var bell := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.1
			bm.bottom_radius = 0.24
			bm.height = 0.34
			bm.radial_segments = 10
			bell.mesh = bm
			bell.material_override = _mat(Color("#c08a3a"))
			bell.position.y = -0.2
			turn.add_child(bell)
			glow_y = 1.72
		_:
			_box(root, Vector3(0.6, 0.2, 0.6), 0.1, stone)
			var pillar := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.16
			pm.bottom_radius = 0.24
			pm.height = 1.0
			pm.radial_segments = 5
			pillar.mesh = pm
			pillar.material_override = stone
			pillar.position.y = 0.7
			root.add_child(pillar)
	var gem := StandardMaterial3D.new()
	gem.albedo_color = AIR_GLOW
	gem.emission_enabled = true
	gem.emission = AIR_GLOW
	gem.emission_energy_multiplier = 1.6 if lit else 0.2
	var crystal := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.34
	sm.radial_segments = 5
	sm.rings = 2
	crystal.mesh = sm
	crystal.material_override = gem
	crystal.position.y = glow_y
	root.add_child(crystal)
	var label := Label3D.new()
	label.text = str(k)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 12
	label.modulate = Color("#fff8e8")
	label.position.y = glow_y + 0.45
	root.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = AIR_GLOW
	light.omni_range = 2.2
	light.light_energy = 0.7 if lit else 0.0
	light.position.y = glow_y
	root.add_child(light)
	return [root, gem, light, turn]


static func _tablet_node() -> Node3D:
	var root := Node3D.new()
	var stone := _mat(Color("#b8925a"))
	_box(root, Vector3(0.7, 0.16, 0.36), 0.08, stone)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.62, 0.14)
	slab.mesh = bm
	slab.material_override = stone
	slab.position = Vector3(0, 0.42, 0)
	slab.rotation.x = -0.35
	root.add_child(slab)
	# the star cut into it
	var star := MeshInstance3D.new()
	star.mesh = star_mesh(0.22, 0.02)
	var carve := _mat(Color("#6a4a2a"))
	carve.cull_mode = BaseMaterial3D.CULL_DISABLED
	star.material_override = carve
	star.position = Vector3(0, 0.46, 0.08)
	star.rotation.x = PI / 2.0 - 0.35
	root.add_child(star)
	return root


## A flat five-pointed star (lying in the XZ plane, its top point north), `r` across to its tips.
static func star_mesh(r: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(Vector3(cos(a) * rr, thick, sin(a) * rr))
	for i in 10:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, thick, 0))
		st.add_vertex(pts[(i + 1) % 10])
		st.add_vertex(pts[i])
	return st.commit()


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _box(parent: Node3D, size: Vector3, y: float, mat: Material, offset := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = offset + Vector3(0, y, 0)
	parent.add_child(mi)


# ---------------------------------------------------------------- touching
static func _points(world, rid: String) -> Dictionary:
	var out := {}
	for p in world.npcs:
		var m: Dictionary = world.npcs[p]
		if m.get("id", "") == "star_point" and m.get("lock", "") == rid:
			out[int(m["point"])] = m
	return out


## Touching a point: the next in the star answers; a wrong one puts the lock out. The sixth touch (the top again)
## opens it.
static func touch(world, n: Dictionary) -> void:
	var rid := String(n["lock"])
	var k := int(n["point"])
	if Layout.ring_open(rid, GameState.flags):
		_sound(n, k)
		await Story.say(["It answers softly. The way on is open."])
		return
	var at := int(progress.get(rid, 0))
	if Layout.STAR[at] != k:
		progress[rid] = 0
		Sfx.play("fail")
		await _reset(world, rid)
		await Story.say([_wrong_line(String(n["variant"]), at)] + ([] if GameState.flag("star_taught")
			else ["There's a carved tablet at the foot of it. It might say where to start."]))
		return
	at += 1
	progress[rid] = at
	await _answer(world, n, at)
	if at < Layout.STAR.size():
		if not GameState.flag("star_taught"):
			UI.toast("Next: point %d. Skip one, going round clockwise." % Layout.STAR[at] if at < 5 else "Last: back to the top, point 1.")
		return
	progress.erase(rid)
	GameState.set_flag("star_ring_" + rid)
	var first := not GameState.flag("star_taught")
	GameState.set_flag("star_taught")
	Sfx.secret_chime()
	await UI.flash(AIR_GLOW, 1)
	await Story.say([_solved_line(String(n["variant"]))]
		+ (["Top first and last, the star between. The desert seems to answer to that."] if first else []))


static func _wrong_line(variant: String, at: int) -> String:
	match variant:
		"pillars":
			return "With a grinding of stone, the pillars all turn back to face the middle."
		"ducks":
			return "The duck flaps back to the middle of the pond, quacking crossly. The pads go dark."
		"bells":
			return "The bell clanks flat, and the others' hum dies away."
	return "The stone's hum dies away, and the others go dark with it." if at > 0 else "The stone stays dark. Perhaps it starts somewhere else."


static func _solved_line(variant: String) -> String:
	match variant:
		"pillars":
			return "The five pillars lock into place, each pointing along the star, and the loose sand round them settles into firm ground."
		"ducks":
			return "The duck finishes its lap and quacks. A sluice somewhere gurgles open, and the sand round the pond firms underfoot."
		"bells":
			return "The five bells ring out together in one long chord, and the drifting sand stills into a firm path."
	return "All five stones ring out together, and the loose sand round the ring settles into firm ground."


## Answers point `n` as the `at`th touch: its sound, its light, and what its face does.
static func _answer(world, n: Dictionary, at: int) -> void:
	var k := int(n["point"])
	_sound(n, k)
	_light(n, true)
	var node: Node3D = n.get("node", null)
	match String(n["variant"]):
		"pillars":
			var turn: Node3D = n.get("turn", null)
			if turn != null and at < Layout.STAR.size():
				var to: Vector2i = Layout.STAR_POINTS[Layout.STAR[at]] - Layout.STAR_POINTS[k]
				await _turn_to(turn, atan2(float(to.x), float(to.y)))
		"bells":
			var bell: Node3D = n.get("turn", null)
			if bell != null:
				var tw := bell.create_tween()
				tw.tween_property(bell, "rotation:z", 0.4, 0.12)
				tw.tween_property(bell, "rotation:z", -0.3, 0.2)
				tw.tween_property(bell, "rotation:z", 0.0, 0.25)
				await tw.finished
		"ducks":
			var duck := _duck(world, String(n["lock"]))
			if duck != null:
				var c: Vector2i = n["center"]
				var off := Vector2(Layout.STAR_POINTS[k]).normalized() * 0.95
				duck.face(Vector3(off.x, 0, off.y) - duck.position * Vector3(1, 0, 1))
				var tw := duck.create_tween()
				tw.tween_property(duck, "position", Vector3(off.x, duck.position.y, off.y), 0.5)
				await tw.finished
				duck.quack()
		_:
			if node != null:
				await node.get_tree().create_timer(0.15).timeout


static func _turn_to(turn: Node3D, yaw: float) -> void:
	var tw := turn.create_tween()
	tw.tween_property(turn, "rotation:y", turn.rotation.y + wrapf(yaw - turn.rotation.y, -PI, PI), 0.45)
	await tw.finished


static func _duck(world, rid: String) -> Node3D:
	for p in world.npcs:
		var m: Dictionary = world.npcs[p]
		if m.get("id", "") == "star_duck" and m.get("lock", "") == rid and m.get("node", null) != null:
			return (m["node"] as Node3D).get_node_or_null("Duck")
	return null


static func _sound(n: Dictionary, k: int) -> void:
	var f: float = NOTES[k - 1]
	if String(n.get("variant", "")) == "bells":
		Sfx.tone(f * 2.0, 0.7, "sine", -10.0)
	else:
		Sfx.flute_note(f)


static func _light(n: Dictionary, on: bool) -> void:
	if n.get("glow", null) == null:
		return
	(n["glow"] as StandardMaterial3D).emission_energy_multiplier = 1.6 if on else 0.2
	(n["light"] as OmniLight3D).light_energy = 0.7 if on else 0.0


## The lock goes out: lights off, pillars back to the middle, the duck home.
static func _reset(world, rid: String) -> void:
	for n in _points(world, rid).values():
		_light(n, false)
		var turn: Node3D = n.get("turn", null)
		if String(n["variant"]) == "pillars" and turn != null:
			var to: Vector2i = -Layout.STAR_POINTS[int(n["point"])]
			_turn_to(turn, atan2(float(to.x), float(to.y)))
	var duck := _duck(world, rid)
	if duck != null:
		duck.quack()
		var tw := duck.create_tween()
		tw.tween_property(duck, "position", Vector3(0, duck.position.y, 0), 0.5)
		await tw.finished


## The tablet: what the lock is, and, until the rule's been learned, the order shown point by point.
static func read_tablet(world, n: Dictionary) -> void:
	var rid := String(n["lock"])
	var face: String = {"ring": "five stones", "pillars": "five pillars", "ducks": "five pads round the pond", "bells": "five bells"}.get(String(n["variant"]), "five points")
	if Layout.ring_open(rid, GameState.flags):
		await Story.say(["The carving is worn smooth where hands have traced it: the star, top first and last."])
		return
	if GameState.flag("star_taught"):
		await Story.say(["The same star as before, cut for %s. Top first and last, the star between." % face])
		return
	await Story.say(["A star is cut into the stone, its points numbered one to five, going round clockwise from the top.",
		"Under it: \"Begin at the top. Skip one, and skip one again, until you are home.\"",
		"Lines join the %s in that order. Watch..." % face])
	var points := _points(world, rid)
	for k in Layout.STAR:
		if points.has(k):
			_sound(points[k], k)
			_light(points[k], true)
		await world.get_tree().create_timer(0.6).timeout
	for p in points.values():
		_light(p, false)
	await Story.say(["One, three, five, two, four, and one again. Try touching them in that order."])
