extends RefCounted
## Surface textures for buildings, terrain, water and lava.
## Most are textures from assets/textures/surfaces (built by tools/build_psx_textures.gd from the packs credited in
## CREDITS.md, then cleaned up by tools/smooth_textures.gd), sampled smoothly. They are nearly grey, so buildings tint them per style with vertex colours and the ground
## is coloured per biome. Kinds without a texture of their own (brass, iron...) take one of the soft finishes (tools/build_soft_textures.py).

const PSX_DIR := "res://assets/textures/surfaces/"
## The ground layers of the terrain shader, in texture-array order.
const GROUND_LAYERS := ["grass", "path", "plaza", "sand", "rock", "bed", "lava_bed", "paving", "ice", "grass_dark"]
## The layers that are grass: a pillow of turf above the ground (terrain_mesh.gd LIFT), darker in "grass_dark" (the
## tall grass, and round the trees and hedges).
const GRASS_LAYERS := ["grass", "grass_dark"]
## Which PSX texture each ground layer uses.
const GROUND_SOURCE := {"grass": "ground_grass", "path": "ground_path", "plaza": "ground_plaza", "sand": "ground_sand",
	"rock": "ground_rock", "bed": "ground_bed", "lava_bed": "ground_rock", "paving": "ground_paving", "ice": "ground_ice",
	"grass_dark": "ground_grass"}
## The ground layers' size (tools/smooth_textures.gd leaves them smoothed at twice the packs' 128).
const GROUND_SIZE := 256
const WATER_FRAMES := 10
const LAVA_FRAMES := 3
## The legacy terrain kinds (one texture per tile) and the PSX texture behind each.
const TERRAIN_SOURCE := {"top_grass": "ground_grass", "top_path": "ground_path", "top_plaza": "ground_plaza",
	"top_sand": "ground_sand", "top_rock": "ground_rock", "side_soil": "ground_path", "side_rock": "ground_rock",
	"water": "water_0", "lava": "lava_0", "snow": "ground_ice"}

const SurfaceFinish = preload("res://scripts/gfx/surface_finish.gd")

static var _cache := {}
static var _mats := {}
static var _images := {}
## One material of each kind drawn so far (see keep_shaders).
static var _kept_kinds := {}


## Compatibility, the web build's renderer, compiles a kind of material the first time something draws with it, a stall
## of seconds, and forgets the result along with the last material of that kind. Holding on to one of each means a kind
## only ever compiles once. The hold is bounded by how many kinds the game has, and keeps those few materials' textures
## loaded, so the other renderers, which cache their pipelines and gain nothing from this, skip it.
static func keep_shaders(root: Node, extra: Array = []) -> void:
	if RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]:
		return
	var seen := {}
	for material: Material in extra:
		_keep_kind(material, seen)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		_keep_kind(node.material_override, seen)
		_keep_kind(node.material_overlay, seen)
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			_keep_kind(mesh.surface_get_material(surface), seen)
			if node is MeshInstance3D:
				_keep_kind(node.get_surface_override_material(surface), seen)


static func _keep_kind(material: Material, seen: Dictionary) -> void:
	if material == null or seen.has(material):
		return
	seen[material] = true
	if material is BaseMaterial3D:
		var kind := _kind_of(material)
		if not _kept_kinds.has(kind):
			_kept_kinds[kind] = material


## Everything about a material that decides which shader it compiles to.
static func _kind_of(m: BaseMaterial3D) -> String:
	var flags := 0
	for i in BaseMaterial3D.FLAG_MAX:
		flags |= int(m.get_flag(i)) << i
	var features := 0
	for i in BaseMaterial3D.FEATURE_MAX:
		features |= int(m.get_feature(i)) << i
	var textures := 0
	for i in BaseMaterial3D.TEXTURE_MAX:
		textures |= int(m.get_texture(i) != null) << i
	return str([m.get_class(), m.transparency, m.alpha_antialiasing_mode, m.blend_mode, m.cull_mode, m.depth_draw_mode,
		m.shading_mode, m.diffuse_mode, m.specular_mode, m.texture_filter, m.billboard_mode, m.distance_fade_mode,
		m.proximity_fade_enabled, m.grow, m.detail_uv_layer, m.detail_blend_mode, m.emission_operator,
		m.heightmap_deep_parallax, flags, features, textures])


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
		if img.get_size() != Vector2i(GROUND_SIZE, GROUND_SIZE):
			img.resize(GROUND_SIZE, GROUND_SIZE, Image.INTERPOLATE_CUBIC)
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


## Surface kinds without a painted texture of their own, and the soft finish each takes (default "soft").
const SOFT_KINDS := {"brass": "brushed", "iron": "brushed", "slot": "brushed", "drape": "fabric", "banner": "fabric"}


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
	# Anything else is one of the soft finishes (tools/build_soft_textures.py), never a small pixel drawing.
	var finish: String = SOFT_KINDS.get(kind, "soft")
	var soft := psx_image(finish)
	if soft == null:
		soft = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		soft.fill(Color.WHITE)
	_cache[kind] = _mipmapped(soft)
	return _cache[kind]


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
		if tile.get_width() > 128:
			tile.resize(128, 128, Image.INTERPOLATE_LANCZOS)
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


## The one wood colour the wooden props share (signposts, stalls, benches, fences): with the kit's own plank grain
## ("planks" / "planks_v") it reads as the same timber as the stairs, decks and signs beside it.
const WOOD := Color("#8a6038")


## That shared wood for meshes whose own UVs don't follow the kit's (fences, the Cove kit's timber, the house pack's
## wooden trim and decks, dock planks): the plank grain in WOOD, `lighten` lighter for decks and slats, mapped in world
## space at the kit's density so boards are the same size on everything, with no vertex colours.
static func wood_material(grain := "planks_v", lighten := 0.0) -> StandardMaterial3D:
	var key := "wood:%s:%s" % [grain, lighten]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.roughness = 0.95
		_mats[key] = apply_wood(m, grain, lighten)
	return _mats[key]


## Turns `m` (a duplicate of a pack material, keeping its culling and other settings) into the shared wood.
static func apply_wood(m: StandardMaterial3D, grain := "planks_v", lighten := 0.0) -> StandardMaterial3D:
	m.albedo_texture = texture(grain)
	m.albedo_color = WOOD.lightened(lighten)
	m.vertex_color_use_as_albedo = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / PSX_SPAN
	m.uv1_offset = Vector3.ZERO
	return m


## The street pack's crates, barrels and kegs (assets/exteriors) share one atlas whose wood is a cooler grey-brown
## (about 109, 91, 77): this tint brings it to the shared WOOD's warm brown, their iron hoops darkening a little with it.
const PACK_WOOD_TINT := Color(1.0, 0.86, 0.6)


## Tints a pack model's wood to the shared wood, once per loaded mesh (its materials are its own).
static func match_wood(mesh: Mesh) -> Mesh:
	if mesh == null or mesh.has_meta("shared_wood"):
		return mesh
	for si in mesh.get_surface_count():
		var m := mesh.surface_get_material(si) as BaseMaterial3D
		if m != null:
			m.albedo_color = PACK_WOOD_TINT
	mesh.set_meta("shared_wood", true)
	return mesh


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
	# "pat_<name>": a seamless pattern from assets/textures/patterns (books, quilts, planks...)
	m.albedo_texture = load(PATTERN_DIR + kind.substr(4) + ".png") if kind.begins_with("pat_") else texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	# painted colour on the soft finish (the kit's UVs are in world units)
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture("soft")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(1.0 / PSX_SPAN, 1.0 / PSX_SPAN, 1.0)
	var k := 1.0 / SurfaceFinish.mean("soft")
	m.albedo_color = Color(k, k, k)
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
