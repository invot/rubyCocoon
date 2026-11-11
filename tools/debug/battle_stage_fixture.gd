extends "res://scripts/battle/battle.gd"
## Real stage/rendering without a competing command coroutine or player saves.
func _run() -> void:
	ally_ring = GameState.ring()
	ally_side = 0
	foe_side = 0
	if not wild:
		var placed := Ring.arrange(foes)
		for slot in placed:
			if int(slot) >= 0:
				foe_ring[slot] = placed[slot]
		foe_side = maxi(0, Ring.best_side(foe_ring))
	for team in ring_root:
		ring_psi[team] = _psi_for(team, ally_side if team == "ally" else foe_side)
		_light_pads(team)
	_sync_slots()
	for slot in ally_ring:
		_spawn(ally_ring[slot], "ally", slot)
	_place_ring("ally")
	if wild:
		for i in mini(3, foes.size()):
			foe_slots[i] = foes[i]
			_spawn(foes[i], "foe", i)
	else:
		for slot in foe_ring:
			_spawn(foe_ring[slot], "foe", slot)
		_place_ring("foe")
	_refresh()
	_commanding = true
	var row: Dictionary = _panel_rows()[0]
	_select_hud_actor("trainer_self")
	_show_option(row, row["options"][0])
	_caption("What will you do, %s?" % GameState.player_name, "trainer_self")
