extends Node3D
## A summon's entrance, attack and exit in battle (battle.gd _do_summon): a summoning circle and a pillar of light,
## the temple guardian's model (assets/summons, tools/import_summons.gd) arriving beside the foes, its elemental attack
## on every foe, and its exit. All particles, additive shader meshes and lights, so it runs on phones and on the web.
##   var fx := SummonFX.new(); battle.add_child(fx); fx.setup(battle, element, at, toward, targets)
##   await fx.arrive(); await fx.attack(on_hit); await fx.leave()
## on_hit is called once, at the moment the attack lands (the battle deals its damage then).

const SUMMON_DIR := "res://assets/summons/"
## per summon: model size (its longest side, world units), how high it hovers, and its colours
const LOOK := {
	"water": {"size": 6.4, "hover": 1.0, "a": "#3ab0ff", "b": "#e8fbff", "light": "#5ac8ff"},
	"air": {"size": 11.0, "hover": 1.2, "a": "#7affd8", "b": "#ffffff", "light": "#c8fff0"},
	"fire": {"size": 6.4, "hover": 0.9, "a": "#ff6a1a", "b": "#ffe07a", "light": "#ff8a3a"},
	"earth": {"size": 8.0, "hover": 0.0, "a": "#b0743a", "b": "#ff6ad8", "light": "#ffb070"},
	"ghost": {"size": 3.8, "hover": 0.0, "a": "#8a4aff", "b": "#ff7a2a", "light": "#a56bff"},
}

const CIRCLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float fade = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * 0.8;
	float rings = smoothstep(0.035, 0.0, abs(r - 0.94)) + smoothstep(0.02, 0.0, abs(r - 0.8)) + smoothstep(0.02, 0.0, abs(r - 0.42));
	float runes = step(0.82, r) * step(r, 0.92) * step(0.55, fract(a * 36.0 / 6.2832)) * 0.7;
	float b = -TIME * 1.3;
	float star = 0.0;
	for (int i = 0; i < 5; i++) {
		float ang = b + float(i) * 1.2566;
		vec2 d = vec2(cos(ang), sin(ang));
		star += smoothstep(0.022, 0.0, abs(dot(p, vec2(-d.y, d.x)) - 0.5)) * step(r, 0.8);
	}
	float v = (rings + runes + star * 0.8 + smoothstep(1.0, 0.0, r) * 0.18) * step(r, 1.0);
	ALBEDO = col.rgb * 2.2;
	ALPHA = clamp(v, 0.0, 1.0) * fade;
}
"""
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform float swirl = 1.0;
void fragment() {
	float along = sin(UV.y * 3.14159);
	float bands = 0.55 + 0.45 * sin(UV.x * 37.7 + UV.y * 12.0 * swirl - TIME * 9.0);
	float face = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.4);
	ALBEDO = col.rgb * 2.0;
	ALPHA = clamp(along * bands * face * fade, 0.0, 1.0);
}
"""
const WAVE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 deep : source_color = vec4(0.1, 0.35, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float fade = 1.0;
void fragment() {
	float crest = smoothstep(0.55, 0.95, UV.y + 0.06 * sin(UV.x * 30.0 + TIME * 8.0));
	float streaks = 0.5 + 0.5 * sin(UV.x * 60.0 + UV.y * 9.0 - TIME * 14.0);
	vec3 c = mix(deep.rgb, foam.rgb, clamp(crest + streaks * 0.25 * UV.y, 0.0, 1.0));
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALBEDO = c;
	EMISSION = c * 0.6;
	ALPHA = clamp((0.72 + crest * 0.28) * edge * fade * smoothstep(0.0, 0.2, UV.y + 0.1), 0.0, 1.0);
}
"""

var bt: Node
var element := ""
var at := Vector3.ZERO
var toward := Vector3.FORWARD
var targets: Array = []
var look: Dictionary
var model: MeshInstance3D
var circle: MeshInstance3D
var light: OmniLight3D
var _soft: Texture2D


func setup(battle: Node, el: String, where: Vector3, facing: Vector3, hit_at: Array) -> void:
	bt = battle
	element = el
	at = where
	toward = Vector3(facing.x, 0, facing.z).normalized()
	targets = hit_at
	look = LOOK.get(el, LOOK["fire"])
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_soft = gt


func col(key: String) -> Color:
	return Color(String(look[key]))


# ---------------------------------------------------------------- entrance
func arrive() -> void:
	var size: float = look["size"]
	var hover: float = look["hover"]
	Sfx.play("stinger")
	# the summoning circle opens on the ground, and a pillar of light rises from it
	circle = _disc(maxf(3.2, size * 0.55), _circle_mat(col("a")))
	circle.position = at + Vector3(0, 0.06, 0)
	circle.scale = Vector3(0.05, 1, 0.05)
	add_child(circle)
	var tw := create_tween()
	tw.tween_property(circle, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	light = OmniLight3D.new()
	light.light_color = col("light")
	light.omni_range = size * 1.6
	light.light_energy = 0.0
	light.position = at + Vector3(0, 2.0, 0)
	add_child(light)
	create_tween().tween_property(light, "light_energy", 4.0, 0.5)
	bt.summon_dim(0.55)
	bt.summon_cam(at, size)
	await get_tree().create_timer(0.35).timeout
	var beam := _beam(maxf(1.2, size * 0.18), 14.0, col("b"))
	beam.position = at + Vector3(0, 7.0, 0)
	add_child(beam)
	_fade_out(beam, 1.4, 0.2)
	_particles(at + Vector3(0, 0.3, 0), col("a"), col("b"), 90, 1.4, Vector2(2.5, 6.0), 0.22,
		{"dir": Vector3.UP, "spread": 18.0, "radius": size * 0.25, "gravity": Vector3(0, 1.0, 0)})
	Sfx.play("levelup")
	# the guardian itself: flyers swoop down from the sky, the rest rise out of the circle
	model = MeshInstance3D.new()
	model.mesh = load(SUMMON_DIR + element + ".res")
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.rotation.y = atan2(toward.x, toward.z)
	add_child(model)
	var rest := at + Vector3(0, hover, 0)
	var full := Vector3.ONE * size
	if hover > 0.0:
		model.position = rest + Vector3(0, 9.0, 0) - toward * 4.0
		model.scale = full * 0.6
		var t2 := create_tween().set_parallel()
		t2.tween_property(model, "position", rest, 0.75).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t2.tween_property(model, "scale", full, 0.75)
	else:
		model.position = rest - Vector3(0, size * 0.6, 0)
		model.scale = full * 0.85
		var t3 := create_tween().set_parallel()
		t3.tween_property(model, "position", rest, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t3.tween_property(model, "scale", full, 0.7)
	Sfx.play("fly")
	await get_tree().create_timer(0.75).timeout
	# a roar: it swells, the screen shakes
	Sfx.play("growl")
	bt.summon_shake(0.25)
	var t4 := create_tween()
	t4.tween_property(model, "scale", full * 1.08, 0.18).set_trans(Tween.TRANS_SINE)
	t4.tween_property(model, "scale", full, 0.3).set_trans(Tween.TRANS_SINE)
	_ring_burst(at + Vector3(0, 0.1, 0), col("b"), size * 0.9, 0.6)
	await get_tree().create_timer(0.6).timeout


# ---------------------------------------------------------------- attacks
func attack(on_hit: Callable) -> void:
	match element:
		"fire":
			await _fire(on_hit)
		"water":
			await _water(on_hit)
		"air":
			await _air(on_hit)
		"earth":
			await _earth(on_hit)
		_:
			await _ghost(on_hit)


## Pyroclast rears and rains fireballs on every foe: each lands in a blast and a pillar of flame.
func _fire(on_hit: Callable) -> void:
	var size: float = look["size"]
	var mouth := model.position + Vector3(0, size * 0.32, 0) + toward * size * 0.3
	var t := create_tween()
	t.tween_property(model, "rotation:x", -0.32, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(model, "rotation:x", 0.12, 0.2)
	t.tween_property(model, "rotation:x", 0.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	Sfx.play("fire")
	_particles(mouth, Color("#ffe07a"), Color("#ff3a0a"), 60, 0.6, Vector2(4.0, 8.0), 0.35, {"dir": toward + Vector3(0, -0.2, 0), "spread": 14.0})
	var rounds := 2
	for k in rounds:
		for i in targets.size():
			_fireball(mouth, targets[i] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), 0.42 + i * 0.07)
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.35).timeout
	bt.summon_shake(0.55)
	for p in targets:
		_flame_pillar(p)
	on_hit.call()
	await get_tree().create_timer(1.0).timeout


func _fireball(from: Vector3, to: Vector3, dur: float) -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 10
	sm.rings = 6
	ball.mesh = sm
	ball.material_override = _glow_mat(Color("#ffb03a"), 4.0)
	ball.position = from
	add_child(ball)
	var trail := _particles(Vector3.ZERO, Color("#ffe07a"), Color("#ff2a0a"), 40, 0.45, Vector2(0.2, 0.8), 0.3,
		{"one_shot": false, "explosive": 0.0, "spread": 180.0, "gravity": Vector3(0, 1.5, 0), "local": false, "parent": ball})
	var mid := from.lerp(to, 0.5) + Vector3(0, 2.2, 0)
	var fly := func(u: float) -> void:
		ball.position = from.lerp(mid, u).lerp(mid.lerp(to, u), u)
	var land := func() -> void:
		_explosion(to, Color("#ffd060"), Color("#ff3a0a"))
		Sfx.play("explosion", 0.1)
		trail.emitting = false
		ball.visible = false
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, dur)
	tw.tween_callback(land)
	tw.tween_interval(0.6)
	tw.tween_callback(ball.queue_free)


func _flame_pillar(p: Vector3) -> void:
	var pil := _beam(0.75, 4.5, Color("#ff7a1a"), 2.5)
	pil.position = Vector3(p.x, 2.25, p.z)
	pil.scale = Vector3(1, 0.05, 1)
	add_child(pil)
	var tw := create_tween()
	tw.tween_property(pil, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_out(pil, 0.9, 0.35)
	_particles(Vector3(p.x, 0.2, p.z), Color("#ffe07a"), Color("#ff2a0a"), 50, 0.9, Vector2(3.0, 6.0), 0.32,
		{"dir": Vector3.UP, "spread": 12.0, "radius": 0.5, "gravity": Vector3(0, 2.0, 0)})


## Abyssion beats its wings and a tidal wave rises in front of it and sweeps over every foe.
func _water(on_hit: Callable) -> void:
	var size: float = look["size"]
	var t := create_tween()
	for i in 2:
		t.tween_property(model, "scale", Vector3(size * 1.06, size * 0.95, size * 1.06), 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(model, "scale", Vector3.ONE * size, 0.16).set_trans(Tween.TRANS_SINE)
	Sfx.play("fly")
	await get_tree().create_timer(0.35).timeout
	var center := Vector3.ZERO
	for p in targets:
		center += p
	center = center / maxf(1.0, targets.size())
	var side := Vector3(toward.z, 0, -toward.x)
	var width := 9.0
	var wave := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, 4.6)
	qm.subdivide_width = 24
	qm.subdivide_depth = 8
	wave.mesh = qm
	var wm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WAVE_SHADER
	wm.shader = sh
	wave.material_override = wm
	var start := at + toward * 1.2
	var finish := Vector3(center.x, 0, center.z) + toward * 3.0
	wave.position = start + Vector3(0, 0.2, 0)
	wave.look_at_from_position(wave.position, wave.position + toward, Vector3.UP)
	wave.scale = Vector3(1, 0.15, 1)
	add_child(wave)
	var spray := _particles(Vector3(0, 1.8, 0), Color("#e8fbff"), Color("#3ab0ff"), 120, 0.8, Vector2(1.0, 3.5), 0.25,
		{"one_shot": false, "explosive": 0.0, "dir": Vector3(0, 1, 0), "spread": 40.0, "radius": width * 0.4, "gravity": Vector3(0, -6.0, 0), "local": false, "parent": wave})
	Sfx.play("ice")
	var tw := create_tween().set_parallel()
	tw.tween_property(wave, "position", finish + Vector3(0, 1.6, 0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(wave, "scale", Vector3(1.15, 1.0, 1), 0.5).set_trans(Tween.TRANS_BACK)
	var lt := OmniLight3D.new()
	lt.light_color = Color("#5ac8ff")
	lt.omni_range = 10.0
	lt.light_energy = 3.0
	wave.add_child(lt)
	await get_tree().create_timer(0.62).timeout
	bt.summon_shake(0.45)
	Sfx.play("explosion")
	for p in targets:
		_splash(p)
	on_hit.call()
	await get_tree().create_timer(0.45).timeout
	spray.emitting = false
	var tf := create_tween()
	tf.tween_method(func(f: float): wm.set_shader_parameter("fade", f), 1.0, 0.0, 0.5)
	tf.tween_callback(wave.queue_free)
	await get_tree().create_timer(0.6).timeout


func _splash(p: Vector3) -> void:
	_particles(Vector3(p.x, 0.3, p.z), Color("#ffffff"), Color("#3a90ff"), 70, 0.9, Vector2(3.0, 7.0), 0.28,
		{"dir": Vector3.UP, "spread": 35.0, "radius": 0.4, "gravity": Vector3(0, -12.0, 0)})
	_ring_burst(Vector3(p.x, 0.1, p.z), Color("#bfeaff"), 2.4, 0.5)


## Zephyrax swims a ring through the sky around the foes, whipping up a tornado, and lightning strikes each of them.
func _air(on_hit: Callable) -> void:
	var size: float = look["size"]
	var center := Vector3.ZERO
	for p in targets:
		center += p
	center = Vector3(center.x, 0, center.z) / maxf(1.0, targets.size())
	var r := 4.2
	var from_ang := atan2(model.position.z - center.z, model.position.x - center.x)
	var start := model.position
	Sfx.play("fly")
	var swim := func(u: float) -> void:
		var ang := from_ang + u * TAU * 1.1
		var p := center + Vector3(cos(ang) * r, 2.6 + sin(u * PI) * 1.2, sin(ang) * r)
		if u < 0.15:
			p = start.lerp(p, u / 0.15)
		var tangent := Vector3(-sin(ang), 0, cos(ang))
		model.position = p
		model.rotation.y = atan2(tangent.x, tangent.z)
	var spin := create_tween()
	spin.tween_method(swim, 0.0, 1.0, 1.6)
	# the tornado over the foes
	var tornado := Node3D.new()
	tornado.position = center
	add_child(tornado)
	for i in 3:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.6 + i * 0.7
		cm.bottom_radius = 0.35 + i * 0.25
		cm.height = 5.5
		cm.radial_segments = 20
		cm.cap_top = false
		cm.cap_bottom = false
		c.mesh = cm
		c.material_override = _beam_mat(Color("#c8fff0"), 2.0)
		c.position.y = 2.75
		tornado.add_child(c)
	tornado.scale = Vector3(0.1, 0.1, 0.1)
	var tt := create_tween().set_parallel()
	tt.tween_property(tornado, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
	tt.tween_property(tornado, "rotation:y", TAU * 6.0, 2.2)
	_particles(center + Vector3(0, 0.5, 0), Color("#ffffff"), Color("#7affd8"), 140, 1.4, Vector2(1.0, 3.0), 0.22,
		{"dir": Vector3.UP, "spread": 25.0, "radius": 2.2, "gravity": Vector3(0, 3.0, 0), "orbit": 2.5})
	await get_tree().create_timer(1.15).timeout
	for p in targets:
		_lightning(p)
	Sfx.play("crit")
	bt.summon_flash(Color("#e8ffff"))
	bt.summon_shake(0.5)
	on_hit.call()
	await get_tree().create_timer(0.3).timeout
	for p in targets:
		_lightning(p)
	await get_tree().create_timer(0.5).timeout
	var tf := create_tween()
	tf.tween_property(tornado, "scale", Vector3(1.6, 0.05, 1.6), 0.4).set_ease(Tween.EASE_IN)
	tf.tween_callback(tornado.queue_free)
	await get_tree().create_timer(0.3).timeout


func _lightning(p: Vector3) -> void:
	var bolt := Node3D.new()
	add_child(bolt)
	var mat := _glow_mat(Color("#e8ffff"), 6.0)
	var top := p + Vector3(randf_range(-1.0, 1.0), 9.0, randf_range(-1.0, 1.0))
	var prev := top
	var steps := 9
	for i in range(1, steps + 1):
		var u := float(i) / steps
		var q := top.lerp(p, u)
		if i < steps:
			q += Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var seg_len := prev.distance_to(q)
		bm.size = Vector3(0.09, 0.09, seg_len)
		seg.mesh = bm
		seg.material_override = mat
		seg.position = (prev + q) / 2.0
		seg.look_at_from_position(seg.position, q, Vector3.UP if absf((q - prev).normalized().y) < 0.99 else Vector3.FORWARD)
		bolt.add_child(seg)
		prev = q
	var lt := OmniLight3D.new()
	lt.light_color = Color("#c8f8ff")
	lt.light_energy = 6.0
	lt.omni_range = 6.0
	lt.position = p + Vector3(0, 1.0, 0)
	bolt.add_child(lt)
	_particles(p, Color("#ffffff"), Color("#7affd8"), 40, 0.5, Vector2(2.0, 5.0), 0.18, {"spread": 180.0, "gravity": Vector3(0, -4.0, 0)})
	var tw := create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func(): bolt.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func(): bolt.visible = true)
	tw.tween_interval(0.12)
	tw.tween_callback(bolt.queue_free)


## Terranox rears up and stamps: the ground cracks open and stone spikes burst up under every foe.
func _earth(on_hit: Callable) -> void:
	var size: float = look["size"]
	var rest := model.position
	var t := create_tween()
	t.tween_property(model, "position", rest + Vector3(0, size * 0.18, 0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(model, "position", rest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.51).timeout
	Sfx.play("smash")
	bt.summon_shake(0.9)
	_ring_burst(at + Vector3(0, 0.08, 0), Color("#ff6ad8"), 12.0, 0.9)
	_particles(at + Vector3(0, 0.2, 0), Color("#c8a070"), Color("#5a4030"), 80, 1.2, Vector2(2.0, 5.0), 0.4,
		{"dir": Vector3.UP, "spread": 70.0, "radius": size * 0.3, "gravity": Vector3(0, -3.0, 0)})
	await get_tree().create_timer(0.25).timeout
	for p in targets:
		_spikes(p)
	Sfx.play("explosion")
	bt.summon_shake(0.6)
	on_hit.call()
	await get_tree().create_timer(1.1).timeout


func _spikes(p: Vector3) -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("#5e5348")
	rock.roughness = 1.0
	rock.emission_enabled = true
	rock.emission = Color("#c84ad8")
	rock.emission_energy_multiplier = 0.06
	var group := Node3D.new()
	group.position = Vector3(p.x, 0, p.z)
	add_child(group)
	for i in 6:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.25, 0.45)
		cm.height = randf_range(1.6, 2.8)
		cm.radial_segments = 5
		s.mesh = cm
		s.material_override = rock
		var a := float(i) / 6.0 * TAU + randf() * 0.5
		var d := 0.35 if i > 0 else 0.0
		s.position = Vector3(cos(a) * d, cm.height * 0.5, sin(a) * d)
		s.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		s.scale = Vector3(1, 0.02, 1)
		group.add_child(s)
		var tw := create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(s, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_particles(Vector3(p.x, 0.3, p.z), Color("#a88060"), Color("#3a2a20"), 50, 1.0, Vector2(3.0, 6.0), 0.2,
		{"dir": Vector3.UP, "spread": 45.0, "radius": 0.5, "gravity": Vector3(0, -12.0, 0), "box": true})
	var gone := create_tween()
	gone.tween_interval(1.2)
	gone.tween_property(group, "position:y", -3.0, 0.5).set_ease(Tween.EASE_IN)
	gone.tween_callback(group.queue_free)


## Nocthrax raises its claws: the battle darkens, spirits swirl into a void over the foes, and it bursts.
func _ghost(on_hit: Callable) -> void:
	var size: float = look["size"]
	bt.summon_dim(0.2)
	Sfx.play("debuff")
	var t := create_tween()
	t.tween_property(model, "scale", Vector3(size * 1.1, size * 1.15, size * 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	var center := Vector3.ZERO
	for p in targets:
		center += p
	center = center / maxf(1.0, targets.size()) + Vector3(0, 1.2, 0)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	orb.mesh = sm
	orb.material_override = _beam_mat(Color("#8a4aff"), 0.0)
	orb.position = center
	orb.scale = Vector3.ONE * 0.1
	add_child(orb)
	var to := create_tween()
	to.tween_property(orb, "scale", Vector3.ONE * 2.2, 0.9).set_trans(Tween.TRANS_SINE)
	# spirits drawn in from all around
	_particles(center, Color("#d0b0ff"), Color("#4a1a8a"), 160, 1.0, Vector2(-5.0, -3.0), 0.3,
		{"spread": 180.0, "radius": 4.5, "gravity": Vector3.ZERO, "explosive": 0.2, "orbit": 3.0})
	await get_tree().create_timer(0.95).timeout
	Sfx.play("growl")
	var tc := create_tween()
	tc.tween_property(orb, "scale", Vector3.ONE * 0.2, 0.18).set_ease(Tween.EASE_IN)
	tc.tween_callback(orb.queue_free)
	await get_tree().create_timer(0.18).timeout
	bt.summon_flash(Color("#c8a0ff"))
	bt.summon_shake(0.7)
	Sfx.play("explosion")
	_ring_burst(Vector3(center.x, 0.1, center.z), Color("#a56bff"), 9.0, 0.7)
	_explosion(center, Color("#ffb07a"), Color("#5a2aaa"), 1.6)
	for p in targets:
		_particles(p, Color("#ff9a4a"), Color("#3a1a6a"), 40, 0.8, Vector2(1.0, 3.0), 0.3, {"spread": 180.0, "gravity": Vector3(0, 2.0, 0)})
	on_hit.call()
	var tb := create_tween()
	tb.tween_property(model, "scale", Vector3.ONE * size, 0.4)
	await get_tree().create_timer(0.9).timeout
	bt.summon_dim(0.55)


# ---------------------------------------------------------------- exit
func leave() -> void:
	var size: float = look["size"]
	Sfx.play("merge")
	_particles(model.position + Vector3(0, size * 0.2, 0), col("b"), col("a"), 90, 1.0, Vector2(1.5, 4.0), 0.25,
		{"spread": 180.0, "radius": size * 0.3, "gravity": Vector3(0, 2.5, 0)})
	var tw := create_tween().set_parallel()
	tw.tween_property(model, "scale", Vector3(size * 0.05, size * 1.6, size * 0.05), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(model, "position:y", model.position.y + 3.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_method(func(f: float): (circle.material_override as ShaderMaterial).set_shader_parameter("fade", f), 1.0, 0.0, 0.6)
	bt.summon_flash(col("b"))
	bt.summon_dim(1.0)
	await get_tree().create_timer(0.6).timeout
	bt.summon_release()
	await get_tree().create_timer(0.35).timeout
	queue_free()


# ---------------------------------------------------------------- building blocks
func _disc(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _circle_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CIRCLE_SHADER
	m.shader = sh
	m.set_shader_parameter("col", c)
	return m


func _beam_mat(c: Color, swirl := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	m.shader = sh
	m.set_shader_parameter("col", c)
	m.set_shader_parameter("swirl", swirl)
	return m


func _beam(radius: float, height: float, c: Color, swirl := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = _beam_mat(c, swirl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Fades a shader mesh (its "fade" parameter) out over `dur` after `wait`, then frees it.
func _fade_out(mi: MeshInstance3D, dur: float, wait := 0.0) -> void:
	var m := mi.material_override as ShaderMaterial
	var tw := create_tween()
	if wait > 0.0:
		tw.tween_interval(wait)
	tw.tween_method(func(f: float): m.set_shader_parameter("fade", f), 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)


## A shockwave: a flat ring that races outwards and fades.
func _ring_burst(p: Vector3, c: Color, radius: float, dur: float) -> void:
	var ring := _disc(1.0, _circle_mat(c))
	ring.position = p
	ring.scale = Vector3(0.1, 1, 0.1)
	add_child(ring)
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 1, radius), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(f: float): (ring.material_override as ShaderMaterial).set_shader_parameter("fade", f), 1.0, 0.0, dur)
	tw.chain().tween_callback(ring.queue_free)


func _explosion(p: Vector3, a: Color, b: Color, k := 1.0) -> void:
	_particles(p, a, b, int(70 * k), 0.75, Vector2(2.5 * k, 6.0 * k), 0.42 * k, {"spread": 180.0, "gravity": Vector3(0, 1.0, 0)})
	_particles(p, Color(0.25, 0.22, 0.22, 0.9), Color(0.1, 0.1, 0.1, 0.0), int(30 * k), 1.3, Vector2(0.8, 2.0), 0.7 * k,
		{"spread": 180.0, "gravity": Vector3(0, 1.5, 0), "mix": true})
	var lt := OmniLight3D.new()
	lt.light_color = a
	lt.light_energy = 5.0
	lt.omni_range = 5.0 * k
	lt.position = p
	add_child(lt)
	var tw := create_tween()
	tw.tween_property(lt, "light_energy", 0.0, 0.5)
	tw.tween_callback(lt.queue_free)


## One-shot (or continuous) billboard sparks fading from `a` to `b`. opts: one_shot, explosive, dir, spread, radius,
## gravity, local (false: the sparks stay where they were emitted), orbit (swirl speed), box (tumbling rock chips),
## mix (normal blending instead of additive, for smoke), parent (the node to attach to; this one by default).
func _particles(p: Vector3, a: Color, b: Color, amount: int, life: float, speed: Vector2, size: float, opts := {}) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.position = p
	ps.amount = maxi(4, amount)
	ps.lifetime = life
	ps.one_shot = opts.get("one_shot", true)
	ps.explosiveness = float(opts.get("explosive", 0.92))
	ps.local_coords = opts.get("local", true)
	ps.direction = opts.get("dir", Vector3.UP)
	ps.spread = float(opts.get("spread", 180.0))
	ps.initial_velocity_min = speed.x
	ps.initial_velocity_max = speed.y
	ps.gravity = opts.get("gravity", Vector3(0, -2.0, 0))
	var radius := float(opts.get("radius", 0.0))
	if radius > 0.0:
		ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		ps.emission_sphere_radius = radius
	if opts.has("orbit"):
		ps.tangential_accel_min = float(opts["orbit"]) * 2.0
		ps.tangential_accel_max = float(opts["orbit"]) * 3.0
		ps.radial_accel_min = -2.0
		ps.radial_accel_max = -1.0
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, a)
	ramp.set_color(1, Color(b, 0.0))
	ramp.add_point(0.6, b)
	ps.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if opts.get("box", false):
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * size
		bm.material = mat
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		ps.mesh = bm
		ps.angular_velocity_min = -360.0
		ps.angular_velocity_max = 360.0
	else:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = _soft
		if not opts.get("mix", false):
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * size
		qm.material = mat
		ps.mesh = qm
	(opts.get("parent", self) as Node).add_child(ps)
	ps.emitting = true
	if ps.one_shot:
		var tw := create_tween()
		tw.tween_interval(life + 0.6)
		tw.tween_callback(ps.queue_free)
	return ps
