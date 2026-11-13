extends Node
## Player settings, saved independently of the game's save slots.

const PATH := "user://settings.cfg"
const RESOLUTIONS := [540, 720, 1080, 1440]
const QUALITY_ORDER := ["min", "mid", "max"]

var music_volume := 0.8
var sfx_volume := 0.9
## characters per second in dialogue boxes; 0 = instant
var text_speed := 60.0
## "auto" (touch controls only on touch devices), "on", "off"
var touch_controls := "auto"
## Empty keeps automatic selection for existing settings. Explicit choices persist across launches.
var input_mode := ""
var _hardware_keyboard := false
var show_key_legend := true
var fullscreen := false
## Internal 3D height; width follows the window's aspect. The UI keeps its full resolution.
var render_height := 540
var graphics_quality := "max"
var _browser_mobile: Variant = null
## the gem the menus are tinted with: one of UIKit.ACCENTS ("ruby", "sapphire", "emerald", "hematite")
var accent := "ruby"

signal changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_prefs()
	_hardware_keyboard = DisplayServer.has_hardware_keyboard()
	if OS.has_feature("android"):
		DisplayServer.set_hardware_keyboard_connection_change_callback(_keyboard_changed)
	apply()
	add_child(load("res://scripts/gfx/render_quality.gd").new())


## Explicit override for isolated settings tests; ordinary play always uses PATH.
func prefs_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if (arg.begins_with("--prefs_path=res://build/") or arg.begins_with("--prefs_path=user://bench/vo/")) and not ".." in arg:
			return arg.trim_prefix("--prefs_path=")
	return PATH


func load_prefs() -> void:
	var c := ConfigFile.new()
	if c.load(prefs_path()) != OK:
		return
	music_volume = float(c.get_value("audio", "music", music_volume))
	sfx_volume = float(c.get_value("audio", "sfx", sfx_volume))
	text_speed = float(c.get_value("game", "text_speed", text_speed))
	touch_controls = String(c.get_value("controls", "touch", touch_controls))
	input_mode = String(c.get_value("controls", "input", ""))
	if not input_mode in ["", "screen", "keyboard", "controller"]:
		input_mode = ""
	show_key_legend = bool(c.get_value("controls", "key_legend", show_key_legend))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	render_height = int(c.get_value("video", "render_height", 540))
	graphics_quality = String(c.get_value("video", "graphics_quality", "max"))
	_validate_video()
	accent = String(c.get_value("ui", "accent", accent))
	# (an old "style" value, Pixel or Classic, is ignored: there is one look now)
	# the old highlight colours became gems
	accent = {"red": "ruby", "blue": "sapphire", "green": "emerald", "silver": "hematite", "purple": "ruby"}.get(accent, accent)


func save_prefs() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sfx", sfx_volume)
	c.set_value("game", "text_speed", text_speed)
	c.set_value("controls", "touch", touch_controls)
	c.set_value("controls", "input", input_mode)
	c.set_value("controls", "key_legend", show_key_legend)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "render_height", render_height)
	c.set_value("video", "graphics_quality", graphics_quality)
	c.set_value("ui", "accent", accent)
	DirAccess.make_dir_recursive_absolute(prefs_path().get_base_dir())
	c.save(prefs_path())


func apply() -> void:
	_validate_video()
	if is_instance_valid(Sfx):
		Sfx.set_volumes(music_volume, sfx_volume)
	if not is_mobile() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
	changed.emit()


func _validate_video() -> void:
	if not render_height in RESOLUTIONS:
		render_height = 540
	if not graphics_quality in QUALITY_ORDER:
		graphics_quality = "max"


func render_size(window_size: Vector2i) -> Vector2i:
	var height := maxi(1, window_size.y)
	return Vector2i(maxi(2, roundi(float(window_size.x) * render_height / height)), render_height)


## Smooth both ways: bilinear when enlarging a lower resolution (never blocky pixels) and when reducing a higher one.
func render_filter(_window_size: Vector2i) -> int:
	return CanvasItem.TEXTURE_FILTER_LINEAR


## A mild sharpen after enlarging (resolve_sharpen.gdshader), on Forward+ and Mobile only; Compatibility (desktop
## OpenGL, the web) keeps plain bilinear. No pass at or above the window's height.
func render_sharpen(window_size: Vector2i) -> bool:
	return render_height < window_size.y and RenderingServer.get_current_rendering_method() != "gl_compatibility"


func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save_prefs()


## True on phones and tablets (including mobile web browsers).
func is_mobile() -> bool:
	if OS.has_feature("web"):
		if _browser_mobile == null:
			_browser_mobile = JavaScriptBridge.eval("window.rubyMobileBrowser", true)
		if _browser_mobile != null:
			return bool(_browser_mobile)
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch" in OS.get_cmdline_user_args()


func is_desktop_web() -> bool:
	return OS.has_feature("web") and not is_mobile()


func touch_enabled() -> bool:
	# Desktop web always uses the key guide, including touchscreen laptops and old saved pad settings.
	if is_desktop_web():
		return false
	if input_mode != "" or is_instance_valid(Controllers) and Controllers.connected():
		return effective_input() == "screen"
	match touch_controls:
		"on":
			return true
		"off":
			return false
	return is_mobile() or (DisplayServer.is_touchscreen_available() and OS.has_feature("web"))


func _keyboard_changed(connected: bool) -> void:
	_hardware_keyboard = connected
	changed.emit()


## Touchscreen controls only appear as a choice on a touch-capable device; desktop web stays keyboard based.
func available_inputs() -> Array[String]:
	var modes: Array[String] = []
	if not is_desktop_web() and (is_mobile() or DisplayServer.is_touchscreen_available()):
		modes.append("screen")
	if _hardware_keyboard or not is_mobile():
		modes.append("keyboard")
	if is_instance_valid(Controllers) and Controllers.connected():
		modes.append("controller")
	return modes


func effective_input() -> String:
	var modes := available_inputs()
	if input_mode in modes:
		return input_mode
	if "controller" in modes:
		return "controller"
	if "screen" in modes and is_mobile():
		return "screen"
	return "keyboard" if "keyboard" in modes else "screen"
