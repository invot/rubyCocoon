extends Control
## Two texture slots, threaded look-ahead, aspect-preserving cover and a gentle Ken Burns zoom.
const CONTENT_PATH := "res://assets/loading/slideshow.json"
const ART_DIR := "res://assets/loading/"
const HOLD := 7.0
const FADE := 2.0
static var content: Dictionary = {}
var index := 0
var elapsed := 0.0
var front: TextureRect
var back: TextureRect
var _requested := ""

static func library() -> Dictionary:
	if content.is_empty():
		content = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	return content

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for slot in 2:
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	_place(front, elapsed)
	_place(back, maxf(0.0, elapsed - HOLD))
	if elapsed >= HOLD + FADE and back.texture != null:
		front.texture = back.texture
		back.texture = null
		back.modulate.a = 0.0
		index = (index + 1) % library().slides.size()
		elapsed -= HOLD
		_request_next()

func _place(image: TextureRect, age: float) -> void:
	var zoom := lerpf(1.0, 1.07, clampf(age / (HOLD + FADE), 0.0, 1.0))
	image.size = size * zoom
	image.position = (size - image.size) * 0.5

func _exit_tree() -> void:
	# Claim completed look-ahead requests; never block waiting for an unfinished decode.
	if _requested != "" and ResourceLoader.load_threaded_get_status(_requested) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(_requested)
