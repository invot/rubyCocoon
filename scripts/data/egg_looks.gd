extends RefCounted
## A shell for every hatchable species. First-form ids keep old and newly dropped eggs identical.
const RaceDB = preload("res://scripts/data/race_db.gd")
## shell, markings, motif, width, crown (the shapes echo the beast inside).
const SHELLS := {
	0: ["#f6bc69", "#c94a35", 0, 0.85, "plates"], # Embit: flame chevrons, dorsal plates
	3: ["#7cba81", "#f6d77c", 1, 0.76, "buds"], # Pricklet: cactus ribs and buds
	6: ["#ce7957", "#fff0be", 2, 0.91, "ears"], # Impkin: warm freckles, little ears
	9: ["#b96d62", "#ffe0a0", 3, 0.79, "horns"], # Nipskit: armoured bands
	12: ["#83a695", "#e7ce81", 4, 0.95, "horn"], # Grubbit: split carapace, single horn
	15: ["#9fc9dc", "#795d96", 0, 0.94, "tusks"], # Tuskit: icy chevrons and tusks
	18: ["#d6b58c", "#659d73", 1, 0.82, "leaves"], # Saplet: wood veins and leaves
	21: ["#f2a4b2", "#399ba7", 3, 0.72, "fin"], # Wrigglet: turquoise whorls
	24: ["#78bfd6", "#fff0cf", 3, 0.98, "claws"], # Clawlet: seafoam bands and paired claws
	27: ["#8fc8a1", "#497fa6", 2, 0.88, "buds"], # Tadlet: pond spots
	30: ["#fff0c6", "#dc8c44", 0, 0.80, "feathers"], # Hootlet: feather chevrons
	33: ["#9e8dcc", "#ef9dbc", 4, 0.74, "ears"], # Flittle: dusk membrane panels
	36: ["#c492c8", "#f9de98", 2, 0.97, "leaves"], # Berrypuff: berry speckles and calyx
	39: ["#275a99", "#b9f4ff", 3, 0.78, "fin"],
	40: ["#c5ece8", "#edc86f", 0, 0.75, "feathers"],
	41: ["#a94439", "#ffc96c", 1, 0.94, "horns"],
	42: ["#75977d", "#cbefc0", 4, 1.0, "horn"],
	47: ["#473654", "#dba4ed", 1, 0.86, "horns"],
}
static var _icons := {}


static func look(egg: Dictionary) -> Dictionary:
	var race := RaceDB.first_form(int(egg["race"]))
	var s: Array = SHELLS.get(race, SHELLS[0])
	var ghost: bool = bool(egg.get("ghost", false)) or egg.get("kind", "") == "ghost"
	return {"shell": Color(s[0]).darkened(0.65) if ghost else Color(s[0]),
		"mark": Color(s[1]).lerp(Color("#b780ed"), 0.75) if ghost else Color(s[1]),
		"motif": int(s[2]), "width": float(s[3]), "crown": String(s[4]),
		"radiant": egg.get("kind", "") == "legendary", "race": race}


static func name_for(egg: Dictionary) -> String:
	var prefix := ""
	if egg.get("ghost", false) or egg.get("kind", "") == "ghost":
		prefix = "Shadow "
	elif egg.get("kind", "") == "legendary":
		prefix = "Radiant "
	return "%s%s Egg" % [prefix, RaceDB.race_name(RaceDB.first_form(int(egg["race"])))]


## Smooth shell motifs, shared by the small inventory icon and the 3D shell's UV texture.
static func marking(u: float, v: float, motif: int) -> float:
	match motif:
		0: return smoothstep(0.25, 0.42, sin(v * 24.0 + abs(sin(u * TAU * 4.0)) * 3.0))
		1: return smoothstep(0.55, 0.75, sin(u * TAU * 7.0 + sin(v * 9.0) * 0.6))
		2:
			var p := Vector2(fposmod(u * 7.0 + floor(v * 6.0) * 0.5, 1.0), fposmod(v * 6.0, 1.0))
			return 1.0 - smoothstep(0.17, 0.23, p.distance_to(Vector2(0.5, 0.5)))
		3: return smoothstep(0.3, 0.5, sin(v * 32.0 + sin(u * TAU * 3.0) * 1.6))
		_: return smoothstep(0.5, 0.7, cos(u * TAU * 5.0)) * smoothstep(0.0, 0.2, sin(v * 12.0))


static func shell_texture(egg: Dictionary) -> ImageTexture:
	var key := name_for(egg)
	if _icons.has(key + ":shell"):
		return _icons[key + ":shell"]
	var d := look(egg)
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 256:
			img.set_pixel(x, y, (d.shell as Color).lerp(d.mark, marking(float(x) / 256.0, float(y) / 128.0, d.motif) * 0.72))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_icons[key + ":shell"] = tex
	return tex


static func icon(egg: Dictionary) -> Texture2D:
	var key := name_for(egg)
	if _icons.has(key):
		return _icons[key]
	var d := look(egg)
	var img := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in 90:
		for x in 96:
			var v := float(y - 8) / 78.0
			var nx := float(x - 48) / (34.0 * float(d.width) * (0.83 + v * 0.24))
			var ny := (v - 0.5) * 2.0
			var r := nx * nx + ny * ny
			if r < 1.0:
				var u := 0.5 + asin(clampf(nx, -1, 1)) / PI
				var col: Color = (d.shell as Color).lerp(d.mark, marking(u, v, d.motif) * 0.72)
				col = col.lightened(maxf(0.0, (1.0 - r) * 0.18 - nx * 0.12))
				col.a = clampf((1.0 - r) * 12.0, 0, 1)
				img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex
