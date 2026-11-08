extends RefCounted
## The hatching vault's baked geometry and painted textures, saved by tools/import_hatchery.gd: an egg-shaped stone
## shell with curved ribs (the inside of a great cocoon), stepped plinth, flagstone floor and a horseshoe of lanterns
## open towards the camera. Textures are soft painted courses with no grain; tools/smooth_textures.gd finishes them.
const Stage = preload("res://scripts/gfx/hatchery_stage.gd")
const ANISO := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
const SEG := 72
const RIBS := 18
## Width of the three blocks in one repeat of the course texture, per surface.
const FLOOR_TILE := 5.4
const WALL_TILE := 6.6
## Repeats of those three blocks around the base. One count from floor to top keeps every joint on the same radial line.
const PLINTH_RUNS := 6.0
## Inner face of the shell, from the oculus down to the floor, as (radius, height).
const SHELL := [Vector2(2.4, 15.0), Vector2(5.4, 14.2), Vector2(8.4, 12.6), Vector2(10.5, 10.2), Vector2(11.7, 7.6),
	Vector2(12.3, 4.8), Vector2(12.4, 2.2), Vector2(12.2, 0.0)]
## Stepped plinth, climbing from the floor to the platform's seat.
const PLINTH := [Vector2(3.85, 0.0), Vector2(3.85, 0.20), Vector2(3.76, 0.28), Vector2(3.02, 0.28), Vector2(3.02, 0.46),
	Vector2(2.93, 0.54), Vector2(2.22, 0.54), Vector2(2.22, 0.70), Vector2(2.13, 0.77), Vector2(1.5, 0.77)]
const POST := [Vector2(0.36, 0.0), Vector2(0.36, 0.10), Vector2(0.27, 0.17), Vector2(0.18, 0.26), Vector2(0.15, 0.62),
	Vector2(0.15, 0.96), Vector2(0.19, 1.05), Vector2(0.16, 1.14), Vector2(0.27, 1.27), Vector2(0.31, 1.38),
	Vector2(0.25, 1.43), Vector2(0.09, 1.40)]
static var _metal: ImageTexture


class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nor: Vector3, t: Vector2) -> int:
		v.append(p)
		n.append(nor)
		uv.append(t)
		return v.size() - 1

	## Winds the triangle so it faces along its vertex normals (Godot's front faces are clockwise).
	func tri(a: int, b: int, c: int) -> void:
		var flip := (v[b] - v[a]).cross(v[c] - v[a]).dot(n[a] + n[b] + n[c]) > 0.0
		idx.append(a)
		idx.append(c if flip else b)
		idx.append(b if flip else c)

	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func build() -> ArrayMesh:
	var course := _course()
	var smooth_stone := _rib_stone()
	var shell := _curve(SHELL, 16)
	var wall := Geo.new()
	_lathe(wall, shell, Vector3.ZERO, SEG, WALL_TILE)
	var ground := Geo.new()
	var rings := [Vector2(12.2, 0.0)]
	while rings.back().x - 1.5 > 3.85:
		rings.append(Vector2(rings.back().x - 1.5, 0.0))
	rings.append(Vector2(3.85, 0.0))
	_lathe(ground, rings.slice(0, rings.size() - 1), Vector3.ZERO, SEG, FLOOR_TILE)
	# The ring against the plinth shares its joints, so they run unbroken from the floor up over every step.
	_wrapped(ground, rings.slice(rings.size() - 2), Vector3.ZERO, SEG, PLINTH_RUNS, 0.0, 1.0)
	var plinth := Geo.new()
	# Each step's riser, bevel and tread are one course of stone wrapping over the edge.
	for start in range(0, PLINTH.size() - 1, 3):
		_wrapped(plinth, PLINTH.slice(start, start + 4), Vector3.ZERO, SEG, PLINTH_RUNS, 1.0, 0.0)
	var ribs := Geo.new()
	for i in RIBS:
		_rib(ribs, _curve(SHELL, 40), TAU * (float(i) + 0.5) / RIBS)
	var posts := Geo.new()
	var bulbs := Geo.new()
	var bulb := []
	for k in 13:
		var f := float(k) / 12.0
		bulb.append(Vector2(maxf(0.012, 0.20 * pow(sin(f * PI), 0.75) * (1.0 - f * 0.18)), 1.38 + f * 0.48))
	for at in Stage.LANTERNS:
		var base := Vector3(at.x, 0.0, at.y)
		_wrapped(posts, POST, base, 20, 2.0, 0.0, _length(POST) / 1.4)
		_lathe(bulbs, bulb, base, 20, 1.4, false)
	var mesh := ArrayMesh.new()
	wall.add_to(mesh, _stone("vault_wall", course, Color("#6d7388")))
	ground.add_to(mesh, _stone("vault_floor", course, Color("#a3a6b4")))
	plinth.add_to(mesh, _stone("vault_plinth", course, Color("#d2cfca")))
	ribs.add_to(mesh, _stone("vault_rib", smooth_stone, Color("#a9abb9")))
	posts.add_to(mesh, _stone("vault_lantern", smooth_stone, Color("#cfc6b6")))
	var glow := _stone("lantern_glow", _bulb(), Color.WHITE)
	glow.emission_enabled = true
	glow.emission_texture = glow.albedo_texture
	glow.emission = Color("#ffc98a")
	glow.emission_energy_multiplier = 1.0
	bulbs.add_to(mesh, glow)
	return mesh


## The column the core hangs from, in the core's own units: a metal tube banded with clamps, wrapped in a bundle of
## cables, with slack loops dropping to the core's crown. Tall enough that its top never enters the frame.
static func conduit() -> ArrayMesh:
	const TOP := 12.0
	var metal_parts := Geo.new()
	_lathe(metal_parts, [Vector2(0.84, 0.02), Vector2(0.84, 0.12), Vector2(0.70, 0.20), Vector2(0.62, 0.34), Vector2(0.50, 0.46),
		Vector2(0.46, 0.62), Vector2(0.46, TOP)], Vector3.ZERO, 36, 1.0, false)
	var y := 0.95
	while y < TOP - 0.4:
		_lathe(metal_parts, [Vector2(0.46, y), Vector2(0.60, y + 0.02), Vector2(0.63, y + 0.06), Vector2(0.63, y + 0.16),
			Vector2(0.60, y + 0.20), Vector2(0.46, y + 0.22)], Vector3.ZERO, 28, 1.0, false)
		y += 1.35
	var wires := Geo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# The bundle climbs through the clamps with a slow twist.
	for i in 16:
		var start := TAU * float(i) / 16.0 + rng.randf_range(-0.08, 0.08)
		var radius := 0.50 + rng.randf_range(-0.03, 0.03)
		var phase := rng.randf() * TAU
		var path := []
		var h := 0.35
		while h < TOP:
			var a := start + h * 0.10 + sin(h * 1.4 + phase) * 0.05
			var r := radius + sin(h * 2.2 + phase) * 0.02
			path.append(Vector3(cos(a) * r, h, sin(a) * r))
			h += 0.35
		_cable(wires, path, rng.randf_range(0.035, 0.07), 5, (float(i % 4) + 0.5) / 4.0)
	# Loose runs sag from the column down onto the core, tying the two together.
	for i in 9:
		var a := TAU * (float(i) + 0.3) / 9.0 + rng.randf_range(-0.1, 0.1)
		var top := Vector3(cos(a) * 0.50, rng.randf_range(1.1, 1.9), sin(a) * 0.50)
		var reach := rng.randf_range(0.82, 1.05)
		var foot := Vector3(cos(a + 0.2) * reach, 0.10, sin(a + 0.2) * reach)
		var sag := top.lerp(foot, 0.5) + Vector3(cos(a), 0.0, sin(a)) * 0.24 + Vector3.DOWN * 0.34
		var path := []
		for k in 15:
			var f := float(k) / 14.0
			path.append(top.lerp(sag, f).lerp(sag.lerp(foot, f), f))
		_cable(wires, path, rng.randf_range(0.04, 0.06), 6, (float(i % 4) + 0.5) / 4.0)
	var metal_mat := StandardMaterial3D.new()
	metal_mat.resource_name = "conduit_metal"
	metal_mat.albedo_texture = metal()
	metal_mat.albedo_color = Color("#a89a88")
	metal_mat.texture_filter = ANISO
	metal_mat.uv1_triplanar = true
	metal_mat.uv1_scale = Vector3.ONE * 1.5
	metal_mat.roughness = 0.55
	metal_mat.metallic = 0.12
	var wire_mat := _stone("conduit_wire", _wire_colours(), Color.WHITE)
	wire_mat.roughness = 0.6
	var mesh := ArrayMesh.new()
	metal_parts.add_to(mesh, metal_mat)
	wires.add_to(mesh, wire_mat)
	return mesh


## A round tube along a path; `u` picks its colour from the wire palette.
static func _cable(g: Geo, path: Array, radius: float, sides: int, u: float) -> void:
	var first := g.v.size()
	var side: Vector3 = Vector3.FORWARD.cross(path[1] - path[0]).normalized()
	for j in path.size():
		var tangent: Vector3 = (path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)]).normalized()
		side = (side - tangent * side.dot(tangent)).normalized()
		var other := tangent.cross(side)
		for k in sides + 1:
			var a := TAU * float(k) / sides
			var out := side * cos(a) + other * sin(a)
			g.vert(path[j] + out * radius, out, Vector2(u, float(j) / 4.0))
	for j in path.size() - 1:
		for k in sides:
			var q := first + j * (sides + 1) + k
			g.tri(q, q + 1, q + sides + 1)
			g.tri(q + 1, q + sides + 2, q + sides + 1)


## Four warm insulation colours, side by side.
static func _wire_colours() -> ImageTexture:
	var colours := [Color("#2f2a26"), Color("#49423a"), Color("#74332c"), Color("#94723f")]
	var img := Image.create(256, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 256:
			img.set_pixel(x, y, colours[mini(x / 64, 3)])
	return ImageTexture.create_from_image(img)


## Soft, seamless clouds that the mist layers drift over one another.
static func mist() -> ImageTexture:
	var img := _noise(256, 0.014, 8, 4)
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


## Clean cast bronze for the core's frame and tongs. Warm on purpose, so nothing on the mechanism reads blue.
static func metal() -> ImageTexture:
	if _metal != null:
		return _metal
	var size := 256
	var broad := _noise(size, 0.010, 21, 2)
	var fine := _noise(size, 0.045, 22, 2)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var dark := Color("#6b5a48")
	var pale := Color("#b29a78")
	for y in size:
		for x in size:
			var k := clampf(broad.get_pixel(x, y).r * 0.85 + fine.get_pixel(x, y).r * 0.15, 0.0, 1.0)
			img.set_pixel(x, y, dark.lerp(pale, smoothstep(0.25, 0.8, k)))
	_metal = ImageTexture.create_from_image(img)
	return _metal


static func _stone(title: String, tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = title
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.texture_filter = ANISO
	mat.roughness = 0.88
	return mat


## Each band of the profile is one course of blocks, so the blocks stay evenly sized from wall to plinth.
static func _lathe(g: Geo, profile: Array, at: Vector3, seg: int, tile: float, courses := true) -> void:
	for j in profile.size() - 1:
		var a: Vector2 = profile[j]
		var b: Vector2 = profile[j + 1]
		var repeats := maxf(1.0, round(TAU * (a.x + b.x) * 0.5 / tile))
		_band(g, profile, j, at, seg, repeats, fmod(float(j) * 0.37, 1.0), 0.0, 1.0 if courses else a.distance_to(b) / tile)


## Bands sharing one run of blocks, with the texture carried continuously across them, so joints stay unbroken round
## every corner of the profile.
static func _wrapped(g: Geo, profile: Array, at: Vector3, seg: int, repeats: float, v_from: float, v_to: float) -> void:
	var total := _length(profile)
	var run := 0.0
	for j in profile.size() - 1:
		var step: float = (profile[j] as Vector2).distance_to(profile[j + 1])
		_band(g, profile, j, at, seg, repeats, 0.0, lerpf(v_from, v_to, run / total), lerpf(v_from, v_to, (run + step) / total))
		run += step


## Band `j` of a profile, turned around the axis.
static func _band(g: Geo, profile: Array, j: int, at: Vector3, seg: int, repeats: float, shift: float, v0: float, v1: float) -> void:
	var a: Vector2 = profile[j]
	var b: Vector2 = profile[j + 1]
	var band := _normal(a, b)
	var na := band
	var nb := band
	if j > 0 and _normal(profile[j - 1], a).dot(band) > 0.72:
		na = (_normal(profile[j - 1], a) + band).normalized()
	if j + 2 < profile.size() and _normal(b, profile[j + 2]).dot(band) > 0.72:
		nb = (_normal(b, profile[j + 2]) + band).normalized()
	var first := g.v.size()
	for i in seg + 1:
		var th := TAU * float(i) / seg
		var c := cos(th)
		var s := sin(th)
		var u := float(i) / seg * repeats + shift
		g.vert(at + Vector3(c * a.x, a.y, s * a.x), Vector3(c * na.x, na.y, s * na.x), Vector2(u, v0))
		g.vert(at + Vector3(c * b.x, b.y, s * b.x), Vector3(c * nb.x, nb.y, s * nb.x), Vector2(u, v1))
	for i in seg:
		var q := first + i * 2
		g.tri(q, q + 1, q + 2)
		g.tri(q + 1, q + 3, q + 2)


static func _length(profile: Array) -> float:
	var total := 0.0
	for j in profile.size() - 1:
		total += (profile[j] as Vector2).distance_to(profile[j + 1])
	return total


## Profile direction turned to its surface normal, as (radial, up): climbing faces out, running inward faces up.
static func _normal(a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	return Vector2(d.y, -d.x).normalized()


## A half-round rib lying on the shell, thinning as it climbs towards the oculus.
static func _rib(g: Geo, path: Array, angle: float) -> void:
	const SIDES := 8
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var side := Vector3(-sin(angle), 0.0, cos(angle))
	var run := 0.0
	var first := g.v.size()
	for j in path.size():
		var p: Vector2 = path[j]
		var tangent: Vector2 = (path[mini(j + 1, path.size() - 1)] - path[maxi(j - 1, 0)]).normalized()
		var inward2 := Vector2(tangent.y, -tangent.x)
		var inward := radial * inward2.x + Vector3.UP * inward2.y
		var thin := lerpf(0.30, 0.62, smoothstep(13.5, 4.0, p.y))
		if j > 0:
			run += p.distance_to(path[j - 1])
		for k in SIDES + 1:
			var a := PI * float(k) / SIDES
			var across := cos(a)
			var depth := sin(a)
			var pos := radial * p.x + Vector3.UP * p.y + side * across * thin + inward * depth * thin * 0.72
			g.vert(pos, (side * across + inward * depth).normalized(), Vector2(float(k) / SIDES, run / 2.6))
	for j in path.size() - 1:
		for k in SIDES:
			var q := first + j * (SIDES + 1) + k
			g.tri(q, q + 1, q + SIDES + 1)
			g.tri(q + 1, q + SIDES + 2, q + SIDES + 1)


## Catmull-Rom through the control points, for a soft outline.
static func _curve(points: Array, samples: int) -> Array:
	var out := []
	var spans := points.size() - 1
	for i in samples + 1:
		var f := float(i) / samples * spans
		var j := mini(int(f), spans - 1)
		var t := f - j
		var p0: Vector2 = points[maxi(j - 1, 0)]
		var p1: Vector2 = points[j]
		var p2: Vector2 = points[j + 1]
		var p3: Vector2 = points[mini(j + 2, spans)]
		out.append(p1.cubic_interpolate(p2, p0, p3, t))
	return out


## Three fitted blocks with soft seams, a lit upper edge and gently mottled faces. Grey, tinted per surface.
static func _course() -> ImageTexture:
	const BLOCKS := 3
	var w := 768
	var h := 256
	var broad := _noise_size(w, h, 0.007, 3, 3)
	var fine := _noise_size(w, h, 0.024, 4, 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var tones := [0.97, 0.89, 1.03]
	var cell := float(w) / BLOCKS
	for y in h:
		for x in w:
			var k := mini(int(float(x) / cell), BLOCKS - 1)
			var fx := float(x) - k * cell
			var edge := minf(minf(fx, cell - fx), minf(float(y), float(h - y)))
			var body: float = tones[k] * (0.84 + 0.20 * broad.get_pixel(x, y).r + 0.07 * fine.get_pixel(x, y).r)
			var bevel := (1.0 - smoothstep(0.0, 20.0, float(y))) * 0.10 - (1.0 - smoothstep(0.0, 20.0, float(h - y))) * 0.13
			var shade := lerpf(0.50, body + bevel, smoothstep(4.0, 15.0, edge))
			img.set_pixel(x, y, Color(0.74 * shade, 0.74 * shade, 0.78 * shade))
	return ImageTexture.create_from_image(img)


## Smooth carved stone, rounded across its width, with a faint joint every repeat.
static func _rib_stone() -> ImageTexture:
	var size := 256
	var broad := _noise(size, 0.012, 13, 3)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var across := 0.84 + 0.16 * sin(float(x) / size * PI)
			var joint := smoothstep(2.0, 12.0, minf(float(y), float(size - y)))
			var shade := across * (0.82 + 0.20 * broad.get_pixel(x, y).r) * lerpf(0.70, 1.0, joint)
			img.set_pixel(x, y, Color(0.80 * shade, 0.80 * shade, 0.83 * shade))
	return ImageTexture.create_from_image(img)


static func _bulb() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var c := Color("#ffe9c6").lerp(Color("#ffb468"), float(y) / 63.0)
		for x in 64:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _noise(size: int, frequency: float, seed_value: int, octaves: int) -> Image:
	return _noise_size(size, size, frequency, seed_value, octaves)


static func _noise_size(w: int, h: int, frequency: float, seed_value: int, octaves: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n.get_seamless_image(w, h)
