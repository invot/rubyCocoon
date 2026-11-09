extends RefCounted
## The supplied, repaired Towns kit, fitted to existing tile plots and door anchors.
## Both interactive and scenery buildings use the streamed world building path.

const DIR := "res://assets/exteriors/cove_"
const Houses = preload("res://scripts/gfx/house_models.gd")
const DOORS := {
	"whole_house": Vector3(-0.03,1.12,3.60), "house_1": Vector3(0,1.02,3.61),
	"house_2": Vector3(-1.40,0.95,1.56), "house_3": Vector3(-0.246,0.95,2.89),
	"house_4": Vector3(-2.81,0.95,3.14), "hut_1": Vector3(-1.1905,1.1,2.18),
	"hut_3": Vector3(1.1435,1.1,2.07), "hut_4": Vector3(0.9475,1.1,4.28),
}
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
	var dx := float(b.get("cove_door_dx",float(b["door"].x)+0.5-float(b["x"])-w/2.0))
	var scale := minf((w/2.0+dx-0.12)/(door.x-bb.position.x),(w/2.0-dx-0.12)/(bb.end.x-door.x))
	scale = minf(scale,(d-0.2)/(door.z-bb.position.z))
	scale = minf(scale,float(b.get("cove_max_height",4.8))/bb.size.y)
	var offset := Vector3(dx-door.x*scale,-bb.position.y*scale,d/2.0-0.12-door.z*scale)
	return {"key":key,"scale":scale,"offset":offset,"height":bb.size.y*scale,
		"rect":Rect2(Vector2(bb.position.x*scale+offset.x,bb.position.z*scale+offset.z),Vector2(bb.size.x,bb.size.z)*scale),
		"door_at":offset+door*scale,"door_size":Vector2(1.0,door.y*2.0)*scale}


static func build(b: Dictionary) -> Node3D:
	var node := Node3D.new()
	var p: Dictionary = b.get("cove_plan",{})
	if p.is_empty():
		p = plan(b)
	var inst := MeshInstance3D.new()
	inst.mesh = _meshes[p["key"]]
	inst.scale = Vector3.ONE*float(p["scale"])
	inst.position = p["offset"]
	node.add_child(inst)
	var shop: String = b["shop"]
	var builders = load("res://scripts/gfx/voxel_buildings.gd")
	# Use exactly the same 1.8-unit door, frame, texture and brass knob as the
	# other towns, placed over the kit's sealed source leaf.
	var at: Vector3 = p["door_at"]
	p = p.duplicate()
	p["door_at"] = Vector3(at.x,Houses.DOOR_H/2.0,at.z+0.15)
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
		builders._shop_front(node,p,shop,builders.STYLES["coastal"])
	return node


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
