extends RefCounted
## The rules of the Temple of Tides' two water puzzles (interior_maps.gd rooms with a "puzzle"). Each has four routing levers, and
## each lever is a flag (lever down = set). Its spots are where a waterfall can be: letters in the room's rows, blocked
## while water falls there. Which spots run follows only from the levers' positions, so pulling a lever back undoes it.
## The first room drains at its solution. In the maze, all four down reveal a fifth, drain lever in a wall cubby.
##   falls: three falls, all running to begin with. "running" gives the falls running for each pattern of the levers,
##          read as a binary number (lever 0 lowest; bit i = spots[i]). Each pull stops one, starts one, or does both.
##   maze:  three falls, each with its own lattices ("at"): the levers in "levers" pick which, by their positions read as
##          a binary number, so each lever moves one fall from one lattice to another.

const PUZZLES := {
	"falls": {"flag": "tides_falls_solved", "solution": [1, 1, 0, 1], "spots": ["a", "b", "c"],
		"running": [7, 6, 3, 5, 3, 5, 6, 3, 6, 5, 5, 4, 5, 3, 3, 2]},
	"maze": {"flag": "tides_maze_solved", "solution": [1, 1, 1, 1], "spots": ["a", "b", "c", "d", "e", "f", "g", "h"],
		"falls": [{"levers": [0], "at": ["a", "b"]}, {"levers": [1], "at": ["c", "d"]}, {"levers": [2, 3], "at": ["e", "f", "g", "h"]}]},
}
const LEVERS := 4
const CUBBY_FLAG := "tides_maze_cubby"
const CUBBY_TILE := Vector2i(14, 0)


static func cubby_open(flags: Dictionary) -> bool:
	# Also handles an older save made with all four levers already down, and completed saves.
	return bool(flags.get(CUBBY_FLAG, false)) or solved("maze", flags) or pattern("maze", flags) == PUZZLES["maze"]["solution"]


## The flag of lever `i` of puzzle `id`.
static func lever_flag(id: String, i: int) -> String:
	return "tide_%s_lever_%d" % [id, i]


## The levers' positions, 0 (up) or 1 (down).
static func pattern(id: String, flags: Dictionary) -> Array:
	var out := []
	for i in LEVERS:
		out.append(1 if flags.get(lever_flag(id, i), false) else 0)
	return out


static func solved(id: String, flags: Dictionary) -> bool:
	return bool(flags.get(PUZZLES[id]["flag"], false))


## True when the first room's pattern is right, or the maze's revealed drain lever has been pulled.
static func is_solution(id: String, flags: Dictionary) -> bool:
	if id == "maze":
		return cubby_open(flags) and bool(flags.get(lever_flag(id, 4), false))
	return pattern(id, flags) == PUZZLES[id]["solution"]


## The spots with water falling on them now (none once it's solved).
static func running(id: String, flags: Dictionary) -> Array:
	if solved(id, flags):
		return []
	var p: Dictionary = PUZZLES[id]
	var levers := pattern(id, flags)
	var out := []
	if p.has("running"):
		var pulled := 0
		for i in LEVERS:
			pulled += int(levers[i]) << i
		for i: int in p["spots"].size():
			if int(p["running"][pulled]) >> i & 1 != 0:
				out.append(p["spots"][i])
		return out
	for f: Dictionary in p["falls"]:
		var at := 0
		for i: int in f["levers"]:
			at = at * 2 + int(levers[i])
		out.append(f["at"][at])
	return out


## Writes puzzle `id`'s spots into a room's `rows`: water where a fall runs, floor elsewhere. Returns {"rows", "spots":
## tile -> spot letter}.
static func place(id: String, rows: Array, flags: Dictionary) -> Dictionary:
	var spots := {}
	var on := running(id, flags)
	var letters: Array = PUZZLES[id]["spots"]
	var out := []
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] in letters:
				spots[Vector2i(x, y)] = row[x]
				row[x] = "_" if row[x] in on else ":"
		out.append(row)
	return {"rows": out, "spots": spots}
