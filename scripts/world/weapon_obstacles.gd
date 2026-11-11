extends Node3D
## Small road mechanisms; all timing is local to a single use, with no per-frame fixture work.
const Rules = preload("res://scripts/core/weapon_obstacles.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const Person = preload("res://scripts/gfx/voxel_person.gd")
const ItemDB = preload("res://scripts/data/item_db.gd")
const TempleProps = preload("res://scripts/gfx/temple_props.gd")
const Kit = preload("res://scripts/gfx/voxel_buildings.gd").Kit
var world
var targets := {}
var barriers := {}
var ladders := {}
var hanging := {}
static var materials := {}


func build(owner_world) -> void:
	world = owner_world
	for o in world.map.get("weapon_obstacles", []):
		for p in o["targets"]:
			if o["weapon"] == "bat" and o["solved"]:
				continue
			var root := _target(o["type"])
			root.position = world.tile_pos(p)
			var d: Vector2i = o["use_from"] - p
			root.rotation.y = clampf(atan2(float(d.x), float(d.y)), -PI / 4.0, PI / 4.0)
			add_child(root)
			targets[p] = root
			if o["solved"]:
				root.rotation.z = 0.25
		if o.get("effect", "") == "ladder":
			for p in o["blocks"]:
				if o["solved"]:
					continue # The shared ROPE terrain renderer draws ladders on map re-entry.
				var ladder := MeshInstance3D.new()
				ladder.mesh = VP.obstacle("rope_ladder")
				ladder.transform = world._on_slope(p, 0.02)
				ladder.visible = o["solved"]
				add_child(ladder)
				ladders[p] = ladder
		elif not o["solved"] and o["weapon"] != "bat":
			for p in o.get("blocks", []):
				var gate := MeshInstance3D.new()
				gate.mesh = VP.obstacle("gate")
				gate.position = world.tile_pos(p)
				add_child(gate)
				barriers[p] = gate
		if o.get("effect", "") == "chest" and not o["solved"]:
			var p: Vector2i = o["reward"]["pos"]
			var frame := Kit.new()
			frame.box("planks", Vector3(-0.48, 1.3, 0), Vector3(0.12, 2.6, 0.12), Color("#97704c"))
			frame.box("planks", Vector3(0, 2.6, 0), Vector3(1.1, 0.12, 0.12), Color("#97704c"))
			frame.box("color", Vector3(0, 2.35, 0), Vector3(0.025, 0.5, 0.025), Color("#d9bf91"))
			var support := MeshInstance3D.new()
			support.mesh = frame.mesh()
			support.position = world.tile_pos(p)
			add_child(support)
			var chest := TempleProps.chest(false)
			chest.position = world.tile_pos(p) + Vector3(0, 1.7, 0)
			add_child(chest)
			hanging[o["id"]] = chest
	# Props never add shadow casters to the world.
	for node in find_children("*", "GeometryInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func from_facing() -> Dictionary:
	var adjacent: Vector2i = world.player_pos + world.facing
	if world.npcs.has(adjacent) or world.doors.has(adjacent) or world.items.has(adjacent) or world.shards.has(adjacent):
		return {}
	for o in world.map.get("weapon_obstacles", []):
		if Rules.can_use(world.map, o, world.player_pos, world.facing):
			return o
	return {}


## Taps use a shot already in reach; otherwise pathfinding goes to the authored clear approach.
func approach(o: Dictionary) -> Vector2i:
	var target: Vector2i = Rules.shot_targets(o, world.player_pos)[0]
	var d := Vector2i(signi(target.x - world.player_pos.x), signi(target.y - world.player_pos.y))
	return world.player_pos if Rules.can_use(world.map, o, world.player_pos, d) else o["use_from"]


func use(o: Dictionary) -> void:
	if not Rules.can_use(world.map, o, world.player_pos, world.facing):
		return
	var weapon: String = o["weapon"]
	if GameState.item_count(weapon) <= 0:
		await UI.say([Rules.hint(o, GameState.weapon_seen(weapon))])
		return
	Person.set_ready(world.player, weapon, true)
	Person.set_action(world.player, ItemDB.weapon(weapon)["anim"])
	Sfx.play("slingshot" if weapon != "bat" else "smash")
	await get_tree().create_timer(0.16).timeout
	var projectile: Node3D
	var start: Vector3 = world.player.position + Vector3(0, 1.15, 0)
	if weapon != "bat":
		projectile = _projectile(weapon)
		projectile.position = start
		add_child(projectile)
		if weapon == "boomerang":
			Person.show_weapon(world.player, false)
	for p in Rules.shot_targets(o, world.player_pos):
		if projectile != null:
			var tw := create_tween()
			tw.tween_property(projectile, "position", world.tile_pos(p) + Vector3(0, 1.15, 0), 0.14)
			tw.parallel().tween_property(projectile, "rotation:y", projectile.rotation.y + TAU, 0.14)
			await tw.finished
		var node: Node3D = targets[p]
		var hit := create_tween()
		if weapon == "bat":
			hit.tween_property(node, "scale", Vector3.ONE * 0.02, 0.25)
		else:
			hit.tween_property(node, "rotation:z", 0.25, 0.08)
		Sfx.play("smash" if weapon == "bat" else "menu_ok")
		await hit.finished
	if projectile != null:
		if weapon == "boomerang":
			var returning := create_tween()
			returning.tween_property(projectile, "position", start, 0.22)
			returning.parallel().tween_property(projectile, "rotation:y", projectile.rotation.y + TAU, 0.22)
			await returning.finished
			Person.show_weapon(world.player, true)
			Person.set_action(world.player, "catch")
		projectile.queue_free()
	GameState.set_flag(o["flag"])
	Rules.solve(world.map, o)
	for p in o.get("blocks", []):
		if barriers.has(p):
			var gate: Node3D = barriers[p]
			var tw := create_tween()
			tw.tween_property(gate, "scale:y", 0.02, 0.3)
			tw.tween_callback(gate.queue_free)
		if ladders.has(p):
			var ladder: Node3D = ladders[p]
			var full := ladder.scale
			ladder.scale = full * Vector3(1, 1, 0.06)
			ladder.show()
			create_tween().tween_property(ladder, "scale", full, 0.35).set_trans(Tween.TRANS_BOUNCE)
	if hanging.has(o["id"]):
		var chest: Node3D = hanging[o["id"]]
		var drop := create_tween()
		drop.tween_property(chest, "position", world.tile_pos(o["reward"]["pos"]), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await drop.finished
		chest.queue_free()
	else:
		await get_tree().create_timer(0.35).timeout
	for p in world.npcs:
		var n: Dictionary = world.npcs[p]
		if n.get("hidden_until", "") == o["flag"]:
			n["node"].show()
	Person.set_ready(world.player, "")
	Sfx.secret_chime()
	UI.toast({"ladder": "The ladder drops into place!", "gate": "The gate opens!", "chest": "The chest drops to the ground!"}.get(o.get("effect", ""), "The way to the treasure is clear!"), "pin")


static func _material(colour: String) -> StandardMaterial3D:
	if not materials.has(colour):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(colour)
		mat.roughness = 0.85
		materials[colour] = mat
	return materials[colour]


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, colour: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(colour)
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _target(kind: String) -> Node3D:
	var root := Node3D.new()
	if kind == "cracked_rock":
		var rock := MeshInstance3D.new()
		rock.mesh = VP.obstacle("boulder")
		root.add_child(rock)
		# The common boulder's painted crack is too fine at the gameplay camera. A wider seam follows its surface.
		var seam := ImmediateMesh.new()
		var seam_material := _material("#514d49")
		seam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		seam.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, seam_material)
		for i in 25:
			var y := lerpf(1.4, 12.0, i / 24.0)
			var x := 8.0 + sin(y * 0.7) * 1.3
			for side in [-1.0, 1.0]:
				var px: float = x + side * 0.5
				var z := 8.0 + 7.0 * sqrt(maxf(0.0, 1.0 - pow((px - 8.0) / 7.5, 2) - pow((y - 6.5) / 6.5, 2)))
				var upper := 1.0 - pow((px - 6.0) / 4.5, 2) - pow((y - 10.0) / 4.0, 2)
				if upper >= 0.0:
					z = maxf(z, 7.0 + 4.5 * sqrt(upper))
				seam.surface_set_normal(Vector3(0, 0.3, 1).normalized())
				seam.surface_add_vertex(Vector3(px - 8.0, y, z - 8.0) * VP.VS + Vector3(0, 0, 0.012))
		seam.surface_end()
		var crack := MeshInstance3D.new()
		crack.mesh = seam
		root.add_child(crack)
		return root
	if kind == "stump":
		var stump := CylinderMesh.new()
		stump.top_radius = 0.42
		stump.bottom_radius = 0.5
		stump.height = 0.85
		stump.radial_segments = 9
		_part(root, stump, Vector3(0, 0.425, 0), "#9a6c43")
		for i in 3:
			var ring := CylinderMesh.new()
			ring.top_radius = 0.42 - i * 0.12
			ring.bottom_radius = ring.top_radius
			ring.height = 0.01
			ring.radial_segments = 18
			_part(root, ring, Vector3(0, 0.855 + i * 0.008, 0), "#d1aa75" if i != 1 else "#a67a4e")
		var crack := BoxMesh.new()
		crack.size = Vector3(0.055, 0.04, 0.8)
		_part(root, crack, Vector3(0, 0.88, 0), "#523c2b")
		return root
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 1.6 if kind == "bell" else 1.35, 0.12)
	_part(root, post, Vector3(-0.42, 0.8, 0) if kind == "bell" else Vector3(0, 0.675, 0), "#916844")
	if kind == "bell":
		var beam := BoxMesh.new()
		beam.size = Vector3(0.68, 0.1, 0.16)
		_part(root, beam, Vector3(-0.16, 1.6, 0.06), "#916844")
		var hanger := BoxMesh.new()
		hanger.size = Vector3(0.05, 0.18, 0.05)
		_part(root, hanger, Vector3(0, 1.5, 0.12), "#785e2c")
		var bell := CylinderMesh.new()
		bell.top_radius = 0.15
		bell.bottom_radius = 0.37
		bell.height = 0.42
		_part(root, bell, Vector3(0, 1.35, 0.12), "#d6b65a")
		var clapper := SphereMesh.new()
		clapper.radius = 0.09
		clapper.height = 0.18
		_part(root, clapper, Vector3(0, 1.08, 0.12), "#785e2c")
	else:
		for i in 3:
			var disc := CylinderMesh.new()
			disc.top_radius = 0.39 - i * 0.12
			disc.bottom_radius = disc.top_radius
			disc.height = 0.035
			disc.radial_segments = 24
			var node := _part(root, disc, Vector3(0, 1.15, 0.07 + i * 0.025), "#f4ead7" if i == 1 else ("#d9ac48" if kind == "switches" else "#bc4635"))
			node.rotation.x = PI / 2.0
	return root


static func _projectile(weapon: String) -> Node3D:
	var root := Node3D.new()
	if weapon == "boomerang":
		for side in [-1, 1]:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.34, 0.055, 0.09)
			var node := _part(root, arm, Vector3(side * 0.12, 0, 0), "#d9a066")
			node.rotation.y = side * -0.65
	else:
		var stone := SphereMesh.new()
		stone.radius = 0.09
		stone.height = 0.18
		_part(root, stone, Vector3.ZERO, "#c8c1b4")
	return root
