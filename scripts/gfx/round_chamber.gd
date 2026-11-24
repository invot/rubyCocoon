extends RefCounted
## The Temple of Tides' guardian chamber, a round room (a room's "round" in interior_maps.gd): a raised round stone
## platform almost filling it, standing over a dark pit; round the wall, curtains of water pour from a ledge all the
## way round and fall past the platform's edge into the pool of dark water below. A stone bridge crosses from the doorway, and in
## the middle the guardian's nest sits on a round dais of three steps, lit by a soft shaft of sunlight from above.
## The room is dark: candles along the way in and torches by the door light it (temple_lights.gd).
## The wall nearest the camera stands low, the water pouring over its top, so the room is seen whole.
## Built in world units (a tile is one unit); `round` is {"centre": Vector2i, "platform": r, "wall": r, "dais": [r..]}.

const TempleLights = preload("res://scripts/gfx/temple_lights.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")

const SEGS := 72
## the wall's height at the back, and at the front (towards the camera)
const WALL_H := 4.4
const FRONT_H := 0.55
## how deep the pit is, under the platform, and the pool of water filling its bottom (the falls land in it)
const PIT := 3.6
const POOL_Y := -2.9
## the water's colours, deep and dim (the room is dark)
const FALL_TINT := Color("#1d6688")
const POOL_TINT := Color("#124a66")
## each step of the dais
const STEP := 0.17
const DOOR_W := 1.1
const DOOR_TOP := 2.5

var centre: Vector3
var rp: float
var rw: float
var parent: Node3D
var stone: Color
var inlay: Color
var _st := {}
var _mats := {}


## Builds the chamber into `p`. Returns how high the dais's top stands (for the nest on it).
static func build(p: Node3D, m: Dictionary, water: ShaderMaterial, stone_colour: Color, inlay_colour: Color) -> float:
	var rc = load("res://scripts/gfx/round_chamber.gd").new()
	return rc._build(p, m, water, stone_colour, inlay_colour)


## The dais's top (where the nest stands), from the room's settings.
static func dais_top(room: Dictionary) -> float:
	return (room.get("round", {}).get("dais", []) as Array).size() * STEP


func _build(p: Node3D, m: Dictionary, water: ShaderMaterial, stone_colour: Color, inlay_colour: Color) -> float:
	parent = p
	stone = stone_colour
	inlay = inlay_colour
	var cfg: Dictionary = m["room"]["round"]
	var c: Vector2i = cfg["centre"]
	centre = Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	rp = float(cfg.get("platform", 7.0))
	rw = float(cfg.get("wall", 9.0))
	_mats["floor"] = RoomBuilder.floor_surface("floor_ancient")
	_mats["stone"] = RoomBuilder.wall_surface("ashlar", stone)
	_mats["dark"] = RoomBuilder.wall_surface("ashlar", stone.darkened(0.55))
	_mats["trim"] = RoomBuilder.wall_surface("ashlar", stone.lightened(0.08))
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = inlay
	glow.emission_enabled = true
	glow.emission = inlay
	glow.emission_energy_multiplier = 0.9
	_mats["glow"] = glow
	var doors := []
	for e: Vector2i in m.get("exits", {}):
		doors.append(atan2(e.y + 0.5 - centre.z, e.x + 0.5 - centre.x))
	_platform()
	_pit()
	_wall(doors)
	for a in doors:
		_bridge(a)
	var top := _dais(cfg.get("dais", []))
	_commit()
	_curtain(water, doors)
	_pool(water)
	_sunbeam(top)
	_lights(m, doors, cfg)
	return top


# ---------------------------------------------------------------- geometry
func _tool(mat: String) -> SurfaceTool:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat] = st
	return _st[mat]


## One triangle facing `n` (Godot's front faces wind clockwise as seen from the front).
func _tri(mat: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var st := _tool(mat)
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for v in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(mat, a, b, c, n, ua, ub, uc)
	_tri(mat, a, c, d, n, ua, uc, ud)


func _at(a: float, r: float, y: float) -> Vector3:
	return centre + Vector3(cos(a) * r, y, sin(a) * r)


## An upright band round the middle from angle a0 to a1, radius r, from y0 to y1, facing in (or out).
func _band(mat: String, r: float, y0: float, y1: float, a0: float, a1: float, inward: bool) -> void:
	var n := maxi(1, int(ceil(absf(a1 - a0) / TAU * SEGS)))
	for i in n:
		var b0 := lerpf(a0, a1, float(i) / n)
		var b1 := lerpf(a0, a1, float(i + 1) / n)
		var mid := (b0 + b1) / 2.0
		var nrm := Vector3(cos(mid), 0, sin(mid)) * (-1.0 if inward else 1.0)
		_quad(mat, _at(b0, r, y0), _at(b1, r, y0), _at(b1, r, y1), _at(b0, r, y1), nrm,
			Vector2(b0 * r, -y0), Vector2(b1 * r, -y0), Vector2(b1 * r, -y1), Vector2(b0 * r, -y1))


## A flat ring (or disc, r0 = 0) at height y, facing up (or down).
func _ring(mat: String, r0: float, r1: float, y: float, a0 := 0.0, a1 := TAU, up := true) -> void:
	var n := maxi(1, int(ceil(absf(a1 - a0) / TAU * SEGS)))
	var nrm := Vector3.UP if up else Vector3.DOWN
	for i in n:
		var b0 := lerpf(a0, a1, float(i) / n)
		var b1 := lerpf(a0, a1, float(i + 1) / n)
		var p := [_at(b0, r0, y), _at(b1, r0, y), _at(b1, r1, y), _at(b0, r1, y)]
		var uv := p.map(func(v: Vector3) -> Vector2: return Vector2(v.x, v.z))
		if r0 <= 0.001:
			_tri(mat, p[0], p[2], p[3], nrm, uv[0], uv[2], uv[3])
		else:
			_quad(mat, p[0], p[1], p[2], p[3], nrm, uv[0], uv[1], uv[2], uv[3])


func _commit() -> void:
	for mat in _st:
		var st: SurfaceTool = _st[mat]
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "Chamber_" + String(mat)
		mi.mesh = st.commit()
		mi.material_override = _mats[mat]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mat == "glow" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mi)
	_st.clear()


# ---------------------------------------------------------------- the room
## The platform: a stone disc, a raised lip round its edge with a thin glowing line, its side going down into the pit.
func _platform() -> void:
	_ring("floor", 0.0, rp - 0.3, 0.0)
	_ring("trim", rp - 0.3, rp, 0.12)
	_band("trim", rp - 0.3, 0.0, 0.12, 0.0, TAU, false)
	_band("trim", rp, -0.25, 0.12, 0.0, TAU, false)
	_band("glow", rp + 0.005, -0.2, -0.16, 0.0, TAU, false)
	_band("stone", rp - 0.15, -PIT, -0.25, 0.0, TAU, false)
	# (a ledge under the lip, so the edge reads as a slab)
	_ring("stone", rp - 0.15, rp, -0.25, 0.0, TAU, false)


## The pit's dark floor, far down under its water.
func _pit() -> void:
	_ring("dark", 0.0, rw + 0.2, -PIT)


## The pool filling the pit's bottom, from the platform's foot to the wall, and the white water where the falls land.
func _pool(water: ShaderMaterial) -> void:
	var mat: ShaderMaterial = water.duplicate()
	mat.set_shader_parameter("tint", POOL_TINT)
	mat.set_shader_parameter("opacity", 0.94)
	mat.set_shader_parameter("drift", Vector2(0.0, 0.05))
	_mats["pool"] = mat
	_ring("pool", rp - 0.2, rw + 0.05, POOL_Y)
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_color = Color(0.85, 0.93, 1.0, 0.32)
	_mats["foam"] = foam
	_ring("foam", rw - 0.75, rw - 0.05, POOL_Y + 0.03)
	_commit()


## The round wall: high at the back, low at the front (the camera's side, +z), with the doorways cut through it, and
## the ledge at its top the water pours from.
func _wall(doors: Array) -> void:
	for i in SEGS:
		var a0 := TAU * i / SEGS
		var a1 := TAU * (i + 1) / SEGS
		var mid := (a0 + a1) / 2.0
		var hgt := _height(mid)
		var door := _in_door(mid, doors)
		var y_lo := -PIT
		if door:
			# under the doorway's sill, and over its lintel
			_band("stone", rw, y_lo, -0.05, a0, a1, true)
			_band("stone", rw, DOOR_TOP, maxf(hgt, DOOR_TOP + 0.6), a0, a1, true)
			_band("stone", rw + 0.5, DOOR_TOP, maxf(hgt, DOOR_TOP + 0.6), a0, a1, false)
			_ring("trim", rw, rw + 0.5, maxf(hgt, DOOR_TOP + 0.6), a0, a1)
			continue
		_band("stone", rw, y_lo, hgt, a0, a1, true)
		_band("stone", rw + 0.5, -0.4, hgt, a0, a1, false)
		_ring("trim", rw - 0.25, rw + 0.55, hgt, a0, a1)
		_band("trim", rw - 0.25, hgt - 0.22, hgt, a0, a1, true)
		_band("glow", rw - 0.255, hgt - 0.16, hgt - 0.12, a0, a1, true)


## The wall's height at angle a: WALL_H at the back, falling smoothly to FRONT_H across the front.
func _height(a: float) -> float:
	var front := maxf(0.0, sin(a))
	return lerpf(WALL_H, FRONT_H, smoothstep(0.35, 0.75, front))


func _in_door(a: float, doors: Array) -> bool:
	for d: float in doors:
		if absf(angle_difference(a, d)) < DOOR_W / 2.0 / rw + 0.02:
			return true
	return false


## A stone bridge from the doorway at angle a over the pit to the platform's lip, with low parapets.
func _bridge(a: float) -> void:
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x)
	var r0 := rp - 0.35
	var r1 := rw + 0.05
	var half := 0.62
	var p0 := centre + dir * r0
	var p1 := centre + dir * r1
	var deck := 0.12
	_quad("floor", p0 - side * half + Vector3(0, deck, 0), p1 - side * half + Vector3(0, deck, 0), p1 + side * half + Vector3(0, deck, 0),
		p0 + side * half + Vector3(0, deck, 0), Vector3.UP, Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p1.x, p1.z) + Vector2(1, 0), Vector2(p0.x, p0.z) + Vector2(1, 0))
	_quad("stone", p0 - side * half + Vector3(0, -0.45, 0), p1 - side * half + Vector3(0, -0.45, 0), p1 + side * half + Vector3(0, -0.45, 0),
		p0 + side * half + Vector3(0, -0.45, 0), Vector3.DOWN, Vector2.ZERO, Vector2(r1 - r0, 0), Vector2(r1 - r0, 1), Vector2(0, 1))
	for s in [-1.0, 1.0]:
		var e: Vector3 = side * s * half
		# its side face, and a parapet along it
		_quad("stone", p0 + e + Vector3(0, -0.45, 0), p1 + e + Vector3(0, -0.45, 0), p1 + e + Vector3(0, deck, 0), p0 + e + Vector3(0, deck, 0),
			side * s, Vector2(0, 0.45), Vector2(r1 - r0, 0.45), Vector2(r1 - r0, -deck), Vector2(0, -deck))
		_box("trim", (p0 + p1) / 2.0 + side * s * (half - 0.08) + Vector3(0, deck + 0.17, 0), dir, side, r1 - r0 - 0.1, 0.16, 0.34)


## A box along `dir` (its length), across `side` (its width), `tall` high, centred at c.
func _box(mat: String, c: Vector3, dir: Vector3, side: Vector3, length: float, wide: float, tall: float) -> void:
	var hx := dir * length / 2.0
	var hz := side * wide / 2.0
	var hy := Vector3(0, tall / 2.0, 0)
	var faces := [[hy, hx, hz], [-hy, hx, hz], [hx, hy, hz], [-hx, hy, hz], [hz, hx, hy], [-hz, hx, hy]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n
		_quad(mat, o - u - v, o + u - v, o + u + v, o - u + v, n.normalized(), Vector2(0, 0), Vector2(u.length() * 2.0, 0),
			Vector2(u.length() * 2.0, v.length() * 2.0), Vector2(0, v.length() * 2.0))


## The dais: a round step for each radius, the top one the widest flat (the nest stands on it). Returns its top.
func _dais(radii: Array) -> float:
	var y := 0.0
	for r: float in radii:
		_band("trim", r, y, y + STEP, 0.0, TAU, false)
		_band("glow", r + 0.004, y + STEP - 0.05, y + STEP - 0.03, 0.0, TAU, false)
		y += STEP
		_ring("stone", 0.0, r, y)
	return y


## The curtain of falling water just inside the wall, all the way round but the doorways, from its ledge into the pit.
func _curtain(water: ShaderMaterial, doors: Array) -> void:
	var mat: ShaderMaterial = water.duplicate()
	mat.set_shader_parameter("opacity", 0.8)
	mat.set_shader_parameter("tint", FALL_TINT)
	mat.set_shader_parameter("spec", 0.15)
	mat.set_shader_parameter("fall_swell", true)
	mat.set_shader_parameter("fall_rim", true)
	mat.set_shader_parameter("drift", Vector2(0.0, -1.3))
	mat.set_shader_parameter("fall_stretch", 4.0)
	mat.set_shader_parameter("froth", 0.55)
	# (stream lines spaced round the ring, not along x + z, which folds into a chevron at the back left; five a unit)
	mat.set_shader_parameter("fall_ring", roundf(TAU * (rw - 0.32) * 5.0))
	mat.set_shader_parameter("fall_centre", Vector2(centre.x, centre.z))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var r := rw - 0.32
	for i in SEGS:
		var a0 := TAU * i / SEGS
		var a1 := TAU * (i + 1) / SEGS
		if _in_door((a0 + a1) / 2.0, doors) or _in_door(a0, doors) or _in_door(a1, doors):
			continue
		var top0 := _height(a0) - 0.2
		var top1 := _height(a1) - 0.2
		# (out over the ledge, then straight down)
		var prof0 := [Vector2(r + 0.1, top0), Vector2(r - 0.05, top0 - 0.35), Vector2(r - 0.12, POOL_Y)]
		var prof1 := [Vector2(r + 0.1, top1), Vector2(r - 0.05, top1 - 0.35), Vector2(r - 0.12, POOL_Y)]
		for j in prof0.size() - 1:
			var q := [_at(a0, prof0[j].x, prof0[j].y), _at(a1, prof1[j].x, prof1[j].y), _at(a1, prof1[j + 1].x, prof1[j + 1].y),
				_at(a0, prof0[j + 1].x, prof0[j + 1].y)]
			var mid := (a0 + a1) / 2.0
			var n := -Vector3(cos(mid), 0, sin(mid))
			var u0 := a0 * r
			var u1 := a1 * r
			var uv := [Vector2(u0, top0 - prof0[j].y), Vector2(u1, top1 - prof1[j].y), Vector2(u1, top1 - prof1[j + 1].y), Vector2(u0, top0 - prof0[j + 1].y)]
			for k in [0, 2, 1, 0, 3, 2]:
				verts.append(q[k])
				norms.append(n)
				uvs.append(uv[k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Curtain"
	mi.mesh = am
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## A soft shaft of sunlight from high above onto the middle of the dais, and the light it casts there. Subtle.
func _sunbeam(top: float) -> void:
	var spot := SpotLight3D.new()
	spot.name = "Sunbeam"
	spot.position = centre + Vector3(0, top + 6.5, 0)
	spot.rotation.x = -PI / 2.0
	spot.light_color = Color("#fff1d2")
	spot.light_energy = 16.0
	spot.spot_range = 9.0
	spot.spot_attenuation = 0.6
	spot.spot_angle = 17.0
	spot.spot_angle_attenuation = 1.4
	spot.shadow_enabled = false
	parent.add_child(spot)
	var beam := MeshInstance3D.new()
	beam.name = "SunShaft"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.7
	cone.bottom_radius = 1.9
	cone.height = 1.0
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/gfx/hatchery_beam.gdshader")
	mat.set_shader_parameter("light_color", Color("#fff1d2"))
	mat.set_shader_parameter("power", 1.0)
	mat.set_shader_parameter("strength", 0.2)
	mat.set_shader_parameter("falloff", 2.2)
	mat.set_shader_parameter("base_fade", 0.7)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (a shaft of light, not an object: its shader fades it out, so it needs no texture)
	beam.add_to_group("untextured_fx")
	var tall := 8.0
	beam.position = centre + Vector3(0, top + tall / 2.0, 0)
	beam.scale = Vector3(1, tall, 1)
	parent.add_child(beam)
	# where it comes in: a round opening of pale daylight in the dark overhead
	var sky := MeshInstance3D.new()
	sky.name = "Oculus"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.02
	disc.radial_segments = 24
	sky.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("#fff4dc")
	sm.emission_enabled = true
	sm.emission = Color("#fff1d2")
	sm.emission_energy_multiplier = 1.4
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = centre + Vector3(0, top + tall, 0)
	parent.add_child(sky)


## Bundles of candles, every candle a different height and thickness, along the way in and round the foot of the
## dais (a few of them lighting the floor), and a torch either side of each doorway.
func _lights(m: Dictionary, doors: Array, cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	var lit := 0
	# along both edges of the lane the room lists ("candles": [[from, to], ...] in tiles, bundles along each)
	for line: Array in cfg.get("candles", []):
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var n := maxi(1, int(round(a.distance_to(b) / 1.25)))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n) + Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.06, 0.06))
			var light := 0.0
			if i % 2 == 1 and lit < 4:
				light = 0.75
				lit += 1
			parent.add_child(TempleLights.bundle(Vector3(p.x, 0.0, p.y), rng.randi_range(3, 6), rng, light, 3.2))
	# bundles round the dais's bottom step
	var radii: Array = cfg.get("dais", [])
	if radii.size() > 1:
		var r := (float(radii[0]) + float(radii[1])) / 2.0
		for i in 7:
			var a := TAU * (i + 0.5) / 7.0
			parent.add_child(TempleLights.bundle(_at(a, r, STEP), rng.randi_range(2, 4), rng))
	for d: float in doors:
		for s in [-1.0, 1.0]:
			var a: float = d + s * (DOOR_W / 2.0 + 0.45) / rw
			var at := _at(a, rw - 0.02, 1.2)
			parent.add_child(TempleLights.wall_torch(at, -Vector3(cos(a), 0, sin(a)), true, 1.1, 4.5))
