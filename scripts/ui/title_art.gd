extends Control
## The title screen's art (tools/make_splash.py): the boot splash's picture covering the screen as the boot splash
## does (project.godot's stretch mode Cover), and its logo laid over it just where the boot splash has it, so the boot
## splash gives way to the title without a jump. The logo can be hidden on its own (Load Game, the character creator).

const BACKDROP := preload("res://assets/icon/title_backdrop.png")
const LOGO := preload("res://assets/icon/title_logo.png")
## the picture's size, and the logo's top edge in it, centred across it (make_splash.py LOGO_TOP)
const ART := Vector2(1920, 1080)
const LOGO_TOP := 150.0

var logo: TextureRect


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	# (a painting, scaled to the screen: smooth, unlike the pixel interface)
	texture_filter = TEXTURE_FILTER_LINEAR
	var back := TextureRect.new()
	back.texture = BACKDROP
	back.set_anchors_preset(PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back)
	logo = TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(logo)
	resized.connect(_place_logo)


## Puts the logo where the covering picture has it.
func _place_logo() -> void:
	var k := maxf(size.x / ART.x, size.y / ART.y)
	var at := (size - ART * k) / 2.0
	logo.size = LOGO.get_size() * k
	logo.position = at + Vector2((ART.x * k - logo.size.x) / 2.0, LOGO_TOP * k)
