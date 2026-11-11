extends Node
## USB and Bluetooth use Godot's built-in joypad mappings. No player setup is needed.
## Track the last used pad (not a hardcoded device 0) and bridge its stick to cardinal menu presses.

const Layout = preload("res://scripts/core/controller_layout.gd")
const DEADZONE := 0.35
signal changed

var active_device := -1
var devices := PackedInt32Array()
var layout := "xbox-one"
var _menu_action := ""
var _repeat := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)
	devices = Input.get_connected_joypads()
	if not devices.is_empty():
		_select(devices[0])
	get_window().focus_exited.connect(_release_menu)


func connected() -> bool:
	return not devices.is_empty()


func _connection_changed(device: int, on: bool) -> void:
	if on and not device in devices:
		devices.append(device)
	elif not on:
		devices.erase(device)
	if active_device == device or active_device < 0 or not active_device in devices:
		_select(devices[0] if not devices.is_empty() else -1)
	else:
		changed.emit()


func _select(device: int) -> void:
	_release_menu()
	active_device = device
	layout = Layout.identify(Input.get_joy_name(device), Input.get_joy_info(device)) if device >= 0 else "xbox-one"
	changed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > DEADZONE:
		if event.device != active_device:
			_select(event.device)


func stick() -> Vector2:
	if active_device < 0 or not get_window().has_focus() and DisplayServer.get_name() != "headless":
		return Vector2.ZERO
	var v := Vector2(Input.get_joy_axis(active_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(active_device, JOY_AXIS_LEFT_Y))
	return v if v.length() >= DEADZONE else Vector2.ZERO


## Round to the nearest 45 degrees, preserving a radial deadzone.
func direction() -> Vector2i:
	var v := stick()
	if v == Vector2.ZERO:
		return Vector2i.ZERO
	var angle := snappedf(v.angle(), PI / 4.0)
	return Vector2i(roundi(cos(angle)), roundi(sin(angle)))


func _process(delta: float) -> void:
	var v := stick() if is_instance_valid(UI) and UI.busy() else Vector2.ZERO
	var action := ""
	if v != Vector2.ZERO:
		action = ("ui_right" if v.x > 0.0 else "ui_left") if absf(v.x) > absf(v.y) else ("ui_down" if v.y > 0.0 else "ui_up")
	if action != _menu_action:
		_release_menu()
		_menu_action = action
		_repeat = 0.38
		if action != "":
			_send(action, true)
			_send(action, false)
	elif action != "":
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = 0.13
			_send(action, true)
			_send(action, false)


func _release_menu() -> void:
	if _menu_action != "":
		_send(_menu_action, false)
	_menu_action = ""


func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
