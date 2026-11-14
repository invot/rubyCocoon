extends Control
## Two picture slots, threaded look-ahead, aspect-preserving cover and a slow Ken Burns zoom.
## The slots draw their pictures themselves at sub-pixel positions: moving and resizing a TextureRect every frame
## snaps it to whole pixels (gui snap_controls_to_pixels), which made the zoom judder.
const CONTENT_PATH := "res://assets/loading/slideshow.json"
const ART_DIR := "res://assets/loading/"
## seconds each picture holds before the next fades in, and the crossfade's length
const HOLD := 10.0
const FADE := 2.5
## how far a picture has zoomed in by the time the next has faded over it
const ZOOM := 1.05
## where on the picture the crop and zoom centre (0 top .. 1 bottom): above the middle, so the pictures sit a little
## lower on screen and their subjects stay clear of the title plaque
const FOCUS := Vector2(0.5, 0.32)
static var content: Dictionary = {}
var index := 0
var elapsed := 0.0
var front: Slot
var back: Slot
var _requested := ""


## One picture, drawn to cover the slideshow at a zoom, without pixel snapping.
class Slot extends Control:
	var texture: Texture2D:
		set(value):
			texture = value
			queue_redraw()
	var zoom := 1.0:
		set(value):
			if value != zoom:
				zoom = value
				queue_redraw()

	func _draw() -> void:
		if texture == null or size.x <= 0.0 or size.y <= 0.0:
			return
		var tex := Vector2(texture.get_size())
		# cover: the smallest scale that fills the slot on both axes, then the zoom
		var scale_by := maxf(size.x / tex.x, size.y / tex.y) * zoom
		var shown := tex * scale_by
		# the picture's focus point stays at the same place on screen as it zooms
		var at := (size - shown) * FOCUS
		draw_texture_rect(texture, Rect2(at, shown), false)


static func library() -> Dictionary:
	if content.is_empty():
		content = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	return content


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for slot in 2:
		var image := Slot.new()
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		if slot == 0:
			front = image
		else:
			back = image
	front.texture = load(ART_DIR + library().slides[index])
	back.modulate.a = 0.0
	_request_next()
	_process(0.0)


func _request_next() -> void:
	_requested = ART_DIR + library().slides[(index + 1) % library().slides.size()]
	ResourceLoader.load_threaded_request(_requested)


func _process(delta: float) -> void:
	# A slow map-build frame must not cause a sudden zoom or skip multiple pictures.
	elapsed += minf(delta, 0.1)
	if back.texture == null and ResourceLoader.load_threaded_get_status(_requested) == ResourceLoader.THREAD_LOAD_LOADED:
		back.texture = ResourceLoader.load_threaded_get(_requested)
	if back.texture == null:
		elapsed = minf(elapsed, HOLD)
	var blend := smoothstep(HOLD, HOLD + FADE, elapsed)
	back.modulate.a = blend
	front.zoom = _zoom_at(elapsed)
	back.zoom = _zoom_at(maxf(0.0, elapsed - HOLD))
	if elapsed >= HOLD + FADE and back.texture != null:
		front.texture = back.texture
		front.zoom = back.zoom
		back.texture = null
		back.modulate.a = 0.0
		index = (index + 1) % library().slides.size()
		elapsed -= HOLD
		_request_next()


## A steady zoom over the picture's whole time on screen (from fading in to being faded over).
func _zoom_at(age: float) -> float:
	return lerpf(1.0, ZOOM, clampf(age / (HOLD + FADE), 0.0, 1.0))


func _exit_tree() -> void:
	# Claim completed look-ahead requests; never block waiting for an unfinished decode.
	if _requested != "" and ResourceLoader.load_threaded_get_status(_requested) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(_requested)
