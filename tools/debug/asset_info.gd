extends SceneTree
## Debug: prints an asset's bounding box.  godot --headless -s tools/debug/asset_info.gd -- palm fern
func _init() -> void:
	var VA = load("res://scripts/gfx/voxel_assets.gd")
	for n in OS.get_cmdline_user_args():
		print(n, " aabb=", VA.aabb(n), " fit(2.5)=", VA.fit_scale(n, 2.5))
	quit()
