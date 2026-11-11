extends RefCounted
## Dictionaries retain total quantities; a visible stack contains at most nine items.

static func used(items: Dictionary) -> int:
	return GameState.stacks_used(items)

static func room(items: Dictionary, id: String, capacity: int) -> int:
	return GameState.item_room(id, items, capacity)

static func move(source: Dictionary, target: Dictionary, id: String, quantity: int, capacity: int) -> int:
	var n := mini(maxi(quantity, 0), mini(int(source.get(id, 0)), room(target, id, capacity)))
	if n <= 0:
		return 0
	target[id] = int(target.get(id, 0)) + n
	source[id] = int(source[id]) - n
	if source[id] <= 0:
		source.erase(id)
	return n

static func rows(items: Dictionary) -> Array:
	var result := []
	for id in items:
		if GameState.bag_exempt(id):
			continue
		var left := int(items[id])
		while left > 0:
			var n := mini(left, GameState.ITEM_STACK_SIZE)
			result.append({"id": String(id), "count": n})
			left -= n
	return result
