extends Node
## Minimal NPC container for story transitions; tests use real map data and real UI separately.
var npcs := {}


func remove_npc(n: Dictionary) -> void:
	npcs.erase(n.get("pos", Vector2i(-1, -1)))
