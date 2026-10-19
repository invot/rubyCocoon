extends "res://scripts/ui/modal.gd"
## Shown right after saving: the snapshot of that moment, the slot, where you are and how long you've played.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")

var slot := 0
var _t := 0.0


func setup(_slot: int) -> Control:
	slot = _slot
	dim = 0.5
	return self


func _ready() -> void:
	var info: Dictionary = GameState.slot_info(slot)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", -10)
	add_child(outer)
	var rib := UIKit.ribbon("Game saved!")
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rib.custom_minimum_size.x = 360
	rib.z_index = 1
	outer.add_child(rib)
	var p := UIKit.panel()
	outer.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	vb.add_child(Control.new())
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box("slot", Vector4(4, 4, 4, 4)))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(frame)
	var shot := TextureRect.new()
	shot.texture = GameState.slot_texture(slot)
	shot.custom_minimum_size = Vector2(480, 270)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(shot)
	vb.add_child(UIKit.header("Slot %d   ·   %s" % [slot + 1, String(info.get("place", ""))], UIKit.ACCENT))
	vb.add_child(UIKit.label("Play time  %s" % GameState.time_text(float(info.get("play_time", 0.0))), 33, UIKit.INK))
	vb.add_child(UIKit.label(String(info.get("summary", "")), 20, UIKit.DIM))
	UIKit.place(outer, "center")


func _process(delta: float) -> void:
	_t += delta


func on_input(ev: InputEvent) -> void:
	if ev.is_echo() or _t < 0.3:
		return
	if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interact") or ev.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		close()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and _t >= 0.3 and not UI.touch_blocks(ev.position):
		close()
