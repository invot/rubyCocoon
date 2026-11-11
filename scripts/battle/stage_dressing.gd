extends RefCounted
## Cached regional assets in small perimeter batches. Tall pieces stay beyond every fighting pad and normal shot.
const VA = preload("res://scripts/gfx/voxel_assets.gd")


static func _place(batches: Dictionary, asset: String, at: Vector3, height: float, yaw: float) -> void:
	var scale := VA.fit_scale(asset, height)
	at.y -= VA.aabb(asset).position.y * scale
	if not batches.has(asset):
		batches[asset] = []
	batches[asset].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at))


static func build(battle: Node3D, rng: RandomNumberGenerator) -> void:
	var batches := {}
	if battle.indoor and not battle.cfg.get("arena", false):
		_room_corners(battle, batches)
	else:
		_perimeter(battle, batches, rng)
	for asset in batches:
		battle._multimesh(VA.mesh(asset), batches[asset])


static func _perimeter(battle: Node3D, batches: Dictionary, rng: RandomNumberGenerator) -> void:
	var biome: Dictionary = battle.biome
	var fishing: bool = battle.cfg.get("fishing", false)
	var arena: bool = battle.cfg.get("arena", false)
	var arid: bool = biome.has("boulders")
	var big: Array = biome.get("boulders", biome["trees"])
	var rocks: Array = biome["rocks"]
	var shrubs: Array = biome["shrubs"]
	var shore: Vector3 = battle.ALLY_CENTER - battle._toward("ally") * 4.0
	for corner in 4:
		var angle := PI * 0.25 + corner * PI * 0.5
		var outward := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-outward.z, 0, outward.x)
		var center := Vector3(0, 0, 1.5) + outward * 25.8
		var wet: bool = fishing and (center - shore).dot(battle._toward("ally")) > 0.0
		for i in 3:
			var at := center + tangent * (i - 1) * 2.2 + outward * rng.randf_range(-0.5, 0.5)
			var asset: String
			if arena:
				asset = "stone_pillar"
			elif wet:
				asset = "beach_rock"
			else:
				var entry = big[(corner + i) % big.size()]
				asset = String(entry if arid else entry[0])
			var height := rng.randf_range(4.8, 6.6) if not wet else rng.randf_range(2.4, 3.8)
			_place(batches, asset, at + Vector3.DOWN * (0.25 if wet else 0.0), height, angle + i * 0.7)
			var foot := center - outward * 1.9 + tangent * (i - 1) * 2.7
			var low: String = rocks[(corner + i) % rocks.size()] if arid or wet else shrubs[(corner + i) % shrubs.size()]
			if arena:
				low = "banner" if i == 1 else "stone_pillar"
			_place(batches, low, foot, rng.randf_range(1.0, 1.8) if not arena else 2.8, angle + PI)
		for side in [-1.0, 1.0]:
			var asset: String = "beach_rock" if fishing else String(rocks[corner % rocks.size()])
			_place(batches, asset, center - outward * 0.8 + tangent * side * 4.5, 1.7, angle + side)


static func _room_corners(battle: Node3D, batches: Dictionary) -> void:
	var glow := Color("#ad8ce0")
	var office: bool = String(battle.biome["id"]) == "steampunk"
	if is_instance_valid(GameState.main) and GameState.main.world != null:
		var building: Dictionary = GameState.main.world.map.get("building", {})
		glow = Color(building.get("glow", "#ad8ce0"))
	for x in [-22.7, 22.7]:
		for z in [-20.7, 23.7]:
			var at := Vector3(x, 0, z)
			var inward := (Vector3(0, 0, 1.5) - at).normalized()
			var yaw := atan2(inward.x, inward.z)
			# A column spans each wall junction up to the ceiling; lower props break up the floor/wall join.
			_place(batches, "stone_pillar_dark", at, 11.4, yaw)
			_place(batches, "crates" if office else "mossy_statue", at + inward * 2.3, 2.7, yaw)
			_place(batches, "barrel" if office else "stone_pillar", at + inward * 3.0 + Vector3(inward.z, 0, -inward.x) * 1.6, 1.6, yaw)
			_place(batches, "torch", at + inward * 1.5 + Vector3.UP * 2.4, 1.4, yaw)
			var practical := OmniLight3D.new()
			practical.name = "CornerAccent"
			practical.position = at + inward * 2.0 + Vector3.UP * 3.5
			practical.light_color = glow.lerp(Color("#ffbd79"), 0.55)
			practical.light_energy = 0.9
			practical.omni_range = 9.0
			practical.shadow_enabled = false
			battle.add_child(practical)
