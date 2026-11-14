extends RefCounted
## The temples' lights: KayKit's wall torch, standing torch and candles (tools/import_kaykit.gd --hoard), each with a
## small glowing flame and, where asked, a warm light. The temples are dark (world.gd _build_room); these are what
## light them. Lights cast no shadows, and a room keeps to a handful of them for the Mobile renderer.

const DIR := "res://assets/props/kaykit_hoard_"
const FLAME := Color("#ffb04a")
const TORCH_SCALE := 1.45
## where the wall torch's basket is in its own mesh (the wall behind it at -z), at scale 1
const BASKET := Vector3(0.0, 0.4, 0.035)

static var _meshes := {}
static var _flame_mat: StandardMaterial3D
static var _flame_mesh: SphereMesh


static func piece(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".res") if ResourceLoader.exists(DIR + name + ".res") else null
	return _meshes[name]


## A torch on a wall: at `at` (on the wall's face, at the height of its foot), leaning out along `out`. With `lit`, a
## warm light of `energy` reaching `reach`.
static func wall_torch(at: Vector3, out: Vector3, lit := true, energy := 1.3, reach := 5.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.basis = Basis.looking_at(-out, Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = piece("torch_mounted")
	mi.scale = Vector3.ONE * TORCH_SCALE
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var top := BASKET * TORCH_SCALE
	root.add_child(flame(top + Vector3(0, 0.05, 0), 0.11))
	if lit:
		root.add_child(light(top + Vector3(0, 0.25, 0.25), energy, reach))
	return root


## A candle (`kind`: "candle_lit", "candle_triple", "candle_thin_lit", "candle_melted") standing at `at`; `flames` are
## where its wicks are, in its own space; with `energy` > 0, a small warm light over it.
## `size` stretches it: x and z its thickness, y its height (the flame keeps to the candle's thickness).
static func candle(kind: String, at: Vector3, yaw := 0.0, size := Vector3.ONE, energy := 0.0, reach := 2.6) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	var m := piece(kind)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if m != null:
		var top := m.get_aabb().end.y * size.y
		var thick := (size.x + size.z) / 2.0
		root.add_child(flame(Vector3(0, top + 0.02, 0), 0.05 * clampf(thick, 0.7, 1.4)))
		if energy > 0.0:
			root.add_child(light(Vector3(0, top + 0.3, 0), energy, reach))
	return root


## A bundle of `count` candles standing together round `at`, every one a different height and thickness, tallest
## towards the middle; with `energy` > 0, one warm light over the bundle.
static func bundle(at: Vector3, count: int, rng: RandomNumberGenerator, energy := 0.0, reach := 3.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	var heights := []
	for i in count:
		heights.append(lerpf(0.45, 1.75, float(i) / maxf(1.0, count - 1)) + rng.randf_range(-0.08, 0.08))
	heights.reverse()
	var turn := rng.randf() * TAU
	var tallest := 0.0
	for i in count:
		var h: float = heights[i]
		var thick := rng.randf_range(0.75, 1.6)
		var kind := "candle_thin_lit" if thick < 1.05 else "candle_lit"
		if kind == "candle_lit":
			thick *= 0.75
			h *= 0.75
		# the tallest in the middle, the rest round it, shorter going out
		var r := 0.0 if i == 0 else 0.07 + 0.045 * i
		var a := turn + i * 2.39996
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		root.add_child(candle(kind, p, rng.randf() * TAU, Vector3(thick, h, thick)))
		tallest = maxf(tallest, piece(kind).get_aabb().end.y * h if piece(kind) != null else 0.0)
	if energy > 0.0:
		root.add_child(light(Vector3(0, tallest + 0.35, 0), energy, reach))
	return root


## A small flame: a soft glowing drop.
static func flame(at: Vector3, size: float) -> MeshInstance3D:
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.albedo_color = FLAME.lightened(0.2)
		_flame_mat.emission_enabled = true
		_flame_mat.emission = FLAME
		_flame_mat.emission_energy_multiplier = 3.0
		_flame_mesh = SphereMesh.new()
		_flame_mesh.radius = 0.5
		_flame_mesh.height = 1.0
		_flame_mesh.radial_segments = 8
		_flame_mesh.rings = 4
	var f := MeshInstance3D.new()
	f.mesh = _flame_mesh
	f.material_override = _flame_mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.position = at + Vector3(0, size * 0.4, 0)
	f.scale = Vector3(size, size * 1.8, size)
	return f


static func light(at: Vector3, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = Color("#ffbe78")
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.light_specular = 0.3
	return l
