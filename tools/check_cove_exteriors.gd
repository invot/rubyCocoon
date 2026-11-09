extends SceneTree
## Verify that audited source apertures are occluded by opaque exterior geometry.
## Independent segment/triangle checks use points inside the source openings.

const DIR := "res://assets/exteriors/cove_"
var bad := 0
var rays := 0


func _init() -> void:
	for key in ["house_1","house_2","house_3","house_4","hut_1","hut_2","hut_3","hut_4","whole_house"]:
		var mesh: Mesh = load(DIR+key+".res")
		if mesh == null:
			_fail(key+" missing")
			continue
		if mesh.get_aabb().position.y < -0.001:
			_fail(key+" extends below ground")
		for si in mesh.get_surface_count():
			var material := mesh.surface_get_material(si) as BaseMaterial3D
			if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a < 0.999:
				_fail(key+" has a transparent exterior surface")
		for sample in _samples(key):
			var point: Vector3 = sample[0]
			var outward: Vector3 = sample[1]
			if key.begins_with("hut_"):
				point = Vector3(-point.x,point.y,-point.z)
				outward = -outward
			var from := point + outward * 0.6
			var to := point - outward * 0.25
			rays += 1
			if not _occluded(mesh,from,to):
				_fail("%s has an unsealed aperture at %s" % [key,point])
	print("COVE EXTERIORS DONE: %d aperture rays, %d problem(s)" % [rays,bad])
	quit(1 if bad else 0)


func _samples(key: String) -> Array:
	var result := []
	if key == "whole_house":
		for p in [Vector3(-0.3,1.3,3.50),Vector3(-3.75,2.0,3.50),Vector3(3.15,2.0,3.50),Vector3(3.1,6.1,3.50)]:
			result.append([p,Vector3.BACK])
		for p in [Vector3(-2.7,2.0,-3.50),Vector3(-2.6,5.4,-3.50),Vector3(-0.2,5.4,-3.50)]:
			result.append([p,Vector3.FORWARD])
		for z in [-0.6,2.0]:
			result.append([Vector3(-5.05,5.4,z),Vector3.LEFT])
		result.append([Vector3(-5.05,8.4,0.4),Vector3.LEFT])
		result.append([Vector3(5.05,8.4,0.4),Vector3.RIGHT])
	elif key == "house_1":
		for p in [Vector3(0.3,0.8,3.56),Vector3(-2.5,1.58,3.57),Vector3(2.5,1.58,3.57)]:
			result.append([p,Vector3.BACK])
	elif key == "house_2":
		for p in [Vector3(-1.4,0.7,1.50),Vector3(0.35,1.13,1.50)]:
			result.append([p,Vector3.BACK])
	elif key == "house_3":
		result.append([Vector3(-0.24,0.7,2.83),Vector3.BACK])
		result.append([Vector3(-2.0,6.0,-0.04),Vector3.BACK])
		for y in [1.30,4.22]:
			result.append([Vector3(-2.2,y,2.83),Vector3.BACK])
			for z in [-1.35,1.05]:
				result.append([Vector3(3.46,y,z),Vector3.RIGHT])
				result.append([Vector3(-3.46,y,z),Vector3.LEFT])
	elif key == "house_4":
		for p in [Vector3(-2.8,0.7,3.05),Vector3(0.5,2.4,3.05),Vector3(2.8,2.4,3.05)]:
			result.append([p,Vector3.BACK])
	else:
		var door_points := {"hut_1":Vector3(1.0,0.88,-2.10),"hut_2":Vector3(-0.3,0.89,-3.45),
			"hut_3":Vector3(-1.3,0.88,-1.98),"hut_4":Vector3(-1.1,0.87,-4.19)}
		result.append([door_points[key],Vector3.FORWARD])
		if key == "hut_1":
			for x in [-2.197,2.312]:
				result.append([Vector3(x,3.6,0.25),Vector3.LEFT if x<0 else Vector3.RIGHT])
		elif key == "hut_3":
			for x in [-4.306,3.903]:
				result.append([Vector3(x,3.6,0.25),Vector3.LEFT if x<0 else Vector3.RIGHT])
		elif key == "hut_4":
			result.append([Vector3(1.55,3.7,3.974),Vector3.BACK])
			result.append([Vector3(1.55,3.7,-4.358),Vector3.FORWARD])
			result.append([Vector3(-4.233,3.6,-2.0),Vector3.LEFT])
	return result


func _occluded(mesh: Mesh, from: Vector3, to: Vector3) -> bool:
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count,3):
			var a := vertices[indices[i] if not indices.is_empty() else i]
			var b := vertices[indices[i+1] if not indices.is_empty() else i+1]
			var c := vertices[indices[i+2] if not indices.is_empty() else i+2]
			if Geometry3D.segment_intersects_triangle(from,to,a,b,c) != null:
				return true
	return false


func _fail(message: String) -> void:
	bad += 1
	print("FAIL ",message)
