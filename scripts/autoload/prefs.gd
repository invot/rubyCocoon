extends Node
## Player settings (volume, text speed, controls, highlight colour), saved to user://settings.cfg.

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 0.9
## characters per second in dialogue boxes; 0 = instant
var text_speed := 60.0
## "auto" (touch controls only on touch devices), "on", "off"
var touch_controls := "auto"
var show_key_legend := true
var fullscreen := false
## the gem the menus are tinted with: one of UIKit.ACCENTS ("ruby", "sapphire", "emerald", "hematite")
var accent := "ruby"
## how the menus look: "pixel" (the 1-bit frames and the paper book) or "cozy" (the rounded windows); see UIKit.STYLES
var ui_style := "pixel"

signal changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_prefs()
	apply()


func load_prefs() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	music_volume = float(c.get_value("audio", "music", music_volume))
	sfx_volume = float(c.get_value("audio", "sfx", sfx_volume))
	text_speed = float(c.get_value("game", "text_speed", text_speed))
	touch_controls = String(c.get_value("controls", "touch", touch_controls))
	show_key_legend = bool(c.get_value("controls", "key_legend", show_key_legend))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	accent = String(c.get_value("ui", "accent", accent))
	ui_style = String(c.get_value("ui", "style", ui_style))
	# the old highlight colours became gems
	accent = {"red": "ruby", "blue": "sapphire", "green": "emerald", "silver": "hematite", "purple": "ruby"}.get(accent, accent)


func save_prefs() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music_volume)
	c.set_value("audio", "sfx", sfx_volume)
	c.set_value("game", "text_speed", text_speed)
	c.set_value("controls", "touch", touch_controls)
	c.set_value("controls", "key_legend", show_key_legend)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("ui", "accent", accent)
	c.set_value("ui", "style", ui_style)
	c.save(PATH)


func apply() -> void:
	if is_instance_valid(Sfx):
		Sfx.set_volumes(music_volume, sfx_volume)
	if not is_mobile() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
	changed.emit()


func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save_prefs()


## True on phones and tablets (including mobile web browsers).
func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch" in OS.get_cmdline_user_args()


func touch_enabled() -> bool:
	match touch_controls:
		"on":
			return true
		"off":
			return false
	return is_mobile() or (DisplayServer.is_touchscreen_available() and OS.has_feature("web"))
