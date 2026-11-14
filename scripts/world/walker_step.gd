extends RefCounted
## Occupancy and neighbour rules shared by the hero, people and beasts.
## Keep movement policy outside elevation.gd: its source pins baked terrain.
const Elev = preload("res://scripts/world/elevation.gd")


## The caller supplies occupancy and tiles requiring cardinal approaches.
## Check every edge of a diagonal's square, including both side tiles.
static func clear(m: Dictionary, a: Vector2i, b: Vector2i, free: Callable, cardinal_only := Callable()) -> bool:
	var d := b - a
	if d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
		return false
	if not free.call(b):
		return false
	if d.x == 0 or d.y == 0:
		return Elev.joined(m, a, b)
	var x := a + Vector2i(d.x, 0)
	var y := a + Vector2i(0, d.y)
	if not free.call(x) or not free.call(y):
		return false
	for p in [a, x, y, b]:
		if Elev.ramp_dir(m, p) != Vector2i.ZERO or Elev.diagonal(m, p) != 0:
			return false
		if cardinal_only.is_valid() and cardinal_only.call(p):
			return false
	return Elev.joined(m, a, x) and Elev.joined(m, a, y) and Elev.joined(m, x, b) and Elev.joined(m, y, b)
