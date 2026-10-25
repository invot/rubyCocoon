extends RefCounted
## Bellerive's French Quarter (the "creole" style, world_db.gd biome "quarter"): every building but the Beast Center's
## diner and Gil's tin shack is built here, of the house pack's wall sections (assets/exteriors, as house_builder.gd)
## and VBld.Kit boxes:
##   townhouses (the north row, with nothing to walk on behind them): two or three storeys of pastel stucco or red
##   brick, tall windows with louvred shutters, and an iron gallery on posts over the sidewalk (or a balcony on
##   brackets) with lace railings and hanging ferns, under a slate hip roof, a side gable with dormers, or a cornice
##   and parapet. Shops have a shop front, a striped awning in the shop's colour and a sign board hanging from the
##   gallery, so they read as shops from across the street.
##   cottages (a row with a street close behind it, world.gd "low"): one storey, Creole cottages under a steep side
##   gable with dormers and a deep eave, or shotgun houses gable-end to the street behind a porch with brackets; low
##   shops are cottages with a shop front and awning.
##   Sparkwire Electronics is a townhouse shop with a blue blade sign; the Sky Tower is the square's white bell tower
##   with a clock, a belfry and a black slate spire; the arena an oval of pale limestone under a mansard ring, entered
##   through a pavilion with a mansard roof, iron cresting, a clock and Mardi Gras banners.
## Street furniture for the town: the quay's stone balustrade and the lamps' stone piers (world.gd).
## A building's local origin is the centre of its plot at ground level; its front faces +z (as voxel_buildings.gd).

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

## stucco paints: warm, soft pastels, so a street of them reads as one place
const STUCCO := ["#eaa58e", "#f0cc7a", "#acd4be", "#cbb4da", "#a2c8e2", "#f2bfbd", "#f3e6cc", "#e9b89c", "#d8e6a8"]
const BRICK := "#b9644a"
## shutters and doors: deep greens, blues and an oxblood
const SHUTTERS := ["#2f6048", "#2a5a78", "#7e3036", "#3c5a40", "#2e4a72", "#355e5e"]
const IRON := Color("#25302c")
const TRIM := Color("#f6f1e6")
const SLATE := Color("#56626e")
const BASE := Color("#a8a096")
const FERN := Color("#4f9a3e")
const WOOD := Color("#9a6a42")
const LIMESTONE := Color("#ece2cc")
## Mardi Gras: purple, green and gold
const MARDI_GRAS := [Color("#6a3a98"), Color("#2e8a4a"), Color("#e8b830")]

const S := HouseBuilder.STOREY
const PLINTH := 0.24
## how far a gallery reaches out over the sidewalk: its posts stand at the far edge of the sidewalk tile, half a tile
## from anyone walking along it, and on the tiles' edges across it, so nobody walks into one
const GALLERY := 1.04
const DOORS := ["door_3", "door_5", "door_6", "door_8"]
const TALL_WINDOWS := ["win_1", "win_3"]


## The node for one of the town's buildings (b: shop, x, y, w, d, door, seed, low, locked).
static func build(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	var shop: String = b["shop"]
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var locked: bool = b.get("locked", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("creole:%s:%d:%d" % [shop, int(b.get("seed", 0)), int(b["x"])]).hash()
	match shop:
		"skytower":
			b["height"] = _bell_tower(node, w, d, door_lx)
		"arena":
			b["height"] = _arena(node, w, d, door_lx, locked)
		_:
			if b.get("low", false):
				b["height"] = _cottage(node, b, w, d, door_lx, locked, rng)
			else:
				b["height"] = _townhouse(node, b, w, d, door_lx, locked, rng)
	return node


## Scenery nobody goes into (world.gd scenery_houses): the French Market's arcade ("kind": "market"), or a low
## building like the rest of its row.
static func scenery(b: Dictionary) -> Node3D:
	if String(b.get("kind", "")) == "market":
		var node := Node3D.new()
		_market(node, float(b["w"]), float(b["d"]))
		return node
	return build(b)


## A larger townhouse for the outskirts, past the map's edge: [node, radius].
static func backdrop(rng: RandomNumberGenerator) -> Array:
	var w := float(rng.randi_range(5, 7))
	var d := 4.0
	var b := {"shop": "house", "x": 0, "y": 0, "w": w, "d": d, "door": Vector2i(int(w) / 2, 3), "seed": rng.randi()}
	var node := Node3D.new()
	_townhouse(node, b, w, d, float(int(w) / 2) + 0.5 - w / 2.0, false, rng, true)
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [node, maxf(w, d) * 0.5 + GALLERY]


# ================================================================ townhouses
## Two or three storeys behind an iron gallery or balcony; returns the height of its walls.
static func _townhouse(node: Node3D, b: Dictionary, w: float, d: float, door_lx: float, locked: bool, rng: RandomNumberGenerator, outskirt := false) -> float:
	var shop: String = b["shop"]
	var commercial: bool = shop in VBld.COMMERCIAL or shop == "electronics"
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	hb.rng.seed = rng.randi()
	var k := VBld.Kit.new()
	var brick := not commercial and shop != "uncle" and rng.randf() < 0.3
	var paint := Color(STUCCO[rng.randi_range(0, STUCCO.size() - 1)])
	if shop == "electronics":
		paint = Color("#e4eef4")
	elif shop == "uncle":
		paint = Color("#f0cc7a")
	var wall_col := Color(BRICK) if brick else paint
	var mat: Material = HouseBuilder.wall_material("brick" if brick else "plaster", wall_col)
	var shutter := Color(SHUTTERS[rng.randi_range(0, SHUTTERS.size() - 1)])
	var brand := Color(VBld.SHOP_ROOF.get(shop, "#c84040"))
	if commercial:
		shutter = brand.darkened(0.35)
	var floors := 3 if not commercial and w >= 4 and rng.randf() < 0.4 else 2
	var kind := "gallery" if commercial or shop == "uncle" or rng.randf() < 0.55 else "balcony"
	var roof: String = ["hip", "parapet", "gable"][rng.randi_range(0, 2)]
	if commercial:
		roof = "parapet" if rng.randf() < 0.6 else "hip"
	var zf := d / 2.0 - HouseBuilder.INSET
	var x0 := -w / 2.0 + HouseBuilder.INSET + HouseBuilder.THICK
	var x1 := w / 2.0 - HouseBuilder.INSET - HouseBuilder.THICK
	# the stone base and a step up to the door
	k.box("stone", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.08, PLINTH, d - 0.08), BASE)
	k.box("stone", Vector3(door_lx, 0.07, zf + 0.2), Vector3(1.3, 0.14, 0.32), BASE.lightened(0.08))
	var y := PLINTH
	var decks := []
	for f in floors:
		if f == 0:
			var dw := 1.5
			var door: String = "door_1" if locked else DOORS[rng.randi_range(0, DOORS.size() - 1)]
			hb.place(door, Vector2i(0, 1), door_lx, dw, y, mat)
			_door_frame(k, door_lx, dw, y, zf, shutter)
			if commercial:
				_shop_window(hb, k, x0, door_lx - dw / 2.0, y, zf, mat, brand)
				_shop_window(hb, k, door_lx + dw / 2.0, x1, y, zf, mat, brand)
			else:
				_bays(hb, k, x0, door_lx - dw / 2.0, y, zf, mat, shutter, TALL_WINDOWS)
				_bays(hb, k, door_lx + dw / 2.0, x1, y, zf, mat, shutter, TALL_WINDOWS)
			if locked:
				VBld._door_lock(k, Vector3(door_lx, y + 1.0, zf + 0.02), 0.8, 1.9)
		else:
			_bays(hb, k, x0, x1, y, zf, mat, shutter, TALL_WINDOWS)
			decks.append(y)
		# the back and the sides: plain (the neighbours' walls would meet them)
		hb.place("wall_2", Vector2i(0, -1), 0.0, x1 - x0, y, mat)
		var z0 := -d / 2.0 + HouseBuilder.INSET + HouseBuilder.THICK
		for sx in [-1, 1]:
			hb.place("wall_2", Vector2i(sx, 0), 0.0, zf - HouseBuilder.THICK - z0, y, mat)
		# stucco quoins up the corners (the brick ones have stone)
		hb.corners(k, y, S, wall_col.lightened(0.18) if not brick else Color("#e8dcc8"))
		y += S
		if f < floors - 1:
			# a string course between the storeys
			k.box("plaster", Vector3(0, y + 0.06, zf - (d - 0.2) / 2.0 + 0.05), Vector3(w - 0.1, 0.12, d - 0.1), TRIM)
			y += 0.12
	var top := y
	# the gallery or balcony on every upper floor, under the roof's eave
	for i in decks.size():
		var dy: float = decks[i]
		_deck(k, w, zf, dy - 0.12, kind == "gallery")
		_railing(k, Vector3(-w / 2.0 + 0.03, dy, zf + GALLERY - 0.05), Vector3(w / 2.0 - 0.03, dy, zf + GALLERY - 0.05), 0.92)
		for sx in [-1.0, 1.0]:
			_railing(k, Vector3(sx * (w / 2.0 - 0.03), dy, zf + 0.05), Vector3(sx * (w / 2.0 - 0.03), dy, zf + GALLERY - 0.05), 0.92)
		if kind == "balcony":
			# iron brackets under it
			var bx := -w / 2.0 + 0.4
			while bx < w / 2.0 - 0.3:
				VBld._beam(k, "color", Vector3(bx, dy - 0.75, zf + 0.02), Vector3(bx, dy - 0.15, zf + GALLERY - 0.15), 0.05, IRON)
				bx += 1.2
		# hanging ferns between the posts
		var fx := -w / 2.0 + 1.0
		while fx < w / 2.0 - 0.5:
			_fern(k, Vector3(fx, dy + S - (0.65 if i == decks.size() - 1 else 0.45), zf + GALLERY - 0.3))
			fx += 2.0
	if kind == "gallery":
		# iron posts from the sidewalk to the roof, on the tiles' edges, and a light roof over the top floor
		for t in int(round(w)) + 1:
			var px := -w / 2.0 + float(t) + (0.05 if t == 0 else (-0.05 if t == int(round(w)) else 0.0))
			_iron_post(k, Vector3(px, 0.0, zf + GALLERY - 0.05), top + 0.02)
		_gallery_roof(k, w, zf, top)
	else:
		# a balcony on the top floor wears a little canopy of its own
		_gallery_roof(k, w, zf, top)
	# a cornice along the top of the front
	k.box("plaster", Vector3(0, top + 0.1, zf - 0.02), Vector3(w + 0.02, 0.2, 0.22), TRIM)
	var ridge := top
	match roof:
		"hip":
			ridge = VBld._hip(k, w, d - 0.1, top + 0.08, 0.62, 0.22, false, "slate", SLATE, TRIM)
			_chimney(k, Vector3(-w / 2.0 + 0.7, top, -d / 2.0 + 0.6), top + 1.5)
		"gable":
			ridge = VBld._gable(k, w, d - 0.1, top + 0.08, 0.95, 0.2, "slate", SLATE, "brick" if brick else "plaster", wall_col, TRIM)
			for dx in _dormer_spots(w, door_lx):
				_dormer(k, dx, top + 0.12, (d - 0.1) / 2.0 + 0.2, 0.95, wall_col, shutter)
			for sx in [-1.0, 1.0]:
				_chimney(k, Vector3(sx * (w / 2.0 - 0.35), top, 0.0), ridge + 0.55)
		_:
			# a flat roof behind a parapet, the parapet rising to a little pediment over the door
			k.box("tin", Vector3(0, top + 0.12, -0.05), Vector3(w - 0.2, 0.1, d - 0.3), Color("#7a7068"))
			k.box("plaster", Vector3(0, top + 0.45, zf - 0.08), Vector3(w, 0.5, 0.16), wall_col.lightened(0.08))
			k.box("plaster", Vector3(0, top + 0.72, zf - 0.08), Vector3(w + 0.06, 0.08, 0.24), TRIM)
			k.poly("plaster", [Vector3(door_lx - 0.8, top + 0.76, zf - 0.02), Vector3(door_lx + 0.8, top + 0.76, zf - 0.02), Vector3(door_lx, top + 1.2, zf - 0.02)], Vector3.BACK, TRIM)
			for sx in [-1.0, 1.0]:
				k.box("plaster", Vector3(sx * (w / 2.0 - 0.08), top + 0.45, 0.0), Vector3(0.16, 0.5, d - 0.3), wall_col)
			k.box("plaster", Vector3(0, top + 0.45, -d / 2.0 + 0.2), Vector3(w, 0.5, 0.16), wall_col)
			_chimney(k, Vector3(w / 2.0 - 0.6, top, -d / 2.0 + 0.6), top + 1.3)
			ridge = top + 1.2
	if commercial:
		_shop_sign(node, k, shop, w, door_lx, zf, decks[0] - 0.12, brand)
	if shop == "uncle":
		# Rafe's golden flute, on the gallery's railing over his door, facing the street
		VBld._rafe_flute_sign(node, b, decks[0] + 0.5)
		var flute: Node3D = node.get_node("RafeFluteSign")
		flute.position.z = zf + GALLERY + 0.02
	if shop == "electronics":
		_blade_sign(node, k, Vector3(w / 2.0 - 0.15, decks[0] + 0.35, zf + GALLERY + 0.05))
	if not outskirt and not commercial:
		# a lantern by the door
		k.box("color", Vector3(door_lx + 0.95, PLINTH + 2.05, zf + 0.06), Vector3(0.08, 0.08, 0.12), IRON)
		k.box("glow", Vector3(door_lx + 0.95, PLINTH + 1.9, zf + 0.14), Vector3(0.16, 0.24, 0.16), Color("#ffd890"))
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return ridge


## A span of a storey's front laid out in bays, a tall window in each with its shutters open against the wall (or
## plain wall where it's too narrow).
static func _bays(hb, k: VBld.Kit, a: float, b: float, y: float, zf: float, mat: Material, shutter: Color, pieces: Array) -> void:
	var span := b - a
	if span < 0.05:
		return
	if span < 1.05:
		hb.place("wall_1", Vector2i(0, 1), (a + b) / 2.0, span, y, mat)
		return
	var n := maxi(1, int(round(span / 1.55)))
	var share := span / n
	for i in n:
		var c := a + share * (i + 0.5)
		hb.place(pieces[i % pieces.size()], Vector2i(0, 1), c, share, y, mat)
		_shutters(k, c, share * 0.5, y, zf, shutter)


## Louvred shutters open flat against the wall either side of an opening `ow` wide, and a little sill under it.
static func _shutters(k: VBld.Kit, c: float, ow: float, y: float, zf: float, col: Color) -> void:
	var sy0 := y + 0.37
	var sh := 1.87
	var pw := ow * 0.5
	for sx in [-1.0, 1.0]:
		var px: float = c + sx * (ow / 2.0 + pw / 2.0 + 0.03)
		k.box("color", Vector3(px, sy0 + sh / 2.0, zf + 0.03), Vector3(pw, sh, 0.05), col)
		var ly := sy0 + 0.18
		while ly < sy0 + sh - 0.12:
			k.box("color", Vector3(px, ly, zf + 0.06), Vector3(pw - 0.06, 0.035, 0.02), col.darkened(0.25))
			ly += 0.16
	k.box("plaster", Vector3(c, sy0 - 0.03, zf + 0.06), Vector3(ow + 0.16, 0.07, 0.12), TRIM)


## A front door's surround: pilasters and a fanlight-style lintel in the trim colour, the door's colour on its panel.
static func _door_frame(k: VBld.Kit, x: float, dw: float, y: float, zf: float, col: Color) -> void:
	var ow := dw * 0.5
	for sx in [-1.0, 1.0]:
		k.box("plaster", Vector3(x + sx * (ow / 2.0 + 0.08), y + 1.1, zf + 0.04), Vector3(0.12, 2.2, 0.08), TRIM)
	k.box("plaster", Vector3(x, y + 2.18, zf + 0.05), Vector3(ow + 0.36, 0.14, 0.1), TRIM)
	k.box("glow", Vector3(x, y + 2.36, zf + 0.03), Vector3(ow - 0.05, 0.2, 0.04), Color("#ffe6a8"))


## A shop's display window across a span, with a painted stall riser in the shop's colour under it.
static func _shop_window(hb, k: VBld.Kit, a: float, b: float, y: float, zf: float, mat: Material, brand: Color) -> void:
	var span := b - a
	if span < 0.05:
		return
	if span < 1.2:
		hb.place("wall_1", Vector2i(0, 1), (a + b) / 2.0, span, y, mat)
		return
	hb.place("win_double_2", Vector2i(0, 1), (a + b) / 2.0, span, y, mat)
	k.box("color", Vector3((a + b) / 2.0, y + 0.2, zf + 0.04), Vector3(span * 0.7, 0.34, 0.06), brand.darkened(0.2))


## The floor of a gallery or balcony over the sidewalk: boards on a beam, with a fascia along the front.
static func _deck(k: VBld.Kit, w: float, zf: float, y: float, gallery: bool) -> void:
	k.box("planks", Vector3(0, y + 0.06, zf + GALLERY / 2.0), Vector3(w + (0.06 if gallery else -0.1), 0.12, GALLERY), Color("#8a6a4a"))
	k.box("color", Vector3(0, y - 0.04, zf + GALLERY - 0.04), Vector3(w + (0.08 if gallery else -0.08), 0.14, 0.08), IRON)


## A cast-iron lace railing from p0 to p1 (along x or z) on a deck at p0.y, `h` high: top and bottom rails, balusters,
## and a band of crossed lattice in the middle.
static func _railing(k: VBld.Kit, p0: Vector3, p1: Vector3, h: float) -> void:
	var y := p0.y
	var along := (p1 - p0)
	var len := along.length()
	if len < 0.05:
		return
	var dir := along / len
	for ry in [0.08, 0.3, 0.62, h]:
		VBld._beam(k, "color", Vector3(p0.x, y + ry, p0.z), Vector3(p1.x, y + ry, p1.z), 0.045 if ry == h else 0.03, IRON)
	var n := maxi(2, int(len / 0.13))
	for i in n + 1:
		var p := p0 + dir * len * float(i) / float(n)
		var c := Vector3(p.x, y, p.z)
		k.box("color", c + Vector3(0, 0.19, 0), Vector3(0.025, 0.22, 0.025), IRON)
		k.box("color", c + Vector3(0, (0.62 + h) / 2.0, 0), Vector3(0.025, h - 0.62, 0.025), IRON)
	# the lattice: crossing diagonals between the band's rails
	var m := maxi(1, int(len / 0.3))
	for i in m:
		var a := p0 + dir * len * float(i) / float(m)
		var b := p0 + dir * len * float(i + 1) / float(m)
		VBld._beam(k, "color", Vector3(a.x, y + 0.3, a.z), Vector3(b.x, y + 0.62, b.z), 0.022, IRON)
		VBld._beam(k, "color", Vector3(a.x, y + 0.62, a.z), Vector3(b.x, y + 0.3, b.z), 0.022, IRON)


## A slender cast-iron post with a little capital and a scrolled bracket at its top, from the ground up to `top`.
static func _iron_post(k: VBld.Kit, p: Vector3, top: float) -> void:
	k.box("color", Vector3(p.x, p.y + top / 2.0, p.z), Vector3(0.07, top, 0.07), IRON)
	k.box("color", Vector3(p.x, p.y + 0.06, p.z), Vector3(0.13, 0.12, 0.13), IRON)
	k.box("color", Vector3(p.x, p.y + top - 0.08, p.z), Vector3(0.12, 0.1, 0.12), IRON)
	VBld._beam(k, "color", Vector3(p.x, p.y + top - 0.55, p.z), Vector3(p.x, p.y + top - 0.12, p.z - 0.4), 0.03, IRON)


## The light tin roof over the top floor's gallery, from the wall's top out over the railing, and a frilled fascia.
static func _gallery_roof(k: VBld.Kit, w: float, zf: float, top: float) -> void:
	var y0 := top - 0.05
	var y1 := top - 0.3
	var ze := zf + GALLERY + 0.12
	VBld._slope(k, "tin", [Vector3(-w / 2.0 - 0.04, y0, zf), Vector3(w / 2.0 + 0.04, y0, zf), Vector3(w / 2.0 + 0.04, y1, ze), Vector3(-w / 2.0 - 0.04, y1, ze)], Color("#9aa4a0"), Vector3.RIGHT)
	k.poly("tin", [Vector3(-w / 2.0 - 0.04, y0 - 0.03, zf), Vector3(w / 2.0 + 0.04, y0 - 0.03, zf), Vector3(w / 2.0 + 0.04, y1 - 0.03, ze), Vector3(-w / 2.0 - 0.04, y1 - 0.03, ze)], Vector3.DOWN, Color("#6a706c"))
	k.box("color", Vector3(0, y1 - 0.08, ze), Vector3(w + 0.1, 0.14, 0.04), IRON)
	var x := -w / 2.0 + 0.1
	while x < w / 2.0 - 0.05:
		k.box("color", Vector3(x, y1 - 0.2, ze), Vector3(0.05, 0.1, 0.03), IRON)
		x += 0.18


## A fern in a hanging basket.
static func _fern(k: VBld.Kit, p: Vector3) -> void:
	k.box("color", p + Vector3(0, 0.3, 0), Vector3(0.015, 0.3, 0.015), IRON)
	k.box("color", p + Vector3(0, 0.08, 0), Vector3(0.24, 0.14, 0.24), Color("#8a5a3a"))
	k.box("leaf", p + Vector3(0, 0.2, 0), Vector3(0.36, 0.14, 0.36), FERN)
	k.box("leaf", p + Vector3(0, 0.0, 0), Vector3(0.46, 0.16, 0.46), FERN.darkened(0.1))
	k.box("leaf", p + Vector3(0, -0.14, 0), Vector3(0.3, 0.14, 0.3), FERN.darkened(0.18))


static func _chimney(k: VBld.Kit, p: Vector3, top: float) -> void:
	k.box("brick", Vector3(p.x, (p.y + top) / 2.0, p.z), Vector3(0.42, top - p.y, 0.42), Color(BRICK))
	k.box("stone", Vector3(p.x, top + 0.05, p.z), Vector3(0.52, 0.1, 0.52), BASE)


## Where the dormers go on a front slope: one per two tiles or so, clear of the middle (and so of the door's line).
static func _dormer_spots(w: float, _door_lx: float) -> Array:
	if w < 3.5:
		return [0.0]
	if w < 5.5:
		return [-w / 4.0, w / 4.0]
	return [-w / 3.0, 0.0, w / 3.0]


## A dormer on a roof slope whose eave is at (zeave, y0) and rises `slope` per unit towards z = 0: a little gabled box
## with a shuttered window, standing out of the slope.
static func _dormer(k: VBld.Kit, x: float, y0: float, zeave: float, slope: float, wall: Color, shutter: Color) -> void:
	var zfront := zeave * 0.55
	var ybase := y0 + (zeave - zfront) * slope
	var dw := 0.78
	var dh := 0.72
	var dz := zfront - 0.05
	k.box("plaster", Vector3(x, ybase + dh / 2.0 - 0.15, dz / 2.0 + 0.0), Vector3(dw, dh + 0.3, dz), wall.lightened(0.1))
	k.box("glow", Vector3(x, ybase + dh / 2.0 - 0.02, zfront - 0.03), Vector3(0.32, 0.42, 0.04), Color("#cfe4ee"))
	k.box("plaster", Vector3(x, ybase + 0.16, zfront), Vector3(0.44, 0.06, 0.08), TRIM)
	for sx in [-1.0, 1.0]:
		k.box("color", Vector3(x + sx * 0.25, ybase + dh / 2.0 - 0.02, zfront - 0.01), Vector3(0.14, 0.46, 0.04), shutter)
	var top := ybase + dh - 0.12
	var peak := top + 0.36
	for sx in [-1.0, 1.0]:
		VBld._slope(k, "slate", [Vector3(x, peak, zfront + 0.1), Vector3(x + sx * (dw / 2.0 + 0.08), top, zfront + 0.1), Vector3(x + sx * (dw / 2.0 + 0.08), top, 0.0), Vector3(x, peak, 0.0)], SLATE, Vector3.BACK)
	k.poly("plaster", [Vector3(x - dw / 2.0, top, zfront), Vector3(x + dw / 2.0, top, zfront), Vector3(x, peak - 0.04, zfront)], Vector3.BACK, TRIM)


## The shop's sign: a board hanging from the gallery's beam over the door with the shop's icon, and a striped awning in
## the shop's colour over the shop front under the gallery.
static func _shop_sign(node: Node3D, k: VBld.Kit, shop: String, w: float, door_lx: float, zf: float, deck_y: float, brand: Color) -> void:
	var sy := deck_y - 0.42
	var sz := zf + GALLERY - 0.08
	for sx in [-0.62, 0.62]:
		k.box("color", Vector3(door_lx + sx, deck_y - 0.12, sz), Vector3(0.03, 0.2, 0.03), IRON)
	k.box("planks", Vector3(door_lx, sy, sz), Vector3(1.5, 0.48, 0.07), Color("#e8dcc0"))
	k.box("color", Vector3(door_lx, sy, sz + 0.04), Vector3(1.32, 0.34, 0.02), brand.darkened(0.25))
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon(shop)
	icon.position = Vector3(door_lx, sy - 0.02, VBld._on_face(icon.mesh, sz + 0.05))
	node.add_child(icon)
	# the awning, from the wall under the deck sloping out (its lower edge well above everyone's heads)
	_awning(k, -w / 2.0 + 0.1, w / 2.0 - 0.1, deck_y - 0.25, zf, 0.62, brand)


## A striped awning from x0 to x1, sloping from (zf, y) out `depth`, with a valance along its front.
static func _awning(k: VBld.Kit, x0: float, x1: float, y: float, zf: float, depth: float, brand: Color) -> void:
	var x := x0
	var i := 0
	while x < x1 - 0.01:
		var x2 := minf(x + 0.42, x1)
		k.poly("color", [Vector3(x, y, zf), Vector3(x2, y, zf), Vector3(x2, y - 0.2, zf + depth), Vector3(x, y - 0.2, zf + depth)], Vector3(0, 0.95, 0.3), brand if i % 2 == 0 else Color("#f4f0e4"))
		x = x2
		i += 1
	k.box("color", Vector3((x0 + x1) / 2.0, y - 0.27, zf + depth + 0.01), Vector3(x1 - x0, 0.14, 0.03), brand.darkened(0.15))


## Sparkwire's blade sign: a tall blue board with the lightning bolt standing out from the gallery's corner.
static func _blade_sign(node: Node3D, k: VBld.Kit, p: Vector3) -> void:
	var brand := Color("#3a6ab0")
	k.box("color", p + Vector3(0, 0.9, 0), Vector3(0.9, 1.9, 0.14), Color("#f4f4f0"))
	k.box("color", p + Vector3(0, 0.9, 0), Vector3(0.76, 1.76, 0.18), brand)
	k.box("glow", p + Vector3(0, 1.85, 0), Vector3(0.9, 0.05, 0.16), Color("#5af0ff"))
	k.box("glow", p + Vector3(0, -0.05, 0), Vector3(0.9, 0.05, 0.16), Color("#5af0ff"))
	var bolt := MeshInstance3D.new()
	bolt.mesh = VP.icon("electronics")
	bolt.scale = Vector3.ONE * 1.1
	bolt.position = Vector3(p.x, p.y + 0.85, VBld._on_face(bolt.mesh, p.z + 0.09) + 0.02)
	node.add_child(bolt)


## The French Market on the riverfront: a long open arcade of cream stucco piers and arches under a slate hip roof,
## market stalls of fruit and vegetables under striped awnings inside, and lanterns hanging in the arches. It has no
## door: you look in through the arches from the sidewalk.
static func _market(node: Node3D, w: float, d: float) -> void:
	var k := VBld.Kit.new()
	var wall := Color("#efe2c4")
	k.box("stone", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.06, PLINTH, d - 0.06), BASE)
	var zf := d / 2.0 - 0.25
	var h := 2.9
	var bays := int(round(w / 1.6))
	var bw := (w - 0.5) / float(bays)
	for side in [-1.0, 1.0]:
		for i in bays + 1:
			var x := -w / 2.0 + 0.25 + float(i) * bw
			k.box("plaster", Vector3(x, PLINTH + h / 2.0, side * zf), Vector3(0.36, h, 0.36), wall)
		k.box("plaster", Vector3(0, PLINTH + h + 0.25, side * zf), Vector3(w - 0.1, 0.5, 0.4), wall)
		for i in bays:
			# the haunches of each arch
			var a := -w / 2.0 + 0.25 + float(i) * bw + 0.18
			var b := a + bw - 0.36
			VBld._beam(k, "plaster", Vector3(a, PLINTH + h - 0.5, side * zf), Vector3(a + 0.42, PLINTH + h + 0.02, side * zf), 0.3, wall)
			VBld._beam(k, "plaster", Vector3(b, PLINTH + h - 0.5, side * zf), Vector3(b - 0.42, PLINTH + h + 0.02, side * zf), 0.3, wall)
			# a lantern hanging in every other arch
			if i % 2 == 0 and side > 0.0:
				var lx := (a + b) / 2.0
				k.box("color", Vector3(lx, PLINTH + h - 0.2, side * zf), Vector3(0.02, 0.4, 0.02), IRON)
				k.box("glow", Vector3(lx, PLINTH + h - 0.5, side * zf), Vector3(0.16, 0.24, 0.16), Color("#ffe0a0"))
	for sx in [-1.0, 1.0]:
		k.box("plaster", Vector3(sx * (w / 2.0 - 0.25), PLINTH + h / 2.0, 0), Vector3(0.36, h, 0.36), wall)
		k.box("plaster", Vector3(sx * (w / 2.0 - 0.25), PLINTH + h + 0.25, 0), Vector3(0.4, 0.5, d - 0.5), wall)
	var top := PLINTH + h + 0.5
	k.box("plaster", Vector3(0, top + 0.06, 0), Vector3(w + 0.1, 0.12, d + 0.04), TRIM)
	VBld._hip(k, w, d, top + 0.1, 0.5, 0.3, false, "slate", SLATE, TRIM)
	k.box("color", Vector3(0, top - 0.02, 0), Vector3(w - 0.6, 0.04, d - 0.6), Color("#5a4a3a"))
	# the stalls down the middle: trestle tables of crates under striped awnings
	var produce := [Color("#d8402e"), Color("#f0c838"), Color("#ee8a2a"), Color("#6aa83a"), Color("#7a3a8a"), Color("#f4e4c0")]
	var stripes := [Color("#2e8a4a"), Color("#c23a32"), Color("#2a5a9a")]
	for i in bays:
		if i % 2 == 1:
			continue
		var cx := -w / 2.0 + 0.25 + (float(i) + 0.5) * bw
		for lx in [-0.5, 0.5]:
			k.box("planks", Vector3(cx + lx * 0.9, 0.38 + PLINTH, 0), Vector3(0.06, 0.76, 0.6), WOOD)
		k.box("planks", Vector3(cx, 0.8 + PLINTH, 0), Vector3(1.1, 0.08, 0.7), WOOD.lightened(0.1))
		for j in 3:
			var col: Color = produce[(i + j * 2) % produce.size()]
			k.box("planks", Vector3(cx - 0.35 + j * 0.35, 0.94 + PLINTH, 0.08), Vector3(0.3, 0.2, 0.36), WOOD)
			k.box("leaf" if col == produce[3] else "color", Vector3(cx - 0.35 + j * 0.35, 1.07 + PLINTH, 0.08), Vector3(0.26, 0.08, 0.32), col)
		var stripe: Color = stripes[(i / 2) % stripes.size()]
		var x := cx - 0.65
		var n := 0
		while x < cx + 0.64:
			var x2 := minf(x + 0.26, cx + 0.65)
			k.poly("color", [Vector3(x, PLINTH + 2.0, -0.3), Vector3(x2, PLINTH + 2.0, -0.3), Vector3(x2, PLINTH + 1.75, 0.5), Vector3(x, PLINTH + 1.75, 0.5)], Vector3(0, 0.95, 0.3), stripe if n % 2 == 0 else Color("#f4f0e4"))
			x = x2
			n += 1
		for px in [-0.6, 0.6]:
			k.box("color", Vector3(cx + px, PLINTH + 0.95, 0.48), Vector3(0.04, 1.6, 0.04), IRON)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


# ================================================================ cottages and shotguns
## One storey on a row with a street close behind it: a Creole cottage under a steep side gable with dormers and a
## deep eave over the sidewalk, a shotgun house gable-end to the street behind its porch, or a shop (a cottage with a
## shop front, an awning and a sign). Returns the height of the walls.
static func _cottage(node: Node3D, b: Dictionary, w: float, d: float, door_lx: float, locked: bool, rng: RandomNumberGenerator) -> float:
	var shop: String = b["shop"]
	var commercial: bool = shop in VBld.COMMERCIAL
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	hb.rng.seed = rng.randi()
	var k := VBld.Kit.new()
	var paint := Color(STUCCO[rng.randi_range(0, STUCCO.size() - 1)])
	var shotgun := not commercial and rng.randf() < 0.5
	var wall_kind := "planks" if shotgun else "plaster"
	var mat: Material = HouseBuilder.wall_material(wall_kind, paint)
	var shutter := Color(SHUTTERS[rng.randi_range(0, SHUTTERS.size() - 1)])
	var brand := Color(VBld.SHOP_ROOF.get(shop, "#c84040"))
	var zf := d / 2.0 - HouseBuilder.INSET
	# a shotgun stands back behind its porch (on the plot, never over the sidewalk)
	var porch := 0.95 if shotgun else 0.0
	var hb_d := d - porch
	hb.d = hb_d
	var shift := -porch / 2.0
	var x0 := -w / 2.0 + HouseBuilder.INSET + HouseBuilder.THICK
	var x1 := w / 2.0 - HouseBuilder.INSET - HouseBuilder.THICK
	var lift := 0.3 if shotgun else PLINTH
	# the walls are laid round a plot `porch` shallower, moved back: a holder node shifts them
	var walls := Node3D.new()
	walls.position.z = shift
	node.add_child(walls)
	hb.node = walls
	var wz := hb_d / 2.0 - HouseBuilder.INSET
	k.box("stone", Vector3(0, lift / 2.0, shift), Vector3(w - 0.08, lift, hb_d - 0.08), BASE if not shotgun else Color("#8a7a6a"))
	var dw := 1.5
	var door: String = "door_1" if locked else DOORS[rng.randi_range(0, DOORS.size() - 1)]
	hb.place(door, Vector2i(0, 1), door_lx, dw, lift, mat)
	_door_frame(k, door_lx, dw, lift, wz + shift, shutter)
	if commercial:
		_shop_window(hb, k, x0, door_lx - dw / 2.0, lift, wz + shift, mat, brand)
		_shop_window(hb, k, door_lx + dw / 2.0, x1, lift, wz + shift, mat, brand)
	else:
		_bays(hb, k, x0, door_lx - dw / 2.0, lift, wz + shift, mat, shutter, TALL_WINDOWS)
		_bays(hb, k, door_lx + dw / 2.0, x1, lift, wz + shift, mat, shutter, TALL_WINDOWS)
	if locked:
		VBld._door_lock(k, Vector3(door_lx, lift + 1.0, wz + shift + 0.02), 0.8, 1.9)
	hb.place("wall_2", Vector2i(0, -1), 0.0, x1 - x0, lift, mat)
	var z0 := -hb_d / 2.0 + HouseBuilder.INSET + HouseBuilder.THICK
	for sx in [-1, 1]:
		hb.place("wall_2", Vector2i(sx, 0), 0.0, wz - HouseBuilder.THICK - z0, lift, mat)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cp := Vector3(sx * (w / 2.0 - HouseBuilder.INSET - HouseBuilder.THICK / 2.0), lift + S / 2.0, sz * (hb_d / 2.0 - HouseBuilder.INSET - HouseBuilder.THICK / 2.0) + shift)
			k.box("planks", cp, Vector3(HouseBuilder.THICK + 0.1, S, HouseBuilder.THICK + 0.1), paint.lightened(0.2) if not shotgun else TRIM)
	var top := lift + S
	var ridge := top
	if shotgun:
		ridge = _shotgun_roof(k, w, hb_d, top, shift, paint, shutter)
		# the porch: a deck a step up, turned posts with brackets, under the roof's front
		var pz0 := wz + shift
		var pz1 := d / 2.0 - 0.06
		k.box("planks", Vector3(0, lift - 0.05, (pz0 + pz1) / 2.0), Vector3(w - 0.1, 0.1, pz1 - pz0), Color("#9a7a5a"))
		k.box("stone", Vector3(door_lx, 0.08, pz1 - 0.12), Vector3(1.2, 0.16, 0.26), BASE)
		for sx in [-1.0, 1.0]:
			var px: float = sx * (w / 2.0 - 0.12)
			k.box("color", Vector3(px, lift + (top - lift) / 2.0, pz1 - 0.06), Vector3(0.12, top - lift, 0.12), TRIM)
			VBld._beam(k, "color", Vector3(px, top - 0.55, pz1 - 0.06), Vector3(px - sx * 0.45, top - 0.06, pz1 - 0.06), 0.05, TRIM)
		# gingerbread: a frieze of little brackets along the porch's beam
		k.box("color", Vector3(0, top - 0.12, pz1 - 0.06), Vector3(w - 0.1, 0.14, 0.1), TRIM)
		var gx := -w / 2.0 + 0.4
		while gx < w / 2.0 - 0.35:
			k.box("color", Vector3(gx, top - 0.26, pz1 - 0.06), Vector3(0.06, 0.16, 0.04), TRIM)
			gx += 0.22
	else:
		# the Creole cottage's steep side gable, its front reaching out as an eave over the step, with dormers
		var slate := rng.randf() < 0.6
		ridge = VBld._gable(k, w, d - 0.1, top, 1.05, 0.45, "slate" if slate else "tile", SLATE if slate else Color("#b8624a"), wall_kind, paint, TRIM)
		if not commercial:
			for dx in _dormer_spots(w, door_lx):
				_dormer(k, dx, top + 0.04, (d - 0.1) / 2.0 + 0.45, 1.05, paint, shutter)
		_chimney(k, Vector3(w / 2.0 - 0.45, top, -0.2), ridge + 0.4)
	if commercial:
		_awning(k, -w / 2.0 + 0.15, w / 2.0 - 0.15, lift + 2.42, wz + shift, 0.75, brand)
		# the sign board on the wall above the awning
		var sy := lift + 2.7
		k.box("planks", Vector3(door_lx, sy, wz + shift + 0.05), Vector3(1.6, 0.44, 0.08), Color("#e8dcc0"))
		k.box("color", Vector3(door_lx, sy, wz + shift + 0.09), Vector3(1.42, 0.32, 0.02), brand.darkened(0.25))
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(shop)
		icon.position = Vector3(door_lx, sy - 0.02, VBld._on_face(icon.mesh, wz + shift + 0.1))
		node.add_child(icon)
		if shop == "cafe":
			# café tables under the awning's ends
			for sx in [-1.0, 1.0]:
				var tx: float = door_lx + sx * 1.35
				if absf(tx) < w / 2.0 - 0.3:
					_bistro(k, Vector3(tx, lift, wz + shift + 0.45))
	else:
		k.box("color", Vector3(door_lx + 0.9, lift + 2.0, wz + shift + 0.06), Vector3(0.08, 0.08, 0.12), IRON)
		k.box("glow", Vector3(door_lx + 0.9, lift + 1.85, wz + shift + 0.14), Vector3(0.16, 0.24, 0.16), Color("#ffd890"))
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return ridge


## A shotgun house's roof: gable-end to the street (its ridge running back from the front), the gable's triangle
## boarded and painted with a little vent window, overhanging the porch in front. Returns the ridge's height.
static func _shotgun_roof(k: VBld.Kit, w: float, d: float, top: float, shift: float, paint: Color, shutter: Color) -> float:
	var hw := w / 2.0 + 0.15
	var zb := -d / 2.0 - 0.15 + shift
	var ze := d / 2.0 + shift + 1.0
	var rise := hw * 0.85
	var y0 := top + 0.04
	var ridge := y0 + rise
	for sx in [-1.0, 1.0]:
		VBld._slope(k, "tin", [Vector3(sx * hw, y0, zb), Vector3(sx * hw, y0, ze), Vector3(0, ridge, ze), Vector3(0, ridge, zb)], Color("#8c969a") if sx > 0 else Color("#808a8e"), Vector3.BACK)
		k.box("color", Vector3(sx * hw, y0 - 0.03, (zb + ze) / 2.0), Vector3(0.07, 0.07, ze - zb), TRIM)
	# the gable ends: front (over the porch) and back
	var gw := (w - 0.2) / 2.0
	for z in [ze - 0.04, zb + 0.15]:
		k.poly("planks", [Vector3(-gw, top, z), Vector3(gw, top, z), Vector3(0, ridge - 0.04, z)], Vector3.BACK if z > shift else Vector3.FORWARD, paint.lightened(0.08))
	k.box("glow", Vector3(0, top + rise * 0.4, ze - 0.02), Vector3(0.36, 0.3, 0.03), Color("#cfe4ee"))
	k.box("color", Vector3(0, top + rise * 0.4, ze - 0.01), Vector3(0.44, 0.04, 0.03), shutter)
	k.box("tin", Vector3(0, ridge + 0.02, (zb + ze) / 2.0), Vector3(0.14, 0.08, ze - zb + 0.04), Color("#6a7478"))
	return ridge


## A little round café table with two chairs.
static func _bistro(k: VBld.Kit, p: Vector3) -> void:
	VBld._column(k, "color", p, 0.04, 0.68, 6, IRON)
	VBld._column(k, "color", p + Vector3(0, 0.68, 0), 0.26, 0.04, 8, Color("#f4f0e8"))
	for sx in [-1.0, 1.0]:
		var c := p + Vector3(sx * 0.36, 0, 0)
		k.box("color", c + Vector3(0, 0.22, 0), Vector3(0.05, 0.44, 0.05), IRON)
		k.box("color", c + Vector3(0, 0.44, 0), Vector3(0.24, 0.04, 0.24), Color("#2e6a4a"))
		k.box("color", c + Vector3(sx * 0.1, 0.66, 0), Vector3(0.04, 0.44, 0.24), Color("#2e6a4a"))


# ================================================================ the bell tower (Sky Tower)
## The Sky Tower as the square's bell tower: a square tower of white stucco (the door in front, a round window over it),
## a clock stage, a belfry of tall arched openings with a balustrade round its top and urns on the corners, then a
## tall eight-sided black slate spire with a gilt cross-finial. Tempestrix rests on a little iron balcony on the clock
## stage, facing the square. Returns the height of the tower's top.
static func _bell_tower(node: Node3D, w: float, d: float, door_lx: float) -> float:
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	var k := VBld.Kit.new()
	var white := Color("#f4f0e8")
	var mat: Material = HouseBuilder.wall_material("plaster", white)
	var zf := d / 2.0 - HouseBuilder.INSET
	var x0 := -w / 2.0 + HouseBuilder.INSET + HouseBuilder.THICK
	var x1 := w / 2.0 - HouseBuilder.INSET - HouseBuilder.THICK
	k.box("stone", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.04, PLINTH, d - 0.04), BASE)
	k.box("stone", Vector3(door_lx, 0.07, zf + 0.2), Vector3(1.5, 0.14, 0.32), BASE.lightened(0.08))
	var y := PLINTH
	var pieces := [["door_3", "wall_2"], ["win_small_1", "win_small_1"], ["wall_2", "wall_2"]]
	for f in 3:
		var front: String = pieces[f][0]
		if f == 0:
			hb.place(front, Vector2i(0, 1), door_lx, 1.6, y, mat)
			_door_frame(k, door_lx, 1.6, y, zf, Color("#3a2a22"))
			for side in [[x0, door_lx - 0.8], [door_lx + 0.8, x1]]:
				if side[1] - side[0] > 0.05:
					hb.place("wall_1", Vector2i(0, 1), (side[0] + side[1]) / 2.0, side[1] - side[0], y, mat)
		else:
			hb.place(front, Vector2i(0, 1), 0.0, x1 - x0, y, mat)
		hb.place(pieces[f][1], Vector2i(0, -1), 0.0, x1 - x0, y, mat)
		for sx in [-1, 1]:
			hb.place("win_small_1" if f == 1 else "wall_2", Vector2i(sx, 0), 0.0, x1 - x0, y, mat)
		hb.corners(k, y, S, Color("#e6e0d4"))
		y += S
		k.box("plaster", Vector3(0, y + 0.07, 0), Vector3(w + 0.1, 0.14, d + 0.1), TRIM)
		y += 0.14
	# the clock on the third stage's front
	var cy := y - 0.14 - S * 0.5
	var ring := VBld._loop(Vector2(0, cy), 0.62, 0.62, 16)
	for i in 16:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % 16]
		k.poly("color", [Vector3(0, cy, zf + 0.06), Vector3(a.x, a.y, zf + 0.06), Vector3(b.x, b.y, zf + 0.06)], Vector3.BACK, Color("#fbf8ee"))
		k.poly("color", [Vector3(a.x * 1.12, (a.y - cy) * 1.12 + cy, zf + 0.04), Vector3(b.x * 1.12, (b.y - cy) * 1.12 + cy, zf + 0.04), Vector3(b.x, b.y, zf + 0.05), Vector3(a.x, a.y, zf + 0.05)], Vector3.BACK, Color("#c8a040"))
	k.box("color", Vector3(0, cy + 0.2, zf + 0.08), Vector3(0.05, 0.42, 0.02), Color("#2a2a2a"))
	k.box("color", Vector3(0.14, cy, zf + 0.08), Vector3(0.3, 0.05, 0.02), Color("#2a2a2a"))
	# the belfry: a narrower stage of four tall arched openings, dark inside, with a bell
	var bw := w - 0.6
	var bh := 2.2
	var by := y
	k.box("plaster", Vector3(0, by + bh / 2.0, 0), Vector3(bw - 0.5, bh, bw - 0.5), Color("#3a3430"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("plaster", Vector3(sx * (bw / 2.0 - 0.18), by + bh / 2.0, sz * (bw / 2.0 - 0.18)), Vector3(0.36, bh, 0.36), white)
	for n in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var c: Vector3 = n * (bw / 2.0 - 0.1)
		var across := Vector3(absf(n.z), 0, absf(n.x))
		k.box("plaster", Vector3(c.x, by + bh - 0.25, c.z), across * (bw - 0.3) + Vector3(0, 0.5, 0) + Vector3(absf(n.x), 0, absf(n.z)) * 0.2, white)
	VBld._column(k, "brass", Vector3(0, by + 0.9, 0), 0.32, 0.6, 8, Color("#c8a040"))
	y = by + bh
	k.box("plaster", Vector3(0, y + 0.08, 0), Vector3(bw + 0.2, 0.16, bw + 0.2), TRIM)
	y += 0.16
	# a balustrade round the belfry's top, urns on its corners
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("plaster", Vector3(sx * (bw / 2.0), y + 0.4, sz * (bw / 2.0)), Vector3(0.2, 0.8, 0.2), TRIM)
			VBld._column(k, "plaster", Vector3(sx * (bw / 2.0), y + 0.8, sz * (bw / 2.0)), 0.12, 0.28, 8, TRIM)
	for e in [[Vector3(-bw / 2.0, y, bw / 2.0), Vector3(bw / 2.0, y, bw / 2.0)], [Vector3(-bw / 2.0, y, -bw / 2.0), Vector3(bw / 2.0, y, -bw / 2.0)],
			[Vector3(-bw / 2.0, y, -bw / 2.0), Vector3(-bw / 2.0, y, bw / 2.0)], [Vector3(bw / 2.0, y, -bw / 2.0), Vector3(bw / 2.0, y, bw / 2.0)]]:
		_balusters(k, e[0], e[1], 0.55, TRIM)
	# the spire: eight black slate faces rising high, a gilt ball and cross
	var sr := (bw - 0.5) / 2.0
	var spts := VBld._loop(Vector2.ZERO, sr, sr, 8, PI / 8.0)
	VBld._skirt(k, "slate", spts, y, 0.4, Color("#2e3238"), Vector2.ZERO)
	var rise := 4.2
	VBld._spire(k, "slate", spts, y + 0.4, Vector2.ZERO, rise, Color("#34383e"))
	var tip := y + 0.4 + rise
	VBld._column(k, "brass", Vector3(0, tip - 0.1, 0), 0.04, 0.9, 6, Color("#e0b850"))
	VBld._column(k, "brass", Vector3(0, tip + 0.3, 0), 0.1, 0.16, 8, Color("#f0c860"))
	k.box("brass", Vector3(0, tip + 0.62, 0), Vector3(0.36, 0.06, 0.06), Color("#e0b850"))
	# Tempestrix on its little balcony on the clock stage, facing the square, its wings beating over the rail
	var balc_y := PLINTH + S + 0.14 + 0.25
	k.box("planks", Vector3(0, balc_y - 0.05, zf + 0.42), Vector3(1.6, 0.1, 0.8), Color("#8a6a4a"))
	_railing(k, Vector3(-0.8, balc_y, zf + 0.8), Vector3(0.8, balc_y, zf + 0.8), 0.7)
	for sx in [-0.6, 0.6]:
		VBld._beam(k, "color", Vector3(sx, balc_y - 0.6, zf + 0.02), Vector3(sx, balc_y - 0.1, zf + 0.7), 0.05, IRON)
	var bird := BeastModel.rig(RaceDB.genes(RaceDB.of_form("owl_3")), 1.25)
	bird.position = Vector3(0, balc_y, zf + 0.55)
	bird.rotation.y = -PI / 2.0
	bird.name = "Bird"
	node.add_child(bird)
	# its sign over the door
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("skytower")
	icon.position = Vector3(door_lx, PLINTH + 2.65, VBld._on_face(icon.mesh, zf + 0.05))
	node.add_child(icon)
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return tip


## Turned balusters between two points on a rail of height h, with a coping on top.
static func _balusters(k: VBld.Kit, p0: Vector3, p1: Vector3, h: float, col: Color) -> void:
	var along := p1 - p0
	var len := along.length()
	var n := maxi(2, int(len / 0.2))
	for i in range(1, n):
		var p := p0 + along * float(i) / float(n)
		k.box("plaster", p + Vector3(0, h * 0.25, 0), Vector3(0.09, h * 0.5, 0.09), col)
		k.box("plaster", p + Vector3(0, h * 0.62, 0), Vector3(0.06, h * 0.26, 0.06), col)
	var mid := (p0 + p1) / 2.0
	var ax := Vector3(absf(along.x) + 0.12, 0.08, absf(along.z) + 0.12)
	ax = Vector3(maxf(ax.x, 0.16), ax.y, maxf(ax.z, 0.16))
	k.box("plaster", mid + Vector3(0, h + 0.04, 0), ax, col)


# ================================================================ the arena
## The arena: an oval of pale limestone (an arcade of tall windows below, small ones above, a pilaster at every
## corner, a cornice) under a mansard ring of slate with a glazed lantern over the ring, Mardi Gras pennants round its
## rim; at the front, on the door's tile, an entrance pavilion with a tall mansard roof, iron cresting and a clock, an
## iron balcony over the great door, banners in purple, green and gold either side and gas lamps by the steps.
static func _arena(node: Node3D, w: float, d: float, door_lx: float, locked: bool) -> float:
	var stone := LIMESTONE
	var dark := stone.darkened(0.2)
	# smooth cream render over the walls (dressed stone only at the plinth, piers and cornices)
	var mat: Material = HouseBuilder.wall_material("plaster", stone)
	var k := VBld.Kit.new()
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	var y0 := PLINTH
	var top := y0 + S * 2.0
	var c := Vector2(0.0, -0.22)
	var ax := w / 2.0 - 0.2
	var az := d / 2.0 - 0.38
	var n := 18
	var ring := VBld._loop(c, ax, az, n, PI / n)
	var gx0 := door_lx - 1.55
	var gx1 := door_lx + 1.55
	var gz1 := d / 2.0 - HouseBuilder.INSET
	var gz0 := c.y + az * 0.45
	VBld._plinth(k, VBld._scaled(ring, c, 1.025), c, y0, dark)
	k.box("stone", Vector3((gx0 + gx1) / 2.0, y0 / 2.0, (gz0 + gz1) / 2.0 + 0.04), Vector3(gx1 - gx0 + 0.16, y0, gz1 - gz0 + 0.08), dark)
	k.box("stone", Vector3(door_lx, 0.07, gz1 + 0.24), Vector3(1.7, 0.14, 0.4), dark.lightened(0.1))
	var hidden := func(p: Vector2) -> bool: return p.x > gx0 - 0.3 and p.x < gx1 + 0.3 and p.y > gz0
	for i in n:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		if hidden.call((a + b) / 2.0):
			continue
		hb.span("win_1", a, b, y0, mat, c)
		hb.span("win_small_1", a, b, y0 + S, mat, c)
	for p in ring:
		if not hidden.call(p):
			VBld._column(k, "stone", Vector3(p.x, y0, p.y), 0.16, S * 2.0, 6, stone.lightened(0.05))
	for cy in [y0 + S, top]:
		VBld._ledge(k, "stone", VBld._scaled(ring, c, 1.045), ring, c, cy - 0.08, 0.16, TRIM)
	# the mansard ring: a steep slate slope round the rim, a gentle one above it, then the lantern over the ring
	var m1 := VBld._scaled(ring, c, 0.93)
	var m2 := VBld._scaled(ring, c, 0.8)
	_frustum(k, "slate", VBld._scaled(ring, c, 1.02), m1, top + 0.08, top + 1.0, SLATE, c)
	_frustum(k, "slate", m1, m2, top + 1.0, top + 1.25, SLATE.lightened(0.08), c)
	VBld._band(k, "tin", m2, VBld._fill(c, n), top + 1.25, Color("#6e6a64"))
	var sky := VBld._scaled(ring, c, 0.42)
	VBld._skirt(k, "stone", sky, top + 1.25, 0.3, dark, c)
	VBld._band(k, "color", sky, VBld._fill(c, n), top + 1.52, Color("#a8c8d8"))
	VBld._skirt(k, "color", VBld._scaled(ring, c, 0.43), top + 1.52, 0.06, IRON, c)
	var i2 := 0
	for i in n:
		var p: Vector2 = (ring[i] as Vector2).lerp(c, 0.07)
		if hidden.call(p) or i % 2 == 1:
			continue
		VBld._column(k, "color", Vector3(p.x, top + 1.0, p.y), 0.04, 1.2, 4, IRON)
		VBld._pennant(k, Vector3(p.x, top + 2.2, p.y), MARDI_GRAS[i2 % 3])
		i2 += 1
	# the entrance pavilion: two storeys of limestone, the great door, a tall window over it
	var gc := Vector2((gx0 + gx1) / 2.0, (gz0 + gz1) / 2.0)
	var dw := 1.4
	hb.span("door_1" if locked else "door_3", Vector2(door_lx - dw / 2.0, gz1), Vector2(door_lx + dw / 2.0, gz1), y0, mat, gc)
	hb.span("wall_1", Vector2(gx0, gz1), Vector2(door_lx - dw / 2.0, gz1), y0, mat, gc)
	hb.span("wall_1", Vector2(door_lx + dw / 2.0, gz1), Vector2(gx1, gz1), y0, mat, gc)
	hb.span("win_3", Vector2(door_lx - 0.95, gz1), Vector2(door_lx + 0.95, gz1), y0 + S, mat, gc)
	hb.span("wall_1", Vector2(gx0, gz1), Vector2(door_lx - 0.95, gz1), y0 + S, mat, gc)
	hb.span("wall_1", Vector2(door_lx + 0.95, gz1), Vector2(gx1, gz1), y0 + S, mat, gc)
	for gx in [gx0, gx1]:
		for fl in 2:
			hb.span("wall_2" if fl == 0 else "win_small_1", Vector2(gx, gz0), Vector2(gx, gz1), y0 + S * fl, mat, gc)
		# quoins up the pavilion's corners
		VBld._column(k, "stone", Vector3(gx, y0, gz1 - 0.05), 0.17, S * 2.0, 4, TRIM, PI / 4.0)
	_door_frame(k, door_lx, dw, y0, gz1, Color("#2a3a5a"))
	hb.finish()
	k.box("stone", Vector3(gc.x, top + 0.06, gc.y + 0.02), Vector3(gx1 - gx0 + 0.2, 0.16, gz1 - gz0 + 0.2), TRIM)
	# its mansard: steep slate sides with a dormer and a clock in front, a flat top with iron cresting
	var low := [Vector2(gx0 - 0.05, gz0 - 0.05), Vector2(gx1 + 0.05, gz0 - 0.05), Vector2(gx1 + 0.05, gz1 + 0.05), Vector2(gx0 - 0.05, gz1 + 0.05)]
	var high := VBld._scaled(low, gc, 0.78)
	var mt := top + 0.14
	var mh := 1.9
	_frustum(k, "slate", low, high, mt, mt + mh, SLATE.darkened(0.08), gc)
	VBld._band(k, "slate", high, VBld._fill(gc, 4), mt + mh, SLATE.darkened(0.2))
	var crest_y := mt + mh
	for e in 4:
		var a: Vector2 = high[e]
		var b: Vector2 = high[(e + 1) % 4]
		var len := a.distance_to(b)
		var cnt := int(len / 0.16)
		for j in cnt + 1:
			var p := a.lerp(b, float(j) / float(maxi(1, cnt)))
			k.box("color", Vector3(p.x, crest_y + 0.16, p.y), Vector3(0.03, 0.32 if j % 2 == 0 else 0.2, 0.03), IRON)
		VBld._beam(k, "color", Vector3(a.x, crest_y + 0.12, a.y), Vector3(b.x, crest_y + 0.12, b.y), 0.03, IRON)
	# the pavilion's clock on the front slope, framed in gilt
	var cz := gz1 + 0.05 - 0.45 * 0.22 * (gz1 + 0.05 - gc.y)
	var cyc := mt + mh * 0.45
	var cring := VBld._loop(Vector2(door_lx, cyc), 0.48, 0.48, 16)
	for i in 16:
		var a: Vector2 = cring[i]
		var b: Vector2 = cring[(i + 1) % 16]
		k.poly("color", [Vector3(door_lx, cyc, cz + 0.12), Vector3(a.x, a.y, cz + 0.12), Vector3(b.x, b.y, cz + 0.12)], Vector3.BACK, Color("#fbf8ee"))
	k.box("color", Vector3(door_lx, cyc, cz + 0.06), Vector3(1.2, 1.2, 0.1), Color("#c8a040"))
	k.box("color", Vector3(door_lx, cyc + 0.15, cz + 0.14), Vector3(0.04, 0.32, 0.02), Color("#2a2a2a"))
	k.box("color", Vector3(door_lx + 0.11, cyc, cz + 0.14), Vector3(0.24, 0.04, 0.02), Color("#2a2a2a"))
	# the iron balcony over the door, on brackets
	var by := y0 + S
	k.box("planks", Vector3(door_lx, by - 0.05, gz1 + 0.4), Vector3(2.2, 0.1, 0.8), Color("#8a6a4a"))
	_railing(k, Vector3(door_lx - 1.1, by, gz1 + 0.78), Vector3(door_lx + 1.1, by, gz1 + 0.78), 0.8)
	for sx in [-1.0, 1.0]:
		_railing(k, Vector3(door_lx + sx * 1.1, by, gz1 + 0.02), Vector3(door_lx + sx * 1.1, by, gz1 + 0.78), 0.8)
		VBld._beam(k, "color", Vector3(door_lx + sx * 0.9, by - 0.7, gz1 + 0.02), Vector3(door_lx + sx * 0.9, by - 0.12, gz1 + 0.7), 0.05, IRON)
	# Mardi Gras banners either side of the door, and the sign over it
	for sx in [-1.0, 1.0]:
		var bx: float = door_lx + sx * (dw / 2.0 + 0.42)
		var col: Color = MARDI_GRAS[0 if sx < 0 else 1]
		k.box("color", Vector3(bx, y0 + 1.55, gz1 + 0.04), Vector3(0.46, 1.4, 0.03), col)
		k.box("color", Vector3(bx, y0 + 1.55, gz1 + 0.06), Vector3(0.12, 1.4, 0.02), MARDI_GRAS[2])
		# a fleur-de-lis in gold: a petal up the middle and one curling out to each side
		k.box("color", Vector3(bx, y0 + 1.42, gz1 + 0.07), Vector3(0.08, 0.34, 0.02), MARDI_GRAS[2])
		for px in [-1.0, 1.0]:
			VBld._beam(k, "color", Vector3(bx, y0 + 1.36, gz1 + 0.07), Vector3(bx + px * 0.14, y0 + 1.5, gz1 + 0.07), 0.05, MARDI_GRAS[2])
		k.box("color", Vector3(bx, y0 + 1.3, gz1 + 0.075), Vector3(0.24, 0.04, 0.02), MARDI_GRAS[2])
		k.box("color", Vector3(bx, y0 + 2.27, gz1 + 0.05), Vector3(0.58, 0.06, 0.06), IRON)
		_gas_lamp(k, Vector3(door_lx + sx * 1.45, 0.0, gz1 + 0.2), 1.9)
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("arena")
	icon.position = Vector3(door_lx, y0 + 2.5, VBld._on_face(icon.mesh, gz1 + 0.02))
	node.add_child(icon)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	return crest_y


## Slanted faces between two closed outlines with as many corners (the lower `lo` at y0, the upper `hi` at y1), facing
## away from `centre`: mansard slopes.
static func _frustum(k: VBld.Kit, tex: String, lo: Array, hi: Array, y0: float, y1: float, col: Color, centre: Vector2) -> void:
	for i in lo.size():
		var j := (i + 1) % lo.size()
		var a: Vector2 = lo[i]
		var b: Vector2 = lo[j]
		var a2: Vector2 = hi[i]
		var b2: Vector2 = hi[j]
		var out := Vector2(b.y - a.y, a.x - b.x).normalized()
		if out.dot((a + b) / 2.0 - centre) < 0.0:
			out = -out
		VBld._slope(k, tex, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b2.x, y1, b2.y), Vector3(a2.x, y1, a2.y)], col.darkened(0.04 * float(i % 2)), Vector3(b.x - a.x, 0, b.y - a.y))


# ================================================================ street furniture
## A gas lamp: a black iron post on a stone foot, a lantern with a warm glow and a cap, `h` to the lantern's middle.
static func _gas_lamp(k: VBld.Kit, p: Vector3, h: float) -> void:
	k.box("stone", p + Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.24), BASE)
	k.box("color", p + Vector3(0, h / 2.0, 0), Vector3(0.07, h, 0.07), IRON)
	k.box("color", p + Vector3(0, h - 0.24, 0), Vector3(0.24, 0.05, 0.24), IRON)
	k.box("glow", p + Vector3(0, h, 0), Vector3(0.2, 0.38, 0.2), Color("#ffe0a0"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("color", p + Vector3(sx * 0.1, h, sz * 0.1), Vector3(0.025, 0.4, 0.025), IRON)
	VBld._spire(k, "color", VBld._loop(Vector2(p.x, p.z), 0.18, 0.18, 4, PI / 4.0), p.y + h + 0.2, Vector2(p.x, p.z), 0.18, IRON)


static var _meshes := {}


## One tile of the quay's stone balustrade, along x: a plinth, five turned balusters and a broad coping on top.
static func balustrade() -> ArrayMesh:
	if _meshes.has("balustrade"):
		return _meshes["balustrade"]
	var k := VBld.Kit.new()
	var stone := Color("#ddd2bc")
	k.box("stone", Vector3(0, 0.08, 0), Vector3(1.0, 0.16, 0.36), stone.darkened(0.08))
	for i in 5:
		var x := -0.4 + i * 0.2
		k.box("stone", Vector3(x, 0.26, 0), Vector3(0.11, 0.2, 0.11), stone)
		k.box("stone", Vector3(x, 0.45, 0), Vector3(0.07, 0.18, 0.07), stone)
		k.box("stone", Vector3(x, 0.6, 0), Vector3(0.1, 0.12, 0.1), stone)
	k.box("stone", Vector3(0, 0.71, 0), Vector3(1.0, 0.1, 0.4), stone.lightened(0.06))
	_meshes["balustrade"] = k.mesh()
	return _meshes["balustrade"]


## A square stone pier the height of the balustrade, ending a run of it or carrying a lamp.
static func pier() -> ArrayMesh:
	if _meshes.has("pier"):
		return _meshes["pier"]
	var k := VBld.Kit.new()
	var stone := Color("#ddd2bc")
	k.box("stone", Vector3(0, 0.4, 0), Vector3(0.34, 0.8, 0.34), stone)
	k.box("stone", Vector3(0, 0.83, 0), Vector3(0.42, 0.08, 0.42), stone.lightened(0.06))
	_meshes["pier"] = k.mesh()
	return _meshes["pier"]
