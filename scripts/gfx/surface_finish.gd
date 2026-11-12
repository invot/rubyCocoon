extends RefCounted
## Every 3D object is textured (AGENTS.md, Art and animation consistency): a lit material that would draw as bare flat
## colour gets one of the soft surfaces painted by tools/build_soft_textures.py instead, mapped triplanar in the
## object's own units so it needs no UVs: brushed metal on metal, soft paint on everything else. The textures are just
## under white, so a surface keeps the colour it had. Each material is finished once, in place (they are the game's own
## generated or baked materials, shared between meshes, and never saved back to disk).
## Light rather than objects stays as it is: unshaded materials (glows, lamps, flames, effects) and see-through effects.
## render_quality.gd finishes every geometry node as it enters the tree; builders that copy materials straight away
## (the buildings' arrival fade) finish their node first with apply().
const DIR := "res://assets/textures/surfaces/"
## world units one texture repeat covers
const SPAN := 2.0
const DONE := &"surface_finished"

## (off for measuring what the finishes cost: --scene=field-perf --finish=0)
static var enabled := true
static var _textures := {}
static var _means := {}


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(DIR + name + ".png") if ResourceLoader.exists(DIR + name + ".png") else null
	return _textures[name]


## A finish's average brightness: dividing it out leaves a surface's colour as authored on average.
static func mean(name: String) -> float:
	if not _means.has(name):
		var m := 1.0
		var tex := texture(name)
		if tex != null:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
			var sum := 0.0
			for y in 16:
				for x in 16:
					sum += img.get_pixel(x, y).get_luminance()
			m = clampf(sum / 256.0, 0.5, 1.0)
		_means[name] = m
	return _means[name]


## Finishes every geometry node under (and including) root.
static func apply(root: Node) -> void:
	if root is GeometryInstance3D:
		node(root)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		node(n)


static func node(gi: GeometryInstance3D) -> void:
	material(gi.material_override)
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = gi.mesh
		for s in gi.get_surface_override_material_count():
			material(gi.get_surface_override_material(s))
	elif gi is MultiMeshInstance3D and gi.multimesh != null:
		mesh = gi.multimesh.mesh
	if mesh != null:
		for s in mesh.get_surface_count():
			material(mesh.surface_get_material(s))


static func needs(mat: Material) -> bool:
	if not mat is BaseMaterial3D or mat.has_meta(DONE):
		return false
	var m: BaseMaterial3D = mat
	if m.albedo_texture != null or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	# a see-through effect (glass, ripples, beams), not a fading solid
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.albedo_color.a < 0.95:
		return false
	return true


static func material(mat: Material) -> void:
	if not enabled or not needs(mat):
		return
	var m: BaseMaterial3D = mat
	m.set_meta(DONE, true)
	var name := "brushed" if m.metallic >= 0.3 else "soft"
	var tex := texture(name)
	if tex == null:
		return
	m.albedo_texture = tex
	var k := 1.0 / mean(name)
	m.albedo_color = Color(m.albedo_color.r * k, m.albedo_color.g * k, m.albedo_color.b * k, m.albedo_color.a)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / SPAN
