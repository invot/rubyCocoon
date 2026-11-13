extends SceneTree
## Read-only cache/configuration inventory; never removes or edits existing caches.


func _initialize() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			opts[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	if not String(opts.get("report", "")).begins_with("res://build/"):
		quit(1)
		return
	var settings := {}
	for prop in ProjectSettings.get_property_list():
		var key: String = prop.name
		if "shader_cache" in key or "pipeline_cache" in key or "frame_pacing/android" in key:
			settings[key] = ProjectSettings.get_setting(key)
	var report := {"engine": Engine.get_version_info(), "user_data_dir": OS.get_user_data_dir(), "settings": settings,
		"user_shader_cache": _files(ProjectSettings.globalize_path("user://shader_cache")),
		"project_shader_cache": _files(ProjectSettings.globalize_path("res://.godot/shader_cache"))}
	var path: String = opts.report
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SHADER CACHE PROBE DONE")
	quit()


func _files(path: String) -> Dictionary:
	var count := 0
	var bytes := 0
	var extensions := {}
	var stack := [path]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		for child in dir.get_directories():
			stack.append(current.path_join(child))
		for child in dir.get_files():
			var file := FileAccess.open(current.path_join(child), FileAccess.READ)
			if file != null:
				count += 1
				bytes += file.get_length()
				var ext := child.get_extension()
				extensions[ext] = extensions.get(ext, 0) + 1
	return {"path": path, "exists": DirAccess.dir_exists_absolute(path), "files": count, "bytes": bytes, "extensions": extensions}
