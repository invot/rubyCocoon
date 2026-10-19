extends Node
## Music, ambience and sound effects. Music tracks are the game-ready copies in assets/audio/music
## (made from music/ by tools/convert_audio.py); effects come from sfx/. Flute notes are synthesised.

const RATE := 22050
const MUSIC_DIR := "res://assets/audio/music/"
const FADE_TIME := 0.8

## Music keys -> track files. world_db.gd / main.gd decide which key plays where.
const TRACKS := {
	"title": "journey_to_ascend",
	"ending": "journey_to_ascend",
	"home": "wholesome",
	"coast": "adventures_in_adventureland",
	"island": "poofy_reel",
	"desert": "howling_hound_music_retro_egyptian_theme_187380",
	"western": "desert_city",
	"mountain": "industrious_ferret",
	"summit": "at_launch",
	"steampunk": "ethernight_club",
	"volcano": "monume_retro_arcade_game_music_577980",
	"hotspring": "magic_scout_cottages",
	"jungle": "wind_of_the_rainforest",
	"river": "pleasant_porridge",
	"moor": "unanswered_questions",
	"temple": "ancient_rite",
	"crypt": "ether_vox",
	"hideout": "half_mystery",
	"tower": "djartmusic_the_return_of_the_8_bit_era_301292",
	"arena": "monume_retro_arcade_game_music_547917",
	"shop": "derp_nugget",
	"center": "screen_saver",
	"house": "magic_scout_manor",
	"silly": "farting_around",
	"battle": "rising_tide",
	"victory": "android_sock_hop",
	"andreas": "andreas_theme",
	"krampus": "krampus_workshop",
	"boss": "rising_tide_faster",
}

## Effect keys -> one or more files (a random one plays). Volume in dB.
const SOUNDS := {
	"blip": [["res://sfx/Select/Blip_Select3.wav"], -22.0],
	"select": [["res://sfx/01_UI_Menu/UI_Menu_Hover_001.mp3"], -12.0],
	"confirm": [["res://sfx/01_UI_Menu/UI_Menu_Confirm_001.mp3"], -9.0],
	"back": [["res://sfx/01_UI_Menu/UI_Menu_Click_001.mp3"], -10.0],
	"error": [["res://sfx/01_UI_Menu/UI_Menu_Error_001.mp3"], -9.0],
	"open": [["res://sfx/01_UI_Menu/UI_Menu_OpenMenu_001.mp3"], -8.0],
	"page": [["res://sfx/UI Samples/UI_Guitar_Percussion_Select_1.wav", "res://sfx/UI Samples/UI_Guitar_Percussion_Select_2.wav"], -10.0],
	"toggle": [["res://sfx/UI Samples/UI_SteelDrum_Toggle_1.wav"], -10.0],
	"notify": [["res://sfx/06_Feedback/Feedback_Notification_001.mp3"], -10.0],
	"talk": [["res://sfx/UI Samples/UI_WahTube_Select.wav"], -16.0],
	"hit": [["res://sfx/03_Combat/Combat_Punch_001.mp3", "res://sfx/Hit/Hit_Hurt.wav", "res://sfx/Hit/Hit_Hurt3.wav", "res://sfx/Hit/Hit_Hurt5.wav"], -8.0],
	"metal_hit": [["res://sfx/BitCrushHits/MetalicHit_Crush_Impact_01.wav", "res://sfx/BitCrushHits/MetalicHit_Crush_Impact_03.wav", "res://sfx/BitCrushHits/MetalicHit_Crush_Impact_05.wav"], -10.0],
	"crit": [["res://sfx/03_Combat/Combat_CriticalHit_001.mp3"], -6.0],
	"miss": [["res://sfx/03_Combat/Combat_SwordSwing_001.mp3"], -10.0],
	"shield": [["res://sfx/03_Combat/Combat_ShieldBlock_001.mp3"], -6.0],
	"slingshot": [["res://sfx/02_Player_Actions/Player_Actions_Dash_001.mp3"], -10.0],
	"explosion": [["res://sfx/Explosion/Explosion3.wav", "res://sfx/Explosion/Explosion6.wav"], -11.0],
	"fire": [["res://sfx/10_Magic_Abilities/Magic_Abilities_FireSpell_001.mp3"], -9.0],
	"ice": [["res://sfx/10_Magic_Abilities/Magic_Abilities_IceSpell_001.mp3"], -9.0],
	"heal": [["res://sfx/10_Magic_Abilities/Magic_Abilities_HealSpell_001.mp3"], -9.0],
	"buff": [["res://sfx/PowerUp/Powerup3.wav", "res://sfx/PowerUp/Powerup7.wav"], -13.0],
	"debuff": [["res://sfx/10_Magic_Abilities/Magic_Abilities_IceSpell_001.mp3"], -13.0],
	# made by tools/make_sfx.py: a soft thud when your beast keels over, a smack and a puff of smoke when a foe goes
	"faint": [["res://sfx/Custom/Faint_Thud.wav"], -9.0],
	"defeat": [["res://sfx/Custom/Defeat_Puff.wav"], -7.0],
	"growl": [["res://sfx/09_Creatures/Creatures_MonsterGrowl_001.mp3"], -8.0],
	"levelup": [["res://sfx/06_Feedback/Feedback_LevelUp_001.mp3"], -8.0],
	"capture": [["res://sfx/06_Feedback/Feedback_Achievement_001.mp3"], -8.0],
	"victory": [["res://sfx/06_Feedback/Feedback_Victory_001.mp3"], -7.0],
	"fail": [["res://sfx/UI Samples/UI_SteelDrum_Error_1.wav"], -9.0],
	"encounter": [["res://sfx/07_Transitions/Transitions_WhooshIn_001.mp3"], -7.0],
	"stinger": [["res://sfx/BitCrushHits/Crushed Stingers/Retro_Thriller_CinematicStinger.wav"], -8.0],
	"door": [["res://sfx/05_Environment/Environment_DoorOpen_001.mp3"], -10.0],
	"door_close": [["res://sfx/05_Environment/Environment_DoorClose_001.mp3"], -11.0],
	# made by tools/make_sfx.py: three raps on a locked front door
	"knock": [["res://sfx/Custom/Door_Knock.wav"], -6.0],
	"buy": [["res://sfx/04_Pickups_Items/Pickups_Items_Coin_001.mp3", "res://sfx/Coin/Pickup_Coin.wav"], -10.0],
	"item": [["res://sfx/04_Pickups_Items/Pickups_Items_TreasureChest_001.mp3"], -9.0],
	"shard": [["res://sfx/04_Pickups_Items/Pickups_Items_Gem_001.mp3"], -8.0],
	"merge": [["res://sfx/07_Transitions/Transitions_Teleport_001.mp3"], -7.0],
	"hatch": [["res://sfx/05_Environment/Environment_CrateBreak_001.mp3"], -8.0],
	"fly": [["res://sfx/07_Transitions/Transitions_WhooshOut_001.mp3"], -7.0],
	"smash": [["res://sfx/BitCrushHits/ConcreteHit_Crush_Impact_01.wav", "res://sfx/BitCrushHits/ConcreteHit_Crush_Impact_02.wav"], -9.0],
	"lever": [["res://sfx/05_Environment/Environment_LeverPull_001.mp3"], -9.0],
	"tick": [["res://sfx/06_Feedback/Feedback_CountdownTick_001.mp3"], -12.0],
	"step_grass": [["res://sfx/02_Player_Actions/Player_Actions_FootstepGrass_001.mp3"], -24.0],
	"step_stone": [["res://sfx/02_Player_Actions/Player_Actions_FootstepStone_001.mp3"], -24.0],
	"jump": [["res://sfx/02_Player_Actions/Player_Actions_Jump_001.mp3"], -12.0],
}

## Ambient loops by key.
const AMBIENCE := {
	"wind": "res://sfx/08_Ambient_Loops/Ambient_Loops_Wind_001.mp3",
	"rain": "res://sfx/08_Ambient_Loops/Ambient_Loops_Rain_001.mp3",
	"ghostly": "res://sfx/RetroTextures/Ambient Loop Textures/Ambience_WindVoice_Hybrid_Texture_Loop.wav",
	"machines": "res://sfx/RetroTextures/Ambient Loop Textures/Ambience_ShipInterior_Diegetic_Texture_Loop.wav",
}

var _players: Array = []
var _next := 0
var _cache := {}
var _streams := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_kind := ""
var _ambience_kind := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_ambience = AudioStreamPlayer.new()
	for p in [_music_a, _music_b, _ambience]:
		p.bus = "Music"
		add_child(p)
	_ambience.bus = "SFX"
	set_volumes(0.8, 0.9)


## 0..1 linear volumes for the Music and SFX buses.
func set_volumes(music_v: float, sfx_v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, music_v)) - 6.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_v <= 0.01)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, sfx_v)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_v <= 0.01)


func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[path] = s
	return s


# ---------------------------------------------------------------- synthesis (flute notes, squeaks)
static func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"tri":
			var p := fmod(phase, 1.0)
			return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p
		"noise":
			return randf_range(-1.0, 1.0)
		"flute":
			var s := sin(phase * TAU)
			return s * 0.85 + sin(phase * TAU * 2.0) * 0.12 + sin(phase * TAU * 3.0) * 0.04
	return sin(phase * TAU)


func _make(freq: float, dur: float, wave: String, slide := 0.0, vib := 0.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq + slide * (t / dur)
		if vib > 0.0:
			f *= 1.0 + sin(t * TAU * 5.5) * vib * clampf(t * 4.0, 0.0, 1.0)
		phase += f / RATE
		var env := clampf(t / 0.015, 0.0, 1.0) * clampf((dur - t) / maxf(0.04, dur * 0.5), 0.0, 1.0)
		var s := _wave(wave, phase) * env * 0.45
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _play_stream(s: AudioStream, vol := -6.0, pitch := 1.0) -> void:
	if s == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	p.play()


func tone(freq: float, dur := 0.25, wave := "sine", vol := -8.0, slide := 0.0, vib := 0.0) -> void:
	var key := "%s:%d:%d:%d:%d" % [wave, int(freq), int(dur * 1000), int(slide), int(vib * 1000)]
	if not _cache.has(key):
		_cache[key] = _make(freq, dur, wave, slide, vib)
	_play_stream(_cache[key], vol)


func flute_note(freq: float) -> void:
	tone(freq, 0.42, "flute", -4.0, 0.0, 0.012)


## Plays a named effect. `pitch_jitter` varies the pitch a little so repeats don't sound robotic.
func play(name: String, pitch_jitter := 0.0) -> void:
	if name == "squeak":
		tone(1400, 0.08, "square", -20, -500)
		return
	var spec: Array = SOUNDS.get(name, [])
	if spec.is_empty():
		return
	var files: Array = spec[0]
	var s := _load(files[randi() % files.size()])
	var pitch := 1.0 + (randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 0.0)
	_play_stream(s, float(spec[1]), pitch)


## Plays an effect at an exact pitch and volume offset (touch buttons).
func play_tone(name: String, pitch: float, vol_offset := 0.0) -> void:
	var spec: Array = SOUNDS.get(name, [])
	if spec.is_empty():
		return
	var files: Array = spec[0]
	_play_stream(_load(files[0]), float(spec[1]) + vol_offset, pitch)


## Plays an effect at a set pitch (dialogue voices).
func play_pitched(name: String, pitch: float) -> void:
	var spec: Array = SOUNDS.get(name, [])
	if spec.is_empty():
		return
	var files: Array = spec[0]
	_play_stream(_load(files[randi() % files.size()]), float(spec[1]), pitch * randf_range(0.97, 1.03))


# ---------------------------------------------------------------- music & ambience
func music(kind: String) -> void:
	if kind == _music_kind:
		return
	_music_kind = kind
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, FADE_TIME)
		tw.tween_callback(old.stop)
	if kind == "" or not TRACKS.has(kind):
		return
	var track := String(TRACKS[kind])
	if OS.has_feature("web"):
		_web_music(track)
		return
	var s := _load(MUSIC_DIR + track + ".mp3")
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_fade_in_music(s)


func _fade_in_music(s: AudioStream) -> void:
	if s == null:
		return
	var new := _music_b if _music_a.playing else _music_a
	new.stream = s
	new.volume_db = -40.0
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", 0.0, FADE_TIME)


# On the web the music isn't part of the game download, so the game starts sooner: each track is fetched from
# music/<track>.ogg next to the page the first time it's needed (tools/make_web.py puts them there), then kept.
var _web_fetch: HTTPRequest
var _web_loading := ""


func _web_music(track: String) -> void:
	var key := "web:" + track
	if _streams.has(key):
		_fade_in_music(_streams[key])
		return
	if _web_loading != "":
		# another track is still downloading; _on_web_music picks up whatever is wanted when it's done
		return
	if _web_fetch == null:
		_web_fetch = HTTPRequest.new()
		add_child(_web_fetch)
		_web_fetch.request_completed.connect(_on_web_music)
	var url := str(JavaScriptBridge.eval("new URL('music/%s.ogg', window.location.href).href" % track, true))
	_web_loading = track
	if _web_fetch.request(url) != OK:
		_web_loading = ""


func _on_web_music(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var track := _web_loading
	_web_loading = ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var s := AudioStreamOggVorbis.load_from_buffer(body)
		if s != null:
			s.loop = true
			_streams["web:" + track] = s
	else:
		push_warning("music download failed: %s (%d, %d)" % [track, result, code])
	var wanted := String(TRACKS.get(_music_kind, ""))
	if wanted == "":
		return
	if wanted == track:
		_fade_in_music(_streams.get("web:" + track, null))
	elif not _streams.has("web:" + wanted):
		_web_music(wanted)
	else:
		_fade_in_music(_streams["web:" + wanted])


func current_music() -> String:
	return _music_kind


func ambience(kind: String) -> void:
	if kind == _ambience_kind:
		return
	_ambience_kind = kind
	if kind == "" or not AMBIENCE.has(kind):
		var tw := create_tween()
		tw.tween_property(_ambience, "volume_db", -40.0, FADE_TIME)
		tw.tween_callback(_ambience.stop)
		return
	var s := _load(AMBIENCE[kind])
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_ambience.stream = s
	_ambience.volume_db = -40.0
	_ambience.play()
	var tw2 := create_tween()
	tw2.tween_property(_ambience, "volume_db", -14.0, FADE_TIME)
