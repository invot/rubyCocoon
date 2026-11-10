extends SceneTree
## Extract the user-supplied Towns kit through the existing scenery bake pipeline.
## godot --headless --path . --script res://tools/prepare_cove_proposals.gd -- --source=C:/path/to/downloads
## Then run tools/smooth_textures.gd -- --only=res://assets/exteriors/cove_ and --import.
## The playable Cove and the original layout studies share these repaired assets.

const Bake = preload("res://tools/psx_bake.gd")
const Exterior = preload("res://tools/cove_exteriors.gd")
const OUT := "res://assets/exteriors/cove_"
const PARTS := {
	"house_1": "House1_10", "house_2": "House2_9", "house_3": "House3_8", "house_4": "House4_7",
	"hut_1": "Hut1Pos_13", "hut_2": "Hut2POS_16", "hut_3": "Hut3POS_19", "hut_4": "Hut4POS_22",
	"walkway": "LongWalkway_23", "floor_1": "FloorBoard1_24", "floor_2": "FloorBoard2_32",
	"floor_big": "FloorBoardBIG_27", "platform": "Platform_37", "stairs_1": "Stair1_38",
	"stairs_2": "Stair2_39", "barrel": "Barrel_0", "crate": "Crate_6", "post": "Post1_34",
	"rock": "Rock_36", "stall": "StallPOS_43", "table": "Table1_44",
}


func _init() -> void:
	var source := ""
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if source.is_empty():
		push_error("Pass --source=directory containing towns.glb and wholehousefbx.glb")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var failed := 0
	var report := {}
	for key in PARTS.keys() + ["whole_house"]:
		if not only.is_empty() and not key in only:
			continue
		var path: String = source.path_join("wholehousefbx.glb") if key == "whole_house" else source.path_join("towns.glb") + "#" + PARTS[key]
		var scene := Bake.load_model(path)
		if scene == null:
			push_error("Missing source model: " + path)
			failed += 1
			continue
		var mesh := Bake.bake(scene, {"max_tex": 256, "scale": 0.01 if key == "whole_house" else 1.0})
		scene.free()
		if key in ["whole_house", "crate", "barrel"] or key.begins_with("house_") or key.begins_with("hut_"):
			mesh = Exterior.new().finish(mesh,key)
		if Bake.tris(mesh) > 300:
			mesh = Bake.with_lods(mesh)
		var err := ResourceSaver.save(mesh, OUT + key + ".res", ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			failed += 1
		report[key] = {"size": str(mesh.get_aabb().size), "triangles": Bake.tris(mesh)}
		print(key, " ", report[key])
	var f := FileAccess.open("res://build/pirate_cove/asset_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
	print("COVE ASSETS DONE: %d problem(s)" % failed)
	quit(1 if failed else 0)
