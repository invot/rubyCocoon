extends RefCounted
## The beat attack's rules. A trainer's weapon (item_db.gd WEAPONS) lands a chain of hits in time with the battle
## music: a cue spins above the target (battle/beat_cue.gd) and each press of A on a beat throws, swings or flings once
## more. Sfx keeps the beat (Sfx.beat_now); battle.gd plays the throws and deals the damage. Foe trainers don't play
## it: their hits are rolled from their strength (roll).
##
## - Below trainer Lv UNLOCK_LEVEL a weapon makes one plain throw, as the slingshot always did.
## - From there the chain grows with trainer level (HITS): 3 hits at Lv 4, one more each level, all 10 at Lv 10.
## - Each press is graded by its distance from the beat: Perfect, Good or Miss. The grade sets that hit's damage.
## - A Miss ends the chain; hits already landed count. Missing the very first beat still lands one weak hit.
## - Landing every hit the level allows makes the last one critical.
## - The windows are wider for the guided first time and on the first road (EASY).

const UNLOCK_LEVEL := 4
## the most hits a turn's chain can land, by trainer level (below UNLOCK_LEVEL: a plain throw)
const HITS := {4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 10}
## grading windows: the most a press may be off the beat (seconds) to be Perfect, or Good
const PERFECT := 0.06
const GOOD := 0.13
const EASY_PERFECT := 0.10
const EASY_GOOD := 0.20
## each hit's damage as a share of one plain throw's, by grade ("weak": the first beat missed)
## (a full Perfect chain at Lv 4 is worth about 1.75 plain throws, at Lv 10 about 5.25)
const GRADE_MULT := {"perfect": 0.5, "good": 0.3, "weak": 0.3}
const CRIT_MULT := 1.5
## beats the cue spins before the first one that counts (at least)
const LEAD_BEATS := 1.6


## How many hits a chain may land at a trainer level: 0 below UNLOCK_LEVEL (a plain throw instead).
static func max_hits(trainer_level: int) -> int:
	if trainer_level < UNLOCK_LEVEL:
		return 0
	return int(HITS.get(mini(trainer_level, 10), 10))


## What a trainer level-up means for the beat attack (going from `before` to `after`), "" if nothing.
static func level_line(before: int, after: int) -> String:
	var was := max_hits(before)
	var now := max_hits(after)
	if now <= was:
		return ""
	if was == 0:
		return "Your aim's sharper now! In battle, pick a weapon and press A on the beat to land up to %d hits in a row." % now
	return "Your weapons now land up to %d hits on the beat." % now


## A press `dt` seconds off its beat (either way): "perfect", "good" or "miss".
static func grade(dt: float, easy := false) -> String:
	var d := absf(dt)
	if d <= (EASY_PERFECT if easy else PERFECT):
		return "perfect"
	if d <= (EASY_GOOD if easy else GOOD):
		return "good"
	return "miss"


## The latest a beat can still be pressed (seconds after it) before it counts as missed.
static func late_limit(easy := false) -> float:
	return EASY_GOOD if easy else GOOD


## The hits a run of graded beats lands, in order: [{grade, mult, crit}]. A "miss" ends the chain (the first beat
## missed: one weak hit); every hit of a full chain (`most` long) landed makes the last one critical.
static func hits_from(grades: Array, most: int) -> Array:
	var out := []
	for i in mini(grades.size(), most):
		var g := String(grades[i])
		if g == "miss":
			if i == 0:
				out.append({"grade": "weak", "mult": float(GRADE_MULT["weak"]), "crit": false})
			break
		out.append({"grade": g, "mult": float(GRADE_MULT[g]), "crit": false})
	if out.size() == most and most > 0 and String(out.back()["grade"]) != "weak":
		out.back()["crit"] = true
		out.back()["mult"] = float(out.back()["mult"]) * CRIT_MULT
	return out


## A foe trainer's chain, rolled from their strength (0 = a beginner, 1 = a champion) instead of played: each beat is
## Perfect, Good or Miss by chance, the stronger the likelier to land.
static func roll(strength: float, most: int, rng: RandomNumberGenerator) -> Array:
	var s := clampf(strength, 0.0, 1.0)
	var perfect := lerpf(0.2, 0.55, s)
	var good := lerpf(0.45, 0.35, s)
	var grades := []
	for i in most:
		var r := rng.randf()
		var g := "perfect" if r < perfect else ("good" if r < perfect + good else "miss")
		grades.append(g)
		if g == "miss":
			break
	return hits_from(grades, most)


## What a chain adds up to, as a share of one plain throw (for the top bar and tests).
static func total(hits: Array) -> float:
	var t := 0.0
	for h in hits:
		t += float(h["mult"])
	return t
