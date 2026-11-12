extends RefCounted
## Lists every drawn 3D surface that has no texture, across every town, road and room (with all buildings loaded),
## a battle on each kind of stage, every beast and the title set. Also counts the kinds of material (each kind is a
## shader the renderer has to compile).
##   --maps=caccoon,route1     only these maps (and their rooms unless --rooms=0)
##   --report=res://build/texture_audit.json
##   --verify=1                fail (and say so) if anything that isn't a listed effect is untextured
const Beasts = preload("res://scripts/core/beasts.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")
const WorldDB = preload("res://scripts/data/world_db.gd")
const VT = preload("res://scripts/gfx/voxel_textures.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")

## Effects that are light, shade or glow rather than objects: named by a node, or an ancestor, in the "untextured_fx"
## group, or by one of these scripts on the node or an ancestor.
const FX_GROUP := &"untextured_fx"
const FX_SCRIPTS := ["contact_shadow.gd", "cast_glow.gd", "target_arrow.gd", "beat_cue.gd", "summon_fx.gd"]
## Shaders that paint their own pattern (boards, stucco, roof tiles, leaves) rather than sampling an image.
const PATTERNED := ["island_wood.gdshader", "cove_stucco.gdshader", "cove_roof.gdshader", "lily_pad.gdshader", "hut_plaster.gdshader"]

## group -> {"count", "where": {place: true}, "example"}
var bare := {}
var kinds := {}
var surfaces := 0
var bad := 0


func run(main, opts: Dictionary) -> void:
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	var tree: SceneTree = main.get_tree()
	Engine.time_scale = 8.0
	var ids: Array = Array(String(opts["maps"]).split(",")) if opts.has("maps") else WorldDB.TOWNS.keys() + WorldDB.ROUTES.keys()
	for id in ids:
		await main._load_world(id, "start")
		main.world.frozen = true
		for f in main.world.building_fades:
			main.world._load_building(f)
			main.world._set_building_opacity(f, 1.0)
		await tree.process_frame
		audit(main.world, id)
		if opts.get("rooms", "1") == "1":
			for b in main.world.map.get("buildings", []).duplicate():
				for f in range(1, MapLoader.room_set(b).size() + 1):
					var room := MapLoader.floor_id(b["interior"], f)
					await main._load_world(room, "entry")
					main.world.frozen = true
					await tree.process_frame
					audit(main.world, "room:" + String(b["shop"]))
	if opts.get("beasts", "1") == "1":
		var RaceDB = load("res://scripts/data/race_db.gd")
		var races: Array = range(RaceDB.count())
		races.append_array(RaceDB.LEGENDARY)
		for race in races:
			for ghost in [false, true]:
				var model: Node3D = main.world._beast_node(Beasts.create(race, 5, ghost).genes)
				main.world.add_child(model)
				audit(model, "ghost" if ghost else "beast")
				model.free()
	Engine.time_scale = 1.0
	var keys := bare.keys()
	keys.sort_custom(func(a, b): return bare[a]["count"] > bare[b]["count"])
	var objects := 0
	for k in keys:
		var e: Dictionary = bare[k]
		var fx: bool = e["fx"]
		if not fx:
			objects += 1
		print("[untextured]%s x%-5d %s   in %s" % [" (effect)" if fx else "", e["count"], k, ", ".join(e["where"].keys().slice(0, 4))])
	print("[texture audit] %d surfaces, %d untextured groups (%d of them objects), %d material kinds" % [surfaces, keys.size(), objects, kinds.size()])
	var path := String(opts.get("report", ""))
	if path != "":
		var out := {}
		for k in keys:
			out[k] = {"count": bare[k]["count"], "fx": bare[k]["fx"], "where": bare[k]["where"].keys()}
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"untextured": out, "kinds": kinds.keys(), "surfaces": surfaces}, "\t"))
	if opts.get("verify", "0") == "1":
		bad = objects
	UI.auto = false
	print("TEXTURE AUDIT DONE: %d problem(s)" % bad)


func audit(root: Node, place: String) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not n is GeometryInstance3D or not (n as Node3D).is_visible_in_tree():
			continue
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh != null:
			mesh = n.multimesh.mesh
		elif n is GPUParticles3D or n is CPUParticles3D:
			continue
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat: Material = n.material_override
			if mat == null and n is MeshInstance3D:
				mat = n.get_active_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			surfaces += 1
			if mat is BaseMaterial3D:
				kinds[VT._kind_of(mat)] = true
			elif mat is ShaderMaterial and mat.shader != null:
				kinds["shader:" + mat.shader.resource_path] = true
			if _textured(mat):
				continue
			var key := "%s | %s | %s" % [_trail(n, root), _mesh_name(mesh), _mat_name(mat)]
			if not bare.has(key):
				bare[key] = {"count": 0, "where": {}, "fx": _is_fx(n, mat)}
			bare[key]["count"] += 1
			bare[key]["where"][place] = true


static func _textured(mat: Material) -> bool:
	if mat == null:
		return false
	if mat is BaseMaterial3D:
		return mat.albedo_texture != null or (mat.emission_enabled and mat.emission_texture != null)
	if mat is ShaderMaterial and mat.shader != null:
		if mat.shader.resource_path.get_file() in PATTERNED:
			return true
		for u in mat.shader.get_shader_uniform_list():
			if int(u.get("type", 0)) == TYPE_OBJECT:
				var v = mat.get_shader_parameter(u["name"])
				if v != null:
					return true
				var d = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), u["name"])
				if d != null:
					return true
		return false
	return false


static func _is_fx(n: Node, mat: Material) -> bool:
	# light rather than an object: unshaded glows and lamps, see-through effects (surface_finish.gd leaves these)
	if mat is BaseMaterial3D and (mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			or (mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a < 0.95)):
		return true
	var at := n
	while at != null:
		if at.is_in_group(FX_GROUP):
			return true
		var sc: Script = at.get_script()
		if sc != null and sc.resource_path.get_file() in FX_SCRIPTS:
			return true
		at = at.get_parent()
	return false


## The names of the node and up to three ancestors, without instance numbers, so repeats group together.
static func _trail(n: Node, root: Node) -> String:
	var parts := []
	var at := n
	while at != null and at != root and parts.size() < 4:
		var name := String(at.name)
		var sc: Script = at.get_script()
		if name.begins_with("@"):
			name = at.get_class()
		name = name.rstrip("0123456789")
		if sc != null:
			name += "(" + sc.resource_path.get_file() + ")"
		parts.push_front(name)
		at = at.get_parent()
	return "/".join(parts)


static func _mesh_name(mesh: Mesh) -> String:
	return mesh.resource_path.get_file() if mesh.resource_path != "" else mesh.get_class()


static func _mat_name(mat: Material) -> String:
	if mat == null:
		return "no material"
	if mat is BaseMaterial3D:
		var bits := [mat.resource_path.get_file() if mat.resource_path != "" and not "::" in mat.resource_path else "colour #" + mat.albedo_color.to_html(false)]
		if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			bits.append("unshaded")
		if mat.vertex_color_use_as_albedo:
			bits.append("vertex colours")
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			bits.append("see-through")
		if mat.emission_enabled:
			bits.append("glowing")
		return " ".join(bits)
	if mat is ShaderMaterial:
		return "shader " + (mat.shader.resource_path.get_file() if mat.shader != null else "none")
	return mat.get_class()
