extends RefCounted
## Valkoog, the air temple (docs/scaraba-implementation-plan.md WP6; the outline's §4). The pyramid's inner ways are
## air-keyed: every trap is stilled, never dodged, by answering the desert's star on each floor (points 1, 3, 5, 2, 4
## and the top again), and it takes an air mage to touch a vent at all — before the keepers give the hero a stone, that
## means Tam and Saffi. Each floor's face is its own: five vents, five fans, five gust plates, five spear slots.
##
## Floors (interior_maps.gd, WorldDB.TEMPLES "air"): valkoog_1 .. valkoog_4 climb to the keepers' chamber, and its
## wind-cut seam opens on the summit (temple_air). A floor's points stand on anchors air_1 .. air_5, its trap on
## air_trap (a blocking gust the star tears apart), and the twins on twin_tam / twin_saffi.
##   - Solved: flag valkoog_star_<room>; the trap is taken away and the stair on is clear.
##   - A tell for the next floor: valkoog_tell_<room>, which lights its first point as the dust settles.
##   - Every wrong point gutters out (and the gust shoves you back a step), as the desert's rings do.
const Layout = preload("res://scripts/world/desert_layout.gd")
const StarLocks = preload("res://scripts/world/star_locks.gd")
const ScarabaTown = preload("res://scripts/story/scaraba_town.gd")
const TrapScript = preload("res://scripts/gfx/air_trap.gd")

const AIR_GLOW := Color("#7fe8d0")
const DUST := Color("#d8c49a")
## Floors in the order they climb (WorldDB.TEMPLES "air" ["rooms"], without the summit).
const FLOORS := ["valkoog_1", "valkoog_2", "valkoog_3", "valkoog_4"]
const KEEPERS_ROOM := "valkoog_keepers"
const ROOMS := ["valkoog_1", "valkoog_2", "valkoog_3", "valkoog_4", "valkoog_keepers", "temple_air"]
## What each floor's five points are.
const FACES := {"valkoog_1": "vents", "valkoog_2": "fans", "valkoog_3": "plates", "valkoog_4": "spears"}
## The five keepers at the star's points (A13): bald, hooded, and one speaks.
const KEEPERS := [
	{"name": "Khepri", "shirt": "#3f8f7a", "skin": "#b98a5c"},
	{"name": "Amunet", "shirt": "#4a7a9a", "skin": "#8a5a38"},
	{"name": "Sethi", "shirt": "#8a6a3a", "skin": "#c89a6a"},
	{"name": "Nebet", "shirt": "#6a5a8a", "skin": "#a06a44"},
	{"name": "Ptahmes", "shirt": "#5a7a5a", "skin": "#d0a878"},
]
## How far a floor's star has been answered (floor -> points so far): not saved, like the desert's rings.
static var progress := {}


static func keeper_look(i: int) -> Dictionary:
	var k: Dictionary = KEEPERS[clampi(i, 0, KEEPERS.size() - 1)]
	# a mage's look: the long robe under a thick lined hood, and bald under it (townfolk.gd ROBES)
	return {"robe": "hooded", "element": "air", "shirt": String(k["shirt"]), "skin": String(k["skin"])}


static func in_temple(room_key: String) -> bool:
	return ROOMS.has(room_key)


static func solved(room_key: String) -> bool:
	return GameState.flag("valkoog_star_" + room_key)


## Whether the hero's side can answer a vent here: the twins' stones, or the hero's own once the keepers have taught
## them.
static func air_key_along() -> bool:
	if GameState.has_stone("air") and GameState.learned_spell("gust"):
		return true
	return GameState.flag("met_twins") and not GameState.flag("twins_home")


static func floor_after(room_key: String) -> String:
	var at := FLOORS.find(room_key)
	if at < 0:
		return ""
	if at == FLOORS.size() - 1:
		return KEEPERS_ROOM
	return FLOORS[at + 1]


# ---------------------------------------------------------------- the objects
## A temple room's story objects (Story.extra_npcs): the floor's five points and its trap, the keepers round their
## star, and the twins.
static func objects(map: Dictionary) -> Array:
	var key := String(map.get("room_key", ""))
	if not ROOMS.has(key):
		return []
	# (a floor's star starts over when it's walked into again: like the desert's rings, its half-turned points aren't kept)
	if FLOORS.has(key):
		progress.clear()
	var out := []
	var anchors: Dictionary = map.get("anchors", {})
	var face := String(FACES.get(key, "vents"))
	var open := solved(key)
	for k in range(1, 6):
		var an := "air_%d" % k
		if not anchors.has(an):
			continue
		# the floor's tell: the first point already turning when its room is walked into
		var lit: bool = open or (k == 1 and GameState.flag("valkoog_tell_" + key))
		var made := _point_node(face, k, lit)
		out.append({"kind": "story", "id": "air_point", "name": "", "floor": key, "face": face, "point": k,
			"pos": anchors[an], "scene": made[0], "glow": made[1], "light": made[2], "facing": Vector2i.DOWN, "still": true})
	if anchors.has("air_trap") and not open:
		out.append({"kind": "story", "id": "air_trap", "name": "", "floor": key, "face": face,
			"pos": anchors["air_trap"], "scene": _trap_node(face), "facing": Vector2i.DOWN, "still": true, "blocking": true})
	if key == KEEPERS_ROOM:
		for i in KEEPERS.size():
			var an := "keeper_%d" % i
			if anchors.has(an):
				out.append({"kind": "story", "id": "air_keeper", "name": String(KEEPERS[i]["name"]), "keeper": i,
					"pos": anchors[an], "look": keeper_look(i), "facing": Vector2i(0, 1), "still": true, "story": true})
	var twins := GameState.flag("met_twins") and not GameState.flag("twins_home")
	if twins and anchors.has("twin_tam") and anchors.has("twin_saffi"):
		out.append({"kind": "story", "id": "twin_guest", "twin": "tam", "name": "Tam", "pos": anchors["twin_tam"],
			"look": ScarabaTown.TAM_LOOK, "facing": Vector2i(0, 1), "still": true})
		out.append({"kind": "story", "id": "twin_guest", "twin": "saffi", "name": "Saffi", "pos": anchors["twin_saffi"],
			"look": ScarabaTown.SAFFI_LOOK, "facing": Vector2i(0, 1), "still": true})
	return out


## What a room's object does when spoken to (Story.talk).
static func talk(world, n: Dictionary) -> void:
	match String(n["id"]):
		"air_point":
			await _touch(world, n)
		"air_trap":
			await _trap_talk(world, n)
		"twin_guest":
			var who := "Tam" if String(n.get("twin", "tam")) == "tam" else "Saffi"
			await Story.say([_twin_line(n)], who)


static func _twin_line(n: Dictionary) -> String:
	var key := String(n.get("floor", ""))
	if not solved(key):
		return ["Watch the vents. We'll blow when you say.", "Point one first. Then skip one, going round.", "We've done this before. In the sand."].pick_random()
	return ["See? Easy. For us.", "That's the way up. Come on.", "The wind likes you. I can tell."].pick_random()


# ---------------------------------------------------------------- the star
## Touching one of a floor's five points: the twins (or the hero's stone) gust it. The desert's star answers, and the
## sixth touch stills the floor's trap.
static func _touch(world, n: Dictionary) -> void:
	var key := String(n["floor"])
	var k := int(n["point"])
	var face := String(n.get("face", FACES.get(key, "vents")))
	if solved(key):
		Sfx.flute_note(StarLocks.NOTES[k - 1] * 0.5)
		await Story.say([_still_line(face)])
		return
	if not air_key_along():
		await Story.say(["The vent is cold and dry. Whatever answers it, it isn't you.", "It wants a breath of wind."])
		return
	var at := int(progress.get(key, 0))
	if Layout.STAR[at] != k:
		progress[key] = 0
		Sfx.play("fail")
		_darken(world, key)
		await Story.say([_wrong_line(face, at)])
		return
	at += 1
	progress[key] = at
	Sfx.flute_note(StarLocks.NOTES[k - 1])
	_light(n, true)
	if at < Layout.STAR.size():
		return
	progress.erase(key)
	await _solve(world, key, face)


## The star answered: the trap tears apart, the room says what the next one is, and its first point is left turning.
static func _solve(world, key: String, face: String) -> void:
	GameState.set_flag("valkoog_star_" + key)
	Sfx.secret_chime()
	await UI.flash(AIR_GLOW, 1)
	for p in world.npcs:
		var m: Dictionary = world.npcs[p]
		if m.get("id", "") == "air_point" and m.get("floor", "") == key:
			_light(m, true)
	await _unmake_trap(world, key)
	await Story.say([_solved_line(face)])
	var next := floor_after(key)
	if next == "":
		return
	GameState.set_flag("valkoog_tell_" + next)
	await Story.say([_tell_line(next)])


static func _unmake_trap(world, key: String) -> void:
	var trap := {}
	for p in world.npcs:
		var m: Dictionary = world.npcs[p]
		if m.get("id", "") == "air_trap" and m.get("floor", "") == key:
			trap = m
			break
	if trap.is_empty():
		return
	Sfx.play("wind")
	world.remove_npc(trap)
	await world.get_tree().create_timer(0.4).timeout


static func _trap_talk(world, n: Dictionary) -> void:
	var key := String(n["floor"])
	var face := String(n.get("face", FACES.get(key, "vents")))
	await Story.say([_trap_line(face)])
	if solved(key):
		return
	# (disarmed, not dodged: the gust won't let you through, and there's nothing to roll away from)
	Sfx.play("wind")
	await world.get_tree().create_timer(0.35).timeout
	await Story.say(["The gust shoves you back a step. There has to be a way to still it."])


static func _light(n: Dictionary, on: bool) -> void:
	if n.get("glow", null) == null:
		return
	(n["glow"] as StandardMaterial3D).emission_energy_multiplier = 1.6 if on else 0.2
	(n["light"] as OmniLight3D).light_energy = 0.7 if on else 0.0


static func _darken(world, key: String) -> void:
	for p in world.npcs:
		var m: Dictionary = world.npcs[p]
		if m.get("id", "") == "air_point" and m.get("floor", "") == key:
			_light(m, false)


static func _still_line(face: String) -> String:
	match face:
		"fans":
			return "The fans hang still. Their five hubs are cold."
		"plates":
			return "The plates are quiet underfoot, their rims dark."
		"spears":
			return "The five slots are empty. Nothing left to swallow."
	return "The vents breathe a soft, even thread of air. The way up is open."


static func _wrong_line(face: String, at: int) -> String:
	if at == 0:
		return "The gust dies against the stone. Nothing answers."
	match face:
		"fans":
			return "The fan coughs, slows and stops. The others go still with it."
		"plates":
			return "The plate thuds flat and the dust drops out of the air. Every plate goes dark."
		"spears":
			return "The slot spits its gust out sideways, and the other four fall silent."
	return "The vent's hum dies away, and the other four go dark with it."


static func _solved_line(face: String) -> String:
	match face:
		"fans":
			return "The five fans ring out and slow to a stop. The wind in the shaft sighs, and the way up is clear."
		"plates":
			return "The five plates answer like gongs. Somewhere under the floor a sluice opens, and the hissing sand pours away."
		"spears":
			return "The five slots swallow their gusts. The blades over the door drop, and the seam in the far wall stands open."
	return "The five vents answer together. The wind gate at the top of the stair tears apart into dust."


static func _tell_line(next: String) -> String:
	match String(FACES.get(next, "")):
		"fans":
			return "The dust from the gate drifts up the stair and settles in the shape of a fan. Five of them, waiting. The first is already turning."
		"plates":
			return "The dust slips up the stair and settles into five round plates. One of them is warm underfoot, as if it remembers the way."
		"spears":
			return "The dust runs up the stair and gathers round five slots in the wall. One slot is already bright."
		"vents":
			return "The dust goes up the stair and hangs there, in the shape of this room's vents. One is already lit."
	return "At the top of the stair, a seam in the wall takes the last of the dust and holds it, bright as a blade."


static func _trap_line(face: String) -> String:
	match face:
		"fans":
			return "Five bronze fans turn in the shaft, and their wind stands in the doorway like a wall."
		"plates":
			return "The floor plates hiss, throwing up a curtain of stinging sand across the way on."
		"spears":
			return "Long blades swing across the door in slow arcs, and the wind they cut won't let you by."
	return "A wind gate roars across the top of the stair, packing the dust into a wall you can lean on."


# ---------------------------------------------------------------- the pieces
## A floor's point: a vent stone, a fan, a gust plate or a spear slot, numbered over it. Returns [node, gem, light].
static func _point_node(face: String, k: int, lit: bool) -> Array:
	var root := Node3D.new()
	var stone := _mat(DUST)
	var bronze := _mat(Color("#a88a4a"))
	var glow_y := 1.2
	match face:
		"fans":
			_box(root, Vector3(0.66, 0.16, 0.66), 0.08, stone)
			_box(root, Vector3(0.14, 1.0, 0.14), 0.58, bronze)
			var hub := Node3D.new()
			hub.position.y = 1.08
			root.add_child(hub)
			for i in 4:
				var blade := _box(hub, Vector3(0.12, 0.44, 0.04), 0.0, bronze, Vector3(0, 0, 0))
				blade.position = Vector3(cos(i * PI / 2.0) * 0.22, sin(i * PI / 2.0) * 0.22, 0.02)
				blade.rotation.z = i * PI / 2.0
			glow_y = 1.36
		"plates":
			var plate := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.46
			cm.bottom_radius = 0.5
			cm.height = 0.12
			cm.radial_segments = 12
			plate.mesh = cm
			plate.material_override = bronze
			plate.position.y = 0.06
			root.add_child(plate)
			glow_y = 0.16
		"spears":
			_box(root, Vector3(0.7, 0.18, 0.5), 0.09, stone)
			_box(root, Vector3(0.5, 0.9, 0.12), 0.55, stone, Vector3(0, 0, -0.06))
			# the empty slot, and the blade that would stand in it
			_box(root, Vector3(0.1, 0.5, 0.06), 0.66, _mat(Color("#4a4038")), Vector3(0, 0, 0.09))
			_box(root, Vector3(0.05, 0.62, 0.16), 0.7, bronze, Vector3(0, 0, 0.09))
			glow_y = 1.3
		_:
			var ring := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.4
			rm.bottom_radius = 0.46
			rm.height = 0.36
			rm.radial_segments = 8
			ring.mesh = rm
			ring.material_override = stone
			ring.position.y = 0.18
			root.add_child(ring)
			glow_y = 0.5
	var gem := StandardMaterial3D.new()
	gem.albedo_color = AIR_GLOW
	gem.emission_enabled = true
	gem.emission = AIR_GLOW
	gem.emission_energy_multiplier = 1.7 if lit else 0.2
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
	label.position.y = glow_y + 0.42
	root.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = AIR_GLOW
	light.omni_range = 2.2
	light.light_energy = 0.7 if lit else 0.0
	light.position.y = glow_y
	root.add_child(light)
	return [root, gem, light]


## The trap itself: a turning fan, a spinning dust column, a wind gate's funnel, or swinging blades.
static func _trap_node(face: String) -> Node3D:
	var root: Node3D = TrapScript.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	root.set("part", spin)
	var dust := _mat(DUST)
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.albedo_color = Color(0.85, 0.78, 0.6, 0.38)
	dust.cull_mode = BaseMaterial3D.CULL_DISABLED
	match face:
		"fans":
			_box(root, Vector3(0.14, 1.6, 0.14), 0.8, _mat(Color("#8a7a4a")))
			for i in 4:
				var blade := _box(spin, Vector3(0.16, 0.7, 0.05), 0.0, _mat(Color("#b8964a")))
				blade.position = Vector3(cos(i * PI / 2.0) * 0.34, sin(i * PI / 2.0) * 0.34, 0.0)
				blade.rotation.z = i * PI / 2.0 + 0.4
			spin.position.y = 1.2
			root.set("spin", 3.4)
		"plates":
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.8
			cm.bottom_radius = 0.08
			cm.height = 1.7
			cm.radial_segments = 10
			cone.mesh = cm
			cone.material_override = dust
			cone.position.y = 0.85
			spin.add_child(cone)
			root.set("spin", 2.0)
		"spears":
			_box(root, Vector3(0.12, 2.0, 0.12), 1.0, _mat(Color("#8a7a4a")), Vector3(-0.7, 0, 0))
			_box(root, Vector3(0.12, 2.0, 0.12), 1.0, _mat(Color("#8a7a4a")), Vector3(0.7, 0, 0))
			_box(root, Vector3(1.5, 0.1, 0.12), 1.85, _mat(Color("#8a7a4a")))
			for i in 2:
				var blade := _box(spin, Vector3(0.08, 1.5, 0.16), 0.0, _mat(Color("#b8964a")))
				blade.position.x = -0.45 + i * 0.9
				blade.position.y = 1.0
			spin.position.y = 0.0
			root.set("spin", 1.6)
			root.set("swing", 0.5)
		_:
			_box(root, Vector3(0.2, 1.7, 0.2), 0.85, dust, Vector3(-0.55, 0, 0))
			_box(root, Vector3(0.2, 1.7, 0.2), 0.85, dust, Vector3(0.55, 0, 0))
			var funnel := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.62
			fm.bottom_radius = 0.2
			fm.height = 1.6
			fm.radial_segments = 10
			funnel.mesh = fm
			funnel.material_override = dust
			funnel.position.y = 0.8
			spin.add_child(funnel)
			root.set("spin", 2.6)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _box(parent: Node3D, size: Vector3, y: float, mat: Material, offset := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = offset + Vector3(0, y, 0)
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- battles
## Every battle in Valkoog's inner ways is fought with the twins and the Air Shield (the outline's §4 rules), and a
## loss resets the room instead of costing gold and a walk back.
static func decorate_battle(cfg: Dictionary) -> void:
	cfg["air_shield"] = true
	cfg["retry_room"] = true
	if cfg.has("guests"):
		return
	if not (GameState.flag("met_twins") and not GameState.flag("twins_home")):
		return
	cfg["guests"] = guests()


## Tam and Saffi as guest combatants (battle_guest.gd): they keep pace with the party by a few levels.
static func guests() -> Array:
	var lv := 8
	for b in GameState.party:
		lv = maxi(lv, int(b.level) - 4)
	var hp := 34 + maxi(0, lv - 8) * 3
	return [{"name": "Tam", "look": ScarabaTown.TAM_LOOK, "level": lv, "hp": hp},
		{"name": "Saffi", "look": ScarabaTown.SAFFI_LOOK, "level": lv, "hp": hp}]
