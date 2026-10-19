extends SceneTree
## Renders the app icon: the game's own voxel Redcoon on a little floating meadow island, with sky, clouds and green
## hills behind. Three passes, saved as 1024 x 1024 PNGs for tools/make_icon.py to cut into Android icon layers:
##   <out>_full.png  everything   <out>_fg.png  island + Redcoon on transparency   <out>_bg.png  sky, clouds, hills
##   <out>_mono.png  the Redcoon alone on transparency (its silhouette becomes the monochrome icon)
## Run (needs a window, not --headless):
##   godot --path . --resolution 1024x1024 --script res://tools/make_icon.gd -- --out=C:/tmp/icon

const VB = preload("res://scripts/gfx/voxel_beast.gd")
const VA = preload("res://scripts/gfx/voxel_assets.gd")
const VBld = preload("res://scripts/gfx/voxel_buildings.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const VM = preload("res://scripts/gfx/voxel_mesher.gd")

const V := 0.2  # one voxel of ground

var out := "user://icon"
var rot := -PI / 2.0 + 0.3
var probe := false
var top_view := false
var face_view := false
var fg: Node3D
var bg: Node3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--rot="):
			rot = float(a.substr(6))
		elif a == "--probe":
			probe = true
		elif a == "--top":
			top_view = true
		elif a == "--face":
			face_view = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1024, 1024)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#52aef0")
	sm.sky_horizon_color = Color("#d4f1ff")
	sm.ground_horizon_color = Color("#d4f1ff")
	sm.ground_bottom_color = Color("#9ad8f4")
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff4e0")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe4bc")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 20.0
	sun.rotation_degrees = Vector3(-48, -32, 0)
	root.add_child(sun)
	# a cool fill from the other side, so the shadows stay soft and blue rather than black
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#cfe4ff")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-25, 150, 0)
	root.add_child(fill)
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	var cam := Camera3D.new()
	# the valley and hills melt into a soft blur behind the island
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 17.5
	ca.dof_blur_far_transition = 7.0
	ca.dof_blur_amount = 0.06
	cam.attributes = ca
	cam.fov = 26.0
	cam.position = Vector3(0, 5.0, 14.6)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))
	if top_view:
		cam.position = Vector3(0, 14, 0.01)
		cam.look_at(Vector3.ZERO)
	elif face_view:
		cam.fov = 20.0
		cam.position = Vector3(0.6, 2.2, 4.2)
		cam.look_at(Vector3(0, 1.55, 0.6))
	cam.current = true

	fg = Node3D.new()
	root.add_child(fg)
	bg = Node3D.new()
	root.add_child(bg)
	_island(fg)
	_hills(bg)
	_clouds(bg)

	if face_view:
		bg.visible = false
		await _frames(8)
		_save("_face")
		quit()
		return
	if probe:
		bg.visible = false
		var b: MeshInstance3D = fg.get_node("Beast")
		print("beast aabb ", b.mesh.get_aabb())
		for i in 4:
			b.rotation.y = i * PI / 2.0
			await _frames(6)
			_save("_probe%d" % i)
		quit()
		return
	await _frames(12)
	_save("_full")
	bg.visible = false
	root.transparent_bg = true
	await _frames(6)
	_save("_fg")
	bg.visible = true
	fg.visible = false
	root.transparent_bg = false
	await _frames(6)
	_save("_bg")
	# the Redcoon alone, for the monochrome (themed) icon's silhouette
	bg.visible = false
	fg.visible = true
	for c in fg.get_children():
		c.visible = c.name == "Beast"
	root.transparent_bg = true
	await _frames(6)
	_save("_mono")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(suffix: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out + suffix + ".png")
	print("saved ", out + suffix + ".png")


## A chunky floating island: grass-topped columns of dirt that taper to a stony point, rising to a gentle mound.
## The Redcoon stands in the middle, among flowers and grass tufts, with a round tree and a bush behind it.
const R := 1.9


## The height of the island's grass at (x, z).
func _surface(x: float, z: float) -> float:
	var d := Vector2(x, z * 1.1).length()
	return (round((1.0 - d / R) * 2.0) + 1.0) * V


func _island(parent: Node3D) -> void:
	var k := VBld.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(ceil(R / V))
	var greens := [Color("#6fcf4a"), Color("#79d552"), Color("#66c444"), Color("#84dd5e")]
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var x := ix * V
			var z := iz * V
			var d := Vector2(x, z * 1.1).length()
			if d > R:
				continue
			var top := _surface(x, z)
			var col: Color = greens[rng.randi_range(0, greens.size() - 1)]
			k.box("color", Vector3(x, top - V * 0.5, z), Vector3(V, V, V), col)
			var bottom := -(int((1.0 - d / R) * 6.0) + 1) * V
			var mid := maxf(bottom, -V * 1.5)
			k.box("color", Vector3(x, (top - V + mid) / 2.0, z), Vector3(V, top - V - mid, V), Color("#9a6a42").darkened(rng.randf() * 0.1))
			if bottom < mid:
				k.box("color", Vector3(x, (mid + bottom) / 2.0, z), Vector3(V, mid - bottom, V), Color("#80786e").darkened(rng.randf() * 0.12), true)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	parent.add_child(mi)
	var beast := MeshInstance3D.new()
	beast.name = "Beast"
	beast.mesh = _redcoon()
	beast.scale = Vector3.ONE * 1.3
	beast.rotation.y = rot
	beast.position = Vector3(0.0, _surface(0, 0.3), 0.3)
	parent.add_child(beast)
	var tree := VA.instance("tree_round_1", 2.0)
	tree.position += Vector3(-1.05, _surface(-1.05, -0.75), -0.75)
	parent.add_child(tree)
	_bush(parent, Vector3(1.15, _surface(1.15, -0.6), -0.6), rng)
	# clumps of voxel grass blades
	for spot in [Vector2(-1.25, 0.65), Vector2(1.3, 0.5), Vector2(0.75, -1.15), Vector2(-0.35, -1.3), Vector2(1.5, -0.05), Vector2(-1.55, -0.1), Vector2(0.55, 0.95), Vector2(-0.75, 1.1)]:
		var gk := VBld.Kit.new()
		for j in 5:
			var o := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.1, 0.1))
			var hb := rng.randf_range(0.12, 0.26)
			gk.box("color", Vector3(spot.x, _surface(spot.x, spot.y) + hb / 2.0, spot.y) + o, Vector3(0.045, hb, 0.045), Color("#4fb83a").lightened(rng.randf() * 0.25))
		var gm := MeshInstance3D.new()
		gm.mesh = gk.mesh()
		parent.add_child(gm)
	var petals := [Color("#ff6a8a"), Color("#ffd84a"), Color("#ffffff"), Color("#b07aff"), Color("#ff9a4a")]
	var placed := 0
	while placed < 10:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.8, 1.6)
		var p := Vector2(cos(a) * rr, sin(a) * rr * 0.85)
		if p.y < -0.4 and absf(p.x) < 0.9:
			continue
		var fk := VBld.Kit.new()
		var base := Vector3(p.x, _surface(p.x, p.y), p.y)
		fk.box("color", base + Vector3(0, 0.08, 0), Vector3(0.04, 0.16, 0.04), Color("#3f9a32"))
		var pc: Color = petals[placed % petals.size()]
		for o in [Vector3(0.06, 0, 0), Vector3(-0.06, 0, 0), Vector3(0, 0, 0.06), Vector3(0, 0, -0.06)]:
			fk.box("color", base + Vector3(0, 0.18, 0) + o, Vector3(0.06, 0.06, 0.06), pc)
		fk.box("color", base + Vector3(0, 0.19, 0), Vector3(0.065, 0.065, 0.065), Color("#ffe060"))
		var fm := MeshInstance3D.new()
		fm.mesh = fk.mesh()
		parent.add_child(fm)
		placed += 1


## The game's Redcoon with an icon-only face painted on the front of its head: big shiny eyes in its mask, a cream
## muzzle with a little mouth, and pink cheeks. (In the game its eyes are small dots on the sides of its head.)
func _redcoon() -> Mesh:
	var genes := RaceDB.genes(0)
	var g: VM.Grid = VB.grid(genes)
	var hc: Vector3 = VB._anchors(String(genes["body"]))["head"]
	var cy := int(round(hc.y))
	var cz := int(VB.CZ)
	var W := g.add_color(Color("#fbfaf4"))
	var P := g.add_color(Color("#140c14"))
	var GL := g.add_color(Color("#ffffff"), true)
	var BL := g.add_color(Color("#ff9fb8"))
	var CR := g.add_color(Color("#f6e4c8"))
	var paint := func(dy: int, dz: int, c: int) -> void:
		var y := cy + dy
		var z := cz + dz
		var x := VB.SX - 1
		while x > 0 and g.get_v(x, y, z) == 0:
			x -= 1
		if x > 0:
			g.set_v(x, y, z, c)
	# flatten the bump in the middle of the mask so the eyes sit on a flat face
	var front := 0
	for y in range(cy - 2, cy + 3):
		for z in range(cz - 3, cz + 4):
			for x in range(VB.SX - 1, 0, -1):
				if g.get_v(x, y, z) != 0:
					front = maxi(front, x)
					break
	for y in range(cy - 2, cy + 3):
		for z in range(cz - 3, cz + 4):
			g.set_v(front, y, z, 0)
	for side in [-1, 1]:
		# a tall white eye with a big pupil and a sparkle, either side of the nose bridge
		var cols := [side * 3, side * 2, side * 1]
		var rows := [[W, W, W], [W, GL, P], [W, P, P], [W, P, P]]
		for ri in 4:
			for ci in 3:
				paint.call(1 - ri, cols[ci], rows[ri][ci])
		paint.call(-3, side * 5, BL)
		paint.call(-3, side * 4, BL)
	# pink inside the ears instead of dark crosses
	var dark := Color(str(genes["c2"]))
	var PK := g.add_color(Color("#f49aac"))
	for x in VB.SX:
		for y in range(cy + 4, VB.SY):
			for z in VB.SZ:
				var v := g.get_v(x, y, z)
				if v != 0 and g.palette[v].is_equal_approx(dark):
					g.set_v(x, y, z, PK)
	for dz in range(-2, 3):
		paint.call(-3, dz, CR)
		paint.call(-4, dz, CR)
	for dz in range(-1, 2):
		paint.call(-5, dz, CR)
	paint.call(-4, 0, P)
	paint.call(-5, -1, P)
	paint.call(-5, 1, P)
	return VM.build(g, VB.VSIZE * float(genes.get("size", 1.0)))


## A round voxel bush, a blob of leafy cubes.
func _bush(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var k := VBld.Kit.new()
	var c := 0.12
	for ix in range(-3, 4):
		for iy in range(0, 5):
			for iz in range(-3, 4):
				var p := Vector3(ix, iy - 1.5, iz) * c
				if p.length() > 0.38 + rng.randf() * 0.05:
					continue
				k.box("color", at + Vector3(0, 0.22, 0) + p, Vector3(c, c, c), Color("#3fa83a").lerp(Color("#7ad65a"), rng.randf() * 0.6 + (0.3 if iy > 2 else 0.0)))
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	parent.add_child(mi)


## Rolling voxel hills and a few trees far behind, under the horizon.
func _hills(parent: Node3D) -> void:
	var k := VBld.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var S := 0.9
	for ix in range(-26, 27):
		for iz in range(0, 8):
			var x := ix * S
			var z := -9.0 - iz * S
			var hgt := 2.2 + sin(x * 0.35 + iz * 0.7) * 1.1 + sin(x * 0.13) * 0.9 - iz * 0.12
			var col := Color("#58b84a").lerp(Color("#8fd0a8"), iz / 8.0).darkened(rng.randf() * 0.06)
			k.box("color", Vector3(x, hgt / 2.0 - 4.0, z), Vector3(S, hgt, S), col)
	# the valley floor far below the island, with a little pond
	for ix in range(-30, 31):
		for iz in range(-1, 14):
			var x := ix * S
			var z := -8.0 + iz * S
			var hgt := 0.6 + sin(x * 0.4 + z * 0.3) * 0.25
			var pond := Vector2((x - 2.6) * 0.8, z - 2.0).length() < 2.2
			var col := Color("#4ab0e0") if pond else Color("#5cc04a").lerp(Color("#79d05c"), rng.randf() * 0.7)
			k.box("color", Vector3(x, -5.0 + (0.3 if pond else hgt) / 2.0, z), Vector3(S, 0.3 if pond else hgt, S), col)
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	parent.add_child(mi)
	for i in 16:
		var vt := VA.instance("tree_round_1", rng.randf_range(1.3, 2.0))
		var vx := rng.randf_range(-11.0, 11.0)
		var vz := rng.randf_range(-7.0, 4.0)
		if Vector2((vx - 2.6) * 0.8, vz - 2.0).length() < 2.6:
			continue
		vt.position += Vector3(vx, -4.4, vz)
		parent.add_child(vt)
	for i in 12:
		var t := VA.instance("tree_round_1", rng.randf_range(1.5, 2.3))
		var x := rng.randf_range(-12.0, 12.0)
		t.position += Vector3(x, -2.6 + sin(x * 0.35) * 0.9 + 0.9, -9.6 - rng.randf() * 2.0)
		parent.add_child(t)


## Puffy voxel clouds.
func _clouds(parent: Node3D) -> void:
	var k := VBld.Kit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c in [Vector3(-5.0, 2.3, -12.0), Vector3(5.2, 2.7, -13.0), Vector3(0.8, 3.2, -16.0), Vector3(-9.0, 1.6, -14.0), Vector3(9.5, 1.8, -14.5)]:
		for j in 6:
			var o := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.15, 0.3), rng.randf_range(-0.3, 0.3))
			k.box("color", c + o, Vector3(rng.randf_range(0.6, 1.0), 0.45, 0.6), Color("#ffffff"))
	var mi := MeshInstance3D.new()
	mi.mesh = k.mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
