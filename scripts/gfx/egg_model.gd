extends RefCounted
## Rounded painted shells with species-specific silhouettes; no voxel filtering or generated disk assets.
const Looks = preload("res://scripts/data/egg_looks.gd")
const RADIUS := 0.52
const HEIGHT := 1.06
## How much narrower the shell's crown is than its base.
const TAPER := 0.22


## The shell's radius at a height above its base, for anything that has to touch it (the hatchery's tongs).
static func radius_at(height: float, width: float) -> float:
	var half := HEIGHT * 0.5
	return RADIUS * width * (1.0 - height / HEIGHT * TAPER) * sqrt(maxf(0.0, 1.0 - pow((height - half) / half, 2)))


static func build(egg: Dictionary) -> Node3D:
	var root := Node3D.new()
	var d := Looks.look(egg)
	var shell := StandardMaterial3D.new()
	shell.albedo_texture = Looks.shell_texture(egg)
	shell.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	shell.roughness = 0.48
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = HEIGHT
	mesh.radial_segments = 48
	mesh.rings = 24
	# A narrow crown and generous lower half make a true egg silhouette.
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var taper := 1.0 - (verts[i].y / HEIGHT + 0.5) * TAPER
		verts[i].x *= taper * float(d.width)
		verts[i].z *= taper * float(d.width)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var rounded := ArrayMesh.new()
	rounded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = rounded
	mi.material_override = shell
	mi.position.y = HEIGHT * 0.5
	root.add_child(mi)
	var mark := StandardMaterial3D.new()
	mark.albedo_color = d.mark
	mark.roughness = 0.55
	if d.radiant:
		mark.emission_enabled = true
		mark.emission = d.mark
		mark.emission_energy_multiplier = 0.65
	var count := 5 if d.crown in ["leaves", "feathers", "plates"] else (1 if d.crown == "horn" else 2)
	for i in count:
		var a := TAU * float(i) / count + 0.4
		var crown := MeshInstance3D.new()
		var part := SphereMesh.new()
		part.radius = 0.13 if d.crown == "buds" else 0.08
		part.height = 0.24 if d.crown == "buds" else 0.48
		part.radial_segments = 16
		part.rings = 8
		crown.mesh = part
		crown.material_override = mark
		crown.position = Vector3(cos(a) * 0.20, HEIGHT * 0.9, sin(a) * 0.20)
		crown.rotation = Vector3(sin(a) * 0.5, a, cos(a) * -0.5)
		if d.crown in ["leaves", "feathers", "fin", "plates"]:
			crown.scale = Vector3(1.7, 1.0, 0.30)
		root.add_child(crown)
	return root
