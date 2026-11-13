extends SceneTree
## Rasterises every SVG in a folder with Godot's own SVG renderer (ThorVG, as the game uses), each scaled to a width.
##   godot --headless --script res://tools/place_banners/raster.gd -- <svg_dir> <out_dir> <width>


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src: String = a[0]
	var out: String = a[1]
	var w := float(a[2])
	DirAccess.make_dir_recursive_absolute(out)
	for f in DirAccess.get_files_at(src):
		if not f.ends_with(".svg"):
			continue
		var text := FileAccess.get_file_as_string(src.path_join(f))
		var probe := Image.new()
		probe.load_svg_from_string(text, 1.0)
		var img := Image.new()
		img.load_svg_from_string(text, w / maxf(1.0, probe.get_width()))
		img.save_png(out.path_join(f.get_basename() + ".png"))
		print("%s %dx%d" % [f, img.get_width(), img.get_height()])
	quit()
