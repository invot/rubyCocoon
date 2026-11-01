extends RefCounted
## Repeatable CPU stall audit. Run in a fresh process, with an isolated --save_dir.
## Reports wall time as well as individual frame gaps; headless results measure CPU work only.
const Beasts = preload("res://scripts/core/beasts.gd")
const BeastModel = preload("res://scripts/gfx/beast_model.gd")
const HeroMaker = preload("res://scripts/ui/hero_maker.gd")

var report := {}
var bad := 0

func run(main, opts: Dictionary) -> void:
	UI.auto = true
	GameState.set_flag("intro_done")
	GameState.set_flag("tutorial_done")
	GameState.set_flag("ritual_done")
	GameState.party = [Beasts.create(0, 10)]
	var began := Time.get_ticks_usec()
	var maker := HeroMaker.new()
	UI.push(maker)
	_record("creator_open_ms", began)
	for id in ["name", "top", "outfit", "hairdo", "body"]:
		var samples := []
		for i in 12:
			began = Time.get_ticks_usec()
			maker._change(id, 1)
			samples.append((Time.get_ticks_usec() - began) / 1000.0)
			await main.get_tree().process_frame
		report["creator_" + id] = _stats(samples)
	maker.close(null)
	await main.get_tree().process_frame
	for form in ["dino_1", "owl_1", "beetle_3"]:
		var samples := []
		for i in 8:
			began = Time.get_ticks_usec()
			var rig := BeastModel.rig({"form": form})
			samples.append((Time.get_ticks_usec() - began) / 1000.0)
			var cached := BeastModel.rig({"form": form})
			_check(is_equal_approx(rig.height(), cached.height()) and rig._feet == cached._feet and rig._swing == cached._swing,
				"cached animation measurements match " + form)
			cached.free()
			rig.free()
		report["beast_" + form] = _stats(samples)
	began = Time.get_ticks_usec()
	var battle_script = main.loaded_script(main.BATTLE_PATH)
	_record("battle_script_ms", began)
	began = Time.get_ticks_usec()
	battle_script.prewarm()
	_record("ring_prepare_ms", began)
	var layouts := {}
	for town in String(opts.get("maps", "caccoon,tidewater,cogsworth,route1")).split(","):
		var loading_frames := []
		var frame_clock := {"last": Time.get_ticks_usec()}
		var sample_frame := func():
			var now := Time.get_ticks_usec()
			loading_frames.append((now - int(frame_clock["last"])) / 1000.0)
			frame_clock["last"] = now
		main.get_tree().process_frame.connect(sample_frame)
		began = Time.get_ticks_usec()
		await main._load_world(town, "start")
		_record("map_" + town + "_ms", began)
		main.get_tree().process_frame.disconnect(sample_frame)
		if not loading_frames.is_empty():
			report["loading_frames_" + town] = _stats(loading_frames)
		var world = main.world
		world.busy = true
		world.set_process(false)
		layouts[town] = hash(world.map["tiles"] if world.map.has("tiles") else world.map.get("grid", []))
		var samples := []
		for f in world.building_fades:
			if is_instance_valid(f["node"]):
				continue
			began = Time.get_ticks_usec()
			world._load_building(f)
			samples.append((Time.get_ticks_usec() - began) / 1000.0)
			await main.get_tree().process_frame
		if not samples.is_empty():
			report["buildings_" + town] = _stats(samples)
		world.set_process(true)
		world.frozen = true
		var frames := []
		var last := Time.get_ticks_usec()
		for i in 120:
			await main.get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
		report["frames_" + town] = _stats(frames)
		# Free off-screen nodes that were cached; the cache must remain bounded on a map tour.
		var hidden := 0
		for f in world.building_fades:
			if is_instance_valid(f["node"]) and not f["node"].visible:
				hidden += 1
		_check(hidden <= world.HIDDEN_BUILDING_CACHE, "hidden building cache is bounded")
	report["layouts"] = layouts
	if opts.has("baseline"):
		var baseline = JSON.parse_string(FileAccess.get_file_as_string(String(opts["baseline"])))
		for town in layouts:
			_check(int(baseline["layouts"].get(town, -1)) == int(layouts[town]), town + " collision grid unchanged")
	print("[stalls] ", JSON.stringify(report))
	var path := String(opts.get("report", ""))
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	UI.auto = false
	print("PERFORMANCE AUDIT DONE: %d problem(s)" % bad)

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
		print("FAIL ", label)

func _record(label: String, began: int) -> void:
	report[label] = (Time.get_ticks_usec() - began) / 1000.0
	print("[stalls] %s: %.2f" % [label, report[label]])

func _stats(samples: Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	return {"first_ms": samples[0], "median_ms": sorted[sorted.size() / 2],
		"p95_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max_ms": sorted.back()}
