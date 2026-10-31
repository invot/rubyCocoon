extends SceneTree
## Focused scenery checks: every map's hedge lines, unchanged solid garden footprints, and grass budgets.
const Loader = preload("res://scripts/world/map_loader.gd")
const DB = preload("res://scripts/data/world_db.gd")
const MG = preload("res://scripts/world/map_gen.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
func _initialize() -> void:
 var bad := 0
 var full := 0
 var drawn := 0
 var world = load("res://scripts/world/world.gd").new()
 for id in DB.TOWNS.keys()+DB.ROUTES.keys():
  var m := Loader.load_map(id,{})
  var grid: PackedByteArray = m.grid.duplicate()
  world.map=m
  var lines: Dictionary=world._hedge_lines()
  if m.grid!=grid:
   push_error("Hedge rendering changed collision in "+id)
   bad+=1
  for y in m.h:
   for x in m.w:
    if MG.get_t(m,x,y)==MG.BUSH:
     full+=1
  drawn+=lines.size()
  for p: Vector2i in lines:
   if MG.get_t(m,p.x,p.y)!=MG.BUSH:
    push_error("Hedge outside its planted ground in "+id)
    bad+=1
   if lines.has(p+Vector2i.RIGHT) and lines.has(p+Vector2i.DOWN) and lines.has(p+Vector2i.ONE):
    push_error("Filled 2x2 hedge block in "+id)
    bad+=1
 for i in 3:
  var mesh := VA.mesh("grass_leaf_%d"%i)
  var tris := 0
  for surface in mesh.get_surface_count():
   var a := mesh.surface_get_arrays(surface)
   tris+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and a[Mesh.ARRAY_INDEX].size()>0 else a[Mesh.ARRAY_VERTEX].size())/3
  print("grass ",i,": ",tris," triangles")
  if tris>400 or tris==0:
   bad+=1
 world.free()
 print("HEDGE/GRASS CHECK DONE: %d problem(s), %d shrubs in lines instead of %d packed tiles"%[bad,drawn,full])
 quit(bad)
