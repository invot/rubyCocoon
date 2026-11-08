extends SceneTree
## Smooths the baked world textures in place for the game's PS2-era look (scripts/gfx/smooth_texture.gd): the surface,
## pattern and interior PNGs, and the textures inside the baked scenery, house, landmark and furniture meshes, whose materials
## are switched to smooth (linear, mipmapped, anisotropic) sampling. People, beasts, robots and summons are left alone.
##   godot --headless --path . --script res://tools/smooth_textures.gd
##   godot --headless --path . --import
## Run it after re-baking any of those assets. tools/smoothed.json remembers each file as it was left, so a file is
## only smoothed again once a bake has replaced it.
## -- --compress-only losslessly repacks already-smoothed resources without smoothing their textures again.

const Smooth = preload("res://scripts/gfx/smooth_texture.gd")
const RECORD := "res://tools/smoothed.json"
const PNG_DIRS := ["res://assets/textures/surfaces/", "res://assets/textures/patterns/", "res://assets/interiors/tex/"]
const MESH_DIRS := ["res://assets/nature/", "res://assets/props/", "res://assets/boats/", "res://assets/houses/tiles/",
	"res://assets/houses/", "res://assets/exteriors/", "res://assets/interiors/"]

var record := {}
var done_textures := {}
var only_prefix := ""
var compress_only := false
var failures := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only_prefix = arg.trim_prefix("--only=")
		elif arg == "--compress-only":
			compress_only = true
	if FileAccess.file_exists(RECORD):
		record = JSON.parse_string(FileAccess.get_file_as_string(RECORD))
	var count := 0
	if not compress_only:
		for dir in PNG_DIRS:
			for f in DirAccess.get_files_at(dir):
				if f.get_extension() == "png" and _png(dir + f):
					count += 1
	for dir in MESH_DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() != "res":
				continue
			var changed := _compress_resource(dir + f) if compress_only else _resource(dir + f)
			if changed:
				count += 1
	var out := FileAccess.open(RECORD, FileAccess.WRITE)
	out.store_string(JSON.stringify(record, "\t", true))
	out.close()
	if compress_only:
		print("COMPRESS RESOURCES DONE: %d files compressed, %d problem(s)" % [count, failures])
	else:
		print("SMOOTH TEXTURES DONE: %d files smoothed, %d textures" % [count, done_textures.size()])
	quit(1 if failures > 0 else 0)


func _fresh(path: String) -> bool:
	if only_prefix != "" and not path.begins_with(only_prefix):
		return false
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
	return _save_resource(res, path)


func _compress_resource(path: String) -> bool:
	if only_prefix != "" and not path.begins_with(only_prefix):
		return false
	# Only repack resources whose smoothing record is current. A re-baked file still needs the normal pass.
	if not record.has(path) or _fresh(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var header := file.get_buffer(4).get_string_from_ascii()
	file.close()
	if header != "RSRC":
		return false
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		failures += 1
		return false
	return _save_resource(res, path)


func _save_resource(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		failures += 1
		push_error("Could not save %s: %s" % [path, error_string(err)])
		return false
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
