extends SceneTree
## Bakes the pieces the landmark buildings are dressed with into assets/psx/landmarks/ (see CREDITS.md):
##   godot --headless --path . --script res://tools/import_psx_landmarks.gd [-- name1 name2 ...]
##
## The arena is a small stone keep from McSteeg's Castle and Fort Builder Pack (crenellated walls, round towers with
## battlements, cone roofs, glazed windows) with the studded door of heyheythere's Castle Kit; the
## electronics shop wears a rooftop billboard from EmaceArt's Alone in the Dusk kit and a utility pole for its aerial
## (see voxel_buildings.gd). Each piece stays in its pack's metres, centred on x/z, standing on
## y = 0, turned so its front faces +z (walls run along x); the game scales and places them.

const B = preload("res://tools/psx_bake.gd")
const OUT := "res://assets/psx/landmarks/"
const MC := "Environments/FREE Castle and Fort Builder Pack (MCSTEEG)/Castles_and_Forts.glb#"
const CK := "Environments/PSX Castle Kit Free - Retro FPS Castle Hall Sampler (heyheythere)/glb/"
const DK := "Environments/FREE PSX Alone in the DUSK - environment asset kit (EmaceArt)/AloneInTheDusk_glTF_2026-10-04/single_models/"
const SANDSTONE := Color("#f2e4c8")

## name: [model under psx/, degrees to turn it so its front faces +z, options for psx_bake (gain, max_tex)]
## options: share = pieces painted from one texture sheet share one material, saved once as <share>_material.res;
##          tint = a colour laid over the texture (the castle pack's grey rubble warmed to the arena's sandstone)
const PIECES := {
	"fort_wall": [MC + "Wall_2x4", 90.0, {"gain": 1.45, "tint": SANDSTONE}],
	"fort_tower": [MC + "Tower_Mid", 0.0, {"gain": 1.45, "tint": SANDSTONE}],
	"fort_tower_top": [MC + "Tower_top_1", 0.0, {"gain": 1.45, "tint": SANDSTONE}],
	"fort_cone": [MC + "Roof_Cone", 0.0, {"gain": 1.25}],
	"fort_window": [MC + "Window_glass", -90.0, {}],
	"castle_door": [CK + "door_castle.glb", 0.0, {"max_tex": 512, "share": "castle"}],
	"castle_banner": [CK + "banner_red.glb", 0.0, {"max_tex": 512, "share": "castle"}],
	"billboard": [DK + "sh_Sign.glb", 180.0, {}],
	"utility_pole": [DK + "Telegraph_pole.glb", 0.0, {}],
}


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	var shared := {}
	for name in PIECES:
		if not only.is_empty() and not only.has(name):
			continue
		var e: Array = PIECES[name]
		var scene := B.load_model(src + String(e[0]))
		if scene == null:
			push_error("could not load " + String(e[0]))
			continue
		var mesh := B.turned(B.bake(scene, e[2]), float(e[1]))
		scene.free()
		if (e[2] as Dictionary).has("tint"):
			for si in mesh.get_surface_count():
				var tm := mesh.surface_get_material(si) as BaseMaterial3D
				if tm != null:
					tm.albedo_color = tm.albedo_color * Color(e[2]["tint"])
		var share := String((e[2] as Dictionary).get("share", ""))
		if share != "":
			# the kit's sheet is large: one copy, which every piece of the kit points at
			var mp := OUT + share + "_material.res"
			if not shared.has(share):
				ResourceSaver.save(mesh.surface_get_material(0), mp, ResourceSaver.FLAG_COMPRESS)
				shared[share] = load(mp)
			for si in mesh.get_surface_count():
				mesh.surface_set_material(si, shared[share])
		var err := ResourceSaver.save(mesh, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
		print("  %-16s %5d tris  %s  %s" % [name, B.tris(mesh), mesh.get_aabb().size.snapped(Vector3.ONE * 0.01), "ok" if err == OK else "SAVE FAILED"])
	quit()
