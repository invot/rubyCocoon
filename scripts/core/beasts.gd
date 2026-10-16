extends RefCounted
## Creates beasts: wild/trainer beasts, loaded beasts, and temple merges.

const Beast = preload("res://scripts/core/beast.gd")
const RaceDB = preload("res://scripts/data/race_db.gd")
const MoveDB = preload("res://scripts/data/move_db.gd")

const GHOST_STAT_MULT := 1.25
const PARTS := ["body", "head", "ears", "tail", "back", "pattern"]


static func create(race_id: int, level: int, ghost := false) -> Beast:
	var r := RaceDB.get_race(race_id)
	var b := Beast.new()
	b.uid = randi()
	b.race = race_id
	b.lineage = [race_id]
	b.ghost = ghost
	b.element = "ghost" if ghost else r["el"]
	b.nickname = ("Umbral " + r["name"]) if ghost else r["name"]
	b.level = clampi(level, 1, 100)
	b.rank = maxi(1, int(ceil(b.level / 20.0)))
	b.xp = Beast.xp_for_level(b.level)
	var bs := RaceDB.base_stats(race_id)
	for i in Beast.STAT_KEYS.size():
		var v: float = bs[i] * randf_range(0.92, 1.08)
		if ghost:
			v *= GHOST_STAT_MULT
		b.base[Beast.STAT_KEYS[i]] = snappedf(v, 0.1)
	b.genes = RaceDB.genes(race_id)
	if ghost:
		b.genes["shade"] = 0.85
	b.passives = [r["passive"]]
	if RaceDB.is_legendary(race_id):
		b.passives = RaceDB.LEGENDARY_PASSIVES[race_id].duplicate()
	if ghost:
		b.passives.append("Phantom")
	var ls: Array = RaceDB.ghost_learnset(race_id) if ghost else RaceDB.learnset(race_id)
	for e in ls:
		if int(e[0]) <= b.level and not b.known.has(e[1]):
			b.known.append(e[1])
	b.moves = b.known.slice(maxi(0, b.known.size() - Beast.MAX_MOVES))
	b.hp = b.max_hp()
	b.mp = b.max_mp()
	return b


static func from_dict(d: Dictionary) -> Beast:
	var b := Beast.new()
	b.load_dict(d)
	return b


static func copy(b: Beast) -> Beast:
	return from_dict(b.to_dict())


static func can_merge(a: Beast, b: Beast, ghost_allowed: bool) -> String:
	## Returns "" if the pair can merge, otherwise a reason.
	if a == b:
		return "A beast can't merge with itself."
	if not a.at_cap():
		return "%s hasn't reached its level limit (Lv %d)." % [a.nickname, a.level_cap()]
	if not b.at_cap():
		return "%s hasn't reached its level limit (Lv %d)." % [b.nickname, b.level_cap()]
	if (a.ghost or b.ghost) and not ghost_allowed:
		return "Ghost beasts resist merging... Only in Gravenmoor, where the shadows gather, can they be merged."
	if maxi(a.rank, b.rank) >= 5:
		return "These beasts are already at the highest rank."
	return ""


static func merged_name(a: String, b: String) -> String:
	a = a.replace("Umbral ", "")
	b = b.replace("Umbral ", "")
	var ha := int(ceil(a.length() / 2.0))
	var hb := int(floor(b.length() / 2.0))
	var n := a.substr(0, ha) + b.substr(b.length() - hb)
	return n.to_lower().capitalize()


## Who dominates a merge: a legendary parent passes on ~80% of the traits, otherwise 50/50.
static func dominance(a: Beast, b: Beast) -> float:
	var la := RaceDB.is_legendary(a.race)
	var lb := RaceDB.is_legendary(b.race)
	if la and not lb:
		return 0.8
	if lb and not la:
		return 0.2
	return 0.5


static func merge(a: Beast, b: Beast, temple := false) -> Beast:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pa := dominance(a, b)  # chance each trait comes from `a`
	var pick := func(): return rng.randf() < pa
	var c := Beast.new()
	c.uid = randi()
	var primary := a if pick.call() else b
	if pa != 0.5:
		primary = a if pa > 0.5 else b  # the legendary keeps its race
	c.race = primary.race
	c.ghost = a.ghost or b.ghost
	if c.ghost:
		c.element = "ghost"
	elif a.element == b.element:
		c.element = a.element
	else:
		c.element = a.element if pick.call() else b.element
	c.rank = maxi(a.rank, b.rank) + 1
	c.level = mini(maxi(a.level, b.level) + 1, c.level_cap())
	c.xp = Beast.xp_for_level(c.level)
	c.merges = a.merges + b.merges + 1
	c.origin = "merge"

	var lin := []
	for r in a.lineage + b.lineage:
		if not lin.has(r):
			lin.append(r)
	while lin.size() > 6:
		lin.remove_at(0)
	c.lineage = lin
	c.parents = [a.family_node(1), b.family_node(1)]

	# stats: each stat comes from one parent, then improves
	var lucky: String = Beast.STAT_KEYS[rng.randi_range(0, 4)]
	for s in Beast.STAT_KEYS:
		var va: float = a.base.get(s, 50.0)
		var vb: float = b.base.get(s, 50.0)
		var v := va if pick.call() else vb
		if temple and s == lucky:
			v = maxf(va, vb)
		var boost := rng.randf_range(1.06, 1.16) + (0.05 if temple else 0.0)
		c.base[s] = snappedf(v * boost, 0.1)

	# appearance: each body part from one parent; colours mix
	var g := {}
	for p in PARTS:
		g[p] = a.genes.get(p, "none") if pick.call() else b.genes.get(p, "none")
	var first := a if pick.call() else b
	var second := b if first == a else a
	g["c1"] = first.genes.get("c1", "#888888")
	g["c2"] = (a if pick.call() else b).genes.get("c2", "#cccccc") if pa != 0.5 else second.genes.get("c2", "#cccccc")
	g["c3"] = (a if pick.call() else b).genes.get("c3", "#ffffff")
	if pa == 0.5 and rng.randf() < 0.3:
		var mix := Color(str(a.genes.get("c1", "#888888"))).lerp(Color(str(b.genes.get("c1", "#888888"))), 0.5)
		g["c1"] = "#" + mix.to_html(false)
	g["size"] = minf(1.6, maxf(float(a.genes.get("size", 1.0)), float(b.genes.get("size", 1.0))) * rng.randf_range(1.0, 1.06))
	var sa: float = a.genes.get("shade", 0.0)
	var sb: float = b.genes.get("shade", 0.0)
	if c.ghost:
		g["shade"] = 0.85 if (a.ghost and b.ghost) else 0.62
	else:
		g["shade"] = maxf(sa, sb)
	c.genes = g

	# moves: mostly from the dominant parent, everything else remembered
	var pool := []
	for m in a.known + b.known:
		if not pool.has(m):
			pool.append(m)
	var am := a.moves.duplicate()
	var bm := b.moves.duplicate()
	am.shuffle()
	bm.shuffle()
	var na := int(round(4 * pa))
	var active := []
	for m in am.slice(0, na) + bm.slice(0, 4 - na) + am + bm:
		if active.size() >= Beast.MAX_MOVES:
			break
		if not active.has(m):
			active.append(m)
	c.moves = active
	c.known = pool

	# passives
	var ppool := []
	var dom_first: Array = a.passives + b.passives if pa >= 0.5 else b.passives + a.passives
	for p in dom_first:
		if not ppool.has(p) and p != "Phantom":
			ppool.append(p)
	if pa == 0.5:
		ppool.shuffle()
	c.passives = [ppool[0]] if ppool.size() > 0 else []
	if ppool.size() > 1 and (temple and rng.randf() < 0.5 or rng.randf() < 0.15 or pa != 0.5):
		c.passives.append(ppool[1])
	if c.ghost:
		c.passives.append("Phantom")

	c.nickname = merged_name(primary.nickname, (b if primary == a else a).nickname) if pa == 0.5 else primary.nickname.replace("Umbral ", "")
	if c.ghost:
		c.nickname = "Umbral " + c.nickname.replace("Umbral ", "")
	c.hp = c.max_hp()
	c.mp = c.max_mp()
	return c
