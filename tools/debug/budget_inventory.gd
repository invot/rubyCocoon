extends RefCounted
## CPU-side source complexity, independent of renderer LOD/occlusion decisions.
var _meshes := {}


func collect(root: Node3D, camera: Camera3D) -> Dictionary:
	var headless := DisplayServer.get_name() == "headless"
	var result := {"geometry_nodes": 0, "surface_submissions": 0, "source_triangles": 0,
		"distinct_materials": 0, "transparent_surfaces": 0, "cutout_surfaces": 0,
		"texture_rgba8_mip_bytes": 0, "distinct_textures": 0, "unsupported_textures": [],
		"scope": "whole subtree including hidden; source capacity, not visible draws" if headless else "visible source-AABB frustum estimate; base LOD/full batch capacity"}
	var materials := {}
	var textures := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if not headless and (not node.is_visible_in_tree() or node.layers & camera.cull_mask == 0):
			continue
		var mesh: Mesh = null
		var instances := 1
		if node is MeshInstance3D or node is CPUParticles3D:
			mesh = node.mesh
			if node is CPUParticles3D:
				instances = node.amount # Capacity, including residual/nonemitting particles.
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		if mesh == null or instances == 0:
			continue
		var source := _mesh_source(mesh)
		var bounds: AABB = source.bounds
		if node is MultiMeshInstance3D and not headless:
			bounds = node.multimesh.get_instance_transform(0) * source.bounds
			for i in range(1, instances):
				bounds = bounds.merge(node.multimesh.get_instance_transform(i) * source.bounds)
		elif node is CPUParticles3D:
			bounds = node.visibility_aabb
		bounds = node.global_transform * bounds.grow(node.extra_cull_margin)
		# Dummy RenderingServer does not retain usable MultiMesh transforms/AABBs.
		# Headless checks therefore guard the whole subtree, never pretend to count in-view geometry.
		if not headless and not _in_frustum(bounds, camera):
			continue
		result.geometry_nodes += 1
		result.source_triangles += source.triangles * instances
		for surface in mesh.get_surface_count():
			var material: Material = node.material_override
			if material == null:
				material = node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
			_surface(material, result, materials, textures, {})
		if node.material_overlay != null:
			_surface(node.material_overlay, result, materials, textures, {})
	result.distinct_materials = materials.size()
	result.distinct_textures = textures.size()
	return result


func _mesh_source(mesh: Mesh) -> Dictionary:
	var id := mesh.get_instance_id()
	if _meshes.has(id):
		return _meshes[id]
	var bounds := AABB()
	var first := true
	var triangles := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if first:
				bounds = AABB(vertex, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(vertex)
		var count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else vertices.size()
		var primitive: int = mesh.surface_get_primitive_type(s) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			triangles += count / 3
		elif primitive == Mesh.PRIMITIVE_TRIANGLE_STRIP:
			triangles += maxi(0, count - 2)
	var value := {"bounds": bounds, "triangles": triangles}
	# Hold the resource too: a freed mesh's instance ID must not alias a later mesh.
	_meshes[id] = {"bounds": bounds, "triangles": triangles, "resource": mesh}
	return value


static func _in_frustum(bounds: AABB, camera: Camera3D) -> bool:
	for plane in camera.get_frustum():
		var inside := false
		for corner in 8:
			if not plane.is_point_over(bounds.get_endpoint(corner)):
				inside = true
				break
		if not inside:
			return false
	return true


func _surface(material: Material, result: Dictionary, materials: Dictionary, textures: Dictionary, chain: Dictionary) -> void:
	result.surface_submissions += 1
	if material == null or chain.has(material.get_instance_id()):
		return
	chain[material.get_instance_id()] = true
	var transparent := false
	var cutout := false
	if material is BaseMaterial3D:
		transparent = material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
		cutout = material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]
	elif material is ShaderMaterial and material.shader != null:
		cutout = "ALPHA_SCISSOR_THRESHOLD" in material.shader.code or "ALPHA_HASH_SCALE" in material.shader.code
		transparent = "ALPHA" in material.shader.code and not cutout # Conservative source classification.
	result.transparent_surfaces += int(transparent)
	result.cutout_surfaces += int(cutout)
	if not materials.has(material.get_instance_id()):
		materials[material.get_instance_id()] = true
		if material is ShaderMaterial and material.shader != null:
			for uniform in material.shader.get_shader_uniform_list():
				var value = material.get_shader_parameter(uniform.name)
				if value is Texture:
					_texture(value, result, textures)
		else:
			for property in material.get_property_list():
				if property.type == TYPE_OBJECT:
					var value = material.get(property.name)
					if value is Texture:
						_texture(value, result, textures)
	if material.next_pass != null:
		_surface(material.next_pass, result, materials, textures, chain)


func _texture(texture: Texture, result: Dictionary, textures: Dictionary) -> void:
	if texture is AtlasTexture:
		if texture.atlas != null:
			_texture(texture.atlas, result, textures)
		return
	if textures.has(texture.get_instance_id()):
		return
	textures[texture.get_instance_id()] = true
	var pixels := 0
	if texture is Texture2D:
		pixels = texture.get_width() * texture.get_height()
	elif texture is TextureLayered:
		pixels = texture.get_width() * texture.get_height() * texture.get_layers()
	elif texture is Texture3D:
		pixels = texture.get_width() * texture.get_height() * texture.get_depth()
	else:
		result.unsupported_textures.append(texture.get_class())
	# Declared RGBA8-equivalent full mip chain. Neither actual format nor resident VRAM.
	result.texture_rgba8_mip_bytes += ceili(pixels * 4.0 * 4.0 / 3.0)
