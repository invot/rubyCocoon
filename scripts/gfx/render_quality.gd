extends Node
## Apply one rendering preset to new and existing scenes, including portraits and cinematic stages.
## Remember authored flags on each node so Max never enables shadows/effects on deliberately unlit scenery.
## Registration is deferred until builders finish assigning their properties. No per-frame tree traversal.

const GROUP := &"render_quality_nodes"
const BASELINE := &"render_quality_baseline"
var _quality := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_node_added)
	Prefs.changed.connect(_refresh)
	_refresh()


func _node_added(node: Node) -> void:
	if node is SubViewport or node is WorldEnvironment or node is Light3D:
		_register.call_deferred(node)


func _register(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if not node.has_meta(BASELINE):
		var base := {}
		if node is WorldEnvironment:
			var env: Environment = node.environment
			if env == null:
				return
			if not env.has_meta(BASELINE):
				env.set_meta(BASELINE, {"glow": env.glow_enabled, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled})
			base = env.get_meta(BASELINE)
		elif node is Light3D:
			base = {"shadow": node.shadow_enabled}
		node.set_meta(BASELINE, base)
	node.add_to_group(GROUP)
	_apply_node(node)


func _refresh() -> void:
	if _quality == Prefs.graphics_quality:
		return
	_quality = Prefs.graphics_quality
	for node in get_tree().get_nodes_in_group(GROUP):
		_apply_node(node)


func _apply_node(node: Node) -> void:
	var base: Dictionary = node.get_meta(BASELINE)
	if node is SubViewport:
		node.msaa_3d = {"min": Viewport.MSAA_DISABLED, "mid": Viewport.MSAA_2X, "max": Viewport.MSAA_4X}[_quality]
		node.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	elif node is Light3D:
		node.shadow_enabled = base["shadow"] and _quality != "min"
	elif node is WorldEnvironment and node.environment != null:
		var env: Environment = node.environment
		env.glow_enabled = base["glow"] and _quality != "min"
		var method := RenderingServer.get_current_rendering_method()
		var maximum := _quality == "max"
		# Godot 4.7 also supports SSAO on Compatibility; SSIL and SSR still require Forward+.
		env.ssao_enabled = base["ssao"] and maximum and method != "mobile"
		env.ssil_enabled = base["ssil"] and maximum and method == "forward_plus"
		env.ssr_enabled = base["ssr"] and maximum and method == "forward_plus"
