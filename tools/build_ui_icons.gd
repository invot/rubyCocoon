extends SceneTree
## Copies the flatUI icons the menus use into assets/ui/flat/<name>.png, shrunk to PSX size and made crisp (alpha cut
## at half), named after the icons they stand in for (see ui_kit.gd tex).
##   godot --headless --path . --script res://tools/build_ui_icons.gd

const SRC := "res://ui/flatUI/Free icons/"
const OUT := "res://assets/ui/flat/"
const SIZE := 24
## name: index in the kit's (sorted) file list. None of the brand logos in the kit are used.
const PICK := {
	"tab_trainer": 8, "icon_notes": 35, "tab_bag": 7, "icon_quill": 15, "icon_map": 43, "tab_settings": 70,
	"icon_save": 0, "icon_home": 82, "icon_lock": 60, "icon_close": 75, "icon_info": 45, "icon_question": 47,
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var files := []
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(SRC)):
		if f.get_extension().to_lower() == "png":
			files.append(f)
	files.sort()
	for name in PICK:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + files[PICK[name]]))
		img.convert(Image.FORMAT_RGBA8)
		# trim the empty margin, then fit the icon in a square
		var used := img.get_used_rect()
		img = img.get_region(used)
		var side := maxi(img.get_width(), img.get_height())
		var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
		sq.fill(Color(0, 0, 0, 0))
		sq.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((side - img.get_width()) / 2, (side - img.get_height()) / 2))
		sq.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		for y in SIZE:
			for x in SIZE:
				var c := sq.get_pixel(x, y)
				sq.set_pixel(x, y, Color(1, 1, 1, 1.0 if c.a >= 0.5 else 0.0))
		sq.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("  ", name, " <- ", files[PICK[name]])
	quit()
