extends RefCounted
## --scene=robe-options: a design preview of temple robes for the Beast Center's staff, stood in a row inside the
## real Center (Cocoon Cove's), each option worn by Nurse Clover (left) and Guide Dottie (right) with their own skin
## and hair. The room's own people are hidden and the camera looks at the row from the front. Add --shot=path to
## capture it (--wait seconds first, 2 by default).
const VPer = preload("res://scripts/gfx/voxel_person.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")

## [name, look] per option: the keys every staff look gets on top of its own skin and hair
const OPTIONS := [
	["1  White and gold", {"robe": "plain", "shirt": "#f4f1ea", "shoes": "#8a5a3a", "glasses": false}],
	["2  Ruby and gold", {"robe": "plain", "shirt": "#b02a3a", "shoes": "#5a3424", "glasses": false}],
	["3  Temple stone", {"robe": "plain", "shirt": "#c4c0b8", "shoes": "#5a5048", "glasses": false}],
	["4  Teal tile", {"robe": "plain", "shirt": "#3a9e98", "shoes": "#4a3a30", "glasses": false}],
]
const STAFF := [
	{"skin": "#f0c8a0", "hair": "#e88aa0", "hair_style": 1},
	{"skin": "#c8946a", "hair": "#5a3a22", "hair_style": 0},
]


func run(main, opts: Dictionary) -> void:
	await main._do_goto("caccoon#0", "entry")
	var world = main.world
	while not is_instance_valid(world) or world.cam == null:
		await main.get_tree().process_frame
		world = main.world
	await main.get_tree().create_timer(0.5).timeout
	for p in world.npcs:
		var n: Dictionary = world.npcs[p]
		if n.has("node") and is_instance_valid(n["node"]):
			(n["node"] as Node3D).visible = false
	world.player.visible = false
	var row_z := 5.0
	var labels := []
	if opts.get("preview", "") == "uniform":
		# the staff's robe as the game has it (map_loader.gd CENTER_UNIFORM), close up
		for j in 3:
			var look: Dictionary = MapLoader.CENTER_UNIFORM.merged([STAFF[0], STAFF[1], {"skin": "#f0c8a0", "hair": "#f0d070", "hair_style": 1}][j], true)
			var person := VPer.build(look)
			person.position = Vector3(5.2 + j * 0.8, 0.0, row_z)
			world.add_child(person)
		world.cam_free = true
		world.cam.position = Vector3(6.0, 2.2, 8.6)
		world.cam.look_at(Vector3(6.0, 0.8, row_z), Vector3.UP)
		await main.get_tree().create_timer(float(opts.get("wait", "2"))).timeout
		if opts.has("shot"):
			main._save_shot(String(opts["shot"]))
		if opts.get("quit", "1") == "1":
			main.get_tree().quit()
		return
	for i in OPTIONS.size():
		var gx := 2.0 + i * 2.65
		for j in STAFF.size():
			var look: Dictionary = (STAFF[j] as Dictionary).merged(OPTIONS[i][1], true)
			var person := VPer.build(look)
			person.position = Vector3(gx + (j - 0.5) * 0.85, 0.0, row_z)
			person.rotation.y = 0.0
			world.add_child(person)
		labels.append([String(OPTIONS[i][0]), Vector3(gx, 0.0, row_z + 0.6)])
	world.cam_free = true
	world.cam.position = Vector3(6.0, 4.2, 13.5)
	world.cam.look_at(Vector3(6.0, 0.9, row_z), Vector3.UP)
	await main.get_tree().process_frame
	# a caption under each pair, in the shared dark window style
	var layer := CanvasLayer.new()
	main.get_tree().root.add_child(layer)
	layer.layer = 100
	for l in labels:
		var at: Vector2 = world.cam.unproject_position(l[1]) * main.get_viewport().get_visible_rect().size / Vector2(main.get_viewport().size)
		var lab := Label.new()
		lab.text = l[0]
		lab.add_theme_font_override("font", UIKit.font_body())
		lab.add_theme_font_size_override("font_size", UIKit.body_px(22))
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.07, 0.8)
		sb.border_color = Color.WHITE
		sb.set_border_width_all(1)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		box.add_theme_stylebox_override("panel", sb)
		box.add_child(lab)
		layer.add_child(box)
		await main.get_tree().process_frame
		box.position = at - Vector2(box.size.x / 2.0, -8.0)
	await main.get_tree().create_timer(float(opts.get("wait", "2"))).timeout
	if opts.has("shot"):
		main._save_shot(String(opts["shot"]))
	if opts.get("quit", "1") == "1":
		main.get_tree().quit()
