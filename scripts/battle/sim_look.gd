extends RefCounted
## The Codex's simulation (the user's 2026-11-15 direction): while it runs a lesson in battle, the stage loses its
## paint and turns almost black (a smooth screen-wide gradient, black at the top to the faintest green at the bottom),
## every polygon's edges drawn in bright green lines, like a training
## simulation. The fighters (beasts, trainers) keep their own look so they read clearly. apply() swaps it in,
## restore() puts everything back as it was. It's an effect, so (like glows and target arrows) it is untextured.
##
## Edge meshes are built once per mesh and cached; edges between two faces lying flat on each other are left out, so
## a flat floor shows its real polygon outlines rather than every triangle's diagonal.

const FACE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 top_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 bottom_color : source_color = vec3(0.0, 0.22, 0.11);
void fragment() {
	// one smooth screen-wide gradient, the same on every face: almost black at the top, the faintest green at the
	// bottom (the user's 2026-11-15 direction: mostly black)
	ALBEDO = mix(top_color, bottom_color, smoothstep(0.0, 1.0, SCREEN_UV.y));
}
"""
## The background behind everything: the same gradient, so the stage and any gap in it are one smooth fill.
const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 bottom_color : source_color = vec3(0.0, 0.22, 0.11);
void sky() {
	COLOR = mix(top_color, bottom_color, smoothstep(0.0, 1.0, SCREEN_UV.y));
}
"""
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled, shadows_disabled;
uniform vec4 line_color : source_color = vec4(0.3, 1.0, 0.5, 1.0);
void vertex() {
	// drawn a hair toward the camera, so the lines sit on their faces without flickering into them
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.997;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	ALBEDO = line_color.rgb;
}
"""
## Faces this close to flat on each other share an edge that isn't drawn.
const FLAT := 0.995
## Meshes past this many triangles keep only their outlines' worth of edges (FLAT is loosened) to stay readable.
const DENSE := 20000

static var _edges := {}
static var _face_mat: ShaderMaterial
static var _line_mat: ShaderMaterial
static var _sky: Sky

var _swapped := {}
var _hidden := []
var _lines := []
var _env: Environment
var _env_was := {}


static func _materials() -> void:
	if _face_mat == null:
		var fs := Shader.new()
		fs.code = FACE_SHADER
		_face_mat = ShaderMaterial.new()
		_face_mat.shader = fs
		var ls := Shader.new()
		ls.code = LINE_SHADER
		_line_mat = ShaderMaterial.new()
		_line_mat.shader = ls
		var ss := Shader.new()
		ss.code = SKY_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = ss
		_sky = Sky.new()
		_sky.sky_material = sm


## Turns everything under `root` except `keep` (nodes whose whole subtree keeps its look) into the simulation;
## `env` (the stage's environment) gets a dark green-black background.
func apply(root: Node, keep: Array, env: Environment) -> void:
	_materials()
	var skip := {}
	for k in keep:
		if is_instance_valid(k):
			skip[k] = true
	_walk(root, skip)
	_env = env
	if env != null:
		_env_was = {"mode": env.background_mode, "color": env.background_color, "fog": env.fog_enabled,
			"vfog": env.volumetric_fog_enabled, "glow": env.glow_intensity, "sky": env.sky}
		env.background_mode = Environment.BG_SKY
		env.sky = _sky
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_intensity = maxf(env.glow_intensity, 0.9)


func restore() -> void:
	for n in _swapped:
		if is_instance_valid(n):
			(n as GeometryInstance3D).material_override = _swapped[n]
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	for l in _lines:
		if is_instance_valid(l):
			l.queue_free()
	_swapped = {}
	_hidden = []
	_lines = []
	if _env != null and not _env_was.is_empty():
		_env.background_mode = _env_was["mode"]
		_env.background_color = _env_was["color"]
		_env.sky = _env_was["sky"]
		_env.fog_enabled = _env_was["fog"]
		_env.volumetric_fog_enabled = _env_was["vfog"]
		_env.glow_intensity = _env_was["glow"]
	_env = null


func _walk(n: Node, skip: Dictionary) -> void:
	if skip.has(n) or n is SubViewport or n is CanvasItem:
		return
	if n is MeshInstance3D and n.visible and n.mesh != null:
		_swap(n)
		var lm := _edge_mesh(n.mesh)
		if lm != null:
			var li := MeshInstance3D.new()
			li.mesh = lm
			li.material_override = _line_mat
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			li.layers = n.layers
			n.add_child(li)
			_lines.append(li)
	elif n is MultiMeshInstance3D and n.visible and n.multimesh != null and n.multimesh.mesh != null:
		_swap(n)
		var lm := _edge_mesh(n.multimesh.mesh)
		if lm != null:
			var src: MultiMesh = n.multimesh
			var mm := MultiMesh.new()
			mm.transform_format = src.transform_format
			mm.mesh = lm
			mm.instance_count = src.instance_count
			mm.visible_instance_count = src.visible_instance_count
			if src.instance_count > 0:
				var buf := src.buffer
				var stride := 12 if src.transform_format == MultiMesh.TRANSFORM_3D else 8
				var keep_stride := buf.size() / src.instance_count
				if keep_stride == stride:
					mm.buffer = buf
				else:
					for i in src.instance_count:
						if src.transform_format == MultiMesh.TRANSFORM_3D:
							mm.set_instance_transform(i, src.get_instance_transform(i))
						else:
							mm.set_instance_transform_2d(i, src.get_instance_transform_2d(i))
			var li := MultiMeshInstance3D.new()
			li.multimesh = mm
			li.material_override = _line_mat
			li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			li.layers = n.layers
			n.add_child(li)
			_lines.append(li)
	elif n is GeometryInstance3D and n.visible:
		# sprites, particles, 3D lettering: out of the simulation
		n.visible = false
		_hidden.append(n)
	for c in n.get_children():
		if not _lines.has(c):
			_walk(c, skip)


func _swap(g: GeometryInstance3D) -> void:
	_swapped[g] = g.material_override
	g.material_override = _face_mat


## The mesh's polygon edges as lines (cached per mesh), or null if it has no triangles.
static func _edge_mesh(m: Mesh) -> Mesh:
	var id := m.get_instance_id()
	if _edges.has(id):
		return _edges[id]
	var pts := PackedVector3Array()
	for s in m.get_surface_count():
		# (primitive meshes, a box or a sphere, are always triangles)
		if m is ArrayMesh and (m as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := m.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_count := (idx.size() if not idx.is_empty() else verts.size()) / 3
		var flat := FLAT if tri_count < DENSE else 0.9
		# welded corners (split vertices at seams share a position), so neighbouring faces find each other
		var weld := {}
		var key := func(v: Vector3) -> Vector3i:
			return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		var edge := {}
		for t in tri_count:
			var c := []
			for k in 3:
				var vi: int = idx[t * 3 + k] if not idx.is_empty() else t * 3 + k
				var v: Vector3 = verts[vi]
				var kk: Vector3i = key.call(v)
				if not weld.has(kk):
					weld[kk] = weld.size()
				c.append([int(weld[kk]), v])
			var nrm: Vector3 = (c[1][1] - c[0][1]).cross(c[2][1] - c[0][1])
			if nrm.length_squared() < 1e-14:
				continue
			nrm = nrm.normalized()
			for k in 3:
				var a: Array = c[k]
				var b: Array = c[(k + 1) % 3]
				var ek: int = mini(a[0], b[0]) * 2097152 + maxi(a[0], b[0])
				if edge.has(ek):
					var e: Array = edge[ek]
					# the second face on this edge: a fold keeps it, a flat join drops it
					if absf((e[2] as Vector3).dot(nrm)) >= flat:
						e[3] = false
				else:
					edge[ek] = [a[1], b[1], nrm, true]
		for e in edge.values():
			if e[3]:
				pts.append(e[0])
				pts.append(e[1])
	var out: Mesh = null
	if not pts.is_empty():
		var am := ArrayMesh.new()
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pts
		var nr := PackedVector3Array()
		nr.resize(pts.size())
		nr.fill(Vector3.UP)
		a[Mesh.ARRAY_NORMAL] = nr
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
		out = am
	_edges[id] = out
	return out
