extends RefCounted
## A continuous, inward-facing painted surround. A curved foot meets the stage without a hard floor/wall crease.
const DIR := "res://assets/battle/backdrops/"
const SHADER = preload("res://scripts/battle/backdrop.gdshader")
const StageLighting = preload("res://scripts/battle/stage_lighting.gd")
const SEGMENTS := 96
## Beyond every directed camera position, including the widest summon. The sky environment closes the top.
const PROFILE := [Vector2(29.0, -0.3), Vector2(29.3, 0.0), Vector2(29.6, 0.12), Vector2(30.0, 0.38),
	Vector2(30.35, 0.85), Vector2(30.6, 1.5), Vector2(30.75, 2.4), Vector2(30.8, 4.0), Vector2(30.8, 8.0), Vector2(30.8, 28.0)]
static var _mesh: ArrayMesh


static func build(biome: Dictionary, ground: Texture2D) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = "PaintedSurround"
	wall.mesh = mesh()
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("panorama", load(DIR + String(biome["id"]) + ".png"))
	mat.set_shader_parameter("ground_texture", ground)
	mat.set_shader_parameter("paint_tint", StageLighting.backdrop_tint(biome))
	mat.set_shader_parameter("edge_tint", StageLighting.edge_tint(biome))
	wall.material_override = mat
	return wall


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
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
	_mesh = out
	return out
