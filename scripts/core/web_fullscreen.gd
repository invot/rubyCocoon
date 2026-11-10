extends Node
## The browser owns fullscreen gestures; this bridge owns only its temporary pause.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
var _browser: JavaScriptObject
var _callback: JavaScriptObject
var _blocked := false
var _was_paused := false
var _was_muted := false
var _ui_mode: int


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	if not bool(JavaScriptBridge.eval("typeof window.rubyFullscreen !== 'undefined'", true)):
		return
	_browser = JavaScriptBridge.get_interface("rubyFullscreen")
	if _browser == null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_callback = JavaScriptBridge.create_callback(_on_browser_state)
	_browser.connectGame(_callback)
	Prefs.changed.connect(_theme)
	_theme()


func _on_browser_state(args: Array) -> void:
	var blocked := bool(args[0])
	if blocked == _blocked:
		return
	_blocked = blocked
	for action in InputMap.get_actions():
		Input.action_release(action)
	if blocked:
		_was_paused = get_tree().paused
		_was_muted = AudioServer.is_bus_mute(0)
		_ui_mode = UI.process_mode
		UI.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		AudioServer.set_bus_mute(0, true)
	else:
		get_tree().paused = _was_paused
		AudioServer.set_bus_mute(0, _was_muted)
		UI.process_mode = _ui_mode


func _theme() -> void:
	# Prefs emits after UIKit's UI listener, so these are the current shared colours.
	_browser.theme("#" + UIKit.ACCENT.to_html(), "#" + UIKit.WINDOW_TOP.to_html(),
		"#" + UIKit.WINDOW_BOTTOM.to_html(), "#" + UIKit.BORDER.to_html(), "#" + UIKit.INK.to_html())
