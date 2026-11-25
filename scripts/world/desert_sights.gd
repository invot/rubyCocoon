extends RefCounted
## The Scaraba Desert's set pieces (docs/scaraba-implementation-plan.md WP3), from each section's "sights" list in
## desert_sections.gd: [{"kind", "at": [x, y], ...}]. Built as story objects (desert_crossing.gd ring_npcs).
##   spring        the cold spring in its stone bowl: a drink heals the party (oasis_cold_spring)
##   hot_spring    a steaming pool: a soak heals the party (oasis_hot_spring)
##   reeds         the reed pool's marker: a quiet line, the oasis found (oasis_reed_pool)
##   cactus        the Singing Cactus: it sings only to someone standing beside it facing away (singing_cactus.gd)
##   shrine        the half-buried shrine's carving: the arch-wizard and the desert's test
##   statue        one of the Three Sleeping Statues ("beast": its likeness); they don't wake yet
##   band          the Rubywave Five's waystation ("member" 0-3), while they're on the road to Cogsworth
##   campfire      the waystation's fire
##   star_mark     a star cut on one of Valkoog's landings ("size" 1-6)
##   conduit       the gear-iron pipe the wind bared once the air guardian was calmed (dunes_b's conduit variant)
const Layout = preload("res://scripts/world/desert_layout.gd")
const StarLocks = preload("res://scripts/world/star_locks.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const BAND := ["Riff", "Tempo", "Cadence", "Encore"]
const BAND_MODELS := [13, 29, 62, 74]
const BAND_SHIRTS := ["#b93646", "#3a6ab8", "#3a8a4a", "#7a4aa8"]
const STATUES := {"owl": "an owl", "snake": "a coiled serpent", "cat": "a long-eared cat"}


static func objects(map: Dictionary) -> Array:
	var out := []
	for s in map.get("desert_sights", []):
		var kind := String(s["kind"])
		var p := Vector2i(int(s["at"][0]), int(s["at"][1]))
		var o := {"kind": "story", "id": "desert_sight", "sight": kind, "name": "", "pos": p, "facing": Vector2i(0, 1), "still": true}
		match kind:
			"band":
				# on the road from Dustwell to Cogsworth: here until the hero has crossed the desert
				if not GameState.flag("band_freed") or GameState.flag("desert_crossed"):
					continue
				var i := int(s["member"])
				o.merge({"name": BAND[i], "member": i, "look": {"model": "tf%d" % BAND_MODELS[i], "shirt": BAND_SHIRTS[i]},
					"facing": Vector2i(int(s.get("face", [0, 1])[0]), int(s.get("face", [0, 1])[1]))}, true)
				o.erase("still")
				o["still"] = true
			"campfire":
				if not GameState.flag("band_freed") or GameState.flag("desert_crossed"):
					continue
				o["scene"] = _campfire()
			"cactus":
				var c: Node3D = preload("res://scripts/gfx/singing_cactus.gd").new()
				c.tile = p
				o["scene"] = c
			"spring", "hot_spring":
				o["scene"] = _spring(kind == "hot_spring")
			"reeds":
				o["scene"] = _reed_post()
			"shrine":
				o["scene"] = _shrine()
			"statue":
				o.merge({"beast": String(s["beast"]), "scene": _statue(String(s["beast"]))}, true)
			"star_mark":
				o.merge({"size": int(s["size"]), "scene": _star_mark(int(s["size"]))}, true)
			"conduit":
				o["scene"] = _conduit()
			_:
				continue
		out.append(o)
	return out


static func talk(world, n: Dictionary) -> void:
	match String(n.get("sight", "")):
		"spring":
			GameState.set_flag("oasis_cold_spring")
			GameState.heal_party()
			Sfx.play("heal")
			await Story.say(["Water wells up into the stone bowl, cold as winter even in this heat.",
				"Your beasts drink deep and shake themselves off, good as new."])
		"hot_spring":
			GameState.set_flag("oasis_hot_spring")
			GameState.heal_party()
			Sfx.play("heal")
			await Story.say(["A hot spring, bubbling up out of the sand! Your beasts wade in and soak until every ache is gone."])
		"reeds":
			GameState.set_flag("oasis_reed_pool")
			await Story.say(["Reeds rattle round a pool of clear water. Dragonflies skim it. It's the quietest place for miles."])
		"cactus":
			await Story.say(["A tall old cactus. It seems to be holding its breath while you look at it."
				if not GameState.flag("cactus_heard") else "The cactus keeps quiet while you watch it. It only sings with your back turned."])
		"shrine":
			GameState.set_flag("shrine_read")
			await Story.say(["A shrine, sunk to its shoulders in the sand. A star is cut over its door, and words under it:",
				"\"The arch-wizard set the winds to keep the way. Let the desert test whoever crosses it: they shall find the way by the star, or not at all.\""])
		"statue":
			await Story.say(["A stone statue of %s, curled up fast asleep. Its eyes are shut tight." % STATUES.get(String(n.get("beast", "")), "a beast"),
				"There are two more like it nearby. Something tells you they'd wake for the right touch, but not yet."])
		"band":
			await _band(n)
		"campfire":
			await Story.say(["A little campfire, with a pot of beans on it. Someone has written a set list in the sand. It has one song on it, crossed out."])
		"conduit":
			if GameState.flag("conduit_rubbed"):
				await Story.say(["The pipe runs north under the sand, stamped with its gear. You have the rubbing in your bag."])
				return
			GameState.set_flag("conduit_seen")
			await Story.say(["The wind has scoured the dune down to a pipe of gear-iron as thick as a barrel, running north under the sand.",
				"It's stamped with a gear in a circle. Gearheart's mark, out here in the middle of nowhere."])
			# the discovery goes back to Dalton as evidence (the plan's rubbing)
			GameState.set_flag("conduit_rubbed")
			GameState.receive_item("conduit_rubbing")
			Sfx.play("item")
			UI.toast("Received the %s!" % ItemDB.item_name("conduit_rubbing"), "item:conduit_rubbing")
			await Story.say(["You lay a page from your journal over the mark and rub it with a stub of charcoal.",
				"The gear comes away clean, and under it a line of letters: COGWORKS FREIGHT, SUBLEVEL 4. The rubbing goes in your bag."])
		"star_mark":
			GameState.set_flag("valkoog_landings")
			await Story.say(["A star is cut into the landing, wider than the one below it. Its points are numbered from the top, going round clockwise."
				if int(n.get("size", 1)) > 1 else "A small star is cut into the first landing, its points numbered from the top, going round clockwise."])


## The Rubywave Five on the road (there are four of them, and nobody mentions it): why they won't stop in Scaraba.
static func _band(n: Dictionary) -> void:
	GameState.set_flag("band_waystation")
	var i := int(n["member"])
	await Story.say([["Hey, it's you! I'm the first member of the Rubywave Five. We're walking to Cogsworth. There's a music shop there that'll take us on.",
			"Scaraba? We'll go round it. A walled town full of soldiers isn't a place for a band that's just got out of a contract."],
		["I'm the second member. We're resting our feet. Mostly mine.",
			"We heard Scaraba's sheriff asks every stranger for papers. We don't have papers. We have a tambourine."],
		["I'm the fourth member. Don't ask about the third.",
			"There's a star cut into every old stone out here. Riff says it's a chord chart. It isn't."],
		["I'm the fifth member! We're playing a second song tonight. A whole second song!",
			"If you see a cactus that sings, don't stare at it. We learned that the hard way."],
		][i], n["name"])


# ---------------------------------------------------------------- nodes
static func _mat(c: Color, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _spring(hot: bool) -> Node3D:
	var root := Node3D.new()
	var rim := CylinderMesh.new()
	rim.top_radius = 0.46
	rim.bottom_radius = 0.52
	rim.height = 0.34
	rim.radial_segments = 12
	_mesh(root, rim, Vector3(0, 0.17, 0), _mat(Color("#9a8a74") if not hot else Color("#8a6a5a")))
	var pool := CylinderMesh.new()
	pool.top_radius = 0.38
	pool.bottom_radius = 0.38
	pool.height = 0.04
	pool.radial_segments = 12
	_mesh(root, pool, Vector3(0, 0.33, 0), preload("res://scripts/gfx/duck.gd").water(Color("#5ab8d8") if not hot else Color("#8ad0c8")))
	if hot:
		var steam := CPUParticles3D.new()
		steam.amount = 10
		steam.lifetime = 2.2
		steam.direction = Vector3.UP
		steam.spread = 12.0
		steam.initial_velocity_min = 0.3
		steam.initial_velocity_max = 0.5
		steam.gravity = Vector3.ZERO
		steam.scale_amount_min = 0.6
		steam.scale_amount_max = 1.2
		var puff := SphereMesh.new()
		puff.radius = 0.12
		puff.height = 0.24
		var pm := _mat(Color(1, 1, 1, 0.35))
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material = pm
		steam.mesh = puff
		steam.position.y = 0.4
		root.add_child(steam)
	return root


static func _reed_post() -> Node3D:
	var root := Node3D.new()
	var reed := CylinderMesh.new()
	reed.top_radius = 0.02
	reed.bottom_radius = 0.035
	reed.height = 1.1
	reed.radial_segments = 4
	var green := _mat(Color("#6a8a3a"))
	for i in 7:
		var a := i * TAU / 7.0
		var mi := _mesh(root, reed, Vector3(cos(a) * 0.22, 0.55, sin(a) * 0.22), green)
		mi.rotation.z = cos(a) * 0.12
		mi.rotation.x = sin(a) * 0.12
	return root


static func _shrine() -> Node3D:
	var root := Node3D.new()
	var sand := _mat(Color("#b8a284"))
	var block := BoxMesh.new()
	block.size = Vector3(0.9, 0.7, 0.7)
	_mesh(root, block, Vector3(0, 0.3, 0), sand)
	var cap := BoxMesh.new()
	cap.size = Vector3(1.05, 0.14, 0.82)
	_mesh(root, cap, Vector3(0, 0.71, 0), _mat(Color("#b08858")))
	var door := BoxMesh.new()
	door.size = Vector3(0.36, 0.42, 0.04)
	_mesh(root, door, Vector3(0, 0.22, 0.34), _mat(Color("#3a2a1a")))
	var carve := _mat(Color("#6a4a2a"))
	carve.cull_mode = BaseMaterial3D.CULL_DISABLED
	var star := _mesh(root, StarLocks.star_mesh(0.14, 0.0), Vector3(0, 0.55, 0.355), carve)
	star.rotation.x = PI / 2.0
	# a drift of sand banked up against it
	var drift := SphereMesh.new()
	drift.radius = 0.6
	drift.height = 0.5
	var dm := _mesh(root, drift, Vector3(0.15, 0.0, -0.1), _mat(Color("#e0c08a")))
	dm.scale = Vector3(1.4, 1.0, 1.1)
	# (a shrine stands taller than the hero, even half buried)
	root.scale = Vector3.ONE * 1.7
	return root


## A sleeping beast in stone: plain rounded shapes, eyes shut (two dark slits).
static func _statue(beast: String) -> Node3D:
	var root := Node3D.new()
	var stone := _mat(Color("#a89880"))
	var plinth := BoxMesh.new()
	plinth.size = Vector3(0.8, 0.24, 0.8)
	_mesh(root, plinth, Vector3(0, 0.12, 0), stone)
	var body := SphereMesh.new()
	body.radius = 0.34
	body.height = 0.56
	var b := _mesh(root, body, Vector3(0, 0.5, 0), stone)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.36
	var hy := 0.86
	match beast:
		"snake":
			b.scale = Vector3(1.2, 0.6, 1.2)
			hy = 0.72
		"cat":
			for side in [-1, 1]:
				var ear := CylinderMesh.new()
				ear.top_radius = 0.0
				ear.bottom_radius = 0.07
				ear.height = 0.2
				_mesh(root, ear, Vector3(0.1 * side, 1.08, 0.12), stone)
		"owl":
			b.scale = Vector3(1.0, 1.2, 1.0)
			hy = 0.98
	_mesh(root, head, Vector3(0, hy, 0.12), stone)
	var slit := BoxMesh.new()
	slit.size = Vector3(0.08, 0.015, 0.02)
	for side in [-1, 1]:
		_mesh(root, slit, Vector3(0.07 * side, hy + 0.03, 0.3), _mat(Color("#3a3028")))
	return root


static func _star_mark(size: int) -> Node3D:
	var root := Node3D.new()
	var plate := CylinderMesh.new()
	plate.top_radius = 0.3 + size * 0.025
	plate.bottom_radius = plate.top_radius
	plate.height = 0.06
	plate.radial_segments = 10
	_mesh(root, plate, Vector3(0, 0.03, 0), _mat(Color("#b8925a")))
	var glow := _mat(Color("#7fe8d0"))
	glow.emission_enabled = true
	glow.emission = Color("#7fe8d0")
	glow.emission_energy_multiplier = 0.5
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(root, StarLocks.star_mesh(0.18 + size * 0.025, 0.07), Vector3.ZERO, glow)
	return root


static func _conduit() -> Node3D:
	var root := Node3D.new()
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.3
	pipe.bottom_radius = 0.3
	pipe.height = 1.0
	pipe.radial_segments = 12
	var iron := _mat(Color("#6a6460"), 0.6)
	iron.metallic = 0.5
	var mi := _mesh(root, pipe, Vector3(0, 0.12, 0), iron)
	mi.rotation.z = PI / 2.0
	var flange := CylinderMesh.new()
	flange.top_radius = 0.36
	flange.bottom_radius = 0.36
	flange.height = 0.08
	flange.radial_segments = 12
	for side in [-1, 1]:
		var f := _mesh(root, flange, Vector3(0.42 * side, 0.12, 0), iron)
		f.rotation.z = PI / 2.0
	return root


static func _campfire() -> Node3D:
	var root := Node3D.new()
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.05
	log_mesh.bottom_radius = 0.05
	log_mesh.height = 0.5
	var wood := _mat(Color("#5a3a22"))
	for i in 3:
		var mi := _mesh(root, log_mesh, Vector3(0, 0.06, 0), wood)
		mi.rotation = Vector3(PI / 2.0, i * TAU / 3.0, 0)
	var flame := _mat(Color("#ffa040"))
	flame.emission_enabled = true
	flame.emission = Color("#ff8a20")
	flame.emission_energy_multiplier = 2.0
	var fm := CylinderMesh.new()
	fm.top_radius = 0.0
	fm.bottom_radius = 0.12
	fm.height = 0.32
	_mesh(root, fm, Vector3(0, 0.22, 0), flame)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa050")
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.4
	root.add_child(light)
	return root
