extends RefCounted
## Turns the hand-made ASCII maps (scripts/data/maps/) into map dictionaries the world can build.
## Map ids: "caccoon" (town), "route3" (route), "tidewater#2" (inside building 2),
## "cogsworth#4@3" (third floor of building 4).

const MapGen = preload("res://scripts/world/map_gen.gd")
const Elev = preload("res://scripts/world/elevation.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const TownMaps = preload("res://scripts/data/maps/town_maps.gd")
const RouteMaps = preload("res://scripts/data/maps/route_maps.gd")
const InteriorMaps = preload("res://scripts/data/maps/interior_maps.gd")
const RoomBuilder = preload("res://scripts/gfx/room_builder.gd")

const TILE_CHARS := {
	".": MapGen.GRASS, ",": MapGen.PATH, ":": MapGen.PLAZA, "g": MapGen.TALL, "T": MapGen.TREE,
	"t": MapGen.BUSH, "~": MapGen.WATER, "=": MapGen.BRIDGE, "#": MapGen.ROCK, "W": MapGen.WALL,
	"f": MapGen.FLOWERS, "F": MapGen.FENCE, "_": MapGen.SAND, "L": MapGen.LAMP, "%": MapGen.LAVA,
	"S": MapGen.STATUE, "+": MapGen.SIGN, "c": MapGen.ICE,
}
## Blocks you can push around: "u" a boulder (moves one tile), "e" an ice block (slides until it hits something).
const PUSHABLE_CHARS := {"u": "boulder", "e": "ice"}
const ROOM_CHARS := {
	"#": MapGen.IWALL, "w": MapGen.IWINDOW, ".": MapGen.IFLOOR, ":": MapGen.ITILE, "r": MapGen.RUG,
	"x": MapGen.RING, "C": MapGen.COUNTER, "s": MapGen.SHELF, "B": MapGen.BOOKSHELF, "t": MapGen.TABLE,
	"h": MapGen.STOOL, "p": MapGen.PLANT, "b": MapGen.BED, "q": MapGen.FIREPLACE, "A": MapGen.ALTAR,
	"G": MapGen.BOARD, "M": MapGen.TERMINAL, "o": MapGen.PILLAR, "e": MapGen.EXHIBIT, "n": MapGen.ORGAN,
	"=": MapGen.BENCH, "~": MapGen.FOUNTAIN, "Y": MapGen.CRYSTAL, "D": MapGen.MAT, "%": MapGen.LAVA,
	">": MapGen.STAIRS_UP, "<": MapGen.STAIRS_DOWN, "g": MapGen.MIST, "H": MapGen.HEALER, "I": MapGen.INCUBATOR,
	"K": MapGen.KENNEL, "d": MapGen.IDOOR, "L": MapGen.LOCKED, "Z": MapGen.LOCKED, " ": MapGen.IVOID,
	"/": MapGen.IDIAG_A, "\\": MapGen.IDIAG_B,
}
## Tiles drawn as furniture (see room_builder.gd KINDS): the furniture letters of interior_maps.gd plus the older
## room tiles that are furniture too.
const FURNITURE_CODES := {MapGen.BED: "bed", MapGen.TABLE: "table", MapGen.STOOL: "stool", MapGen.PLANT: "plant",
	MapGen.BOOKSHELF: "bookshelf", MapGen.SHELF: "shelf", MapGen.RUG: "rug"}
const BUILDING_LETTERS := {
	"C": "center", "A": "apothecary", "G": "beast_gear", "O": "trainer_gear", "K": "bookstore",
	"R": "arena", "Y": "dojo", "M": "museum", "U": "music_hall", "N": "fortune", "E": "cafe",
	"H": "house", "Z": "home", "Q": "temple", "X": "electronics", "V": "skytower", "I": "ceo_tower",
	"B": "cathedral", "J": "hideout", "h": "decor", "D": "music_shop", "b": "cabin", "r": "uncle", "p": "fishery",
	"s": "shack",
}
const ENTITY_CHARS := "@v^<>$*123456789P"
const FACING := {"v": Vector2i(0, 1), "^": Vector2i(0, -1), "<": Vector2i(-1, 0), ">": Vector2i(1, 0)}
const CLEAR_TO := {"path": MapGen.PATH, "grass": MapGen.GRASS, "sand": MapGen.SAND, "bridge": MapGen.BRIDGE, "rope": MapGen.ROPE}
## Everyone who works in a shop or a Beast Center wears their workplace's uniform (see voxel_person.gd): a polo with
## a collar, short sleeves and a name badge, and usually a visor, so staff stand out from the townsfolk.
## Beast Center staff all share the diner's red and white: a red cap with the pawprint from the sign over the door on a
## white panel on its front (see voxel_person.gd), and no glasses.
const CENTER_UNIFORM := {"shirt": "#f4f4f4", "trim": "#d8283a", "pants": "#d8283a", "hat": "#d8283a", "cap": true,
	"logo": "center", "glasses": false, "badge": "#ffd94a", "outfit": "uniform"}
const KEEPER_LOOKS := {
	"center": {"skin": "#f0c8a0", "hair": "#e88aa0", "hair_style": 1, "shirt": "#f4f4f4", "trim": "#d8283a", "pants": "#d8283a",
		"hat": "#d8283a", "cap": true, "logo": "center", "glasses": false, "badge": "#ffd94a", "outfit": "uniform"},
	"apothecary": {"skin": "#e0b088", "hair": "#4a3a2a", "shirt": "#5a9a6a", "trim": "#f0ece0", "pants": "#3a4a3a",
		"hat": "#3a6a4a", "hat_style": "visor", "apron": "#f0ece0", "outfit": "uniform"},
	"beast_gear": {"skin": "#c08a60", "hair": "#2a1a10", "shirt": "#d08030", "trim": "#4a3a2a", "pants": "#4a3a2a",
		"hat": "#4a3a2a", "hat_style": "visor", "badge": "#f4f4f4", "outfit": "uniform"},
	"trainer_gear": {"skin": "#f0c8a0", "hair": "#c04030", "shirt": "#4070c0", "trim": "#f4f4f4", "pants": "#2e3448",
		"hat": "#f4f4f4", "hat_style": "visor", "outfit": "uniform"},
	"bookstore": {"skin": "#f8d8c0", "hair": "#e8e8f0", "shirt": "#8050b0", "trim": "#e8d8a0", "pants": "#3a2a2a",
		"hat": "#3a8a5a", "hat_style": "visor", "outfit": "uniform"},
	"arena": {"skin": "#e0b088", "hair": "#303040", "shirt": "#c8a030", "trim": "#3a3020", "pants": "#3a3020",
		"hat": "#3a3020", "hat_style": "visor", "badge": "#f4f4f4", "outfit": "uniform"},
	"cafe": {"skin": "#f0c8a0", "hair": "#a06030", "shirt": "#f0f0e0", "trim": "#c07040", "pants": "#6a4a3a",
		"hat": "#c07040", "hat_style": "visor", "apron": "#6a4a3a", "outfit": "uniform"},
	"dojo": {"skin": "#d8a880", "hair": "#202020", "shirt": "#f0ece0", "trim": "#202028", "pants": "#e8e4d8",
		"hat": "#d8283a", "hat_style": "band", "badge": "#d8283a", "outfit": "uniform"},
	"museum": {"skin": "#f8d8c0", "hair": "#6a4a2a", "shirt": "#3a5a8a", "trim": "#e8c060", "pants": "#2a2a3a",
		"hat": "#2a3a5a", "hat_style": "visor", "outfit": "uniform"},
	"music_hall": {"skin": "#e0b088", "hair": "#1a1a2a", "shirt": "#a82a3a", "trim": "#e8c060", "pants": "#1a1a2a",
		"hat": "#a82a3a", "outfit": "uniform"},
	"music_shop": {"skin": "#f0c8a0", "hair": "#d8d8d8", "shirt": "#b07a30", "trim": "#f4f0e8", "pants": "#2a2a3a",
		"hat": "#6a4a20", "hat_style": "visor", "badge": "#f4f4f4", "outfit": "uniform"},
	"fortune": {"skin": "#d8b0a0", "hair": "#6a3a8a", "hair_style": 1, "shirt": "#8a3aa0", "trim": "#ffd040", "pants": "#4a2a5a",
		"hat": "#ffd040", "hat_style": "band", "outfit": "uniform"},
	"electronics": {"skin": "#f0c8a0", "hair": "#3a3a3a", "shirt": "#3a6ab0", "trim": "#ffd040", "pants": "#2a2a3a",
		"hat": "#ffd040", "hat_style": "visor", "outfit": "uniform"},
	"skytower": {"skin": "#e0b088", "hair": "#c04030", "hair_style": 1, "shirt": "#4aa8e0", "trim": "#f4f4f4", "pants": "#2a3a5a",
		"hat": "#2a3a5a", "hat_style": "visor", "outfit": "uniform"},
	"temple": {"skin": "#e8c0a0", "hair": "#a0a0a0", "shirt": "#d8c8a0", "pants": "#a08860", "outfit": "robe"},
}
const BANDIT_LOOK := {"skin": "#d8a880", "hair": "#3a2a1a", "shirt": "#7a3a2a", "pants": "#4a3a2a", "hat": "#4a3a2a"}
const GRUNT_LOOK := {"skin": "#d8b8a0", "hair": "#20182a", "shirt": "#2a2038", "pants": "#18121f", "hat": "#4a2a6a", "outfit": "armor"}


static func is_interior(id: String) -> bool:
	return "#" in id


static func parent_of(id: String) -> String:
	return id.get_slice("#", 0)


static func load_map(id: String, flags: Dictionary) -> Dictionary:
	if is_interior(id):
		return _interior(id, flags)
	var src = TownMaps.MAPS.get(id, RouteMaps.MAPS.get(id, null))
	if src == null:
		return MapGen.generate(id, flags)
	return _parse(id, src, flags)


## Interior id of the first building of `shop` type in a map ("" if none).
static func interior_of(map_id: String, shop: String) -> String:
	var m := load_map(map_id, {})
	for b in m["buildings"]:
		if b["shop"] == shop:
			return b["interior"]
	return ""


## The room of building `interior` you wake up in on the first morning (the one whose template says "wake").
static func wake_room(interior: String) -> String:
	var base := interior.get_slice("@", 0)
	var pm := load_map(parent_of(base), {})
	var idx := int(base.get_slice("#", 1))
	if idx < 0 or idx >= pm["buildings"].size():
		return base
	var rooms := room_set(pm["buildings"][idx])
	for i in rooms.size():
		if InteriorMaps.ROOMS[rooms[i]].has("wake"):
			return floor_id(base, i + 1)
	return base


# ================================================================ outdoor maps
static func _parse(id: String, src: Dictionary, flags: Dictionary) -> Dictionary:
	var rows: Array = src["rows"]
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var kind := "town" if WorldDB.is_town(id) else "route"
	var m := MapGen._new_map(id, kind, w, h)
	m["anchors"] = {}
	m["openings"] = {}
	m["handmade"] = true
	m["obstacles"] = {}
	m["shards"] = []
	m["gate_tiles"] = []
	m["pushables"] = {}
	m["log_bridges"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var letters := {}
	var ents := []
	var obst_chars := {}
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x] if x < row.length() else "T"
			var p := Vector2i(x, y)
			if TILE_CHARS.has(ch):
				MapGen.set_t(m, x, y, TILE_CHARS[ch])
			elif BUILDING_LETTERS.has(ch):
				letters[p] = ch
				MapGen.set_t(m, x, y, MapGen.BUILDING)
			elif WorldDB.OBSTACLES.has(ch):
				obst_chars[p] = ch
				MapGen.set_t(m, x, y, MapGen.OBSTACLE)
			elif ch == "&":
				m["gate_tiles"].append(p)
				MapGen.set_t(m, x, y, MapGen.GATE)
			elif ch in ENTITY_CHARS:
				ents.append([ch, p])
			elif PUSHABLE_CHARS.has(ch):
				m["pushables"][p] = {"kind": PUSHABLE_CHARS[ch]}
				MapGen.set_t(m, x, y, MapGen.ICE if ch == "e" else MapGen.GRASS)
			else:
				MapGen.set_t(m, x, y, MapGen.GRASS)
	for e in ents:
		var p: Vector2i = e[1]
		MapGen.set_t(m, p.x, p.y, _infer_floor(m, p))
	# cliffs and ramps (elevation.gd)
	if src.has("heights"):
		Elev.parse(m, src["heights"])
	# "walls": the cliffs are drawn as dressed-stone retaining walls (a city's), not rock
	if src.has("cliffs"):
		m["cliffs"] = src["cliffs"]
	for setting in ["outskirt_houses", "outskirt_scale", "scenery_houses"]:
		if src.has(setting):
			m[setting] = src[setting]
	for p in m["pushables"]:
		if MapGen.get_t(m, p.x, p.y) != MapGen.ICE:
			MapGen.set_t(m, p.x, p.y, _infer_floor(m, p))
	# a solved push puzzle keeps its blocks where you left them
	if flags.get("puzzle_" + id, false) and typeof(flags.get("pushed_" + id, null)) == TYPE_ARRAY:
		var kinds := {}
		for p in m["pushables"]:
			kinds[m["pushables"][p]["kind"]] = true
		m["pushables"] = {}
		for e2 in flags["pushed_" + id]:
			m["pushables"][Vector2i(int(e2[0]), int(e2[1]))] = {"kind": String(e2[2])}

	# obstacles: connected groups of the same character, each with its own "cleared" flag
	var seen_o := {}
	var gi := 0
	for y in h:
		for x in w:
			var p0 := Vector2i(x, y)
			if not obst_chars.has(p0) or seen_o.has(p0):
				continue
			var ch: String = obst_chars[p0]
			var comp := _flood(p0, func(q): return obst_chars.get(q, "") == ch, seen_o)
			var info: Dictionary = WorldDB.OBSTACLES[ch]
			var flag := "obst_%s_%d" % [id, gi]
			var group := {"id": gi, "char": ch, "kind": info["kind"], "name": info["name"], "elements": info["elements"], "flag": flag, "tiles": comp}
			if flags.get(flag, false):
				for q in comp:
					MapGen.set_t(m, q.x, q.y, CLEAR_TO.get(info["clear"], MapGen.PATH))
				if info["kind"] == "broken_bridge":
					m["log_bridges"].append(comp)
			else:
				for q in comp:
					m["obstacles"][q] = group
			gi += 1

	# push puzzles draw their walls plain, so the maze is easy to read
	if src.has("puzzle_area"):
		var pa: Array = src["puzzle_area"]
		m["puzzle_area"] = Rect2i(int(pa[0]), int(pa[1]), int(pa[2]), int(pa[3]))
	# story gate
	var gate: Dictionary = src.get("gate", {})
	if not gate.is_empty():
		m["gate"] = gate
		if flags.get(gate["flag"], false):
			for q in m["gate_tiles"]:
				MapGen.set_t(m, q.x, q.y, MapGen.PATH)
			m["gate_tiles"] = []
		else:
			for q in m["gate_tiles"]:
				m["signs"][q] = gate["text"]

	# buildings: connected rectangles of one letter
	var hidden: Dictionary = src.get("hidden", {})
	var seen := {}
	var idx := 0
	var plots := []
	for y in h:
		for x in w:
			var p0 := Vector2i(x, y)
			if not letters.has(p0) or seen.has(p0):
				continue
			var letter: String = letters[p0]
			var comp := _flood(p0, func(q): return letters.get(q, "") == letter, seen)
			var minp: Vector2i = comp[0]
			var maxp: Vector2i = comp[0]
			for c in comp:
				minp = Vector2i(mini(minp.x, c.x), mini(minp.y, c.y))
				maxp = Vector2i(maxi(maxp.x, c.x), maxi(maxp.y, c.y))
			var sz := maxp - minp + Vector2i.ONE
			if hidden.has(letter) and not flags.get(hidden[letter], false):
				for c in comp:
					MapGen.set_t(m, c.x, c.y, MapGen.GRASS)
				m["hidden_spot"] = minp + sz / 2
				continue
			plots.append({"shop": BUILDING_LETTERS[letter], "pos": minp, "size": sz})
	# Authored ordering keeps saved interior ids and seeded room layouts stable when a town is rearranged.
	if src.has("building_order"):
		var order := {}
		for entry in src["building_order"]:
			order[Vector2i(int(entry[0]), int(entry[1]))] = order.size()
		plots.sort_custom(func(a, b): return int(order.get(a["pos"], 999)) < int(order.get(b["pos"], 999)))
	for plot in plots:
		_add_building(m, plot["shop"], plot["pos"], plot["size"], rng, id, idx)
		var appearance: Dictionary = src.get("building_looks", {}).get(str(idx), {})
		for key in appearance:
			m["buildings"].back()[key] = appearance[key]
		idx += 1

	# statue (top-left of the 2x2 block)
	for y in h:
		for x in w:
			if MapGen.get_t(m, x, y) == MapGen.STATUE and m["statue"].is_empty() and WorldDB.TOWNS.has(id):
				m["statue"] = {"pos": Vector2i(x, y), "race": WorldDB.TOWNS[id]["mascot"]}
				m["plaza"] = Vector2i(x + 1, y)

	# signs and lamps (reading order)
	var sign_texts: Array = src.get("signs", [])
	var si := 0
	for y in h:
		for x in w:
			var c := MapGen.get_t(m, x, y)
			if c == MapGen.SIGN:
				m["signs"][Vector2i(x, y)] = sign_texts[si] if si < sign_texts.size() else "A weathered sign."
				si += 1
			elif c == MapGen.LAMP:
				m["lamps"].append(Vector2i(x, y))

	# entities (reading order)
	var anchor_names: Dictionary = src.get("anchors", {})
	var trainers := []
	var item_k := 0
	var shard_k := 0
	var fixed_k := {}
	for e in ents:
		var ch: String = e[0]
		var p: Vector2i = e[1]
		if ch == "@":
			m["npcs"].append(_villager(p, rng))
		elif FACING.has(ch):
			trainers.append([p, FACING[ch]])
		elif ch == "$":
			m["items"].append({"pos": p, "item": _item_for(id, rng), "flag": "item_%s_%d" % [id, item_k]})
			item_k += 1
		elif ch == "*":
			m["shards"].append({"pos": p, "flag": "shard_%s_%d" % [id, shard_k]})
			shard_k += 1
		elif ch == "P":
			m["spawns"]["start"] = p
		elif anchor_names.has(ch):
			var an: String = anchor_names[ch]
			if an.begins_with("item:"):
				# a fixed item lying on the ground (e.g. the logs for the footbridge), each with its own flag
				var item_id := an.substr(5)
				var k: int = fixed_k.get(item_id, 0)
				fixed_k[item_id] = k + 1
				m["items"].append({"pos": p, "item": item_id, "flag": "item_%s_%s_%d" % [id, item_id, k]})
			else:
				m["anchors"][an] = p
	if WorldDB.ROUTES.has(id):
		var r: Dictionary = WorldDB.ROUTES[id]
		var legion_idx: int = src.get("legion", -2)
		var bard: Dictionary = WorldDB.BARDS.get(id, {})
		for k in trainers.size():
			var legion: bool = legion_idx == -1 or legion_idx == k
			var t := MapGen._make_trainer(id, k, trainers[k][0], trainers[k][1], _trainer_route(r), legion, rng)
			if not legion and not bard.is_empty() and int(bard["index"]) == k:
				_make_bard(t, bard)
			m["npcs"].append(t)
		m["encounter"] = {"races": r["races"], "lv": r["lv"], "rate": 0.11, "ghosts": r.get("ghosts", 0.0), "after_flute": r.get("after_flute", false)}
		if r.has("pack"):
			m["encounter"]["pack"] = r["pack"]

	# a town's catching ground (Bellerive's park): wild beasts live only inside it, never in the streets
	if src.has("meadow"):
		var md: Dictionary = src["meadow"]
		m["encounter"] = {"races": md["races"], "lv": md["lv"], "rate": 0.11, "ghosts": 0.0, "after_flute": true, "pack": 1}
		# a ring round "center" (radius tiles), or a fenced park's "rect" [x0, y0, x1, y1]
		var mc := Vector2(float(md.get("center", [0, 0])[0]), float(md.get("center", [0, 0])[1]))
		var mr: Array = md.get("rect", [])
		var area := {}
		for y in h:
			for x in w:
				var inside := Vector2(x, y).distance_to(mc) <= float(md.get("radius", 0.0)) if mr.is_empty() else \
					(x >= int(mr[0]) and y >= int(mr[1]) and x <= int(mr[2]) and y <= int(mr[3]))
				if inside and MapGen.walkable(MapGen.get_t(m, x, y)):
					area[Vector2i(x, y)] = true
		m["wild_area"] = area
	# a building standing in the water (a fishery on the docks) stands on planks over it
	var over := {}
	for b in m["buildings"]:
		if not b["shop"] in ["decor", "fishery"]:
			continue
		var wet := false
		for y in range(int(b["y"]) - 1, int(b["y"]) + int(b["d"]) + 1):
			for x in range(int(b["x"]) - 1, int(b["x"]) + int(b["w"]) + 1):
				if MapGen.get_t(m, x, y) == MapGen.WATER:
					wet = true
		if wet:
			if b["shop"] == "decor":
				b["name"] = "Fishery"
			for y in range(int(b["y"]), int(b["y"]) + int(b["d"])):
				for x in range(int(b["x"]), int(b["x"]) + int(b["w"])):
					over[Vector2i(x, y)] = true
	if not over.is_empty():
		m["over_water"] = over
	m["fish_spots"] = _fish_spots(id, m, src.get("fish_spots", []))
	# each spot's patch of water: FISH_AREA x FISH_AREA tiles round it, where the fish bite best
	var areas := {}
	for c in m["fish_spots"]:
		for dy in range(-1, FISH_AREA - 1):
			for dx in range(-1, FISH_AREA - 1):
				areas[Vector2i(c.x + dx, c.y + dy)] = true
	m["fish_areas"] = areas
	m["boats"] = src.get("boats", [])
	# exits along each connected edge
	var edges := WorldDB.town_edges(id) if WorldDB.TOWNS.has(id) else WorldDB.route_edges(id)
	for dir in edges:
		var target: String = edges[dir]
		var tiles := _edge_tiles(m, dir)
		m["openings"][dir] = tiles
		if tiles.is_empty():
			push_warning("Map %s has no exit on its %s edge" % [id, dir])
			continue
		for t in tiles:
			m["exits"][t] = {"to": target, "spawn": WorldDB.opposite(dir)}
		m["spawns"][dir] = _spawn_inside(m, tiles, dir)
	if m.has("center_front"):
		m["spawns"]["center"] = m["center_front"]
	m["spawns"]["skytower"] = m.get("skytower_front", m.get("center_front", Vector2i(-1, -1)))
	if not m["spawns"].has("start"):
		m["spawns"]["start"] = m["spawns"].get("center", m["spawns"].values()[0] if m["spawns"].size() > 0 else Vector2i(w / 2, h / 2))
	if not m.has("plaza"):
		m["plaza"] = m["spawns"]["start"]
	for a in m["anchors"]:
		if a == "dock":
			m["spawns"]["dock"] = m["anchors"][a]
	if WorldDB.TOWNS.has(id):
		_add_payphone(m)
	return m


## A red payphone a few steps from the town's square (see phone.gd), on open paving: the nearest tile to the square's
## middle, clear of the statue, with every tile round it free to walk on (so it never blocks the way) and nothing
## there that matters: a door, a sign, a person, an exit, a spawn.
static func _add_payphone(m: Dictionary) -> void:
	var mid := Vector2(m["plaza"]) + Vector2(0.0, 1.0) if not m["statue"].is_empty() else Vector2(m["plaza"])
	var taken := {}
	for b in m["buildings"]:
		taken[Vector2i(b["door"])] = true
		taken[Vector2i(b["door"]) + Vector2i(0, 1)] = true
	for n in m["npcs"]:
		taken[n["pos"]] = true
	for it in m["items"]:
		taken[it["pos"]] = true
	for t in m["exits"].keys() + m["signs"].keys() + m["spawns"].values() + m["anchors"].values():
		taken[t] = true
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(int(mid.y) - 6, int(mid.y) + 7):
		for x in range(int(mid.x) - 7, int(mid.x) + 8):
			var p := Vector2i(x, y)
			var d := (Vector2(p) + Vector2(0.5, 0.5)).distance_to(mid)
			if d < 2.6 or d >= best_d or not MapGen.get_t(m, x, y) in [MapGen.PLAZA, MapGen.PATH]:
				continue
			var open := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q: Vector2i = p + Vector2i(dx, dy)
					if taken.has(q) or not MapGen.walkable(MapGen.get_t(m, q.x, q.y)):
						open = false
					# (all round it on the same level ground: never at a cliff's edge or on a ramp)
					elif Elev.ramp_dir(m, q) != Vector2i.ZERO or not is_equal_approx(Elev.surface(m, q), Elev.surface(m, p)):
						open = false
			if open:
				best = p
				best_d = d
	if best.x >= 0:
		MapGen.set_t(m, best.x, best.y, MapGen.STREET_PROP)
		m["payphone"] = best


## How many tiles across each fishing spot's patch of rippling water is.
const FISH_AREA := 4


## Where the water ripples and the fish bite (fishing.gd): the map's own spots, and a few more by the shore or a pier,
## well apart (the same ones every time). Each is the middle of a FISH_AREA-square patch (see "fish_areas").
static func _fish_spots(id: String, m: Dictionary, given: Array) -> Dictionary:
	var out := {}
	for g in given:
		out[Vector2i(int(g[0]), int(g[1]))] = true
	var cands := []
	for y in range(1, int(m["h"]) - 1):
		for x in range(1, int(m["w"]) - 1):
			if MapGen.get_t(m, x, y) != MapGen.WATER:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := MapGen.get_t(m, x + d.x, y + d.y)
				if c != MapGen.WATER and (MapGen.walkable(c) or c == MapGen.BRIDGE):
					cands.append(Vector2i(x, y))
					break
	var rng := RandomNumberGenerator.new()
	rng.seed = (id + ":fish").hash()
	var tries := 0
	while out.size() < 3 + given.size() and not cands.is_empty() and tries < 60:
		tries += 1
		var q: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
		var far := true
		for o in out:
			if Vector2(q - o).length() < 7.0:
				far = false
		if far:
			out[q] = true
	return out


## A trainer who plays a flute song in battle.
static func _make_bard(t: Dictionary, bard: Dictionary) -> void:
	t["cls"] = "Bard"
	t["name"] = bard["name"]
	t["song"] = bard["song"]
	t["flute_skill"] = bard["skill"]
	t["encore"] = true
	t["look"]["hat"] = "#8a3aa0"
	t["look"]["outfit"] = "coat"
	t["lines"] = ["Ah, an audience! Let me play you something while my beasts do the fighting!"]
	t["defeat"] = "Bravo! You battle the way a virtuoso plays."


static func _flood(start: Vector2i, same: Callable, seen: Dictionary) -> Array:
	var comp := [start]
	seen[start] = true
	var qi := 0
	while qi < comp.size():
		var p: Vector2i = comp[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if not seen.has(q) and same.call(q):
				seen[q] = true
				comp.append(q)
	return comp


static func _trainer_route(r: Dictionary) -> Dictionary:
	var rr := r.duplicate()
	rr["trainers"] = 1
	return rr


static func _item_for(id: String, rng: RandomNumberGenerator) -> String:
	var pool := ["minor_potion", "potion", "remedy_herb", "fire_bomb", "revival_seed", "calm_incense", "haste_tonic", "mega_potion", "training_candy"]
	var tier := 0
	if WorldDB.TOWNS.has(id):
		tier = WorldDB.town_tier(id)
	else:
		var lv: Array = WorldDB.ROUTES.get(id, {"lv": [2, 5]})["lv"]
		tier = int(lv[0]) / 6
	return pool[clampi(rng.randi_range(0, 2) + tier / 2, 0, pool.size() - 1)]


static func _villager(p: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	return {"kind": "villager", "pos": p, "look": MapGen.random_look(rng),
		"facing": [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)][rng.randi_range(0, 2)],
		"name": WorldDB.TRAINER_NAMES[rng.randi_range(0, WorldDB.TRAINER_NAMES.size() - 2)], "seed": rng.randi(), "wander": true}


static func _add_building(m: Dictionary, shop: String, pos: Vector2i, sz: Vector2i, rng: RandomNumberGenerator, map_id: String, idx: int) -> void:
	var door := Vector2i(pos.x + sz.x / 2, pos.y + sz.y - 1)
	var b := {"shop": shop, "name": MapGen.SHOP_NAMES.get(shop, shop), "x": pos.x, "y": pos.y, "w": sz.x, "d": sz.y, "door": door,
		"roof": MapGen.ROOF.get(shop, "#a05a40"), "town": map_id, "seed": rng.randi(), "height": 2.6 if sz.y >= 4 else 2.2,
		"index": idx, "interior": "%s#%d" % [map_id, idx]}
	match shop:
		"bookstore":
			if map_id == "caccoon":
				b["name"] = "Cocoon Cove Library"
		"home":
			b["name"] = "Your Home"
		"arena":
			b["name"] = WorldDB.map_name(map_id) + " Arena"
			b["height"] = 3.2
		"electronics":
			b["name"] = "Sparkwire Electronics"
		"skytower":
			b["name"] = "Sky Tower"
		"ceo_tower":
			b["name"] = "Gearhart Tower"
		"cathedral":
			b["name"] = "Gravenmoor Cathedral"
		"hideout":
			b["name"] = "Bandit Hideout"
		"cabin":
			b["name"] = "Builder's Cabin"
		"uncle":
			b["name"] = "Uncle Rafe's House"
		"fishery":
			b["name"] = "Gil's Fishing Shack"
		"shack":
			b["name"] = "Cliffside Shack"
		"temple":
			var tk := WorldDB.ROUTES.get(map_id, {}).get("temple", "water") as String
			b["temple"] = tk
			b["name"] = WorldDB.TEMPLES[tk]["name"]
			b["glow"] = WorldDB.TEMPLES[tk]["glow"]
	if shop != "decor":
		MapGen.set_t(m, door.x, door.y, MapGen.DOOR)
	m["buildings"].append(b)
	if shop == "center" and not m.has("center_front"):
		m["center_front"] = door + Vector2i(0, 1)
	if shop == "skytower":
		m["skytower_front"] = door + Vector2i(0, 1)


static func _infer_floor(m: Dictionary, p: Vector2i) -> int:
	var counts := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := MapGen.get_t(m, p.x + d.x, p.y + d.y)
		if c in [MapGen.PATH, MapGen.PLAZA, MapGen.SAND, MapGen.BRIDGE, MapGen.GRASS, MapGen.FLOWERS, MapGen.TALL]:
			if c == MapGen.FLOWERS:
				c = MapGen.GRASS
			counts[c] = int(counts.get(c, 0)) + 1
	var best := MapGen.GRASS
	var best_n := 0
	for c in counts:
		if counts[c] > best_n or (counts[c] == best_n and c != MapGen.TALL):
			best = c
			best_n = counts[c]
	return best


static func _edge_tiles(m: Dictionary, dir: String) -> Array:
	var w: int = m["w"]
	var h: int = m["h"]
	var out := []
	match dir:
		"north":
			for x in range(1, w - 1):
				out.append(Vector2i(x, 0))
		"south":
			for x in range(1, w - 1):
				out.append(Vector2i(x, h - 1))
		"west":
			for y in range(1, h - 1):
				out.append(Vector2i(0, y))
		"east":
			for y in range(1, h - 1):
				out.append(Vector2i(w - 1, y))
	return out.filter(func(t): return MapGen.walkable(MapGen.get_t(m, t.x, t.y)))


static func _inward(dir: String) -> Vector2i:
	return {"north": Vector2i(0, 1), "south": Vector2i(0, -1), "west": Vector2i(1, 0), "east": Vector2i(-1, 0)}[dir]


## The way into the room from a doorway in its wall at `t`: towards the floor beside it.
static func _into_room(m: Dictionary, t: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + d
		var c := MapGen.get_t(m, q.x, q.y)
		if q.x > 0 and q.y > 0 and q.x < m["w"] - 1 and q.y < m["h"] - 1 and MapGen.walkable(c) and c != MapGen.IDOOR:
			return d
	return Vector2i(0, 1)


static func _spawn_inside(m: Dictionary, tiles: Array, dir: String) -> Vector2i:
	var mid: Vector2i = tiles[tiles.size() / 2]
	for k in [2, 1, 0]:
		var q: Vector2i = mid + _inward(dir) * k
		if MapGen.walkable(MapGen.get_t(m, q.x, q.y)):
			return q
	return mid


# ================================================================ interiors
## The room template names a building uses, one per floor.
static func room_set(b: Dictionary) -> Array:
	var shop: String = b["shop"]
	if shop == "bookstore" and b.get("town", "") == "caccoon":
		return ["library"]
	if shop == "house":
		return InteriorMaps.HOUSES[int(b["seed"]) % InteriorMaps.HOUSES.size()]
	if shop == "temple":
		return [WorldDB.TEMPLES[b.get("temple", "water")]["room"]]
	return InteriorMaps.SHOP_ROOMS.get(shop, ["house_a"])


static func floor_of(id: String) -> int:
	return int(id.get_slice("@", 1)) if "@" in id else 1


static func floor_id(base: String, f: int) -> String:
	return base if f <= 1 else "%s@%d" % [base, f]


static func _interior(id: String, flags: Dictionary) -> Dictionary:
	var base := id.get_slice("@", 0)
	var fl := floor_of(id)
	var parent := parent_of(base)
	var idx := int(base.get_slice("#", 1))
	var pm := load_map(parent, flags)
	if idx < 0 or idx >= pm["buildings"].size():
		return pm
	var b: Dictionary = pm["buildings"][idx]
	var rooms := room_set(b)
	var key: String = rooms[clampi(fl - 1, 0, rooms.size() - 1)]
	var room: Dictionary = InteriorMaps.ROOMS[key]
	var rows: Array = room["rows"]
	var h := rows.size()
	var w := String(rows[0]).length()
	var m := MapGen._new_map(id, "interior", w, h)
	m["name"] = b["name"]
	m["building"] = b
	m["parent"] = parent
	m["room"] = room
	m["room_key"] = key
	m["floor_num"] = fl
	# a stage room is one room of a building, seen whole like a stage set (no front wall, the camera still): its
	# set's other rooms are rooms, not floors
	m["stage"] = room.get("stage", false)
	m["floors"] = rooms.size() if not m["stage"] else 1
	m["biome"] = pm["biome"]
	m["anchors"] = {}
	m["exhibits"] = {}
	m["shards"] = []
	m["furniture"] = {}
	m["staff_doors"] = {}
	m["zone_rows"] = room.get("zones", [])
	m["zone_default"] = room.get("zone", _default_zone(key, room))
	var dots := 0
	var tiles := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["seed"]) + fl * 101
	var npc_roles: Dictionary = room.get("npcs", {})
	# named spots the story puts its own people on (Youngster Kit in his cabin), as outdoors
	var anchor_names: Dictionary = room.get("anchors", {})
	var exhibit_k := 0
	var mats := []
	var ups := []
	var downs := []
	var item_k := 0
	var fixed_k := {}
	# doors through to the building's other rooms (each loaded on its own): symbol -> the room's template
	var door_rooms: Dictionary = room.get("doors", {})
	var links := {}
	# what's behind each locked door, in reading order
	var locked_texts: Array = room.get("locked", [])
	var locked_k := 0
	m["locked_text"] = {}
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			var p := Vector2i(x, y)
			if door_rooms.has(ch):
				MapGen.set_t(m, x, y, MapGen.IDOOR)
				links[p] = door_rooms[ch]
			elif InteriorMaps.FURNITURE.has(ch):
				MapGen.set_t(m, x, y, MapGen.FURN)
				m["furniture"][p] = InteriorMaps.FURNITURE[ch]
			elif ROOM_CHARS.has(ch):
				MapGen.set_t(m, x, y, ROOM_CHARS[ch])
				if ch == "Z":
					m["staff_doors"][p] = true
				elif ch == "L" and locked_k < locked_texts.size():
					m["locked_text"][p] = locked_texts[locked_k]
					locked_k += 1
				if ch == ".":
					dots += 1
				elif ch == ":":
					tiles += 1
			elif ch == "P":
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
				m["spawns"]["entry"] = p
			elif anchor_names.has(ch):
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
				var an: String = anchor_names[ch]
				if an.begins_with("item:"):
					# a fixed item lying on the floor (the starter gear in the cliff shack), as outdoors
					var item_id := an.substr(5)
					var k: int = fixed_k.get(item_id, 0)
					fixed_k[item_id] = k + 1
					m["items"].append({"pos": p, "item": item_id, "flag": "item_%s_%s_%d" % [id, item_id, k]})
				else:
					m["anchors"][an] = p
			elif npc_roles.has(ch):
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
				var npc := _room_npc(npc_roles[ch], b, p, rng, id, ch, key)
				if not npc.is_empty():
					m["npcs"].append(npc)
			elif ch == "*":
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
				m["shards"].append({"pos": p, "flag": "shard_%s_%d" % [id, m["shards"].size()]})
			elif ch == "$":
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
				m["items"].append({"pos": p, "item": _item_for(parent, rng), "flag": "item_%s_%d" % [id, item_k]})
				item_k += 1
			else:
				MapGen.set_t(m, x, y, MapGen.IFLOOR)
			if ch == "e":
				m["exhibits"][p] = (int(b["seed"]) + exhibit_k * 11 + WorldDB.town_tier(parent) * 3) % RaceDB.count()
				exhibit_k += 1
			elif ch == "D":
				mats.append(p)
			elif ch == ">":
				ups.append(p)
			elif ch == "<":
				downs.append(p)
	m["floor"] = "tile" if tiles > dots else "wood"
	var fcode := MapGen.ITILE if tiles > dots else MapGen.IFLOOR
	for y in h:
		for x in w:
			if MapGen.get_t(m, x, y) == MapGen.IFLOOR and String(rows[y])[x] != ".":
				MapGen.set_t(m, x, y, fcode)
	# someone standing on a rug stands ON the rug: their tile takes the floor around them
	var spots: Array = m["npcs"].map(func(n): return n["pos"]) + m["anchors"].values()
	for it in m["items"] + m["shards"]:
		spots.append(it["pos"])
	if m["spawns"].has("entry"):
		spots.append(m["spawns"]["entry"])
	for q in spots:
		MapGen.set_t(m, q.x, q.y, floor_around(m, q, MapGen.get_t(m, q.x, q.y)))
	# the older furniture tiles are drawn as furniture too
	for y in h:
		for x in w:
			var fc := MapGen.get_t(m, x, y)
			var diner: bool = room.get("checker", false)
			if fc == MapGen.TABLE and diner:
				m["furniture"][Vector2i(x, y)] = "diner_table"
			elif FURNITURE_CODES.has(fc) and not m["furniture"].has(Vector2i(x, y)):
				m["furniture"][Vector2i(x, y)] = FURNITURE_CODES[fc]
			# benches: the diner's are red leather booths
			elif fc == MapGen.BENCH and not room.get("open", false):
				m["furniture"][Vector2i(x, y)] = "booth" if diner else "bench"
			elif fc == MapGen.TERMINAL:
				m["furniture"][Vector2i(x, y)] = "computer"
	# people face the middle of the room, or the table they're sitting at; never a wall
	# (staff stay facing out over their counters)
	# (a diner's patrons sit at their tables too)
	for n in m["npcs"]:
		var table := _table_beside(m, n["pos"])
		if n.get("kind", "") in ["villager", "resident", "patron"] or n.get("id", "") == "mom":
			if table != Vector2i.ZERO:
				# sitting there, on a chair (see world.gd seat)
				n["facing"] = table
				n["wander"] = false
				n["sit"] = true
			elif n.get("kind", "") != "patron":
				n["facing"] = room_facing(m, n["pos"])
				# visitors and people at home walk about the room (see world.gd _roam)
				if n.get("kind", "") in ["villager", "resident"]:
					n["roam"] = true
	m["spawn_face"] = {}
	m["front_doors"] = []
	for t in mats:
		m["exits"][t] = {"to": parent, "spawn": b["door"] + Vector2i(0, 1), "face": Vector2i(0, 1)}
		# a front door in a side (or back) wall is a doorway in it, and you come in facing the room
		if t.y < h - 1:
			MapGen.set_t(m, t.x, t.y, MapGen.IDOOR)
			m["front_doors"].append(t)
			m["spawn_face"]["entry"] = _into_room(m, t)
	for t in links:
		var to := rooms.find(links[t])
		if to < 0:
			push_warning("%s: a door to %s, which %s doesn't have" % [key, links[t], b["shop"]])
			continue
		m["exits"][t] = {"to": floor_id(base, to + 1), "spawn": "from_" + key}
		m["spawns"]["from_" + String(links[t])] = t + _into_room(m, t)
		m["spawn_face"]["from_" + String(links[t])] = _into_room(m, t)
	for t in ups:
		m["exits"][t] = {"to": floor_id(base, fl + 1), "spawn": "entry", "face": Vector2i(0, 1)}
	for t in downs:
		m["exits"][t] = {"to": floor_id(base, fl - 1), "spawn": "from_above"}
	# where you arrive coming back down from the floor above: in a house, stepping off the foot of the stairs (the only
	# way onto them, see RoomBuilder.stair_ways_in); elsewhere beside them, facing the room
	if not ups.is_empty():
		var u: Vector2i = ups[0]
		var run := RoomBuilder.flight(m, u)
		var off: Vector2i = run["foot"] - run["up"]
		if m["stage"] and MapGen.walkable(MapGen.get_t(m, off.x, off.y)):
			m["spawns"]["from_above"] = off
			m["spawn_face"]["from_above"] = -run["up"]
		else:
			m["spawn_face"]["from_above"] = Vector2i(0, 1)
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q: Vector2i = u + d
				if MapGen.walkable(MapGen.get_t(m, q.x, q.y)) and not ups.has(q):
					m["spawns"]["from_above"] = q
					break
	m["spawns"]["start"] = m["spawns"].get("entry", Vector2i(w / 2, h - 2))
	# where you wake up on the first morning (your home)
	if room.has("wake"):
		m["spawns"]["wake"] = Vector2i(room["wake"][0], room["wake"][1])
	m["spawns"]["center"] = m["spawns"]["start"]
	if room.has("encounter"):
		var enc: Dictionary = room["encounter"]
		m["encounter"] = {"races": enc.get("races", []), "lv": enc["lv"], "rate": 0.13, "ghosts": 1.0 if enc.get("ghost", false) else 0.0}
	return m


## The kind of room a template is, if it doesn't say (see room_builder.gd ZONES).
static func _default_zone(key: String, room: Dictionary) -> String:
	if room.get("checker", false):
		return "diner"
	if key.begins_with("temple") or key.begins_with("crypt") or key in ["hideout"]:
		return "stone"
	if key in ["cathedral", "museum", "music_hall"]:
		return "grand"
	if key.begins_with("ceo") or key in ["skytower", "electronics"]:
		return "office"
	if key in ["dojo", "arena", "arena_ring", "fortune"]:
		return "wood"
	if key.begins_with("home") or key.begins_with("house") or key.begins_with("studio") or key == "uncle_home":
		return "living"
	return "shop"


## The floor a person or a piece of furniture at `p` stands on: a rug if it's in the middle of one, otherwise
## whichever of wood or tiles surrounds it.
static func floor_around(m: Dictionary, p: Vector2i, fallback: int) -> int:
	var n := {MapGen.IFLOOR: 0, MapGen.ITILE: 0, MapGen.RUG: 0}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := MapGen.get_t(m, p.x + d.x, p.y + d.y)
		if n.has(c):
			n[c] += 1
	if n[MapGen.RUG] >= 2:
		return MapGen.RUG
	if n[MapGen.IFLOOR] > n[MapGen.ITILE]:
		return MapGen.IFLOOR
	if n[MapGen.ITILE] > n[MapGen.IFLOOR]:
		return MapGen.ITILE
	return fallback


## The direction of a table right next to `p` (someone sitting there), or ZERO.
static func _table_beside(m: Dictionary, p: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if MapGen.get_t(m, p.x + d.x, p.y + d.y) == MapGen.TABLE:
			return d
	return Vector2i.ZERO


## True if someone at `p` looking along `d` would be staring at a wall.
static func faces_wall(m: Dictionary, p: Vector2i, d: Vector2i) -> bool:
	# The fourth wall is omitted: residents at the front can still face the audience.
	if m.get("kind", "") == "interior" and p.y + d.y == int(m["h"]) - 1:
		return false
	return MapGen.get_t(m, p.x + d.x, p.y + d.y) in [MapGen.IWALL, MapGen.IWINDOW]


## Stage residents open towards the audience; elsewhere face the room's middle. Never face a visible wall.
static func room_facing(m: Dictionary, p: Vector2i) -> Vector2i:
	var to := Vector2(m["w"] - 1, m["h"] - 1) / 2.0 - Vector2(p)
	var dirs := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
	if not m.get("stage", false):
		dirs.sort_custom(func(a, b): return Vector2(a).dot(to) > Vector2(b).dot(to))
	for d in dirs:
		if not faces_wall(m, p, d):
			return d
	return Vector2i(0, 1)


static func _room_npc(role: String, b: Dictionary, p: Vector2i, rng: RandomNumberGenerator, map_id: String, ch: String, room := "") -> Dictionary:
	var shop: String = b["shop"]
	match role:
		"keeper":
			var look: Dictionary = KEEPER_LOOKS.get(shop, MapGen.random_look(rng))
			return {"kind": "keeper", "pos": p, "look": look, "facing": Vector2i(0, 1), "name": "", "building": b}
		"leader":
			var a: Dictionary = WorldDB.ARENAS.get(b["town"], {})
			if a.is_empty():
				return {}
			var look2: Dictionary = MapGen.random_look(rng)
			for k in a.get("look", {}):
				look2[k] = a["look"][k]
			return {"kind": "leader", "pos": p, "look": look2, "facing": Vector2i(0, 1), "name": "%s %s" % [a["title"], a["leader"]], "building": b}
		"resident":
			var n := _villager(p, rng)
			n["kind"] = "resident"
			n["building"] = b
			return n
		"mom":
			# the kit's long-haired, smiling woman (no hat or hood); she has your skin, hair and eyes (world.gd _build_npcs)
			return {"kind": "story", "id": "mom", "name": "Mom", "pos": p, "look": {"model": "tf62", "skin": "#f0c8a0", "hair": "#8a3a20", "shirt": "#e07a5a", "pants": "#4a3a6a"}, "facing": Vector2i(0, 1)}
		"guardian":
			var tk: String = WorldDB.temple_for_room(room)
			if tk == "":
				tk = b.get("temple", "water")
			var t: Dictionary = WorldDB.TEMPLES[tk]
			return {"kind": "guardian", "id": "guardian_" + tk, "temple": tk, "name": RaceDB.race_name(t["guardian"]), "pos": p,
				"beast_genes": RaceDB.genes(t["guardian"]), "facing": Vector2i(0, 1), "flag": "guardian_" + tk, "big": true}
		"thunderhawk":
			# the Sky Tower's giant bird, a Tempestrix, waiting on the roof (its id is from when it was a Thunderhawk)
			return {"kind": "story", "id": "thunderhawk", "name": "Tempestrix", "pos": p, "beast_genes": RaceDB.genes(32), "big": true,
				"facing": Vector2i(0, 1), "building": b}
		"kennel":
			# the Beast Center uniform, with a green apron for the muddy paws
			return {"kind": "story", "id": "kennel_keeper", "name": "Kennel Keeper Pip", "pos": p, "facing": Vector2i(0, 1),
				"look": CENTER_UNIFORM.merged({"skin": "#c8946a", "hair": "#5a3a22", "hair_style": 0, "apron": "#7ab04a"}, true)}
		"guide":
			# she walks about the front of the room, ready to help (see world.gd _roam)
			return {"kind": "story", "id": "center_guide", "name": "Guide Dottie", "pos": p, "facing": Vector2i(0, 1), "roam": true,
				"look": CENTER_UNIFORM.merged({"skin": "#f0c8a0", "hair": "#f0d070", "hair_style": 1}, true)}
		"receptionist":
			# Gearhart Industries' brass-trimmed company uniform
			return {"kind": "story", "id": "receptionist", "name": "Receptionist", "pos": p, "facing": Vector2i(0, 1),
				"look": {"skin": "#f0c8a0", "hair": "#2a1a10", "hair_style": 1, "shirt": "#3a3a48", "trim": "#c8a040", "pants": "#2a2a32",
					"badge": "#c8a040", "outfit": "uniform"}}
		"robot":
			var lv := 26 + ["3", "4", "5"].find(ch) + (int(map_id.get_slice("@", 1)) if "@" in map_id else 1) * 2
			var race: int = RaceDB.ROBOTS[rng.randi_range(0, RaceDB.ROBOTS.size() - 1)]
			return {"kind": "trainer", "pos": p, "facing": Vector2i(0, 1), "sight": 3, "flag": "tr_%s_%s" % [map_id, ch],
				"name": "Unit %d" % rng.randi_range(100, 999), "cls": "Gearhart Sentry", "robot_body": RaceDB.ROBOT_MODELS[race],
				"team": [[race, lv, false], [RaceDB.ROBOTS[rng.randi_range(0, 3)], lv - 1, false]],
				"lines": ["INTRUDER DETECTED. COMMENCING REMOVAL."], "defeat": "SYSTEM... FAILURE...", "vanish": true}
		"ceo":
			return {"kind": "story", "id": "ceo", "name": "Magnus Gearhart", "pos": p, "facing": Vector2i(0, 1), "story": true,
				"look": {"skin": "#e8c0a0", "hair": "#d8d8e0", "shirt": "#1a1a22", "pants": "#1a1a22", "hat": "#2a2a2a", "outfit": "coat"}}
		"bandit", "bandit_boss":
			var boss := role == "bandit_boss"
			var lv2 := 22 if boss else 18
			var team := [[36, lv2, false], [6, lv2, false]]
			if boss:
				team = [[9, 24, false], [6, 24, false], [33, 25, false]]
			return {"kind": "trainer", "pos": p, "facing": Vector2i(0, 1), "sight": 3, "flag": "tr_%s_%s" % [map_id, ch],
				"name": "Black Bart" if boss else "Bandit %s" % WorldDB.TRAINER_NAMES[rng.randi_range(0, 30)], "cls": "Bandit Boss" if boss else "Bandit",
				"look": BANDIT_LOOK, "team": team, "lines": ["This here's our hideout, stranger. Turn around!"] if not boss else ["So you're the one roughin' up my boys. Let's dance!"],
				"defeat": "Alright, alright! We'll leave Sundown alone!" if boss else "Ugh... the boss won't like this.", "vanish": not boss, "bandit_boss": boss}
		"grunt", "ghost_grunt":
			var lv3 := 44 if role == "ghost_grunt" else 40
			var team2 := []
			for i in 2:
				team2.append([rng.randi_range(0, RaceDB.NORMAL_COUNT - 1), lv3 + i, true])
			return {"kind": "trainer", "pos": p, "facing": Vector2i(0, 1), "sight": 3, "flag": "tr_%s_%s" % [map_id, ch],
				"name": "Grunt " + WorldDB.TRAINER_NAMES[rng.randi_range(0, 30)], "cls": "Umbral Legion", "look": GRUNT_LOOK, "legion": true,
				"team": team2, "lines": ["None shall disturb the General's ritual!"], "defeat": "The shadows... retreat...", "vanish": true}
		"nyx":
			return {"kind": "story", "id": "nyx", "name": "Commander Nyx", "pos": p, "facing": Vector2i(0, 1), "story": true, "gone_flag": "nyx_defeated",
				"look": {"skin": "#d0b8a8", "hair": "#20182a", "shirt": "#3a1a4a", "pants": "#18121f", "hat": "#3a3a6a", "outfit": "armor"}}
		"vexmora":
			return {"kind": "story", "id": "vexmora", "name": "General Vexmora", "pos": p, "facing": Vector2i(0, 1), "story": true, "gone_flag": "game_cleared",
				"look": {"skin": "#c8b0b8", "hair": "#e0e0f0", "shirt": "#1a1024", "pants": "#120c18", "hat": "#6a2a9a", "outfit": "armor", "eyes": "#a838e0"}}
		_:
			return _villager(p, rng)
