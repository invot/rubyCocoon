extends SceneTree
## Resource, routing, loop-boundary and rapid-transition checks. Never reads or writes player saves.

const MapLoader = preload("res://scripts/world/map_loader.gd")
var bad := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		bad += 1
	print("ok " if ok else "FAIL ", label)

func _run() -> void:
	var sfx = root.get_node("Sfx")
	for key in sfx.SOUNDS:
		var spec: Array = sfx.SOUNDS[key]
		if spec.is_empty():
			continue
		for path in spec[0]:
			if not ResourceLoader.exists(path):
				_check(false, "%s missing: %s" % [key, path])
				continue
			var stream = load(path)
			_check(stream is AudioStream and stream.get_length() > 0.0, "%s loads: %s" % [key, path])
	for key in sfx.AMBIENCE:
		var path: String = sfx.AMBIENCE[key]
		if not ResourceLoader.exists(path):
			_check(false, "%s ambience missing: %s" % [key, path])
			continue
		var stream = load(path)
		_check(stream is AudioStream and stream.get_length() > 0.0, "%s ambience loads" % key)
	# These replacements must reach a live player, including short dialogue syllables at a speaker's pitch.
	for key in ["crit", "hatch", "toggle", "talk", "fail", "stinger"]:
		var next_player: int = sfx._next
		if key == "talk":
			sfx.play_pitched(key, 0.8)
		else:
			sfx.play(key)
		var player: AudioStreamPlayer = sfx._players[next_player]
		_check(sfx._next != next_player and player.playing and player.stream is AudioStreamOggVorbis
			and player.bus == "SFX", "%s reaches a live SFX player" % key)
		if key == "talk":
			var expected := 0.8 * pow(2.0, 3.0 / 12.0)
			_check(player.pitch_scale >= expected * 0.97 - 0.00001
				and player.pitch_scale <= expected * 1.03 + 0.00001,
				"dialogue adds three semitones while preserving speaker pitch and jitter")
	var main = load("res://scripts/main.gd").new()
	_check(main.ambience_for("shellhaven") == "surf", "Shellhaven routes to surf")
	_check(main.ambience_for("route1") == "forest", "Coastal Path routes to nature")
	for town in ["shellhaven", "tidewater"]:
		_check(main.ambience_for(MapLoader.interior_of(town, "center")) == "", "%s center has no outdoor ambience" % town)
	_check(main.ambience_for(MapLoader.interior_of("cogsworth", "ceo_tower")) == "machines", "Gearhart Tower routes to machines")
	_check(main.ambience_for("gravenmoor") == "ghostly", "moor exteriors route to the spell texture")
	_check(main.ambience_for(MapLoader.interior_of("gravenmoor", "cathedral")) == "cathedral", "cathedral routes to the forest drone")
	main.free()
	sfx.ambience("surf")
	await create_timer(sfx.FADE_TIME + 0.1).timeout
	var surf = sfx._ambience.stream
	_check(surf is AudioStreamOggVorbis and surf.loop, "surf enables Ogg looping")
	_check(is_equal_approx(sfx._ambience.volume_db, -18.0), "surf stays beneath the music")
	await create_timer(surf.get_length() + 0.1).timeout
	_check(sfx._ambience.playing, "surf continues beyond its twelve-second boundary")
	# The old fade-out callback must not stop a newly started outdoor loop.
	sfx.ambience("")
	await create_timer(sfx.FADE_TIME * 0.2).timeout
	sfx.ambience("forest")
	await create_timer(sfx.FADE_TIME + 0.1).timeout
	_check(sfx._ambience.playing and sfx._ambience.stream.resource_path == sfx.AMBIENCE.forest,
		"a rapid indoor/outdoor transition keeps the new loop playing")
	_check(sfx._ambience.stream.loop and is_equal_approx(sfx._ambience.volume_db, -20.0), "nature loops at its quiet level")
	sfx.ambience("machines")
	await create_timer(sfx.FADE_TIME + 0.1).timeout
	_check(sfx._ambience.playing and sfx._ambience.stream.loop
		and is_equal_approx(sfx._ambience.volume_db, -18.0), "machine ambience loops at its quiet level")
	for key in ["ghostly", "cathedral"]:
		sfx.ambience(key)
		await create_timer(sfx.FADE_TIME + 0.1).timeout
		_check(sfx._ambience.playing and sfx._ambience.stream is AudioStreamOggVorbis
			and sfx._ambience.stream.loop and sfx._ambience.stream.resource_path == sfx.AMBIENCE[key]
			and is_equal_approx(sfx._ambience.volume_db, -20.0), "%s loops at its quiet level" % key)
	sfx.ambience("")
	await create_timer(sfx.FADE_TIME + 0.1).timeout
	_check(not sfx._ambience.playing, "an interior without ambience fades to silence")
	print("AUDIO CHECK DONE: %d problem(s)" % bad)
	quit(1 if bad > 0 else 0)
