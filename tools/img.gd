extends SceneTree
## Measures screenshots so they needn't be looked at: answers in a line or two of numbers.
##   godot --headless --path . --script res://tools/img.gd -- <command> <file> [file2] [--option=value ...]
##
##   diff A B             how much of B differs from A: the share of pixels changed, and where (the box round
##                        them); --tol=24 (how far a colour may drift, 0-255 per channel, before it counts)
##   bbox IMG             the box round the pixels that differ from the background (--bg=#rrggbb, or the colour at
##                        the top-left corner), or that match --like=#rrggbb; their count; --tol=24
##   color IMG x y        the average colour round a point (--r=2 pixels each way)
##   crop IMG OUT         a copy of part of it (--region), shrunk to --w pixels wide at most
##   size IMG             its width and height
## Every command takes --region=x0,y0,x1,y1 to look at just part of the image: fractions of it (0-1), or pixels if
## any is over 1. Boxes are printed in pixels and as fractions of the image. Points (color) are pixels, or fractions
## if both are 1 or less.

var args := {}
var pos := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
		else:
			pos.append(a)
	if pos.is_empty():
		print("usage: diff A B | bbox IMG | color IMG x y | crop IMG OUT | size IMG  [--region=x0,y0,x1,y1] [--tol=24]")
		quit(2)
		return
	var cmd: String = pos[0]
	match cmd:
		"diff":
			_diff(_load(pos[1]), _load(pos[2]))
		"bbox":
			_bbox(_load(pos[1]))
		"color":
			_color(_load(pos[1]), float(pos[2]), float(pos[3]))
		"crop":
			_crop(_load(pos[1]), String(pos[2]))
		"size":
			var img := _load(pos[1])
			print("%dx%d" % [img.get_width(), img.get_height()])
		_:
			print("unknown command ", cmd)
			quit(2)
			return
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		print("can't read ", path)
		quit(2)
		return Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.convert(Image.FORMAT_RGBA8)
	return img


## The part of an image --region names (all of it without one).
func _region(img: Image) -> Rect2i:
	var full := Rect2i(0, 0, img.get_width(), img.get_height())
	if not args.has("region"):
		return full
	var c: Array = Array(String(args["region"]).split(",")).map(func(x): return float(x))
	if c.size() != 4:
		return full
	var px: bool = c.any(func(x): return x > 1.0)
	var sz := Vector2(img.get_width(), img.get_height())
	var a := Vector2(c[0], c[1]) if px else Vector2(c[0], c[1]) * sz
	var b := Vector2(c[2], c[3]) if px else Vector2(c[2], c[3]) * sz
	return Rect2i(Vector2i(a), Vector2i(b - a)).intersection(full)


func _tol() -> float:
	return float(args.get("tol", "24")) / 255.0


func _near(a: Color, b: Color, tol: float) -> bool:
	return absf(a.r - b.r) <= tol and absf(a.g - b.g) <= tol and absf(a.b - b.b) <= tol


func _box_text(box: Rect2i, img: Image) -> String:
	var w := float(img.get_width())
	var h := float(img.get_height())
	return "x %d..%d y %d..%d (%dx%d px; %.2f,%.2f to %.2f,%.2f)" % [box.position.x, box.end.x - 1, box.position.y,
		box.end.y - 1, box.size.x, box.size.y, box.position.x / w, box.position.y / h, box.end.x / w, box.end.y / h]


func _diff(a: Image, b: Image) -> void:
	if a.get_size() != b.get_size():
		b.resize(a.get_width(), a.get_height(), Image.INTERPOLATE_BILINEAR)
	var r := _region(a)
	var tol := _tol()
	var n := 0
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _near(a.get_pixel(x, y), b.get_pixel(x, y), tol):
				n += 1
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var total := r.size.x * r.size.y
	if n == 0:
		print("same (0 of %d pixels differ)" % total)
	else:
		print("%.2f%% differ (%d of %d pixels), in %s" % [100.0 * n / total, n, total, _box_text(Rect2i(lo, hi - lo + Vector2i.ONE), a)])


func _bbox(img: Image) -> void:
	var r := _region(img)
	var tol := _tol()
	var like: bool = args.has("like")
	var ref := Color(String(args["like"])) if like else (Color(String(args["bg"])) if args.has("bg") else img.get_pixel(r.position.x, r.position.y))
	var n := 0
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _near(img.get_pixel(x, y), ref, tol) == like:
				n += 1
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	if n == 0:
		print("none (%s %s)" % ["no pixels like" if like else "nothing but", ref.to_html(false)])
	else:
		print("%d pixels %s %s, in %s" % [n, "like" if like else "unlike", ref.to_html(false), _box_text(Rect2i(lo, hi - lo + Vector2i.ONE), img)])


func _color(img: Image, x: float, y: float) -> void:
	if x <= 1.0 and y <= 1.0:
		x *= img.get_width()
		y *= img.get_height()
	var rad := int(args.get("r", "2"))
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var px := clampi(int(x) + dx, 0, img.get_width() - 1)
			var py := clampi(int(y) + dy, 0, img.get_height() - 1)
			sum += img.get_pixel(px, py)
			n += 1
	var c := sum / float(n)
	print("#%s at %d,%d (r %d)" % [c.to_html(false), int(x), int(y), rad])


func _crop(img: Image, out: String) -> void:
	var r := _region(img)
	var part := img.get_region(r)
	var w := int(args.get("w", "0"))
	if w > 0 and part.get_width() > w:
		part.resize(w, maxi(1, roundi(part.get_height() * float(w) / part.get_width())), Image.INTERPOLATE_BILINEAR)
	part.save_png(out)
	print("saved %s (%dx%d)" % [out, part.get_width(), part.get_height()])
