extends RefCounted
## The supplied, repaired Towns kit, fitted to existing tile plots and door anchors.
## Both interactive and scenery buildings use the streamed world building path.

const DIR := "res://assets/exteriors/cove_"
const Houses = preload("res://scripts/gfx/house_models.gd")
const Windows = preload("res://scripts/gfx/cartoon_windows.gd")
const STUCCO := {
	"sky": Color("#a3cad8"), "coral": Color("#e4ac99"),
	"sage": Color("#b4cb9c"), "rose": Color("#d8adb8"),
	"butter": Color("#ead398"), "lavender": Color("#c7b9d9"),
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
const TIMBER := Color("#89684b")
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
	"whole_house": [3.75, 7.5], "house_1": [3.08], "house_2": [2.72],
	"house_3": [2.925, 5.12], "house_4": [5.12],
	"hut_1": [3.14], "hut_3": [3.14], "hut_4": [3.2],
}
const GROUND_STOREY := 2.6
## The shops' taller ground storey: the apothecary's (house_3) and the Beast Center's (house_1), whose sign board over
## the awning (voxel_buildings.gd _shop_front, up to about 2.7) must sit on the wall under the eaves, not in the roof.
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


## Remove the source door slab and fit the closed building once per plot scale.
static func warped(key: String, scale: float) -> Mesh:
	var m: Mesh = _meshes[key]
	var ck := "%s@%.4f" % [key,scale]
	if _meshes.has(ck):
		return _meshes[ck]
	var door: Vector3 = DOORS[key]
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arr := _without_door(m.surface_get_arrays(si),door)
		if (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			continue
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var v := vs[i]
			if ns != null:
				var slope := (_height(key,v.y+0.001,scale)-_height(key,v.y,scale))/0.001/scale
				var n: Vector3 = ns[i]
				ns[i] = Vector3(n.x,n.y/slope,n.z).normalized()
			vs[i] = Vector3(v.x,_height(key,v.y,scale)/scale,v.z)
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns != null:
			arr[Mesh.ARRAY_NORMAL] = ns
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		out.surface_set_name(out.get_surface_count()-1,m.surface_get_name(si))
		out.surface_set_material(out.get_surface_count()-1,m.surface_get_material(si))
	var dressed := Windows.dress(out, [], true, Color("#c49a64") if key.begins_with("hut") else TIMBER, false, GLASS)
	_meshes[ck] = dressed
	return dressed


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
	var paint: String = b.get("cove_stucco", "butter")
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
		elif _roof(material):
			inst.set_surface_override_material(surface, _roof_material(material))
	inst.scale = Vector3.ONE*float(p["scale"])
	inst.position = p["offset"]
	node.add_child(inst)
	var shop: String = b["shop"]
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
	if shop in ["center","apothecary","bookstore"]:
		# Reuse the game's striped shop fronts, colors and pixel sign icons.
		if shop == "bookstore":
			p["awning_width"] = p["door_size"].x+0.35
		p["awning_a"] = AWNING[0]
		p["awning_b"] = AWNING[1]
		builders._shop_front(node,p,shop,builders.STYLES["coastal"])
	return node


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
	var wood := Color("#89684b")
	kit.box("planks",Vector3(center.x,0.01,center.y),Vector3(rect.size.x,0.02,rect.size.y),wood)
	for x in [rect.position.x+0.06,rect.end.x-0.06]:
		kit.box("planks",Vector3(x,height/2.0,rect.end.y-0.06),Vector3(0.12,height,0.12),wood)
	for z in [p["door_at"].z-0.03,rect.end.y-0.06]:
		kit.box("planks",Vector3(center.x,height-0.05,z),Vector3(rect.size.x+0.12,0.14,0.22),wood)
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
			# Painted boards with quiet seams, instead of magnified dark wood grain.
			for seam in [0.0,0.33,0.66]:
				kit.box("color",Vector3(x+0.5,0.084,y+seam),Vector3(1.0,0.006,0.013),Color("#96734f"))
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if gen.get_t(map,x+delta.x,y+delta.y) != gen.WATER:
					continue
				var edge := Vector3(x+0.5+delta.x*0.48,0.52,y+0.5+delta.y*0.48)
				var size := Vector3(0.07,0.07,1.02) if delta.x != 0 else Vector3(1.02,0.07,0.07)
				kit.box("planks",edge,size,Color("#b18b5e"))
				if delta.x != 0:
					var px := x+(1 if delta.x>0 else 0)
					posts[Vector2i(px,y)] = true
					posts[Vector2i(px,y+1)] = true
				else:
					var pz := y+(1 if delta.y>0 else 0)
					posts[Vector2i(x,pz)] = true
					posts[Vector2i(x+1,pz)] = true
	for p in posts:
		kit.box("planks",Vector3(p.x,-0.10,p.y),Vector3(0.13,1.42,0.13),Color("#886746"))
	var root := Node3D.new()
	var inst := MeshInstance3D.new()
	inst.mesh = kit.mesh()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)
	return root
