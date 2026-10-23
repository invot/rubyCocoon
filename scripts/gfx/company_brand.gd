extends RefCounted
## Mounted company signage shared by the prologue and Gearhart's office.
const LOGO = preload("res://assets/branding/gearheart_industries.svg")


static func sign_node(width := 8.4) -> Node3D:
	var root := Node3D.new()
	root.name = "GearheartIndustriesSign"
	var height := width * 320.0 / 1024.0
	var back := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(width + 0.16, height + 0.16, 0.16)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#986e43")
	metal.metallic = 0.65
	metal.roughness = 0.45
	block.material = metal
	back.mesh = block
	root.add_child(back)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var print_mat := StandardMaterial3D.new()
	print_mat.albedo_texture = LOGO
	print_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	print_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material = print_mat
	face.mesh = quad
	face.position.z = 0.087
	root.add_child(face)
	return root
