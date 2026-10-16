extends RefCounted
## Voxel-style buildings assembled from textured boxes, in regional styles.
## A building's local origin is the centre of its footprint at ground level; the front faces +Z.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")

const SHADE := {Vector3(0, 1, 0): 1.0, Vector3(0, -1, 0): 0.6, Vector3(1, 0, 0): 0.86, Vector3(-1, 0, 0): 0.86, Vector3(0, 0, 1): 0.95, Vector3(0, 0, -1): 0.78}

const STYLES := {
	"coastal": {"wall": ["plaster", "#f2eee2"], "roof": ["shingle", "#3a86b8"], "trim": "#8a6a48", "base": "#b0a898", "roof_type": "gable", "door": "#3a6a9a"},
	"island": {"wall": ["bamboo", "#d8b878"], "roof": ["thatch", "#c8a860"], "trim": "#6a4a2a", "base": "#8a6a48", "roof_type": "hip", "stilts": true, "door": "#7a4a2a"},
	"adobe": {"wall": ["adobe", "#dcb88a"], "roof": ["adobe", "#c8a070"], "trim": "#7a4a2a", "base": "#b89a70", "roof_type": "flat", "door": "#3a6aa8"},
	"western": {"wall": ["planks_v", "#b8804a"], "roof": ["tin", "#9a9aa0"], "trim": "#5a3a22", "base": "#8a6a48", "roof_type": "western", "door": "#5a3a22"},
	"mining": {"wall": ["planks", "#8a6a4a"], "roof": ["tin", "#a08a7a"], "trim": "#4a3a2a", "base": "#7a7068", "roof_type": "shed", "door": "#4a3a2a"},
	"steampunk": {"wall": ["brick", "#a8503a"], "roof": ["slate", "#4a4a5a"], "trim": "#c8a040", "base": "#5a5a62", "roof_type": "gable", "pipes": true, "door": "#3a2a22"},
	"hotspring": {"wall": ["wood_dark", "#7a4a32"], "roof": ["tile", "#3a4a5a"], "trim": "#c83a2a", "base": "#7a7068", "roof_type": "pagoda", "door": "#4a2a1e", "lanterns": true},
	"jungle": {"wall": ["planks_v", "#9a7040"], "roof": ["leaf", "#5a9a3a"], "trim": "#5a3a1a", "base": "#6a4a2a", "roof_type": "hip", "stilts": true, "door": "#5a3a1a"},
	"town": {"wall": ["timber", "#efe4cc"], "roof": ["shingle", "#a8503a"], "trim": "#5a3a26", "base": "#9a948a", "roof_type": "gable", "door": "#5a3a26"},
	"gothic": {"wall": ["stone_dark", "#7a7a84"], "roof": ["slate", "#3a3a48"], "trim": "#4a4a52", "base": "#5a5a62", "roof_type": "steep", "door": "#3a2a3a", "window": "#b080ff"},
}
const SHOP_ROOF := {"center": "#d84848", "arena": "#c8a030", "electronics": "#3a3a48", "apothecary": "#48a868", "bookstore": "#8050b0",
	"cafe": "#e090a0", "dojo": "#7a4a30", "museum": "#4890a0", "music_hall": "#3a50a8", "music_shop": "#b07a30", "fortune": "#a040a0", "beast_gear": "#d08030",
	"trainer_gear": "#4070c0", "home": "#c05a3a"}

## Shops look nothing like houses: a shop front at street level (big display windows, a sign board and an awning in
## the shop's colour) and, in most towns, a flat above it. The look depends on the town:
##   floors 1 or 2; ground / upper: [texture, colour]; roof: flat (behind a parapet), gable, steep, false_front, pagoda, hip
##   jetty: the upper floor juts out over the street; balcony: a porch roof with a railing above it; skirt: a tiled
##   skirt roof between the floors; vigas: log beam ends under the roof; open: an open market counter instead of windows
const COMMERCIAL := ["apothecary", "beast_gear", "trainer_gear", "bookstore", "cafe", "music_shop", "fortune"]
const SHOP_LOOKS := {
	"coastal": {"floors": 2, "ground": ["brick", "#b0563c"], "upper": ["brick", "#9e4a34"], "roof": "flat", "trim": "#ece2d0", "flat_roof": "#5a5650"},
	"steampunk": {"floors": 2, "ground": ["brick", "#8a3a2a"], "upper": ["brick", "#7a3426"], "roof": "flat", "trim": "#c8a040", "flat_roof": "#3a3a42"},
	"town": {"floors": 2, "ground": ["plaster", "#f2ead6"], "upper": ["timber", "#efe4cc"], "roof": "gable", "jetty": true},
	"gothic": {"floors": 2, "ground": ["stone_dark", "#6a6a74"], "upper": ["wood_dark", "#4a3a3a"], "roof": "steep", "jetty": true},
	"western": {"floors": 2, "ground": ["planks_v", "#c08a52"], "upper": ["planks", "#a87444"], "roof": "false_front", "balcony": true},
	"adobe": {"floors": 2, "ground": ["adobe", "#e4c494"], "upper": ["adobe", "#d8b484"], "roof": "flat", "trim": "#7a4a2a", "vigas": true, "flat_roof": "#c8a070"},
	"mining": {"floors": 1, "ground": ["tin", "#9a8a7a"], "roof": "false_front"},
	"hotspring": {"floors": 2, "ground": ["wood_dark", "#7a4a32"], "upper": ["plaster", "#f2ead6"], "roof": "pagoda", "skirt": true},
	"island": {"floors": 1, "ground": ["bamboo", "#d8b878"], "roof": "hip", "open": true},
	"jungle": {"floors": 1, "ground": ["planks_v", "#9a7040"], "roof": "hip", "open": true},
}
const SHOP_GROUND := 2.3
const SHOP_UPPER := 1.9
## Locked doors (b["locked"]) are crimson in every town, with iron straps and a brass padlock, so you can tell them
## from the doors you can open. No style's ordinary door is red.
const LOCKED_DOOR := Color("#b3262c")


static var _mesh_cache := {}


## How tall a shop's walls are in this style (for tapping it and hanging its sign).
static func shop_height(style_name: String) -> float:
	var look: Dictionary = SHOP_LOOKS.get(style_name, SHOP_LOOKS["town"])
	var lift := 0.45 if STYLES.get(style_name, {}).get("stilts", false) else 0.0
	return lift + 0.16 + SHOP_GROUND + (SHOP_UPPER if int(look["floors"]) == 2 else 0.0)


class Kit:
	var surf := {}

	func box(mat: String, c: Vector3, s: Vector3, col := Color.WHITE, bottom := false) -> void:
		var h := s * 0.5
		var faces := [
			[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
			[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
			[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
			[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
			[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		]
		if bottom:
			faces.append([Vector3(0, -1, 0), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]])
		if not surf.has(mat):
			surf[mat] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
		var arr: Array = surf[mat]
		for f in faces:
			var n: Vector3 = f[0]
			var q: Array = f[1]
			var sh: float = SHADE[n] if mat != "glow" else 1.0
			var cc := Color(col.r * sh, col.g * sh, col.b * sh, col.a)
			var a: Vector3 = c + q[0]
			var b: Vector3 = c + q[1]
			var d: Vector3 = c + q[2]
			var e: Vector3 = c + q[3]
			var tri := [a, b, d, a, d, e] if (b - a).cross(d - a).dot(n) < 0.0 else [a, d, b, a, e, d]
			for v in tri:
				arr[0].append(v)
				arr[1].append(n)
				arr[2].append(cc)

	func mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in surf:
			var arr: Array = surf[key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = arr[0]
			arrays[Mesh.ARRAY_NORMAL] = arr[1]
			arrays[Mesh.ARRAY_COLOR] = arr[2]
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material
			if key == "color":
				mat = VT.color_material()
			elif key == "glow":
				mat = VT.glow_material()
			else:
				mat = VT.material(key)
			m.surface_set_material(m.get_surface_count() - 1, mat)
		return m


static func style_for(biome_id: String) -> String:
	return {"coast": "coastal", "island": "island", "desert": "adobe", "western": "western", "canyon": "western",
		"mountain": "mining", "steampunk": "steampunk", "volcano": "hotspring", "hotspring": "hotspring",
		"jungle": "jungle", "river": "town", "moor": "gothic", "forest": "town", "meadow": "town"}.get(biome_id, "town")


## Builds the full node for a building dictionary (shop, w, d, height, door, x, y, seed).
static func build(b: Dictionary, style_name: String) -> Node3D:
	var st: Dictionary = STYLES.get(style_name, STYLES["town"])
	var shop: String = b["shop"]
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var locked: bool = b.get("locked", false)
	var node := Node3D.new()
	var key := "%s:%s:%d:%d:%d%s" % [style_name if shop != "center" else "diner", shop, int(w), int(d), int(b.get("seed", 0)) % 3, ":locked" if locked else ""]
	var kit_mesh: ArrayMesh = _mesh_cache.get(key, null)
	var extras := []
	if kit_mesh == null:
		var kit := Kit.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = key.hash()
		match shop:
			"center":
				_diner(kit, w, d, door_lx)
			"arena":
				_arena(kit, w, d, st, door_lx)
			"skytower":
				_skytower(kit, w, d, st)
			"electronics":
				_electronics(kit, w, d, door_lx)
			"ceo_tower":
				_ceo_tower(kit, w, d, door_lx)
			"cathedral":
				_cathedral(kit, w, d, door_lx, locked)
			"hideout":
				pass
			"temple":
				pass
			_:
				if shop in COMMERCIAL:
					_shop(kit, w, d, st, SHOP_LOOKS.get(style_name, SHOP_LOOKS["town"]), shop, door_lx, rng)
				else:
					_house(kit, w, d, float(b.get("height", 2.4)), st, shop, door_lx, rng, locked)
		kit_mesh = kit.mesh()
		_mesh_cache[key] = kit_mesh
	var mi := MeshInstance3D.new()
	mi.mesh = kit_mesh
	node.add_child(mi)
	match shop:
		"skytower":
			var bird := MeshInstance3D.new()
			bird.mesh = VB.mesh(RaceDB.genes(43))
			bird.scale = Vector3(1.7, 1.7, 1.7)
			bird.position = Vector3(0, 7.25, 0)
			bird.rotation.y = -PI / 2.0
			bird.name = "Bird"
			node.add_child(bird)
		"hideout":
			var rock := VA.instance_footprint("mountain_4", d + 0.4, w + 0.6)
			rock.rotation.y = PI / 2.0
			node.add_child(rock)
			var hole := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.0, 1.3, 0.2)
			hole.mesh = bm
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color("#0a0806")
			hole.material_override = hm
			hole.position = Vector3(door_lx, 0.65, d / 2.0 + 0.02)
			node.add_child(hole)
		"temple":
			var tm := VA.instance_footprint("temple", w + 0.3, d + 0.3)
			node.add_child(tm)
			var gate := MeshInstance3D.new()
			gate.mesh = _temple_gate(d, door_lx, Color(b.get("glow", "#ffd870")))
			node.add_child(gate)
			var gem := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.6, 0.9, 0.6)
			gem.mesh = pm
			var col := Color(b.get("glow", "#ffd870"))
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = col
			gmat.emission_enabled = true
			gmat.emission = col
			gmat.emission_energy_multiplier = 3.0
			gem.material_override = gmat
			gem.position = Vector3(0, tm.scale.y * VA.aabb("temple").size.y + 0.8, 0)
			gem.set_meta("spin", true)
			node.add_child(gem)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 1.5
			l.omni_range = 5.0
			l.position = gem.position
			node.add_child(l)
	if shop == "center":
		# the Beast Center's pawprint sign hangs on the wall right by the door
		var paw := MeshInstance3D.new()
		paw.mesh = VP.icon("center")
		paw.position = Vector3(door_lx + 0.95, 1.4, _on_face(paw.mesh, _sign_face(shop, d)))
		node.add_child(paw)
	# wordless sign above the door
	if shop not in ["house", "home", "hideout", "temple", "decor", "cathedral", "ceo_tower", "center"]:
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(shop)
		var hgt := float(b.get("height", 2.4))
		if shop == "skytower":
			hgt = 2.4
		elif shop == "arena":
			hgt = 3.0
		var iy := 2.15
		if STYLES.get(style_name, {}).get("stilts", false):
			iy += 0.45
		if shop == "arena":
			iy = 2.3
		var iz := _on_face(icon.mesh, _sign_face(shop, d))
		if shop in COMMERCIAL:
			# on the shop's sign board
			icon.position = Vector3(door_lx, iy - 0.02, iz)
		else:
			icon.position = Vector3(door_lx, minf(iy, hgt + 0.1), iz)
		node.add_child(icon)
	if st.get("lanterns", false) or shop == "center":
		var l2 := OmniLight3D.new()
		l2.light_color = Color("#ffd8a0")
		l2.light_energy = 0.7
		l2.omni_range = 3.5
		l2.position = Vector3(door_lx, 1.6, d / 2.0 + 0.6)
		node.add_child(l2)
	return node


# ---------------------------------------------------------------- Beast Center: a 1950s roadside diner
static func _diner(k: Kit, w: float, d: float, door_lx: float) -> void:
	var chrome := Color("#dfe3e8")
	var red := Color("#d8283a")
	var teal := Color("#4fd0c0")
	var white := Color("#f6f6f2")
	# checkered plinth
	var cells := int(w * 2.0)
	for i in cells:
		for j in int(d * 2.0):
			var on := (i + j) % 2 == 0
			k.box("color", Vector3(-w / 2.0 + 0.25 + i * 0.5, 0.06, -d / 2.0 + 0.25 + j * 0.5), Vector3(0.5, 0.12, 0.5), Color("#f2f2ee") if on else Color("#2a2a30"))
	var y0 := 0.12
	var H := 2.0
	var bw := w - 0.8
	var bd := d - 0.6
	# body with rounded (stepped) ends
	k.box("tin", Vector3(0, y0 + H / 2.0, 0), Vector3(bw, H, bd), chrome)
	for sx in [-1, 1]:
		k.box("tin", Vector3(sx * (bw / 2.0 + 0.15), y0 + H / 2.0, 0), Vector3(0.3, H, bd - 0.4), chrome)
		k.box("tin", Vector3(sx * (bw / 2.0 + 0.35), y0 + H / 2.0, 0), Vector3(0.1, H, bd - 1.0), chrome.darkened(0.05))
	# red belt, thin teal pinstripe, white kick plate
	k.box("color", Vector3(0, y0 + 0.62, 0), Vector3(bw + 0.04, 0.26, bd + 0.04), red)
	for sx in [-1, 1]:
		k.box("color", Vector3(sx * (bw / 2.0 + 0.15), y0 + 0.62, 0), Vector3(0.32, 0.26, bd - 0.36), red)
	k.box("color", Vector3(0, y0 + 0.88, bd / 2.0 + 0.01), Vector3(bw, 0.06, 0.04), teal)
	k.box("color", Vector3(0, y0 + 0.2, bd / 2.0 + 0.01), Vector3(bw, 0.3, 0.04), white)
	# a long run of windows (with room beside the door for the pawprint sign)
	var x := -bw / 2.0 + 0.45
	while x < bw / 2.0 - 0.3:
		if absf(x - door_lx) > 0.75 and absf(x - door_lx - 0.95) > 0.6:
			k.box("color", Vector3(x, y0 + 1.42, bd / 2.0 + 0.02), Vector3(0.66, 0.78, 0.05), chrome.darkened(0.25))
			k.box("glow", Vector3(x, y0 + 1.42, bd / 2.0 + 0.05), Vector3(0.56, 0.66, 0.03), Color("#fff2c8"))
		x += 0.72
	# glass door in a chrome frame
	k.box("color", Vector3(door_lx, y0 + 0.75, bd / 2.0 + 0.03), Vector3(0.9, 1.5, 0.06), chrome.darkened(0.3))
	k.box("glow", Vector3(door_lx, y0 + 0.75, bd / 2.0 + 0.06), Vector3(0.66, 1.3, 0.03), Color("#bfe8ff"))
	k.box("color", Vector3(door_lx + 0.22, y0 + 0.7, bd / 2.0 + 0.09), Vector3(0.05, 0.3, 0.04), chrome)
	# red-and-white awning over the door
	for i in 4:
		k.box("color", Vector3(door_lx - 0.45 + i * 0.3, y0 + 1.62, bd / 2.0 + 0.35), Vector3(0.3, 0.07, 0.6), red if i % 2 == 0 else white)
	# flat roof with an overhang and a red trim
	k.box("tin", Vector3(0, y0 + H + 0.06, 0), Vector3(w - 0.2, 0.12, d - 0.3), white)
	k.box("color", Vector3(0, y0 + H + 0.06, (d - 0.3) / 2.0), Vector3(w - 0.2, 0.14, 0.06), red)


# ---------------------------------------------------------------- shops
static func _shop(k: Kit, w: float, d: float, st: Dictionary, look: Dictionary, shop: String, door_lx: float, rng: RandomNumberGenerator) -> void:
	var trim := Color(look.get("trim", st["trim"]))
	var brand := Color(SHOP_ROOF.get(shop, "#c84040"))
	var dark := Color("#2e2a2a")
	var roof_tex: String = st["roof"][0]
	var roof_col := Color(SHOP_ROOF.get(shop, st["roof"][1])).lerp(Color(st["roof"][1]), 0.5)
	var lift := 0.0
	if st.get("stilts", false):
		lift = 0.45
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				k.box("color", Vector3(sx * (w / 2.0 - 0.3), lift / 2.0, sz * (d / 2.0 - 0.3)), Vector3(0.2, lift, 0.2), trim)
		k.box("planks", Vector3(0, lift - 0.05, 0), Vector3(w - 0.1, 0.1, d - 0.1), trim.lightened(0.2))
		k.box("planks", Vector3(door_lx, 0.1, d / 2.0 + 0.15), Vector3(0.9, 0.2, 0.3), trim.lightened(0.1))
		k.box("planks", Vector3(door_lx, 0.3, d / 2.0 - 0.05), Vector3(0.9, 0.2, 0.2), trim.lightened(0.1))
	else:
		k.box("stone", Vector3(0, 0.08, 0), Vector3(w - 0.05, 0.16, d - 0.05), Color(st["base"]))
	var wy := lift + 0.16
	var ww := w - 0.2
	var wd := d - 0.3
	var front := wd / 2.0
	var two: bool = int(look["floors"]) == 2
	var G := SHOP_GROUND
	var U := SHOP_UPPER if two else 0.0
	var top := wy + G + U
	# ---- the shop floor
	k.box(String(look["ground"][0]), Vector3(0, wy + G / 2.0, 0), Vector3(ww, G, wd), Color(look["ground"][1]))
	for sx in [-1, 1]:
		k.box("color", Vector3(sx * ww / 2.0, wy + G / 2.0, front), Vector3(0.18, G + 0.02, 0.16), trim)
	if look.get("open", false):
		# a market stall: a wide opening with goods piled on the counter
		k.box("color", Vector3(0, wy + 1.25, front + 0.01), Vector3(ww - 0.7, 1.0, 0.02), Color("#3a2a1e"))
		k.box("planks", Vector3(0, wy + 0.72, front + 0.16), Vector3(ww - 0.5, 0.1, 0.36), trim.lightened(0.25))
		var gx := -ww / 2.0 + 0.55
		while gx < ww / 2.0 - 0.4:
			if absf(gx - door_lx) > 0.6:
				k.box("color", Vector3(gx, wy + 0.86, front + 0.16), Vector3(0.22, 0.18, 0.22), Color.from_hsv(rng.randf(), 0.6, 0.85))
			gx += 0.36
	else:
		# big display windows either side of the door
		for side in [-1, 1]:
			var a: float = door_lx + side * 0.55
			var b: float = side * (ww / 2.0 - 0.22)
			var span := absf(b - a)
			if span < 0.45:
				continue
			var cx: float = (a + b) / 2.0
			k.box("color", Vector3(cx, wy + 0.25, front + 0.04), Vector3(span, 0.5, 0.06), brand.darkened(0.35))
			k.box("color", Vector3(cx, wy + 1.08, front + 0.04), Vector3(span, 1.2, 0.06), dark)
			k.box("glow", Vector3(cx, wy + 1.08, front + 0.07), Vector3(span - 0.14, 1.06, 0.03), Color("#ffe9b8"))
			var m: float = cx - span / 2.0 + 0.6
			while m < cx + span / 2.0 - 0.3:
				k.box("color", Vector3(m, wy + 1.08, front + 0.09), Vector3(0.05, 1.06, 0.03), dark)
				m += 0.6
			# a few goods on show
			for i in int(span / 0.3):
				if rng.randf() < 0.55:
					var gx2: float = cx - span / 2.0 + 0.2 + i * 0.3
					k.box("color", Vector3(gx2, wy + 0.62 + rng.randf() * 0.1, front + 0.1), Vector3(0.16, 0.2, 0.04), Color.from_hsv(rng.randf(), 0.55, 0.8))
	# the door
	k.box("color", Vector3(door_lx, wy + 0.7, front + 0.04), Vector3(0.86, 1.4, 0.08), dark)
	k.box("planks_v", Vector3(door_lx, wy + 0.64, front + 0.07), Vector3(0.64, 1.26, 0.06), Color(st["door"]))
	k.box("glow", Vector3(door_lx, wy + 0.95, front + 0.1), Vector3(0.36, 0.4, 0.03), Color("#ffe9b8"))
	k.box("color", Vector3(door_lx + 0.21, wy + 0.62, front + 0.12), Vector3(0.06, 0.06, 0.04), Color("#e8c060"))
	# sign board (the shop's icon hangs on it) and a striped awning
	k.box("color", Vector3(0, wy + G - 0.3, front + 0.06), Vector3(ww + 0.04, 0.42, 0.1), brand.darkened(0.15))
	k.box("color", Vector3(0, wy + G - 0.07, front + 0.08), Vector3(ww + 0.08, 0.06, 0.12), trim)
	var n_st := maxi(3, int(ww / 0.4))
	var stw := ww / n_st
	for i in n_st:
		var col := brand if i % 2 == 0 else Color("#f6f2e8")
		var x := -ww / 2.0 + stw * (i + 0.5)
		k.box("color", Vector3(x, wy + 1.74, front + 0.2), Vector3(stw, 0.07, 0.36), col)
		k.box("color", Vector3(x, wy + 1.64, front + 0.5), Vector3(stw, 0.07, 0.3), col.darkened(0.08))
		k.box("color", Vector3(x, wy + 1.55, front + 0.66), Vector3(stw, 0.14, 0.04), col.darkened(0.12))
	# ---- the flat upstairs
	var jet := 0.0
	if two:
		jet = 0.22 if look.get("jetty", false) else 0.0
		var utex: String = look["upper"][0]
		var ucol := Color(look["upper"][1])
		k.box("color", Vector3(0, wy + G + 0.02, jet / 2.0), Vector3(ww + 0.14, 0.14, wd + jet + 0.08), trim)
		k.box(utex, Vector3(0, wy + G + U / 2.0, jet / 2.0), Vector3(ww, U, wd + jet), ucol)
		var glass := Color(st.get("window", "#bfe0ff"))
		var nw := maxi(2, int(ww / 1.25))
		for i in nw:
			var x2 := -ww / 2.0 + ww / nw * (i + 0.5)
			var p := Vector3(x2, wy + G + U * 0.52, front + jet)
			_window(k, p, Vector3(0, 0, 1), trim, glass)
			k.box("color", p + Vector3(0, -0.36, 0.08), Vector3(0.72, 0.06, 0.14), trim)
			if String(look["roof"]) == "flat" and rng.randf() < 0.5:
				# a window box of flowers
				k.box("planks", p + Vector3(0, -0.45, 0.14), Vector3(0.6, 0.14, 0.14), Color("#7a5232"))
				for f in 3:
					k.box("color", p + Vector3(-0.2 + f * 0.2, -0.34, 0.15), Vector3(0.1, 0.1, 0.1), Color.from_hsv(rng.randf(), 0.6, 0.95))
		if d >= 3:
			for sx in [-1, 1]:
				_window(k, Vector3(sx * ww / 2.0, wy + G + U * 0.52, jet / 2.0), Vector3(sx, 0, 0), trim, glass)
		if look.get("balcony", false):
			# porch roof over the shop front, with a railing round the balcony on top of it
			k.box("planks", Vector3(0, wy + G + 0.02, front + 0.5), Vector3(ww + 0.1, 0.1, 1.0), trim.lightened(0.2))
			for px in [-ww / 2.0 + 0.1, ww / 2.0 - 0.1]:
				k.box("color", Vector3(px, (wy + G) / 2.0, front + 0.92), Vector3(0.1, wy + G, 0.1), trim)
			k.box("color", Vector3(0, wy + G + 0.5, front + 0.96), Vector3(ww + 0.1, 0.06, 0.06), trim)
			var r := -ww / 2.0 + 0.1
			while r <= ww / 2.0 - 0.05:
				k.box("color", Vector3(r, wy + G + 0.28, front + 0.96), Vector3(0.05, 0.44, 0.05), trim)
				r += 0.3
		if look.get("skirt", false):
			k.box(roof_tex, Vector3(0, wy + G + 0.12, 0), Vector3(ww + 0.8, 0.14, wd + 0.8), roof_col)
			k.box(roof_tex, Vector3(0, wy + G + 0.24, 0), Vector3(ww + 0.4, 0.12, wd + 0.4), roof_col.darkened(0.05))
	# ---- the roof
	match String(look["roof"]):
		"flat":
			var slab := Color(look.get("flat_roof", "#5a5650"))
			var ptex: String = look["upper"][0]
			var pcol := Color(look["upper"][1])
			k.box("tin", Vector3(0, top + 0.06, 0), Vector3(ww + 0.06, 0.12, wd + 0.06), slab)
			# parapet, with a cornice along the street side
			k.box(ptex, Vector3(0, top + 0.24, front - 0.04), Vector3(ww + 0.06, 0.48, 0.14), pcol)
			k.box(ptex, Vector3(0, top + 0.17, -front + 0.04), Vector3(ww + 0.06, 0.34, 0.14), pcol)
			for sx in [-1, 1]:
				k.box(ptex, Vector3(sx * (ww / 2.0 - 0.04), top + 0.17, 0), Vector3(0.14, 0.34, wd), pcol)
			k.box("color", Vector3(0, top + 0.5, front - 0.02), Vector3(ww + 0.26, 0.08, 0.3), trim)
			k.box("color", Vector3(0, top - 0.06, front + 0.02), Vector3(ww + 0.14, 0.1, 0.14), trim)
			# a little roof hatch
			k.box("tin", Vector3(-ww / 4.0, top + 0.3, -wd / 5.0), Vector3(0.6, 0.36, 0.5), slab.lightened(0.15))
			if look.get("vigas", false):
				var vx := -ww / 2.0 + 0.3
				while vx < ww / 2.0 - 0.2:
					k.box("planks", Vector3(vx, top - 0.22, front + 0.12), Vector3(0.12, 0.12, 0.3), Color("#6a4a2a"))
					vx += 0.55
		"gable", "steep":
			_roof(k, String(look["roof"]), w, d + jet, top, roof_tex, roof_col, String(look["upper"][0]), Color(look["upper"][1]), trim)
		"false_front":
			k.box(roof_tex, Vector3(0, top + 0.06, -0.15), Vector3(ww, 0.12, wd - 0.2), Color(st["roof"][1]))
			var face_tex: String = look["upper"][0] if two else look["ground"][0]
			var face_col := Color(look["upper"][1]) if two else Color(look["ground"][1]).lightened(0.1)
			k.box(face_tex, Vector3(0, top + 0.6, front - 0.05), Vector3(ww + 0.1, 1.2, 0.14), face_col)
			k.box("color", Vector3(0, top + 1.24, front - 0.05), Vector3(ww + 0.22, 0.1, 0.22), trim)
			k.box("color", Vector3(0, top + 0.62, front + 0.04), Vector3(ww * 0.72, 0.5, 0.06), brand)
			k.box("color", Vector3(0, top + 0.62, front + 0.06), Vector3(ww * 0.72 - 0.16, 0.34, 0.04), Color("#f6f2e8"))
		"pagoda", "hip":
			_roof(k, String(look["roof"]), w, d, top, roof_tex, roof_col, String(look["ground"][0]), Color(look["ground"][1]), trim)
	if st.get("pipes", false):
		var copper := Color("#b8703a")
		k.box("brass", Vector3(ww / 2.0 + 0.08, (top + wy) / 2.0, -wd / 4.0), Vector3(0.14, top - wy, 0.14), copper)
		k.box("brass", Vector3(ww / 2.0 - 0.5, top + 0.5, -wd / 4.0), Vector3(0.36, 0.7, 0.36), Color("#4a4a52"))
		_gear(k, Vector3(-ww / 2.0 + 0.5, wy + G + U * 0.5, front + jet + 0.06), 0.3, Color("#c8a040"))
	if st.get("lanterns", false):
		for sx in [-1, 1]:
			k.box("glow", Vector3(door_lx + sx * 0.65, wy + 1.4, front + 0.2), Vector3(0.2, 0.28, 0.2), Color("#ff6a3a"))
		# a noren curtain over the door
		k.box("color", Vector3(door_lx, wy + 1.32, front + 0.14), Vector3(0.8, 0.28, 0.03), brand.darkened(0.2))


# ---------------------------------------------------------------- generic house/shop
static func _house(k: Kit, w: float, d: float, H: float, st: Dictionary, shop: String, door_lx: float, rng: RandomNumberGenerator, locked := false) -> void:
	var wall_tex: String = st["wall"][0]
	var wall_col := Color(st["wall"][1])
	var roof_tex: String = st["roof"][0]
	var roof_col := Color(SHOP_ROOF.get(shop, st["roof"][1])) if shop != "house" else Color(st["roof"][1]).lerp(Color.from_hsv(rng.randf(), 0.4, 0.7), 0.25)
	var trim := Color(st["trim"])
	var base := Color(st["base"])
	var lift := 0.0
	if st.get("stilts", false):
		lift = 0.45
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				k.box("color", Vector3(sx * (w / 2.0 - 0.3), lift / 2.0, sz * (d / 2.0 - 0.3)), Vector3(0.2, lift, 0.2), trim)
		k.box("planks", Vector3(0, lift - 0.05, 0), Vector3(w - 0.1, 0.1, d - 0.1), trim.lightened(0.2))
		# steps up to the door
		k.box("planks", Vector3(door_lx, 0.1, d / 2.0 + 0.15), Vector3(0.9, 0.2, 0.3), trim.lightened(0.1))
		k.box("planks", Vector3(door_lx, 0.3, d / 2.0 - 0.05), Vector3(0.9, 0.2, 0.2), trim.lightened(0.1))
	else:
		k.box("stone", Vector3(0, 0.08, 0), Vector3(w - 0.05, 0.16, d - 0.05), base)
	var wy := lift + 0.16
	var ww := w - 0.2
	var wd := d - 0.3
	k.box(wall_tex, Vector3(0, wy + H / 2.0, 0), Vector3(ww, H, wd), wall_col)
	# corner posts and beams
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.box("color", Vector3(sx * ww / 2.0, wy + H / 2.0, sz * wd / 2.0), Vector3(0.16, H + 0.02, 0.16), trim)
	k.box("color", Vector3(0, wy + H - 0.06, wd / 2.0 + 0.02), Vector3(ww + 0.1, 0.12, 0.08), trim)
	# door
	k.box("color", Vector3(door_lx, wy + 0.65, wd / 2.0 + 0.04), Vector3(0.82, 1.32, 0.08), trim)
	k.box("planks_v", Vector3(door_lx, wy + 0.6, wd / 2.0 + 0.07), Vector3(0.62, 1.2, 0.06), LOCKED_DOOR if locked else Color(st["door"]))
	if locked:
		_door_lock(k, Vector3(door_lx, wy + 0.6, wd / 2.0 + 0.1), 0.62, 1.2)
	else:
		k.box("color", Vector3(door_lx + 0.2, wy + 0.6, wd / 2.0 + 0.11), Vector3(0.06, 0.06, 0.04), Color("#e8c060"))
	# windows on the front and sides
	var glass := Color(st.get("window", "#ffe8a8"))
	var xs := []
	var x := -ww / 2.0 + 0.75
	while x < ww / 2.0 - 0.5:
		if absf(x - door_lx) > 0.8:
			xs.append(x)
		x += 1.4
	for wx in xs:
		_window(k, Vector3(wx, wy + H * 0.55, wd / 2.0), Vector3(0, 0, 1), trim, glass)
	if d >= 3:
		_window(k, Vector3(ww / 2.0, wy + H * 0.55, 0), Vector3(1, 0, 0), trim, glass)
		_window(k, Vector3(-ww / 2.0, wy + H * 0.55, 0), Vector3(-1, 0, 0), trim, glass)
	# awning over shop doors
	if shop not in ["house", "home"]:
		var aw := Color(SHOP_ROOF.get(shop, "#c84040"))
		for i in 3:
			k.box("color", Vector3(door_lx - 0.4 + i * 0.4, wy + 1.55, wd / 2.0 + 0.35), Vector3(0.4, 0.08, 0.6), aw if i % 2 == 0 else Color("#f4f0e8"))
	var rt := String(st["roof_type"])
	if rt == "western" and shop in ["house", "home"]:
		# out west only shops wear false fronts; homes get a plain tin gable
		rt = "gable"
	_roof(k, rt, w, d, wy + H, roof_tex, roof_col, wall_tex, wall_col, trim)
	# extras
	if st.get("pipes", false):
		var copper := Color("#b8703a")
		k.box("brass", Vector3(ww / 2.0 + 0.08, wy + H * 0.6, -wd / 4.0), Vector3(0.14, H * 1.3, 0.14), copper)
		k.box("brass", Vector3(-ww / 2.0 + 0.4, wy + H + 1.1, -wd / 4.0), Vector3(0.36, 1.2, 0.36), Color("#4a4a52"))
		_gear(k, Vector3(ww / 2.0 - 0.6, wy + H * 0.8, wd / 2.0 + 0.06), 0.32, Color("#c8a040"))
	if st.get("lanterns", false):
		for sx in [-1, 1]:
			k.box("glow", Vector3(door_lx + sx * 0.65, wy + 1.4, wd / 2.0 + 0.2), Vector3(0.2, 0.28, 0.2), Color("#ff6a3a"))
	if shop in ["house", "home"] and String(st["roof_type"]) in ["gable", "steep"] and rng.randf() < 0.7:
		k.box("brick", Vector3(-ww / 4.0, wy + H + 0.9, -wd / 4.0), Vector3(0.35, 1.1, 0.35), Color("#8a5a4a"))


## A temple's way in: a stone arch with a glowing keystone at the front of its base, and a vaulted passage running
## back into the ruin, so the doorway is part of the temple rather than a dark slab standing in front of it.
static func _temple_gate(d: float, door_lx: float, glow: Color) -> ArrayMesh:
	var k := Kit.new()
	var stone := Color("#8a7260")
	var fz := d / 2.0 - 0.05
	k.box("stone", Vector3(door_lx, 0.95, fz - 0.9), Vector3(1.5, 1.9, 1.8), stone.darkened(0.15))
	k.box("color", Vector3(door_lx, 0.72, fz + 0.01), Vector3(0.9, 1.44, 0.02), Color("#0a0806"))
	for sx in [-1, 1]:
		k.box("stone", Vector3(door_lx + sx * 0.62, 1.05, fz), Vector3(0.28, 2.1, 0.36), stone)
		k.box("stone", Vector3(door_lx + sx * 0.62, 0.1, fz), Vector3(0.4, 0.2, 0.46), stone.darkened(0.1))
	k.box("stone", Vector3(door_lx, 2.08, fz), Vector3(1.66, 0.3, 0.4), stone.lightened(0.05))
	k.box("glow", Vector3(door_lx, 2.08, fz + 0.21), Vector3(0.22, 0.24, 0.04), glow)
	k.box("stone", Vector3(door_lx, 0.05, fz + 0.3), Vector3(1.2, 0.1, 0.24), stone.darkened(0.05))
	return k.mesh()


## How far in front of a building's centre its sign hangs: the wall face (or a shop's sign board) it's fixed to.
static func _sign_face(shop: String, d: float) -> float:
	if shop in COMMERCIAL:
		return (d - 0.3) / 2.0 + 0.11
	match shop:
		"center":
			return (d - 0.6) / 2.0
		"skytower":
			return (d - 0.8) / 2.0
	return (d - 0.3) / 2.0


## The z that puts the back of `mesh` flat against a surface at `face`.
static func _on_face(mesh: Mesh, face: float) -> float:
	return face - mesh.get_aabb().position.z + 0.004


## Dresses a locked door: two iron straps across it and a brass padlock where the handle would be.
## `c` is the centre of the door's front face; `dw` and `dh` its width and height.
static func _door_lock(k: Kit, c: Vector3, dw: float, dh: float) -> void:
	var iron := Color("#2a2a30")
	for f in [-0.28, 0.28]:
		k.box("color", Vector3(c.x, c.y + dh * f, c.z + 0.015), Vector3(dw + 0.04, 0.07, 0.03), iron)
	var brass := Color("#f0c850")
	var lp := Vector3(c.x + dw * 0.3, c.y - 0.06, c.z + 0.04)
	k.box("color", lp, Vector3(0.13, 0.11, 0.05), brass)
	k.box("color", lp + Vector3(0, -0.01, 0.026), Vector3(0.03, 0.045, 0.01), Color("#3a2a10"))
	for sx in [-0.04, 0.04]:
		k.box("color", lp + Vector3(sx, 0.08, 0), Vector3(0.025, 0.06, 0.025), iron.lightened(0.4))
	k.box("color", lp + Vector3(0, 0.115, 0), Vector3(0.105, 0.025, 0.025), iron.lightened(0.4))


static func _window(k: Kit, p: Vector3, n: Vector3, trim: Color, glass: Color) -> void:
	var out := n * 0.04
	if n.z != 0:
		k.box("color", p + out, Vector3(0.62, 0.62, 0.06), trim)
		k.box("glow", p + out * 2.0, Vector3(0.46, 0.46, 0.04), glass)
		k.box("color", p + out * 2.5, Vector3(0.06, 0.46, 0.04), trim)
	else:
		k.box("color", p + out, Vector3(0.06, 0.62, 0.62), trim)
		k.box("glow", p + out * 2.0, Vector3(0.04, 0.46, 0.46), glass)


static func _gear(k: Kit, c: Vector3, r: float, col: Color) -> void:
	k.box("brass", c, Vector3(r * 1.4, r * 1.4, 0.08), col)
	for i in 8:
		var a := i * TAU / 8.0
		k.box("brass", c + Vector3(cos(a), sin(a), 0) * r * 0.95, Vector3(0.12, 0.12, 0.08), col.darkened(0.15))
	k.box("color", c + Vector3(0, 0, 0.05), Vector3(0.12, 0.12, 0.04), Color("#3a3a3a"))


static func _roof(k: Kit, t: String, w: float, d: float, top: float, tex: String, col: Color, wall_tex: String, wall_col: Color, trim: Color) -> void:
	match t:
		"gable", "steep":
			var steps := int(ceil(d / 2.0 / 0.25)) + 1
			var rise := 0.22 if t == "gable" else 0.42
			for i in steps:
				var depth := d + 0.5 - i * 0.5
				if depth <= 0.1:
					break
				k.box(tex, Vector3(0, top + i * rise + 0.08, 0), Vector3(w + 0.3, 0.18, depth), col.darkened(0.04 * (i % 2)))
				if i > 0:
					k.box(wall_tex, Vector3(0, top + (i - 0.5) * rise, 0), Vector3(w - 0.3, rise, maxf(0.1, depth - 0.6)), wall_col)
		"hip", "pagoda":
			var layers := 6 if t == "hip" else 4
			for i in layers:
				var f := 1.0 - float(i) / layers
				var ex := 0.45 if t == "hip" else (0.6 if i == 0 else 0.3)
				k.box(tex, Vector3(0, top + i * 0.24 + 0.1, 0), Vector3((w + ex) * f + 0.2, 0.22, (d + ex) * f + 0.2), col.darkened(0.05 * (i % 2)))
				if t == "pagoda" and i == 0:
					for sx in [-1, 1]:
						for sz in [-1, 1]:
							k.box(tex, Vector3(sx * (w / 2.0 + 0.35), top + 0.24, sz * (d / 2.0 + 0.35)), Vector3(0.3, 0.12, 0.3), col)
			k.box("color", Vector3(0, top + layers * 0.24 + 0.15, 0), Vector3(0.2, 0.3, 0.2), trim)
		"flat":
			k.box(tex, Vector3(0, top + 0.08, 0), Vector3(w - 0.1, 0.16, d - 0.2), col)
			for sz in [-1, 1]:
				k.box(tex, Vector3(0, top + 0.3, sz * (d / 2.0 - 0.2)), Vector3(w - 0.1, 0.3, 0.16), col.lightened(0.05))
			for sx in [-1, 1]:
				k.box(tex, Vector3(sx * (w / 2.0 - 0.1), top + 0.3, 0), Vector3(0.16, 0.3, d - 0.2), col.lightened(0.05))
			var x := -w / 2.0 + 0.5
			while x < w / 2.0 - 0.3:
				k.box("color", Vector3(x, top - 0.25, d / 2.0 - 0.05), Vector3(0.12, 0.12, 0.35), trim)
				x += 0.7
		"western":
			k.box(tex, Vector3(0, top + 0.06, -0.15), Vector3(w - 0.1, 0.12, d - 0.2), col)
			k.box("planks", Vector3(0, top + 0.55, d / 2.0 - 0.12), Vector3(w + 0.1, 1.1, 0.14), wall_col.lightened(0.12))
			k.box("color", Vector3(0, top + 1.12, d / 2.0 - 0.12), Vector3(w + 0.2, 0.1, 0.2), trim)
			# porch roof and posts
			k.box("planks", Vector3(0, top - 0.6, d / 2.0 + 0.45), Vector3(w + 0.1, 0.08, 0.9), trim.lightened(0.2))
			for px in [-w / 2.0 + 0.1, w / 2.0 - 0.1]:
				k.box("color", Vector3(px, (top - 0.6) / 2.0, d / 2.0 + 0.85), Vector3(0.1, top - 0.6, 0.1), trim)
		"shed":
			for i in 4:
				k.box(tex, Vector3(0, top + i * 0.12 + 0.06, -d / 2.0 + 0.25 + i * (d / 4.0) * 0.0), Vector3(w + 0.3, 0.12, d + 0.3 - i * 0.2), col.darkened(0.05 * (i % 2)))


# ---------------------------------------------------------------- special buildings
static func _arena(k: Kit, w: float, d: float, st: Dictionary, door_lx: float) -> void:
	var stone := Color("#c8bca8")
	var H := 3.0
	k.box("stone", Vector3(0, H / 2.0, 0), Vector3(w - 0.2, H, d - 0.3), stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.box("stone", Vector3(sx * (w / 2.0 - 0.3), (H + 0.8) / 2.0, sz * (d / 2.0 - 0.35)), Vector3(0.9, H + 0.8, 0.9), stone.lightened(0.05))
			k.box("color", Vector3(sx * (w / 2.0 - 0.3), H + 0.95, sz * (d / 2.0 - 0.35)), Vector3(0.2, 0.5, 0.2), Color("#c83a3a"))
	var x := -w / 2.0 + 0.3
	while x < w / 2.0:
		k.box("stone", Vector3(x, H + 0.15, d / 2.0 - 0.2), Vector3(0.3, 0.3, 0.3), stone)
		k.box("stone", Vector3(x, H + 0.15, -d / 2.0 + 0.2), Vector3(0.3, 0.3, 0.3), stone)
		x += 0.6
	# arches and banners
	x = -w / 2.0 + 1.0
	var i := 0
	while x < w / 2.0 - 0.6:
		if absf(x - door_lx) > 1.0:
			k.box("color", Vector3(x, 1.6, d / 2.0 - 0.1), Vector3(0.5, 1.2, 0.06), Color("#3a2a20"))
			k.box("color", Vector3(x, 2.4, d / 2.0 - 0.08), Vector3(0.6, 0.9, 0.05), [Color("#c83a3a"), Color("#3a6ac8"), Color("#e8c040")][i % 3])
			i += 1
		x += 1.2
	k.box("color", Vector3(door_lx, 0.9, d / 2.0 - 0.1), Vector3(1.6, 1.8, 0.1), Color("#c8a040"))
	k.box("planks_v", Vector3(door_lx, 0.85, d / 2.0 - 0.05), Vector3(1.3, 1.6, 0.06), Color("#6a4a2a"))


static func _skytower(k: Kit, w: float, d: float, st: Dictionary) -> void:
	var wall_tex: String = st["wall"][0]
	var col := Color(st["wall"][1])
	var trim := Color(st["trim"])
	var H := 6.8
	k.box("stone", Vector3(0, 0.1, 0), Vector3(w - 0.1, 0.2, d - 0.1), Color(st["base"]))
	k.box(wall_tex, Vector3(0, H / 2.0, 0), Vector3(w - 0.8, H, d - 0.8), col)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.box("color", Vector3(sx * (w - 0.8) / 2.0, H / 2.0, sz * (d - 0.8) / 2.0), Vector3(0.2, H, 0.2), trim)
	# windows up the stairwell (clear of the sign over the door)
	for y in [3.0, 4.4, 5.8]:
		k.box("glow", Vector3(0, y, (d - 0.8) / 2.0 + 0.02), Vector3(0.4, 0.6, 0.04), Color("#ffe8a8"))
	k.box("planks", Vector3(0, H + 0.1, 0), Vector3(w + 0.4, 0.2, d + 0.4), trim.lightened(0.2))
	var x := -(w + 0.4) / 2.0
	while x <= (w + 0.4) / 2.0 + 0.01:
		for sz in [-1, 1]:
			k.box("color", Vector3(x, H + 0.45, sz * (d + 0.4) / 2.0), Vector3(0.08, 0.5, 0.08), trim)
		x += 0.5
	k.box("color", Vector3(0, H + 0.7, (d + 0.4) / 2.0), Vector3(w + 0.4, 0.06, 0.06), trim)
	k.box("color", Vector3(0, H + 0.7, -(d + 0.4) / 2.0), Vector3(w + 0.4, 0.06, 0.06), trim)
	k.box("color", Vector3((w + 0.4) / 2.0, H + 1.3, -(d + 0.4) / 2.0), Vector3(0.08, 1.8, 0.08), trim)
	k.box("color", Vector3((w + 0.4) / 2.0 - 0.35, H + 1.95, -(d + 0.4) / 2.0), Vector3(0.6, 0.3, 0.04), Color("#e84a3a"))
	# the door, in a frame, standing on the plinth
	var front := (d - 0.8) / 2.0
	k.box("color", Vector3(0, 0.92, front + 0.04), Vector3(0.88, 1.44, 0.08), trim)
	k.box("planks_v", Vector3(0, 0.86, front + 0.07), Vector3(0.68, 1.3, 0.06), Color(st["door"]))
	k.box("color", Vector3(0.22, 0.84, front + 0.11), Vector3(0.06, 0.06, 0.04), Color("#e8c060"))


static func _electronics(k: Kit, w: float, d: float, door_lx: float) -> void:
	var H := 2.6
	var fz := (d - 0.3) / 2.0
	var y0 := 0.16
	var metal := Color("#3a4a5a")
	k.box("stone", Vector3(0, 0.08, 0), Vector3(w - 0.05, 0.16, d - 0.05), Color("#8a8a90"))
	k.box("plaster", Vector3(0, y0 + H / 2.0, 0), Vector3(w - 0.2, H, d - 0.3), Color("#c8ccd4"))
	# shop windows either side of the door, lit by the screens on show
	for side in [-1, 1]:
		var a: float = door_lx + side * 0.6
		var b: float = side * ((w - 0.2) / 2.0 - 0.3)
		var span := absf(b - a)
		if span < 0.4:
			continue
		var cx: float = (a + b) / 2.0
		k.box("color", Vector3(cx, y0 + 1.05, fz + 0.03), Vector3(span, 1.4, 0.06), metal)
		k.box("glow", Vector3(cx, y0 + 1.05, fz + 0.07), Vector3(span - 0.12, 1.26, 0.02), Color("#8ad8ff"))
	# a glass door in a metal frame, with a push bar
	k.box("color", Vector3(door_lx, y0 + 0.76, fz + 0.04), Vector3(0.9, 1.52, 0.08), metal)
	k.box("glow", Vector3(door_lx, y0 + 0.74, fz + 0.09), Vector3(0.66, 1.34, 0.02), Color("#bfeaff"))
	k.box("color", Vector3(door_lx, y0 + 0.72, fz + 0.115), Vector3(0.5, 0.05, 0.04), Color("#d8dce4"))
	k.box("glow", Vector3(0, H + 0.1, fz + 0.05), Vector3(w - 0.1, 0.12, 0.06), Color("#3affd8"))
	k.box("tin", Vector3(0, H + 0.24, 0), Vector3(w, 0.16, d - 0.1), Color("#5a5a66"))
	k.box("color", Vector3(w / 2.0 - 0.6, H + 0.75, -0.3), Vector3(0.08, 0.9, 0.08), Color("#8a8a90"))
	k.box("color", Vector3(w / 2.0 - 0.6, H + 1.25, -0.3), Vector3(0.6, 0.5, 0.06), Color("#d8dce4"))


static func _ceo_tower(k: Kit, w: float, d: float, door_lx: float) -> void:
	var brick := Color("#8a3a2a")
	var brass := Color("#c8a040")
	var y := 0.0
	var tiers := [[w - 0.2, d - 0.3, 4.0], [w - 1.2, d - 1.0, 4.0], [w - 2.0, d - 1.6, 3.5], [w - 2.8, d - 2.2, 2.5]]
	for t in tiers:
		k.box("brick", Vector3(0, y + t[2] / 2.0, 0), Vector3(t[0], t[2], t[1]), brick)
		k.box("brass", Vector3(0, y + t[2] - 0.08, 0), Vector3(t[0] + 0.15, 0.16, t[1] + 0.15), brass)
		var x: float = -t[0] / 2.0 + 0.5
		while x < t[0] / 2.0 - 0.3:
			for ry in range(1, int(t[2])):
				k.box("glow", Vector3(x, y + ry - 0.1, t[1] / 2.0 + 0.03), Vector3(0.36, 0.5, 0.04), Color("#ffd890"))
			x += 0.8
		y += t[2]
	# clock face and spire
	k.box("color", Vector3(0, 10.6, (d - 1.6) / 2.0 + 0.06), Vector3(1.6, 1.6, 0.08), Color("#f4ecd0"))
	k.box("color", Vector3(0, 10.9, (d - 1.6) / 2.0 + 0.11), Vector3(0.08, 0.6, 0.04), Color("#2a2a2a"))
	k.box("color", Vector3(0.2, 10.6, (d - 1.6) / 2.0 + 0.11), Vector3(0.45, 0.08, 0.04), Color("#2a2a2a"))
	k.box("brass", Vector3(0, y + 1.2, 0), Vector3(0.3, 2.4, 0.3), brass)
	k.box("glow", Vector3(0, y + 2.5, 0), Vector3(0.25, 0.25, 0.25), Color("#ff4a3a"))
	for sx in [-1, 1]:
		k.box("brick", Vector3(sx * (w / 2.0 - 0.5), 5.5, -d / 2.0 + 0.6), Vector3(0.6, 11.0, 0.6), Color("#5a5a62"))
	_gear(k, Vector3(-w / 2.0 + 1.0, 2.5, d / 2.0 - 0.1), 0.55, brass)
	_gear(k, Vector3(w / 2.0 - 1.0, 3.2, d / 2.0 - 0.1), 0.4, brass)
	k.box("brass", Vector3(door_lx, 0.9, d / 2.0 - 0.1), Vector3(1.3, 1.8, 0.1), brass)
	k.box("color", Vector3(door_lx, 0.85, d / 2.0 - 0.04), Vector3(1.0, 1.6, 0.06), Color("#2a2a32"))


static func _cathedral(k: Kit, w: float, d: float, door_lx: float, locked := false) -> void:
	var stone := Color("#6a6a74")
	var H := 5.0
	k.box("stone_dark", Vector3(0, H / 2.0, -0.4), Vector3(w - 2.4, H, d - 1.1), stone)
	_roof(k, "steep", w - 2.4, d - 1.1, H, "slate", Color("#2e2e3a"), "stone_dark", stone, Color("#3a3a42"))
	for sx in [-1, 1]:
		var tx: float = sx * (w / 2.0 - 0.75)
		k.box("stone_dark", Vector3(tx, 4.0, d / 2.0 - 0.9), Vector3(1.5, 8.0, 1.5), stone.lightened(0.05))
		for i in 6:
			k.box("slate", Vector3(tx, 8.2 + i * 0.4, d / 2.0 - 0.9), Vector3(1.5 - i * 0.25, 0.4, 1.5 - i * 0.25), Color("#2e2e3a"))
		k.box("glow", Vector3(tx, 5.5, d / 2.0 - 0.13), Vector3(0.4, 1.2, 0.04), Color("#9a6aff"))
	# rose window and doors, flat on the front wall
	var wall := -0.4 + (d - 1.1) / 2.0
	k.box("glow", Vector3(door_lx, 3.4, wall + 0.02), Vector3(1.4, 1.4, 0.04), Color("#c070ff"))
	k.box("color", Vector3(door_lx, 1.1, wall + 0.04), Vector3(1.4, 2.2, 0.08), Color("#2a1a2a"))
	k.box("planks_v", Vector3(door_lx, 1.0, wall + 0.07), Vector3(1.1, 2.0, 0.06), LOCKED_DOOR if locked else Color("#4a2a3a"))
	if locked:
		_door_lock(k, Vector3(door_lx, 1.0, wall + 0.1), 1.1, 2.0)
