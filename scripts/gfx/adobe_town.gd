extends RefCounted
## Sunwall's old walled adobe town (a town map's "town_wall", with "style": "adobe" for its houses and shops: the
## house pack's pueblos and riads, house_models.gd, and voxel_buildings.gd's flat-roofed adobe shops with vigas).
##
## The town wall stands on the map's W tiles (world.gd _build_terrain): thick sun-dried mud walls in a warm sand colour,
## a lighter rounded coping along the top, a row of rounded merlons along its outer edge, and log beam ends (vigas)
## jutting from the town side under the walk. Where a road passes through, square gate towers stand either side, a
## little taller, with a dark slit window; the gateway between them is open to the sky (an arch over it would hide
## whoever walks through). The camera looks north, so the wall is tall only behind and beside the town: from the row
## "low_from" south it is a knee-high parapet with broad gateposts, low enough that nobody on the street beside it is
## hidden (tools/town_check.py).
##
## The street props (world.gd _street_mesh "adobe_*") are the market's: a stall under a striped cloth awning on poles
## with baskets of fruit on its counter, a cluster of clay jars, and a round stone well with a timber frame and bucket.

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const MapGen = preload("res://scripts/world/map_gen.gd")

const MUD := Color("#d9b386")
const COPING := Color("#e8c9a0")
const VIGA := Color("#6e4a2e")
const SLIT := Color("#3a2a22")
const CLAY := Color("#c4703f")
## the wall's height above its tile, the low south parapet's, and how much higher a gate tower rises
const TALL := 3.2
const LOW := 0.45
const TOWER_UP := 1.0

static var _props := {}


## The town wall along every W tile of `map` (with its "town_wall" settings); `lift` gives a tile's ground height.
static func wall(map: Dictionary, lift: Callable) -> Mesh:
	var cfg: Dictionary = map.get("town_wall", {})
	var low_from := int(cfg.get("low_from", map["h"]))
	var k := VBld.Kit.new()
	var w: int = map["w"]
	var h: int = map["h"]
	for y in h:
		for x in w:
			var p := Vector2i(x, y)
			if MapGen.get_t(map, x, y) != MapGen.WALL:
				continue
			var g: float = lift.call(p)
			# down to the lowest ground beside it, so no step or cliff shows a gap under it
			var base := g
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
					base = minf(base, float(lift.call(q)))
			base -= 0.3
			var low := y >= low_from
			var top := g + (LOW if low else TALL)
			var c := Vector3(x + 0.5, 0, y + 0.5)
			# the town side: towards whichever neighbour is open ground (not wall, not off the map)
			var inward := _inward(map, p)
			var gate := _gate_side(map, p)
			if gate != Vector2i.ZERO:
				_tower(k, c, base, top, low, inward)
				continue
			k.box("adobe", Vector3(c.x, (base + top) / 2.0, c.z), Vector3(1.0, top - base, 1.0), MUD)
			# the coping: a lighter rounded cap, a little proud of the wall
			k.box("adobe", Vector3(c.x, top + 0.05, c.z), Vector3(1.04, 0.1, 1.04), COPING)
			var along := _along(map, p)
			if low:
				continue
			# merlons along the outer edge (the side away from town), rounded mud blocks
			var out := -inward
			for i in 2:
				var off := -0.25 + i * 0.5
				var mc := c + Vector3(along.x, 0, along.y) * off + Vector3(out.x, 0, out.y) * 0.32
				k.box("adobe", Vector3(mc.x, top + 0.3, mc.z), Vector3(0.3 if along.x != 0 else 0.32, 0.4, 0.32 if along.x != 0 else 0.3), MUD)
				k.box("adobe", Vector3(mc.x, top + 0.52, mc.z), Vector3(0.24 if along.x != 0 else 0.26, 0.06, 0.26 if along.x != 0 else 0.24), COPING)
			# vigas: two log ends on the town side under the walk
			if inward != Vector2i.ZERO:
				for i in 2:
					var off := -0.25 + i * 0.5
					var vc := c + Vector3(along.x, 0, along.y) * off + Vector3(inward.x, 0, inward.y) * 0.6
					k.box("planks", Vector3(vc.x, top - 0.45, vc.z), Vector3(0.14 if along.x != 0 else 0.22, 0.14, 0.22 if along.x != 0 else 0.14), VIGA)
	return k.mesh()


## Which way the wall runs at p (along x or along z), from its wall neighbours.
static func _along(map: Dictionary, p: Vector2i) -> Vector2i:
	var ew := MapGen.get_t(map, p.x - 1, p.y) == MapGen.WALL or MapGen.get_t(map, p.x + 1, p.y) == MapGen.WALL
	var ns := MapGen.get_t(map, p.x, p.y - 1) == MapGen.WALL or MapGen.get_t(map, p.x, p.y + 1) == MapGen.WALL
	return Vector2i(1, 0) if ew or not ns else Vector2i(0, 1)


## The way into town from wall tile p: the side whose neighbour is walkable (or, at a corner, the first that is).
static func _inward(map: Dictionary, p: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var q: Vector2i = p + d
		if q.x < 0 or q.y < 0 or q.x >= map["w"] or q.y >= map["h"]:
			continue
		var t := MapGen.get_t(map, q.x, q.y)
		if t != MapGen.WALL and t != MapGen.TREE and t != MapGen.ROCK:
			return d
	return Vector2i.ZERO


## A gate tower's side: the direction along the wall's line to the road through it (a path tile in line with the wall
## and wall on its far side of it), or zero if p isn't beside a gate.
static func _gate_side(map: Dictionary, p: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = p + d
		if MapGen.get_t(map, q.x, q.y) == MapGen.PATH and MapGen.get_t(map, p.x - d.x, p.y - d.y) == MapGen.WALL:
			return d
	return Vector2i.ZERO


## A gate tower on p: square, a little wider than the wall, with a slit window on both faces; on the low south wall a
## broad gatepost no higher than the parapet, with a rounded cap.
static func _tower(k: VBld.Kit, c: Vector3, base: float, top: float, low: bool, inward: Vector2i) -> void:
	if low:
		k.box("adobe", Vector3(c.x, (base + top) / 2.0, c.z), Vector3(1.0, top - base, 1.12), MUD.darkened(0.03))
		VBld._column(k, "adobe", Vector3(c.x, top, c.z), 0.42, 0.08, 12, COPING)
		return
	var tt := top + TOWER_UP
	k.box("adobe", Vector3(c.x, (base + tt) / 2.0, c.z), Vector3(1.16, tt - base, 1.16), MUD.darkened(0.03))
	k.box("adobe", Vector3(c.x, tt + 0.06, c.z), Vector3(1.24, 0.12, 1.24), COPING)
	# merlons on the four corners and between them
	for sx in [-1, 0, 1]:
		for sz in [-1, 0, 1]:
			if sx == 0 and sz == 0:
				continue
			k.box("adobe", Vector3(c.x + sx * 0.44, tt + 0.32, c.z + sz * 0.44), Vector3(0.3, 0.42, 0.3), MUD)
	# a slit window on its town face and its outer face
	var faces := [inward, -inward] if inward != Vector2i.ZERO else [Vector2i(0, 1)]
	for f in faces:
		var fc := c + Vector3(f.x, 0, f.y) * 0.585
		k.box("color", Vector3(fc.x, tt - 1.0, fc.z), Vector3(0.14 if f.x == 0 else 0.03, 0.62, 0.03 if f.x == 0 else 0.14), SLIT)
		k.box("adobe", Vector3(fc.x, tt - 1.36, fc.z) + Vector3(f.x, 0, f.y) * 0.03, Vector3(0.36 if f.x == 0 else 0.08, 0.08, 0.08 if f.x == 0 else 0.36), COPING)


# ================================================================ the market's street props
## One of the market's props as a mesh (cached): "adobe_stall", "adobe_jars", "adobe_well". Its origin is its tile's
## centre on the ground; it fits within the tile.
static func prop(name: String) -> Mesh:
	if _props.has(name):
		return _props[name]
	var k := VBld.Kit.new()
	match name:
		"adobe_stall":
			_stall(k)
		"adobe_jars":
			_jars(k)
		"adobe_well":
			_well(k)
		_:
			return null
	_props[name] = k.mesh()
	return _props[name]


## A market stall: a plank counter on mud legs, four poles and a striped cloth awning, baskets of fruit on the counter.
static func _stall(k: VBld.Kit) -> void:
	var wood := Color("#8a5a36")
	var cloth := [Color("#c8483a"), Color("#f2e6cc")]
	k.box("adobe", Vector3(0, 0.38, -0.08), Vector3(0.86, 0.76, 0.5), MUD.darkened(0.05))
	k.box("planks", Vector3(0, 0.79, -0.06), Vector3(0.92, 0.06, 0.58), wood.lightened(0.1))
	for sx in [-0.42, 0.42]:
		for sz in [-0.36, 0.3]:
			k.box("planks", Vector3(sx, 0.95, sz), Vector3(0.06, 1.9, 0.06), wood)
	# the awning, sloping down to the front, in stripes
	var n := 6
	for i in n:
		var x0 := -0.5 + float(i) / n
		var x1 := -0.5 + float(i + 1) / n
		k.poly("fabric", [Vector3(x0, 1.92, -0.42), Vector3(x1, 1.92, -0.42), Vector3(x1, 1.72, 0.42), Vector3(x0, 1.72, 0.42)], Vector3(0, 0.97, 0.22), cloth[i % 2])
		k.poly("fabric", [Vector3(x1, 1.92, -0.42), Vector3(x0, 1.92, -0.42), Vector3(x0, 1.72, 0.42), Vector3(x1, 1.72, 0.42)], Vector3(0, -0.97, -0.22), cloth[i % 2].darkened(0.2))
		# a scalloped valance along the front
		k.box("fabric", Vector3((x0 + x1) / 2.0, 1.64, 0.43), Vector3(1.0 / n - 0.02, 0.16, 0.02), cloth[i % 2])
	# baskets of fruit
	var fruit := [Color("#f2a33a"), Color("#d8443a"), Color("#8ab83a")]
	for i in 3:
		var bx := -0.28 + i * 0.28
		VBld._column(k, "planks", Vector3(bx, 0.82, 0.06), 0.11, 0.1, 8, Color("#b98a52"))
		k.box("color", Vector3(bx, 0.95, 0.06), Vector3(0.16, 0.08, 0.16), fruit[i])


## Three clay jars of different sizes, with a little rim on each.
static func _jars(k: VBld.Kit) -> void:
	for j in [[-0.18, -0.1, 0.2, 0.62], [0.2, -0.05, 0.16, 0.48], [0.02, 0.22, 0.13, 0.36]]:
		var c := Vector3(j[0], 0, j[1])
		var r: float = j[2]
		var hh: float = j[3]
		var col := CLAY.lerp(Color("#d89a5a"), float(absi(int(j[0] * 10.0))) * 0.15)
		VBld._column(k, "color", c, r * 0.7, hh * 0.18, 10, col.darkened(0.08))
		VBld._column(k, "color", c + Vector3.UP * hh * 0.18, r, hh * 0.52, 10, col)
		VBld._column(k, "color", c + Vector3.UP * hh * 0.7, r * 0.55, hh * 0.22, 10, col.darkened(0.05))
		VBld._column(k, "color", c + Vector3.UP * hh * 0.92, r * 0.7, hh * 0.08, 10, col.lightened(0.1))
		k.box("color", c + Vector3.UP * (hh + 0.002), Vector3(r * 0.9, 0.01, r * 0.9), Color("#3a2418"))


## A round stone well: a low wall of plastered stone, a timber frame over it with a roller, a rope and a bucket.
static func _well(k: VBld.Kit) -> void:
	var wood := Color("#7a4e30")
	VBld._column(k, "adobe", Vector3(0, 0, 0), 0.42, 0.62, 14, COPING.darkened(0.05))
	VBld._column(k, "adobe", Vector3(0, 0.62, 0), 0.45, 0.08, 14, COPING)
	k.box("color", Vector3(0, 0.6, 0), Vector3(0.62, 0.01, 0.62), Color("#22303a"))
	for sx in [-0.4, 0.4]:
		k.box("planks", Vector3(sx, 0.95, 0), Vector3(0.08, 1.3, 0.08), wood)
	k.box("planks", Vector3(0, 1.5, 0), Vector3(0.92, 0.08, 0.1), wood)
	k.box("planks", Vector3(0, 1.32, 0), Vector3(0.6, 0.08, 0.08), wood.lightened(0.1))
	k.box("color", Vector3(0.05, 1.08, 0), Vector3(0.02, 0.44, 0.02), Color("#c8b088"))
	VBld._column(k, "planks", Vector3(0.05, 0.74, 0), 0.08, 0.13, 8, wood.lightened(0.15))


# ================================================================ the town's buildings
## Sunwall's houses and shops (the "adobe" style: a town map's "style", world.gd _building_node), built like Dustwell's
## (frontier_builder.gd) of the house pack's wall sections for doors and windows (HouseBuilder), laid over with sun-dried
## mud in a warm earth colour, with VBld.Kit boxes for the rest:
##   a block of thick walls with rounded corners on a low plinth; a flat roof behind a parapet, stepped up at its
##   corners, with log beam ends (vigas) jutting out under it and a wooden drain spout or two; in the bigger ones a
##   smaller second storey set back on the roof, a ladder leaning up to it. Shops have wide windows under a striped
##   cloth awning in their colour and their icon (or words) on a board on the parapet.
## A building's local origin is the centre of its plot at ground level; its front faces +z.

const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")
const Frontier = preload("res://scripts/gfx/frontier_builder.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")

## the walls' earth colours: sand, honey, clay, cream, apricot, whitewash
const EARTHS := ["#dcb88a", "#e6c79a", "#d2a274", "#ead6b4", "#e2b08a", "#efe2ca"]
const S := HouseBuilder.STOREY
const IN := HouseBuilder.INSET
const THICK := HouseBuilder.THICK
const PLINTH := 0.18
const PARAPET := 0.45
const BRASS := Color("#f0c850")
const WOOD := Color("#6e4a2e")


## Whether this style builds that building (the Beast Center is the temple every town has, beast_temple.gd; the arena
## and Sky Tower their own).
static func handles(shop: String) -> bool:
	return shop in ["house", "home", "decor"] or shop in VBld.COMMERCIAL


static func build(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	var shop: String = b["shop"]
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("adobe:%s:%d:%d:%d" % [shop, int(b.get("seed", 0)), int(b["x"]), int(b["y"])]).hash()
	var col := Color(EARTHS[absi(int(b["x"]) * 7 + int(b["y"]) * 3) % EARTHS.size()])
	var store := shop in VBld.COMMERCIAL
	# (no storey set back on the roof where people walk not far behind it, world.gd "low": the camera looks over it)
	var two := ((w >= 5) if store else (w >= 4 and rng.randf() < 0.6)) and not bool(b.get("low", false))
	var o := {"col": col, "locked": bool(b.get("locked", false)), "door_lx": door_lx, "store": store, "floors": 2 if two else 1}
	if store:
		o["icon"] = shop
		o["awning"] = Color(VBld.SHOP_ROOF.get(shop, "#c84040"))
	if b.has("words"):
		o["words"] = b["words"]
	b["height"] = _block(node, w, d, rng, o)
	return node


## A house for the outskirts, past the map's edge: [node, radius].
static func backdrop(rng: RandomNumberGenerator) -> Array:
	var w := float(rng.randi_range(4, 6))
	var d := 4.0
	var b := {"shop": "decor", "x": rng.randi_range(0, 60), "y": rng.randi_range(0, 9), "w": w, "d": d, "door": Vector2i(int(w) / 2, 3), "seed": rng.randi()}
	var node := build(b)
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [node, maxf(w, d) * 0.5]


## The building: its ground storey with the door, the flat roof, and the storey set back above. Returns its top.
static func _block(node: Node3D, w: float, d: float, rng: RandomNumberGenerator, o: Dictionary) -> float:
	var k := VBld.Kit.new()
	var col: Color = o["col"]
	var mat: Material = HouseBuilder.wall_material("adobe", col)
	var door_lx: float = o["door_lx"]
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	hb.rng.seed = rng.randi()
	var zf := d / 2.0 - IN
	var x0 := -w / 2.0 + IN + THICK
	var x1 := w / 2.0 - IN - THICK
	# the plinth, and a step at the door
	k.box("adobe", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.08, PLINTH, d - 0.08), col.darkened(0.12))
	k.box("adobe", Vector3(door_lx, PLINTH / 4.0, zf + 0.12), Vector3(1.3, PLINTH / 2.0, 0.24), col.darkened(0.18))
	var y := PLINTH
	# ---- the ground storey
	var dw := 1.5
	var door: String = "door_1" if o["locked"] else String(VBld.PACK_DOORS[rng.randi_range(0, VBld.PACK_DOORS.size() - 1)])
	hb.place(door, Vector2i(0, 1), door_lx, dw, y, mat)
	if o["locked"]:
		VBld._door_lock(k, Vector3(door_lx, y + 1.0, zf + 0.02), 0.8, 1.9)
	else:
		k.box("color", Vector3(door_lx + 0.27, y + 0.95, zf + 0.05), Vector3(0.07, 0.07, 0.07), BRASS)
	var kind := "wide" if o["store"] else "house"
	Frontier._openings(hb, x0, door_lx - dw / 2.0, y, mat, kind)
	Frontier._openings(hb, door_lx + dw / 2.0, x1, y, mat, kind)
	Frontier._walls(hb, x0, x1, d, y, mat)
	_round_corners(k, w, d, y, S, col)
	var top := y + S
	# (a shop's awning hangs where the vigas would jut out)
	_roof(k, w, d, top, col, rng, true, not o["store"])
	var peak := top + 0.16 + PARAPET + 0.4
	if o["store"]:
		_awning(k, w, zf, y, o["awning"])
		_sign(node, k, w, zf, top, o)
	# ---- the storey set back on the roof: at the back, to one side or in the middle
	if int(o["floors"]) == 2:
		var uw := maxf(3.0, roundf(w * 0.62))
		var ud := maxf(2.2, roundf(d * 0.55 * 2.0) / 2.0)
		var ux: float = [-(w - uw) / 2.0, 0.0, (w - uw) / 2.0][rng.randi_range(0, 2)]
		var up := Node3D.new()
		up.position = Vector3(ux, 0, -d / 2.0 + ud / 2.0)
		node.add_child(up)
		var hu = HouseBuilder.new()
		hu.node = up
		hu.w = uw
		hu.d = ud
		hu.rng.seed = rng.randi()
		var uy := top + 0.16
		var ux0 := -uw / 2.0 + IN + THICK
		var ux1 := uw / 2.0 - IN - THICK
		Frontier._openings(hu, ux0, ux1, uy, mat, "house")
		Frontier._walls(hu, ux0, ux1, ud, uy, mat)
		var uk := VBld.Kit.new()
		_round_corners(uk, uw, ud, uy, S, col)
		_roof(uk, uw, ud, uy + S, col, rng, false, true)
		# a ladder leaning on its front from the roof below, at the end nearer the middle of the building
		var lx := ux1 - 0.3 if ux <= 0.0 else ux0 + 0.3
		var zu := ud / 2.0 - IN
		_ladder(uk, Vector3(lx, uy, zu + 0.55), Vector3(lx, uy + S + 0.5, zu + 0.06))
		hu.finish()
		var um := MeshInstance3D.new()
		um.mesh = uk.mesh()
		up.add_child(um)
		peak = uy + S + 0.16 + PARAPET + 0.4
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return peak


## Rounded corners: a mud column at each corner of a storey, hiding where its walls meet.
static func _round_corners(k: VBld.Kit, w: float, d: float, y0: float, h: float, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			VBld._column(k, "adobe", Vector3(sx * (w / 2.0 - IN - THICK / 2.0), y0, sz * (d / 2.0 - IN - THICK / 2.0)), 0.18, h, 10, col)


## A flat roof: a slab over the walls and a parapet round it with a lighter coping, stepped up at the corners; vigas
## under it along the front and, on the ground storey, a drain spout or two through the front parapet.
static func _roof(k: VBld.Kit, w: float, d: float, top: float, col: Color, rng: RandomNumberGenerator, spouts: bool, vigas: bool) -> void:
	var cope := col.lightened(0.12)
	k.box("adobe", Vector3(0, top + 0.08, 0), Vector3(w - 0.12, 0.16, d - 0.12), col.darkened(0.06))
	var yp := top + 0.16
	var t := 0.24
	var hx := w / 2.0 - 0.06 - t / 2.0
	var hz := d / 2.0 - 0.06 - t / 2.0
	for sz in [-1.0, 1.0]:
		k.box("adobe", Vector3(0, yp + PARAPET / 2.0, sz * hz), Vector3(w - 0.12, PARAPET, t), col)
		k.box("adobe", Vector3(0, yp + PARAPET + 0.04, sz * hz), Vector3(w - 0.08, 0.08, t + 0.06), cope)
	for sx in [-1.0, 1.0]:
		k.box("adobe", Vector3(sx * hx, yp + PARAPET / 2.0, 0), Vector3(t, PARAPET, d - 0.12), col)
		k.box("adobe", Vector3(sx * hx, yp + PARAPET + 0.04, 0), Vector3(t + 0.06, 0.08, d - 0.08), cope)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("adobe", Vector3(sx * (hx - 0.1), yp + PARAPET + 0.2, sz * (hz - 0.1)), Vector3(0.44, 0.32, 0.44), col)
			k.box("adobe", Vector3(sx * (hx - 0.1), yp + PARAPET + 0.38, sz * (hz - 0.1)), Vector3(0.48, 0.06, 0.48), cope)
	# vigas along the front, just under the roof
	var zf := d / 2.0 - IN
	var n := maxi(2, int((w - 0.8) / 0.75))
	for i in (n if vigas else 0):
		var x := -w / 2.0 + 0.55 + (w - 1.1) * (float(i) + 0.5) / n
		k.box("planks", Vector3(x, top - 0.18, zf + 0.15), Vector3(0.15, 0.15, 0.3), WOOD)
	if spouts:
		var sides := [-1.0, 1.0] if w >= 5 else [1.0 if rng.randf() < 0.5 else -1.0]
		for sx in sides:
			k.box("planks", Vector3(sx * (w / 2.0 - 0.75), yp + 0.12, hz + t / 2.0 + 0.2), Vector3(0.16, 0.1, 0.42), WOOD.lightened(0.1))


## A shop's cloth awning across its front, above the door's top, striped in its colour.
static func _awning(k: VBld.Kit, w: float, zf: float, y: float, colour: Color) -> void:
	var yw := y + 2.72
	var yb := y + 2.42
	var depth := 0.55
	var x := -w / 2.0 + 0.3
	var x_end := w / 2.0 - 0.3
	var i := 0
	while x < x_end - 0.01:
		var x2 := minf(x + 0.42, x_end)
		var c: Color = colour if i % 2 == 0 else Color("#f4ecdc")
		k.poly("fabric", [Vector3(x, yw, zf), Vector3(x2, yw, zf), Vector3(x2, yb, zf + depth), Vector3(x, yb, zf + depth)], Vector3(0, 0.88, 0.48), c)
		k.poly("fabric", [Vector3(x2, yw, zf), Vector3(x, yw, zf), Vector3(x, yb, zf + depth), Vector3(x2, yb, zf + depth)], Vector3(0, -0.88, -0.48), c.darkened(0.25))
		k.box("fabric", Vector3((x + x2) / 2.0, yb - 0.07, zf + depth), Vector3(x2 - x - 0.02, 0.14, 0.02), c)
		x = x2
		i += 1
	# the iron rod it hangs from
	k.box("color", Vector3(0, yw + 0.02, zf + 0.04), Vector3(w - 0.5, 0.04, 0.04), Color("#2a2a30"))


## A shop's sign: a board on the front parapet with its icon, or words, painted on it.
static func _sign(node: Node3D, k: VBld.Kit, w: float, zf: float, top: float, o: Dictionary) -> void:
	var z := zf + 0.04
	var sy := top + 0.16 + PARAPET * 0.5 + 0.1
	var brand: Color = o.get("awning", Color("#5a3424"))
	if o.has("words"):
		var text := String(o["words"])
		var bw := minf(w - 0.6, 0.42 * text.length() + 0.5)
		k.box("planks", Vector3(0, sy, z), Vector3(bw, 0.62, 0.06), Color("#f4ecdc"))
		k.box("color", Vector3(0, sy, z + 0.035), Vector3(bw - 0.14, 0.5, 0.02), brand.darkened(0.3))
		Frontier._words(node, text, Vector3(0, sy, z + 0.05), Color("#ffe7a8"))
	elif o.has("icon"):
		k.box("planks", Vector3(0, sy, z), Vector3(1.7, 0.56, 0.06), Color("#f4ecdc"))
		k.box("color", Vector3(0, sy, z + 0.035), Vector3(1.5, 0.42, 0.02), brand.darkened(0.25))
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(String(o["icon"]))
		icon.position = Vector3(0, sy - 0.02, VBld._on_face(icon.mesh, z + 0.05))
		node.add_child(icon)


## A wooden ladder from its foot `a` to its top `b`: two rails (short boxes stepped up the slope) and rungs.
static func _ladder(k: VBld.Kit, a: Vector3, b: Vector3) -> void:
	var wood := Color("#8a5a36")
	var len := a.distance_to(b)
	var n := int(len / 0.2)
	for sx in [-0.2, 0.2]:
		for i in n:
			var p := a.lerp(b, (float(i) + 0.5) / n)
			k.box("planks", Vector3(a.x + sx, p.y, p.z), Vector3(0.06, len / n + 0.03, 0.06), wood)
	var rungs := int(len / 0.38)
	for i in rungs:
		var p := a.lerp(b, (float(i) + 0.7) / (float(rungs) + 0.4))
		k.box("planks", Vector3(a.x, p.y, p.z), Vector3(0.4, 0.05, 0.05), wood.lightened(0.1))
