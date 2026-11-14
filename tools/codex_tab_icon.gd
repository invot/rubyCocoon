extends SceneTree
## Draws the Start book's Codex tab icon (assets/ui/icons/tabs/tab_codex.png): a white silhouette of the Codex's
## robot head (a dome, a band, two round eyes and two brows cut out), antialiased, 128 x 128 like the other tab icons.
##   godot --headless --path . --script res://tools/codex_tab_icon.gd
##   godot --headless --path . --import

const OUT := "res://assets/ui/icons/tabs/tab_codex.png"
const N := 128
const SS := 4


func _init() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var a := 0.0
			for sy in SS:
				for sx in SS:
					a += _cover(Vector2(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS))
			img.set_pixel(x, y, Color(1, 1, 1, a / float(SS * SS)))
	img.save_png(OUT)
	print("wrote ", OUT)
	quit()


## 1 inside the white shape, 0 outside (or in a cut-out).
func _cover(p: Vector2) -> float:
	# the head: a dome on a rounded box
	var inside := _round_box(p, Rect2(16, 46, 96, 58), 16.0) or (p.distance_to(Vector2(64, 60)) < 48.0 and p.y < 70.0)
	if not inside:
		return 0.0
	# the eyes, and a white pupil-less ring left round them
	for c in [Vector2(44, 72), Vector2(84, 72)]:
		if p.distance_to(c) < 13.0:
			return 0.0
	# the brows, tilted up at their outer ends
	if _brow(p, Vector2(32, 50), Vector2(54, 54)) or _brow(p, Vector2(74, 54), Vector2(96, 50)):
		return 0.0
	# the band under the eyes
	if p.y > 92.0 and p.y < 96.0:
		return 0.0
	return 1.0


func _round_box(p: Vector2, r: Rect2, rad: float) -> bool:
	var q := Vector2(clampf(p.x, r.position.x + rad, r.end.x - rad), clampf(p.y, r.position.y + rad, r.end.y - rad))
	return p.distance_to(q) <= rad


func _brow(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t)) < 3.5
