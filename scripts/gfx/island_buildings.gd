extends RefCounted
## Kelpwick adapts the supplied tropical hut; Shellhaven retains its shared wall sections and roof mesher.
const VB = preload("res://scripts/gfx/voxel_buildings.gd")
const HB = preload("res://scripts/gfx/house_builder.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const PERSON = preload("res://scripts/gfx/voxel_person.gd")
const WORLD = preload("res://scripts/data/world_db.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const PASTELS := ["#f1b8ae", "#f3d995", "#b5d9c8", "#c9bce1", "#aed4e2"]
const HUT_LIFT := 0.84
const HUT_FACE_INSET := 0.70
const ARENA_FACE_INSET := 0.81
const HUT_TIMBER := Color("#98683f")
# Pink, orange, dusty red, clay brown, lavender and sky blue.
const HUT_PASTELS := ["#e8b4c2", "#eac09a", "#dca39a", "#bf9d88", "#c4b0db", "#aed0e2"]
const HUT_PAINT_ORDER := [2, 0, 1, 4, 5]

static func hut_face_inset(b: Dictionary) -> float:
	return ARENA_FACE_INSET if b.get("shop", "") == "arena" else HUT_FACE_INSET

## Shared with the entrance animation; the flight ends at the original street tile's centre.
static func hut_stairs(b: Dictionary, ground: float) -> Array:
	var x := float(b["door"].x) + 0.5
	var face := float(b["y"]) + float(b["d"]) - hut_face_inset(b)
	var points := [Vector3(x, ground, float(b["door"].y) + 1.5)]
	for step in 6:
		points.append(Vector3(x, ground + HUT_LIFT * float(step + 1) / 6.0, face + 1.125 - float(step) * 0.15))
	points.append(Vector3(x, ground + HUT_LIFT, face + 0.14))
	return points

static var _wood: ShaderMaterial

static func wood_material() -> ShaderMaterial:
	if _wood == null:
		_wood = ShaderMaterial.new()
		_wood.shader = preload("res://scripts/gfx/island_wood.gdshader")
	return _wood

static var _hut_meshes := {}
static var _hut_timber: StandardMaterial3D

static func timber_material() -> StandardMaterial3D:
	if _hut_timber == null:
		# the hut's stairs, deck and posts in the game's shared wood (voxel_textures.gd WOOD), like every dock and fence
		_hut_timber = StandardMaterial3D.new()
		_hut_timber.roughness = 0.95
		load("res://scripts/gfx/voxel_textures.gd").apply_wood(_hut_timber, "planks", 0.0)
	return _hut_timber

## Fit the supplied mesh to the existing plot, keeping a full-size door and the source roof/profile.
static func _asset_hut(rx: float, r: float) -> ArrayMesh:
	var key := Vector2(rx, r)
	if _hut_meshes.has(key):
		return _hut_meshes[key]
	var source: ArrayMesh = load("res://assets/exteriors/tribal_hut.res")
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var p := vertices[i]
			var y_scale := 1.84 / 157.612 if p.y < 48.2 else 0.009
			var height := (p.y + 109.412) * y_scale if p.y < 48.2 else 1.84 + (p.y - 48.2) * y_scale
			var x := p.x * rx
			if p.y < 110.0 and p.z > -0.35 and absf(p.x) < 0.75:
				var ax := absf(p.x)
				var fitted := ax / 0.2 * 0.45 if ax <= 0.2 else lerpf(0.45, rx * 0.75, (ax - 0.2) / 0.55)
				x = lerpf(x, signf(p.x) * fitted, smoothstep(-0.35, -0.08, p.z))
			vertices[i] = Vector3(x, height, p.z * r)
			normals[i] = Vector3(normals[i].x / rx, normals[i].y / (y_scale * 200.0), normals[i].z / r).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
		mesh.surface_set_name(surface, source.surface_get_name(surface))
	_hut_meshes[key] = mesh
	return mesh

static func _stilt_hut(node: Node3D, k: VB.Kit, b: Dictionary, dx: float, face: float) -> float:
	var r := float(b.get("hut_radius", minf(float(b["w"]) / 2.0 - 0.12, float(b["d"]) / 2.0 - 0.12)))
	var rx := maxf(r, float(b.get("hut_rx", r)))
	var paint_index: int = HUT_PAINT_ORDER[int(b.get("index", 0)) % HUT_PAINT_ORDER.size()]
	var paint := Color(b.get("hut_paint", HUT_PASTELS[paint_index]))
	var center := Vector2(dx, face - r * 0.98138)
	var mi := MeshInstance3D.new()
	mi.mesh = _asset_hut(rx, r)
	mi.position = Vector3(dx, HUT_LIFT, face)
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://scripts/gfx/hut_plaster.gdshader")
	finish.set_shader_parameter("atlas", (mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture)
	finish.set_shader_parameter("paint", paint)
	mi.set_surface_override_material(0, finish)
	node.add_child(mi)
	b["door_sill"] = HUT_LIFT
	# Seal the room within its walls. A flat ceiling avoids a second roof cutting through the plaster.
	var ceiling := VB._loop(center, rx * 0.97, r * 0.97, 32)
	VB._skirt(k, "color", ceiling, HUT_LIFT, 2.30, paint, center)
	VB._band(k, "planks", ceiling, VB._fill(center, 32), HUT_LIFT + 2.30, HUT_TIMBER)
	var deck := VB._loop(center, rx + 0.10, r + 0.10, 24)
	VB._ledge(k, "planks", deck, VB._fill(center, 24), center, HUT_LIFT - 0.15, 0.15, HUT_TIMBER)
	for angle in [PI / 6.0, PI / 2.0, 5.0 * PI / 6.0, 7.0 * PI / 6.0, 3.0 * PI / 2.0, 11.0 * PI / 6.0]:
		VB._column(k, "planks", Vector3(center.x + sin(angle) * rx * 0.92, 0, center.y + cos(angle) * r * 0.92), 0.14, HUT_LIFT, 6, HUT_TIMBER)
	_hut_entry(node, k, b, dx, face, paint)
	_hut_garden(node, dx, face, rx)
	return HUT_LIFT + 3.70

static func _hut_entry(node: Node3D, k: VB.Kit, b: Dictionary, dx: float, face: float, paint: Color, lintel := true) -> void:
	k.box("planks", Vector3(dx, HUT_LIFT - 0.075, face + 0.12), Vector3(1.44, 0.15, 0.42), HUT_TIMBER, true)
	for step in 6:
		var h := HUT_LIFT * float(step + 1) / 6.0
		k.box("planks", Vector3(dx, h - 0.045, face + 1.125 - float(step) * 0.15), Vector3(1.22, 0.09, 0.17), HUT_TIMBER, true)
	for side in [-1.0, 1.0]:
		VB._beam(k, "planks", Vector3(dx + side * 0.51, 0.04, face + 1.18), Vector3(dx + side * 0.51, HUT_LIFT - 0.1, face + 0.3), 0.11, HUT_TIMBER)
		VB._column(k, "planks", Vector3(dx + side * 0.62, 0, face + 0.26), 0.09, HUT_LIFT, 6, HUT_TIMBER)
	# The asset's cloth panel is removed at bake time. A solid timber leaf seals its place.
	var locked: bool = b.get("locked", false)
	var door_kit := VB.Kit.new()
	door_kit.box("planks_v", Vector3(dx, HUT_LIFT + 0.92, face - 0.015), Vector3(0.92, 1.84, 0.07), VB.LOCKED_DOOR if locked else VB.OPEN_DOOR, true)
	var leaf := MeshInstance3D.new()
	leaf.name = "SolidWoodDoor"
	leaf.mesh = door_kit.mesh()
	leaf.material_override = preload("res://scripts/gfx/house_models.gd").door_material(locked)
	node.add_child(leaf)
	k.box("color", Vector3(dx + 0.29, HUT_LIFT + 0.86, face + 0.035), Vector3(0.065, 0.13, 0.05), Color("#d6b46b"))
	if lintel:
		k.box("color", Vector3(dx, HUT_LIFT + 2.09, face - 0.02), Vector3(0.92, 0.50, 0.08), paint, true)

static func _hut_garden(node: Node3D, dx: float, face: float, span: float) -> void:
	# Low ground planting sits outside the stair's 1.44-wide landing and walking approach.
	var bush_mesh: Mesh = VA.mesh("shrub_1")
	var bush_scale := VA.fit_scale("shrub_1", 0.36, 0.62)
	var planting := MultiMesh.new()
	planting.transform_format = MultiMesh.TRANSFORM_3D
	planting.mesh = bush_mesh
	planting.instance_count = 2
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var at := Vector3(dx + side * maxf(1.32, span * 0.78), -bush_mesh.get_aabb().position.y * bush_scale, face + 0.14)
		planting.set_instance_transform(i, Transform3D(Basis(Vector3.UP, side * 0.6).scaled(Vector3.ONE * bush_scale), at))
	var garden := MultiMeshInstance3D.new()
	garden.name = "GroundBushes"
	garden.multimesh = planting
	garden.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(garden)

## The supplied arena keeps one horizontal scale, rather than stretching into an oval.
const ARENA_SCALE := 5.75
const ARENA_SOURCE_DOOR_X := -0.0185
const ARENA_SOURCE_DOOR_Z := 0.385
static var _arena_mesh: ArrayMesh

static func arena_footprint(b: Dictionary) -> Rect2:
	var w := float(b["w"])
	var d := float(b["d"])
	var dx := float(b["door"].x) + 0.5 - float(b["x"]) - w / 2.0
	var face := d / 2.0 - hut_face_inset(b)
	return Rect2(dx + (-0.516 - ARENA_SOURCE_DOOR_X) * ARENA_SCALE, face + (-0.516 - ARENA_SOURCE_DOOR_Z) * ARENA_SCALE, 1.032 * ARENA_SCALE, 1.038 * ARENA_SCALE)

static func _arena_fitted() -> ArrayMesh:
	if _arena_mesh != null:
		return _arena_mesh
	var source: ArrayMesh = load("res://assets/exteriors/kelpwick_arena.res")
	_arena_mesh = ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var p := vertices[i]
			var y_scale := ARENA_SCALE
			var y := 1.84 + (p.y + 0.044) * y_scale
			if p.y < -0.174:
				y_scale = HUT_LIFT / 0.066
				y = (p.y + 0.24) * y_scale - HUT_LIFT
			elif p.y < -0.044:
				y_scale = 1.84 / 0.130
				y = (p.y + 0.174) * y_scale
			var x := (p.x - ARENA_SOURCE_DOOR_X) * ARENA_SCALE
			var z := (p.z - ARENA_SOURCE_DOOR_Z) * ARENA_SCALE
			var ax := absf(p.x - ARENA_SOURCE_DOOR_X)
			if p.z > 0.30 and ax < 0.20:
				var fitted := ax / 0.068 * 0.46 if ax <= 0.068 else lerpf(0.46, 0.20 * ARENA_SCALE, (ax - 0.068) / 0.132)
				x = lerpf(x, signf(x) * fitted, smoothstep(0.30, 0.37, p.z))
				if p.y <= -0.174 and p.z > ARENA_SOURCE_DOOR_Z:
					z = minf(z, 0.25)
			vertices[i] = Vector3(x, y, z)
			normals[i] = Vector3(normals[i].x / ARENA_SCALE, normals[i].y / y_scale, normals[i].z / ARENA_SCALE).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		_arena_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_arena_mesh.surface_set_material(surface, source.surface_get_material(surface))
	return _arena_mesh

static func _arena(node: Node3D, k: VB.Kit, b: Dictionary, dx: float, face: float) -> float:
	var mi := MeshInstance3D.new()
	mi.name = "SuppliedArena"
	mi.mesh = _arena_fitted()
	mi.position = Vector3(dx, HUT_LIFT, face)
	node.add_child(mi)
	b["door_sill"] = HUT_LIFT
	var center := Vector2(dx - ARENA_SOURCE_DOOR_X * ARENA_SCALE, face - ARENA_SOURCE_DOOR_Z * ARENA_SCALE)
	# A concealed ceiling closes the room below the model's open-air roof terrace.
	var inner := VB._loop(center, 0.30 * ARENA_SCALE, 0.30 * ARENA_SCALE, 32)
	VB._skirt(k, "color", inner, HUT_LIFT, 2.38, Color("#dfbd8d"), center)
	VB._band(k, "planks", inner, VB._fill(center, 32), HUT_LIFT + 2.38, HUT_TIMBER)
	_hut_entry(node, k, b, dx, face, Color("#dfbd8d"), false)
	_hut_garden(node, dx, face, ARENA_SCALE * 0.50)
	return mi.mesh.get_aabb().end.y + HUT_LIFT

static func build(b: Dictionary, style: String) -> Node3D:
	var node := Node3D.new()
	var k := VB.Kit.new()
	var hb := HB.new()
	hb.node = node
	var w := float(b["w"])
	var d := float(b["d"])
	var dx := float(b["door"].x) + 0.5 - float(b["x"]) - w / 2.0
	var shop := String(b["shop"])
	var wood := style == "roundwood"
	var great := wood and shop == "arena"
	var face := d / 2.0 - (hut_face_inset(b) if wood else 0.16)
	var top: float
	if great:
		top = _arena(node, k, b, dx, face)
	elif wood:
		top = _stilt_hut(node, k, b, dx, face)
	else:
		var wall := _stucco(int(b["seed"]))
		if shop == "center":
			# The Beast Center is a temple of pale stone among the pastel villas (voxel_buildings.gd's shrine pieces).
			wall.albedo_color = VB.SHRINE_STONE
		top = _hotel(node, b, w, d, dx, wall) if b.get("hotel", false) else _villa(k, hb, b, w, d, dx, wall)
		if shop == "center":
			# An inner stucco shell seals the enlarged façade's wall-section corner joins.
			k.box("color", Vector3(0, top / 2.0, 0), Vector3(w - 0.42, top, d - 0.42), (wall as StandardMaterial3D).albedo_color, true)
			# Its temple front stands round the mission arch: columns, a lintel and the stepped pediment with the
			# pawprint, where a shop would hang its awning and sign. A crystal stands on the roof's ridge.
			VB.shrine_front(k, dx, 0.0, d / 2.0 - HB.INSET, 2.74, top, VB.SHRINE_STONE, 1.0)
			var ridge := top + 0.04 + ((d - 0.12) / 2.0 + 0.08) * 0.36
			k.box("plaster", Vector3(0, ridge + 0.12, 0), Vector3(0.34, 0.3, 0.34), VB.SHRINE_STONE)
			VB.shrine_crystal(k, Vector3(0, ridge + 0.27 + 0.3, 0), 0.2, 0.74)
		if shop in ["apothecary", "cafe"]:
			var brand := Color("#439d93") if shop == "apothecary" else Color("#bd757b")
			for stripe in 8:
				k.box("color", Vector3(dx - 1.4 + float(stripe) * 0.4, 2.7, face + 0.1), Vector3(0.4, 0.12, 0.65), brand if stripe % 2 == 0 else Color("#fff3dc"))
	hb.finish()
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	if wood:
		var surface_index := 0
		for kind in k.surf:
			if kind == "planks":
				mi.set_surface_override_material(surface_index, timber_material())
			surface_index += 1
	node.add_child(mi)
	b["height"] = top if wood else top + 1.8
	# (a resort Beast Center's sign is the pawprint carved on its pediment)
	if shop != "house" and not (shop == "center" and not wood):
		var plaque := MeshInstance3D.new()
		plaque.mesh = VP.icon(shop)
		# The arena sign follows its roof lip as the supplied model grows.
		var sign_z := face + (ARENA_SCALE * 0.07 if great else (0.46 if wood else 0.12))
		plaque.position = Vector3(dx, HUT_LIFT + (2.32 if great else 2.25) if wood else 3.5, sign_z)
		plaque.scale = Vector3.ONE * (0.75 if great else (0.975 if wood else 0.65))
		node.add_child(plaque)
	return node

static func _stucco(seed_value: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(PASTELS[absi(seed_value) % PASTELS.size()])
	m.roughness = 0.95
	return m


# ---------------------------------------------------------------- Shellhaven's Spanish resort
const TRIM := Color("#fff3df")
const IRON := Color("#2d2622")
const GLASS := Color("#30475a")
## the round head of a window catches the sky
const FANLIGHT := Color("#7598b2")
const SASH := Color("#5d4130")
const TERRACOTTA := Color("#c0704f")
## shutter paints: sea greens and blues, an olive and a weathered red
const PAINTS := ["#3f8079", "#356b93", "#5f8b4c", "#2f6a6a", "#8a5236"]
const BLOOMS := ["#d8417f", "#ef6f9d", "#e2523f", "#c93a6a"]
const LEAF := Color("#4c9a45")
const STOREY := 2.8
## The hotel's arcade and balconies are set this deep into its plot, so nothing hangs over the street.
const LOGGIA := 1.0
const ARCH_SPRING := 1.7
## the hotel's three-storey entrance block, at the east end of its long plot
const HOTEL_ENTRY_W := 7.0
## how far the hotel's west wing stands back from the entrance block's front, behind its terrace
const HOTEL_WING_SETBACK := 1.0
## Palms along the beach below the cliff, as columns east of the western sea (clear of both ramps).
const CLIFF_PALMS := [7, 15, 21, 33, 39]


## A box on a wall running along `t` (x or z): `along` long, `h` high and `depth` out from the wall.
static func _wbox(k: VB.Kit, mat: String, c: Vector3, t: Vector3, along: float, h: float, depth: float, col: Color) -> void:
	k.box(mat, c, Vector3(along, h, depth) if absf(t.x) > 0.5 else Vector3(depth, h, along), col)


## Points round a half circle over `c` on a wall along `t`, from its left end over the top to its right end.
static func _arc(c: Vector3, t: Vector3, r: float, segs := 10) -> Array:
	var pts := []
	for i in segs + 1:
		var a := PI - PI * float(i) / float(segs)
		pts.append(c + t * cos(a) * r + Vector3.UP * sin(a) * r)
	return pts


## An arched opening's outline: up the left side from `p` (the middle of its foot), over the round head and down.
static func _outline(p: Vector3, t: Vector3, w: float, spring: float) -> Array:
	return [p - t * w / 2.0] + _arc(p + Vector3.UP * spring, t, w / 2.0) + [p + t * w / 2.0]


static func _trace(k: VB.Kit, mat: String, pts: Array, thick: float, col: Color) -> void:
	for i in pts.size() - 1:
		VB._beam(k, mat, pts[i], pts[i + 1], thick, col)


## A flat arched panel facing `n`: the rectangle up to the spring, then the round head (in `head`, if it's given).
static func _arch_fill(k: VB.Kit, mat: String, p: Vector3, t: Vector3, n: Vector3, w: float, spring: float, col: Color, head := Color(0, 0, 0, 0)) -> void:
	var up := Vector3.UP
	var r := w / 2.0
	k.poly(mat, [p - t * r, p + t * r, p + t * r + up * spring, p - t * r + up * spring], n, col)
	var c := p + up * spring
	var arc := _arc(c, t, r)
	for i in arc.size() - 1:
		k.poly(mat, [c, arc[i], arc[i + 1]], n, head if head.a > 0.0 else col)


## How far each of the openings at `xs` along a wall can spread before reaching a neighbour or a `stop` (the wall's
## ends, the door's jambs).
static func _room(xs: Array, stops: Array) -> Array:
	var out := []
	for i in xs.size():
		var r := 9.0
		for j in xs.size():
			if j != i:
				r = minf(r, absf(float(xs[i]) - float(xs[j])) / 2.0)
		for s in stops:
			r = minf(r, absf(float(xs[i]) - float(s)))
		out.append(r)
	return out


## A Spanish window or French door on a wall: `p` the middle of its foot on the wall's face, `t` along the wall, `n` out
## of it, `w` wide and `h` tall to the top of its round head. Glass behind dark glazing bars, a white surround with a
## keystone and a sill, then (by `kind`) an iron grille ("reja") or an iron railing with geraniums ("juliet"). Louvred
## shutters fold back against the wall when there's `room` for them either side.
static func _window(k: VB.Kit, p: Vector3, t: Vector3, n: Vector3, w: float, h: float, kind: String, paint: Color, room: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var r := w / 2.0
	var spring := h - r
	_arch_fill(k, "color", p + n * 0.012, t, n, w, spring, GLASS, FANLIGHT)
	var g := p + n * 0.03
	VB._beam(k, "color", g, g + up * (h - 0.02), 0.04, SASH)
	VB._beam(k, "color", g - t * r + up * spring, g + t * r + up * spring, 0.05, SASH)
	if spring > 1.1:
		VB._beam(k, "color", g - t * r + up * spring * 0.5, g + t * r + up * spring * 0.5, 0.035, SASH)
	_trace(k, "plaster", _outline(p + n * 0.05, t, w + 0.14, spring), 0.12, TRIM)
	_wbox(k, "plaster", p + n * 0.07 + up * (h + 0.06), t, 0.15, 0.2, 0.1, TRIM)
	if kind != "juliet":
		# (the sill is let a hair into the wall, so its back never lies exactly in the wall's face)
		_wbox(k, "plaster", p + n * 0.065 - up * 0.04, t, w + 0.3, 0.08, 0.15, TRIM)
	var leaf := minf(r * 0.9, room - r - 0.16)
	if leaf >= 0.17:
		_shutters(k, p, t, n, r, leaf, spring + r * 0.4, paint)
	match kind:
		"reja":
			_reja(k, p, t, n, w, spring, rng)
		"juliet":
			_juliet(k, p, t, n, w, rng)


## Louvred shutters `sw` wide and `hs` tall, open flat against the wall either side of an opening of half-width `r`.
static func _shutters(k: VB.Kit, p: Vector3, t: Vector3, n: Vector3, r: float, sw: float, hs: float, paint: Color) -> void:
	var up := Vector3.UP
	for s in [-1.0, 1.0]:
		var c: Vector3 = p + t * s * (r + 0.14 + sw / 2.0) + n * 0.035
		_wbox(k, "color", c + up * hs / 2.0, t, sw, hs, 0.05, paint)
		var y := 0.12
		while y < hs - 0.08:
			_wbox(k, "color", c + n * 0.03 + up * y, t, sw - 0.07, 0.03, 0.02, paint.darkened(0.28))
			y += 0.14


## A wrought-iron grille standing just proud of a ground-floor window, its bars curving over the arch, with a pot of
## geraniums on the sill behind it now and then.
static func _reja(k: VB.Kit, p: Vector3, t: Vector3, n: Vector3, w: float, spring: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var f := p + n * 0.12
	var r := w / 2.0 + 0.04
	var top := spring + 0.1
	var bars := maxi(4, int(round(w / 0.12)))
	for i in bars + 1:
		var o := -r + 2.0 * r * float(i) / float(bars)
		VB._beam(k, "color", f + t * o - up * 0.06, f + t * o + up * top, 0.028, IRON)
	for y in [0.0, spring * 0.5, top]:
		VB._beam(k, "color", f - t * r + up * y, f + t * r + up * y, 0.04, IRON)
	_trace(k, "color", _arc(f + up * top, t, r, 8), 0.035, IRON)
	for s in [-1.0, 1.0]:
		for y in [0.0, top]:
			VB._beam(k, "color", f + t * s * r + up * y, f + t * s * r + up * y - n * 0.11, 0.03, IRON)
	if rng.randf() < 0.6:
		_flowers(k, p + n * 0.06 + up * 0.02, t, w * 0.6, rng)


## A French door's balcony rail: a shallow ledge, an iron railing across the bottom of the opening, and usually a
## planter of geraniums behind it. It stays within the wall's own plot.
static func _juliet(k: VB.Kit, p: Vector3, t: Vector3, n: Vector3, w: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var f := p + n * 0.1
	var half := w / 2.0 + 0.16
	_wbox(k, "plaster", p + n * 0.055 - up * 0.02, t, w + 0.42, 0.1, 0.11, TRIM)
	VB._beam(k, "color", f - t * half + up * 0.92, f + t * half + up * 0.92, 0.045, IRON)
	VB._beam(k, "color", f - t * half + up * 0.12, f + t * half + up * 0.12, 0.035, IRON)
	for i in 11:
		var o := -half + 2.0 * half * float(i) / 10.0
		VB._beam(k, "color", f + t * o + up * 0.04, f + t * o + up * 0.92, 0.025, IRON)
	for s in [-1.0, 1.0]:
		VB._beam(k, "color", f + t * s * half + up * 0.92, p + t * s * half + up * 0.92, 0.035, IRON)
	if rng.randf() < 0.75:
		_flowers(k, p + n * 0.05 + up * 0.03, t, w * 0.8, rng)


## A terracotta planter `length` long (along `t`) full of geraniums.
static func _flowers(k: VB.Kit, c: Vector3, t: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	_wbox(k, "color", c + up * 0.09, t, length, 0.18, 0.09, TERRACOTTA)
	var count := maxi(2, int(length / 0.11))
	for i in count:
		var o := -length / 2.0 + length * (float(i) + 0.5) / float(count)
		var at := c + t * o + up * (0.2 + rng.randf() * 0.05)
		k.box("color", at, Vector3.ONE * 0.12, LEAF.darkened(rng.randf() * 0.15))
		if i % 2 == 0 or rng.randf() < 0.4:
			k.box("color", at + up * 0.06 + t * rng.randf_range(-0.03, 0.03), Vector3.ONE * 0.075, Color(BLOOMS[rng.randi_range(0, BLOOMS.size() - 1)]))


## A terracotta pot with a leafy plant, on a balcony floor at `p`.
static func _pot(k: VB.Kit, p: Vector3, rng: RandomNumberGenerator) -> void:
	VB._column(k, "color", p, 0.13, 0.3, 8, TERRACOTTA)
	for i in 4:
		var at := p + Vector3(rng.randf_range(-0.1, 0.1), 0.42 + rng.randf() * 0.2, rng.randf_range(-0.1, 0.1))
		k.box("color", at, Vector3.ONE * rng.randf_range(0.16, 0.24), LEAF.darkened(rng.randf() * 0.2))


## An iron lantern on a bracket, its lamp lit: `p` where the bracket meets the wall, `n` out of it.
static func _lantern(k: VB.Kit, p: Vector3, n: Vector3) -> void:
	var up := Vector3.UP
	var l := p + n * 0.16
	VB._beam(k, "color", p + up * 0.1, l + up * 0.1, 0.035, IRON)
	VB._beam(k, "color", p - up * 0.12, l + up * 0.08, 0.03, IRON)
	k.box("color", l + up * 0.05, Vector3(0.17, 0.05, 0.17), IRON)
	k.box("glow", l - up * 0.08, Vector3(0.12, 0.22, 0.12), Color("#ffd98a"))
	k.box("color", l - up * 0.21, Vector3(0.14, 0.04, 0.14), IRON)


## Bougainvillea climbing a wall from the ground at `p` to just under the eaves at `top`, then running along them
## towards `dir`, its leaves full of magenta bracts.
static func _bougainvillea(k: VB.Kit, p: Vector3, t: Vector3, n: Vector3, top: float, dir: float, rng: RandomNumberGenerator) -> void:
	var up := Vector3.UP
	var stem := p + n * 0.04
	var prev := stem
	var y := 0.0
	var o := 0.0
	while y < top - 0.35:
		y = minf(y + 0.45, top - 0.35)
		o = clampf(o + rng.randf_range(-0.2, 0.2), -0.22, 0.22)
		var q := stem + t * o + up * y
		VB._beam(k, "color", prev, q, 0.05, Color("#6b4a2e"))
		prev = q
	var end := prev + t * dir * rng.randf_range(1.0, 1.5)
	VB._beam(k, "color", prev, end, 0.04, Color("#6b4a2e"))
	for i in 38:
		var c: Vector3
		if i < 20:
			c = stem + t * rng.randf_range(-0.28, 0.28) + up * lerpf(0.5, top - 0.3, sqrt(rng.randf()))
		else:
			c = prev.lerp(end, rng.randf()) + up * rng.randf_range(-0.4, 0.08)
		c += n * rng.randf_range(0.06, 0.15)
		k.box("color", c, Vector3.ONE * rng.randf_range(0.16, 0.26), LEAF.darkened(rng.randf() * 0.2))
		var jitter := Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.04, 0.08), rng.randf_range(-0.07, 0.07))
		k.box("color", c + n * 0.06 + jitter, Vector3.ONE * rng.randf_range(0.11, 0.17), Color(BLOOMS[rng.randi_range(0, BLOOMS.size() - 1)]))


## The mission arch round a front door on a wall face at `z`: white pilasters and a round head.
static func _door_arch(k: VB.Kit, dx: float, z: float) -> void:
	for side in [-1.0, 1.0]:
		k.box("plaster", Vector3(dx + side * 0.71, 1.075, z + 0.06), Vector3(0.15, 2.15, 0.12), TRIM)
	for i in 16:
		var a := PI * float(i) / 16.0
		var c := PI * float(i + 1) / 16.0
		VB._beam(k, "plaster", Vector3(dx + cos(a) * 0.71, 2.15 + sin(a) * 0.5, z + 0.06), Vector3(dx + cos(c) * 0.71, 2.15 + sin(c) * 0.5, z + 0.06), 0.15, TRIM)


## An arch across the front between two piers (x `a` to `e`) on the plane `z`: the wall over it up to `ytop`, its
## soffit running `deep` back, and a white archivolt.
static func _arch_span(k: VB.Kit, a: float, e: float, y0: float, spring: float, ytop: float, z: float, deep: float, col: Color) -> void:
	var r := (e - a) / 2.0
	var c := Vector3((a + e) / 2.0, y0 + spring, z)
	var arc := _arc(c, Vector3.RIGHT, r, 12)
	for i in arc.size() - 1:
		var p0: Vector3 = arc[i]
		var p1: Vector3 = arc[i + 1]
		k.poly("color", [p0, p1, Vector3(p1.x, ytop, z), Vector3(p0.x, ytop, z)], Vector3.BACK, col)
		var inward := -((p0 + p1) / 2.0 - c).normalized()
		k.poly("plaster", [p0, p1, p1 - Vector3(0, 0, deep), p0 - Vector3(0, 0, deep)], inward, TRIM.darkened(0.1))
	_trace(k, "plaster", _arc(c + Vector3(0, 0, 0.03), Vector3.RIGHT, r + 0.05, 12), 0.1, TRIM)


## An iron balcony railing along x from `a` to `e`, `z` deep, on a floor at `y`.
static func _rail(k: VB.Kit, a: float, e: float, y: float, z: float) -> void:
	_rail_between(k, Vector3(a, y, z), Vector3(e, y, z))


## An iron railing in a straight line between two points on a floor.
static func _rail_between(k: VB.Kit, from: Vector3, to: Vector3) -> void:
	VB._beam(k, "color", from + Vector3.UP * 0.95, to + Vector3.UP * 0.95, 0.05, IRON)
	VB._beam(k, "color", from + Vector3.UP * 0.12, to + Vector3.UP * 0.12, 0.035, IRON)
	var count := maxi(2, int(round(from.distance_to(to) / 0.1)))
	for i in range(1, count):
		var at := from.lerp(to, float(i) / float(count))
		VB._beam(k, "color", at + Vector3.UP * 0.02, at + Vector3.UP * 0.95, 0.025, IRON)


## Two storeys of pastel stucco: round-arched windows behind iron rejas below (wide shop windows on the shops), French
## doors on railed Juliet balconies above, louvred shutters, a painted base, a string course and a cornice, the mission
## arch round the door, a lantern by it and bougainvillea up a corner. Returns the height of its walls.
static func _villa(k: VB.Kit, hb: HB, b: Dictionary, w: float, d: float, dx: float, wall: Material) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["seed"])
	var house := String(b["shop"]) == "house"
	var colour: Color = (wall as StandardMaterial3D).albedo_color
	var paint := Color(PAINTS[rng.randi_range(0, PAINTS.size() - 1)])
	var top := 2.0 * STOREY
	hb.w = w
	hb.d = d
	for level in 2:
		hb.storey(float(level) * STOREY, wall, ("door_1" if b.get("locked", false) else "door_3") if level == 0 else "", dx, {}, false, false)
	var zf := d / 2.0 - HB.INSET
	var edge := w / 2.0 - HB.INSET
	var t := Vector3.RIGHT
	var front := Vector3.BACK
	var below := []
	for span in [[-edge + 0.25, dx - 0.85], [dx + 0.85, edge - 0.25]]:
		var length: float = span[1] - span[0]
		var count := int((length + 0.25) / 1.3)
		for i in count:
			below.append(span[0] + length * (float(i) + 0.5) / float(count))
	var room := _room(below, [-edge, edge, dx - 0.8, dx + 0.8])
	for i in below.size():
		if house:
			_window(k, Vector3(below[i], 0.62, zf), t, front, 0.72, 1.55, "reja", paint, room[i], rng)
		else:
			_window(k, Vector3(below[i], 0.45, zf), t, front, 0.95, 1.85, "", paint, room[i], rng)
	# a shop's sign hangs over its door, so only a house has a balcony there
	var above := below.duplicate()
	if house:
		above.append(dx)
	room = _room(above, [-edge, edge])
	for i in above.size():
		_window(k, Vector3(above[i], STOREY + 0.06, zf), t, front, 0.74, 2.05, "juliet", paint, room[i], rng)
	_door_arch(k, dx, zf - 0.06)
	# a window in the middle of each side on both floors
	for sx in [-1.0, 1.0]:
		var n := Vector3(sx, 0, 0)
		for level in 2:
			_window(k, Vector3(sx * edge, float(level) * STOREY + 0.62, 0.0), Vector3.BACK, n, 0.72, 1.5, "reja" if house and level == 0 else "", paint, d / 2.0 - 0.2, rng)
	# the painted base, a string course between the floors and a cornice under the eaves
	var base := colour.darkened(0.22)
	for span in [[-edge, dx - 0.8], [dx + 0.8, edge]]:
		var length: float = span[1] - span[0]
		if length > 0.05:
			k.box("color", Vector3((span[0] + span[1]) / 2.0, 0.22, zf + 0.012), Vector3(length, 0.44, 0.04), base)
	k.box("plaster", Vector3(0, STOREY - 0.02, zf + 0.02), Vector3(w - 0.16, 0.1, 0.08), TRIM)
	k.box("plaster", Vector3(0, top - 0.08, zf + 0.02), Vector3(w - 0.16, 0.16, 0.08), TRIM)
	for sx in [-1.0, 1.0]:
		k.box("color", Vector3(sx * (edge + 0.012), 0.22, 0.0), Vector3(0.04, 0.44, d - 0.24), base)
		k.box("plaster", Vector3(sx * (edge + 0.02), top - 0.08, 0.0), Vector3(0.08, 0.16, d - 0.2), TRIM)
	VB._hip(k, w - 0.12, d - 0.12, top, 0.36, 0.08, false, "tiles", TERRACOTTA, Color("#f8edda"))
	# a lantern on the side of the door with no window, and bougainvillea up the corner beyond it
	for s in [1.0, -1.0]:
		var lx: float = dx + s * 0.98
		if absf(lx) < edge - 0.15 and below.all(func(x): return absf(float(x) - lx) > 1.3):
			_lantern(k, Vector3(lx, 2.0, zf), front)
			break
	if house or String(b["shop"]) == "cafe":
		var corner := 1.0 if dx <= 0.0 else -1.0
		_bougainvillea(k, Vector3(corner * (edge - 0.3), 0.0, zf), t, front, top, -corner, rng)
	return top


## Hotel Mariposa, a long resort hotel on the quay behind the marina: a three-storey entrance block at its east end, on
## the forecourt, with a tiled HOTEL sign over its middle arch and the mission bell gable on its roof, and a two-storey
## west wing running on behind the docks, set back behind a railed terrace. Returns the entrance block's wall height.
static func _hotel(node: Node3D, b: Dictionary, w: float, d: float, dx: float, wall: Material) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["seed"])
	var paint := Color(PAINTS[rng.randi_range(0, PAINTS.size() - 1)])
	var east := w / 2.0
	var entry_w := minf(w, HOTEL_ENTRY_W)
	var ex := clampf(dx, -east + entry_w / 2.0, east - entry_w / 2.0)
	# the wing runs a little way in under the entrance block, so no gap opens between them
	var wing_w := ex - entry_w / 2.0 + east + 0.3
	var top := _hotel_block(node, ex, entry_w, d, 3, true, 2 if wing_w > 1.0 else 0, wall, paint, rng)
	if wing_w > 1.0:
		_hotel_block(node, -east + wing_w / 2.0, wing_w, d, 2, false, 0, wall, paint, rng)
	return top


## One block of the hotel, `w` wide and `levels` storeys, centred at `cx`: an arcade along the ground floor (the wing's
## opens onto a railed terrace at the plot's front, above the water), and above it a balcony for every room, set back into the plot
## between the piers behind iron railings, with arches again along the top floor under the eaves. `west_cover` storeys
## of its west side are hidden by the wing, so their windows are left out. Returns its wall height.
static func _hotel_block(node: Node3D, cx: float, w: float, plot_d: float, levels: int, entry: bool, west_cover: int, wall: Material, paint: Color, rng: RandomNumberGenerator) -> float:
	# the wing's back wall stays put and its front comes in, leaving its terrace on the plot's front tiles
	var setback := 0.0 if entry else HOTEL_WING_SETBACK
	var d := plot_d - setback
	var block := Node3D.new()
	block.position = Vector3(cx, 0.0, -setback / 2.0)
	node.add_child(block)
	var k := VB.Kit.new()
	var hb := HB.new()
	# the rooms stand back behind the arcade and balconies
	var body := Node3D.new()
	body.position.z = -LOGGIA / 2.0
	block.add_child(body)
	hb.node = body
	hb.w = w
	hb.d = d - LOGGIA
	var top := float(levels) * STOREY
	for level in levels:
		hb.storey(float(level) * STOREY, wall, "door_3" if entry and level == 0 else "", 0.0, {}, false, false)
	var colour: Color = (wall as StandardMaterial3D).albedo_color
	var zr := d / 2.0 - LOGGIA - HB.INSET
	var zf := d / 2.0 - 0.05
	var deep := zf - zr
	var cz := (zr + zf) / 2.0
	var t := Vector3.RIGHT
	var front := Vector3.BACK
	var bays := maxi(1, int(round((w - 0.16) / 1.38)))
	if entry and bays % 2 == 0:
		bays += 1
	var x0 := -w / 2.0 + 0.08
	var bw := (w - 0.16) / float(bays)
	# (the kit's faces are shaded a touch darker than the walls' own material)
	var face := colour.lightened(0.06)
	k.box("stone", Vector3(0, 0.03, cz), Vector3(w - 0.16, 0.06, deep), Color("#c98a64"))
	if setback > 0.0:
		# the arcade's paving carried out to an iron railing along the front and round the west end
		var rail_z := zf + setback - 0.1
		var west := -w / 2.0 + 0.2
		k.box("stone", Vector3(0, 0.03, zf + setback / 2.0), Vector3(w - 0.16, 0.06, setback), Color("#c98a64"))
		_rail_between(k, Vector3(west, 0.0, rail_z), Vector3(w / 2.0 - 0.2, 0.0, rail_z))
		_rail_between(k, Vector3(west, 0.0, zf), Vector3(west, 0.0, rail_z))
	for level in levels:
		var y0 := float(level) * STOREY
		var last := level == levels - 1
		# piers: square at the corners and between the balconies, round columns along the arcade
		for j in bays + 1:
			var corner := j == 0 or j == bays
			var px := x0 + bw * float(j) + (0.15 if j == 0 else (-0.15 if j == bays else 0.0))
			if level == 0 and not corner:
				k.box("plaster", Vector3(px, 0.08, zf - 0.15), Vector3(0.3, 0.16, 0.3), TRIM)
				VB._column(k, "plaster", Vector3(px, 0.16, zf - 0.15), 0.11, ARCH_SPRING - 0.3, 10, TRIM)
				k.box("plaster", Vector3(px, ARCH_SPRING - 0.07, zf - 0.15), Vector3(0.3, 0.14, 0.3), TRIM)
				k.box("color", Vector3(px, (ARCH_SPRING + STOREY) / 2.0, zf - 0.15), Vector3(0.24, STOREY - ARCH_SPRING, 0.3), face)
			else:
				k.box("color", Vector3(px, y0 + STOREY / 2.0, cz), Vector3(0.3 if corner else 0.24, STOREY, deep), face)
		# arches on the ground floor and along the top; a plain lintel over the balconies between
		for i in bays:
			var a := x0 + bw * float(i) + (0.3 if i == 0 else 0.12)
			var e := x0 + bw * float(i + 1) - (0.3 if i == bays - 1 else 0.12)
			if level == 0 or last:
				_arch_span(k, a, e, y0, ARCH_SPRING if level == 0 else 1.85, y0 + STOREY, zf, 0.3, face)
			else:
				k.box("color", Vector3((a + e) / 2.0, y0 + 2.6, zf - 0.15), Vector3(e - a, 0.4, 0.3), face)
			var mid := (a + e) / 2.0
			if level == 0:
				if not entry or i != bays / 2:
					_window(k, Vector3(mid, 0.6, zr), t, front, 0.7, 1.45, "reja", paint, 0.0, rng)
				# a lantern hanging in each bay of the arcade
				VB._beam(k, "color", Vector3(mid, STOREY - 0.2, cz), Vector3(mid, 2.4, cz), 0.02, IRON)
				k.box("color", Vector3(mid, 2.4, cz), Vector3(0.18, 0.05, 0.18), IRON)
				k.box("glow", Vector3(mid, 2.27, cz), Vector3(0.13, 0.22, 0.13), Color("#ffd98a"))
			else:
				# each room's French doors open onto its balcony
				_window(k, Vector3(mid, y0 + 0.02, zr), t, front, 0.74, 2.1, "", paint, 0.0, rng)
				_rail(k, a, e, y0, zf - 0.1)
				if rng.randf() < 0.6:
					_pot(k, Vector3(mid + (0.4 if rng.randf() < 0.5 else -0.4), y0, zr + 0.25), rng)
		# the balcony floor above (the ceiling here) and a white band along its edge
		if not last:
			k.box("plaster", Vector3(0, y0 + STOREY - 0.1, cz - 0.01), Vector3(w - 0.16, 0.2, deep - 0.02), TRIM, true)
			k.box("plaster", Vector3(0, y0 + STOREY, zf + 0.03), Vector3(w, 0.12, 0.08), TRIM)
		# a window in each side the wing doesn't cover (the wing's east end is inside the entrance block)
		for sx in [-1.0, 1.0]:
			if (sx < 0.0 and level < west_cover) or (sx > 0.0 and not entry):
				continue
			var edge := w / 2.0 - HB.INSET
			_window(k, Vector3(sx * edge, y0 + 0.62, -LOGGIA / 2.0), Vector3.BACK, Vector3(sx, 0, 0), 0.72, 1.5, "reja" if level == 0 else "", paint, (d - LOGGIA) / 2.0 - 0.2, rng)
	k.box("plaster", Vector3(0, top - 0.08, zf + 0.02), Vector3(w, 0.16, 0.1), TRIM)
	VB._hip(k, w - 0.12, d - 0.12, top, 0.36, 0.08, false, "tiles", TERRACOTTA, Color("#f8edda"))
	if entry:
		_door_arch(k, 0.0, zr - 0.06)
		# HOTEL in blue on white tiles, over the middle arch
		k.box("plaster", Vector3(0, 2.58, zf + 0.03), Vector3(1.04, 0.34, 0.04), Color("#fbf6ec"))
		for y in [2.42, 2.74]:
			k.box("color", Vector3(0, y, zf + 0.05), Vector3(1.08, 0.04, 0.03), Color("#2f5f9e"))
		for sx in [-1.0, 1.0]:
			k.box("color", Vector3(sx * 0.52, 2.58, zf + 0.05), Vector3(0.04, 0.36, 0.03), Color("#2f5f9e"))
		var title := Label3D.new()
		load("res://scripts/gfx/world_lettering.gd").apply(title, "HOTEL")
		title.font_size = 48
		title.pixel_size = 0.0055
		title.outline_size = 0
		title.position = Vector3(0, 2.58, zf + 0.06)
		title.modulate = Color("#24508f")
		block.add_child(title)
		# the mission bell gable on the roof
		k.box("plaster", Vector3(0, top + 0.08, 0), Vector3(1.7, 0.38, 0.28), Color("#f8e6c8"))
		for side in [-1.0, 1.0]:
			k.box("plaster", Vector3(side * 0.57, top + 0.8, 0), Vector3(0.22, 1.4, 0.4), Color("#f8e6c8"))
		k.box("plaster", Vector3(0, top + 1.5, 0), Vector3(1.36, 0.23, 0.46), Color("#f8e6c8"))
		VB._column(k, "metal", Vector3(0, top + 0.75, 0), 0.22, 0.4, 12, Color("#d5ad54"))
	hb.finish()
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	block.add_child(mi)
	return top


## Beach furniture has real occupied tiles. Open aisles connect both ramps and the ferry. Striped umbrellas stand in
## the sand over occupied chaises, with towels laid out between them, and palms stand well apart along the foot of the
## cliff.
static func beach(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in 6:
		var x := 15 + WORLD.SHELLHAVEN_WEST_PADDING + i * 4
		var z := 19
		for occupied in [Vector2i(x, z), Vector2i(x - 1, z), Vector2i(x - 1, z + 1)]:
			MG.set_t(world.map, occupied.x, occupied.y, MG.STREET_PROP)
		var k := VB.Kit.new()
		var color := Color(PASTELS[i % PASTELS.size()])
		# The pole stands in the sand and runs right up to the canopy's peak, where a finial caps it.
		var centre := Vector2(x + 0.5, z + 0.5)
		var crown := 2.25
		var rim := crown - 0.42
		VB._column(k, "planks", Vector3(centre.x, -0.06, centre.y), 0.04, crown + 0.06, 8, Color("#b18b5d"))
		VB._column(k, "planks", Vector3(centre.x, crown - 0.02, centre.y), 0.065, 0.11, 8, Color("#8a6640"))
		var ring := VB._loop(centre, 1.05, 1.05, 16)
		var tip := Vector3(centre.x, crown, centre.y)
		for j in ring.size():
			var a: Vector2 = ring[j]
			var e: Vector2 = ring[(j + 1) % ring.size()]
			VB._slope(k, "plaster", [Vector3(a.x, rim, a.y), Vector3(e.x, rim, e.y), tip], color if j % 2 == 0 else Color("#fbf4e6"), Vector3(e.x - a.x, 0, e.y - a.y))
		VB._band(k, "plaster", ring, VB._fill(centre, ring.size()), rim, color.darkened(0.3), false)
		VB._skirt(k, "plaster", ring, rim - 0.1, 0.1, color.darkened(0.06), centre)
		# ribs from a runner on the pole out to the rim
		for j in range(0, ring.size(), 2):
			var a: Vector2 = ring[j]
			VB._beam(k, "planks", Vector3(centre.x, rim - 0.3, centre.y), Vector3(a.x, rim - 0.01, a.y), 0.025, Color("#8a6640"))
		# Low chaise, sloping back, and legs. Its two-tile footprint stays off the promenade.
		var chair_x := x - 1.0
		k.box("planks", Vector3(chair_x, 0.27, z + 0.7), Vector3(0.7, 0.1, 1.4), Color("#faf1dd"))
		VB._beam(k, "planks", Vector3(chair_x, 0.28, z + 0.05), Vector3(chair_x, 0.7, z - 0.5), 0.58, color)
		for end in [-0.45, 0.45]:
			k.box("planks", Vector3(chair_x, 0.12, z + 0.7 + end), Vector3(0.65, 0.24, 0.08), Color("#b98c63"))
		# a striped towel on the sand beside every other umbrella (flat: people walk across it)
		if i % 2 == 0:
			var towel := Color(PASTELS[(i + 3) % PASTELS.size()]).darkened(0.1)
			for stripe in 5:
				k.box("color", Vector3(x + 1.5, 0.012, z + 0.4 + float(stripe) * 0.3), Vector3(0.72, 0.02, 0.3), towel if stripe % 2 == 0 else Color("#fbf4e6"))
		var mesh := MeshInstance3D.new()
		mesh.mesh = k.mesh()
		world.add_child(mesh)
		# The existing character rig reclines on the chaise, with bare arms/legs and swim trunks.
		var skin: String = ["#e7b58c", "#bd8059", "#8f5f45"][i % 3]
		var person := PERSON.build({"skin": skin, "shirt": skin, "pants": PASTELS[(i + 2) % 5], "shoes": skin, "hair": "#593a27", "body": "male", "hair_style": 0, "model": "tf0", "outfit": "swim"})
		person.rotation.x = -PI / 2.0
		person.position = Vector3(chair_x, 0.42, z + 1.35)
		person.scale = Vector3.ONE * 0.75
		world.add_child(person)
	# Palms along the foot of the cliff, clear of both ramps and the aisles below them; bent ones lean out to sea.
	for j in CLIFF_PALMS.size():
		var tile := Vector2i(WORLD.SHELLHAVEN_WEST_PADDING + int(CLIFF_PALMS[j]), 17)
		MG.set_t(world.map, tile.x, tile.y, MG.STREET_PROP)
		var name := "palm_bent" if j % 2 == 1 else "palm"
		var bent := name == "palm_bent"
		var bb := VA.aabb(name)
		# kept low enough that their crowns don't hide the lawn above the cliff
		var sc := VA.fit_scale(name, rng.randf_range(3.0, 3.4))
		# The bent palm's trunk rises from one side of its model and its crown leans across (measured from the mesh):
		# its foot goes on the tile and the lean is turned out to sea.
		var foot := Vector3(-0.33, 0.0, 0.12) if bent else Vector3.ZERO
		var yaw := -atan2(0.33, -0.14) + rng.randf_range(-0.35, 0.35) if bent else rng.randf() * TAU
		var palm := MeshInstance3D.new()
		palm.mesh = VA.mesh(name)
		palm.scale = Vector3.ONE * sc
		palm.rotation.y = yaw
		palm.position = Vector3(tile.x + 0.5, world._lift(tile) - bb.position.y * sc, tile.y + 0.4) - Basis(Vector3.UP, yaw) * (foot * sc)
		world.add_child(palm)
