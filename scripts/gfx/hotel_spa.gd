extends RefCounted
## Hotel spa dressing; navigation and steps come from the room's shared dais. The healing spring itself is walked into
## by its own front steps (world.gd _spa_way, _soak).

static func build(parent: Node3D, at: Vector3, tile: Material, ivory: Material) -> void:
	var spa := Node3D.new()
	spa.name = "HotelSpa"
	spa.position = at
	parent.add_child(spa)
	var basin := CylinderMesh.new()
	basin.top_radius = 1.06
	basin.bottom_radius = 1.06
	basin.height = 0.08
	basin.radial_segments = 48
	var lining := (ivory as StandardMaterial3D).duplicate() as StandardMaterial3D
	lining.albedo_color = Color("#f5c7d9")
	_piece(spa, basin, lining, Vector3(0, 0.04, 0))
	var wall := TorusMesh.new()
	wall.inner_radius = 0.86
	wall.outer_radius = 1.1
	wall.rings = 48
	wall.ring_segments = 16
	var sides := _piece(spa, wall, tile, Vector3(0, 0.23, 0))
	sides.scale.y = 1.9
	var rim := TorusMesh.new()
	rim.inner_radius = 0.87
	rim.outer_radius = 1.12
	rim.rings = 48
	rim.ring_segments = 12
	var lip := _piece(spa, rim, ivory, Vector3(0, 0.43, 0))
	lip.scale.y = 0.55
	var pool := CylinderMesh.new()
	pool.top_radius = 0.91
	pool.bottom_radius = 0.91
	pool.height = 0.025
	pool.radial_segments = 48
	var water := ShaderMaterial.new()
	water.shader = preload("res://scripts/gfx/water.gdshader")
	var textures = preload("res://scripts/gfx/voxel_textures.gd")
	water.set_shader_parameter("frames", textures.frames("water"))
	water.set_shader_parameter("frame_count", float(textures.WATER_FRAMES))
	water.set_shader_parameter("tint", Color("#edafc9"))
	water.set_shader_parameter("shallow_tint", Color("#eab0c7"))
	water.set_shader_parameter("deep_tint_scale", Vector3(0.85, 0.85, 0.85))
	water.set_shader_parameter("opacity", 0.84)
	water.set_shader_parameter("drift", Vector2(0.0, 0.03))
	var surface := _piece(spa, pool, water, Vector3(0, 0.425, 0))
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_steps(spa, tile, ivory)
	_steam(spa)


## The way in (world.gd _spa_way): one low curved step outside the rim, below its lip, centred on the line you walk in
## by, the front-right tile's middle (ENTRY_X right of the spring's middle, walking north), and as wide as that tile.
## [inner radius, outer radius, top] from the spring's middle.
const STEP := [1.12, 1.42, 0.25]
const ENTRY_X := 0.5
const STEP_ARC := 21.0


static func _steps(parent: Node3D, tile: Material, ivory: Material) -> void:
	var r: float = (STEP[0] + STEP[1]) / 2.0
	var turn := asin(ENTRY_X / r)
	var top: float = STEP[2]
	var block := _piece(parent, _arc(STEP[0], STEP[1], 0.0, top - 0.04, STEP_ARC), tile, Vector3.ZERO)
	var cap := _piece(parent, _arc(STEP[0], STEP[1] + 0.02, top - 0.05, top, STEP_ARC + 1.0), ivory, Vector3.ZERO)
	block.rotation.y = turn
	cap.rotation.y = turn


## A solid curved slab: the ring between radii r0 and r1, from y0 to y1, `half` degrees either side of +z.
static func _arc(r0: float, r1: float, y0: float, y1: float, half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var at := func(r: float, a: float, y: float) -> Vector3: return Vector3(sin(a) * r, y, cos(a) * r)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v in [a, c, b, a, d, c]:
			st.add_vertex(v)
	for k in n:
		var a0 := deg_to_rad(lerpf(-half, half, float(k) / n))
		var a1 := deg_to_rad(lerpf(-half, half, float(k + 1) / n))
		quad.call(at.call(r0, a0, y1), at.call(r1, a0, y1), at.call(r1, a1, y1), at.call(r0, a1, y1))
		quad.call(at.call(r1, a0, y1), at.call(r1, a0, y0), at.call(r1, a1, y0), at.call(r1, a1, y1))
		quad.call(at.call(r0, a1, y1), at.call(r0, a1, y0), at.call(r0, a0, y0), at.call(r0, a0, y1))
	for a in [deg_to_rad(-half), deg_to_rad(half)]:
		var s := 1.0 if a < 0.0 else -1.0
		var p := [at.call(r0, a, y1), at.call(r0, a, y0), at.call(r1, a, y0), at.call(r1, a, y1)]
		if s > 0.0:
			quad.call(p[0], p[1], p[2], p[3])
		else:
			quad.call(p[3], p[2], p[1], p[0])
	st.generate_normals()
	return st.commit()


## The spa's small plaque: how big it is, and how high its middle stands above the platform (under the railing's
## handrail).
const PLAQUE_SIZE := Vector2(0.78, 0.34)
const PLAQUE_UP := 0.66
## The plaque hangs on the platform's front railing along fixture tile (x, y)'s south side, centred on the tile's west
## edge, facing the camera: its back this far south of the tile's middle, just in front of the railing's slats (the run
## is 0.42 out, room_builder.gd _daises, its slats 0.065 thick), and deep enough that its face stands in front of the
## posts (0.145) too, so no part of the railing shows through it.
const PLAQUE_BACK := 0.49
const PLAQUE_DEPTH := 0.09


## Where the plaque's middle is for its fixture tile `t` on a platform `dais_h` high.
static func plaque_at(t: Vector2i, dais_h: float) -> Vector3:
	return Vector3(t.x, dais_h + PLAQUE_UP, t.y + 0.5 + PLAQUE_BACK)


## The spa's small plaque on the platform's front railing at fixture tile `t`, facing the camera: an ivory board with
## the steam glyph and two words of world lettering.
static func plaque(parent: Node3D, t: Vector2i, dais_h: float, ivory: Material) -> void:
	plaque_on(parent, plaque_at(t, dais_h), ivory)


## A spa whose sign hangs on a wall instead (Dale's cave spring): the fixture is the wall tile `t` itself, read from
## the floor in front of it, the plaque on its south face this high above floor level `floor_y`.
const WALL_UP := 1.25
const WALL_OUT := 0.16


static func wall_plaque_at(t: Vector2i, floor_y: float) -> Vector3:
	return Vector3(t.x + 0.5, floor_y + WALL_UP, t.y + 1.0 + WALL_OUT)


## Every healing spring has this sign explaining it (Places.prop "hot_tub_sign"), at `at`, facing the camera.
static func plaque_on(parent: Node3D, at: Vector3, ivory: Material) -> void:
	var plate := Node3D.new()
	plate.name = "SpaPlaque"
	plate.position = at
	parent.add_child(plate)
	var board := BoxMesh.new()
	board.size = Vector3(PLAQUE_SIZE.x, PLAQUE_SIZE.y, PLAQUE_DEPTH)
	_piece(plate, board, ivory, Vector3(0, 0, PLAQUE_DEPTH / 2.0))
	var logo := QuadMesh.new()
	logo.size = Vector2(0.24, 0.24)
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = load("res://assets/ui/icons/glyphs/spa_steam.png")
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_piece(plate, logo, ink, Vector3(-0.24, 0, PLAQUE_DEPTH + 0.002))
	var words := Label3D.new()
	preload("res://scripts/gfx/world_lettering.gd").apply(words, "THERMAL\nSANCTUARY")
	words.font_size = 32
	words.pixel_size = 0.0022
	words.outline_size = 0
	words.modulate = Color("#49393c")
	words.position = Vector3(0.1, 0, PLAQUE_DEPTH + 0.003)
	plate.add_child(words)

static func _piece(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	parent.add_child(piece)
	return piece

static func _steam(parent: Node3D) -> void:
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.position.y = 0.49
	steam.amount = 20
	steam.lifetime = 2.8
	steam.preprocess = 2.8
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam.emission_box_extents = Vector3(0.65, 0.01, 0.65)
	steam.direction = Vector3.UP
	steam.spread = 18.0
	steam.gravity = Vector3(0.025, 0.035, 0)
	steam.initial_velocity_min = 0.16
	steam.initial_velocity_max = 0.28
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.1
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.94, 0.96, 0))
	fade.add_point(0.2, Color(1, 0.94, 0.96, 0.32))
	fade.add_point(0.6, Color(1, 0.97, 0.98, 0.2))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	steam.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.5))
	steam.scale_amount_curve = grow
	var puff := GradientTexture2D.new()
	puff.width = 64
	puff.height = 64
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color.WHITE)
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	var mist := StandardMaterial3D.new()
	mist.albedo_texture = puff
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist.vertex_color_use_as_albedo = true
	mist.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = mist
	steam.mesh = quad
	parent.add_child(steam)
