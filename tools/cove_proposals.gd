extends SceneTree
## Windowed, isolated art/layout studies using the supplied models, not playable maps.
## godot --path . --script res://tools/cove_proposals.gd -- --layout=a --shot=res://build/shots/cove_a.png
## --layout=gallery|a|b|c, --view=overview|square|harbour|home, --hold=1 keeps the window open.

const KIT := "res://assets/exteriors/cove_"
var opts := {}
var stage: Node3D
var camera: Camera3D
var mats := {}
var meshes := {}
var labels := []
var layout := "a"
var base := 2.8


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			opts[pair[0]] = pair[1]
	layout = opts.get("layout", "a")
	_run.call_deferred()


func _run() -> void:
	root.title = "Ruby Cocoon — Cocoon Cove layout study " + layout.to_upper()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	_environment()
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 250
	if layout == "gallery":
		_gallery()
	else:
		_ocean()
		if layout == "a":
			_horseshoe()
		elif layout == "b":
			_switchback()
		else:
			_lagoon()
		_camera()
		_overlay()
	for i in 12:
		await process_frame
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	if opts.has("shot"):
		var path: String = ProjectSettings.globalize_path(opts["shot"])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := root.get_texture().get_image().save_png(path)
		print("COVE PROPOSAL CAPTURE: ", path, " ", error_string(err))
	print("COVE PROPOSAL DONE: ", layout, " (visual study, no gameplay or save changes)")
	if opts.get("hold", "0") != "1":
		quit()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a9d3d1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e5e0")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.ssao_enabled = RenderingServer.get_current_rendering_method() != "mobile"
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -35, 0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 100
	stage.add_child(sun)


func _mat(hex: String) -> StandardMaterial3D:
	if not mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.88
		m.metallic_specular = 0.15
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mats[hex] = m
	return mats[hex]


func _box(pos: Vector3, size: Vector3, col: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	n.mesh = m
	n.material_override = _mat(col)
	n.position = pos
	stage.add_child(n)
	return n


func _cylinder(pos: Vector3, radius: float, height: float, col: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	n.mesh = m
	n.material_override = _mat(col)
	n.position = pos
	stage.add_child(n)
	return n


func _model(key: String, p: Vector3, width: float, angle := 0.0, depth := 0.0) -> MeshInstance3D:
	if not meshes.has(key):
		meshes[key] = load(KIT + key + ".res")
	var m: Mesh = meshes[key]
	var n := MeshInstance3D.new()
	n.mesh = m
	var bb := m.get_aabb()
	var s := width / bb.size.x
	n.scale = Vector3(s, s, s if depth <= 0 else depth / bb.size.z)
	n.rotation_degrees.y = angle
	n.position = p
	stage.add_child(n)
	return n


func _poly(points: Array, height: float, green := true) -> void:
	var polygon := PackedVector2Array()
	for p in points:
		polygon.append(Vector2(p[0], p[1]))
	var indices := Geometry2D.triangulate_polygon(polygon)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		for j in [0, 1, 2]:
			var p := polygon[indices[i + j]]
			top.set_normal(Vector3.UP)
			top.add_vertex(Vector3(p.x, height, p.y))
	var cap := MeshInstance3D.new()
	cap.mesh = top.commit()
	cap.material_override = _mat("7f9d69" if green else "baa888")
	stage.add_child(cap)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var aa := Vector3(a.x, -0.7, a.y)
		var ab := Vector3(a.x, height - 0.05, a.y)
		var ba := Vector3(b.x, -0.7, b.y)
		var bb := Vector3(b.x, height - 0.05, b.y)
		for v in [aa, ba, bb, aa, bb, ab]:
			walls.set_color(Color("cbb58c") if v.y > 0 else Color("8c8e7b"))
			walls.add_vertex(v)
	walls.generate_normals()
	var cliff := MeshInstance3D.new()
	cliff.mesh = walls.commit()
	var stone := _mat("ffffff").duplicate() as StandardMaterial3D
	stone.vertex_color_use_as_albedo = true
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	cliff.material_override = stone
	stage.add_child(cliff)
	# Large, irregular rock buttresses avoid a straight retaining-wall silhouette.
	for i in polygon.size():
		if i % 2 == 0:
			var p := polygon[i]
			var rock := _model("rock", Vector3(p.x, -0.45, p.y), 2.8 + float(i % 3), float(i * 37))
			rock.scale.y = (height + 0.2) / rock.mesh.get_aabb().size.y
			rock.material_override = _mat("aa9c82")


func _ocean() -> void:
	var n := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	n.mesh = plane
	n.position.y = -0.12
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; void fragment(){ float w=sin(UV.x*190.0+sin(UV.y*110.0))*sin(UV.y*250.0+UV.x*90.0); ALBEDO=mix(vec3(0.055,0.31,0.34),vec3(0.12,0.48,0.48),w*0.12+0.56); ROUGHNESS=0.28; SPECULAR=0.45; }"
	var m := ShaderMaterial.new()
	m.shader = shader
	n.material_override = m
	stage.add_child(n)


func _path(points: Array, y: float, width := 2.2) -> void:
	for i in points.size() - 1:
		var a := Vector3(points[i][0], y + 0.03, points[i][1])
		var b := Vector3(points[i + 1][0], y + 0.03, points[i + 1][1])
		var d := b - a
		var n := _box((a + b) / 2.0, Vector3(width, 0.08, d.length() + width * 0.3), "c8b99b")
		n.rotation.y = atan2(d.x, d.z)
		_cylinder(a, width * 0.52, 0.08, "c8b99b").rotation_degrees.y = 15


func _stairs(a: Vector3, b: Vector3, width := 2.8) -> void:
	var delta := b - a
	var steps := maxi(8, ceili(absf(delta.y) / 0.18))
	var run := Vector2(delta.x, delta.z).length()
	for i in steps:
		var t := (float(i) + 0.5) / steps
		var p := a.lerp(b, t)
		var n := _box(p - Vector3(0, 0.13, 0), Vector3(width, 0.26, run / steps + 0.04), "d0c1a0")
		n.rotation.y = atan2(delta.x, delta.z)
	for side in [-1, 1]:
		var normal: Vector3 = Vector3(delta.z, 0, -delta.x).normalized() * width * 0.48 * side
		var rail := _box((a + b) * 0.5 + normal + Vector3.UP * 0.7, Vector3(0.1, 0.12, delta.length()), "e1d3b0")
		rail.look_at(b + normal + Vector3.UP * 0.7)


func _dock(x: float, z: float, width: float, depth: float) -> void:
	# Reuse the pack's platform planks, with tidy modern timber fascias and grounded pilings.
	var deck := _model("platform", Vector3(x, 0.91, z), width, 0, depth)
	deck.scale.y = 0.14 / deck.mesh.get_aabb().size.y
	deck.material_override = _mat("a0815a")
	_box(Vector3(x, 0.9, z), Vector3(width + 0.12, 0.22, depth + 0.12), "785b40")
	for edge in [-1, 1]:
		for end in [-1, 1]:
			_cylinder(Vector3(x + edge * (width / 2 - 0.16), 0.15, z + end * (depth / 2 - 0.16)), 0.15, 2.5, "614b38")
	# Plank seams are quiet and regular; the walkable centre stays clear.
	for i in int(depth / 0.5):
		_box(Vector3(x, 1.055, z - depth / 2 + i * 0.5), Vector3(width - 0.12, 0.015, 0.025), "8a6c4c")


func _lamp(x: float, y: float, z: float) -> void:
	_cylinder(Vector3(x, y + 1.25, z), 0.055, 2.5, "425557")
	_box(Vector3(x, y + 2.5, z), Vector3(0.32, 0.4, 0.32), "f7d695")
	_box(Vector3(x, y + 2.74, z), Vector3(0.44, 0.1, 0.44), "425557")


func _planter(x: float, y: float, z: float) -> void:
	_box(Vector3(x, y + 0.19, z), Vector3(1.25, 0.38, 0.65), "8b6849")
	for i in 4:
		var p := Vector3(x - 0.44 + i * 0.29, y + 0.43, z)
		_cylinder(p, 0.22, 0.18, "749256")
		_cylinder(p + Vector3.UP * 0.15, 0.1, 0.12, "e6bd86" if i % 2 == 0 else "d99a86")


func _greenery(points: Array, y: float) -> void:
	for i in points.size():
		var p := Vector3(points[i][0], y, points[i][1])
		var key := "palm" if i % 3 == 0 else "tree_round_1"
		var n := MeshInstance3D.new()
		n.mesh = load("res://assets/nature/" + key + ".res")
		var bb := n.mesh.get_aabb()
		var s := (3.4 if key == "palm" else 2.7) / bb.size.y
		n.scale = Vector3.ONE * s
		n.position = p - Vector3(0, bb.position.y * s, 0)
		n.rotation.y = i * 1.8
		stage.add_child(n)


func _house(key: String, x: float, y: float, z: float, width: float, title: String, angle := 0.0) -> void:
	var n := _model(key, Vector3(x, y, z), width, angle)
	var bb := n.mesh.get_aabb()
	labels.append([title, Vector3(x, y + bb.size.y * n.scale.y + 0.5, z)])
	# Simple modern additions keep the original roof and timber silhouettes.
	_planter(x - width * 0.3, y, z + bb.size.z * n.scale.z * 0.45 + 0.5)
	_lamp(x + width * 0.48 + 0.2, y, z + bb.size.z * n.scale.z * 0.35)
	if title == "BEAST CENTER":
		# The healing service remains a diner: striped canopy and a clear red service sign.
		for i in 10:
			_box(Vector3(x - width * 0.45 + i * width * 0.09, y + 2.0, z + 3.05), Vector3(width * 0.09, 0.14, 1.2), "b45c54" if i % 2 == 0 else "eee0bf")
		_box(Vector3(x, y + 2.65, z + 3.12), Vector3(0.85, 0.85, 0.12), "b45c54")
		_box(Vector3(x, y + 2.65, z + 3.20), Vector3(0.5, 0.14, 0.08), "fff2d8")
		_box(Vector3(x, y + 2.65, z + 3.20), Vector3(0.14, 0.5, 0.08), "fff2d8")
	elif title == "APOTHECARY":
		# A plaster shop with its own green storefront, keeping the source building
		# geometry and opaque closures. It must not read as the wooden gear shack.
		var front := bb.size.z * n.scale.z * 0.34
		var canopy_y := y + 1.35
		for i in 8:
			_box(Vector3(x-width*0.36+i*width*0.09,canopy_y,z+front+0.42),Vector3(width*0.09,0.12,0.85),"507c62" if i%2==0 else "eee0bf")
		_box(Vector3(x+width*0.28,y+1.95,z+front+0.48),Vector3(0.62,0.72,0.1),"507c62")
		# A little cream bottle on the sign distinguishes it from the healer.
		_box(Vector3(x+width*0.28,y+1.91,z+front+0.55),Vector3(0.28,0.33,0.05),"fff2d8")
		_box(Vector3(x+width*0.28,y+2.14,z+front+0.55),Vector3(0.13,0.15,0.05),"fff2d8")


func _square(x: float, y: float, z: float) -> void:
	_box(Vector3(x, y + 0.035, z), Vector3(12, 0.09, 7.5), "c5baa0")
	# Broad stone courses instead of small noisy cobbles.
	for i in 6:
		_box(Vector3(x, y + 0.085, z - 3 + i * 1.2), Vector3(11.8, 0.01, 0.025), "b3a88e")
	_cylinder(Vector3(x, y + 0.15, z), 0.85, 0.3, "e0cfaa")
	_box(Vector3(x, y + 0.55, z), Vector3(0.65, 0.8, 0.65), "b4986a")
	# Reuse Cocoon Cove's real mascot model, not a generic pirate statue.
	var rendering = load("res://scripts/gfx/beast_model.gd")
	var beast: Node3D = rendering.rig(load("res://scripts/data/race_db.gd").genes(2), 1.0)
	stage.add_child(beast)
	rendering.cast(beast, _mat("b4986a"))
	beast.position = Vector3(x, y + 0.95, z)
	beast.rotation_degrees.y = -35
	for side in [-1, 1]:
		_planter(x + side * 4.8, y, z + 2.7)
		_box(Vector3(x + side * 4.7, y + 0.4, z + 0.5), Vector3(1.8, 0.12, 0.6), "9c7751")
		_lamp(x + side * 5.3, y, z - 2.9)
	labels.append(["TOWN SQUARE · ON LAND", Vector3(x, y + 0.2, z + 3.5)])


func _horseshoe() -> void:
	_poly([[-22,-23],[-11,-24],[1,-23],[13,-20],[20,-14],[22,-7],[19,-1],[13,0],[9,-1],[4,1],[-2,0],[-7,2],[-14,5],[-20,2],[-23,-5]], base)
	_poly([[-21,-22],[-9,-23],[-6,-18],[-7,-12],[-12,-10],[-20,-11],[-22,-15]], 7.2)
	_poly([[-5,-22],[7,-23],[15,-19],[13,-13],[5,-13],[-4,-15]], 5.4)
	_house("whole_house", -15, 7.2, -17, 6.0, "YOUR HOME")
	_house("house_2", -2, 5.4, -18, 4.8, "NEIGHBOR")
	_house("hut_1", 9, 5.4, -17, 4.8, "NEIGHBOR")
	_house("house_4", -6.4, base, -8.5, 6.2, "LIBRARY")
	_house("house_1", 3, base, -8.5, 7.2, "BEAST CENTER")
	_square(1, base, -2.3)
	_path([[-15,-13],[-14,-11],[-11,-11]],7.2)
	_stairs(Vector3(-10.8,7.2,-10.8), Vector3(-10.8,base,-3.3))
	_path([[-10.8,-3.3],[-6,-3.3],[-6,-1],[0,-1]],base)
	_path([[6,-3],[11,-3],[13,-5],[18,-5]],base)
	_stairs(Vector3(15,base,-10),Vector3(15,5.4,-15),2.4)
	_path([[-2,-14],[4,-14],[11,-14],[15,-15]],5.4)
	_house("house_3", 18, base, -9, 4.8, "APOTHECARY")
	_dock(-15,8,6.5,6)
	_dock(-4.9,9.8,24.5,3.0)
	_dock(5.2,8.3,6.5,6.8)
	_dock(8.5,2.6,2.8,6.4)
	# One simple L, entered only from the right; the shack terminates its far end.
	_dock(-15,13.0,2.6,6.0)
	_dock(-15,17.0,6.5,6.0)
	_stairs(Vector3(8.5,base,-1),Vector3(8.5,1.05,2.1))
	_house("hut_3",-15,1.05,7,5.4,"DOCKSIDE HOME")
	_house("house_2",5.2,1.05,7,4.5,"DOCKSIDE HOME")
	_house("house_2",-15,1.05,16.3,4.2,"OLD GEAR SHACK")
	_path([[7,-2],[15,-2],[18,-3],[25,-3]],base)
	labels.append(["TO COASTAL PATH · BRAM'S GATE",Vector3(22,base+0.6,-3)])
	_greenery([[-20,-17],[-19,-13],[-13,-22],[-8,-21]],7.2)
	_greenery([[-20,-7],[-18,-4],[-17,-7],[13,-8],[20,-12]],base)


func _switchback() -> void:
	_poly([[-23,-23],[-7,-24],[7,-22],[15,-17],[16,-11],[21,-9],[22,-2],[15,1],[9,4],[5,7],[-3,8],[-8,4],[-13,9],[-19,10],[-23,4]],base)
	_poly([[-23,-23],[-11,-24],[-7,-20],[-9,-14],[-15,-11],[-22,-12]],8.0)
	_poly([[-22,-11],[-15,-12],[-9,-14],[-3,-14],[0,-10],[-4,-5],[-11,-4],[-21,-5]],5.4)
	_house("whole_house",-16,8,-18,6,"YOUR HOME")
	_path([[-16,-15.8],[-13,-15.8],[-10.5,-15]],8.0)
	_house("house_2",-16,5.4,-8.2,4.7,"NEIGHBOR")
	_house("house_4",0,base,-9,6,"LIBRARY")
	_house("house_1",8.6,base,-8,7,"BEAST CENTER")
	_square(5,base,-1.7)
	_stairs(Vector3(-10.5,8,-15),Vector3(-10.5,5.4,-9))
	_path([[-10.5,-9],[-8,-8],[-6,-8]],5.4)
	_stairs(Vector3(-5.2,5.4,-7),Vector3(-5.2,base,0))
	_path([[-5,0],[0,0],[5,0],[12,0],[15,-2],[25,-2]],base)
	_house("hut_1",-15,base,4.9,4.5,"OLD GEAR SHACK")
	_path([[-5,0],[-5,3],[-9,3],[-10,6],[-15,7]],base)
	_stairs(Vector3(5.5,base,3),Vector3(5.5,1.05,7.5))
	_dock(7,11,6.5,7)
	_dock(13.5,12,7,2.6)
	_dock(19,10,6.5,6.6)
	_dock(19,4.5,2.8,5)
	_stairs(Vector3(19,1.05,2.2),Vector3(19,base,-2.2),2.8)
	_house("hut_4",7,1.05,10,4.6,"APOTHECARY")
	_house("hut_3",19,1.05,9,5.4,"DOCKSIDE HOME")
	_house("house_2",-1,base,-17,4.4,"NEIGHBOR")
	_house("hut_1",8,base,-16,4.2,"NEIGHBOR")
	labels.append(["TO COASTAL PATH · BRAM'S GATE",Vector3(23,base+0.5,-2)])
	_greenery([[-21,-20],[-20,-14],[-12,-22]],8.0)
	_greenery([[-22,-8],[-20,-10]],5.4)
	_greenery([[-21,0],[-20,6],[-9,-17],[15,-14],[17,-7]],base)


func _lagoon() -> void:
	_poly([[-23,-24],[-11,-25],[3,-24],[15,-22],[22,-15],[22,-7],[17,-1],[12,-2],[8,-5],[2,-4],[-4,-2],[-9,0],[-12,8],[-18,11],[-23,6]],base)
	_poly([[-22,-23],[-12,-24],[-8,-20],[-9,-15],[-14,-12],[-21,-13]],7.0)
	_poly([[-5,-23],[7,-24],[16,-20],[17,-14],[9,-13],[-2,-15]],5.4)
	_house("whole_house",-16,7,-18,5.8,"YOUR HOME")
	_house("house_2",2,5.4,-18.5,4.5,"NEIGHBOR")
	_house("hut_1",11,5.4,-18,4.6,"NEIGHBOR")
	_house("house_4",-5.2,base,-10,6.1,"LIBRARY")
	_house("house_1",4.6,base,-10,7.2,"BEAST CENTER")
	_square(0,base,-4)
	_path([[-16,-15],[-12,-15],[-12,-14]],7.0)
	_stairs(Vector3(-12,7,-14),Vector3(-12,base,-7))
	_path([[-12,-7],[-10,-6]],base)
	_path([[-10,-6],[-6,-6],[-5,-3],[0,-3],[8,-4],[16,-5],[25,-5]],base)
	_stairs(Vector3(16,base,-11),Vector3(16,5.4,-16))
	_path([[1,-14],[9,-14],[16,-16]],5.4)
	_path([[-10,-4],[-16,-2],[-17,3]],base)
	_house("hut_1",-17,base,3,4.7,"OLD GEAR SHACK")
	_stairs(Vector3(-12,base,3),Vector3(-9,1.05,6))
	_dock(-7.5,8,6.5,6)
	_dock(-2,10,5,2.6)
	_dock(2,10,3.4,2.6)
	_dock(7,8.4,7,6)
	_dock(14,9,7.5,2.8)
	_dock(19,5,6.5,7)
	_dock(19,0,2.8,4.5)
	_stairs(Vector3(19,1.05,-2),Vector3(19,base,-6))
	_house("hut_3",-7.5,1.05,7.5,5.6,"DOCKSIDE HOME")
	_house("house_2",7,1.05,7.5,4.5,"DOCKSIDE HOME")
	_house("hut_4",19,1.05,4.5,4.8,"APOTHECARY")
	labels.append(["TO COASTAL PATH · BRAM'S GATE",Vector3(23,base+0.5,-5)])
	_greenery([[-21,-19],[-20,-14],[-12,-22]],7)
	_greenery([[-21,-6],[-21,0],[-20,7],[-16,-9],[13,-9],[20,-13]],base)


func _camera() -> void:
	var view: String = opts.get("view", "overview")
	if view == "square":
		camera.size = 27
		var target := Vector3(0,base+1,-7)
		camera.position = target + Vector3(0,18,28)
		camera.look_at(target)
	elif view == "home":
		camera.size = 23
		var target := Vector3(-13,6.8,-15)
		camera.position = target + Vector3(5,15,25)
		camera.look_at(target)
	elif view == "harbour":
		camera.size = 37 if layout == "a" else 31
		var target := Vector3(-2,1.1,10) if layout == "a" else Vector3(1,1.1,5)
		camera.position = target + Vector3(8,18,24)
		camera.look_at(target)
	elif view == "apothecary":
		camera.size = 18
		var target := Vector3(18,base+1,-9)
		camera.position = target+Vector3(7,13,20)
		camera.look_at(target)
	else:
		camera.size = 61 if layout == "a" else (59 if layout == "b" else 55)
		var target := Vector3(0,1.5,-9 if layout == "b" else -6)
		camera.position = target + Vector3(16,43,48)
		camera.look_at(target)
	camera.current = true


func _gallery() -> void:
	_box(Vector3(0,-0.2,0),Vector3(60,0.4,48),"a3ae9a")
	var keys := ["house_1","house_2","house_3","house_4","hut_1","hut_2","hut_3","hut_4","whole_house"]
	if opts.has("model"):
		keys = [opts["model"],opts["model"],opts["model"],opts["model"]]
	for i in keys.size():
		var x := float(i % 3 - 1) * 14 if not opts.has("model") else float(i % 2) * 13 - 6.5
		var z := float(i / 3 - 1) * 13 if not opts.has("model") else float(i / 2) * 13 - 6.5
		var angle := i * 90.0 if opts.has("model") else 0.0
		var n := _model(keys[i],Vector3(x,0,z),8,angle)
		labels.append([keys[i] + (" / " + str(angle) if opts.has("model") else ""),Vector3(x,n.mesh.get_aabb().size.y*n.scale.y+0.5,z)])
	camera.size = 58 if not opts.has("model") else 36
	camera.position = Vector3(10,38,48)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	_overlay()


func _overlay() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color("102c32")
	panel.position = Vector2(36,32)
	panel.size = Vector2(740,118)
	canvas.add_child(panel)
	var names := {"a":"A  /  LANTERN HORSESHOE", "b":"B  /  SWITCHBACK VILLAGE", "c":"C  /  TIDECUP LAGOON", "gallery":"SUPPLIED BUILDINGS / ASSET STUDY"}
	_text(canvas,names.get(layout,"COCOON COVE"),Vector2(58,45),32,Color("fff0cc"))
	_text(canvas,"COCOON COVE   ·   EARLY ART STUDY",Vector2(58,91),24,Color("a9cebd"))
	var footer := ColorRect.new()
	footer.color = Color("102c32")
	footer.position = Vector2(36,986)
	footer.size = Vector2(1848,58)
	canvas.add_child(footer)
	_text(canvas,"ACTUAL PACK MODELS  /  WARM TIMBER + SEASIDE CLIFFS  /  LAND SQUARE  /  NO SHIPS  /  CONCEPT ONLY",Vector2(57,1001),23,Color("e7d9b9"))
	if opts.get("view","overview") != "overview" and layout != "gallery":
		return
	for entry in labels:
		var p := camera.unproject_position(entry[1])
		var title: String = entry[0]
		var text := Label.new()
		text.text = title
		text.add_theme_font_size_override("font_size",18)
		text.add_theme_color_override("font_color",Color("fff4d6"))
		text.add_theme_color_override("font_shadow_color",Color("102a2d"))
		text.add_theme_constant_override("shadow_offset_x",2)
		text.add_theme_constant_override("shadow_offset_y",2)
		text.add_theme_constant_override("outline_size",5)
		text.add_theme_color_override("font_outline_color",Color("173a3c"))
		text.position = p - Vector2(title.length()*5.3,10)
		canvas.add_child(text)


func _text(parent: Node, value: String, p: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = p
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
