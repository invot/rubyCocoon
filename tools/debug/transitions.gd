extends RefCounted
## Times whole map transitions as the player meets them, fades and black hold included, and checks that none of them
## puts a loading message on screen. Run in a fresh process with an isolated --save_dir. Windowed runs are VSync-capped,
## which is what a player gets; headless runs measure CPU work only.
##   --passes=2  how many times to walk the route (the first is cold, later ones reuse caches)
##   --shot=path  the arrival view of the last step, and <path>_black.<ext> from the middle of its black hold
##   --battles=2  then fight this many battles, reporting the longest frame of each (Compatibility stalls on first draw)
const Beasts = preload("res://scripts/core/beasts.gd")
const MapLoader = preload("res://scripts/world/map_loader.gd")

var report := {}
var bad := 0
var _main
var _trace := {}
var _black_shot := ""


func run(main, opts: Dictionary) -> void:
	_main = main
	UI.auto = true
	for flag in ["intro_done", "tutorial_done", "ritual_done", "opening_seen"]:
		GameState.set_flag(flag)
	GameState.party = [Beasts.create(0, 10)]
	var route := [
		["caccoon", "start"],
		[MapLoader.interior_of("caccoon", "home"), "entry"],
		["caccoon", "start"],
		[MapLoader.interior_of("caccoon", "center"), "entry"],
		["caccoon", "start"],
		["route1", "west"],
		["tidewater", "center"],
		[MapLoader.interior_of("tidewater", "center"), "entry"],
		["tidewater", "center"],
		["cogsworth", "start"],
	]
	var passes := int(opts.get("passes", "2"))
	var shot := String(opts.get("shot", ""))
	var tree: SceneTree = main.get_tree()
	tree.process_frame.connect(_sample)
	for p in passes:
		for i in route.size():
			var step: Array = route[i]
			var last := p == passes - 1 and i == route.size() - 1
			if last and shot != "":
				_black_shot = "%s_black.%s" % [shot.get_basename(), shot.get_extension()]
			var now := Time.get_ticks_usec()
			_trace = {"began": now, "last": now, "frames": 0, "gap": 0, "black_began": -1, "black_ended": -1}
			await main._do_goto(step[0], step[1])
			var done := Time.get_ticks_usec()
			var key := "pass%d_%02d_%s" % [p + 1, i, String(step[0]).replace("#", "_")]
			report[key] = {
				"total_ms": snappedf((done - int(_trace["began"])) / 1000.0, 0.1),
				"black_ms": snappedf(maxf(0.0, (int(_trace["black_ended"]) - int(_trace["black_began"])) / 1000.0), 0.1),
				"frames": int(_trace["frames"]),
				"largest_gap_ms": snappedf(int(_trace["gap"]) / 1000.0, 0.1),
			}
			print("[transition] %s %s" % [key, JSON.stringify(report[key])])
			await tree.create_timer(0.15).timeout
	for b in int(opts.get("battles", "0")):
		main.autoplay = true
		var now := Time.get_ticks_usec()
		_trace = {"began": now, "last": now, "frames": 0, "gap": 0, "black_began": -1, "black_ended": -1}
		await main.start_battle({"wild": true, "foes": [Beasts.create(27, 3)], "seed": 5})
		var key := "battle_%d" % (b + 1)
		report[key] = {"total_ms": snappedf((Time.get_ticks_usec() - now) / 1000.0, 0.1), "largest_gap_ms": snappedf(int(_trace["gap"]) / 1000.0, 0.1)}
		print("[transition] %s %s" % [key, JSON.stringify(report[key])])
		main.autoplay = false
		await tree.create_timer(0.15).timeout
	tree.process_frame.disconnect(_sample)
	if shot != "":
		await _main._wait(0.6)
		_main._save_shot(shot)
	var path := String(opts.get("report", ""))
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	UI.auto = false
	print("TRANSITIONS DONE: %d problem(s)" % bad)


func _sample() -> void:
	if _trace.is_empty():
		return
	var now := Time.get_ticks_usec()
	_trace["frames"] += 1
	_trace["gap"] = maxi(int(_trace["gap"]), now - int(_trace["last"]))
	_trace["last"] = now
	if UI.fade_rect.color.a < 0.999:
		return
	if int(_trace["black_began"]) < 0:
		_trace["black_began"] = now
	_trace["black_ended"] = now
	# While the screen is black, nothing should be telling the player they're waiting.
	for label in UI.root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and String(label.text).to_lower().contains("loading"):
			bad += 1
			print("FAIL a loading message is on screen: ", label.text)
			break
	if _black_shot != "" and now - int(_trace["black_began"]) > 30000:
		_main._save_shot(_black_shot)
		_black_shot = ""
