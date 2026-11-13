extends SubViewportContainer
## The book's live battle formation, rendered by the battle's own ring/model builders.

const PreviewStage = preload("res://scripts/ui/battle_ring_preview_stage.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Silhouette = preload("res://scripts/battle/silhouette_outline.gdshader")

var stage: Node3D
var _faded: TextureRect
var _outline: TextureRect
var _fade: Tween
var facing := 0.0:
	set(value):
		facing = value
		if is_instance_valid(stage):
			stage.face_offset(value)


func _init(px := 160.0) -> void:
	custom_minimum_size = Vector2(px, px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(px, px)
	viewport.handle_input_locally = false
	add_child(viewport)
	stage = PreviewStage.new()
	viewport.add_child(stage)
	resized.connect(_fit_camera)


func set_ring(placed: Dictionary, side := -1) -> void:
	stage.show_ring(placed, maxi(side, 0))
	_fit_camera()


func show_placement(beast, slot: int) -> void:
	stage.show_placement(beast, slot)
	if _faded == null:
		_faded = TextureRect.new()
		_faded.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_faded.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_faded.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_faded)
		_faded.texture = stage.faded_texture()
		_outline = TextureRect.new()
		_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := ShaderMaterial.new()
		material.shader = Silhouette
		material.set_shader_parameter("count", 1)
		material.set_shader_parameter("boxes", [Vector4(0, 0, 1, 1)])
		material.set_shader_parameter("colors", [UIKit.ACCENT])
		_outline.material = material
		add_child(_outline)
		_outline.texture = stage.front_texture()
		_faded.visible = false
	if not _faded.visible:
		_faded.modulate.a = 1.0
		_fade = create_tween()
		_fade.tween_property(_faded, "modulate:a", 0.12, 0.18)
	_faded.show()
	_outline.show()
	_fit_camera()
	_outline.material.set_shader_parameter("width", 3.0)


func clear_placement() -> void:
	if is_instance_valid(stage) and stage.is_node_ready():
		stage.clear_placement()
	if _faded != null:
		if _fade != null and _fade.is_running():
			_fade.kill()
		_faded.hide()
		_outline.hide()


func _fit_camera() -> void:
	if is_instance_valid(stage) and stage.is_node_ready():
		stage.fit_camera(size)
