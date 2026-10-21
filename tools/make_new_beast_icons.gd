extends SceneTree
## Renders the menu icon of every new beast form (assets/beasts/<form>.res, beast_rig.gd) to
## assets/beasts/icons/<form>.res, and of its ghost to <form>_ghost.res (ImageTextures, so the game needs no import
## step), with scripts/gfx/beast_icons.gd: a three-quarter view from the front in the form's own colours, 48 x 48,
## with a dark outline, as the PSX beasts' (tools/make_beast_icons.gd). PixelArt.beast_texture shows them; a merge
## shows its frame's till the game has rendered its own.
## Needs a window (it renders):
##   godot --path . --rendering-driver opengl3 --script res://tools/make_new_beast_icons.gd [-- form1 form2 ...]
##   [-- --sheet=/path/sheet.png: all of them, larger, on one sheet to look over]

const BeastIcons = preload("res://scripts/gfx/beast_icons.gd")
const SRC := "res://assets/beasts/"
const OUT := "res://assets/beasts/icons/"


func _initialize() -> void:
	var only := []
	var sheet := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			sheet = a.substr(8)
		else:
			only.append(a)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var forms := []
	for f in DirAccess.get_files_at(SRC):
		if f.ends_with(".res") and (only.is_empty() or only.has(f.get_basename())):
			forms.append(f.get_basename())
	forms.sort()
	if forms.is_empty():
		quit()
		return
	var painter: SubViewport = BeastIcons.new()
	root.add_child(painter)
	# the very first render comes out empty: one throwaway first
	await painter.render({"form": forms[0]})
	var done := []
	for f in forms:
		for ghost in [false, true]:
			var img: Image = await painter.render({"form": f, "shade": 0.85 if ghost else 0.0})
			if img == null:
				push_error("no icon rendered for %s (run it with a window)" % f)
				continue
			var path: String = OUT + f + ("_ghost" if ghost else "") + ".res"
			ResourceSaver.save(ImageTexture.create_from_image(img), path, ResourceSaver.FLAG_COMPRESS)
			done.append(img)
			print("  icon ", path)
	if sheet != "" and not done.is_empty():
		# a row per form, its ghost beside it, three times the size on a mid grey
		var k := 3
		var cell := BeastIcons.SIZE * k + 6
		var cols := 12
		var out := Image.create(cell * cols, cell * ceili(done.size() / float(cols)), false, Image.FORMAT_RGBA8)
		out.fill(Color("#b8b4ac"))
		for i in done.size():
			var im: Image = done[i].duplicate()
			im.resize(BeastIcons.SIZE * k, BeastIcons.SIZE * k, Image.INTERPOLATE_NEAREST)
			out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * cell + 3, (i / cols) * cell + 3))
		out.save_png(sheet)
		print("  sheet ", sheet)
	quit()
