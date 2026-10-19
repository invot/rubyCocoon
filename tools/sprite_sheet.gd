extends SceneTree
## Debug tool: renders every race (plus ghost + merge samples) to user://sprites.png
## Run: godot --headless --path . --script res://tools/sprite_sheet.gd -- <out.png>

const PixelArt = preload("res://scripts/gfx/pixel_art.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const Beasts = preload("res://scripts/core/beasts.gd")

func _init() -> void:
	var cols := 12
	var scale := 3
	var cell := 40 * scale
	var extra_rows := 2
	var rows := 4 + extra_rows
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#2a3040"))
	for i in RaceDB.count():
		var img := PixelArt.beast_image(RaceDB.genes(i))
		img.resize(40 * scale, 40 * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, cell, cell), Vector2i((i % cols) * cell, (i / cols) * cell))
	for i in cols:
		var b = Beasts.create(i * 4, 20, true)
		var img := PixelArt.beast_image(b.genes)
		img.resize(40 * scale, 40 * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 4 * cell))
	for i in cols:
		var a = Beasts.create(i * 4 % 48, 20)
		var b = Beasts.create((i * 7 + 13) % 48, 20)
		var c = Beasts.merge(a, b, true)
		var img := PixelArt.beast_image(c.genes)
		img.resize(40 * scale, 40 * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 5 * cell))
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://sprites.png"
	sheet.save_png(out)
	print("saved ", out)
	quit()
