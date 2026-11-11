extends RefCounted
## Godot normalizes gamepad buttons by position: south confirms, east backs out.
## Nintendo's printed letters differ, so the guide describes the actual bound positions.

static func identify(device_name: String, info := {}) -> String:
	var n := device_name.to_lower()
	var vendor := int(info.get("vendor_id", 0))
	if "dualsense" in n or "ps5" in n:
		return "ps5"
	if "dualshock 4" in n or "dualshock4" in n or "ps4" in n:
		return "ps4"
	if "dualshock 3" in n or "dualshock3" in n or "playstation 3" in n or "playstation(r)3" in n or "ps3" in n:
		return "ps3"
	if "playstation" in n or "sony" in n or vendor == 0x054c:
		return "ps4"
	if "joy-con" in n or "joycon" in n:
		return "joy-cons"
	if "wii u pro" in n:
		return "wii-u-pro"
	if "wii classic" in n:
		return "wii-classic"
	if "switch" in n or "nintendo" in n or vendor == 0x057e:
		return "switch-pro"
	if "stadia" in n:
		return "stadia"
	if "360" in n and ("xbox" in n or "xinput" in n):
		return "xbox-360"
	if "xbox" in n and ("series" in n or "elite" in n):
		return "xbox-series-x"
	return "xbox-one"


static func describe(layout: String) -> Dictionary:
	var names := {"ps5": "DualSense", "ps4": "DualShock 4", "ps3": "DualShock 3",
		"joy-cons": "Joy-Cons", "switch-pro": "Switch Pro", "wii-u-pro": "Wii U Pro",
		"wii-classic": "Wii Classic", "stadia": "Stadia", "xbox-360": "Xbox 360",
		"xbox-series-x": "Xbox Series", "xbox-one": "Xbox"}
	var out := {"name": names.get(layout, "Xbox"), "accept": "A", "back": "B", "start": "Menu", "pause": "View"}
	if layout.begins_with("ps"):
		out.merge({"accept": "Cross", "back": "Circle", "start": "Options" if layout != "ps3" else "Start",
			"pause": "Create" if layout == "ps5" else ("Select" if layout == "ps3" else "Share")}, true)
	elif layout in ["switch-pro", "joy-cons", "wii-u-pro", "wii-classic"]:
		out.merge({"accept": "B", "back": "A", "start": "+", "pause": "−"}, true)
	elif layout == "xbox-360":
		out.merge({"start": "Start", "pause": "Back"}, true)
	elif layout == "stadia":
		out.merge({"start": "Menu", "pause": "Options"}, true)
	return out
