extends SceneTree
## Export the renderer's fitted bounds for the Python sightline checker.
const Maps = preload("res://scripts/world/map_loader.gd")
const Cove = preload("res://scripts/gfx/cove_buildings.gd")
func _init() -> void:
	var map := Maps.load_map("caccoon",{})
	var bounds := {}
	var buildings: Array = map["buildings"].duplicate()
	for scenery in map.get("scenery_houses",[]):
		var b: Dictionary = scenery.duplicate()
		b["door"] = Vector2i(int(b["x"])+int(b["w"])/2,int(b["y"])+int(b["d"])-1)
		buildings.append(b)
	for b in buildings:
		var p := Cove.plan(b)
		var r: Rect2 = p["rect"]
		bounds["%d,%d"%[b["x"],b["y"]]] = {"plot":[b["w"],b["d"]],"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"height":p["height"]}
	var f := FileAccess.open("res://assets/exteriors/cove_layout_bounds.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(bounds,"\t"))
	print("COVE BOUNDS DONE: ",bounds.size()," fitted buildings")
	quit()
