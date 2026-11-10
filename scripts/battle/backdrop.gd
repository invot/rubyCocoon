extends RefCounted
## A continuous, inward-facing painted surround. A curved foot meets the stage without a hard floor/wall crease.
const DIR := "res://assets/battle/backdrops/"
const SHADER = preload("res://scripts/battle/backdrop.gdshader")
const SEGMENTS := 96
const PROFILE := [Vector2(12.5, -0.3), Vector2(12.8, 0.0), Vector2(13.1, 0.12), Vector2(13.5, 0.38),
	Vector2(13.85, 0.85), Vector2(14.1, 1.5), Vector2(14.25, 2.4), Vector2(14.3, 4.0), Vector2(14.3, 8.0), Vector2(14.3, 18.0)]


static func build(biome: Dictionary, ground: Texture2D) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = "PaintedSurround"
	wall.mesh = mesh()
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("panorama", load(DIR + String(biome["id"]) + ".png"))
	mat.set_shader_parameter("ground_texture", ground)
	wall.material_override = mat
	return wall


static func mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in PROFILE.size():
		var p: Vector2 = PROFILE[row]
		var slope: Vector2 = PROFILE[mini(row + 1, PROFILE.size() - 1)] - PROFILE[maxi(0, row - 1)]
		for i in SEGMENTS + 1:
			var angle := TAU * float(i) / SEGMENTS
			var radial := Vector3(cos(angle), 0, sin(angle))
			vertices.append(radial * p.x + Vector3(0, p.y, 1.5))
			normals.append((-radial * slope.y + Vector3.UP * slope.x).normalized())
			uvs.append(Vector2(float(i) / SEGMENTS, 1.0 - clampf(p.y / 9.0, 0.0, 1.0)))
	for row in PROFILE.size() - 1:
		for i in SEGMENTS:
			var a := row * (SEGMENTS + 1) + i
			var b := a + 1
			var c := b + SEGMENTS + 1
			var d := a + SEGMENTS + 1
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
