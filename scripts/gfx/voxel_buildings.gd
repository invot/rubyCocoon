extends RefCounted
## Voxel-style buildings assembled from textured boxes, in regional styles.
## A building's local origin is the centre of its footprint at ground level; the front faces +Z.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const VP = preload("res://scripts/gfx/voxel_props.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")
const HouseModels = preload("res://scripts/gfx/house_models.gd")

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
	# Bellerive's French Quarter: its buildings are creole_builder.gd's; this is for what's shared (the diner, rooms)
	"creole": {"wall": ["plaster", "#f0cc7a"], "roof": ["slate", "#56626e"], "trim": "#f6f1e6", "base": "#a8a096", "roof_type": "hip", "door": "#2f6048"},
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
## Other buildings that are a house from the PSX pack with the shop front (awning and sign) added (house_models.gd).
const SIGNED_HOUSES := ["dojo", "museum", "music_hall"]
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
	"creole": {"floors": 2, "ground": ["plaster", "#f0cc7a"], "upper": ["plaster", "#f0cc7a"], "roof": "flat", "trim": "#f6f1e6", "flat_roof": "#7a7068"},
}
const SHOP_GROUND := 2.8
const SHOP_UPPER := 2.9
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
		var arr := _arrays(mat)
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
				arr[3].append(Kit.planar_uv(v, n))

	## A flat polygon (3 or 4 corners, any order around its edge) facing `n`: roof slopes, gable ends, eaves.
	## `uv_axis` runs along the texture's rows (roof tiles run along the ridge); world units, like the boxes.
	func poly(mat: String, pts: Array, n: Vector3, col := Color.WHITE, uv_axis := Vector3.ZERO, uv_origin := Vector3.ZERO) -> void:
		var arr := _arrays(mat)
		n = n.normalized()
		var cc := col
		if mat != "glow":
			# the same soft per-face shading the boxes get, by how much the face looks up or away
			var sh := lerpf(0.82, 1.0, clampf(n.y * 0.5 + 0.5 + n.z * 0.15, 0.0, 1.0))
			cc = Color(col.r * sh, col.g * sh, col.b * sh, col.a)
		var tris := [[pts[0], pts[1], pts[2]]]
		if pts.size() == 4:
			tris.append([pts[0], pts[2], pts[3]])
		var u_dir := uv_axis.normalized()
		var v_dir := n.cross(u_dir).normalized() if u_dir != Vector3.ZERO else Vector3.ZERO
		for t in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var d: Vector3 = t[2]
			var tri := [a, b, d] if (b - a).cross(d - a).dot(n) < 0.0 else [a, d, b]
			for v in tri:
				arr[0].append(v)
				arr[1].append(n)
				arr[2].append(cc)
				if u_dir != Vector3.ZERO:
					arr[3].append(Vector2((v - uv_origin).dot(u_dir), (v - uv_origin).dot(v_dir)))
				else:
					arr[3].append(Kit.planar_uv(v, n))

	func _arrays(mat: String) -> Array:
		if not surf.has(mat):
			surf[mat] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array()]
		return surf[mat]

	## Box-style texture coordinates in world units: each face is mapped straight on (crisp, unlike triplanar).
	static func planar_uv(p: Vector3, n: Vector3) -> Vector2:
		if absf(n.y) >= absf(n.x) and absf(n.y) >= absf(n.z):
			return Vector2(p.x, p.z)
		if absf(n.z) >= absf(n.x):
			return Vector2(p.x * signf(n.z), -p.y)
		return Vector2(-p.z * signf(n.x), -p.y)

	func mesh() -> ArrayMesh:
		var m := ArrayMesh.new()
		for key in surf:
			var arr: Array = surf[key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = arr[0]
			arrays[Mesh.ARRAY_NORMAL] = arr[1]
			arrays[Mesh.ARRAY_COLOR] = arr[2]
			arrays[Mesh.ARRAY_TEX_UV] = arr[3]
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material
			if key == "color":
				mat = VT.color_material()
			elif key == "glow":
				mat = VT.glow_material()
			else:
				mat = VT.kit_material(key)
			m.surface_set_material(m.get_surface_count() - 1, mat)
		return m


static func style_for(biome_id: String) -> String:
	return {"coast": "coastal", "island": "island", "desert": "adobe", "western": "western", "canyon": "western",
		"mountain": "mining", "steampunk": "steampunk", "volcano": "hotspring", "hotspring": "hotspring",
		"jungle": "jungle", "river": "town", "moor": "gothic", "forest": "town", "meadow": "town", "quarter": "creole"}.get(biome_id, "town")


## Builds the full node for a building dictionary (shop, w, d, height, door, x, y, seed).
static func build(b: Dictionary, style_name: String) -> Node3D:
	var st: Dictionary = STYLES.get(style_name, STYLES["town"])
	var shop: String = b["shop"]
	var w: float = b["w"]
	var d: float = b["d"]
	var door_lx: float = float(b["door"].x) + 0.5 - (float(b["x"]) + w / 2.0)
	var locked: bool = b.get("locked", false)
	if shop == "fishery":
		return _rust_shack(w, d, door_lx)
	# houses are houses from the PSX pack, fitted to their plot by world.gd (see house_models.gd)
	if not (b.get("house_plan", {}) as Dictionary).is_empty():
		var hp0: Dictionary = b["house_plan"]
		hp0["planters"] = not (shop in COMMERCIAL or shop in SIGNED_HOUSES)
		# (a shop's awning is its porch's roof)
		hp0["porch_roof"] = hp0["planters"]
		var house := HouseModels.build(hp0, locked)
		if shop in COMMERCIAL or shop in SIGNED_HOUSES:
			_shop_front(house, b["house_plan"], shop, st)
		if shop == "uncle":
			_rafe_flute_sign(house, b, hp0["door_at"].y + hp0["door_size"].y / 2.0 + 0.65)
		if locked:
			var lk := Kit.new()
			var hp: Dictionary = b["house_plan"]
			var ds: Vector2 = hp["door_size"]
			_door_lock(lk, hp["door_at"], ds.x, ds.y)
			var lmi := MeshInstance3D.new()
			lmi.mesh = lk.mesh()
			house.add_child(lmi)
		return house
	var node := Node3D.new()
	if shop in COMMERCIAL or shop not in SPECIAL or PACK_LOOKS.has(shop):
		_pack_building(node, b, style_name, st, shop, w, d, door_lx, locked)
		if shop == "uncle":
			_rafe_flute_sign(node, b, 3.15)
		return node
	match shop:
		"skytower":
			_pack_skytower(node, st, w, d, door_lx)
			return node
		"arena":
			_pack_arena(node, style_name, w, d, door_lx, locked)
			return node
		"electronics":
			_pack_electronics(node, w, d, door_lx, locked)
			return node
		"ceo_tower":
			_pack_ceo_tower(node, w, d, door_lx, locked)
			return node
		"cathedral":
			_pack_cathedral(node, w, d, door_lx, locked)
			return node
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
			"hideout":
				pass
			"temple":
				_temple(kit, w, d)
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
		"hideout":
			# a rocky outcrop, tall enough to tunnel into, with a timbered mine entrance in its face
			var rock := VA.instance_footprint("mountain_4", d + 0.4, w + 0.6)
			rock.rotation.y = PI / 2.0
			var rh: float = VA.aabb("mountain_4").size.y * rock.scale.y
			if rh < 3.4:
				rock.scale.y *= 3.4 / maxf(0.1, rh)
				rock.position.y = -VA.aabb("mountain_4").position.y * rock.scale.y
			node.add_child(rock)
			_mine_entrance(node, door_lx, d / 2.0 + 0.05)
		"temple":
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
			gem.position = Vector3(0, _temple(null, w, d) + 0.75, 0)
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
	if shop not in ["house", "home", "hideout", "temple", "decor", "cathedral", "ceo_tower", "center", "uncle"]:
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(shop)
		var hgt := float(b.get("height", 2.4))
		var iy := 2.15
		if STYLES.get(style_name, {}).get("stilts", false):
			iy += 0.45
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


## Buildings with a look of their own; every other house and shop is built from the house pack (_pack_building).
const SPECIAL := ["center", "arena", "skytower", "electronics", "ceo_tower", "cathedral", "hideout", "temple"]
## The special buildings built as a shop of the house pack with a look of their own (as SHOP_LOOKS): the Beast
## Center's chrome diner. The other landmarks have builders of their own (_pack_arena, _pack_electronics,
## _pack_skytower, _pack_ceo_tower, _pack_cathedral).
const PACK_LOOKS := {
	"center": {"floors": 1, "ground": ["tin", "#eef0f2"], "roof": "flat", "trim": "#d8283a", "flat_roof": "#b8bcc4", "brand": "#d8283a"},
}
## House paints by town style: soft colours, so a street of houses isn't all one shade.
const HOUSE_PAINTS := {
	"town": ["#efe4cc", "#f0e2a8", "#f0d4c8", "#d8e2ec", "#dce4c8", "#f4f0e8"],
	"coastal": ["#f2eee2", "#cfe4f0", "#f4d8c8", "#e4f0d4", "#f8e8b8", "#e8dcf0"],
	"adobe": ["#dcb88a", "#e4c494", "#d4a878", "#e8cca4"],
	"western": ["#b8804a", "#a8784a", "#c49060", "#9a6a40"],
	"island": ["#d8b878", "#e0c088", "#c8a868"],
	"jungle": ["#9a7040", "#a87c48", "#8a6438"],
	"steampunk": ["#a8503a", "#985040", "#b05a40"],
	"hotspring": ["#7a4a32", "#8a5a3a"],
}
const PACK_DOORS := ["door_2", "door_3", "door_4", "door_5", "door_6", "door_7", "door_8"]
## A door panel's own width (2 m in the pack, at the storey's scale): any narrower and its door comes out tall and thin.
const DOOR_PANEL_W := 1.85
const PACK_WINDOWS := ["win_1", "win_2", "win_3", "win_4"]
const PACK_SMALL := ["win_small_1", "win_small_2", "win_small_3"]
const PACK_WIDE := ["win_double_1", "win_double_2", "win_double_3", "win_double_4"]


## A house or shop of the house pack's pieces (see house_builder.gd): a stone plinth (or a deck on stilts), one or two
## storeys of the town's wall finish with the pack's doors, windows and shutters, corner posts, a beam between the
## storeys and the style's roof. Shops get display windows, a striped awning in the shop's colour and a sign board with
## its icon; houses a lamp by the door and, under pitched roofs, a chimney.
static func _pack_building(node: Node3D, b: Dictionary, style_name: String, st: Dictionary, shop: String, w: float, d: float, door_lx: float, locked: bool) -> void:
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	hb.rng.seed = ("%s:%d:%d" % [shop, int(b.get("seed", 0)), int(w)]).hash()
	var rng: RandomNumberGenerator = hb.rng
	var commercial := shop in COMMERCIAL or PACK_LOOKS.has(shop)
	var look: Dictionary = PACK_LOOKS.get(shop, SHOP_LOOKS.get(style_name, SHOP_LOOKS["town"]))
	var k := Kit.new()
	var trim := Color(look.get("trim", st["trim"])) if commercial else Color(st["trim"])
	var base := Color(st["base"])
	var lift := 0.0
	if st.get("stilts", false):
		lift = 0.5
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				k.box("color", Vector3(sx * (w / 2.0 - 0.3), lift / 2.0, sz * (d / 2.0 - 0.3)), Vector3(0.22, lift, 0.22), trim)
		k.box("planks", Vector3(0, lift - 0.06, 0.1), Vector3(w + 0.1, 0.12, d + 0.3), trim.lightened(0.2))
		for i in 2:
			k.box("planks", Vector3(door_lx, 0.12 + i * 0.2, d / 2.0 + 0.55 - i * 0.22), Vector3(1.1, 0.12, 0.3), trim.lightened(0.1))
	else:
		k.box("stone", Vector3(0, 0.12, 0), Vector3(w - 0.08, 0.24, d - 0.08), base)
		# a step up to the door
		k.box("stone", Vector3(door_lx, 0.07, d / 2.0 + 0.12), Vector3(1.3, 0.14, 0.4), base.lightened(0.08))
	var y0 := lift + (0.24 if lift == 0.0 else 0.0)
	var ground: Array = look["ground"] if commercial else st["wall"]
	var upper: Array = look.get("upper", look["ground"]) if commercial else st["wall"]
	# houses in town wear plaster below and half-timbering above, like the shops
	if not commercial and style_name == "town" and rng.randf() < 0.5:
		ground = ["plaster", st["wall"][1]]
	# every house its own paint
	if not commercial and HOUSE_PAINTS.has(style_name):
		var paints: Array = HOUSE_PAINTS[style_name]
		var paint: String = paints[rng.randi_range(0, paints.size() - 1)]
		if String(ground[0]) in ["plaster", "timber", "adobe", "planks_v", "planks"]:
			ground = [ground[0], paint]
		if String(upper[0]) in ["plaster", "timber", "adobe", "planks_v", "planks"]:
			upper = [upper[0], paint]
	var gmat: Material = HouseBuilder.wall_material(String(ground[0]), Color(ground[1]))
	var umat: Material = HouseBuilder.wall_material(String(upper[0]), Color(upper[1]))
	var floors := int(look["floors"]) if commercial else (2 if (w >= 4 and rng.randf() < 0.55) or shop == "home" else 1)
	# (one with a street close behind it is kept to one storey: see world.gd _plan_houses)
	if b.get("low", false):
		floors = 1
	var door: String = "door_1" if locked else PACK_DOORS[rng.randi_range(0, PACK_DOORS.size() - 1)]
	var shutters := not commercial and style_name in ["town", "coastal", "gothic", "steampunk"] and rng.randf() < 0.75
	var kinds := {2: PACK_WINDOWS, 3: PACK_WIDE} if commercial else {2: PACK_WINDOWS if rng.randf() < 0.6 else PACK_SMALL}
	hb.storey(y0, gmat, door, door_lx, kinds, shutters, d >= 3)
	hb.corners(k, y0, HouseBuilder.STOREY, trim)
	if locked:
		_door_lock(k, Vector3(door_lx, y0 + 1.0, d / 2.0 - HouseBuilder.INSET + 0.06), 0.8, 1.9)
	var top := y0 + HouseBuilder.STOREY
	if floors == 2:
		# a beam between the storeys
		k.box("planks", Vector3(0, top + 0.07, 0), Vector3(w - 0.14, 0.14, d - 0.14), trim)
		top += 0.14
		hb.storey(top, umat, "", 0.0, {2: PACK_WINDOWS if commercial else PACK_SMALL}, shutters, d >= 3)
		hb.corners(k, top, HouseBuilder.STOREY, trim)
		top += HouseBuilder.STOREY
	var front := d / 2.0 - HouseBuilder.INSET
	if commercial:
		var brand := Color(look.get("brand", SHOP_ROOF.get(shop, "#c84040")))
		# a striped awning over the shop front
		var ay := y0 + 2.3
		var x := -w / 2.0 + 0.2
		var i := 0
		while x < w / 2.0 - 0.2:
			var x2 := minf(x + 0.45, w / 2.0 - 0.2)
			k.poly("color", [Vector3(x, ay, front), Vector3(x2, ay, front), Vector3(x2, ay - 0.42, front + 0.85), Vector3(x, ay - 0.42, front + 0.85)],
				Vector3(0, 0.9, 0.45), brand if i % 2 == 0 else Color("#f4f0e4"))
			x = x2
			i += 1
		# the awning's valance
		k.box("color", Vector3(0, ay - 0.5, front + 0.86), Vector3(w - 0.4, 0.16, 0.03), brand.darkened(0.15))
		# the sign board, above the awning
		k.box("planks", Vector3(door_lx, y0 + 2.62, front + 0.05), Vector3(1.7, 0.42, 0.08), trim)
		k.box("color", Vector3(door_lx, y0 + 2.62, front + 0.09), Vector3(1.5, 0.3, 0.02), brand.darkened(0.25))
		var icon := MeshInstance3D.new()
		icon.mesh = VP.icon(shop)
		icon.position = Vector3(door_lx, y0 + 2.6, _on_face(icon.mesh, front + 0.1))
		node.add_child(icon)
	else:
		# a lamp on the wall by the door (the interior pack's sconce)
		var lamp: Mesh = load("res://assets/interiors/wall_light.res") if ResourceLoader.exists("res://assets/interiors/wall_light.res") else null
		if lamp != null:
			var mi := MeshInstance3D.new()
			mi.mesh = lamp
			mi.scale = Vector3.ONE * 1.3
			mi.position = Vector3(door_lx + (0.95 if door_lx < w / 2.0 - 1.4 else -0.95), y0 + 1.7, front)
			node.add_child(mi)
	var rt := String(look["roof"]) if commercial else String(st["roof_type"])
	if shop == "center":
		# the Beast Center: a railcar diner's curved roof and a roadside sign, the same in every town
		_diner_roof(k, w, d, top, Color(look["flat_roof"]), Color(look["brand"]))
		_diner_pylon(node, k, w, d, door_lx, top, Color(look["brand"]))
		rt = "none"
	if rt == "false_front":
		rt = "western"
	if rt == "western" and not commercial:
		rt = "gable"
	var roof_col := Color(SHOP_ROOF.get(shop, st["roof"][1])).lerp(Color(st["roof"][1]), 0.5) if commercial else \
		(Color(SHOP_ROOF.get(shop, st["roof"][1])) if shop != "house" else Color(st["roof"][1]).lerp(Color.from_hsv(rng.randf(), 0.4, 0.7), 0.25))
	if rt == "none":
		pass
	elif rt == "flat":
		_roof(k, rt, w, d, top, String(look.get("flat_roof", st["roof"][0])) if false else st["roof"][0], Color(look.get("flat_roof", roof_col.to_html())) if commercial else roof_col, String(upper[0]), Color(upper[1]), trim)
	else:
		_roof(k, rt, w, d, top, st["roof"][0], roof_col, String(upper[0]), Color(upper[1]), trim)
	if not commercial and rt in ["gable", "steep"] and rng.randf() < 0.7:
		var ch := hb.piece("chimney")
		if ch != null:
			var mi2 := MeshInstance3D.new()
			mi2.mesh = ch
			mi2.scale = Vector3(0.85, 1.3, 0.85)
			mi2.position = Vector3(-w / 4.0, top + 0.15, -d / 4.0)
			node.add_child(mi2)
	if st.get("lanterns", false):
		for sx in [-1, 1]:
			k.box("glow", Vector3(door_lx + sx * 0.75, y0 + 1.6, front + 0.2), Vector3(0.22, 0.32, 0.22), Color("#ff6a3a"))
	hb.finish()
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## How far a shop awning slopes down from the wall (its lower edge stays above the door's top, clear of every head).
const AWNING_DROP := 0.16


## A shop in a house from the PSX pack: a striped awning in the shop's colour over its door, and above it a sign board
## with the shop's icon, so a shop reads as a shop from across the square.
static func _shop_front(node: Node3D, plan: Dictionary, shop: String, st: Dictionary) -> void:
	var k := Kit.new()
	var brand := Color(SHOP_ROOF.get(shop, "#c84040"))
	var trim := Color(st["trim"])
	var door: Vector3 = plan["door_at"]
	var ds: Vector2 = plan["door_size"]
	var front := door.z + 0.02
	# just above the door, sloping gently, so its lower edge clears everyone's heads where it reaches over the street;
	# over a porch, at the top of its posts, reaching to the porch's front
	var ay := door.y + ds.y / 2.0 + AWNING_DROP + 0.18
	var depth := 0.7
	var pc: Dictionary = plan.get("porch", {})
	var drop := AWNING_DROP
	if not pc.is_empty():
		# over a porch it lies flat on the tops of its posts
		ay = float(pc["top"]) + 0.01
		drop = 0.0
		depth = maxf(depth, (pc["rect"] as Rect2).end.y - front)
	# over the door; over a porch, the whole of it
	var x0 := door.x - 1.25
	var x1 := door.x + 1.25
	if not pc.is_empty():
		x0 = (pc["rect"] as Rect2).position.x
		x1 = (pc["rect"] as Rect2).end.x
	var x := x0
	var i := 0
	while x < x1 - 0.01:
		var x2 := minf(x + 0.42, x1)
		k.poly("color", [Vector3(x, ay, front), Vector3(x2, ay, front), Vector3(x2, ay - drop, front + depth), Vector3(x, ay - drop, front + depth)],
			Vector3(0, 0.95, 0.3), brand if i % 2 == 0 else Color("#f4f0e4"))
		x = x2
		i += 1
	# the valance along its front edge (over a porch, a trim along the edge instead, so the posts meet it)
	if pc.is_empty():
		k.box("color", Vector3((x0 + x1) / 2.0, ay - drop - 0.07, front + depth + 0.01), Vector3(x1 - x0, 0.14, 0.03), brand.darkened(0.15))
	else:
		k.box("color", Vector3((x0 + x1) / 2.0, ay + 0.03, front + depth), Vector3(x1 - x0, 0.06, 0.05), brand.darkened(0.15))

	# the sign board, on the wall above the awning (over a porch, at the porch's end: standing on the awning's front
	# edge, so the awning can sit high on the posts)
	var sign_y := ay + 0.34
	var sign_z := front + 0.04
	if not pc.is_empty():
		sign_y = ay + 0.27
		sign_z = front + depth - 0.06
	k.box("planks", Vector3(door.x, sign_y, sign_z), Vector3(1.5, 0.46, 0.08), trim)
	k.box("color", Vector3(door.x, sign_y, sign_z + 0.045), Vector3(1.3, 0.34, 0.02), brand.darkened(0.25))
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	node.add_child(mi)
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon(shop)
	icon.position = Vector3(door.x, sign_y - 0.02, _on_face(icon.mesh, sign_z + 0.06))
	node.add_child(icon)


## A railcar diner's roof: a low barrel vault along the building in brushed steel with a stripe of the brand colour
## along its crown, closed at both ends, with a chrome band at the eaves.
static func _diner_roof(k: Kit, w: float, d: float, top: float, steel: Color, brand: Color) -> void:
	var seg := 12
	var half := d / 2.0 + 0.18
	var rise := 1.05
	var x0 := -w / 2.0 - 0.12
	var x1 := w / 2.0 + 0.12
	var arc := []
	for i in seg + 1:
		var a := PI * float(i) / seg
		arc.append(Vector2(cos(a) * half, sin(a) * rise))
	for i in seg:
		var p0: Vector2 = arc[i]
		var p1: Vector2 = arc[i + 1]
		var n := Vector3(0, (p0.y + p1.y) / rise, (p0.x + p1.x) / half).normalized()
		var col := brand if i in [seg / 2 - 1, seg / 2] else steel.lightened(0.06 * float(i % 2))
		k.poly("color", [Vector3(x0, top + p0.y, p0.x), Vector3(x1, top + p0.y, p0.x), Vector3(x1, top + p1.y, p1.x), Vector3(x0, top + p1.y, p1.x)], n, col)
	for ex in [x0, x1]:
		for i in seg:
			var p0: Vector2 = arc[i]
			var p1: Vector2 = arc[i + 1]
			k.poly("color", [Vector3(ex, top, 0.0), Vector3(ex, top + p0.y, p0.x), Vector3(ex, top + p1.y, p1.x)], Vector3(signf(ex), 0, 0), steel.darkened(0.12))
	for sz in [-1.0, 1.0]:
		k.box("color", Vector3(0, top + 0.06, sz * half), Vector3(x1 - x0 + 0.04, 0.12, 0.08), Color("#e8ecf0"))


## The Beast Center's sign: a post rising from the front corner of its roof (away from the door) holding a board in
## the brand colour with the pawprint, seen from across town; it stays over the diner, clear of its neighbours.
static func _diner_pylon(node: Node3D, k: Kit, w: float, d: float, door_lx: float, top: float, brand: Color) -> void:
	var x := w / 2.0 - 0.6 if door_lx < w / 4.0 else -w / 2.0 + 0.6
	var z := d / 2.0 - 0.35
	var y := top + 0.35
	k.box("color", Vector3(x, y + 0.7, z - 0.1), Vector3(0.14, 1.4, 0.14), Color("#d8dce2"))
	k.box("color", Vector3(x, y + 1.75, z), Vector3(0.95, 0.95, 0.14), brand)
	k.box("color", Vector3(x, y + 1.75, z - 0.02), Vector3(1.07, 1.07, 0.08), Color("#f4f4f0"))
	k.box("glow", Vector3(x, y + 2.3, z), Vector3(0.8, 0.09, 0.16), Color("#ffe8a0"))
	var paw := MeshInstance3D.new()
	paw.mesh = VP.icon("center")
	paw.position = Vector3(x, y + 1.7, _on_face(paw.mesh, z + 0.08))
	node.add_child(paw)


## The Sky Tower: an eight-sided lookout of the house pack's walls in the town's wall finish, three storeys that step
## in as they rise (the door on the front face, small windows round about, a rib up every corner and a ledge at every
## floor), then a gallery on brackets with a railing all round, a glazed lantern room under a pointed roof with a
## weathervane, a windsock, and Tempestrix (the owl line's last form) hovering at the gallery.
static func _pack_skytower(node: Node3D, st: Dictionary, w: float, d: float, door_lx: float) -> void:
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	var k := Kit.new()
	var trim := Color(st["trim"])
	var mat: Material = HouseBuilder.wall_material(String(st["wall"][0]), Color(st["wall"][1]))
	# centred on the door, so the front face (and its door) stands on the door's tile
	var c := Vector2(clampf(door_lx, -w / 2.0 + 1.5, w / 2.0 - 1.5), 0.0)
	var r0 := (d / 2.0 - HouseBuilder.INSET) / cos(PI / 8.0)
	_plinth(k, _loop(c, r0 + 0.08, r0 + 0.08, 8, PI / 8.0), c, 0.24, Color(st["base"]))
	k.box("stone", Vector3(c.x, 0.07, d / 2.0 + 0.12), Vector3(1.3, 0.14, 0.4), Color(st["base"]).lightened(0.08))
	var y := 0.24
	var r := r0
	for f in 3:
		var pts := _loop(c, r, r, 8, PI / 8.0)
		for i in 8:
			# corner i-1 to corner i: face i is centred at i * 45 degrees round from the front
			var a: Vector2 = pts[(i + 7) % 8]
			var b: Vector2 = pts[i]
			var piece := "wall_1"
			if i == 0:
				# (the ground floor's door is in the entrance porch in front, below)
				piece = "wall_1" if f == 0 else "win_small_3"
			elif i % 2 == 1 or (f > 0 and i == 4):
				piece = "win_small_2" if f < 2 else "win_small_3"
			hb.span(piece, a, b, y, mat, c)
		for p in pts:
			_column(k, "planks", Vector3(p.x, y, p.y), 0.1, HouseBuilder.STOREY, 4, trim, PI / 4.0)
		y += HouseBuilder.STOREY
		# the ledge where the next storey steps in
		var nr := r * 0.9 if f < 2 else r
		_ledge(k, "planks", _loop(c, r + 0.1, r + 0.1, 8, PI / 8.0), _loop(c, nr - 0.05, nr - 0.05, 8, PI / 8.0), c, y, 0.14, trim)
		y += 0.14
		r = nr
	# the entrance: a little porch in front of the front face, wide enough for the door panel at its own width (on the
	# narrow face it came out tall and thin), its cheeks in the walls' finish and a cornice of the trim on top
	var front_z := c.y + r0 * cos(PI / 8.0)
	var pz := front_z + 0.32
	var ph := HouseBuilder.STOREY * 0.86
	hb.span(PACK_DOORS[3], Vector2(c.x - DOOR_PANEL_W / 2.0, pz), Vector2(c.x + DOOR_PANEL_W / 2.0, pz), 0.24, mat, Vector2(c.x, front_z - 1.0), ph)
	for sx in [-1.0, 1.0]:
		k.box("stone", Vector3(c.x + sx * (DOOR_PANEL_W / 2.0 - 0.04), 0.24 + ph / 2.0, (front_z + pz) / 2.0 - 0.08), Vector3(0.12, ph, pz - front_z + 0.3), Color(st["base"]).lightened(0.15))
	k.box("planks", Vector3(c.x, 0.24 + ph + 0.06, (front_z + pz) / 2.0 - 0.05), Vector3(DOOR_PANEL_W + 0.2, 0.12, pz - front_z + 0.42), trim)
	hb.finish()
	# the gallery, on a bracket under every corner
	var deck_r := r0 + 0.55
	var deck := _loop(c, deck_r, deck_r, 8, PI / 8.0)
	var top_pts := _loop(c, r, r, 8, PI / 8.0)
	for i in 8:
		var p: Vector2 = top_pts[i]
		var q: Vector2 = deck[i]
		_beam(k, "planks", Vector3(p.x, y - 1.0, p.y), Vector3(lerpf(p.x, q.x, 0.85), y - 0.02, lerpf(p.y, q.y, 0.85)), 0.12, trim)
	_ledge(k, "planks", deck, _fill(c, 8), c, y, 0.16, trim.lightened(0.25))
	var gy := y + 0.16
	# its railing: a post at every corner and halfway along every side, two rails
	for i in 8:
		var a: Vector2 = deck[i]
		var b: Vector2 = deck[(i + 1) % 8]
		var ai := a.lerp(c, 0.04)
		var bi := b.lerp(c, 0.04)
		for t in [0.0, 0.5]:
			var p := ai.lerp(bi, t)
			_column(k, "color", Vector3(p.x, gy, p.y), 0.04, 0.95, 4, trim)
		for h in [0.45, 0.95]:
			_beam(k, "color", Vector3(ai.x, gy + h, ai.y), Vector3(bi.x, gy + h, bi.y), 0.07, trim)
	# the lantern room: glazed all round
	var lr := r0 * 0.62
	var lpts := _loop(c, lr, lr, 8, PI / 8.0)
	var lb = HouseBuilder.new()
	lb.node = node
	for i in 8:
		lb.span("win_3", lpts[(i + 7) % 8], lpts[i], gy, mat, c, 2.1)
	lb.finish()
	for p in lpts:
		_column(k, "planks", Vector3(p.x, gy, p.y), 0.07, 2.1, 4, trim, PI / 4.0)
	var ry := gy + 2.1
	_ledge(k, "planks", _loop(c, lr + 0.3, lr + 0.3, 8, PI / 8.0), _fill(c, 8), c, ry, 0.12, trim)
	var roof_col := Color(st["roof"][1])
	var peak := ry + 0.12 + 1.7
	_spire(k, String(st["roof"][0]), _loop(c, lr + 0.36, lr + 0.36, 8, PI / 8.0), ry + 0.12, c, 1.7, roof_col)
	# a finial, a brass ball and the weathervane's arrow
	_column(k, "brass", Vector3(c.x, peak - 0.1, c.y), 0.05, 1.0, 6, Color("#c8a040"))
	_column(k, "brass", Vector3(c.x, peak + 0.5, c.y), 0.12, 0.2, 8, Color("#e0c060"))
	_beam(k, "color", Vector3(c.x - 0.5, peak + 0.8, c.y), Vector3(c.x + 0.45, peak + 0.8, c.y), 0.05, Color("#3a3a3a"))
	k.poly("color", [Vector3(c.x + 0.45, peak + 0.68, c.y), Vector3(c.x + 0.62, peak + 0.8, c.y), Vector3(c.x + 0.45, peak + 0.92, c.y)], Vector3.BACK, Color("#3a3a3a"))
	k.poly("color", [Vector3(c.x - 0.5, peak + 0.8, c.y), Vector3(c.x - 0.36, peak + 0.8, c.y), Vector3(c.x - 0.36, peak + 1.0, c.y), Vector3(c.x - 0.5, peak + 1.0, c.y)], Vector3.BACK, Color("#3a3a3a"))
	# a windsock on a pole at the gallery's back corner
	var sp: Vector2 = deck[4].lerp(c, 0.08)
	_column(k, "color", Vector3(sp.x, gy, sp.y), 0.04, 2.4, 4, trim)
	k.box("color", Vector3(sp.x - 0.4, gy + 2.25, sp.y), Vector3(0.6, 0.28, 0.28), Color("#e84a3a"))
	k.box("color", Vector3(sp.x - 0.85, gy + 2.22, sp.y), Vector3(0.35, 0.2, 0.2), Color("#f4f0e8"))
	# Tempestrix, the owl line's last form, hovering on the front of the gallery, facing the street, its wings
	# beating over the rail (beast_rig.gd)
	var bird := BeastModel.rig(RaceDB.genes(RaceDB.of_form("owl_3")), 1.25)
	bird.position = Vector3(c.x, gy, c.y + deck_r * 0.82)
	bird.rotation.y = -PI / 2.0
	bird.name = "Bird"
	node.add_child(bird)
	# its sign over the door
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("skytower")
	icon.position = Vector3(c.x, 0.24 + 2.55, _on_face(icon.mesh, d / 2.0 - HouseBuilder.INSET))
	node.add_child(icon)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## The arena's stone by town: sandstone in the west and the desert, granite in the mines, mossy in the jungle.
const ARENA_STONE := {"western": "#dcb890", "adobe": "#e0bc8c", "mining": "#b8b4ac", "jungle": "#bcc09c", "island": "#e2d6ba",
	"hotspring": "#b0a49a", "gothic": "#a4a4ac"}


## The arena: an oval stadium of the house pack's walls (an arcade of tall windows below, small ones above, a pilaster
## at every corner, a cornice and a parapet) under a flat roof with a low glazed skylight over the ring, and pennants
## on masts round the rim. At the front, on the door's tile, a crenellated
## gatehouse with the great carved door, banners and the arena's sign, between two round turrets with pointed roofs.
static func _pack_arena(node: Node3D, style_name: String, w: float, d: float, door_lx: float, locked: bool) -> void:
	var stone := Color(ARENA_STONE.get(style_name, "#d8ccb4"))
	var dark := stone.darkened(0.22)
	var brand := Color("#c8a030")
	var flags := [Color("#c83a3a"), Color("#3a6ac8"), Color("#e8c040")]
	var mat: Material = HouseBuilder.wall_material("stone", stone)
	var k := Kit.new()
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	var y0 := 0.24
	var top := y0 + HouseBuilder.STOREY * 2.0
	# the oval, set back a little so the gatehouse stands proud of it
	var c := Vector2(0.0, -0.22)
	var ax := w / 2.0 - 0.2
	var az := d / 2.0 - 0.38
	var n := 18
	var ring := _loop(c, ax, az, n, PI / n)
	# the gatehouse: from a little inside the oval out to the front of the plot
	var gx0 := door_lx - 1.45
	var gx1 := door_lx + 1.45
	var gz1 := d / 2.0 - HouseBuilder.INSET
	var gz0 := c.y + az * 0.45
	_plinth(k, _scaled(ring, c, 1.025), c, y0, dark)
	k.box("stone", Vector3((gx0 + gx1) / 2.0, y0 / 2.0, (gz0 + gz1) / 2.0 + 0.04), Vector3(gx1 - gx0 + 0.16, y0, gz1 - gz0 + 0.08), dark)
	k.box("stone", Vector3(door_lx, 0.07, gz1 + 0.24), Vector3(1.6, 0.14, 0.4), dark.lightened(0.1))
	var hidden := func(p: Vector2) -> bool: return p.x > gx0 - 0.3 and p.x < gx1 + 0.3 and p.y > gz0
	for i in n:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % n]
		if hidden.call((a + b) / 2.0):
			continue
		hb.span("win_1", a, b, y0, mat, c)
		hb.span("win_small_1", a, b, y0 + HouseBuilder.STOREY, mat, c)
	for p in ring:
		if not hidden.call(p):
			_column(k, "stone", Vector3(p.x, y0, p.y), 0.17, HouseBuilder.STOREY * 2.0, 6, stone.lightened(0.06))
	# a cornice between the storeys and round the top, and the parapet
	for cy in [y0 + HouseBuilder.STOREY, top]:
		_ledge(k, "stone", _scaled(ring, c, 1.045), ring, c, cy - 0.08, 0.16, dark)
	_skirt(k, "stone", ring, top, 0.62, stone, c)
	var inner := _scaled(ring, c, 0.95)
	_skirt(k, "stone", inner, top, 0.62, stone.darkened(0.12), c, true)
	_band(k, "stone", _scaled(ring, c, 1.01), inner, top + 0.62, stone.lightened(0.05))
	# the flat roof inside the parapet, and a low glazed skylight over the ring in its middle
	_band(k, "tin", inner, _fill(c, n), top + 0.12, Color("#6e6a64"))
	var sky := _scaled(ring, c, 0.42)
	_skirt(k, "stone", sky, top + 0.12, 0.3, dark, c)
	_band(k, "stone", _scaled(ring, c, 0.46), sky, top + 0.42, stone.lightened(0.05))
	_band(k, "color", sky, _fill(c, n), top + 0.4, Color("#9cc0d0"))
	# masts round the rim, every other one flying a pennant
	var i2 := 0
	for i in n:
		var p: Vector2 = ring[i]
		if hidden.call(p):
			continue
		_column(k, "color", Vector3(p.x, top + 0.62, p.y), 0.045, 1.0, 4, Color("#5a4a3a"))
		if i % 2 == 0:
			_pennant(k, Vector3(p.x, top + 1.62, p.y), flags[i2 % 3])
			i2 += 1
	# the gatehouse: two storeys and a crenellated top, the carved door, a window over it
	var gc := Vector2((gx0 + gx1) / 2.0, (gz0 + gz1) / 2.0)
	var dw := 1.3
	hb.span("door_1" if locked else "door_3", Vector2(door_lx - dw / 2.0, gz1), Vector2(door_lx + dw / 2.0, gz1), y0, mat, gc)
	hb.span("wall_1", Vector2(gx0, gz1), Vector2(door_lx - dw / 2.0, gz1), y0, mat, gc)
	hb.span("wall_1", Vector2(door_lx + dw / 2.0, gz1), Vector2(gx1, gz1), y0, mat, gc)
	hb.span("win_double_2", Vector2(gx0, gz1), Vector2(gx1, gz1), y0 + HouseBuilder.STOREY, mat, gc)
	for gx in [gx0, gx1]:
		for fl in 2:
			hb.span("wall_2" if fl == 0 else "win_small_1", Vector2(gx, gz0), Vector2(gx, gz1), y0 + HouseBuilder.STOREY * fl, mat, gc)
	hb.finish()
	# an attic over the gatehouse, so its battlements stand above the oval's parapet
	var gtop := top + 0.95
	k.box("stone", Vector3(gc.x, (top + gtop) / 2.0, gc.y + 0.02), Vector3(gx1 - gx0 - 0.02, gtop - top + 0.02, gz1 - gz0 - 0.02), stone)
	k.box("stone", Vector3(gc.x, gtop + 0.06, gc.y), Vector3(gx1 - gx0 + 0.12, 0.12, gz1 - gz0 + 0.12), dark)
	k.box("stone", Vector3(gc.x, y0 + HouseBuilder.STOREY, gz1 + 0.04), Vector3(gx1 - gx0 + 0.1, 0.14, 0.12), dark)
	var mx := gx0 + 0.15
	while mx < gx1 - 0.1:
		k.box("stone", Vector3(mx, gtop + 0.34, gz1 - 0.12), Vector3(0.3, 0.44, 0.24), stone)
		mx += 0.55
	var mz := gz0 + 0.2
	while mz < gz1 - 0.4:
		for gx in [gx0, gx1]:
			k.box("stone", Vector3(gx + (0.12 if gx == gx0 else -0.12), gtop + 0.34, mz), Vector3(0.24, 0.44, 0.3), stone)
		mz += 0.55
	# banners either side of the door and the sign over it
	for sx in [-1.0, 1.0]:
		var bx: float = door_lx + sx * (dw / 2.0 + 0.36)
		k.box("color", Vector3(bx, y0 + 1.75, gz1 + 0.03), Vector3(0.44, 1.5, 0.03), flags[0 if sx < 0 else 1])
		k.box("color", Vector3(bx, y0 + 1.75, gz1 + 0.05), Vector3(0.12, 1.5, 0.02), brand)
		k.box("color", Vector3(bx, y0 + 2.52, gz1 + 0.05), Vector3(0.56, 0.06, 0.06), Color("#5a4a3a"))
		# a brazier on a post either side of the steps
		_column(k, "stone", Vector3(door_lx + sx * 1.15, 0.0, gz1 + 0.45), 0.09, 0.9, 6, dark)
		_column(k, "brass", Vector3(door_lx + sx * 1.15, 0.9, gz1 + 0.45), 0.18, 0.14, 6, Color("#6a4a2a"))
		k.box("glow", Vector3(door_lx + sx * 1.15, 1.12, gz1 + 0.45), Vector3(0.18, 0.2, 0.18), Color("#ff8a3a"))
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("arena")
	icon.position = Vector3(door_lx, y0 + 2.55, _on_face(icon.mesh, gz1))
	node.add_child(icon)
	# the turrets either side of the gatehouse
	for gx in [gx0, gx1]:
		var tc := Vector3(gx, 0.0, gz1 - 0.55)
		var th := top + 1.75
		_column(k, "stone", tc, 0.66, y0, 8, dark, PI / 8.0)
		_column(k, "stone", tc + Vector3(0, y0, 0), 0.6, th - y0, 8, stone.lightened(0.04), PI / 8.0)
		# arrow slits up the front
		for sy in [1.3, 3.6, 5.9]:
			k.box("color", Vector3(gx, sy, tc.z + 0.57), Vector3(0.1, 0.55, 0.04), Color("#2a221c"))
		_ledge(k, "stone", _loop(Vector2(tc.x, tc.z), 0.76, 0.76, 8, PI / 8.0), _fill(Vector2(tc.x, tc.z), 8), Vector2(tc.x, tc.z), th, 0.14, dark)
		var tp := th + 0.14 + 1.5
		_spire(k, "tile", _loop(Vector2(tc.x, tc.z), 0.8, 0.8, 8, PI / 8.0), th + 0.14, Vector2(tc.x, tc.z), 1.5, Color("#b84a32"))
		_column(k, "color", Vector3(tc.x, tp - 0.1, tc.z), 0.035, 0.75, 4, Color("#5a4a3a"))
		_pennant(k, Vector3(tc.x, tp + 0.65, tc.z), brand)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## Sparkwire Electronics: a streamlined shop of the house pack's walls in white render with blue speed stripes. Its
## front-left corner curves round in glass, under a cantilevered canopy that wraps the corner with the shop's sign on
## its fascia; above it, two storeys up, a round drum carries a tall blade sign with a lightning bolt. On the flat roof,
## a satellite dish and a lattice radio mast with a red beacon.
static func _pack_electronics(node: Node3D, w: float, d: float, door_lx: float, locked: bool) -> void:
	var render := Color("#eef0f2")
	var steel := Color("#9aa2ae")
	var brand := Color("#3a6ab0")
	var neon := Color("#5af0ff")
	var mat: Material = HouseBuilder.wall_material("plaster", render)
	var k := Kit.new()
	var hb = HouseBuilder.new()
	hb.node = node
	hb.w = w
	hb.d = d
	var I := HouseBuilder.INSET
	var x0 := -w / 2.0 + I
	var x1 := w / 2.0 - I
	var z0 := -d / 2.0 + I
	var z1 := d / 2.0 - I
	# the curved corner: as round as the room left of the door allows; the door panel at its own width (squeezed, the
	# pack's door comes out tall and thin)
	var dw := DOOR_PANEL_W
	var rad := clampf(door_lx - dw / 2.0 - 0.25 - x0, 0.6, minf(1.3, z1 - z0 - 0.6))
	var cc := Vector2(x0 + rad, z1 - rad)
	var arc := []
	for i in 4:
		var a := -PI / 2.0 * float(i) / 3.0
		arc.append(Vector2(cc.x + rad * sin(a), cc.y + rad * cos(a)))
	# the outline, round from the front's right end: front, curve, left side, back, right side
	var outline := [Vector2(x1, z1)]
	outline.append_array(arc)
	outline.append_array([Vector2(x0, z0), Vector2(x1, z0)])
	var centre := Vector2(0.0, 0.0)
	_plinth(k, _grown(outline, 0.08), centre, 0.24, Color("#8a8a90"))
	k.box("stone", Vector3(door_lx, 0.07, z1 + 0.22), Vector3(1.3, 0.14, 0.4), Color("#9a9aa0"))
	var y0 := 0.24
	var S := HouseBuilder.STOREY
	for fl in 2:
		var y := y0 + S * fl
		var front: Vector2 = arc[0]
		if fl == 0:
			if door_lx - dw / 2.0 - front.x > 0.3:
				hb.span("win_2", front, Vector2(door_lx - dw / 2.0, z1), y, mat, centre)
			hb.span("door_1" if locked else "door_7", Vector2(door_lx - dw / 2.0, z1), Vector2(door_lx + dw / 2.0, z1), y, mat, centre)
			if x1 - door_lx - dw / 2.0 > 0.3:
				hb.span("win_double_2", Vector2(door_lx + dw / 2.0, z1), Vector2(x1, z1), y, mat, centre)
		else:
			# a ribbon of windows along the front
			hb.span("win_double_2", front, Vector2(x1, z1), y, mat, centre)
		for i in 3:
			hb.span("win_double_2" if fl == 0 else "win_2", arc[i], arc[i + 1], y, mat, centre)
		hb.span("win_2" if fl == 0 else "win_small_2", arc[3], Vector2(x0, z0), y, mat, centre)
		hb.span("wall_2", Vector2(x0, z0), Vector2(x1, z0), y, mat, centre)
		hb.span("win_small_3" if fl == 1 else "wall_2", Vector2(x1, z0), Vector2(x1, z1), y, mat, centre)
	# corner posts where the straight walls meet
	for p in [Vector2(x1, z1), Vector2(x0, z0), Vector2(x1, z0)]:
		_column(k, "tin", Vector3(p.x, y0, p.y), 0.12, S * 2.0, 4, steel, PI / 4.0)
	# speed stripes round the upper storey, and the roof's slab and parapet
	for sy in [y0 + S + 0.22, y0 + S + 0.42]:
		_skirt(k, "color", _grown(outline, 0.02), sy, 0.08, brand, centre)
	var top := y0 + S * 2.0
	var roof_in := _grown(outline, -0.12)
	_ledge(k, "plaster", _grown(outline, 0.1), roof_in, centre, top, 0.4, render.darkened(0.04))
	_skirt(k, "plaster", roof_in, top + 0.22, 0.18, render.darkened(0.12), centre, true)
	_band(k, "tin", roof_in, _fill(centre, outline.size()), top + 0.22, Color("#5a5a66"))
	_skirt(k, "color", _grown(outline, 0.11), top + 0.3, 0.06, brand, centre)
	# the canopy over the shop front, wrapping the corner: a slab with a blue fascia and a neon strip
	var cy := y0 + 2.42
	var cin := [Vector2(x1, z1)]
	cin.append_array(arc)
	var cout := []
	for p in cin:
		var o: Vector2 = p
		if p == Vector2(x1, z1):
			o = p + Vector2(0.1, 0.55)
		else:
			o = cc + (p - cc).normalized() * (rad + 0.55)
		cout.append(o)
	for i in cin.size() - 1:
		var a: Vector2 = cin[i]
		var b: Vector2 = cin[i + 1]
		var ao: Vector2 = cout[i]
		var bo: Vector2 = cout[i + 1]
		k.poly("tin", [Vector3(a.x, cy + 0.12, a.y), Vector3(b.x, cy + 0.12, b.y), Vector3(bo.x, cy + 0.12, bo.y), Vector3(ao.x, cy + 0.12, ao.y)], Vector3.UP, Color("#d8dce4"))
		k.poly("tin", [Vector3(a.x, cy, a.y), Vector3(b.x, cy, b.y), Vector3(bo.x, cy, bo.y), Vector3(ao.x, cy, ao.y)], Vector3.DOWN, Color("#c8ccd4"))
		var on := Vector2(bo.y - ao.y, ao.x - bo.x).normalized()
		if on.dot((ao + bo) / 2.0 - cc) < 0.0:
			on = -on
		k.poly("color", [Vector3(ao.x, cy - 0.16, ao.y), Vector3(bo.x, cy - 0.16, bo.y), Vector3(bo.x, cy + 0.2, bo.y), Vector3(ao.x, cy + 0.2, ao.y)], Vector3(on.x, 0, on.y), brand)
		k.poly("glow", [Vector3(ao.x + on.x * 0.01, cy - 0.12, ao.y + on.y * 0.01), Vector3(bo.x + on.x * 0.01, cy - 0.12, bo.y + on.y * 0.01),
			Vector3(bo.x + on.x * 0.01, cy - 0.08, bo.y + on.y * 0.01), Vector3(ao.x + on.x * 0.01, cy - 0.08, ao.y + on.y * 0.01)], Vector3(on.x, 0, on.y), neon)
	# the canopy's right end
	var e0: Vector2 = cin[0]
	var e1: Vector2 = cout[0]
	k.poly("color", [Vector3(e0.x, cy - 0.16, e0.y), Vector3(e1.x, cy - 0.16, e1.y), Vector3(e1.x, cy + 0.2, e1.y), Vector3(e0.x, cy + 0.2, e0.y)], Vector3.RIGHT, brand)
	var icon := MeshInstance3D.new()
	icon.mesh = VP.icon("electronics")
	icon.position = Vector3(door_lx, cy + 0.04, _on_face(icon.mesh, z1 + 0.56))
	icon.scale = Vector3(0.7, 0.7, 0.7)
	node.add_child(icon)
	# the drum over the corner, a storey above the roof, with the blade sign rising from it
	var dr := rad * 0.92
	var drum := _loop(cc, dr, dr, 8, PI / 8.0)
	for i in 8:
		hb.span("win_2" if i in [0, 6, 7] else "wall_1", drum[(i + 7) % 8], drum[i], top + 0.22, mat, cc, 2.2)
	hb.finish()
	var dtop := top + 0.22 + 2.2
	for sy in [dtop - 1.75, dtop - 1.55]:
		_skirt(k, "color", _scaled(drum, cc, 1.02), sy, 0.08, brand, cc)
	_ledge(k, "plaster", _scaled(drum, cc, 1.12), _fill(cc, 8), cc, dtop, 0.18, render.darkened(0.04))
	var fin := Vector3(cc.x, dtop + 0.18, cc.y + dr * 0.35)
	k.box("color", fin + Vector3(0, 1.1, 0), Vector3(1.0, 2.2, 0.16), Color("#f4f4f0"))
	k.box("color", fin + Vector3(0, 1.1, 0), Vector3(0.84, 2.04, 0.2), brand)
	k.box("glow", fin + Vector3(0, 2.2, 0), Vector3(1.0, 0.06, 0.18), neon)
	k.box("glow", fin + Vector3(0, 0.02, 0), Vector3(1.0, 0.06, 0.18), neon)
	var bolt := MeshInstance3D.new()
	bolt.mesh = VP.icon("electronics")
	bolt.scale = Vector3(1.25, 1.25, 1.25)
	bolt.position = Vector3(fin.x, fin.y + 1.05, _on_face(bolt.mesh, fin.z + 0.1) + 0.02)
	node.add_child(bolt)
	# the satellite dish and the radio mast on the roof behind
	var free := Vector2((cc.x + dr + x1) / 2.0 + 0.1, (z0 + z1) / 2.0 + 0.25)
	_dish(k, Vector3(free.x, top + 0.22, free.y), 0.62, Color("#e4e6ea"))
	var mp := Vector3(x1 - 0.42, top + 0.22, z0 + 0.42)
	var mh := 3.2
	var legs := [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(0.3, 0, 0.3), Vector3(-0.3, 0, 0.3)]
	var tip := mp + Vector3(0, mh, 0)
	for l in legs:
		_beam(k, "color", mp + l, tip, 0.05, Color("#c84a3a"))
	for h in [0.8, 1.6, 2.4]:
		var s: float = 1.0 - h / mh
		for i in 4:
			var a: Vector3 = mp + legs[i] * s + Vector3(0, h, 0)
			var b: Vector3 = mp + legs[(i + 1) % 4] * s + Vector3(0, h, 0)
			_beam(k, "color", a, b, 0.035, Color("#e8e8e8"))
	k.box("glow", tip + Vector3(0, 0.08, 0), Vector3(0.14, 0.14, 0.14), Color("#ff3a2a"))
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## A satellite dish on a short post: a shallow bowl of twelve petals tipped back towards the sky, a feed arm and its
## horn at the focus.
static func _dish(k: Kit, base: Vector3, r: float, col: Color) -> void:
	_column(k, "tin", base, 0.07, 0.55, 6, Color("#7a7a84"))
	var c := base + Vector3(0, 0.75, 0)
	# tipped back 40 degrees from upright, facing the front of the shop and a little left
	var face := Basis(Vector3.UP, -0.45) * Basis(Vector3.RIGHT, -deg_to_rad(40.0))
	var depth := r * 0.3
	var n := 12
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var p0 := c + face * Vector3(r * cos(a0), r * sin(a0), depth)
		var p1 := c + face * Vector3(r * cos(a1), r * sin(a1), depth)
		k.poly("tin", [c, p0, p1], face * Vector3(0, 0, 1), col)
		k.poly("tin", [c, p1, p0], face * Vector3(0, 0, -1), col.darkened(0.25))
	_beam(k, "color", c + face * Vector3(0, -r, depth), c + face * Vector3(0, 0, r * 0.9), 0.04, Color("#5a5a62"))
	_beam(k, "color", c + face * Vector3(0, 0, r * 0.8), c + face * Vector3(0, 0, r), 0.12, Color("#3a3a42"))


# ---------------------------------------------------------------- shapes for the landmarks
## Corners round an ellipse (a circle when ax == az): n of them round centre c (x/z), the first `rot` radians round
## from +z towards +x. A face is centred on the front when rot = PI / n.
static func _loop(c: Vector2, ax: float, az: float, n: int, rot := 0.0) -> Array:
	var out := []
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		out.append(Vector2(c.x + ax * sin(a), c.y + az * cos(a)))
	return out


## An outline scaled about its centre (an ellipse stays an ellipse).
static func _scaled(pts: Array, c: Vector2, f: float) -> Array:
	return pts.map(func(p): return c + (p - c) * f)


## A closed outline grown outwards by `by` (shrunk, for a negative `by`): every side moved out square to itself, the
## corners mitred.
static func _grown(pts: Array, by: float) -> Array:
	var n := pts.size()
	# which way round the outline runs, so "out" is the same side of every edge
	var area := 0.0
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var turn := 1.0 if area > 0.0 else -1.0
	var out := []
	for i in n:
		var p: Vector2 = pts[i]
		var e1: Vector2 = (p - (pts[(i + n - 1) % n] as Vector2)).normalized()
		var e2: Vector2 = ((pts[(i + 1) % n] as Vector2) - p).normalized()
		var n1 := Vector2(e1.y, -e1.x) * turn
		var n2 := Vector2(e2.y, -e2.x) * turn
		var m := (n1 + n2).normalized()
		out.append(p + m * by / maxf(0.3, m.dot(n1)))
	return out


## `n` copies of the centre: the inner edge of a band that closes into a disc.
static func _fill(c: Vector2, n: int) -> Array:
	var out := []
	out.resize(n)
	out.fill(c)
	return out


## Upright faces along a closed outline (x/z), from y0 up h, facing away from `centre` (or towards it, `inward`, for
## the inside of a parapet or the arena's stands).
static func _skirt(k: Kit, tex: String, pts: Array, y0: float, h: float, col: Color, centre: Vector2, inward := false) -> void:
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var n := Vector2(b.y - a.y, a.x - b.x).normalized()
		if (n.dot((a + b) / 2.0 - centre) < 0.0) != inward:
			n = -n
		k.poly(tex, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y0 + h, b.y), Vector3(a.x, y0 + h, a.y)], Vector3(n.x, 0, n.y), col, Vector3(b.x - a.x, 0, b.y - a.y))


## A flat band between two outlines with as many corners (x/z) at height y, facing up (or down): decks, roofs round a
## drum, the treads of the arena's stands; with an inner edge of _fill() it is a disc.
static func _band(k: Kit, tex: String, outer: Array, inner: Array, y: float, col: Color, up := true) -> void:
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var o0: Vector2 = outer[i]
		var o1: Vector2 = outer[j]
		var i0: Vector2 = inner[i]
		var i1: Vector2 = inner[j]
		k.poly(tex, [Vector3(o0.x, y, o0.y), Vector3(o1.x, y, o1.y), Vector3(i1.x, y, i1.y), Vector3(i0.x, y, i0.y)], Vector3.UP if up else Vector3.DOWN, col)


## A slab between two outlines: its top, its underside and its outer edge, `t` thick from y (ledges, cornices, decks).
static func _ledge(k: Kit, tex: String, outer: Array, inner: Array, c: Vector2, y: float, t: float, col: Color) -> void:
	_band(k, tex, outer, inner, y + t, col)
	_band(k, tex, outer, inner, y, col.darkened(0.2), false)
	_skirt(k, tex, outer, y, t, col.darkened(0.06), c)


## A stone plinth `h` high under an outline.
static func _plinth(k: Kit, pts: Array, c: Vector2, h: float, col: Color) -> void:
	_skirt(k, "stone", pts, 0.0, h, col, c)
	_band(k, "stone", pts, _fill(c, pts.size()), h, col.lightened(0.04))


## A pointed roof over a closed outline (x/z) at height y, its faces rising `rise` to a point over `apex`.
static func _spire(k: Kit, tex: String, pts: Array, y: float, apex: Vector2, rise: float, col: Color) -> void:
	var tip := Vector3(apex.x, y + rise, apex.y)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		_slope(k, tex, [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), tip], col.darkened(0.05 * float(i % 2)), Vector3(b.x - a.x, 0, b.y - a.y))
	# the roof's underside, so it reads as a roof from the gallery below
	_band(k, tex, pts, _fill(apex, pts.size()), y, col.darkened(0.3), false)


## A post of `sides` faces round an upright axis (a column, a turret, a mast), radius r, from c.y up h, with a lid.
static func _column(k: Kit, tex: String, c: Vector3, r: float, h: float, sides: int, col: Color, rot := 0.0) -> void:
	var base := Vector2(c.x, c.z)
	var pts := _loop(base, r, r, sides, rot)
	_skirt(k, tex, pts, c.y, h, col, base)
	_band(k, tex, pts, _fill(base, sides), c.y + h, col.lightened(0.05))


## A beam of square section `t` between two points: rails, brackets, the struts of a mast.
static func _beam(k: Kit, tex: String, p0: Vector3, p1: Vector3, t: float, col: Color) -> void:
	var dir := (p1 - p0).normalized()
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.01:
		u = dir.cross(Vector3.RIGHT)
	u = u.normalized() * t / 2.0
	var v := dir.cross(u).normalized() * t / 2.0
	var cs := [u + v, -u + v, -u - v, u - v]
	for i in 4:
		var a: Vector3 = cs[i]
		var b: Vector3 = cs[(i + 1) % 4]
		k.poly(tex, [p0 + a, p0 + b, p1 + b, p1 + a], (a + b).normalized(), col, dir)


## A pennant flying from the top of a pole at p, towards +x, drawn from both sides.
static func _pennant(k: Kit, p: Vector3, col: Color) -> void:
	var pts := [p, p + Vector3(0.62, -0.13, 0), p + Vector3(0, -0.3, 0)]
	k.poly("color", pts, Vector3.BACK, col)
	k.poly("color", pts, Vector3.FORWARD, col.darkened(0.2))


## Gearhart Tower: the steam company's offices, a stepped brick tower of the house pack's walls and windows (two
## storeys, then two narrower set-backs), brass bands at each set-back, a clock on the top tier, chimney stacks
## at the back, gears on the front and a brass spire with a red beacon.
static func _pack_ceo_tower(node: Node3D, w: float, d: float, door_lx: float, locked: bool) -> void:
	var brick := Color("#8a3a2a")
	var brass := Color("#c8a040")
	var k := Kit.new()
	k.box("stone", Vector3(0, 0.12, 0), Vector3(w - 0.08, 0.24, d - 0.08), Color("#5a5a62"))
	k.box("stone", Vector3(door_lx, 0.07, d / 2.0 + 0.12), Vector3(1.6, 0.14, 0.4), Color("#6a6a72"))
	var mat: Material = HouseBuilder.wall_material("brick", brick)
	var upper: Material = HouseBuilder.wall_material("brick", brick.darkened(0.1))
	var y := 0.24
	# [width, depth, storeys]
	var tiers := [[w, d, 2], [w - 1.6, d - 1.6, 1], [maxf(2.2, w - 3.0), maxf(2.2, d - 3.0), 1]]
	for ti in tiers.size():
		var t: Array = tiers[ti]
		var hb = HouseBuilder.new()
		hb.node = node
		hb.w = t[0]
		hb.d = t[1]
		hb.rng.seed = 900 + ti
		for f in int(t[2]):
			var ground: bool = ti == 0 and f == 0
			hb.storey(y, mat if ti == 0 else upper, ("door_1" if locked else PACK_DOORS[4]) if ground else "", door_lx,
				{2: PACK_WINDOWS, 3: PACK_WIDE} if ground else {2: PACK_WINDOWS}, false, true)
			hb.corners(k, y, HouseBuilder.STOREY, Color("#4a3a32"))
			y += HouseBuilder.STOREY
		hb.finish()
		# a flat roof and a brass band where the next tier steps back
		k.box("stone", Vector3(0, y + 0.08, 0), Vector3(float(t[0]) - 0.1, 0.16, float(t[1]) - 0.1), Color("#4a4a52"))
		k.box("brass", Vector3(0, y + 0.2, 0), Vector3(float(t[0]) + 0.05, 0.12, float(t[1]) + 0.05), brass)
		y += 0.26
	if locked:
		_door_lock(k, Vector3(door_lx, 1.24, d / 2.0 - HouseBuilder.INSET + 0.06), 0.8, 1.9)
	# the clock on the top tier's front, and the spire
	var top: Array = tiers[tiers.size() - 1]
	var cz: float = float(top[1]) / 2.0 - HouseBuilder.INSET + 0.04
	var clock := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.08
	disc.radial_segments = 16
	clock.mesh = disc
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("#f4ecd0")
	cm.emission_enabled = true
	cm.emission = Color("#fff0c0")
	cm.emission_energy_multiplier = 0.4
	clock.material_override = cm
	clock.rotation.x = PI / 2.0
	clock.position = Vector3(0, y - 1.5, cz + 0.05)
	node.add_child(clock)
	k.box("brass", Vector3(0, y - 1.5, cz + 0.02), Vector3(1.6, 1.6, 0.04), brass)
	k.box("color", Vector3(0, y - 1.3, cz + 0.11), Vector3(0.07, 0.5, 0.03), Color("#2a2a2a"))
	k.box("color", Vector3(0.17, y - 1.5, cz + 0.11), Vector3(0.38, 0.07, 0.03), Color("#2a2a2a"))
	k.box("brass", Vector3(0, y + 1.4, 0), Vector3(0.3, 2.8, 0.3), brass)
	k.box("glow", Vector3(0, y + 2.9, 0), Vector3(0.28, 0.28, 0.28), Color("#ff4a3a"))
	var beacon := OmniLight3D.new()
	beacon.light_color = Color("#ff5a3a")
	beacon.light_energy = 1.2
	beacon.omni_range = 4.0
	beacon.position = Vector3(0, y + 2.9, 0)
	node.add_child(beacon)
	# chimney stacks at the back of the first roof
	var ch := HouseBuilder.piece("chimney")
	if ch != null:
		for sx in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = ch
			mi.scale = Vector3(1.0, 2.2, 1.0)
			mi.position = Vector3(sx * (w / 2.0 - 0.6), 0.24 + 2.0 * HouseBuilder.STOREY + 0.26, -d / 2.0 + 0.6)
			node.add_child(mi)
	_gear(k, Vector3(door_lx - 1.5, 2.2, d / 2.0 - HouseBuilder.INSET + 0.05), 0.5, brass)
	_gear(k, Vector3(door_lx + 1.5, 2.6, d / 2.0 - HouseBuilder.INSET + 0.05), 0.36, brass)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## Gravenmoor Cathedral: a dark stone nave of the house pack's walls (two storeys of tall windows down its sides, the
## great door at the front under a round rose window that glows violet) under a steep slate roof, and two square towers
## at the front corners, three storeys of small windows each, with pyramid spires.
static func _pack_cathedral(node: Node3D, w: float, d: float, door_lx: float, locked: bool) -> void:
	var stone := Color("#6a6a74")
	var mat: Material = HouseBuilder.wall_material("stone_dark", stone)
	var tmat: Material = HouseBuilder.wall_material("stone_dark", stone.lightened(0.06))
	var k := Kit.new()
	k.box("stone", Vector3(0, 0.12, 0), Vector3(w - 0.08, 0.24, d - 0.08), Color("#4a4a52"))
	k.box("stone", Vector3(door_lx, 0.07, d / 2.0 + 0.12), Vector3(2.0, 0.14, 0.4), Color("#5a5a62"))
	# the nave, set back a little behind the towers' fronts
	var nave := Node3D.new()
	nave.position.z = -0.4
	node.add_child(nave)
	var nw := w - 2.4
	var nd := d - 0.8
	var hb = HouseBuilder.new()
	hb.node = nave
	hb.w = nw
	hb.d = nd
	hb.rng.seed = 666
	var y := 0.24
	hb.storey(y, mat, "door_1" if locked else PACK_DOORS[1], door_lx, {2: PACK_WINDOWS}, false, true)
	y += HouseBuilder.STOREY
	# the upper storey: plain at the front (the rose window goes there), tall windows down the sides
	hb.storey(y, mat, "", 0.0, {}, false, true)
	y += HouseBuilder.STOREY
	hb.finish()
	var nk := Kit.new()
	_roof(nk, "steep", nw, nd, y, "slate", Color("#2e2e3a"), "stone_dark", stone, Color("#3a3a42"))
	var nmi := MeshInstance3D.new()
	nmi.mesh = nk.mesh()
	nave.add_child(nmi)
	var front := nd / 2.0 - HouseBuilder.INSET - 0.4
	if locked:
		_door_lock(k, Vector3(door_lx, 1.24, front + 0.06), 0.8, 1.9)
	# the rose window: a stone ring round a violet glass disc
	var rose_y := 0.24 + HouseBuilder.STOREY * 1.5
	var glass := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.05
	disc.radial_segments = 16
	glass.mesh = disc
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#5a3a8a")
	gm.emission_enabled = true
	gm.emission = Color("#8a50d0")
	gm.emission_energy_multiplier = 0.55
	glass.material_override = gm
	glass.rotation.x = PI / 2.0
	glass.position = Vector3(door_lx, rose_y, front + 0.06)
	node.add_child(glass)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 0.98
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = HouseBuilder.wall_material("stone", Color("#8a8a92"))
	ring.rotation.x = PI / 2.0
	ring.position = glass.position + Vector3(0, 0, 0.03)
	node.add_child(ring)
	for sp in [-0.5, 0.5]:
		k.box("stone", Vector3(door_lx + sp * 1.1, rose_y, front + 0.08), Vector3(0.08, 1.5, 0.05), Color("#8a8a92"))
	var violet := OmniLight3D.new()
	violet.light_color = Color("#b070ff")
	violet.light_energy = 1.0
	violet.omni_range = 4.5
	violet.position = Vector3(door_lx, rose_y, front + 1.0)
	node.add_child(violet)
	# the towers
	for sx in [-1.0, 1.0]:
		var tower := Node3D.new()
		tower.position = Vector3(sx * (w / 2.0 - 0.8), 0, d / 2.0 - 0.9)
		node.add_child(tower)
		var tb = HouseBuilder.new()
		tb.node = tower
		tb.w = 1.6
		tb.d = 1.6
		tb.rng.seed = 700 + int(sx)
		var ty := 0.24
		for f in 3:
			tb.storey(ty, tmat, "", 0.0, {2: PACK_SMALL}, false, true)
			ty += HouseBuilder.STOREY
		tb.finish()
		var tk := Kit.new()
		tk.box("stone", Vector3(0, ty + 0.1, 0), Vector3(1.75, 0.2, 1.75), Color("#5a5a64"))
		_hip(tk, 1.5, 1.5, ty + 0.2, 3.0, 0.15, false, "slate", Color("#2e2e3a"), Color("#3a3a42"))
		var tmi := MeshInstance3D.new()
		tmi.mesh = tk.mesh()
		tower.add_child(tmi)
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)


## A mine entrance cut into the bandits' rock: a dark passage behind a timber frame (two posts and a lintel, with a
## brace either side), a lantern on the frame, and crates and barrels stacked outside. `fz` is the rock's front face.
static func _mine_entrance(node: Node3D, door_lx: float, fz: float) -> void:
	var k := Kit.new()
	var timber := Color("#6a4a2a")
	k.box("color", Vector3(door_lx, 1.1, fz - 0.6), Vector3(1.3, 2.2, 1.6), Color("#0a0806"))
	for sx in [-1.0, 1.0]:
		k.box("planks", Vector3(door_lx + sx * 0.72, 1.15, fz), Vector3(0.22, 2.3, 0.26), timber)
		k.box("planks", Vector3(door_lx + sx * 0.55, 2.05, fz + 0.02), Vector3(0.36, 0.14, 0.2), timber.darkened(0.1))
	k.box("planks", Vector3(door_lx, 2.36, fz), Vector3(1.9, 0.26, 0.3), timber)
	k.box("planks", Vector3(door_lx, 0.04, fz + 0.4), Vector3(1.4, 0.08, 0.9), timber.lightened(0.1))
	var km := MeshInstance3D.new()
	km.mesh = k.mesh()
	node.add_child(km)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffb060")
	lamp.light_energy = 0.9
	lamp.omni_range = 3.0
	lamp.position = Vector3(door_lx + 0.72, 2.0, fz + 0.4)
	node.add_child(lamp)
	var lantern: Mesh = load("res://assets/interiors/wall_light.res") if ResourceLoader.exists("res://assets/interiors/wall_light.res") else null
	if lantern != null:
		var lm := MeshInstance3D.new()
		lm.mesh = lantern
		lm.scale = Vector3.ONE * 1.3
		lm.position = Vector3(door_lx + 0.72, 1.75, fz + 0.14)
		node.add_child(lm)
	# supplies outside
	var spots := [["crate", Vector3(-1.5, 0, 0.6), 0.3], ["crate_open", Vector3(-1.45, 0.62, 0.6), -0.2], ["barrel", Vector3(1.45, 0, 0.5), 0.0],
		["keg", Vector3(1.9, 0, 0.85), 1.2]]
	for e in spots:
		var m := HouseBuilder.piece(String(e[0]))
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = Vector3(door_lx, 0, fz) + (e[1] as Vector3)
		mi.rotation.y = float(e[2])
		node.add_child(mi)


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
			# a tiled skirt roof between the floors: four slopes from the wide eaves in to the upper walls
			var y0 := wy + G + 0.06
			var y1 := y0 + 0.36
			var ox := ww / 2.0 + 0.45
			var oz := wd / 2.0 + 0.45
			var ix := ww / 2.0 - 0.02
			var iz := wd / 2.0 + jet - 0.02
			for s in [-1.0, 1.0]:
				_slope(k, roof_tex, [Vector3(-ox, y0, oz * s), Vector3(ox, y0, oz * s), Vector3(ix, y1, iz * s), Vector3(-ix, y1, iz * s)], roof_col if s > 0 else roof_col.darkened(0.06), Vector3.RIGHT)
				_slope(k, roof_tex, [Vector3(ox * s, y0, -oz), Vector3(ox * s, y0, oz), Vector3(ix * s, y1, iz), Vector3(ix * s, y1, -iz)], roof_col.darkened(0.03), Vector3.BACK)
				k.box("color", Vector3(0, y0 - 0.03, oz * s), Vector3(ox * 2.0, 0.06, 0.06), trim)
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


## An elemental temple: a weathered three-tier ziggurat of cut stone, each tier lipped, with a pillared shrine and a
## slate pyramid roof on top. Returns the height of the roof's peak (with no kit, only works that out).
static func _temple(k: Kit, w: float, d: float) -> float:
	var stone := Color("#a89880")
	var y := 0.0
	var tw := w + 0.3
	var td := d + 0.3
	for t in 3:
		var h := 1.0
		if k:
			k.box("stone", Vector3(0, y + h / 2.0, 0), Vector3(tw, h, td), stone.darkened(0.05 * t))
			k.box("stone", Vector3(0, y + h - 0.05, 0), Vector3(tw + 0.12, 0.12, td + 0.12), stone.lightened(0.08))
		y += h
		tw -= 1.3
		td -= 1.1
	var sw := maxf(1.6, tw)
	var sd := maxf(1.4, td)
	var sh := 1.9
	if k:
		k.box("stone_dark", Vector3(0, y + sh / 2.0, 0), Vector3(sw - 0.3, sh, sd - 0.3), stone.darkened(0.2))
		# pillars at the corners and either side of a dark doorway
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.box("stone", Vector3(sx * (sw / 2.0 - 0.12), y + sh / 2.0, sz * (sd / 2.0 - 0.12)), Vector3(0.24, sh, 0.24), stone.lightened(0.1))
		k.box("color", Vector3(0, y + 0.8, sd / 2.0 - 0.14), Vector3(0.75, 1.6, 0.04), Color("#16100c"))
		k.box("stone", Vector3(0, y + sh + 0.06, 0), Vector3(sw + 0.1, 0.12, sd + 0.1), stone.lightened(0.05))
		return _hip(k, sw, sd, y + sh + 0.12, 0.9, 0.2, false, "slate", stone.darkened(0.3), stone)
	var hs := minf(sw, sd) / 2.0 + 0.2
	return y + sh + 0.12 + 0.04 + hs * 0.9


## A temple's way in: a stone arch with a glowing keystone at the front of its base, and a vaulted passage running
## back into the ruin, so the doorway is part of the temple rather than a dark slab standing in front of it.
static func _temple_gate(d: float, door_lx: float, glow: Color) -> ArrayMesh:
	var k := Kit.new()
	var stone := Color("#8a7260")
	var fz := d / 2.0 - 0.05
	# sized for people: a doorway 1.2 wide and 2.2 high
	k.box("stone", Vector3(door_lx, 1.35, fz - 0.9), Vector3(1.9, 2.7, 1.8), stone.darkened(0.15))
	k.box("color", Vector3(door_lx, 1.1, fz + 0.01), Vector3(1.2, 2.2, 0.02), Color("#0a0806"))
	for sx in [-1, 1]:
		k.box("stone", Vector3(door_lx + sx * 0.8, 1.4, fz), Vector3(0.34, 2.8, 0.4), stone)
		k.box("stone", Vector3(door_lx + sx * 0.8, 0.12, fz), Vector3(0.48, 0.24, 0.5), stone.darkened(0.1))
	k.box("stone", Vector3(door_lx, 2.86, fz), Vector3(2.1, 0.36, 0.46), stone.lightened(0.05))
	k.box("glow", Vector3(door_lx, 2.86, fz + 0.24), Vector3(0.26, 0.28, 0.04), glow)
	k.box("stone", Vector3(door_lx, 0.05, fz + 0.3), Vector3(1.5, 0.1, 0.28), stone.darkened(0.05))
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


## Rafe's landmark: a large golden flute on a teal board, above the door and in front of the porch roof.
static func _rafe_flute_sign(node: Node3D, b: Dictionary, height: float) -> void:
	var k := Kit.new()
	var gold := Color("#ffd15c")
	k.box("color", Vector3.ZERO, Vector3(2.3, 0.86, 0.14), Color("#b88a38"), true)
	k.box("color", Vector3(0, 0, 0.08), Vector3(2.14, 0.7, 0.06), Color("#245e66"), true)
	# A straight reed flute, with a mouthpiece, binding rings and six dark finger holes.
	k.box("color", Vector3(0, 0, 0.17), Vector3(1.82, 0.22, 0.16), gold, true)
	k.box("color", Vector3(-0.87, 0, 0.18), Vector3(0.26, 0.3, 0.18), Color("#fff0b0"), true)
	for x in [-0.64, 0.88]:
		k.box("color", Vector3(x, 0, 0.18), Vector3(0.07, 0.27, 0.18), Color("#c08a30"), true)
	for i in 6:
		k.box("color", Vector3(-0.43 + i * 0.21, 0.01, 0.257), Vector3(0.075, 0.075, 0.02), Color("#493823"), true)
	for x in [-0.8, 0.8]:
		k.box("color", Vector3(x, 0.53, -0.04), Vector3(0.06, 0.32, 0.08), Color("#624b32"), true)
	var sign := MeshInstance3D.new()
	sign.name = "RafeFluteSign"
	sign.mesh = k.mesh()
	var door_x := float(b["door"].x) + 0.5 - (float(b["x"]) + float(b["w"]) / 2.0)
	sign.position = Vector3(door_x, height, float(b["d"]) / 2.0 - 0.14)
	node.add_child(sign)


## The z that puts the back of `mesh` flat against a surface at `face`.
static func _on_face(mesh: Mesh, face: float) -> float:
	return face - mesh.get_aabb().position.z + 0.004


## Dresses a locked door: two iron straps across it and a brass padlock where the handle would be.
## `c` is the centre of the door's front face; `dw` and `dh` its width and height.
## Fisher Gil's shack on the Bellerive docks: a lean-to nailed together from corrugated sheets of every rust and old grey
## zinc, each a little off true and a different height, a patched roof sloping to the front past its plank door, a
## boarded window, a stovepipe, a lifebuoy and a crate of floats. It stands on the pier's planks (map_loader.gd
## over_water).
static func _rust_shack(w: float, d: float, door_lx: float) -> Node3D:
	var node := Node3D.new()
	var k := Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var rusts := [Color("#8a4a2a"), Color("#a65a2e"), Color("#6e3a24"), Color("#9a6a4a"), Color("#7e7a70"), Color("#b4703c"), Color("#5e4a3e")]
	var hw := w / 2.0 - 0.3
	var hd := d / 2.0 - 0.25
	var front_h := 2.3
	var back_h := 2.9
	var height_at := func(z: float) -> float:
		return lerpf(back_h, front_h, (z + hd) / (2.0 * hd))
	# a run of sheets along one wall: x runs for the front and back, z runs for the sides; `gap`: a doorway left open
	var sheets := func(along_x: bool, fixed: float, from: float, to: float, out: float, gap: Vector2) -> void:
		var t := from
		var i := 0
		while t < to - 0.02:
			var sw := minf(rng.randf_range(0.62, 0.9), to - t)
			var mid := t + sw / 2.0
			t += sw
			i += 1
			if mid > gap.x and mid < gap.y:
				continue
			var top: float = height_at.call(fixed if along_x else mid) + rng.randf_range(-0.12, 0.06)
			var bottom := rng.randf_range(0.0, 0.08)
			var col: Color = rusts[rng.randi_range(0, rusts.size() - 1)]
			# every other sheet lapped a little proud of the last
			var o := out * (0.03 if i % 2 == 0 else 0.0)
			var c := Vector3(mid, (top + bottom) / 2.0, fixed + o) if along_x else Vector3(fixed + o, (top + bottom) / 2.0, mid)
			var size := Vector3(sw + 0.04, top - bottom, 0.05) if along_x else Vector3(0.05, top - bottom, sw + 0.04)
			k.box("tin", c, size, col)
			# a rust run down from a nail, now and then
			if rng.randf() < 0.45:
				var sx := rng.randf_range(-sw * 0.35, sw * 0.35)
				var streak := Vector3(mid + sx, top - 0.45, fixed + out * 0.035) if along_x else Vector3(fixed + out * 0.035, top - 0.45, mid + sx)
				k.box("color", streak, Vector3(0.06, 0.7, 0.01) if along_x else Vector3(0.01, 0.7, 0.06), col.darkened(0.35))
	var door_gap := Vector2(door_lx - 0.55, door_lx + 0.55)
	sheets.call(true, hd, -hw, hw, 1.0, door_gap)
	sheets.call(true, -hd, -hw, hw, -1.0, Vector2(99, 99))
	sheets.call(false, -hw, -hd, hd, -1.0, Vector2(99, 99))
	sheets.call(false, hw, -hd, hd, 1.0, Vector2(99, 99))
	# the door: weathered planks in a rough frame, hung a touch crooked
	var dark := Color("#4a3424")
	k.box("color", Vector3(door_lx, 1.0, hd + 0.02), Vector3(1.04, 2.0, 0.04), dark)
	for i in 4:
		k.box("planks", Vector3(door_lx - 0.33 + i * 0.22, 0.95, hd + 0.05), Vector3(0.2, 1.84 - (i % 2) * 0.05, 0.04), Color("#8a6a48").darkened(0.08 * i))
	k.box("color", Vector3(door_lx, 1.45, hd + 0.08), Vector3(0.9, 0.08, 0.03), dark)
	k.box("color", Vector3(door_lx, 0.45, hd + 0.08), Vector3(0.9, 0.08, 0.03), dark)
	k.box("color", Vector3(door_lx + 0.32, 1.0, hd + 0.1), Vector3(0.06, 0.06, 0.04), Color("#2a2a2e"))
	# the roof: four sheets lapped across, sloping from the back down to the front, overhanging
	var roof_x := -hw - 0.25
	var strip := (2.0 * hw + 0.5) / 4.0
	for i in 4:
		var x0 := roof_x + i * strip - 0.03
		var x1 := x0 + strip + 0.06
		var lift := 0.02 * (i % 2)
		var col2: Color = rusts[rng.randi_range(0, rusts.size() - 1)]
		var pts := [Vector3(x0, back_h + 0.08 + lift, -hd - 0.3), Vector3(x1, back_h + 0.08 + lift, -hd - 0.3),
			Vector3(x1, front_h - 0.05 + lift, hd + 0.5), Vector3(x0, front_h - 0.05 + lift, hd + 0.5)]
		var n: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
		if n.y < 0.0:
			n = -n
		k.poly("tin", pts, n, col2, Vector3(1, 0, 0))
		# its underside, seen from the deck
		var under := [pts[0] - Vector3(0, 0.03, 0), pts[3] - Vector3(0, 0.03, 0), pts[2] - Vector3(0, 0.03, 0), pts[1] - Vector3(0, 0.03, 0)]
		k.poly("color", under, -n, col2.darkened(0.45))
	# a boarded-up window on the side
	k.box("color", Vector3(hw + 0.06, 1.45, -0.1), Vector3(0.03, 0.6, 0.7), Color("#2a2420"))
	for i in 2:
		k.box("planks", Vector3(hw + 0.09, 1.3 + i * 0.3, -0.1), Vector3(0.03, 0.12, 0.85), Color("#9a7a52"))
	# a stovepipe through the roof at the back
	k.box("tin", Vector3(-hw + 0.5, back_h + 0.35, -hd + 0.25), Vector3(0.16, 1.1, 0.16), Color("#5a5a5e"))
	k.box("tin", Vector3(-hw + 0.5, back_h + 0.92, -hd + 0.25), Vector3(0.26, 0.06, 0.26), Color("#4a4a4e"))
	# a lifebuoy on the front wall, and a crate of floats by the door
	var bx := door_lx + (0.95 if door_lx < 0.0 else -0.95)
	for a in 8:
		var ang := a * TAU / 8.0
		k.box("color", Vector3(bx + cos(ang) * 0.24, 1.55 + sin(ang) * 0.24, hd + 0.08), Vector3(0.13, 0.13, 0.07), Color("#e8e4dc") if a % 2 == 0 else Color("#d8402c"))
	var cx := door_lx + (-0.95 if door_lx < 0.0 else 0.95)
	k.box("planks", Vector3(cx, 0.22, hd + 0.4), Vector3(0.6, 0.44, 0.45), Color("#9a7a52"))
	for f in 3:
		k.box("color", Vector3(cx - 0.15 + f * 0.15, 0.5, hd + 0.4), Vector3(0.11, 0.11, 0.11), Color("#e04030") if f != 1 else Color("#f0f0e8"))
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	node.add_child(mi)
	return node


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


## One sloped roof face (3 or 4 corners) with its tile rows running along `along`; it always faces up.
static func _slope(k: Kit, tex: String, pts: Array, col: Color, along: Vector3) -> void:
	var a: Vector3 = pts[0]
	var n: Vector3 = (pts[1] - a).cross(pts[2] - a)
	if n.length() < 0.0001 and pts.size() == 4:
		n = (pts[2] - a).cross(pts[3] - a)
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	k.poly(tex, pts, n, col, along, a)


## A pitched roof whose ridge runs along x: two slopes, gable-end walls under them, a ridge cap and thin eaves.
## `slope` is rise over run; the roof hangs `ov` past the walls.
static func _gable(k: Kit, w: float, d: float, top: float, slope: float, ov: float, tex: String, col: Color, wall_tex: String, wall_col: Color, trim: Color) -> float:
	var hw := w / 2.0 + 0.15
	var hd := d / 2.0 + ov
	var rh := hd * slope
	var y0 := top + 0.04
	var ridge := y0 + rh
	for sz in [-1.0, 1.0]:
		_slope(k, tex, [Vector3(-hw, y0, hd * sz), Vector3(hw, y0, hd * sz), Vector3(hw, ridge, 0), Vector3(-hw, ridge, 0)], col if sz > 0 else col.darkened(0.06), Vector3.RIGHT)
		# the eaves' edge, so the roof has some thickness from below
		k.box("color", Vector3(0, y0 - 0.03, hd * sz), Vector3(hw * 2.0, 0.07, 0.07), trim)
	# gable ends: the wall carries on up into the triangle under the roof
	var gw := (w - 0.2) / 2.0
	var gd := (d - 0.3) / 2.0
	for sx in [-1.0, 1.0]:
		k.poly(wall_tex, [Vector3(gw * sx, top, -gd), Vector3(gw * sx, top, gd), Vector3(gw * sx, ridge - 0.04, 0)], Vector3(sx, 0, 0), wall_col)
	k.box(tex, Vector3(0, ridge + 0.02, 0), Vector3(hw * 2.0 + 0.04, 0.09, 0.18), col.darkened(0.22))
	return ridge


## A hipped roof: slopes on all four sides up to a short ridge (or a point on a square plan). A pagoda's eaves flare:
## each side is cut in two, a shallow skirt and a steeper upper slope, with the corners kicked up.
static func _hip(k: Kit, w: float, d: float, top: float, slope: float, ov: float, flare: bool, tex: String, col: Color, trim: Color) -> float:
	var long_x := w >= d
	var hl := (w if long_x else d) / 2.0 + ov
	var hs := (d if long_x else w) / 2.0 + ov
	var rl := maxf(0.0, hl - hs)
	var y0 := top + 0.04
	# the profile from eave to ridge as [inset, height] points
	var prof := [[0.0, y0], [hs, y0 + hs * slope]]
	if flare:
		var skirt := minf(0.55, hs * 0.4)
		prof = [[0.0, y0], [skirt, y0 + skirt * slope * 0.45], [hs, y0 + skirt * slope * 0.45 + (hs - skirt) * slope * 1.25]]
	var P := func(along: float, across: float, y: float) -> Vector3:
		return Vector3(along, y, across) if long_x else Vector3(across, y, along)
	var along_axis := Vector3.RIGHT if long_x else Vector3.BACK
	for seg in prof.size() - 1:
		var i0: float = prof[seg][0]
		var i1: float = prof[seg + 1][0]
		var ya: float = prof[seg][1]
		var yb: float = prof[seg + 1][1]
		var l0 := hl - i0
		var l1 := maxf(rl, hl - i1)
		var s0 := hs - i0
		var s1 := hs - i1
		var shade := col.darkened(0.04 * seg)
		for side in [-1.0, 1.0]:
			# the long sides: trapezoids
			_slope(k, tex, [P.call(-l0, s0 * side, ya), P.call(l0, s0 * side, ya), P.call(l1, s1 * side, yb), P.call(-l1, s1 * side, yb)], shade if side > 0 else shade.darkened(0.06), along_axis)
			# the short ends: trapezoids closing to the ridge's ends
			var e: float = side
			_slope(k, tex, [P.call(l0 * e, -s0, ya), P.call(l0 * e, s0, ya), P.call(l1 * e, s1, yb), P.call(l1 * e, -s1, yb)], shade.darkened(0.03), Vector3.BACK if long_x else Vector3.RIGHT)
	var ridge_y: float = prof[prof.size() - 1][1]
	for side in [-1.0, 1.0]:
		k.box("color", P.call(0.0, hs * side, y0 - 0.03), Vector3(hl * 2.0, 0.07, 0.07) if long_x else Vector3(0.07, 0.07, hl * 2.0), trim)
	if flare:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.box(tex, Vector3(sx * (w / 2.0 + ov - 0.05), y0 + 0.12, sz * (d / 2.0 + ov - 0.05)), Vector3(0.22, 0.1, 0.22), col.lightened(0.05))
	if rl > 0.05:
		k.box(tex, P.call(0.0, 0.0, ridge_y + 0.03), Vector3(rl * 2.0 + 0.1, 0.09, 0.16) if long_x else Vector3(0.16, 0.09, rl * 2.0 + 0.1), col.darkened(0.2))
	k.box("color", Vector3(0, ridge_y + 0.15, 0), Vector3(0.14, 0.26, 0.14), trim)
	return ridge_y


static func _roof(k: Kit, t: String, w: float, d: float, top: float, tex: String, col: Color, wall_tex: String, wall_col: Color, trim: Color) -> void:
	match t:
		"gable", "steep":
			_gable(k, w, d, top, 0.88 if t == "gable" else 1.68, 0.25, tex, col, wall_tex, wall_col, trim)
		"hip", "pagoda":
			_hip(k, w, d, top, 0.62 if t == "hip" else 0.55, 0.45 if t == "hip" else 0.6, t == "pagoda", tex, col, trim)
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
			# one slope, high at the back, low over the door
			var hw := w / 2.0 + 0.15
			var hd := d / 2.0 + 0.15
			var lo := top + 0.04
			var hi := top + 0.5
			_slope(k, tex, [Vector3(-hw, lo, hd), Vector3(hw, lo, hd), Vector3(hw, hi, -hd), Vector3(-hw, hi, -hd)], col, Vector3.RIGHT)
			var gw := (w - 0.2) / 2.0
			var gd := (d - 0.3) / 2.0
			for sx in [-1.0, 1.0]:
				k.poly(wall_tex, [Vector3(gw * sx, top, -gd), Vector3(gw * sx, top, gd), Vector3(gw * sx, lo + (hi - lo) * (hd + gd) / (2.0 * hd), -gd)], Vector3(sx, 0, 0), wall_col)
			k.box("color", Vector3(0, lo - 0.03, hd), Vector3(hw * 2.0, 0.07, 0.07), trim)
