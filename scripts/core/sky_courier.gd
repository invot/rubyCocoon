extends RefCounted
## Reservations stay in the locker, including while a call is replaced or a save is loaded.
const Stacks = preload("res://scripts/core/item_stacks.gd")
const LOCKER_CAP := 48
const BAG_CAP := 24
const LOAD_CAP := 12
const DELAY := 30.0
const PICKUP_FEE := 20
const KEEPER := "Sky Tower Courier"

static func available() -> Dictionary:
	var stock := GameState.locker.duplicate()
	for id in GameState.courier_request.get("items", {}):
		stock[id] = maxi(0, int(stock.get(id, 0)) - int(GameState.courier_request["items"][id]))
		if stock[id] == 0:
			stock.erase(id)
	return stock

static func order(service: int, items: Dictionary = {}) -> bool:
	if service < 0 or service > 3 or Stacks.used(items) > LOAD_CAP:
		return false
	for id in items:
		if int(items[id]) <= 0 or int(items[id]) > int(GameState.locker.get(id, 0)):
			return false
	GameState.courier_request = {"service": service, "items": items.duplicate()}
	GameState.courier_left = DELAY
	return true

static func receive(id: String, quantity: int) -> int:
	var pending: Dictionary = GameState.courier_request.get("items", {})
	var n := mini(quantity, int(pending.get(id, 0)))
	n = Stacks.move(GameState.locker, GameState.inventory, id, n, BAG_CAP)
	if n > 0:
		pending[id] = int(pending[id]) - n
		if pending[id] <= 0:
			pending.erase(id)
	return n

static func receive_fitting() -> void:
	var pending: Dictionary = GameState.courier_request.get("items", {})
	for id in pending.keys():
		receive(id, int(pending[id]))

static func pickup(items: Dictionary) -> bool:
	if items.is_empty() or GameState.gold < PICKUP_FEE or Stacks.used(items) > LOAD_CAP:
		return false
	var bag := GameState.inventory.duplicate()
	var locker := GameState.locker.duplicate()
	for id in items:
		var n := int(items[id])
		if n <= 0 or Stacks.move(bag, locker, id, n, LOCKER_CAP) != n:
			return false
	GameState.inventory.assign(bag)
	GameState.locker.assign(locker)
	GameState.gold -= PICKUP_FEE
	return true

## True means a flight is queued: keep the old world's controls frozen through its transition.
static func visit(world, employee: Node3D) -> bool:
	var service := int(GameState.courier_request.get("service", -1))
	if service in [2, 3]:
		receive_fitting()
		if not GameState.courier_request.get("items", {}).is_empty():
			await UI.say(["Your bag is full. You can send stacks back to your locker or drop them to make room."], KEEPER, null, employee)
			await load("res://scripts/ui/locker_screen.gd").open("receive")
		await UI.say(["Your delivery is here. Anything you couldn't carry stays safe in your locker."], KEEPER, null, employee)
	if service == 1:
		if GameState.gold < PICKUP_FEE:
			await UI.say(["A pickup costs 20 gold. You don't have enough today."], KEEPER, null, employee)
		else:
			var items: Dictionary = await load("res://scripts/ui/locker_screen.gd").open("pickup")
			if not items.is_empty():
				if pickup(items):
					await UI.say(["All safely stored. That's 20 gold, thank you!"], KEEPER, null, employee)
				else:
					await UI.say(["There isn't room in your locker for that load. Nothing was charged."], KEEPER, null, employee)
	# Release undelivered reservations before travel. They never left storage.
	GameState.courier_request = {}
	if service in [0, 3]:
		var fare := Places.FLIGHT_COST * 2
		if GameState.gold < fare:
			await UI.say(["A courier ride costs %d gold. You don't have enough today." % fare], KEEPER, null, employee)
		else:
			await UI.say(["Where shall we take you? A courier ride costs %d gold." % fare], KEEPER, null, employee)
			# Leave on the bird before the shared flight flash and map transition.
			var dests: Array = GameState.visited.filter(func(t): return t != world.map_id)
			var labels: Array = dests.map(func(t): return preload("res://scripts/data/world_db.gd").map_name(t))
			if labels.is_empty():
				await UI.say(["Visit another town first, then we'll take you there."], KEEPER, null, employee)
			else:
				var choice := await UI.choose("Ride · %d gold" % fare, labels)
				if choice >= 0:
					await world.courier_takeoff()
					await Places.fly_to(String(dests[choice]), fare)
					return true
	return false
