extends RefCounted
## The battle ring (as in Jade Cocoon 2): every trainer stands in the middle of a ring of 8 slots.
## The ring has four sides, one per element, in this order round it: Fire, Air, Water, Earth. A side's middle slot
## holds a beast of that element; the corner between two sides holds a beast of either element, or one of both
## (a merged dual beast). Opposite elements (Fire and Water, Air and Earth) share no corner and cannot merge.
##
## Slots are numbered round the ring: even slots are the sides' middles (0 Fire, 2 Air, 4 Water, 6 Earth), odd slots
## the corners after them (1 Fire/Air, 3 Air/Water, 5 Water/Earth, 7 Earth/Fire).
## In battle one side faces the foe: its three slots are the trainer's three active beasts, listed top to bottom as
## the corner before it, its middle and the corner after it. Only that side's element (and plain, neutral moves) can
## be used. If the beast in its middle slot is down, or the slot is empty, the trainer can be attacked directly.
## Ghost beasts (the Umbral Legion's) fit any slot and use ghost and neutral moves on any side.

const ORDER := ["fire", "air", "water", "earth"]
const SLOTS := 8


static func side_element(side: int) -> String:
	return ORDER[posmod(side, 4)]


static func side_index(el: String) -> int:
	return ORDER.find(el)


## The elements a slot accepts: one for a side's middle, two for a corner.
static func slot_elements(slot: int) -> Array:
	slot = posmod(slot, SLOTS)
	if slot % 2 == 0:
		return [ORDER[slot / 2]]
	return [ORDER[slot / 2], ORDER[(slot / 2 + 1) % 4]]


## "Fire side", "Fire / Air corner".
static func slot_name(slot: int) -> String:
	var els := slot_elements(slot)
	if els.size() == 1:
		return "%s side" % String(els[0]).capitalize()
	return "%s / %s corner" % [String(els[0]).capitalize(), String(els[1]).capitalize()]


static func is_corner(slot: int) -> bool:
	return posmod(slot, 2) == 1


## The three slots of a side, top to bottom: the corner before it, its middle, the corner after it.
static func side_slots(side: int) -> Array:
	var mid := posmod(side, 4) * 2
	return [posmod(mid - 1, SLOTS), mid, mid + 1]


static func opposite(a: String, b: String) -> bool:
	var i := ORDER.find(a)
	var j := ORDER.find(b)
	return i >= 0 and j >= 0 and absi(i - j) == 2


static func adjacent(a: String, b: String) -> bool:
	var i := ORDER.find(a)
	var j := ORDER.find(b)
	return i >= 0 and j >= 0 and absi(i - j) in [1, 3]


## The elements a beast counts as on the ring (one, or two for a merged dual beast).
static func elements_of(b) -> Array:
	return b.elements()


## True if the beast may stand in the slot: a side takes its element; a corner takes either of its two elements, or a
## dual beast of exactly those two. Ghosts stand anywhere.
static func can_hold(b, slot: int) -> bool:
	if b.ghost or b.element == "ghost":
		return true
	var els := elements_of(b)
	var accepts := slot_elements(slot)
	if accepts.size() == 1:
		return accepts[0] in els
	for e in els:
		if not e in accepts:
			return false
	return true


## The slots a beast may stand in, best first: its own side's middle, then its corners.
static func legal_slots(b) -> Array:
	var out := []
	for k in SLOTS:
		if can_hold(b, k):
			out.append(k)
	out.sort_custom(func(x, y): return int(is_corner(x)) < int(is_corner(y)))
	return out


## The element a beast fights with while `side` faces the foe: the side's own element if the beast has it, ghost
## for ghosts, otherwise only plain (neutral) moves.
static func fighting_element(b, side: int) -> String:
	if b.ghost or b.element == "ghost":
		return "ghost"
	var el := side_element(side)
	return el if el in elements_of(b) else "neutral"


## The element that defends a beast on the ring: the active side's element if it is one of the beast's, else its own.
static func guarding_element(b, side: int) -> String:
	if b.ghost or b.element == "ghost":
		return "ghost"
	var el := side_element(side)
	return el if el in elements_of(b) else String(b.element)


## The side most of a ring's beasts stand on (fainted or not), or -1 for an empty ring.
static func home_side(ring: Dictionary) -> int:
	var best := -1
	var most := 0
	for side in 4:
		var n := 0
		for k in side_slots(side):
			if ring.get(k, null) != null:
				n += 1 + (1 if k == side * 2 else 0)
		if n > most:
			most = n
			best = side
	return best


## The free slots a beast may stand in, best first: on the team's home side (so as many beasts as possible fight
## together), its own side's middle if that side has none yet, then the rest.
static func preferred_slots(b, ring: Dictionary) -> Array:
	var home := home_side(ring)
	var free := legal_slots(b).filter(func(k): return ring.get(k, null) == null)
	var score := func(k: int) -> float:
		var sc := 0.0
		if home >= 0 and k in side_slots(home):
			sc += 10.0 + (2.0 if k == home * 2 else 0.0)
		if not is_corner(k):
			sc += 3.0
		return sc
	free.sort_custom(func(x, y): return score.call(x) > score.call(y))
	return free


## Places a team on a ring: {slot: beast}, with -1 -> [the beasts left off it]. The side that can field the most
## (and strongest) of them is filled first, middle then corners; the rest take the best free slots they may.
static func arrange(team: Array) -> Dictionary:
	var best_side := 0
	var best_fill := {}
	var best_score := -1.0
	for side in 4:
		var fill := {}
		var left := team.duplicate()
		for k in [side * 2, side_slots(side)[0], side_slots(side)[2]]:
			var pick = null
			for b in left:
				if can_hold(b, k) and (pick == null or b.level > pick.level):
					pick = b
			if pick != null:
				fill[k] = pick
				left.erase(pick)
		var sc := 0.0
		for k in fill:
			sc += 10.0 + float(fill[k].level) * 0.1 + (5.0 if k == side * 2 else 0.0)
		if sc > best_score:
			best_score = sc
			best_side = side
			best_fill = fill
	var out := best_fill.duplicate()
	var off := []
	for b in team:
		if b in out.values():
			continue
		var slots := preferred_slots(b, out)
		if slots.is_empty():
			off.append(b)
		else:
			out[slots[0]] = b
	out[-1] = off
	return out


## The side with the most beasts still standing in its three slots (ties: the one with more HP left), or -1.
static func best_side(ring: Dictionary) -> int:
	var best := -1
	var best_score := 0.0
	for s in 4:
		var score := 0.0
		for k in side_slots(s):
			var b = ring.get(k, null)
			if b != null and b.hp > 0:
				score += 1.0 + b.hp_ratio() * 0.5 + (0.6 if k == s * 2 else 0.0)
		if score > best_score:
			best_score = score
			best = s
	return best


## True if some beast is standing on `side` (a trainer may only turn the ring to such a side).
static func side_alive(ring: Dictionary, side: int) -> bool:
	for k in side_slots(side):
		var b = ring.get(k, null)
		if b != null and b.hp > 0:
			return true
	return false


## The next side round from `side` in direction `dir` (-1 or 1) with a beast standing on it, or `side` if none.
static func next_side(ring: Dictionary, side: int, dir: int) -> int:
	for i in range(1, 4):
		var s := posmod(side + dir * i, 4)
		if side_alive(ring, s):
			return s
	return side
