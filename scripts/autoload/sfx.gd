extends Node
## Music, ambience and sound effects. Music tracks are the game-ready copies in assets/audio/music
## (made from music/ by tools/convert_audio.py); effects come from sfx/ and assets/audio/sfx/.
## Flute notes are synthesised.

const RATE := 22050
const MUSIC_DIR := "res://assets/audio/music/"
const FADE_TIME := 0.8
const DIALOGUE_PITCH := 1.189207115 # Three semitones: 2^(3/12), on top of each speaker's voice.
const BATTLE_TONES := [[196, 0.8, "square", -17, 600], [392, 0.8, "square", -23, 1200], [784, 0.3, "tri", -16, 0]]
const BATTLE_AUDIO := "res://assets/audio/battle/"

## Music keys -> track files. world_db.gd / main.gd decide which key plays where.
const TRACKS := {
	"title": "nerves",
	"ending": "journey_to_ascend",
	"home": "pennsylvania_rose",
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
	"center": "hep_cats",
	"house": "magic_scout_manor",
	"silly": "farting_around",
	"battle": "rising_tide",
	"victory": "android_sock_hop",
	"andreas": "andreas_theme",
	"krampus": "krampus_workshop",
	"boss": "rising_tide_faster",
}

## The beat of the battle tracks (track file -> beats a minute, and where the first beat falls, in seconds into the
## file), measured from the decoded audio; both hold their tempo the whole way through. The beat attack
## (scripts/core/beat_chain.gd) keeps time with it through beat_now(), and a percussion layer plays along (percussion).
## A track without an entry has no steady beat: a beat attack over it keeps time with a fixed click (CLICK_BPM).
const TEMPOS := {
	"rising_tide": {"bpm": 106.0, "first": 0.012},
	"rising_tide_faster": {"bpm": 122.0, "first": 0.014},
}
const CLICK_BPM := 100.0
## Output delay (seconds) the audio driver doesn't report, by platform, to be set by ear on the device with
## --scene=beat-click (the percussion's ticks against the music's beat).
const BEAT_LATENCY := {"web": 0.0, "android": 0.0}
## the percussion layer's volume (dB, on the Music bus): quietly under the whole battle, and full for a beat attack
const PERC_DB := {"bed": -24.0, "full": -5.0}
## a beat that drifts further than this from the music (seconds) is put back in step
const PERC_DRIFT := 0.025

## Effect keys -> one or more files (a random one plays). Volume in dB; an empty spec disables a cue.
const SOUNDS := {
	"bird_cry": [["res://assets/audio/sfx/hatch_chirp.ogg"], -7.0],
	"blip": [["res://sfx/Select/Blip_Select3.wav"], -22.0],
	"select": [["res://sfx/01_UI_Menu/UI_Menu_Hover_001.mp3"], -12.0],
	"confirm": [["res://assets/audio/sfx/menu_confirm.ogg"], -10.0],
	"back": [["res://sfx/01_UI_Menu/UI_Menu_Click_001.mp3"], -10.0],
	"error": [["res://assets/audio/sfx/menu_unavailable.ogg"], -12.0],
	"page": [["res://assets/audio/sfx/book_page.ogg"], -10.0],
	"open": [["res://assets/audio/sfx/arrange_open.ogg"], -10.0],
	"pickup": [["res://assets/audio/sfx/pickup_kalimba.ogg"], -10.0],
	"toggle": [["res://assets/audio/sfx/toggle_click.ogg"], -10.0],
	"notify": [["res://sfx/06_Feedback/Feedback_Notification_001.mp3"], -10.0],
	"talk": [["res://assets/audio/sfx/dialogue_pop.ogg"], -12.0],
	"hit": [["res://assets/audio/sfx/body_hit.ogg"], -8.0],
	"metal_hit": [["res://sfx/BitCrushHits/MetalicHit_Crush_Impact_01.wav", "res://sfx/BitCrushHits/MetalicHit_Crush_Impact_03.wav", "res://sfx/BitCrushHits/MetalicHit_Crush_Impact_05.wav"], -10.0],
	"crit": [["res://assets/audio/sfx/critical_hit.ogg"], -6.0],
	"miss": [["res://assets/audio/sfx/attack_miss.ogg"], -10.0],
	"shield": [["res://sfx/03_Combat/Combat_ShieldBlock_001.mp3"], -6.0],
	"slingshot": [["res://sfx/02_Player_Actions/Player_Actions_Dash_001.mp3"], -10.0],
	"explosion": [["res://sfx/Explosion/Explosion3.wav", "res://sfx/Explosion/Explosion6.wav"], -11.0],
	"fire": [["res://sfx/10_Magic_Abilities/Magic_Abilities_FireSpell_001.mp3"], -9.0],
	"ice": [["res://sfx/10_Magic_Abilities/Magic_Abilities_IceSpell_001.mp3"], -9.0],
	"heal": [["res://assets/audio/sfx/heal_plucks.ogg"], -13.0],
	"buff": [["res://sfx/PowerUp/Powerup3.wav", "res://sfx/PowerUp/Powerup7.wav"], -13.0],
	"debuff": [["res://sfx/10_Magic_Abilities/Magic_Abilities_IceSpell_001.mp3"], -13.0],
	# made by tools/make_sfx.py: a soft thud when your beast keels over, a smack and a puff of smoke when a foe goes
	"faint": [["res://sfx/Custom/Faint_Thud.wav"], -9.0],
	"defeat": [["res://sfx/Custom/Defeat_Puff.wav"], -7.0],
	"growl": [["res://sfx/09_Creatures/Creatures_MonsterGrowl_001.mp3"], -8.0],
	"levelup": [["res://sfx/06_Feedback/Feedback_LevelUp_001.mp3"], -8.0],
	"capture": [["res://sfx/06_Feedback/Feedback_Achievement_001.mp3"], -8.0],
	"victory": [["res://sfx/06_Feedback/Feedback_Victory_001.mp3"], -7.0],
	"fail": [["res://assets/audio/sfx/failed_attempt.ogg"], -12.0],
	"encounter": [["res://sfx/07_Transitions/Transitions_WhooshIn_001.mp3"], -7.0],
	"stinger": [["res://assets/audio/sfx/boss_dread.ogg", "res://assets/audio/sfx/boss_brass.ogg"], -8.0],
	"door": [["res://sfx/05_Environment/Environment_DoorOpen_001.mp3"], -10.0],
	"door_close": [["res://sfx/05_Environment/Environment_DoorClose_001.mp3"], -11.0],
	# made by tools/make_sfx.py: three raps on a locked front door
	"knock": [["res://sfx/Custom/Door_Knock.wav"], -6.0],
	# made by tools/make_sfx.py: an old bell telephone ringing (calling Dad saves the game)
	"phone_ring": [["res://sfx/Custom/Phone_Ring.wav"], -9.0],
	# made by tools/make_sfx.py: a ghost beast rising, and a dread hit (the intro's cage reveal)
	"ghost": [["res://sfx/Custom/Ghost_Rise.wav"], -9.0],
	"dread": [["res://sfx/Custom/Dread_Hit.wav"], -4.0],
	"buy": [["res://assets/audio/sfx/payment_coin.ogg"], -14.0],
	"item": [["res://sfx/04_Pickups_Items/Pickups_Items_TreasureChest_001.mp3"], -9.0],
	"shard": [["res://sfx/04_Pickups_Items/Pickups_Items_Gem_001.mp3"], -8.0],
	"merge": [["res://assets/audio/sfx/energy_flow.ogg"], -10.0],
	"hatch": [["res://assets/audio/sfx/hatch_chirp.ogg"], -10.0],
	"fly": [["res://sfx/07_Transitions/Transitions_WhooshOut_001.mp3"], -7.0],
	"smash": [["res://sfx/BitCrushHits/ConcreteHit_Crush_Impact_01.wav", "res://sfx/BitCrushHits/ConcreteHit_Crush_Impact_02.wav"], -9.0],
	"lever": [["res://assets/audio/sfx/mechanism_latch.ogg"], -13.0],
	"tick": [["res://sfx/06_Feedback/Feedback_CountdownTick_001.mp3"], -12.0],
	"step_grass": [["res://sfx/02_Player_Actions/Player_Actions_FootstepGrass_001.mp3"], -24.0],
	"step_stone": [["res://sfx/02_Player_Actions/Player_Actions_FootstepStone_001.mp3"], -24.0],
	"step_water": [["res://sfx/Custom/Shallow_Step_1.wav", "res://sfx/Custom/Shallow_Step_2.wav"], -19.0],
	"jump": [["res://sfx/02_Player_Actions/Player_Actions_Jump_001.mp3"], -12.0],
}

## Ambient loops by key.
const AMBIENCE := {
	"wind": "res://sfx/08_Ambient_Loops/Ambient_Loops_Wind_001.mp3",
	"rain": "res://sfx/08_Ambient_Loops/Ambient_Loops_Rain_001.mp3",
	"ghostly": "res://assets/audio/sfx/haunted_spell.ogg",
	"cathedral": "res://assets/audio/sfx/haunted_forest.ogg",
	"machines": "res://assets/audio/sfx/machine_room.ogg",
	"surf": "res://assets/audio/sfx/shellhaven_surf.ogg",
	"forest": "res://assets/audio/sfx/coastal_path_nature.ogg",
}
const AMBIENCE_VOLUMES := {"surf": -18.0, "forest": -20.0, "machines": -18.0, "ghostly": -20.0, "cathedral": -20.0}

var _players: Array = []
var _next := 0
var _cache := {}
var _streams := {}
var _music_cache: Array[String] = []
const MUSIC_CACHE_LIMIT := 3
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_kind := ""
var _ambience_kind := ""
var _ambience_tween: Tween
var _music_tweens := {}
## the player of the current track and its file (for the beat), and when it started
var _music_now: AudioStreamPlayer
var _music_track := ""
var _music_start_usec := 0
## the beat clock: whole beats added each time the track loops (so the count keeps growing on whole beats), the last
## raw count read, and the fixed click used over a track with no steady beat
var _beat_base := 0.0
var _beat_last := 0.0
var _click_on := false
var _click_start_usec := 0
## the percussion layer: its player, the bar loop in it ("click" or a track), "off" / "bed" / "full", and its fade
var _perc: AudioStreamPlayer
var _perc_key := ""
var _perc_mode := "off"
var _perc_tween: Tween
var _perc_start_usec := 0


func _cancel_music_tween(player: AudioStreamPlayer) -> void:
	var tween: Tween = _music_tweens.get(player)
	if tween != null and tween.is_valid():
		tween.kill()
	_music_tweens.erase(player)


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
	_perc = AudioStreamPlayer.new()
	for p in [_music_a, _music_b, _ambience, _perc]:
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
	if path.begins_with(MUSIC_DIR):
		_music_cache.erase(path)
		_music_cache.append(path)
		while _music_cache.size() > MUSIC_CACHE_LIMIT:
			# Players retain their own streams during crossfades; evicting a cache entry cannot cut one off.
			_streams.erase(_music_cache.pop_front())
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


## A secret unlocked: a rising bell arpeggio over a held low note (a water puzzle solved).
func secret_chime() -> void:
	tone(261.63, 1.4, "sine", -11.0)
	for freq: float in [523.25, 659.25, 880.0, 987.77, 1318.51, 1760.0]:
		tone(freq, 0.7, "sine", -7.0)
		tone(freq * 2.0, 0.35, "sine", -16.0)
		await get_tree().create_timer(0.13).timeout


func flute_note(freq: float) -> void:
	tone(freq, 0.42, "flute", -4.0, 0.0, 0.012)


## A battle begins (the swirl or the flash): the whoosh, with a rising chiptune sweep the length of the swirl under it,
## so it sounds unlike a trainer spotting you.
func battle_start() -> void:
	play("encounter")
	for spec in BATTLE_TONES:
		_play_stream(_battle_tone(spec), float(spec[3]))


func _battle_tone(spec: Array) -> AudioStream:
	var key := "battle:%d" % int(spec[0])
	if not _cache.has(key):
		var path := BATTLE_AUDIO + "sweep_%d.res" % int(spec[0])
		_cache[key] = load(path) if ResourceLoader.exists(path) else _make(float(spec[0]), float(spec[1]), String(spec[2]), float(spec[4]))
	return _cache[key]


## Walking and the first encounter must not load a random footstep variant or synthesize sweeps mid-frame.
## Called behind a map transition's fade; only these small, frequently used effects are retained.
func prewarm_field() -> void:
	var slice := Time.get_ticks_usec()
	for name in ["step_grass", "step_stone", "step_water", "notify", "encounter"]:
		for path in SOUNDS.get(name, [[]])[0]:
			_load(path)
			if Time.get_ticks_usec() - slice >= 6000:
				await get_tree().process_frame
				slice = Time.get_ticks_usec()
	for spec in BATTLE_TONES:
		_battle_tone(spec)


func bake_battle_tones(verify := false) -> int:
	DirAccess.make_dir_recursive_absolute(BATTLE_AUDIO)
	var bad := 0
	var made := {}
	for spec in BATTLE_TONES:
		made[BATTLE_AUDIO + "sweep_%d.res" % int(spec[0])] = _make(float(spec[0]), float(spec[1]), String(spec[2]), float(spec[4]))
	# the percussion layer's bars: one per timed track, and the fixed click
	for key in _perc_keys():
		made[_perc_path(key)] = _percussion_bar(_perc_bpm(key))
	for path in made:
		var generated: AudioStreamWAV = made[path]
		if verify:
			var baked: AudioStreamWAV = load(path) if ResourceLoader.exists(path) else null
			bad += int(baked == null or baked.data != generated.data or baked.mix_rate != generated.mix_rate
				or baked.loop_mode != generated.loop_mode or baked.loop_end != generated.loop_end)
		else:
			bad += int(ResourceSaver.save(generated, path, ResourceSaver.FLAG_COMPRESS) != OK)
	return bad


# ---------------------------------------------------------------- the beat (battle tracks) and the percussion layer
static func _perc_keys() -> Array:
	return TEMPOS.keys() + ["click"]


static func _perc_bpm(key: String) -> float:
	return float(TEMPOS[key]["bpm"]) if TEMPOS.has(key) else CLICK_BPM


static func _perc_path(key: String) -> String:
	return BATTLE_AUDIO + "beat_%s.res" % key


## One bar (four beats) of the percussion layer at `bpm`, looping: a woodblock tock on each beat (the first lower and
## louder) with a soft shaker between. Each tock starts right on its sample, so the loop's beats are exact.
func _percussion_bar(bpm: float) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var n := int(round(4.0 * beat * RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1606
	for b in 4:
		var start := int(round(b * beat * RATE))
		var f := 980.0 if b == 0 else 1320.0
		var amp := 1.0 if b == 0 else 0.72
		for i in int(0.12 * RATE):
			if start + i >= n:
				break
			var t := float(i) / RATE
			var s := sin(TAU * f * t) * exp(-t / 0.016) + 0.45 * sin(TAU * 210.0 * t) * exp(-t / 0.03)
			s += rng.randf_range(-1.0, 1.0) * exp(-t / 0.0015) * 0.5
			buf[start + i] += s * amp * 0.55
		# the shaker on the "and": high-passed noise, rising quickly and dying away
		var mid := int(round((b + 0.5) * beat * RATE))
		var prev := 0.0
		for i in int(0.07 * RATE):
			if mid + i >= n:
				break
			var t := float(i) / RATE
			var x := rng.randf_range(-1.0, 1.0)
			var hp := x - prev
			prev = x
			buf[mid + i] += hp * clampf(t / 0.004, 0.0, 1.0) * exp(-t / 0.022) * 0.16
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _perc_stream(key: String) -> AudioStream:
	var cache_key := "perc:" + key
	if not _cache.has(cache_key):
		var path := _perc_path(key)
		_cache[cache_key] = load(path) if ResourceLoader.exists(path) else _percussion_bar(_perc_bpm(key))
	return _cache[cache_key]


func _extra_latency() -> float:
	if OS.has_feature("web"):
		return float(BEAT_LATENCY["web"])
	if OS.has_feature("android"):
		return float(BEAT_LATENCY["android"])
	return 0.0


## Where the current track's player is, in seconds into the file (as mixed, not yet heard), or -1 when nothing plays.
## The web's sample playback may not report it: then it's counted from when the track started.
func _music_pos() -> float:
	var p := _music_now
	if p == null or not p.playing or not TEMPOS.has(_music_track):
		return -1.0
	var pos := p.get_playback_position()
	var wall := float(Time.get_ticks_usec() - _music_start_usec) / 1e6
	if pos <= 0.0 and wall > 0.3:
		var length := p.stream.get_length() if p.stream != null else 0.0
		return fposmod(wall, length) if length > 0.0 else wall
	return pos


## True while a battle track with a steady beat is playing (see TEMPOS).
func has_tempo() -> bool:
	return _music_pos() >= 0.0


## Seconds between beats: the current track's, or the fixed click's.
func beat_period() -> float:
	if not _click_on and TEMPOS.has(_music_track):
		return 60.0 / float(TEMPOS[_music_track]["bpm"])
	return 60.0 / CLICK_BPM


## The beat as you hear it now: beats since the current track's first beat (or since the click started), allowing for
## the audio output's delay. It only ever grows, and stays on whole beats when the track loops. NAN when there's no
## beat to keep (no timed track and no click: see beat_begin).
func beat_now() -> float:
	var lag := AudioServer.get_output_latency() + _extra_latency()
	if _click_on:
		return (float(Time.get_ticks_usec() - _click_start_usec) / 1e6 - lag) / beat_period()
	var pos := _music_pos()
	if pos < 0.0:
		return NAN
	var spec: Dictionary = TEMPOS[_music_track]
	var heard := pos + AudioServer.get_time_since_last_mix() - lag
	var raw := (heard - float(spec["first"])) * float(spec["bpm"]) / 60.0
	if raw < _beat_last - 2.0:
		# the track looped: carry on counting from the next whole beat
		_beat_base = ceilf(_beat_base + _beat_last) + 1.0
	_beat_last = raw
	return _beat_base + raw


## A beat attack starts keeping time: with the battle track's beat, or, over a track without a steady one (or none
## yet: the web still fetching it), a fixed click that the percussion layer plays out.
func beat_begin() -> void:
	_click_on = not has_tempo()
	if _click_on:
		_click_start_usec = Time.get_ticks_usec()


func beat_end() -> void:
	_click_on = false


## The percussion layer: "bed" plays it quietly in step with a timed battle track, "full" brings it up for a beat
## attack (also over the fixed click), "off" fades it out.
func percussion(mode: String) -> void:
	if mode == _perc_mode:
		return
	_perc_mode = mode
	if _perc_tween != null and _perc_tween.is_valid():
		_perc_tween.kill()
	_perc_tween = create_tween()
	if mode == "off":
		_perc_tween.tween_property(_perc, "volume_db", -60.0, 0.4)
		_perc_tween.tween_callback(_perc.stop)
	else:
		if not _perc.playing:
			_perc.volume_db = -60.0
		_perc_tween.tween_property(_perc, "volume_db", float(PERC_DB.get(mode, PERC_DB["bed"])), 0.25 if mode == "full" else 0.8)


func _process(_delta: float) -> void:
	if TEMPOS.has(_music_track) and not _click_on:
		beat_now()
	if _perc_mode != "off":
		_sync_percussion()


## Keeps the percussion bar in step with the beat: started where the bar should be, and moved back in step if it has
## drifted (the track looping off a bar line, a hitch). Nothing to follow: it stops.
func _sync_percussion() -> void:
	var key := ""
	var at := 0.0
	if _click_on:
		key = "click"
		at = float(Time.get_ticks_usec() - _click_start_usec) / 1e6
	elif _music_pos() >= 0.0:
		key = _music_track
		at = _music_pos() - float(TEMPOS[key]["first"])
	if key == "":
		if _perc.playing:
			_perc.stop()
		return
	var bar := 4.0 * beat_period()
	var want := fposmod(at, bar)
	if key != _perc_key or not _perc.playing:
		_perc_key = key
		_perc.stream = _perc_stream(key)
		_perc.play(want)
		_perc_start_usec = Time.get_ticks_usec()
		return
	var now := _perc.get_playback_position()
	if now <= 0.0 and Time.get_ticks_usec() - _perc_start_usec > 300000:
		# (a player that can't report where it is: trust where it started)
		return
	var off := fposmod(now - want + bar * 0.5, bar) - bar * 0.5
	if absf(off) > PERC_DRIFT:
		_perc.seek(want)


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
	var base_pitch := pitch * (DIALOGUE_PITCH if name == "talk" else 1.0)
	_play_stream(_load(files[randi() % files.size()]), float(spec[1]), base_pitch * randf_range(0.97, 1.03))


# ---------------------------------------------------------------- music & ambience
func music(kind: String) -> void:
	if kind == _music_kind:
		return
	_music_kind = kind
	var old := _music_a if _music_a.playing else _music_b
	if old.playing:
		_cancel_music_tween(old)
		var tw := create_tween()
		_music_tweens[old] = tw
		tw.tween_property(old, "volume_db", -40.0, FADE_TIME)
		tw.tween_callback(old.stop)
	_music_now = null
	_music_track = ""
	if kind == "" or not TRACKS.has(kind):
		return
	var track := String(TRACKS[kind])
	if OS.has_feature("web"):
		_web_music(track)
		return
	var s := _load(MUSIC_DIR + track + ".mp3")
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_fade_in_music(s, track)


func _fade_in_music(s: AudioStream, track := "") -> void:
	if s == null:
		return
	var new := _music_b if _music_a.playing else _music_a
	_cancel_music_tween(new)
	new.stream = s
	new.volume_db = -40.0
	new.play()
	# the beat clock follows the new track from its start
	_music_now = new
	_music_track = track
	_music_start_usec = Time.get_ticks_usec()
	_beat_base = 0.0
	_beat_last = 0.0
	var tw2 := create_tween()
	_music_tweens[new] = tw2
	tw2.tween_property(new, "volume_db", 0.0, FADE_TIME)


# On the web the music isn't part of the game download, so the game starts sooner: each track is fetched from
# music/<track>.ogg next to the page the first time it's needed (tools/make_web.py puts them there), then kept.
var _web_fetch: HTTPRequest
var _web_loading := ""


func _web_music(track: String) -> void:
	var key := "web:" + track
	if _streams.has(key):
		_fade_in_music(_streams[key], track)
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
		_fade_in_music(_streams.get("web:" + track, null), track)
	elif not _streams.has("web:" + wanted):
		_web_music(wanted)
	else:
		_fade_in_music(_streams["web:" + wanted], wanted)


func current_music() -> String:
	return _music_kind


func ambience(kind: String) -> void:
	if kind == _ambience_kind:
		return
	# A quick return outdoors must cancel the indoor fade's pending stop callback.
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_kind = kind
	if kind == "" or not AMBIENCE.has(kind):
		_ambience_tween = create_tween()
		_ambience_tween.tween_property(_ambience, "volume_db", -40.0, FADE_TIME)
		_ambience_tween.tween_callback(_ambience.stop)
		return
	var s := _load(AMBIENCE[kind])
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_ambience.stream = s
	_ambience.volume_db = -40.0
	_ambience.play()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", float(AMBIENCE_VOLUMES.get(kind, -14.0)), FADE_TIME)
