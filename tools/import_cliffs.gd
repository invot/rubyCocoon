extends SceneTree
## Bakes the cliff faces' textures (WorldDB.CLIFF_LOOKS "tex", terrain.gdshader) from the cliff packs in CREDITS.md:
## a clean patch of each pack's painted rock, made grey (each biome tints it), even, and seamless both ways.
##   godot --headless --path . --script res://tools/import_cliffs.gd -- [folder with the downloads]
## The folder (default build/cliff_source/) holds "sandstone__cliff.glb", "sandstone__cliff(1).glb" and
## "Stylized Cliff-Faces.zip" as downloaded; they're read where they are, never changed. Then run
## tools/smooth_textures.gd and godot --headless --path . --import.

const OUT := "res://assets/textures/surfaces/cliff_%s.png"
## name: [source file, image inside it, the patch to take (fractions: x0, y0, x1, y1), size baked]
const BAKES := {
	# YadroGames' Sandstone Cliff: its big face's upright grooves
	"rock": ["sandstone__cliff(1).glb", 0, [0.26, 0.12, 0.6, 0.53], Vector2i(512, 512)],
	# the other Sandstone Cliff: broken blocks
	"sandstone": ["sandstone__cliff.glb", 0, [0.56, 0.06, 0.92, 0.36], Vector2i(512, 512)],
	# Stylized Cliff-Faces: a band of weathered slabs
	"slate": ["Stylized Cliff-Faces.zip", "collection/CliffFaces_Set01_Diffuse.png", [0.07, 0.84, 0.73, 0.985], Vector2i(1024, 256)],
}
## the average grey a baked texture comes out at (terrain_mesh.gd TEX_LEVEL: the tints are scaled for it), and how
## far its shading spreads round that
const LEVEL := 0.71
const SPREAD := 0.13
## how much of a patch, past the size baked, is folded back to hide the seam
const OVERLAP := 0.25


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://build/cliff_source/")
	if not dir.ends_with("/") and not dir.ends_with("\\"):
		dir += "/"
	var bad := 0
	for name in BAKES:
		var b: Array = BAKES[name]
		var img := _source(dir + String(b[0]), b[1])
		if img == null:
			push_error("could not read %s from %s" % [b[1], dir + String(b[0])])
			bad += 1
			continue
		var r: Array = b[2]
		var sz := img.get_size()
		var rect := Rect2i(int(r[0] * sz.x), int(r[1] * sz.y), int((r[2] - r[0]) * sz.x), int((r[3] - r[1]) * sz.y))
		var out := img.get_region(rect)
		# a little more than the size baked: the overlap is folded back over the start to hide the seam
		out.resize(int(b[3].x * (1.0 + OVERLAP)), int(b[3].y * (1.0 + OVERLAP)), Image.INTERPOLATE_LANCZOS)
		_grey(out)
		out = _seamless(out, b[3].x, true)
		out = _seamless(out, b[3].y, false)
		out.save_png(ProjectSettings.globalize_path(OUT % name))
		print("%s: %s of %s -> %s" % [name, rect, b[0], OUT % name])
	quit(1 if bad > 0 else 0)


## The image `which` of a pack file: a GLB's nth image, or a file inside a zip.
func _source(path: String, which: Variant) -> Image:
	if path.get_extension().to_lower() == "zip":
		var z := ZIPReader.new()
		if z.open(path) != OK:
			return null
		var data := z.read_file(String(which))
		z.close()
		var img := Image.new()
		return img if img.load_png_from_buffer(data) == OK else null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var images := state.get_images()
	if int(which) >= images.size():
		return null
	var tex: Texture2D = images[int(which)]
	var img2 := tex.get_image()
	if img2.is_compressed():
		img2.decompress()
	img2.convert(Image.FORMAT_RGBA8)
	return img2


## Grey, averaging LEVEL, its shading eased to spread about SPREAD either way (dark cracks become soft shade).
func _grey(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	var mean := 0.0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			lum[x + y * w] = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
			mean += lum[x + y * w]
	mean /= w * h
	var dev := 0.0
	for v in lum:
		dev += (v - mean) * (v - mean)
	dev = sqrt(dev / (w * h))
	var k := SPREAD / maxf(dev, 0.001)
	for y in h:
		for x in w:
			var d := (lum[x + y * w] - mean) * k
			# soften the darkest cracks more than the highlights
			if d < 0.0:
				d = -SPREAD * 2.2 * (1.0 - exp(d / (SPREAD * 2.2)))
			var v := clampf(LEVEL + d, 0.3, 0.97)
			img.set_pixel(x, y, Color(v, v, v))


## The image cut to `size` across (or down), repeating seamlessly: what lies past that size is faded in over its start,
## so its first pixels carry on from its last.
func _seamless(img: Image, size: int, across: bool) -> Image:
	var w := size if across else img.get_width()
	var h := img.get_height() if across else size
	var band := (img.get_width() if across else img.get_height()) - size
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var at := x if across else y
			if at < band:
				var past := img.get_pixel(x + size, y) if across else img.get_pixel(x, y + size)
				c = past.lerp(c, smoothstep(0.0, 1.0, float(at) / band))
			out.set_pixel(x, y, c)
	return out
