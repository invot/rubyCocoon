extends RefCounted
## Items lying about the world sit in KayKit chests (world.gd _build_items / _pickup, temple_props.gd chest()): the lid
## swings open when the item is taken, the emptied chest stays open and solid, and it is built open again on the next
## visit. Also builds the temple's gold chest and the KayKit crates and barrels.
##   godot --path . -- --scene=item-chests --save_dir=res://build/item_chest_tests/ [--shots=res://build/shots/chests/c]
const TempleProps = preload("res://scripts/gfx/temple_props.gd")
const HouseBuilder = preload("res://scripts/gfx/house_builder.gd")
var bad := 0
var main: Node


func check(ok: bool, message: String) -> void:
	if not ok:
		bad += 1
	print("%s %s" % ["ok" if ok else "FAIL", message])


func shot(opts: Dictionary, name: String) -> void:
	if opts.has("shots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		main._save_shot(String(opts["shots"]) + "_" + name + ".png")


func run(root: Node, opts: Dictionary) -> void:
	main = root
	check(GameState.save_dir().begins_with("res://build/"), "only isolated saves")
	GameState.inventory = {}
	await main._go(String(opts.get("map", "caccoon")), "start")
	var w = main.world
	w.frozen = true
	await main._wait(0.6)
	check(w._street_mesh("bench").resource_path.get_file() == "kaykit_stool_bench.res", "street benches are the stretched KayKit stool")
	if opts.has("benches"):
		# for the screenshots: both stretched benches (chair, stool) in front of the hero, looking at the camera
		for k in 2:
			var b := MeshInstance3D.new()
			b.mesh = load("res://assets/exteriors/%s.res" % ["kaykit_bench", "kaykit_stool_bench"][k])
			b.position = w.tile_pos(w.player_pos + Vector2i(-2 + k * 3, 2)) + Vector3(0.5, 0, 0)
			w.add_child(b)
	# a chest just east of the hero, the hero turned to it
	var at: Vector2i = w.player_pos + Vector2i(1, 0)
	check(w._walkable(at), "test tile beside the hero is free")
	var it := {"item": "potion", "count": 2, "flag": "item_chest_test", "pos": at}
	w.map["items"].append(it)
	var chest: Node3D = TempleProps.chest(false, false)
	chest.position = w.tile_pos(at)
	w.add_child(chest)
	it["node"] = chest
	w.items[at] = it
	w.facing = Vector2i(1, 0)
	var lid: Node3D = chest.get_node_or_null("Lid")
	check(lid != null and is_zero_approx(lid.rotation.x), "a new chest is shut, with a hinged lid")
	check(chest.find_children("*", "MeshInstance3D", true, false).size() == 2, "chest is the KayKit base and lid")
	check(not w._walkable(at), "a closed chest blocks its tile")
	await shot(opts, "closed")
	w._pickup(it)
	await main._wait(0.18)
	await shot(opts, "opening")
	await main._wait(0.6)
	check(is_equal_approx(lid.rotation.x, TempleProps.LID_OPEN), "taking the item swings the lid open")
	check(GameState.item_count("potion") == 2 and GameState.flag("item_chest_test"), "the item went into the bag")
	check(is_instance_valid(chest) and chest.is_inside_tree(), "the emptied chest stays")
	check(not w.items.has(at) and w.opened_chests.has(at), "it is no longer an item, but an opened chest")
	check(not w._walkable(at) and w._usable(at) == "", "the open chest still blocks its tile and offers nothing")
	await shot(opts, "open")
	# a revisit: the flag set, the chest is built open
	var again := {"item": "potion", "flag": "item_chest_test", "pos": at + Vector2i(0, 1)}
	w.map["items"] = [again]
	w.items.clear()
	w._build_items()
	var built: Node3D = w.opened_chests.get(again["pos"])
	check(built != null and is_equal_approx(built.get_node("Lid").rotation.x, TempleProps.LID_OPEN), "a taken chest is built open on the next visit")
	check(not w.items.has(again["pos"]), "and holds nothing to take")
	built.queue_free()
	# a temple's treasure, gold-filled
	var gold := TempleProps.chest(true, true)
	check(gold.get_node_or_null("Lid") != null and gold.find_children("*", "MeshInstance3D", true, false).size() == 2, "temple chest is KayKit's gold chest")
	gold.free()
	for name in HouseBuilder.KAYKIT:
		var m: Mesh = HouseBuilder.piece(name)
		check(m != null and m.resource_path.get_file().begins_with("kaykit_"), "%s is KayKit's" % name)
	for key in ["barrel", "crates"]:
		check(String(load("res://scripts/data/voxel_manifest.gd").ASSETS.get(key, "")).get_file().begins_with("kaykit_"), "scenery %s is KayKit's" % key)
	print("ITEM CHESTS DONE: %d problem(s)" % bad)
