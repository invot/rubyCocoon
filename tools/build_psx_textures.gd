extends SceneTree
## Builds the PSX surface textures in assets/psx/textures/ from the downloaded packs in psx/ (see CREDITS.md).
##   godot --headless --path . --script res://tools/build_psx_textures.gd
##
## Every texture is shrunk to a small size and, for "tint" ones, turned nearly grey with an even brightness, so the
## game can colour it per town or biome (vertex colours on buildings, biome colours on the ground) the way the voxel
## textures were coloured. "color" textures keep their own colours. Water and lava keep a few animation frames.

const OUT := "res://assets/psx/textures/"
const CD := "Environments/3D Retro Medieval-Fantasy Building Kit (chilly_durango)/Textures/"
const RG := "Textures/RetroGround Free - [48 Retro Materials] (Binbun)/"
const SBS := "Textures/Mini Texture Pack 2- Rooftops (Screaming Brain Studios)/SBS - Mini Texture Pack 2 - Rooftops 128x128/128x128/"
const FOX := "Textures/Foxtex - Complete Edition (Foxhead)/foxtexcom-renamed/Textures/"

## name: [source (relative to psx/), size, mode, chroma kept (tint only), extra]
## extra: "rot" turns the texture a quarter turn (planks running the other way)
const TEXTURES := {
	# ---- buildings (tinted by the building style's colours)
	"plaster": [CD + "Lime-Render.png", 64, "tint", 0.0],
	"adobe": [CD + "Adobe.png", 64, "tint", 0.0],
	"brick": [CD + "Brick-Tan-2.png", 64, "tint", 0.0],
	"stone": [CD + "Brick-Stone.png", 64, "tint", 0.0],
	"stone_dark": [CD + "Brick-Large-Irregular.png", 64, "tint", 0.0],
	"planks_v": [CD + "Wood-Pale.png", 64, "tint", 0.0],
	"planks": [CD + "Wood-Mid.png", 64, "tint", 0.0, "rot"],
	"wood_dark": [CD + "Wood-Dark.png", 64, "tint", 0.0, "rot"],
	"bamboo": [SBS + "Yellow/Roof_Yellow_07-128x128.png", 64, "tint", 0.0],
	"cobble": [CD + "Paving-Cobble.png", 64, "tint", 0.0],
	"floor_tiles": [CD + "Floor-Tiles.png", 64, "tint", 0.0],
	# ---- roofs
	"shingle": [SBS + "Gray/Roof_Gray_01-128x128.png", 64, "tint", 0.0],
	"slate": [SBS + "Gray/Roof_Gray_03-128x128.png", 64, "tint", 0.0],
	"tile": [SBS + "White/Roof_White_03-128x128.png", 64, "tint", 0.0],
	"tin": [SBS + "Gray/Roof_Gray_07-128x128.png", 64, "tint", 0.0],
	"thatch": [SBS + "Thatch/Roof_Thatch_01-128x128.png", 64, "tint", 0.0],
	"leaf": [SBS + "Thatch/Roof_Thatch_03-128x128.png", 64, "tint", 0.0],
	# ---- ground (grey: the terrain shader colours each layer per biome)
	"ground_grass": [RG + "Grass/Grass_01/Grass_01_basecolor.png", 128, "tint", 0.0],
	"ground_path": [RG + "Dirt/Dirt_05/Dirt_05_basecolor.png", 128, "tint", 0.0],
	"ground_plaza": [CD + "Paving-Square.png", 128, "tint", 0.0],
	"ground_sand": [RG + "Sand/Sand_01/Sand_01_basecolor.png", 128, "tint", 0.0],
	"ground_rock": [RG + "Rock/Rock_01/Rock_01_basecolor.png", 128, "tint", 0.0],
	"ground_bed": [RG + "Gravel/Gravel_02/Gravel_02_basecolor.png", 128, "tint", 0.0],
	"ground_ice": [RG + "Rock/Rock_05/Rock_05_basecolor.png", 128, "tint", 0.0],
	"ground_paving": [CD + "Paving-Square.png", 128, "tint", 0.0],
}
const WATER_FRAMES := 10
const LAVA_FRAMES := 3


func _init() -> void:
	var src := ProjectSettings.globalize_path("res://psx/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name in TEXTURES:
		var e: Array = TEXTURES[name]
		var img := _load(src + e[0])
		if img == null:
			continue
		if e.size() > 4 and e[4] == "rot":
			img.rotate_90(CLOCKWISE)
		img.resize(e[1], e[1], Image.INTERPOLATE_LANCZOS)
		if e[2] == "tint":
			_flatten(img, float(e[3]))
		_save(img, name)
	# water: every other frame of the 20-frame surface loop, kept blue-ish and tinted per biome in the game
	for i in WATER_FRAMES:
		var img := _load(src + FOX + "Water/WATER_surface_FRAME_%d.png" % (i * 2 + 1))
		if img:
			img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			_flatten(img, 0.0, 0.75)
			_save(img, "water_%d" % i)
	for i in LAVA_FRAMES:
		var img := _load(src + FOX + "Outdoors/Melted/OUTDOOR_Melted_lava_%d.png" % (i + 1))
		if img:
			img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			_save(img, "lava_%d" % i)
	quit()


func _load(path: String) -> Image:
	var img := Image.new()
	if img.load(path) != OK:
		push_error("missing texture source: " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Nearly grey with an even brightness (mean `level`), keeping `chroma` of the source's own colour.
func _flatten(img: Image, chroma: float, level := 0.86) -> void:
	var total := 0.0
	var n := img.get_width() * img.get_height()
	for y in img.get_height():
		for x in img.get_width():
			total += img.get_pixel(x, y).get_luminance()
	var mean := maxf(0.01, total / n)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			var g := Color(l, l, l).lerp(c, chroma)
			# a touch more contrast than the source, so the detail survives the tinting
			var k := level / mean
			var v := Color(g.r * k, g.g * k, g.b * k)
			v = Color(level, level, level).lerp(v, 1.15)
			img.set_pixel(x, y, Color(clampf(v.r, 0, 1), clampf(v.g, 0, 1), clampf(v.b, 0, 1), c.a))


func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("  ", name, " ", img.get_size())
