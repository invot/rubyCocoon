extends RefCounted
## Voxel people (player, NPCs). Each limb is its own small voxel mesh on a pivot so the rig can walk.
## look: skin, hair, shirt, pants, hat (optional), hair_style (0-3), outfit ("plain"/"coat"/"armor"/"robe"/"apron"/"jacket"/"uniform")
## Hero extras (all optional): hat_style "cap" (baseball cap, "logo" colour), face "hero" (brows, grin, blush),
## "tee" + "trim" (jacket inner shirt and gold bands), "backpack", "gloves", "shoes" (sneakers).
## Staff "uniform": a short-sleeved polo with a "trim" collar and cuffs, a "badge" name tag and an optional half
## "apron"; staff hat_styles are "visor", "soda" (a diner paper hat with a "trim" stripe) and "band" (a headband).
## Rig faces +Z; rotate the "Body" node to face other directions.

const VM = preload("res://scripts/gfx/voxel_mesher.gd")
const VS := 0.062

static var _cache := {}


static func _parts(look: Dictionary) -> Dictionary:
	var key := JSON.stringify(look)
	if _cache.has(key):
		return _cache[key]
	var skin := Color(str(look.get("skin", "#f0c8a0")))
	var hair := Color(str(look.get("hair", "#5a3a20")))
	var shirt := Color(str(look.get("shirt", "#c8402f")))
	var pants := Color(str(look.get("pants", "#2e3448")))
	var outfit: String = look.get("outfit", "plain")
	var style := int(look.get("hair_style", JSON.stringify(look).hash() % 4))
	var has_hat := look.has("hat")
	var hatc := Color(str(look.get("hat", "#5a5a66")))
	var hat_style: String = look.get("hat_style", "")
	var cap := hat_style == "cap"
	var trim := Color(str(look.get("trim", "#ffd071")))
	var hero_face: bool = look.get("face", "") == "hero"

	# ---- head (10 x 12 x 12, head occupies x1..8, y0..7, z1..8; z9..10 is room for a cap bill)
	var h := VM.Grid.new(10, 12, 12)
	var SK := h.add_color(skin)
	var HR := h.add_color(hair)
	var EY := h.add_color(Color("#1a1018"))
	var HT := h.add_color(hatc)
	var HTD := h.add_color(hatc.darkened(0.3))
	var CH := h.add_color(skin.darkened(0.12))
	h.box(1, 0, 1, 8, 7, 8, SK)
	for c in [Vector3i(1, 7, 1), Vector3i(8, 7, 1), Vector3i(1, 7, 8), Vector3i(8, 7, 8), Vector3i(1, 0, 1), Vector3i(8, 0, 1)]:
		h.set_v(c.x, c.y, c.z, 0)
	# hair
	h.box(1, 6, 1, 8, 7, 8, HR)
	h.box(1, 2, 1, 8, 7, 2, HR)
	h.box(1, 4, 1, 1, 7, 6, HR)
	h.box(8, 4, 1, 8, 7, 6, HR)
	match style:
		1:
			h.box(1, 1, 1, 8, 7, 1, HR)
			h.box(1, 1, 1, 1, 5, 4, HR)
			h.box(8, 1, 1, 8, 5, 4, HR)
		2:
			for x in [2, 4, 6, 8]:
				h.set_v(x - 1, 8, 4, HR)
				h.set_v(x - 1, 8, 6, HR)
		3:
			h.box(4, 3, 0, 5, 6, 0, HR)
	h.box(2, 7, 8, 7, 7, 8, HR)
	# face
	h.set_v(3, 4, 8, EY)
	h.set_v(3, 3, 8, EY)
	h.set_v(6, 4, 8, EY)
	h.set_v(6, 3, 8, EY)
	h.box(4, 1, 8, 5, 1, 8, CH)
	if hero_face:
		var MO := h.add_color(Color("#8a3a3a"))
		var BLS := h.add_color(Color("#f08a8a"))
		# messy side bangs framing the face (kept clear of the eyes)
		h.box(1, 4, 8, 1, 5, 8, HR)
		h.set_v(2, 5, 8, HR)
		h.box(8, 4, 8, 8, 5, 8, HR)
		h.set_v(7, 5, 8, HR)
		h.set_v(5, 5, 8, HR)
		# bright eyes: a light glint on top
		var GL := h.add_color(Color("#f4f8ff"))
		h.set_v(3, 4, 8, GL)
		h.set_v(6, 4, 8, GL)
		h.set_v(3, 2, 8, EY)
		h.set_v(6, 2, 8, EY)
		# a cheeky grin and rosy cheeks
		h.box(4, 1, 8, 5, 1, 8, MO)
		h.set_v(2, 2, 8, BLS)
		h.set_v(7, 2, 8, BLS)
	if cap:
		var LG := h.add_color(Color(str(look.get("logo", "#d8283a"))))
		var LGH := h.add_color(Color(str(look.get("logo", "#d8283a"))).lightened(0.4))
		# crown
		h.box(1, 6, 1, 8, 8, 8, HT)
		for c in [Vector3i(1, 8, 1), Vector3i(8, 8, 1), Vector3i(1, 8, 8), Vector3i(8, 8, 8)]:
			h.set_v(c.x, c.y, c.z, 0)
		h.box(2, 9, 2, 7, 9, 7, HT)
		h.set_v(4, 9, 4, HTD)
		h.set_v(5, 9, 5, HTD)
		# seam stripe and the ruby emblem on the front panel
		h.box(4, 6, 1, 5, 8, 1, HTD)
		h.set_v(4, 7, 8, LG)
		h.set_v(5, 7, 8, LG)
		h.set_v(4, 8, 8, LGH)
		h.set_v(5, 6, 8, LG)
		h.set_v(4, 6, 8, LG)
		# the bill
		h.box(1, 6, 9, 8, 6, 10, HTD)
		h.box(2, 6, 10, 7, 6, 10, HT)
		h.set_v(1, 6, 10, 0)
		h.set_v(8, 6, 10, 0)
		# spiky hair escaping at the sides and back
		for y in [3, 4, 5]:
			h.set_v(0, y, 4 + (y % 2), HR)
			h.set_v(9, y, 4 + (y % 2), HR)
		h.box(2, 2, 0, 7, 5, 0, HR)
		for x in [2, 4, 6]:
			h.set_v(x, 1, 0, HR)
		h.set_v(3, 6, 0, HR)
		h.set_v(6, 6, 0, HR)
	elif outfit == "armor" or look.get("hood", false):
		# hood / helmet shell with an opening for the face
		h.box(0, 1, 0, 9, 8, 8, HT)
		h.box(2, 1, 8, 7, 6, 8, SK)
		h.box(1, 8, 1, 8, 8, 7, HTD)
		h.set_v(3, 4, 8, EY)
		h.set_v(3, 3, 8, EY)
		h.set_v(6, 4, 8, EY)
		h.set_v(6, 3, 8, EY)
		h.box(4, 1, 8, 5, 1, 8, CH)
	elif hat_style == "visor" or hat_style == "band":
		# a band round the forehead (hair still showing on top); a visor adds a bill and a little emblem
		h.box(1, 6, 1, 8, 6, 8, HT)
		if hat_style == "visor":
			h.box(1, 6, 9, 8, 6, 10, HTD)
			h.box(2, 6, 10, 7, 6, 10, HT)
			h.set_v(1, 6, 10, 0)
			h.set_v(8, 6, 10, 0)
			var EM := h.add_color(Color(str(look.get("badge", "#ffe070"))))
			h.set_v(4, 6, 8, EM)
			h.set_v(5, 6, 8, EM)
		else:
			# the knot and its two tails at the back
			h.box(4, 5, 0, 5, 6, 0, HTD)
			h.set_v(4, 4, 0, HT)
			h.set_v(5, 3, 0, HT)
	elif hat_style == "soda":
		# a diner paper hat: a long, low peak running front to back, with a stripe round its edge
		var SST := h.add_color(trim)
		h.box(2, 8, 1, 7, 8, 8, HT)
		h.box(3, 9, 1, 6, 9, 8, HT)
		h.box(4, 10, 2, 5, 10, 7, HTD)
		h.box(2, 8, 1, 2, 8, 8, SST)
		h.box(7, 8, 1, 7, 8, 8, SST)
	elif has_hat:
		h.box(0, 8, 0, 9, 8, 9, HTD)
		h.box(1, 8, 1, 8, 10, 8, HT)
		h.box(1, 9, 9, 8, 9, 9, 0)
		h.box(2, 8, 9, 7, 8, 9, HTD)

	# ---- torso (8 x 9 x 4, or 8 x 9 x 6 with a backpack behind it)
	var pack: bool = look.has("backpack")
	var zo := 2 if pack else 0
	var t := VM.Grid.new(8, 9, 4 + zo)
	var SH := t.add_color(shirt)
	var SHD := t.add_color(shirt.darkened(0.3))
	var BL := t.add_color(pants.darkened(0.35))
	var BK := t.add_color(Color("#e8c060"))
	var AP := t.add_color(Color("#f0ece0"))
	var fz := 3 + zo
	t.box(0, 0, zo, 7, 8, fz, SH)
	t.box(0, 0, zo, 7, 1, fz, BL)
	t.set_v(3, 1, fz, BK)
	t.set_v(4, 1, fz, BK)
	t.box(2, 8, fz, 5, 8, fz, SHD)
	if outfit == "jacket":
		var TE := t.add_color(Color(str(look.get("tee", "#f4f0e8"))))
		var TR := t.add_color(trim)
		var TRD := t.add_color(trim.darkened(0.25))
		# open front over a tee, a gold hem band, raised collar and a chest badge
		t.box(3, 2, fz, 4, 7, fz, TE)
		t.box(0, 2, zo, 7, 2, fz, TR)
		t.box(2, 3, fz, 2, 7, fz, SHD)
		t.box(5, 3, fz, 5, 7, fz, SHD)
		t.box(1, 8, fz, 2, 8, fz, TRD)
		t.box(5, 8, fz, 6, 8, fz, TRD)
		t.box(3, 8, fz, 4, 8, fz, TE)
		t.set_v(6, 6, fz, TR)
		t.set_v(6, 5, fz, TRD)
		# shoulder stripes
		t.box(0, 7, zo, 0, 8, fz, TR)
		t.box(7, 7, zo, 7, 8, fz, TR)
	if pack:
		var PK := t.add_color(Color(str(look["backpack"])))
		var PKL := t.add_color(Color(str(look["backpack"])).lightened(0.2))
		var PKD := t.add_color(Color(str(look["backpack"])).darkened(0.35))
		var BU := t.add_color(Color("#ffd071"))
		t.box(1, 2, 0, 6, 7, 1, PK)
		t.box(1, 6, 0, 6, 7, 0, PKL)
		t.box(1, 7, 1, 6, 7, 1, PKL)
		t.set_v(3, 5, 0, BU)
		t.set_v(4, 5, 0, BU)
		t.box(1, 2, 0, 6, 2, 0, PKD)
		# straps over the shoulders and down the front
		t.box(1, 8, zo, 1, 8, fz, PKD)
		t.box(6, 8, zo, 6, 8, fz, PKD)
		t.box(1, 4, fz, 1, 7, fz, PKD)
		t.box(6, 4, fz, 6, 7, fz, PKD)
	match outfit:
		"coat":
			t.box(3, 2, fz, 4, 7, fz, SHD)
			t.box(0, 0, zo, 0, 8, fz, SHD)
			t.box(7, 0, zo, 7, 8, fz, SHD)
		"armor":
			t.box(1, 3, fz, 6, 7, fz, SHD)
			t.box(0, 7, zo, 7, 8, fz, SHD)
		"apron":
			t.box(1, 0, fz, 6, 6, fz, AP)
		"robe":
			t.box(3, 0, fz, 4, 8, fz, BK)
		"jacket":
			pass
		"uniform":
			# collar round an open neck, a short button placket and a name badge on the left of the chest
			var UTR := t.add_color(trim)
			t.box(1, 8, zo, 6, 8, fz, UTR)
			t.box(3, 8, fz, 4, 8, fz, t.add_color(skin))
			t.set_v(2, 7, fz, UTR)
			t.set_v(5, 7, fz, UTR)
			t.box(3, 5, fz, 3, 7, fz, SHD)
			t.set_v(3, 6, fz, UTR)
			t.box(5, 5, fz, 6, 6, fz, t.add_color(Color(str(look.get("badge", "#ffe070")))))
			t.box(5, 6, fz, 6, 6, fz, t.add_color(Color(str(look.get("badge", "#ffe070"))).lightened(0.35)))
			if look.has("apron"):
				# a half apron tied round the waist, with a pocket
				var UA := t.add_color(Color(str(look["apron"])))
				var UAD := t.add_color(Color(str(look["apron"])).darkened(0.2))
				t.box(0, 3, zo, 7, 3, fz, UAD)
				t.box(1, 0, fz, 6, 3, fz, UA)
				t.box(3, 1, fz, 4, 2, fz, UAD)
		_:
			t.box(3, 3, fz, 3, 7, fz, SHD)

	# ---- arm (2 x 9 x 3), hand at the bottom
	var arm := VM.Grid.new(2, 9, 3)
	var AS := arm.add_color(shirt)
	var AK := arm.add_color(skin)
	arm.box(0, 2, 0, 1, 8, 2, AS)
	arm.box(0, 0, 0, 1, 1, 2, AK)
	if outfit == "robe":
		arm.box(0, 1, 0, 1, 3, 2, AS)
	if outfit == "jacket":
		arm.box(0, 2, 0, 1, 2, 2, arm.add_color(trim))
		arm.box(0, 7, 0, 1, 8, 2, arm.add_color(shirt.lightened(0.08)))
	elif outfit == "uniform":
		# short sleeves with a cuff in the collar colour
		arm.box(0, 2, 0, 1, 4, 2, AK)
		arm.box(0, 5, 0, 1, 5, 2, arm.add_color(trim))
	if look.has("gloves"):
		var GL := arm.add_color(Color(str(look["gloves"])))
		arm.box(0, 1, 0, 1, 1, 2, GL)
		arm.set_v(0, 0, 1, GL)

	# ---- leg (3 x 9 x 3), shoe at the bottom
	var leg := VM.Grid.new(3, 9, 4)
	var LP := leg.add_color(pants)
	var LS := leg.add_color(Color("#2a2020"))
	leg.box(0, 2, 0, 2, 8, 2, LP)
	if look.has("shoes"):
		var SC := leg.add_color(Color(str(look["shoes"])))
		var SW := leg.add_color(Color("#f4f0e8"))
		leg.box(0, 2, 0, 2, 2, 2, leg.add_color(pants.lightened(0.18)))
		leg.box(0, 1, 0, 2, 1, 3, SC)
		leg.box(0, 0, 0, 2, 0, 3, SW)
		leg.set_v(1, 1, 3, SW)
		leg.set_v(1, 1, 2, SW)
	else:
		leg.box(0, 0, 0, 2, 1, 2, LS)
		leg.box(0, 0, 3, 2, 0, 3, LS)
	if outfit == "robe":
		leg.box(0, 2, 0, 2, 8, 2, leg.add_color(shirt))

	var parts := {
		"head": VM.build(h, VS, Vector3(5, 0, 5)),
		"torso": VM.build(t, VS, Vector3(4, 0, 2 + zo)),
		"arm": VM.build(arm, VS, Vector3(1, 9, 1.5)),
		"leg": VM.build(leg, VS, Vector3(1.5, 9, 1.5)),
	}
	_cache[key] = parts
	return parts


## Builds a rig. Children: Body (rotate for facing) > Torso, Head, ArmL, ArmR, LegL, LegR.
static func build(look: Dictionary) -> Node3D:
	var p := _parts(look)
	var root := Node3D.new()
	root.name = "Person"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var hip := 9.0 * VS
	var torso := MeshInstance3D.new()
	torso.mesh = p["torso"]
	torso.position = Vector3(0, hip, 0)
	body.add_child(torso)
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = p["head"]
	head.position = Vector3(0, hip + 9.0 * VS, 0)
	body.add_child(head)
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.mesh = p["arm"]
		arm.position = Vector3(side * 5.0 * VS, hip + 8.5 * VS, 0)
		body.add_child(arm)
		var leg := MeshInstance3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.mesh = p["leg"]
		leg.position = Vector3(side * 1.6 * VS, hip, 0)
		body.add_child(leg)
	return root


static func face(rig: Node3D, dir: Vector2i) -> void:
	var body: Node3D = rig.get_node("Body")
	var ang := 0.0
	if dir == Vector2i(0, -1):
		ang = PI
	elif dir == Vector2i(1, 0):
		ang = PI / 2.0
	elif dir == Vector2i(-1, 0):
		ang = -PI / 2.0
	body.rotation.y = ang


## Walk cycle. phase in radians; amount 0 (standing) .. 1 (full stride).
static func animate(rig: Node3D, phase: float, amount: float) -> void:
	var body: Node3D = rig.get_node("Body")
	var swing := sin(phase) * 0.7 * amount
	body.get_node("LegL").rotation.x = swing
	body.get_node("LegR").rotation.x = -swing
	body.get_node("ArmL").rotation.x = -swing * 0.8
	body.get_node("ArmR").rotation.x = swing * 0.8
	body.position.y = absf(sin(phase)) * 0.04 * amount


static func height() -> float:
	return 26.0 * VS
