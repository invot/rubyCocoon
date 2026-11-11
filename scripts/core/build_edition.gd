extends RefCounted
## The export feature is baked into the demo; command-line preview is editor-only.
const WorldDB = preload("res://scripts/data/world_db.gd")


static func is_demo() -> bool:
	return OS.has_feature("demo") or (OS.has_feature("editor") and "--demo" in OS.get_cmdline_user_args())


static func allows_map(id: String) -> bool:
	if not is_demo():
		return true
	var base := id.get_slice("#", 0)
	var towns := WorldDB.TOWN_ORDER.slice(0, WorldDB.TOWN_ORDER.find("dustwell") + 1)
	if base in towns:
		return true
	var route: Dictionary = WorldDB.ROUTES.get(base, {})
	return not route.is_empty() and route["from"] in towns and (route["to"] == "" or route["to"] in towns)
