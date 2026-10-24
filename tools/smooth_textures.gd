extends SceneTree
## Smooths the baked world textures in place for the game's PS2-era look (scripts/gfx/smooth_texture.gd): the surface,
## pattern and interior PNGs, and the textures inside the baked scenery, house, landmark and furniture meshes, whose materials
## are switched to smooth (linear, mipmapped, anisotropic) sampling. People, beasts, robots and summons are left alone.
##   godot --headless --path . --script res://tools/smooth_textures.gd
##   godot --headless --path . --import
## Run it after re-baking any of those assets. tools/smoothed.json remembers each file as it was left, so a file is
## only smoothed again once a bake has replaced it.

const Smooth = preload("res://scripts/gfx/smooth_texture.gd")
const RECORD := "res://tools/smoothed.json"
const PNG_DIRS := ["res://assets/textures/surfaces/", "res://assets/textures/patterns/", "res://assets/interiors/tex/"]
const MESH_DIRS := ["res://assets/nature/", "res://assets/props/", "res://assets/boats/", "res://assets/houses/tiles/",
	"res://assets/houses/", "res://assets/exteriors/", "res://assets/interiors/"]

var record := {}
var done_textures := {}


func _init() -> void:
	if FileAccess.file_exists(RECORD):
		record = JSON.parse_string(FileAccess.get_file_as_string(RECORD))
	var count := 0
	for dir in PNG_DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() == "png" and _png(dir + f):
				count += 1
	for dir in MESH_DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() == "res" and _resource(dir + f):
				count += 1
	var out := FileAccess.open(RECORD, FileAccess.WRITE)
	out.store_string(JSON.stringify(record, "\t", true))
	out.close()
	print("SMOOTH TEXTURES DONE: %d files smoothed, %d textures" % [count, done_textures.size()])
	quit()


func _fresh(path: String) -> bool:
	return record.get(path, "") != FileAccess.get_md5(path)


func _png(path: String) -> bool:
	if not _fresh(path):
		return false
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return false
	var out := Smooth.soften(img)
	out.clear_mipmaps()
	out.save_png(ProjectSettings.globalize_path(path))
	# the game samples them with mipmaps now
	var imp := path + ".import"
	if FileAccess.file_exists(imp):
		var text := FileAccess.get_file_as_string(imp).replace("mipmaps/generate=false", "mipmaps/generate=true")
		var f := FileAccess.open(imp, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	record[path] = FileAccess.get_md5(path)
	return true


func _resource(path: String) -> bool:
	if not _fresh(path):
		return false
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is ImageTexture:
		res = _smoothed(res)
	elif res is Mesh:
		for si in res.get_surface_count():
			_material(res.surface_get_material(si))
	else:
		return false
	ResourceSaver.save(res, path)
	record[path] = FileAccess.get_md5(path)
	return true


func _material(m) -> void:
	if not m is BaseMaterial3D:
		return
	var bm := m as BaseMaterial3D
	bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# a texture saved in its own file (house tiles) is smoothed there
	if _inline(bm.albedo_texture):
		var emits := bm.emission_texture == bm.albedo_texture
		bm.albedo_texture = _smoothed(bm.albedo_texture)
		if emits:
			bm.emission_texture = bm.albedo_texture
	if _inline(bm.emission_texture):
		bm.emission_texture = _smoothed(bm.emission_texture)


func _inline(tex) -> bool:
	return tex is ImageTexture and (tex.resource_path == "" or "::" in tex.resource_path)


## A new texture rather than set_image() on the old one: without a renderer (--headless) the old one would still save
## its old picture.
func _smoothed(tex: ImageTexture) -> ImageTexture:
	var id := tex.get_instance_id()
	if not done_textures.has(id):
		done_textures[id] = ImageTexture.create_from_image(Smooth.soften(tex.get_image()))
	return done_textures[id]
