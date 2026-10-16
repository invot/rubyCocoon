extends RefCounted
## Surface textures for buildings, terrain, water and lava.
## Most are small PSX-style textures from assets/psx/textures (built by tools/build_psx_textures.gd from the packs
## credited in CREDITS.md). They are nearly grey, so buildings tint them per style with vertex colours and the ground
## is coloured per biome. Kinds without a PSX texture (brass, timber framing) are drawn here at 16x16.

const PSX_DIR := "res://assets/psx/textures/"
## The ground layers of the terrain shader, in texture-array order.
const GROUND_LAYERS := ["grass", "path", "plaza", "sand", "rock", "bed", "lava_bed", "paving", "ice"]
## Which PSX texture each ground layer uses.
const GROUND_SOURCE := {"grass": "ground_grass", "path": "ground_path", "plaza": "ground_plaza", "sand": "ground_sand",
	"rock": "ground_rock", "bed": "ground_bed", "lava_bed": "ground_rock", "paving": "ground_paving", "ice": "ground_ice"}
const WATER_FRAMES := 10
const LAVA_FRAMES := 3
## The legacy terrain kinds (one texture per tile) and the PSX texture behind each.
const TERRAIN_SOURCE := {"top_grass": "ground_grass", "top_path": "ground_path", "top_plaza": "ground_plaza",
	"top_sand": "ground_sand", "top_rock": "ground_rock", "side_soil": "ground_path", "side_rock": "ground_rock",
	"water": "water_0", "lava": "lava_0", "snow": "ground_ice"}

static var _cache := {}
static var _mats := {}
static var _images := {}


## A PSX texture's image (uncompressed, no mipmaps), or null if there is none for `name`.
static func psx_image(name: String) -> Image:
	if _images.has(name):
		return _images[name]
	var path := PSX_DIR + name + ".png"
	var img: Image = null
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		img = t.get_image()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
	_images[name] = img
	return img


static func _mipmapped(img: Image) -> ImageTexture:
	var im: Image = img.duplicate()
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


## `img` multiplied by `col`, scaled so the texture's average comes out as `col` (the textures average about 0.86).
static func _tinted(img: Image, col: Color, level := 0.86) -> Image:
	var out: Image = img.duplicate()
	var k := Vector3(col.r, col.g, col.b) / level
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(minf(1.0, c.r * k.x), minf(1.0, c.g * k.y), minf(1.0, c.b * k.z), c.a))
	return out


## The terrain shader's ground layers as one texture array (grey detail; the shader colours each per biome).
static func ground_layers() -> Texture2DArray:
	if _cache.has("ground_layers"):
		return _cache["ground_layers"]
	var imgs: Array[Image] = []
	for layer in GROUND_LAYERS:
		var img := psx_image(GROUND_SOURCE[layer])
		if img == null:
			img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.86, 0.86, 0.86))
		img = img.duplicate()
		img.resize(128, 128, Image.INTERPOLATE_NEAREST)
		img.generate_mipmaps()
		imgs.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	_cache["ground_layers"] = arr
	return arr


## The animation frames of the water (or lava) surface as a texture array.
static func frames(kind: String) -> Texture2DArray:
	var key := "frames:" + kind
	if _cache.has(key):
		return _cache[key]
	var imgs: Array[Image] = []
	for i in (WATER_FRAMES if kind == "water" else LAVA_FRAMES):
		var img := psx_image("%s_%d" % [kind, i])
		if img == null:
			break
		img = img.duplicate()
		img.generate_mipmaps()
		imgs.append(img)
	if imgs.is_empty():
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.8, 0.8))
		img.generate_mipmaps()
		imgs.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	_cache[key] = arr
	return arr


static func _img() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return img


static func _shade(img: Image, x: int, y: int, v: float) -> void:
	img.set_pixel(posmod(x, 16), posmod(y, 16), Color(v, v, v))


static func texture(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var psx := psx_image(kind)
	if psx != null:
		_cache[kind] = _mipmapped(psx)
		return _cache[kind]
	if kind == "timber":
		var plaster := psx_image("plaster")
		if plaster != null:
			# half-timbering: dark beams round the edge and two braces, over the plaster
			var tim: Image = plaster.duplicate()
			var s := tim.get_width()
			var beam := Color(0.42, 0.3, 0.2)
			var bw := s / 10
			for y in s:
				for x in s:
					var d1 := absi(x - y)
					var d2 := absi(x - (s - 1 - y))
					if x < bw or y < bw or d1 < bw / 2 + 1 or d2 < bw / 2 + 1:
						tim.set_pixel(x, y, beam.darkened(0.1 * float((x * 3 + y) % 3)))
			_cache[kind] = _mipmapped(tim)
			return _cache[kind]
	var img := _img()
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for y in 16:
		for x in 16:
			_shade(img, x, y, rng.randf_range(0.9, 1.0))
	match kind:
		"plaster":
			for i in 10:
				_shade(img, rng.randi_range(0, 15), rng.randi_range(0, 15), 0.84)
		"adobe":
			for i in 14:
				_shade(img, rng.randi_range(0, 15), rng.randi_range(0, 15), rng.randf_range(0.78, 0.86))
			for x in 16:
				_shade(img, x, 7, 0.88)
		"planks_v", "bamboo":
			for y in 16:
				for x in 16:
					if x % 4 == 0:
						_shade(img, x, y, 0.68)
					elif kind == "bamboo" and y % 8 == 3:
						_shade(img, x, y, 0.76)
			for i in 6:
				_shade(img, rng.randi_range(0, 15), rng.randi_range(0, 15), 0.8)
		"planks", "wood_dark":
			for y in 16:
				for x in 16:
					if y % 4 == 0:
						_shade(img, x, y, 0.66)
					elif (x + (y / 4) * 7) % 16 == 0:
						_shade(img, x, y, 0.72)
		"brick", "stone", "stone_dark":
			var bh := 4 if kind == "brick" else 8
			for y in 16:
				for x in 16:
					var row := y / bh
					var off := (bh if kind == "brick" else 4) * (row % 2)
					if y % bh == 0 or (x + off) % 8 == 0:
						_shade(img, x, y, 0.62)
					elif y % bh == 1:
						_shade(img, x, y, 1.0)
		"slate", "shingle", "tile":
			for y in 16:
				for x in 16:
					if y % 4 == 3:
						_shade(img, x, y, 0.6)
					elif (x + (y / 4) * 3) % 5 == 0:
						_shade(img, x, y, 0.78)
		"thatch", "leaf":
			for y in 16:
				for x in 16:
					var v := 0.75 + 0.25 * float((x * 7 + y * 3) % 5) / 4.0
					if y % 5 == 4:
						v = 0.62
					_shade(img, x, y, v)
		"tin":
			for y in 16:
				for x in 16:
					_shade(img, x, y, 0.95 if x % 3 == 0 else 0.8)
		"brass":
			for y in 16:
				for x in 16:
					if x % 8 == 0 or y % 8 == 0:
						_shade(img, x, y, 0.7)
					elif (x + y) % 8 == 2:
						_shade(img, x, y, 1.0)
			for p in [Vector2i(2, 2), Vector2i(10, 2), Vector2i(2, 10), Vector2i(10, 10)]:
				_shade(img, p.x, p.y, 0.55)
		"timber":
			for y in 16:
				for x in 16:
					if x < 2 or y < 2 or x == y or x == 15 - y:
						img.set_pixel(x, y, Color(0.45, 0.32, 0.22))
		"cobble":
			for i in 10:
				var cx := rng.randi_range(0, 15)
				var cy := rng.randi_range(0, 15)
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					_shade(img, cx + d.x, cy + d.y, 0.72)
	var t := ImageTexture.create_from_image(img)
	_cache[kind] = t
	return t


## Coloured 16x16 terrain textures. kind: top_grass, top_path, top_plaza, top_sand, top_rock,
## side_soil (with a lip of `lip_hex` on top), side_rock, water, lava, snow.
static func terrain(kind: String, base_hex: String, lip_hex := "") -> ImageTexture:
	var key := "terrain:%s:%s:%s" % [kind, base_hex, lip_hex]
	if _cache.has(key):
		return _cache[key]
	var base := Color(base_hex)
	var psx := psx_image(TERRAIN_SOURCE.get(kind, ""))
	if psx != null:
		# one tile's worth: the PSX ground textures span two tiles, so they're halved for per-tile use
		var tile: Image = psx.duplicate()
		if tile.get_width() > 64:
			tile.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		if kind != "lava":
			tile = _tinted(tile, base)
		if lip_hex != "":
			var lip := Color(lip_hex)
			for x in tile.get_width():
				for y in 6 + (x * 7) % 3:
					tile.set_pixel(x, y, lip.darkened(0.03 * y))
		var pt := _mipmapped(tile)
		_cache[key] = pt
		return pt
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for y in 16:
		for x in 16:
			var v := rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, base.lightened(v) if v > 0 else base.darkened(-v))
	match kind:
		"top_grass":
			for i in 22:
				var x := rng.randi_range(0, 15)
				var y := rng.randi_range(0, 15)
				img.set_pixel(x, y, base.darkened(0.16) if i % 3 else base.lightened(0.14))
		"top_path":
			for i in 9:
				var x := rng.randi_range(0, 14)
				var y := rng.randi_range(0, 14)
				img.set_pixel(x, y, base.darkened(0.22))
				img.set_pixel(x + 1, y, base.darkened(0.12))
				img.set_pixel(x, y + 1, base.lightened(0.1))
		"top_plaza":
			for y in 16:
				for x in 16:
					var row := y / 4
					var off := 2 * (row % 2)
					if y % 4 == 0 or (x + off) % 4 == 0:
						img.set_pixel(x, y, base.darkened(0.25))
					elif (x + y) % 7 == 0:
						img.set_pixel(x, y, base.lightened(0.08))
		"top_sand":
			for y in range(1, 16, 4):
				for x in 16:
					if (x + y) % 5 < 3:
						img.set_pixel(x, y, base.darkened(0.08))
		"top_rock":
			for i in 4:
				var x := rng.randi_range(1, 12)
				var y := rng.randi_range(1, 12)
				for k in 4:
					img.set_pixel(clampi(x + k, 0, 15), clampi(y + (k % 2), 0, 15), base.darkened(0.3))
		"side_soil", "side_rock":
			for i in 8:
				var x := rng.randi_range(0, 14)
				var y := rng.randi_range(3, 14)
				img.set_pixel(x, y, base.darkened(0.25))
				img.set_pixel(x + 1, y, base.darkened(0.15))
			if kind == "side_rock":
				for x in 16:
					img.set_pixel(x, 7, base.darkened(0.2))
			if lip_hex != "":
				var lip := Color(lip_hex)
				for x in 16:
					var depth := 2 + (1 if rng.randf() < 0.4 else 0)
					for y in depth:
						img.set_pixel(x, y, lip.darkened(0.05 * y))
		"water":
			for i in 6:
				var x := rng.randi_range(0, 12)
				var y := rng.randi_range(0, 15)
				for k in 3:
					img.set_pixel(x + k, y, base.lightened(0.28))
		"lava":
			for i in 10:
				img.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color("#ffe060"))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


const PATTERN_DIR := "res://assets/textures/patterns/"


## World units one PSX building texture spans (its bricks, planks or shingles read at the game's resolution).
const PSX_SPAN := 2.0


## A material showing `kind`, tinted by vertex colours, mapped in object space (triplanar).
static func material(kind: String, scale := 1.0) -> StandardMaterial3D:
	var key := "%s:%s" % [kind, scale]
	if _mats.has(key):
		return _mats[key]
	var m := _base_material(kind)
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE * scale * (1.0 / PSX_SPAN if psx_image(kind) != null or kind == "timber" else 1.0)
	_mats[key] = m
	return m


## The same look for meshes that carry their own UVs in world units (buildings from VBld.Kit, sloped roofs).
static func kit_material(kind: String) -> StandardMaterial3D:
	var key := "kit:" + kind
	if _mats.has(key):
		return _mats[key]
	var m := _base_material(kind)
	var span := PSX_SPAN if psx_image(kind) != null or kind == "timber" else 1.0
	m.uv1_scale = Vector3(1.0 / span, 1.0 / span, 1.0)
	_mats[key] = m
	return m


static func _base_material(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# "pat_<name>": a seamless pixel pattern from assets/textures/patterns (books, quilts, planks...)
	m.albedo_texture = load(PATTERN_DIR + kind.substr(4) + ".png") if kind.begins_with("pat_") else texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if not kind.begins_with("pat_") else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	if kind in ["brass", "tin"]:
		m.metallic = 0.5
		m.roughness = 0.45
	return m


static func color_material() -> StandardMaterial3D:
	if _mats.has("color"):
		return _mats["color"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	_mats["color"] = m
	return m


static func glow_material() -> StandardMaterial3D:
	if _mats.has("glow"):
		return _mats["glow"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats["glow"] = m
	return m
