extends SceneTree
## Debug: lists voxel assets whose bounds are off-centre or unusually flat.
func _init() -> void:
	var VA = load("res://scripts/gfx/voxel_assets.gd")
	for n in VA.Manifest.ASSETS:
		var bb: AABB = VA.aabb(n)
		var c := bb.get_center()
		if absf(c.x) > 0.3 or absf(c.z) > 0.3 or absf(bb.position.y) > 0.15 or bb.size.y < 0.15:
			print("%-22s pos=%s size=%s" % [n, bb.position, bb.size])
	quit()
