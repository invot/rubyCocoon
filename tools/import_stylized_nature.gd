extends SceneTree
## Bake the three supplied OBJ collections using the shared scenery mesh/LOD pipeline.
## python tools/prepare_stylized_nature.py [zip directory]
## godot --headless --path . --script res://tools/import_stylized_nature.gd
## Follow with tools/smooth_textures.gd and --import.
const Bake = preload("res://tools/import_psx_models.gd")
func _init() -> void:
 var baker = Bake.new()
 var only := OS.get_cmdline_user_args()
 for file in DirAccess.get_files_at("res://build/nature_split/"):
  if not file.ends_with(".json"):
   continue
  if not only.is_empty() and not only.has(file.get_basename()):
   continue
  var d = JSON.parse_string(FileAccess.get_file_as_string("res://build/nature_split/"+file))
  if not d is Dictionary or not d.has("v"):
   continue
  var img := Image.load_from_file(d.texture)
  img.resize(256,256,Image.INTERPOLATE_LANCZOS)
  if d.get("green",false):
   for y in img.get_height():
    for x in img.get_width():
     var c := img.get_pixel(x,y)
     if c.g > 0.2 and c.r > c.g*0.8 and c.b < c.g*0.65:
      img.set_pixel(x,y,Color(c.r*0.52,c.g*0.78,c.b*0.75,c.a))
  img.generate_mipmaps()
  var mat := StandardMaterial3D.new()
  mat.albedo_texture=ImageTexture.create_from_image(img)
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  mat.roughness=0.9
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(0,d.v.size(),3):
   for j in [0,2,1]:
    var p = d.v[i+j]
    var uv = d.uv[i+j]
    var n = d.n[i+j]
    st.set_uv(Vector2(uv[0],1.0-uv[1]))
    st.set_normal(Vector3(n[0],n[1],n[2]))
    st.add_vertex(Vector3(p[0],p[1],p[2]))
  st.set_material(mat)
  st.index()
  var mesh: ArrayMesh=st.commit()
  mesh=baker._simplified(mesh,_budget(file.get_basename()))
  var path := "res://assets/nature/"+file.get_basename()+".res"
  ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
  print(file.get_basename(),": ",d.v.size()/3," triangles")
 baker.free()
 quit()


static func _budget(name: String) -> int:
 if name.begins_with("bush") or name.begins_with("shrub"):
  return 700
 if name.begins_with("tree") or name.begins_with("palm") or name == "dead_tree":
  return 1400
 return 1000000
