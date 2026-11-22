extends RefCounted
## Generated meshes on disk, so a map's first visit reads them back rather than making them again in script (the same
## idea as the ground, ground_store.gd). A builder asks fetch(group, key, maker) for what it would otherwise make with
## maker; the shipped copy in res://assets/baked_meshes/<group>/ is used when there is one, and maker runs otherwise.
## Cocoon Cove's houses (cove_buildings.gd warped: each kit house reshaped vertex by vertex per plot size) took about
## 275 ms of its first build and the voxel props (voxel_props.gd: the signpost alone 77 ms) about 80 ms.
## A copy is only as good as the code and models that made it. The shipped set records them (index.json, a hash per
## group of GROUPS' files), and a run that can read the scripts (the editor, the tests) ignores a group baked from other
## ones; an exported game has only compiled scripts and trusts the set it was exported with. Bake and check the set with
## tools/bake_meshes.gd (--scene=bake-meshes, --verify=1; run_tests.sh "meshes").
const DIR := "res://assets/baked_meshes/"
const INDEX := DIR + "index.json"
## Materials the baked meshes share, saved once (tools/bake_meshes.gd), and the painted textures of theirs left out to be
## taken from voxel_textures.gd (by its key there) or from inside a model file (res:<path>::<id>) as they load:
## {material file: {slot: where}}.
const SHARED := DIR + "shared/"
const LINKS := SHARED + "links.json"
## What each group's meshes are made from: its scripts and source models. (A file in a folder: every file in it.)
const GROUPS := {
	"cove": ["res://scripts/gfx/cove_buildings.gd", "res://scripts/gfx/cartoon_windows.gd",
		"res://scripts/gfx/window_glass.gd", "res://scripts/gfx/voxel_textures.gd", "res://assets/exteriors/cove_*.res"],
	"props": ["res://scripts/gfx/voxel_props.gd", "res://scripts/gfx/lowpoly_mesher.gd",
		"res://scripts/gfx/voxel_textures.gd", "res://scripts/gfx/voxel_buildings.gd"],
	"houses": ["res://scripts/gfx/house_builder.gd", "res://scripts/gfx/cartoon_windows.gd",
		"res://scripts/gfx/window_glass.gd", "res://assets/exteriors/door_*.res", "res://assets/exteriors/win_*.res"],
	"fences": ["res://scripts/gfx/fence_models.gd", "res://scripts/gfx/voxel_assets.gd",
		"res://scripts/data/voxel_manifest.gd", "res://assets/props/*fence*.res"],
	"folk": ["res://scripts/gfx/townfolk.gd", "res://scripts/data/wardrobe_db.gd", "res://assets/townfolk/townfolk.json",
		"res://assets/townfolk/parts/*.res"],
}

## Off: make everything afresh (the bake tool, and comparing with the generators).
static var reading := true
## The bake tool's: every mesh made, by its file, to save or compare.
static var recording := false
static var recorded := {}
static var _usable := {}
static var _index = null
static var _links = null


static func file_of(group: String, key: String) -> String:
	return DIR + group + "/" + key.md5_text() + ".res"


static func fetch(group: String, key: String, maker: Callable) -> Resource:
	var file := file_of(group, key)
	if reading and usable(group) and ResourceLoader.exists(file):
		var got := ResourceLoader.load(file)
		if got != null:
			_relink(got)
			return got
	var made: Resource = maker.call()
	if recording and made != null:
		recorded[file] = made
	return made


## Whether the shipped copies of a group came from the code and models this run has.
static func usable(group: String) -> bool:
	if not _usable.has(group):
		if _index == null:
			_index = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) if FileAccess.file_exists(INDEX) else {}
			if not _index is Dictionary:
				_index = {}
		var made := made_from(group)
		_usable[group] = _index.has(group) and (made == "compiled" or String(_index[group]) == made)
		if _index.has(group) and not _usable[group]:
			push_warning("The baked meshes in %s%s are from other code or models: run tools/bake_meshes.gd." % [DIR, group])
	return _usable[group]


## A hash of a group's scripts and models, or "compiled" where only compiled scripts exist (an exported game).
static func made_from(group: String) -> String:
	var text := ""
	for path: String in GROUPS[group]:
		if path.contains("*"):
			var dir := path.get_base_dir()
			var files := Array(DirAccess.get_files_at(dir))
			files.sort()
			for f: String in files:
				if f.match(path.get_file()):
					text += FileAccess.get_md5(dir + "/" + f)
		elif path.ends_with(".gd"):
			var source := FileAccess.get_file_as_string(path)
			if not "func " in source:
				return "compiled"
			text += source.replace("\r\n", "\n").md5_text()
		else:
			text += FileAccess.get_md5(path)
	return text.md5_text()


## Puts voxel_textures.gd's own textures back on a loaded mesh's shared materials (see LINKS) where they are missing.
static func _relink(mesh: Mesh) -> void:
	if _links == null:
		_links = JSON.parse_string(FileAccess.get_file_as_string(LINKS)) if FileAccess.file_exists(LINKS) else {}
		if not _links is Dictionary:
			_links = {}
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat == null or not _links.has(mat.resource_path):
			continue
		var vt: GDScript = load("res://scripts/gfx/voxel_textures.gd")
		var slots: Dictionary = _links[mat.resource_path]
		for slot in slots:
			if (mat.get_shader_parameter(slot) if mat is ShaderMaterial else mat.get(slot)) != null:
				continue
			var key: String = slots[slot]
			var tex: Texture2D
			if key.begins_with("res:"):
				tex = _inside(key.substr(4))
			elif key.begins_with("terrain:"):
				var parts := key.split(":")
				tex = vt.terrain(parts[1], parts[2], parts[3])
			else:
				tex = vt.texture(key)
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter(slot, tex)
			else:
				mat.set(slot, tex)


## A texture saved inside another resource file ("res://a.res::ImageTexture_x"): loading the file caches its parts by
## those paths. The file is kept so its parts stay cached.
static var _files := {}
static func _inside(path: String) -> Texture2D:
	var file := path.get_slice("::", 0)
	if not _files.has(file):
		_files[file] = load(file)
	return ResourceLoader.load(path) if ResourceLoader.has_cached(path) else null
