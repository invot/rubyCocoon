extends RefCounted
## Dustwell Oasis's old western main street (the "frontier" style: a town map's "style"), built of the house pack's
## wall sections (assets/exteriors, as house_builder.gd) and VBld.Kit boxes, after the western packs in CREDITS.md:
##   every building is painted plank siding in a warm, bright colour (red, orange, yellow, pink) with cream trim, and
##   stands back from its plot's front behind a plank boardwalk under a porch roof on posts, all within the plot (no
##   porch over a path; the roof sits on the posts' tops). Shops wear a tall false front with a sign board carrying
##   their icon, and a porch roof striped in their colour; houses a tin gable roof.
##   The saloon (building_looks "frontier": "saloon") is two storeys with a balcony on posts across its front, batwing
##   doors and SALOON on its false front; the jail ("jail") one storey with barred windows, a sheriff's star and JAIL.
##   The Beast Center is a little temple (voxel_buildings.gd's shrine pieces: pale stone, a stepped tiled roof with a
##   crystal at its peak, the pawprint on a stepped pediment) behind a colonnade where the other buildings have porches.
## Missing-trainer posters are pinned to the porch posts (Story's poster boards are the ones you can read).
## A building's local origin is the centre of its plot at ground level; its front faces +z (as voxel_buildings.gd).

const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const TrainerCell = preload("res://scripts/story/trainer_cell.gd")

## siding paints: a sunset street
const PAINTS := {"red": "#d9544a", "orange": "#ec8a3a", "yellow": "#f2c14e", "pink": "#ef8fb0", "coral": "#f27866",
	"gold": "#f5a93c", "rose": "#e2708e"}
const ORDER := ["red", "yellow", "pink", "orange", "coral", "gold", "rose"]
const TRIM := Color("#fbf1dc")
const WOOD := Color("#8a5a36")
const DECK := Color("#b9844f")
const TIN := Color("#b4aca6")
const IRON := Color("#2a2a30")
const BRASS := Color("#f0c850")
const S := HouseBuilder.STOREY
const IN := HouseBuilder.INSET
const THICK := HouseBuilder.THICK
## the boardwalk's height, how far the front wall stands back from the plot's front, the porch posts' height above the
## boardwalk, and how far a false front rises above the roof
const PLINTH := 0.18
const PORCH := 1.15
const POST_TOP := 2.45
const FALSE_FRONT := 1.3
const UIKit = preload("res://scripts/ui/ui_kit.gd")


## Whether this style builds that building (the others are voxel_buildings.gd's, in the western style).
static func handles(shop: String) -> bool:
	return shop in ["center", "house", "home", "decor"] or shop in VBld.COMMERCIAL


static func build(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	var shop: String = b["shop"]
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("frontier:%s:%d:%d" % [shop, int(b.get("seed", 0)), int(b["x"])]).hash()
	var kind := String(b.get("frontier", shop))
	var paint := Color(PAINTS.get(String(b.get("paint", "")), PAINTS[ORDER[absi(int(b["x"]) * 7 + int(b["y"])) % ORDER.size()]]))
	var o := {"paint": paint, "locked": bool(b.get("locked", false)), "door_lx": door_lx, "shop": shop}
	match kind:
		"center":
			b["height"] = _beast_center(node, w, d, door_lx)
		"saloon":
			o.merge({"floors": 2, "front": "step", "balcony": true, "words": "SALOON", "batwings": true, "ground": "wide", "upper": "door"})
			b["height"] = _facade(node, w, d, rng, o)
		"jail":
			o.merge({"floors": 1, "front": "flat", "words": "JAIL", "star": true, "ground": "barred", "door": "door_2", "plinth": "stone"})
			b["height"] = _facade(node, w, d, rng, o)
		"studio":
			o.merge({"floors": 1, "front": "flat", "words": "DANCE", "ground": "wide", "awning": Color(VBld.SHOP_ROOF.get(shop, "#c84040"))})
			b["height"] = _facade(node, w, d, rng, o)
		"house", "home", "decor":
			o.merge({"floors": 2 if w >= 5 and rng.randf() < 0.5 else 1, "front": "gable", "ground": "house", "upper": "house"})
			b["height"] = _facade(node, w, d, rng, o)
		_:
			# a store: a false front over a shop front, a flat above it in the bigger ones
			o.merge({"floors": 2 if w >= 5 else 1, "front": ["step", "arch", "flat"][rng.randi_range(0, 2)],
				"ground": "wide", "upper": "house", "awning": Color(VBld.SHOP_ROOF.get(shop, "#c84040"))})
			if shop in VBld.COMMERCIAL:
				o["icon"] = shop
			if b.has("words"):
				o["words"] = b["words"]
			b["height"] = _facade(node, w, d, rng, o)
	return node


## A store or house for the outskirts, past the map's edge: [node, radius].
static func backdrop(rng: RandomNumberGenerator) -> Array:
	var w := float(rng.randi_range(4, 6))
	var d := 4.0
	var shop := "house" if rng.randf() < 0.5 else "decor"
	var b := {"shop": shop, "x": rng.randi_range(0, 60), "y": 0, "w": w, "d": d, "door": Vector2i(int(w) / 2, 3), "seed": rng.randi()}
	if shop == "decor":
		b["frontier"] = "store"
	var node := build(b)
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [node, maxf(w, d) * 0.5]


# ================================================================ the street's buildings
## A plank-sided building standing back behind its boardwalk and porch; returns the height of its top.
## o: paint, floors, front (step, arch, flat: a false front; gable: a house's tin roof), ground and upper (what fills
## the storeys' fronts: wide shop windows, house windows, barred ones, or a door onto the balcony), balcony, awning
## (a shop's colour, for the porch roof's stripes), icon, words, star, batwings, door, plinth, locked, door_lx.
static func _facade(node: Node3D, w: float, d: float, rng: RandomNumberGenerator, o: Dictionary) -> float:
	var body := Node3D.new()
	body.position.z = -PORCH / 2.0
	node.add_child(body)
	var bd := d - PORCH
	var hb = HouseBuilder.new()
	hb.node = body
	hb.w = w
	hb.d = bd
	hb.rng.seed = rng.randi()
	var k := VBld.Kit.new()
	var paint: Color = o["paint"]
	var mat: Material = HouseBuilder.wall_material("planks_v", paint)
	var door_lx: float = o["door_lx"]
	var floors := int(o["floors"])
	# (in the body's space: its front wall's face, the porch's posts and the plot's front edge)
	var zf := bd / 2.0 - IN
	var zp := bd / 2.0 + PORCH - 0.16
	var zfront := bd / 2.0 + PORCH - 0.03
	var x0 := -w / 2.0 + IN + THICK
	var x1 := w / 2.0 - IN - THICK
	# the floor, the boardwalk, and a step down at the door
	k.box("stone" if o.get("plinth", "") == "stone" else "planks", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.08, PLINTH, bd - 0.08), Color("#c9a27a") if o.get("plinth", "") == "stone" else WOOD)
	k.box("planks", Vector3(0, PLINTH / 2.0, (zf + zfront - 0.32) / 2.0), Vector3(w - 0.04, PLINTH, zfront - 0.32 - zf), DECK)
	k.box("planks", Vector3(door_lx, PLINTH / 4.0, zfront - 0.16), Vector3(1.3, PLINTH / 2.0, 0.32), DECK.darkened(0.08))
	for sx in [-1.0, 1.0]:
		k.box("planks", Vector3(sx * (w / 2.0 - 0.6), PLINTH / 2.0, zfront - 0.16), Vector3(1.2, PLINTH, 0.32), DECK)
	var y := PLINTH
	# ---- the ground floor
	var dw := 1.5
	var door: String = "door_1" if o["locked"] else String(o.get("door", VBld.PACK_DOORS[rng.randi_range(0, VBld.PACK_DOORS.size() - 1)]))
	hb.place(door, Vector2i(0, 1), door_lx, dw, y, mat)
	if o["locked"]:
		VBld._door_lock(k, Vector3(door_lx, y + 1.0, zf + 0.02), 0.8, 1.9)
	else:
		# one wide door with a brass knob
		k.box("color", Vector3(door_lx + 0.27, y + 0.95, zf + 0.05), Vector3(0.07, 0.07, 0.07), BRASS)
	if o.get("batwings", false):
		for sx in [-1.0, 1.0]:
			k.box("planks", Vector3(door_lx + sx * 0.2, y + 1.05, zf + 0.14), Vector3(0.36, 0.8, 0.05), WOOD.lightened(0.15))
			k.box("color", Vector3(door_lx + sx * 0.2, y + 1.47, zf + 0.17), Vector3(0.38, 0.06, 0.03), TRIM)
	var ground := String(o.get("ground", "house"))
	var spots := []
	spots.append_array(_openings(hb, x0, door_lx - dw / 2.0, y, mat, ground))
	spots.append_array(_openings(hb, door_lx + dw / 2.0, x1, y, mat, ground))
	if ground == "barred":
		for sp in spots:
			_bars(k, sp[0], sp[1] * 0.5, y + 1.12, y + 2.05, zf + 0.12)
	_walls(hb, x0, x1, bd, y, mat)
	hb.corners(k, y, S, TRIM)
	y += S
	# ---- the floor above
	if floors == 2:
		k.box("planks", Vector3(0, y + 0.06, 0), Vector3(w - 0.12, 0.12, bd - 0.12), TRIM)
		y += 0.12
		if String(o.get("upper", "")) == "door":
			# a door out onto the balcony
			hb.place("door_3", Vector2i(0, 1), door_lx, 1.5, y, mat)
			_openings(hb, x0, door_lx - 0.75, y, mat, "house")
			_openings(hb, door_lx + 0.75, x1, y, mat, "house")
		else:
			_openings(hb, x0, x1, y, mat, "house")
		_walls(hb, x0, x1, bd, y, mat)
		hb.corners(k, y, S, TRIM)
		y += S
	var top := y
	# ---- the porch: a boardwalk roof on posts, or the saloon's balcony
	var post_top := PLINTH + (S if o.get("balcony", false) else POST_TOP)
	var posts := _posts(w, door_lx)
	for px in posts:
		k.box("planks", Vector3(px, (PLINTH + post_top) / 2.0, zp), Vector3(0.14, post_top - PLINTH, 0.14), TRIM)
	# hitching rails between the posts (not across the door)
	for i in posts.size() - 1:
		var a: float = posts[i]
		var bx: float = posts[i + 1]
		if door_lx > a and door_lx < bx:
			continue
		k.box("planks", Vector3((a + bx) / 2.0, PLINTH + 0.78, zp), Vector3(bx - a, 0.08, 0.07), WOOD.lightened(0.1))
	# the beam along the posts' tops
	k.box("planks", Vector3(0, post_top + 0.07, zp), Vector3(w - 0.04, 0.14, 0.18), TRIM)
	if o.get("balcony", false):
		# the balcony: its deck on the beam, a railing round it
		var bz := (zf + zp + 0.1) / 2.0
		k.box("planks", Vector3(0, post_top + 0.2, bz), Vector3(w - 0.04, 0.12, zp + 0.1 - zf), DECK)
		_railing(k, Vector3(-w / 2.0 + 0.05, post_top + 0.26, zp), Vector3(w / 2.0 - 0.05, post_top + 0.26, zp))
		for sx in [-1.0, 1.0]:
			_railing(k, Vector3(sx * (w / 2.0 - 0.05), post_top + 0.26, zf + 0.05), Vector3(sx * (w / 2.0 - 0.05), post_top + 0.26, zp))
	else:
		# a shed roof from under the eave down onto the beam: striped in a shop's colour, else tin
		var yw := minf(PLINTH + S - 0.04, post_top + 0.55)
		var yb := post_top + 0.14
		var awning: Variant = o.get("awning", null)
		var x := -w / 2.0
		var i := 0
		while x < w / 2.0 - 0.01:
			var x2 := minf(x + (0.45 if awning != null else w), w / 2.0)
			var col: Color = (awning if i % 2 == 0 else Color("#f4f0e4")) if awning != null else TIN
			k.poly("color" if awning != null else "tin", [Vector3(x, yw, zf), Vector3(x2, yw, zf), Vector3(x2, yb, zp + 0.12), Vector3(x, yb, zp + 0.12)],
				Vector3(0, 0.95, 0.3), col)
			x = x2
			i += 1
	_posters(k, posts, door_lx, zp + 0.08, rng)
	# ---- the roof
	var ridge := top
	var front := String(o.get("front", "flat"))
	if front == "gable":
		ridge = VBld._gable(k, w, bd - 0.1, top + 0.04, 0.55, 0.22, "tin", Color("#b0584a") if paint.h > 0.9 or paint.h < 0.05 else Color("#a65a3e"), "planks_v", paint, TRIM)
	else:
		# a tin roof behind a false front
		k.box("tin", Vector3(0, top + 0.08, -0.1), Vector3(w - 0.16, 0.12, bd - 0.3), TIN)
		ridge = _false_front(node, k, w, zf, top, front, paint, o)
	# lanterns either side of the door
	for sx in [-1.0, 1.0]:
		var lx: float = door_lx + sx * 1.0
		if lx > x0 + 0.1 and lx < x1 - 0.1:
			k.box("color", Vector3(lx, PLINTH + 2.0, zf + 0.06), Vector3(0.08, 0.08, 0.12), IRON)
			k.box("glow", Vector3(lx, PLINTH + 1.86, zf + 0.14), Vector3(0.15, 0.22, 0.15), Color("#ffd890"))
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	body.add_child(km)
	return ridge


## Fills a span of a front with windows (wide: shop windows; house; barred: small ones for the bars), or plain wall
## where none fit; returns each window's [centre, share of the wall].
static func _openings(hb, a: float, b: float, y: float, mat: Material, kind: String) -> Array:
	var span := b - a
	if span < 0.05:
		return []
	var list: Array = {"wide": VBld.PACK_WIDE, "house": VBld.PACK_WINDOWS, "barred": ["win_small_1"]}.get(kind, VBld.PACK_WINDOWS)
	var unit := 2.6 if kind == "wide" else 1.7
	var n := int(span / unit)
	if n < 1 and kind == "wide" and span >= 1.5:
		list = VBld.PACK_WINDOWS
		n = 1
	if n < 1:
		hb.place("wall_2" if span > 1.4 else "wall_1", Vector2i(0, 1), (a + b) / 2.0, span, y, mat)
		return []
	var share := span / n
	var pick: String = list[hb.rng.randi_range(0, list.size() - 1)]
	var out := []
	for i in n:
		var c := a + share * (i + 0.5)
		hb.place(pick, Vector2i(0, 1), c, share, y, mat)
		out.append([c, share])
	return out


## A storey's back and sides: plain walls.
static func _walls(hb, x0: float, x1: float, bd: float, y: float, mat: Material) -> void:
	hb.place("wall_2", Vector2i(0, -1), 0.0, x1 - x0, y, mat)
	var z0 := -bd / 2.0 + IN + THICK
	var z1 := bd / 2.0 - IN - THICK
	for sx in [-1, 1]:
		hb.place("wall_2", Vector2i(sx, 0), (z0 + z1) / 2.0, z1 - z0, y, mat)


## Where the porch posts stand along the front: at both ends and about every 1.8 between, never in front of the door.
static func _posts(w: float, door_lx: float) -> Array:
	var a := -w / 2.0 + 0.1
	var b := w / 2.0 - 0.1
	var n := maxi(1, int(round((b - a) / 1.8)))
	var out := []
	for i in n + 1:
		var px := a + (b - a) * float(i) / n
		if i > 0 and i < n and absf(px - door_lx) < 0.95:
			px = door_lx + signf(px - door_lx + 0.001) * 0.95
		out.append(px)
	return out


## Iron bars over a small window.
static func _bars(k: VBld.Kit, c: float, half: float, ya: float, yb: float, z: float) -> void:
	var n := 5
	for i in n:
		var x := c - half * 0.45 + half * 0.9 * float(i) / (n - 1)
		k.box("color", Vector3(x, (ya + yb) / 2.0, z), Vector3(0.04, yb - ya, 0.04), IRON)
	for yy in [ya + 0.05, yb - 0.05]:
		k.box("color", Vector3(c, yy, z), Vector3(half * 1.0, 0.05, 0.05), IRON)


## A plain plank railing from p0 to p1 (its foot), with a top rail and pickets.
static func _railing(k: VBld.Kit, p0: Vector3, p1: Vector3) -> void:
	var len := p0.distance_to(p1)
	var mid := (p0 + p1) / 2.0
	var along_x := absf(p1.x - p0.x) > absf(p1.z - p0.z)
	k.box("planks", mid + Vector3(0, 0.82, 0), Vector3(len if along_x else 0.08, 0.08, 0.08 if along_x else len), TRIM)
	var n := maxi(2, int(len / 0.28))
	for i in n + 1:
		var p := p0.lerp(p1, float(i) / n)
		k.box("planks", p + Vector3(0, 0.4, 0), Vector3(0.05, 0.8, 0.05), TRIM)


## The false front over a store: a tall board across the street side, stepped up in the middle, arched or flat, with a
## cornice, a sign board (the shop's icon, or words), and for the jail a sheriff's star. Returns its top.
static func _false_front(node: Node3D, k: VBld.Kit, w: float, zf: float, top: float, shape: String, paint: Color, o: Dictionary) -> float:
	var face := paint.lightened(0.06)
	var z := zf + 0.08
	var base := top - 0.25
	var hi := top + FALSE_FRONT
	var side_hi := hi - (0.42 if shape in ["step", "arch"] else 0.0)
	k.box("planks_v", Vector3(0, (base + side_hi) / 2.0, z), Vector3(w + 0.08, side_hi - base, 0.16), face)
	k.box("planks", Vector3(0, side_hi + 0.05, z + 0.02), Vector3(w + 0.2, 0.1, 0.24), TRIM)
	var peak := side_hi + 0.1
	if shape == "step":
		var sw := minf(w * 0.5, 2.6)
		k.box("planks_v", Vector3(0, (side_hi + hi) / 2.0, z), Vector3(sw, hi - side_hi, 0.16), face)
		k.box("planks", Vector3(0, hi + 0.05, z + 0.02), Vector3(sw + 0.14, 0.1, 0.24), TRIM)
		peak = hi + 0.1
	elif shape == "arch":
		var r := minf(w * 0.24, 1.2)
		var seg := 10
		for i in seg:
			var a0 := PI * float(i) / seg
			var a1 := PI * float(i + 1) / seg
			k.poly("planks_v", [Vector3(0, side_hi, z + 0.08), Vector3(cos(a0) * r, side_hi + sin(a0) * r * 0.5, z + 0.08), Vector3(cos(a1) * r, side_hi + sin(a1) * r * 0.5, z + 0.08)], Vector3.BACK, face)
			k.box("planks", Vector3(cos((a0 + a1) / 2.0) * r, side_hi + sin((a0 + a1) / 2.0) * r * 0.5 + 0.04, z + 0.1), Vector3(0.36, 0.08, 0.1), TRIM)
		peak = side_hi + r * 0.5 + 0.1
	# the sign board, centred on the front
	var sy := base + (side_hi - base) * 0.55
	var brand := Color(VBld.SHOP_ROOF.get(String(o.get("icon", "")), "#5a3424"))
	if o.has("words"):
		var text := String(o["words"])
		var bw := minf(w - 0.5, 0.42 * text.length() + 0.5)
		k.box("planks", Vector3(0, sy, z + 0.1), Vector3(bw, 0.62, 0.06), TRIM)
		k.box("color", Vector3(0, sy, z + 0.135), Vector3(bw - 0.14, 0.5, 0.02), Color("#5a3424") if not o.has("icon") else brand.darkened(0.25))
		_words(node, text, Vector3(0, sy, z + 0.15 - PORCH / 2.0), Color("#ffe7a8"))
	elif o.has("icon"):
		k.box("planks", Vector3(0, sy, z + 0.1), Vector3(1.7, 0.56, 0.06), TRIM)
		k.box("color", Vector3(0, sy, z + 0.135), Vector3(1.5, 0.42, 0.02), brand.darkened(0.25))
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(String(o["icon"]))
		icon.position = Vector3(0, sy - 0.02, VBld._on_face(icon.mesh, z + 0.15) - PORCH / 2.0)
		node.add_child(icon)
	if o.get("star", false):
		_star(k, Vector3(0, minf(peak - 0.5, sy + 0.75), z + 0.1), 0.34, BRASS)
	return peak


## Big painted letters on a sign board, in the shared semibold heading font.
static func _words(node: Node3D, text: String, p: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UIKit.font_head()
	l.font_size = 64
	l.pixel_size = 0.0068
	l.outline_size = 0
	l.modulate = col
	l.position = p
	node.add_child(l)


## A five-pointed star badge facing the street.
static func _star(k: VBld.Kit, c: Vector3, r: float, col: Color) -> void:
	var pts := []
	for i in 10:
		var a := PI / 2.0 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector3(cos(a) * rr, sin(a) * rr, 0))
	for i in 10:
		k.poly("color", [c, pts[i], pts[(i + 1) % 10]], Vector3.BACK, col)
	k.box("color", c - Vector3(0, 0, 0.02), Vector3(r * 0.5, r * 0.5, 0.02), col.darkened(0.3))


## Missing-trainer posters pinned to the porch posts beside the door (one face for each trainer). Once the trainers
## are home, each has FOUND stamped across it.
static func _posters(k: VBld.Kit, posts: Array, door_lx: float, z: float, rng: RandomNumberGenerator) -> void:
	var found := _trainers_home()
	for px in posts:
		if absf(float(px) - door_lx) > 2.2 or rng.randf() < 0.35:
			continue
		poster(k, Vector3(float(px), PLINTH + 1.45, z), rng.randi_range(0, 2), found, 0.8)


## One poster: a cream sheet with MISSING's red band, the trainer's picture in their shirt and hair colours, and lines
## of print; `found` adds the green FOUND band. `c` is the middle of its face.
static func poster(k: VBld.Kit, c: Vector3, who: int, found: bool, s := 1.0) -> void:
	var look: Dictionary = TrainerCell.LOOKS[who % TrainerCell.LOOKS.size()]
	k.box("color", c, Vector3(0.4, 0.54, 0.02) * s, Color("#f6ecd2"))
	k.box("color", c + Vector3(0, 0.2, 0.012) * s, Vector3(0.34, 0.08, 0.01) * s, Color("#c8382e"))
	k.box("color", c + Vector3(0, 0.04, 0.012) * s, Vector3(0.2, 0.2, 0.01) * s, Color(look["shirt"]))
	k.box("color", c + Vector3(0, 0.1, 0.016) * s, Vector3(0.1, 0.08, 0.01) * s, Color(look["hair"]))
	k.box("color", c + Vector3(0, 0.05, 0.018) * s, Vector3(0.08, 0.07, 0.01) * s, Color(look["skin"]))
	for i in 2:
		k.box("color", c + Vector3(0, -0.12 - i * 0.06, 0.012) * s, Vector3(0.28 - i * 0.08, 0.025, 0.01) * s, Color("#6a5a4a"))
	if found:
		k.box("color", c + Vector3(0, -0.02, 0.022) * s, Vector3(0.44, 0.1, 0.01) * s, Color("#3f9a52"))


## A notice board on two posts under a little plank roof, MISSING painted along its top, with one trainer's poster
## (`who`), or all three (-1), pinned to it: Story's poster boards, which you can read. Faces +z.
static func poster_board(who: int, found: bool) -> Node3D:
	var node := Node3D.new()
	var k := VBld.Kit.new()
	for sx in [-0.48, 0.48]:
		k.box("planks", Vector3(sx, 0.85, 0), Vector3(0.1, 1.7, 0.1), WOOD)
	k.box("planks", Vector3(0, 1.08, 0.02), Vector3(1.12, 0.92, 0.06), DECK.lightened(0.05))
	k.box("planks", Vector3(0, 1.62, 0.04), Vector3(1.2, 0.18, 0.1), TRIM)
	k.box("planks", Vector3(0, 1.76, -0.02), Vector3(1.32, 0.06, 0.3), WOOD.darkened(0.1))
	if who >= 0:
		poster(k, Vector3(0, 1.06, 0.06), who, found, 1.45)
	else:
		for i in 3:
			poster(k, Vector3(-0.35 + i * 0.35, 1.06, 0.06), i, found, 0.78)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	node.add_child(mi)
	var l := Label3D.new()
	l.text = "FOUND" if found else "MISSING"
	l.font = UIKit.font_head()
	l.font_size = 64
	l.pixel_size = 0.0034
	l.outline_size = 0
	l.modulate = Color("#3f9a52") if found else Color("#c8382e")
	l.position = Vector3(0, 1.62, 0.1)
	node.add_child(l)
	return node


static func _trainers_home() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GameState") if tree != null else null
	return gs != null and bool(gs.call("flag", "trainers_freed"))


# ================================================================ the Beast Center
## The Beast Center: the temple every town has (voxel_buildings.gd "Beast Center: a small temple"), standing back
## behind a colonnade where its neighbours have porches: walls of pale stone on a stone platform, round stone columns
## carrying a stone beam and a tiled porch roof, and over the door, where a store's false front would step up, the
## stepped pediment with the pawprint roundel; a stepped tiled roof with a crystal at its peak. Returns its top.
static func _beast_center(node: Node3D, w: float, d: float, door_lx: float) -> float:
	var body := Node3D.new()
	body.position.z = -PORCH / 2.0
	node.add_child(body)
	var bd := d - PORCH
	var hb = HouseBuilder.new()
	hb.node = body
	hb.w = w
	hb.d = bd
	hb.rng.seed = int(w * 13.0 + d)
	hb.stone_windows = true
	var k := VBld.Kit.new()
	var stone := VBld.SHRINE_STONE.lerp(Color("#e8c9a0"), 0.3)
	var tile := VBld.SHRINE_TILE.lerp(Color("#c8703c"), 0.4)
	var mat: Material = HouseBuilder.wall_material("plaster", stone)
	var zf := bd / 2.0 - IN
	var zp := bd / 2.0 + PORCH - 0.2
	var zfront := bd / 2.0 + PORCH - 0.03
	var x0 := -w / 2.0 + IN + THICK
	var x1 := w / 2.0 - IN - THICK
	# the platform: stone under the hall and the colonnade, a broad step down at the door
	var flag := stone.darkened(0.2)
	k.box("stone", Vector3(0, PLINTH / 2.0, 0), Vector3(w - 0.08, PLINTH, bd - 0.08), flag)
	k.box("stone", Vector3(0, PLINTH / 2.0, (zf + zfront - 0.32) / 2.0), Vector3(w - 0.04, PLINTH, zfront - 0.32 - zf), flag.lightened(0.08))
	k.box("stone", Vector3(door_lx, PLINTH / 4.0, zfront - 0.16), Vector3(1.6, PLINTH / 2.0, 0.32), flag)
	for sx in [-1.0, 1.0]:
		k.box("stone", Vector3(sx * (w / 2.0 - 0.6), PLINTH / 2.0, zfront - 0.16), Vector3(1.2, PLINTH, 0.32), flag.lightened(0.08))
	var y := PLINTH
	var dw := 1.5
	hb.place("door_6", Vector2i(0, 1), door_lx, dw, y, mat)
	k.box("color", Vector3(door_lx + 0.27, y + 0.95, zf + 0.05), Vector3(0.07, 0.07, 0.07), BRASS)
	_openings(hb, x0, door_lx - dw / 2.0, y, mat, "house")
	_openings(hb, door_lx + dw / 2.0, x1, y, mat, "house")
	_walls(hb, x0, x1, bd, y, mat)
	VBld._shrine_corners(k, w, bd, y, S, stone)
	var top := VBld._shrine_frieze(k, w, bd, y + S, stone, 0.5)
	var peak := VBld.shrine_roof(k, w, bd, top, "tile", tile, stone)
	# the colonnade: round columns on square bases, a stone beam on their tops, and a tiled roof from the wall to it
	var post_top := PLINTH + POST_TOP
	var posts := _posts(w, door_lx)
	for px in posts:
		k.box("plaster", Vector3(px, PLINTH + 0.08, zp), Vector3(0.34, 0.16, 0.34), stone.darkened(0.12))
		VBld._column(k, "plaster", Vector3(px, PLINTH + 0.16, zp), 0.115, post_top - PLINTH - 0.28, 10, stone.lightened(0.03), PI / 10.0)
		k.box("plaster", Vector3(px, post_top - 0.06, zp), Vector3(0.34, 0.12, 0.34), stone.darkened(0.06))
	k.box("plaster", Vector3(0, post_top + 0.09, zp), Vector3(w - 0.04, 0.18, 0.3), stone, true)
	k.box("color", Vector3(0, post_top + 0.03, zp + 0.006), Vector3(w - 0.03, 0.05, 0.3), VBld.SHRINE_GOLD.darkened(0.1))
	var yw := PLINTH + S - 0.04
	VBld._slope(k, "tile", [Vector3(-w / 2.0, post_top + 0.18, zp + 0.17), Vector3(w / 2.0, post_top + 0.18, zp + 0.17), Vector3(w / 2.0, yw, zf),
		Vector3(-w / 2.0, yw, zf)], tile, Vector3.RIGHT)
	_posters(k, posts, door_lx, zp + 0.125, RandomNumberGenerator.new())
	# over the door, where a store's false front would stand: the stepped pediment with the pawprint
	var hi := VBld.shrine_pediment(k, Vector3(door_lx, post_top + 0.18, zp), minf(3.0, w - 1.0), 0.3, 0.9, stone)
	for sx in [-1.0, 1.0]:
		var bx: float = door_lx + sx * 1.3
		if absf(bx) < w / 2.0 - 0.4:
			VBld._shrine_banner(k, Vector3(bx, y + S - 0.2, zf + 0.03), 0.36, 0.7)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffd8a0")
	l.light_energy = 0.7
	l.omni_range = 3.5
	l.position = Vector3(door_lx, 1.6, zp)
	body.add_child(l)
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	body.add_child(km)
	return maxf(hi + 0.1, peak)
