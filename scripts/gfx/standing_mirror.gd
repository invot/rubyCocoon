extends RefCounted
## The hero's standing mirror: a chunky wooden frame (HomeDecor.frame_mesh) on two stout feet, its glass the frame's
## canvas (surface 1). The character creator's (hero_maker.gd) shows the room in its glass from a second camera; the
## one against the back wall of the hero's bedroom (room_builder.gd, furniture "mirror") has a soft silvered sheen
## and opens the wardrobe when you look in it (Places.prop).

const HomeDecor = preload("res://scripts/gfx/home_decor.gd")

## the glass's width and height, inside the frame
const SIZE := Vector2(0.78, 1.62)
## how high the feet hold the frame off the floor
const LIFT := 0.12
## the feet's depth, front to back (the mirror's footprint)
const FOOT_DEPTH := 0.42

static var _silver: StandardMaterial3D


## The mirror standing at its holder's origin, facing +z, with `glass` on its canvas.
static func build(glass: Material) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Mirror"
	var wood: Material = HomeDecor.atlas_material("jewel_pop")
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = HomeDecor.frame_mesh(SIZE.x, SIZE.y, false)
	frame.set_surface_override_material(0, wood)
	frame.set_surface_override_material(1, glass)
	frame.position.y = LIFT + SIZE.y / 2.0
	holder.add_child(frame)
	# its feet: two chubby blocks it stands on, in the frame's wood
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		HomeDecor._box(st, Vector3(side * (SIZE.x / 2.0 - 0.08), 0.07, 0.0), Vector3(0.16, 0.14, FOOT_DEPTH), Color(0, 0, 1, 0), HomeDecor.WOOD_CELL)
	var feet := MeshInstance3D.new()
	feet.name = "Feet"
	feet.mesh = st.commit()
	feet.material_override = wood
	holder.add_child(feet)
	return holder


## Every part of a mirror on render layers `layers`.
static func set_layers(holder: Node3D, layers: int) -> void:
	for child in holder.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = layers


## The bedroom mirror's glass: a cool silvered gradient with a soft diagonal sheen, painted rather than reflecting
## (a second camera rendering the room every frame would cost a phone too much for one mirror).
static func silvered() -> StandardMaterial3D:
	if _silver == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.38, 0.47, 0.56, 1.0])
		g.colors = PackedColorArray([Color("#9fb0bd"), Color("#c4d2dc"), Color("#eef4f7"), Color("#c4d2dc"), Color("#8c9daa")])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.width = 64
		tex.height = 128
		tex.fill_from = Vector2(0.0, 0.0)
		tex.fill_to = Vector2(1.0, 1.0)
		_silver = StandardMaterial3D.new()
		_silver.albedo_texture = tex
		_silver.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_silver.roughness = 0.2
		_silver.metallic_specular = 0.8
	return _silver
