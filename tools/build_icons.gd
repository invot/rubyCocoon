extends SceneTree
## Bakes the game's smooth menu icons from vector silhouettes (tools/icon_src, copied from the packs; see CREDITS.md)
## into 128 px PNGs, all in one cozy painted look: the shape in its colour with soft top light and a darker rim,
## its inner detail (enclosed gaps) in a light tint of the same colour, a warm dark outline round the outside and
## a soft drop shadow. What to bake and in which colours is in tools/icon_manifest.gd.
##   godot --headless --path . --script res://tools/build_icons.gd [-- --only=potion,heart] [--sheet=build/shots/icons.png]
## then `godot --headless --path . --import`.

const Manifest = preload("res://tools/icon_manifest.gd")

const SRC := "res://tools/icon_src/"
const OUT := "res://assets/ui/icons/"
## Working size (baked at twice the output size, then shrunk for clean edges).
const W := 256
const SIZE := 128
## Free margin around the shape for the outline and shadow, in working pixels.
const PAD := 22
const OUTLINE := 9.0
const SHADOW_DROP := 7
const INK := Color("3b2a2c")
const CREAM := Color("fff6e6")


func _init() -> void:
	var only := []
	var sheet := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
	var done := []
	for group in Manifest.ICONS:
		var dir: String = OUT + group + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var entries: Dictionary = Manifest.ICONS[group]
		for name in entries:
			if not only.is_empty() and not (name in only):
				continue
			var e: Array = entries[name]
			var img := bake(e[0], Color(e[1]), Color(e[2]) if e.size() > 2 and e[2] != "" else Color(0, 0, 0, 0),
				e[3] if e.size() > 3 else {})
			if img == null:
				printerr("icon %s/%s: missing source %s" % [group, name, e[0]])
				continue
			img.save_png(ProjectSettings.globalize_path(dir + name + ".png"))
			done.append([group + "/" + name, img])
	print("baked %d icons" % done.size())
	if sheet != "":
		_contact_sheet(done, sheet)
	quit()


## The source silhouette's coverage at W x W (fitted inside PAD), or null.
func _silhouette(src: String, opts: Dictionary) -> Image:
	var path := ProjectSettings.globalize_path(SRC + src + ".svg")
	if src.begins_with("gi/") and src.count("/") == 1:
		# game-icons sit in their author's folder
		var gi := ProjectSettings.globalize_path(SRC + "gi/")
		for author in DirAccess.get_directories_at(gi):
			if FileAccess.file_exists(gi.path_join(author).path_join(src.substr(3) + ".svg")):
				path = gi.path_join(author).path_join(src.substr(3) + ".svg")
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	# draw everything in white so the coverage is the alpha (the packs fill in black, white or green)
	if not opts.get("prompt", false):
		var re := RegEx.create_from_string("(fill|stroke)=\"(?!none)[^\"]*\"")
		text = re.sub(text, "$1=\"#ffffff\"", true)
	var probe := Image.new()
	probe.load_svg_from_string(text, 1.0)
	var big := Image.new()
	big.load_svg_from_string(text, 1024.0 / maxf(probe.get_width(), probe.get_height()))
	big.convert(Image.FORMAT_RGBA8)
	var used := big.get_used_rect()
	if used.size.x <= 0:
		return null
	big = big.get_region(used)
	if opts.get("flip", false):
		big.flip_x()
	var inner := float(W - 2 * PAD) * float(opts.get("scale", 1.0))
	var k := inner / maxf(big.get_width(), big.get_height())
	big.resize(maxi(1, roundi(big.get_width() * k)), maxi(1, roundi(big.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var img := Image.create(W, W, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# sit a little high so the shadow has room below
	img.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()),
		Vector2i((W - big.get_width()) / 2, (W - big.get_height()) / 2 - SHADOW_DROP / 2))
	return img


func bake(src: String, base: Color, detail: Color, opts: Dictionary) -> Image:
	var sil := _silhouette(src, opts)
	if sil == null:
		return null
	if opts.get("mono", false) or opts.get("prompt", false):
		# a plain white shape; for a Kenney prompt, its coloured part (the pressed arm, the letter) is cut away
		var white := Image.create(W, W, false, Image.FORMAT_RGBA8)
		for y in W:
			for x in W:
				var c := sil.get_pixel(x, y)
				var a := c.a
				if opts.get("prompt", false):
					a *= clampf((minf(c.r, minf(c.g, c.b)) - 0.25) / 0.7, 0.0, 1.0)
				white.set_pixel(x, y, Color(1, 1, 1, a))
		white.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		return white
	var n := W * W
	var cover := PackedFloat32Array()
	cover.resize(n)
	var solid := PackedByteArray()
	solid.resize(n)
	var y0 := W
	var y1 := 0
	for y in W:
		for x in W:
			var a := sil.get_pixel(x, y).a
			cover[y * W + x] = a
			if a >= 0.5:
				solid[y * W + x] = 1
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	# outside = clear pixels reachable from the border; enclosed clear pixels are inner detail
	var outside := PackedByteArray()
	outside.resize(n)
	var stack := PackedInt32Array()
	for i in W:
		for p in [i, (W - 1) * W + i, i * W, i * W + W - 1]:
			if solid[p] == 0 and outside[p] == 0:
				outside[p] = 1
				stack.append(p)
	while not stack.is_empty():
		var p: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var px := p % W
		var py := p / W
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var qx: int = px + d[0]
			var qy: int = py + d[1]
			if qx < 0 or qy < 0 or qx >= W or qy >= W:
				continue
			var q := qy * W + qx
			if solid[q] == 0 and outside[q] == 0:
				outside[q] = 1
				stack.append(q)
	var body := PackedByteArray()
	body.resize(n)
	for p in n:
		body[p] = 0 if outside[p] == 1 else 1
	var d_out := _distance(body) # distance outside the closed shape
	var inv := PackedByteArray()
	inv.resize(n)
	for p in n:
		inv[p] = 1 - solid[p]
	var d_in := _distance(inv) # inside the shape: distance to its nearest edge
	if detail.a == 0.0:
		detail = base.lerp(CREAM, 0.62)
	var rim := base.darkened(0.22)
	var line := base.darkened(0.6).lerp(INK, 0.55)
	var light := base.lerp(Color.WHITE, 0.22)
	var shade := base.darkened(0.12)
	var h := maxf(1.0, y1 - y0)
	var out := Image.create(W, W, false, Image.FORMAT_RGBA8)
	for y in W:
		var t := clampf((y - y0) / h, 0.0, 1.0)
		var fill := light.lerp(shade, t)
		for x in W:
			var p := y * W + x
			# shadow, then the outline ring, then the inner detail, then the shape itself
			var sy := y - SHADOW_DROP
			var c := Color(0, 0, 0, 0)
			if sy >= 0:
				var sd := d_out[sy * W + x]
				var sa := clampf((OUTLINE + 4.0 - sd) / 8.0, 0.0, 1.0) * 0.28
				c = Color(INK.r, INK.g, INK.b, sa)
			var od := d_out[p]
			var oa := clampf(OUTLINE + 0.5 - od, 0.0, 1.0)
			if oa > 0.0:
				c = _over(c, Color(line.r, line.g, line.b, oa))
			if body[p] == 1 and solid[p] == 0:
				c = _over(c, detail)
			var a := cover[p]
			if a > 0.0:
				# a darker rim just inside the edge, like a painted bevel
				var e := clampf(1.0 - (d_in[p] - 1.0) / 5.0, 0.0, 1.0) if solid[p] == 1 else 1.0
				var col := fill.lerp(rim, e * 0.75)
				c = _over(c, Color(col.r, col.g, col.b, a))
			out.set_pixel(x, y, c)
	out.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return out


static func _over(under: Color, top: Color) -> Color:
	var a := top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var r := (top.r * top.a + under.r * under.a * (1.0 - top.a)) / a
	var g := (top.g * top.a + under.g * under.a * (1.0 - top.a)) / a
	var b := (top.b * top.a + under.b * under.a * (1.0 - top.a)) / a
	return Color(r, g, b, a)


## Euclidean distance (two-pass nearest-seed propagation) from each pixel to the nearest pixel where mask is 1.
static func _distance(mask: PackedByteArray) -> PackedFloat32Array:
	var n := W * W
	var sx := PackedInt32Array()
	var sy := PackedInt32Array()
	sx.resize(n)
	sy.resize(n)
	var far := 1 << 20
	for p in n:
		if mask[p] == 1:
			sx[p] = p % W
			sy[p] = p / W
		else:
			sx[p] = far
			sy[p] = far
	var fwd := [[-1, -1], [0, -1], [1, -1], [-1, 0]]
	var bwd := [[1, 0], [-1, 1], [0, 1], [1, 1]]
	for pass_i in 2:
		var ys := range(W) if pass_i == 0 else range(W - 1, -1, -1)
		var xs := range(W) if pass_i == 0 else range(W - 1, -1, -1)
		var nb: Array = fwd if pass_i == 0 else bwd
		for y in ys:
			for x in xs:
				var p: int = y * W + x
				var bx := sx[p]
				var by := sy[p]
				var best: int = (bx - x) * (bx - x) + (by - y) * (by - y) if bx != far else 1 << 30
				for d in nb:
					var qx: int = x + d[0]
					var qy: int = y + d[1]
					if qx < 0 or qy < 0 or qx >= W or qy >= W:
						continue
					var q := qy * W + qx
					var cx := sx[q]
					if cx == far:
						continue
					var cy := sy[q]
					var dd: int = (cx - x) * (cx - x) + (cy - y) * (cy - y)
					if dd < best:
						best = dd
						bx = cx
						by = cy
				sx[p] = bx
				sy[p] = by
	var out := PackedFloat32Array()
	out.resize(n)
	for p in n:
		var x := p % W
		var y := p / W
		out[p] = sqrt(float((sx[p] - x) * (sx[p] - x) + (sy[p] - y) * (sy[p] - y))) if sx[p] != far else 9999.0
	return out


## A review sheet of every baked icon on the windows' off-white, at 64 and 32 px.
func _contact_sheet(done: Array, path: String) -> void:
	var cols := 10
	var cell := 112
	var rows := ceili(done.size() / float(cols))
	var img := Image.create(cols * cell, maxi(1, rows) * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color("f4efe8"))
	for i in done.size():
		var ic: Image = done[i][1].duplicate()
		var big: Image = ic.duplicate()
		big.resize(72, 72, Image.INTERPOLATE_LANCZOS)
		var small: Image = ic.duplicate()
		small.resize(32, 32, Image.INTERPOLATE_LANCZOS)
		var ox := (i % cols) * cell
		var oy := (i / cols) * cell
		img.blend_rect(big, Rect2i(0, 0, 72, 72), Vector2i(ox + 4, oy + 8))
		img.blend_rect(small, Rect2i(0, 0, 32, 32), Vector2i(ox + 76, oy + 48))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	img.save_png(ProjectSettings.globalize_path(path))
	print("sheet: ", path)
