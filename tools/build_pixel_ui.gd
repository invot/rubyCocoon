extends SceneTree
## Cuts the pieces the Pixel interface style is built from (UIKit style "pixel") out of two UI kits, into
## assets/ui/pixel_ui.res:
##   godot --headless --path . --script res://tools/build_pixel_ui.gd
## - ui/1-bit_UI_byBatuhanK.png: windows, plates, bars, dots, stars, hearts and the round icons (white on near-black)
## - ui/Humble Gift - v1.3/PNG/SpriteSheet.png: the Start book's pages, their ornament frames, the selection arrows and
##   the page buttons (paper, ink and maroon)
## Every piece is stored as tones, not colours, so the game paints it in any gem (UIKit.piece): each texel's red
## channel says what it is (0 the fill, 128 a mid shade, 255 a line) and its alpha how solid. The 1-bit kit's white is
## its line and its near-black its fill; the Humble Gift paper is the fill, its shading the mid shade, its ink and
## maroon the line.
## The resource's metadata: "pieces" {name: Image}.

const ONE_BIT := "res://ui/1-bit_UI_byBatuhanK.png"
const HUMBLE := "res://ui/Humble Gift - v1.3/PNG/SpriteSheet.png"
const OUT := "res://assets/ui/pixel_ui.res"

## name: [x, y, w, h] on the 1-bit sheet
const ONE_BIT_PIECES := {
	"window": [271, 119, 174, 83],
	"panel_tall": [91, 11, 30, 45], "plate_small": [132, 11, 22, 9], "panel": [132, 25, 22, 29], "panel_pins": [90, 59, 53, 19],
	"hex": [158, 55, 32, 28], "plate": [96, 83, 39, 14], "ribbon": [150, 88, 38, 9], "banner": [100, 115, 93, 27],
	"sign": [158, 11, 23, 36],
	"bar_full": [90, 159, 106, 8], "bar_empty": [90, 171, 106, 8], "bar_dither": [90, 183, 106, 8], "bar_thin": [91, 196, 80, 6],
	"dot_on": [92, 206, 14, 14], "dot_dark": [110, 206, 14, 14], "dot_off": [127, 206, 14, 14],
	"star": [13, 119, 16, 16], "heart": [15, 68, 15, 15], "shield": [38, 68, 15, 16], "sword": [60, 68, 15, 15],
	"potion": [15, 188, 12, 18], "potion_dark": [36, 188, 12, 18],
	"line_solid": [213, 112, 27, 1], "line_dash": [213, 122, 25, 5], "line_arrows": [213, 131, 25, 3], "line_beads": [213, 138, 25, 7],
	# the round icons, 20 x 20
	"i_play": [214, 9, 20, 20], "i_door": [242, 9, 20, 20], "i_cross": [267, 9, 20, 20], "i_right": [293, 9, 20, 20],
	"i_sound": [318, 9, 20, 20], "i_unlock": [343, 9, 20, 20], "i_blank": [368, 9, 20, 20],
	"i_pause": [214, 34, 20, 20], "i_gear": [242, 34, 20, 20], "i_target": [267, 34, 20, 20], "i_left": [293, 34, 20, 20],
	"i_back": [318, 34, 20, 20], "i_retry": [343, 34, 20, 20],
	"i_close": [214, 59, 20, 20], "i_home": [242, 59, 20, 20], "i_ring": [267, 59, 20, 20], "i_up": [293, 58, 20, 20],
	"i_key": [318, 58, 20, 20], "i_trophy": [343, 58, 20, 20],
	"i_help": [214, 83, 20, 20], "i_check": [242, 83, 20, 20], "i_circle": [267, 83, 20, 20], "i_down": [293, 83, 20, 20],
	"i_lock": [318, 83, 20, 20], "i_list": [343, 83, 20, 20],
}
## name: [x, y, w, h] on the Humble Gift sheet
const HUMBLE_PIECES := {
	"page": [32, 1120, 183, 280], "page_frame": [268, 1135, 159, 249],
	"page_big": [38, 1666, 248, 280], "page_big_frame": [338, 1681, 224, 249],
	"page_arrow": [57, 1496, 17, 31], "page_arrow_on": [105, 1496, 17, 31],
	"page_button": [52, 1557, 57, 22], "page_button_on": [132, 1557, 57, 20],
}


func _initialize() -> void:
	var pieces := {}
	var one := _load(ONE_BIT)
	for k in ONE_BIT_PIECES:
		pieces[k] = _tones(one, ONE_BIT_PIECES[k], false)
	var hg := _load(HUMBLE)
	for k in HUMBLE_PIECES:
		pieces[k] = _tones(hg, HUMBLE_PIECES[k], true)
	var res := Resource.new()
	res.set_meta("pieces", pieces)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(res, OUT, ResourceSaver.FLAG_COMPRESS)
	print("%d pieces -> %s (%s)" % [pieces.size(), OUT, error_string(err)])
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## A piece as tones (see the top). Humble Gift: bright paper is the fill, its shading the mid shade, anything dark the
## line. 1-bit: white is the line, the rest the fill.
func _tones(src: Image, r: Array, humble: bool) -> Image:
	var out := Image.create(r[2], r[3], false, Image.FORMAT_RGBA8)
	for y in r[3]:
		for x in r[2]:
			var c := src.get_pixel(r[0] + x, r[1] + y)
			if c.a < 0.5:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var lum := c.get_luminance()
			var tone := 0.0
			if humble:
				tone = 0.0 if lum > 0.62 else (0.5 if lum > 0.42 else 1.0)
			else:
				tone = 1.0 if lum > 0.5 else 0.0
			out.set_pixel(x, y, Color(tone, tone, tone, 1.0))
	return out
