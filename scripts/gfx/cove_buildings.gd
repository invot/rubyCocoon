extends RefCounted
## The supplied, repaired Towns kit, fitted to existing tile plots and door anchors.
## Both interactive and scenery buildings use the streamed world building path.

const VT = preload("res://scripts/gfx/voxel_textures.gd")
const DIR := "res://assets/exteriors/cove_"
const Houses = preload("res://scripts/gfx/house_models.gd")
const Windows = preload("res://scripts/gfx/cartoon_windows.gd")
const MeshStore = preload("res://scripts/gfx/mesh_store.gd")
const STUCCO := {
	"red": Color("#ba3e36"),
	"sky": Color("#a3cad8"), "coral": Color("#e4ac99"),
	"sage": Color("#b4cb9c"), "rose": Color("#d8adb8"),
	"butter": Color("#ead398"), "lavender": Color("#c7b9d9"),
	# the Beast Center's temple: pale dressed stone (voxel_buildings.gd SHRINE_STONE)
	"shrine": Color("#e9dfc8"),
}
## The plaster's finish: painted stucco with soft trowel sweeps (cove_stucco.gdshader), one material per paint.
const StuccoShader = preload("res://scripts/gfx/cove_stucco.gdshader")
static var _stucco_materials := {}
## The roofs' finish: courses of clay tiles (cove_roof.gdshader) over the kit's flat roof reds, one material per
## palette (or per plain clay colour).
const RoofShader = preload("res://scripts/gfx/cove_roof.gdshader")
const ROOF_CLAY := Color("#bb704d")
static var _roof_materials := {}
## The kit's own painted timber, which the windows' frames and sills match (the kit's "Cove painted wood").
const TIMBER := VT.WOOD
## The panes: sea glass, softer than the other towns' bright blue, so they sit quietly in the plaster.
const GLASS := Color("#7fa9ad")
## The shops' awnings: clay canvas and cream, the colours of the roofs and plaster, rather than each shop's brand.
const AWNING := [Color("#c9714a"), Color("#f3e5c6")]
const DOORS := {
	"whole_house": Vector3(-0.03,1.12,3.60), "house_1": Vector3(0,1.02,3.61),
	"house_2": Vector3(-1.40,0.95,1.56), "house_3": Vector3(-0.246,0.95,2.89),
	"house_4": Vector3(-2.81,0.95,3.14), "hut_1": Vector3(-1.1905,1.1,2.18),
	"hut_3": Vector3(1.1435,1.1,2.07), "hut_4": Vector3(0.9475,1.1,4.28),
}
## Measured wall tops in the kit's metres. Fit doors and whole storeys to people,
## rather than leaving a full-size door under a compressed upper floor or eave.
const FLOORS := {
	"whole_house": [3.75, 7.5], "house_1": [2.80], "house_2": [2.72],
	"house_3": [2.925, 5.12], "house_4": [5.12],
	"hut_1": [3.14], "hut_3": [3.14], "hut_4": [3.2],
}
const GROUND_STOREY := 2.6
## The taller ground storey: the apothecary's (house_3), whose sign board over the awning (voxel_buildings.gd
## _shop_front, up to about 2.7) must sit on the wall under the eaves, not in the roof, and the Beast Center's (house_1),
## whose temple front (voxel_buildings.gd shrine_front: columns, a lintel and the stepped pediment with the pawprint)
## stands under the eaves the same way.
const SHOP_STOREY := 3.1
const SHOP_STOREY_MODELS := ["house_3", "house_1"]
const APOTHECARY_SETBACK := 1.2
const APOTHECARY_PORCH_WIDTH := 4.0
const UPPER_STOREY := 2.45
## The kit's own closed door is a slab and frame standing out from its wall (up to 0.25 of its metres): everything in
## its doorway in front of the wall (within DOOR_CUT across, up to a little over the doorway) is cut away, so the
## full-size door build() puts there lies on the wall like every other town's, over the kit's sealed infill.
const DOOR_CUT := Vector3(0.9,0.4,0.6)
static var _meshes := {}
## The plastered houses' timber is Kelpwick's hut wood (the boards the huts and fences use), its grain run along each
## beam: one repeat of the texture covers WOOD_TILE (across, along) of the world.
const HUT_WOOD := "res://assets/exteriors/tribal_hut_wood.res"
const WOOD_TILE := Vector2(0.9, 3.6)
static var _hut_wood := {}
## The plastered houses' half-timbering and corner posts are chunkier than the kit's: a flat strip on a wall is
## TRIM_WIDEN times as wide and stands TRIM_DEEPEN times as far out from it; a corner post is POST_WIDEN times as thick.
const TRIM_WIDEN := 1.6
const TRIM_DEEPEN := 1.6
const POST_WIDEN := 1.3
## Stone blocks standing a little proud of the plaster here and there, as on Kelpwick's arena: this much darker than
## the house's paint, sized in the world's units (width range, height range, how far they stand out).
const BLOCK_SHADE := 0.11
const BLOCK_W := Vector2(0.30, 0.42)
const BLOCK_H := Vector2(0.15, 0.19)
const BLOCK_OUT := 0.05
## About one cluster of blocks for every this many square units of outside wall.
const BLOCK_AREA := 1.6
static var _block_materials := {}


static func plan(b: Dictionary) -> Dictionary:
	var key: String = b.get("cove_model","house_2")
	if not _meshes.has(key):
		_meshes[key] = load(DIR+key+".res")
	var mesh: Mesh = _meshes[key]
	var bb := mesh.get_aabb()
	var door: Vector3 = DOORS[key]
	var w := float(b["w"])
	var d := float(b["d"])
	var setback := APOTHECARY_SETBACK if b.get("shop", "") == "apothecary" else 0.0
	var dx := float(b.get("cove_door_dx",float(b["door"].x)+0.5-float(b["x"])-w/2.0))
	var scale := minf((w/2.0+dx-0.12)/(door.x-bb.position.x),(w/2.0-dx-0.12)/(bb.end.x-door.x))
	scale = minf(scale,(d-0.2-setback)/(door.z-bb.position.z))
	scale = minf(scale,float(b.get("cove_max_height",4.8))/bb.size.y)
	var offset := Vector3(dx-door.x*scale,-bb.position.y*scale,d/2.0-0.12-setback-door.z*scale)
	var out := {"key":key,"scale":scale,"offset":offset,
		"height":_height(key,bb.end.y,scale),
		"rect":Rect2(Vector2(bb.position.x*scale+offset.x,bb.position.z*scale+offset.z),Vector2(bb.size.x,bb.size.z)*scale),
		"door_at":Vector3(offset.x+door.x*scale,Houses.DOOR_H/2.0,offset.z+door.z*scale),
		"door_size":Vector2(Houses.DOOR_H/Houses.DOOR_ASPECT,Houses.DOOR_H)}
	if setback > 0.0:
		var front := d/2.0-0.12-setback
		var deck := Rect2(dx-APOTHECARY_PORCH_WIDTH/2.0,front-0.12,APOTHECARY_PORCH_WIDTH,setback+0.12)
		out["porch"] = {"rect":deck,"top":2.7,"y":0.02}
		out["rect"] = (out["rect"] as Rect2).merge(deck)
	return out


## Map the doorway, wall tops and upper floors independently; roof proportions stay intact.
static func _height(key: String, y: float, scale: float) -> float:
	var source: float = DOORS[key].y*2.0
	var target := Houses.DOOR_H
	if y <= source:
		return y/source*target
	for i in FLOORS[key].size():
		var next_source := float(FLOORS[key][i])
		var next_target := ground_storey(key) if i == 0 else target+maxf(UPPER_STOREY,(next_source-source)*scale)
		if y <= next_source:
			return lerpf(target,next_target,(y-source)/(next_source-source))
		source = next_source
		target = next_target
	return target+(y-source)*scale


static func ground_storey(key: String) -> float:
	return SHOP_STOREY if key in SHOP_STOREY_MODELS else GROUND_STOREY


## Remove the source door slab and fit the closed building once per plot scale (read back from disk where baked:
## mesh_store.gd, about 275 ms of Cocoon Cove's first build).
static func warped(key: String, scale: float) -> Mesh:
	var ck := "%s@%.4f" % [key,scale]
	if _meshes.has(ck):
		return _meshes[ck]
	var dressed: Mesh = MeshStore.fetch("cove", ck, func() -> Mesh: return _make_warped(key, scale))
	_meshes[ck] = dressed
	if not key.begins_with("hut"):
		_meshes[ck+"#blocks"] = MeshStore.fetch("cove", ck+"#blocks", func() -> Mesh: return _stucco_blocks(dressed, key, scale))
	return dressed


static func _make_warped(key: String, scale: float) -> Mesh:
	var m: Mesh = _meshes[key]
	var door: Vector3 = DOORS[key]
	var plastered := not key.begins_with("hut")
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arr := _without_door(m.surface_get_arrays(si),door)
		if (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			continue
		var material: Material = m.surface_get_material(si)
		var timber := plastered and material != null and material.resource_name == "Cove painted wood"
		var long_axes := PackedInt32Array()
		if timber:
			long_axes = _thicken(arr, m.get_aabb().get_center())
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		# The old bake's sealing box extended to 3.08, above this roof's 2.80 eave.
		# Lower its cap inside the roof; preserve the walls that seal the door/windows.
		var sealing_box := key == "house_1" and material.resource_name == "cove_stucco" and vs.size() == 24
		for i in vs.size():
			var v := vs[i]
			if sealing_box:
				v.y = minf(v.y, 2.80)
			if ns != null:
				var slope := (_height(key,v.y+0.001,scale)-_height(key,v.y,scale))/0.001/scale
				var n: Vector3 = ns[i]
				ns[i] = Vector3(n.x,n.y/slope,n.z).normalized()
			vs[i] = Vector3(v.x,_height(key,v.y,scale)/scale,v.z)
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns != null:
			arr[Mesh.ARRAY_NORMAL] = ns
			if timber:
				arr[Mesh.ARRAY_TEX_UV] = _grain_uvs(vs, ns, long_axes, scale)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		out.surface_set_name(out.get_surface_count()-1,m.surface_get_name(si))
		out.surface_set_material(out.get_surface_count()-1,m.surface_get_material(si))
	var dressed := Windows.dress(out, [], true, VT.WOOD.lightened(0.14) if key.begins_with("hut") else TIMBER, false, GLASS)
	if plastered:
		dressed = _grained_frames(dressed, scale)
	return dressed


## Widen the kit's timber in place (see TRIM_WIDEN): each separate piece is found by its touching corners, and only
## flat strips laid on a wall and upright square posts change. Returns each vertex's piece's long axis (0 x, 1 y, 2 z),
## which the grain follows.
static func _thicken(arr: Array, centre: Vector3, widen := true) -> PackedInt32Array:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		idx = PackedInt32Array(range(vs.size()))
	# One root per position, so a box's separately-normalled corners join up; then join each triangle's corners.
	# (a plain Array: the lambda below must see the joins made after it)
	var root := []
	root.resize(vs.size())
	var first := {}
	for i in vs.size():
		var k := vs[i].snapped(Vector3.ONE*0.001)
		root[i] = first.get(k, i)
		if not first.has(k):
			first[k] = i
	var find := func(a: int) -> int:
		while root[a] != a:
			a = root[a]
		return a
	for t in range(0, idx.size()-2, 3):
		var r0: int = find.call(idx[t])
		for j in [1, 2]:
			var r: int = find.call(idx[t+j])
			if r != r0:
				root[r] = r0
	var boxes := {}
	for i in idx:
		var r: int = find.call(i)
		boxes[r] = (boxes[r] as AABB).expand(vs[i]) if boxes.has(r) else AABB(vs[i], Vector3.ZERO)
	var long_axes := PackedInt32Array()
	long_axes.resize(vs.size())
	long_axes.fill(-1)
	var moves := {}
	for r in boxes:
		var box: AABB = boxes[r]
		var order := [0, 1, 2]
		order.sort_custom(func(a, b): return box.size[a] < box.size[b])
		var d0: float = box.size[order[0]]
		var d1: float = box.size[order[1]]
		var d2: float = box.size[order[2]]
		var c := box.get_center()
		var move := {"long": order[2]}
		if not widen:
			pass
		elif d0 <= 0.16 and d1 >= 0.12 and d1 <= 0.5 and d2 >= 0.9:
			# a strip on a wall: wider about its middle, and further out from the wall it lies on
			var inner: float = box.position[order[0]] if c[order[0]] > centre[order[0]] else box.end[order[0]]
			move["scale"] = [[order[1], c[order[1]], TRIM_WIDEN], [order[0], inner, TRIM_DEEPEN]]
		elif order[2] == 1 and d0 >= 0.2 and d1 <= 0.5 and d2 >= 1.5:
			move["scale"] = [[order[0], c[order[0]], POST_WIDEN], [order[1], c[order[1]], POST_WIDEN]]
		moves[r] = move
	for i in vs.size():
		var r: int = find.call(i)
		if not moves.has(r):
			continue
		var move: Dictionary = moves[r]
		long_axes[i] = move["long"]
		var v := vs[i]
		for s in move.get("scale", []):
			v[s[0]] = s[1] + (v[s[0]] - s[1]) * s[2]
		vs[i] = v
	arr[Mesh.ARRAY_VERTEX] = vs
	return long_axes


## The window frames Windows.dress() drew, given the hut wood's grain UVs (unwidened), so build() can dress them in
## the same timber as the beams.
static func _grained_frames(mesh: ArrayMesh, scale: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		if mesh.surface_get_name(si) == "window_frame":
			var long_axes := _thicken(arr, Vector3.ZERO, false)
			arr[Mesh.ARRAY_TEX_UV] = _grain_uvs(arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_NORMAL], long_axes, scale)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(si, mesh.surface_get_name(si))
		out.surface_set_material(si, mesh.surface_get_material(si))
	for key in mesh.get_meta_list():
		out.set_meta(key, mesh.get_meta(key))
	return out


## Texture coordinates for the hut wood: in world units (the kit's times `scale`), the grain along each piece's long
## axis, across it on the faces that show its length and over the end grain on its ends.
static func _grain_uvs(vs: PackedVector3Array, ns: PackedVector3Array, long_axes: PackedInt32Array, scale: float) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(vs.size())
	for i in vs.size():
		var n := ns[i].abs()
		var facing := 0 if n.x >= n.y and n.x >= n.z else (1 if n.y >= n.z else 2)
		var along := long_axes[i] if long_axes[i] >= 0 else 1
		if along == facing:
			along = (facing + 1) % 3
		var across := 3 - facing - along
		var p := vs[i] * scale
		uvs[i] = Vector2(p[across] / WOOD_TILE.x, p[along] / WOOD_TILE.y)
	return uvs


## Small blocks of darker plaster standing proud of a house's outside walls (see BLOCK_SHADE), in clusters of one to
## three, wherever plaster faces outwards with nothing in front of it: clear of windows, timber, the eaves and the
## front door. Built in the kit's (warped) space, like the house; null when nothing fits.
static func _stucco_blocks(mesh: ArrayMesh, key: String, scale: float) -> ArrayMesh:
	var tris := PackedVector3Array()
	var stucco := PackedByteArray()
	for si in mesh.get_surface_count():
		var material := mesh.surface_get_material(si)
		var plaster := material != null and material.resource_name == "cove_stucco"
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			idx = PackedInt32Array(range(vs.size()))
		for t in range(0, idx.size()-2, 3):
			tris.append_array([vs[idx[t]], vs[idx[t+1]], vs[idx[t+2]]])
			stucco.append(1 if plaster else 0)
	# a coarse grid of the triangles, so each ray only meets its neighbours
	var cell := 1.0
	var grid := {}
	for t in stucco.size():
		var box := AABB(tris[t*3], Vector3.ZERO).expand(tris[t*3+1]).expand(tris[t*3+2])
		var c0 := Vector3i((box.position / cell).floor())
		var c1 := Vector3i((box.end / cell).floor())
		for x in range(c0.x, c1.x+1):
			for y in range(c0.y, c1.y+1):
				for z in range(c0.z, c1.z+1):
					var key3 := Vector3i(x, y, z)
					if not grid.has(key3):
						grid[key3] = []
					grid[key3].append(t)
	var centre := mesh.get_aabb().get_center()
	var walls := []
	var total := 0.0
	for t in stucco.size():
		if stucco[t] == 0:
			continue
		var a := tris[t*3]
		var b := tris[t*3+1]
		var c := tris[t*3+2]
		# (Godot's front faces wind clockwise, so this points out of the face)
		var cross := (c - a).cross(b - a)
		var area := cross.length() / 2.0
		if area < 0.05:
			continue
		var n := cross.normalized()
		var mid := (a + b + c) / 3.0
		if absf(n.y) > 0.05 or Vector2(n.x, n.z).dot(Vector2(mid.x - centre.x, mid.z - centre.z)) <= 0.0:
			continue
		total += area
		walls.append([total, t, n])
	if walls.is_empty():
		return null
	var door: Vector3 = DOORS[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var reach := 0.6 / scale
	# Whether a point on the wall facing `n` is open plaster: a ray from in front first meets plaster, right there.
	var open := func(q: Vector3, n: Vector3) -> bool:
		var from := q + n * reach
		var to := q - n * (0.05 / scale)
		var near := INF
		var plaster := false
		var seen := {}
		var steps := 4
		for s in steps + 1:
			var cell_at := Vector3i((from.lerp(to, float(s) / steps) / cell).floor())
			for t in grid.get(cell_at, []):
				if seen.has(t):
					continue
				seen[t] = true
				var hit = Geometry3D.segment_intersects_triangle(from, to, tris[t*3], tris[t*3+1], tris[t*3+2])
				if hit != null and from.distance_to(hit) < near:
					near = from.distance_to(hit)
					plaster = stucco[t] == 1
		return plaster and absf(near - reach) < 0.02 / scale
	var placed := []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clusters := int(total * scale * scale / BLOCK_AREA)
	for attempt in clusters * 4:
		if placed.size() >= clusters * 2:
			break
		var pick := rng.randf() * total
		var lo := 0
		var hi := walls.size() - 1
		while lo < hi:
			var mid := (lo + hi) / 2
			if float(walls[mid][0]) < pick:
				lo = mid + 1
			else:
				hi = mid
		var wall: Array = walls[lo]
		var t: int = wall[1]
		var n: Vector3 = wall[2]
		var r1 := rng.randf()
		var r2 := rng.randf()
		if r1 + r2 > 1.0:
			r1 = 1.0 - r1
			r2 = 1.0 - r2
		var p := tris[t*3] + (tris[t*3+1] - tris[t*3]) * r1 + (tris[t*3+2] - tris[t*3]) * r2
		if p.y * scale < 0.35:
			continue
		# keep the doorway's wall clear, where the door, its frame and any shop front or porch go
		if absf(p.x - door.x) < 1.0 / scale and absf(p.z - door.z) < 0.6 / scale and p.y * scale < 2.4:
			continue
		var along := Vector3.UP.cross(n).normalized()
		var w := rng.randf_range(BLOCK_W.x, BLOCK_W.y) / scale
		var h := rng.randf_range(BLOCK_H.x, BLOCK_H.y) / scale
		var gap := 0.05 / scale
		var cluster := [p]
		var more := rng.randi_range(0, 2)
		if more >= 1:
			cluster.append(p + Vector3.UP * (h + gap) + along * w * rng.randf_range(-0.6, 0.6))
		if more >= 2:
			cluster.append(p + along * (w + gap) * (1.0 if rng.randf() < 0.5 else -1.0))
		for i in cluster.size():
			var q: Vector3 = cluster[i]
			var clear := true
			for other in placed:
				if (other as Vector3).distance_to(q) < (w + gap) * 1.1:
					clear = false
					break
			var margin := 0.05 / scale
			for corner in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				if not clear:
					break
				var probe: Vector3 = q + along * corner.x * (w / 2.0 + margin) + Vector3.UP * corner.y * (h / 2.0 + margin)
				clear = open.call(probe, n)
			if not clear:
				if i == 0:
					break
				continue
			placed.append(q)
			_block(st, q, n, along, w * rng.randf_range(0.9, 1.0), h, BLOCK_OUT / scale, 0.018 / scale)
	if placed.is_empty():
		return null
	return st.commit()


## One block on a wall: a box standing `out` proud of it with its front face drawn in by `bevel` all round, so its
## edges catch the light softly. It sinks a little into the wall, so no gap shows behind it.
static func _block(st: SurfaceTool, q: Vector3, n: Vector3, along: Vector3, w: float, h: float, out: float, bevel: float) -> void:
	var up := Vector3.UP
	var back := q - n * out * 0.3
	var front := q + n * out
	var b := [back - along*w/2 - up*h/2, back + along*w/2 - up*h/2, back + along*w/2 + up*h/2, back - along*w/2 + up*h/2]
	var f := [front - along*(w/2-bevel) - up*(h/2-bevel), front + along*(w/2-bevel) - up*(h/2-bevel),
		front + along*(w/2-bevel) + up*(h/2-bevel), front - along*(w/2-bevel) + up*(h/2-bevel)]
	var quad := func(a: Vector3, b2: Vector3, c: Vector3, d: Vector3) -> void:
		var normal := (b2 - a).cross(c - a).normalized()
		if normal.dot((a + b2 + c + d) / 4.0 - q) < 0.0:
			normal = -normal
			var swap := b2
			b2 = d
			d = swap
		st.set_normal(normal)
		for v in [a, c, b2, a, d, c]:
			st.add_vertex(v)
	quad.call(f[0], f[1], f[2], f[3])
	for i in 4:
		var j := (i + 1) % 4
		quad.call(b[i], b[j], f[j], f[i])


## A surface's arrays without the triangles lying wholly in the doorway in front of the wall (see DOOR_CUT).
static func _without_door(arr: Array, door: Vector3) -> Array:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		idx = PackedInt32Array(range(vs.size()))
	var keep := PackedInt32Array()
	for t in range(0,idx.size()-2,3):
		var cut := true
		for j in 3:
			var dv: Vector3 = vs[idx[t+j]]-door
			if absf(dv.x) > DOOR_CUT.x or dv.y > door.y+DOOR_CUT.y or dv.z < 0.02 or dv.z > DOOR_CUT.z:
				cut = false
				break
		if not cut:
			keep.append_array([idx[t],idx[t+1],idx[t+2]])
	arr[Mesh.ARRAY_INDEX] = keep
	return arr


static func build(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	var p: Dictionary = b.get("cove_plan",{})
	if p.is_empty():
		p = plan(b)
	var inst := MeshInstance3D.new()
	inst.mesh = warped(p["key"],float(p["scale"]))
	# One cached mesh can serve several houses without repainting its timber,
	# clay roof, window surrounds or blue/red door.
	var shop: String = b["shop"]
	# The Beast Center is a temple: pale stone, whatever paint its plot was given.
	var paint: String = "shrine" if shop == "center" else String(b.get("cove_stucco", "butter"))
	if not _stucco_materials.has(paint):
		var material := ShaderMaterial.new()
		material.resource_name = "Cove stucco: " + paint
		material.shader = StuccoShader
		material.set_shader_parameter("paint", STUCCO.get(paint, STUCCO["butter"]))
		_stucco_materials[paint] = material
	for surface in inst.mesh.get_surface_count():
		var material: Material = inst.mesh.surface_get_material(surface)
		if material != null and material.resource_name == "cove_stucco":
			inst.set_surface_override_material(surface, _stucco_materials[paint])
		elif material != null and material.resource_name == "Cove painted wood":
			# the kit's timber in the game's wood family (voxel_textures.gd): the dock shacks' walls and plank roofs in
			# sea-weathered boards, a house's frames and trim in wide beams, lighter boards a shade lighter
			var light := (material as StandardMaterial3D).albedo_color.get_luminance() > Color("#89684b").get_luminance() + 0.02
			if String(p["key"]).begins_with("hut"):
				inst.set_surface_override_material(surface, VT.wood_material("wood_drift", 0.12 if light else 0.0, VT.WOOD_DRIFT))
			else:
				inst.set_surface_override_material(surface, hut_wood(light))
		elif _roof(material):
			inst.set_surface_override_material(surface, _roof_material(material))
		elif inst.mesh.surface_get_name(surface) == "window_frame" and not String(p["key"]).begins_with("hut"):
			# the window frames and sills in the same hut wood as the house's beams
			inst.set_surface_override_material(surface, hut_wood())
	inst.scale = Vector3.ONE*float(p["scale"])
	inst.position = p["offset"]
	node.add_child(inst)
	var blocks: ArrayMesh = _meshes.get("%s@%.4f#blocks" % [p["key"], float(p["scale"])])
	if blocks != null and paint != "shrine":
		if not _block_materials.has(paint):
			var block_material := (_stucco_materials[paint] as ShaderMaterial).duplicate() as ShaderMaterial
			block_material.resource_name = "Cove stucco blocks: " + paint
			block_material.set_shader_parameter("paint", (STUCCO.get(paint, STUCCO["butter"]) as Color).darkened(BLOCK_SHADE))
			_block_materials[paint] = block_material
		var stones := MeshInstance3D.new()
		stones.name = "StuccoBlocks"
		stones.mesh = blocks
		stones.material_override = _block_materials[paint]
		stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stones.scale = inst.scale
		stones.position = inst.position
		node.add_child(stones)
	var builders = load("res://scripts/gfx/voxel_buildings.gd")
	if p.has("porch"):
		_porch(node,p)
	# Use exactly the same 1.8-unit door, frame, texture and brass knob as the
	# other towns, set on the wall over the kit's sealed infill (its own door slab cut away: warped()).
	var at: Vector3 = p["door_at"]
	p = p.duplicate()
	p["door_at"] = Vector3(at.x,Houses.DOOR_H/2.0,at.z-0.01)
	p["door_size"] = Vector2(Houses.DOOR_H/Houses.DOOR_ASPECT,Houses.DOOR_H)
	p["skin"] = Houses.SKINS["coastal"][2]
	Houses._front_door(node,p,Houses.mesh("cape-cod"),bool(b.get("locked",false)))
	if b.get("locked",false):
		var kit = builders.Kit.new()
		builders._door_lock(kit,p["door_at"]+Vector3(0,0,0.08),p["door_size"].x,p["door_size"].y)
		var lock := MeshInstance3D.new()
		lock.mesh = kit.mesh()
		node.add_child(lock)
	if shop == "center":
		# The temple front every Beast Center has, on the kit's wall under its clay eaves: columns either side of the
		# door, a lintel, the stepped pediment with the pawprint roundel, banners and a crystal on the roof's ridge.
		var kit = builders.Kit.new()
		var face: float = at.z
		var eave: float = ground_storey(p["key"])
		builders.shrine_front(kit,at.x,0.0,face,Houses.DOOR_H+0.06,eave,builders.SHRINE_STONE,0.78)
		var rect: Rect2 = p["rect"]
		for side in [-1.0,1.0]:
			var x: float = at.x+side*1.5
			if x > rect.position.x+0.35 and x < rect.end.x-0.35:
				builders._shrine_banner(kit,Vector3(x,eave-0.1,face+0.03),0.36,0.7)
		var ridge: float = float(p["height"])
		kit.box("plaster",Vector3(rect.get_center().x,ridge+0.05,rect.get_center().y),Vector3(0.34,0.3,0.34),builders.SHRINE_STONE,true)
		builders.shrine_crystal(kit,Vector3(rect.get_center().x,ridge+0.2+0.3,rect.get_center().y),0.2,0.74)
		var front := MeshInstance3D.new()
		front.name = "ShrineFront"
		front.mesh = kit.mesh()
		node.add_child(front)
	if shop in ["apothecary","bookstore"]:
		# Reuse the game's striped shop fronts, colors and pixel sign icons.
		if shop == "bookstore":
			p["awning_width"] = p["door_size"].x+0.35
		p["awning_a"] = AWNING[0]
		p["awning_b"] = AWNING[1]
		builders._shop_front(node,p,shop,builders.STYLES["coastal"])
	return node


## Kelpwick's hut wood (HUT_WOOD) for the plastered houses' timber, on the grain UVs warped() gives it; `light` boards a
## shade lighter.
static func hut_wood(light := false) -> StandardMaterial3D:
	if not _hut_wood.has(light):
		var material := StandardMaterial3D.new()
		material.resource_name = "Cove hut wood"
		material.albedo_texture = load(HUT_WOOD)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.roughness = 0.95
		if light:
			material.albedo_color = Color(1.14, 1.14, 1.14)
		_hut_wood[light] = material
	return _hut_wood[light]


## Whether a kit material is a roof's: the palette its roof reds come from, or the plain clay of the larger houses.
static func _roof(material: Material) -> bool:
	var m := material as StandardMaterial3D
	if m == null or m.resource_name != "":
		return false
	return m.albedo_texture != null or m.albedo_color.is_equal_approx(ROOF_CLAY)


static func _roof_material(source: StandardMaterial3D) -> ShaderMaterial:
	var key: Variant = source.albedo_texture if source.albedo_texture != null else source.albedo_color
	if not _roof_materials.has(key):
		var material := ShaderMaterial.new()
		material.resource_name = "Cove roof tiles"
		material.shader = RoofShader
		material.set_shader_parameter("use_atlas", source.albedo_texture != null)
		if source.albedo_texture != null:
			material.set_shader_parameter("atlas", source.albedo_texture)
		_roof_materials[key] = material
	return _roof_materials[key]


## A low, flush wood porch under the old town's shared striped shop awning.
## Both the deck and its posts stay inside the plot reserved by plan().
static func _porch(node: Node3D, p: Dictionary) -> void:
	var builders = load("res://scripts/gfx/voxel_buildings.gd")
	var kit = builders.Kit.new()
	var pc: Dictionary = p["porch"]
	var rect: Rect2 = pc["rect"]
	var center := rect.get_center()
	var height := float(pc["top"])
	var wood: Color = VT.WOOD
	kit.box("wood_deck",Vector3(center.x,0.01,center.y),Vector3(rect.size.x,0.02,rect.size.y),wood)
	for x in [rect.position.x+0.06,rect.end.x-0.06]:
		kit.box("wood_beam_v",Vector3(x,height/2.0,rect.end.y-0.06),Vector3(0.12,height,0.12),wood)
	for z in [p["door_at"].z-0.03,rect.end.y-0.06]:
		kit.box("wood_beam",Vector3(center.x,height-0.05,z),Vector3(rect.size.x+0.12,0.14,0.22),wood)
	var inst := MeshInstance3D.new()
	inst.mesh = kit.mesh()
	node.add_child(inst)


static func docks(map: Dictionary) -> Node3D:
	var gen = load("res://scripts/world/map_gen.gd")
	var builders = load("res://scripts/gfx/voxel_buildings.gd")
	var kit = builders.Kit.new()
	var posts := {}
	for y in int(map["h"]):
		for x in int(map["w"]):
			if gen.get_t(map,x,y) != gen.BRIDGE:
				continue
			# the deck itself is the wood family's deck boards, with their own seams (world.gd)
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if gen.get_t(map,x+delta.x,y+delta.y) != gen.WATER:
					continue
				var edge := Vector3(x+0.5+delta.x*0.48,0.52,y+0.5+delta.y*0.48)
				var size := Vector3(0.07,0.07,1.02) if delta.x != 0 else Vector3(1.02,0.07,0.07)
				kit.box("wood_beam",edge,size,VT.WOOD_DRIFT.lightened(0.14))
				if delta.x != 0:
					var px := x+(1 if delta.x>0 else 0)
					posts[Vector2i(px,y)] = true
					posts[Vector2i(px,y+1)] = true
				else:
					var pz := y+(1 if delta.y>0 else 0)
					posts[Vector2i(x,pz)] = true
					posts[Vector2i(x+1,pz)] = true
	for p in posts:
		kit.box("wood_beam_v",Vector3(p.x,-0.10,p.y),Vector3(0.13,1.42,0.13),VT.WOOD_DRIFT.darkened(0.08))
	var root := Node3D.new()
	var inst := MeshInstance3D.new()
	inst.mesh = kit.mesh()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)
	return root
