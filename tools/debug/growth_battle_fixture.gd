extends "res://scripts/battle/battle.gd"
## Exercise the actual reward queue without starting an unrelated battle command coroutine.
func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _refresh() -> void:
	pass


func msg(text: String, _wait := 0.95, _subject = null) -> void:
	UI.auto_log.append(text)
	await get_tree().process_frame
