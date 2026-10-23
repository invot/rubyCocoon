extends Node3D
## One interactable freight cage, with a named captive. The rescue flag lives in GameState, not the scene.
const Person = preload("res://scripts/gfx/voxel_person.gd")
const NAMES := ["Trainer Lio", "Trainer Bea", "Trainer Orin"]
const LOOKS := [
	{"skin": "#bf8968", "hair": "#382c29", "shirt": "#649dba", "pants": "#3c4d68", "pack": true},
	{"skin": "#efd0a7", "hair": "#ae643f", "shirt": "#c3a34b", "pants": "#455b5c", "body": "female", "pack": true},
	{"skin": "#d5ab88", "hair": "#454150", "shirt": "#ac6d96", "pants": "#484256", "pack": true},
]
var index := 0
var person: Node3D
var bars: Node3D
var opened := false
var _clock := 0.0


func _ready() -> void:
	person = Person.build(LOOKS[index])
	person.scale *= 0.78
	add_child(person)
	bars = Node3D.new()
	add_child(bars)
	for y in [0.04, 1.75]:
		_piece(Vector3(0, y, 0), Vector3(0.95, 0.08, 0.95), "#4c5b72")
	for x in [-0.44, 0.44]:
		for z in [-0.44, 0.44]:
			_piece(Vector3(x, 0.9, z), Vector3(0.045, 1.7, 0.045), "#d06b8b")
	for x in [-0.22, 0, 0.22]:
		_piece(Vector3(x, 0.9, 0.44), Vector3(0.025, 1.7, 0.025), "#89bdcf")
	var sign := Label3D.new()
	sign.text = "FREIGHT %02d" % (index + 1)
	sign.position = Vector3(0, 1.98, 0)
	sign.font_size = 24
	sign.pixel_size = 0.005
	sign.modulate = Color("#f4b1c0")
	add_child(sign)


func _piece(at: Vector3, size: Vector3, colour: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour)
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	bars.add_child(node)


func release() -> void:
	opened = true
	var tween := create_tween()
	tween.tween_property(bars, "position:y", 2.1, 0.65).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): bars.visible = false)
	Person.set_talking(person, true)


func _process(delta: float) -> void:
	_clock += delta
	Person.animate(person, 0, 0, _clock + index)
