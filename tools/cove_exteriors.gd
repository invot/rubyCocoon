extends RefCounted
## Bake-time exterior repairs for the supplied kit. Opaque panes and closed door
## leaves cover the source apertures; render-time culling is not used as a closure.
## Authored coordinates are in the centered, grounded source meshes' metres.

const Bake = preload("res://tools/psx_bake.gd")
const PLASTER := Color("dfd0ae")
const TIMBER := Color("b18b55")
const ROOF := Color("bb704d")
const GLASS := Color("42666b")
const DOOR := Color("967246")
const FRAME := Color("bc9965")
const GLEAM := Color("a1bcb4")
const BRASS := Color("c8ad6c")

var parts := {}


func finish(mesh: ArrayMesh, key: String) -> ArrayMesh:
	parts.clear()
	if key == "whole_house":
		mesh = _whole_materials(mesh)
		_box(Vector3(0,3.77,0.04),Vector3(9.96,7.54,6.94),PLASTER)
		for x in [-5.02,5.02]:
			_triangle([Vector3(x,7.5,-3.5),Vector3(x,10.35,0),Vector3(x,7.5,3.5)],PLASTER)
		_door(Vector3(-0.03,1.11,3.60),Vector2(1.43,2.24))
		for entry in [[-3.51,2.18,1.40,1.52],[3.37,2.18,1.40,1.52],[3.37,6.38,1.73,1.48]]:
			_window(Vector3(entry[0],entry[1],3.59),Vector2(entry[2],entry[3]))
		for entry in [[-2.47,2.18,1.40,1.52],[-2.35,5.62,1.96,1.40],[0.05,5.62,1.96,1.40]]:
			_window(Vector3(entry[0],entry[1],-3.59),Vector2(entry[2],entry[3]),180)
		for z in [-0.36,2.20]:
			_window(Vector3(-5.09,5.62,z),Vector2(1.90,1.40),-90)
	elif key == "house_1":
		_box(Vector3(0,1.54,0),Vector3(8.96,3.08,7.08),PLASTER)
		_door(Vector3(0,1.0,3.61),Vector2(2.42,2.04))
		for x in [-2.766,2.765]:
			_window(Vector3(x,1.765,3.61),Vector2(1.16,0.81))
	elif key == "house_2":
		_box(Vector3(0,1.36,0),Vector3(4.27,2.72,2.96),PLASTER)
		_door(Vector3(-1.40,0.94,1.56),Vector2(1.06,1.90))
		_window(Vector3(0.617,1.30,1.535),Vector2(1.17,0.81))
	elif key == "house_3":
		_box(Vector3(0,2.56,0),Vector3(6.86,5.12,5.62),PLASTER)
		_box(Vector3(-1.75,6.065,-1.145),Vector3(2.39,1.87,2.19),PLASTER)
		_door(Vector3(-0.246,0.94,2.89),Vector2(1.06,1.90))
		_door(Vector3(-1.994,6.07,0.005),Vector2(1.06,1.90))
		for y in [1.463,4.388]:
			_window(Vector3(-1.983,y,2.87),Vector2(1.17,0.81))
			for z in [-1.11,1.279]:
				_window(Vector3(3.50,y,z),Vector2(1.17,0.81),90)
				_window(Vector3(-3.50,y,z),Vector2(1.17,0.81),-90)
	elif key == "house_4":
		_box(Vector3(0,2.56,0),Vector3(8.07,5.12,5.99),PLASTER)
		_door(Vector3(-2.81,0.94,3.14),Vector2(1.06,1.90))
		# Former open loading bays become opaque, framed shopfront glazing.
		for x in [-0.03,2.41]:
			_window(Vector3(x,2.05,3.15),Vector2(2.44,4.12))
	elif key.begins_with("hut_"):
		var doors := {"hut_1":Vector3(1.1905,1.10,-2.18),"hut_2":Vector3(-0.1035,1.125,-3.54),
			"hut_3":Vector3(-1.1435,1.10,-2.07),"hut_4":Vector3(-0.9475,1.08,-4.28)}
		_door(doors[key],Vector2(1.10,2.20),180)
		if key == "hut_1":
			_box(Vector3(0.057,1.57,0),Vector3(4.45,3.14,4.08),TIMBER)
			for x in [-2.197,2.312]:
				_triangle([Vector3(x,4.521,-0.057),Vector3(x,3.158,2.477),Vector3(x,3.159,-2.591)],TIMBER)
		elif key == "hut_3":
			_box(Vector3(-0.20,1.57,0),Vector3(8.12,3.14,3.82),TIMBER)
			for x in [-4.306,3.903]:
				_triangle([Vector3(x,4.513,0.057),Vector3(x,3.15,-2.477),Vector3(x,3.15,2.591)],TIMBER)
		elif key == "hut_4":
			for z in [-4.358,3.974]:
				_triangle([Vector3(1.771,4.629,z),Vector3(-0.822,3.266,z),Vector3(4.364,3.266,z)],TIMBER)
			_triangle([Vector3(-4.233,4.553,-2.227),Vector3(-4.233,3.191,0.307),Vector3(-4.233,3.191,-4.761)],TIMBER)
	for color in parts:
		var material := _material(Color(color))
		var tool: SurfaceTool = parts[color]
		tool.set_material(material)
		tool.commit(mesh)
	if key.begins_with("hut_"):
		# The kit's hut doors face -Z; the game's street-facing doors face +Z.
		mesh = Bake.turned(mesh,180)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic_specular = 0.14
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _part(color: Color) -> SurfaceTool:
	var key := color.to_html()
	if not parts.has(key):
		var t := SurfaceTool.new()
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[key] = t
	return parts[key]


func _box(position: Vector3, size: Vector3, color: Color, angle := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(color).append_from(mesh,0,Transform3D(Basis(Vector3.UP,deg_to_rad(angle)),position))


func _triangle(vertices: Array, color: Color) -> void:
	var tool := _part(color)
	var normal: Vector3 = (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	# Both faces are physical closures, with no reliance on a transparent shader.
	for order in [[0,1,2],[2,1,0]]:
		for i in order:
			tool.set_normal(normal if order[0]==0 else -normal)
			tool.set_uv(Vector2.ZERO)
			tool.add_vertex(vertices[i])


func _offset(base: Vector3, relative: Vector3, angle: float) -> Vector3:
	return base + Basis(Vector3.UP,deg_to_rad(angle)) * relative


func _window(p: Vector3, size: Vector2, angle := 0.0) -> void:
	p.y = maxf(p.y,size.y*0.5+0.07)
	_box(p,Vector3(size.x+0.14,size.y+0.14,0.10),FRAME,angle)
	_box(_offset(p,Vector3(0,0,0.065),angle),Vector3(size.x,size.y,0.06),GLASS,angle)
	_box(_offset(p,Vector3(0,0,0.105),angle),Vector3(0.055,size.y,0.04),FRAME,angle)
	_box(_offset(p,Vector3(0,0,0.105),angle),Vector3(size.x,0.055,0.04),FRAME,angle)
	_box(_offset(p,Vector3(-size.x*0.18,size.y*0.32,0.102),angle),Vector3(size.x*0.50,0.055,0.012),GLEAM,angle)


func _door(p: Vector3, size: Vector2, angle := 0.0) -> void:
	p.y = maxf(p.y,size.y*0.5+0.06)
	_box(p,Vector3(size.x+0.14,size.y+0.12,0.13),FRAME,angle)
	_box(_offset(p,Vector3(0,0,0.09),angle),Vector3(size.x,size.y,0.10),DOOR,angle)
	for i in [-1,0,1]:
		_box(_offset(p,Vector3(i*size.x*0.25,-size.y*0.15,0.15),angle),Vector3(0.024,size.y*0.60,0.02),TIMBER,angle)
	_box(_offset(p,Vector3(0,size.y*0.25,0.15),angle),Vector3(size.x*0.59,size.y*0.24,0.04),GLASS,angle)
	_box(_offset(p,Vector3(size.x*0.32,-size.y*0.07,0.20),angle),Vector3(0.09,0.09,0.08),BRASS,angle)


func _whole_materials(source: ArrayMesh) -> ArrayMesh:
	# The original high-frequency orange atlas clashes with Towns' simple finishes.
	# Preserve its geometry and classify its atlas islands into the kit's three roles.
	var by_role := {}
	for si in source.get_surface_count():
		var arrays := source.surface_get_arrays(si)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var mat: BaseMaterial3D = source.surface_get_material(si)
		var image: Image = mat.albedo_texture.get_image()
		for i in range(0,indices.size(),3):
			var mid := (uv[indices[i]]+uv[indices[i+1]]+uv[indices[i+2]])/3.0
			var color := image.get_pixel(clampi(int(mid.x*image.get_width()),0,image.get_width()-1),clampi(int(mid.y*image.get_height()),0,image.get_height()-1))
			var average_y := (vertices[indices[i]].y+vertices[indices[i+1]].y+vertices[indices[i+2]].y)/3.0
			var roof_face := mid.x<0.125 and average_y>6.5
			var role := "roof" if roof_face else ("timber" if color.s>0.60 else "plaster")
			if not by_role.has(role):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_role[role] = tool
			var t: SurfaceTool = by_role[role]
			for j in 3:
				var v := indices[i+j]
				t.set_normal(normals[v])
				t.set_uv(uv[v])
				t.add_vertex(vertices[v])
	var out := ArrayMesh.new()
	for role in by_role:
		var tool: SurfaceTool = by_role[role]
		tool.set_material(_material({"roof":ROOF,"timber":Color("97754d"),"plaster":Color("e8dfc8")}[role]))
		tool.commit(out)
	return out
