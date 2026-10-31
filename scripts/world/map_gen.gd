extends RefCounted
## Generates town and route layouts from WorldDB data. Deterministic per map id.

const WorldDB = preload("res://scripts/data/world_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

enum { GRASS, PATH, TALL, TREE, WATER, ROCK, FLOWERS, BUILDING, DOOR, FENCE, PLAZA, STATUE, SAND, BARRICADE, LAMP, LAVA,
	BUSH, BRIDGE, WALL, SIGN,
	# interiors
	IFLOOR, ITILE, RUG, RING, IWALL, IWINDOW, COUNTER, SHELF, BOOKSHELF, TABLE, STOOL, PLANT, BED, FIREPLACE,
	ALTAR, BOARD, TERMINAL, PILLAR, EXHIBIT, ORGAN, BENCH, FOUNTAIN, CRYSTAL, MAT,
	# voxel era
	OBSTACLE, GATE, STAIRS_UP, STAIRS_DOWN, MIST,
	# Beast Center machines, route puzzles
	HEALER, INCUBATOR, ICE, ROPE, KENNEL,
	# rooms within buildings: an open doorway, a locked door, a piece of furniture (see map "furniture")
	IDOOR, LOCKED, FURN,
	# outside an L-shaped building's walls: nothing at all
	IVOID,
	# street furniture beside a building (a bench, barrels, a bin...): see world.gd _build_street_props
	STREET_PROP,
	# a wall cutting across a room's corner at 45 degrees: "/" runs from the tile's bottom-left to its top-right corner,
	# "\\" from its top-left to its bottom-right (see room_builder.gd)
	IDIAG_A, IDIAG_B,
	# A shallow sandy shore: only a few centimetres of water, never a swimming tile.
	SHALLOWS }

const WALKABLE := [GRASS, PATH, TALL, FLOWERS, PLAZA, SAND, BRIDGE, IFLOOR, ITILE, RUG, RING, MAT, STAIRS_UP, STAIRS_DOWN, MIST, ICE, ROPE,
	IDOOR, SHALLOWS]
## Tiles where wild beasts can appear.
const ENCOUNTER_TILES := [TALL, MIST]

const SHOP_NAMES := {
	"center": "Beast Center", "apothecary": "Apothecary", "beast_gear": "Beast Outfitter",
	"trainer_gear": "Trainer Outfitter", "bookstore": "Bookstore", "arena": "Arena", "cafe": "Café",
	"dojo": "Training Dojo", "museum": "Bestiary Museum", "music_hall": "Music Hall", "music_shop": "Brass & Reed Music",
	"fortune": "Fortune Teller", "house": "House", "temple": "Temple",
}
const ROOF := {
	"center": "#d84848", "apothecary": "#48a868", "beast_gear": "#d08030", "trainer_gear": "#4070c0",
	"bookstore": "#8050b0", "arena": "#c8a030", "cafe": "#e090a0", "dojo": "#7a4a30",
	"museum": "#4890a0", "music_hall": "#3a50a8", "music_shop": "#b07a30", "fortune": "#a040a0", "temple": "#d8c8a0",
}
const HOUSE_ROOFS := ["#a05a40", "#5a7aa0", "#7a9a50", "#b08040", "#806090", "#a04a5a"]
const SHOP_SIZE := {
	"center": Vector2i(6, 4), "arena": Vector2i(6, 4), "house": Vector2i(4, 3), "temple": Vector2i(6, 4),
	"museum": Vector2i(5, 4),
}


static func walkable(code: int) -> bool:
	return code in WALKABLE


static func _new_map(id: String, kind: String, w: int, h: int) -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(w * h)
	grid.fill(GRASS)
	return {
		"id": id, "kind": kind, "name": WorldDB.map_name(id), "w": w, "h": h, "grid": grid,
		"biome": WorldDB.biome_of(id), "buildings": [], "npcs": [], "exits": {}, "spawns": {},
		"items": [], "signs": {}, "lamps": [], "statue": {}, "encounter": {},
	}


static func get_t(m: Dictionary, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= m["w"] or y >= m["h"]:
		return TREE
	return m["grid"][y * m["w"] + x]


static func set_t(m: Dictionary, x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= m["w"] or y >= m["h"]:
		return
	m["grid"][y * m["w"] + x] = v


static func _fill(m: Dictionary, x0: int, y0: int, x1: int, y1: int, v: int, only := -1) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if only < 0 or get_t(m, x, y) == only:
				set_t(m, x, y, v)


static func _region_is(m: Dictionary, x0: int, y0: int, x1: int, y1: int, v: int) -> bool:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= m["w"] or y >= m["h"] or get_t(m, x, y) != v:
				return false
	return true


static func _border(m: Dictionary, thick: int) -> void:
	for y in m["h"]:
		for x in m["w"]:
			if x < thick or y < thick or x >= m["w"] - thick or y >= m["h"] - thick:
				set_t(m, x, y, TREE)


## Carves the opening for an edge and registers its exit + spawn point.
static func _opening(m: Dictionary, dir: String, to_map: String, center: int, locked := false) -> void:
	var w: int = m["w"]
	var h: int = m["h"]
	var tiles := []
	match dir:
		"north":
			for x in range(center - 2, center + 2):
				for y in 2:
					tiles.append(Vector2i(x, y))
			m["spawns"]["north"] = Vector2i(center, 2)
		"south":
			for x in range(center - 2, center + 2):
				for y in range(h - 2, h):
					tiles.append(Vector2i(x, y))
			m["spawns"]["south"] = Vector2i(center, h - 3)
		"west":
			for y in range(center - 1, center + 3):
				for x in 2:
					tiles.append(Vector2i(x, y))
			m["spawns"]["west"] = Vector2i(2, center)
		"east":
			for y in range(center - 1, center + 3):
				for x in range(w - 2, w):
					tiles.append(Vector2i(x, y))
			m["spawns"]["east"] = Vector2i(w - 3, center)
	for t in tiles:
		set_t(m, t.x, t.y, BARRICADE if locked else PATH)
		var outer: bool = (dir == "north" and t.y == 0) or (dir == "south" and t.y == h - 1) or (dir == "west" and t.x == 0) or (dir == "east" and t.x == w - 1)
		if locked:
			m["signs"][t] = "Umbral Legion barricades block the way. Spiked crates are stacked high, sealed with a shadowy sigil."
		elif outer:
			m["exits"][t] = {"to": to_map, "spawn": WorldDB.opposite(dir)}


# ================================================================ towns
static func make_town(id: String, flags: Dictionary) -> Dictionary:
	var t: Dictionary = WorldDB.TOWNS[id]
	var size: String = t["size"]
	var dims: Vector2i = {"hamlet": Vector2i(34, 24), "village": Vector2i(36, 27), "town": Vector2i(42, 31), "city": Vector2i(50, 37)}[size]
	var m := _new_map(id, "town", dims.x, dims.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var w := dims.x
	var h := dims.y
	_border(m, 2)
	var cx := w / 2
	var cy := h / 2
	var pr: int = {"hamlet": 2, "village": 3, "town": 3, "city": 4}[size]
	m["plaza"] = Vector2i(cx, cy)

	# main roads (2 wide) cross at the plaza
	_fill(m, cx - 1, 2, cx, h - 3, PATH)
	_fill(m, 2, cy, w - 3, cy + 1, PATH)
	# extra streets, 1 wide, every 7 rows
	var streets := [cy]
	var y := cy + 1 + 7
	while y <= h - 4:
		streets.append(y)
		_fill(m, 3, y, w - 4, y, PATH)
		y += 7
	y = cy - 7
	while y - 4 >= 2:
		streets.append(y)
		_fill(m, 3, y, w - 4, y, PATH)
		y -= 7
	# plaza
	_fill(m, cx - 1 - pr, cy - pr, cx + pr, cy + 1 + pr, PLAZA)
	_fill(m, cx - 1, cy, cx, cy + 1, STATUE)
	m["statue"] = {"pos": Vector2i(cx - 1, cy), "race": t["mascot"]}

	# edges
	var edges := WorldDB.town_edges(id)
	for dir in edges:
		var rid: String = edges[dir]
		var locked := false
		var lf: String = WorldDB.ROUTES[rid].get("locked_flag", "")
		if lf != "" and not flags.get(lf, false):
			locked = true
		var c := cx if dir in ["north", "south"] else cy
		_opening(m, dir, rid, c, locked)

	# lots above each street
	var lots := []
	for sy in streets:
		var x := 3
		while x + 6 <= w - 4:
			if _region_is(m, x, sy - 4, x + 5, sy - 1, GRASS):
				lots.append({"x": x, "sy": sy, "d": absf(x + 3 - cx) + absf(sy - cy) * 1.2})
				x += 7
			else:
				x += 1
	lots.sort_custom(func(a, b): return a["d"] < b["d"])
	var shops: Array = t["shops"]
	var li := 0
	for i in shops.size():
		if li >= lots.size():
			break
		var shop: String = shops[i]
		var lot: Dictionary = lots[li]
		li += 1
		var sz: Vector2i = SHOP_SIZE.get(shop, Vector2i(5, 3))
		var bx: int = lot["x"] + (6 - sz.x) / 2
		var by: int = lot["sy"] - sz.y
		_add_building(m, shop, bx, by, sz, rng, id)
	# leftover lots become gardens
	for k in range(li, lots.size()):
		var lot: Dictionary = lots[k]
		var gx: int = lot["x"]
		var gy: int = lot["sy"] - 4
		if rng.randf() < 0.5:
			_fill(m, gx + 1, gy + 1, gx + 4, gy + 2, FLOWERS, GRASS)
			_fill(m, gx, gy + 3, gx + 5, gy + 3, FENCE, GRASS)
		else:
			set_t(m, gx + 1, gy + 1, TREE)
			set_t(m, gx + 4, gy + 2, TREE)

	# lamps along the main road
	if size != "hamlet":
		for x in range(4, w - 4, 6):
			for ly in [cy - 1, cy + 2]:
				if get_t(m, x, ly) == GRASS:
					set_t(m, x, ly, LAMP)
					m["lamps"].append(Vector2i(x, ly))

	# scenery
	var flower_rate: float = m["biome"].get("flowers", 0.05)
	for yy in range(2, h - 2):
		for xx in range(2, w - 2):
			if get_t(m, xx, yy) != GRASS or _near(m, xx, yy, [PATH, DOOR, PLAZA], 1):
				continue
			var r := rng.randf()
			if r < 0.05:
				set_t(m, xx, yy, TREE)
			elif r < 0.05 + flower_rate:
				set_t(m, xx, yy, FLOWERS)
	if m["biome"].get("water", false) or m["biome"].get("sand", false):
		_pond(m, rng, 1, m["biome"].get("sand", false))

	# villagers
	var n: int = {"hamlet": 3, "village": 5, "town": 7, "city": 10}[size]
	for i in n:
		var p := _random_tile(m, rng, [PATH, PLAZA], 4)
		if p.x >= 0:
			m["npcs"].append({"kind": "villager", "pos": p, "look": random_look(rng), "facing": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)][rng.randi_range(0, 2)],
				"name": WorldDB.TRAINER_NAMES[rng.randi_range(0, WorldDB.TRAINER_NAMES.size() - 1)], "seed": rng.randi(), "wander": true})
	m["spawns"]["center"] = m.get("center_front", Vector2i(cx, cy + 3))
	m["spawns"]["start"] = Vector2i(cx + 2, cy + 3)
	return m


static func _add_building(m: Dictionary, shop: String, bx: int, by: int, sz: Vector2i, rng: RandomNumberGenerator, town: String) -> void:
	_fill(m, bx, by, bx + sz.x - 1, by + sz.y - 1, BUILDING)
	var door := Vector2i(bx + sz.x / 2, by + sz.y - 1)
	set_t(m, door.x, door.y, DOOR)
	var roof: String = ROOF.get(shop, HOUSE_ROOFS[rng.randi_range(0, HOUSE_ROOFS.size() - 1)])
	var name: String = SHOP_NAMES.get(shop, shop)
	if shop == "arena":
		name = WorldDB.map_name(town) + " Arena"
	var b := {"shop": shop, "name": name, "x": bx, "y": by, "w": sz.x, "d": sz.y, "door": door, "roof": roof,
		"town": town, "seed": rng.randi(), "height": 2.6 if sz.y >= 4 else 2.2}
	m["buildings"].append(b)
	if shop == "center":
		m["center_front"] = door + Vector2i(0, 1)


static func _near_region(m: Dictionary, x0: int, y0: int, x1: int, y1: int, code: int) -> bool:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if get_t(m, x, y) == code:
				return true
	return false


static func _near(m: Dictionary, x: int, y: int, codes: Array, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if get_t(m, x + dx, y + dy) in codes:
				return true
	return false


static func _random_tile(m: Dictionary, rng: RandomNumberGenerator, codes: Array, margin: int) -> Vector2i:
	var taken := {}
	for n in m["npcs"]:
		taken[n["pos"]] = true
	for _i in 300:
		var x := rng.randi_range(margin, m["w"] - margin - 1)
		var y := rng.randi_range(margin, m["h"] - margin - 1)
		var p := Vector2i(x, y)
		if get_t(m, x, y) in codes and not taken.has(p) and not _near(m, x, y, [DOOR], 1):
			return p
	return Vector2i(-1, -1)


static func _pond(m: Dictionary, rng: RandomNumberGenerator, count: int, sandy: bool) -> void:
	for i in count:
		for _try in 40:
			var x := rng.randi_range(5, m["w"] - 6)
			var y := rng.randi_range(5, m["h"] - 6)
			var rx := rng.randi_range(2, 4)
			var ry := rng.randi_range(1, 3)
			var ok := true
			for yy in range(y - ry - 2, y + ry + 3):
				for xx in range(x - rx - 2, x + rx + 3):
					if get_t(m, xx, yy) != GRASS and get_t(m, xx, yy) != FLOWERS and get_t(m, xx, yy) != TREE:
						ok = false
			if not ok:
				continue
			for yy in range(y - ry - 1, y + ry + 2):
				for xx in range(x - rx - 1, x + rx + 2):
					var dx := (xx - x) / float(rx + 0.5)
					var dy := (yy - y) / float(ry + 0.5)
					var d := dx * dx + dy * dy
					if d <= 1.0:
						set_t(m, xx, yy, WATER)
					elif d <= 1.9 and sandy:
						set_t(m, xx, yy, SAND)
			break


# ================================================================ routes
static func make_route(id: String, flags: Dictionary) -> Dictionary:
	var r: Dictionary = WorldDB.ROUTES[id]
	var edges := WorldDB.route_edges(id)
	var vertical := edges.has("north")
	var w := 24 if vertical else 56
	var h := 52 if vertical else 22
	var m := _new_map(id, "route", w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	_border(m, 2)
	var biome: Dictionary = m["biome"]

	# winding main path
	var path := []
	if vertical:
		var x := w / 2
		for y in range(h - 1, -1, -1):
			if y > 6 and y < h - 7 and rng.randf() < 0.2:
				x = clampi(x + (1 if rng.randf() < 0.5 else -1), 6, w - 7)
			elif y <= 6 or y >= h - 7:
				x += signi(w / 2 - x)
			_fill(m, x - 1, y, x, y, PATH)
			path.append(Vector2i(x, y))
	else:
		var y := h / 2
		for x in range(0, w):
			if x > 6 and x < w - 7 and rng.randf() < 0.2:
				y = clampi(y + (1 if rng.randf() < 0.5 else -1), 6, h - 7)
			elif x <= 6 or x >= w - 7:
				y += signi(h / 2 - y)
			_fill(m, x, y, x, y + 1, PATH)
			path.append(Vector2i(x, y))
	for dir in edges:
		var c := w / 2 if vertical else h / 2
		_opening(m, dir, edges[dir], c)

	# temple beside the path (on whichever side has room)
	if r.has("temple"):
		var mid: Vector2i = path[path.size() / 2]
		var sz := Vector2i(6, 4)
		var bx: int
		var by: int
		if vertical:
			bx = 3 if mid.x >= w / 2 else w - 3 - sz.x
			by = mid.y - 4
		else:
			bx = mid.x - 3
			by = 3 if mid.y >= h / 2 - 1 else h - 3 - sz.y
		for off in [0, 4, -4, 8, -8, 12, -12, 16, -16]:
			var ox: int = 0 if vertical else off
			var oy: int = off if vertical else 0
			if not _near_region(m, bx + ox - 1, by + oy - 1, bx + ox + sz.x, by + oy + sz.y, PATH):
				bx += ox
				by += oy
				break
		_fill(m, bx - 1, by - 1, bx + sz.x, by + sz.y, GRASS)
		_add_building(m, "temple", bx, by, sz, rng, id)
		var tb: Dictionary = m["buildings"][-1]
		tb["temple"] = r["temple"]
		tb["name"] = WorldDB.TEMPLES[r["temple"]]["name"]
		var door: Vector2i = tb["door"]
		_connect(m, door + Vector2i(0, 1))
		m["temple_front"] = door + Vector2i(0, 1)

	# tall grass patches
	var patches := int(w * h / 85)
	for i in patches:
		var gx := rng.randi_range(3, w - 4)
		var gy := rng.randi_range(3, h - 4)
		var rx := rng.randf_range(1.5, 4.0)
		var ry := rng.randf_range(1.2, 3.0)
		var over_path := rng.randf() < 0.45
		for yy in range(int(gy - ry) - 1, int(gy + ry) + 2):
			for xx in range(int(gx - rx) - 1, int(gx + rx) + 2):
				var dx := (xx - gx) / rx
				var dy := (yy - gy) / ry
				if dx * dx + dy * dy > 1.0:
					continue
				var cur := get_t(m, xx, yy)
				if cur == GRASS or (cur == PATH and over_path and yy > 2 and yy < h - 3 and xx > 2 and xx < w - 3):
					set_t(m, xx, yy, TALL)

	# water / lava pools
	if biome.get("water", false) or biome.get("sand", false):
		_pond(m, rng, 2 if biome.get("sand", false) else 1, biome.get("sand", false))
	if biome.get("lava", false):
		for i in 2:
			_lava(m, rng)

	# trees, rocks, flowers
	var rock_rate := 0.03
	if biome["id"] in ["rocky", "volcanic", "ashland", "snow", "highland"]:
		rock_rate = 0.06
	for yy in range(2, h - 2):
		for xx in range(2, w - 2):
			if get_t(m, xx, yy) != GRASS or _near(m, xx, yy, [PATH, DOOR], 1):
				continue
			var rr := rng.randf()
			if rr < 0.14:
				set_t(m, xx, yy, TREE)
			elif rr < 0.14 + rock_rate:
				set_t(m, xx, yy, ROCK)
			elif rr < 0.2 + rock_rate:
				set_t(m, xx, yy, FLOWERS)

	# trainers along the path
	var count: int = r["trainers"]
	for k in count:
		var idx := int((k + 1) * path.size() / (count + 1))
		var p: Vector2i = path[clampi(idx, 0, path.size() - 1)]
		var side := 1 if k % 2 == 0 else -1
		var tp: Vector2i
		var face: Vector2i
		if vertical:
			tp = p + Vector2i(2 if side > 0 else -3, 0)
			face = Vector2i(-side, 0)
		else:
			tp = p + Vector2i(0, 3 if side > 0 else -2)
			face = Vector2i(0, -side)
		if get_t(m, tp.x, tp.y) in [BUILDING, DOOR, BARRICADE] or tp.x < 2 or tp.y < 2 or tp.x >= w - 2 or tp.y >= h - 2:
			continue
		set_t(m, tp.x, tp.y, GRASS)
		var legion: bool = r.get("legion", false) and k == count - 1
		m["npcs"].append(_make_trainer(id, k, tp, face, r, legion, rng))

	# item pickups
	var item_pool := ["minor_potion", "potion", "remedy_herb", "revival_seed", "calm_incense", "lure_incense", "mega_potion", "training_candy"]
	for k in 2:
		var p := _random_tile(m, rng, [GRASS], 3)
		if p.x >= 0:
			var tier := WorldDB.ROUTES.keys().find(id)
			var item: String = item_pool[clampi(rng.randi_range(0, 2) + tier / 2, 0, item_pool.size() - 1)]
			m["items"].append({"pos": p, "item": item, "flag": "item_%s_%d" % [id, k]})

	m["encounter"] = {"races": r["races"], "lv": r["lv"], "rate": 0.11}
	return m


## Carves the shortest walkable connection from `start` to the nearest PATH tile.
static func _connect(m: Dictionary, start: Vector2i) -> void:
	var prev := {start: start}
	var queue := [start]
	var goal := Vector2i(-1, -1)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if get_t(m, p.x, p.y) == PATH and p != start:
			goal = p
			break
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if prev.has(q) or q.x < 2 or q.y < 2 or q.x >= m["w"] - 2 or q.y >= m["h"] - 2:
				continue
			if get_t(m, q.x, q.y) in [BUILDING, DOOR, WATER, LAVA]:
				continue
			prev[q] = p
			queue.append(q)
	if goal.x < 0:
		set_t(m, start.x, start.y, PATH)
		return
	var c: Vector2i = goal
	while c != start:
		c = prev[c]
		set_t(m, c.x, c.y, PATH)


static func _lava(m: Dictionary, rng: RandomNumberGenerator) -> void:
	for _try in 30:
		var x := rng.randi_range(5, m["w"] - 6)
		var y := rng.randi_range(5, m["h"] - 6)
		if _near(m, x, y, [PATH, BUILDING, DOOR], 3):
			continue
		var rx := rng.randi_range(1, 3)
		var ry := rng.randi_range(1, 2)
		_fill(m, x - rx, y - ry, x + rx, y + ry, LAVA, GRASS)
		return


static func _make_trainer(map_id: String, k: int, pos: Vector2i, face: Vector2i, r: Dictionary, legion: bool, rng: RandomNumberGenerator) -> Dictionary:
	var lv: Array = r["lv"]
	var team := []
	var size := 1 if int(lv[0]) <= 3 else 1 + rng.randi_range(0, 2 if lv[0] > 8 else 1)
	var npc := {"kind": "trainer", "pos": pos, "facing": face, "sight": 4, "flag": "tr_%s_%d" % [map_id, k]}
	if legion:
		size = 3 if lv[0] > 20 else 2
		for i in size:
			team.append([rng.randi_range(0, RaceDB.NORMAL_COUNT - 1), int(lv[1]) - 1 + rng.randi_range(0, 2), true])
		npc["name"] = "Grunt " + WorldDB.TRAINER_NAMES[rng.randi_range(0, WorldDB.TRAINER_NAMES.size() - 1)]
		npc["cls"] = "Umbral Legion"
		npc["look"] = {"skin": "#d8b8a0", "hair": "#20182a", "shirt": "#2a2038", "pants": "#18121f", "hat": "#4a2a6a"}
		npc["lines"] = ["Halt! The Umbral Legion claims this road.", "Our shadow beasts will crush you!"]
		npc["defeat"] = "Impossible... General Vexmora will hear of this."
		npc["legion"] = true
	else:
		var races: Array = r["races"]
		for i in size:
			var race: int = races[rng.randi_range(0, races.size() - 1)] if rng.randf() < 0.75 else rng.randi_range(0, RaceDB.NORMAL_COUNT - 1)
			# route trainers are always a step above anything wild on their road
			team.append([race, rng.randi_range(int(lv[1]) + 1, int(lv[1]) + 2), false])
		npc["name"] = WorldDB.TRAINER_NAMES[rng.randi_range(0, WorldDB.TRAINER_NAMES.size() - 1)]
		npc["cls"] = WorldDB.TRAINER_CLASSES[rng.randi_range(0, WorldDB.TRAINER_CLASSES.size() - 1)]
		# trainers out on the roads wear camo (see townfolk.gd outfit)
		npc["look"] = random_look(rng)
		npc["look"]["outfit"] = "camo"
		var ChatterDB = load("res://scripts/data/chatter_db.gd")
		npc["lines"] = [ChatterDB.OPENERS[rng.randi_range(0, ChatterDB.OPENERS.size() - 1)]]
		npc["defeat"] = ChatterDB.DEFEATS[rng.randi_range(0, ChatterDB.DEFEATS.size() - 1)]
	npc["team"] = team
	return npc


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var skins := ["#f0c8a0", "#e0b088", "#c08a60", "#8a5a3a", "#f8d8c0", "#6a4028"]
	var hairs := ["#2a1a10", "#5a3a20", "#a06030", "#e0c070", "#c04030", "#303040", "#e8e8f0", "#6a3a8a"]
	var shirts := ["#c84040", "#4070c0", "#40a060", "#e0a030", "#8050b0", "#30a0a0", "#e07090", "#606060", "#f0f0e0"]
	var pants := ["#2e3448", "#4a3a2a", "#3a4a30", "#202028", "#5a5a70"]
	var look := {
		"skin": skins[rng.randi_range(0, skins.size() - 1)],
		"hair": hairs[rng.randi_range(0, hairs.size() - 1)],
		"shirt": shirts[rng.randi_range(0, shirts.size() - 1)],
		"pants": pants[rng.randi_range(0, pants.size() - 1)],
	}
	if rng.randf() < 0.3:
		look["hat"] = shirts[rng.randi_range(0, shirts.size() - 1)]
	return look


static func generate(id: String, flags: Dictionary) -> Dictionary:
	if WorldDB.TOWNS.has(id):
		return make_town(id, flags)
	return make_route(id, flags)
