extends RefCounted
## Cleans the small, noisy pack textures up for the game's smooth, PS2-era look (README Art; AGENTS.md "Art and
## animation consistency"): speckle and grain are smoothed away while the shapes that read from the camera (brick
## courses, plank seams, shingles, leaves) keep their edges, then the texture is enlarged with a soft filter so it
## stays clean when sampled with linear filtering up close. tools/smooth_textures.gd runs it over the baked assets.

## Enlarged textures end up at least this many pixels on their longer side, and no more than MAX_SIZE.
const MIN_SIZE := 128
const MAX_SIZE := 256
## How far (in source pixels) the edge-preserving smoothing reaches, and how different two colours may be before it
## treats them as an edge (0..1, in luminance).
const RADIUS := 2
const EDGE := 0.075
## Smoothing passes: each one flattens the grain inside a shape a little more without moving its edges.
const PASSES := 3
## How much the texture's contrast is eased towards its average colour (harsh black cracks become soft shading).
const CALM := 0.22


## A smoothed, enlarged copy of `src` (with mipmaps). Textures repeat, so the smoothing wraps round the edges.
static func soften(src: Image) -> Image:
	var img: Image = src.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var px := _floats(img)
	_fill_clear(px, w, h)
	for _pass in PASSES:
		px = _bilateral(px, w, h, RADIUS, EDGE)
	var mean := Vector3.ZERO
	var opaque := 0.0
	for i in w * h:
		mean += Vector3(px[i * 4], px[i * 4 + 1], px[i * 4 + 2]) * px[i * 4 + 3]
		opaque += px[i * 4 + 3]
	mean /= maxf(opaque, 1.0)
	for i in w * h:
		for c in 3:
			px[i * 4 + c] = lerpf(px[i * 4 + c], mean[c], CALM)
	img = _image(px, w, h)
	var f := 1
	while maxi(w, h) * f < MIN_SIZE or (maxi(w, h) * f * 2 <= MAX_SIZE and f < 2):
		f *= 2
	if f > 1:
		img.resize(w * f, h * f, Image.INTERPOLATE_CUBIC)
		# cubic leaves a faint ring and stair-steps round hard edges; a small edge-keeping pass at the new size
		# rounds them off
		img = _image(_bilateral(_floats(img), w * f, h * f, 1, EDGE * 1.5), w * f, h * f)
	img.generate_mipmaps()
	return img


static func _floats(img: Image) -> PackedFloat32Array:
	var data := img.get_data()
	var out := PackedFloat32Array()
	out.resize(data.size())
	for i in data.size():
		out[i] = data[i] / 255.0
	return out


static func _image(px: PackedFloat32Array, w: int, h: int) -> Image:
	var data := PackedByteArray()
	data.resize(px.size())
	for i in px.size():
		data[i] = clampi(roundi(px[i] * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


## See-through pixels take the colour of the solid ones round them, so linear filtering doesn't draw dark (or white)
## fringes round leaves and cut-outs.
static func _fill_clear(px: PackedFloat32Array, w: int, h: int) -> void:
	var solid := PackedByteArray()
	solid.resize(w * h)
	var any_clear := false
	for i in w * h:
		solid[i] = 1 if px[i * 4 + 3] > 0.5 else 0
		any_clear = any_clear or solid[i] == 0
	if not any_clear:
		return
	for _pass in 8:
		var grown := solid.duplicate()
		for y in h:
			for x in w:
				var i := y * w + x
				if solid[i] == 1:
					continue
				var sum := Vector3.ZERO
				var n := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var j := posmod(y + d.y, h) * w + posmod(x + d.x, w)
					if solid[j] == 1:
						sum += Vector3(px[j * 4], px[j * 4 + 1], px[j * 4 + 2])
						n += 1
				if n > 0:
					sum /= n
					px[i * 4] = sum.x
					px[i * 4 + 1] = sum.y
					px[i * 4 + 2] = sum.z
					grown[i] = 1
		solid = grown


## Edge-preserving smoothing: each pixel averages its neighbours, weighted down the further they are and the more
## their brightness differs, so grain melts away but the lines between bricks or boards stay put. Alpha is untouched.
static func _bilateral(px: PackedFloat32Array, w: int, h: int, r: int, edge: float) -> PackedFloat32Array:
	var out := px.duplicate()
	var space := {}
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			space[Vector2i(dx, dy)] = exp(-float(dx * dx + dy * dy) / (2.0 * 1.4 * 1.4))
	var inv := 1.0 / (2.0 * edge * edge)
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var l0 := px[i] * 0.3 + px[i + 1] * 0.59 + px[i + 2] * 0.11
			var sum := Vector3.ZERO
			var wsum := 0.0
			for d in space:
				var j := (posmod(y + d.y, h) * w + posmod(x + d.x, w)) * 4
				var l := px[j] * 0.3 + px[j + 1] * 0.59 + px[j + 2] * 0.11
				var k: float = space[d] * exp(-(l - l0) * (l - l0) * inv) * (0.05 + px[j + 3])
				sum += Vector3(px[j], px[j + 1], px[j + 2]) * k
				wsum += k
			if wsum > 0.0:
				out[i] = sum.x / wsum
				out[i + 1] = sum.y / wsum
				out[i + 2] = sum.z / wsum
	return out

